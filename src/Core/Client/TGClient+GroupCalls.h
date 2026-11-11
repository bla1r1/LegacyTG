//
// TGClient+GroupCalls.h - group calls and video chats on the wire.
//
// A group call is one record Telegram keeps updating (groupCall), a set of
// participants that arrive as updates, and the requests a call screen sends
// about them. A video chat is the same call bound to a chat; the setup screen
// creates it, schedules it, and manages recordings, invite links and RTMP.
//
// The screens read one flat dictionary per call, participant, message and
// stream. Flattening lives in the implementation so the call screen, the
// participant list and the message bar all read the same keys.
//
#import "TGClient+Base.h"

/// Posted on the main queue when updateGroupCall changes a call.
/// userInfo carries TGGroupCallIdKey and TGGroupCallValueKey.
FOUNDATION_EXPORT NSString * const TGGroupCallChangedNotification;
/// Posted when one participant changes or leaves (TGGroupCallValueKey is the
/// participant; it is absent when the participant list was removed).
FOUNDATION_EXPORT NSString * const TGGroupCallParticipantsChangedNotification;
/// Posted when a call message is added, deleted or fails to send.
FOUNDATION_EXPORT NSString * const TGGroupCallMessagesChangedNotification;

FOUNDATION_EXPORT NSString * const TGGroupCallIdKey;
FOUNDATION_EXPORT NSString * const TGGroupCallValueKey;
FOUNDATION_EXPORT NSString * const TGGroupCallErrorKey;

/// The join parameters TDLib takes for joinGroupCall and joinVideoChat.
/// A nil payload is an empty one; -muted answers is_muted.
FOUNDATION_EXPORT NSDictionary *TGGroupCallJoinParameters(int32_t audioSourceId,
		NSString *payload, BOOL muted, BOOL videoEnabled);

/// An inputGroupCall for the calls createGroupCall makes. Chat-bound video
/// chats are named by id alone; TDLib uses this object for the chatless ones.
FOUNDATION_EXPORT NSDictionary *TGGroupCallInput(int32_t groupCallId,
		int64_t accessHash);

@interface TGClient (GroupCalls)

#pragma mark - calls and participation

/// getGroupCall. The answer is flattened: "callId", "title", "participantCount",
/// "isActive", "isJoined", "isVideoChat", "isRtmpStream", "scheduledStartDate",
/// "duration", the can_* rights and the two self-video flags.
/// createVideoChat. `startDate` 0 starts it now; TDLib requires 10 seconds to
/// 8 days otherwise. A channel or supergroup with can_manage_video_chats is
/// the only place Telegram accepts it.
/// createGroupCall, for a call that is not bound to a chat. Answers the id
/// and the join payload; the payload is what tgcalls would carry.
/// joinGroupCall for a chatless call, or joinVideoChat for a video chat.
/// `participant` is a MessageSender or nil to join as self.
/// startScheduledVideoChat. Also clears Telegram's scheduled state, so the
/// call screen refreshes the record afterwards.
/// getGroupCallParticipants for a chatless call that is not joined.
/// Answers "total" and "senders" (MessageSender dictionaries).
/// loadGroupCallParticipants. The rows arrive through updates; `completion`
/// says only whether Telegram accepted the request.
#pragma mark - participants

/// setGroupCallParticipantIsSpeaking. `audioSource` 0 means this account;
/// the answer names the participant when Telegram found one, nil otherwise.
#pragma mark - the call's own settings

#pragma mark - recording and screen sharing

/// startGroupCallScreenSharing takes the payload tgcalls handed back at join
/// time and the audio source it allocated. There is no media engine here, so
/// the screen passes what it has and shows Telegram's answer.
#pragma mark - invite links and RTMP

/// getVideoChatRtmpUrl / replaceVideoChatRtmpUrl. Both answer "url" and
/// "streamKey"; the chat is the name because the RTMP half exists before a
/// call does.
#pragma mark - who a video chat is joined as

/// getVideoChatAvailableParticipants. Answers "total" and "senders", the
/// MessageSender records Telegram accepts for this chat.
#pragma mark - messages in a call

/// sendGroupCallMessage. The message itself arrives as updateGroupCallMessage
/// when Telegram accepts it; the completion only reports acceptance.
#pragma mark - streams and the data channel

/// getGroupCallStreams. Answers "streams", one dictionary per channel:
/// "channelId", "scale" and "timeOffset".
/// getGroupCallStreamSegment. `quality` is "thumbnail", "medium", "full" or
/// nil for the worst available. The answer is the file TDLib generated.
/// encryptGroupCallData / decryptGroupCallData. `channel` is "main" or
/// "screenSharing"; nil means main (and, for decrypt, unknown).
#pragma mark - state the screens read

/// The last flattened call updateGroupCall / getGroupCall left, or nil.
- (NSDictionary *)groupCallSnapshot:(int32_t)groupCallId;
/// Participants in the order Telegram gave (highest order first), or empty.
- (NSArray *)groupCallParticipantSnapshot:(int32_t)groupCallId;
/// Call messages, oldest first. Empty when none arrived.
- (NSArray *)groupCallMessageSnapshot:(int32_t)groupCallId;

/// The participant row for this account in a call, or nil.
- (NSDictionary *)currentGroupCallParticipant:(int32_t)groupCallId;

@end

// vim:ft=objc
