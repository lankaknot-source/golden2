#!/usr/bin/env python3

from pathlib import Path


def configure_ios_firebase():
    """Ensure FlutterFire uses static frameworks."""

    project_root = Path(__file__).resolve().parent.parent
    podfile = project_root / "ios" / "Podfile"

    if not podfile.exists():
        print("ERROR: ios/Podfile was not found.")
        return

    content = podfile.read_text(encoding="utf-8")

    # Remove previous versions of this setting.
    lines = content.splitlines()

    filtered_lines = []
    for line in lines:
        if "use_frameworks!" in line:
            continue
        filtered_lines.append(line)

    content = "\n".join(filtered_lines)

    # Add static framework configuration.
    firebase_settings = """use_frameworks! :linkage => :static
$RNFirebaseAsStaticFramework = true
"""

    content = firebase_settings + "\n" + content.lstrip()

    podfile.write_text(content, encoding="utf-8")

    print("iOS Firebase build settings configured successfully.")
    print("Updated:", podfile)


if __name__ == "__main__":
    configure_ios_firebase()
