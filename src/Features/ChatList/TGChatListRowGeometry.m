#import <UIKit/UIKit.h>
#import "TGChatListRowGeometry.h"
#import "TGLocalization.h"

NSDictionary *TGChatListNotice(NSArray *suggestedRows) {
	NSDictionary *password = nil, *premium = nil;
	for (NSDictionary *row in suggestedRows){
		NSDictionary *action = [row isKindOfClass:NSDictionary.class] ? row[@"action"] : nil;
		if (![action isKindOfClass:NSDictionary.class])
			continue;
		NSString *type = action[@"@type"];
		if ([type isEqualToString:@"suggestedActionSetPassword"] && !password)
			password = action;
		else if ([type isEqualToString:@"suggestedActionExtendPremium"] && !premium)
			premium = action;
	}
	if (password)
		return @{ @"kind" : @"setupPassword", @"closable" : @NO, @"action" : password,
				  @"title" : TGLocalized(@"Protect Your Account"),
				  @"text" : TGLocalized(@"Set a password that will be required each time you log in with this phone number.") };
	if (premium){
		NSString *url = premium[@"manage_premium_subscription_url"];
		NSMutableDictionary *notice = [@{ @"kind" : @"premiumGrace", @"closable" : @YES, @"action" : premium,
				@"title" : TGLocalized(@"\u26A0\uFE0F Don't lose access to Telegram Premium!"),
				@"text" : TGLocalized(@"Your exclusive benefits are about to expire.") } mutableCopy];
		if ([url isKindOfClass:NSString.class] && url.length)
			notice[@"url"] = url;
		return notice;
	}
	return nil;
}

NSString *TGChatListArchiveSubtitle(NSUInteger count) {
	return TGLocalizedPlural(@"%d chat", @"%d chats", (NSInteger)count);
}

void TGChatListRowAccessories(CGFloat rightEdge,
                              CGFloat top,
                              BOOL hasBadge,
                              CGFloat badgeWidth,
                              CGFloat badgeHeight,
                              BOOL hasPin,
                              CGFloat pinSide,
                              CGFloat gap,
                              CGRect *badgeFrame,
                              CGRect *pinFrame,
                              CGFloat *previewRight) {
	CGFloat x = rightEdge;

	if (hasBadge){
		if (badgeFrame)
			*badgeFrame = CGRectMake(x - badgeWidth, top, badgeWidth, badgeHeight);
		x -= badgeWidth + gap;
	} else if (badgeFrame){
		*badgeFrame = CGRectZero;
	}

	if (hasPin){
		if (pinFrame)
			*pinFrame = CGRectMake(x - pinSide,
					top + (badgeHeight - pinSide) * 0.5f, pinSide, pinSide);
		x -= pinSide + gap;
	} else if (pinFrame){
		*pinFrame = CGRectZero;
	}

	if (previewRight)
		*previewRight = x;
}

NSRange TGAvatarWindow(NSInteger firstVisible, NSUInteger rows, NSUInteger total) {
	NSUInteger start = firstVisible > 1 ? (NSUInteger)(firstVisible - 1) : 0;
	if (start >= total)
		return NSMakeRange(total, 0);
	return NSMakeRange(start, MIN(rows, total - start));
}

/// Custom emoji ranges as the row reads them, { offset, length, customEmojiId }
/// or [offset, length, id], reduced to numbers so the list stays a plist.
NSArray *TGSnapshotCustomEmoji(id value) {
	if (![value isKindOfClass:NSArray.class])
		return nil;
	NSMutableArray *out = [NSMutableArray array];
	for (id item in value){
		NSNumber *offset = nil, *length = nil, *emojiId = nil;
		if ([item isKindOfClass:NSDictionary.class]){
			offset = item[@"offset"]; length = item[@"length"]; emojiId = item[@"customEmojiId"];
		} else if ([item isKindOfClass:NSArray.class] && [item count] >= 3){
			offset = item[0]; length = item[1]; emojiId = item[2];
		}
		if (![offset isKindOfClass:NSNumber.class] || ![length isKindOfClass:NSNumber.class])
			continue;
		if ([emojiId isKindOfClass:NSString.class])
			emojiId = @([(NSString *)emojiId longLongValue]);
		if (![emojiId isKindOfClass:NSNumber.class] || emojiId.longLongValue == 0)
			continue;
		[out addObject:@{@"offset" : offset, @"length" : length, @"customEmojiId" : emojiId}];
	}
	return out;
}

BOOL TGChatListSwipeGestureShouldBegin(CGPoint delta, CGPoint velocity) {
	if (delta.x == 0 && delta.y == 0) {
		if (fabs(velocity.x) <= fabs(velocity.y) || fabs(velocity.x) < 10.0f)
			return NO;
		return YES;
	}
	if (delta.x == 0 || fabs(delta.x) <= fabs(delta.y))
		return NO;
	return YES;
}

BOOL TGChatListIsTouchInsideActionButton(UIView *view, UIView *cellContentView) {
	if (!view)
		return NO;
	for (UIView *v = view; v != nil; v = v.superview) {
		if (cellContentView && v == cellContentView)
			return NO;
		if ([v isKindOfClass:NSClassFromString(@"UIButton")] || [v isKindOfClass:[UIButton class]])
			return YES;
	}
	return NO;
}

NSString *TGChatListSafeEmojiFallback(NSString *emoji) {
	if (!emoji.length) return @"";
	static NSDictionary *sMap = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		sMap = @{
			@"🥳" : @"🎉",
			@"🥺" : @"😊",
			@"🥑" : @"🍏",
			@"🦖" : @"🐊",
			@"🦕" : @"🐊",
			@"🥰" : @"😍",
			@"🤩" : @"😍",
			@"🤪" : @"😜",
			@"🤗" : @"😊",
			@"🤔" : @"💭",
			@"🤭" : @"🙈",
			@"🤫" : @"😶",
			@"🤤" : @"😋",
			@"🤢" : @"😷",
			@"🤮" : @"😷",
			@"🤧" : @"😷",
			@"🥵" : @"♨️",
			@"🥶" : @"❄️",
			@"🥴" : @"😵",
			@"🤯" : @"💥",
			@"🥱" : @"😪",
			@"🥲" : @"🙂",
			@"🥸" : @"👓",
			@"🤌" : @"👌",
			@"🤏" : @"👌",
			@"🤞" : @"✌️",
			@"🤟" : @"🤘",
			@"🤙" : @"📞",
			@"🤛" : @"👊",
			@"🤜" : @"👊",
			@"🧠" : @"💭",
			@"🫀" : @"❤️",
			@"🫁" : @"💨",
			@"🦾" : @"💪",
			@"🦿" : @"🦵",
			@"🦄" : @"🐴",
			@"🦇" : @"🐾",
			@"🦉" : @"🐦",
			@"🦅" : @"🐦",
			@"🦆" : @"🐦",
			@"🦢" : @"🐦",
			@"🦈" : @"🐟",
			@"🦑" : @"🐙",
			@"🦞" : @"🦀",
			@"🦐" : @"🍤",
			@"🦚" : @"🐦",
			@"🦜" : @"🐦",
			@"🦔" : @"🐾",
			@"🦘" : @"🐾",
			@"🦡" : @"🐾",
			@"🌮" : @"🥪",
			@"🌯" : @"🥪",
			@"🥙" : @"🥪",
			@"🥗" : @"🍲",
			@"🥘" : @"🍲",
			@"🥫" : @"🍲",
			@"🧇" : @"🥞",
			@"🥞" : @"🍰",
			@"🧈" : @"🧀",
			@"🧁" : @"🎂",
			@"🥧" : @"🍰"
		};
	});
	NSString *mapped = sMap[emoji];
	if (mapped)
		return mapped;
	return @"✨";
}
