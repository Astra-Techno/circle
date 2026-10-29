"""Portable checks; native signing and Xcode are exercised only on macOS."""
import copy
import datetime as dt
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('signing', Path(__file__).with_name('signing.py'))
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class SigningValidationTest(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 10, 29, tzinfo=dt.timezone.utc)
        self.profile = {
            'TeamIdentifier': ['ABCDE12345'],
            'UUID': '11111111-2222-3333-4444-555555555555',
            'ExpirationDate': dt.datetime(2027, 1, 1),
            'Entitlements': {
                'application-identifier': 'ABCDE12345.com.circlecommunity.mobile',
                'get-task-allow': False,
            },
        }

    def test_matching_app_store_profile(self):
        signing.profile_checks(self.profile, 'ABCDE12345', self.now)

    def test_rejects_other_team_bundle_expiry_and_profile_types(self):
        for change in [
            {'TeamIdentifier': ['OTHER12345']},
            {'ExpirationDate': dt.datetime(2026, 1, 1)},
            {'ExpirationDate': None},
            {'ProvisionedDevices': ['fictional-device']},
            {'ProvisionsAllDevices': True},
            {'UUID': '../../unexpected'},
            {'Entitlements': {'application-identifier': 'ABCDE12345.other.app', 'get-task-allow': False}},
            {'Entitlements': {'application-identifier': 'ABCDE12345.com.circlecommunity.mobile', 'get-task-allow': True}},
        ]:
            with self.subTest(change=list(change)):
                profile = copy.deepcopy(self.profile)
                profile.update(change)
                with self.assertRaises(ValueError):
                    signing.profile_checks(profile, 'ABCDE12345', self.now)

    def test_missing_secrets_reports_names_only(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, 'IOS_CERTIFICATE_BASE64'):
                signing.preflight()

    def test_decode_is_private_and_does_not_log_source(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'private.p8'
            with patch.dict(os.environ, {'FICTIONAL_KEY': ' cHJpdmF0ZQ==\n'}):
                signing.decode('FICTIONAL_KEY', destination)
            self.assertEqual(destination.read_bytes(), b'private')
            self.assertEqual(destination.stat().st_mode & 0o777, 0o600)
            with patch.dict(os.environ, {'FICTIONAL_KEY': 'not-base64-secret'}):
                with self.assertRaises(ValueError) as raised:
                    signing.decode('FICTIONAL_KEY', destination)
                self.assertNotIn('not-base64-secret', str(raised.exception))

    def test_api_key_accepts_raw_p8_text_or_existing_base64_without_logging_it(self):
        import base64
        pem = '-----BEGIN PRIVATE KEY-----\nfictional-not-a-real-key\n-----END PRIVATE KEY-----'
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'AuthKey.p8'
            for env in [{'ASC_PRIVATE_KEY': pem},
                        {'ASC_PRIVATE_KEY_BASE64': base64.b64encode(pem.encode()).decode()}]:
                with patch.dict(os.environ, env, clear=True):
                    signing.write_api_key(destination)
                self.assertEqual(destination.read_text().strip(), pem)
                self.assertEqual(destination.stat().st_mode & 0o777, 0o600)
            with patch.dict(os.environ, {'ASC_PRIVATE_KEY': 'fictional-secret-invalid-key'}, clear=True):
                with self.assertRaises(ValueError) as raised:
                    signing.write_api_key(destination)
                self.assertNotIn('fictional-secret-invalid-key', str(raised.exception))

    def test_signed_preflight_rejects_non_main(self):
        env = {key: 'fictional-secret' for key in signing.REQUIRED}
        env.update(ASC_PRIVATE_KEY='fictional-present-key', IOS_TEAM_ID='ABCDE12345', ASC_KEY_ID='ABCDE12345',
                   ASC_ISSUER_ID='11111111-2222-3333-4444-555555555555',
                   GITHUB_REF='refs/heads/other')
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaisesRegex(ValueError, 'main'):
                signing.preflight()
            os.environ['GITHUB_REF'] = 'refs/heads/main'
            signing.preflight()


if __name__ == '__main__':
    unittest.main()
