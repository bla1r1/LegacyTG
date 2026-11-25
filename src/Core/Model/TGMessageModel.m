//
// TGMessageModel.m - see TGMessageModel.h.
//
#import "TGMessageModel.h"

@implementation TGMessageModel {
	NSDictionary *_extra;
	NSArray *_allKeys;
}

static NSSet *TGMessageHotKeys(void) {
	static NSSet *keys;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		keys = [NSSet setWithObjects:
				@"id", @"senderId", @"date", @"viewCount", @"replyCount",
				@"outgoing", @"service", @"edited", @"channelPost", @"canComment",
				@"sending", @"kind", @"text", @"entities", @"reactionGroups", nil];
	});
	return keys;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
	if (![dict isKindOfClass:NSDictionary.class])
		return nil;
	self = [super init];
	if (self) {
		_messageId   = [dict[@"id"] longLongValue];
		_senderId    = [dict[@"senderId"] longLongValue];
		_date        = [dict[@"date"] intValue];
		_viewCount   = [dict[@"viewCount"] intValue];
		_replyCount  = [dict[@"replyCount"] intValue];
		_outgoing    = [dict[@"outgoing"] boolValue];
		_service     = [dict[@"service"] boolValue];
		_edited      = [dict[@"edited"] boolValue];
		_channelPost = [dict[@"channelPost"] boolValue];
		_canComment  = [dict[@"canComment"] boolValue];
		_sending     = [dict[@"sending"] boolValue];
		_kind        = [dict[@"kind"] isKindOfClass:NSString.class] ? [dict[@"kind"] copy] : @"";
		_text        = [dict[@"text"] isKindOfClass:NSString.class] ? [dict[@"text"] copy] : @"";
		_entities    = [dict[@"entities"] isKindOfClass:NSArray.class] ? dict[@"entities"] : @[];
		_reactionGroups = [dict[@"reactionGroups"] isKindOfClass:NSArray.class] ? dict[@"reactionGroups"] : @[];

		NSSet *hot = TGMessageHotKeys();
		NSMutableDictionary *rest = [NSMutableDictionary dictionaryWithCapacity:dict.count];
		[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			if (![hot containsObject:key])
				rest[key] = obj;
		}];
		_extra = [rest copy];
	}
	return self;
}

- (NSUInteger)count {
	return _extra.count + (_sending ? 15 : 14);
}

- (id)objectForKey:(id)aKey {
	if (![aKey isKindOfClass:NSString.class])
		return nil;
	NSString *k = (NSString *)aKey;
	if ([k isEqualToString:@"id"]) return @(_messageId);
	if ([k isEqualToString:@"senderId"]) return @(_senderId);
	if ([k isEqualToString:@"date"]) return @(_date);
	if ([k isEqualToString:@"viewCount"]) return @(_viewCount);
	if ([k isEqualToString:@"replyCount"]) return @(_replyCount);
	if ([k isEqualToString:@"outgoing"]) return @(_outgoing);
	if ([k isEqualToString:@"service"]) return @(_service);
	if ([k isEqualToString:@"edited"]) return @(_edited);
	if ([k isEqualToString:@"channelPost"]) return @(_channelPost);
	if ([k isEqualToString:@"canComment"]) return @(_canComment);
	if ([k isEqualToString:@"sending"]) return _sending ? @YES : nil;
	if ([k isEqualToString:@"kind"]) return _kind;
	if ([k isEqualToString:@"text"]) return _text;
	if ([k isEqualToString:@"entities"]) return _entities;
	if ([k isEqualToString:@"reactionGroups"]) return _reactionGroups;
	return _extra[k];
}

- (NSEnumerator *)keyEnumerator {
	if (!_allKeys) {
		NSMutableArray *keys = [NSMutableArray arrayWithObjects:
				@"id", @"senderId", @"date", @"viewCount", @"replyCount",
				@"outgoing", @"service", @"edited", @"channelPost", @"canComment",
				@"kind", @"text", @"entities", @"reactionGroups", nil];
		if (_sending)
			[keys addObject:@"sending"];
		[keys addObjectsFromArray:_extra.allKeys];
		_allKeys = [keys copy];
	}
	return [_allKeys objectEnumerator];
}

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

@end
