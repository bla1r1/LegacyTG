#import "TGProfileViewControllerInternal.h"
#import "TGClientInternal.h"
#import "TGRows.h"
#import "TGRowCell.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGGroupMemberActions.h"
#import "TGMusicPlayer.h"
#import "TGChatViewController.h"
#import "TGSimilarChannelsViewController.h"
#import "TGDMTopicsViewController.h"
#import "TGProfileLogic.h"
#import "TGLocalization.h"
#import "TGIcons.h"
#import <AVFoundation/AVFoundation.h>

/// The card's own height is the label over the value, with the value wrapping
/// to four lines for prose. The shared cell cannot measure the account's text
/// (it is deliberately raw), so the profile sets the row height here.
static CGFloat TGProfileDetailRowHeight(NSDictionary *row, CGFloat width) {
	NSString *kind = row[@"profileKind"] ?: @"";
	NSString *value = row[TGRowDetail] ?: row[TGRowTitle] ?: @"";
	CGFloat textWidth = width - TGMetricPadLarge - TGMetricPadLarge -
			TGDoubled(TGMetricPad);
	if (textWidth < TGMetricActionRow)
		textWidth = TGMetricActionRow;
	if ([kind isEqualToString:@"invite"] ||
			[kind isEqualToString:@"username"] ||
			[kind isEqualToString:@"settings"]){
		textWidth -= TGMetricMenuGlyph + TGMetricPadMedium;
	}
	BOOL ownText = [kind isEqualToString:@"warning"] ||
			[kind isEqualToString:@"addContact"] ||
			[kind isEqualToString:@"block"];
	NSString *measured = ownText ? TGLocalized(value) : value;
	CGFloat textHeight = [measured sizeWithFont:TGFontBody()
			constrainedToSize:CGSizeMake(MAX(TGMetricActionRow, textWidth),
					CGFLOAT_MAX)
			lineBreakMode:NSLineBreakByWordWrapping].height;
	BOOL labelled = [row[TGRowLabelAbove] boolValue];
	CGFloat labelHeight = labelled ? TGMetricLineCaption + TGMetricPadTiny : 0;
	return MAX(TGMetricPersonRow, TGMetricPadSmall + labelHeight +
			ceilf(textHeight) + TGMetricPadMedium);
}

@implementation TGProfileViewController (TGProfileTable)

#pragma mark - sections

- (void)rebuildSections {
	if (!self.isViewLoaded)
		return;
	__weak typeof(self) weakSelf = self;
	NSMutableDictionary *fixture = [NSMutableDictionary dictionary];
	fixture[@"details"] = self.details ?: @[];
	if (self.communityId){
		NSMutableDictionary *community = [@{
			@"id" : @(self.communityId),
			@"title" : self.communityName ?: TGLocalized(@"Community"),
			@"subtitle" : self.communitySubtitle ?: @"",
		} mutableCopy];
		UIImage *avatar = self.chatAvatars[@(self.communityId)];
		if (avatar)
			community[@"avatar"] = avatar;
		fixture[@"community"] = community;
	}
	if (self.personalChannel){
		int64_t target = [self.personalChannel[@"chatId"] longLongValue];
		NSMutableDictionary *channel = [@{
			@"chatId" : @(target),
			@"title" : self.personalChannel[@"title"] ?: TGLocalized(@"Channel"),
			@"subtitle" : self.personalChannelPreview ?: @"",
		} mutableCopy];
		UIImage *avatar = target ? self.chatAvatars[@(target)] : nil;
		if (avatar)
			channel[@"avatar"] = avatar;
		fixture[@"personalChannel"] = channel;
	}
	fixture[@"members"] = self.members ?: @[];
	fixture[@"memberCount"] = @(self.memberCount);
	fixture[@"isChannel"] = @(self.isChannel);
	fixture[@"danger"] = @(self.userId && self.isContact && !self.isBot &&
			![self isOwnProfile]);
	NSArray *tabs = [self currentMediaTabs];
	fixture[@"mediaTabs"] = tabs;
	fixture[@"mediaKind"] = [self selectedMediaKind];
	fixture[@"mediaRows"] = tabs.count ? [self mediaContentRows] : @[];
	fixture[@"tabStripOffset"] = @(self.mediaTabsOffset);
	fixture[@"handlers"] = @{
		@"community" : ^(id ignored){ [weakSelf openCommunity]; },
		@"channel" : ^(id ignored){
			TGProfileViewController *me = weakSelf;
			[me openChat:[me.personalChannel[@"chatId"] longLongValue]
				 title:me.personalChannel[@"title"] message:0];
		},
		@"detail" : ^(id kind){ [weakSelf openDetailKind:kind]; },
		@"danger" : ^(id ignored){ [weakSelf runMoreAction:@"Delete Contact"]; },
		@"member" : ^(id index){
			TGProfileViewController *me = weakSelf;
			NSInteger row = [index integerValue];
			if (row >= 0 && row < (NSInteger)me.members.count)
				[TGGroupMemberActions openProfileForMember:
						me.members[(NSUInteger)row] from:me];
		},
		@"mediaTab" : ^(id kind){ [weakSelf mediaTabSelected:kind]; },
		@"mediaTabHold" : ^(id kind){ [weakSelf setMainTabKind:kind]; },
	};

	NSArray *sections = TGProfileSectionsForFixture(fixture);
	NSMutableArray *styled = [NSMutableArray arrayWithCapacity:sections.count];
	TGTheme *theme = [TGTheme shared];
	CGFloat width = self.tableView.bounds.size.width ?: TGMetricScreenWidth;
	for (NSDictionary *section in sections){
		NSArray *rows = section[@"rows"];
		NSMutableArray *newRows = [NSMutableArray arrayWithCapacity:rows.count];
		for (NSMutableDictionary *row in rows){
			NSDictionary *detail = row[@"profileDetail"];
			if ([detail isKindOfClass:NSDictionary.class]){
				NSString *kind = detail[@"kind"] ?: @"";
				NSString *label = detail[@"label"] ?: @"";
				if ([kind isEqualToString:@"warning"] ||
						[kind isEqualToString:@"block"]){
					if (label.length)
						row[TGRowDetailColour] = [theme destructiveColour];
					else
						row[TGRowTitleColour] = [theme destructiveColour];
				} else if ([kind isEqualToString:@"birthday"] &&
						self.birthdayToday){
					row[TGRowDetailColour] = [theme onlineColour];
				} else if ([kind isEqualToString:@"bio"] ||
						[kind isEqualToString:@"note"] ||
						[kind isEqualToString:@"about"]){
					if (label.length)
						row[TGRowDetailColour] = [theme primaryTextColour];
					else
						row[TGRowTitleColour] = [theme primaryTextColour];
				} else if (!label.length){
					row[TGRowTitleColour] = [theme accentColour];
				} else {
					row[TGRowDetailColour] = [theme accentColour];
				}
				if ([kind isEqualToString:@"username"] ||
						[kind isEqualToString:@"invite"]){
					row[TGRowAccessoryImage] = [TGIcons glyphNamed:@"qr"
							colour:[theme accentColour]
							side:TGMetricMenuGlyph];
					NSString *value = detail[@"value"];
					__weak typeof(self) weak = self;
					row[TGRowAccessoryTap] = ^{
						[weak showQRCodeForValue:value];
					};
				}
				row[TGRowHeight] = @(TGProfileDetailRowHeight(row, width));
			}
			[newRows addObject:row];
		}
		NSMutableDictionary *copy = [section mutableCopy];
		copy[@"rows"] = newRows;
		[styled addObject:copy];
	}
	self.sections = styled;
	[self reloadRows];
}


#pragma mark - media search header

- (UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section {
	if (!self.mediaSearchActive || section != [self mediaSectionIndex])
		return nil;
	UISearchBar *bar = [self ensureMediaSearchBar];
	bar.frame = CGRectMake(0, 0, tableView.bounds.size.width,
			TGMetricSearchBarHeight);
	bar.showsCancelButton = YES;
	return bar;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
	if (self.mediaSearchActive && section == [self mediaSectionIndex])
		return TGMetricSearchBarHeight;
	return [super tableView:tableView heightForHeaderInSection:section];
}

#pragma mark - detail actions

- (void)openCommunity {
	if (!self.communityId)
		return;
	[TGChatViewController openCommunity:self.communityId
							 navigation:self.navigationController
								 inView:self.view];
}

- (void)openDetailKind:(NSString *)kind {
	NSDictionary *row = nil;
	for (NSDictionary *detail in self.details)
		if ([detail[@"kind"] isEqualToString:kind]){
			row = detail;
			break;
		}
	if (!row)
		return;
	if ([kind isEqualToString:@"channel"]){
		[self openChat:[self.personalChannel[@"chatId"] longLongValue]
				 title:self.personalChannel[@"title"] message:0];
	} else if ([kind isEqualToString:@"linkedChat"]){
		[self openChat:self.linkedChatId title:self.linkedChatTitle message:0];
	} else if ([kind isEqualToString:@"community"]){
		[self openCommunity];
	} else if ([kind isEqualToString:@"directMessages"]){
		[self openDirectMessages];
	} else if ([kind isEqualToString:@"settings"]){
		[self runMoreAction:(self.isChannel ? @"Channel Settings"
				: @"Group Settings")];
	} else if ([kind isEqualToString:@"similarChannels"]){
		TGSimilarChannelsViewController *similarVC =
				[[TGSimilarChannelsViewController alloc] init];
		similarVC.originalChatId = self.chatId;
		similarVC.channelChatIds = self.similarChatIds;
		similarVC.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:similarVC animated:YES];
	} else if ([kind isEqualToString:@"businessLocation"]){
		NSString *encoded = [row[@"value"] stringByAddingPercentEscapesUsingEncoding:
				NSUTF8StringEncoding];
		NSString *maps = [NSString stringWithFormat:
				@"http://maps.apple.com/?q=%@", encoded ?: @""];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:maps]];
	} else if ([kind isEqualToString:@"addContact"]){
		[self addToContactsTapped];
	} else if ([kind isEqualToString:@"block"]){
		[self runMoreAction:(self.blocked ? @"Unblock" : @"Block")];
	} else if ([kind isEqualToString:@"addBio"]){
		[self editProfileTapped];
	} else if ([kind isEqualToString:@"bio"]){
		NSURL *url = TGProfileFirstURL(row[@"value"], self.bioEntities);
		if (url)
			[[UIApplication sharedApplication] openURL:url];
	} else if ([kind isEqualToString:@"about"]){
		if (!self.descriptionExpanded){
			self.descriptionExpanded = YES;
			[self reloadTableDebounced];
			return;
		}
		[self copyDetailValue:row[@"value"]];
	} else if ([kind isEqualToString:@"phone"] ||
			[kind isEqualToString:@"username"] ||
			[kind isEqualToString:@"invite"] ||
			[kind isEqualToString:@"birthday"]){
		[self copyDetailValue:row[@"value"]];
	}
}

- (void)openDirectMessages {
	int64_t targetId = self.directMessagesChatId;
	if (targetId == 0) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] chatProfile:self.chatId completion:^(NSDictionary *info){
			TGProfileViewController *me = weakSelf;
			if (!me) return;
			int64_t dmId = [info[@"directMessagesChatId"] longLongValue];
			me.hasDirectMessages = [info[@"hasDirectMessages"] boolValue];
			me.canManageDirectMessages = [info[@"canManageDirectMessages"] boolValue];
			if (dmId != 0) {
				me.directMessagesChatId = dmId;
				[me openDirectMessages];
			} else if (me.hasDirectMessages || me.canManageDirectMessages) {
				me.directMessagesChatId = me.chatId;
				[me openDirectMessages];
			} else {
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									title:TGLocalized(@"Direct Messages")
								   inView:me.view];
			}
		}];
		return;
	}

	if (self.canManage || self.canManageDirectMessages) {
		TGDMTopicsViewController *topics = [[TGDMTopicsViewController alloc] init];
		topics.chatId = targetId;
		topics.chatTitle = self.name;
		topics.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:topics animated:YES];
	} else {
		[self openChat:targetId
				 title:(self.name.length ? self.name : TGLocalized(@"Direct Messages"))
			   message:0];
	}
}

- (void)openChat:(int64_t)chatId title:(NSString *)title message:(int64_t)messageId {
	if (!chatId)
		return;
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = title ?: @"";
	chat.initialMessageId = messageId;
	chat.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

/// A row in the shared lists. Grids have their own tiles; these are the lists.
- (void)openMediaRow:(NSInteger)index {
	NSArray *rows = [self selectedMediaRows];
	if (index >= (NSInteger)rows.count)
		return;
	NSDictionary *m = rows[(NSUInteger)index];
	NSString *kind = [self selectedMediaKind];
	int64_t messageId = [m[@"id"] longLongValue];
	if ([kind isEqualToString:@"music"]){
		[[TGMusicPlayer shared] playTracks:rows atIndex:index inChat:self.chatId];
		[self reloadTableDebounced];
	} else if ([kind isEqualToString:@"links"]){
		NSURL *url = TGProfileFirstURL(m[@"text"], m[@"entities"]);
		if (url)
			[[UIApplication sharedApplication] openURL:url];
	} else if ([kind isEqualToString:@"groups"]){
		[self openChat:[m[@"chatId"] longLongValue] title:m[@"title"] message:0];
	} else if ([kind isEqualToString:@"similar"]){
		int64_t chatId = [m[@"id"] longLongValue];
		[[TGClient shared] openSimilarChat:chatId fromChat:self.chatId];
		[self openChat:chatId title:m[@"title"] message:0];
	} else if ([kind isEqualToString:@"voice"] &&
			   ![m[@"kind"] isEqualToString:@"messageVideoNote"]){
		[self toggleVoiceRow:m];
	} else if ([kind isEqualToString:@"files"] || [kind isEqualToString:@"voice"]){
		[self openChat:self.chatId title:self.name message:messageId];
	}
}

- (void)toggleVoiceRow:(NSDictionary *)m {
	int64_t messageId = [m[@"id"] longLongValue];
	BOOL same = self.voicePlayer && self.playingVoiceId == messageId;
	[self.voicePlayer stop];
	self.voicePlayer = nil;
	self.playingVoiceId = 0;
	[self reloadTableDebounced];
	NSNumber *docId = m[@"docId"];
	if (same || ![docId isKindOfClass:NSNumber.class])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:docId.integerValue completion:^(NSString *path){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGProfileViewController *me = weakSelf;
			if (!me || !path)
				return;
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
			[[AVAudioSession sharedInstance] setActive:YES error:nil];
			NSError *err = nil;
			me.voicePlayer = [[TGStreamingVoicePlayer alloc] initWithPath:path error:&err];
			if (!me.voicePlayer){
				NSLog(@"voice playback: %@", err);
				[TGAlertSheet showMessage:TGLocalized(@"An error occurred.")
									title:TGLocalized(@"Voice Message") inView:me.view];
				return;
			}
			me.voicePlayer.delegate = me;
			me.playingVoiceId = messageId;
			[me.voicePlayer play];
			[me reloadTableDebounced];
		});
	}];
}

- (void)audioPlayerDidFinishPlaying:(id)player successfully:(BOOL)flag {
	self.voicePlayer = nil;
	self.playingVoiceId = 0;
	[self reloadTableDebounced];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self loadVisibleMediaTabIfNeeded];
	[self reloadOwnStories];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.voicePlayer stop];
	self.voicePlayer = nil;
	self.playingVoiceId = 0;
}

/// A hold on a member row is the old tap: the sheet of member actions.
- (void)memberRowHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:
			[hold locationInView:self.tableView]];
	if (!path)
		return;
	NSDictionary *row = self.sections[(NSUInteger)path.section]
			[@"rows"][(NSUInteger)path.row];
	if ([row[@"profileMember"] isKindOfClass:NSDictionary.class]){
		[self showMemberActionsFor:row[@"profileMember"]];
		return;
	}
	NSDictionary *detail = row[@"profileDetail"];
	if ([detail isKindOfClass:NSDictionary.class] &&
			[detail[@"value"] isKindOfClass:NSString.class])
		[self copyDetailValue:detail[@"value"]];
}

- (void)copyDetailValue:(NSString *)value {
	if (![value isKindOfClass:NSString.class])
		return;
	[UIPasteboard generalPasteboard].string = value;
	[self toast:TGLocalized(@"Copied to clipboard.")];
}

@end
