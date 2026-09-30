import plistlib
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_ios_signing import APPLE, BUNDLE, signature_entitlements, verify_ipa


def executable(entitlements):
    xml = plistlib.dumps(entitlements)
    ent = struct.pack('>II', 0xfade7171, 8 + len(xml)) + xml
    blob = struct.pack('>IIIII', 0xfade0cc0, 20 + len(ent), 1, 5, 20) + ent
    header = struct.pack('<IIIIIIII', 0xfeedfacf, 0x100000c, 0, 2, 1, 16, 0, 0)
    return header + struct.pack('<IIII', 0x1d, 16, 48, len(blob)) + blob


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.ent = {APPLE: ['Default'], 'application-identifier': 'TEAM.' + BUNDLE,
                    'com.apple.developer.team-identifier': 'TEAM'}

    def write_ipa(self, path, signed, profile):
        with zipfile.ZipFile(path, 'w') as archive:
            root = 'Payload/Runner.app/'
            archive.writestr(root + 'Info.plist', plistlib.dumps({
                'CFBundleIdentifier': BUNDLE, 'CFBundleExecutable': 'Runner',
                'CFBundleShortVersionString': '1.3.10', 'CFBundleVersion': '39'}))
            archive.writestr(root + 'Runner', executable(signed))
            archive.writestr(root + 'embedded.mobileprovision',
                             b'CMS prefix' + plistlib.dumps({'Entitlements': profile}) + b'CMS suffix')

    def test_valid_signed_app_and_profile(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'app.ipa'
            self.write_ipa(path, self.ent, self.ent)
            verify_ipa(path)

    def test_old_profile_blocks_upload(self):
        profile = dict(self.ent)
        profile.pop(APPLE)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'app.ipa'
            self.write_ipa(path, self.ent, profile)
            with self.assertRaisesRegex(ValueError, 'Provisioning profile: Sign in with Apple is missing'):
                verify_ipa(path)

    def test_dropped_binary_entitlement_blocks_upload(self):
        signed = dict(self.ent)
        signed.pop(APPLE)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'app.ipa'
            self.write_ipa(path, signed, self.ent)
            with self.assertRaisesRegex(ValueError, 'Signed app: Sign in with Apple is missing'):
                verify_ipa(path)

    def test_different_signing_team_is_rejected(self):
        signed = dict(self.ent, **{'com.apple.developer.team-identifier': 'OTHER'})
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'app.ipa'
            self.write_ipa(path, signed, self.ent)
            with self.assertRaisesRegex(ValueError, 'signing teams differ'):
                verify_ipa(path)

    def test_fat_binary_checks_each_architecture(self):
        binary = executable(self.ent)
        fat = struct.pack('>II', 0xcafebabe, 1)
        fat += struct.pack('>IIIII', 0x100000c, 0, 28, len(binary), 0)
        self.assertEqual(list(signature_entitlements(fat + binary)), [self.ent])

    def test_unsigned_binary_rejected(self):
        binary = struct.pack('<IIIIIIII', 0xfeedfacf, 0x100000c, 0, 2, 0, 0, 0, 0)
        with self.assertRaisesRegex(ValueError, 'not signed'):
            list(signature_entitlements(binary))


if __name__ == '__main__':
    unittest.main()
