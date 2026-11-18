#!/usr/bin/env python3
"""Create a new secret config exclusively. Never overwrite existing files."""
import argparse
import os
from pathlib import Path
import secrets

parser = argparse.ArgumentParser()
parser.add_argument('destination', type=Path)
args = parser.parse_args()
template = Path(__file__).resolve().parents[1] / 'judge0.conf.example'
config = template.read_text()
for key in ['AUTHN_TOKEN', 'AUTHZ_TOKEN', 'SECRET_KEY_BASE', 'REDIS_PASSWORD', 'POSTGRES_PASSWORD']:
    config = config.replace('REPLACE_' + key, secrets.token_hex(64))
args.destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
fd = os.open(args.destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as output:
    output.write(config)
print('Created secret config. Values were not printed.')
