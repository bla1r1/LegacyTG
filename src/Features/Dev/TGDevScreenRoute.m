//
// TGDevScreenRoute.m
//
#import "TGDevScreenRoute.h"
#import <objc/message.h>

#if TG_DEV

Class TGDevScreenClass(NSString *name, Class base) {
	if (![name hasPrefix:@"TG"] || !base)
		return Nil;
	// Each needs what only its own route sets up: a loaded chat, a live
	// call, the auth state machine, the iPad canvas.
	static NSArray *own;
	if (!own)
		own = @[@"TGChatViewController", @"TGCallViewController",
				@"TGGroupCallViewController", @"TGLoginViewController",
				@"TGiPadSimulatorContainerViewController", @"TGiPadSplitViewController"];
	if ([own containsObject:name])
		return Nil;
	Class cls = NSClassFromString(name);
	return cls && [cls isSubclassOfClass:base] ? cls : Nil;
}

id TGDevScreenMake(Class cls, int64_t chatId, NSString *title) {
	if (!cls)
		return nil;
	SEL withTitle = NSSelectorFromString(@"initWithChatId:title:");
	SEL withChat = NSSelectorFromString(@"initWithChatId:");
	if (chatId && [cls instancesRespondToSelector:withTitle])
		return ((id (*)(id, SEL, int64_t, NSString *))objc_msgSend)(
				[cls alloc], withTitle, chatId, title ?: @"");
	if (chatId && [cls instancesRespondToSelector:withChat])
		return ((id (*)(id, SEL, int64_t))objc_msgSend)([cls alloc], withChat, chatId);
	id screen = [[cls alloc] init];
	if (chatId && [screen respondsToSelector:NSSelectorFromString(@"setChatId:")])
		[screen setValue:@(chatId) forKey:@"chatId"];
	if (title.length && [screen respondsToSelector:NSSelectorFromString(@"setChatTitle:")])
		[screen setValue:title forKey:@"chatTitle"];
	return screen;
}

#endif
