#!/bin/sh
# PROTOTYPE: builds the throwaway MVP screens app and launches it in the iOS Simulator.
# usage: ./run.sh [-variant A|B|C] [-screen onboarding|home|types|editor] [-page 0-4] [-hideSwitcher YES]
set -eu
cd "$(dirname "$0")"
APP=build/ShiftPrototype.app
DEVICE=$(xcrun simctl list devices available | grep -m1 "${DEVICE_NAME:-iPhone 17 Pro} (" | grep -oE '[0-9A-F-]{36}')

rm -rf build && mkdir -p "$APP"
xcrun -sdk iphonesimulator swiftc -parse-as-library -target arm64-apple-ios26.0-simulator Sources/*.swift -o "$APP/ShiftPrototype"
cp Info.plist "$APP/"
codesign -s - "$APP"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator 2>/dev/null || echo "Simulator.app not found; running headless"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch --terminate-running-process "$DEVICE" dev.prototype.shiftcalendar "$@"
