//
// TGClient+TextStyles.m - the text composition styles wire.
//
// Telegram has no getTextCompositionStyles: the used list arrives whole in
// updateTextCompositionStyles and changes only through the calls below. The
// cache is therefore the list, and every call patches it with the answer so
// a manager opened twice does not show a stale row.
//
#import "TGClient+TextStyles.h"
#import "TGClientInternal.h"

/// One textCompositionStyle, with the example made optional because the
/// list update never carries it.
static NSDictionary *TGTextStyleRow(NSDictionary *style) {
	if (![style isKindOfClass:NSDictionary.class])
		return nil;
	NSString *name = style[@"name"];
	if (![name isKindOfClass:NSString.class] || !name.length)
		return nil;
	return @{
		@"name"         : name,
		@"title"        : style[@"title"] ?: name,
		@"emojiId"      : style[@"custom_emoji_id"] ?: @(0),
		@"isCustom"     : @([style[@"is_custom"] boolValue]),
		@"isCreator"    : @([style[@"is_creator"] boolValue]),
		@"installCount" : style[@"install_count"] ?: @(0),
		@"prompt"       : style[@"prompt"] ?: @"",
		@"creatorUserId": style[@"creator_user_id"] ?: @(0),
	};
}

@implementation TGClient (TextStyles)

/// The update is the whole used list, not a delta: a style added on another
/// client appears and one removed disappears without a request from here.
- (void)applyTextCompositionStylesUpdate:(NSDictionary *)update {
	NSMutableArray *rows = [NSMutableArray array];
	NSArray *styles = update[@"styles"];
	if ([styles isKindOfClass:NSArray.class])
		for (NSDictionary *style in styles){
			NSDictionary *row = TGTextStyleRow(style);
			if (row)
				[rows addObject:row];
		}
	self.textCompositionStylesValue = rows;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGTextCompositionStylesChangedNotification
						  object:self];
}

/// The list is one unit: a style edited or added is replaced by name, and a
/// style deleted disappears. Keeping the order Telegram sent matters - the
/// composer shows it in that order.
@end
