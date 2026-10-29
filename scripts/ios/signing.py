#!/usr/bin/env python3
"""Private, ephemeral signing for the manual macOS TestFlight workflow."""
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import zipfile

BUNDLE = 'com.circlecommunity.mobile'
REQUIRED = ('IOS_TEAM_ID', 'IOS_CERTIFICATE_BASE64', 'IOS_CERTIFICATE_PASSWORD',
            'IOS_PROFILE_BASE64', 'ASC_KEY_ID', 'ASC_ISSUER_ID')


def run(*args, data=None):
    # Never print commands: signing commands contain private keychain passwords.
    return subprocess.run(args, input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=True).stdout


def preflight():
    missing = [name for name in REQUIRED if not os.environ.get(name)]
    if not os.environ.get('ASC_PRIVATE_KEY') and not os.environ.get('ASC_PRIVATE_KEY_BASE64'):
        missing.append('ASC_PRIVATE_KEY (P8 text) or ASC_PRIVATE_KEY_BASE64')
    if missing:
        raise ValueError('Add these secrets in the ios-testflight GitHub environment: '
                         + ', '.join(missing))
    for name in ('IOS_TEAM_ID', 'ASC_KEY_ID'):
        if not re.fullmatch(r'[A-Z0-9]{10}', os.environ[name]):
            raise ValueError(name + ' must be the 10-character Apple identifier.')
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', os.environ['ASC_ISSUER_ID']):
        raise ValueError('ASC_ISSUER_ID must be the App Store Connect issuer UUID.')
    if os.environ.get('GITHUB_REF') != 'refs/heads/main':
        raise ValueError('Signed uploads must run from main.')


def profile_checks(profile, team, now):
    entitlements = profile.get('Entitlements', {})
    if profile.get('TeamIdentifier') != [team]:
        raise ValueError('Provisioning profile belongs to a different Apple team.')
    if entitlements.get('application-identifier') != f'{team}.{BUNDLE}':
        raise ValueError('Use an explicit App Store profile for ' + BUNDLE)
    expires = profile.get('ExpirationDate')
    if not isinstance(expires, dt.datetime) or expires.replace(tzinfo=dt.timezone.utc) <= now:
        raise ValueError('Provisioning profile has expired or has no expiration date.')
    if (profile.get('ProvisionedDevices') is not None or
            profile.get('ProvisionsAllDevices') or entitlements.get('get-task-allow') is not False):
        raise ValueError('Use an App Store Connect distribution profile, not development/ad hoc/enterprise.')
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', profile.get('UUID', '')):
        raise ValueError('Provisioning profile UUID is invalid.')


def paths():
    temp = Path(os.environ['RUNNER_TEMP'])
    return temp / 'circle-ios', temp / 'circle-ios-original-keychains.json'


def decode(name, destination):
    try:
        value = base64.b64decode(''.join(os.environ[name].split()), validate=True)
    except ValueError:
        raise ValueError(name + ' is not valid base64.') from None
    if not value:
        raise ValueError(name + ' is empty.')
    destination.write_bytes(value)
    destination.chmod(0o600)


def write_api_key(destination):
    # Phone users can paste the Apple-downloaded P8 text directly into GitHub,
    # without an online base64 converter or sharing the key in chat.
    raw = os.environ.get('ASC_PRIVATE_KEY', '').strip()
    if raw:
        destination.write_text(raw.replace('\r\n', '\n') + '\n')
        destination.chmod(0o600)
    else:
        decode('ASC_PRIVATE_KEY_BASE64', destination)
    text = destination.read_text().strip()
    if not text.startswith('-----BEGIN PRIVATE KEY-----') or not text.endswith('-----END PRIVATE KEY-----'):
        raise ValueError('App Store API key must contain the complete P8 private-key text.')


def prepare():
    preflight()
    root, original = paths()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    root.chmod(0o700)
    decode('IOS_CERTIFICATE_BASE64', root / 'certificate.p12')
    decode('IOS_PROFILE_BASE64', root / 'profile.mobileprovision')
    api_key_path = root / f"AuthKey_{os.environ['ASC_KEY_ID']}.p8"
    write_api_key(api_key_path)
    run('openssl', 'pkey', '-in', str(api_key_path), '-check', '-noout')
    profile = plistlib.loads(run('security', 'cms', '-D', '-i', str(root / 'profile.mobileprovision')))
    team = os.environ['IOS_TEAM_ID']
    profile_checks(profile, team, dt.datetime.now(dt.timezone.utc))
    # Check the P12's public certificate belongs to this exact profile.
    pem = run('openssl', 'pkcs12', '-in', str(root / 'certificate.p12'),
              '-clcerts', '-nokeys', '-passin', 'env:IOS_CERTIFICATE_PASSWORD')
    cert = run('openssl', 'x509', '-outform', 'DER', data=pem)
    run('openssl', 'x509', '-checkend', '0', '-noout', data=pem)
    if cert not in profile.get('DeveloperCertificates', []):
        raise ValueError('Certificate does not match this provisioning profile.')
    fingerprint = hashlib.sha1(cert).hexdigest().upper()
    keychain = str(root / 'signing.keychain-db')
    original.write_text(json.dumps(shlex.split(run('security', 'list-keychains', '-d', 'user').decode())))
    original.chmod(0o600)
    password = secrets.token_urlsafe(32)
    run('security', 'create-keychain', '-p', password, keychain)
    run('security', 'set-keychain-settings', '-lut', '21600', keychain)
    run('security', 'unlock-keychain', '-p', password, keychain)
    run('security', 'import', str(root / 'certificate.p12'), '-k', keychain,
        '-P', os.environ['IOS_CERTIFICATE_PASSWORD'], '-T', '/usr/bin/codesign', '-T', '/usr/bin/security')
    run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-s', '-k', password, keychain)
    run('security', 'list-keychains', '-d', 'user', '-s', keychain, *json.loads(original.read_text()))
    identities = run('security', 'find-identity', '-v', '-p', 'codesigning', keychain).decode()
    if fingerprint not in identities or 'Apple Distribution' not in identities:
        raise ValueError('P12 must include a valid Apple Distribution certificate and its private key.')
    for directory in profile_directories():
        directory.mkdir(parents=True, exist_ok=True)
        destination = directory / (profile['UUID'] + '.mobileprovision')
        if destination.exists():
            raise ValueError('Profile unexpectedly already installed; refusing to replace it.')
        shutil.copyfile(root / 'profile.mobileprovision', destination)
    (root / 'profile.json').write_text(json.dumps({'uuid': profile['UUID'], 'team': team}))
    export = {'method': 'app-store-connect', 'destination': 'export',
              'teamID': team, 'signingStyle': 'manual', 'signingCertificate': fingerprint,
              'provisioningProfiles': {BUNDLE: profile['UUID']},
              'manageAppVersionAndBuildNumber': False, 'uploadSymbols': True}
    (root / 'ExportOptions.plist').write_bytes(plistlib.dumps(export))
    # Modify only the three Runner configurations in this ephemeral checkout.
    project = Path('ios/Runner.xcodeproj/project.pbxproj')
    source = project.read_text()
    marker = 'INFOPLIST_FILE = Runner/Info.plist;'
    if source.count(marker) != 3:
        raise ValueError('Runner configuration changed; review signing injection before continuing.')
    settings = (f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};'
                '\n\t\t\t\tCODE_SIGN_STYLE = Manual;'
                '\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";'
                f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile["UUID"]}";')
    project.write_text(source.replace(marker, marker + settings))
    print('Apple Distribution identity and matching App Store profile imported.')


def profile_directories():
    return (Path.home() / 'Library/MobileDevice/Provisioning Profiles',
            Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles')


def verify():
    root, _ = paths()
    ipas = list(Path('build/ios/ipa').glob('*.ipa'))
    if len(ipas) != 1:
        raise ValueError('Expected exactly one exported IPA.')
    verification = root / 'verify'
    verification.mkdir()
    with zipfile.ZipFile(ipas[0]) as archive:
        for entry in archive.infolist():
            if not (verification / entry.filename).resolve().is_relative_to(verification.resolve()):
                raise ValueError('Invalid IPA archive path.')
    # ditto preserves executable bits and framework symlinks on macOS.
    run('ditto', '-x', '-k', str(ipas[0]), str(verification))
    apps = list((verification / 'Payload').glob('*.app'))
    if len(apps) != 1:
        raise ValueError('Expected exactly one iPhone app.')
    app = apps[0]
    run('codesign', '--verify', '--deep', '--strict', str(app))
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE:
        raise ValueError('Exported IPA has the wrong bundle ID.')
    expected = f"{1000 + int(os.environ['GITHUB_RUN_NUMBER'])}.{os.environ['GITHUB_RUN_ATTEMPT']}"
    if info.get('CFBundleVersion') != expected:
        raise ValueError('Exported IPA has the wrong build number.')
    embedded = plistlib.loads(run('security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')))
    profile_checks(embedded, os.environ['IOS_TEAM_ID'], dt.datetime.now(dt.timezone.utc))
    if embedded['UUID'] != json.loads((root / 'profile.json').read_text())['uuid']:
        raise ValueError('Exported IPA has an unexpected provisioning profile.')
    entitlements = plistlib.loads(run('codesign', '-d', '--entitlements', ':-', str(app)))
    if (entitlements.get('application-identifier') != f"{os.environ['IOS_TEAM_ID']}.{BUNDLE}" or
            entitlements.get('get-task-allow', False) or
            entitlements.get('keychain-access-groups') != [f"{os.environ['IOS_TEAM_ID']}.{BUNDLE}"]):
        raise ValueError('Exported IPA signing entitlements are invalid.')
    sha = hashlib.sha256(ipas[0].read_bytes()).hexdigest()
    (ipas[0].parent / 'SHA256SUMS.txt').write_text(f'{sha}  {ipas[0].name}\n')
    print(f'Verified signed IPA: version {info["CFBundleShortVersionString"]}, build {expected}.')


def cleanup():
    root, original = paths()
    if original.exists():
        run('security', 'list-keychains', '-d', 'user', '-s', *json.loads(original.read_text()))
        original.unlink()
    keychain = root / 'signing.keychain-db'
    if keychain.exists():
        run('security', 'delete-keychain', str(keychain))
    record = root / 'profile.json'
    if record.exists():
        uuid = json.loads(record.read_text())['uuid']
        for directory in profile_directories():
            (directory / (uuid + '.mobileprovision')).unlink(missing_ok=True)
    shutil.rmtree(root, ignore_errors=True)


if __name__ == '__main__':
    try:
        {'preflight': preflight, 'prepare': prepare, 'verify': verify, 'cleanup': cleanup}[sys.argv[1]]()
    except subprocess.CalledProcessError as error:
        # Do not expose argv, output, key material or passwords in CI failures.
        print(f'::error::{error.cmd[0]} failed (exit {error.returncode}). Check the signing/profile setup.', file=sys.stderr)
        sys.exit(1)
    except (ValueError, KeyError) as error:
        print(f'::error::{error}', file=sys.stderr)
        sys.exit(1)
