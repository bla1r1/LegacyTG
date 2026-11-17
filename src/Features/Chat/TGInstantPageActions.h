//
// TGInstantPageActions.h - what a tap in the Instant View reader does, kept
// apart from UIKit so the host suite can pin it. A tappable run carries one
// action string: "anchor:<name>", "ref:<name>", "details:<n>", "url:<url>",
// "copy:<text>" or "feedback".
//
#import <Foundation/Foundation.h>

/// The action of a pageBlockButtonRow button (inlineButton): its URL or the
/// text it copies; nil for kinds the reader has nowhere to send (a user, a
/// callback).
static inline NSString *TGInstantButtonAction(NSDictionary *button) {
	NSDictionary *type = [button isKindOfClass:NSDictionary.class] && [button[@"type"] isKindOfClass:NSDictionary.class]
			? button[@"type"] : nil;
	NSString *kind = type[@"@type"];
	if ([kind isEqualToString:@"inlineKeyboardButtonTypeUrl"] && [type[@"url"] length])
		return [@"url:" stringByAppendingString:type[@"url"]];
	if ([kind isEqualToString:@"inlineKeyboardButtonTypeCopyText"] && [type[@"text"] length])
		return [@"copy:" stringByAppendingString:type[@"text"]];
	return nil;
}

/// NSTextAlignment for a PageBlockHorizontalAlignment; a row with none is
/// full width, which in a text reader reads as centred.
static inline NSInteger TGInstantAlignment(NSDictionary *align) {
	NSString *kind = [align isKindOfClass:NSDictionary.class] ? align[@"@type"] : nil;
	if ([kind isEqualToString:@"pageBlockHorizontalAlignmentLeft"])
		return 0;   // NSTextAlignmentLeft
	if ([kind isEqualToString:@"pageBlockHorizontalAlignmentRight"])
		return 2;   // NSTextAlignmentRight on iOS
	return 1;       // NSTextAlignmentCenter
}

/// "Wrong layout?" opens the bot the feedback link names with its start
/// parameter (official InstantPageFeedbackNode: t.me/previews?start=webpageN).
static inline NSString *TGInstantFeedbackURL(NSDictionary *link) {
	if (![link isKindOfClass:NSDictionary.class] ||
			![link[@"@type"] isEqualToString:@"internalLinkTypeBotStart"] ||
			![link[@"bot_username"] length])
		return nil;
	NSString *start = [link[@"start_parameter"] isKindOfClass:NSString.class] ? link[@"start_parameter"] : @"";
	return start.length
			? [NSString stringWithFormat:@"https://t.me/%@?start=%@", link[@"bot_username"], start]
			: [NSString stringWithFormat:@"https://t.me/%@", link[@"bot_username"]];
}
