//
// TGStoryText.h - TDLib story state names as the nouns the official sheet
// shows. Pure, so the mappings can be host-tested without a story request.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"
#import "TGRows.h"

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

/// The story sheet's date, in the app language rather than the phone's: a
/// Russian UI must not print an English month. Pure enough for the host test.
static inline NSString *TGStoryDateText(NSNumber *unixTime) {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		formatter = [[NSDateFormatter alloc] init];
		[formatter setDateStyle:NSDateFormatterMediumStyle];
		[formatter setTimeStyle:NSDateFormatterShortStyle];
	});
	if (![unixTime isKindOfClass:NSNumber.class] || unixTime.doubleValue <= 0)
		return @"-";
	NSString *language = TGAppLanguage();
	formatter.locale = language.length
			? [NSLocale localeWithLocaleIdentifier:language]
			: [NSLocale currentLocale];
	return [formatter stringFromDate:
			[NSDate dateWithTimeIntervalSince1970:unixTime.doubleValue]];
}

/// One line of the story sheet: a title, an optional detail under it and a
/// tap when the row opens another page.
static inline NSMutableDictionary *TGStoryInfoRowModel(NSString *title,
													   NSString *detail,
													   void (^tap)(void)) {
	NSMutableDictionary *row = [TGSubtitleRow(title, detail, tap) mutableCopy];
	row[TGRowDetailLines] = @4;
	return row;
}

/// The fixed block at the top of the sheet, in the order the official info
/// screen lists it. Interactions, forwards and statistics are appended by the
/// screen as their pages answer.
static inline NSArray *TGStoryInfoRowsModel(NSDictionary *story,
											BOOL reportMode) {
	story = [story isKindOfClass:NSDictionary.class] ? story : @{};
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Posted Stories"),
			TGStoryDateText(story[@"date"]), nil)];
	[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Views"),
			[NSString stringWithFormat:@"%@", story[@"viewers"] ?: @(0)], nil)];
	[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Forwarded Messages"),
			[NSString stringWithFormat:@"%@", story[@"forwards"] ?: @(0)], nil)];
	[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Reactions"),
			[NSString stringWithFormat:@"%@", story[@"reactions"] ?: @(0)], nil)];
	[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Privacy"),
			TGStoryPrivacyNoun(story[@"privacy"]), nil)];
	[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Chat"),
			[story[@"isPostedToChatPage"] boolValue]
					? TGLocalized(@"Yes") : TGLocalized(@"No"), nil)];
	if (!reportMode){
		[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Interactions"),
				nil, nil)];
		[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Forwarded Messages"),
				nil, nil)];
		[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Statistics"),
				nil, nil)];
		[rows addObject:TGStoryInfoRowModel(TGLocalized(@"Report Story"),
				nil, nil)];
	}
	return rows;
}
