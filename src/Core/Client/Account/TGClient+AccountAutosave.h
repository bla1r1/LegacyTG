//
// TGClient+Account.h - the client surface for the account and its people: sessions, contacts, blocked users, storage stats.
//
#import "TGClient+Base.h"


@interface TGClient (AccountAutosave)

/// Telegram's gallery autosave settings. "private", "groups" and "channels"
/// each carry "photos", "videos" and "maxVideoSize"; "exceptions" is an array
/// of per-chat overrides with "chatId" and the same three fields.
- (void)autosaveSettingsWithCompletion:(void (^)(NSDictionary *settings))completion;
/// Writes one scope's settings. `scope` is "private", "groups" or "channels".
- (void)setAutosaveSettingsForScope:(NSString *)scope
							 photos:(BOOL)photos
							 videos:(BOOL)videos
					   maxVideoSize:(long long)maxVideoSize
						 completion:(void (^)(BOOL ok))completion;
/// Drops every per-chat exception; the three scope defaults stay.
- (void)clearAutosaveSettingsExceptionsWithCompletion:(void (^)(BOOL ok))completion;

@end
