//
// TGDMTopicViewController - one topic in a channel direct messages chat:
// the topic record, its history, and the actions Telegram allows on it.
//
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"
#import "TGLocalization.h"

@interface TGDMTopicViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t topicId;
@property (nonatomic, strong) NSDictionary *topic;
@property (nonatomic, copy)   NSString *chatTitle;

@end

/// The action list in official order. Pure so a host test can pin the one
/// row that changes with the topic's unread mark.
static inline NSArray *TGDMTopicActionTitles(BOOL markedUnread) {
	NSMutableArray *titles = [NSMutableArray arrayWithObjects:
			TGLocalized(@"Send Message"),
			TGLocalized(@"Jump to Date"),
			TGLocalized(@"Read All Reactions"),
			TGLocalized(@"Unpin All Messages"),
			TGLocalized(@"Delete Messages"),
			TGLocalized(@"Delete All Messages"), nil];
	[titles insertObject:(markedUnread ? TGLocalized(@"Mark as Read")
			: TGLocalized(@"Mark as Unread")) atIndex:0];
	return titles;
}

/// Sender, unread counts, mark, paid-message state and the last message, in
/// the order the Topic section draws them.
static inline NSArray *TGDMTopicInfoPairs(NSDictionary *topic) {
	topic = topic ?: @{};
	NSString *sender = topic[@"senderName"];
	if (!sender.length)
		sender = [NSString stringWithFormat:@"%@ %@",
				topic[@"senderKind"] ?: @"user", topic[@"senderId"] ?: @(0)];
	NSString *marked = [topic[@"isMarkedUnread"] boolValue]
			? TGLocalized(@"Yes") : TGLocalized(@"No");
	id lastValue = topic[@"lastMessage"];
	NSString *last = @"—";
	if ([lastValue isKindOfClass:NSDictionary.class]){
		NSString *text = lastValue[@"text"];
		last = text.length ? text : TGLocalized(@"(media)");
	}
	return @[
		@[TGLocalized(@"Sender"), sender],
		@[TGLocalized(@"Unread"), [NSString stringWithFormat:@"%@, %@",
				[NSString stringWithFormat:TGLocalized(@"%@ messages"),
						topic[@"unread"] ?: @(0)],
				[NSString stringWithFormat:TGLocalized(@"%@ reactions"),
						topic[@"unreadReactions"] ?: @(0)]]],
		@[TGLocalized(@"Mark as Unread"), marked],
		@[TGLocalized(@"Paid messages"), [topic[@"canSendUnpaid"] boolValue]
				? TGLocalized(@"Unpaid allowed") : TGLocalized(@"Paid only")],
		@[TGLocalized(@"Last message"),
		  [last isKindOfClass:NSString.class] ? last : @"—"],
	];
}

/// A history row's title: the message text, or the kind's name when the
/// message has no text.
static inline NSString *TGDMTopicMessageTitle(NSDictionary *message) {
	NSString *text = message[@"text"];
	if (text.length)
		return text;
	NSString *kind = message[@"kind"];
	if ([kind isEqualToString:@"messagePhoto"]) return TGLocalized(@"Photo");
	if ([kind isEqualToString:@"messageVideo"]) return TGLocalized(@"Video");
	if ([kind isEqualToString:@"messageAudio"]) return TGLocalized(@"Audio");
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGLocalized(@"Voice Message");
	if ([kind isEqualToString:@"messageDocument"]) return TGLocalized(@"File");
	if ([kind isEqualToString:@"messageSticker"]) return TGLocalized(@"Sticker");
	return TGLocalized(@"Message");
}

/// A history row's subtitle: the date, prefixed with "You" when outgoing.
static inline NSString *TGDMTopicMessageDetail(NSDictionary *message) {
	NSNumber *date = message[@"date"];
	NSString *when = [date isKindOfClass:NSNumber.class] && date.doubleValue > 0
			? [NSDateFormatter localizedStringFromDate:
					[NSDate dateWithTimeIntervalSince1970:date.doubleValue]
					dateStyle:NSDateFormatterShortStyle
					timeStyle:NSDateFormatterShortStyle]
			: @"";
	return [message[@"outgoing"] boolValue]
			? [NSString stringWithFormat:@"%@ · %@", TGLocalized(@"You"), when]
			: when;
}
