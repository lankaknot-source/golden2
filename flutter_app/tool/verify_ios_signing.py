"""Validate Apple login entitlements in the actual signed IPA, without secrets.

Also selects only suitable App Store profiles before Codemagic applies signing.
Uses the Mach-O code-signature load command, not an arbitrary string scan.
"""
import argparse
import datetime
import plistlib
import struct
import subprocess
import zipfile
from pathlib import Path

BUNDLE = 'com.kina.goldenHandCare'
APPLE = 'com.apple.developer.applesignin'


def profile_data(raw):
    start = raw.find(b'<?xml')
    end = raw.find(b'</plist>', start)
    if start < 0 or end < 0:
        raise ValueError('Provisioning profile has no plist')
    return plistlib.loads(raw[start:end + 8])


def signature_entitlements(binary):
    # An exported iOS app is normally a thin arm64 Mach-O. Support fat archives too.
    magic = binary[:4]
    if magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
        count = struct.unpack_from('>I', binary, 4)[0]
        fat64 = magic[-1] == 0xbf
        for i in range(count):
            base = 8 + i * (32 if fat64 else 20)
            offset, size = struct.unpack_from('>QQ' if fat64 else '>II', binary, base + 8)
            yield from signature_entitlements(binary[offset:offset + size])
        return
    if magic not in (b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe'):
        raise ValueError('Unsupported Mach-O executable')
    count = struct.unpack_from('<I', binary, 16)[0]
    pos = 32 if magic[0] == 0xcf else 28
    for _ in range(count):
        command, size = struct.unpack_from('<II', binary, pos)
        if size < 8 or pos + size > len(binary):
            raise ValueError('Invalid Mach-O load command')
        if command == 0x1d:  # LC_CODE_SIGNATURE
            offset, length = struct.unpack_from('<II', binary, pos + 8)
            blob = binary[offset:offset + length]
            magic, blob_length, entries = struct.unpack_from('>III', blob)
            if magic != 0xfade0cc0 or blob_length > len(blob):
                raise ValueError('Invalid code-signature superblob')
            for i in range(entries):
                slot, start = struct.unpack_from('>II', blob, 12 + i * 8)
                if slot == 5:  # CSSLOT_ENTITLEMENTS
                    kind, length = struct.unpack_from('>II', blob, start)
                    if kind != 0xfade7171 or start + length > len(blob):
                        raise ValueError('Invalid entitlement blob')
                    yield plistlib.loads(blob[start + 8:start + length])
                    return
            raise ValueError('Signed executable has no XML entitlements')
        pos += size
    raise ValueError('Executable is not signed')


def validate_entitlements(entitlements, label):
    if 'Default' not in entitlements.get(APPLE, []):
        raise ValueError(f'{label}: Sign in with Apple is missing. Enable it for {BUNDLE} '
                         'in Apple Developer, regenerate the App Store provisioning profile, '
                         'and replace/refetch the profile in Codemagic.')
    if not entitlements.get('application-identifier', '').endswith('.' + BUNDLE):
        raise ValueError(f'{label}: application identifier does not match {BUNDLE}')


def verify_ipa(path):
    with zipfile.ZipFile(path) as archive:
        roots = [n.rsplit('/', 1)[0] + '/' for n in archive.namelist()
                 if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
        if len(roots) != 1:
            raise ValueError('Expected exactly one top-level app')
        root = roots[0]
        info = plistlib.loads(archive.read(root + 'Info.plist'))
        if info['CFBundleIdentifier'] != BUNDLE:
            raise ValueError('Unexpected app bundle identifier')
        profile = profile_data(archive.read(root + 'embedded.mobileprovision'))
        signed = list(signature_entitlements(archive.read(root + info['CFBundleExecutable'])))
        validate_entitlements(profile['Entitlements'], 'Provisioning profile')
        if not signed:
            raise ValueError('No signed executable architectures found')
        for ent in signed:
            validate_entitlements(ent, 'Signed app')
            if ent['application-identifier'] != profile['Entitlements']['application-identifier']:
                raise ValueError('App and profile application identifiers differ')
            team = profile['Entitlements'].get('com.apple.developer.team-identifier')
            if not team or ent.get('com.apple.developer.team-identifier') != team:
                raise ValueError('App and profile signing teams differ')
        print(f"Verified Apple Sign-In in IPA {info['CFBundleShortVersionString']} "
              f"({info['CFBundleVersion']}) and its provisioning profile.")


def configure_profiles():
    roots = [Path.home() / 'Library/MobileDevice/Provisioning Profiles',
             Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles']
    profiles = []
    for root in roots:
        for path in root.glob('*.mobileprovision'):
            profile = profile_data(path.read_bytes())
            ent = profile.get('Entitlements', {})
            if ent.get('application-identifier', '').endswith('.' + BUNDLE):
                if (not ent.get('get-task-allow') and not profile.get('ProvisionedDevices')
                        and not profile.get('ProvisionsAllDevices')
                        and profile.get('ExpirationDate', datetime.datetime.min) > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
                        and 'Default' in ent.get(APPLE, [])):
                    profiles.append((profile['ExpirationDate'], path))
    if not profiles:
        raise ValueError('No valid App Store profile with Sign in with Apple found. '
                         f'Enable Sign in with Apple for {BUNDLE}, regenerate its profile '
                         'in Apple Developer, then upload/fetch it in Codemagic.')
    # Prefer the latest-expiring compatible profile; never select the old profile.
    path = max(profiles, key=lambda item: item[0])[1]
    entitlement_path = Path('ios/Runner/Runner.entitlements')
    required_entitlements = entitlement_path.read_bytes()
    if 'Default' not in plistlib.loads(required_entitlements).get(APPLE, []):
        raise ValueError('Source entitlements are missing Sign in with Apple')
    subprocess.run(['xcode-project', 'use-profiles', '--project', 'ios/Runner.xcodeproj',
                    '--archive-method', 'app-store', '--profile', str(path)], check=True)
    entitlement_path.write_bytes(required_entitlements)
    # Codemagic can rewrite entitlements while applying profiles. Restore the
    # source requirement so Xcode fails instead of silently dropping Apple login.
    subprocess.run(['ruby', '-rxcodeproj', '-e', '''
p = Xcodeproj::Project.open('ios/Runner.xcodeproj')
p.targets.find { |t| t.name == 'Runner' }.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
p.save
'''], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--configure', action='store_true')
    parser.add_argument('ipas', nargs='*', type=Path)
    args = parser.parse_args()
    try:
        if args.configure:
            configure_profiles()
        elif args.ipas:
            for ipa in args.ipas:
                verify_ipa(ipa)
        else:
            parser.error('Supply IPA paths or --configure')
    except (ValueError, KeyError, struct.error, zipfile.BadZipFile) as error:
        raise SystemExit(f'iOS signing check FAILED: {error}')
