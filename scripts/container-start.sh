#!/usr/bin/env bash
set -euo pipefail
# Official startup prints `export` through tee, which would log credentials.
# Keep the official startup and signal handling, suppress exported-variable lines.
exec "$@" > >(sed -u '/^declare -x /d') 2>&1
