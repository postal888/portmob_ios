#!/usr/bin/env bash
# Full iOS build on Mac — same flow as Android (build web → cap sync → Xcode).
# Run from Port_mob/ios after cloning portmob_ios into Port_mob/ios.
set -euo pipefail

IOS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$IOS_DIR/.." && pwd)"

if [[ ! -f "$ROOT/package.json" ]]; then
  echo "Error: Port_mob not found at $ROOT"
  echo "  git clone https://github.com/postal888/Port_mob.git"
  echo "  cd Port_mob && git clone https://github.com/postal888/portmob_ios.git ios"
  exit 1
fi

echo "==> npm ci (Port_mob)"
cd "$ROOT"
npm ci

echo "==> web build"
npm run build

echo "==> cap sync ios"
npx cap sync ios
node "$IOS_DIR/scripts/ios-prepare.mjs"

echo "==> CocoaPods"
cd "$IOS_DIR/App"
pod install

echo ""
echo "Done. Opening Xcode..."
cd "$ROOT"
npx cap open ios
echo ""
echo "In Xcode: Signing & Capabilities → Team, then Product → Run (⌘R) or Archive."
