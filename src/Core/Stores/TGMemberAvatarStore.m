//
// TGMemberAvatarStore.m - the old member-face API, now a name on TGPeerStore.
//
// The member lists were the first screens to share one avatar cache. TGPeerStore
// owns that cache now; this keeps the two callers that still say "user" from
// carrying a second copy of the download and decode rules.
//
#import "TGMemberAvatarStore.h"
#import "TGPeerStore.h"

@implementation TGMemberAvatarStore

+ (instancetype)shared {
	static TGMemberAvatarStore *one;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ one = [[TGMemberAvatarStore alloc] init]; });
	return one;
}

- (UIImage *)cachedAvatarForUser:(int64_t)userId side:(CGFloat)side {
	return [[TGPeerStore shared] cachedAvatarForPeer:userId side:side];
}

- (void)reset {
	[[TGPeerStore shared] reset];
}

- (void)loadAvatarForUser:(int64_t)userId
					 side:(CGFloat)side
			   completion:(void (^)(UIImage *))completion {
	[[TGPeerStore shared] loadAvatarForPeer:userId side:side completion:completion];
}

@end
