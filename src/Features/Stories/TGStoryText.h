//
// TGStoryText.h - TDLib story state names as the nouns the official sheet
// shows. Pure, so the mappings can be host-tested without a story request.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

static inline NSString *TGStoryPrivacyNoun(NSString *privacy) {
	if (![privacy isKindOfClass:NSString.class] || !privacy.length)
		return @"-";
	if ([privacy isEqualToString:@"everyone"])
		return TGLocalized(@"Everybody");
	if ([privacy isEqualToString:@"contacts"])
		return TGLocalized(@"My Contacts");
	if ([privacy isEqualToString:@"closeFriends"])
		return TGLocalized(@"Close Friends");
	if ([privacy isEqualToString:@"selected"])
		return TGLocalized(@"Selected Users");
	return privacy;
}

static inline NSString *TGStoryInteractionNoun(NSString *kind) {
	if ([kind isEqualToString:@"view"])
		return TGLocalized(@"View");
	if ([kind isEqualToString:@"forward"] || [kind isEqualToString:@"repost"])
		return TGLocalized(@"Forwarded Messages");
	return kind ?: TGLocalized(@"View");
}
