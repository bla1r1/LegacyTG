//
// TGEphemeralViewController - the ephemeral message composer and viewer.
//
// sendEphemeralMessage is a bot-side call: a user account gets Telegram's
// refusal, which this screen prints instead of hiding. The composer, the
// receiver, the reply id and the five follow-up calls are all real requests.
//
#import <Foundation/Foundation.h>
#import "TGLocalization.h"

static inline NSArray *TGEphemeralSectionTitles(void) {
	return @[TGLocalized(@"Target"), TGLocalized(@"Requests"),
			TGLocalized(@"Result")];
}

static inline NSArray *TGEphemeralActionTitles(void) {
	return @[
		TGLocalized(@"Send Message"), TGLocalized(@"Edit Message"),
		TGLocalized(@"Edit Caption"), TGLocalized(@"Delete Message"),
		TGLocalized(@"Remove"), TGLocalized(@"Clear"),
	];
}

static inline NSString *TGEphemeralReceiverDetail(int64_t receiverUserId) {
	return receiverUserId
			? [NSString stringWithFormat:@"%lld", receiverUserId]
			: TGLocalized(@"Choose a Bot");
}

static inline NSString *TGEphemeralReplyDetail(NSInteger replyId) {
	return replyId ? [NSString stringWithFormat:@"%ld", (long)replyId]
			: TGLocalized(@"None");
}

static inline NSString *TGEphemeralResultDetail(NSString *lastSentText) {
	return lastSentText.length
			? [NSString stringWithFormat:@"%@: %@",
					TGLocalized(@"Sent"), lastSentText] : nil;
}

#ifndef TGROW_MODELS_ONLY
#import <UIKit/UIKit.h>
#import "TGRowsViewController.h"

@interface TGEphemeralViewController : TGRowsViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy)   NSString *chatTitle;

@end
#endif
