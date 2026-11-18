#!/usr/bin/env bash
# Certbot deploy hook. Copies only a successfully renewed, matching certificate.
set -euo pipefail

expected_lineage=${JUDGE0_CERT_LINEAGE:-/etc/letsencrypt/live/learnable-judge0-ip}
if [ "${RENEWED_LINEAGE:-}" != "$expected_lineage" ]; then
    exit 0
fi

source "${JUDGE0_RENEWAL_CONFIG:-/etc/learnable-judge0/renewal.conf}"
: "${REPO_DIR:?Set the actual repository directory}"
: "${TLS_DIR:?Set the proxy TLS directory}"
: "${CERTIFICATE_IP:?Set the current certificate IP}"
test -d "$REPO_DIR/.git"
test -d "$TLS_DIR"
cd "$REPO_DIR"

exec 9>"${JUDGE0_TLS_LOCK_FILE:-/run/lock/learnable-judge0-tls.lock}"
flock -n 9 || { echo 'A certificate deployment is already running'; exit 1; }
umask 077
stage=$(mktemp -d "$TLS_DIR/.renew-XXXXXXXX")
replaced=false
cleanup() {
    status=$?
    trap - EXIT
    if [ "$replaced" = true ] && [ "$status" -ne 0 ]; then
        mv -f "$stage/previous.crt" "$TLS_DIR/server.crt"
        mv -f "$stage/previous.key" "$TLS_DIR/server.key"
        echo 'Certificate deployment failed. Previous certificate files restored.' >&2
    fi
    rm -rf -- "$stage"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Existing proxy files must be regular files. Preserve their contents for rollback.
for file in server.crt server.key; do
    test -f "$TLS_DIR/$file"
    test ! -L "$TLS_DIR/$file"
done
cp -p "$TLS_DIR/server.crt" "$stage/previous.crt"
cp -p "$TLS_DIR/server.key" "$stage/previous.key"
install -m 0644 "$RENEWED_LINEAGE/fullchain.pem" "$stage/server.crt"
install -m 0600 "$RENEWED_LINEAGE/privkey.pem" "$stage/server.key"
openssl x509 -in "$stage/server.crt" -noout -checkend 3600 >/dev/null
openssl x509 -in "$stage/server.crt" -noout -checkip "$CERTIFICATE_IP" >/dev/null
certificate_public_key=$(openssl x509 -in "$stage/server.crt" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum)
private_public_key=$(openssl pkey -in "$stage/server.key" -pubout -outform DER | sha256sum)
test "$certificate_public_key" = "$private_public_key"

# Verify that Compose points at the directory being updated, without dumping secrets.
export JUDGE0_EXPECTED_TLS_DIR="$TLS_DIR"
python3 - <<'PY'
import json
import os
from pathlib import Path
import subprocess

spec = json.loads(subprocess.check_output(['docker', 'compose', '--profile', 'https', 'config', '--format', 'json']))
mount = next(v for v in spec['services']['proxy']['volumes'] if v['target'] == '/etc/nginx/tls')
if Path(mount['source']).resolve() != Path(os.environ['JUDGE0_EXPECTED_TLS_DIR']).resolve():
    raise SystemExit('Proxy TLS mount differs from the renewal directory')
PY
docker compose --profile https exec -T proxy nginx -t
replaced=true
mv -f "$stage/server.crt" "$TLS_DIR/server.crt"
mv -f "$stage/server.key" "$TLS_DIR/server.key"
docker compose --profile https exec -T proxy nginx -t
docker compose --profile https exec -T proxy nginx -s reload
echo 'Renewed certificate deployed and Nginx reload requested.'
