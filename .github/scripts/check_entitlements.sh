#!/usr/bin/env bash
# Fails unless the app and widget extension inside the given bundle
# directory are signed with the shared App Group entitlement. Without it
# the widget can't read the app's countdowns.
set -euo pipefail

root="$1"
group="group.com.exaltedpixels.Hasta"
app="$root/Hasta.app"
widget="$app/PlugIns/HastaWidgets.appex"

for bundle in "$app" "$widget"; do
  if [ ! -d "$bundle" ]; then
    echo "::error::Missing bundle $bundle"
    exit 1
  fi
  entitlements=$(codesign -d --entitlements - --xml "$bundle" 2>/dev/null || true)
  if ! grep -q "$group" <<<"$entitlements"; then
    echo "::error::$(basename "$bundle") is not signed with the $group App Group."
    codesign -d --entitlements - "$bundle" || true
    exit 1
  fi
  echo "$(basename "$bundle"): App Group present"
done
