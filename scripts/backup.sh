#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test "$#" -eq 1 || { echo 'Usage: bash scripts/backup.sh /secure/path/backup.dump'; exit 1; }
umask 077
# Exclusive creation also prevents overwriting an existing backup.
set -o noclobber
docker compose exec -T db sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$1"
echo 'Database dump completed. Verify it before relying on it for restore.'
