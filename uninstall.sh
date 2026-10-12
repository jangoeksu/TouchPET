#!/bin/bash
set -euo pipefail
PLIST="$HOME/Library/LaunchAgents/com.jangoeksu.touchpet.plist"
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"
rm -rf "$HOME/Applications/TouchPET.app"
echo "TouchPET removed."
