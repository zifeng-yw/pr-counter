#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "build.noindex/PR Counter.app/Contents/Info.plist")
DMG="build.noindex/PR-Counter-$VERSION.dmg"
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "build.noindex/PR Counter.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "PR Counter" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Built $DMG"
