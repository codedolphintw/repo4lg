#!/bin/bash
# Build Probe.app for the iOS simulator with plain swiftc (no Xcode project).
set -euo pipefail
: "${OUT:?}" "${APP:?}"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
rm -rf "$APP"
mkdir -p "$APP"
xcrun --sdk iphonesimulator swiftc -swift-version 5 -parse-as-library -O \
  -target arm64-apple-ios26.0-simulator -sdk "$SDK" \
  probe/App.swift -o "$APP/Probe" 2>&1 | tee "$OUT/build.txt"
cp probe/Info.plist "$APP/"
codesign --force -s - "$APP"
