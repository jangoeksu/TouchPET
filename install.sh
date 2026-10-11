#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test -d dist/TouchPET.app || { echo "Run ./build.sh first"; exit 1; }
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
ditto dist/TouchPET.app "$HOME/Applications/TouchPET.app"
cat > "$HOME/Library/LaunchAgents/com.jangoeksu.touchpet.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>com.jangoeksu.touchpet</string><key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-a</string><string>$HOME/Applications/TouchPET.app</string></array><key>RunAtLoad</key><true/></dict></plist>
EOF
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.jangoeksu.touchpet.plist" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.jangoeksu.touchpet.plist"
