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

and the key itself at `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`. Set `ASC_KEY_PATH` to keep the key somewhere else. The key needs the App Manager role.
