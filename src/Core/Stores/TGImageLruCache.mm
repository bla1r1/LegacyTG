//
// TGImageLruCache.mm - Objective-C bounded LRU cache adapter over C++ TGLruCache.
//
#import "TGImageLruCache.h"
#import "TGLruCache.hpp"

static inline int64_t TGKeyToInt64(id key) {
	if (!key) return 0;
	if ([key isKindOfClass:[NSNumber class]]) {
		return [(NSNumber *)key longLongValue];
	}
	if ([key isKindOfClass:[NSString class]]) {
		NSString *str = (NSString *)key;
		NSUInteger len = str.length;
		if (len > 0) {
			BOOL isPureInt = YES;
			for (NSUInteger i = 0; i < len; i++) {
				unichar c = [str characterAtIndex:i];
				if (i == 0 && (c == '-' || c == '+')) continue;
				if (c < '0' || c > '9') {
					isPureInt = NO;
					break;
				}
			}
			if (isPureInt) {
				return [str longLongValue];
			}
		}
		// 64-bit FNV-1a hash so formatted string keys like "123:20" and "123:40"
		// or non-numeric keys never collide.
		uint64_t hash = 14695981039346656037ULL;
		const char *bytes = [str UTF8String];
		if (bytes) {
			while (*bytes) {
				hash ^= (uint64_t)(unsigned char)(*bytes++);
				hash *= 1099511628211ULL;
			}
		}
		return (int64_t)hash;
	}
	if ([key respondsToSelector:@selector(longLongValue)]) {
		return [key longLongValue];
	}
	return (int64_t)[key hash];
}

@interface TGImageLruCache () {
	TGLruCache<int64_t, UIImage *> _cache;
}
@end

@implementation TGImageLruCache

- (instancetype)initWithCapacity:(NSUInteger)capacity {
	if ((self = [super init])) {
		_cache.set_capacity(capacity ? capacity : 50);
	}
	return self;
}

- (instancetype)init {
	return [self initWithCapacity:50];
}

- (UIImage *)objectForKeyedSubscript:(id)key {
	if (!key) return nil;
	UIImage *val = nil;
	if (_cache.get(TGKeyToInt64(key), val)) {
		return val;
	}
	return nil;
}

- (void)setObject:(UIImage *)image forKeyedSubscript:(id)key {
	if (!key) return;
	int64_t k = TGKeyToInt64(key);
	if (image) {
		_cache.put(k, image);
	} else {
		_cache.remove(k);
	}
}

- (UIImage *)objectForKey:(id)key {
	return [self objectForKeyedSubscript:key];
}

- (void)setObject:(UIImage *)image forKey:(id)key {
	[self setObject:image forKeyedSubscript:key];
}

- (void)removeObjectForKey:(id)key {
	if (key) {
		_cache.remove(TGKeyToInt64(key));
	}
}

- (void)removeAllObjects {
	_cache.clear();
}

- (NSUInteger)count {
	return _cache.size();
}

- (NSUInteger)capacity {
	return _cache.capacity();
}

@end


@interface TGObjectLruCache () {
	TGLruCache<int64_t, id> _cache;
}
@end

@implementation TGObjectLruCache

- (instancetype)initWithCapacity:(NSUInteger)capacity {
	if ((self = [super init])) {
		_cache.set_capacity(capacity ? capacity : 1000);
	}
	return self;
}

- (instancetype)init {
	return [self initWithCapacity:1000];
}

- (id)objectForKeyedSubscript:(id)key {
	if (!key) return nil;
	id val = nil;
	if (_cache.get(TGKeyToInt64(key), val)) {
		return val;
	}
	return nil;
}

- (void)setObject:(id)object forKeyedSubscript:(id)key {
	if (!key) return;
	int64_t k = TGKeyToInt64(key);
	if (object) {
		_cache.put(k, object);
	} else {
		_cache.remove(k);
	}
}

- (id)objectForKey:(id)key {
	return [self objectForKeyedSubscript:key];
}

- (void)setObject:(id)object forKey:(id)key {
	[self setObject:object forKeyedSubscript:key];
}

- (void)removeObjectForKey:(id)key {
	if (key) {
		_cache.remove(TGKeyToInt64(key));
	}
}

- (void)removeAllObjects {
	_cache.clear();
}

- (NSUInteger)count {
	return _cache.size();
}

- (NSUInteger)capacity {
	return _cache.capacity();
}

@end
