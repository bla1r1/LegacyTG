//
// TGMessageServiceCell.m - a service event plate in the message list.
//
#import "TGMessageServiceCell.h"
#import "TGMessageLayout.h"
#import "TGStyle.h"
#import "TGTheme.h"

@implementation TGMessageServiceCell

- (void)configureWithLayout:(TGMessageLayout *)layout theme:(TGTheme *)theme {
	[self resetForReuse];

	self.bubble.frame = layout.bubbleFrame;
	self.bubble.backgroundColor = [theme serviceBubbleColour];
	self.bubble.layer.borderWidth = TGMetricBorderNone;
	self.bubble.layer.cornerRadius = [theme bubbleCornerRadius];

	self.picture.hidden = YES;
	self.time.text = @"";
	self.body.hidden = NO;
	self.body.numberOfLines = 1;
	self.body.font = TGFontMeta();
	self.body.textAlignment = NSTextAlignmentCenter;
	self.body.textColor = [theme serviceTextColour];
	self.body.text = layout.serviceText ?: @"";
	self.body.frame = layout.bodyFrame;
}

@end
