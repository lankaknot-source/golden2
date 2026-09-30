# Release 1.3.10 (39): Apple login and iOS maps

## Findings from the supplied 1.3.9 (38) IPA

- Both the embedded App Store profile and the executable lacked
  `com.apple.developer.applesignin`. This prevents native Apple authorization.
- The source entitlements XML was missing its closing plist tag; this is fixed.
- The map used the Firebase API key. No evidence in an IPA can confirm Google
  Maps SDK enablement, key restrictions or billing. Markers on gray tiles are
  consistent with a basemap loading/configuration failure.

## Changes

- iOS live tracking and service-location selection now use native Apple MapKit.
  They no longer use a Google Maps API key. Android keeps its Google Maps renderer.
  Caregiver updates, destination pins, connecting lines and recenter remain.
- Codemagic selects only an unexpired App Store profile for the correct bundle
  with Sign in with Apple, then restores the source entitlements setting.
- Before upload, the exported IPA is checked for Apple login permission in BOTH
  its profile and signed executable, with matching application and team IDs.
  This is an entitlement check, not cryptographic signature verification.
- Apple login failures retain a non-sensitive Firebase error code for diagnosis.

## Required account setup before building

1. Apple Developer: enable Sign in with Apple for `com.kina.goldenHandCare`.
2. Regenerate its App Store provisioning profile and upload/refetch it in
   Codemagic. The profile bundled in build 38 is not suitable. The next signed
   build intentionally stops with an explanation if no suitable profile exists.
3. Keep Apple enabled in Firebase Authentication. Configure private email relay
   senders if authentication emails are sent to Hide My Email accounts.
4. Build the latest commit with the iOS App Store workflow. The source version is
   1.3.10+39; Codemagic may assign a higher build number.

## Device verification still required

Windows cannot compile or run MapKit/Xcode. Run the native build on Codemagic and
install through TestFlight. Check first/returning Apple login, Hide My Email,
login cancellation, map tiles and pins on iPhone/iPad, tap-to-select a service
location, live movement, recenter, and network failure/retry. Do not re-sign the
IPA with a different profile. Validate regional map availability on the device.

The screenshot and App Privacy rejection issues remain separate required fixes.
