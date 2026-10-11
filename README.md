# TouchPET

Native macOS Touch Bar pet source code (Swift + Objective-C bridge).

## Features
- Kitty
- Tap cat to pet; three quick taps toggle shelter
- Tap blank ground to leave a snack; cat walks to it and eats it
- Tap to clean it
- Drag the pink ball to play
- Saved PET, FED, PLAY, CLEAN counters
- Animated clouds, rain, sun, and four time-of-day palettes
- Menu-bar app; no separate pet window

## Build on a Mac with a physical Touch Bar

```bash
git clone https://github.com/jangoeksu/TouchPET.git
cd TouchPET
chmod +x build.sh install.sh
./build.sh
open dist/TouchPET.app
```

If it launches and the physical Touch Bar responds, install autostart with `./install.sh`.

## Important compatibility notes

**Unverified prototype:** the project was uploaded as source code, but has not been compiled or physically tested on a Mac in this environment. The system-modal Touch Bar bridge invokes **private, undocumented macOS APIs** and could fail on your macOS version. If the pet doesn't appear or taps don't respond, this may be the cause; please provide the macOS version and build output.

The app cannot show the cat while the Mac's Touch Bar hardware is powered off (e.g. during display/system sleep). This implementation does not modify the original closed-source Touchbar Pet app.

To stop automatic login launch, remove `~/Library/LaunchAgents/com.jangoeksu.touchpet.plist` and unload it with `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.jangoeksu.touchpet.plist`.
