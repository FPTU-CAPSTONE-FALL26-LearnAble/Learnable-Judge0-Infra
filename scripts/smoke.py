#!/usr/bin/env python3
"""Small authenticated end-to-end checks. Never print credentials or source output."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import ipaddress
import json
from pathlib import Path
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='http://127.0.0.1:2358')
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--ca', type=Path)
    parser.add_argument('--network-target', required=True, help='Reachable DB container IPv4, port 5432')
    args = parser.parse_args()
    target = str(ipaddress.IPv4Address(args.network_target))
    url = urllib.parse.urlsplit(args.url)
    if url.scheme != 'https' and not (url.scheme == 'http' and url.hostname in ['localhost', '127.0.0.1']):
        raise RuntimeError('Use HTTPS for remote endpoints')
    if url.username or url.password or url.query or url.fragment:
        raise RuntimeError('URL must contain no credentials, query or fragment')
    config = dict(line.strip().split('=', 1) for line in args.config.read_text().splitlines()
                  if line and not line.startswith('#') and '=' in line)
    token = config['AUTHN_TOKEN']
    if not token or token.startswith('REPLACE_'):
        raise RuntimeError('A real token is required')
    context = ssl.create_default_context(cafile=str(args.ca) if args.ca else None)

    def request(method, path, body=None, auth=token):
        headers = {'Content-Type': 'application/json'}
        if auth is not None:
            headers[config['AUTHN_HEADER']] = auth
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(args.url.rstrip('/') + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, context=context, timeout=15) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            return error.code, None

    def require(condition, name):
        if not condition:
            raise RuntimeError(name + ' failed')
        print('PASS ' + name)

    for supplied, name in [(None, 'missing token'), ('invalid-smoke-token', 'wrong token')]:
        require(request('GET', '/languages', auth=supplied)[0] == 401, name)
    code, languages = request('GET', '/languages')
    require(code == 200 and isinstance(languages, list), 'languages')
    print(json.dumps({'verified_languages': languages}, ensure_ascii=False))
    python_id = next(item['id'] for item in languages if item['name'].startswith('Python (3.'))
    cpp_id = next(item['id'] for item in languages if item['name'].startswith('C++ (GCC'))

    def submission(name, source, language, expected_status, expected_output=None):
        body = {'language_id': language, 'source_code': source}
        if expected_output is not None:
            body['expected_output'] = expected_output
        code, created = request('POST', '/submissions?wait=false', body)
        require(code == 201 and bool(created.get('token')), name + ' create')
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            code, result = request('GET', '/submissions/' + created['token'])
            if code != 200:
                raise RuntimeError(name + ' polling HTTP ' + str(code))
            status = result['status']['id']
            if status not in [1, 2]:
                require(status == expected_status, name + ' terminal status ' + str(status))
                return
            time.sleep(1)
        raise RuntimeError(name + ' polling deadline exceeded')

    submission('accepted', 'print(42)', python_id, 3, '42\n')
    submission('wrong answer', 'print(41)', python_id, 4, '42\n')
    submission('compilation error', 'int main( {', cpp_id, 6)
    submission('time limit', 'while True: pass', python_id, 5)
    code, _ = request('POST', '/submissions', {
        'language_id': python_id, 'source_code': 'print(42)', 'enable_network': True})
    require(code == 422, 'network override rejected')
    code, _ = request('POST', '/submissions', {
        'language_id': python_id, 'source_code': 'print(42)', 'cpu_time_limit': 3})
    require(code == 422, 'CPU override rejected')
    network_source = (
        'import socket\n'
        'try:\n'
        f'    s=socket.create_connection(({target!r},5432),timeout=1)\n'
        '    s.close()\n'
        '    print("NETWORK_REACHABLE")\n'
        'except OSError:\n'
        '    print("NETWORK_BLOCKED")\n'
    )
    submission('network isolation', network_source, python_id, 3, 'NETWORK_BLOCKED\n')
    with ThreadPoolExecutor(max_workers=2) as pool:
        runs = [pool.submit(submission, 'queued demo ' + str(i), 'print(42)', python_id, 3, '42\n') for i in range(2)]
        for run in runs:
            run.result()
    print('Worker readiness is demonstrated by terminal submissions. Repeat after restart and via HTTPS.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Exception text can contain request data or credentials. Keep logs bounded.
        print('FAIL smoke checks stopped (' + type(error).__name__ + '). Check host privately.')
        raise SystemExit(1)
