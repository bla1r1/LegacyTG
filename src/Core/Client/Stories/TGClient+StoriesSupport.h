#import "TGClient+Base.h"
#import "TGDevice.h"

NSDictionary * TGStoryDict(id value);
NSArray * TGStoryArray(id value);
NSString * TGStoryErrorText(NSDictionary *result);
BOOL TGStorySucceeded(NSDictionary *result);
NSNumber * TGStoryPhotoFileId(NSDictionary *photo);
NSNumber * TGStoryChatPhotoFileId(NSDictionary *chat);
NSNumber * TGStoryVideoThumbFileId(NSDictionary *video);
NSDictionary * TGStoryFlattenSender(NSDictionary *sender);
NSString * TGStoryPrivacyName(NSDictionary *privacy);
NSDictionary * TGStoryPrivacyObject(NSString *privacy, NSArray *userIds);
id TGStoryReactionObject(NSString *reaction);
NSArray * TGStoryReactionEmojis(NSArray *reactions);
NSDictionary * TGStoryGraph(NSDictionary *graph);
NSDictionary * TGStoryFlatten(NSDictionary *story);
NSDictionary * TGStoryFlattenInfo(NSDictionary *info, NSDictionary *active);
NSDictionary * TGStoryFlattenAlbum(NSDictionary *album);
NSArray * TGStoryFlattenStoryList(NSDictionary *result);
