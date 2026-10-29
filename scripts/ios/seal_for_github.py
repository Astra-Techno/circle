#!/usr/bin/env python3
"""Seal existing inputs using the key from a verified, reviewed GitHub run."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
from nacl.public import PublicKey, SealedBox
from github_secret_setup import NAMES, REPO


def seal_values(values, public_key, key_id):
    if set(values) != NAMES or any(not value or len(value) > 48000 for value in values.values()):
        raise ValueError('Exactly four nonempty, size-bounded signing inputs are required.')
    key = PublicKey(base64.b64decode(public_key, validate=True))
    box = SealedBox(key)
    return {'key_id': key_id, 'values': {
        name: base64.b64encode(box.encrypt(value)).decode() for name, value in values.items()}}


def gh(path):
    result = subprocess.run(['gh', 'api', path], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--signing-dir', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not args.run_id.isdecimal() or not re.fullmatch('[0-9a-f]{40}', args.expected_commit):
        raise ValueError('Use the exact reviewed workflow commit and run id.')
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError('Keep generated transfer files outside the repository.')
    run = gh(f'repos/{REPO}/actions/runs/{args.run_id}')
    if (run.get('head_sha') != args.expected_commit or run.get('head_branch') != 'main'
            or run.get('path') != '.github/workflows/ios-signing-setup.yml'
            or run.get('event') != 'workflow_dispatch' or run.get('conclusion') != 'success'
            or run.get('head_repository', {}).get('full_name') != REPO):
        raise ValueError('Public-key run does not match the reviewed setup workflow on main.')
    jobs = gh(f'repos/{REPO}/actions/runs/{args.run_id}/jobs')['jobs']
    reports = [job for job in jobs if job.get('name', '').startswith('Public iOS key | ')
               and job.get('conclusion') == 'success']
    if len(reports) != 1:
        raise ValueError('Expected one successful public encryption key report.')
    _, key_id, public_key = reports[0]['name'].split(' | ')
    if not re.fullmatch(r'[A-Za-z0-9_=-]{1,128}', key_id):
        raise ValueError('Invalid encryption key id.')
    names = {'IOS_TEAM_ID': 'IOS_TEAM_ID.txt',
             'IOS_CERTIFICATE_BASE64': 'IOS_CERTIFICATE_BASE64.txt',
             'IOS_CERTIFICATE_PASSWORD': 'certificate-password.txt',
             'IOS_PROFILE_BASE64': 'IOS_PROFILE_BASE64.txt'}
    # Only after authenticating GitHub run metadata do we read any private input.
    values = {name: (args.signing_dir / filename).read_bytes() for name, filename in names.items()}
    payload = json.dumps(seal_values(values, public_key, key_id), separators=(',', ':'))
    if len(payload) > 60000:
        raise ValueError('Encrypted transfer exceeds workflow input limit.')
    content = json.dumps({'action': 'import', 'sealed_payload': payload})
    old = os.umask(0o077)
    try:
        args.output.write_text(content)
        args.output.chmod(0o600)
    finally:
        os.umask(old)
    print('Four signing inputs sealed to GitHub; transfer file contains ciphertext only.')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        # Never print private file contents, exception reprs, HTTP output or argv.
        raise SystemExit('Sealing failed. Verify the reviewed workflow run, public key and private input files.')
