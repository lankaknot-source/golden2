#!/usr/bin/env python3

from pathlib import Path

PODFILE = Path("ios/Podfile")

NON_MODULAR_SETTING = (
"config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'"
)

DEFINES_MODULE_SETTING = (
"config.build_settings['DEFINES_MODULE'] = 'YES'"
)

def ensure_static_frameworks(text: str) -> str:
"""Ensure FlutterFire uses static frameworks."""

```
# Already correct.
if "use_frameworks! :linkage => :static" in text:
    return text

# Convert plain use_frameworks! to static linkage.
if "use_frameworks!" in text:
    return text.replace(
        "use_frameworks!",
        "use_frameworks! :linkage => :static",
        1,
    )

# If the Podfile does not contain use_frameworks!,
# add it inside Runner target.
marker = "target 'Runner' do"

if marker not in text:
    raise SystemExit(
        "ERROR: Could not locate target 'Runner' in ios/Podfile"
    )

return text.replace(
    marker,
    marker
    + "\n  use_frameworks! :linkage => :static",
    1,
)
```

def ensure_modular_headers(text: str) -> str:
"""Ensure CocoaPods modular headers are enabled."""

```
if "use_modular_headers!" in text:
    return text

marker = "target 'Runner' do"

if marker not in text:
    raise SystemExit(
        "ERROR: Could not locate target 'Runner' in ios/Podfile"
    )

return text.replace(
    marker,
    marker
    + "\n  use_modular_headers!",
    1,
)
```

def ensure_build_settings(text: str) -> str:
"""
Ensure the Firebase/Xcode compatibility settings are present
in the existing post_install block.
"""

```
marker = "post_install do |installer|"

if marker not in text:
    raise SystemExit(
        "ERROR: Could not locate post_install block in ios/Podfile"
    )

# If both settings already exist, nothing needs to be changed.
if (
    NON_MODULAR_SETTING in text
    and DEFINES_MODULE_SETTING in text
):
    return text

flutter_marker = "flutter_additional_ios_build_settings(target)"

if flutter_marker not in text:
    raise SystemExit(
        "ERROR: Could not locate "
        "flutter_additional_ios_build_settings(target) "
        "in ios/Podfile"
    )

settings = """

target.build_configurations.each do |config|
  config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
  config.build_settings['DEFINES_MODULE'] = 'YES'
end
```

"""

```
# No settings exist yet.
if (
    NON_MODULAR_SETTING not in text
    and DEFINES_MODULE_SETTING not in text
):
    return text.replace(
        flutter_marker,
        flutter_marker + settings,
        1,
    )

# Only non-modular setting exists.
if (
    NON_MODULAR_SETTING in text
    and DEFINES_MODULE_SETTING not in text
):
    return text.replace(
        NON_MODULAR_SETTING,
        NON_MODULAR_SETTING
        + "\n      "
        + DEFINES_MODULE_SETTING,
        1,
    )

# Only DEFINES_MODULE exists.
if (
    DEFINES_MODULE_SETTING in text
    and NON_MODULAR_SETTING not in text
):
    return text.replace(
        DEFINES_MODULE_SETTING,
        NON_MODULAR_SETTING
        + "\n      "
        + DEFINES_MODULE_SETTING,
        1,
    )

return text
```

def main():
if not PODFILE.exists():
raise SystemExit(
"ERROR: ios/Podfile not found"
)

```
text = PODFILE.read_text(encoding="utf-8")

# Apply each configuration deterministically.
text = ensure_static_frameworks(text)
text = ensure_modular_headers(text)
text = ensure_build_settings(text)

PODFILE.write_text(
    text,
    encoding="utf-8",
)

print(
    "iOS Firebase/CocoaPods compatibility configuration "
    "applied successfully."
)
```

if **name** == "**main**":
main()
