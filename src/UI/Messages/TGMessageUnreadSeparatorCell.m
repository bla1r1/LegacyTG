//
// TGMessageUnreadSeparatorCell.m - the unread band in the message list.
//
#import "TGMessageUnreadSeparatorCell.h"
#import "TGMessageLayout.h"
#import "TGStyle.h"
#import "TGTheme.h"

@implementation TGMessageUnreadSeparatorCell

- (void)configureWithLayout:(TGMessageLayout *)layout theme:(TGTheme *)theme {
	[super configureWithLayout:layout theme:theme];
	self.bubble.backgroundColor = [theme unreadSeparatorColour];
	self.bubble.layer.cornerRadius = TGMetricCornerNone;
	self.body.font = TGFontCaptionStrong();
	self.body.textColor = [theme secondaryTextColour];
}

@end
