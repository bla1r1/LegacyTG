#import "TGChatViewControllerInternal.h"
#import "TGForwardPicker.h"
#import "TGPopupMenu.h"
#import "TGStyle.h"
#import "TGAlertSheet.h"
#import "TGReactionPicker.h"
#import "TGDateFormat.h"
#import "TGOptions.h"
#import "TGMessageStore.h"
#import "TGInstantViewController.h"
#import "TGMessageAudienceViewController.h"
#import "TGSponsoredMessagesViewController.h"
#import "TGGameScoresViewController.h"
#import "TGPollPresentation.h"
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>

@implementation TGChatViewController (MessageSheets)

#pragma mark - message record sheets

/// One-shared-shape date for the sheets: three shapes the chat list shows.
static NSString *TGSheetDate(NSTimeInterval unix) {
	char buf[TGDateFormatBufferSize + 1] = {0};
	size_t len = TGChatDateFormat((time_t)unix, (time_t)TGOptionNow(), buf, TGDateFormatBufferSize);
	return len ? [[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding]
			   : @"";
}

/// The helper behind five of the menu rows: the action message is read into
/// a bound pair, since a sheet can arrive after the chat scrolled on.
- (void)withActionMessage:(void (^)(int64_t messageId, int64_t chatId, NSDictionary *m))block {
	NSDictionary *m = self.actionMessage;
	if (!m || !block)
		return;
	block([m[@"id"] longLongValue], self.chatId, m);
}

/// Who read this message. The list screen asks TDLib for the viewers and,
/// when a private chat refuses that, shows the read date and its reason in
/// the same place - so the row never opens an empty table.
- (void)showViewersOfActionMessage {
	int64_t messageId = [self.actionMessage[@"id"] longLongValue];
	if (!messageId)
		return;
	TGMessageAudienceViewController *people =
			[[TGMessageAudienceViewController alloc]
					initWithKind:TGMessageAudienceKindViewers
							chat:self.chatId
						 message:messageId
						   emoji:nil
				   customEmojiId:0];
	people.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:people animated:YES];
}

/// Every public copy of this message TDLib knows about: channels and open
/// groups that forwarded it. A copy opens where it was posted, at the same
/// message id the forward carries.
- (void)showPublicForwardsOfActionMessage {
	__weak typeof(self) weakSelf = self;
	[self withActionMessage:^(int64_t messageId, int64_t chatId, NSDictionary *m){
		[[TGMessageStore shared] publicForwardsOfMessage:messageId
											 inChat:chatId
										 completion:^(NSArray *forwards){
			TGChatViewController *me = weakSelf;
			if (!me)
				return;
			if (!forwards.count){
				[TGAlertSheet showMessage:@"Telegram knows no public copies "
							@"of this message." title:@"Forwarded Messages"
										inView:me.view];
				return;
			}
			NSMutableArray *rows = [NSMutableArray array];
			for (NSDictionary *copy in forwards){
				int64_t where = [copy[@"chat_id"] longLongValue];
				NSString *title = where
						? ([[TGMessageStore shared] titleForChat:where] ?: @"A chat")
						: @"Unknown chat";
				[rows addObject:[NSString stringWithFormat:@"%@  ·  #%@",
						title, copy[@"message_id"] ?: @""]];
			}
			[TGAlertSheet showChoices:rows
								title:@"Forwarded Messages"
					 destructiveIndex:-1
							   inView:me.view
							 onChoice:^(NSInteger index){
				NSDictionary *copy = forwards[(NSUInteger)index];
				int64_t where = [copy[@"chat_id"] longLongValue];
				int64_t copyId = [copy[@"message_id"] longLongValue];
				if (!where || !copyId)
					return;
				TGChatViewController *vc = [[TGChatViewController alloc] init];
				vc.chatId = where;
				vc.chatTitle = [[TGMessageStore shared] titleForChat:where] ?: @"";
				vc.isGroup = YES;
				vc.initialMessageId = copyId;
				vc.hidesBottomBarWhenPushed = YES;
				[me.navigationController pushViewController:vc animated:YES];
			}];
		}];
	}];
}

- (void)showReactorsOfActionMessage {
	[self showReactorsOfMessage:self.actionMessage];
}

/// The menu's Reaction row, for a message with groups the chips already
/// summarise. One group opens its people directly; several ask which group
/// first, because a chip is the only thing that names one without asking.
- (void)showReactorsOfMessage:(NSDictionary *)m {
	NSArray *groups = m[@"reactionGroups"];
	if (![groups isKindOfClass:NSArray.class] || !groups.count){
		[TGAlertSheet showMessage:@"No Reactions"
							title:@"Reactions"
						   inView:self.view];
		return;
	}
	if (groups.count == 1){
		NSDictionary *group = groups.firstObject;
		[self showReactorsOfMessage:m
							  emoji:group[@"emoji"]
					  customEmojiId:[group[@"customEmojiId"] longLongValue]];
		return;
	}

	__weak typeof(self) weakSelf = self;
	NSMutableArray *lines = [NSMutableArray arrayWithCapacity:groups.count];
	for (NSDictionary *group in groups){
		NSString *emoji = group[@"emoji"];
		NSString *name = emoji.length ? emoji : @"★";
		[lines addObject:[NSString stringWithFormat:@"%@  ×%@", name,
						  group[@"count"] ?: @(0)]];
	}
	[TGAlertSheet showChoices:lines
						title:@"Reactions"
			 destructiveIndex:-1
					   inView:self.view
					 onChoice:^(NSInteger index){
		NSDictionary *group = groups[(NSUInteger)index];
		[weakSelf showReactorsOfMessage:m
								  emoji:group[@"emoji"]
						  customEmojiId:[group[@"customEmojiId"] longLongValue]];
	}];
}

/// The list itself: a pushed screen with one row per person, their picture,
/// when they reacted and the emoji they used. A chip calls this directly -
/// there is no intermediate sheet on the path a tap takes.
- (void)showReactorsOfMessage:(NSDictionary *)m
						emoji:(NSString *)emoji
				customEmojiId:(int64_t)customEmojiId {
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;
	TGMessageAudienceViewController *people =
			[[TGMessageAudienceViewController alloc]
					initWithKind:TGMessageAudienceKindReactions
							chat:self.chatId
						 message:messageId
						   emoji:emoji
				   customEmojiId:customEmojiId];
	people.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:people animated:YES];
}

- (void)showAuthorOfActionMessage {
	__weak typeof(self) weakSelf = self;
	[self withActionMessage:^(int64_t messageId, int64_t chatId, NSDictionary *m){
		[[TGMessageStore shared] authorOfMessage:messageId inChat:chatId completion:^(NSDictionary *user){
			TGChatViewController *me = weakSelf;
			if (!me || !user){
				[TGAlertSheet showMessage:@"Telegram names an author only for a "
										  @"post an anonymous admin made."
									 title:@"Author" inView:me.view];
				return;
			}
			NSString *name = [NSString stringWithFormat:@"%@ %@",
					user[@"first_name"] ?: @"", user[@"last_name"] ?: @""];
			[TGAlertSheet showMessage:name ?: @"The server named nobody"
							   title:@"Author" inView:me.view];
		}];
	}];
}

- (void)translateActionMessage {
	__weak typeof(self) weakSelf = self;
	[self withActionMessage:^(int64_t messageId, int64_t chatId, NSDictionary *m){
		NSString *language = [[NSLocale currentLocale] objectForKey:
				NSLocaleLanguageCode] ?: @"en";
		NSString *text = m[@"text"] ?: @"";
		// translateText keeps the text's entities and takes a tone, which is
		// what a plain message needs. translateMessageText remains the
		// fallback for a message with no flattened text, where Telegram can
		// still translate the content it holds.
		if (text.length){
			[[TGMessageStore shared] translateText:text toLanguageCode:language tone:@""
								  completion:^(NSString *translated){
				TGChatViewController *me = weakSelf;
				if (!me)
					return;
				if (translated.length){
					[TGAlertSheet showMessage:translated
									   title:@"Translation"
									   inView:me.view];
					return;
				}
				[[TGMessageStore shared] translateMessage:messageId inChat:chatId
											 toCode:language
										  completion:^(NSString *fallback){
					[TGAlertSheet showMessage:(fallback.length ? fallback : @"Not translatable")
									   title:@"Translation"
									   inView:me.view];
				}];
			}];
			return;
		}
		[[TGMessageStore shared] translateMessage:messageId inChat:chatId
									 toCode:language
								  completion:^(NSString *translated){
			TGChatViewController *me = weakSelf;
			if (!me) return;
			[TGAlertSheet showMessage:(translated.length ? translated : @"Not translatable")
							   title:@"Translation"
							   inView:me.view];
		}];
	}];
}

/// Where a phrase sits in this message, found by Telegram rather than by
/// NSString. The position is UTF-16 units, so it is the same number a
/// selection API on this OS would use.
- (void)findQuoteInActionMessage {
	__weak typeof(self) weakSelf = self;
	[self withActionMessage:^(int64_t messageId, int64_t chatId, NSDictionary *m){
		NSString *text = m[@"text"] ?: @"";
		if (!text.length)
			return;
		TGChatViewController *me = weakSelf;
		if (!me)
			return;
		[TGAlertSheet showInput:@"Quote"
						message:@"Telegram returns the character position of the phrase."
					placeholder:@"Phrase in this message"
						   text:@""
						 action:@"Search"
						 inView:me.view
					 onSubmit:^(NSString *quote){
			[[TGMessageStore shared] searchQuote:quote inText:text position:0
								completion:^(NSInteger position, BOOL found){
				TGChatViewController *live = weakSelf;
				if (!live)
					return;
				if (!found){
					[TGAlertSheet showMessage:@"That phrase is not in this message."
									   title:@"Quote"
									   inView:live.view];
					return;
				}
				[TGAlertSheet showMessage:
						[NSString stringWithFormat:@"“%@” starts at character %ld.",
								quote, (long)position]
								   title:@"Quote"
								   inView:live.view];
			}];
		}];
	}];
}


- (void)showRecentLocationsInActionMessage {
	__weak typeof(self) weakSelf = self;
	[self withActionMessage:^(int64_t messageId, int64_t chatId, NSDictionary *m){
		[[TGMessageStore shared] recentLocationsInChat:chatId completion:^(NSArray *messages){
			TGChatViewController *me = weakSelf;
			if (!me) return;
			if (!messages.count){
				[TGAlertSheet showMessage:@"No location pins in this chat."
									 title:@"Recent" inView:me.view];
				return;
			}
			NSMutableArray *rows = [NSMutableArray array];
			for (NSDictionary *loc in messages){
				NSString *who = [loc[@"sender_id"] isKindOfClass:NSDictionary.class]
						? ([[TGMessageStore shared] nameForUserId:
						   [loc[@"sender_id"][@"user_id"] longLongValue]]) ?: @"User"
						: @"Location";
				NSString *day = TGSheetDate([loc[@"date"] doubleValue]);
				NSString *live = [loc[@"content"][@"@type"]
						isEqualToString:@"messageLiveLocation"] ? @" · live" : @"";
				NSString *line = [NSString stringWithFormat:@"%@%@%@",
						who ?: @"Location", day.length ? @" · " : @"", day ?: @""];
				[rows addObject:[line stringByAppendingString:live]];
			}
			[TGAlertSheet showChoices:rows
								title:@"Recent"
					 destructiveIndex:-1
							   inView:me.view
							 onChoice:^(NSInteger index){
				if (index >= (NSInteger)messages.count)
					return;
				[weakSelf showMessageId:[messages[index][@"id"] longLongValue]
									 gone:@"That location is gone"];
			}];
		}];
	}];
}

- (void)toggleChatSearchOpenWithTag:(NSString *)tag {
	[self toggleChatSearch];
	if (!self.chatSearchBar)
		return;
	self.chatSearchBar.text = tag;
	[self searchBar:self.chatSearchBar textDidChange:tag];
}


@end
