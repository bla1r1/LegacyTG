//
// TGChatListRowGeometry.h - the trailing accessories of a chat list row.
//
// The unread count and the pin marker are two objects on the same line, and
// Telegram draws both: a pinned chat that also has unread messages used to
// lose its pin because the count was placed where the pin went. Keeping the
// arithmetic here lets the host suite prove the two never overlap; TGChatRowCell
// has no honest way to be measured without a live UIKit hierarchy.
//
#ifndef TGCHATLISTROWGEOMETRY_H
#define TGCHATLISTROWGEOMETRY_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class UIView;

#ifdef __cplusplus
extern "C" {
#endif

/// The archive row's second line: "1 chat" never reads "1 chats". Singular
/// plural is the one bit of Telegram's wording this row has to get right, and
/// the archive is the only row whose count can be one.
NSString *TGChatListArchiveSubtitle(NSUInteger count);

/// The notice over the chat list from TDLib's suggested actions (rows of
/// {title, action}), as official ChatListNoticeItem: "setupPassword" (no
/// close) or "premiumGrace" (closable, opens the subscription page). Keys:
/// kind, title, text, url (may be absent), closable, action. Nil for none.
NSDictionary *TGChatListNotice(NSArray *suggestedRows);

/// Frames for the badge and the pin at the trailing edge of the row's second
/// line, and where the preview has to stop.
///
/// The badge keeps the corner; the pin sits to its left, which is the order
/// Telegram uses (count at the edge, pin beside it). Both frames are
/// CGRectZero when their flag is NO. `previewRight` is the left edge of the
/// first accessory minus `gap`, so a preview is never drawn underneath one.
void TGChatListRowAccessories(CGFloat rightEdge,
                              CGFloat top,
                              BOOL hasBadge,
                              CGFloat badgeWidth,
                              CGFloat badgeHeight,
                              BOOL hasPin,
                              CGFloat pinSide,
                              CGFloat gap,
                              CGRect *badgeFrame,
                              CGRect *pinFrame,
                              CGFloat *previewRight);

/// The chats a stopped scroll needs pictures for: one row behind it, for the
/// archive row that shifts the list by one, and `rows` from there on.
NSRange TGAvatarWindow(NSInteger firstVisible, NSUInteger rows, NSUInteger total);

/// The scroll that opens the main list on the chats: past the table header
/// (search field, expanded stories, folder pills) and, when it is the first
/// row, the archive row. Official Telegram opens with both hidden; a pull
/// down brings them back.
CGFloat TGChatListParkOffset(CGFloat headerHeight, NSArray *headerRows,
                             CGFloat archiveRowHeight);

/// Bottom inset that lets a short list still scroll to the park. Without it
/// a list shorter than the screen (any iPad, a new account) cannot scroll and
/// the search field and archive stay on screen.
CGFloat TGChatListParkBottomInset(CGFloat contentHeight, CGFloat boundsHeight,
                                  CGFloat parkOffset);

/// The list row of the chat open in the iPad detail pane, or NSNotFound.
/// Saved Messages is its own header row; other chats sit after the header
/// rows. The split keeps the open chat highlighted, as official does, so
/// every reload has to find the row again: reloadData drops the selection.
NSInteger TGChatListActiveRow(int64_t activeId, int64_t savedId,
                              NSArray *headerRows, NSArray *chats);

/// Whether a chat row has to ask for its avatar. Only a miss does: a cached
/// one is already drawn, and asking anyway reloads the table from inside
/// the table's own reload.
BOOL TGChatListNeedsAvatarLoad(BOOL savedMessages, int64_t chatId, BOOL cached);

/// The preview's custom emoji ranges reduced to plain numbers for the launch
/// snapshot: { offset, length, customEmojiId } from either row shape, nil
/// entries dropped. Without them the first paint drew fallback characters.
NSArray *TGSnapshotCustomEmoji(id value);

/// Checks whether a swipe pan gesture should begin given horizontal and vertical displacement
/// and velocity. Pure function so swipe gesture initiation can be unit tested without UIKit touches.
BOOL TGChatListSwipeGestureShouldBegin(CGPoint delta, CGPoint velocity);

/// Checks whether a touch view hierarchy belongs to an action button rather than
/// the row's content view or cell background, preventing dismiss gesture intercept.
BOOL TGChatListIsTouchInsideActionButton(UIView *view, UIView *cellContentView);

/// Converts modern or unsupported emoji characters (e.g. 🥳, 🥺, 🥑, 🦖) to clean,
/// renderable iOS 6 fallback emojis (🎉, 😊, 🍏, 🐊) so tofu boxes (□□□□) never render.
NSString *TGChatListSafeEmojiFallback(NSString *emoji);

#ifdef __cplusplus
}
#endif

#endif // TGCHATLISTROWGEOMETRY_H
