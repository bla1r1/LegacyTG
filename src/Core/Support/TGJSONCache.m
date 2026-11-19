//
// TGJSONCache.m - see TGJSONCache.h.
//
#import "TGJSONCache.h"
#import "TGBase64.h"

static id TGJSONSafe(id value) {
	if ([value isKindOfClass:NSData.class])
		return @{ @"$data" : TGBase64Encode(value) ?: @"" };
	if ([value isKindOfClass:NSDictionary.class]) {
		NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:[value count]];
		[(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			out[key] = TGJSONSafe(obj);
		}];
		return out;
	}
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
		for (id obj in (NSArray *)value)
			[out addObject:TGJSONSafe(obj)];
		return out;
	}
	return value;
}

static id TGJSONRestored(id value) {
	if ([value isKindOfClass:NSDictionary.class]) {
		NSDictionary *dict = value;
		if (dict.count == 1 && [dict[@"$data"] isKindOfClass:NSString.class])
			return TGBase64Decode(dict[@"$data"]) ?: [NSData data];
		NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:dict.count];
		[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			out[key] = TGJSONRestored(obj);
		}];
		return out;
	}
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *out = [NSMutableArray arrayWithCapacity:[value count]];
		for (id obj in (NSArray *)value)
			[out addObject:TGJSONRestored(obj)];
		return out;
	}
	return value;
}

BOOL TGJSONCacheWrite(id object, NSString *path) {
	if (!object || !path.length)
		return NO;
	id json = TGJSONSafe(object);
	if (![NSJSONSerialization isValidJSONObject:json])
		return NO;
	NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
	if (!data)
		return NO;
	[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
			withIntermediateDirectories:YES attributes:nil error:NULL];
	return [data writeToFile:path atomically:YES];
}

id TGJSONCacheRead(NSString *path) {
	NSData *data = path.length ? [NSData dataWithContentsOfFile:path] : nil;
	if (!data.length)
		return nil;
	id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
	return object ? TGJSONRestored(object) : nil;
}
