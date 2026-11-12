#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Build on macOS (Touch Bar hardware is not required)" >&2; exit 1; }

# Command Line Tools can ship an SDK that is newer than their Swift compiler.
# E.g. Swift 6.3 cannot import the Swift 6.4 standard library from macOS SDK 27.
# Select an SDK whose Swift standard library was built with the same Swift
# major.minor version as the active compiler.
SWIFT_COMPILER="$(xcrun --find swiftc)"
CLANG_COMPILER="$(xcrun --find clang)"
SWIFT_VERSION="$("$SWIFT_COMPILER" --version | sed -nE 's/.*Apple Swift version ([0-9]+\.[0-9]+).*/\1/p')"
if [[ -z "$SWIFT_VERSION" ]]; then
  echo "error: Cannot determine the active Apple Swift compiler version." >&2
  exit 1
fi

DEFAULT_SDK="$(xcrun --sdk macosx --show-sdk-path)"
SDK_PATH=""
# Prefer the currently selected SDK when it matches; otherwise look through
# the installed macOS SDKs in the same developer directory.
SDK_DIR="$(dirname "$DEFAULT_SDK")"
for candidate in "$DEFAULT_SDK" "$SDK_DIR"/MacOSX*.sdk; do
  [[ -d "$candidate" ]] || continue
  for interface in "$candidate"/usr/lib/swift/Swift.swiftmodule/*-apple-macos.swiftinterface; do
    [[ -f "$interface" ]] || continue
    SDK_SWIFT_VERSION="$(sed -nE 's@^// swift-compiler-version: Apple Swift version ([0-9]+\.[0-9]+).*@\1@p' "$interface" | head -n 1)"
    if [[ "$SDK_SWIFT_VERSION" == "$SWIFT_VERSION" ]]; then
      SDK_PATH="$candidate"
      break 2
    fi
  done
done

if [[ -z "$SDK_PATH" ]]; then
  echo "error: No installed macOS SDK matches Apple Swift $SWIFT_VERSION." >&2
  echo "The active SDK is $DEFAULT_SDK." >&2
  echo "Install or update Xcode Command Line Tools so Swift and the macOS SDK match." >&2
  echo "You can inspect them with: xcrun swift --version; xcrun --sdk macosx --show-sdk-path" >&2
  exit 1
fi
echo "Using Apple Swift $SWIFT_VERSION with SDK: $SDK_PATH"

APP="dist/TouchBarPET.app"
mkdir -p dist
TMP="$(mktemp -d "dist/.touchbarpet-build.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
STAGED_APP="$TMP/TouchBarPET.app"
OBJ="$TMP/bridge.o"
mkdir -p "$STAGED_APP/Contents/MacOS"
"$CLANG_COMPILER" -isysroot "$SDK_PATH" -fobjc-arc -c Sources/TouchBarBridge.m -o "$OBJ"
"$SWIFT_COMPILER" -sdk "$SDK_PATH" -O -swift-version 5 \
  -import-objc-header Sources/TouchBarBridge.h \
  -framework AppKit -framework IOKit \
  Sources/PetNeeds.swift Sources/main.swift "$OBJ" -o "$STAGED_APP/Contents/MacOS/TouchBarPET"
cp Info.plist "$STAGED_APP/Contents/Info.plist"
codesign --force --sign - "$STAGED_APP" >/dev/null 2>&1 || echo "warning: ad-hoc codesign failed (app may still run)"
# Only replace a previously working app after successful compilation.
rm -rf "$APP"
mv "$STAGED_APP" "$APP"
echo "Built $APP"
