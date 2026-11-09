#import "TGProfileViewControllerInternal.h"

@implementation TGProfileViewController

- (instancetype)initWithChatId:(int64_t)chatId userId:(int64_t)userId title:(NSString *)title {
	if ((self = [super init])){
		_chatId = chatId;
		_userId = (chatId < 0) ? 0 : userId;
		_name = ([title isEqualToString:@"."] ? @"" : (title ?: @""));
		_details = @[];
		_photos = @[];
		_files = @[];
		_thumbnailsRequested = [NSMutableSet set];
		_loadedMediaKinds = [NSMutableSet set];
		_loadingMediaKinds = [NSMutableSet set];
		_mediaCounts = [NSMutableDictionary dictionary];
		_coverImages = [NSMutableDictionary dictionary];
		_mediaImages = [NSMutableDictionary dictionary];
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

// The rows are replaced from TDLib callbacks. A row count that changed during
// a layout pass (the header rebuild sets tableHeaderView) asked the table for a
// row past the old array and the profile died. Sections are rebuilt in one
// place and assigned atomically before the reload, so a detail count change can
// never leave the table with rows the section model does not have.
- (void)setDetails:(NSArray *)details {
	NSArray *safe = [details isKindOfClass:NSArray.class] ? details : @[];
	BOOL changed = ![safe isEqualToArray:_details];
	_details = safe;
	if (changed && self.isViewLoaded)
		[self rebuildSections];
}

@end
