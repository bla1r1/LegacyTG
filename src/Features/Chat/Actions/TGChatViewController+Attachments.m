#import "TGChatViewControllerInternal.h"
#import "TGForwardPicker.h"
#import "TGPopupMenu.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGReactionPicker.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGMessageStore.h"
#import "TGInstantViewController.h"
#import "TGMessageAudienceViewController.h"
#import "TGSponsoredMessagesViewController.h"
#import "TGGameScoresViewController.h"
#import "TGPollPresentation.h"
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>

@implementation TGChatViewController (Attachments)

#pragma mark - attachments

- (void)pickMedia {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary])
		return;

	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	// Without this the library shows photos only, and video cannot be sent.
	picker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie];
	picker.delegate = (id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)self;
	[self presentViewController:picker animated:YES completion:nil];
}

/// A replacement picture, not a new one: the library is opened for an image
/// and the pick goes back into the message it came from.
- (void)pickReplacementPhoto {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary])
		return;

	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.mediaTypes = @[(NSString *)kUTTypeImage];
	picker.delegate = (id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)self;
	[self presentViewController:picker animated:YES completion:nil];
}

/// One fix, or a trace that keeps moving: the sheet is where the two live
/// apart, the trace with the period a live location is allowed.
- (void)sendCurrentLocation {
	if (!self.locationManager){
		self.locationManager = [[CLLocationManager alloc] init];
		self.locationManager.delegate = self;
		self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Send Location", @"Share My Live Location for..."]
						title:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		if (index == 0)
			[weakSelf startLocationUpdates];
		else {
			[TGAlertSheet showChoices:@[@"for 15 minutes", @"for 1 hour", @"for 8 hours"]
								title:@"Live Location"
					 destructiveIndex:-1
							   inView:weakSelf.view
							 onChoice:^(NSInteger periodIndex){
				weakSelf.liveLocationSeconds =
						periodIndex == 0 ? 15 * 60 : (periodIndex == 1 ? 3600 : 28800);
				weakSelf.liveLocationMessageId = 0;
				weakSelf.liveLocationRestarts = 0;
				[weakSelf startLocationUpdates];
			}];
		}
	}];
}

/// The manager itself runs until it has what its caller needs: one fix ends
/// it, a live trace keeps it going until the pin is stopped.
- (void)startLocationUpdates {
	if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
		[self.locationManager requestWhenInUseAuthorization];
	[self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager
	 didUpdateLocations:(NSArray *)locations {
	CLLocation *fix = [locations lastObject];
	if (!fix)
		return;
	double lat = fix.coordinate.latitude, lon = fix.coordinate.longitude;

	if (self.liveLocationSeconds){
		// Live: the first fix makes the message, the rest move it - and the
		// queued-up fixes are dropped while TDLib has one in flight, since
		// each edit answers with the message in full.
		if (self.liveLocationInFlight)
			return;
		self.liveLocationInFlight = YES;
		int64_t chatId = self.chatId;
		NSInteger remaining = (NSInteger)(self.liveLocationSeconds -
				([[NSDate date] timeIntervalSince1970] - self.liveLocationSince));
		if (remaining < 1)
			remaining = 0;
		__weak typeof(self) weakSelf = self;
		if (self.liveLocationMessageId){
			[[TGMessageStore shared] editLiveLocationOfMessage:self.liveLocationMessageId
												  inChat:chatId
												latitude:lat
											   longitude:lon
											  livePeriod:remaining
											  completion:^(BOOL ok){
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				me.liveLocationInFlight = NO;
				if (!ok)
					me.liveLocationRestarts++;
			}];
			return;
		}
		self.liveLocationSince = [[NSDate date] timeIntervalSince1970];
		[[TGSendStore shared] sendLiveLocation:self.liveLocationSeconds
								   latitude:lat
								  longitude:lon
									 toChat:chatId
								  completion:^(int64_t messageId){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			me.liveLocationInFlight = NO;
			me.liveLocationMessageId = messageId;
		}];
		return;
	}

	// Fixed: one fix is the pin, and the manager is done.
	[manager stopUpdatingLocation];
	[[TGSendStore shared] sendLocation:lat longitude:lon toChat:self.chatId];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	[manager stopUpdatingLocation];
	NSLog(@"location: %@", error);
}

- (void)pickContact {
	ABPeoplePickerNavigationController *picker =
			[[ABPeoplePickerNavigationController alloc] init];
	picker.peoplePickerDelegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)picker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	NSString *name = (__bridge_transfer NSString *)
			ABRecordCopyCompositeName(person);
	ABMultiValueRef phones = ABRecordCopyValue(person, kABPersonPhoneProperty);
	NSString *phone = ABMultiValueGetCount(phones) > 0
			? (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phones, 0)
			: nil;
	if (phones) CFRelease(phones);

	[picker dismissViewControllerAnimated:YES completion:nil];
	if (phone.length)
		[[TGSendStore shared] sendContactNamed:name phone:phone toChat:self.chatId];
	return NO;
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	[picker dismissViewControllerAnimated:YES completion:nil];

	NSURL *movie = info[UIImagePickerControllerMediaURL];
	if (movie){
		[self confirmSendingVideoAtPath:movie.path];
		return;
	}

	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (image && self.replacingPhoto){
		int64_t messageId = self.editingId;
		self.replacingPhoto = NO;
		self.editingId = 0;
		[self replacePhotoOfMessage:messageId withImage:image];
		return;
	}
	if (image)
		[self confirmSendingImage:image];
}

/// The picked picture replaces the one already on Telegram: the same message
/// id, the same place in the history, the same caption. Leaving the caption
/// out would clear it, since editMessageMedia takes the whole content.
- (void)replacePhotoOfMessage:(int64_t)messageId withImage:(UIImage *)image {
	if (!messageId || !image)
		return;
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	NSString *name = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
	CFRelease(uuid);
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"replacement-%@.jpg", name]];
	if (![UIImageJPEGRepresentation(image, TGCompressionQualityHigh) writeToFile:path atomically:YES]){
		NSLog(@"cannot stage the replacement image");
		return;
	}
	NSString *caption = self.replacingPhotoCaption ?: @"";
	self.replacingPhotoCaption = nil;
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] editPhotoAtPath:path
							   caption:caption
							 ofMessage:messageId
								inChat:self.chatId
							completion:^(BOOL ok){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		[TGSnackbar showInView:me.view
						  text:(ok ? @"Photo updated" : @"An error occurred.")
					   seconds:2 onCommit:nil];
	}];
}

/// A single picture has no preview screen here, so the last step before it
/// goes out is this choice - the place their timer button sits on the preview.
- (void)confirmSendingImage:(UIImage *)image {
	if (!image)
		return;
	// TDLib allows one-time media only in a chat with one person (a positive
	// chat id); everywhere else the picture goes out with no extra tap.
	if (self.chatId <= 0){
		[self sendImage:image viewOnce:NO];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Send Message", @"View Once",
			@"View Once, 10 s", @"View Once, 30 s", @"View Once, 1 min"]
						title:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSInteger seconds = index == 2 ? 10 : (index == 3 ? 30 : (index == 4 ? 60 : 0));
		[weakSelf sendImage:image viewOnce:(index > 0) seconds:seconds];
	}];
}

- (void)confirmSendingVideoAtPath:(NSString *)path {
	if (!path.length)
		return;
	if (self.chatId <= 0){
		[self sendVideoAtPath:path viewOnce:NO];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Send Message", @"View Once",
			@"View Once, 10 s", @"View Once, 30 s", @"View Once, 1 min"]
						title:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSInteger seconds = index == 2 ? 10 : (index == 3 ? 30 : (index == 4 ? 60 : 0));
		[weakSelf sendVideoAtPath:path viewOnce:(index > 0) seconds:seconds];
	}];
}

- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce {
	[self sendVideoAtPath:path viewOnce:viewOnce seconds:0];
}

- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce seconds:(NSInteger)seconds {
	if (!path.length)
		return;
	[[TGSendStore shared] sendVideoAtPath:path viewOnce:viewOnce seconds:seconds
								   toChat:self.chatId];
}

/// TDLib wants a path, so the picture is written to a temporary file first -
/// one per photo, since two sent in a row would otherwise overwrite each
/// other before the first has uploaded.
- (void)sendImage:(UIImage *)image {
	[self sendImage:image viewOnce:NO];
}

- (void)sendImage:(UIImage *)image viewOnce:(BOOL)viewOnce {
	[self sendImage:image viewOnce:viewOnce seconds:0];
}

- (void)sendImage:(UIImage *)image viewOnce:(BOOL)viewOnce seconds:(NSInteger)seconds {
	if (!image)
		return;
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	NSString *name = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
	CFRelease(uuid);
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"outgoing-%@.jpg", name]];
	if (![UIImageJPEGRepresentation(image, TGCompressionQualityHigh) writeToFile:path atomically:YES]){
		NSLog(@"cannot stage the picked image");
		return;
	}
	[[TGSendStore shared] sendPhotoAtPath:path viewOnce:viewOnce seconds:seconds
								   toChat:self.chatId];
}

/// Several pictures as one message. Each is staged on disk the way a single
/// one is - TDLib uploads from a file - and the album goes as one request, so
/// they arrive together instead of as a run that happens to be adjacent.
- (void)sendImageAlbum:(NSArray *)images {
	if (!images.count)
		return;
	NSMutableArray *paths = [NSMutableArray array];
	for (UIImage *image in images){
		if (![image isKindOfClass:UIImage.class])
			continue;
		CFUUIDRef uuid = CFUUIDCreate(NULL);
		NSString *name = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
		CFRelease(uuid);
		NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
				[NSString stringWithFormat:@"outgoing-%@.jpg", name]];
		if ([UIImageJPEGRepresentation(image, TGCompressionQualityHigh) writeToFile:path atomically:YES])
			[paths addObject:path];
	}
	if (!paths.count){
		NSLog(@"cannot stage the picked album");
		return;
	}
	// Whatever is in the composer rides along as the album's caption, which
	// is where their client puts it too.
	NSString *caption = [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (caption.length){
		self.input.text = @"";
		[self inputChanged];
	}
	[[TGSendStore shared] sendPhotoAlbumAtPaths:paths
									 caption:caption
									  toChat:self.chatId
									  thread:self.threadId];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)presentAddContactForMessage:(NSDictionary *)m {
	NSDictionary *contact = [m[@"contact"] isKindOfClass:NSDictionary.class] ? m[@"contact"] : nil;
	NSString *first = contact[@"firstName"];
	NSString *last = contact[@"lastName"];
	NSString *phone = contact[@"phoneNumber"];
	if (!first && !last && !phone) {
		NSArray *parts = [m[@"text"] componentsSeparatedByString:@"\n"];
		if (parts.count) {
			NSArray *names = [parts[0] componentsSeparatedByString:@" "];
			first = names[0];
			if (names.count > 1) last = names[1];
		}
		if (parts.count > 1) phone = parts[1];
	}

	ABRecordRef person = ABPersonCreate();
	if (first.length)
		ABRecordSetValue(person, kABPersonFirstNameProperty, (__bridge CFStringRef)first, NULL);
	if (last.length)
		ABRecordSetValue(person, kABPersonLastNameProperty, (__bridge CFStringRef)last, NULL);
	if (phone.length) {
		ABMutableMultiValueRef phoneMulti = ABMultiValueCreateMutable(kABMultiStringPropertyType);
		ABMultiValueAddValueAndLabel(phoneMulti, (__bridge CFStringRef)phone, kABPersonPhoneMainLabel, NULL);
		ABRecordSetValue(person, kABPersonPhoneProperty, phoneMulti, NULL);
		CFRelease(phoneMulti);
	}

	NSString *fullName = [NSString stringWithFormat:@"%@%@",
			first.length ? first : @"",
			(first.length && last.length) ? [NSString stringWithFormat:@" %@", last] : (last ?: @"")];
	if (!fullName.length) fullName = @"Contact";

	int64_t uid = [contact[@"userId"] longLongValue];
	UIImage *avatarImg = nil;
	if (uid != 0) {
		avatarImg = self.senderAvatars[@(uid)] ?: self.images[@(uid)];
	}
	if (!avatarImg) {
		int64_t senderId = [m[@"senderId"] longLongValue];
		if (senderId != 0) {
			avatarImg = self.senderAvatars[@(senderId)];
		}
	}
	if (!avatarImg) {
		NSString *initials = [TGIcons initialsForTitle:fullName];
		avatarImg = [TGIcons avatarWithInitials:initials
										   size:TGMetricCallAvatarSide
									   colourId:uid ?: (int64_t)[fullName hash]];
	}
	if (avatarImg) {
		NSData *imgData = UIImagePNGRepresentation(avatarImg);
		if (imgData.length) {
			ABPersonSetImageData(person, (__bridge CFDataRef)imgData, NULL);
		}
	}

	ABUnknownPersonViewController *ctrl = [[ABUnknownPersonViewController alloc] init];
	ctrl.displayedPerson = person;
	ctrl.allowsAddingToAddressBook = YES;
	ctrl.allowsActions = YES;
	ctrl.unknownPersonViewDelegate = (id<ABUnknownPersonViewControllerDelegate>)self;
	CFRelease(person);

	[self.navigationController pushViewController:ctrl animated:YES];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return [scrollView viewWithTag:0xF118];
}

- (void)saveFullScreenImage:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan || !self.fullScreenImage)
		return;
	UIImageWriteToSavedPhotosAlbum(self.fullScreenImage, self,
			@selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error
  contextInfo:(void *)contextInfo {
	[TGAlertSheet showMessage:(error ? @"An error occurred." : @"Saved to Photos.")
						title:nil inView:self.view];
}

/// Simple full-screen viewer: black backdrop, tap anywhere to dismiss.
- (void)showFullScreenImage:(UIImage *)image {
	UIWindow *window = [UIApplication sharedApplication].keyWindow;

	UIView *backdrop = [[UIView alloc] initWithFrame:window.bounds];
	backdrop.backgroundColor = [[TGTheme shared] mediaViewerBackdropColour];
	backdrop.tag = 0xF117;

	// A scroll view is all zooming needs; a 4S has no room for a custom one.
	UIScrollView *zoom = [[UIScrollView alloc] initWithFrame:backdrop.bounds];
	zoom.minimumZoomScale = TGMetricZoomMin;
	zoom.maximumZoomScale = TGMetricZoomMax;
	zoom.delegate = self;
	zoom.showsHorizontalScrollIndicator = NO;
	zoom.showsVerticalScrollIndicator = NO;
	[backdrop addSubview:zoom];

	UIImageView *view = [[UIImageView alloc] initWithFrame:backdrop.bounds];
	view.contentMode = UIViewContentModeScaleAspectFit;
	view.image = image;
	view.tag = 0xF118;
	[zoom addSubview:view];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(dismissFullScreen:)];
	[backdrop addGestureRecognizer:tap];

	// Hold the picture to keep it - the only way out of the app for an image.
	self.fullScreenImage = image;
	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(saveFullScreenImage:)];
	[backdrop addGestureRecognizer:hold];

	UILabel *hint = [[UILabel alloc] initWithFrame:
			CGRectMake(0, backdrop.bounds.size.height - TGMetricImageHintBottomOffset,
					backdrop.bounds.size.width, TGMetricLineRow)];
	hint.text = nil;
	hint.font = TGFontMeta();
	hint.textAlignment = NSTextAlignmentCenter;
	hint.textColor = [[TGTheme shared] secondaryTextColour];
	hint.backgroundColor = [UIColor clearColor];
	[backdrop addSubview:hint];

	backdrop.alpha = TGAlphaTransparent;
	[window addSubview:backdrop];
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{ backdrop.alpha = TGAlphaOpaque; }];
}

- (void)dismissFullScreen:(UITapGestureRecognizer *)tap {
	UIView *backdrop = tap.view;
	[UIView animateWithDuration:TGAnimationDurationNormal animations:^{ backdrop.alpha = 0; }
					 completion:^(BOOL done){ [backdrop removeFromSuperview]; }];
}

- (void)openChatWithUsername:(NSString *)username {
	if (!username.length) return;
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] chatWithUsername:username completion:^(int64_t chatId, NSString *title){
		TGChatViewController *me = weakSelf;
		if (!me) return;
		if (!chatId) {
			[TGSnackbar showInView:me.navigationController.view
							  text:@"An error occurred."
						   seconds:2 onCommit:nil];
			return;
		}
		TGChatViewController *chatVC = [[TGChatViewController alloc] init];
		chatVC.chatId = chatId;
		chatVC.chatTitle = title.length ? title : username;
		chatVC.hidesBottomBarWhenPushed = YES;
		[me.navigationController pushViewController:chatVC animated:YES];
	}];
}

/// A link to one message, the way internalLinkKind says "message" for it:
/// Telegram names the chat and the message, and the chat opens to it.
- (void)openMessageLink:(NSString *)link {
	if (!link.length) return;
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] messageLinkInfo:link completion:^(int64_t chatId, int64_t messageId){
		TGChatViewController *me = weakSelf;
		if (!me) return;
		if (!chatId){
			[TGSnackbar showInView:me.navigationController.view
							  text:@"An error occurred."
						   seconds:2 onCommit:nil];
			return;
		}
		TGChatViewController *chatVC = [[TGChatViewController alloc] init];
		chatVC.chatId = chatId;
		NSString *title = [[TGMessageStore shared] titleForChat:chatId];
		chatVC.chatTitle = title.length ? title : @"Chat";
		chatVC.hidesBottomBarWhenPushed = YES;
		chatVC.initialMessageId = messageId;
		[me.navigationController pushViewController:chatVC animated:YES];
	}];
}

- (void)handleOpenLink:(NSString *)urlStr {
	if (!urlStr.length) return;

	NSString *clean = [urlStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	// @mention directly
	if ([clean hasPrefix:@"@"]) {
		[self openChatWithUsername:[clean substringFromIndex:1]];
		return;
	}

	NSURL *u = [NSURL URLWithString:clean];
	if (!u.scheme.length) {
		u = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", clean]];
	}

	NSString *host = u.host.lowercaseString;
	NSString *scheme = u.scheme.lowercaseString;

	BOOL isTelegramHost = [host isEqualToString:@"t.me"] || [host isEqualToString:@"telegram.me"] || [host isEqualToString:@"telegram.dog"];
	BOOL isTelegramScheme = [scheme isEqualToString:@"tg"];

	if (isTelegramHost || isTelegramScheme) {
		// Telegram knows what its own links mean; this screen used to guess
		// from the path, which read t.me/addstickers/foo as a chat called
		// "addstickers". The guess is still the fallback, because an answer
		// takes a round trip and some links genuinely have no kind.
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] internalLinkKind:clean
								 completion:^(NSString *kind, NSString *value){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			// Telegram can spell one link many ways. Asking it for the
			// canonical form before opening means a share link, a short
			// link and a copied link all land on the same chat.
			[me resolveInternalLinkKind:kind value:value original:clean
						 isTelegramHost:isTelegramHost
					   isTelegramScheme:isTelegramScheme];
		}];
		return;
	}

	[self presentExternalLink:clean];
}

/// The canonical t.me/tg:// form of a link Telegram has already classified,
/// then the screen acts on that form. A failed conversion falls back to the
/// text the message carried.
- (void)resolveInternalLinkKind:(NSString *)kind
						  value:(NSString *)value
					   original:(NSString *)original
				 isTelegramHost:(BOOL)isTelegramHost
			   isTelegramScheme:(BOOL)isTelegramScheme {
	NSDictionary *type = nil;
	if ([kind isEqualToString:@"publicChat"] && value.length)
		type = @{@"@type" : @"internalLinkTypePublicChat",
				 @"chat_username" : value,
				 @"draft_text" : @"",
				 @"open_profile" : @NO,
				 @"unpaid_messages_token" : @""};
	else if ([kind isEqualToString:@"message"] && value.length)
		type = @{@"@type" : @"internalLinkTypeMessage", @"url" : value};
	else if ([kind isEqualToString:@"inviteLink"] && value.length)
		type = @{@"@type" : @"internalLinkTypeChatInvite", @"invite_link" : value};
	else if ([kind isEqualToString:@"stickerSet"] && value.length)
		type = @{@"@type" : @"internalLinkTypeStickerSet",
				 @"sticker_set_name" : value,
				 @"expect_custom_emoji" : @NO};
	else if ([kind isEqualToString:@"phoneNumber"] && value.length)
		type = @{@"@type" : @"internalLinkTypeUserPhoneNumber",
				 @"phone_number" : value,
				 @"draft_text" : @"",
				 @"open_profile" : @NO,
				 @"unpaid_messages_token" : @""};
	else if ([kind isEqualToString:@"userToken"] && value.length)
		type = @{@"@type" : @"internalLinkTypeUserToken", @"token" : value};

	if (!type){
		// A deep link has no InternalLinkType to convert, and the path
		// fallback reads the original text.
		[self continueInternalLinkKind:kind value:value link:original
						isTelegramHost:isTelegramHost
					  isTelegramScheme:isTelegramScheme];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] internalLinkForType:type http:YES completion:^(NSString *link){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSString *resolved = link.length ? link : original;
		if (link.length && ![resolved isEqualToString:original])
			[TGSnackbar showInView:me.navigationController.view ?: me.view
							  text:[NSString stringWithFormat:@"Opened %@", resolved]
						   seconds:2 onCommit:nil];
		[me continueInternalLinkKind:kind value:value link:resolved
					  isTelegramHost:isTelegramHost
					isTelegramScheme:isTelegramScheme];
	}];
}

/// The branches that act on a classified internal link, now reading the
/// canonical URL rather than the text that was tapped.
- (void)continueInternalLinkKind:(NSString *)kind
						   value:(NSString *)value
							link:(NSString *)link
				   isTelegramHost:(BOOL)isTelegramHost
				 isTelegramScheme:(BOOL)isTelegramScheme {
	NSURL *u = [NSURL URLWithString:link];
	if (!u.scheme.length)
		u = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", link]];
	NSString *host = u.host.lowercaseString;

	if ([kind isEqualToString:@"publicChat"] && value.length){
		[self openChatWithUsername:value];
		return;
	}
	if ([kind isEqualToString:@"message"] && value.length){
		// A link to the exact message, t.me/name/12345: the chat is
		// resolved and the message jumped to, by Telegram's own
		// answer at getMessageLinkInfo.
		[self openMessageLink:value];
		return;
	}
	if ([kind isEqualToString:@"inviteLink"] && value.length){
		[self joinChatByInviteLink:value];
		return;
	}
	if ([kind isEqualToString:@"stickerSet"] && value.length){
		// A sticker set is not a chat, and opening one as a chat is
		// what this did before. The pack's record comes in with the
		// id and the count the sheet needs, and Telegram's answer
		// says whether this account already has it.
		[self askForStickerSet:value];
		return;
	}
	if ([kind isEqualToString:@"phoneNumber"] && value.length){
		[self openChatWithPhoneNumber:value];
		return;
	}
	if ([kind isEqualToString:@"userToken"] && value.length){
		// A user link that carries no username: the token is the only handle
		// Telegram gives, and searchUserByToken resolves it.
		[self openChatWithUserToken:value];
		return;
	}
	if ([kind isEqualToString:@"deepLink"] && value.length){
		[TGAlertSheet showMessage:value
							title:@"LegacyTG"
							inView:self.navigationController.view ?: self.view];
		return;
	}
	// Anything Telegram has no kind for falls through to the paths
	// this screen has always matched by hand.
	[self openTelegramLinkByPath:link url:u
					isTelegramHost:isTelegramHost
				  isTelegramScheme:isTelegramScheme
							  host:host];
}


/// Joining by a link, with the snackbar the tap used to get inline.
- (void)joinChatByInviteLink:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] joinChatByInviteLink:link completion:^(int64_t chatId,
															 NSString *title){
		TGChatViewController *me = weakSelf;
		if (!me) return;
		if (chatId != 0){
			TGChatViewController *chatVC = [[TGChatViewController alloc] init];
			chatVC.chatId = chatId;
			chatVC.chatTitle = title.length ? title : @"Chat";
			chatVC.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:chatVC animated:YES];
		} else {
			[TGSnackbar showInView:me.navigationController.view
							  text:@"An error occurred." seconds:2 onCommit:nil];
		}
	}];
}

/// A pack met through a link, offered the way their clients offer it: named,
/// counted, and installed on one confirm.
- (void)askForStickerSet:(NSString *)shortName {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] stickerSetByShortName:shortName completion:^(NSDictionary *set){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (!set){
			[TGSnackbar showInView:me.navigationController.view ?: me.view
							  text:@"An error occurred."
						   seconds:2 onCommit:nil];
			return;
		}
		NSString *title = [set[@"title"] length] ? set[@"title"] : shortName;
		if ([set[@"installed"] boolValue]){
			[TGSnackbar showInView:me.navigationController.view ?: me.view
							  text:[NSString stringWithFormat:@"%@ is already installed", title]
						   seconds:2 onCommit:nil];
			return;
		}
		NSString *counted = [NSString stringWithFormat:@"%@ - %lu stickers",
				title, (unsigned long)[set[@"count"] unsignedIntegerValue]];
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:@[@"Install"]
							title:counted
				  destructiveIndex:-1
							inView:me.navigationController.view ?: me.view
						  onChoice:^(NSInteger index){
			TGChatViewController *me = weakSelf;
			[[TGMessageStore shared] setStickerSet:set[@"id"] installed:YES archived:NO];
			[TGSnackbar showInView:me ? (me.navigationController.view ?: me.view) : nil
							  text:@"Done"
						   seconds:2 onCommit:nil];
		}];
	}];
}

/// Someone by their number, which a tg://resolve link can carry instead of a
/// username.
- (void)openChatWithPhoneNumber:(NSString *)phone {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] userForPhone:phone completion:^(NSDictionary *user){
		TGChatViewController *me = weakSelf;
		int64_t userId = [user[@"id"] longLongValue];
		if (!me || !userId){
			[TGSnackbar showInView:me.navigationController.view ?: me.view
							  text:@"An error occurred."
						   seconds:2 onCommit:nil];
			return;
		}
		[[TGMessageStore shared] privateChatWithUser:userId completion:^(int64_t chatId){
			if (!chatId)
				return;
			TGChatViewController *chatVC = [[TGChatViewController alloc] init];
			chatVC.chatId = chatId;
			chatVC.chatTitle = [[TGMessageStore shared] nameForUserId:userId] ?: phone;
			chatVC.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:chatVC animated:YES];
		}];
	}];
}

/// A user link whose only handle is a token - the form Telegram gives for an
/// account with no username. searchUserByToken is the one request that turns
/// it into a name; a refusal is the server's words, not a guessed chat.
- (void)openChatWithUserToken:(NSString *)token {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] searchUserByToken:token completion:^(NSDictionary *user,
															NSString *error){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		int64_t userId = [user[@"id"] longLongValue];
		if (!userId){
			[TGSnackbar showInView:me.navigationController.view ?: me.view
							  text:(error ?: @"An error occurred.")
						   seconds:2 onCommit:nil];
			return;
		}
		[[TGMessageStore shared] privateChatWithUser:userId completion:^(int64_t chatId){
			if (!chatId)
				return;
			TGChatViewController *chatVC = [[TGChatViewController alloc] init];
			chatVC.chatId = chatId;
			chatVC.chatTitle = user[@"name"] ?: user[@"username"] ?: @"Chat";
			chatVC.hidesBottomBarWhenPushed = YES;
			[me.navigationController pushViewController:chatVC animated:YES];
		}];
	}];
}

/// The paths this screen has always matched by hand, now the fallback for a
/// link Telegram gave no kind for.
- (void)openTelegramLinkByPath:(NSString *)clean
						   url:(NSURL *)u
				isTelegramHost:(BOOL)isTelegramHost
			  isTelegramScheme:(BOOL)isTelegramScheme
						  host:(NSString *)host {
	{
		NSString *inviteHash = nil;
		if (isTelegramHost) {
			NSString *path = u.path;
			if ([path hasPrefix:@"/+"]) {
				inviteHash = [path substringFromIndex:2];
			} else if ([path hasPrefix:@"/joinchat/"]) {
				inviteHash = [path substringFromIndex:10];
			}
		} else if (isTelegramScheme && [host isEqualToString:@"join"]) {
			for (NSString *param in [u.query componentsSeparatedByString:@"&"]) {
				NSArray *kv = [param componentsSeparatedByString:@"="];
				if (kv.count == 2 && [kv[0] isEqualToString:@"invite"]) {
					inviteHash = kv[1];
					break;
				}
			}
		}

		if (inviteHash.length) {
			[self joinChatByInviteLink:clean];
			return;
		}

		NSString *username = nil;
		if (isTelegramHost) {
			NSString *path = u.path;
			if ([path hasPrefix:@"/"]) path = [path substringFromIndex:1];
			NSRange slash = [path rangeOfString:@"/"];
			username = (slash.location != NSNotFound) ? [path substringToIndex:slash.location] : path;
		} else if (isTelegramScheme) {
			for (NSString *param in [u.query componentsSeparatedByString:@"&"]) {
				NSArray *kv = [param componentsSeparatedByString:@"="];
				if (kv.count == 2 && [kv[0] isEqualToString:@"domain"]) {
					username = kv[1];
					break;
				}
			}
		}

		if (username.length && ![username isEqualToString:@"joinchat"] && ![username hasPrefix:@"+"]) {
			[self openChatWithUsername:username];
			return;
		}
	}

	[self openPlainLink:u];
}

/// Anything that is not a Telegram link: Safari, which is the whole of what
/// this app does with the web.
- (void)openPlainLink:(NSURL *)url {
	if (url)
		[[UIApplication sharedApplication] openURL:url];
}

/// An external link gets one sheet before it leaves the app. Telegram is
/// asked twice: which browser the host needs, and whether the link signs in
/// or asks for write access. A login link is not opened until the user has
/// seen the domain and the permission, which is the whole reason TDLib
/// exposes getExternalLinkInfo.
- (void)presentExternalLink:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] webBrowserTypeForURL:link completion:^(NSString *browser){
		[[TGMessageStore shared] externalLinkInfoForURL:link completion:^(NSDictionary *info){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			[me showExternalLink:link browser:browser info:info];
		}];
	}];
}

- (void)showExternalLink:(NSString *)link
				 browser:(NSString *)browser
					info:(NSDictionary *)info {
	NSString *host = [NSURL URLWithString:link].host ?: link;
	BOOL write = [info[@"requestWriteAccess"] boolValue];

	NSMutableString *message = [NSMutableString string];

	__weak typeof(self) weakSelf = self;
	// A page Telegram already knows how to read opens in the reader, with no
	// sheet in between; the sheet is for links that leave the app.
	if (!write){
		[[TGMessageStore shared] instantViewForURL:link onlyLocal:YES completion:^(NSDictionary *view){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			NSArray *blocks = view[@"blocks"];
			if ([blocks isKindOfClass:NSArray.class] && blocks.count){
				[me openInstantViewForLink:link view:view];
				return;
			}
			[me showLinkChoices:link host:host message:message write:write];
		}];
		return;
	}
	[self showLinkChoices:link host:host message:message write:write];
}

- (void)showLinkChoices:(NSString *)link
				   host:(NSString *)host
				message:(NSMutableString *)message
				  write:(BOOL)write {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Open Link", @"Instant View", @"Copy Link"]
						title:host
					  message:message
			 destructiveIndex:-1
					   inView:self.navigationController.view ?: self.view
					 onChoice:^(NSInteger index){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		if (index == 0){
			[[TGMessageStore shared] externalLinkForURL:link
								 allowWriteAccess:write
									  completion:^(NSString *resolved){
				NSString *target = resolved.length ? resolved : link;
				[me openPlainLink:[NSURL URLWithString:target]];
			}];
		} else if (index == 1){
			[me openInstantViewForLink:link];
		} else {
			[UIPasteboard generalPasteboard].string = link;
			[TGSnackbar showInView:me.navigationController.view ?: me.view
							  text:@"Link copied." seconds:2 onCommit:nil];
		}
	}];
}

/// Telegram's reader view, pushed as its own screen. A page without one is
/// not an error worth a screen: the sheet says so and the user can open it
/// in Safari instead.
- (void)openInstantViewForLink:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[[TGMessageStore shared] instantViewForURL:link onlyLocal:NO
							  completion:^(NSDictionary *view){
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		NSArray *blocks = view[@"blocks"];
		if (![blocks isKindOfClass:NSArray.class] || !blocks.count){
			[TGAlertSheet showMessage:@"An error occurred."
							   title:@"Instant View"
							   inView:me.navigationController.view ?: me.view];
			return;
		}
		[me openInstantViewForLink:link view:view];
	}];
}

- (void)openInstantViewForLink:(NSString *)link view:(NSDictionary *)view {
	NSArray *blocks = view[@"blocks"];
	if (![blocks isKindOfClass:NSArray.class] || !blocks.count)
		return;
	NSString *site = view[@"site_name"];
	if (![site isKindOfClass:NSString.class] || !site.length){
		// TDLib's instant view does not carry the site name; the link preview
		// does. Ask for it rather than titling every reader with the host.
		__weak typeof(self) weakSelf = self;
		[[TGMessageStore shared] linkPreviewForText:link completion:^(NSDictionary *preview){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			[me presentInstantView:link view:view site:preview[@"site"]];
		}];
		return;
	}
	[self presentInstantView:link view:view site:site];
}

- (void)presentInstantView:(NSString *)link view:(NSDictionary *)view
					 site:(NSString *)site {
	NSArray *blocks = view[@"blocks"];
	if (![blocks isKindOfClass:NSArray.class] || !blocks.count)
		return;
	TGInstantViewController *reader = [[TGInstantViewController alloc] init];
	reader.pageSiteName = [site isKindOfClass:NSString.class] && site.length
			? site : nil;
	reader.pageTitle = [NSURL URLWithString:link].host ?: @"Instant View";
	reader.sourceURL = link;
	reader.blocks = blocks;
	reader.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:reader animated:YES];
}



#pragma mark - files and music

/// A file from the system picker. iOS 8 is the first OS with one; on iOS 6/7
/// the sheet says so instead of pretending a button works.
- (void)pickDocument {
	Class pickerClass = NSClassFromString(@"UIDocumentPickerViewController");
	if (!pickerClass){
		[TGAlertSheet showMessage:TGLocalized(@"Sending files needs iOS 8 or later.")
							title:TGLocalized(@"File") inView:self.view];
		return;
	}
	id picker = [[pickerClass alloc] initWithDocumentTypes:@[(NSString *)kUTTypeData]
													 inMode:1 /* UIDocumentPickerModeImport */];
	[picker setDelegate:(id<UIDocumentPickerDelegate>)self];
	[self presentViewController:picker animated:YES completion:nil];
}

/// Music comes from the iPod library, which iOS 6 already had. The item is
/// exported to a temporary .m4a because TDLib sends a local file, not a
/// library URL.
- (void)pickAudio {
	MPMediaPickerController *picker = [[MPMediaPickerController alloc]
			initWithMediaTypes:MPMediaTypeMusic];
	picker.delegate = self;
	picker.allowsPickingMultipleItems = NO;
	picker.prompt = TGLocalized(@"Choose a track");
	[self presentViewController:picker animated:YES completion:nil];
}

- (NSString *)attachmentCaption {
	return [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

- (void)clearComposerAfterAttachment {
	self.input.text = @"";
	self.composerText = [[TGComposerText alloc] initWithText:@"" entities:@[]];
	[self clearComposeState];
	[[TGMessageStore shared] setDraft:@"" inChat:self.chatId thread:self.threadId replyTo:0];
	[[TGMessageStore shared] cancelTypingInChat:self.chatId thread:self.threadId];
}

- (void)sendPickedDocumentAtPath:(NSString *)path {
	if (!path.length)
		return;
	NSString *caption = [self attachmentCaption];
	[[TGSendStore shared] sendDocumentAtPath:path caption:caption
									  toChat:self.chatId thread:self.threadId];
	if (caption.length)
		[self clearComposerAfterAttachment];
}

- (void)sendPickedAudioAtPath:(NSString *)path title:(NSString *)title
					performer:(NSString *)performer duration:(NSInteger)seconds {
	if (!path.length)
		return;
	NSString *caption = [self attachmentCaption];
	[[TGSendStore shared] sendAudioAtPath:path title:title performer:performer
								 duration:seconds caption:caption
								   toChat:self.chatId thread:self.threadId];
	if (caption.length)
		[self clearComposerAfterAttachment];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
	didPickDocumentAtURL:(NSURL *)url {
	[self dismissViewControllerAnimated:YES completion:^{
		[self sendPickedDocumentAtPath:url.path];
	}];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
	didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	[self dismissViewControllerAnimated:YES completion:^{
		NSURL *url = urls.firstObject;
		if (url)
			[self sendPickedDocumentAtPath:url.path];
	}];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker
 didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	MPMediaItem *item = mediaItemCollection.items.firstObject;
	[self dismissViewControllerAnimated:YES completion:^{
		if (!item)
			return;
		NSURL *assetURL = [item valueForProperty:MPMediaItemPropertyAssetURL];
		if (!assetURL){
			[TGAlertSheet showMessage:TGLocalized(@"This track cannot be sent.")
								title:TGLocalized(@"Music") inView:self.view];
			return;
		}
		NSString *out = [NSTemporaryDirectory() stringByAppendingPathComponent:
				[NSString stringWithFormat:@"tg-audio-%.0f.m4a",
						[[NSDate date] timeIntervalSince1970] * 1000.0]];
		AVURLAsset *asset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
		AVAssetExportSession *export = [[AVAssetExportSession alloc]
				initWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
		export.outputURL = [NSURL fileURLWithPath:out];
		export.outputFileType = AVFileTypeAppleM4A;
		__weak typeof(self) weakSelf = self;
		[export exportAsynchronouslyWithCompletionHandler:^{
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				if (export.status != AVAssetExportSessionStatusCompleted){
					[TGAlertSheet showMessage:TGLocalized(@"This track cannot be sent.")
										title:TGLocalized(@"Music") inView:me.view];
					return;
				}
				NSString *title = [item valueForProperty:MPMediaItemPropertyTitle] ?: @"";
				NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist] ?: @"";
				[me sendPickedAudioAtPath:out title:title performer:artist
								 duration:(NSInteger)round(item.playbackDuration)];
			});
		}];
	}];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	[self dismissViewControllerAnimated:YES completion:nil];
}


@end
