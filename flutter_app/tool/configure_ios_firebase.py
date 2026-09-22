#!/usr/bin/env python3

from pathlib import Path


def configure_ios_firebase():
    """Configure the iOS Podfile for Firebase static frameworks."""

    project_root = Path(__file__).resolve().parent.parent
    podfile = project_root / "ios" / "Podfile"

    if not podfile.exists():
        raise FileNotFoundError(f"Podfile not found: {podfile}")

    content = podfile.read_text(encoding="utf-8")

    # Remove settings previously inserted by this script.
    lines = content.splitlines()

    filtered = []
    for line in lines:
        stripped = line.strip()

        if stripped.startswith("use_frameworks!"):
            continue

        if stripped == "use_modular_headers!":
            continue

        if "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES" in line:
            continue

        if "DEFINES_MODULE" in line:
            continue

        filtered.append(line)

    content = "\n".join(filtered).rstrip() + "\n"

    firebase_settings = """use_frameworks! :linkage => :static
use_modular_headers!

$firebase_ios_build_settings = {
  'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  'DEFINES_MODULE' => 'YES',
}

"""

    podfile.write_text(
        firebase_settings + content,
        encoding="utf-8",
    )

    print("iOS Firebase build settings configured successfully.")
    print(f"Updated: {podfile}")


if __name__ == "__main__":
    configure_ios_firebase()
