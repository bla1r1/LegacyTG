//
// TGClient+Stickers.m - sticker sets, favourites, saved GIFs and GIF search
// for the emoji / sticker / GIF panel.
//
#import "TGClientInternal.h"
#import "TGStickerPack.h"

/// One sticker as the panel wants it: what to send, and what to draw in the
/// grid. The thumbnail is drawn only when it is a still picture; a .tgs or
/// .webm thumbnail is left to the emoji beside it.
NSDictionary *TGStickerInfo(NSDictionary *sticker) {
	if (![sticker isKindOfClass:NSDictionary.class])
		return nil;
	NSNumber *fileId = sticker[@"sticker"][@"id"];
	if (!fileId)
		return nil;
	NSString *format = sticker[@"format"][@"@type"] ?: @"";
	BOOL webp = [format isEqualToString:@"stickerFormatWebp"];

	NSDictionary *thumbnail = sticker[@"thumbnail"];
	NSString *thumbFormat = thumbnail[@"format"][@"@type"] ?: @"";
	NSNumber *thumbId = thumbnail[@"file"][@"id"];
	BOOL thumbIsPicture = [thumbFormat isEqualToString:@"thumbnailFormatWebp"] ||
						  [thumbFormat isEqualToString:@"thumbnailFormatJpeg"] ||
						  [thumbFormat isEqualToString:@"thumbnailFormatPng"];
	if (!thumbId || !thumbIsPicture){
		// A plain WebP sticker is its own thumbnail.
		thumbId = webp ? fileId : @0;
	}
	return @{
		@"fileId"     : fileId,
		@"emoji"      : sticker[@"emoji"] ?: @"",
		@"isAnimated" : @(!webp),
		@"thumbId"    : thumbId ?: @0,
		@"width"      : sticker[@"width"] ?: @512,
		@"height"     : sticker[@"height"] ?: @512,
	};
}

/// The panel's sticker rows, held as one flat POD buffer rather than a
/// dictionary per sticker - TGStickerPack is itself an NSArray, so nothing
/// downstream changes. See TGStickerPack.h for what that costs and saves.
static NSArray *TGStickerList(NSArray *stickers) {
	return [TGStickerPack packWithTDLibStickers:stickers];
}

@implementation TGClient (Stickers)

/// stickerSetInfo down to the three things a row needs. Shared by the
/// installed list, the search and the trending list, which all answer with
/// the same shape. The count, the flags and the short name ride along, which
/// is what an install sheet - and a refusal for an installed pack - needs.
NSArray *TGFlattenStickerSets(NSArray *sets) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *set in sets){
		if (![set isKindOfClass:NSDictionary.class] || !set[@"id"])
			continue;
		NSArray *covers = TGStickerList(set[@"covers"]);
		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		info[@"id"] = set[@"id"];
		info[@"title"] = set[@"title"] ?: @"";
		info[@"count"] = set[@"count"] ?: @(0);
		info[@"installed"] = @([set[@"is_installed"] boolValue]);
		info[@"archived"] = @([set[@"is_archived"] boolValue]);
		info[@"owned"] = @([set[@"is_owned"] boolValue]);
		// td_api settled on "name"; older fixtures and the search answer
		// this file has always read use "short_name". Both are the same
		// string, and a pack with neither is unnamed rather than wrong.
		info[@"shortName"] = set[@"name"] ?: (set[@"short_name"] ?: @"");
		// The editor and the group picker have to tell a custom emoji pack
		// from an ordinary one; the type is the only field that does it.
		info[@"stickerType"] = set[@"sticker_type"][@"@type"] ?: @"stickerTypeRegular";
		if (covers.count)
			info[@"cover"] = covers.firstObject;
		[out addObject:info];
	}
	return out;
}

/// Stickers for an emoji, from the sets this account has installed. Their
/// panel does this as you type an emoji into the composer; here it is what
/// the sticker tab's search asks for.
/// The same, but across every public set rather than the installed ones -
/// which is the half that finds something new.
/// Sets by name, for finding one that is not installed. Entries are the same
/// shape -installedStickerSets answers with: "id", "title", "cover".
/// What is popular now, which is the other half of finding a new set.
/// A pack by the name a t.me/addstickers link carries. The record Telegram
/// answers with carries everything the sheet needs - the id to install by,
/// the count, and whether the account already has it.
- (void)stickerSetByShortName:(NSString *)shortName
				   completion:(void (^)(NSDictionary *set))completion {
	if (!shortName.length){
		if (completion) completion(nil);
		return;
	}
	[self request:@{
		@"@type"  : @"getStickerSet",
		@"set_id" : @{@"@type" : @"inputStickerSetShortName",
					  @"short_name" : shortName},
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		if (![result[@"@type"] isEqualToString:@"stickerSet"] || !result[@"id"]){
			completion(nil);
			return;
		}
		NSArray *flattened = TGFlattenStickerSets(@[result]);
		completion(flattened.firstObject);
	}];
}

- (void)setSticker:(NSInteger)fileId favourite:(BOOL)favourite {
	if (fileId <= 0)
		return;
	// Answered rather than fire-and-forget: a refused favourite is otherwise
	// silent, and "nothing happened" is the hardest kind of bug to chase.
	[self request:@{@"@type"   : favourite ? @"addFavoriteSticker" : @"removeFavoriteSticker",
					@"sticker" : @{@"@type" : @"inputFileId", @"id" : @(fileId)}}
	   completion:^(NSDictionary *result){
		NSLog(@"TGClient: %@ favourite %ld -> %@", favourite ? @"add" : @"remove",
				(long)fileId, result[@"@type"]);
	}];
}

- (void)setStickerSet:(id)setId installed:(BOOL)installed archived:(BOOL)archived {
	if (!setId)
		return;
	// Answered rather than fire-and-forget: a declined removal is otherwise
	// silent, and "nothing happened" is the hardest kind of bug to chase.
	[self request:@{@"@type"        : @"changeStickerSet",
					@"set_id"       : setId,
					@"is_installed" : @(installed),
					@"is_archived"  : @(archived)}
	   completion:^(NSDictionary *result){
		NSLog(@"TGClient: change set %@ (installed %d, archived %d) -> %@",
				setId, installed, archived, result[@"@type"]);
	}];
}

/// Installed sets whose titles match. Their own client reaches for this when
/// the search says the word and the answer is a pack the account already has.
/// The archived shelf is where a set deleted by accident survives, so this
/// is the second half the "Remove from Recent"-style removal needs.
/// The sticker sets a piece of media carries. TDLib names them by the media
/// file's own id, which is what a bubble already has; this is how a photo
/// with stickers on it says which packs they came from.
/// GIF search is the @gif inline bot, which every client uses for it. Its
/// results are sent as inline results so the message credits the bot.
#pragma mark - authoring a pack

/// A sticker type from the word the editor shows.
static NSDictionary *TGStickerType(NSString *name) {
	NSString *type = @"stickerTypeRegular";
	if ([name isEqualToString:@"mask"])
		type = @"stickerTypeMask";
	else if ([name isEqualToString:@"customEmoji"])
		type = @"stickerTypeCustomEmoji";
	return @{@"@type" : type};
}

/// One TDLib sticker with the two ids the flat pack drops: the custom emoji
/// it stands for and the set it belongs to. Used only by the custom emoji
/// screens, where those ids are the whole point.
NSArray *TGCustomEmojiStickerList(NSArray *stickers) {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *sticker in stickers){
		if (![sticker isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *info = TGStickerInfo(sticker);
		if (!info)
			continue;
		NSMutableDictionary *row = [info mutableCopy];
		// TDLib writes int64 either as a JSON number or as a string when it
		// is too large for a double; both become one NSNumber here so the
		// same id can be passed straight back to a request.
		row[@"customEmojiId"] = @([sticker[@"full_type"][@"custom_emoji_id"]
				longLongValue]);
		row[@"setId"] = @([sticker[@"set_id"] longLongValue]);
		row[@"format"] = sticker[@"format"][@"@type"] ?: @"";
		[out addObject:row];
	}
	return out;
}

#pragma mark - emoji metadata and outlines

- (void)allStickerEmojisForQuery:(NSString *)query
						  chatId:(int64_t)chatId
					 stickerType:(NSString *)type
						mainOnly:(BOOL)mainOnly
					  completion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getAllStickerEmojis",
					@"sticker_type" : TGStickerType(type),
					@"query" : query ?: @"",
					@"chat_id" : @(chatId),
					@"return_only_main_emoji" : @(mainOnly)}
	   completion:^(NSDictionary *result){
		if (completion) completion(result[@"emojis"] ?: @[]);
	}];
}

#pragma mark - emoji panel and reactions

/// One category row as the strip reads it. Telegram's source is either a
/// search list or a premium shelf; the panel draws the first and has nothing
/// this account can open for the second, so both are handed over with the
/// kind that says which. The icon is a custom emoji sticker: its "emoji"
/// field is the only part a phone without custom-emoji rendering can draw.
- (void)emojiCategoriesWithCompletion:(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getEmojiCategories",
					@"type" : [NSNull null]}
	   completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *category in result[@"categories"]){
			if (![category isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *source = category[@"source"];
			if (![source isKindOfClass:NSDictionary.class])
				source = @{};
			NSArray *emojis = [source[@"emojis"] isKindOfClass:NSArray.class]
					? source[@"emojis"] : @[];
			NSDictionary *iconInfo = [category[@"icon"] isKindOfClass:NSDictionary.class]
					? category[@"icon"] : nil;
			NSString *icon = iconInfo[@"emoji"];
			if (!icon.length && emojis.count)
				icon = emojis.firstObject;
			[out addObject:@{
				@"name"   : category[@"name"] ?: @"",
				@"icon"   : icon ?: @"",
				@"kind"   : source[@"@type"] ?: @"",
				@"emojis" : emojis,
			}];
		}
		if (completion) completion(out);
	}];
}

/// searchEmojis answers emojiKeyword rows, one per (emoji, keyword) pair, so
/// the same glyph repeats. The grid wants glyphs, once, in TDLib's order.
- (void)searchEmojis:(NSString *)text
       languageCodes:(NSArray *)languageCodes
          completion:(void (^)(NSArray *))completion {
	if (!text.length){
		if (completion) completion(@[]);
		return;
	}
	[self request:@{@"@type"                 : @"searchEmojis",
					@"text"                  : text,
					@"input_language_codes"  : languageCodes ?: @[]}
	   completion:^(NSDictionary *result){
		NSMutableArray *out = [NSMutableArray array];
		NSMutableSet *seen = [NSMutableSet set];
		for (NSDictionary *row in result[@"emoji_keywords"]){
			NSString *emoji = row[@"emoji"];
			if (![emoji isKindOfClass:NSString.class] || !emoji.length ||
				[seen containsObject:emoji])
				continue;
			[seen addObject:emoji];
			[out addObject:emoji];
		}
		if (completion) completion(out);
	}];
}

- (void)keywordEmojis:(NSString *)text
        languageCodes:(NSArray *)languageCodes
           completion:(void (^)(NSArray *))completion {
	if (!text.length){
		if (completion) completion(@[]);
		return;
	}
	[self request:@{@"@type"                 : @"getKeywordEmojis",
					@"text"                  : text,
					@"input_language_codes"  : languageCodes ?: @[]}
	   completion:^(NSDictionary *result){
		NSArray *emojis = [result[@"emojis"] isKindOfClass:NSArray.class]
				? result[@"emojis"] : @[];
		if (completion) completion(emojis);
	}];
}

- (void)emojiSuggestionsUrlForLanguage:(NSString *)languageCode
                            completion:(void (^)(NSString *))completion {
	NSString *code = languageCode.length ? languageCode
			: ([[NSLocale preferredLanguages] firstObject] ?: @"en");
	[self request:@{@"@type"          : @"getEmojiSuggestionsUrl",
					@"language_code"  : code}
	   completion:^(NSDictionary *result){
		NSString *url = [result[@"@type"] isEqualToString:@"error"]
				? @"" : (result[@"url"] ?: @"");
		if (completion) completion(url);
	}];
}

/// The animation Telegram names first is the one to play; the field order
/// here follows how a reaction is shown - centre, then appear, then select.
static NSDictionary *TGReactionAnimation(NSDictionary *reaction) {
	NSArray *names = @[@"center_animation", @"appear_animation",
					   @"select_animation", @"activate_animation",
					   @"effect_animation", @"around_animation"];
	for (NSString *name in names){
		NSDictionary *info = TGStickerInfo(reaction[name]);
		if (info)
			return info;
	}
	return nil;
}

- (void)emojiReactionForEmoji:(NSString *)emoji
                  completion:(void (^)(NSDictionary *))completion {
	if (!emoji.length){
		if (completion) completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getEmojiReaction", @"emoji" : emoji}
	   completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(nil);
			return;
		}
		NSDictionary *animation = TGReactionAnimation(result);
		NSDictionary *staticIcon = TGStickerInfo(result[@"static_icon"]);
		NSMutableDictionary *row = [NSMutableDictionary dictionary];
		row[@"emoji"]   = result[@"emoji"] ?: emoji;
		row[@"title"]   = result[@"title"] ?: @"";
		row[@"active"]  = @([result[@"is_active"] boolValue]);
		if (animation) row[@"animation"] = animation;
		if (staticIcon) row[@"static"] = staticIcon;
		if (completion) completion(row);
	}];
}

- (void)animatedEmojiForEmoji:(NSString *)emoji
                  completion:(void (^)(NSDictionary *))completion {
	if (!emoji.length){
		if (completion) completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getAnimatedEmoji", @"emoji" : emoji}
	   completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"]){
			if (completion) completion(nil);
			return;
		}
		NSDictionary *info = TGStickerInfo(result[@"sticker"]);
		if (!info){
			if (completion) completion(nil);
			return;
		}
		NSMutableDictionary *row = [info mutableCopy];
		NSDictionary *sound = [result[@"sound"] isKindOfClass:NSDictionary.class]
				? result[@"sound"] : nil;
		row[@"soundId"] = sound[@"id"] ?: @0;
		row[@"fitzpatrick"] = result[@"fitzpatrick_type"] ?: @0;
		row[@"regularEmoji"] = result[@"is_regular_emoji"] ?: @NO;
		if (completion) completion(row);
	}];
}

- (void)customEmojiReactionAnimationsWithCompletion:
		(void (^)(NSArray *))completion {
	[self request:@{@"@type" : @"getCustomEmojiReactionAnimations"}
	   completion:^(NSDictionary *result){
		NSArray *stickers = [result[@"stickers"] isKindOfClass:NSArray.class]
				? result[@"stickers"] : @[];
		if (completion) completion(TGCustomEmojiStickerList(stickers));
	}];
}

- (void)setDefaultReactionEmoji:(NSString *)emoji
                     completion:(void (^)(BOOL))completion {
	if (!emoji.length){
		if (completion) completion(NO);
		return;
	}
	[self request:@{
		@"@type"         : @"setDefaultReactionType",
		@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji},
	} completion:^(NSDictionary *result){
		BOOL ok = ![result[@"@type"] isEqualToString:@"error"];
		// The update says the same thing later; setting it here keeps the
		// picker that asked from flicking back to the old default first.
		if (ok)
			self.reactionDefaultEmoji = emoji;
		else
			NSLog(@"setDefaultReactionType %@: %@", emoji, result[@"message"]);
		if (completion) completion(ok);
	}];
}

#pragma mark - custom emoji

- (void)customEmojiStickersForIds:(NSArray *)ids
					   completion:(void (^)(NSArray *))completion {
	if (!ids.count){
		if (completion) completion(@[]);
		return;
	}
	[self request:@{@"@type" : @"getCustomEmojiStickers",
					@"custom_emoji_ids" : ids}
	   completion:^(NSDictionary *result){
		if (completion) completion(TGCustomEmojiStickerList(result[@"stickers"]));
	}];
}

- (void)clearRecentStickersAttached:(BOOL)attached {
	[self request:@{@"@type" : @"clearRecentStickers", @"is_attached" : @(attached)}
	   completion:^(NSDictionary *result){
		if ([result[@"@type"] isEqualToString:@"error"])
			NSLog(@"clearRecentStickers: %@", result[@"message"]);
	}];
}

@end

NSDictionary *TGFlattenCustomEmojiSet(NSDictionary *set) {
	if (![set isKindOfClass:NSDictionary.class])
		return nil;
	if ([set[@"@type"] isEqualToString:@"error"])
		return nil;
	NSString *title = [set[@"title"] isKindOfClass:NSString.class] ? set[@"title"] : @"";
	NSMutableArray *emojis = [NSMutableArray array];
	NSArray *stickers = [set[@"stickers"] isKindOfClass:NSArray.class] ? set[@"stickers"] : @[];
	for (NSDictionary *sticker in stickers){
		if (![sticker isKindOfClass:NSDictionary.class])
			continue;
		id ft = sticker[@"full_type"];
		id rawId = [ft isKindOfClass:NSDictionary.class] ? ft[@"custom_emoji_id"] : nil;
		if (!rawId)
			rawId = sticker[@"custom_emoji_id"];
		if (![rawId respondsToSelector:@selector(longLongValue)])
			continue;
		int64_t customEmojiId = [rawId longLongValue];
		if (customEmojiId <= 0)
			continue;
		NSString *emoji = [sticker[@"emoji"] isKindOfClass:NSString.class] ? sticker[@"emoji"] : @"";
		[emojis addObject:@{
			@"customEmojiId" : @(customEmojiId),
			@"emoji"         : emoji
		}];
	}
	return @{
		@"title"  : title,
		@"emojis" : emojis
	};
}

NSArray *TGFlattenCustomEmojiSets(NSArray *sets) {
	if (![sets isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *set in sets){
		NSDictionary *flat = TGFlattenCustomEmojiSet(set);
		if (flat)
			[out addObject:flat];
	}
	return out;
}
