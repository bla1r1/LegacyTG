#import "TGClient+Base.h"

@interface TGClient (StoriesLive)

/// Starts a live story. `rtmp` asks Telegram for an RTMP stream; without a
/// camera encoder this client still shows the server's stream key and the
/// live state. The answer carries "ok", "story" and, on failure, "error".
- (void)startLiveStoryInChat:(int64_t)chatId
					 privacy:(NSString *)privacy
					  userIds:(NSArray *)userIds
			   protectContent:(BOOL)protectContent
					   rtmp:(BOOL)rtmp
			 enableMessages:(BOOL)enableMessages
			  paidMessageStars:(NSInteger)paidMessageStars
				  completion:(void (^)(NSDictionary *answer))completion;

/// Joins the call behind a live story and returns Telegram's join payload.
/// This client has no camera to put into it; the payload and the server's
/// refusal are shown as they arrive.
- (void)joinLiveStoryCall:(int32_t)groupCallId
			   completion:(void (^)(NSString *payload, NSString *error))completion;

/// Who is streaming: "kind", "id", "name", "isCurrentUser", "isSpeaking",
/// "isMuted" and "bio".
- (void)liveStoryStreamerForCall:(int32_t)groupCallId
					  completion:(void (^)(NSDictionary *streamer, NSString *error))completion;

/// The chat's RTMP address: "url" and "streamKey".
- (void)liveStoryRtmpUrlForChat:(int64_t)chatId
					 completion:(void (^)(NSDictionary *url, NSString *error))completion;

/// Asks Telegram for a new stream key, invalidating the old one.
- (void)replaceLiveStoryRtmpUrlForChat:(int64_t)chatId
							completion:(void (^)(NSDictionary *url, NSString *error))completion;

/// Senders messages may be posted in the live story as, with "needsPremium".
- (void)liveStoryAvailableMessageSendersForCall:(int32_t)groupCallId
									 completion:(void (^)(NSArray *senders, NSString *error))completion;

/// `sender` is a dictionary with "kind" ("user" or "chat") and "id".
- (void)setLiveStoryMessageSender:(NSDictionary *)sender
						  forCall:(int32_t)groupCallId
					   completion:(void (^)(BOOL ok, NSString *error))completion;

/// "totalStarCount" and "donors": "kind", "id", "name", "stars", "isTop",
/// "isMe" and "isAnonymous".
- (void)liveStoryTopDonorsForCall:(int32_t)groupCallId
					   completion:(void (^)(NSDictionary *donors, NSString *error))completion;

/// Paid reactions are batched: add one, then commit when the undo window
/// ends, or remove every pending one when the user changes their mind.
- (void)addPendingLiveStoryReactionInCall:(int32_t)groupCallId
								   stars:(NSInteger)stars
							  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)commitPendingLiveStoryReactionsInCall:(int32_t)groupCallId
								   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removePendingLiveStoryReactionsInCall:(int32_t)groupCallId
								   completion:(void (^)(BOOL ok, NSString *error))completion;

@end
