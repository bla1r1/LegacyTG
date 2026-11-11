//
// TGUpdateHandlers+Stories.m - one family of update* branches.
//
#import "TGUpdateHandlers.h"
#import "TGUpdateHandlersSupport.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGState.h"
#import "TGTransport.h"
#import "TGUpdateRouter.h"
#import "TGAccountSession.h"
#import "TGJson.h"
#import "TGOptions.h"
#import "TGBase64.h"
#import "TGCall.h"
#include "TGUpdateType.h"

@interface TGClient (TGUpdateHandlerPrivate)
- (void)markSavedMessagesRow;
@end

@implementation TGUpdateHandlers (Stories)

- (BOOL)handleStoriesUpdates:(NSString *)type obj:(NSDictionary *)obj {
	switch (TGUpdateTypeFor(type.UTF8String, type.length)){
	case TGUpdateChatActiveStories: {
		[self.client applyChatActiveStoriesUpdate:obj];
		return YES;
	}
	case TGUpdateStory:
		[self.client applyStoryUpdate:obj];
		return YES;
	case TGUpdateStoryDeleted:
		[self.client applyStoryDeletedUpdate:obj];
		return YES;
	case TGUpdateStoryPostSucceeded:
	case TGUpdateStoryPostFailed:
		[self.client applyStoryPostUpdate:obj];
		return YES;
	case TGUpdateStoryListChatCount:
		[self.client applyStoryListChatCountUpdate:obj];
		return YES;
	case TGUpdateStoryStealthMode:
		[self.client applyStoryStealthModeUpdate:obj];
		return YES;
	case TGUpdateOwnedStarCount:
		[self.client applyOwnedStarCountUpdate:obj];
		return YES;
	case TGUpdateChatRevenueAmount:
		[self.client applyChatRevenueAmountUpdate:obj];
		return YES;
	case TGUpdateStarRevenueStatus:
		[self.client applyStarRevenueStatusUpdate:obj];
		return YES;
	case TGUpdateVideoPublished: {
		// A scheduled video went live. It is a message change plus a chat-list
		// change (the preview and order move), so both windows are nudged; the
		// open chat also gets the id to re-read that one message.
		if (!obj[@"chat_id"] || !obj[@"message_id"])
			return YES;
		NSNumber *chatId = @([obj[@"chat_id"] longLongValue]);
		NSNumber *messageId = @([obj[@"message_id"] longLongValue]);
		NSDictionary *state = @{
			@"chat_id"    : chatId,
			@"message_id" : messageId,
		};
		self.client.publishedVideoValue = state;
		if (self.client.updateCoalescer)
			[self.client.updateCoalescer markMessageDirty:[messageId longLongValue]
											inChat:[chatId longLongValue]];
		[self.client markChatRowDirty:[chatId longLongValue]];
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatVideoPublishedNotification object:self
							userInfo:state];
		return YES;
	}

	case TGUpdateCommunity:
		[self.client applyCommunityUpdate:obj];
		return YES;
	case TGUpdateCommunityFullInfo:
		[self.client applyCommunityFullInfoUpdate:obj];
		return YES;
	case TGUpdateQuickReplyShortcut:
		[self.client applyQuickReplyShortcutUpdate:obj];
		return YES;
	case TGUpdateQuickReplyShortcutDeleted:
		[self.client applyQuickReplyShortcutDeleted:obj];
		return YES;
	case TGUpdateQuickReplyShortcuts:
		[self.client applyQuickReplyShortcutsUpdate:obj];
		return YES;
	case TGUpdateQuickReplyShortcutMessages:
		[self.client applyQuickReplyShortcutMessagesUpdate:obj];
		return YES;
	case TGUpdateSuggestedActions:
		[self.client applySuggestedActionsUpdate:obj];
		return YES;

	// TDLib's local notification list. The page that removes entries reads
	// this copy, because no request re-reads what updateActiveNotifications
	// sent.
	case TGUpdateActiveNotifications:
	case TGUpdateNotification:
	case TGUpdateNotificationGroup:
		[self.client applyActiveNotificationUpdate:obj];
		return YES;
	case TGUpdateHavePendingNotifications: {
		// TDLib is still fetching or delaying notifications. The screen keeps
		// a spinner up until both flags are off rather than calling the list
		// final while rows are still on the way.
		[self.client applyHavePendingNotificationsUpdate:obj];
		return YES;
	}

	default:
		break;
	}
	return NO;
}

@end

// vim:ft=objc
