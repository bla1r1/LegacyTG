//
// TGGroupStore.h - the group screens' boundary to TDLib.
//
// Members, invites, forum topics, permissions, usernames, communities,
// welcomes and message import all live here; the group screens never import
// TGClient.h. The request bodies are in the TGGroupStore+*.m files.
//
#import <Foundation/Foundation.h>
#import "TGClientTypes.h"

/// The status word a member record names: owner, administrator, member,
/// restricted, banned or left.
FOUNDATION_EXPORT NSString *TGGroupMemberStatusName(NSDictionary *status);

@interface TGGroupStore : NSObject

+ (instancetype)shared;

- (void)forumTopicsForChat:(int64_t)chatId completion:(void (^)(NSArray *))completion;
- (void)toggleGeneralForumTopicHidden:(BOOL)hidden
                               inChat:(int64_t)chatId
                           completion:(void (^)(BOOL, NSString *))completion;
- (void)createForumTopicInChat:(int64_t)chatId
						  name:(NSString *)name
				   iconColour:(NSInteger)colour
				  iconEmojiId:(int64_t)iconEmojiId
				   completion:(void (^)(int64_t threadId, NSString *name))completion;
- (void)forumTopicDefaultIconsWithCompletion:(void (^)(NSArray *))completion;
- (void)toggleForumTopic:(int64_t)threadId inChat:(int64_t)chatId pinned:(BOOL)pinned;
- (void)toggleForumTopic:(int64_t)threadId inChat:(int64_t)chatId closed:(BOOL)closed;
- (void)deleteForumTopic:(int64_t)threadId inChat:(int64_t)chatId;
- (void)setForumTopicIcon:(int64_t)iconEmojiId
				 threadId:(int64_t)threadId
				   inChat:(int64_t)chatId
			   completion:(void (^)(BOOL ok))completion;
- (void)renameForumTopic:(int64_t)threadId
				   inChat:(int64_t)chatId
					 name:(NSString *)name
			 iconEmojiId:(int64_t)iconEmojiId
			  completion:(void (^)(BOOL ok))completion;
- (void)readAllForumTopicMentionsInChat:(int64_t)chatId
                                  topic:(int64_t)threadId
                             completion:(void (^)(BOOL, NSString *))completion;
- (void)readAllForumTopicPollVotesInChat:(int64_t)chatId
                                   topic:(int64_t)threadId
                              completion:(void (^)(BOOL, NSString *))completion;
- (void)readAllForumTopicReactionsInChat:(int64_t)chatId
                                  topic:(int64_t)threadId
                             completion:(void (^)(BOOL))completion;
- (void)forumTopic:(int64_t)threadId
            inChat:(int64_t)chatId
        completion:(void (^)(NSDictionary *))completion;
- (void)forumTopicLinkForTopic:(int64_t)threadId
                         inChat:(int64_t)chatId
                     completion:(void (^)(NSString *))completion;
- (void)setForumTopicNotificationSettings:(NSDictionary *)settings
                                    topic:(int64_t)threadId
                                   inChat:(int64_t)chatId
                               completion:(void (^)(BOOL, NSString *))completion;
- (void)setPinnedForumTopics:(NSArray *)topicIds
                      inChat:(int64_t)chatId
                  completion:(void (^)(BOOL, NSString *))completion;
- (void)antiSpamFalsePositiveCandidatesForChat:(int64_t)chatId
									completion:(void (^)(NSArray *, NSString *))completion;
- (void)reportAntiSpamFalsePositiveInChat:(int64_t)chatId
								messageId:(int64_t)messageId
							   completion:(void (^)(BOOL, NSString *))completion;
- (void)setDefaultChannelAdministratorRightsPreset:(NSString *)preset
										completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setDefaultGroupAdministratorRightsPreset:(NSString *)preset
									  completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setCommunityName:(int64_t)communityId
                    name:(NSString *)name
              completion:(void (^)(BOOL, NSString *))completion;
- (void)setCommunityPermissions:(int64_t)communityId
                  canEditChatList:(BOOL)canEditChatList
                      completion:(void (^)(BOOL, NSString *))completion;
- (void)setCommunityPhoto:(int64_t)communityId
                     path:(NSString *)path
               completion:(void (^)(BOOL, NSString *))completion;
- (void)deleteCommunity:(int64_t)communityId
             completion:(void (^)(BOOL, NSString *))completion;
- (void)administratorsOfChat:(int64_t)chatId
				  completion:(void (^)(NSArray *admins))completion;
- (void)setMember:(int64_t)userId
		   inChat:(int64_t)chatId
		   status:(NSString *)status
	   completion:(void (^)(BOOL ok))completion;
- (void)deleteChatMessagesBySender:(NSDictionary *)sender
							inChat:(int64_t)chatId
							revoke:(BOOL)revoke;
- (void)banMember:(int64_t)userId
		   inChat:(int64_t)chatId
   revokeMessages:(BOOL)revokeMessages
	   completion:(void (^)(BOOL ok))completion;
- (void)canTransferOwnershipWithCompletion:
		(void (^)(NSString *result, NSInteger retryAfter,
				  NSString *error))completion;
- (void)hasPasswordWithCompletion:(void (^)(BOOL, NSString *))completion;
- (void)transferOwnershipOfChat:(int64_t)chatId
						 toUser:(int64_t)userId
					   password:(NSString *)password
					 completion:(void (^)(BOOL ok))completion;
- (void)createCommunity:(NSString *)name
                 chatId:(int64_t)chatId
                 hidden:(BOOL)hidden
             completion:(void (^)(int64_t, NSString *))completion;
- (void)reorderSupergroupActiveUsernames:(NSArray *)usernames
								  inChat:(int64_t)chatId
							  completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setChatPermissionsFromPreset:(NSString *)preset
							   inChat:(int64_t)chatId
						  completion:(void (^)(BOOL ok))completion;
- (void)convertSupergroupToBroadcastInChat:(int64_t)chatId
								completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)welcomeMessagesOfChat:(int64_t)chatId
				   completion:(void (^)(NSArray *welcomes))completion;
- (void)clearAllWelcomeMessagesInChat:(int64_t)chatId;
- (void)deleteWelcomeMessage:(int64_t)messageId inChat:(int64_t)chatId;
- (void)addWelcomeMessageToChat:(int64_t)chatId
						   text:(NSString *)text
					 completion:(void (^)(BOOL ok))completion;
- (void)setWelcomeMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
					 text:(NSString *)text
			   completion:(void (^)(BOOL ok))completion;
- (void)searchMembersInChat:(int64_t)chatId
					  query:(NSString *)query
				 completion:(void (^)(NSArray *members))completion;
- (void)availableMessageSendersInChat:(int64_t)chatId
						   completion:(void (^)(NSArray *senders))completion;
- (void)setMessageSender:(NSDictionary *)sender
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion;
- (void)setDirectMessagesEnabled:(BOOL)enabled
					   paidStars:(NSInteger)paidStars
						  inChat:(int64_t)chatId
					  completion:(void (^)(BOOL ok))completion;
- (void)deleteChatMessagesByDate:(int64_t)chatId
						 minDate:(NSInteger)minDate
						 maxDate:(NSInteger)maxDate
						  revoke:(BOOL)revoke;
- (void)setSupergroupCustomEmojiStickerSet:(int64_t)setId
									inChat:(int64_t)chatId
								completion:(void (^)(BOOL))completion;
- (void)setSupergroupStickerSet:(int64_t)setId
						inChat:(int64_t)chatId
					completion:(void (^)(BOOL))completion;
- (void)messageFileTypeForHead:(NSString *)head
					completion:(void (^)(NSDictionary *fileType))completion;
- (void)importConfirmationTextForChat:(int64_t)chatId
						   completion:(void (^)(NSString *text))completion;
- (void)importMessagesFromFile:(NSString *)path
				 attachedFiles:(NSArray *)attachedPaths
					  intoChat:(int64_t)chatId
					completion:(void (^)(BOOL ok))completion;
- (void)inviteLinksForChat:(int64_t)chatId
				completion:(void (^)(NSArray *links))completion;
- (void)createInviteLinkForChat:(int64_t)chatId
						   name:(NSString *)name
					memberLimit:(NSInteger)memberLimit
					 completion:(void (^)(NSString *link))completion;
- (void)editSubscriptionInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							  name:(NSString *)name
						completion:(void (^)(BOOL ok))completion;
- (void)editInviteLink:(NSString *)link
				inChat:(int64_t)chatId
				  name:(NSString *)name
			expiration:(NSInteger)expiration
		   memberLimit:(NSInteger)memberLimit
		   joinRequest:(BOOL)joinRequest
			completion:(void (^)(BOOL ok))completion;
- (void)deleteRevokedInviteLink:(NSString *)link
						 inChat:(int64_t)chatId
					 completion:(void (^)(BOOL ok))completion;
- (void)replacePrimaryInviteLinkForChat:(int64_t)chatId
							 completion:(void (^)(NSString *link))completion;
- (void)revokeInviteLink:(NSString *)link
				  inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion;
- (void)membersOfInviteLink:(NSString *)link
					 inChat:(int64_t)chatId
				 completion:(void (^)(NSArray *members))completion;
- (void)inviteLinkCountsForChat:(int64_t)chatId
					 completion:(void (^)(NSArray *counts))completion;
- (void)createSubscriptionInviteLink:(int64_t)chatId
								name:(NSString *)name
							   stars:(NSInteger)stars
							  period:(NSInteger)period
						  completion:(void (^)(NSString *link))completion;
- (void)deleteAllRevokedInviteLinks:(int64_t)chatId
							creator:(int64_t)creatorId
						 completion:(void (^)(BOOL ok))completion;
- (void)supergroupSettingsForChat:(int64_t)chatId
						completion:(void (^)(NSDictionary *settings))completion;
- (void)supergroupFlagsForChat:(int64_t)chatId
					completion:(void (^)(BOOL signMessages, BOOL joinToSend,
										 BOOL allHistory, BOOL ok))completion;
- (void)setChat:(int64_t)chatId
		  title:(NSString *)title
	 completion:(void (^)(BOOL ok))completion;
- (void)setChat:(int64_t)chatId
	description:(NSString *)description
	 completion:(void (^)(BOOL ok))completion;
- (void)setChat:(int64_t)chatId
	photoAtPath:(NSString *)path
	 completion:(void (^)(BOOL ok))completion;
- (void)upgradeGroupToSupergroup:(int64_t)chatId
					  completion:(void (^)(int64_t newChatId))completion;
- (void)toggleSupergroupUsernameIsActive:(NSString *)username
								  inChat:(int64_t)chatId
								isActive:(BOOL)isActive
							  completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setChatSignMessages:(int64_t)chatId
						 on:(BOOL)on
				 completion:(void (^)(BOOL ok))completion;
- (void)setChatJoinToSendMessages:(int64_t)chatId
							   on:(BOOL)on
					   completion:(void (^)(BOOL ok))completion;
- (void)setSupergroupAllHistoryAvailable:(int64_t)chatId
									  on:(BOOL)on
							  completion:(void (^)(BOOL ok))completion;
- (void)setChat:(int64_t)chatId
	aggressiveAntiSpam:(BOOL)on
			 completion:(void (^)(BOOL, NSString *))completion;
- (void)setSupergroupHiddenMembersInChat:(int64_t)chatId
									 on:(BOOL)on
							 completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setSupergroupForumInChat:(int64_t)chatId
							  on:(BOOL)on
					  completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setSupergroupJoinByRequestInChat:(int64_t)chatId
									 on:(BOOL)on
						   guardBotUserId:(int64_t)guardBotUserId
							 completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)setSupergroupAutomaticTranslationInChat:(int64_t)chatId
											 on:(BOOL)on
									 completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)deleteChat:(int64_t)chatId;
- (void)deleteChatForEveryone:(int64_t)chatId completion:(void (^)(NSString *error))completion;
- (void)setSupergroupUsername:(NSString *)username
					   inChat:(int64_t)chatId
				   completion:(void (^)(BOOL ok, NSString *error))completion;
- (void)disableAllSupergroupUsernamesInChat:(int64_t)chatId
								 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setMemberTag:(NSString *)tag
			  forUser:(int64_t)userId
			   inChat:(int64_t)chatId
		   completion:(void (^)(BOOL ok))completion;

- (void)inviteLink:(NSString *)link
			inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *info))completion;

@end
