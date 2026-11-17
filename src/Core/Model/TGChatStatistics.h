//
// TGChatStatistics.h - getChatStatistics as the rows the statistics screen
// draws, in official's order (StatisticsUI ChannelStatsController,
// GroupStatsController).
//
#import <Foundation/Foundation.h>

typedef NSString *(^TGStatName)(int64_t userId);

/// "1234 +56 (4.75%)": a statisticalValue with its change against the
/// previous period, as official's overview cell writes it
/// (StatsOverviewItem deltaText). "-" for no value.
FOUNDATION_EXPORT NSString *TGStatValueText(NSDictionary *value);

/// The overview and list rows, @{title, detail[, section]}; a row with a
/// "section" belongs under that heading ("TOP MEMBERS", "TOP ADMINS",
/// "TOP INVITERS", "RECENT POSTS") after the graphs. `postText` names a
/// recent post's message by id, nil while unknown.
FOUNDATION_EXPORT NSArray *TGChatStatisticsRows(NSDictionary *result, TGStatName name,
		NSString *(^postText)(int64_t messageId));

/// The channel posts a recent interaction names, to fetch their text.
FOUNDATION_EXPORT NSArray *TGChatStatisticsPostIds(NSDictionary *result);
