#import "TGMediaViewerInternal.h"

@implementation TGMediaViewer

- (id)init {
	if ((self = [super init])){
		_pages = [NSMutableDictionary dictionary];
		_originals = [NSMutableDictionary dictionary];
		_requested = [NSMutableSet set];
		_placeholderPages = [NSMutableSet set];
		_loading = [NSCountedSet set];
		_moviePage = NSNotFound;
	}
	return self;
}


@end
