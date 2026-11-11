#import "TGAccountStore.h"
//
// TGClient+Accounts.m
//
#import "TGClient+Accounts.h"
#import "TGClientInternal.h"
#import "TGOptions.h"

extern NSString *const TGAccountDidSwitchNotification;

/// The defaults key the slot list is stored under.
static NSString *const TGAccountSlotsKey = @"TGAccountSlots";
/// The defaults key the active slot is stored under. Absent reads as 0, which
/// is the pre-accounts session an existing install already has.
static NSString *const TGActiveAccountSlotKey = @"TGActiveAccountSlot";
/// Telegram's own ceiling: three accounts, slots 0, 1 and 2.
static const NSInteger TGAccountSlotMax = 3;

/// The client methods this file forwards to. Resetting an account clears the
/// push identity the old account registered and the verification request the
/// sign-in flow was waiting on; both live on TGClient+Auth.
@interface TGClient (TGStorePrivate)
- (void)setPushReceiverId:(int64_t)receiverId;
- (void)noteApplicationVerificationWithId:(int64_t)verificationId
									nonce:(NSString *)nonce;
@end

static void TGStoreAccountSlots(NSArray *slots) {
	[[NSUserDefaults standardUserDefaults] setObject:slots forKey:TGAccountSlotsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

NSString *TGAccountStoreDatabaseDirectory(NSString *documents, NSInteger slot) {
	if (slot <= 0)
		return [documents stringByAppendingPathComponent:@"tdlib"];
	return [documents stringByAppendingPathComponent:
			[NSString stringWithFormat:@"tdlib-%ld", (long)slot]];
}

NSString *TGAccountStoreDefaultsKey(NSString *base) {
	NSInteger slot = [TGClient activeAccountSlot];
	if (slot <= 0)
		return base;
	return [base stringByAppendingFormat:@"-%ld", (long)slot];
}

@implementation TGAccountStore (Accounts)

+ (NSInteger)activeAccountSlot {
	NSInteger slot = [[NSUserDefaults standardUserDefaults]
			integerForKey:TGActiveAccountSlotKey];
	if (slot < 0 || slot >= TGAccountSlotMax)
		return 0;
	return slot;
}

+ (NSArray *)accountSlots {
	NSArray *raw = [[NSUserDefaults standardUserDefaults]
			arrayForKey:TGAccountSlotsKey];
	if (![raw isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
	for (id entry in raw){
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *slot = entry[@"slot"];
		if (![slot isKindOfClass:NSNumber.class])
			continue;
		NSString *title = [entry[@"title"] isKindOfClass:NSString.class]
				? entry[@"title"] : @"";
		NSString *phone = [entry[@"phone"] isKindOfClass:NSString.class]
				? entry[@"phone"] : @"";
		[out addObject:@{@"slot" : slot, @"title" : title, @"phone" : phone}];
	}
	return out;
}

+ (NSInteger)addAccount {
	NSArray *existing = [self accountSlots];
	NSInteger active = [self activeAccountSlot];

	// The active slot is the running account, whether or not the stored list
	// has named it yet: an install that signed out of slot 0 keeps an empty
	// list, and the next free slot must never be the one TDLib already uses.
	BOOL used[3] = { NO, NO, NO };
	if (active >= 0 && active < TGAccountSlotMax)
		used[active] = YES;
	BOOL activeListed = NO;
	for (NSDictionary *entry in existing){
		NSInteger s = [entry[@"slot"] integerValue];
		if (s >= 0 && s < TGAccountSlotMax){
			used[s] = YES;
			if (s == active)
				activeListed = YES;
		}
	}
	NSInteger next = 0;
	while (next < TGAccountSlotMax && used[next])
		next++;
	if (next >= TGAccountSlotMax)
		return -1;

	NSMutableArray *slots = [existing mutableCopy];
	// The active slot is being signed into but the list does not name it yet;
	// store it too, so the account that signs in there survives the switch
	// away from it.
	if (!activeListed)
		[slots addObject:@{@"slot" : @(active), @"title" : @"", @"phone" : @""}];
	[slots addObject:@{@"slot" : @(next), @"title" : @"", @"phone" : @""}];
	TGStoreAccountSlots(slots);
	return next;
}

- (void)recordActiveAccountFromMe:(NSDictionary *)me {
	if (![me isKindOfClass:NSDictionary.class])
		return;
	NSInteger slot = [TGClient activeAccountSlot];
	NSString *firstName = [me[@"first_name"] isKindOfClass:NSString.class]
			? me[@"first_name"] : @"";
	NSString *username = [me[@"username"] isKindOfClass:NSString.class]
			? me[@"username"] : @"";
	NSString *phone = [me[@"phone"] isKindOfClass:NSString.class]
			? me[@"phone"] : @"";
	// The name the switcher shows, falling back to what the record carries
	// while Telegram has not sent a name yet.
	NSString *title = firstName.length ? firstName
			: (username.length ? username : phone);

	NSArray *existing = [TGClient accountSlots];
	NSMutableArray *slots = [NSMutableArray arrayWithCapacity:existing.count + 1];
	BOOL found = NO;
	for (NSDictionary *entry in existing){
		NSMutableDictionary *row = [entry mutableCopy];
		if ([row[@"slot"] integerValue] == slot){
			row[@"title"] = title ?: @"";
			row[@"phone"] = phone ?: @"";
			found = YES;
		}
		[slots addObject:row];
	}
	if (!found)
		[slots addObject:@{@"slot" : @(slot), @"title" : title ?: @"",
						   @"phone" : phone ?: @""}];
	TGStoreAccountSlots(slots);
}

- (void)switchToAccountSlot:(NSInteger)slot {
	if (slot < 0 || slot >= TGAccountSlotMax)
		return;
	if (slot == [TGClient activeAccountSlot])
		return;
	// A switch while TDLib is still closing must not move the active slot:
	// pauseForBackground runs its completion at once when pausing is already
	// YES, and the slot would move while the old database is still closing.
	if ([TGClient shared].pausing)
		return;

	// pauseForBackground closes TDLib safely and its completion runs on the
	// main queue once the client is gone - the only window where the active
	// slot may move, because a running client has already opened a database.
	[[TGClient shared] pauseForBackground:^{
		[[NSUserDefaults standardUserDefaults] setInteger:slot
												  forKey:TGActiveAccountSlotKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self resetStateForAccountSwitch];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGAccountDidSwitchNotification object:[TGClient shared]];
		[[TGClient shared] resumeFromBackground];
	}];
}

- (void)resetStateForAccountSwitch {
	// Identity and the half-finished sign-in steps.
	[TGClient shared].me = nil;
	[TGClient shared].authState = TGAuthStateUnknown;
	[TGClient shared].pendingPhoneNumber = nil;
	[TGClient shared].codeInfo = nil;
	[TGClient shared].loginPasswordInfo = nil;
	[TGClient shared].emailCodeInfo = nil;
	[TGClient shared].qrCodeLink = nil;
	[TGClient shared].registrationTermsText = nil;
	[[TGClient shared] noteApplicationVerificationWithId:0 nonce:@""];
	[[TGClient shared] setPushReceiverId:0];

	// Chat and user caches.
	[[TGClient shared].chatsById removeAllObjects];
	[[TGClient shared].usersById removeAllObjects];
	[[TGClient shared].rawUsersById removeAllObjects];
	[[TGClient shared].userPhotosById removeAllObjects];
	[[TGClient shared].forumSupergroups removeAllObjects];
	[[TGClient shared].savedTopicsById removeAllObjects];
	[TGClient shared].archivedChats = @[];
	[TGClient shared].folders = @[];
	[TGClient shared].chats = @[];
	[TGClient shared].chatListComplete = NO;
	[TGClient shared].loadChatsAttempts = 0;
	[TGClient shared].chatsAtLastLoad = 0;
	[TGClient shared].chatsNeedRebuild = NO;
	[TGClient shared].batchingUpdates = NO;

	// Account facts the settings and profile pages read from the client.
	[TGClient shared].accentColorIds = @[];
	[TGClient shared].profileAccentColorIds = @[];
	[TGClient shared].accentColors = @[];
	[TGClient shared].profileAccentColors = @[];
	[TGClient shared].contactCloseBirthdays = @[];
	[TGClient shared].freezeStateValue = nil;
	[TGClient shared].ageVerificationParametersValue = nil;
	[TGClient shared].recaptchaVerificationRequestValue = nil;
	[[TGClient shared].userSubscriptionsById removeAllObjects];
	[TGClient shared].reactionMessageEffectIds = @[];
	[TGClient shared].stickerMessageEffectIds = @[];
	[TGClient shared].defaultBackgroundValue = nil;
	[TGClient shared].emojiChatThemesValue = @[];
	[TGClient shared].stoppedMessageDraftValue = nil;
	[TGClient shared].publishedVideoValue = nil;
	for (NSNumber *pending in [[TGClient shared].noteSendWaiters allKeys])
		[[TGClient shared] noteSendFinished:pending.longLongValue sent:NO];
	[TGClient shared].storyMainListChatCount = 0;
	[TGClient shared].storyArchiveListChatCount = 0;
	[TGClient shared].storyStealthModeValue = nil;
	[TGClient shared].ownedStarCountValue = 0;
	[[TGClient shared].chatRevenueAmountByChat removeAllObjects];
	[[TGClient shared].starRevenueStatusByOwner removeAllObjects];
	[TGClient shared].reactionDefaultEmoji = nil;
	[TGClient shared].reactionNotificationSettingsValue = nil;
	[TGClient shared].gifSearchProvider = nil;
	[TGClient shared].gifSearchEmojis = @[];
	[TGClient shared].archiveSettings = nil;

	// Tier 2, notifications and the misc caches.
	[TGClient shared].textCompositionStylesValue = @[];
	[[TGClient shared].directMessagesTopicsByChat removeAllObjects];
	[TGClient shared].stakeDiceStateValue = nil;
	[TGClient shared].activeNotificationGroupRows = @[];
	[TGClient shared].activeNotificationGroupsValue = @[];
	[TGClient shared].haveDelayedNotifications = NO;
	[TGClient shared].haveUnreceivedNotifications = NO;
	[[TGClient shared].autosaveSettingsByScope removeAllObjects];
	[TGClient shared].languagePackStringsByPack = nil;
	[[TGClient shared].communitiesById removeAllObjects];
	[[TGClient shared].communityOrder removeAllObjects];
	[[TGClient shared].communityFullInfoById removeAllObjects];
	[[TGClient shared].quickReplyShortcutsById removeAllObjects];
	[[TGClient shared].quickReplyShortcutOrder removeAllObjects];
	[[TGClient shared].quickReplyMessagesByShortcut removeAllObjects];
	[TGClient shared].suggestedActionsValue = @[];
	[[TGClient shared].checklistCache removeAllObjects];

	// Connection, requests and the outbox.
	[TGClient shared].connectionState = TGConnectionStateUnknown;
	[[TGClient shared].pendingRequests removeAllObjects];
	[TGClient shared].requestSeq = 0;
	[[TGClient shared].outboxLock lock];
	[[TGClient shared].outbox removeAllObjects];
	[[TGClient shared].outboxLock unlock];
	[[TGClient shared].updateCoalescer reset];
	[[TGClient shared] removeAllFileWaiters];

	// Server options (updateOption) are account-scoped too; the next account
	// re-fetches them and a stale value would otherwise be read as its own.
	TGOptionReset();

	// The stores and players that hold this account's ids are the app's to
	// reset, on TGAccountDidSwitchNotification.
	[[TGClient shared] resetGroupCallState];
	[[TGClient shared] removeAllPendingGenerations];
}

@end
