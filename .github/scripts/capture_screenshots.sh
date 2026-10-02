#!/usr/bin/env bash
# Installs the simulator build of Hasta and captures its main screens in
# light and dark mode, using screenshot launch modes and deep links.
set -euo pipefail

device="$1"
app="$2"
out="${3:-Screenshots}"
bundle="com.exaltedpixels.Hasta"

mkdir -p "$out"
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$device" "$app"

launch() {
  xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
  xcrun simctl launch "$device" "$bundle" -HastaScreenshotMode "$1" >/dev/null
  sleep 4
}

shot() {
  xcrun simctl io "$device" screenshot --type=png "$out/$1.png" >/dev/null
  echo "captured $1"
}

open_url() {
  xcrun simctl openurl "$device" "$1"
  sleep 3
}

for appearance in light dark; do
  xcrun simctl ui "$device" appearance "$appearance"

  launch welcome
  shot "$appearance-01-welcome"

  launch empty
  shot "$appearance-02-empty"

  launch samples
  shot "$appearance-03-home"
  open_url "hasta://countdown/00000000-0000-0000-0000-000000000001"
  shot "$appearance-04-detail"

  launch samples
  open_url "hasta://new"
  shot "$appearance-05-editor"

  launch samples
  open_url "hasta://settings"
  shot "$appearance-06-settings"

  launch samples
  open_url "hasta://premium"
  shot "$appearance-07-premium"
done
