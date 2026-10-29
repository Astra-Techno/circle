#!/usr/bin/env python3
"""One-time encrypted import. This runner never receives plaintext signing data."""
import base64
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

REPO = 'Astra-Techno/circle'
ENVIRONMENT = 'ios-testflight'
PREFIX = f'/repos/{REPO}/environments/{ENVIRONMENT}'
NAMES = frozenset(('IOS_TEAM_ID', 'IOS_CERTIFICATE_BASE64',
                   'IOS_CERTIFICATE_PASSWORD', 'IOS_PROFILE_BASE64'))


class ApiFailure(Exception):
    def __init__(self, status):
        self.status = status
        super().__init__(f'GitHub API HTTP {status}; check token scope, expiry and repository access.')


def api(method, path, data=None):
    token = os.environ.get('IOS_SIGNING_SETUP_TOKEN', '').strip()
    if not token:
        raise ValueError('Add IOS_SIGNING_SETUP_TOKEN as a repository Actions secret. Never send it in chat or workflow inputs.')
    if not re.fullmatch(r'[A-Za-z0-9_]{20,255}', token):
        raise ValueError('Setup token format is invalid; paste it directly into the GitHub secret without extra text.')
    request = urllib.request.Request('https://api.github.com' + path, method=method,
        data=None if data is None else json.dumps(data).encode(), headers={
            'Authorization': 'Bearer ' + token,
            'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json',
            'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'CIRCLE-iOS-signing-setup'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        # Never print provider bodies, request headers, credentials or payloads.
        raise ApiFailure(error.code) from None
    return json.loads(raw) if raw else {}


def check_context():
    if os.environ.get('GITHUB_REF') != 'refs/heads/main' or os.environ.get('GITHUB_REPOSITORY') != REPO:
        raise ValueError('Signing setup is restricted to Astra-Techno/circle on main.')


def public_key():
    value = api('GET', PREFIX + '/secrets/public-key')
    if not isinstance(value, dict):
        raise ValueError('Invalid GitHub public-key response.')
    key_id, key = value.get('key_id'), value.get('key')
    if not isinstance(key_id, str) or not re.fullmatch(r'[A-Za-z0-9_=-]{1,128}', key_id):
        raise ValueError('Invalid GitHub encryption key id.')
    if not isinstance(key, str) or len(base64.b64decode(key, validate=True)) != 32:
        raise ValueError('Invalid GitHub public encryption key.')
    return value


def prepare():
    check_context()
    try:
        api('GET', PREFIX)
    except ApiFailure as error:
        if error.status != 404:
            raise
        api('PUT', PREFIX, {'deployment_branch_policy': {
            'protected_branches': False, 'custom_branch_policies': True}})
        api('POST', PREFIX + '/deployment-branch-policies', {'name': 'main', 'type': 'branch'})
    value = public_key()
    # This is a public encryption key, not an Apple signing key or a credential.
    with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
        output.write(f"key_id={value['key_id']}\npublic_key={value['key']}\n")
    print('GitHub public encryption key prepared; existing environment protections preserved.')


def validate_payload(raw, expected_id):
    if len(raw) > 60000:
        raise ValueError('Sealed payload is too large.')
    value = json.loads(raw)
    if not isinstance(value, dict) or value.get('key_id') != expected_id:
        raise ValueError('GitHub encryption key changed or mismatched; prepare and seal again.')
    values = value.get('values')
    if not isinstance(values, dict) or set(values) != NAMES:
        raise ValueError('Only the four approved iOS signing secrets can be imported.')
    for name, encoded in values.items():
        if not isinstance(encoded, str) or len(encoded) > 50000:
            raise ValueError('Invalid sealed input: ' + name)
        binary = base64.b64decode(encoded, validate=True)
        if len(binary) < 49:
            raise ValueError('Invalid sealed input: ' + name)
    return values


def import_secrets():
    check_context()
    key = public_key()
    values = validate_payload(os.environ.get('SEALED_PAYLOAD', ''), key['key_id'])
    for name in sorted(NAMES):
        api('PUT', PREFIX + '/secrets/' + name,
            {'key_id': key['key_id'], 'encrypted_value': values[name]})
        print('Stored private environment secret: ' + name)
    print('Four signing inputs stored. Remove the one-time setup secret and revoke its token after verification.')


if __name__ == '__main__':
    try:
        {'prepare': prepare, 'import': import_secrets}[sys.argv[1]]()
    except Exception as error:
        if isinstance(error, (ApiFailure, ValueError)):
            # Only our operational messages are safe; JSON/base64 errors carry
            # no input text. Never print a traceback or HTTP response body.
            print('::error::' + str(error), file=sys.stderr)
        else:
            print('::error::Signing setup failed; no signing secrets were printed.', file=sys.stderr)
        sys.exit(1)
