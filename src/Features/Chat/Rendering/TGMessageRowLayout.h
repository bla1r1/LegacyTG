//
// TGMessageRowLayout.h - one chat row's frames as a function of the message,
// its neighbours, the width and what the screen has loaded.
//
// This was -layoutForMessage:atRow:, 560 lines inside the chat screen, where
// no host test reached it. The screen still owns the cache, the map card it
// draws for a location and the slow-row report; everything it used to read
// from itself while measuring is a field below.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class TGMessageLayout, TGMessageCard;

@interface TGMessageRowInput : NSObject
@property (nonatomic, copy) NSDictionary *message;
/// The table's width; 0 before the first layout pass means the screen width.
@property (nonatomic, assign) CGFloat tableWidth;
/// The message text size the theme sets.
@property (nonatomic, assign) CGFloat fontSize;
/// Neighbours: first and last of a run from one sender, and a row that
/// continues the album above it with no gap.
@property (nonatomic, assign) BOOL runStart;
@property (nonatomic, assign) BOOL runEnd;
@property (nonatomic, assign) BOOL continuesAlbum;
@property (nonatomic, assign) BOOL isGroup;
/// TGChatCardForRow for rows that may be cards (TGMessageRowWantsCard).
@property (nonatomic, strong) TGMessageCard *card;
/// The picture's size as the screen has it loaded (-imageSizeFor:).
@property (nonatomic, assign) CGSize imageSize;
/// The message this one answers, when loaded, and its author's name.
@property (nonatomic, strong) NSDictionary *replied;
@property (nonatomic, copy) NSString *quoteAuthor;
/// The sender's name in a group, for someone else's message; nil otherwise.
@property (nonatomic, copy) NSString *senderName;
/// The width of TGMessageSenderLine as drawn, emoji status included once it
/// has loaded. Asked only by a plain bubble: measuring is the expensive part.
@property (nonatomic, copy) CGFloat (^senderLineWidth)(NSString *line);
/// Who acted, for a service line; nil for a date or unread separator.
@property (nonatomic, copy) NSString *serviceWho;
/// The loaded messages, for the pin line's quote.
@property (nonatomic, strong) NSArray *messages;
/// A multiple-answer poll's draft answers.
@property (nonatomic, strong) NSIndexSet *pendingVotes;
/// The animated sticker file is on disk and this device plays animations.
@property (nonatomic, assign) BOOL animatedStickerReady;
@end

FOUNDATION_EXPORT TGMessageLayout *TGMessageRowLayout(TGMessageRowInput *input);

/// A location, venue or live location, or any message carrying a latitude.
FOUNDATION_EXPORT BOOL TGMessageIsLocation(NSDictionary *m);

/// Every row but a service line may be a card; a community card is the
/// service line that is one.
FOUNDATION_EXPORT BOOL TGMessageRowWantsCard(NSDictionary *m);

/// The sender line over a bubble: the name, and the sender's tag after a
/// middle dot. Nil for no name.
FOUNDATION_EXPORT NSString *TGMessageSenderLine(NSString *name, NSDictionary *m);

/// The text's size inside a bubble; zero for a sticker or no text.
FOUNDATION_EXPORT CGSize TGMessageBodySize(NSDictionary *m, CGFloat fontSize);

/// A picture with no caption, an album with none, or a caption above the
/// picture carries the stamp on the picture.
FOUNDATION_EXPORT BOOL TGMessageStampOnPicture(NSDictionary *m, CGSize imageSize,
		CGFloat fontSize);
