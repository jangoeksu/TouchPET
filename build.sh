#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Build on a Touch Bar Mac"; exit 1; }
APP="dist/TouchPET.app"
OBJ="$(mktemp -t touchpet_bridge).o"
trap 'rm -f "$OBJ"' EXIT
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
clang -fobjc-arc -c Sources/TouchBarBridge.m -o "$OBJ"
swiftc -O -swift-version 5 \
  -import-objc-header Sources/TouchBarBridge.h \
  -framework AppKit -framework IOKit \
  Sources/main.swift "$OBJ" -o "$APP/Contents/MacOS/TouchPET"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: ad-hoc codesign failed (app may still run)"
echo "Built $APP"
