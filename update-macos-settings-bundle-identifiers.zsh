#!/usr/bin/env zsh
#
# update-macos-settings-bundle-identifiers.zsh
#
# Gathers known macOS 15 System Settings bundle identifiers from Sidebar.plist,
# plus potential .extension IDs from the System Settings binary.

set -euo pipefail

# Quick OS version check
MAC_VER=$(sw_vers -productVersion | cut -d '.' -f1)
if [[ "$MAC_VER" -lt 15 ]]; then
  echo "This script expects macOS 15 (Sequoia). You appear to be on: $MAC_VER"
  exit 1
fi

SIDEBAR_PLIST="/System/Applications/System Settings.app/Contents/Resources/Sidebar.plist"
SETTINGS_BIN="/System/Applications/System Settings.app/Contents/MacOS/System Settings"

if [[ ! -f "$SIDEBAR_PLIST" ]]; then
  echo "Error: $SIDEBAR_PLIST not found. (Are you on an early beta or different path?)"
  exit 1
fi

if [[ ! -f "$SETTINGS_BIN" ]]; then
  echo "Error: $SETTINGS_BIN not found. (Unexpected path?)"
  exit 1
fi

mkdir -p v15

# Convert the plist to JSON; save for debugging
TMP_JSON="$(mktemp -t sidebar.json.XXXXXX)"
plutil -convert json -o "$TMP_JSON" "$SIDEBAR_PLIST" 2>/dev/null

# Optional: peek at the JSON for troubleshooting
# echo "Debug: printing $TMP_JSON"
# cat "$TMP_JSON"

# Defensive jq query:
# - The top level is an array of objects.
# - Some objects have a 'content' array. We select only those.
# - Then flatten out each 'content' array item if it exists.
set +e
jq_output=$(
  jq -r '[.[]? | select(.content != null) | .content[]?] | unique | .[]' "$TMP_JSON" 2>/dev/null
)
rc=$?
set -e

if [[ $rc -ne 0 || -z "$jq_output" ]]; then
  echo "Warning: The plist did not yield any 'com.apple.*' items. Possibly the structure changed or is empty."
  echo "Output from jq was empty or errored out."
  # If you want to fail the script entirely, uncomment next line
  # exit 1
fi

# Now filter only those that match com.apple. to be safe, then sort
sorted_plist_ids=$(echo "$jq_output" | grep '^com\.apple\.' | sort -u)

# Output official list
echo "$sorted_plist_ids" > v15/macOS_System_Settings_bundle_identifiers.txt

# Next, gather unconfirmed .extension IDs from the System Settings binary
strings "$SETTINGS_BIN" \
  | awk '/^com\.apple\./ {print $1}' \
  | grep '\.extension$' \
  | sort -u \
  | comm -23 - v15/macOS_System_Settings_bundle_identifiers.txt \
  > v15/unconfirmed_preference_panels.txt

echo "Done."
echo "Official list in:      v15/macOS_System_Settings_bundle_identifiers.txt"
echo "Unconfirmed list in:   v15/unconfirmed_preference_panels.txt"