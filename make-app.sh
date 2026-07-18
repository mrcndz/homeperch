#!/bin/sh
# Build HomePerch.app from the SPM release binary
set -e
cd "$(dirname "$0")"

swift build -c release

APP=HomePerch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/HomePerch "$APP/Contents/MacOS/"
cp Assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>HomePerch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>dev.mrcndz.homeperch</string>
    <key>CFBundleName</key><string>HomePerch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP - copy it to /Applications"

# Optional: ./make-app.sh dmg also produces HomePerch.dmg
if [ "$1" = "dmg" ]; then
    STAGING=$(mktemp -d)
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    rm -f HomePerch.dmg
    hdiutil create -volname HomePerch -srcfolder "$STAGING" -format UDZO -quiet HomePerch.dmg
    rm -rf "$STAGING"
    echo "Built HomePerch.dmg"
fi
