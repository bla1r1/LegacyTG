//
// TGSettingsViewControllerInternal.h - Private class extension and row model for TGSettingsViewController
//
#ifndef TGSETTINGSVIEWCONTROLLERINTERNAL_H
#define TGSETTINGSVIEWCONTROLLERINTERNAL_H

#import "TGSettingsViewController.h"
#import "TGUI.h"
#import "TGLocalization.h"
#import "TGSettingsFormatting.h"
#import "TGTheme.h"
#import "TGThemeFile.h"
#import "TGStorageViewController.h"
#import "TGDevFileToolsViewController.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGDevice.h"
#import "TGCapabilities.h"
#import "TGEditProfileViewController.h"
#import "TGProfileViewController.h"
#import "TGQRViewController.h"
#import "TGPlaceholderViewController.h"
#import "TGIcons.h"
#import "TGRows.h"
#import <QuartzCore/QuartzCore.h>

@interface TGSettingsViewController (Tier2)
/// The profile-extras card: emoji status, profile audio, text styles and the
/// stake dice panel. Implemented in TGSettingsViewController+Tier2.m so the
/// root page does not grow another list of rows.
- (NSArray *)tier2Sections;
@end

@interface TGSettingsViewController () <
		UIImagePickerControllerDelegate, UINavigationControllerDelegate,
		UISearchBarDelegate>

@property (nonatomic, strong) NSMutableDictionary *privacy;    // setting -> value
@property (nonatomic, strong) NSMutableDictionary *muted;      // scope -> NSNumber
@property (nonatomic, strong) NSMutableDictionary *previews;   // scope -> NSNumber
/// Keep the slot the profile-photo action clears after an upload; the header
/// itself is now a shared row cell and no longer held here.
@property (nonatomic, strong) UITableViewCell *profileCell;
@property (nonatomic, strong) NSArray *languages;
@property (nonatomic, strong) NSString *currentLanguage;
/// The language page's navigation-bar search. The list is filtered by the
/// native name and the pack id as the user types.
@property (nonatomic, strong) UISearchBar *languageSearchBar;
@property (nonatomic, copy) NSString *languageSearchText;
/// The current pack's record, read back from getLanguagePackInfo. The actions
/// that edit a pack need the whole object, not only the id.
@property (nonatomic, strong) NSDictionary *languageInfo;
/// The string list this page last read. updateLanguagePackStrings re-reads it
/// so the row's count and the sheet both follow the server.
@property (nonatomic, strong) NSArray *languagePackStrings;
/// The country this device is in, its preferred language and its flag. All
/// three come from Telegram so the page agrees with the phone step.
@property (nonatomic, strong) NSString *countryCode;
@property (nonatomic, strong) NSDictionary *countryInfo;
@property (nonatomic, strong) NSString *preferredCountryLanguage;
@property (nonatomic, strong) NSString *countryFlag;
@property (nonatomic, strong) NSArray *blocked;
@property (nonatomic, strong) NSArray *calls;
@property (nonatomic, assign) NSInteger accountTtl;
/// Whether the away-for answer has arrived; zero is a real value.
@property (nonatomic, assign) BOOL accountTtlLoaded;
/// A tap on Saved Messages before the chat id exists waits a few times for
/// the account record rather than showing a modal "Loading..." alert.
@property (nonatomic, assign) NSInteger savedMessagesRetries;
/// Privacy page: the lifetime new chats start with, loaded per open.
@property (nonatomic, assign) NSInteger autoDeleteDefault;
@property (nonatomic, assign) BOOL hasPassword;
@property (nonatomic, assign) BOOL passwordKnown;
@property (nonatomic, assign) BOOL suggestFrequent;
@property (nonatomic, assign) long long networkSent;
@property (nonatomic, assign) long long networkReceived;
@property (nonatomic, strong) NSString *tdlibVersion;
@property (nonatomic, assign) BOOL pickingProfilePhoto;
@property (nonatomic, assign) CGFloat lastScrollY;
/// The folders page: the account's own folders and Telegram's suggestions,
/// each loaded once the page opens.
@property (nonatomic, strong) NSArray *recommendedFolders;
/// Chat folder tags: the setting lives on Telegram's side, so the switch
/// starts on and remembers the last move for this launch.
@property (nonatomic, assign) BOOL folderTagsEnabled;
@property (nonatomic, assign) BOOL folderTagsLoaded;
/// Privacy: who may write first, and the chat shown as this account's own.
@property (nonatomic, assign) BOOL newChatAllowUnknown;
@property (nonatomic, assign) BOOL newChatPrivacyLoaded;
@property (nonatomic, assign) int64_t personalChatId;
/// Privacy: the read-date switch and the close-friends count, both read per
/// open. The contacts with a birthday nearby come from the client's update
/// cache, so the row can say how many the hide clears.
@property (nonatomic, assign) BOOL readDateLoaded;
@property (nonatomic, assign) BOOL showReadDate;
@property (nonatomic, assign) BOOL closeFriendsLoaded;
@property (nonatomic, assign) NSInteger closeFriendsCount;
@property (nonatomic, strong) NSArray *closeBirthdayRows;
/// The proxy page: every proxy TDLib knows, and whether one is on.
@property (nonatomic, strong) NSArray *proxies;
/// The downloads page: the list Telegram keeps, and how many are running.
@property (nonatomic, strong) NSArray *downloads;
@property (nonatomic, assign) NSInteger activeDownloads;
/// Custom Sounds: getSavedNotificationSounds answered, and whether it has.
@property (nonatomic, strong) NSArray *savedSounds;
@property (nonatomic, assign) BOOL savedSoundsLoaded;
/// Data and Storage: Telegram's Low/Medium/High auto-download presets, as
/// getAutoDownloadSettingsPresets answered them.
@property (nonatomic, strong) NSDictionary *autoDownloadPresets;
/// Whether the user moved an auto-download setting since this page opened;
/// the Reset row is only active after a change.
@property (nonatomic, assign) BOOL autoDownloadChanged;
/// The Autosave page: which scope it was opened for, empty for the combined
/// page the row used to show.
@property (nonatomic, copy) NSString *autosaveScope;
/// Chat counts per folder id, read when the folders page opens; the official
/// row shows the count on the right.
@property (nonatomic, strong) NSMutableDictionary *folderChatCounts;
/// The Autosave page: private/group/channel defaults plus per-chat exceptions.
@property (nonatomic, strong) NSDictionary *autosaveSettings;
/// Appearance: the two accent colours this account has selected. -1 is the
/// profile's "none", which is a real value Telegram sends.
@property (nonatomic, assign) BOOL accentColorsLoaded;
@property (nonatomic, assign) NSInteger accentColorId;
@property (nonatomic, assign) NSInteger profileAccentColorId;
/// Auto-Night's time picker and which end of the schedule it is editing.
@property (nonatomic, strong) UIDatePicker *autoNightPicker;
@property (nonatomic, assign) BOOL autoNightPickingFrom;
/// The payment page: the order Telegram kept from the last checkout. A 404
/// is "none saved", not a read failure, so the error is kept apart.
@property (nonatomic, strong) NSDictionary *savedOrder;
@property (nonatomic, strong) NSString *savedOrderError;
@property (nonatomic, assign) BOOL savedOrderLoaded;
/// Recent Calls: which diagnostics have already gone for a call, keyed by
/// "chatId:messageId" and kept in defaults so the row can say so after a
/// reopen. Sending a log twice is allowed; the row only records that one did.
@property (nonatomic, strong) NSMutableDictionary *callDiagnostics;
@property (nonatomic, assign) NSInteger recentCallsFilter;
/// The root page names what its rows are set to, the way Telegram's does:
/// the cache size under Data and Storage, the current device under Devices,
/// the pack name under Language and the proxy state under Proxy. They are
/// read once per open and stay empty until the client answers, so a slow
/// answer leaves the row as it was rather than a placeholder.
@property (nonatomic, assign) long long rootCacheBytes;
@property (nonatomic, assign) BOOL rootCacheLoaded;
@property (nonatomic, strong) NSString *rootDeviceName;
@property (nonatomic, assign) NSInteger rootSessionCount;
@property (nonatomic, strong) NSString *rootLanguageName;
@property (nonatomic, strong) NSString *rootProxyDetail;

+ (NSArray *)privacySettings;
+ (NSArray *)privacyTitles;

- (void)rebuild;
- (void)repaint;
- (void)applyTheme;
- (void)loadForPage;
- (void)openPage:(TGSettingsPage)page;
- (void)openMyProfile;
- (void)openMyProfileOnTab:(NSString *)tab;
- (void)openEditProfile;
- (void)openUsername;
- (void)openQRCode;
- (UIImage *)qrBarIcon;
- (void)openFAQ;
- (void)openTelegramTips;
- (void)showAccountChoices;
- (void)toast:(NSString *)text;
- (void)pushPlaceholder:(NSString *)featureName;
- (void)openURL:(NSString *)url;
- (void)openSavedMessages;
- (void)openChat:(int64_t)chatId title:(NSString *)title;
- (void)addProxyByAsking;
- (void)addChatToFolder:(NSInteger)folderId named:(NSString *)title;
- (void)removeChatFromFolder:(NSInteger)folderId named:(NSString *)title;
- (void)runFolderActionFor:(NSDictionary *)folder;
- (void)runProxyActionFor:(NSDictionary *)proxy;
- (void)checkProxy:(NSDictionary *)proxy named:(NSString *)name;
- (void)editProxyAddress:(NSDictionary *)proxy named:(NSString *)name;
- (void)askRecoveryEmailCodeFor:(NSString *)address;
- (void)runDownloadActionFor:(NSDictionary *)download;
- (void)showPremiumState;
- (void)runRecentCallActionFor:(NSDictionary *)call;
- (void)noteCallDiagnostic:(NSString *)kind forCall:(NSDictionary *)call;
- (void)showTwoStepState;
- (void)showLostPasswordFlow;
- (void)askPasswordRecoveryCodeFor:(NSString *)pattern;
- (void)askResetPassword;
- (void)showLoginEmailFlow;
- (void)askLoginEmailCodeFor:(NSString *)pattern;
- (void)showChangePhoneFlow;
- (void)showPhoneChangeCodeStep:(NSDictionary *)info;
- (void)showTemporaryPasswordFlow;
- (void)showVerifyEmailFlow;
- (void)askEmailVerificationCodeFor:(NSString *)pattern;
- (void)showApplicationVerification;
- (void)showFreezeState;
- (void)showSubscriptionState;
- (void)showAgeVerificationState;
- (void)showRecaptchaVerification;
- (void)askCurrentPasswordThen:(void (^)(NSString *current))next;
- (void)askNewPasswordReplacing:(NSString *)current;
- (void)commitPassword:(NSString *)new replacing:(NSString *)current hint:(NSString *)hint;
- (void)askTurnPasswordOff;
- (void)askRecoveryAddress;
- (void)askDeleteAccountNow;
- (void)openSupport;
- (void)askCountryCode;
- (void)showLanguagePackInfo;
- (void)showLanguagePackStrings;
- (void)readLanguagePackString;
- (void)createCustomLanguagePack;
- (void)editLanguagePackName;
- (void)setLanguagePackString;
- (void)deleteLanguagePackString;
- (void)installServerLanguagePack;
- (void)synchronizeCurrentLanguagePack;
- (void)deleteCurrentLanguagePack;
- (void)refreshLanguagePage;
- (void)askPrivacyRuleAtIndex:(NSUInteger)index;
- (void)showCloseFriends;
- (void)hideCloseBirthdays;
- (void)chooseAccentColorForProfile:(BOOL)profile;
- (void)showDefaultBackground;
- (void)chooseTextSize;
- (void)chooseWallpaper;
- (void)presentWallpaperPicker;
- (void)uploadProfilePhoto:(UIImage *)image;
- (void)pickProfilePhoto;
- (void)clearTemporaryFiles;
- (void)openResolvedChat:(int64_t)chatId title:(NSString *)title;

- (NSArray *)buildSections;
- (NSArray *)rootSections;
/// The one Settings row the Tier 2 hub hangs from. Built in
/// TGSettingsViewController+Tier2.m so the root list stays a list.
- (NSDictionary *)tier2ToolsRow;
- (NSArray *)appearanceSections;
- (NSArray *)chatThemesSections;
- (NSArray *)autoNightSections;
- (void)chooseAutoNightTimeFrom:(BOOL)from;
- (void)saveAutoNightTime;
- (NSArray *)dataSections;
- (NSArray *)notificationSections;
- (NSArray *)soundSections;
- (NSArray *)activeNotificationSections;
- (void)addSoundFromBundle;
- (void)addSoundFromDocuments;
- (void)addSavedSoundAtPath:(NSString *)path;
- (void)showSavedSound:(NSDictionary *)sound;
- (void)removeSavedSound:(NSDictionary *)sound;
- (void)removeNotificationRow:(NSDictionary *)notification
                      inGroup:(NSDictionary *)group;
- (void)removeNotificationGroup:(NSDictionary *)group;
- (NSArray *)privacySections;
- (NSArray *)passcodeSections;
- (NSArray *)languageSections;
- (NSArray *)blockedSections;
- (NSArray *)powerSavingSections;
- (NSArray *)recentCallSections;
- (NSArray *)paymentSections;
- (NSArray *)paymentDevSections;
- (void)showBankCardLookup;
- (void)addOfferFlow;
- (void)validateOrderFlow;
- (void)askOrderFieldAtIndex:(NSUInteger)index
						keys:(NSArray *)keys
					 prompts:(NSArray *)prompts
					  values:(NSMutableDictionary *)values
				   allowSave:(BOOL)allowSave;
- (void)runOrderValidation:(NSMutableDictionary *)values allowSave:(BOOL)allowSave;
- (NSArray *)debugSections;
- (NSArray *)folderSections;
- (NSArray *)proxySections;
- (NSArray *)downloadSections;
- (NSArray *)autosaveSections;
- (void)chooseAutoDownloadPreset;
- (NSString *)autoDownloadPresetSummary;
- (void)changeAutosaveScope:(NSString *)scope photos:(BOOL)photos videos:(BOOL)videos;
- (void)clearAutosaveExceptions;
- (void)autosaveSettingsChanged;
- (void)languagePackStringsChanged:(NSString *)packId;

@end

#endif // TGSETTINGSVIEWCONTROLLERINTERNAL_H
