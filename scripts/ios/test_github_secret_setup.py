import base64
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import github_secret_setup as setup

KEY = {'key_id': 'fictional-key', 'key': base64.b64encode(b'k' * 32).decode()}
CONTEXT = {'GITHUB_REF': 'refs/heads/main', 'GITHUB_REPOSITORY': setup.REPO}
VALUES = {name: base64.b64encode(b'x' * 60).decode() for name in setup.NAMES}


class GithubSetupTest(unittest.TestCase):
    def test_malformed_token_does_not_leak_into_header_errors(self):
        secret = 'fictional-private-token-with-internal\nnewline'
        with patch.dict(os.environ, {'IOS_SIGNING_SETUP_TOKEN': secret}), \
                patch.object(setup.urllib.request, 'urlopen') as request:
            with self.assertRaises(ValueError) as error:
                setup.api('GET', setup.PREFIX)
            request.assert_not_called()
            self.assertNotIn('fictional-private-token', str(error.exception))

    def test_rejects_other_repo_or_branch(self):
        for context in [{**CONTEXT, 'GITHUB_REF': 'refs/heads/other'},
                        {**CONTEXT, 'GITHUB_REPOSITORY': 'other/repo'}]:
            with patch.dict(os.environ, context), self.assertRaises(ValueError):
                setup.check_context()

    def test_payload_rejects_changed_key_and_other_secret_names(self):
        for payload in [{'key_id': 'other-key', 'values': VALUES},
                        {'key_id': KEY['key_id'], 'values': {**VALUES, 'UNRELATED': VALUES[next(iter(VALUES))]}},
                        {'key_id': KEY['key_id'], 'values': {name: 'plaintext' for name in setup.NAMES}}]:
            with self.assertRaises(ValueError):
                setup.validate_payload(json.dumps(payload), KEY['key_id'])
        self.assertEqual(setup.validate_payload(json.dumps({'key_id': KEY['key_id'], 'values': VALUES}), KEY['key_id']), VALUES)

    def test_existing_environment_protections_are_not_changed(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            with patch.dict(os.environ, {**CONTEXT, 'GITHUB_OUTPUT': str(output)}), \
                    patch.object(setup, 'api', side_effect=[{}, KEY]) as api, \
                    contextlib.redirect_stdout(io.StringIO()):
                setup.prepare()
                self.assertTrue(all(call.args[0] == 'GET' for call in api.call_args_list))
            self.assertIn('public_key=', output.read_text())

    def test_new_environment_is_restricted_to_main(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {**CONTEXT, 'GITHUB_OUTPUT': str(Path(directory) / 'out')}), \
                    patch.object(setup, 'api', side_effect=[setup.ApiFailure(404), {}, {}, KEY]) as api, \
                    contextlib.redirect_stdout(io.StringIO()):
                setup.prepare()
                self.assertEqual(api.call_args_list[1].args[2]['deployment_branch_policy'],
                                 {'protected_branches': False, 'custom_branch_policies': True})
                self.assertEqual(api.call_args_list[2].args[2], {'name': 'main', 'type': 'branch'})

    def test_import_writes_only_four_sealed_values(self):
        raw = json.dumps({'key_id': KEY['key_id'], 'values': VALUES})
        with patch.dict(os.environ, {**CONTEXT, 'SEALED_PAYLOAD': raw}), \
                patch.object(setup, 'api', side_effect=[KEY, {}, {}, {}, {}]) as api, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            setup.import_secrets()
        for call in api.call_args_list[1:]:
            self.assertEqual(call.args[0], 'PUT')
            self.assertIn(call.args[1].split('/')[-1], setup.NAMES)
            self.assertEqual(set(call.args[2]), {'key_id', 'encrypted_value'})
        self.assertNotIn(next(iter(VALUES.values())), output.getvalue())

    def test_invalid_payload_cannot_write_any_secret(self):
        with patch.dict(os.environ, {**CONTEXT, 'SEALED_PAYLOAD': '{}'}), \
                patch.object(setup, 'api', return_value=KEY) as api, self.assertRaises(ValueError):
            setup.import_secrets()
        self.assertEqual(api.call_count, 1)

    @unittest.skipUnless(importlib.util.find_spec('nacl'), 'Sealing helper needs requirements-sealing.txt')
    def test_sealed_data_decrypts_only_with_matching_private_key(self):
        from nacl.public import PrivateKey, SealedBox
        from seal_for_github import seal_values
        key = PrivateKey.generate()
        public_key = base64.b64encode(bytes(key.public_key)).decode()
        values = {name: ('fictional-private-' + name).encode() for name in setup.NAMES}
        payload = seal_values(values, public_key, KEY['key_id'])
        setup.validate_payload(json.dumps(payload), KEY['key_id'])
        for name, encrypted in payload['values'].items():
            self.assertEqual(SealedBox(key).decrypt(base64.b64decode(encrypted)), values[name])
            self.assertNotIn(values[name].decode(), json.dumps(payload))
            with self.assertRaises(Exception):
                SealedBox(PrivateKey.generate()).decrypt(base64.b64decode(encrypted))


if __name__ == '__main__':
    unittest.main()
