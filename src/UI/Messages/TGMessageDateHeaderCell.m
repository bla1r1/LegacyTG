//
// TGMessageDateHeaderCell.m - the day plate in the message list.
//
#import "TGMessageDateHeaderCell.h"
#import "TGMessageLayout.h"
#import "TGStyle.h"
#import "TGTheme.h"

@implementation TGMessageDateHeaderCell

- (void)configureWithLayout:(TGMessageLayout *)layout theme:(TGTheme *)theme {
	[super configureWithLayout:layout theme:theme];
	self.body.font = TGFontMetaStrong();
}

@end
