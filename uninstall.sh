#!/bin/bash
set -euo pipefail
PLIST="$HOME/Library/LaunchAgents/com.jangoeksu.touchbarpet.plist"
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"
INSTALLED_EXE="$HOME/Applications/TouchBarPET.app/Contents/MacOS/TouchBarPET"
if [[ -x "$INSTALLED_EXE" ]]; then
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if [[ "$(ps -p "$pid" -o comm= 2>/dev/null || true)" == "$INSTALLED_EXE" ]]; then
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done < <(pgrep -x TouchBarPET || true)
  sleep 0.5
fi
rm -rf "$HOME/Applications/TouchBarPET.app"
echo "TouchBarPET removed."
