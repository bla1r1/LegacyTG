//
// TGClient+TextStyles - custom text composition styles: the list Telegram
// streams through updateTextCompositionStyles, and the seven calls that
// create, edit, find, preview, add and remove one.
//
#import "TGClient+Base.h"

@interface TGClient (TextStyles)

/// The styles this account may use, kept live by updateTextCompositionStyles.
/// Each entry: "name", "title", "emojiId", "isCustom", "isCreator",
/// "installCount", "prompt", "creatorUserId".
@property (nonatomic, readonly) NSArray *textCompositionStyles;

/// Creates a style. TDLib answers the whole object, so the screen does not
/// wait for the update to draw it.
/// Telegram's 404 means there is no style by that name. It is returned as an
/// error sentence so the manager can show it rather than an empty row.
/// An example of the style in use. `number` is 0-based; the screen walks it
/// until Telegram answers 404. Keys: "sourceText", "resultText" and the two
/// entity arrays under "sourceEntities" / "resultEntities".
/// Puts the style into the used list the composer's style picker reads.
/// Takes it out again. A style this account created is deleted, not removed.
@end
