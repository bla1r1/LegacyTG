//
// TGStatisticsViewController.m - statistics with their graphs. A graph is
// drawn once into a picture: nothing on the A4 redraws lines while the list
// scrolls. Every kind (line, bar, area, step) is drawn as lines.
//
#import "TGStatisticsViewController.h"
#import "TGRows.h"
#import "TGTheme.h"
#import "TGThemeFile.h"
#import "TGStyle.h"
#import "TGLocalization.h"
#import "TGMessageStore.h"
#import "TGStatChart.h"
#import "TGUIFormat.h"

static const CGFloat kChartHeight = 150.0f;

@interface TGStatisticsViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSArray *statRows;
/// Section title -> chart JSON, or an NSString error, once known.
@property (nonatomic, strong) NSMutableDictionary *charts;
@end

@implementation TGStatisticsViewController

- (instancetype)initWithChatId:(int64_t)chatId rows:(NSArray *)rows {
	self = [super init];
	if (self){
		_chatId = chatId;
		_statRows = [rows copy];
		_charts = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGLocalized(@"Statistics");
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *row in self.statRows){
		NSDictionary *graph = row[@"graph"];
		NSString *title = row[@"title"];
		NSString *type = graph[@"@type"];
		if ([type isEqualToString:@"statisticalGraphData"])
			self.charts[title] = graph[@"json_data"] ?: @"";
		else if ([type isEqualToString:@"statisticalGraphError"])
			self.charts[title] = @{@"error" : graph[@"error_message"] ?: @""};
		else if ([type isEqualToString:@"statisticalGraphAsync"])
			[[TGMessageStore shared] statisticalGraph:graph[@"token"] inChat:self.chatId
										   completion:^(NSString *json, NSString *error){
				TGStatisticsViewController *me = weakSelf;
				me.charts[title] = json ?: @{@"error" : error ?: @""};
				[me rebuild];
			}];
	}
	[self rebuild];
}

/// The graph as a picture: a light grid, the series as lines, the first and
/// last dates under it and the series names in their colours.
- (UIImage *)pictureForChart:(NSDictionary *)chart width:(CGFloat)width {
	TGTheme *theme = [TGTheme shared];
	CGFloat legendH = TGMetricLineCaption;
	CGFloat plotH = kChartHeight - TGDoubled(legendH);
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, kChartHeight), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[[theme separatorColour] setStroke];
	CGContextSetLineWidth(ctx, TGMetricHairline);
	for (int i = 0; i <= 4; i++){
		CGFloat y = roundf(plotH * i / 4.0f) + TGMetricHairline;
		CGContextMoveToPoint(ctx, 0, y);
		CGContextAddLineToPoint(ctx, width, y);
	}
	CGContextStrokePath(ctx);
	double top = TGStatChartMax(chart);
	NSArray *x = chart[@"x"];
	CGContextSetLineWidth(ctx, TGMetricBorderWidth + TGMetricHairline);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);
	for (NSDictionary *series in chart[@"series"]){
		NSArray *values = series[@"values"];
		if (values.count < 2)
			continue;
		[(TGColourFromHexString(series[@"colour"]) ?: [theme accentColour]) setStroke];
		for (NSUInteger i = 0; i < values.count; i++){
			CGFloat px = width * i / (CGFloat)(values.count - 1);
			CGFloat py = plotH - plotH * (CGFloat)([values[i] doubleValue] / top);
			if (i == 0)
				CGContextMoveToPoint(ctx, px, py);
			else
				CGContextAddLineToPoint(ctx, px, py);
		}
		CGContextStrokePath(ctx);
	}
	UIFont *font = TGFontMicro();
	[[theme secondaryTextColour] setFill];
	// Day graphs carry milliseconds; hour and weekday ones small numbers.
	double first = [x.firstObject doubleValue], last = [x.lastObject doubleValue];
	if (first > 1e11){
		NSString *from = TGAppDate(first / 1000, NSDateFormatterShortStyle, NSDateFormatterNoStyle);
		NSString *to = TGAppDate(last / 1000, NSDateFormatterShortStyle, NSDateFormatterNoStyle);
		[from drawInRect:CGRectMake(0, plotH, TGHalf(width), legendH) withFont:font];
		[to drawInRect:CGRectMake(TGHalf(width), plotH, TGHalf(width), legendH) withFont:font
		 lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentRight];
	}
	NSString *topText = TGCompactCount((int64_t)top);
	[topText drawAtPoint:CGPointMake(0, TGMetricHairline) withFont:font];
	CGFloat lx = 0;
	for (NSDictionary *series in chart[@"series"]){
		[(TGColourFromHexString(series[@"colour"]) ?: [theme accentColour]) setFill];
		CGSize size = [series[@"name"] sizeWithFont:font];
		if (lx + size.width > width)
			break;
		[series[@"name"] drawAtPoint:CGPointMake(lx, plotH + legendH) withFont:font];
		lx += size.width + TGMetricPad;
	}
	UIImage *picture = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return picture;
}

- (void)rebuild {
	NSMutableArray *overview = [NSMutableArray array];
	NSMutableArray *sections = [NSMutableArray array];
	CGFloat width = self.view.bounds.size.width - TGDoubled(TGMetricPadLarge + TGMetricPad);
	// TOP MEMBERS, TOP ADMINS, TOP INVITERS and RECENT POSTS come after the
	// graphs, each under its heading, as official lists them.
	NSMutableArray *listTitles = [NSMutableArray array];
	NSMutableDictionary *lists = [NSMutableDictionary dictionary];
	for (NSDictionary *row in self.statRows){
		NSString *heading = row[@"section"];
		if (heading.length){
			if (!lists[heading]){
				lists[heading] = [NSMutableArray array];
				[listTitles addObject:heading];
			}
			NSMutableDictionary *item = TGRow(TGKindPlain, row[@"title"]);
			item[TGRowDetail] = row[@"detail"] ?: @"";
			item[TGRowRawTitle] = @YES;
			[lists[heading] addObject:item];
			continue;
		}
		if (!row[@"graph"]){
			NSMutableDictionary *plain = TGRow(TGKindPlain, row[@"title"]);
			plain[TGRowDetail] = row[@"detail"] ?: @"";
			[overview addObject:plain];
			continue;
		}
		NSString *title = row[@"title"];
		id known = self.charts[title];
		NSMutableDictionary *cell;
		NSDictionary *chart = [known isKindOfClass:NSString.class] ? TGStatChartParse(known) : nil;
		if (chart){
			cell = TGRow(TGKindChart, @"");
			cell[TGRowImage] = [self pictureForChart:chart width:width];
			cell[TGRowHeight] = @(kChartHeight + TGDoubled(TGMetricPadMedium));
		} else {
			NSString *error = [known isKindOfClass:NSDictionary.class] ? known[@"error"] : nil;
			cell = TGRow(TGKindPlain, known ? (error.length ? error : TGLocalized(@"No data"))
					: TGLocalized(@"Loading..."));
		}
		[sections addObject:TGSection(TGLocalized(title), nil, @[cell])];
	}
	for (NSString *heading in listTitles)
		[sections addObject:TGSection(TGLocalized(heading), nil, lists[heading])];
	[sections insertObject:TGSection(TGLocalized(@"OVERVIEW"), nil, overview) atIndex:0];
	self.sections = sections;
	[self reloadRows];
}

@end
