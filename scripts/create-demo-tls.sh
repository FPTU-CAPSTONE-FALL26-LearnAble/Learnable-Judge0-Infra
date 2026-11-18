#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2 || { echo 'Usage: bash scripts/create-demo-tls.sh CURRENT_IPV4 NEW_TLS_DIRECTORY'; exit 1; }
python3 -c 'import ipaddress,sys; ipaddress.IPv4Address(sys.argv[1])' "$1"
umask 077
# mkdir must fail if the destination exists, preserving all existing certificates.
mkdir -m 700 "$2"
openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 30 \
  -subj '/CN=LearnAble Judge0 demo' \
  -addext "subjectAltName=IP:$1" \
  -addext 'basicConstraints=critical,CA:FALSE' \
  -addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
  -addext 'extendedKeyUsage=serverAuth' \
  -keyout "$2/server.key" -out "$2/server.crt" 2>/dev/null
openssl x509 -in "$2/server.crt" -noout -fingerprint -sha256 -dates
echo 'Install only server.crt in backend trust through an authenticated channel.'
