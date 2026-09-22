#!/usr/bin/env python3

from pathlib import Path


def configure_ios_firebase():
    project_root = Path(__file__).resolve().parent.parent
    podfile = project_root / "ios" / "Podfile"

    if not podfile.exists():
        raise FileNotFoundError(f"Podfile not found: {podfile}")

    content = podfile.read_text(encoding="utf-8")

    required = [
        "use_frameworks! :linkage => :static",
        "use_modular_headers!",
        "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES",
        "DEFINES_MODULE",
    ]

    for item in required:
        if item not in content:
            raise RuntimeError(f"Missing required Podfile setting: {item}")

    if "__FILE__" not in content:
        raise RuntimeError("Podfile contains an invalid FILE reference.")

    print("iOS Firebase build settings verified successfully.")
    print(f"Podfile: {podfile}")


if __name__ == "__main__":
    configure_ios_firebase()
