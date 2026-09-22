import tempfile
import unittest
from pathlib import Path

from patch_firebase_ios import AUTH_IMPORT, FIREBASE_MODULES, patch_package


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
            self.assertIn("#import <FirebaseCore/FirebaseCore.h>", source.read_text())
            self.assertIn("#import <FirebaseDatabase/FirebaseDatabase.h>", source.read_text())
            self.assertNotIn("FirebaseAuth", source.read_text())

    def test_all_plugins_patch_nested_headers_and_objcpp_without_losing_core(self):
        self.assertEqual(set(FIREBASE_MODULES), {
            "firebase_core", "firebase_auth", "cloud_firestore",
            "firebase_storage", "firebase_database", "firebase_messaging",
        })
        for name, module in FIREBASE_MODULES.items():
            with self.subTest(package=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                sources = []
                for filename in ("Private/Handler.h", "Public/Plugin.h", "Plugin.m", "Parser.mm"):
                    source = root / "ios/Classes" / filename
                    source.parent.mkdir(parents=True, exist_ok=True)
                    source.write_text("#import <Firebase/Firebase.h>\nFIRApp *app;\n")
                    sources.append(source)
                patch_package(root, module)
                for source in sources:
                    patched = source.read_text()
                    self.assertNotIn("Firebase/Firebase.h", patched)
                    self.assertEqual(patched.count("#import <FirebaseCore/FirebaseCore.h>"), 1)
                    self.assertIn(f"#import <{module}/{module}.h>", patched)
                    self.assertIn("FIRApp *app;", patched)
                first = [source.read_bytes() for source in sources]
                patch_package(root, module)
                self.assertEqual(first, [source.read_bytes() for source in sources])

    def test_missing_legacy_sources_are_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            # Modern FlutterFire plugins can omit the legacy ios/Classes tree.
            patch_package(Path(tmp), "FirebaseMessaging")


if __name__ == "__main__":
    unittest.main()
