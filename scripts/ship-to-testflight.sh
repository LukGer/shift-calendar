#!/usr/bin/env bash
# Archives Shift Alarm, then exports and uploads it to App Store Connect for TestFlight.
#
# Credentials stay on the dev Mac, outside the repo, in ~/.appstoreconnect/shift-alarm.env:
#
#   ASC_KEY_ID=XXXXXXXXXX
#   ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8   # optional, this is the default
#
# Variables already set in the environment win over the file.
set -euo pipefail

cd "$(dirname "$0")/.."

config="${ASC_CONFIG:-$HOME/.appstoreconnect/shift-alarm.env}"
if [[ -f "$config" ]]; then
  # shellcheck source=/dev/null
  source "$config"
fi
: "${ASC_KEY_ID:?set ASC_KEY_ID in $config}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID in $config}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "No API key at $ASC_KEY_PATH" >&2; exit 1; }

build_number="$(date -u +%Y%m%d%H%M)"
archive="build/ShiftAlarm-$build_number.xcarchive"
auth=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

echo "Archiving build $build_number"
xcodebuild archive \
  -project ShiftAlarm.xcodeproj \
  -scheme ShiftAlarm \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  "${auth[@]}" \
  CURRENT_PROJECT_VERSION="$build_number" \
  -quiet

echo "Uploading build $build_number to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "build/export-$build_number" \
  "${auth[@]}"

echo "Uploaded build $build_number. TestFlight shows it once App Store Connect has processed it."
