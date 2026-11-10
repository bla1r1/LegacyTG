//
// TGProfileSupport.h - the small helpers the Profile screens share.
//
#import <Foundation/Foundation.h>
@class TGClient;
NSArray *TGChatRowsForIds(TGClient *client, NSArray *ids);
NSDictionary *TGProfileTabObject(NSString *name);
NSString *TGProfileTabName(NSDictionary *tab);
NSDictionary *TGMemberSender(int64_t userId);
NSArray *TGCustomEmojiStickerList(NSArray *stickers);


/// The first username a TDLib user record carries, or nil.
NSString *TGFirstUsername(NSDictionary *user);

/// Appends a media page without repeating an id the list already holds.
NSArray *TGMediaPageAppending(NSArray *existing, NSArray *more);
