//
// TGCallStore.h - group calls and video chats.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TGClientTypes.h"

/// The pure join parameter/input builders, shared with the call screens.
FOUNDATION_EXPORT NSDictionary *TGGroupCallJoinParameters(int32_t audioSourceId,
														  NSString *payload,
														  BOOL isVideo,
														  BOOL isP2P);
FOUNDATION_EXPORT NSDictionary *TGGroupCallInput(int32_t groupCallId,
												 int64_t accessHash);


extern NSString *const TGGroupCallChangedNotification;
extern NSString *const TGGroupCallParticipantsChangedNotification;
extern NSString *const TGGroupCallMessagesChangedNotification;
extern NSString *const TGGroupCallIdKey;
extern NSString *const TGGroupCallValueKey;
extern NSString *const TGGroupCallErrorKey;

@interface TGCallStore : NSObject

+ (instancetype)shared;

- (void)resetGroupCallState;
- (void)groupCall:(int32_t)groupCallId
	   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)createVideoChatInChat:(int64_t)chatId
						title:(NSString *)title
					startDate:(int32_t)startDate
					   isRtmp:(BOOL)isRtmp
				   completion:(void (^)(int32_t, NSString *))completion;
- (void)createGroupCallWithParameters:(NSDictionary *)parameters
						   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)joinGroupCallWithInput:(NSDictionary *)input
					parameters:(NSDictionary *)parameters
					completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)joinVideoChat:(int32_t)groupCallId
		  participant:(NSDictionary *)participant
		   parameters:(NSDictionary *)parameters
		   inviteHash:(NSString *)inviteHash
		   completion:(void (^)(NSString *, NSString *))completion;
- (void)leaveGroupCall:(int32_t)groupCallId
			completion:(void (^)(BOOL, NSString *))completion;
- (void)endGroupCall:(int32_t)groupCallId
		  completion:(void (^)(BOOL, NSString *))completion;
- (void)startScheduledVideoChat:(int32_t)groupCallId
					 completion:(void (^)(BOOL, NSString *))completion;
- (void)groupCallParticipantsWithInput:(NSDictionary *)input
								 limit:(NSInteger)limit
							completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)loadGroupCallParticipants:(int32_t)groupCallId
							limit:(NSInteger)limit
					   completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleGroupCallParticipant:(NSDictionary *)participant
							inCall:(int32_t)groupCallId
							isMuted:(BOOL)muted
						completion:(void (^)(BOOL, NSString *))completion;
- (void)setGroupCallParticipant:(NSDictionary *)participant
						 inCall:(int32_t)groupCallId
					volumeLevel:(NSInteger)volumeLevel
					 completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleGroupCallParticipant:(NSDictionary *)participant
							inCall:(int32_t)groupCallId
					  isHandRaised:(BOOL)raised
						completion:(void (^)(BOOL, NSString *))completion;
- (void)setGroupCallParticipantSpeaking:(int32_t)audioSource
								 inCall:(int32_t)groupCallId
							  isSpeaking:(BOOL)speaking
							  completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)inviteGroupCallParticipant:(int64_t)userId
							toCall:(int32_t)groupCallId
							isVideo:(BOOL)isVideo
						 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)inviteVideoChatParticipants:(NSArray *)userIds
							 toCall:(int32_t)groupCallId
						 completion:(void (^)(BOOL, NSString *))completion;
- (void)banGroupCallParticipants:(NSArray *)userIds
						  inCall:(int32_t)groupCallId
					  completion:(void (^)(BOOL, NSString *))completion;
- (void)declineGroupCallInvitationInChat:(int64_t)chatId
							   messageId:(int64_t)messageId
							  completion:(void (^)(BOOL, NSString *))completion;
- (void)setVideoChatTitle:(NSString *)title
				   inCall:(int32_t)groupCallId
			   completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleVideoChatMuteNewParticipants:(int32_t)groupCallId
									muted:(BOOL)muted
							   completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleGroupCallMessagesAllowed:(int32_t)groupCallId
							   allowed:(BOOL)allowed
							completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleVideoChatStartNotification:(int32_t)groupCallId
								   enabled:(BOOL)enabled
								completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleGroupCallMyVideoEnabled:(int32_t)groupCallId
							  enabled:(BOOL)enabled
						   completion:(void (^)(BOOL, NSString *))completion;
- (void)toggleGroupCallMyVideoPaused:(int32_t)groupCallId
							  paused:(BOOL)paused
						  completion:(void (^)(BOOL, NSString *))completion;
- (void)startGroupCallRecording:(int32_t)groupCallId
						  title:(NSString *)title
					recordVideo:(BOOL)recordVideo
					   portrait:(BOOL)portrait
					 completion:(void (^)(BOOL, NSString *))completion;
- (void)endGroupCallRecording:(int32_t)groupCallId
				   completion:(void (^)(BOOL, NSString *))completion;
- (void)startGroupCallScreenSharing:(int32_t)groupCallId
					 audioSourceId:(int32_t)audioSourceId
						   payload:(NSString *)payload
						completion:(void (^)(NSString *, NSString *))completion;
- (void)toggleGroupCallScreenSharingPaused:(int32_t)groupCallId
									paused:(BOOL)paused
								completion:(void (^)(BOOL, NSString *))completion;
- (void)endGroupCallScreenSharing:(int32_t)groupCallId
					   completion:(void (^)(BOOL, NSString *))completion;
- (void)videoChatInviteLink:(int32_t)groupCallId
			 canSelfUnmute:(BOOL)canSelfUnmute
				completion:(void (^)(NSString *, NSString *))completion;
- (void)revokeGroupCallInviteLink:(int32_t)groupCallId
					   completion:(void (^)(BOOL, NSString *))completion;
- (void)videoChatRtmpUrlForChat:(int64_t)chatId
					 completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)replaceVideoChatRtmpUrlForChat:(int64_t)chatId
							completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)videoChatAvailableParticipantsForChat:(int64_t)chatId
								   completion:(void (^)(NSDictionary *, NSString *))completion;
- (void)setVideoChatDefaultParticipant:(NSDictionary *)participant
							   forChat:(int64_t)chatId
							completion:(void (^)(BOOL, NSString *))completion;
- (void)sendGroupCallMessage:(NSString *)text
					  inCall:(int32_t)groupCallId
			   paidStarCount:(int64_t)paidStarCount
				  completion:(void (^)(BOOL, NSString *))completion;
- (void)deleteGroupCallMessages:(NSArray *)messageIds
						 inCall:(int32_t)groupCallId
					 reportSpam:(BOOL)reportSpam
					 completion:(void (^)(BOOL, NSString *))completion;
- (void)deleteGroupCallMessagesBySender:(NSDictionary *)sender
								 inCall:(int32_t)groupCallId
							 reportSpam:(BOOL)reportSpam
							 completion:(void (^)(BOOL, NSString *))completion;
- (void)groupCallStreams:(int32_t)groupCallId
			  completion:(void (^)(NSArray *, NSString *))completion;
- (void)groupCallStreamSegment:(int32_t)groupCallId
					timeOffset:(int64_t)timeOffset
						 scale:(NSInteger)scale
					 channelId:(NSInteger)channelId
					   quality:(NSString *)quality
					completion:(void (^)(NSData *, NSString *))completion;
- (void)encryptGroupCallData:(NSData *)data
					  inCall:(int32_t)groupCallId
					 channel:(NSString *)channel
		 unencryptedPrefixSize:(NSInteger)prefixSize
				  completion:(void (^)(NSData *, NSString *))completion;
- (void)decryptGroupCallData:(NSData *)data
			  fromParticipant:(NSDictionary *)participant
					  inCall:(int32_t)groupCallId
					 channel:(NSString *)channel
				  completion:(void (^)(NSData *, NSString *))completion;
- (NSDictionary *)groupCallSnapshot:(int32_t)groupCallId;
- (NSArray *)groupCallParticipantSnapshot:(int32_t)groupCallId;
- (NSArray *)groupCallMessageSnapshot:(int32_t)groupCallId;
- (NSDictionary *)currentGroupCallParticipant:(int32_t)groupCallId;
- (void)applyGroupCallUpdate:(NSDictionary *)update;
- (void)applyGroupCallParticipantUpdate:(NSDictionary *)update;
- (void)applyGroupCallMessagesDeleted:(NSDictionary *)update;
- (void)applyGroupCallMessageSendFailed:(NSDictionary *)update;
- (void)applyNewGroupCallMessage:(NSDictionary *)update;
- (void)applyGroupCallParticipantsUpdate:(NSDictionary *)update;

@end
