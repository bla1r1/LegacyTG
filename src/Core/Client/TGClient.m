#import "TGGhostMode.h"
#import "TGClientInternal.h"
#import "TGTransport.h"
#import "TGUpdateRouter.h"
#import "TGAccountSession.h"
#import "TGState.h"
#import "TGUpdateHandlers.h"
#import "TGBase64.h"
#import "TGDatabaseKey.h"
#import "TGOptions.h"
#import "TGCall.h"
#import "TGJson.h"
#include "TGUpdateType.h"
#include <dlfcn.h>
#include "api_id.h"

/// The saved-chat row rule lives beside mergeChat in TGClient+Chats.mm.
@interface TGClient (SavedMessagesRow)
- (void)markSavedMessagesRow;
@end

/// The plain string a folder is named with. tdlib nests the name two levels
/// deep: chatFolderInfo.name is a chatFolderName whose "text" is itself a
/// formattedText, and only THAT "text" is the string. The old chain stopped
/// one level short (B3 - every folder parsed as an empty string), and the
/// pill strip had three nameless tabs to show for it.
NSString *TGPlainTitle(id value){
	while ([value isKindOfClass:NSDictionary.class])
		value = value[@"text"];
	return [value isKindOfClass:NSString.class] ? value : nil;
}

NSString *const TGChatReadOutboxChangedNotification = @"TGChatReadOutboxChangedNotification";
NSString *const TGMessageSendStateChangedNotification = @"TGMessageSendStateChangedNotification";
NSString *const TGChatsChangedNotification = @"TGChatsChangedNotification";
NSString *const TGChatReplyMarkupChangedNotification = @"TGChatReplyMarkupChangedNotification";
NSString *const TGConnectionStateChangedNotification = @"TGConnectionStateChangedNotification";
NSString *const TGUserStatusChangedNotification = @"TGUserStatusChangedNotification";
NSString *const TGInAppNotificationReceivedNotification = @"TGInAppNotificationReceivedNotification";
NSString *const TGUnreadTotalChangedNotification = @"TGUnreadTotalChangedNotification";
NSString *const TGDownloadsChangedNotification = @"TGDownloadsChangedNotification";
NSString *const TGFullInfoChangedNotification = @"TGFullInfoChangedNotification";
NSString *const TGStickerListsChangedNotification = @"TGStickerListsChangedNotification";
NSString *const TGChatMembersChangedNotification = @"TGChatMembersChangedNotification";
NSString *const TGNotificationSettingsChangedNotification = @"TGNotificationSettingsChangedNotification";
NSString *const TGForumTopicsChangedNotification = @"TGForumTopicsChangedNotification";
NSString *const TGTextCompositionStylesChangedNotification = @"TGTextCompositionStylesChangedNotification";
NSString *const TGDirectMessagesTopicsChangedNotification = @"TGDirectMessagesTopicsChangedNotification";
NSString *const TGStakeDiceStateChangedNotification = @"TGStakeDiceStateChangedNotification";
NSString *const TGApplicationVerificationRequiredNotification = @"TGApplicationVerificationRequiredNotification";
NSString *const TGChatActionBarChangedNotification = @"TGChatActionBarChangedNotification";
NSString *const TGSavedTopicsChangedNotification = @"TGSavedTopicsChangedNotification";
NSString *const TGServiceNotificationReceivedNotification = @"TGServiceNotificationReceivedNotification";
NSString *const TGTermsOfServiceReceivedNotification = @"TGTermsOfServiceReceivedNotification";
NSString *const TGPrivacyRulesChangedNotification = @"TGPrivacyRulesChangedNotification";
NSString *const TGSessionsChangedNotification = @"TGSessionsChangedNotification";
NSString *const TGAccentColorsChangedNotification = @"TGAccentColorsChangedNotification";
NSString *const TGContactCloseBirthdaysChangedNotification = @"TGContactCloseBirthdaysChangedNotification";
NSString *const TGAccountStatusChangedNotification = @"TGAccountStatusChangedNotification";
NSString *const TGAppearanceDefaultsChangedNotification = @"TGAppearanceDefaultsChangedNotification";
NSString *const TGMessageEffectsChangedNotification = @"TGMessageEffectsChangedNotification";
NSString *const TGChatDraftStoppedNotification = @"TGChatDraftStoppedNotification";
NSString *const TGChatVideoPublishedNotification = @"TGChatVideoPublishedNotification";
NSString *const TGActiveNotificationsChangedNotification = @"TGActiveNotificationsChangedNotification";
NSString *const TGAutosaveSettingsChangedNotification = @"TGAutosaveSettingsChangedNotification";
NSString *const TGLanguagePackStringsChangedNotification = @"TGLanguagePackStringsChangedNotification";
NSString *const TGCommunitiesChangedNotification = @"TGCommunitiesChangedNotification";
NSString *const TGStoriesChangedNotification = @"TGStoriesChangedNotification";
NSString *const TGStoryPostFinishedNotification = @"TGStoryPostFinishedNotification";
NSString *const TGChatRevenueChangedNotification = @"TGChatRevenueChangedNotification";
NSString *const TGStarRevenueChangedNotification = @"TGStarRevenueChangedNotification";
NSString *const TGQuickRepliesChangedNotification = @"TGQuickRepliesChangedNotification";
NSString *const TGSuggestedActionsChangedNotification = @"TGSuggestedActionsChangedNotification";

@implementation TGClient


- (TGAuthState)authState { return [TGAccountSession shared].authState; }
- (void)setAuthState:(TGAuthState)value { [TGAccountSession shared].authState = value; }
- (NSTimeInterval)readyAt { return [TGAccountSession shared].readyAt; }
- (void)setReadyAt:(NSTimeInterval)value { [TGAccountSession shared].readyAt = value; }
- (NSString *)registrationTermsText { return [TGAccountSession shared].registrationTermsText; }
- (void)setRegistrationTermsText:(NSString *)value { [TGAccountSession shared].registrationTermsText = value; }
- (NSDictionary *)codeInfo { return [TGAccountSession shared].codeInfo; }
- (void)setCodeInfo:(NSDictionary *)value { [TGAccountSession shared].codeInfo = value; }
- (NSDictionary *)loginPasswordInfo { return [TGAccountSession shared].loginPasswordInfo; }
- (void)setLoginPasswordInfo:(NSDictionary *)value { [TGAccountSession shared].loginPasswordInfo = value; }
- (NSDictionary *)emailCodeInfo { return [TGAccountSession shared].emailCodeInfo; }
- (void)setEmailCodeInfo:(NSDictionary *)value { [TGAccountSession shared].emailCodeInfo = value; }
- (NSString *)qrCodeLink { return [TGAccountSession shared].qrCodeLink; }
- (void)setQrCodeLink:(NSString *)value { [TGAccountSession shared].qrCodeLink = value; }
- (NSString *)pendingPhoneNumber { return [TGAccountSession shared].pendingPhoneNumber; }
- (void)setPendingPhoneNumber:(NSString *)value { [TGAccountSession shared].pendingPhoneNumber = value; }
- (NSDictionary *)recaptchaVerificationRequestValue { return [TGAccountSession shared].recaptchaVerificationRequestValue; }
- (void)setRecaptchaVerificationRequestValue:(NSDictionary *)value { [TGAccountSession shared].recaptchaVerificationRequestValue = value; }
- (BOOL)pausing { return [TGAccountSession shared].pausing; }
- (void)setPausing:(BOOL)value { [TGAccountSession shared].pausing = value; }
- (BOOL)paused { return [TGAccountSession shared].paused; }
- (void)setPaused:(BOOL)value { [TGAccountSession shared].paused = value; }
- (BOOL)resumeWanted { return [TGAccountSession shared].resumeWanted; }
- (void)setResumeWanted:(BOOL)value { [TGAccountSession shared].resumeWanted = value; }
- (void (^)(void))pauseDone { return [TGAccountSession shared].pauseDone; }
- (void)setPauseDone:(void (^)(void))value { [TGAccountSession shared].pauseDone = value; }

- (TGUpdateCoalescer *)updateCoalescer { return [TGUpdateRouter shared].coalescer; }
- (BOOL)batchingUpdates { return [TGUpdateRouter shared].batchingUpdates; }
- (void)setBatchingUpdates:(BOOL)value { [TGUpdateRouter shared].batchingUpdates = value; }
- (BOOL)chatsNeedRebuild { return [TGUpdateRouter shared].chatsNeedRebuild; }
- (void)setChatsNeedRebuild:(BOOL)value { [TGUpdateRouter shared].chatsNeedRebuild = value; }
- (NSMutableDictionary *)chatsById { return [TGState shared].chatsById; }
- (void)setChatsById:(NSMutableDictionary *)value { [TGState shared].chatsById = value; }
- (NSMutableDictionary *)usersById { return [TGState shared].usersById; }
- (void)setUsersById:(NSMutableDictionary *)value { [TGState shared].usersById = value; }
- (TGObjectLruCache *)rawUsersById { return [TGState shared].rawUsersById; }
- (void)setRawUsersById:(TGObjectLruCache *)value { [TGState shared].rawUsersById = value; }
- (NSMutableDictionary *)userPhotosById { return [TGState shared].userPhotosById; }
- (void)setUserPhotosById:(NSMutableDictionary *)value { [TGState shared].userPhotosById = value; }
- (NSMutableDictionary *)forumSupergroups { return [TGState shared].forumSupergroups; }
- (void)setForumSupergroups:(NSMutableDictionary *)value { [TGState shared].forumSupergroups = value; }
- (NSArray *)archivedChats { return [TGState shared].archivedChats; }
- (void)setArchivedChats:(NSArray *)value { [TGState shared].archivedChats = value; }
- (NSMutableDictionary *)savedTopicsById { return [TGState shared].savedTopicsById; }
- (void)setSavedTopicsById:(NSMutableDictionary *)value { [TGState shared].savedTopicsById = value; }
- (NSArray *)folders { return [TGState shared].folders; }
- (void)setFolders:(NSArray *)value { [TGState shared].folders = value; }
- (NSDictionary *)archiveSettings { return [TGState shared].archiveSettings; }
- (void)setArchiveSettings:(NSDictionary *)value { [TGState shared].archiveSettings = value; }
- (NSArray *)chats { return [TGState shared].chats; }
- (void)setChats:(NSArray *)value { [TGState shared].chats = value; }
- (NSDictionary *)me { return [TGState shared].me; }
- (void)setMe:(NSDictionary *)value { [TGState shared].me = value; }
- (NSArray *)accentColorIds { return [TGState shared].accentColorIds; }
- (void)setAccentColorIds:(NSArray *)value { [TGState shared].accentColorIds = value; }
- (NSArray *)profileAccentColorIds { return [TGState shared].profileAccentColorIds; }
- (void)setProfileAccentColorIds:(NSArray *)value { [TGState shared].profileAccentColorIds = value; }
- (NSArray *)accentColors { return [TGState shared].accentColors; }
- (void)setAccentColors:(NSArray *)value { [TGState shared].accentColors = value; }
- (NSArray *)profileAccentColors { return [TGState shared].profileAccentColors; }
- (void)setProfileAccentColors:(NSArray *)value { [TGState shared].profileAccentColors = value; }
- (NSMutableDictionary *)userSubscriptionsById { return [TGState shared].userSubscriptionsById; }
- (void)setUserSubscriptionsById:(NSMutableDictionary *)value { [TGState shared].userSubscriptionsById = value; }
- (NSMutableDictionary *)noteSendWaiters { return [TGState shared].noteSendWaiters; }
- (void)setNoteSendWaiters:(NSMutableDictionary *)value { [TGState shared].noteSendWaiters = value; }
- (NSMutableDictionary *)communitiesById { return [TGState shared].communitiesById; }
- (void)setCommunitiesById:(NSMutableDictionary *)value { [TGState shared].communitiesById = value; }
- (NSMutableArray *)communityOrder { return [TGState shared].communityOrder; }
- (void)setCommunityOrder:(NSMutableArray *)value { [TGState shared].communityOrder = value; }
- (NSMutableDictionary *)communityFullInfoById { return [TGState shared].communityFullInfoById; }
- (void)setCommunityFullInfoById:(NSMutableDictionary *)value { [TGState shared].communityFullInfoById = value; }
- (NSMutableDictionary *)quickReplyShortcutsById { return [TGState shared].quickReplyShortcutsById; }
- (void)setQuickReplyShortcutsById:(NSMutableDictionary *)value { [TGState shared].quickReplyShortcutsById = value; }
- (NSMutableArray *)quickReplyShortcutOrder { return [TGState shared].quickReplyShortcutOrder; }
- (void)setQuickReplyShortcutOrder:(NSMutableArray *)value { [TGState shared].quickReplyShortcutOrder = value; }
- (NSMutableDictionary *)quickReplyMessagesByShortcut { return [TGState shared].quickReplyMessagesByShortcut; }
- (void)setQuickReplyMessagesByShortcut:(NSMutableDictionary *)value { [TGState shared].quickReplyMessagesByShortcut = value; }
- (NSMutableDictionary *)directMessagesTopicsByChat { return [TGState shared].directMessagesTopicsByChat; }
- (void)setDirectMessagesTopicsByChat:(NSMutableDictionary *)value { [TGState shared].directMessagesTopicsByChat = value; }
- (NSMutableDictionary *)checklistCache { return [TGState shared].checklistCache; }
- (void)setChecklistCache:(NSMutableDictionary *)value { [TGState shared].checklistCache = value; }
- (NSMutableDictionary *)chatRevenueAmountByChat { return [TGState shared].chatRevenueAmountByChat; }
- (void)setChatRevenueAmountByChat:(NSMutableDictionary *)value { [TGState shared].chatRevenueAmountByChat = value; }
- (NSMutableDictionary *)starRevenueStatusByOwner { return [TGState shared].starRevenueStatusByOwner; }
- (void)setStarRevenueStatusByOwner:(NSMutableDictionary *)value { [TGState shared].starRevenueStatusByOwner = value; }

- (NSMutableArray *)outbox { return [TGTransport shared].outbox; }
- (NSMutableDictionary *)pendingRequests { return [TGTransport shared].pendingRequests; }
- (BOOL)available { return [TGTransport shared].available; }
- (BOOL)running { return [TGTransport shared].running; }

- (void)chatsChanged {
	if (self.onChatsChanged)
		self.onChatsChanged();
	[[NSNotificationCenter defaultCenter] postNotificationName:TGChatsChangedNotification object:nil];
}

- (NSUInteger)chatsCached {
	return self.chatsById.count;
}

/// The update's emoji, or nil while it has not arrived; the picker keeps its
/// own order then.
- (NSString *)defaultReactionEmoji {
	return self.reactionDefaultEmoji;
}

/// "gif" is the provider every client ships with, and the one the update
/// starts from until Telegram names another.
- (NSString *)animationSearchProvider {
	return self.gifSearchProvider ?: @"gif";
}

- (NSArray *)animationSearchEmojis {
	return self.gifSearchEmojis ?: @[];
}

// The public account-status surface reads the records handleUpdate keeps.
// Each one is nil or empty until its update arrives, never a made-up default:
// the Settings rows have to distinguish "Telegram says none" from "not told".
- (NSDictionary *)freezeState {
	return self.freezeStateValue;
}

- (NSDictionary *)ageVerificationParameters {
	return self.ageVerificationParametersValue;
}

- (NSDictionary *)recaptchaVerificationRequest {
	return self.recaptchaVerificationRequestValue;
}

- (NSDictionary *)subscriptionForUserId:(int64_t)userId {
	id row = self.userSubscriptionsById[@(userId)];
	return [row isKindOfClass:NSDictionary.class] ? row : nil;
}

- (NSArray *)availableMessageEffectIds {
	return self.reactionMessageEffectIds ?: @[];
}

- (NSArray *)availableStickerEffectIds {
	return self.stickerMessageEffectIds ?: @[];
}

- (NSDictionary *)defaultBackground {
	return self.defaultBackgroundValue;
}

- (NSArray *)emojiChatThemes {
	return self.emojiChatThemesValue ?: @[];
}

- (NSDictionary *)stoppedMessageDraft {
	return self.stoppedMessageDraftValue;
}

- (NSDictionary *)publishedVideo {
	return self.publishedVideoValue;
}

// The Saved Messages topics, array-shaped the way the screen reads them:
// pinned rows first, the rest newest activity on top.
- (NSArray *)savedTopics {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *row in self.savedTopicsById.allValues)
		[out addObject:row];
	return [out sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
		BOOL pa = [a[@"pinned"] boolValue], pb = [b[@"pinned"] boolValue];
		if (pa != pb)
			return pa ? NSOrderedAscending : NSOrderedDescending;
		id da = a[@"date"], db = b[@"date"];
		long long ta = da ? [da longLongValue] : 0;
		long long tb = db ? [db longLongValue] : 0;
		if (tb > ta)
			return NSOrderedAscending;
		if (tb < ta)
			return NSOrderedDescending;
		return NSOrderedSame;
	}];
}

+ (instancetype)shared {
	static TGClient *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		s = [[TGClient alloc] init];
		__weak TGClient *weakClient = s;
		[TGUpdateRouter shared].onUpdate = ^(NSDictionary *obj){
			[weakClient handleUpdate:obj];
		};
		[TGUpdateRouter shared].onChatsRebuilt = ^{
			[weakClient rebuildChats];
		};
		[TGUpdateRouter shared].onMessageNudged = ^(int64_t chatId){
			TGClient *client = weakClient;
			if (client.onMessage)
				client.onMessage(chatId, nil, 0);
		};
		[TGAccountSession shared].isRunning = ^BOOL{
			return weakClient.running;
		};
		[TGAccountSession shared].onCloseRequested = ^{
			[weakClient send:@{@"@type" : @"close"}];
		};
		[TGAccountSession shared].onRestartRequested = ^{
			TGClient *client = weakClient;
			// A new TDLib instance sends chat positions only for lists asked
			// for again.
			client.chatListComplete = NO;
			client.loadChatsAttempts = 0;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[client start];
			});
		};
	});
	return s;
}

#pragma mark - lifecycle

- (BOOL)start {
	if ([TGTransport shared].running)
		return [TGTransport shared].available;

	TGTransport *transport = [TGTransport shared];
	__weak TGClient *weakSelf = self;
	transport.onUpdateBatch = ^(NSArray *batch){
		[[TGUpdateRouter shared] routeBatch:batch];
	};
	transport.onClosed = ^{
		[weakSelf clientClosed];
	};
	if (![transport start])
		return NO;

	// The single-threaded ClientManager creates its scheduler lazily, on the
	// first request - without this nothing ever runs and no update arrives.
	[self send:@{@"@type" : @"getAuthorizationState"}];

	// TDLib refuses every language-pack call until a localization target is
	// named, and this client's only target is the one iOS packs carry.
	[self send:@{@"@type" : @"setOption",
				@"name" : @"localization_target",
				@"value" : @{@"@type" : @"optionValueString", @"value" : @"ios"}}];
	return YES;
}



#pragma mark - background

- (void)pauseForBackground:(void (^)(void))done {
	[[TGAccountSession shared] pauseForBackground:done];
}



- (void)resumeFromBackground {
	[[TGAccountSession shared] resumeFromBackground];
}



- (void)clientClosed {
	[[TGAccountSession shared] clientClosed];
}



#pragma mark - sending

// The single-threaded ClientManager requires send and receive on the SAME
// thread: sending from elsewhere while the receive loop holds the scheduler
// guard aborts on `Scheduler.cpp:126 Check !scheduler_->has_guard_ failed`.
// So callers only enqueue here, and the receive thread does the sending.
- (void)send:(NSDictionary *)request {
	[[TGTransport shared] send:request];
}



/// Runs on the receive thread only.
- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *))completion {
	[[TGTransport shared] request:request completion:completion];
}



/// The synchronous half of td_api: a few functions answer on the spot, with
/// no client and no round trip. nil when the dylib has no execute symbol,
/// which is also how the host tests see it.
- (NSDictionary *)executeSynchronously:(NSDictionary *)request {
	return [[TGTransport shared] executeSynchronously:request];
}



/// What goes into an inputMessageText. Bold, italic, code and links are
/// written the way Telegram Desktop writes them - *bold*, _italic_, `code` -
/// and read back out here, because a UITextField on this OS has no way to
/// mark up a selection.
///
/// Markup that does not pair up is left alone: a lone asterisk is an
/// asterisk. When the parse is not available at all the text is sent as
/// written, which is what this app did for every message until now.
NSDictionary *TGFormattedText(NSString *text) {
	NSDictionary *plain = @{@"@type" : @"formattedText",
							@"text"  : text ?: @"",
							@"entities" : @[]};
	if (!text.length)
		return plain;

	NSDictionary *parsed = [[TGClient shared] executeSynchronously:@{
		@"@type" : @"parseTextEntities",
		@"text"  : text,
		@"parse_mode" : @{@"@type" : @"textParseModeMarkdown",
						  // Version 2 is the one that needs every reserved
						  // character escaped; version 1 is what people type.
						  @"version" : @(1)},
	}];
	if (![parsed[@"@type"] isEqualToString:@"formattedText"])
		return plain;
	return parsed;
}

#pragma mark - updates

- (void)handleUpdate:(NSDictionary *)obj {
	if ([[TGUpdateRouter shared] deliverResponse:obj])
		return;
	[TGUpdateHandlers shared].client = self;
	[[TGUpdateHandlers shared] handleUpdate:obj];
}

/// With no coalescer the rebuild stays immediate, so nothing silently waits
/// on a main-queue timer that may never fire.
- (void)markChatRowDirty:(int64_t)chatId {
	if (self.updateCoalescer)
		[self.updateCoalescer markChatDirty:chatId];
	else
		[self rebuildChats];
}

- (void)handleAuthState:(NSDictionary *)state {
	NSString *type = state[@"@type"];
	NSLog(@"TGClient: <<< AUTH STATE: %@ details: %@", type, state);

	TGAuthState s = TGAuthStateUnknown;

	if ([type isEqualToString:@"authorizationStateWaitTdlibParameters"]){
		[self sendTdlibParameters];
		return;                       // not a user-visible state
	} else if ([type isEqualToString:@"authorizationStateWaitPhoneNumber"]){
		s = TGAuthStateWaitPhoneNumber;
	} else if ([type isEqualToString:@"authorizationStateWaitCode"]){
		s = TGAuthStateWaitCode;
		self.codeInfo = state[@"code_info"];
	} else if ([type isEqualToString:@"authorizationStateWaitPassword"]){
		s = TGAuthStateWaitPassword;
		self.loginPasswordInfo = state;
	} else if ([type isEqualToString:@"authorizationStateWaitEmailAddress"]){
		// These two fell through to "not a user-visible state": a number
		// Telegram wants an email for sat on the phone step for good.
		s = TGAuthStateWaitEmailAddress;
	} else if ([type isEqualToString:@"authorizationStateWaitEmailCode"]){
		s = TGAuthStateWaitEmailCode;
		self.emailCodeInfo = state;
	} else if ([type isEqualToString:@"authorizationStateWaitRegistration"]){
		s = TGAuthStateWaitRegistration;
		// The terms come with the state and nowhere else; a screen that has
		// to show them before making an account cannot ask for them later.
		self.registrationTermsText = state[@"terms_of_service"][@"text"][@"text"];
	} else if ([type isEqualToString:@"authorizationStateWaitOtherDeviceConfirmation"]){
		s = TGAuthStateWaitOtherDeviceConfirmation;
		self.qrCodeLink = state[@"link"];
	} else if ([type isEqualToString:@"authorizationStateReady"]){
		s = TGAuthStateReady;
	} else if ([type isEqualToString:@"authorizationStateLoggingOut"]){
		s = TGAuthStateLoggingOut;
	} else if ([type isEqualToString:@"authorizationStateClosed"]){
		[[TGTransport shared] markClosed];
		if (self.pausing)
			return;                   // our own close for the background
		s = TGAuthStateClosed;
	} else {
		return;                       // encryption-key states etc.
	}

	self.authState = s;
	if (s == TGAuthStateReady){
		self.readyAt = [NSDate date].timeIntervalSince1970;
		[self loadChats];
		[self send:@{@"@type" : @"getMe"}];
	}
	if (s == TGAuthStateWaitPhoneNumber)
		[self flushPendingPhoneNumber];
	if (self.onAuthState)
		self.onAuthState(s);
}

- (void)sendTdlibParameters {
	NSString *docs = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	// Each account's database lives in its own directory so switching never
	// opens another account's files; slot 0 keeps the pre-accounts path.
	NSString *db = TGAccountDatabaseDirectory(docs, [TGClient activeAccountSlot]);

	int SETUP_API_ID(apiId)
	char * SETUP_API_HASH(apiHash)

	UIDevice *dev = [UIDevice currentDevice];

	// The key this app set through Debug Menu, if any. An empty string is
	// TDLib's unencrypted database, which is how every install starts.
	NSData *databaseKey = [TGDatabaseKey currentKey];

	[self send:@{
		@"@type"                  : @"setTdlibParameters",
		@"database_directory"     : db,
		@"files_directory"        : [db stringByAppendingPathComponent:@"files"],
		@"database_encryption_key": TGBase64Encode(databaseKey),
		@"use_message_database"   : @YES,
		// Chat rows and downloaded files have to survive a launch, or every
		// start is a cold sync: the list, avatars and media are fetched again.
		@"use_chat_info_database" : @YES,
		@"use_file_database"      : @YES,
		@"use_secret_chats"       : @NO,
		@"api_id"                 : @(apiId),
		@"api_hash"               : [NSString stringWithUTF8String:apiHash],
		@"system_language_code"   : @"en",
		@"device_model"           : dev.model ?: @"iPhone",
		@"system_version"         : dev.systemVersion ?: @"7.1.2",
		@"application_version"    : @"1.0",
	}];
}

- (void)handleInAppNotificationForNewMessage:(NSDictionary *)m {
	if (!m || [m[@"is_outgoing"] boolValue])
		return;
	if (self.authState != TGAuthStateReady || self.connectionState != TGConnectionStateReady)
		return;
	if (self.readyAt <= 0)
		return;
	NSTimeInterval msgDate = [m[@"date"] doubleValue];
	if (msgDate < self.readyAt)
		return;
	NSNumber *chatIdNum = m[@"chat_id"];
	if (!chatIdNum)
		return;
	int64_t chatId = [chatIdNum longLongValue];
	if ([self isChatMuted:chatId])
		return;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGInAppNotificationReceivedNotification
						  object:self
						userInfo:@{@"message" : m, @"chatId" : chatIdNum}];
}

@end
