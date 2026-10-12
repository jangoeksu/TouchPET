#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test -d dist/TouchPET.app || { echo "Run ./build.sh first"; exit 1; }
LABEL="com.jangoeksu.touchpet"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -rf "$HOME/Applications/TouchPET.app"
ditto dist/TouchPET.app "$HOME/Applications/TouchPET.app"

# Run the binary directly (not via `open`) so launchd can supervise it:
# it is restarted if it crashes or is killed, but not after "Quit" from the menu.
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$HOME/Applications/TouchPET.app/Contents/MacOS/TouchPET</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
<key>ThrottleInterval</key><integer>5</integer>
<key>ProcessType</key><string>Interactive</string>
<key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
PLISTEOF
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed. TouchPET starts at login and restarts if it crashes."
