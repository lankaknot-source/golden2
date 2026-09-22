#!/usr/bin/env python3

"""Replace legacy Firebase umbrella imports in selected FlutterFire iOS packages."""

import json
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname


AUTH_IMPORT = """#if __has_include(<FirebaseAuth/FirebaseAuth.h>)
#import <FirebaseAuth/FirebaseAuth.h>
#endif
"""


def patch_package(package_root, module):
    classes = package_root / "ios" / "Classes"

    if not classes.is_dir():
        raise RuntimeError(f"Legacy iOS sources not found: {classes}")

    for source in sorted(classes.rglob("*")):
        if source.suffix not in (".h", ".m"):
            continue

        original = source.read_text(encoding="utf-8")
        patched = original

        # Replace Firebase umbrella header.
        patched = patched.replace(
            "#import <Firebase/Firebase.h>",
            f"#import <{module}/{module}.h>",
        )

        # firebase_auth may reference FIRAuth types from headers.
        if module == "FirebaseAuth":
            if "FIRAuth" in patched and "#import <FirebaseAuth/FirebaseAuth.h>" not in patched:
                patched = (
                    "#import <FirebaseAuth/FirebaseAuth.h>\n\n"
                    + patched
                )

        # firebase_messaging optional Auth notification handler.
        if source.name == "FLTFirebaseMessagingPlugin.m":
            if "#import <FirebaseAuth/FirebaseAuth.h>" not in patched:
                anchor = '#import "FLTFirebaseMessagingPlugin.h"\n'

                if anchor not in patched:
                    raise RuntimeError(
                        f"Messaging import anchor missing: {source}"
                    )

                patched = patched.replace(
                    anchor,
                    anchor + "\n" + AUTH_IMPORT,
                    1,
                )

        if patched != original:
            source.write_text(patched, encoding="utf-8")
            print(f"Patched {source}")


def main():
    # Only patch the package versions selected by flutter pub get.
    config = (
        Path(__file__).resolve().parents[1]
        / ".dart_tool"
        / "package_config.json"
    )

    if not config.exists():
        raise RuntimeError(f"Package configuration not found: {config}")

    packages = {
        p["name"]: p
        for p in json.loads(config.read_text(encoding="utf-8"))["packages"]
    }

    packages_to_patch = (
        ("firebase_auth", "FirebaseAuth"),
        ("firebase_database", "FirebaseDatabase"),
        ("firebase_messaging", "FirebaseMessaging"),
    )

    for name, module in packages_to_patch:
        if name not in packages:
            print(f"Skipping {name}: package not found.")
            continue

        root_uri = urlparse(
            urljoin(
                config.as_uri(),
                packages[name]["rootUri"],
            )
        )

        if root_uri.scheme != "file" or root_uri.netloc:
            raise RuntimeError(
                f"Unsupported package URI: {root_uri.geturl()}"
            )

        patch_package(
            Path(url2pathname(root_uri.path)),
            module,
        )


if __name__ == "__main__":
    main()
