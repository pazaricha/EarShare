#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP=build/EarShare.app
mkdir -p $APP/Contents/MacOS
# universal binary so it runs on Apple Silicon and Intel Macs
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos14.0 \
    -framework IOBluetooth -framework CoreAudio -framework AudioToolbox -framework SwiftUI \
    -o build/EarShare-$arch Sources/*.swift
done
lipo -create build/EarShare-arm64 build/EarShare-x86_64 -output $APP/Contents/MacOS/EarShare
rm build/EarShare-arm64 build/EarShare-x86_64
cp Info.plist $APP/Contents/
mkdir -p $APP/Contents/Resources
cp Resources/AppIcon.icns Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png $APP/Contents/Resources/
codesign --force --deep -s - $APP
(cd build && rm -f EarShare.zip && ditto -c -k --keepParent EarShare.app EarShare.zip)
echo "$PWD/$APP"
