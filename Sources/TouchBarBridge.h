#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Presents `bar` as a system-modal Touch Bar (private API, resolved at runtime).
/// Returns NO if no known presentation selector exists on this macOS version.
BOOL TouchPETPresentBar(NSTouchBar *bar, NSString *_Nullable trayIdentifier);
void TouchPETDismissBar(NSTouchBar *bar);

/// Shows/hides the small "X" close button of the system-modal bar.
void TouchPETSetCloseBoxVisible(BOOL visible);

/// Adds a button to the Control Strip so the pet can be reopened with one tap.
void TouchPETInstallTrayItem(NSTouchBarItem *item, NSString *identifier);
void TouchPETRemoveTrayItem(NSString *identifier);

NS_ASSUME_NONNULL_END
