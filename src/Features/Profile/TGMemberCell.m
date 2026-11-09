//
// TGMemberCell.m - the group member row, drawn by the shared peer row.
//
// The class stays because the profile card and Group Settings both dequeue it
// by name; inside, every field becomes a TGPeerRow, so a member and a contact
// cannot drift apart again.
//
#import "TGMemberCell.h"
#import "TGPeerRowCell.h"
#import "TGRows.h"
#import "TGBadge.h"
#import "TGLocalization.h"

@implementation TGMemberCell

- (void)setName:(NSString *)name userId:(int64_t)userId inTable:(UITableView *)tableView {
	[self setName:name userId:userId status:nil tag:nil statusEmojiId:0
		  inTable:tableView];
}

- (void)setName:(NSString *)name
		 userId:(int64_t)userId
		 status:(NSString *)status
		inTable:(UITableView *)tableView {
	[self setName:name userId:userId status:status tag:nil statusEmojiId:0
		  inTable:tableView];
}

- (void)setName:(NSString *)name
		 userId:(int64_t)userId
		 status:(NSString *)status
			tag:(NSString *)tag
		inTable:(UITableView *)tableView {
	[self setName:name userId:userId status:status tag:tag statusEmojiId:0
		  inTable:tableView];
}

- (void)setName:(NSString *)name
		 userId:(int64_t)userId
		 status:(NSString *)status
			tag:(NSString *)tag
  statusEmojiId:(int64_t)statusEmojiId
		inTable:(UITableView *)tableView {
	NSMutableDictionary *row = TGPeerRow(@(userId), name ?: @"", nil, nil);
	row[TGRowAvatarUser] = @YES;
	row[TGRowAccessory] = TGRowAccessoryDisclosure;
	if (statusEmojiId > 0)
		row[TGRowStatusEmojiId] = @(statusEmojiId);

	NSString *label = [tag isKindOfClass:NSString.class]
			? [tag stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
	if ([status isEqualToString:@"owner"]){
		row[TGRowBadge] = label.length ? label : TGLocalized(@"Owner");
		row[TGRowBadgeVariant] = @(TGBadgeVariantAccent);
		row[TGRowBadgeInline] = @YES;
	} else if ([status isEqualToString:@"admin"]){
		row[TGRowBadge] = label.length ? label : TGLocalized(@"Admin");
		row[TGRowBadgeVariant] = @(TGBadgeVariantMuted);
		row[TGRowBadgeInline] = @YES;
	}

	[self configureWithRow:row inTable:tableView];
}

@end
