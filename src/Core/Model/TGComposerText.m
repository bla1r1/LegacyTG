//
// TGComposerText.m - the composer's text with the custom emoji in it.
//
#import "TGComposerText.h"

@interface TGComposerText () {
	NSString *_text;
	NSArray *_customEmoji;
}
@end

@implementation TGComposerText

@synthesize text = _text;
@synthesize customEmoji = _customEmoji;

- (instancetype)initWithText:(NSString *)text entities:(NSArray *)entities {
	if ((self = [super init])) {
		_text = [text isKindOfClass:[NSString class]] ? [text copy] : @"";

		if (![entities isKindOfClass:[NSArray class]]) {
			_customEmoji = @[];
			return self;
		}

		NSMutableArray *parsed = [NSMutableArray array];
		for (id item in entities) {
			if (![item isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *dict = (NSDictionary *)item;

			// Extract custom emoji id from TDLib textEntityTypeCustomEmoji or raw customEmojiId
			id typeObj = dict[@"type"];
			id rawId = nil;
			if ([typeObj isKindOfClass:[NSDictionary class]] &&
				[typeObj[@"@type"] isEqualToString:@"textEntityTypeCustomEmoji"]) {
				rawId = typeObj[@"custom_emoji_id"];
			} else if (dict[@"customEmojiId"]) {
				rawId = dict[@"customEmojiId"];
			}

			if (![rawId isKindOfClass:[NSNumber class]] && ![rawId isKindOfClass:[NSString class]])
				continue;
			int64_t emojiId = [rawId longLongValue];
			if (emojiId == 0)
				continue;

			id offsetObj = dict[@"offset"];
			id lengthObj = dict[@"length"];
			if (!([offsetObj isKindOfClass:[NSNumber class]] || [offsetObj isKindOfClass:[NSString class]]) ||
				!([lengthObj isKindOfClass:[NSNumber class]] || [lengthObj isKindOfClass:[NSString class]]))
				continue;

			NSInteger offset = [offsetObj integerValue];
			NSInteger length = [lengthObj integerValue];
			if (offset < 0 || length <= 0)
				continue;
			if ((NSUInteger)(offset + length) > _text.length)
				continue;

			[parsed addObject:@{
				@"offset"        : @(offset),
				@"length"        : @(length),
				@"customEmojiId" : @(emojiId),
			}];
		}

		[parsed sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
			NSInteger offA = [a[@"offset"] integerValue];
			NSInteger offB = [b[@"offset"] integerValue];
			if (offA < offB) return NSOrderedAscending;
			if (offA > offB) return NSOrderedDescending;
			return NSOrderedSame;
		}];

		// Drop any overlapping entities from invalid input
		NSMutableArray *valid = [NSMutableArray arrayWithCapacity:parsed.count];
		NSInteger lastEnd = 0;
		for (NSDictionary *e in parsed) {
			NSInteger off = [e[@"offset"] integerValue];
			NSInteger len = [e[@"length"] integerValue];
			if (off >= lastEnd) {
				[valid addObject:e];
				lastEnd = off + len;
			}
		}
		_customEmoji = [valid copy];
	}
	return self;
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string {
	NSString *replacement = [string isKindOfClass:[NSString class]] ? string : @"";

	// Past the end clamps to the end
	if (range.location > _text.length) {
		range.location = _text.length;
		range.length = 0;
	}
	if (range.location + range.length > _text.length)
		range.length = _text.length - range.location;

	NSMutableString *mText = [_text mutableCopy];
	[mText replaceCharactersInRange:range withString:replacement];
	_text = [mText copy];

	NSInteger delta = (NSInteger)replacement.length - (NSInteger)range.length;
	NSMutableArray *kept = [NSMutableArray arrayWithCapacity:_customEmoji.count];

	for (NSDictionary *entity in _customEmoji) {
		NSInteger off = [entity[@"offset"] integerValue];
		NSInteger len = [entity[@"length"] integerValue];
		int64_t eid = [entity[@"customEmojiId"] longLongValue];

		if ((NSInteger)(range.location + range.length) <= off) {
			// Entirely before the entity (or insert at its start boundary): shift offset
			[kept addObject:@{
				@"offset"        : @(off + delta),
				@"length"        : @(len),
				@"customEmojiId" : @(eid),
			}];
		} else if ((NSInteger)range.location >= off + len) {
			// Entirely after the entity (or insert at its end boundary): keep as is
			[kept addObject:entity];
		}
		// Overlapping or strictly inside: dropped
	}
	_customEmoji = [kept copy];
}

- (void)insertCustomEmoji:(int64_t)emojiId fallback:(NSString *)fallback atIndex:(NSUInteger)index {
	if (![fallback isKindOfClass:[NSString class]] || fallback.length == 0)
		return;

	NSUInteger clampedIndex = MIN(index, _text.length);
	[self replaceCharactersInRange:NSMakeRange(clampedIndex, 0) withString:fallback];

	NSDictionary *newEntity = @{
		@"offset"        : @(clampedIndex),
		@"length"        : @(fallback.length),
		@"customEmojiId" : @(emojiId),
	};

	NSMutableArray *list = [_customEmoji mutableCopy];
	[list addObject:newEntity];
	[list sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		NSInteger offA = [a[@"offset"] integerValue];
		NSInteger offB = [b[@"offset"] integerValue];
		if (offA < offB) return NSOrderedAscending;
		if (offA > offB) return NSOrderedDescending;
		return NSOrderedSame;
	}];
	_customEmoji = [list copy];
}

- (void)resetText:(NSString *)text {
	NSString *newText = [text isKindOfClass:[NSString class]] ? [text copy] : @"";
	NSMutableArray *kept = [NSMutableArray arrayWithCapacity:_customEmoji.count];

	for (NSDictionary *entity in _customEmoji) {
		NSInteger off = [entity[@"offset"] integerValue];
		NSInteger len = [entity[@"length"] integerValue];
		if (off < 0 || len <= 0)
			continue;

		NSRange r = NSMakeRange((NSUInteger)off, (NSUInteger)len);
		if (r.location + r.length > _text.length || r.location + r.length > newText.length)
			continue;

		NSString *oldSub = [_text substringWithRange:r];
		NSString *newSub = [newText substringWithRange:r];
		if ([newSub isEqualToString:oldSub])
			[kept addObject:entity];
	}

	_text = newText;
	_customEmoji = [kept copy];
}

- (NSDictionary *)formattedText {
	NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSUInteger len = _text.length;
	NSUInteger start = 0;
	while (start < len && [ws characterIsMember:[_text characterAtIndex:start]])
		start++;

	NSUInteger end = len;
	while (end > start && [ws characterIsMember:[_text characterAtIndex:end - 1]])
		end--;

	NSString *trimmed = (start < end) ? [_text substringWithRange:NSMakeRange(start, end - start)] : @"";
	NSMutableArray *entities = [NSMutableArray array];

	for (NSDictionary *e in _customEmoji) {
		NSInteger off = [e[@"offset"] integerValue];
		NSInteger l = [e[@"length"] integerValue];
		int64_t eid = [e[@"customEmojiId"] longLongValue];

		// Keep only entities fully inside the untrimmed range
		if (off >= (NSInteger)start && (off + l) <= (NSInteger)end) {
			[entities addObject:@{
				@"@type"  : @"textEntity",
				@"offset" : @(off - (NSInteger)start),
				@"length" : @(l),
				@"type"   : @{
					@"@type"           : @"textEntityTypeCustomEmoji",
					@"custom_emoji_id" : @(eid),
				},
			}];
		}
	}

	return @{
		@"@type"    : @"formattedText",
		@"text"     : trimmed,
		@"entities" : [entities copy],
	};
}

@end
