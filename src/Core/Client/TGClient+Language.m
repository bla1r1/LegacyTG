//
// TGClient+Language.m - the language page's server half, country data, and
// the two text tools behind the composer's formatting preview.
//
#import "TGClientInternal.h"
#import "TGLocalization.h"

/// The localization target this client reads. Telegram ships one pack per
/// target, and the user clients all read the "ios" target.
/// The synchronous text functions all have the same shape: try execute, and
/// fall back to the request loop where the dylib has no execute symbol.
static void TGTextAnswer(TGClient *client, NSDictionary *request,
						 void (^take)(NSDictionary *answer)) {
	NSDictionary *sync = [client executeSynchronously:request];
	if (sync){
		if (take) take(sync);
		return;
	}
	[client request:request completion:^(NSDictionary *answer){
		if (take) take(answer);
	}];
}

@implementation TGClient (Language)

#pragma mark - language packs

- (void)applyLanguagePackStringsUpdate:(NSDictionary *)update {
	NSString *packId = [update[@"language_pack_id"] isKindOfClass:NSString.class]
			? update[@"language_pack_id"] : @"";
	if (!packId.length)
		return;
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGLanguagePackStringsChangedNotification
						  object:self
						userInfo:@{@"packId" : packId}];
}

#pragma mark - countries

#pragma mark - formatting and translation

- (void)parseMarkdownText:(NSString *)text
			   completion:(void (^)(NSDictionary *))completion {
	if (!text.length){
		if (completion)
			completion(@{@"@type" : @"formattedText",
						 @"text" : @"",
						 @"entities" : @[]});
		return;
	}
	TGTextAnswer(self,
				 @{@"@type" : @"parseMarkdown",
				   @"text" : @{@"@type" : @"formattedText",
							   @"text" : text,
							   @"entities" : @[]}},
				 ^(NSDictionary *answer){
		if (!completion)
			return;
		if (![answer[@"@type"] isEqualToString:@"formattedText"]){
			completion(nil);
			return;
		}
		completion(@{
			@"@type" : @"formattedText",
			@"text" : answer[@"text"] ?: text,
			@"entities" : answer[@"entities"] ?: @[],
		});
	});
}

- (void)textEntitiesInText:(NSString *)text
				completion:(void (^)(NSArray *))completion {
	if (!text.length){
		if (completion) completion(@[]);
		return;
	}
	TGTextAnswer(self,
				 @{@"@type" : @"getTextEntities",
				   @"text" : text},
				 ^(NSDictionary *answer){
		if (!completion)
			return;
		if (![answer[@"@type"] isEqualToString:@"textEntities"]){
			completion(@[]);
			return;
		}
		completion(answer[@"entities"] ?: @[]);
	});
}

@end
