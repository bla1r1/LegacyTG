#import "TGClient+Base.h"

#ifdef __cplusplus
extern "C" {
#endif

NSDictionary * TGFlattenStory(NSDictionary *story);
BOOL TGProfileBirthdayIsToday(NSInteger day, NSInteger month, NSDate *now);
NSString * TGProfileBirthdayText(NSInteger day, NSInteger month, NSInteger year, NSDate *now);
NSString * TGFirstUsername(NSDictionary *user);

#ifdef __cplusplus
}
#endif
