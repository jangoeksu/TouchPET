#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "TouchBarBridge.h"
BOOL TouchPETPresentBar(NSTouchBar *bar) {
    Class cls = [NSTouchBar class];
    SEL s = NSSelectorFromString(@"presentSystemModalFunctionBar:systemTrayItemIdentifier:");
    if (![cls respondsToSelector:s]) s = NSSelectorFromString(@"presentSystemModalTouchBar:systemTrayItemIdentifier:");
    if (![cls respondsToSelector:s]) return NO;
    ((void(*)(id,SEL,id,id))[cls methodForSelector:s])(cls,s,bar,nil);
    return YES;
}
void TouchPETDismissBar(NSTouchBar *bar) {
    Class cls = [NSTouchBar class];
    SEL s = NSSelectorFromString(@"dismissSystemModalFunctionBar:");
    if (![cls respondsToSelector:s]) s = NSSelectorFromString(@"dismissSystemModalTouchBar:");
    if ([cls respondsToSelector:s])
        ((void(*)(id,SEL,id))[cls methodForSelector:s])(cls,s,bar);
}
