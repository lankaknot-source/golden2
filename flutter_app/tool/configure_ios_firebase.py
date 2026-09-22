#!/usr/bin/env python3
from pathlib import Path

PODFILE = Path("ios/Podfile")

def main():
    if not PODFILE.exists():
        raise SystemExit("ios/Podfile not found")

    text = PODFILE.read_text(encoding="utf-8")

    # Make the Firebase/Xcode compatibility settings deterministic.
    text = text.replace(
        "  use_frameworks!\n  use_modular_headers!",
        "  use_frameworks! :linkage => :static\n  use_modular_headers!"
    )

    marker = "    flutter_additional_ios_build_settings(target)\n"
    setting = (
        "\n"
        "    target.build_configurations.each do |config|\n"
        "      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'\n"
        "      config.build_settings['DEFINES_MODULE'] = 'YES'\n"
        "    end\n"
    )

    if "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES" not in text:
        if marker not in text:
            raise SystemExit("Could not locate flutter_additional_ios_build_settings in ios/Podfile")
        text = text.replace(marker, marker + setting, 1)

    PODFILE.write_text(text, encoding="utf-8")
    print("iOS Firebase/CocoaPods compatibility settings applied.")

if __name__ == "__main__":
    main()
