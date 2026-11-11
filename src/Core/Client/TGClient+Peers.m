//
// TGClient+Peers.m - the union of the user and chat caches, for TGPeerStore.
//
#import "TGClient+Peers.h"
#import "TGClientInternal.h"
#import "TGClient+AccountCore.h"
#import "TGClient+AccountSupport.h"
#import "TGClient+ChatFolders.h"
#import "TGClient+ChatTools.h"

@implementation TGClient (Peers)

- (NSDictionary *)peerUserRecordForId:(int64_t)userId {
	NSDictionary *user = self.rawUsersById[@(userId)];
	return [user isKindOfClass:NSDictionary.class] ? user : nil;
}

- (NSDictionary *)peerChatRecordForId:(int64_t)chatId {
	NSDictionary *chat = self.chatsById[@(chatId)];
	return [chat isKindOfClass:NSDictionary.class] ? chat : nil;
}

- (NSNumber *)peerPhotoFileIdForId:(int64_t)peerId {
	if (!peerId)
		return nil;
	NSNumber *chatPhoto = [self peerChatRecordForId:peerId][@"photoFileId"];
	if ([chatPhoto isKindOfClass:NSNumber.class] && chatPhoto.integerValue > 0)
		return chatPhoto;
	NSDictionary *user = [self peerUserRecordForId:peerId];
	NSNumber *userPhoto = user[@"profile_photo"][@"small"][@"id"];
	if ([userPhoto isKindOfClass:NSNumber.class])
		return userPhoto;
	if (peerId > 0)
		return [self photoFileIdForUserId:peerId];
	return nil;
}

- (void)peerPhotoFileIdForId:(int64_t)peerId
                  completion:(void (^)(NSNumber *))completion {
	if (!peerId){
		if (completion) completion(nil);
		return;
	}
	NSNumber *cached = [self peerPhotoFileIdForId:peerId];
	if (cached){
		if (completion) completion(cached);
		return;
	}
	// A chat we have no row for still has a photo on the server. A user id
	// is the private chat id, so the same request answers it.
	if (peerId > 0 && ![self peerChatRecordForId:peerId]){
		[self profilePhotoFileIdForUser:peerId completion:completion];
		return;
	}
	[self chatRecordForChat:peerId completion:^(NSDictionary *chat){
		NSNumber *fileId = chat[@"photo"][@"small"][@"id"];
		if (![fileId isKindOfClass:NSNumber.class])
			fileId = chat[@"photoFileId"];
		if (![fileId isKindOfClass:NSNumber.class])
			fileId = nil;
		if (completion) completion(fileId);
	}];
}

- (void)peerStatusForUserId:(int64_t)userId
                 completion:(void (^)(NSString *))completion {
	[self statusForUser:userId completion:completion];
}

- (void)peerMemberCountForChatId:(int64_t)chatId
                      completion:(void (^)(NSInteger))completion {
	[self memberCountForChat:chatId completion:completion];
}

@end
