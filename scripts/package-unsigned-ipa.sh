#!/bin/bash
set -euo pipefail
xcodegen generate
xcodebuild -project SnapRequestAssistant.xcodeproj -scheme SnapRequestAssistant -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
APP=$(find build/DerivedData/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' | head -1)
test -n "$APP"
rm -rf build/Payload build/SnapRequestAssistant-unsigned.ipa
mkdir -p build/Payload
cp -R "$APP" build/Payload/
cd build && zip -qr SnapRequestAssistant-unsigned.ipa Payload && cd ..
ls -lh build/SnapRequestAssistant-unsigned.ipa
unzip -l build/SnapRequestAssistant-unsigned.ipa | head -20
