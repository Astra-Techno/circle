"""Validate bundled static font identities without third-party dependencies.

CoreText must not receive three different weights with one PostScript identity.
This checks the actual sfnt tables, not merely filenames or Flutter's manifest.
"""
import hashlib
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]


def font_tables(path):
    data = path.read_bytes()
    count = struct.unpack_from(">H", data, 4)[0]
    tables = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + i * 16)
        tables[tag] = data[offset:offset + length]
    return tables


def font_name(table, name_id):
    _, count, storage = struct.unpack_from(">HHH", table)
    matches = []
    for i in range(count):
        platform, _, language, entry, length, offset = struct.unpack_from(
            ">HHHHHH", table, 6 + i * 12)
        if entry != name_id:
            continue
        value = table[storage + offset:storage + offset + length]
        text = value.decode("utf-16-be" if platform in (0, 3) else "mac_roman")
        matches.append((platform == 3 and language == 0x409, text))
    return max(matches)[1] if matches else None


class FontAssetsTest(unittest.TestCase):
    def test_static_faces_have_unique_correct_native_identities(self):
        identities, outlines = [], []
        for label, weight in [("Regular", 400), ("Medium", 500), ("SemiBold", 600)]:
            with self.subTest(face=label):
                tables = font_tables(ROOT / "mobile/assets/fonts" / f"Inter-{label}.ttf")
                self.assertNotIn(b"fvar", tables)
                self.assertEqual(struct.unpack_from(">H", tables[b"OS/2"], 4)[0], weight)
                identity = font_name(tables[b"name"], 6)
                self.assertEqual(identity, f"Inter-{label}")
                self.assertEqual(font_name(tables[b"name"], 16)
                                 or font_name(tables[b"name"], 1), "Inter")
                identities.append(identity)
                outlines.append(hashlib.sha256(tables[b"glyf"]).hexdigest())
        self.assertEqual(len(set(identities)), 3)
        self.assertEqual(len(set(outlines)), 3)


if __name__ == "__main__":
    unittest.main()
