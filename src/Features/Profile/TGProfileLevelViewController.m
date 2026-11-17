#import "TGProfileLevelViewController.h"
#import "TGUserRating.h"
#import "TGRows.h"
#import "TGLocalization.h"

@interface TGProfileLevelViewController ()
@property (nonatomic, strong) NSDictionary *rating;
@property (nonatomic, strong) NSDictionary *pending;
@property (nonatomic, assign) int64_t pendingDate;
@property (nonatomic, copy) NSString *name;
@end

@implementation TGProfileLevelViewController

- (instancetype)initWithRating:(NSDictionary *)rating pending:(NSDictionary *)pending
				   pendingDate:(int64_t)pendingDate name:(NSString *)name {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self){
		_rating = rating;
		_pending = pending;
		_pendingDate = pendingDate;
		_name = [name copy];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalizedKey(@"ProfileLevelInfo.Title", @"Rating");
	[self rebuildSections];
}

/// Official's "**Ann's**" marks the name bold; a table header has no bold,
/// so the stars go and the words stay.
static NSString *TGLevelPlain(NSString *text) {
	return [text stringByReplacingOccurrencesOfString:@"**" withString:@""];
}

- (void)rebuildSections {
	// The bar's two ends and the points between them (ProfileLevelRatingBar).
	NSMutableDictionary *level = [TGTapRow(TGUserRatingLevelText(self.rating),
			TGUserRatingProgressText(self.rating), nil) mutableCopy];
	level[TGRowRawTitle] = @YES;
	level[TGRowRawDetail] = @YES;
	NSString *pendingText = TGUserRatingPendingText(self.rating, self.pending,
			self.pendingDate, [[NSDate date] timeIntervalSince1970]);

	NSString *about = self.name.length
			? TGLevelPlain([NSString stringWithFormat:TGLocalizedKey(@"ProfileLevelInfo.OtherDescription",
					@"The rating reflects **%@'s** activity on Telegram. What affects it:"), self.name])
			: TGLocalizedKey(@"ProfileLevelInfo.MyText",
					@"The rating reflects your activity on Telegram. What affects it:");

	NSArray *items = @[
		@[@"ProfileLevelInfo.Item0", @"Gifts from Telegram",
		  @"100% of the Stars spent on gifts purchased from Telegram.", @"ADDED"],
		@[@"ProfileLevelInfo.Item1", @"Gifts and Posts from Users",
		  @"20% of the Stars spent on gifts or posts from users and channels.", @"ADDED"],
		@[@"ProfileLevelInfo.Item2", @"Refunds and Conversions",
		  @"10x of refunded Stars and 85% of bought gifts converted to Stars.", @"DEDUCTED"],
	];
	NSMutableArray *rows = [NSMutableArray array];
	for (NSArray *item in items){
		NSString *key = item[0];
		NSMutableDictionary *row = [TGTapRow(
				TGLocalizedKey([key stringByAppendingString:@".Title"], item[1]),
				TGLocalizedKey([key stringByAppendingString:@".Badge"], item[3]), nil) mutableCopy];
		row[TGRowSubtitle] = TGLocalizedKey([key stringByAppendingString:@".Text"], item[2]);
		[rows addObject:row];
	}

	self.sections = @[
		TGSection(nil, pendingText, @[level]),
		TGSection(about, nil, rows),
	];
	[self reloadRows];
}

@end
