//
// TGComposerText - the composer's text with the custom emoji in it.
//
// The field shows each custom emoji as its fallback emoji (or its picture on
// iOS 7+), so the string alone cannot say which ids the person picked. This
// model follows every edit of the field and keeps the ids where they sit, so
// the message goes out with real custom emoji and not their stand-ins.
// Foundation only.
//
#import <Foundation/Foundation.h>

@interface TGComposerText : NSObject

/// `entities` are TDLib textEntity dictionaries ({offset, length, type});
/// only the custom emoji among them are kept. Nil text means "".
- (instancetype)initWithText:(NSString *)text entities:(NSArray *)entities;

@property (nonatomic, readonly, copy) NSString *text;
/// [{@"offset", @"length", @"customEmojiId"}] in UTF-16 units, sorted by offset.
@property (nonatomic, readonly, copy) NSArray *customEmoji;

/// What the field did on a keystroke, paste or autocorrect: entities after
/// the range shift by the change in length, any entity the range overlaps
/// is dropped (its stand-in was edited, so it is no longer that emoji).
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string;

/// Puts `fallback` at `index` and remembers it as custom emoji `emojiId`.
- (void)insertCustomEmoji:(int64_t)emojiId fallback:(NSString *)fallback atIndex:(NSUInteger)index;

/// The field changed in a way the model could not follow: keep only the
/// entities whose stand-in is still at the same place in `text`.
- (void)resetText:(NSString *)text;

/// {"@type":"formattedText","text":...,"entities":[textEntityTypeCustomEmoji...]}
/// with leading and trailing whitespace trimmed and offsets moved to match.
/// Markdown is not parsed here (TGClient's markdownParsed: does that).
- (NSDictionary *)formattedText;

@end
