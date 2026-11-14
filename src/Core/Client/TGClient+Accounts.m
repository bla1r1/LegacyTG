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

NSString *TGAccountDataRootInLibrary(NSString *library) {
	if (!library.length)
		return nil;
	// Not `Library/Accounts`: installed to /Applications the app has no
	// container, Library is /var/mobile/Library, and that name is the
	// system's own account database (Accounts3.sqlite). The backup flag
	// below would have taken it out of the device backup.
	NSString *path = [library stringByAppendingPathComponent:@"LegacyTG"];
	NSError *error = nil;
	if (![[NSFileManager defaultManager] createDirectoryAtPath:path
			withIntermediateDirectories:YES attributes:nil error:&error]){
		NSLog(@"TGClient: cannot create %@: %@", path, error);
		return nil;
	}
	// The flag is inherited by everything inside: one call covers every
	// slot's database and its files directory.
	if (![[NSURL fileURLWithPath:path isDirectory:YES] setResourceValue:@YES
			forKey:NSURLIsExcludedFromBackupKey error:&error])
		NSLog(@"TGClient: cannot exclude %@ from backup: %@", path, error);
	return path;
}

NSString *TGAccountDataRoot(void) {
	static NSString *root = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		root = TGAccountDataRootInLibrary([NSSearchPathForDirectoriesInDomains(
				NSLibraryDirectory, NSUserDomainMask, YES) firstObject]);
	});
	return root;
}

NSString *TGAccountMoveDatabase(NSString *oldDirectory, NSString *newDirectory) {
	if (!newDirectory.length)
		return oldDirectory;
	NSFileManager *fm = [NSFileManager defaultManager];
	if (!oldDirectory.length || ![fm fileExistsAtPath:oldDirectory])
		return newDirectory;
	// Both exist only after a downgrade and a second upgrade. The new place
	// wins and the old copy is left alone: which one is fresher cannot be
	// told from here, and deleting a session is not this function's call.
	if ([fm fileExistsAtPath:newDirectory])
		return newDirectory;
	// Same volume, so this is a rename: all of it moves or none of it does.
	NSError *error = nil;
	if (![fm moveItemAtPath:oldDirectory toPath:newDirectory error:&error]){
		NSLog(@"TGClient: database stays at %@: %@", oldDirectory, error);
		return oldDirectory;
	}
	return newDirectory;
}

NSString *TGAccountResolvedDatabaseDirectory(NSInteger slot) {
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
			NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	NSString *old = TGAccountDatabaseDirectory(documents, slot);
	NSString *root = TGAccountDataRoot();
	if (!root)
		return old;
	return TGAccountMoveDatabase(old, TGAccountDatabaseDirectory(root, slot));
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
