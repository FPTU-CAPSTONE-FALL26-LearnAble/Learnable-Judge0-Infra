#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test "$(uname -m)" = x86_64 || { echo 'Judge0 image requires verified amd64 support'; exit 1; }
test "$(stat -fc %T /sys/fs/cgroup)" != cgroup2fs || { echo 'Release requires reviewed cgroups v1 configuration'; exit 1; }
docker info --format 'Docker={{.ServerVersion}} Cgroups={{.CgroupVersion}} Architecture={{.Architecture}}'
docker compose version
docker compose config --quiet
python3 - <<'PY'
import json
import subprocess

spec = json.loads(subprocess.check_output(['docker', 'compose', 'config', '--format', 'json']))
settings = spec['services']['db']['environment']
for key in ['AUTHN_TOKEN', 'AUTHZ_TOKEN', 'SECRET_KEY_BASE', 'POSTGRES_PASSWORD', 'REDIS_PASSWORD']:
    value = settings.get(key, '')
    if not value or value.startswith('REPLACE_'):
        raise SystemExit('Missing real secret for ' + key)
if settings.get('AUTHN_HEADER') != 'X-Auth-Token':
    raise SystemExit('Review authentication header and proxy policy together')
print('Secret presence checks passed without printing values.')
PY
echo 'Render validation passed. Review RAM/disk, existing mounts/volume names and secrets before up.'
free -h
df -h . /var/lib/docker
