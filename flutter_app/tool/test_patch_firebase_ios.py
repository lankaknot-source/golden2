import tempfile
import unittest
from pathlib import Path

from patch_firebase_ios import AUTH_IMPORT, patch_package


class FirebaseHeaderPatchTest(unittest.TestCase):
    def test_messaging_keeps_auth_handler_and_is_repeatable(self):
        # Cover a fresh download and the output of the previous CI patch.
        for header_import in (
            "#import <Firebase/Firebase.h>",
            "#import <FirebaseMessaging/FirebaseMessaging.h>",
        ):
            with self.subTest(header_import=header_import), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                classes = root / "ios/Classes"
                classes.mkdir(parents=True)
                header = classes / "FLTFirebaseMessagingPlugin.h"
                source = classes / "FLTFirebaseMessagingPlugin.m"
                header.write_text(header_import + "\n")
                handler = (
                    "#if __has_include(<FirebaseAuth/FirebaseAuth.h>)\n"
                    "  if ([[FIRAuth auth] canHandleNotification:userInfo]) {}\n"
                    "#endif\n"
                )
                source.write_text('#import "FLTFirebaseMessagingPlugin.h"\n' + handler)
                patch_package(root, "FirebaseMessaging")
                patched = source.read_text()
                self.assertIn(AUTH_IMPORT, patched)
                self.assertIn(handler, patched)
                self.assertLess(patched.index(AUTH_IMPORT), patched.index("[FIRAuth auth]"))
                self.assertNotIn("Firebase/Firebase.h", header.read_text())
                self.assertNotIn("FirebaseAuth", header.read_text())
                patch_package(root, "FirebaseMessaging")
                self.assertEqual(source.read_text(), patched)

    def test_database_does_not_gain_auth_dependency(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            classes = root / "ios/Classes"
            classes.mkdir(parents=True)
            source = classes / "FLTFirebaseDatabasePlugin.m"
            source.write_text("#import <Firebase/Firebase.h>\n")
            patch_package(root, "FirebaseDatabase")
            self.assertEqual(source.read_text(), "#import <FirebaseDatabase/FirebaseDatabase.h>\n")

    def test_missing_legacy_sources_fail_early(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError, "Legacy iOS sources not found"):
                patch_package(Path(tmp), "FirebaseMessaging")


if __name__ == "__main__":
    unittest.main()
