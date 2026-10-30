# Shift Alarm

An iOS 26 iPhone app that keeps alarms armed for the Shifts in her calendar. See [GLOSSARY.md](GLOSSARY.md) for the domain language.

## Build and test

Needs Xcode 26 or later. Open `ShiftAlarm.xcodeproj` and press Run, or run the tests from the command line:

```sh
xcodebuild test -project ShiftAlarm.xcodeproj -scheme ShiftAlarm \
  -destination 'platform=iOS Simulator,name=<any iPhone simulator>'
```

## Ship a build to TestFlight

```sh
scripts/ship-to-testflight.sh
```

It archives the app, then exports and uploads it to App Store Connect. The build number is the current UTC time (`yyyyMMddHHmm`), so repeated uploads never collide. Once App Store Connect finishes processing (usually a few minutes), the build reaches the internal TestFlight group "Testing".

It signs and uploads with an App Store Connect API key that lives on the dev Mac, never in the repo. Put this in `~/.appstoreconnect/shift-alarm.env`:

```sh
ASC_KEY_ID=XXXXXXXXXX
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

and the key itself at `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`. Set `ASC_KEY_PATH` to keep the key somewhere else.

The upload is signed manually, because the API key has no access to cloud-managed distribution certificates. The dev Mac needs:

- the "Apple Distribution: Lukas Gerhold" certificate with its private key in the login keychain
- the App Store provisioning profile "Shift Alarm App Store" for `dev.lukger.shiftalarm` in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`

Both expire on 2027-10-30. To renew them, create a new distribution certificate and a new App Store profile with the same name under Certificates, Identifiers & Profiles. Then install both on the Mac.
