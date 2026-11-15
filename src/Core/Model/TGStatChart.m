#import "TGStatChart.h"

NSDictionary *TGStatChartParse(NSString *json) {
	if (![json isKindOfClass:NSString.class] || !json.length)
		return nil;
	id root = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
											  options:0 error:NULL];
	if (![root isKindOfClass:NSDictionary.class])
		return nil;
	NSArray *columns = [root[@"columns"] isKindOfClass:NSArray.class] ? root[@"columns"] : nil;
	NSDictionary *names = [root[@"names"] isKindOfClass:NSDictionary.class] ? root[@"names"] : nil;
	NSDictionary *colours = [root[@"colors"] isKindOfClass:NSDictionary.class] ? root[@"colors"] : nil;
	NSDictionary *types = [root[@"types"] isKindOfClass:NSDictionary.class] ? root[@"types"] : nil;
	NSArray *x = nil;
	NSMutableArray *series = [NSMutableArray array];
	for (NSArray *column in columns){
		if (![column isKindOfClass:NSArray.class] || column.count < 2 ||
			![column[0] isKindOfClass:NSString.class])
			continue;
		NSString *key = column[0];
		NSArray *values = [column subarrayWithRange:NSMakeRange(1, column.count - 1)];
		if ([types[key] isEqual:@"x"] || [key isEqualToString:@"x"]){
			x = values;
			continue;
		}
		[series addObject:@{@"name" : names[key] ?: key,
							@"colour" : colours[key] ?: @"#3497ED",
							@"type" : types[key] ?: @"line",
							@"values" : values}];
	}
	if (!x.count || !series.count)
		return nil;
	return @{@"x" : x, @"series" : series};
}

double TGStatChartMax(NSDictionary *chart) {
	double top = 1;
	for (NSDictionary *s in chart[@"series"])
		for (NSNumber *v in s[@"values"])
			if ([v isKindOfClass:NSNumber.class])
				top = MAX(top, v.doubleValue);
	return top;
}
