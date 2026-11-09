#import "TGProfileViewController.h"
#import "TGSettingsViewControllerInternal.h"
#import "TGPrivacyRuleViewController.h"
#import "TGAlertSheet.h"
#import "TGStyle.h"
#import "TGInstantViewController.h"
#import "TGUsernameSettingsViewController.h"
#import "TGQRCode.h"
#include <time.h>

/// The bar button's QR glyph: three finder squares and a centre dot, drawn at
/// whatever size the navigation bar asks for.
static const CGFloat kSettingsQRIconSide = 24.0f;
static const CGFloat kSettingsQRSide = 220.0f;
static const CGFloat kSettingsQRTopOffset = 30.0f;

/// The bar button's QR glyph, from TGIconPaths.
static UIImage *TGSettingsQRIcon(void) {
	UIImage *image = [TGIcons glyphNamed:@"qr" colour:[UIColor blackColor]
									side:kSettingsQRIconSide];
	// Template rendering is iOS 7+; iOS 6 bar items tint the glyph anyway.
	if ([image respondsToSelector:@selector(imageWithRenderingMode:)])
		image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	return image;
}

/// Your own account's QR, not the login scanner. The code points at the
/// account's public link when it has one; without a username it points at the
/// account id Telegram knows.
@interface TGSettingsAccountQRViewController : UIViewController
@property (nonatomic, copy) NSString *code;
@end

@implementation TGSettingsAccountQRViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"QR Code");
	self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
	CGFloat side = kSettingsQRSide;
	UIImageView *image = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
	image.center = CGPointMake(CGRectGetMidX(self.view.bounds),
			CGRectGetMidY(self.view.bounds) - kSettingsQRTopOffset);
	image.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin;
	image.image = TGQRCodeImage(self.code, side);
	[self.view addSubview:image];
	UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricPadLarge,
			CGRectGetMaxY(image.frame) + TGMetricPadLarge,
			self.view.bounds.size.width - TGDoubled(TGMetricPadLarge), TGMetricLineRow)];
	caption.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	caption.textAlignment = NSTextAlignmentCenter;
	caption.font = TGFontBody();
	caption.textColor = [[TGTheme shared] secondaryTextColour];
	caption.backgroundColor = [UIColor clearColor];
	caption.text = self.code;
	[self.view addSubview:caption];
}
@end

/// ThemeSettingsFontSizeItem is a slider of seven positions. It edits the
/// message size the whole app reads from TGTheme, and the sample above it is
/// the same face at that size.
@interface TGTextSizeViewController : UIViewController
@end

@implementation TGTextSizeViewController {
	UISlider *_slider;
	UILabel *_sample;
	NSInteger _step;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Text Size");
	self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

	CGFloat width = self.view.bounds.size.width;
	CGFloat sliderW = width - TGDoubled(TGMetricPadLarge);
	TGTheme *theme = [TGTheme shared];
	_step = TGMessageFontSizeStep(theme.messageFontSize);

	_sample = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricPadLarge, TGMetricPadLarge, sliderW,
					TGMetricLineTitle + TGMetricPadLarge)];
	_sample.text = TGLocalized(@"Hello");
	_sample.textAlignment = NSTextAlignmentCenter;
	_sample.textColor = [theme primaryTextColour];
	_sample.backgroundColor = [UIColor clearColor];
	_sample.adjustsFontSizeToFitWidth = YES;
	[self.view addSubview:_sample];

	UILabel *small = [[UILabel alloc] initWithFrame:
			CGRectMake(TGMetricPadLarge, CGRectGetMaxY(_sample.frame) + TGMetricPadLarge,
					TGMetricLineRow, TGMetricLineRow)];
	small.text = @"A";
	small.font = TGFontMicro();
	small.textColor = [theme secondaryTextColour];
	small.backgroundColor = [UIColor clearColor];
	[self.view addSubview:small];

	UILabel *large = [[UILabel alloc] initWithFrame:
			CGRectMake(width - TGMetricPadLarge - TGMetricLineRow,
					CGRectGetMinY(small.frame), TGMetricLineRow, TGMetricLineRow)];
	large.text = @"A";
	large.font = TGFontHeader();
	large.textAlignment = NSTextAlignmentRight;
	large.textColor = [theme primaryTextColour];
	large.backgroundColor = [UIColor clearColor];
	[self.view addSubview:large];

	CGFloat sliderX = CGRectGetMaxX(small.frame) + TGMetricPad;
	_slider = [[UISlider alloc] initWithFrame:
			CGRectMake(sliderX, TGCenteredOrigin(TGMetricLineRow, TGMetricSliderH) +
					CGRectGetMinY(small.frame), width - TGDoubled(sliderX), TGMetricSliderH)];
	_slider.minimumValue = 0;
	_slider.maximumValue = TGMetricMessageSizeSteps - 1;
	_slider.value = (float)_step;
	if ([_slider respondsToSelector:@selector(setMinimumTrackTintColor:)])
		_slider.minimumTrackTintColor = [theme accentColour];
	_slider.continuous = YES;
	[_slider addTarget:self action:@selector(sizeChanged:)
	  forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:_slider];
	[self updateSample];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.navigationController.navigationBarHidden)
		[self.navigationController setNavigationBarHidden:NO animated:NO];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)sizeChanged:(UISlider *)slider {
	NSInteger step = (NSInteger)lroundf(slider.value);
	if (step == _step)
		return;
	_step = step;
	slider.value = (float)step;
	[TGTheme shared].messageFontSize = TGMessageFontSizeForStep(step);
	[self updateSample];
}

- (void)updateSample {
	CGFloat size = TGMessageFontSizeForStep(_step);
	_sample.font = TGFontAtSize(size);
	CGFloat height = _sample.font.lineHeight + TGMetricPadLarge;
	CGRect frame = _sample.frame;
	frame.size.height = height;
	_sample.frame = frame;
}

@end

@implementation TGSettingsViewController (Actions)

#pragma mark - actions

/// Your own profile, as everyone else sees it - their "My Profile" row.
- (void)openMyProfile {
	[self openMyProfileOnTab:nil];
}

- (void)openMyProfileOnTab:(NSString *)tab {
	int64_t userId = [[TGClient shared].me[@"id"] longLongValue];
	if (!userId)
		return;
	TGProfileViewController *profile = [[TGProfileViewController alloc]
			initWithChatId:userId userId:userId
					 title:[TGClient shared].me[@"first_name"] ?: @"Profile"];
	profile.storedMediaKind = tab;
	profile.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:profile animated:YES];
}

- (void)openEditProfile {
	TGEditProfileViewController *edit = [[TGEditProfileViewController alloc] init];
	edit.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:edit animated:YES];
}

- (void)openUsername {
	TGUsernameSettingsViewController *username =
			[[TGUsernameSettingsViewController alloc] init];
	username.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:username animated:YES];
}

- (UIImage *)qrBarIcon {
	return TGSettingsQRIcon();
}

- (void)openQRCode {
	NSDictionary *me = [TGClient shared].me;
	NSString *username = me[@"username"];
	NSString *code = username.length
			? [NSString stringWithFormat:@"https://t.me/%@", username]
			: [NSString stringWithFormat:@"tg://user?id=%lld",
					(long long)[me[@"id"] longLongValue]];
	TGSettingsAccountQRViewController *qr = [[TGSettingsAccountQRViewController alloc] init];
	qr.code = code;
	qr.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:qr animated:YES];
}

/// The account switcher: each account's title with the active one marked,
/// then Add Account while fewer than three are in use. Picking an account
/// switches to it; Add Account makes a new slot and switches straight over,
/// so an empty slot lands on the login screen.
- (void)showAccountChoices {
	__weak typeof(self) weakSelf = self;
	NSArray *slots = [TGClient accountSlots];
	NSInteger active = [TGClient activeAccountSlot];

	NSMutableArray *choices = [NSMutableArray arrayWithCapacity:slots.count + 1];
	NSMutableArray *choiceSlots = [NSMutableArray arrayWithCapacity:slots.count];
	for (NSDictionary *entry in slots){
		NSInteger slot = [entry[@"slot"] integerValue];
		NSString *title = [entry[@"title"] length] ? entry[@"title"]
				: ([entry[@"phone"] length] ? entry[@"phone"] : @"Account");
		[choiceSlots addObject:@(slot)];
		[choices addObject:slot == active
				? [NSString stringWithFormat:@"%@ ✓", title] : title];
	}
	if (slots.count < 3)
		[choices addObject:@"Add Account"];

	[TGAlertSheet showChoices:choices
						title:@"Switch Account"
					  message:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;
		if (index < (NSInteger)choiceSlots.count){
			NSInteger slot = [choiceSlots[index] integerValue];
			if (slot != active)
				[[TGClient shared] switchToAccountSlot:slot];
			return;
		}
		// The one row after the accounts is Add Account.
		NSInteger newSlot = [TGClient addAccount];
		if (newSlot >= 0)
			[[TGClient shared] switchToAccountSlot:newSlot];
	}];
}

- (void)pickProfilePhoto {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	self.pickingProfilePhoto = YES;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)pushPlaceholder:(NSString *)featureName {
	TGPlaceholderViewController *placeholder = [[TGPlaceholderViewController alloc] init];
	placeholder.featureName = featureName;
	placeholder.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:placeholder animated:YES];
}

- (void)openURL:(NSString *)url {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

/// Saved Messages is a real chat - your own - so it opens as one rather than
/// as a page saying the feature is missing.
- (void)openSavedMessages {
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId){
		// The id arrives with the account record shortly after login. Wait
		// for it instead of putting a "Loading..." alert in the user's way.
		BOOL onScreen = self.isViewLoaded && self.view.window != nil;
		if (TGSettingsSavedMessagesShouldRetry(self.savedMessagesRetries, onScreen)){
			self.savedMessagesRetries++;
			[self performSelector:@selector(openSavedMessages) withObject:nil afterDelay:0.3];
		} else {
			self.savedMessagesRetries = 0;
			if (onScreen)
				[self toast:@"An error occurred."];
		}
		return;
	}
	self.savedMessagesRetries = 0;
	[self openChat:chatId title:@"Saved Messages"];
}

- (void)openChat:(int64_t)chatId title:(NSString *)title {
	// Loaded by name to keep the settings screen from knowing about chats in
	// general; it only ever opens one at a time.
	Class chatClass = NSClassFromString(@"TGChatViewController");
	UIViewController *chat = [[chatClass alloc] init];
	[chat setValue:@(chatId) forKey:@"chatId"];
	[chat setValue:(title ?: @"") forKey:@"chatTitle"];
	chat.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:chat animated:YES];
}

- (void)showPremiumState {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] premiumStateWithCompletion:^(NSString *summary){
		[TGAlertSheet showMessage:(summary.length ? summary
						: @"Telegram Premium")
							title:@"Telegram Premium" inView:weakSelf.view];
	}];
}

/// Their Two-Step Verification page, as a sheet: what the state is, and the
/// three things that can be done to it. The password is never held - each
/// request carries the one just typed and nothing keeps it afterwards.
- (void)showTwoStepState {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] hasPasswordWithCompletion:^(BOOL has, NSString *email){
		TGSettingsViewController *me = weakSelf;
		if (!me)
			return;

		(void)email;
		NSArray *choices = has
				? @[@"Change Password", @"Recovery Email", @"Disable Password",
					@"Forgot Password?"]
				: @[@"Set a Password"];

		[TGAlertSheet showChoices:choices
							title:@"Two-Step Verification"
						  message:nil
				 destructiveIndex:(has ? 2 : -1)
						   inView:me.view
						 onChoice:^(NSInteger index){
			if (!has){
				[me askNewPasswordReplacing:nil];
				return;
			}
			if (index == 0)
				[me askCurrentPasswordThen:^(NSString *current){
					[me askNewPasswordReplacing:current];
				}];
			else if (index == 1)
				[me askRecoveryAddress];
			else if (index == 3)
				[me showLostPasswordFlow];
			else
				[me askTurnPasswordOff];
		}];
	}];
}

/// The gate every change goes through. Asked once, handed on, forgotten.
- (void)askCurrentPasswordThen:(void (^)(NSString *current))next {
	[TGAlertSheet showSecureInput:@"Enter your password"
						  message:nil
					  placeholder:@"Password"
						   action:@"Continue"
						   inView:self.view
						 onSubmit:^(NSString *current){
		if (next) next(current);
	}];
}

/// A new password, then its hint. Telegram shows the hint to whoever is
/// signing in, so it is asked for separately rather than guessed at.
- (void)askNewPasswordReplacing:(NSString *)current {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showSecureInput:@"New Password"
						  message:nil
					  placeholder:@"Password"
						   action:@"Next"
						   inView:self.view
						 onSubmit:^(NSString *new){
		TGSettingsViewController *me = weakSelf;
		[TGAlertSheet showInput:@"Hint"
						message:nil
					placeholder:@"Hint"
						   text:nil
						 action:@"Save"
						 inView:me.view
					   onSubmit:^(NSString *hint){
			[me commitPassword:new replacing:current hint:hint];
		}];
	}];
}

/// Set Password with an empty hint has to be reachable too, so the hint sheet
/// being cancelled is not the end of the flow - this is the shared landing.
- (void)commitPassword:(NSString *)new replacing:(NSString *)current
				  hint:(NSString *)hint {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPassword:current
							   new:new
							  hint:hint
				   setEmailAddress:NO
							 email:nil
						completion:^(BOOL ok){
		TGSettingsViewController *me = weakSelf;
		if (!ok){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Two-Step Verification" inView:me.view];
			return;
		}
		me.hasPassword = YES;
		me.passwordKnown = YES;
		[me rebuild];
		[TGAlertSheet showMessage:@"Password set"
							title:@"Two-Step Verification" inView:me.view];
	}];
}

/// Off is an empty new password, not a request of its own - and it still
/// needs the current one.
- (void)askTurnPasswordOff {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Disable Password"
					   action:@"Disable Password"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		TGSettingsViewController *me = weakSelf;
		[me askCurrentPasswordThen:^(NSString *current){
			[[TGClient shared] setPassword:current
									   new:@""
									  hint:@""
						   setEmailAddress:NO
									 email:nil
								completion:^(BOOL ok){
				if (!ok){
					[TGAlertSheet showMessage:@"This password is incorrect."
										title:@"Disable Password" inView:me.view];
					return;
				}
				me.hasPassword = NO;
				me.passwordKnown = YES;
				[me rebuild];
				[TGAlertSheet showMessage:@"Password Removed"
									title:@"Disable Password" inView:me.view];
			}];
		}];
	}];
}

/// Reading the address back needs the password, which is the whole point of
/// it - so the same sheet shows what is there and offers to change it.
- (void)askRecoveryAddress {
	__weak typeof(self) weakSelf = self;
	[self askCurrentPasswordThen:^(NSString *current){
		TGSettingsViewController *me = weakSelf;
		[[TGClient shared] recoveryEmailAddress:current completionWithError:^(NSString *email,
																	  NSString *error){
			if (error.length){
				[TGAlertSheet showMessage:error title:@"Recovery Email"
								   inView:me.view];
				return;
			}
			[TGAlertSheet showChoices:@[@"Change Email"]
								title:@"Recovery Email"
							  message:(email.length ? email : nil)
					 destructiveIndex:-1
							   inView:me.view
							 onChoice:^(NSInteger index){
				[TGAlertSheet showInput:@"Recovery Email"
								message:nil
							placeholder:@"you@example.com"
								   text:email
								 action:@"Save"
								 inView:me.view
							   onSubmit:^(NSString *address){
					[[TGClient shared] setRecoveryEmailAddress:current
															to:address
													completion:^(BOOL ok){
						if (!ok){
							[TGAlertSheet showMessage:@"An error occurred."
												title:@"Recovery Email"
											   inView:me.view];
							return;
						}
						// The address is not in force until the code sent to
						// it is entered, so the flow has to ask for it rather
						// than stopping at "we have written".
						[me askRecoveryEmailCodeFor:address];
					}];
				}];
			}];
		}];
	}];
}

/// The code Telegram emails to a new recovery address. Cancelling leaves the
/// old address standing - and the cancel is a request of its own, so the
/// server's answer replaces the guess that nothing happened.
- (void)askRecoveryEmailCodeFor:(NSString *)address {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Enter Code", @"Cancel"]
						title:@"Email Code"
					  message:address
			 destructiveIndex:1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (index == 1){
			[[TGClient shared] cancelRecoveryEmailAddressVerificationWithCompletion:
					^(NSDictionary *state, NSString *error){
				NSString *said = error;
				if (!said){
					said = [state[@"hasRecoveryEmail"] boolValue]
							? [NSString stringWithFormat:@"%@",
									state[@"recoveryPattern"] ?: @"Recovery Email"]
							: @"Recovery Email";
				}
				[TGAlertSheet showMessage:said title:@"Recovery Email"
								   inView:me.view];
			}];
			return;
		}
		[TGAlertSheet showInput:@"Email Code"
						message:address
					placeholder:@"Code"
						   text:nil
						 action:@"Confirm"
						 inView:me.view
					   onSubmit:^(NSString *code){
			[[TGClient shared] checkRecoveryEmailCode:code completion:^(BOOL ok){
				if (ok){
					[TGAlertSheet showMessage:@"Done"
										title:@"Recovery Email" inView:me.view];
					return;
				}
				[TGAlertSheet showChoices:@[@"Re-send Code", @"Enter Code"]
									title:@"Recovery Email"
								  message:nil
						 destructiveIndex:-1
								   inView:me.view
								 onChoice:^(NSInteger choice){
					if (choice == 1){
						[me askRecoveryEmailCodeFor:address];
						return;
					}
					[[TGClient shared] resendRecoveryEmailCode];
					[me askRecoveryEmailCodeFor:address];
				}];
			}];
		}];
	}];
}

/// The end of the road. Two confirmations, then the reason their own form
/// asks for, then the password when two-step verification is on.
- (void)askDeleteAccountNow {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Delete My Account"
					   action:@"Delete My Account"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		TGSettingsViewController *me = weakSelf;
		[TGAlertSheet showInput:@"Reason"
						message:nil
					placeholder:@"Reason"
						   text:nil
						 action:@"Continue"
						 inView:me.view
					   onSubmit:^(NSString *reason){
			void (^finish)(NSString *) = ^(NSString *password){
				[[TGClient shared] deleteAccountWithReason:reason
												  password:password
												completion:^(BOOL ok){
					if (!ok)
						[TGAlertSheet showMessage:@"An error occurred."
											title:@"Delete My Account" inView:me.view];
					// On success TDLib logs out on its own and the login
					// screen takes over; there is nothing left to say.
				}];
			};
			if (me.hasPassword)
				[me askCurrentPasswordThen:finish];
			else
				finish(nil);
		}];
	}];
}

- (void)openSupport {
	// Official shows the FAQ intro first; OK then opens the support chat and
	// the FAQ button opens the same cached page as the row above it. The
	// alert has only those two buttons, no Cancel.
	__weak typeof(self) weakSelf = self;
	void (^openSupportChat)(void) = ^{
		[[TGClient shared] supportUserWithCompletion:^(NSDictionary *user, NSString *error){
			if (!user){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Support" inView:weakSelf.view];
				return;
			}
			int64_t userId = [user[@"id"] longLongValue];
			[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId){
				if (!chatId){
					[TGAlertSheet showMessage:@"An error occurred."
										title:@"Support" inView:weakSelf.view];
					return;
				}
				[weakSelf openChat:chatId title:(user[@"name"] ?: @"Support")];
			}];
		}];
	};
	// One literal: the pack key is the whole paragraph.
	NSString *text = @"Please note that Telegram Support is done by volunteers. We try to respond as quickly as possible, but it may take a while.\n\nPlease take a look at the Telegram FAQ: it has important troubleshooting tips and answers to most questions.";
	[TGAlertSheet showAlertActions:@[@"Telegram FAQ", @"OK"]
							 title:nil
						   message:text
							inView:self.view
						  onAction:^(NSInteger index){
		if (index == 0)
			[weakSelf openFAQ];
		else
			openSupportChat();
	}];
}

/// Telegram's FAQ is an Instant View page; opening Safari left the app for a
/// page it already has on the device.
- (void)openFAQ {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] instantViewForURL:@"https://telegram.org/faq"
							   onlyLocal:YES
							  completion:^(NSDictionary *view){
		if (!view){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Telegram FAQ" inView:weakSelf.view];
			return;
		}
		TGInstantViewController *page = [[TGInstantViewController alloc] init];
		page.pageTitle = @"Telegram FAQ";
		page.sourceURL = @"https://telegram.org/faq";
		page.blocks = view[@"blocks"] ?: @[];
		page.hidesBottomBarWhenPushed = YES;
		[weakSelf.navigationController pushViewController:page animated:YES];
	}];
}

/// "Telegram Features" is the @TelegramTips chat, not the blog in Safari.
- (void)openTelegramTips {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatWithUsername:@"TelegramTips"
							completion:^(int64_t chatId, NSString *title){
		if (!chatId){
			[TGAlertSheet showMessage:@"An error occurred."
								title:@"Telegram Features" inView:weakSelf.view];
			return;
		}
		[weakSelf openChat:chatId title:(title ?: TGLocalized(@"Telegram Features"))];
	}];
}

- (void)askPrivacyRuleAtIndex:(NSUInteger)index {
	NSString *setting = [TGSettingsViewController privacySettings][index];
	NSString *title = [TGSettingsViewController privacyTitles][index];
	__weak typeof(self) weakSelf = self;
	TGPrivacyRuleViewController *vc =
			[[TGPrivacyRuleViewController alloc] initWithSetting:setting title:title];
	vc.onChanged = ^(NSString *changedSetting, NSString *newRuleType){
		weakSelf.privacy[changedSetting] = newRuleType;
		[weakSelf rebuild];
	};
	vc.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:vc animated:YES];
}

/// Official opens TextSizeSelectionController from this row; the slider there
/// is ThemeSettingsFontSizeItem. The size itself stays in TGTheme.
- (void)chooseTextSize {
	TGTextSizeViewController *size = [[TGTextSizeViewController alloc] init];
	size.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:size animated:YES];
}

#pragma mark - wallpaper

- (void)chooseWallpaper {
	if ([TGTheme shared].wallpaper){
		__weak typeof(self) weakSelf = self;
		[TGAlertSheet showChoices:@[@"Remove", @"Choose Wallpaper"]
							title:@"Chat Wallpaper"
				 destructiveIndex:0
						   inView:self.view
						 onChoice:^(NSInteger index){
			if (index == 0)
				[[TGTheme shared] setWallpaperImage:nil];
			else
				[weakSelf presentWallpaperPicker];
			[weakSelf rebuild];
		}];
		return;
	}
	[self presentWallpaperPicker];
}

- (void)presentWallpaperPicker {
	if (![UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image){
		self.pickingProfilePhoto = NO;
		return;
	}

	// One picker serves the wallpaper and the profile picture, so it has to
	// know which row opened it.
	if (self.pickingProfilePhoto){
		self.pickingProfilePhoto = NO;
		[self uploadProfilePhoto:image];
		return;
	}
	[[TGTheme shared] setWallpaperImage:image];
	[self rebuild];
}

/// TDLib uploads from a file, and a camera frame is far larger than a picture
/// anyone will ever see as an avatar - so it is scaled before it is written.
- (void)uploadProfilePhoto:(UIImage *)image {
	UIImage *scaled = [TGIcons decodedImage:image
								fittingSize:CGSizeMake(TGMetricUploadPhotoSide, TGMetricUploadPhotoSide)
									   fill:NO scale:TGMetricScaleFull];
	NSString *path = [NSTemporaryDirectory()
			stringByAppendingPathComponent:@"profile-photo.jpg"];
	if (![UIImageJPEGRepresentation(scaled, TGCompressionQualityStandard) writeToFile:path atomically:YES]){
		[self toast:@"An error occurred."];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setProfilePhotoAtPath:path completion:^(BOOL ok){
		if (!ok){
			[weakSelf toast:@"An error occurred."];
			return;
		}
		// The new file id arrives with the updateUser that follows.
		weakSelf.profileCell = nil;
		[weakSelf rebuild];
	}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.pickingProfilePhoto = NO;
	[picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - password recovery inside the account

/// A time Telegram named, written by the same formatter the scheduled-message
/// sheet uses. Building an NSDateFormatter here made the date follow the
/// phone's medium/short styles instead of the selected language pack.
static NSString *TGSettingsDateString(double stamp) {
	return TGSettingsDateTimeText(stamp, (NSTimeInterval)time(NULL));
}

/// The two roads open to an account that has a password it cannot type: the
/// recovery address, or the slow reset Telegram allows without one. Both
/// requests answer with their own refusal, which is what the sheets show.
- (void)showLostPasswordFlow {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Recovery Email", @"Reset Account"]
						title:@"Forgot Password?"
					  message:nil
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (index == 1){
			[me askResetPassword];
			return;
		}
		[[TGClient shared] requestAccountPasswordRecoveryWithCompletion:
				^(NSString *pattern, NSString *error){
			if (error){
				[TGAlertSheet showChoices:@[@"Reset Account"]
									title:@"Forgot Password?"
								  message:error
						 destructiveIndex:-1
								   inView:me.view
								 onChoice:^(NSInteger ignored){
					[me askResetPassword];
				}];
				return;
			}
			[me askPasswordRecoveryCodeFor:pattern];
		}];
	}];
}

- (void)askPasswordRecoveryCodeFor:(NSString *)pattern {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Email Code"
					message:pattern
				placeholder:@"Code"
					   text:nil
					 action:@"Check"
					 inView:self.view
				   onSubmit:^(NSString *code){
		TGSettingsViewController *me = weakSelf;
		[[TGClient shared] checkAccountPasswordRecoveryCode:code completion:^(NSString *error){
			if (error){
				[TGAlertSheet showChoices:@[@"Enter Code"]
									title:@"Email Code"
								  message:error
						 destructiveIndex:-1
								   inView:me.view
								 onChoice:^(NSInteger ignored){
					[me askPasswordRecoveryCodeFor:pattern];
				}];
				return;
			}
			[TGAlertSheet showSecureInput:@"New Password"
								  message:nil
							  placeholder:@"Password"
								   action:@"Next"
								   inView:me.view
								 onSubmit:^(NSString *password){
				[TGAlertSheet showInput:@"Hint"
								message:nil
							placeholder:@"Hint"
								   text:nil
								 action:@"Save"
								 inView:me.view
							   onSubmit:^(NSString *hint){
					[[TGClient shared] recoverAccountPasswordWithCode:code
														   newPassword:password
																  hint:hint
															completion:^(NSDictionary *state,
																		 NSString *recoverError){
						if (recoverError){
							[TGAlertSheet showMessage:recoverError
												title:@"Forgot Password?"
											   inView:me.view];
							return;
						}
						me.hasPassword = [state[@"hasPassword"] boolValue];
						me.passwordKnown = YES;
						[me rebuild];
						[TGAlertSheet showMessage:[state[@"hasPassword"] boolValue]
								? @"Password set"
								: @"Password Removed"
											title:@"Forgot Password?" inView:me.view];
					}];
				}];
			}];
		}];
	}];
}

/// The reset Telegram allows without the address: repeated calls move a date
/// forward until the password can be dropped. The reply names which stage it
/// is at, and a pending one can still be called off.
- (void)askResetPassword {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showConfirm:nil
						title:@"Reset Account"
					   action:@"Continue"
				  destructive:YES
					   inView:self.view
					onConfirm:^{
		TGSettingsViewController *me = weakSelf;
		[[TGClient shared] resetAccountPasswordWithCompletion:
				^(NSString *result, double date, NSString *error){
			if ([result isEqualToString:@"ok"]){
				me.hasPassword = NO;
				me.passwordKnown = YES;
				[me rebuild];
				[TGAlertSheet showMessage:@"Password Removed"
									title:@"Reset Account" inView:me.view];
				return;
			}
			if ([result isEqualToString:@"pending"]){
				[TGAlertSheet showChoices:@[@"Cancel"]
									title:@"Reset"
								  message:TGSettingsDateString(date)
						 destructiveIndex:1
								   inView:me.view
								 onChoice:^(NSInteger ignored){
					[[TGClient shared] cancelAccountPasswordResetWithCompletion:
							^(NSString *cancelError){
						[TGAlertSheet showMessage:(cancelError ?: @"Done")
											title:@"Reset Account"
										   inView:me.view];
					}];
				}];
				return;
			}
			if ([result isEqualToString:@"declined"]){
				[TGAlertSheet showMessage:(error ?: @"An error occurred.")
									title:@"Reset Account" inView:me.view];
				return;
			}
			[TGAlertSheet showMessage:(error ?: @"An error occurred.")
								title:@"Reset Account" inView:me.view];
		}];
	}];
}

#pragma mark - login email address

/// The login email is the address Telegram mails when a new device signs in.
/// Whether the account may change it is the server's call, and that answer
/// is said before the field is offered rather than after it is refused.
- (void)showLoginEmailFlow {
	__weak typeof(self) weakSelf = self;
	// Official opens the field directly; the explanation sits under the row.
	[TGAlertSheet showInput:@"Login Email"
					message:@"You will receive Telegram login codes via email and not SMS. Please enter an email address to which you have access."
				placeholder:@"you@example.com"
					   text:nil
					 action:@"Send"
					 inView:self.view
				   onSubmit:^(NSString *email){
		[[TGClient shared] setLoginEmailAddress:email
									completion:^(NSString *pattern,
												  NSString *setError){
			if (setError){
				[TGAlertSheet showMessage:setError
									title:@"Login Email"
								   inView:weakSelf.view];
				return;
			}
			[weakSelf askLoginEmailCodeFor:(pattern.length ? pattern : email)];
		}];
	}];
}

/// The code sheet loops: a refusal offers the code again, and the resend
/// request is the server's answer for the masked address it mails to.
- (void)askLoginEmailCodeFor:(NSString *)pattern {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Enter Code", @"Re-send Code"]
						title:@"Login Email"
					  message:pattern
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (index == 1){
			[[TGClient shared] resendLoginEmailAddressCodeWithCompletion:
					^(NSString *resent, NSString *error){
				[TGAlertSheet showMessage:(error ?: @"Done")
									title:@"Login Email" inView:me.view];
				[me askLoginEmailCodeFor:(resent.length ? resent : pattern)];
			}];
			return;
		}
		[TGAlertSheet showInput:@"Email Code"
						message:pattern
					placeholder:@"Code"
						   text:nil
						 action:@"Confirm"
						 inView:me.view
					   onSubmit:^(NSString *code){
			[[TGClient shared] checkLoginEmailAddressCode:code
											   completion:^(NSString *error){
				if (error){
					[TGAlertSheet showMessage:error
										title:@"Login Email"
									   inView:me.view];
					[me askLoginEmailCodeFor:pattern];
					return;
				}
				[TGAlertSheet showMessage:@"Done"
									title:@"Login Email" inView:me.view];
			}];
		}];
	}];
}

#pragma mark - phone number

/// The change-number flow. Telegram sends the code to the new number and
/// only moves the account when it is checked; the old number keeps working
/// until then, which is what the first sheet has to say.
- (void)showChangePhoneFlow {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Change Phone Number"
					message:nil
				placeholder:@"+380..."
					   text:nil
					 action:@"Next"
					 inView:self.view
				   onSubmit:^(NSString *number){
		TGSettingsViewController *me = weakSelf;
		// The synchronous answer is what a sheet needs before it can name the
		// country and the way Telegram would write the number.
		NSDictionary *info = [[TGClient shared] phoneNumberInfoForPrefixSync:number];
		NSString *said = info
				? [NSString stringWithFormat:@"%@ %@\n%@",
						info[@"flag"] ?: @"", info[@"name"] ?: @"",
						info[@"formatted"] ?: number]
				: number;
		[TGAlertSheet showConfirm:said
							title:@"Change Phone Number"
						   action:@"Send"
					  destructive:NO
						   inView:me.view
						onConfirm:^{
			[[TGClient shared] sendPhoneNumberChangeCode:number
											  completion:^(NSDictionary *codeInfo,
														   NSString *error){
				if (error){
					[TGAlertSheet showMessage:error title:@"Change Phone Number"
									   inView:me.view];
					return;
				}
				[me showPhoneChangeCodeStep:codeInfo];
			}];
		}];
	}];
}

- (void)showPhoneChangeCodeStep:(NSDictionary *)info {
	__weak typeof(self) weakSelf = self;
	NSString *type = info[@"type"] ?: @"";
	BOOL firebase = [type hasPrefix:@"authenticationCodeTypeFirebase"];
	NSMutableArray *choices = [NSMutableArray arrayWithObjects:
			@"Enter Code", @"Re-send Code", @"It Never Arrived", nil];
	if (firebase)
		[choices addObject:@"Send Push Secret"];

	[TGAlertSheet showChoices:choices
						title:@"Change Phone Number"
					  message:info[@"phone"]
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (index == 1){
			[[TGClient shared] resendPhoneNumberChangeCodeWithCompletion:
					^(NSDictionary *resent, NSString *error){
				if (error){
					[TGAlertSheet showMessage:error
										title:@"Change Phone Number" inView:me.view];
					return;
				}
				[me showPhoneChangeCodeStep:resent];
			}];
			return;
		}
		if (index == 2){
			[[TGClient shared] reportPhoneNumberCodeMissingWithCompletion:
					^(NSString *error){
				[TGAlertSheet showMessage:(error ?: @"Done")
									title:@"Change Phone Number" inView:me.view];
				[me showPhoneChangeCodeStep:info];
			}];
			return;
		}
		if (index == 3){
			[TGAlertSheet showInput:@"Verify"
							message:nil
						placeholder:@"Secret"
							   text:nil
							 action:@"Send"
							 inView:me.view
						   onSubmit:^(NSString *token){
				[[TGClient shared] sendPhoneNumberFirebaseSms:token
												   completion:^(NSString *error){
					[TGAlertSheet showMessage:(error ?: @"Done")
												title:@"Change Phone Number"
											   inView:me.view];
					[me showPhoneChangeCodeStep:info];
				}];
			}];
			return;
		}
		[TGAlertSheet showInput:@"Enter Code"
						message:(info[@"phone"] ?: nil)
					placeholder:@"Code"
						   text:nil
						 action:@"Confirm"
						 inView:me.view
					   onSubmit:^(NSString *code){
			[[TGClient shared] checkPhoneNumberChangeCode:code
											   completion:^(NSString *error){
				if (error){
					[TGAlertSheet showMessage:error
										title:@"Change Phone Number" inView:me.view];
					[me showPhoneChangeCodeStep:info];
					return;
				}
				[TGAlertSheet showMessage:@"Done"
									title:@"Change Phone Number" inView:me.view];
			}];
		}];
	}];
}

#pragma mark - temporary password

/// The temporary password is what pays for things without typing the real
/// one each time. Both the read and the create answer the same state, so the
/// sheet can always say whether one exists and for how long.
- (void)showTemporaryPasswordFlow {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] temporaryPasswordStateWithCompletion:
			^(BOOL has, NSInteger validFor, NSString *error){
		TGSettingsViewController *me = weakSelf;
		NSString *said;
		if (error){
			said = error;
		} else if (has){
			said = [NSString stringWithFormat:
					@"A temporary password is active for another %ld minutes.",
					(long)(validFor / 60)];
		} else {
			said = @"Empty";
		}
		[TGAlertSheet showChoices:@[@"Create"]
							title:@"Password"
						  message:said
				 destructiveIndex:-1
						   inView:me.view
						 onChoice:^(NSInteger ignored){
			[me askCurrentPasswordThen:^(NSString *current){
				[TGAlertSheet showChoices:@[@"1 hour", @"1 day"]
									title:@"Duration"
						 destructiveIndex:-1
								   inView:me.view
								 onChoice:^(NSInteger index){
					static const NSInteger seconds[2] = {3600, 86400};
					[[TGClient shared] createTemporaryPassword:current
													  validFor:seconds[index]
													completion:^(BOOL created,
																 NSInteger left,
																 NSString *createError){
						[TGAlertSheet showMessage:(createError
								?: [NSString stringWithFormat:
										@"The temporary password is good for %ld minutes.",
										(long)(left / 60)])
													title:@"Password"
												   inView:me.view];
					}];
				}];
			}];
		}];
	}];
}

#pragma mark - email address verification

/// Passport's address half: Telegram mails a code, and entering it marks the
/// address verified. The app has no Passport form, but a refusal from the
/// server is still the answer this flow shows.
- (void)showVerifyEmailFlow {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showInput:@"Email Address"
					message:nil
				placeholder:@"you@example.com"
					   text:nil
					 action:@"Send"
					 inView:self.view
				   onSubmit:^(NSString *email){
		TGSettingsViewController *me = weakSelf;
		[[TGClient shared] sendEmailAddressVerificationCodeTo:email
												  completion:^(NSString *pattern,
															   NSString *error){
			if (error){
				[TGAlertSheet showMessage:error
									title:@"Email Address"
								   inView:me.view];
				return;
			}
			[me askEmailVerificationCodeFor:(pattern.length ? pattern : email)];
		}];
	}];
}

- (void)askEmailVerificationCodeFor:(NSString *)pattern {
	__weak typeof(self) weakSelf = self;
	[TGAlertSheet showChoices:@[@"Enter Code", @"Re-send Code"]
						title:@"Email Address"
					  message:pattern
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		TGSettingsViewController *me = weakSelf;
		if (index == 1){
			[[TGClient shared] resendEmailAddressVerificationCodeWithCompletion:
					^(NSString *resent, NSString *error){
				[TGAlertSheet showMessage:(error ?: @"Done")
									title:@"Email Address"
								   inView:me.view];
				[me askEmailVerificationCodeFor:(resent.length ? resent : pattern)];
			}];
			return;
		}
		[TGAlertSheet showInput:@"Email Code"
						message:pattern
					placeholder:@"Code"
						   text:nil
						 action:@"Verify"
						 inView:me.view
					   onSubmit:^(NSString *code){
			[[TGClient shared] checkEmailAddressVerificationCode:code
													  completion:^(NSString *error){
				if (error){
					[TGAlertSheet showMessage:error
										title:@"Email Address"
									   inView:me.view];
					[me askEmailVerificationCodeFor:pattern];
					return;
				}
				[TGAlertSheet showMessage:@"Done"
									title:@"Email Address"
								   inView:me.view];
			}];
		}];
	}];
}

#pragma mark - application verification

/// Telegram asks the app to prove itself through the platform's
/// verification service. The update names the request; this sheet hands the
/// service's token back and shows whether the server accepted it.
- (void)showApplicationVerification {
	__weak typeof(self) weakSelf = self;
	int64_t verificationId = [TGClient shared].pendingApplicationVerificationId;
	if (!verificationId){
		[TGAlertSheet showMessage:@"Empty"
							title:@"Verify" inView:self.view];
		return;
	}
	NSString *nonce = [TGClient shared].pendingApplicationVerificationNonce;
	[TGAlertSheet showInput:@"Verify"
					message:[NSString stringWithFormat:
							@"Request %lld waits for the verification service's "
							@"token.\nNonce: %@",
							(long long)verificationId,
							nonce.length ? nonce : @"(none)"]
				placeholder:@"Token"
					   text:nil
					 action:@"Send"
					 inView:self.view
				   onSubmit:^(NSString *token){
		TGSettingsViewController *me = weakSelf;
		[[TGClient shared] setApplicationVerificationToken:token
											verificationId:verificationId
												completion:^(NSString *error){
			[TGAlertSheet showMessage:(error ?: @"Done")
								title:@"Verify"
							   inView:me.view];
			[me rebuild];
		}];
	}];
}

@end
