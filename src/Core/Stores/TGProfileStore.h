//
// TGProfileStore.h - the Profile feature's store surface.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TGClientTypes.h"
#import "TGClientNotifications.h"
#import "TGDownloadPriority.h"

@interface TGProfileStore : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSDictionary *me;
@property (nonatomic, readonly) NSArray *communities;
@property (nonatomic, readonly) TGConnectionState connectionState;

- (UIColor *)accentColourForId:(NSInteger)colourId profile:(BOOL)profile;

- (void)addProfileAudioAtPath:(NSString *)path
                        title:(NSString *)title
                    performer:(NSString *)performer
                     duration:(NSInteger)duration
                   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)archivedStoriesForChat:(int64_t)chatId
					completion:(void (^)(NSArray *))completion;

- (NSArray *)availableAccentColorIds;

- (NSArray *)availableProfileAccentColorIds;

- (void)bioLengthMaxWithCompletion:(void (^)(NSInteger maxLength))completion;

- (NSDictionary *)cachedCommunityFullInfo:(int64_t)communityId;

- (void)canSendMessageToUser:(int64_t)userId
				  completion:(void (^)(NSString *result))completion;

- (BOOL)chatIsSavedMessages:(int64_t)chatId;

- (void)chatMember:(int64_t)userId
			 inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *member))completion;

- (void)chatProfile:(int64_t)chatId completion:(void (^)(NSDictionary *info))completion;

- (void)chatRecordForChat:(int64_t)chatId
			   completion:(void (^)(NSDictionary *chat))completion;

- (void)chatWithViewAsTopics:(int64_t)chatId
				  completion:(void (^)(BOOL viewAsTopics))completion;

- (void)clearHistoryInChat:(int64_t)chatId;

- (void)clearProfileShareThemeForChat:(int64_t)chatId
						   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)clearRecentEmojiStatusesWithCompletion:(void (^)(BOOL ok, NSString *error))completion;

- (void)communityFullInfo:(int64_t)communityId
               completion:(void (^)(NSDictionary *info, NSString *error))completion;

- (void)createSecretChatWithUser:(int64_t)userId
					  completion:(void (^)(int64_t chatId))completion;

- (void)customEmojiStickersForIds:(NSArray *)ids
					   completion:(void (^)(NSArray *stickers))completion;

- (void)defaultChatEmojiStatusesWithCompletion:(void (^)(NSArray *emojiIds))completion;

- (void)defaultEmojiStatusesWithCompletion:(void (^)(NSArray *emojiIds))completion;

- (void)deleteChat:(int64_t)chatId;

- (void)deleteChatForEveryone:(int64_t)chatId completion:(void (^)(NSString *error))completion;

- (void)deleteProfilePhoto:(int64_t)photoId
				completion:(void (^)(BOOL ok))completion;

- (void)deleteStory:(int32_t)storyId
		   fromChat:(int64_t)chatId
		 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)disallowedChatEmojiStatusesWithCompletion:(void (^)(NSArray *emojiIds))completion;

- (void)downloadFile:(NSInteger)fileId completion:(void (^)(NSString *path))completion;

- (void)downloadFile:(NSInteger)fileId priority:(NSInteger)priority completion:(void (^)(NSString *path))completion;

- (int64_t)emojiStatusIdForUser:(int64_t)userId;

- (void)giftsForOwner:(NSDictionary *)ownerId
			   offset:(NSString *)offset
		   completion:(void (^)(NSArray *gifts, NSString *nextOffset, NSInteger totalCount))completion;

- (void)groupsInCommonWithUser:(int64_t)userId
					completion:(void (^)(NSArray *chats))completion;

- (void)historyForChat:(int64_t)chatId
                 limit:(NSInteger)limit
            completion:(void (^)(NSArray *messages))completion;

- (BOOL)isChatMuted:(int64_t)chatId;

- (void)isProfileAudioFileId:(NSInteger)fileId
                  completion:(void (^)(BOOL isProfileAudio,
                                       NSString *error))completion;

- (void)logOut;

- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter
         completion:(void (^)(NSArray *messages))completion;

- (void)mediaInChat:(int64_t)chatId filter:(NSString *)filter
      fromMessageId:(int64_t)fromMessageId limit:(NSInteger)limit
         completion:(void (^)(NSArray *messages))completion;

- (void)memberCountForChat:(int64_t)chatId completion:(void (^)(NSInteger count))completion;

- (void)membersOfChat:(int64_t)chatId completion:(void (^)(NSArray *members))completion;

- (void)messageCountInChat:(int64_t)chatId
					filter:(NSString *)filterType
				completion:(void (^)(NSInteger count))completion;

- (void)myAccentColoursWithCompletion:(void (^)(NSInteger accentId,
											   NSInteger profileAccentId,
											   int64_t backgroundEmojiId,
											   int64_t profileBackgroundEmojiId))completion;

- (void)myBirthdayWithCompletion:(void (^)(NSInteger day, NSInteger month,
                                           NSInteger year))completion;

- (void)myMainProfileTabWithCompletion:(void (^)(NSString *tab))completion;

- (void)myUserLink:(void (^)(NSString *link))completion;

- (void)openSimilarChat:(int64_t)openedChatId fromChat:(int64_t)chatId;

- (NSNumber *)photoFileIdForUserId:(int64_t)userId;

- (void)privacyRule:(NSString *)setting
         completion:(void (^)(NSString *value))completion;

- (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion;

- (void)profileAudiosForUser:(int64_t)userId
                      offset:(NSInteger)offset
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray *audios, NSInteger total,
                                       NSString *error))completion;

- (void)profileShareThemeBackdropsWithCompletion:(void (^)(NSArray *backdrops,
														  NSString *error))completion;

- (void)recentEmojiStatusesWithCompletion:(void (^)(NSArray *statuses))completion;

- (void)removeContactWithUserId:(int64_t)userId completion:(void (^)(BOOL ok))completion;

- (void)removeProfileAudioFileId:(NSInteger)fileId
                     completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reportChat:(int64_t)chatId
		  optionId:(NSString *)optionId
			  text:(NSString *)text
		completion:(void (^)(NSString *title, NSArray *options, BOOL done))completion;

- (void)request:(NSDictionary *)request completion:(void (^)(NSDictionary *result))completion;

- (int64_t)savedMessagesChatId;

- (void)sendText:(NSString *)text toChat:(int64_t)chatId;

- (void)setAccountAccentColorPreservingBackgroundEmoji:(NSInteger)accentId
											completion:(void (^)(BOOL ok,
																 NSString *error))completion;

- (void)setAccountProfileAccentColorPreservingBackgroundEmoji:(NSInteger)accentId
												   completion:(void (^)(BOOL ok,
																		 NSString *error))completion;

- (void)setBio:(NSString *)bio
	completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setBirthdayDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year
			completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setChat:(int64_t)chatId autoDeleteSeconds:(NSInteger)seconds;

- (void)setChat:(int64_t)chatId muted:(BOOL)muted;

- (void)setChatEmojiStatus:(int64_t)customEmojiId
            expirationDate:(NSInteger)expirationDate
                    inChat:(int64_t)chatId
                completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setChatViewAsTopics:(int64_t)chatId
			   viewAsTopics:(BOOL)viewAsTopics
				 completion:(void (^)(BOOL ok))completion;

- (void)setEmojiStatus:(int64_t)customEmojiId
        expirationDate:(NSInteger)expirationDate
            completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setMainProfileTab:(NSString *)tab
			   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setName:(NSString *)firstName
			last:(NSString *)lastName
	  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setPersonalChat:(int64_t)chatId completion:(void (^)(BOOL ok))completion;

- (void)setPersonalProfilePhotoAtPath:(NSString *)path
							  forUser:(int64_t)userId
						   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value;
- (void)setPrivacyRule:(NSString *)setting to:(NSString *)value
			completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setProfileAudioFileId:(NSInteger)fileId
                  afterFileId:(NSInteger)afterFileId
                   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setProfilePhotoAtPath:(NSString *)path completion:(void (^)(BOOL ok))completion;

- (void)setProfileShareThemeForChat:(int64_t)chatId
						 backdropId:(NSInteger)backdropId
						 useDefault:(BOOL)useDefault
						 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setSupergroupMainProfileTab:(NSString *)tab
							 inChat:(int64_t)chatId
						 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setUser:(int64_t)userId blocked:(BOOL)blocked completion:(void (^)(BOOL ok))completion;

- (void)setUserEmojiStatus:(int64_t)customEmojiId
            expirationDate:(NSInteger)expirationDate
                   forUser:(int64_t)userId
                completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setUserNote:(NSString *)note
			forUser:(int64_t)userId
		 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)similarChatsForChat:(int64_t)chatId
				 completion:(void (^)(NSArray *chats, NSInteger total))completion;

- (void)storiesForChat:(int64_t)chatId completion:(void (^)(NSArray *stories))completion;

- (void)suggestBirthdateDay:(NSInteger)day
					  month:(NSInteger)month
					   year:(NSInteger)year
					 forUser:(int64_t)userId
				  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)suggestProfilePhotoAtPath:(NSString *)path
						  forUser:(int64_t)userId
					   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)suitablePersonalChatsWithCompletion:(void (^)(NSArray *chats))completion;

- (void)supergroupSettingsForChat:(int64_t)chatId
						completion:(void (^)(NSDictionary *settings))completion;

- (void)themedChatEmojiStatusesWithCompletion:(void (^)(NSArray *emojiIds))completion;

- (void)themedEmojiStatusesWithCompletion:(void (^)(NSArray *emojiIds))completion;

- (NSString *)titleForChat:(int64_t)chatId;

- (void)toggleStory:(int32_t)storyId
			 fromChat:(int64_t)chatId
	  postedToChatPage:(BOOL)posted
		  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)userInfo:(int64_t)userId completion:(void (^)(NSDictionary *user))completion;

- (BOOL)userIsBot:(int64_t)userId;

- (void)userProfile:(int64_t)userId completion:(void (^)(NSDictionary *info))completion;

- (void)userProfilePhotos:(int64_t)userId
			   completion:(void (^)(NSArray *photos))completion;

@end
