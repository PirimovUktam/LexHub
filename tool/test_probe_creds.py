"""2026-09-20: secret references fail closed; synthetic tests, not live rotation proof."""
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys
sys.path.insert(0, str(Path(__file__).parent))
import probe_creds

class ProbeCredentialsTest(unittest.TestCase):
    def load(self, config, environment=None, value='synthetic-fixture'):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / 'probe.json'
            file.write_text(json.dumps(config), encoding='utf-8')
            with patch.dict(os.environ, environment or {}, clear=True), patch.object(probe_creds, 'CREDS_PATH', str(file)), patch.object(probe_creds, '_stored_password', return_value=value) as read:
                result = probe_creds.probe_credentials()
                return result, read.call_args

    def test_reference_resolves_without_plaintext_password(self):
        result, call = self.load({'PROBE_EMAIL':'synthetic@example.invalid','PROBE_PASSWORD_CREDENTIAL_TARGET':'LexHub:probe:synthetic'})
        self.assertEqual(result, ('synthetic@example.invalid','synthetic-fixture'))
        self.assertEqual(call.args, ('LexHub:probe:synthetic',))

    def test_reference_does_not_fall_back_to_old_password(self):
        with self.assertRaises(SystemExit):
            self.load({'PROBE_EMAIL':'synthetic@example.invalid','PROBE_PASSWORD_CREDENTIAL_TARGET':'LexHub:probe:synthetic','PROBE_PASSWORD':'synthetic-old'},value='')

    def test_explicit_environment_remains_supported(self):
        result, call = self.load({}, {'LEXHUB_PROBE_EMAIL':'synthetic@example.invalid','LEXHUB_PROBE_PASSWORD':'synthetic-env'})
        self.assertEqual(result, ('synthetic@example.invalid','synthetic-env'))
        self.assertIsNone(call)

    def test_invalid_credential_store_target_is_rejected(self):
        with self.assertRaises(SystemExit):
            probe_creds._stored_password('UnrelatedService')

if __name__ == '__main__':
    unittest.main()
