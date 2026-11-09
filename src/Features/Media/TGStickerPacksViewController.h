//
// TGStickerPacksViewController - the shelf behind Settings: packs this
// account owns, the public packs Telegram is recommending, the custom emoji
// shelves and the greeting stickers. Also the way into the pack editor.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"
#import "TGLocalization.h"

@interface TGStickerPacksViewController : TGRowsViewController @end

/// A pack's title, with the shelf's own name when the server sent none.
static inline NSString *TGStickerPackRowTitle(NSDictionary *set,
		NSString *fallback) {
	NSString *title = set[@"title"];
	return title.length ? title : fallback;
}

static inline NSString *TGStickerPackCountText(NSUInteger count) {
	return TGLocalizedPluralValue(@"%@ sticker", @"%@ stickers",
			[NSString stringWithFormat:@"%lu", (unsigned long)count],
			(NSInteger)count);
}

static inline NSString *TGStickerPackTypeWord(NSString *type) {
	if ([type isEqualToString:@"stickerTypeCustomEmoji"] ||
		[type isEqualToString:@"customEmoji"])
		return TGLocalized(@"custom emoji");
	if ([type isEqualToString:@"stickerTypeMask"] ||
		[type isEqualToString:@"mask"])
		return TGLocalized(@"masks");
	return TGLocalized(@"regular");
}

static inline NSString *TGStickerPackOwnedDetail(NSDictionary *set) {
	NSUInteger count = (NSUInteger)[set[@"count"] unsignedIntegerValue];
	return [NSString stringWithFormat:@"%@  ·  %@  ·  %@",
			set[@"shortName"] ?: @"-", TGStickerPackCountText(count),
			TGStickerPackTypeWord(set[@"stickerType"])];
}

static inline NSString *TGStickerPackTrendingDetail(NSDictionary *set) {
	NSUInteger count = (NSUInteger)[set[@"count"] unsignedIntegerValue];
	NSString *installed = [set[@"installed"] boolValue]
			? [NSString stringWithFormat:@"  ·  %@", TGLocalized(@"installed")]
			: @"";
	return [NSString stringWithFormat:@"%@%@",
			TGStickerPackCountText(count), installed];
}

static inline NSString *TGStickerPackArchivedDetail(NSDictionary *set) {
	NSUInteger count = (NSUInteger)[set[@"count"] unsignedIntegerValue];
	return [NSString stringWithFormat:@"%@  ·  %@", set[@"shortName"] ?: @"-",
			TGStickerPackCountText(count)];
}

static inline NSString *TGStickerPacksShelfDetail(NSArray *stickers) {
	return stickers.count ? TGStickerPackCountText(stickers.count)
			: TGLocalized(@"No Results");
}

/// Every section's row titles, in the order the shelf draws them. Empty
/// sections keep their one placeholder row; an installed list is never empty
/// on screen because the placeholder replaces it.
static inline NSArray *TGStickerPacksRowTitles(NSArray *owned,
		NSArray *trending, NSArray *archived, NSArray *recent,
		NSArray *favorites) {
	NSMutableArray *ownedTitles = [NSMutableArray array];
	if (!owned.count)
		[ownedTitles addObject:TGLocalized(@"No Stickers Found")];
	for (NSDictionary *set in owned)
		[ownedTitles addObject:TGStickerPackRowTitle(set,
				TGLocalized(@"Stickers"))];

	NSMutableArray *trendingTitles = [NSMutableArray array];
	if (!trending.count)
		[trendingTitles addObject:TGLocalized(@"No Results")];
	for (NSDictionary *set in trending)
		[trendingTitles addObject:TGStickerPackRowTitle(set,
				TGLocalized(@"Trending Stickers"))];

	NSMutableArray *archivedTitles = [NSMutableArray array];
	if (!archived.count)
		[archivedTitles addObject:TGLocalized(@"No Results")];
	for (NSDictionary *set in archived)
		[archivedTitles addObject:TGStickerPackRowTitle(set,
				TGLocalized(@"Archived Stickers"))];

	return @[
		@[TGLocalized(@"New Sticker Set"), TGLocalized(@"Search Stickers"),
		  TGLocalized(@"Clear Recent Stickers")],
		ownedTitles,
		trendingTitles,
		@[TGLocalized(@"Add Icons To Profile"),
		  TGLocalized(@"Add Icons To Replies"),
		  TGLocalized(@"Background Emoji"), TGLocalized(@"Search Emoji")],
		@[TGLocalized(@"Stickers")],
		@[TGLocalized(@"Recently Used"), TGLocalized(@"Favorites")],
		archivedTitles,
	];
}
