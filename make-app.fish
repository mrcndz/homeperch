#!/usr/bin/env fish
# Build HomePerch.app from the SPM release binary
cd (dirname (status filename))

swift build -c release; or exit 1

set app HomePerch.app
rm -rf $app
mkdir -p $app/Contents/MacOS

cp .build/release/HomePerch $app/Contents/MacOS/

echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>HomePerch</string>
    <key>CFBundleIdentifier</key><string>dev.mrcndz.homeperch</string>
    <key>CFBundleName</key><string>HomePerch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>' > $app/Contents/Info.plist

codesign --force --sign - $app; or exit 1
echo "Built $app - copy it to /Applications"
