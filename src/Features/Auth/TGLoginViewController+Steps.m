#import "TGTextDraw.h"
#import "TGLocalization.h"
#import "TGLoginViewControllerInternal.h"
#import "TGStyle.h"
#import "TGUIFormat.h"
#import "TGIcons.h"
#import "TGPhoneNumberRules.h"
#import "TGQRCode.h"
#import "TGAccountStore.h"
#import "TGSettingsStore.h"

/// The code step is a row of digit boxes, as official draws it. The real text
/// field stays behind them so the number pad and the paste menu keep working;
/// the boxes only paint what it holds.
@interface TGCodeBoxesView : UIView
@property (nonatomic, copy) NSString *code;
@property (nonatomic, assign) NSInteger boxCount;
@property (nonatomic, assign) BOOL errorState;
@property (nonatomic, strong) UIColor *boxBorderColour;
@property (nonatomic, strong) UIColor *boxTextColour;
@end

@implementation TGCodeBoxesView

- (void)drawRect:(CGRect)rect {
    NSInteger count = MAX(self.boxCount, 1);
    CGFloat gap = TGMetricPadSmall;
    CGFloat boxWidth = (CGRectGetWidth(self.bounds) - gap * (count - 1)) / count;
    boxWidth = MIN(boxWidth, TGMetricRow);
    CGFloat total = boxWidth * count + gap * (count - 1);
    CGFloat x = TGHalf(CGRectGetWidth(self.bounds) - total);
    UIFont *font = TGFontHeader();
    NSDictionary *attributes = @{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : self.boxTextColour
                ?: [[TGTheme shared] primaryTextColour]
    };
    for (NSInteger i = 0; i < count; i++) {
        CGRect box = CGRectMake(x, 0, boxWidth, TGMetricRow);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:box
                cornerRadius:TGMetricCornerControl];
        UIColor *border = self.errorState
                ? [[TGTheme shared] destructiveColour]
                : (self.boxBorderColour ?: [[TGTheme shared] separatorColour]);
        [border setStroke];
        path.lineWidth = self.errorState ? TGMetricBorderThick : TGMetricHairline;
        [path stroke];
        if ((NSUInteger)i < self.code.length) {
            NSString *digit = [self.code substringWithRange:NSMakeRange((NSUInteger)i, 1)];
            CGSize size = [digit sizeWithAttributes:attributes];
            [digit drawAtPoint:CGPointMake(CGRectGetMidX(box) - TGHalf(size.width),
                                           CGRectGetMidY(box) - TGHalf(size.height))
                    withAttributes:attributes];
        }
        x += boxWidth + gap;
    }
}

@end

/// Every step is the same vertical stack: instructions, a field, a button,
/// and maybe a link or two. Each one used to carry its own column of
/// offsets - 56/108/154/190/210 here, 64/116/162/196/230/250 next door - so
/// the four steps drifted a few points apart from each other for no reason
/// anybody chose.
///
/// The show* methods only *choose* a step - titles, secrets, timers,
/// keyboards - and then land in layoutActiveStep, which writes every frame
/// from the view's present bounds and again on every rotation. These two
/// static helpers put a thing where the cursor is and answer where the next
/// thing goes, so the rhythm stays one value for every step and every
/// screen size.
static CGFloat TGStackPlace(UIView *view, CGFloat y, CGFloat height,
                            CGFloat width, CGFloat gutter) {
    if (view)
        view.frame = CGRectMake(gutter, y, width - TGDoubled(gutter), height);
    return y + height + TGMetricStackStep;
}

/// The same, for whatever starts a new group further down the form - it gets
/// the larger step above it.
static CGFloat TGStackPlaceGroup(UIView *view, CGFloat y, CGFloat height,
                                 CGFloat width, CGFloat gutter) {
    return TGStackPlace(view, y + TGMetricStackGroup - TGMetricStackStep,
                        height, width, gutter);
}

/// The whole form is the scroll view, so a step swap made its fields, links
/// and title blink from one arrangement to the next. The fade is run by the
/// render server, which leaves the one core free for the next request.
static void TGCrossFadeStepChange(UIScrollView *scrollView) {
    CATransition *fade = [CATransition animation];
    fade.type = kCATransitionFade;
    fade.duration = TGAnimationDurationNormal;
    [scrollView.layer addAnimation:fade forKey:@"tg.stepChange"];
}

@implementation TGLoginViewController (Steps)

#pragma mark - step geometry

/// The current step's frames, written from the view's present bounds. Every
/// show* method below ends here, and so does every rotation and layout pass:
/// the phone step folds its prefix into one row on 320 pt and spreads on
/// wider screens, the QR re-centres, the links re-stack under the button.
/// This is the one place the answer to "where does a thing go" lives.
- (void)layoutActiveStep {
    if (!self.scrollView || !self.inputContainer)
        return;
    CGFloat width = self.view.bounds.size.width;

    // Only the first step is the app's front door; the code, password and
    // email steps are about the one thing they ask for and start at the top.
    BOOL showsBrand = (self.currentStep == TGLoginStepPhone) &&
            (!self.qrImageView || self.qrImageView.hidden);
    // Each step names its own heading in the content; only the phone step is
    // the app's front door.
    self.headingLabel.hidden = (self.headingLabel.text.length == 0);
    self.brandLogoView.hidden = YES;
    self.brandLabel.hidden = YES;
    self.countryButton.hidden = !showsBrand;
    if (!showsBrand)
        self.countryLabel.hidden = YES;

    if (self.qrImageView && !self.qrImageView.hidden) {
        [self layoutQRStepInWidth:width];
        return;
    }
    switch (self.currentStep) {
        case TGLoginStepPhone:
            [self layoutPhoneStepInWidth:width];
            break;
        case TGLoginStepCode:
            [self layoutCodeStepInWidth:width];
            break;
        case TGLoginStepRegister:
        case TGLoginStepEmail:
        case TGLoginStepEmailCode:
        case TGLoginStepPassword:
        case TGLoginStepRecoveryCode:
            [self layoutFieldStepInWidth:width];
            break;
    }
}

- (void)layoutPhoneStepInWidth:(CGFloat)width {
    CGFloat y = TGMetricStackTop;
    CGFloat inner = width - TGDoubled(TGMetricGutter);

    self.headingLabel.frame = CGRectMake(TGMetricGutter, y, inner,
            TGMetricLoginBrandLabel);
    y += TGMetricLoginBrandLabel + TGMetricPadMedium;
    y = [self placeSubtitleAtY:y] + TGMetricStackGroup;

    self.countryButton.frame = CGRectMake(TGMetricGutter, y, inner,
            TGMetricLoginLinkHeight);
    y += TGMetricLoginLinkHeight + TGMetricStackStep;

    y = TGStackPlace(self.inputContainer, y, TGMetricRow, width, TGMetricGutter);
    y = [self placeErrorAtY:y width:width];
    y = TGStackPlace(self.actionButton, y, TGMetricRow, width, TGMetricGutter);

    CGFloat fieldX = TGMetricPadMedium + TGMetricLoginPrefixWidth + TGMetricPadMedium;
    self.inputField.frame = CGRectMake(fieldX, 0,
            width - TGDoubled(TGMetricGutter) - fieldX - TGMetricPadMedium,
            TGMetricRow);

    y = [self placeStepLinksFromY:y width:width];
    [self updatePrimaryActionForWidth:width];

    y += TGMetricStackGroup;
    self.scrollView.contentSize = CGSizeMake(width,
            y - TGMetricStackStep + TGMetricPadLarge);
}

- (void)layoutCodeStepInWidth:(CGFloat)width {
    CGFloat y = [self placeSubtitle] + TGMetricStackGroup;
    y = TGStackPlace(self.inputContainer, y, TGMetricRow, width, TGMetricGutter);
    if (self.codeBoxesView) {
        self.codeBoxesView.frame = self.inputContainer.frame;
    }
    y = [self placeErrorAtY:y width:width];
    // No Submit: the field sends itself at the server's code length, and the
    // only other control is the one next-option link under the boxes.
    self.actionButton.hidden = YES;
    self.inputField.frame = CGRectMake(0, 0,
            width - TGDoubled(TGMetricGutter), TGMetricRow);
    // The code has no bottom button, but official still shows a nav Next on
    // widths under 360, where the boxes are the only control on screen.
    [self updatePrimaryActionForWidth:width];

    y = [self placeGhostRow:self.resendButton atY:y width:width];
    y = [self placeStepLinksFromY:y width:width];
    [self updateCodeBoxes];

    y += TGMetricStackGroup;
    self.scrollView.contentSize = CGSizeMake(width,
            y - TGMetricStackStep + TGMetricPadLarge);
}

/// One primary action per screen: the bottom Continue on a wide layout, the
/// navigation-bar Next below 360 pt, where the keyboard leaves no room for a
/// pinned button.
- (void)updatePrimaryActionForWidth:(CGFloat)width {
    BOOL narrow = width < 360.0f;
    BOOL codeStep = (self.currentStep == TGLoginStepCode);
    BOOL fieldStep = (self.currentStep == TGLoginStepPhone ||
                      self.currentStep == TGLoginStepPassword ||
                      self.currentStep == TGLoginStepRegister ||
                      self.currentStep == TGLoginStepEmail ||
                      self.currentStep == TGLoginStepEmailCode ||
                      self.currentStep == TGLoginStepRecoveryCode);
    self.actionButton.hidden = narrow || !fieldStep || codeStep;
    self.navigationItem.rightBarButtonItem = narrow ? self.nextItem : nil;
}

- (void)updateCodeBoxes {
    if (![self.codeBoxesView isKindOfClass:[TGCodeBoxesView class]])
        return;
    TGCodeBoxesView *boxes = (TGCodeBoxesView *)self.codeBoxesView;
    NSInteger count = self.expectedCodeLength > 0 ? self.expectedCodeLength : 5;
    boxes.boxCount = count;
    boxes.errorState = self.codeErrorShown;
    boxes.code = self.inputField.text ?: @"";
    boxes.boxBorderColour = [[TGTheme shared] separatorColour];
    boxes.boxTextColour = [[TGTheme shared] primaryTextColour];
    [boxes setNeedsDisplay];
}

/// A rejected code: the boxes go red, the digits are dropped and the reason
/// sits under them, as the official node does. Called when the client reports
/// the failed check (the auth state stays on the code step, so there is no
/// step change to tell us).
- (void)showCodeError {
    if (self.currentStep != TGLoginStepCode)
        return;
    self.codeErrorShown = YES;
    self.codeSubmitPending = NO;
    self.inputField.text = @"";
    self.errorLabel.text = TGLocalized(@"Invalid code, please try again.");
    self.errorLabel.hidden = NO;
    [self layoutActiveStep];
    [self updateCodeBoxes];
    [self.inputField becomeFirstResponder];
}

/// The password, email, register and recovery steps are one field, one
/// button, and whatever links the caller asked for under that button.
- (void)layoutFieldStepInWidth:(CGFloat)width {
    CGFloat y = TGMetricStackTop;
    // The sign-up avatar is the first control on the official form, above the
    // heading and the name fields, not a picture wedged under the first field.
    if (self.currentStep == TGLoginStepRegister && !self.avatarButton.hidden) {
        CGFloat side = TGMetricProfilePhotoSide;
        self.avatarButton.frame = CGRectMake(TGCenteredOrigin(width, side), y,
                side, side);
        self.avatarImageView.frame = self.avatarButton.bounds;
        y += side + TGMetricPadMedium;
    }
    if (!self.headingLabel.hidden) {
        self.headingLabel.frame = CGRectMake(TGMetricGutter, y,
                width - TGDoubled(TGMetricGutter), TGMetricLoginBrandLabel);
        y += TGMetricLoginBrandLabel + TGMetricPadMedium;
    }
    y = [self placeSubtitleAtY:y] + TGMetricStackGroup;
    y = TGStackPlace(self.inputContainer, y, TGMetricRow, width, TGMetricGutter);
    self.inputField.frame = CGRectMake(TGMetricPadMedium, 0,
            width - TGDoubled(TGMetricGutter) - TGDoubled(TGMetricPadMedium),
            TGMetricRow);
    if (self.currentStep == TGLoginStepRegister) {
        y = TGStackPlace(self.lastNameContainer, y, TGMetricRow, width,
                         TGMetricGutter);
        self.lastNameField.frame = CGRectMake(TGMetricPadMedium, 0,
                width - TGDoubled(TGMetricGutter) - TGDoubled(TGMetricPadMedium),
                TGMetricRow);
    }
    y = [self placeErrorAtY:y width:width];

    // The consent label sits above the bottom Continue, as the official node
    // stacks it: form, terms, button.
    if (self.currentStep == TGLoginStepRegister && !self.termsButton.hidden) {
        CGFloat termsHeight = TGDoubled(TGMetricLineCaption) + TGMetricPadSmall;
        self.termsButton.frame = CGRectMake(TGMetricGutter, y,
                width - TGDoubled(TGMetricGutter), termsHeight);
        y += termsHeight + TGMetricPadSmall;
    }

    y = TGStackPlace(self.actionButton, y, TGMetricRow, width, TGMetricGutter);

    y = [self placeStepLinksFromY:y width:width];
    [self updatePrimaryActionForWidth:width];

    y += TGMetricStackGroup;
    self.scrollView.contentSize = CGSizeMake(width,
            y - TGMetricStackStep + TGMetricPadLarge);
}

- (void)layoutQRStepInWidth:(CGFloat)width {
    [self placeSubtitle];

    CGFloat qrSize = MIN(width - 80, TGMetricLoginQRSize);
    self.qrImageView.frame = CGRectMake(
            TGCenteredOrigin(width, qrSize), TGMetricStackQRTop, qrSize, qrSize);

    CGFloat qrY = TGStackPlaceGroup(nil, TGMetricStackQRTop + qrSize,
                                    0, width, TGMetricPadWide);
    qrY = [self placeStepLinksFromY:qrY width:width];
    self.scrollView.contentSize = CGSizeMake(width,
            qrY - TGMetricStackStep + TGMetricPadLarge);
}

/// One full-width ghost row - the resend, the QR link - framed at `y`; the
/// cursor answers where the next row starts.
- (CGFloat)placeGhostRow:(UIView *)view atY:(CGFloat)y width:(CGFloat)width {
    TGStackPlace(view, y, TGMetricLoginLinkHeight, width, TGMetricGutter);
    return y + TGMetricLoginLinkHeight + TGMetricPadSmall;
}

/// Every step link the step carries, stacked from `y`; returns the cursor
/// past the last one.
- (CGFloat)placeStepLinksFromY:(CGFloat)y width:(CGFloat)width {
    for (UIView *link in self.stepLinks) {
        link.frame = CGRectMake(TGMetricGutter, y,
                width - TGDoubled(TGMetricGutter), TGMetricLoginLinkHeight);
        y += TGMetricLoginLinkHeight + TGMetricPadSmall;
    }
    return y;
}

- (void)showPhoneStep {
    TGCrossFadeStepChange(self.scrollView);
    [self clearStepLinks];
    [self.resendTimer invalidate];
    self.resendTimer = nil;
    [self setBusy:NO];
    self.errorLabel.text = nil;
    self.errorLabel.hidden = YES;
    self.currentStep = TGLoginStepPhone;
    self.title = nil;
    self.headingLabel.text = @"Your Phone";
    self.subtitleLabel.text = @"Please confirm your country code\nand enter your phone number.";

    // Official has no Reset: a screen button must never destroy the TDLib
    // session. The root phone screen has no left item; Close belongs to the
    // add-another-account flow, which is not wired here.
    self.navigationItem.leftBarButtonItem = nil;

    self.inputContainer.hidden = NO;
    self.inputContainer.backgroundColor = [[TGTheme shared] cardBackgroundColour];
    self.inputContainer.layer.borderWidth = TGMetricHairline;
    self.inputContainer.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    self.actionButton.hidden = NO;
    self.inputField.hidden = NO;
    self.headingLabel.hidden = NO;
    self.countryButton.hidden = NO;
    if (self.qrImageView) {
        self.qrImageView.hidden = YES;
    }
    if (self.codeBoxesView) {
        self.codeBoxesView.hidden = YES;
    }
    if (self.lastNameContainer)
        self.lastNameContainer.hidden = YES;
    if (self.termsButton)
        self.termsButton.hidden = YES;
    if (self.avatarButton)
        self.avatarButton.hidden = YES;
    [self.inputField resignFirstResponder];
    self.phonePrefixField.hidden = NO;
    self.prefixSeparator.hidden = NO;
    self.countryLabel.text = nil;
    self.countryLabel.hidden = YES;
    self.expectedCodeLength = 0;
    self.inputField.textAlignment = NSTextAlignmentLeft;
    self.inputField.font = TGFontInput();
    self.inputField.placeholder = @"Phone number";
    self.inputField.text = self.savedNationalNumber ?: @"";
    self.inputField.secureTextEntry = NO;
    self.inputField.textColor = [[TGTheme shared] primaryTextColour];
    self.inputField.keyboardType = UIKeyboardTypePhonePad;
    self.inputField.returnKeyType = UIReturnKeyGo;
    [self.actionButton setTitle:@"Continue" forState:UIControlStateNormal];
    self.nextItem.title = @"Next";
    self.countryButton.userInteractionEnabled = YES;
    [self.countryButton setTitle:self.savedCountryName.length
            ? self.savedCountryName : @"Country" forState:UIControlStateNormal];

    if (self.resendButton) {
        [self.resendButton removeFromSuperview];
        self.resendButton = nil;
    }
    if (self.codeStepQrButton) {
        [self.codeStepQrButton removeFromSuperview];
        self.codeStepQrButton = nil;
    }

    // Start from the device's own country, then let Telegram's network guess
    // replace it. The old hardcoded +380 was wrong for everyone outside
    // Ukraine until the answer arrived.
    self.countryGuessGeneration++;
    self.countryGuessResolvedByNetwork = NO;
    if (!self.prefixEdited) {
        [self selectDeviceCountryPrefix];
    }

    [self layoutActiveStep];
    [self applyTheme];
    [self updateActionEnabled];
    [self.inputField becomeFirstResponder];
}

/// The calling code of the device's region, before any network answer. The
/// network guess in selectNetworkCountryPrefix then wins if it differs.
- (void)selectDeviceCountryPrefix {
    NSString *iso = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    if (!iso.length)
        return;
    NSInteger generation = self.countryGuessGeneration;
    __weak typeof(self) weakSelf = self;
    [[TGSettingsStore shared] countryInfoForCode:iso completion:^(NSDictionary *country){
        TGLoginViewController *me = weakSelf;
        if (!me || me.currentStep != TGLoginStepPhone ||
            !TGCountryGuessCanApply(generation, me.countryGuessGeneration,
                    me.prefixEdited, me.countryGuessResolvedByNetwork, NO))
            return;
        NSString *prefix = [country[@"callingCodes"] firstObject];
        if (![prefix isKindOfClass:[NSString class]] || !prefix.length)
            return;
        me.phonePrefixField.text = [@"+" stringByAppendingString:prefix];
        me.savedCountryName = country[@"name"];
        [me.countryButton setTitle:me.savedCountryName
                          forState:UIControlStateNormal];
        [me refreshPhoneNumberInfo];
    }];
    [[TGAccountStore shared] countryCodeWithCompletion:^(NSString *code){
        TGLoginViewController *me = weakSelf;
        if (!me || me.currentStep != TGLoginStepPhone ||
            !code.length ||
            !TGCountryGuessCanApply(generation, me.countryGuessGeneration,
                    me.prefixEdited, me.countryGuessResolvedByNetwork, YES))
            return;
        [[TGSettingsStore shared] countryInfoForCode:code completion:^(NSDictionary *country){
            if (!me || me.currentStep != TGLoginStepPhone ||
                !TGCountryGuessCanApply(generation, me.countryGuessGeneration,
                        me.prefixEdited, me.countryGuessResolvedByNetwork, YES))
                return;
            NSString *prefix = [country[@"callingCodes"] firstObject];
            if (![prefix isKindOfClass:[NSString class]] || !prefix.length)
                return;
            me.countryGuessResolvedByNetwork = YES;
            me.phonePrefixField.text = [@"+" stringByAppendingString:prefix];
            me.savedCountryName = country[@"name"];
            [me.countryButton setTitle:me.savedCountryName
                              forState:UIControlStateNormal];
            [me refreshPhoneNumberInfo];
        }];
    }];
}

- (void)useSingleFieldLayout {
    self.inputContainer.hidden = NO;
    self.inputContainer.backgroundColor = [[TGTheme shared] cardBackgroundColour];
    self.inputContainer.layer.borderWidth = TGMetricHairline;
    self.inputContainer.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    self.actionButton.hidden = NO;
    self.inputField.hidden = NO;
    self.inputField.textColor = [[TGTheme shared] primaryTextColour];
    self.phonePrefixField.hidden = YES;
    self.prefixSeparator.hidden = YES;
    if (self.qrImageView) {
        self.qrImageView.hidden = YES;
    }
    if (self.codeBoxesView) {
        self.codeBoxesView.hidden = YES;
    }
    if (self.lastNameContainer)
        self.lastNameContainer.hidden = YES;
    if (self.termsButton)
        self.termsButton.hidden = YES;
    if (self.avatarButton)
        self.avatarButton.hidden = YES;
    self.countryButton.hidden = YES;
    self.countryLabel.hidden = YES;
    self.inputField.textAlignment = NSTextAlignmentCenter;
    self.inputField.font = TGFontInput();
    self.inputField.text = @"";
    self.inputField.returnKeyType = UIReturnKeyGo;
}

- (void)qrCodeButtonTapped {
    [self setBusy:YES];
    if (self.onRequestQRCode) {
        self.onRequestQRCode();
    }
}

- (void)showQRCodeStepWithLink:(NSString *)link {
    TGCrossFadeStepChange(self.scrollView);
    [self clearStepLinks];
    [self setBusy:NO];
    self.errorLabel.text = nil;
    self.errorLabel.hidden = YES;
    self.title = @"Scan QR Code";
    self.subtitleLabel.text = @"Scan the QR code to connect your account";

    self.inputContainer.hidden = YES;
    self.actionButton.hidden = YES;
    self.phonePrefixField.hidden = YES;
    self.prefixSeparator.hidden = YES;
    self.inputField.hidden = YES;
    self.qrCodeButton.hidden = YES;
    if (self.resendButton) {
        [self.resendButton removeFromSuperview];
        self.resendButton = nil;
    }
    if (self.codeStepQrButton) {
        [self.codeStepQrButton removeFromSuperview];
        self.codeStepQrButton = nil;
    }
    [self.resendTimer invalidate];
    self.resendTimer = nil;
    [self.view endEditing:YES];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Cancel"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(showPhoneStep)];
    // Nothing to submit here: the other device does the work.
    self.navigationItem.rightBarButtonItem = nil;

    CGFloat width = self.view.bounds.size.width;
    CGFloat qrSize = MIN(width - 80, TGMetricLoginQRSize);
    CGFloat qrX = TGCenteredOrigin(width, qrSize);
    if (!self.qrImageView) {
        self.qrImageView = [[UIImageView alloc] initWithFrame:
                CGRectMake(qrX, TGMetricStackQRTop, qrSize, qrSize)];
        self.qrImageView.backgroundColor = [UIColor whiteColor];
        self.qrImageView.layer.cornerRadius = TGMetricCornerControl;
        self.qrImageView.layer.borderWidth = TGMetricHairline;
        self.qrImageView.clipsToBounds = YES;
        [self.scrollView addSubview:self.qrImageView];
    }
    self.qrImageView.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    self.qrImageView.hidden = NO;
    UIImage *qrImage = [self generateQRCodeForString:link size:qrSize];
    self.qrImageView.image = qrImage;
    if (qrImage) {
        // The code comes back from a round trip; fading it in makes the wait
        // read as finished instead of the picture blinking into place.
        self.qrImageView.alpha = TGAlphaTransparent;
        __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:TGAnimationDurationNormal animations:^{
            weakSelf.qrImageView.alpha = TGAlphaOpaque;
        }];
    } else {
        self.qrImageView.alpha = TGAlphaOpaque;
    }

    // The other direction: the other device shows the code and this one
    // confirms the link, which is what their "scan a QR" does with a camera
    // this OS may not have.
    [self addStepLink:@"QR Code" action:@selector(qrLinkTapped) atY:0];

    [self layoutActiveStep];
    [self applyTheme];
}

- (UIImage *)generateQRCodeForString:(NSString *)string size:(CGFloat)size {
    return TGQRCodeImage(string, size);
}

- (void)showCodeStepWithPhoneNumber:(NSString *)phoneNumber {
    TGCrossFadeStepChange(self.scrollView);
    [self clearStepLinks];
    [self setBusy:NO];
    self.errorLabel.text = nil;
    self.errorLabel.hidden = YES;
    self.currentStep = TGLoginStepCode;
    self.codeSubmitPending = NO;
    self.codeErrorShown = NO;
    self.title = nil;
    self.headingLabel.text = nil;
    self.headingLabel.hidden = YES;
    if (phoneNumber.length > 0) {
        self.savedPhoneNumber = phoneNumber;
    }
    NSString *displayNumber = self.savedPhoneNumber ?: phoneNumber ?: @"";

    NSDictionary *info = [TGAccountStore shared].codeInfo;
    NSString *codeType = info[@"type"][@"@type"];
    NSString *sentence = nil;
    if ([codeType isEqualToString:@"authenticationCodeTypeSms"]) {
        sentence = TGLocalizedFormat(
                @"We've sent an SMS with an activation code to your phone **%@**.",
                displayNumber);
    } else if ([codeType isEqualToString:@"authenticationCodeTypeCall"]) {
        sentence = TGLocalized(@"Calling your phone to dictate the code.");
    } else {
        sentence = TGLocalizedFormat(
                @"We've sent the code to the **Telegram app** for %@ on your other device.",
                displayNumber);
    }
    // The pack keys carry markdown bold markers; a UILabel does not parse
    // them, so the sentence keeps the official words without the asterisks.
    self.subtitleLabel.text = [sentence stringByReplacingOccurrencesOfString:@"**"
                                                                 withString:@""];

    self.countryLabel.hidden = YES;
    self.expectedCodeLength = [info[@"length"] integerValue];
    [self useSingleFieldLayout];
    [self.inputField resignFirstResponder];   // or the number pad never shows
    // The boxes paint the code; the field behind them stays the responder.
    self.inputField.placeholder = nil;
    self.inputField.textColor = [UIColor clearColor];
    self.inputField.keyboardType = UIKeyboardTypeNumberPad;
    self.inputField.returnKeyType = UIReturnKeyDone;
    self.inputContainer.backgroundColor = [UIColor clearColor];
    self.inputContainer.layer.borderWidth = 0.0f;
    self.actionButton.hidden = YES;
    self.navigationItem.rightBarButtonItem = nil;

    if (!self.codeBoxesView) {
        self.codeBoxesView = [[TGCodeBoxesView alloc] initWithFrame:CGRectZero];
        self.codeBoxesView.backgroundColor = [UIColor clearColor];
        self.codeBoxesView.userInteractionEnabled = NO;
        [self.scrollView addSubview:self.codeBoxesView];
    }
    self.codeBoxesView.hidden = NO;

    // Back chevron, with the official stop-verification question.
    self.navigationItem.leftBarButtonItem = [self backItemWithAction:
            @selector(confirmStopVerification)];

    // One dynamic next-option line: a countdown while the server waits, then
    // the action that asks for the code by the other channel.
    if (!self.resendButton) {
        self.resendButton = [TGButton buttonWithTitle:@"Resend Code"
                                             variant:TGButtonVariantGhost
                                                size:TGButtonSizeSmall];
        [self.resendButton addTarget:self action:@selector(resendButtonTapped)
                    forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:self.resendButton];
    }
    if (self.codeStepQrButton) {
        [self.codeStepQrButton removeFromSuperview];
        self.codeStepQrButton = nil;
    }

    [self layoutActiveStep];

    [self.resendTimer invalidate];
    self.resendTimer = nil;

    int timeout = [info[@"timeout"] intValue];
    if (timeout > 0) {
        self.resendCountdown = timeout;
        [self.resendButton setTitle:[self resendTitleForCountdown:self.resendCountdown]
                          forState:UIControlStateDisabled];
        self.resendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(resendTick:) userInfo:nil repeats:YES];
    } else {
        self.resendCountdown = 0;
        [self.resendButton setTitle:TGLocalized(@"Send the code as an SMS")
                          forState:UIControlStateNormal];
    }

    [self applyTheme];
    [self updateActionEnabled];
    [self.inputField becomeFirstResponder];
}

/// A back chevron, the only left control official gives the code, password
/// and email steps.
- (UIBarButtonItem *)backItemWithAction:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *chevron = [TGIcons backChevronWithColour:[[TGTheme shared] accentColour]];
    [button setImage:chevron forState:UIControlStateNormal];
    CGFloat side = TGMetricRow;
    button.frame = CGRectMake(0, 0, side, side);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)confirmStopVerification {
    __weak typeof(self) weakSelf = self;
    [TGAlertSheet showConfirm:TGLocalized(@"Do you want to stop the verification process?")
                        title:nil
                       action:TGLocalized(@"OK")
                  destructive:NO
                       inView:self.view
                    onConfirm:^{
        TGLoginViewController *me = weakSelf;
        [me clearError];
        [me showPhoneStep];
    }];
}

- (NSString *)resendTitleForCountdown:(NSInteger)seconds {
    NSInteger clamped = MAX(0, seconds);
    NSInteger minutes = clamped / 60;
    NSInteger rest = clamped % 60;
    return TGLocalizedFormat(@"Sending you an SMS in %d:%.2d",
            (int)minutes, (int)rest);
}

- (void)resendTick:(NSTimer *)timer {
    self.resendCountdown--;
    if (self.resendCountdown <= 0) {
        [self.resendTimer invalidate];
        self.resendTimer = nil;
        self.resendCountdown = 0;
        [self.resendButton setTitle:TGLocalized(@"Send the code as an SMS")
                          forState:UIControlStateNormal];
    } else {
        [self.resendButton setTitle:[self resendTitleForCountdown:self.resendCountdown]
                          forState:UIControlStateDisabled];
    }
    [self updateActionEnabled];
}

- (void)resendButtonTapped {
    if (self.onResendCode) {
        self.onResendCode();
    }
    self.resendCountdown = 60;
    [self.resendButton setTitle:[self resendTitleForCountdown:self.resendCountdown]
                      forState:UIControlStateDisabled];
    [self.resendTimer invalidate];
    self.resendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(resendTick:) userInfo:nil repeats:YES];
    [self updateActionEnabled];
}

/// Their sign-up screen: the add-photo control above the heading, both name
/// fields, the consent label and one primary Continue.
- (void)showRegisterStep {
    TGCrossFadeStepChange(self.scrollView);
    [self clearStepLinks];
    [self setBusy:NO];
    self.currentStep = TGLoginStepRegister;
    self.title = nil;
    self.headingLabel.text = @"Registration";
    self.headingLabel.hidden = NO;
    self.subtitleLabel.text = @"First and Last Name";

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Cancel"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(showPhoneStep)];

    if (self.resendButton) {
        [self.resendButton removeFromSuperview];
        self.resendButton = nil;
    }
    if (self.codeStepQrButton) {
        [self.codeStepQrButton removeFromSuperview];
        self.codeStepQrButton = nil;
    }
    [self.resendTimer invalidate];
    self.resendTimer = nil;

    [self useSingleFieldLayout];
    [self setupAvatarButtonIfNeeded];
    self.avatarButton.hidden = NO;
    self.registrationLastName = nil;
    self.inputField.placeholder = @"First Name";
    self.inputField.secureTextEntry = NO;
    self.inputField.keyboardType = UIKeyboardTypeDefault;
    self.inputField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    self.inputContainer.hidden = NO;

    // The second field, drawn lazily for this step only.
    if (!self.lastNameContainer) {
        self.lastNameContainer = [[UIView alloc] initWithFrame:CGRectZero];
        self.lastNameContainer.layer.cornerRadius = TGMetricCornerControl;
        self.lastNameContainer.layer.borderWidth = TGMetricHairline;
        self.lastNameContainer.clipsToBounds = YES;
        self.lastNameField = [[UITextField alloc] initWithFrame:CGRectZero];
        self.lastNameField.font = TGFontInput();
        self.lastNameField.contentVerticalAlignment =
                UIControlContentVerticalAlignmentCenter;
        self.lastNameField.placeholder = @"Last Name";
        self.lastNameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
        self.lastNameField.delegate = self;
        [self.lastNameField addTarget:self action:@selector(lastNameChanged:)
                     forControlEvents:UIControlEventEditingChanged];
        [self.lastNameContainer addSubview:self.lastNameField];
        [self.scrollView addSubview:self.lastNameContainer];
    }
    self.lastNameContainer.hidden = NO;
    self.lastNameContainer.backgroundColor = [[TGTheme shared] cardBackgroundColour];
    self.lastNameContainer.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    self.lastNameField.textColor = [[TGTheme shared] primaryTextColour];
    self.lastNameField.text = @"";

    // The terms belong in a small label at the bottom, not in the form's
    // subtitle; the alert carries the Agree/Decline decision.
    if (!self.termsButton) {
        self.termsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.termsButton.titleLabel.font = TGFontCaption();
        self.termsButton.titleLabel.numberOfLines = 0;
        self.termsButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.termsButton.backgroundColor = [UIColor clearColor];
        [self.termsButton addTarget:self action:@selector(signUpTermsTapped)
                   forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:self.termsButton];
    }
    self.termsButton.hidden = NO;
    [self.termsButton setTitle:@"By signing up,\nyou agree to the [Terms of Service]."
                      forState:UIControlStateNormal];
    [self.termsButton setTitleColor:[[TGTheme shared] secondaryTextColour]
                           forState:UIControlStateNormal];

    [self.actionButton setTitle:@"Continue" forState:UIControlStateNormal];
    self.nextItem.title = @"Next";

    [self layoutActiveStep];

    [self applyTheme];
    [self updateActionEnabled];
    [self.inputField becomeFirstResponder];
}

/// The 110 pt (this size's 100 pt token) add-photo control at the top of the
/// official sign-up form. The image is uploaded once the account exists.
- (void)setupAvatarButtonIfNeeded {
    if (self.avatarButton)
        return;
    CGFloat side = TGMetricProfilePhotoSide;
    self.avatarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.avatarButton.layer.cornerRadius = TGHalf(side);
    self.avatarButton.clipsToBounds = YES;
    self.avatarButton.backgroundColor = [[TGTheme shared] cardBackgroundColour];
    self.avatarButton.layer.borderWidth = TGMetricHairline;
    self.avatarButton.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    [self.avatarButton addTarget:self action:@selector(avatarTapped)
                forControlEvents:UIControlEventTouchUpInside];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:
            CGRectMake(0, 0, side, side)];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.userInteractionEnabled = NO;
    [self.avatarButton addSubview:imageView];
    self.avatarImageView = imageView;

    [self.avatarButton setImage:[TGIcons glyphNamed:@"plus"
            colour:[[TGTheme shared] secondaryTextColour]
            side:TGMetricRow] forState:UIControlStateNormal];
    [self.scrollView addSubview:self.avatarButton];
}

- (void)avatarTapped {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [self dismissViewControllerAnimated:YES completion:nil];
    if (!image)
        return;
    NSData *data = UIImageJPEGRepresentation(image, 0.9f);
    NSString *path = [NSTemporaryDirectory()
            stringByAppendingPathComponent:@"tg_signup_avatar.jpg"];
    if (data && [data writeToFile:path atomically:YES]) {
        self.registrationPhotoPath = path;
        self.avatarImageView.image = image;
        [self.avatarButton setImage:nil forState:UIControlStateNormal];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)lastNameChanged:(UITextField *)sender {
    self.registrationLastName = sender.text;
    [self updateActionEnabled];
}

- (void)signUpTermsTapped {
    NSString *terms = [[TGAccountStore shared] registrationTerms];
    __weak typeof(self) weakSelf = self;
    [TGAlertSheet showChoices:@[TGLocalized(@"Agree"), TGLocalized(@"Decline")]
                        title:TGLocalized(@"Terms of Service")
                      message:(terms.length ? terms : nil)
             destructiveIndex:1
                       inView:self.view
                     onChoice:^(NSInteger index){
        if (index != 1)
            return;
        TGLoginViewController *me = weakSelf;
        [TGAlertSheet showConfirm:TGLocalized(@"Do you want to stop the registration process?")
                            title:nil
                           action:TGLocalized(@"OK")
                      destructive:YES
                           inView:me.view
                        onConfirm:^{
            [me clearError];
            [me showPhoneStep];
        }];
    }];
}

- (void)showPasswordStep {
    NSDictionary *info = [TGAccountStore shared].loginPasswordInfo;
    NSString *hint = info[@"password_hint"];
    // The hint is the field's placeholder, as official uses it; it used to be
    // a second paragraph under the instructions.
    NSString *placeholder = hint.length ? hint : @"Password";
    [self showFieldStep:TGLoginStepPassword title:nil
               subtitle:TGLocalized(@"Enter your Telegram 2-Step Verification password to continue.")
            placeholder:placeholder secure:YES keyboard:UIKeyboardTypeDefault
                 button:@"Continue"];
    self.headingLabel.text = nil;
    [self addStepLink:@"Forgot password?" action:@selector(forgotPasswordTapped) atY:0];
    [self layoutActiveStep];
}

/// Asks Telegram to mail a recovery code. An account without a recovery
/// address gets Telegram's refusal, said plainly: there is nothing else this
/// app can offer it.
- (void)forgotPasswordTapped {
    [self setBusy:YES];
    __weak typeof(self) weakSelf = self;
    [[TGAccountStore shared] requestPasswordRecoveryWithCompletion:^(NSString *error){
        TGLoginViewController *me = weakSelf;
        [me setBusy:NO];
        if (error) {
            [TGAlertSheet showMessage:error title:@"Forgot Password?" inView:me.view];
            return;
        }
        [me showRecoveryCodeStep];
    }];
}

- (void)showRecoveryCodeStep {
    NSString *pattern = [TGAccountStore shared].loginPasswordInfo[@"recovery_email_address_pattern"];
    NSString *subtitle = pattern.length
            ? TGLocalizedFormat(@"Please enter the code we just emailed to %@", pattern)
            : TGLocalized(@"The code has been sent. Please check your email. Be sure to check the spam folder as well.");
    [self showFieldStep:TGLoginStepRecoveryCode title:nil subtitle:subtitle
            placeholder:@"Code" secure:NO keyboard:UIKeyboardTypeNumberPad
                 button:@"Continue"];
}

- (void)showEmailStep {
    [self showFieldStep:TGLoginStepEmail title:nil
               subtitle:TGLocalized(@"Setup your email address for Telegram login codes.")
            placeholder:@"Email Address" secure:NO keyboard:UIKeyboardTypeEmailAddress
                 button:@"Continue"];
    // The heading belongs in the content, not in the bar.
    self.headingLabel.hidden = NO;
    self.headingLabel.text = @"Login Email";
    [self layoutActiveStep];
}

- (void)showEmailCodeStep {
    NSDictionary *info = [TGAccountStore shared].emailCodeInfo;
    NSString *pattern = info[@"code_info"][@"email_address_pattern"];
    NSString *subtitle = pattern.length
            ? TGLocalizedFormat(@"Please enter the code we have sent to your email %@.", pattern)
            : TGLocalized(@"The code has been sent. Please check your email. Be sure to check the spam folder as well.");
    [self showFieldStep:TGLoginStepEmailCode title:nil subtitle:subtitle
            placeholder:@"Code" secure:NO keyboard:UIKeyboardTypeNumberPad
                 button:@"Continue"];
    self.expectedCodeLength = [info[@"code_info"][@"length"] integerValue];
    [self updateActionEnabled];
    if ([info[@"can_reset_email_address"] boolValue])
        [self addStepLink:@"Can't access this email?" action:@selector(resetEmailTapped) atY:0];
    [self layoutActiveStep];
}

- (void)resetEmailTapped {
    // The reset has no completion; the next authorization state replaces this
    // step. Releasing here keeps the button usable if the answer never comes.
    [[TGAccountStore shared] resetAuthenticationEmailAddress];
    [self setBusy:NO];
}

- (void)codeMissingTapped {
    [[TGAccountStore shared] reportAuthenticationCodeMissing];
    [TGAlertSheet showMessage:@"Done"
                        title:@"Code" inView:self.view];
}

/// A token from a web login: the desktop page shows one when it waits for a
/// phone to approve it. Either it signs in, or it is dropped so it stops
/// waiting - both answers come from Telegram and are shown.
- (void)webTokenTapped {
    __weak typeof(self) weakSelf = self;
    [TGAlertSheet showInput:@"Web Login Token"
                    message:nil
                placeholder:@"Token"
                       text:nil
                     action:@"Continue"
                     inView:self.view
                   onSubmit:^(NSString *token){
        TGLoginViewController *me = weakSelf;
        [TGAlertSheet showChoices:@[@"Log In", @"Dismiss"]
                            title:@"Web Login Token"
                     destructiveIndex:1
                           inView:me.view
                         onChoice:^(NSInteger index){
            if (index == 1){
                [[TGAccountStore shared] dismissWebToken:token completion:^(NSString *error){
                    [TGAlertSheet showMessage:(error
                            ?: @"Done")
                                        title:@"Web Login Token" inView:me.view];
                }];
                return;
            }
            [TGAlertSheet showInput:@"Datacenter"
                            message:nil
                        placeholder:@"dc_id"
                               text:@"2"
                             action:@"Log In"
                             inView:me.view
                           onSubmit:^(NSString *dc){
                NSInteger dcId = [dc integerValue];
                if (dcId <= 0)
                    dcId = 2;
                [[TGAccountStore shared] checkAuthenticationWebToken:token dcId:dcId
                                                    completion:^(NSString *error){
                    [TGAlertSheet showMessage:(error
                            ?: @"Done")
                                        title:@"Web Login Token" inView:me.view];
                }];
            }];
        }];
    }];
}

/// The other half of QR login: a link from a QR another device shows. The
/// server creates the session, so success is the authorization state that
/// follows; a refusal is said here instead.
- (void)qrLinkTapped {
    __weak typeof(self) weakSelf = self;
    [TGAlertSheet showInput:@"QR Code"
                    message:nil
                placeholder:@"tg://login?token=..."
                       text:nil
                     action:@"Confirm"
                     inView:self.view
                   onSubmit:^(NSString *link){
        TGLoginViewController *me = weakSelf;
        [[TGAccountStore shared] confirmQrCodeAuthenticationLink:link completion:^(NSString *error){
            [TGAlertSheet showMessage:(error
                    ?: @"Done")
                                title:@"QR Code" inView:me.view];
        }];
    }];
}

/// The Firebase code arrives as a secret in a push, not as an SMS. There is
/// no verification SDK on this OS, so the sheet asks for the secret; the
/// answer still comes from the server.
- (void)firebaseCodeTapped {
    __weak typeof(self) weakSelf = self;
    [TGAlertSheet showInput:@"Verify"
                    message:nil
                placeholder:@"Secret"
                       text:nil
                     action:@"Submit"
                     inView:self.view
                   onSubmit:^(NSString *token){
        TGLoginViewController *me = weakSelf;
        [[TGAccountStore shared] sendAuthenticationFirebaseSms:token completion:^(NSString *error){
            [TGAlertSheet showMessage:(error
                    ?: @"Done")
                                title:@"Verify" inView:me.view];
        }];
    }];
}

/// Sizes the subtitle to its text and returns where it ends. It was two
/// lines high whatever it said, so "...via SMS to" lost the phone number on
/// the code step, the one line that says where the code went.
- (CGFloat)placeSubtitle {
    return [self placeSubtitleAtY:TGMetricStackTop];
}

- (CGFloat)placeSubtitleAtY:(CGFloat)y {
    CGFloat width = self.view.bounds.size.width - TGDoubled(TGMetricPadWide);
    self.subtitleLabel.numberOfLines = 0;
    CGFloat height = MAX(TGTextHeight(self.subtitleLabel.text, self.subtitleLabel.font, width),
                         TGMetricLoginSubtitleHeight);
    self.subtitleLabel.frame = CGRectMake(TGMetricPadWide, y, width, height);
    return y + height;
}

- (CGFloat)placeErrorAtY:(CGFloat)y width:(CGFloat)width {
    if (self.errorLabel.hidden)
        return y;
    CGFloat height = TGDoubled(TGMetricLineCaption);
    self.errorLabel.frame = CGRectMake(TGMetricGutter, y,
            width - TGDoubled(TGMetricGutter), height);
    return y + height + TGMetricStackStep;
}

- (void)clearError {
    self.codeErrorShown = NO;
    if (self.errorLabel.hidden && !self.errorLabel.text.length)
        return;
    self.errorLabel.text = nil;
    self.errorLabel.hidden = YES;
    [self layoutActiveStep];
}

- (void)clearStepLinks {
    for (UIView *link in self.stepLinks)
        [link removeFromSuperview];
    [self.stepLinks removeAllObjects];
}

/// One ghost link at `y`; returns where the next one goes. A step added after
/// layoutActiveStep ran lands its own frame here; the same geometry pass
/// places every link again from the step's anchor.
- (CGFloat)addStepLink:(NSString *)title action:(SEL)action atY:(CGFloat)y {
    if (!self.stepLinks)
        self.stepLinks = [NSMutableArray array];
    CGFloat width = self.view.bounds.size.width;
    TGButton *link = [TGButton buttonWithTitle:title variant:TGButtonVariantGhost size:TGButtonSizeSmall];
    link.frame = CGRectMake(TGMetricGutter, y, width - TGDoubled(TGMetricGutter), TGMetricLoginLinkHeight);
    [link addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:link];
    [self.stepLinks addObject:link];
    CGFloat next = y + TGMetricLoginLinkHeight + TGMetricPadSmall;
    self.scrollView.contentSize = CGSizeMake(width, MAX(self.scrollView.contentSize.height, next + TGMetricPadLarge));
    return next;
}

/// The steps that are one field and one button: the password and the
/// email ones. Links are added by the caller under the button.
- (void)showFieldStep:(TGLoginStep)step title:(NSString *)title subtitle:(NSString *)subtitle
          placeholder:(NSString *)placeholder secure:(BOOL)secure
             keyboard:(UIKeyboardType)keyboard button:(NSString *)button {
    TGCrossFadeStepChange(self.scrollView);
    [self setBusy:NO];
    self.errorLabel.text = nil;
    self.errorLabel.hidden = YES;
    [self clearStepLinks];
    self.currentStep = step;
    self.title = nil;
    self.headingLabel.text = nil;
    self.headingLabel.hidden = YES;
    self.subtitleLabel.text = subtitle;

    // Back chevron, not a text Cancel: official only ever goes back from
    // these steps.
    self.navigationItem.leftBarButtonItem = [self backItemWithAction:
            @selector(showPhoneStep)];

    if (self.resendButton) {
        [self.resendButton removeFromSuperview];
        self.resendButton = nil;
    }
    if (self.codeStepQrButton) {
        [self.codeStepQrButton removeFromSuperview];
        self.codeStepQrButton = nil;
    }
    [self.resendTimer invalidate];
    self.resendTimer = nil;

    [self useSingleFieldLayout];
    // A keyboard type set on a field that already has focus is ignored until
    // it loses it: the code steps used to open on letters.
    [self.inputField resignFirstResponder];
    self.inputField.text = @"";
    self.inputField.placeholder = placeholder;
    self.inputField.secureTextEntry = secure;
    self.inputField.keyboardType = keyboard;
    self.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.inputField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self.actionButton setTitle:button forState:UIControlStateNormal];
    self.nextItem.title = @"Next";
    self.countryLabel.hidden = YES;
    self.expectedCodeLength = 0;

    [self layoutActiveStep];

    [self applyTheme];
    [self updateActionEnabled];
    [self.inputField becomeFirstResponder];
}

@end
