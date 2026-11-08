#import "TGClient+ChatReporting.h"
#import "TGClientInternal.h"
#ifndef typeof
#define typeof __typeof__
#endif


@implementation TGClient (ChatReporting)

#pragma mark - reporting

/// Reporting is a conversation, not a call: the first request comes back with
/// the reasons to choose from, and the chosen one goes in the second. The
/// completion is called either with a list of options to put to the user -
/// each carrying "id" and "text" - or with an empty list once it is done.
- (void)reportChat:(int64_t)chatId
		  optionId:(NSString *)optionId
			  text:(NSString *)text
		completion:(void (^)(NSString *title, NSArray *options, BOOL done))completion {
	[self request:@{
		@"@type"       : @"reportChat",
		@"chat_id"     : @(chatId),
		// bytes travel as base64 in tdjson, and an option id is handed back
		// exactly as it arrived, so it is carried as the string it came as.
		@"option_id"   : optionId ?: @"",
		@"message_ids" : @[],
		@"text"        : text ?: @"",
	} completion:^(NSDictionary *result){
		if (!completion)
			return;
		NSString *kind = result[@"@type"] ?: @"";
		if ([kind isEqualToString:@"reportChatResultOptionRequired"]){
			NSMutableArray *options = [NSMutableArray array];
			for (NSDictionary *option in result[@"options"]){
				NSString *optionText = option[@"text"];
				if (optionText.length)
					[options addObject:@{@"id"   : option[@"id"] ?: @"",
										 @"text" : optionText}];
			}
			completion(result[@"title"], options, NO);
			return;
		}
		// Ok, or a kind this screen has no step for - a free-text reason, or
		// a report that wants the messages named. Either way there is nothing
		// more to ask here.
		completion(nil, @[], [kind isEqualToString:@"reportChatResultOk"]);
	}];
}

/// The "Report spam / Add to contacts" bar above a chat from someone unknown.
- (void)removeActionBarInChat:(int64_t)chatId {
	[self send:@{@"@type" : @"removeChatActionBar", @"chat_id" : @(chatId)}];
}

@end
