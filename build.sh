#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP=build/DualAudio.app
mkdir -p $APP/Contents/MacOS
# universal binary so it runs on Apple Silicon and Intel Macs
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos14.0 \
    -framework IOBluetooth -framework CoreAudio -framework AudioToolbox -framework SwiftUI \
    -o build/DualAudio-$arch Sources/*.swift
done
lipo -create build/DualAudio-arm64 build/DualAudio-x86_64 -output $APP/Contents/MacOS/DualAudio
rm build/DualAudio-arm64 build/DualAudio-x86_64
cp Info.plist $APP/Contents/
codesign --force --deep -s - $APP
(cd build && rm -f DualAudio.zip && ditto -c -k --keepParent DualAudio.app DualAudio.zip)
echo "$PWD/$APP"
