//
// TGPageHeaderRowCell.m
//
#import "TGPageHeaderRowCell.h"
#import "TGPageHeaderView.h"
#import "TGRows.h"
#import "TGLocalization.h"
#import "TGIcons.h"

/// The row's strings come through the pack like every row title.
static NSString *TGPageHeaderRowText(NSDictionary *row, NSString *key) {
	NSString *text = row[key];
	return [text isKindOfClass:NSString.class] && text.length ? TGLocalized(text) : nil;
}

/// The row's own picture, or the settings tile its icon name draws: a page
/// opened from a settings row repeats that row's icon.
static UIImage *TGPageHeaderRowArt(NSDictionary *row) {
	UIImage *art = row[TGRowAvatarImage];
	if ([art isKindOfClass:UIImage.class])
		return art;
	NSString *icon = row[TGRowIcon];
	return [icon isKindOfClass:NSString.class] && icon.length
			? [TGIcons settingsIconNamed:icon color:row[TGRowColour]] : nil;
}

static CGFloat TGPageHeaderRowArtSide(NSDictionary *row) {
	return TGPageHeaderRowArt(row).size.width;
}

@interface TGPageHeaderRowCell ()
@property (nonatomic, strong) TGPageHeaderView *header;
@end

@implementation TGPageHeaderRowCell

+ (CGFloat)heightForRow:(NSDictionary *)row inTableView:(UITableView *)tableView {
	return [TGPageHeaderView heightForWidth:tableView.bounds.size.width
			artSide:TGPageHeaderRowArtSide(row)
			title:TGPageHeaderRowText(row, TGRowTitle) subtitle:nil
			text:TGPageHeaderRowText(row, TGRowDetail)];
}

+ (instancetype)cellForTableView:(UITableView *)tableView row:(NSDictionary *)row {
	// Not reused: a page has one, and its height is its content.
	TGPageHeaderRowCell *cell = [[TGPageHeaderRowCell alloc]
			initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.backgroundColor = [UIColor clearColor];
	UIView *clear = [[UIView alloc] initWithFrame:CGRectZero];
	clear.backgroundColor = [UIColor clearColor];
	cell.backgroundView = clear;
	TGPageHeaderView *header = [[TGPageHeaderView alloc]
			initWithWidth:tableView.bounds.size.width
			artSide:TGPageHeaderRowArtSide(row)
			title:TGPageHeaderRowText(row, TGRowTitle) subtitle:nil
			text:TGPageHeaderRowText(row, TGRowDetail)];
	header.imageView.image = TGPageHeaderRowArt(row);
	header.imageView.contentMode = UIViewContentModeCenter;
	// The cell's own frame is inset on an iOS 6 grouped table; the header is
	// laid out across the table and placed back over the inset.
	cell.header = header;
	[cell addSubview:header];
	return cell;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if (self.superview)
		self.header.frame = CGRectMake(-self.frame.origin.x, 0,
				self.superview.bounds.size.width, self.bounds.size.height);
}

@end
