//
// TGMessageCellFactory.h - which message element a chat row is.
//
// The message list stays its own table, not TGRows: it is the one list where a
// row is a message, which is why its cells are an element family rather than a
// row kind. The chat screen asks this factory for every row; the factory
// chooses the bubble, the service plate, the day header or the unread band and
// configures it from the prebuilt TGMessageLayout record and the theme. The
// chat then supplies the message-specific data (media, replies, reactions);
// layout itself stays precomputed and cached by the chat.
//
#import <Foundation/Foundation.h>

@class UITableView;
@class UITableViewCell;
@class TGMessageLayout;

typedef NS_ENUM(NSInteger, TGMessageCellKind) {
	TGMessageCellKindBubble = 0,
	TGMessageCellKindService,
	TGMessageCellKindDateHeader,
	TGMessageCellKindUnreadSeparator,
};

/// The element this message needs. Pure: it reads the resolved flags of the
/// layout record (and the separator spelling as a fallback) without touching
/// UIKit, so the choice is testable on the host.
FOUNDATION_EXPORT TGMessageCellKind TGMessageCellKindForMessage(
		NSDictionary *message, TGMessageLayout *layout);

/// The table's reuse identifier for an element; separate pools keep a bubble
/// from being reused as a service plate.
FOUNDATION_EXPORT NSString *TGMessageCellReuseIdentifierForKind(
		TGMessageCellKind kind);

@interface TGMessageCellFactory : NSObject

/// The configured cell for a message row. No allocation beyond the first cell
/// of each kind: a reused cell is reset and placed from the layout record, so
/// scrolling cost is the same as when the chat built its cells itself.
+ (UITableViewCell *)cellForTableView:(UITableView *)tableView
							  message:(NSDictionary *)message
							   layout:(TGMessageLayout *)layout;

@end
