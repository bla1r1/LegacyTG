//
// TGMessageStore.h - the whole message surface a Chat screen may ask for.
//
// The store is the line between the chat UI and TGClient. Screens call it;
// TGClient stays behind it. The declarations below mirror the client
// methods the Chat feature actually uses, so a screen never imports a
// TGClient header. Forwarding lives in TGMessageStore.m.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TGClientTypes.h"
#import "TGDownloadPriority.h"
#import "TGClientNotifications.h"

@interface TGMessageStore : NSObject

+ (instancetype)shared;

/// The two scheduling records a held Send uses.
+ (NSDictionary *)scheduledAtDate:(NSTimeInterval)date;
+ (NSDictionary *)scheduledWhenOnline;

@property (nonatomic, readonly) TGConnectionState connectionState;
@property (nonatomic, readonly) NSArray *chats;
@property (nonatomic, readonly) NSArray *folders;
@property (nonatomic, readonly) NSArray *communities;
@property (nonatomic, readonly) NSArray *savedTopics;
@property (nonatomic, readonly) NSArray *quickReplyShortcuts;
@property (nonatomic, readonly) NSDictionary *me;
@property (nonatomic, readonly, copy) NSArray *availableMessageEffectIds;
@property (nonatomic, readonly, copy) NSArray *availableStickerEffectIds;
@property (nonatomic, readonly) NSString *defaultReactionEmoji;
@property (nonatomic, copy) void (^onMessage)(int64_t chatId, NSDictionary *message, int64_t deletedId);
@property (nonatomic, copy) void (^onChatAction)(int64_t chatId, NSString *action);
@property (nonatomic, copy) void (^onSecretChat)(NSInteger secretChatId, NSString *state);
@property (nonatomic, copy) void (^onFileProgress)(NSInteger fileId, float progress);

- (void)addChat:(int64_t)chatId toList:(NSDictionary *)list
	 completion:(void (^)(BOOL ok))completion;

- (void)addChecklistTasks:(NSArray *)tasks
                toMessage:(int64_t)messageId
                   inChat:(int64_t)chatId
               completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)addPollOption:(NSString *)text
            toMessage:(int64_t)messageId
                 inChat:(int64_t)chatId
            completion:(void (^)(BOOL ok))completion;

- (void)addQuickReplyShortcutMessage:(NSString *)shortcutName
                                text:(NSString *)text
                          completion:(void (^)(NSDictionary *message, NSString *error))completion;

- (void)addQuickReplyShortcutMessageAlbum:(NSString *)shortcutName
                                    texts:(NSArray *)texts
                               completion:(void (^)(NSArray *messages, NSString *error))completion;

- (void)addedReactionsOfMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
				   reactionType:(NSDictionary *)reactionType
						 offset:(NSString *)offset
					 completion:(void (^)(NSArray *rows, NSString *next))completion;

- (void)approveSuggestedPost:(int64_t)messageId
                      inChat:(int64_t)chatId
                    sendDate:(NSInteger)sendDate
                  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)authorOfMessage:(int64_t)messageId
				inChat:(int64_t)chatId
			 completion:(void (^)(NSDictionary *user))completion;

- (void)availableReactionsForMessage:(int64_t)messageId
							  inChat:(int64_t)chatId
						  completion:(void (^)(NSArray *emojis))completion;

- (void)blockSenderOfMessage:(int64_t)messageId
			  deleteMessages:(BOOL)deleteMessages
				  reportSpam:(BOOL)reportSpam;

- (void)blockUserWithUserId:(int64_t)userId;

- (void)calendarJumpForChat:(int64_t)chatId
					 endDate:(NSInteger)end
				  completion:(void (^)(int64_t messageId, NSInteger total))completion;

- (void)canSendInChat:(int64_t)chatId completion:(void (^)(BOOL canSend, BOOL isChannel))completion;

- (void)cancelDownloadOfFile:(NSInteger)fileId onlyIfPending:(BOOL)onlyIfPending;



- (void)cancelTypingInChat:(int64_t)chatId thread:(int64_t)threadId;

- (BOOL)chatIsSavedMessages:(int64_t)chatId;

- (void)chatKindForChat:(int64_t)chatId
             completion:(void (^)(NSDictionary *kind))completion;

- (void)chatListsForChat:(int64_t)chatId
			  completion:(void (^)(NSArray *lists))completion;

- (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion;

- (void)chatRecordForChat:(int64_t)chatId
			   completion:(void (^)(NSDictionary *chat))completion;

- (void)chatStatisticsForChat:(int64_t)chatId
				   completion:(void (^)(NSArray *rows, NSString *kind))completion;

- (void)chatWithUsername:(NSString *)username
              completion:(void (^)(int64_t chatId, NSString *title))completion;

- (void)checkQuickReplyShortcutName:(NSString *)name
                         completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)checklistForMessage:(int64_t)messageId
                     inChat:(int64_t)chatId
                 completion:(void (^)(NSDictionary *checklist, NSString *error))completion;

- (void)clearHistoryInChat:(int64_t)chatId revoke:(BOOL)revoke;

- (void)clearReplyMarkupOfMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(BOOL ok))completion;

- (void)clearSavedTopicMessagesBefore:(int64_t)topicId
							 minDate:(NSInteger)minDate
							 maxDate:(NSInteger)maxDate;

- (void)clickAnimatedEmojiMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					   completion:(void (^)(NSString *emoji))completion;

- (void)closeChat:(int64_t)chatId;

- (void)closeSecretChat:(NSInteger)secretChatId;

- (void)commentThreadForChat:(int64_t)chatId
				   messageId:(int64_t)messageId
				  completion:(void (^)(int64_t discussionChatId, int64_t threadId,
									   NSString *error))completion;

- (void)communityFullInfo:(int64_t)communityId
               completion:(void (^)(NSDictionary *info, NSString *error))completion;

- (void)composeTextWithAi:(NSString *)text
         translateTo:(NSString *)languageCode
               style:(NSString *)styleName
           addEmojis:(BOOL)addEmojis
          completion:(void (^)(NSString *text, NSString *error))completion;

- (void)confirmLoginButton:(NSDictionary *)button
					inChat:(int64_t)chatId
				 messageId:(int64_t)messageId
				completion:(void (^)(NSString *url, NSString *error))completion;

- (void)currentWeatherAtLatitude:(double)latitude
					   longitude:(double)longitude
					  completion:(void (^)(NSDictionary *weather,
										   NSString *error))completion;

- (void)declineSuggestedPost:(int64_t)messageId
                      inChat:(int64_t)chatId
                     comment:(NSString *)comment
                  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)defaultChatPhotoEmojiStickersWithCompletion:
		(void (^)(NSArray *stickers))completion;

- (void)deleteAllReactionsOfSender:(NSDictionary *)sender inChat:(int64_t)chatId;

- (void)deleteChatBackground:(int64_t)chatId restorePrevious:(BOOL)restore;

- (void)deleteDirectMessagesChatTopicHistory:(int64_t)topicId
                                      inChat:(int64_t)chatId
                                  completion:(void (^)(BOOL ok,
                                                       NSString *error))completion;

- (void)deleteDirectMessagesChatTopicMessages:(int64_t)topicId
                                       inChat:(int64_t)chatId
                                     minDate:(NSInteger)minDate
                                     maxDate:(NSInteger)maxDate
                                  completion:(void (^)(BOOL ok,
                                                       NSString *error))completion;

- (void)deleteEphemeralMessage:(NSInteger)ephemeralMessageId
                      receiver:(int64_t)receiverUserId
                        inChat:(int64_t)chatId
                    completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteMessageEphemeralContent:(int64_t)messageId
                              inChat:(int64_t)chatId
                          completion:(void (^)(BOOL ok,
                                               NSString *error))completion;



- (void)deletePollOption:(NSString *)optionId
               ofMessage:(int64_t)messageId
                  inChat:(int64_t)chatId
              completion:(void (^)(BOOL ok))completion;

- (void)deleteQuickReplyShortcut:(NSInteger)shortcutId
                      completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteQuickReplyShortcutMessages:(NSArray *)messageIds
                              shortcutId:(NSInteger)shortcutId
                              completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteReactionsOfSender:(NSDictionary *)sender
					  ofMessage:(int64_t)messageId
						 inChat:(int64_t)chatId;

- (void)deleteSavedTopicHistory:(int64_t)topicId;

- (void)directMessagesChatTopic:(int64_t)topicId
                         inChat:(int64_t)chatId
                     completion:(void (^)(NSDictionary *topic,
                                          NSString *error))completion;

- (void)directMessagesChatTopicHistory:(int64_t)topicId
                                inChat:(int64_t)chatId
                         fromMessageId:(int64_t)fromMessageId
                                offset:(NSInteger)offset
                                 limit:(NSInteger)limit
                            completion:(void (^)(NSArray *messages,
                                                 NSString *error))completion;

- (void)directMessagesChatTopicMessageByDate:(int64_t)topicId
                                      inChat:(int64_t)chatId
                                        date:(NSInteger)date
                                  completion:(void (^)(NSDictionary *message,
                                                       NSString *error))completion;

- (NSArray *)directMessagesChatTopicsForChat:(int64_t)chatId;

- (void)dismissReplyMarkupInChat:(int64_t)chatId;

- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion;

- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority completion:(void (^)(NSString *path))completion;

- (NSString *)draftForChat:(int64_t)chatId;

- (void)editCaption:(NSString *)caption
		  ofMessage:(int64_t)messageId
			 inChat:(int64_t)chatId
		 completion:(void (^)(BOOL ok))completion;

- (void)editEphemeralMessage:(NSInteger)ephemeralMessageId
                        text:(NSString *)text
                    receiver:(int64_t)receiverUserId
                      inChat:(int64_t)chatId
                  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)editEphemeralMessageCaption:(NSInteger)ephemeralMessageId
                            caption:(NSString *)caption
                           receiver:(int64_t)receiverUserId
                             inChat:(int64_t)chatId
                         completion:(void (^)(BOOL ok,
                                              NSString *error))completion;

- (void)editLiveLocationOfMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
						 latitude:(double)latitude
						longitude:(double)longitude
					   livePeriod:(NSInteger)seconds
					   completion:(void (^)(BOOL ok))completion;

- (void)editMessageChecklist:(int64_t)messageId
                      inChat:(int64_t)chatId
                       title:(NSString *)title
                       tasks:(NSArray *)tasks
                othersCanAdd:(BOOL)othersCanAdd
              othersCanMark:(BOOL)othersCanMark
                  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)editPhotoAtPath:(NSString *)path
				caption:(NSString *)caption
			  ofMessage:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^)(BOOL ok))completion;

- (void)editQuickReplyMessage:(int64_t)messageId
                   shortcutId:(NSInteger)shortcutId
                         text:(NSString *)text
                   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)embeddingCodeOfMessage:(int64_t)messageId
						inChat:(int64_t)chatId
						 album:(BOOL)album
					completion:(void (^)(NSString *code))completion;

- (int64_t)emojiStatusIdForChat:(int64_t)chatId;

- (int64_t)emojiStatusIdForUser:(int64_t)userId;

- (void)ensureUserName:(int64_t)userId completion:(void (^)(void))completion;

- (void)externalLinkForURL:(NSString *)url
		   allowWriteAccess:(BOOL)allowWriteAccess
				completion:(void (^)(NSString *link))completion;

- (void)externalLinkInfoForURL:(NSString *)url
					completion:(void (^)(NSDictionary *info))completion;

- (void)fixTextWithAi:(NSString *)text
           completion:(void (^)(NSString *text, NSString *diff, NSString *error))completion;

- (void)forwardMessages:(NSArray *)messageIds
               fromChat:(int64_t)fromChatId
                 toChat:(int64_t)toChatId;

- (void)gameHighScoresForChat:(int64_t)chatId
					  message:(int64_t)messageId
						 user:(int64_t)userId
				   completion:(void (^)(NSArray *scores,
										NSString *error))completion;

- (void)getFullRichMessage:(int64_t)messageId
                    inChat:(int64_t)chatId
                completion:(void (^)(NSString *text, NSDictionary *message, NSString *error))completion;

- (void)giveawayInfoForChat:(int64_t)chatId
					message:(int64_t)messageId
				 completion:(void (^)(NSDictionary *info, NSString *error))completion;

- (void)groupFullInfoForChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *info))completion;

- (void)historyForChat:(int64_t)chatId
       aroundMessageId:(int64_t)messageId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *messages))completion;

- (void)historyForChat:(int64_t)chatId
         fromMessageId:(int64_t)fromMessageId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *messages))completion;

- (void)historyForChat:(int64_t)chatId
                thread:(int64_t)threadId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *messages))completion;

- (void)inlineGameHighScores:(NSString *)inlineMessageId
						 user:(int64_t)userId
				   completion:(void (^)(NSArray *scores,
										NSString *error))completion;

- (void)instantViewForURL:(NSString *)url
				onlyLocal:(BOOL)onlyLocal
			   completion:(void (^)(NSDictionary *view))completion;

- (void)internalLinkForType:(NSDictionary *)type
					   http:(BOOL)http
				 completion:(void (^)(NSString *link))completion;

- (void)internalLinkKind:(NSString *)link
			  completion:(void (^)(NSString *kind, NSString *value))completion;

- (BOOL)isChatMuted:(int64_t)chatId;

- (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL blocked))completion;

- (void)joinChat:(int64_t)chatId completion:(void (^)(BOOL ok, BOOL requestSent))completion;

- (void)joinChatByInviteLink:(NSString *)inviteLink
                  completion:(void (^)(int64_t chatId, NSString *title))completion;

- (void)joinRequestsForChat:(int64_t)chatId
				 completion:(void (^)(NSArray *requests))completion;

- (void)labelSavedTag:(NSDictionary *)tag label:(NSString *)label;

- (int64_t)lastReadInboxForChat:(int64_t)chatId;

- (void)linkPreviewForText:(NSString *)text
				completion:(void (^)(NSDictionary *preview))completion;

- (void)linkToMessage:(int64_t)messageId
			   inChat:(int64_t)chatId
		   completion:(void (^)(NSString *link))completion;

- (void)loadDirectMessagesChatTopicsInChat:(int64_t)chatId
                                     limit:(NSInteger)limit
                                completion:(void (^)(BOOL ok,
                                                     NSString *error))completion;

- (void)loadQuickReplyMessagesForShortcut:(NSInteger)shortcutId
                               completion:(void (^)(NSArray *messages))completion;

- (void)loadQuickReplyShortcutsWithCompletion:
        (void (^)(NSArray *shortcuts))completion;

- (void)loadSavedMessagesTopics;

- (void)localMessageWithId:(int64_t)messageId
					inChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *message))completion;

- (void)loginURLForButton:(NSDictionary *)button
				   inChat:(int64_t)chatId
				messageId:(int64_t)messageId
			   completion:(void (^)(NSString *url, NSString *confirmDomain,
									NSString *error))completion;

- (void)mapThumbnailForLatitude:(double)latitude
					  longitude:(double)longitude
						  width:(NSInteger)width
						 height:(NSInteger)height
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSString *path))completion;

- (void)markChecklistTask:(int64_t)taskId done:(BOOL)done inMessage:(int64_t)messageId chat:(int64_t)chatId;

- (void)markChecklistTasksAsDone:(NSArray *)doneTaskIds
                    notDoneTaskIds:(NSArray *)notDoneTaskIds
                         onMessage:(int64_t)messageId
                            inChat:(int64_t)chatId
                        completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId;

- (NSDictionary *)markdownForEditing:(NSDictionary *)formattedText;

- (NSDictionary *)markdownParsed:(NSDictionary *)formattedText;

- (void)messageAtDate:(NSTimeInterval)date inChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *message))completion;

- (void)messageCountInChat:(int64_t)chatId
					thread:(int64_t)threadId
				completion:(void (^)(NSInteger count))completion;

- (void)messageEffectWithId:(int64_t)effectId
				 completion:(void (^)(NSDictionary *effect))completion;

- (void)messageLinkInfo:(NSString *)link
			 completion:(void (^)(int64_t chatId, int64_t messageId))completion;

- (void)messagePropertiesForChat:(int64_t)chatId
					   messageId:(int64_t)messageId
					  completion:(void (^)(NSDictionary *properties))completion;

- (void)messagesInChat:(int64_t)chatId
			messageIds:(NSArray *)messageIds
			completion:(void (^)(NSArray *messages))completion;

- (UIColor *)nameColourForUser:(int64_t)userId;

- (NSString *)nameForUserId:(int64_t)userId;

- (void)newerHistoryForChat:(int64_t)chatId
              fromMessageId:(int64_t)fromMessageId
                      limit:(NSInteger)limit
                 completion:(void (^)(NSArray *messages))completion;

- (void)openChat:(int64_t)chatId;

- (void)openContentOfMessage:(int64_t)messageId inChat:(int64_t)chatId;

- (void)ownerAfterLeavingChat:(int64_t)chatId
				   completion:(void (^)(NSDictionary *user))completion;

- (void)parseMarkdownText:(NSString *)text
			   completion:(void (^)(NSDictionary *formatted))completion;

- (void)pinMessage:(int64_t)messageId inChat:(int64_t)chatId notify:(BOOL)notify;

- (void)pinnedMessageForChat:(int64_t)chatId
                  completion:(void (^)(NSDictionary *message))completion;

- (void)pollVoteStatisticsOfMessage:(int64_t)messageId
							 inChat:(int64_t)chatId
						 completion:(void (^)(NSDictionary *graph))completion;

- (void)pollVotersOfOption:(NSInteger)optionIndex
                ofMessage:(int64_t)messageId
                     inChat:(int64_t)chatId
                completion:(void (^)(NSArray *voters, BOOL end))completion;

- (void)positionOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
				   thread:(int64_t)threadId
			   completion:(void (^)(NSInteger position))completion;

- (void)pressCallbackButton:(NSDictionary *)button
					 inChat:(int64_t)chatId
				  messageId:(int64_t)messageId
				 completion:(void (^)(NSString *text, BOOL alert, NSString *url,
									  NSString *error))completion;

- (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion;

- (void)processAllJoinRequests:(int64_t)chatId
						  link:(NSString *)link
					   approve:(BOOL)approve
					completion:(void (^)(BOOL ok))completion;

- (void)processJoinRequest:(int64_t)userId inChat:(int64_t)chatId approve:(BOOL)approve;

- (void)publicForwardsOfMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(NSArray *messages))completion;

- (void)publicMessagesByTag:(NSString *)tag
					 offset:(NSString *)offset
				completion:(void (^)(NSArray *messages, NSString *next))completion;

- (void)rateSpeechInChat:(int64_t)chatId
				 message:(int64_t)messageId
					isGood:(BOOL)isGood
			  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reactTo:(int64_t)messageId inChat:(int64_t)chatId emoji:(NSString *)emoji;

- (void)readAllChatPollVotes:(int64_t)chatId;

- (void)readAllDirectMessagesChatTopicReactions:(int64_t)topicId
                                         inChat:(int64_t)chatId
                                     completion:(void (^)(BOOL ok,
                                                          NSString *error))completion;

- (void)readAllMentionsAndReactionsInChat:(int64_t)chatId;

- (void)readDateOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
			   completion:(void (^)(NSTimeInterval date, NSString *reason))completion;

- (void)readdQuickReplyShortcutMessages:(NSArray *)messageIds
                           shortcutName:(NSString *)shortcutName
                             completion:(void (^)(NSArray *messages, NSString *error))completion;

- (void)recentLocationsInChat:(int64_t)chatId
				   completion:(void (^)(NSArray *messages))completion;

- (void)recognizeSpeechInChat:(int64_t)chatId
					  message:(int64_t)messageId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)recommendedChatsWithCompletion:(void (^)(NSArray *chats))completion;

- (void)removeActionBarInChat:(int64_t)chatId;

- (void)removeReaction:(NSString *)emoji
		   fromMessage:(int64_t)messageId
				inChat:(int64_t)chatId;

- (void)reorderQuickReplyShortcuts:(NSArray *)shortcutIds
                        completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)repliedMessageTo:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(NSDictionary *message))completion;

- (void)replyKeyboardForChat:(int64_t)chatId completion:(void (^)(NSDictionary *keyboard))completion;

- (void)reportChat:(int64_t)chatId
		  optionId:(NSString *)optionId
			  text:(NSString *)text
		completion:(void (^)(NSString *title, NSArray *options, BOOL done))completion;

- (void)reportChatPhotoInChat:(int64_t)chatId
					   reason:(NSString *)reason
					   detail:(NSString *)detail
				   completion:(void (^)(BOOL ok))completion;

- (void)reportReactionBySender:(NSDictionary *)sender
					 ofMessage:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^)(BOOL ok))completion;

- (void)reportSpamMessages:(NSArray *)messageIds
				    inChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion;

- (void)reportViewOfMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				timeInViewMs:(NSInteger)timeInViewMs
		  activeTimeInViewMs:(NSInteger)activeTimeInViewMs
				 heightRatio:(NSInteger)heightPerMille
			   seenRangeRatio:(NSInteger)seenPerMille
				 completion:(void (^)(BOOL ok))completion;

- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *result))completion;

- (int64_t)savedMessagesChatId;

- (void)savedTopicMessageAtDate:(int64_t)topicId
						 date:(NSInteger)date
					completion:(void (^)(NSDictionary *message))completion;

- (void)savedTopicsTags:(int64_t)topicId
			 completion:(void (^)(NSArray *tags))completion;

- (void)scheduledMessagesInChat:(int64_t)chatId
                     completion:(void (^)(NSArray *messages))completion;

- (void)searchInChat:(int64_t)chatId query:(NSString *)query
          completion:(void (^)(NSArray *messages))completion;

- (void)searchQuote:(NSString *)quote
			 inText:(NSString *)text
		   position:(NSInteger)position
		 completion:(void (^)(NSInteger position, BOOL found))completion;

- (void)searchSavedMessagesInTopic:(int64_t)topicId
							 query:(NSString *)query
							 tag:(NSDictionary *)tag
							  from:(int64_t)fromMessageId
					completion:(void (^)(NSArray *found, int64_t next))completion;

- (void)searchUserByToken:(NSString *)token
			   completion:(void (^)(NSDictionary *user, NSString *error))completion;

- (void)secretChatIdForChat:(int64_t)chatId
				 completion:(void (^)(NSInteger secretChatId))completion;

- (void)secretChatState:(NSInteger)secretChatId
			 completion:(void (^)(NSString *state, BOOL outgoing))completion;



























- (void)sendTypingToChat:(int64_t)chatId thread:(int64_t)threadId;







- (void)setAvailableReactionsForChat:(int64_t)chatId
								mode:(NSString *)mode
						  completion:(void (^)(BOOL ok))completion;

- (void)setChat:(int64_t)chatId muted:(BOOL)muted;

- (void)setChatAccentColour:(int64_t)chatId colourId:(NSInteger)colourId;

- (void)setChatBackground:(int64_t)chatId
				imagePath:(NSString *)imagePath
				   colour:(NSInteger)colour
			  onlyForSelf:(BOOL)onlyForSelf
			   completion:(void (^)(BOOL ok))completion;

- (void)setChatProfileAccentColour:(int64_t)chatId colourId:(NSInteger)colourId;

- (void)setChatTheme:(int64_t)chatId name:(NSString *)name
		  completion:(void (^)(BOOL ok))completion;

- (void)setClientNote:(NSString *)note forChat:(int64_t)chatId
		   completion:(void (^)(BOOL ok))completion;

- (void)setDefaultReactionEmoji:(NSString *)emoji
                     completion:(void (^)(BOOL ok))completion;

- (void)setDirectMessagesChatTopic:(int64_t)topicId
                            inChat:(int64_t)chatId
                  markedAsUnread:(BOOL)markedAsUnread
                        completion:(void (^)(BOOL ok,
                                             NSString *error))completion;

- (void)setDiscussionGroup:(int64_t)discussionChatId
				   forChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion;

- (void)setDraft:(NSString *)text
		  inChat:(int64_t)chatId
		  thread:(int64_t)threadId
		 replyTo:(int64_t)replyToId;

- (void)setEmojiPhotoForChat:(int64_t)chatId
				customEmojiId:(int64_t)customEmojiId
					   colour:(NSInteger)colour
				   completion:(void (^)(BOOL ok))completion;

- (void)setGameScoreForChat:(int64_t)chatId
					message:(int64_t)messageId
					 user:(int64_t)userId
					  score:(int32_t)score
					  force:(BOOL)force
			 editMessage:(BOOL)editMessage
				 completion:(void (^)(NSDictionary *message,
									  NSString *error))completion;

- (void)setInlineGameScore:(NSString *)inlineMessageId
					  user:(int64_t)userId
					 score:(int32_t)score
					 force:(BOOL)force
			   editMessage:(BOOL)editMessage
				completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setLocationAddress:(NSString *)address
				   forChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion;

- (void)setMessageFactCheck:(int64_t)messageId
                     inChat:(int64_t)chatId
                       text:(NSString *)text
                 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setPinnedSavedTopics:(NSArray *)topicIds;

- (void)setQuickReplyShortcutName:(NSInteger)shortcutId
                             name:(NSString *)name
                       completion:(void (^)(BOOL ok, NSString *error))completion;



- (void)setSlowModeDelayForChat:(int64_t)chatId
						seconds:(NSInteger)seconds
					 completion:(void (^)(BOOL ok))completion;

- (void)setSticker:(NSInteger)fileId favourite:(BOOL)favourite;

- (void)setStickerSet:(id)setId installed:(BOOL)installed archived:(BOOL)archived;

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked;

- (void)sharePhoneNumberWithUser:(int64_t)userId;

- (void)sparsePositionsInChat:(int64_t)chatId
				fromMessageId:(int64_t)fromMessageId
					   thread:(int64_t)threadId
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *messageIds))completion;

- (void)stakeDiceStateWithCompletion:(void (^)(NSDictionary *state,
                                              NSString *error))completion;

- (void)statisticsOfMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSDictionary *statistics))completion;

- (void)statusForUser:(int64_t)userId completion:(void (^)(NSString *status))completion;

- (void)stickerSetByShortName:(NSString *)shortName
				   completion:(void (^)(NSDictionary *set))completion;

- (void)stopPoll:(int64_t)messageId inChat:(int64_t)chatId;

- (void)suggestedPostForMessage:(int64_t)messageId
                         inChat:(int64_t)chatId
                     completion:(void (^)(NSDictionary *post, NSString *error))completion;

- (void)suitableDiscussionChatsWithCompletion:(void (^)(NSArray *chats))completion;

- (void)summarizeMessage:(int64_t)messageId
                  inChat:(int64_t)chatId
             translateTo:(NSString *)languageCode
                    tone:(NSString *)tone
              completion:(void (^)(NSString *text, NSString *error))completion;

- (void)textEntitiesInText:(NSString *)text
				completion:(void (^)(NSArray *entities))completion;

- (NSString *)titleForChat:(int64_t)chatId;

- (void)toggleDefaultSilentForChat:(int64_t)chatId on:(BOOL)on;

- (void)toggleProtectedContentForChat:(int64_t)chatId
								   on:(BOOL)on
						   completion:(void (^)(BOOL ok))completion;

- (void)toggleSavedTopicPinned:(int64_t)topicId pinned:(BOOL)pinned;

- (void)toggleTranslatableForChat:(int64_t)chatId on:(BOOL)on;

- (void)topChatsWithCompletion:(void (^)(NSArray *chats))completion;

- (void)translateMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
				 toCode:(NSString *)languageCode
			  completion:(void (^)(NSString *text))completion;

- (void)translateMessageRichMessage:(int64_t)messageId
                             inChat:(int64_t)chatId
                             toCode:(NSString *)languageCode
                               tone:(NSString *)tone
                         completion:(void (^)(NSString *text, NSString *error))completion;

- (void)translateText:(NSString *)text
	   toLanguageCode:(NSString *)languageCode
				 tone:(NSString *)tone
		   completion:(void (^)(NSString *text))completion;

- (void)unpinAllDirectMessagesChatTopicMessages:(int64_t)topicId
                                         inChat:(int64_t)chatId
                                     completion:(void (^)(BOOL ok,
                                                          NSString *error))completion;

- (void)unpinAllMessagesInChat:(int64_t)chatId thread:(int64_t)threadId;

- (void)unpinMessage:(int64_t)messageId inChat:(int64_t)chatId;

- (void)userForPhone:(NSString *)phone completion:(void (^)(NSDictionary *user))completion;

- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion;

- (void)viewersOfMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^)(NSArray *viewers))completion;

- (void)votePoll:(int64_t)messageId inChat:(int64_t)chatId options:(NSArray *)optionIds;

- (void)webBrowserTypeForURL:(NSString *)url
				  completion:(void (^)(NSString *kind))completion;

@end
