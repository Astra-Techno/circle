#!/usr/bin/env python3
"""Fail closed when altool returns zero despite an Apple validation rejection."""
import os
from pathlib import Path
import re
import subprocess
import sys


def accepted(returncode, output):
    rejected = re.search(r'UPLOAD FAILED|Failed to upload|Validation failed|ERROR:|"errors"\s*:\s*\[\s*\{', output, re.I)
    confirmed = re.search(r'UPLOAD SUCCEEDED|No errors uploading', output, re.I)
    return returncode == 0 and not rejected and bool(confirmed)


def main():
    ipas = list(Path('build/ios/ipa').glob('*.ipa'))
    if len(ipas) != 1:
        raise ValueError('Expected exactly one IPA for upload.')
    env = dict(os.environ, API_PRIVATE_KEYS_DIR=str(Path(os.environ['RUNNER_TEMP']) / 'circle-ios'))
    result = subprocess.run(
        ['xcrun', 'altool', '--upload-app', '--type', 'ios', '--file', str(ipas[0]),
         '--apiKey', os.environ['ASC_KEY_ID'], '--apiIssuer', os.environ['ASC_ISSUER_ID']],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    # Standard Apple delivery output; never print environment or private key files.
    print(result.stdout)
    if not accepted(result.returncode, result.stdout):
        print('::error::Apple upload rejected or success receipt missing. See delivery output above.')
        return 1
    print('Apple upload accepted. TestFlight processing is a separate step.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
