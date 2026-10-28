#!/bin/sh
# PROTOTYPE: captures every variant × screen into screenshots/. Run ./run.sh once first to build and install.
set -eu
cd "$(dirname "$0")"
DEVICE=$(xcrun simctl list devices available | grep -m1 "${DEVICE_NAME:-iPhone}" | grep -oE "[0-9A-F-]{36}") || { echo "no available iPhone simulator" >&2; exit 1; }
mkdir -p screenshots
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryLevel 100 --cellularBars 4
for variant in A B C D; do
  for screen in onboarding home types editor; do
    xcrun simctl launch --terminate-running-process "$DEVICE" dev.prototype.shiftcalendar \
      -variant "$variant" -screen "$screen" -page 1 -hideSwitcher YES >/dev/null
    sleep 2
    xcrun simctl io "$DEVICE" screenshot "screenshots/$variant-$screen.png" >/dev/null 2>&1
  done
done
