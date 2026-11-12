#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test -d dist/TouchBarPET.app || { echo "Run ./build.sh first"; exit 1; }

# Installing no longer means taking over the Touch Bar or adding a login agent.
# Add --login explicitly to launch the on-screen preview at login.
if [[ $# -gt 1 || ( $# -eq 1 && "${1:-}" != "--login" ) ]]; then
  echo "Usage: ./install.sh [--login]" >&2
  exit 2
fi

LABEL="com.jangoeksu.touchbarpet"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"

# Remove a previous launch agent that may have been automatically taking over the bar.
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
ditto dist/TouchBarPET.app "$HOME/Applications/TouchBarPET.app"

if [[ "${1:-}" == "--login" ]]; then
  cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$HOME/Applications/TouchBarPET.app/Contents/MacOS/TouchBarPET</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><false/>
<key>ProcessType</key><string>Interactive</string>
<key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
PLISTEOF
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "Installed: preview-only at login. Normal macOS Touch Bar stays available."
else
  echo "Installed without autostart. Run: open \"$HOME/Applications/TouchBarPET.app\""
  echo "Normal macOS Touch Bar is not changed."
fi
