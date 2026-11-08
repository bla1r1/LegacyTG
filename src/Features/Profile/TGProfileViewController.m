#import "TGProfileViewControllerInternal.h"

@implementation TGProfileViewController

- (instancetype)initWithChatId:(int64_t)chatId userId:(int64_t)userId title:(NSString *)title {
	if ((self = [super initWithStyle:UITableViewStyleGrouped])){
		_chatId = chatId;
		_userId = (chatId < 0) ? 0 : userId;
		_name = title ?: @"";
		_details = @[];
		_photos = @[];
		_files = @[];
		_thumbnailsRequested = [NSMutableSet set];
		_loadedMediaKinds = [NSMutableSet set];
		_loadingMediaKinds = [NSMutableSet set];
		_mediaCounts = [NSMutableDictionary dictionary];
		_coverImages = [NSMutableDictionary dictionary];
		_memberCount = 0;
		_canManage = NO;
		_canInvite = NO;
		_chatAvatars = [NSMutableDictionary dictionary];
		_requestedChatAvatars = [NSMutableSet set];
		_similarChannelAvatars = [NSMutableDictionary dictionary];
		_similarChannelsRequested = [NSMutableSet set];
	}
	return self;
}

@end
