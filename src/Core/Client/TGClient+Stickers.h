//
// TGClient+Stickers.h - the client surface for the sticker shelf: installed sets, search, favourites, GIFs.
//
#import "TGClient+Base.h"

@interface TGClient (Stickers)

/// The inline bot GIF search uses. "gif" until updateAnimationSearchParameters
/// names another, which is what keeps the tab working if Telegram moves it.
@property (nonatomic, readonly) NSString *animationSearchProvider;
/// The emoji Telegram suggests for GIF search; empty until that update.
@property (nonatomic, readonly) NSArray *animationSearchEmojis;

/// Installed sets: "id" (pass back as is), "title", and "cover" - a sticker
/// in the same shape recentStickers gives.
/// Add or remove a sticker from Favourites, which is what holding one does.
- (void)setSticker:(NSInteger)fileId favourite:(BOOL)favourite;

/// Drop one sticker out of Recently Used.
/// Uninstall a sticker set, which is what removing a pack means.
/// `archived` with `installed` NO moves it to the archived shelf instead of
/// throwing it away; YES YES puts it back among the installed.
- (void)setStickerSet:(id)setId installed:(BOOL)installed archived:(BOOL)archived;

/// A pack by the name a t.me/addstickers link carries: "id", "title",
/// "count", "shortName", "cover", and "installed" - whether this account
/// already has it. nil when Telegram does not know the name at all.
- (void)stickerSetByShortName:(NSString *)shortName
				   completion:(void (^)(NSDictionary *set))completion;

/// Installed sets whose titles match, for finding a pack the account has.
/// The archived shelf, which is where a set removed by accident survives.
/// The sets attached to one media file - a picture or a video that carries
/// stickers. TDLib answers by file id, the same id the bubble draws.
/// The installed order after a move. `setIds` is the whole list, the
/// first id becoming the first strip slot.
/// Put a GIF in Saved GIFs, and take one out again.
/// GIFs: "fileId", "width", "height", "duration", optional "thumbId" (a
/// still picture) and "minithumbnail" (NSData, a tiny inline JPEG). Search
/// results also carry "queryId" and "resultId".
/// Stickers for an emoji, out of the sets this account has installed.
/// The same across every public set - the half that finds something new.
/// Sets by name. Entries are shaped as -installedStickerSetsWithCompletion:
/// answers: "id", "title", "cover".
#pragma mark - authoring a pack

/// Sets this account owns, all sticker types, shaped as the installed list
/// plus "stickerType" and "name". The editor and the group sticker picker
/// read from here, because only an owned set may be changed.
/// The status word for a name before a pack is made: "ok", "invalid" or
/// "occupied". `message` is a sentence a sheet can show verbatim.
/// What Telegram would call a pack with this title: a lower-case short name
/// with the words joined, which is the suggestion `checkStickerSetName`
/// answers with when the typed one is taken.
/// The short name behind a set id, which the id alone does not carry.
/// A public pack by its short name, with its stickers. Unlike
/// -stickerSetByShortName: this asks Telegram to search rather than fetch a
/// name the caller already knows, and it returns the pack's own name too.
/// Make a pack owned by this account. `stickers` are newSticker dictionaries
/// (see -newStickerWithFileId:format:emojis:keywords:maskPosition:); at least
/// one is required by Telegram. `type` is "regular" or "mask".
/// Delete a pack this account owns.
/// A newSticker record from the pieces the editor has. `maskPosition` may be
/// nil; `keywords` may be empty.
/// Add a sticker, upload a file first, and the two halves of replacing one.
/// Reorder, retag and re-mask a sticker that is already in a pack. Position
/// is zero based.
/// `maskPosition` is a TDLib maskPosition dictionary; nil removes it, which
/// td_api spells as a null mask_position.
/// Rename a pack, or give it a new thumbnail. The thumbnail is a local image
/// file uploaded by TDLib; `format` is "webp", "tgs" or "webm".
/// Upload one sticker file and answer its file id, which is what
/// addStickerToSet and createStickerSet take. A path that cannot be read
/// answers 0 without a request.
#pragma mark - emoji metadata and outlines

/// The emoji a single sticker is filed under, as Telegram stores them.
/// Every emoji matching `query` across the installed sets, or across all
/// public sets when `chatId` is 0. `type` is "regular", "mask" or
/// "customEmoji"; `mainOnly` drops the secondary tags.
- (void)allStickerEmojisForQuery:(NSString *)query
						  chatId:(int64_t)chatId
					 stickerType:(NSString *)type
						mainOnly:(BOOL)mainOnly
					  completion:(void (^)(NSArray *emojis))completion;

/// A sticker's outline as the paths Telegram publishes. The completion gets
/// the number of closed paths and the number of points across them; a sheet
/// shows both without needing a vector renderer.
/// The same outline as one SVG path string, for clipping or for copying.
#pragma mark - emoji panel and reactions

/// Telegram's emoji categories, each as "name", "icon" (the character to draw
/// on the strip), "kind" (emojiCategorySourceSearch or ...Premium) and
/// "emojis" (the list its search source carries). An older TDLib or a phone
/// with no file database answers empty, and the panel keeps its built-in set.
- (void)emojiCategoriesWithCompletion:(void (^)(NSArray *categories))completion;

/// Emoji matching a typed word. TDLib answers emoji-keyword pairs; the
/// duplicates are dropped and the glyph order is kept, which is what a grid
/// needs. `languageCodes` may be empty when the input language is unknown.
- (void)searchEmojis:(NSString *)text
       languageCodes:(NSArray *)languageCodes
          completion:(void (^)(NSArray *emojis))completion;

/// The emoji filed under one keyword, with no keyword rows in the answer.
- (void)keywordEmojis:(NSString *)text
        languageCodes:(NSArray *)languageCodes
           completion:(void (^)(NSArray *emojis))completion;

/// The translation platform's link for suggesting emoji replacements. The
/// link is short lived; it is fetched when the card is opened, not cached.
- (void)emojiSuggestionsUrlForLanguage:(NSString *)languageCode
                            completion:(void (^)(NSString *url))completion;

/// One reaction's title, whether it is active, and the animation Telegram
/// plays for it: "title", "active", "animation" and "static" (sticker rows as
/// TGStickerInfo makes them). nil when Telegram has no such reaction.
- (void)emojiReactionForEmoji:(NSString *)emoji
                  completion:(void (^)(NSDictionary *reaction))completion;

/// The animated version of a plain emoji: a sticker row plus "soundId". nil
/// when the emoji has none, which is most of them.
- (void)animatedEmojiForEmoji:(NSString *)emoji
                   completion:(void (^)(NSDictionary *animated))completion;

/// TGS animations for custom-emoji reactions, shaped as the sticker list.
- (void)customEmojiReactionAnimationsWithCompletion:
		(void (^)(NSArray *stickers))completion;

/// Empty the server's recently used reactions, which is the order the picker
/// starts from. Answered so the settings row can say it landed.
/// Make one emoji the reaction the bar leads with, on every device.
- (void)setDefaultReactionEmoji:(NSString *)emoji
                     completion:(void (^)(BOOL ok))completion;

#pragma mark - custom emoji

/// Custom emoji stickers by their ids, shaped as the sticker list plus
/// "customEmojiId". A chat that shows an emoji in text carries the id.
- (void)customEmojiStickersForIds:(NSArray *)ids
					   completion:(void (^)(NSArray *stickers))completion;

/// The three default shelves Telegram ships: what a profile photo, a chat
/// photo and a background may use.
/// Stickers Telegram suggests for greeting messages.
/// Give a custom emoji pack one of its emoji as its thumbnail.
/// Tell Telegram the trending shelf was shown, which is what stops the same
/// packs being recommended again. The ids are the ones the shelf carries.
/// Empty Recently Used. `attached` clears the half used inside messages
/// instead of the ordinary shelf.
- (void)clearRecentStickersAttached:(BOOL)attached;

/// Custom emoji packs installed on this account, each shaped as:
/// @{@"title": NSString, @"emojis": @[@{@"customEmojiId": NSNumber, @"emoji": NSString}]}
@end

#ifdef __cplusplus
extern "C" {
#endif

/// Flattens a TDLib stickerSet dictionary into @{@"title": NSString, @"emojis": @[@{@"customEmojiId": NSNumber, @"emoji": NSString}]}.
NSDictionary *TGFlattenCustomEmojiSet(NSDictionary *set);
NSArray *TGFlattenCustomEmojiSets(NSArray *sets);

#ifdef __cplusplus
}
#endif
