#!/usr/bin/env python3

"""Fix legacy Firebase umbrella imports for FlutterFire iOS packages."""

import json
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname


def patch_package(package_root, module):
    classes = package_root / "ios" / "Classes"

    if not classes.is_dir():
        raise RuntimeError(f"Legacy iOS sources not found: {classes}")

    for source in sorted(classes.rglob("*")):
        if source.suffix not in (".h", ".m"):
            continue

        original = source.read_text(encoding="utf-8")
        patched = original

        # Replace:
        # #import <Firebase/Firebase.h>
        #
        # with the specific Firebase module header.
        patched = patched.replace(
            "#import <Firebase/Firebase.h>",
            f"#import <{module}/{module}.h>",
        )

        # Firebase Auth uses FIRAuth types.
        if module == "FirebaseAuth" and "FIRAuth" in patched:
            auth_import = "#import <FirebaseAuth/FirebaseAuth.h>"

            if auth_import not in patched:
                patched = auth_import + "\n\n" + patched

        if patched != original:
            source.write_text(patched, encoding="utf-8")
            print(f"Patched {source}")


def main():
    project_root = Path(__file__).resolve().parents[1]

    config = project_root / ".dart_tool" / "package_config.json"

    if not config.exists():
        raise RuntimeError(
            f"Package configuration not found: {config}"
        )

    data = json.loads(
        config.read_text(encoding="utf-8")
    )

    packages = {
        package["name"]: package
        for package in data["packages"]
    }

    # Your app uses only:
    #   firebase_auth
    #   cloud_firestore
    packages_to_patch = (
        ("firebase_auth", "FirebaseAuth"),
        ("cloud_firestore", "FirebaseFirestore"),
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

        package_root = Path(
            url2pathname(root_uri.path)
        )

        patch_package(
            package_root,
            module,
        )


if __name__ == "__main__":
    main()
