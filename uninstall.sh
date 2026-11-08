#!/bin/bash
set -euo pipefail
PLIST="$HOME/Library/LaunchAgents/com.jangoeksu.touchbarpet.plist"
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"
rm -rf "$HOME/Applications/TouchBarPET.app"
echo "TouchBarPET removed."
