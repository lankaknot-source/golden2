"""Check iOS inputs before spending time on a native build. No extra packages."""

import json
import plistlib
import re
from pathlib import Path
from xml.etree import ElementTree


def check_project(app):
    ios = app / "ios"
    with (ios / "Runner/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    with (ios / "Runner/GoogleService-Info.plist").open("rb") as handle:
        firebase = plistlib.load(handle)
    with (ios / "Flutter/AppFrameworkInfo.plist").open("rb") as handle:
        framework = plistlib.load(handle)
    project = (ios / "Runner.xcodeproj/project.pbxproj").read_text()
    bundle_ids = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", project)
    app_ids = {value.strip('"') for value in bundle_ids if not value.endswith(".RunnerTests")}
    if app_ids != {firebase["BUNDLE_ID"]}:
        raise ValueError(
            f"Runner bundle IDs {app_ids} do not match Firebase BUNDLE_ID "
            f"{firebase['BUNDLE_ID']}. Supply the Firebase iOS configuration "
            "registered for the signing bundle ID; do not edit BUNDLE_ID alone."
        )
    if info.get("GIDClientID") != firebase.get("CLIENT_ID"):
        raise ValueError("Google Sign-In client ID does not match Firebase iOS configuration")
    schemes = [scheme for item in info.get("CFBundleURLTypes", [])
               for scheme in item.get("CFBundleURLSchemes", [])]
    if firebase.get("REVERSED_CLIENT_ID") not in schemes:
        raise ValueError("Google Sign-In callback URL scheme is missing")
    targets = set(re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);", project))
    if targets != {"15.0"} or framework["MinimumOSVersion"] != "15.0":
        raise ValueError("Runner and Flutter framework must target iOS 15.0")
    if "platform :ios, '15.0'" not in (ios / "Podfile").read_text():
        raise ValueError("CocoaPods minimum iOS version must match Runner")
    ElementTree.parse(ios / "Runner.xcworkspace/contents.xcworkspacedata")
    ElementTree.parse(ios / "Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme")
    for storyboard in (ios / "Runner/Base.lproj").glob("*.storyboard"):
        ElementTree.parse(storyboard)
    for catalog in (ios / "Runner/Assets.xcassets").rglob("Contents.json"):
        for image in json.loads(catalog.read_text()).get("images", []):
            if "filename" in image and not (catalog.parent / image["filename"]).is_file():
                raise ValueError(f"Missing iOS image: {image['filename']}")
    brand_images = (
        app / "assets/brand_logo.jpeg",
        app / "assets/images/logo.png",
        app / "assets/icon/app_icon.png",
    )
    if not any(path.is_file() for path in brand_images):
        raise ValueError("Missing Flutter brand image")
    print("iOS configuration, Firebase identity, workspace, and assets are valid.")


if __name__ == "__main__":
    check_project(Path(__file__).resolve().parents[1])
