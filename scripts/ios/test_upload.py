import unittest
from upload import accepted


class UploadReceiptTest(unittest.TestCase):
    def test_rejects_zero_exit_validation_failure(self):
        self.assertFalse(accepted(0, 'UPLOAD FAILED with 1 error\nValidation failed (409) Invalid large app icon.'))

    def test_requires_explicit_success_receipt(self):
        self.assertFalse(accepted(0, 'Running altool...'))
        self.assertTrue(accepted(0, 'UPLOAD SUCCEEDED\nDelivery UUID: fictional'))
        self.assertTrue(accepted(0, 'No errors uploading archive.'))
        self.assertFalse(accepted(1, 'UPLOAD SUCCEEDED'))
        self.assertFalse(accepted(0, 'UPLOAD SUCCEEDED\nERROR: rejected'))


class IconFormatTest(unittest.TestCase):
    def test_catalog_icons_have_no_alpha_or_transparency_chunk(self):
        from pathlib import Path
        import struct
        directory = Path(__file__).resolve().parents[2] / 'mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset'
        for icon in directory.glob('*.png'):
            data = icon.read_bytes()
            self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(data[25], 2, icon.name)  # PNG truecolour RGB
            offset = 8
            while offset < len(data):
                size = struct.unpack('>I', data[offset:offset + 4])[0]
                self.assertNotEqual(data[offset + 4:offset + 8], b'tRNS', icon.name)
                offset += size + 12
