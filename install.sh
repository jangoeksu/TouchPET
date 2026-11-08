#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test -d dist/TouchBarPET.app || { echo "Run ./build.sh first"; exit 1; }
# Use --preview to keep the interactive on-screen pet running at login.
PREVIEW_XML=""
if [[ "${1:-}" == "--preview" && $# -eq 1 ]]; then
  PREVIEW_XML="<string>--preview</string>"
elif [[ $# -ne 0 ]]; then
  echo "Usage: ./install.sh [--preview]" >&2
  exit 2
fi
LABEL="com.jangoeksu.touchbarpet"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -rf "$HOME/Applications/TouchBarPET.app"
ditto dist/TouchBarPET.app "$HOME/Applications/TouchBarPET.app"

# Run the binary directly (not via `open`) so launchd can supervise it:
# it is restarted if it crashes or is killed, but not after "Quit" from the menu.
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$HOME/Applications/TouchBarPET.app/Contents/MacOS/TouchBarPET</string>${PREVIEW_XML}</array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
<key>ThrottleInterval</key><integer>5</integer>
<key>ProcessType</key><string>Interactive</string>
<key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
PLISTEOF
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed. TouchBarPET starts at login and restarts if it crashes."
