//
// TGPinnedLine.m - quote the pinned message in the pin service line.
//
// The service text is built in Core before the chat has loaded the message it
// names, so the substitution belongs here: display time, once the message is
// in the list. Foundation only, so the layout and the cell share one string.
//
#import "TGPinnedLine.h"

/// How much of the pinned text the line shows before the ellipsis.
static const NSUInteger TGPinnedLineLimit = 20;

static NSString *TGPinnedLineKindWord(NSString *kind) {
	if ([kind isEqualToString:@"messagePhoto"])
		return @"a photo";
	if ([kind isEqualToString:@"messageVideo"])
		return @"a video";
	if ([kind isEqualToString:@"messageVoiceNote"])
		return @"a voice message";
	if ([kind isEqualToString:@"messageSticker"] ||
			[kind isEqualToString:@"messageAnimatedEmoji"])
		return @"a sticker";
	if ([kind isEqualToString:@"messagePoll"])
		return @"a poll";
	if ([kind isEqualToString:@"messageDocument"])
		return @"a file";
	return nil;
}

NSString *TGPinnedLine(NSString *serviceText, NSDictionary *pinned) {
	if (![serviceText isKindOfClass:NSString.class])
		return serviceText;
	if (![pinned isKindOfClass:NSDictionary.class])
		return serviceText;

	static NSString *const suffix = @"a message";
	static NSString *const marker = @"\u200B";
	BOOL isPinnedLine = [serviceText hasSuffix:marker] ||
			[serviceText hasSuffix:suffix];
	if (!isPinnedLine)
		return serviceText;
	if ([serviceText hasSuffix:marker])
		serviceText = [serviceText substringToIndex:serviceText.length - 1];

	BOOL replacesSuffix = [serviceText hasSuffix:suffix];

	id raw = pinned[@"text"];
	NSString *text = [raw isKindOfClass:NSString.class] ? raw : @"";
	text = [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	NSString *quoted = nil;
	if (text.length) {
		NSString *shown = text;
		BOOL cut = text.length > TGPinnedLineLimit;
		if (cut) {
			// Count composed characters so a surrogate pair or an emoji with
			// modifiers is never split in half.
			NSRange range = [text rangeOfComposedCharacterSequencesForRange:
					NSMakeRange(0, TGPinnedLineLimit)];
			shown = [text substringToIndex:range.length];
		}
		quoted = cut
				? [NSString stringWithFormat:@"\"%@...\"", shown]
				: [NSString stringWithFormat:@"\"%@\"", shown];
	} else {
		NSString *kind = [pinned[@"kind"] isKindOfClass:NSString.class]
				? pinned[@"kind"] : @"";
		quoted = TGPinnedLineKindWord(kind);
	}
	if (!quoted.length)
		return serviceText;

	if (!replacesSuffix)
		return [serviceText stringByAppendingFormat:@": %@", quoted];
	return [[serviceText substringToIndex:serviceText.length - suffix.length]
			stringByAppendingString:quoted];
}
