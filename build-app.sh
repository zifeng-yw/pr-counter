#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
APP="build.noindex/PR Counter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/PRCounter" "$APP/Contents/MacOS/PRCounter"
ICON_BUILD_DIR=$(mktemp -d)
xcrun actool Resources/AppIcon.icon \
  --compile "$APP/Contents/Resources" \
  --app-icon AppIcon \
  --platform macosx \
  --target-device mac \
  --minimum-deployment-target 15.0 \
  --output-partial-info-plist "$ICON_BUILD_DIR/partial.plist" >/dev/null
rm -rf "$ICON_BUILD_DIR"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>PRCounter</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>com.zifeng.prcounter</string>
  <key>CFBundleName</key><string>PR Counter</string>
  <key>CFBundleDisplayName</key><string>PR Counter</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
