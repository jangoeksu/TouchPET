# TouchBarPET

Native macOS Touch Bar pet (Swift + a small Objective-C bridge). Menu-bar app, no window.

## Features
- Pet the cat in the on-screen preview or Touch Bar
- Tap empty ground to leave a snack; the cat walks over and eats it
- Tap poop to clean it
- Drag the pink ball to play
- Saved PET / FED / PLAY / CLEAN counters
- Animated clouds and a day/night sky in the native app

## Build (macOS)

```bash
chmod +x build.sh install.sh uninstall.sh
./build.sh
open dist/TouchBarPET.app
```

The build script checks the active Apple Swift compiler against the Swift standard
library in each installed macOS SDK. If the selected SDK is too new (for example,
Swift 6.3 with SDK 27 requiring Swift 6.4), it uses a compatible installed SDK
instead. If none matches, the script prints an actionable error before removing
any previously built app. On a Mac with older Command Line Tools, install a
matching set of tools if the error persists; full Xcode is not otherwise required.

### Test without a physical Touch Bar

TouchBarPET can now display its interactive pet directly in a small floating window.
On any Mac, build as above, then start the app in preview mode:

```bash
open dist/TouchBarPET.app --args --preview
```

The same drawing, mouse interactions, and saved counters are used for the on-screen
preview and the physical Touch Bar. Click the cat to pet it, click empty space to
feed it, and drag the ball to play. You can also select **Open on-screen preview**
from the menu bar at any time. If another copy of TouchBarPET is already running,
quit it first so the new `--preview` argument takes effect.

**Important:** The preview tests the pet itself, but it does **not** simulate
macOS's private Touch Bar presentation APIs or prove that the app works on
real Touch Bar hardware. A separate Touch Bar simulator is not required to
test the pet's UI.

For autostart on a Mac with a physical Touch Bar, run `./install.sh`.
To automatically open the on-screen preview at login on a Mac without
a Touch Bar, run `./install.sh --preview`.
(launchd restarts it if it ever crashes; **Quit** from the menu really quits). `./uninstall.sh` removes it.

## Keeping the pet on the Touch Bar

| Situation | What TouchBarPET does |
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
The on-screen preview can be used to test the pet without Touch Bar hardware.
The hardware integration uses private APIs whose behavior varies by macOS release.
If something fails, send the macOS version and the
output of `./build.sh` / `log stream --predicate 'process == "TouchBarPET"'`.
