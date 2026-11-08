#import "TGLoginViewControllerInternal.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGClient.h"
#import "TGIcons.h"
#import "TGUIFormat.h"
#import "TGLocalization.h"

@implementation TGLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Official has no title in the bar on any auth screen: the heading lives
    // in the content, where it can be the 28 pt line the node draws.
    self.title = nil;

    self.nextItem = [[UIBarButtonItem alloc] initWithTitle:@"Next"
                                                     style:UIBarButtonItemStyleDone
                                                    target:self
                                                    action:@selector(actionButtonTapped)];

    [self setupUI];
    [self applyTheme];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:TGThemeChangedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    // viewDidLayoutSubviews carries most devices through a rotation; this
    // notification catches the iOS 6 and 7 passes that once didn't call it.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(layoutActiveStep)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)dealloc {
    [self.resendTimer invalidate];
    self.resendTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutActiveStep];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

- (void)setupUI {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    self.view.backgroundColor = [[TGTheme shared] groupedBackgroundColour];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.alwaysBounceVertical = YES;
    if ([self.scrollView respondsToSelector:@selector(setKeyboardDismissMode:)]) {
        self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    }
    [self.view addSubview:self.scrollView];

    CGFloat inner = width - TGDoubled(TGMetricGutter);
    CGFloat y = TGMetricStackTop;

    // The heading is the screen's title, in the content rather than the bar,
    // as the official phone entry node draws it.
    self.headingLabel = [[UILabel alloc] initWithFrame:
            CGRectMake(TGMetricGutter, y, inner, TGMetricLoginBrandLabel)];
    self.headingLabel.text = @"Your Phone";
    self.headingLabel.font = TGFontTitle();
    self.headingLabel.textAlignment = NSTextAlignmentLeft;
    self.headingLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.headingLabel];

    y += TGMetricLoginBrandLabel + TGMetricPadMedium;
    self.subtitleLabel = [[UILabel alloc] initWithFrame:
            CGRectMake(TGMetricGutter, y, inner, TGMetricLoginSubtitleHeight)];
    self.subtitleLabel.text = @"Please confirm your country code\nand enter your phone number.";
    self.subtitleLabel.backgroundColor = [UIColor clearColor];
    self.subtitleLabel.font = TGFontSubhead();
    self.subtitleLabel.textAlignment = NSTextAlignmentLeft;
    self.subtitleLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.subtitleLabel];

    // Country is a row above the number, not an editable prefix and not a
    // ghost link under the form.
    y += TGMetricLoginSubtitleHeight + TGMetricStackGroup;
    self.countryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.countryButton.frame = CGRectMake(TGMetricGutter, y, inner,
                                          TGMetricLoginLinkHeight);
    self.countryButton.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;
    self.countryButton.titleLabel.font = TGFontSubheadStrong();
    self.countryButton.backgroundColor = [UIColor clearColor];
    [self.countryButton addTarget:self action:@selector(countryPickerTapped)
                forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.countryButton];

    self.countryLabel = [[UILabel alloc] initWithFrame:
            CGRectMake(TGMetricGutter, y, inner, TGMetricLoginCountryLine)];
    self.countryLabel.font = TGFontSubhead();
    self.countryLabel.textAlignment = NSTextAlignmentLeft;
    self.countryLabel.backgroundColor = [UIColor clearColor];
    self.countryLabel.numberOfLines = 1;
    self.countryLabel.hidden = YES;
    [self.scrollView addSubview:self.countryLabel];

    self.errorLabel = [[UILabel alloc] initWithFrame:
            CGRectMake(TGMetricGutter, 0, inner, TGMetricLineCaption)];
    self.errorLabel.font = TGFontCaption();
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.backgroundColor = [UIColor clearColor];
    self.errorLabel.numberOfLines = 2;
    self.errorLabel.hidden = YES;
    [self.scrollView addSubview:self.errorLabel];

    // Grouped input container: the calling code is read-only, the country is
    // chosen from the row above it.
    y += TGMetricLoginLinkHeight + TGMetricStackStep;
    self.inputContainer = [[UIView alloc] initWithFrame:
            CGRectMake(TGMetricGutter, y, inner, TGMetricRow)];
    self.inputContainer.layer.cornerRadius = TGMetricCornerControl;
    self.inputContainer.layer.borderWidth = TGMetricHairline;
    self.inputContainer.clipsToBounds = YES;
    [self.scrollView addSubview:self.inputContainer];

    self.phonePrefixField = [[UITextField alloc] initWithFrame:
            CGRectMake(TGMetricPadMedium, 0, TGMetricLoginPrefixWidth, TGMetricRow)];
    self.phonePrefixField.text = @"";
    self.phonePrefixField.font = TGFontHeader();
    self.phonePrefixField.textAlignment = NSTextAlignmentCenter;
    self.phonePrefixField.userInteractionEnabled = NO;
    [self.inputContainer addSubview:self.phonePrefixField];

    // Hairline vertical separator between prefix and phone number.
    self.prefixSeparator = [[UIView alloc] initWithFrame:CGRectMake(
            TGMetricPadMedium + TGMetricLoginPrefixWidth + TGMetricPadTiny,
            TGMetricBubblePadV, TGMetricHairline,
            TGMetricRow - TGDoubled(TGMetricBubblePadV))];
    [self.inputContainer addSubview:self.prefixSeparator];

    CGFloat fieldX = TGMetricPadMedium + TGMetricLoginPrefixWidth + TGMetricPadMedium;
    self.inputField = [[UITextField alloc] initWithFrame:
            CGRectMake(fieldX, 0, inner - fieldX - TGMetricPadMedium, TGMetricRow)];
    self.inputField.placeholder = @"Phone number";
    self.inputField.font = TGFontInput();
    // iOS 6 sets a field's text against its top edge unless told otherwise;
    // in a 44 pt row the code and password sat a third of the way down.
    self.inputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.phonePrefixField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.inputField.keyboardType = UIKeyboardTypePhonePad;
    self.inputField.returnKeyType = UIReturnKeyGo;
    self.inputField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.inputField.delegate = self;
    [self.inputField addTarget:self action:@selector(inputFieldChanged:)
              forControlEvents:UIControlEventEditingChanged];
    [self.inputContainer addSubview:self.inputField];

    self.actionButton = [TGButton buttonWithTitle:@"Continue"
                                          variant:TGButtonVariantPrimary
                                             size:TGButtonSizeLarge];
    y += TGMetricRow + TGMetricStackStep;
    // One control height, not 44 for the field and 42 for the button under it.
    self.actionButton.frame = CGRectMake(TGMetricGutter, y, inner, TGMetricRow);
    [self.actionButton addTarget:self action:@selector(actionButtonTapped)
                forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.actionButton];

    // Activity spinner beside the title rather than replacing it.
    self.spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.center = CGPointMake(TGHalf(inner) - TGMetricPadWide, TGHalf(TGMetricRow));
    self.spinner.hidesWhenStopped = YES;
    [self.actionButton addSubview:self.spinner];

    y += TGMetricRow + TGMetricStackGroup;
    self.scrollView.contentSize = CGSizeMake(width, y);
    self.currentStep = TGLoginStepPhone;
    [self updateActionEnabled];
}

- (void)applyTheme {
    TGTheme *theme = [TGTheme shared];

    if (self.navigationController) {
        [theme styleNavigationBar:self.navigationController.navigationBar];
    }
    // iOS 7 reads an item's tint as its text colour; iOS 6 as the colour of
    // the button itself, so white there made white text on a white button.
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        self.nextItem.tintColor = [theme barButtonColour];
    }

    self.view.backgroundColor = [theme groupedBackgroundColour];

    self.headingLabel.textColor = [theme primaryTextColour];
    self.subtitleLabel.textColor = [theme secondaryTextColour];
    self.subtitleLabel.shadowColor = [theme etchedTextShadowColour];
    self.subtitleLabel.shadowOffset = TGMetricShadowOffsetEtched;

    [self.countryButton setTitleColor:[theme accentColour]
                             forState:UIControlStateNormal];
    self.countryLabel.textColor = [theme secondaryTextColour];
    self.errorLabel.textColor = [theme destructiveColour];

    self.inputContainer.backgroundColor = [theme cardBackgroundColour];
    self.inputContainer.layer.borderColor = [theme separatorColour].CGColor;
    self.prefixSeparator.backgroundColor = [theme separatorColour];

    self.phonePrefixField.textColor = [theme primaryTextColour];
    self.phonePrefixField.keyboardAppearance = UIKeyboardAppearanceLight;

    self.inputField.textColor = [theme primaryTextColour];
    self.inputField.keyboardAppearance = UIKeyboardAppearanceLight;

    if (self.inputField.placeholder.length) {
        self.inputField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:self.inputField.placeholder
            attributes:@{ NSForegroundColorAttributeName : [theme placeholderColour] }];
    }

    [self.actionButton setBackgroundImage:[TGTheme buttonImageForStyle:TGButtonStyleAction highlighted:NO height:TGMetricRow] forState:UIControlStateNormal];
    [self.actionButton setBackgroundImage:[TGTheme buttonImageForStyle:TGButtonStyleAction highlighted:YES height:TGMetricRow] forState:UIControlStateHighlighted];
    self.actionButton.backgroundColor = [UIColor clearColor];
    self.actionButton.layer.borderWidth = 0.0f;
    [self.actionButton setTitleColor:[[TGTheme shared] onAccentColour] forState:UIControlStateNormal];

    if (self.resendButton) {
        [self.resendButton setTitleColor:[theme accentColour] forState:UIControlStateNormal];
    }
    if (self.codeStepQrButton) {
        [self.codeStepQrButton setTitleColor:[theme accentColour] forState:UIControlStateNormal];
    }

    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (void)setBusy:(BOOL)busy {
    BOOL wasBusy = _busy;
    _busy = busy;
    if (busy) {
        self.errorLabel.text = nil;
        self.errorLabel.hidden = YES;
    }
    self.actionButton.enabled = !busy;
    self.nextItem.enabled = !busy;
    // The title stays while the spinner runs beside it, as on the official
    // node; hiding it made the button look empty on a slow network.
    if (busy) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
    [self updateActionEnabled];
    // A code check that fails leaves the auth state on the same step; the
    // client reports the error by releasing busy. Success changes the step,
    // so anything still pending here was rejected.
    if (!busy && wasBusy && self.codeSubmitPending &&
            self.currentStep == TGLoginStepCode)
        [self showCodeError];
}

/// Whether the current field holds enough to be sent. Telegram keeps the
/// button inactive until it does; a disabled Continue is the only error a
/// number that is still being typed needs.
- (BOOL)canSubmitCurrentStep {
    NSString *text = [self.inputField.text
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *digits = [text stringByReplacingOccurrencesOfString:@"\\D"
            withString:@"" options:NSRegularExpressionSearch
            range:NSMakeRange(0, text.length)];
    switch (self.currentStep) {
        case TGLoginStepPhone:
            return digits.length >= 4;
        case TGLoginStepCode:
        case TGLoginStepEmailCode:
        case TGLoginStepRecoveryCode:
            return digits.length >= 4;
        case TGLoginStepEmail:
            return [text rangeOfString:@"@"].location != NSNotFound &&
                   [text rangeOfString:@"."].location != NSNotFound;
        default:
            return text.length > 0;
    }
}

- (void)updateActionEnabled {
    BOOL ready = !self.busy && [self canSubmitCurrentStep];
    self.actionButton.enabled = ready;
    self.nextItem.enabled = ready;
    self.inputField.enabled = !self.busy;
    self.countryButton.enabled = !self.busy;
    self.resendButton.enabled = !self.busy && self.resendCountdown <= 0;
    self.codeStepQrButton.enabled = !self.busy;
    for (UIView *link in self.stepLinks) {
        link.userInteractionEnabled = !self.busy;
        link.alpha = self.busy ? TGAlphaDimmed : TGAlphaOpaque;
    }
}

- (void)actionButtonTapped {
    if (![self canSubmitCurrentStep])
        return;
    NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (self.currentStep == TGLoginStepPhone) {
        NSString *fullPhone = TGUIFormatFullPhone(self.phonePrefixField.text, text);
        self.savedPhoneNumber = fullPhone;
        self.savedNationalNumber = text;
        // Official confirms the number before it is sent: a sheet above 320 pt,
        // an alert below it. Busy starts only on Continue, so closing either
        // one leaves the form usable.
        if (self.view.bounds.size.width > 320.0f)
            [self presentPhoneConfirmationForNumber:fullPhone];
        else
            [self presentPhoneConfirmationAlertForNumber:fullPhone];
        return;
    }

    [self setBusy:YES];

    if (self.currentStep == TGLoginStepCode) {
        NSString *cleanCode = [text stringByReplacingOccurrencesOfString:@"\\D" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)];
        self.codeSubmitPending = YES;
        if (self.onCodeSubmitted) {
            self.onCodeSubmitted(cleanCode.length ? cleanCode : text);
        }
    } else if (self.currentStep == TGLoginStepPassword) {
        if (self.onPasswordSubmitted) {
            self.onPasswordSubmitted(text);
        }
    } else if (self.currentStep == TGLoginStepEmail) {
        [[TGClient shared] sendEmailAddress:text];
    } else if (self.currentStep == TGLoginStepEmailCode) {
        [[TGClient shared] sendEmailCode:text];
    } else if (self.currentStep == TGLoginStepRecoveryCode) {
        __weak typeof(self) weakSelf = self;
        [[TGClient shared] recoverPasswordWithCode:text completion:^(NSString *error){
            TGLoginViewController *me = weakSelf;
            [me setBusy:NO];
            if (error)    // success moves on by the authorization state
                [TGAlertSheet showMessage:error title:@"Code" inView:me.view];
        }];
    } else if (self.currentStep == TGLoginStepRegister) {
        __weak typeof(self) weakSelf = self;
        [[TGClient shared] registerWithFirstName:text
                                        lastName:self.registrationLastName
                                      completion:^(BOOL ok, NSString *error){
            TGLoginViewController *me = weakSelf;
            [me setBusy:NO];
            if (ok) {
                // The avatar chosen on the form is uploaded now that the
                // account exists; the authorization state carries the screen
                // on, and a failed upload is not worth blocking it.
                if (me.registrationPhotoPath.length)
                    [[TGClient shared] setProfilePhotoAtPath:me.registrationPhotoPath
                                                  completion:nil];
                return;
            }
            [TGAlertSheet showMessage:(error ?: @"An error occurred.")
                                title:@"Registration" inView:me.view];
        }];
    }
}

#pragma mark - phone number confirmation

/// Above 320 pt official slides up a confirmation sheet with the number and
/// Edit/Continue. A bottom card is that sheet on this OS; the form stays
/// behind it and nothing is disabled until Continue.
- (void)presentPhoneConfirmationForNumber:(NSString *)fullPhone {
    [self dismissPhoneConfirmation];
    // The card sits at the bottom edge, so the keypad has to be gone first.
    [self.view endEditing:YES];

    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat cardH = TGMetricPadLarge + TGMetricLineTitle + TGMetricPadSmall +
            TGDoubled(TGMetricLineCaption) + TGMetricPadLarge + TGMetricRow +
            TGMetricPadLarge;

    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.backgroundColor = [[TGTheme shared] scrimColour];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

    // The wash is a separate view under the card: a recognizer on the overlay
    // itself also caught taps on Edit/Continue, cancelling the button and
    // turning Continue into Edit.
    UIView *wash = [[UIView alloc] initWithFrame:self.view.bounds];
    wash.backgroundColor = [UIColor clearColor];
    wash.autoresizingMask = UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(phoneConfirmationEditTapped)];
    [wash addGestureRecognizer:tap];
    [overlay addSubview:wash];

    UIView *card = [[UIView alloc] initWithFrame:
            CGRectMake(0, height - cardH, width, cardH)];
    card.backgroundColor = [[TGTheme shared] groupedBackgroundColour];
    card.layer.borderWidth = TGMetricHairline;
    card.layer.borderColor = [[TGTheme shared] separatorColour].CGColor;
    card.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleWidth;
    [overlay addSubview:card];

    UILabel *number = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricGutter,
            TGMetricPadLarge, width - TGDoubled(TGMetricGutter), TGMetricLineTitle)];
    number.text = fullPhone;
    number.font = TGFontTitle();
    number.textAlignment = NSTextAlignmentCenter;
    number.textColor = [[TGTheme shared] primaryTextColour];
    number.backgroundColor = [UIColor clearColor];
    [card addSubview:number];

    UILabel *question = [[UILabel alloc] initWithFrame:CGRectMake(TGMetricGutter,
            CGRectGetMaxY(number.frame) + TGMetricPadSmall,
            width - TGDoubled(TGMetricGutter), TGDoubled(TGMetricLineCaption))];
    question.text = TGLocalized(@"Is this the correct number?");
    question.font = TGFontSubhead();
    question.numberOfLines = 2;
    question.textAlignment = NSTextAlignmentCenter;
    question.textColor = [[TGTheme shared] secondaryTextColour];
    question.backgroundColor = [UIColor clearColor];
    [card addSubview:question];

    CGFloat buttonY = cardH - TGMetricPadLarge - TGMetricRow;
    CGFloat buttonW = TGHalf(width - TGDoubled(TGMetricGutter) - TGMetricPadSmall);
    TGButton *edit = [TGButton buttonWithTitle:TGLocalized(@"Edit")
            variant:TGButtonVariantGhost size:TGButtonSizeLarge];
    edit.frame = CGRectMake(TGMetricGutter, buttonY, buttonW, TGMetricRow);
    [edit addTarget:self action:@selector(phoneConfirmationEditTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:edit];

    TGButton *cont = [TGButton buttonWithTitle:TGLocalized(@"Continue")
            variant:TGButtonVariantPrimary size:TGButtonSizeLarge];
    cont.frame = CGRectMake(width - TGMetricGutter - buttonW, buttonY,
            buttonW, TGMetricRow);
    [cont addTarget:self action:@selector(phoneConfirmationContinueTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:cont];

    self.phoneConfirmationView = overlay;
    [self.view addSubview:overlay];
}

- (void)presentPhoneConfirmationAlertForNumber:(NSString *)fullPhone {
    __weak typeof(self) weakSelf = self;
    [TGAlertSheet showChoices:@[TGLocalized(@"Edit"), TGLocalized(@"Continue")]
                        title:fullPhone
                        message:TGLocalized(@"Is this the correct number?")
                        destructiveIndex:-1
                         inView:self.view
                       onChoice:^(NSInteger index){
        TGLoginViewController *me = weakSelf;
        if (!me)
            return;
        if (index != 1) {
            [me setBusy:NO];
            [me.inputField becomeFirstResponder];
            return;
        }
        [me submitConfirmedPhoneNumber:fullPhone];
    }];
}

- (void)phoneConfirmationEditTapped {
    [self dismissPhoneConfirmation];
    [self.inputField becomeFirstResponder];
}

- (void)phoneConfirmationContinueTapped {
    NSString *number = self.savedPhoneNumber;
    [self dismissPhoneConfirmation];
    if (number.length)
        [self submitConfirmedPhoneNumber:number];
}

- (void)submitConfirmedPhoneNumber:(NSString *)fullPhone {
    [self setBusy:YES];
    if (self.onPhoneSubmitted)
        self.onPhoneSubmitted(fullPhone);
}

- (void)dismissPhoneConfirmation {
    [self.phoneConfirmationView removeFromSuperview];
    self.phoneConfirmationView = nil;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat kbHeight = kbFrame.size.height;

    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0, 0, kbHeight + TGMetricPadMedium, 0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;

    CGRect field = [self.inputField convertRect:self.inputField.bounds
                                         toView:self.scrollView];
    [self.scrollView scrollRectToVisible:CGRectInset(field, 0, -TGMetricPad)
                                animated:YES];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

@end
