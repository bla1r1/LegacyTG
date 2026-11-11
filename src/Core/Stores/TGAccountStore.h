//
// TGAccountStore.h - the account record, its sign-in and its people.
//
// Sessions, usernames, websites, support, imported contacts, two-step
// verification, the account slots and the state a settings row reads.
//
// The store is the seam a settings screen talks to. The request bodies live
// here, not in the view: a screen names what it wants and the store builds the
// TDLib object. Reads that only expose the client's account cache are kept
// here too, so a screen never imports TGClient or one of its duty headers.
//
#import <Foundation/Foundation.h>
#import "TGClientTypes.h"
#import "TGClientNotifications.h"

/// The per-account defaults key for `base`: the name is unchanged for slot 0
/// and gains `-N` for slot N, so one account's value is never read as
/// another's. The screens that store a per-account setting call this instead
/// of reaching into the client.
FOUNDATION_EXPORT NSString *TGAccountStoreDefaultsKey(NSString *base);

@interface TGAccountStore : NSObject

+ (instancetype)shared;

@end

@interface TGAccountStore (State)
#pragma mark - account state

@property (nonatomic, readonly) TGAuthState authState;
@property (nonatomic, readonly) int64_t ownedStarCount;
/// Telegram's freeze, age-verification and recaptcha records, empty until
/// the server sends them. The three pages that show them read these.
@property (nonatomic, readonly) NSDictionary *freezeState;
@property (nonatomic, readonly) NSDictionary *ageVerificationParameters;
@property (nonatomic, readonly) NSDictionary *recaptchaVerificationRequest;
/// The application-verification request the update named, and its nonce.
@property (nonatomic, readonly) int64_t pendingApplicationVerificationId;
@property (nonatomic, readonly) NSString *pendingApplicationVerificationNonce;

/// The subscription record the account holds for a user, or nil.
- (NSDictionary *)subscriptionForUserId:(int64_t)userId;

/// The signed-in account's own username, changed from the username page.
- (void)setUsername:(NSString *)username completion:(void (^)(BOOL ok))completion;
@end


#pragma mark - Auth
@interface TGAccountStore (Auth)

	/// What authorizationStateWaitCode carries.
	@property (nonatomic, readonly) NSDictionary *codeInfo;
	/// From authorizationStateWaitPassword.
	@property (nonatomic, readonly) NSDictionary *loginPasswordInfo;
	/// From authorizationStateWaitEmailCode.
	@property (nonatomic, readonly) NSDictionary *emailCodeInfo;


	- (void)hasPasswordWithCompletion:(void (^)(BOOL hasPassword, NSString *recoveryEmail))completion;
	- (void)sendPhoneNumber:(NSString *)phoneNumber;
	- (void)sendCode:(NSString *)code;
	- (void)sendPassword:(NSString *)password;
	- (void)resendAuthenticationCode;
	- (void)requestQrCodeAuthentication;
	- (void)registerWithFirstName:(NSString *)firstName lastName:(NSString *)lastName completion:(void (^)(BOOL ok, NSString *error))completion;
	- (NSString *)registrationTerms;
	- (void)countriesWithCompletion:(void (^)(NSArray *countries))completion;
	- (void)countryCodeWithCompletion:(void (^)(NSString *code))completion;
	- (void)registerPushToken:(NSString *)token sandbox:(BOOL)sandbox completion:(void (^)(BOOL ok))completion;
	- (void)processPushPayload:(NSDictionary *)payload;
	- (void)pushReceiverOfPayload:(NSDictionary *)payload completion:(void (^)(BOOL ok, int64_t receiverId))completion;
	- (void)acceptTermsOfService:(NSString *)termsId completion:(void (^)(BOOL ok))completion;
	- (void)destroySession;
	- (void)logOut;
	- (void)sendEmailAddress:(NSString *)email;
	- (void)sendEmailCode:(NSString *)code;
	- (void)resetAuthenticationEmailAddress;
	- (void)reportAuthenticationCodeMissing;
	- (void)requestPasswordRecoveryWithCompletion:(void (^)(NSString *error))completion;
	- (void)recoverPasswordWithCode:(NSString *)code completion:(void (^)(NSString *error))completion;
	- (void)loginEmailAddressRequiredWithCompletion: (void (^)(BOOL required, NSString *error))completion;
	- (void)setLoginEmailAddress:(NSString *)email completion:(void (^)(NSString *pattern, NSString *error))completion;
	- (void)resendLoginEmailAddressCodeWithCompletion: (void (^)(NSString *pattern, NSString *error))completion;
	- (void)checkLoginEmailAddressCode:(NSString *)code completion:(void (^)(NSString *error))completion;
	- (void)checkAuthenticationWebToken:(NSString *)token dcId:(NSInteger)dcId completion:(void (^)(NSString *error))completion;
	- (void)dismissWebToken:(NSString *)token completion:(void (^)(NSString *error))completion;
	- (void)confirmQrCodeAuthenticationLink:(NSString *)link completion:(void (^)(NSString *error))completion;
	- (void)searchUserByToken:(NSString *)token completion:(void (^)(NSDictionary *user, NSString *error))completion;
	- (void)phoneNumberInfoForPrefix:(NSString *)prefix completion:(void (^)(NSDictionary *info))completion;
	- (NSDictionary *)phoneNumberInfoForPrefixSync:(NSString *)prefix;
	- (void)sendPhoneNumberChangeCode:(NSString *)phoneNumber completion:(void (^)(NSDictionary *info, NSString *error))completion;
	- (void)checkPhoneNumberChangeCode:(NSString *)code completion:(void (^)(NSString *error))completion;
	- (void)resendPhoneNumberChangeCodeWithCompletion: (void (^)(NSDictionary *info, NSString *error))completion;
	- (void)reportPhoneNumberCodeMissingWithCompletion: (void (^)(NSString *error))completion;
	- (void)sendAuthenticationFirebaseSms:(NSString *)token completion:(void (^)(NSString *error))completion;
	- (void)sendPhoneNumberFirebaseSms:(NSString *)token completion:(void (^)(NSString *error))completion;
	- (void)requestAccountPasswordRecoveryWithCompletion: (void (^)(NSString *pattern, NSString *error))completion;
	- (void)checkAccountPasswordRecoveryCode:(NSString *)code completion:(void (^)(NSString *error))completion;
	- (void)recoverAccountPasswordWithCode:(NSString *)code newPassword:(NSString *)password hint:(NSString *)hint completion:(void (^)(NSDictionary *state, NSString *error))completion;
	- (void)resetAccountPasswordWithCompletion: (void (^)(NSString *result, double date, NSString *error))completion;
	- (void)cancelAccountPasswordResetWithCompletion: (void (^)(NSString *error))completion;
	- (void)temporaryPasswordStateWithCompletion: (void (^)(BOOL has, NSInteger validFor, NSString *error))completion;
	- (void)createTemporaryPassword:(NSString *)password validFor:(NSInteger)seconds completion:(void (^)(BOOL has, NSInteger validFor, NSString *error))completion;
	- (void)deleteSavedCredentialsWithCompletion: (void (^)(NSString *error))completion;
	- (void)cancelRecoveryEmailAddressVerificationWithCompletion: (void (^)(NSDictionary *state, NSString *error))completion;
	- (void)sendEmailAddressVerificationCodeTo:(NSString *)email completion:(void (^)(NSString *pattern, NSString *error))completion;
	- (void)resendEmailAddressVerificationCodeWithCompletion: (void (^)(NSString *pattern, NSString *error))completion;
	- (void)checkEmailAddressVerificationCode:(NSString *)code completion:(void (^)(NSString *error))completion;
	- (void)canTransferOwnershipWithCompletion: (void (^)(NSString *result, NSInteger retryAfter, NSString *error))completion;
	- (void)noteApplicationVerificationWithId:(int64_t)verificationId nonce:(NSString *)nonce;
	- (void)setApplicationVerificationToken:(NSString *)token verificationId:(int64_t)verificationId completion:(void (^)(NSString *error))completion;
@end


#pragma mark - Accounts
@interface TGAccountStore (Accounts)

	+ (NSInteger)activeAccountSlot;
	+ (NSArray *)accountSlots;
	+ (NSInteger)addAccount;
	- (void)switchToAccountSlot:(NSInteger)slot;
	- (void)resetStateForAccountSwitch;
	- (void)recordActiveAccountFromMe:(NSDictionary *)me;
@end


#pragma mark - People
@interface TGAccountStore (People)

	- (void)setUser:(int64_t)userId blocked:(BOOL)blocked;
	- (void)setUser:(int64_t)userId blocked:(BOOL)blocked completion:(void (^)(BOOL ok))completion;
	- (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL blocked))completion;
	- (void)giftsForUser:(int64_t)userId completion:(void (^)(NSArray *gifts))completion;
	- (void)giftsForOwner:(NSDictionary *)ownerId offset:(NSString *)offset completion:(void (^)(NSArray *gifts, NSString *nextOffset, NSInteger totalCount))completion;
	- (void)premiumStateWithCompletion:(void (^)(NSString *summary))completion;
@end


#pragma mark - TwoStep
@interface TGAccountStore (TwoStep)

	- (void)setPassword:(NSString *)oldPassword new:(NSString *)newPassword hint:(NSString *)hint setEmailAddress:(BOOL)setEmailAddress email:(NSString *)recoveryEmail completion:(void (^)(BOOL ok))completion;
	- (void)recoveryEmailAddress:(NSString *)password completion:(void (^)(NSString *email))completion;
	- (void)recoveryEmailAddress:(NSString *)password completionWithError:(void (^)(NSString *email, NSString *error))completion;
	- (void)setRecoveryEmailAddress:(NSString *)password to:(NSString *)email completion:(void (^)(BOOL ok))completion;
@end


#pragma mark - Usernames
@interface TGAccountStore (Usernames)

	- (void)accountUsernamesWithCompletion:(void (^)(NSDictionary *usernames))completion;
	- (void)toggleUsernameIsActive:(NSString *)username isActive:(BOOL)isActive completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)reorderActiveUsernames:(NSArray *)usernames completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)supergroupSettingsForChat:(int64_t)chatId completion:(void (^)(NSDictionary *settings))completion;
	- (void)setSupergroupUsername:(NSString *)username inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)toggleSupergroupUsernameIsActive:(NSString *)username inChat:(int64_t)chatId isActive:(BOOL)isActive completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)reorderSupergroupActiveUsernames:(NSArray *)usernames inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)disableAllSupergroupUsernamesInChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)setSupergroupForumInChat:(int64_t)chatId on:(BOOL)on completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)setSupergroupJoinByRequestInChat:(int64_t)chatId on:(BOOL)on guardBotUserId:(int64_t)guardBotUserId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)setSupergroupHiddenMembersInChat:(int64_t)chatId on:(BOOL)on completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)convertSupergroupToBroadcastInChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)setSupergroupAutomaticTranslationInChat:(int64_t)chatId on:(BOOL)on completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)setSupergroupMainProfileTab:(NSString *)tab inChat:(int64_t)chatId completion:(void (^)(BOOL ok, NSString *error))completion;
	+ (NSDictionary *)administratorRightsForPreset:(NSString *)preset;
	- (void)setDefaultGroupAdministratorRightsPreset:(NSString *)preset completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)setDefaultChannelAdministratorRightsPreset:(NSString *)preset completion:(void (^)(BOOL ok, NSString *error))completion;
@end


#pragma mark - Websites
@interface TGAccountStore (Websites)

	- (void)connectedWebsitesWithCompletion:(void (^)(NSArray *sites, NSString *error))completion;
	- (void)disconnectWebsite:(int64_t)websiteId completion:(void (^)(BOOL ok, NSString *error))completion;
	- (void)disconnectAllWebsitesWithCompletion:(void (^)(BOOL ok, NSString *error))completion;
@end


#pragma mark - Support
@interface TGAccountStore (Support)

	- (void)supportNameWithCompletion:(void (^)(NSString *name, NSString *error))completion;
	- (void)supportInfoForUser:(int64_t)userId completion:(void (^)(NSDictionary *info, NSString *error))completion;
	- (void)setSupportInfo:(NSString *)message forUser:(int64_t)userId completion:(void (^)(NSDictionary *info, NSString *error))completion;
@end


#pragma mark - Contacts
@interface TGAccountStore (Contacts)

	- (void)contactsWithCompletion:(void (^)(NSArray *users))completion;
	- (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion;
	- (void)userForPhone:(NSString *)phone completion:(void (^)(NSDictionary *user))completion;
@end
