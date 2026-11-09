# TouchBarPET

A cartoon Blob Kitty pet for macOS, with an optional **hardware Touch Bar** mode.
**The normal macOS Touch Bar is preserved by default.** The app no longer
claims the physical Touch Bar just because it is launched.

## Default: normal Touch Bar, floating Kitty preview

```bash
./build.sh
open dist/TouchBarPET.app
```

This opens the interactive on-screen Kitty window and leaves the hardware Touch Bar
and Control Strip alone. The older `--preview` argument is no longer necessary.

To deliberately show Kitty on the physical Touch Bar, choose **PET → Show on Touch Bar
(opt in)** from the macOS menu bar, or start:

```bash
open dist/TouchBarPET.app --args --touchbar
```

Select **PET → Restore normal Touch Bar** to immediately dismiss the pet's
system-modal Touch Bar and remove its Control Strip tray item. **Quit TouchBarPET**
also dismisses the hardware bar.

This experimental hardware mode relies on undocumented Apple Touch Bar APIs; it
may behave differently on different macOS versions. MacOS can reserve space for
the Control Strip.

## Install without changing macOS startup

```bash
./build.sh
./install.sh
open "$HOME/Applications/TouchBarPET.app"
```

`./install.sh` installs an app copy but **does not** add a login item or launch
the pet at startup. It also removes older TouchBarPET launch-agent settings,
which may have been configured to take over the bar.

To intentionally open the **preview only** at login:

```bash
./install.sh --login
```

There is no hardware-mode autostart option. If you want to stop older versions
and restore the original Touch Bar immediately:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.jangoeksu.touchbarpet.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.jangoeksu.touchbarpet.plist"
pkill -x TouchBarPET 2>/dev/null || true
```

If macOS does not restore its Touch Bar controls after quitting, restart the Mac
and check the Touch Bar preferences in System Settings → Keyboard. To remove
TouchBarPET completely, run `./uninstall.sh`.

## Kitty features

- Round brown-and-cream cartoon cat with pointed ears, whiskers, blue eyes,
  tiny paws, pink nose and curved tail
- Slow walking, chasing the rolling matte pink ball, feeding, petting and
  occasional belly-up rest
- Hunger and company state with happy/sad expressions
- Blue sky with small faint clouds and a very thin ground strip, no rain,
  house or sleeping ZZZ
- The same Swift view and state for physical Touch Bar and floating preview;
  a separate HTML demo lives in `preview/blob-kitty.html`

## Build requirements

`build.sh` requires Apple developer Command Line Tools or Xcode on a Mac and
selects an installed macOS SDK compatible with the active Swift compiler.
If your compiler and SDK do not match, the script reports the mismatch and
preserves the previously built app.

## Limitations

The physical Touch Bar mode is optional, private-API-based and has not been
verified on all macOS versions. The HTML preview is a separate implementation
and may differ from the native Swift rendering.
