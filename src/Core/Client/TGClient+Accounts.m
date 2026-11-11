//
// TGClient+Accounts.m
//
#import "TGClient+Accounts.h"
#import "TGClientInternal.h"
#import "TGTransport.h"
#import "TGOptions.h"

NSString *const TGAccountDidSwitchNotification = @"TGAccountDidSwitchNotification";

/// The defaults key the slot list is stored under.
static NSString *const TGAccountSlotsKey = @"TGAccountSlots";
/// The defaults key the active slot is stored under. Absent reads as 0, which
/// is the pre-accounts session an existing install already has.
static NSString *const TGActiveAccountSlotKey = @"TGActiveAccountSlot";
/// Telegram's own ceiling: three accounts, slots 0, 1 and 2.
static const NSInteger TGAccountSlotMax = 3;

/// The private setter TGClient+Auth owns; resetting an account clears the
/// push identity the old account registered.
@interface TGClient (AuthPrivate)
- (void)setPushReceiverId:(int64_t)receiverId;
@end

static void TGStoreAccountSlots(NSArray *slots) {
	[[NSUserDefaults standardUserDefaults] setObject:slots forKey:TGAccountSlotsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

NSString *TGAccountDatabaseDirectory(NSString *documents, NSInteger slot) {
	if (slot <= 0)
		return [documents stringByAppendingPathComponent:@"tdlib"];
	return [documents stringByAppendingPathComponent:
			[NSString stringWithFormat:@"tdlib-%ld", (long)slot]];
}

NSString *TGAccountDefaultsKey(NSString *base) {
	NSInteger slot = [TGClient activeAccountSlot];
	if (slot <= 0)
		return base;
	return [base stringByAppendingFormat:@"-%ld", (long)slot];
}

@implementation TGClient (Accounts)

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

@end
