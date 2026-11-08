#import "TGClient+Base.h"

@interface TGClient (ChatReporting)

/// Reporting is a conversation: the first call answers with the reasons to
/// choose from, and the chosen option id goes in the second. The completion
/// gets either a title and a list of options - each with "id" and "text" -
/// to put to the user, or an empty list and `done` once it is accepted.
- (void)reportChat:(int64_t)chatId
		  optionId:(NSString *)optionId
			  text:(NSString *)text
		completion:(void (^)(NSString *title, NSArray *options, BOOL done))completion;

/// Dismisses the "Report spam / Add to contacts" bar above a chat from
/// someone this account does not know.
- (void)removeActionBarInChat:(int64_t)chatId;

@end
