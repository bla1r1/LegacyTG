//
// TGMessageModel.h - typed NSDictionary subclass for flattened messages.
//
// Keeps hot scalar and collection fields in direct ivars so cell layout,
// table reloads and scroll loops avoid hash lookups and NSNumber unboxing,
// while remaining drop-in compatible with NSDictionary callers and JSON.
//
#import <Foundation/Foundation.h>

@interface TGMessageModel : NSDictionary

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int64_t senderId;
@property (nonatomic, readonly) int32_t date;
@property (nonatomic, readonly) int32_t viewCount;
@property (nonatomic, readonly) int32_t replyCount;
@property (nonatomic, readonly) BOOL outgoing;
@property (nonatomic, readonly) BOOL service;
@property (nonatomic, readonly) BOOL edited;
@property (nonatomic, readonly) BOOL channelPost;
@property (nonatomic, readonly) BOOL canComment;
@property (nonatomic, readonly) BOOL sending;
@property (nonatomic, readonly, copy) NSString *kind;
@property (nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly, strong) NSArray *entities;
@property (nonatomic, readonly, strong) NSArray *reactionGroups;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

static inline int64_t TGMsgId(id m) {
	return [m isKindOfClass:TGMessageModel.class]
			? ((TGMessageModel *)m).messageId
			: [m[@"id"] longLongValue];
}

static inline int64_t TGMsgSenderId(id m) {
	return [m isKindOfClass:TGMessageModel.class]
			? ((TGMessageModel *)m).senderId
			: [m[@"senderId"] longLongValue];
}

static inline BOOL TGMsgOutgoing(id m) {
	return [m isKindOfClass:TGMessageModel.class]
			? ((TGMessageModel *)m).outgoing
			: [m[@"outgoing"] boolValue];
}

static inline BOOL TGMsgService(id m) {
	return [m isKindOfClass:TGMessageModel.class]
			? ((TGMessageModel *)m).service
			: [m[@"service"] boolValue];
}

static inline NSString *TGMsgKind(id m) {
	return [m isKindOfClass:TGMessageModel.class]
			? ((TGMessageModel *)m).kind
			: m[@"kind"];
}

static inline NSString *TGMsgText(id m) {
	return [m isKindOfClass:TGMessageModel.class]
			? ((TGMessageModel *)m).text
			: m[@"text"];
}
