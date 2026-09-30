# Build 37 review follow-up

## Sign in with Apple

The iOS login screen now offers Apple alongside Google, using Firebase's native
Apple provider. New accounts retain the email returned by Apple, including Hide
My Email relay addresses. Existing profiles are preserved.

Before producing the signed release:

1. Enable Sign in with Apple for `com.kina.goldenHandCare` in Apple Developer.
2. Enable the Apple provider in Firebase Authentication and complete its required
   configuration. Configure Apple's private email relay for Firebase email
   senders if sending authentication emails to relay addresses.
3. Regenerate the distribution provisioning profile with Sign in with Apple,
   then make sure Codemagic uses that profile. Runner now includes the entitlement
   in Debug, Profile and Release configurations.
4. On a physical iPhone/iPad, test first-time sign-in with Hide My Email, sign-out,
   returning sign-in and cancellation. Confirm an existing account is preserved.

## Live Tracking

The home shortcut previously read `bookings/active`, which is not a real booking
ID, then force-unwrapped the missing document. It now opens a session selector,
shows an empty state when no session is assigned, and navigates using a real ID.
Missing booking documents and live-location stream errors have recoverable UI.

Before resubmission, test a fresh install on iPad: no bookings, accepted booking,
active booking with a caregiver publishing location, network interruption and
retry, and leaving the map while updates arrive. Confirm the release Google Maps
key has Maps SDK for iOS enabled and permits `com.kina.goldenHandCare`.

Use a build number higher than the latest uploaded build (reviewed build was 37).
Provide the reviewer a working test account and the steps to an active session.
The screenshot and App Privacy rejection issues remain separate required fixes.

Native signing, Apple/Firebase console settings and physical iPad behavior cannot
be verified from the Windows development environment.
