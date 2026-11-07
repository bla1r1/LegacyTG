//
// TGMessageCard - what a card bubble shows, built from a flattened message
// row. One card draws invoices, gifts, giveaways and their winners, games,
// shared chats and users, group calls and stories, so they look alike and
// cost one view in the chat cell.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, TGMessageCardAction) {
	TGMessageCardActionNone = 0,
	TGMessageCardActionPay,          ///< open the invoice
	TGMessageCardActionOpenChat,     ///< actionTargetId is a chat id
	TGMessageCardActionOpenUser,     ///< actionTargetId is a user id
	TGMessageCardActionJoinCall,     ///< actionTargetId is a group call id
	TGMessageCardActionPlayGame,
	TGMessageCardActionOpenStory,    ///< actionTargetId is the story id, actionChatId the poster
	TGMessageCardActionOpenGiveaway, ///< actionTargetId is the giveaway message id
	TGMessageCardActionViewGift,
};

@interface TGMessageCard : NSObject
/// The small accent line on top: "Giveaway", "Gift", "Invoice", "Video chat".
@property (nonatomic, copy) NSString *kicker;
/// The bold line. Never empty for a card that exists.
@property (nonatomic, copy) NSString *title;
/// Up to four detail lines in reading order; empty array for none.
@property (nonatomic, copy) NSArray *lines;
/// A TDLib file id to show as the card's picture, or 0 for none.
@property (nonatomic, assign) int64_t imageFileId;
/// Width over height of that picture; 1 for stickers and avatars.
@property (nonatomic, assign) CGFloat imageAspect;
/// Draw the picture as a circle (people, chats).
@property (nonatomic, assign) BOOL imageIsRound;
/// The button under the lines, or nil for none ("Pay $4.99", "Join", "Play").
@property (nonatomic, copy) NSString *buttonTitle;
@property (nonatomic, assign) TGMessageCardAction action;
@property (nonatomic, assign) int64_t actionTargetId;
@property (nonatomic, assign) int64_t actionChatId;
@end

/// The card for a flattened message row (TGFlattenMessage output, with the
/// "invoice", "gift", "upgradedGift", "giveaway", "giveawayWinners",
/// "game", "sharedUsers", "sharedChat", "groupCall", "story" keys), or nil
/// when the row is no card. Foundation only: safe off the main thread.
FOUNDATION_EXPORT TGMessageCard *TGMessageCardForRow(NSDictionary *row);
