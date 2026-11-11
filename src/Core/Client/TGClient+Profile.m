#import "TGClientInternal.h"
#import "TGStyle.h"

@implementation TGClient (Profile)

#pragma mark - the private note

#pragma mark - close friends

#pragma mark - read-date privacy

#pragma mark - suggestions

#pragma mark - the main profile tab

#pragma mark - birthdays and support

#pragma mark - accent colours

#pragma mark - the sharing theme

- (UIColor *)nameColourForUser:(int64_t)userId {
	NSNumber *accent = self.rawUsersById[@(userId)][@"accent_color_id"];
	UIColor *chosen = [accent isKindOfClass:NSNumber.class]
			? TGColourAccentName(accent.integerValue, self.accentColors, NO) : nil;
	return chosen ?: TGColourPeerName(userId, NO);
}

@end
