#import <AppKit/AppKit.h>
#import <dlfcn.h>
#import "TouchBarBridge.h"

// All private symbols are looked up at runtime (dlopen/dlsym, respondsToSelector)
// so the app still builds and launches if Apple renames or removes any of them.

static void *TPSymbol(const char *name) {
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY);
    });
    return handle ? dlsym(handle, name) : NULL;
}

BOOL TouchPETPresentBar(NSTouchBar *bar, NSString *trayIdentifier) {
    Class cls = [NSTouchBar class];

    // macOS 10.14+: placement variant (placement 1 = system modal, stays until dismissed)
    SEL withPlacement = NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:");
    if ([cls respondsToSelector:withPlacement]) {
        IMP imp = [cls methodForSelector:withPlacement];
        ((void (*)(id, SEL, id, NSInteger, id))imp)(cls, withPlacement, bar, 1, trayIdentifier);
        return YES;
    }
    // Older / alias names, newest first.
    NSArray<NSString *> *names = @[
        @"presentSystemModalTouchBar:systemTrayItemIdentifier:",
        @"presentSystemModalFunctionBar:systemTrayItemIdentifier:",
    ];
    for (NSString *name in names) {
        SEL s = NSSelectorFromString(name);
        if ([cls respondsToSelector:s]) {
            IMP imp = [cls methodForSelector:s];
            ((void (*)(id, SEL, id, id))imp)(cls, s, bar, trayIdentifier);
            return YES;
        }
    }
    return NO;
}

void TouchPETDismissBar(NSTouchBar *bar) {
    Class cls = [NSTouchBar class];
    for (NSString *name in @[@"dismissSystemModalTouchBar:", @"dismissSystemModalFunctionBar:"]) {
        SEL s = NSSelectorFromString(name);
        if ([cls respondsToSelector:s]) {
            IMP imp = [cls methodForSelector:s];
            ((void (*)(id, SEL, id))imp)(cls, s, bar);
            return;
        }
    }
}

void TouchPETSetCloseBoxVisible(BOOL visible) {
    void (*fn)(BOOL) = (void (*)(BOOL))TPSymbol("DFRSystemModalShowsCloseBoxWhenFrontMost");
    if (fn) fn(visible);
}

void TouchPETInstallTrayItem(NSTouchBarItem *item, NSString *identifier) {
    SEL s = NSSelectorFromString(@"addSystemTrayItem:");
    if ([NSTouchBarItem respondsToSelector:s]) {
        IMP imp = [NSTouchBarItem methodForSelector:s];
        ((void (*)(id, SEL, id))imp)([NSTouchBarItem class], s, item);
    }
    void (*fn)(NSString *, BOOL) = (void (*)(NSString *, BOOL))TPSymbol("DFRElementSetControlStripPresenceForIdentifier");
    if (fn) fn(identifier, YES);
}

void TouchPETRemoveTrayItem(NSString *identifier) {
    void (*fn)(NSString *, BOOL) = (void (*)(NSString *, BOOL))TPSymbol("DFRElementSetControlStripPresenceForIdentifier");
    if (fn) fn(identifier, NO);
}
