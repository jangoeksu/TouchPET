#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Build on a Touch Bar Mac"; exit 1; }
APP="dist/TouchPET.app"
mkdir -p "$APP/Contents/MacOS"
clang -fobjc-arc -c Sources/TouchBarBridge.m -o /tmp/touchpet_bridge_$$.o
swiftc -O -import-objc-header Sources/TouchBarBridge.h -framework AppKit Sources/main.swift /tmp/touchpet_bridge_$$.o -o "$APP/Contents/MacOS/TouchPET"
rm -f /tmp/touchpet_bridge_$$.o
cp Info.plist "$APP/Contents/Info.plist"
echo "Built $APP"
