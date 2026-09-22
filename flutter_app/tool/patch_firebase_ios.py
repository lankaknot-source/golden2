"""Replace legacy Firebase umbrella imports without losing optional Auth support."""

import json
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname

FIREBASE_MODULES = {
    "firebase_core": "FirebaseCore",
    "firebase_auth": "FirebaseAuth",
    "cloud_firestore": "FirebaseFirestore",
    "firebase_storage": "FirebaseStorage",
    "firebase_database": "FirebaseDatabase",
    "firebase_messaging": "FirebaseMessaging",
}

# These are the Firebase plugins that this application currently uses.  The
# remaining entries are optional because older lockfiles or transitive plugins
# can leave them out of package_config.json.
REQUIRED_FIREBASE_PLUGINS = {
    "firebase_core",
    "firebase_auth",
    "cloud_firestore",
}


AUTH_IMPORT = """#if __has_include(<FirebaseAuth/FirebaseAuth.h>)
#import <FirebaseAuth/FirebaseAuth.h>
#endif
"""


def patch_package(package_root, module):
    classes = package_root / "ios" / "Classes"
    if not classes.is_dir():
        # Newer FlutterFire plugins may not ship legacy Objective-C sources
        # under ios/Classes. There is nothing to rewrite in that case.
        print(f"Skipping Firebase plugin without legacy iOS sources: {classes}")
        return

    for source in sorted(classes.rglob("*")):
        if source.suffix not in (".h", ".m", ".mm"):
            continue
        original = source.read_text(encoding="utf-8")
        # Plugins also use FIRApp/FIROptions from Core. Keep those declarations
        # when replacing the non-modular Firebase umbrella with module headers.
        imports = "#import <FirebaseCore/FirebaseCore.h>"
        if module != "FirebaseCore":
            imports += f"\n#import <{module}/{module}.h>"
        patched = original.replace(
            "#import <Firebase/Firebase.h>",
            imports,
        )
        if source.name == "FLTFirebaseMessagingPlugin.m":
            # The optional phone-auth notification handler still uses FIRAuth.
            # Import it in the implementation, not the public framework header.
            if "#import <FirebaseAuth/FirebaseAuth.h>" not in patched:
                anchor = '#import "FLTFirebaseMessagingPlugin.h"\n'
                if anchor not in patched:
                    raise RuntimeError(f"Messaging import anchor missing: {source}")
                patched = patched.replace(anchor, anchor + "\n" + AUTH_IMPORT, 1)
        if patched != original:
            source.write_text(patched, encoding="utf-8")
            print(f"Patched {source}")


def main():
    # Patch only the versions selected by flutter pub get, including PUB_CACHE
    # overrides, rather than every historical package in the global cache.
    config = Path(__file__).resolve().parents[1] / ".dart_tool/package_config.json"
    packages = {p["name"]: p for p in json.loads(config.read_text())["packages"]}
    for name, module in FIREBASE_MODULES.items():
        package = packages.get(name)
        if package is None:
            if name in REQUIRED_FIREBASE_PLUGINS:
                raise RuntimeError(
                    f"Required Firebase plugin {name!r} is missing from package_config.json. "
                    "Run flutter pub get before patching."
                )
            print(f"Skipping optional Firebase plugin {name}: not in package_config.json")
            continue
        root_uri = urlparse(urljoin(config.as_uri(), package["rootUri"]))
        if root_uri.scheme != "file" or root_uri.netloc:
            raise RuntimeError(f"Unsupported package URI: {root_uri.geturl()}")
        patch_package(Path(url2pathname(root_uri.path)), module)


if __name__ == "__main__":
    main()
