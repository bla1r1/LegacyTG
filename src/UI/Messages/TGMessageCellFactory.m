//
// TGMessageCellFactory.m - builds and configures the message list's elements.
//
#import "TGMessageCellFactory.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"
#import "TGMessageBubbleCell.h"
#import "TGMessageServiceCell.h"
#import "TGMessageDateHeaderCell.h"
#import "TGMessageUnreadSeparatorCell.h"

@implementation TGMessageCellFactory

+ (UITableViewCell *)cellForTableView:(UITableView *)tableView
							  message:(NSDictionary *)message
							   layout:(TGMessageLayout *)layout {
	TGMessageCellKind kind = TGMessageCellKindForMessage(message, layout);
	NSString *reuse = TGMessageCellReuseIdentifierForKind(kind);
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		switch (kind) {
			case TGMessageCellKindService:
				cell = [[TGMessageServiceCell alloc]
						initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
				break;
			case TGMessageCellKindDateHeader:
				cell = [[TGMessageDateHeaderCell alloc]
						initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
				break;
			case TGMessageCellKindUnreadSeparator:
				cell = [[TGMessageUnreadSeparatorCell alloc]
						initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
				break;
			case TGMessageCellKindBubble:
			default:
				cell = [[TGBubbleCell alloc]
						initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
				break;
		}
	}
	[(TGBubbleCell *)cell configureWithLayout:layout theme:[TGTheme shared]];
	return cell;
}

@end
