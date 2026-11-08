#ifndef TGLOGINVIEWCONTROLLERINTERNAL_H
#define TGLOGINVIEWCONTROLLERINTERNAL_H

#import "TGLoginViewController.h"
#import "TGUI.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>

typedef NS_ENUM(NSInteger, TGLoginStep) {
    TGLoginStepPhone,
    TGLoginStepCode,
    TGLoginStepPassword,
    /// A phone number Telegram has never seen: the account is made here, and
    /// before this step existed the code screen simply never moved on.
    TGLoginStepRegister,
    TGLoginStepEmail,
    TGLoginStepEmailCode,
    /// The code mailed to the recovery address after "Forgot password?".
    TGLoginStepRecoveryCode
};

@interface TGLoginViewController () <UIImagePickerControllerDelegate,
        UINavigationControllerDelegate>

@property (nonatomic, assign) TGLoginStep currentStep;
/// The last name typed on the registration step, which is optional and so
/// cannot live in the one input field the step shares with every other.
@property (nonatomic, copy) NSString *registrationLastName;
/// True once the prefix has been typed or pasted, so the network's country
/// guess does not overwrite a number that is not local.
@property (nonatomic, assign) BOOL prefixEdited;
/// Bumped for every phone step so an answer requested for an earlier visit
/// cannot write its prefix into the current one.
@property (nonatomic, assign) NSInteger countryGuessGeneration;
/// Set when the network's country guess has been applied; a slower device
/// lookup that lands afterwards must leave the network's answer alone.
@property (nonatomic, assign) BOOL countryGuessResolvedByNetwork;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *brandLogoView;
@property (nonatomic, strong) UILabel *brandLabel;
/// The screen heading, in the content as official draws it, not in the bar.
@property (nonatomic, strong) UILabel *headingLabel;
/// The country row above the number field; its title is the chosen country.
@property (nonatomic, strong) UIButton *countryButton;
@property (nonatomic, strong) UILabel *subtitleLabel;
/// The country and the number Telegram would write under the instructions.
/// It is its own line so the instructions do not grow to four lines as a
/// number is typed.
@property (nonatomic, strong) UILabel *countryLabel;
/// The sentence under the field when a code or password did not take. TDLib
/// keeps the same authorization state on a wrong code, so this is where the
/// screen says what happened instead of a spinner that never ends.
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIView *inputContainer;
@property (nonatomic, strong) UITextField *phonePrefixField;
@property (nonatomic, strong) UIView *prefixSeparator;
@property (nonatomic, strong) UITextField *inputField;
/// The sign-up step's avatar control, second name field and consent label,
/// created lazily.
@property (nonatomic, strong) UIButton *avatarButton;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, copy) NSString *registrationPhotoPath;
@property (nonatomic, strong) UIView *lastNameContainer;
@property (nonatomic, strong) UITextField *lastNameField;
@property (nonatomic, strong) UIButton *termsButton;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIBarButtonItem *nextItem;
@property (nonatomic, strong) UIButton *resendButton;
@property (nonatomic, strong) UIButton *qrCodeButton;
@property (nonatomic, strong) UIButton *codeStepQrButton;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, copy) NSString *savedPhoneNumber;
@property (nonatomic, copy) NSString *savedCountryName;
/// The part after the country code, kept so Edit on the code step returns
/// the number that was typed rather than the code that replaced it.
@property (nonatomic, copy) NSString *savedNationalNumber;
@property (nonatomic, strong) NSTimer *resendTimer;
@property (nonatomic, assign) NSInteger resendCountdown;
/// The length Telegram says a code has; zero when the answer did not name it.
/// A code that reaches it is submitted without a second tap, as Telegram does.
@property (nonatomic, assign) NSInteger expectedCodeLength;
/// True while one request is in flight, so the fields and links stop moving
/// under it and a second tap cannot send the same number twice.
@property (nonatomic, assign) BOOL busy;
/// The ghost links under a step's button that only that step has.
@property (nonatomic, strong) NSMutableArray *stepLinks;
/// Paints the digit boxes over the code field; the field itself stays behind
/// them so the number pad and paste keep working.
@property (nonatomic, strong) UIView *codeBoxesView;
/// A code was sent and its answer has not arrived yet. A busy release while
/// this stays YES means the check failed, since success changes the step.
@property (nonatomic, assign) BOOL codeSubmitPending;
/// The code boxes carry the red rejection border until the next keystroke.
@property (nonatomic, assign) BOOL codeErrorShown;
/// The phone-number confirmation card, on widths where the official sheet
/// fits; nil while it is not showing.
@property (nonatomic, strong) UIView *phoneConfirmationView;

- (void)setupUI;
- (void)applyTheme;
- (void)actionButtonTapped;
- (void)updateActionEnabled;
- (BOOL)canSubmitCurrentStep;

@end

@interface TGLoginViewController (Phone)

- (BOOL)containsKnownCountryPrefix:(NSString *)digits;
- (BOOL)looksLikeInternationalNumber:(NSString *)text;
- (void)processPastedPhoneNumber:(NSString *)raw;
- (void)inputFieldChanged:(UITextField *)sender;
- (void)prefixFieldChanged:(UITextField *)sender;
- (void)countryPickerTapped;
/// Resolves the prefix being typed through getPhoneNumberInfo and says the
/// country and formatted number under the instructions.
- (void)refreshPhoneNumberInfo;

@end

@interface TGLoginViewController (StepsInternal)

/// Writes the current step's frames from the view's present bounds. The
/// show methods only choose a step - titles, secrets, timers - and land
/// here; this runs again on every layout pass and rotation, so nothing on
/// the screen keeps the frame it got while the bounds were other.
- (void)layoutActiveStep;
- (void)layoutPhoneStepInWidth:(CGFloat)width;
- (void)layoutCodeStepInWidth:(CGFloat)width;
- (void)layoutFieldStepInWidth:(CGFloat)width;
- (void)layoutQRStepInWidth:(CGFloat)width;
- (void)updatePrimaryActionForWidth:(CGFloat)width;
- (void)updateCodeBoxes;
/// Paints a rejected code: red boxes, no digits, the reason under them.
- (void)showCodeError;
- (UIBarButtonItem *)backItemWithAction:(SEL)action;
- (void)confirmStopVerification;
- (void)selectDeviceCountryPrefix;
- (CGFloat)placeSubtitle;
- (CGFloat)placeSubtitleAtY:(CGFloat)y;
- (CGFloat)placeErrorAtY:(CGFloat)y width:(CGFloat)width;
- (void)clearError;
- (void)qrCodeButtonTapped;
- (void)useSingleFieldLayout;
- (void)resendTick:(NSTimer *)timer;
- (void)resendButtonTapped;
- (NSString *)resendTitleForCountdown:(NSInteger)seconds;
- (void)resetSessionTapped;
- (UIImage *)generateQRCodeForString:(NSString *)string size:(CGFloat)size;
- (void)clearStepLinks;
- (void)showRecoveryCodeStep;
- (void)forgotPasswordTapped;
- (void)codeMissingTapped;
- (void)resetEmailTapped;
/// A token from a web login: signs in with it, or lets it expire.
- (void)webTokenTapped;
/// Confirms a QR link another screen scanned, instead of showing one here.
- (void)qrLinkTapped;
/// The code is coming by Firebase push: asks for the secret and hands it on.
- (void)firebaseCodeTapped;

@end

#endif // TGLOGINVIEWCONTROLLERINTERNAL_H
