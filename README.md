# TouchPET

Native macOS Touch Bar pet (Swift + a small Objective-C bridge). Menu-bar app, no window.

## Features
- Tap the cat to pet it: it **hops around** (2-3 hops, rapid taps extend the sequence) and hearts float up
- Three quick taps toggle the shelter
- Tap empty ground to leave a snack; the cat walks over and eats it
- Tap poop to clean it
- Drag the pink ball to play
- Saved PET / FED / PLAY / CLEAN counters
- Animated clouds, rain (falls downwards), sun, four time-of-day palettes, blinking, wandering, napping

## Build (Mac with a physical Touch Bar)

```bash
chmod +x build.sh install.sh uninstall.sh
./build.sh
open dist/TouchPET.app
```

If the pet shows up and responds to touch, run `./install.sh` for autostart
(launchd restarts it if it ever crashes; **Quit** from the menu really quits). `./uninstall.sh` removes it.

## Keeping the pet on the Touch Bar

| Situation | What TouchPET does |
|---|---|
| Sleep / wake, screen unlock, fast user switch | Re-presents the bar 1-4 s after wake (hardware needs a moment) |
| Another system-modal bar or display change replaces it | Re-presents it (auto-restore, see below) |
| Dismissed by tapping the "X" | Control Strip cat button or menu-bar **Show cat** brings it back |
| macOS App Nap throttling a windowless app | Disabled, so animation never stalls |
| Display turns off after inactivity | Menu **Keep display awake** (off by default; costs battery) |

Menu-bar options (the cat icon):
- **Pin to Touch Bar** (default on): hides the "X" button and restores the bar automatically if the system drops it. Turn it off to get the close button back. Use **Hide cat** from the menu to hide it deliberately.
- **Keep display awake**: prevents display sleep so the Touch Bar stays lit.

## Compatibility notes

The system-modal presentation uses **private, undocumented macOS APIs**
(`NSTouchBar` system-modal selectors and `DFRFoundation`). They are looked up at runtime, so the app
still builds if one is missing; the menu-bar icon shows a warning sign if no presentation API exists on your macOS version.
This code has not been compiled or run on a Mac by the author of this revision. If something fails, send the macOS version and the
output of `./build.sh` / `log stream --predicate 'process == "TouchPET"'`.
