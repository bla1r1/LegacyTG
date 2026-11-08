#import "TGPerf.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGForwardPicker.h"
#import "TGVoiceRecorder.h"
#import "TGProfileViewController.h"
#import "TGThemeFile.h"
#import "TGCapabilities.h"
#import "TGDevice.h"
#import <AddressBookUI/AddressBookUI.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MapKit/MapKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TGVoiceDecoder.h"
#import "TGEmojiData.h"
#import "TGCustomEmojiStore.h"
#import "UIImage+WebP.h"
#import "TGLottieView.h"
#import "TGDevShowcase.h"
#import "TGCallViewController.h"
#import "TGPopupMenu.h"
#import "TGSnackbar.h"
#import "TGMediaViewer.h"
#import "TGPollPresentation.h"
#import "TGChecklistPresentation.h"
#import "TGGiftViewController.h"
#import "TGStoryViewerViewController.h"
#import "TGCommunityViewController.h"
#import "TGMusicPlayer.h"
#import "TGDevShowcase.h"
#import "TGMessageLayout.h"
#import "TGBubbleCell.h"
#import "TGChatViewControllerInternal.h"
#import "TGMessageStreamStore.h"
#import "TGLocalization.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGDMTopicsViewController.h"

#if TG_DEV
#endif



/// The pin in the strip under the bar, and where its two lines begin after it.
static const CGFloat kPinnedGlyph = 14.0f;
static const CGFloat kPinnedTextX = TGMetricPadLarge + kPinnedGlyph + TGMetricPadSmall;
/// Finds the message line when the strip already exists and only its text changes.
static const NSInteger kPinnedBodyTag = 0x9010;
/// The bar that stands in for the composer: mute for a channel you follow,
/// join for one you have not joined yet. One tag per state, so a second answer
/// replaces the bar instead of stacking another one on top.
static const NSInteger kChatMuteBarTag = 0x9020;
static const NSInteger kChatJoinGroupBarTag = 0x9021;
static const NSInteger kChatJoinChannelBarTag = 0x9022;
static const NSInteger kChatDiscussBarTag = 0x9023;
static const NSInteger kChatChannelBottomBarTag = 0x9024;

#pragma mark - controller


@implementation TGChatViewController (TGChatViewTaps)

#pragma mark - taps

- (void)simulateTapOnRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.messages.count){
		NSLog(@"tap: row %ld out of range (%lu)",
				(long)row, (unsigned long)self.messages.count);
		return;
	}
	NSLog(@"tap: row %ld, kind %@", (long)row, self.messages[row][@"kind"]);
	[self tableView:self.table
			didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
}

- (void)callCellButtonTapped:(UIButton *)btn {
	if (!self.isGroup) {
		[TGCallViewController presentForUserId:self.chatId
										  name:self.chatTitle
									  outgoing:YES];
	}
}

- (void)contactCallButtonTapped:(UIButton *)btn {
	NSInteger row = btn.tag;
	if (row >= 0 && row < (NSInteger)self.messages.count) {
		NSDictionary *m = self.messages[row];
		NSDictionary *contact = [m[@"contact"] isKindOfClass:NSDictionary.class] ? m[@"contact"] : nil;
		NSString *phone = contact[@"phoneNumber"];
		if (!phone.length) {
			NSArray *parts = [m[@"text"] componentsSeparatedByString:@"\n"];
			if (parts.count > 1) phone = parts[1];
		}
		if (phone.length) {
			NSString *clean = [[phone componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]] componentsJoinedByString:@""];
			if (clean.length)
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", clean]]];
		}
	}
}

- (void)contactAddButtonTapped:(UIButton *)btn {
	NSInteger row = btn.tag;
	if (row >= 0 && row < (NSInteger)self.messages.count) {
		[self presentAddContactForMessage:self.messages[row]];
	}
}

- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownCardViewController didResolveToPerson:(ABRecordRef)person {
}

- (void)handleContactTapForMessage:(NSDictionary *)m {
	NSDictionary *contact = [m[@"contact"] isKindOfClass:NSDictionary.class] ? m[@"contact"] : nil;
	NSString *phone = contact[@"phoneNumber"] ?: @"";
	if (!phone.length) {
		NSArray *parts = [m[@"text"] componentsSeparatedByString:@"\n"];
		if (parts.count > 1) phone = parts[1];
	}
	NSString *name = contact[@"name"] ?: @"";
	if (!name.length) {
		NSArray *parts = [m[@"text"] componentsSeparatedByString:@"\n"];
		if (parts.count) name = parts[0];
	}

	__weak typeof(self) weakSelf = self;
	NSString *dialable = [[phone componentsSeparatedByCharactersInSet:
			[[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"]
					invertedSet]] componentsJoinedByString:@""];
	[TGAlertSheet showChoices:@[phone.length ? [NSString stringWithFormat:@"Call %@", phone]
											 : @"Call",
								@"Add to Contacts",
								@"Copy Phone Number"]
						title:name.length ? name : @"Contact"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGChatViewController *me = weakSelf;
		if (index == 0){
			if (dialable.length)
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:
						[NSString stringWithFormat:@"tel:%@", dialable]]];
		} else if (index == 1){
			[me presentAddContactForMessage:m];
		} else {
			[UIPasteboard generalPasteboard].string = phone ?: @"";
			[TGSnackbar showInView:me.view text:@"Phone number copied to clipboard."
						   seconds:2 onCommit:^{}];
		}
	}];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.messages.count)
		return;
	NSDictionary *m = self.messages[indexPath.row];
	if (self.isEditingMessages) {
		if ([m[@"service"] boolValue])
			return;
		int64_t msgId = [m[@"id"] longLongValue];
		if (msgId) {
			[self toggleMessageSelection:msgId];
		}
		return;
	}
	NSString *kind = m[@"kind"];

	// A message still going out has an X on its disc: the tap takes it back
	// rather than opening something that is not there yet.
	if ([m[@"sending"] boolValue]){
		[self cancelSendingRow:m];
		return;
	}

	// "Alice pinned a message" leads to that message, as official does.
	if ([kind isEqualToString:@"messagePinMessage"] && [m[@"pinnedMessageId"] longLongValue]){
		[self jumpToReplyById:[m[@"pinnedMessageId"] longLongValue]];
		return;
	}

	// Contact card tap
	if ([kind isEqualToString:@"messageContact"]){
		[self handleContactTapForMessage:m];
		return;
	}

	// Location card tap -> open in Apple Maps
	if ([kind isEqualToString:@"messageLocation"] || [kind isEqualToString:@"messageVenue"] || [kind isEqualToString:@"messageLiveLocation"]){
		double lat = [m[@"lat"] doubleValue];
		double lon = [m[@"lon"] doubleValue];
		if (lat != 0 || lon != 0){
			NSString *title = [m[@"venue"] isKindOfClass:[NSDictionary class]] ? m[@"venue"][@"title"] : nil;
			NSString *urlStr = nil;
			if (title.length){
				NSString *esc = [title stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				urlStr = [NSString stringWithFormat:@"http://maps.apple.com/?q=%@&ll=%f,%f", esc, lat, lon];
			} else {
				urlStr = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%f,%f", lat, lon];
			}
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
			return;
		}
	}

	// A call log entry calls back, which is the only thing anyone wants from
	// one - and a missed call is otherwise a dead end.
	if ([kind isEqualToString:@"messageCall"] && !self.isGroup){
		[TGCallViewController presentForUserId:self.chatId
										  name:self.chatTitle
									  outgoing:YES];
		return;
	}

	// A poll is voted in by tapping an option, which is a button of its own.
	if ([kind isEqualToString:@"messagePoll"])
		return;

	// A reply is unreadable if you cannot get to what it answers.
	// The flattened message stores absent values as NSNull, which answers no
	// number selector - asking it for a long long is what brought the app
	// down on the first tap on a voice note.
	NSNumber *replyTo = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (replyTo){
		[self jumpToReplyById:replyTo.longLongValue];
		return;
	}

	// A theme file is the one document worth opening in place: tapping it
	// applies the theme, the way the official clients do.
	if ([kind isEqualToString:@"messageDocument"] &&
		[TGThemeFile handlesFile:(m[@"docName"] ?: @"")]){
		[self applyThemeFromMessage:m];
		return;
	}

	if ([kind isEqualToString:@"messageDocument"]){
		[self openDocumentMessage:m fromCell:[tableView cellForRowAtIndexPath:indexPath]];
		return;
	}

	// A video note plays where it sits, in its own circle - handing it to the
	// full-screen player turns a two-second glance into a modal screen.
	if ([kind isEqualToString:@"messageVideoNote"]){
		if (self.playingMessageId == [m[@"id"] longLongValue] && self.videoNotePlayer){
			[self togglePlayback];
			return;
		}
		[self playVideoNoteForMessage:m atRow:indexPath.row];
		return;
	}

	// Paid media cannot be unlocked with Stars in this app yet.
	if ([kind isEqualToString:@"messagePaidMedia"] || [m[@"paidPreview"] boolValue]){
		[TGSnackbar showInView:self.view
						  text:@"Paying with Stars is not available in this app yet."
					   seconds:2 onCommit:nil];
		return;
	}

	// The first tap on a spoiler takes the cover off; the next opens it.
	if ([m[@"hasSpoiler"] boolValue] && m[@"id"] && ![self.revealedSpoilers containsObject:m[@"id"]] &&
		![m[@"viewOnce"] boolValue] && ![m[@"destructSeconds"] integerValue]){
		if (!self.revealedSpoilers)
			self.revealedSpoilers = [NSMutableSet set];
		[self.revealedSpoilers addObject:m[@"id"]];
		[tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
		return;
	}

	// Text spoilers keep the same bargain for the words: the first tap draws
	// them out from under their plate, and they stay revealed for this visit.
	NSArray *textEntities = m[@"entities"];
	if (TGEntitiesHaveSpoiler(textEntities) && m[@"id"] &&
		![self.revealedSpoilers containsObject:m[@"id"]]) {
		if (!self.revealedSpoilers)
			self.revealedSpoilers = [NSMutableSet set];
		[self.revealedSpoilers addObject:m[@"id"]];
		[tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
		return;
	}

	// A one-time or timed picture opens alone - no paging to its neighbours -
	// and tells TDLib it was opened, which starts the sender's clock. TDLib
	// then swaps the content for "expired"; the viewer keeps the file it has.
	if (([kind isEqualToString:@"messagePhoto"] || [kind isEqualToString:@"messageVideo"]) &&
		([m[@"viewOnce"] boolValue] || [m[@"destructSeconds"] integerValue] > 0)){
		[[TGClient shared] openContentOfMessage:[m[@"id"] longLongValue] inChat:self.chatId];
		[TGMediaViewer presentItems:@[m] startAt:0 inChat:self.chatId isAlbum:NO];
		return;
	}

	// Video and photos share one viewer: it pages between them, which is how
	// every current client shows a chat's media.
	if ([kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messageAnimation"] ||
		[kind isEqualToString:@"messagePhoto"] ||
		([m[@"isAlbum"] boolValue] && ![kind isEqualToString:@"messageDocument"])){
		NSArray *albumMsgs = [m[@"isAlbum"] boolValue] ? m[@"albumMessages"] : nil;
		if (albumMsgs.count) {
			[TGMediaViewer presentItems:albumMsgs
								startAt:0
								 inChat:self.chatId
								isAlbum:YES];
			return;
		}
		NSArray *pool = self.rawMessages.count ? self.rawMessages : self.messages;
		NSInteger targetIdx = [pool indexOfObject:m];
		if (targetIdx == NSNotFound) targetIdx = 0;
		// The picture grows out of its bubble, when the bubble is on screen.
		id tappedCell = [tableView cellForRowAtIndexPath:indexPath];
		UIView *source = [tappedCell isKindOfClass:TGBubbleCell.class]
				? ((TGBubbleCell *)tappedCell).picture : nil;
		[TGMediaViewer presentItems:pool
							startAt:targetIdx
							 inChat:self.chatId
							isAlbum:NO
						   fromView:source];
		return;
	}

	// A track is not a voice note: it belongs to the run of music in this chat
	// and it keeps playing when the app goes away.
	if ([kind isEqualToString:@"messageAudio"]){
		if ([TGMusicPlayer shared].currentMessageId == [m[@"id"] longLongValue]){
			[[TGMusicPlayer shared] togglePlayPause];
			return;
		}
		if (self.voicePlayer)
			[self stopPlayback];
		[[TGMusicPlayer shared] playTracks:self.messages
								   atIndex:indexPath.row
									inChat:self.chatId];
		[self showMusicBar];
		return;
	}

	// Voice notes are Opus, which iOS 7 cannot decode - convert, then play.
	if ([kind isEqualToString:@"messageVoiceNote"]){
		[self playVoiceNoteForMessage:m atRow:indexPath.row];
		return;
	}
}

- (void)showPlaybackFailure {
	[TGAlertSheet showMessage:@"An error occurred." title:nil inView:self.view];
}

- (void)openDocumentMessage:(NSDictionary *)m fromCell:(UITableViewCell *)cell {
	NSArray *albumMsgs = [m[@"isAlbum"] boolValue] ? m[@"albumMessages"] : nil;
	if (albumMsgs.count > 1) {
		NSMutableArray *buttons = [NSMutableArray array];
		for (NSDictionary *doc in albumMsgs) {
			NSString *name = [doc[@"docName"] length] ? doc[@"docName"] : @"Document";
			[buttons addObject:name];
		}
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:buttons
							title:@"Open File"
				 destructiveIndex:-1
						   inView:self.view
						 onChoice:^(NSInteger index){
			if (index >= 0 && index < (NSInteger)albumMsgs.count) {
				[weakSelf downloadAndPresentDocument:albumMsgs[(NSUInteger)index] fromCell:cell];
			}
		}];
		return;
	}
	[self downloadAndPresentDocument:m fromCell:cell];
}

- (void)downloadAndPresentDocument:(NSDictionary *)doc fromCell:(UITableViewCell *)cell {
	NSNumber *docId = doc[@"docId"];
	if (![docId isKindOfClass:NSNumber.class] || docId.longLongValue <= 0)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:docId.integerValue priority:TGDownloadPriorityOnScreen completion:^(NSString *path){
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatViewController *me = weakSelf;
			if (!me || !path.length)
				return;
			NSURL *url = [NSURL fileURLWithPath:path];
			me.docInteractionController = [UIDocumentInteractionController interactionControllerWithURL:url];
			me.docInteractionController.delegate = (id<UIDocumentInteractionControllerDelegate>)me;
			if (![me.docInteractionController presentPreviewAnimated:YES]) {
				UIView *source = cell ?: me.view;
				CGRect rect = cell ? cell.bounds : CGRectMake(TGHalf(me.view.bounds.size.width), TGHalf(me.view.bounds.size.height), TGMetricHairline, TGMetricHairline);
				[me.docInteractionController presentOpenInMenuFromRect:rect inView:source animated:YES];
			}
		});
	}];
}


@end
