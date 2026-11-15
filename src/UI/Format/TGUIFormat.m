#import "TGUIFormat.h"
#import "TGDateFormat.h"
#import "TGLocalization.h"

static NSString *TGUIDigits(NSString *raw) {
	NSMutableString *digits = [NSMutableString stringWithCapacity:raw.length];
	for (NSUInteger i = 0; i < raw.length; i++) {
		unichar c = [raw characterAtIndex:i];
		if (c >= '0' && c <= '9')
			[digits appendFormat:@"%C", c];
	}
	return digits;
}

NSString *TGUIFormatCallDuration(NSTimeInterval seconds) {
	NSInteger total = (NSInteger)MAX(0.0, seconds);
	NSInteger hours = total / 3600;
	NSInteger minutes = (total % 3600) / 60;
	NSInteger secs = total % 60;
	if (hours > 0)
		return [NSString stringWithFormat:@"%ld:%02ld:%02ld",
				(long)hours, (long)minutes, (long)secs];
	return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)secs];
}

NSString *TGUIFormatScheduledWhen(NSTimeInterval sendDate, NSTimeInterval now) {
	if (sendDate <= 0)
		return @"";
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:sendDate];
	NSDate *today = [NSDate dateWithTimeIntervalSince1970:now];

	NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
	timeFormatter.dateStyle = NSDateFormatterNoStyle;
	timeFormatter.timeStyle = NSDateFormatterShortStyle;
	NSString *clock = [timeFormatter stringFromDate:date];

	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *day = [calendar dateFromComponents:
			[calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit |
								   NSDayCalendarUnit) fromDate:date]];
	NSDate *base = [calendar dateFromComponents:
			[calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit |
								   NSDayCalendarUnit) fromDate:today]];
	NSDateComponents *oneDay = [[NSDateComponents alloc] init];
	oneDay.day = 1;
	NSDate *tomorrow = [calendar dateByAddingComponents:oneDay toDate:base options:0];

	if ([day isEqualToDate:base])
		return [NSString stringWithFormat:@"Today at %@", clock];
	if ([day isEqualToDate:tomorrow])
		return [NSString stringWithFormat:@"Tomorrow at %@", clock];

	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.dateStyle = NSDateFormatterMediumStyle;
	dateFormatter.timeStyle = NSDateFormatterNoStyle;
	return [NSString stringWithFormat:@"%@ at %@",
			[dateFormatter stringFromDate:date], clock];
}

NSString *TGUIFormatScheduledRelative(NSTimeInterval sendDate, NSTimeInterval now) {
	if (sendDate <= 0)
		return @"";
	NSInteger gap = (NSInteger)(sendDate - now);
	if (gap < 0)
		gap = 0;
	if (gap < 60)
		return @"in less than a minute";
	NSInteger minutes = gap / 60;
	if (minutes < 60)
		return [NSString stringWithFormat:@"in %ld min", (long)minutes];
	NSInteger hours = minutes / 60;
	minutes -= hours * 60;
	if (hours < 24)
		return minutes > 0
				? [NSString stringWithFormat:@"in %ld h %ld min", (long)hours, (long)minutes]
				: [NSString stringWithFormat:@"in %ld h", (long)hours];
	NSInteger days = hours / 24;
	hours -= days * 24;
	return hours > 0
			? [NSString stringWithFormat:@"in %ld d %ld h", (long)days, (long)hours]
			: [NSString stringWithFormat:@"in %ld d", (long)days];
}

NSString *TGUIFormatFullPhone(NSString *prefix, NSString *number) {
	NSString *prefixDigits = TGUIDigits(prefix ?: @"");
	NSString *numberDigits = TGUIDigits(number ?: @"");
	if (prefixDigits.length > 0 &&
			[numberDigits rangeOfString:prefixDigits].location == 0)
		numberDigits = [numberDigits substringFromIndex:prefixDigits.length];
	// A national number is often typed with its trunk zero ("067..." in
	// Ukraine); E.164 drops it. Italy is the country where the zero is part
	// of the number, so it is the one prefix that keeps it.
	if (prefixDigits.length > 0 && [numberDigits hasPrefix:@"0"] &&
			![prefixDigits isEqualToString:@"39"])
		numberDigits = [numberDigits substringFromIndex:1];
	return [NSString stringWithFormat:@"+%@%@", prefixDigits, numberDigits];
}

BOOL TGUIFormatChatMatches(NSString *title, NSString *query) {
	if (!query.length)
		return YES;
	NSString *haystack = [title isKindOfClass:NSString.class] ? title : @"";
	return [haystack rangeOfString:query
						   options:(NSCaseInsensitiveSearch |
									NSDiacriticInsensitiveSearch)].location != NSNotFound;
}

static NSString *TGFormatScaled(int64_t n, double divisor, const char *suffix) {
	double val = (double)n / divisor;
	if (val < 9.95) {
		long long tenths = (long long)round(val * 10.0);
		long long whole = tenths / 10;
		long long frac = tenths % 10;
		if (frac == 0) {
			return [NSString stringWithFormat:@"%lld%s", whole, suffix];
		}
		return [NSString stringWithFormat:@"%lld.%lld%s", whole, frac, suffix];
	} else {
		long long whole = (long long)round(val);
		return [NSString stringWithFormat:@"%lld%s", whole, suffix];
	}
}

NSString *TGCompactCount(int64_t n) {
	if (n < 1000) {
		return [NSString stringWithFormat:@"%lld", (long long)n];
	}
	if (n >= 999500000LL) {
		return TGFormatScaled(n, 1000000000.0, "B");
	}
	if (n >= 999500LL) {
		return TGFormatScaled(n, 1000000.0, "M");
	}
	return TGFormatScaled(n, 1000.0, "K");
}

NSString *TGUIFormatChatDate(NSTimeInterval unix, NSTimeInterval now) {
	if (unix <= 0)
		return @"";
	char buf[TGDateFormatBufferSize + 1] = {0};
	size_t len = TGChatDateFormat((time_t)unix, (time_t)now, buf, TGDateFormatBufferSize);
	return len ? [[NSString alloc] initWithBytes:buf length:len
									   encoding:NSUTF8StringEncoding] : @"";
}

NSString *TGUIFormatDate(NSTimeInterval unix, NSDateFormatterStyle date,
		NSDateFormatterStyle time, NSString *language) {
	if (unix <= 0)
		return nil;
	static NSMutableDictionary *formatters = nil;
	NSString *key = [NSString stringWithFormat:@"%d/%d/%@", (int)date, (int)time,
			language ?: @""];
	NSDateFormatter *formatter = nil;
	@synchronized ([NSDateFormatter class]) {
		if (!formatters)
			formatters = [NSMutableDictionary dictionary];
		formatter = formatters[key];
		if (!formatter){
			formatter = [[NSDateFormatter alloc] init];
			formatter.dateStyle = date;
			formatter.timeStyle = time;
			formatter.locale = language.length
					? [NSLocale localeWithLocaleIdentifier:language]
					: [NSLocale currentLocale];
			formatters[key] = formatter;
		}
		return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:unix]];
	}
}

NSString *TGAppDate(NSTimeInterval unix, NSDateFormatterStyle date,
		NSDateFormatterStyle time) {
	return TGUIFormatDate(unix, date, time, TGAppLanguage());
}

NSString *TGBytesForLanguage(long long bytes, NSString *language) {
	// ponytail: one cached formatter, main-thread callers only (rows and cells).
	static NSNumberFormatter *formatter = nil;
	static NSString *formatterLanguage = nil;
	if (!formatter)
		formatter = [[NSNumberFormatter alloc] init];
	NSString *code = language.length ? language : @"en";
	if (![formatterLanguage isEqualToString:code]){
		formatterLanguage = [code copy];
		formatter.locale = [NSLocale localeWithLocaleIdentifier:code];
		formatter.numberStyle = NSNumberFormatterDecimalStyle;
	}
	if (bytes <= 0)
		return TGLocalizedFormat(@"%@ KB", @"0");
	if (bytes < 1024)
		return TGLocalizedFormat(@"%@ B", [NSString stringWithFormat:@"%lld", bytes]);
	if (bytes < 1024 * 1024){
		formatter.maximumFractionDigits = 0;
		return TGLocalizedFormat(@"%@ KB",
				[formatter stringFromNumber:@(bytes / 1024.0)]);
	}
	if (bytes < 1024LL * 1024 * 1024){
		formatter.maximumFractionDigits = 1;
		return TGLocalizedFormat(@"%@ MB",
				[formatter stringFromNumber:@(bytes / (1024.0 * 1024.0))]);
	}
	formatter.maximumFractionDigits = 2;
	return TGLocalizedFormat(@"%@ GB",
			[formatter stringFromNumber:@(bytes / (1024.0 * 1024.0 * 1024.0))]);
}

NSString *TGBytes(long long bytes) {
	return TGBytesForLanguage(bytes, TGAppLanguage());
}

static NSString *TGEntityTypeName(NSDictionary *entity) {
	id type = entity[@"type"];
	if ([type isKindOfClass:NSDictionary.class] && [type[@"@type"] isKindOfClass:NSString.class])
		return type[@"@type"];
	return [type isKindOfClass:NSString.class] ? type : nil;
}

NSString *TGDateEntityText(int64_t unixTime, NSDictionary *formattingType,
		NSTimeInterval now) {
	if (![formattingType isKindOfClass:NSDictionary.class] || unixTime <= 0)
		return nil;
	NSString *kind = formattingType[@"@type"];
	if ([kind isEqualToString:@"dateTimeFormattingTypeRelative"]){
		int64_t value = (int64_t)now - unixTime;
		BOOL past = value > 0;
		int64_t gap = past ? value : -value;
		int64_t count;
		NSString *one, *other;
		if (gap < 60){
			count = gap;
			one = past ? @"%@ second ago" : @"in %@ second";
			other = past ? @"%@ seconds ago" : @"in %@ seconds";
		} else if (gap <= 3600){
			count = (int64_t)llround(gap / 60.0);
			one = past ? @"%@ minute ago" : @"in %@ minute";
			other = past ? @"%@ minutes ago" : @"in %@ minutes";
		} else if (gap <= 86400){
			count = (int64_t)llround(gap / 3600.0);
			one = past ? @"%@ hour ago" : @"in %@ hour";
			other = past ? @"%@ hours ago" : @"in %@ hours";
		} else {
			count = (int64_t)llround(gap / 86400.0);
			one = past ? @"%@ day ago" : @"in %@ day";
			other = past ? @"%@ days ago" : @"in %@ days";
		}
		return TGLocalizedPluralValue(one, other, [NSString stringWithFormat:@"%lld", count],
				(NSInteger)count);
	}
	if (![kind isEqualToString:@"dateTimeFormattingTypeAbsolute"])
		return nil;
	NSString *datePrecision = formattingType[@"date_precision"][@"@type"];
	NSString *timePrecision = formattingType[@"time_precision"][@"@type"];
	NSDateFormatterStyle dateStyle =
			[datePrecision isEqualToString:@"dateTimePartPrecisionLong"] ? NSDateFormatterLongStyle :
			[datePrecision isEqualToString:@"dateTimePartPrecisionShort"] ? NSDateFormatterShortStyle :
			NSDateFormatterNoStyle;
	NSDateFormatterStyle timeStyle =
			[timePrecision isEqualToString:@"dateTimePartPrecisionLong"] ? NSDateFormatterMediumStyle :
			[timePrecision isEqualToString:@"dateTimePartPrecisionShort"] ? NSDateFormatterShortStyle :
			NSDateFormatterNoStyle;
	NSMutableString *day = [NSMutableString string];
	if ([formattingType[@"show_day_of_week"] boolValue]){
		static NSString *const names[] = {@"Sunday", @"Monday", @"Tuesday", @"Wednesday",
				@"Thursday", @"Friday", @"Saturday"};
		static NSString *const shortNames[] = {@"Sun", @"Mon", @"Tue", @"Wed", @"Thu",
				@"Fri", @"Sat"};
		time_t t = (time_t)unixTime;
		struct tm parts;
		localtime_r(&t, &parts);
		int wday = parts.tm_wday % 7;
		[day appendString:TGLocalized(dateStyle == NSDateFormatterShortStyle
				? shortNames[wday] : names[wday])];
	}
	if (dateStyle != NSDateFormatterNoStyle){
		if (day.length)
			[day appendString:@" "];
		[day appendString:TGAppDate(unixTime, dateStyle, NSDateFormatterNoStyle) ?: @""];
	}
	NSString *time = timeStyle != NSDateFormatterNoStyle
			? TGAppDate(unixTime, NSDateFormatterNoStyle, timeStyle) : nil;
	if (time.length && day.length)
		return [NSString stringWithFormat:TGLocalizedKey(@"Time.AtPreciseDate", @"%@ at %@"),
				day, time];
	return time.length ? time : (day.length ? [day copy] : nil);
}

NSString *TGApplyDateEntities(NSString *text, NSArray *entities, NSTimeInterval now,
		NSArray **outEntities) {
	BOOL any = NO;
	for (NSDictionary *e in entities)
		if ([e isKindOfClass:NSDictionary.class] &&
			[TGEntityTypeName(e) isEqualToString:@"textEntityTypeDateTime"]){
			any = YES;
			break;
		}
	if (!any || !text.length)
		return nil;
	// Replacements move every entity after them, so they are made in text
	// order with a running shift; one that began inside replaced words has
	// nothing left to point at and is dropped.
	NSArray *ordered = [entities sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
		NSInteger x = [a isKindOfClass:NSDictionary.class] ? [a[@"offset"] integerValue] : 0;
		NSInteger y = [b isKindOfClass:NSDictionary.class] ? [b[@"offset"] integerValue] : 0;
		return x < y ? NSOrderedAscending : (x > y ? NSOrderedDescending : NSOrderedSame);
	}];
	NSMutableString *out = [text mutableCopy];
	NSMutableArray *moved = [NSMutableArray arrayWithCapacity:entities.count];
	NSInteger shift = 0, replacedEnd = -1;
	BOOL changed = NO;
	for (NSDictionary *e in ordered){
		if (![e isKindOfClass:NSDictionary.class])
			continue;
		NSInteger offset = [e[@"offset"] integerValue], length = [e[@"length"] integerValue];
		if (offset < replacedEnd)
			continue;
		NSInteger at = offset + shift;
		if (at < 0 || length <= 0 || at + length > (NSInteger)out.length)
			continue;
		NSMutableDictionary *copy = [e mutableCopy];
		copy[@"offset"] = @(at);
		NSString *words = nil;
		if ([TGEntityTypeName(e) isEqualToString:@"textEntityTypeDateTime"])
			words = TGDateEntityText([e[@"type"][@"unix_time"] longLongValue],
					e[@"type"][@"formatting_type"], now);
		if (words.length){
			[out replaceCharactersInRange:NSMakeRange((NSUInteger)at, (NSUInteger)length)
							   withString:words];
			copy[@"length"] = @(words.length);
			shift += (NSInteger)words.length - length;
			replacedEnd = offset + length;
			changed = YES;
		}
		[moved addObject:copy];
	}
	if (!changed)
		return nil;
	if (outEntities)
		*outEntities = moved;
	return out;
}

static NSString *const kMediaTimestampScheme = @"tg-media-timestamp:";

NSString *TGMediaTimestampLink(int32_t seconds) {
	return [kMediaTimestampScheme stringByAppendingFormat:@"%d", MAX(0, seconds)];
}

int32_t TGMediaTimestampFromLink(NSString *link) {
	if (![link isKindOfClass:NSString.class] || ![link hasPrefix:kMediaTimestampScheme])
		return -1;
	return (int32_t)[[link substringFromIndex:kMediaTimestampScheme.length] intValue];
}
