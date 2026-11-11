//
// TGDevStore.h - the Dev screens' store surface.
//
// The Dev hub, bot console, environment, test harness, file tools, proxy
// carrier and showcase are diagnostics: each row sends one real TDLib
// request and prints the answer. The request bodies live here, in the same
// thematic extensions the client categories used, so the screens never
// import TGClient or one of its duty headers.
//
#import <Foundation/Foundation.h>

@interface TGDevStore : NSObject

+ (instancetype)shared;

#pragma mark - suggestions

/// Fixtures name the peers they draw before a header is asked who sent them.
- (void)setDisplayName:(NSString *)name forUserId:(int64_t)userId;

/// The SuggestedAction rows from updateSuggestedActions.
@property (nonatomic, readonly) NSArray *suggestedActions;

- (void)hideSuggestedAction:(NSDictionary *)action
				 completion:(void (^)(BOOL ok, NSString *error))completion;

#pragma mark - files

/// The upload progress of the generated file, as updateFile reports it.
@property (nonatomic, copy) void (^onFileUploadProgress)(NSInteger fileId, float progress);

- (void)readFilePartOfFile:(NSInteger)fileId
					offset:(long long)offset
					 count:(NSInteger)count
				completion:(void (^)(NSData *data))completion;

- (void)cancelPreliminaryUploadOfFile:(NSInteger)fileId;

- (void)generateTextFileNamed:(NSString *)name
					 contents:(NSString *)contents
					 progress:(void (^)(NSInteger fileId, float progress,
										NSString *stage))progress
				   completion:(void (^)(NSInteger fileId, NSString *path,
										NSError *error))completion;

#pragma mark - bot session and passkeys

- (void)checkAuthenticationBotToken:(NSString *)token
						 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)passkeyParametersWithCompletion:(void (^)(NSString *text,
												  NSString *error))completion;

- (void)authenticationPasskeyParametersWithCompletion:
		(void (^)(NSString *text, NSString *error))completion;

- (void)loginPasskeysWithCompletion:(void (^)(NSArray *passkeys,
											 NSString *error))completion;

- (void)addLoginPasskey:(NSString *)clientData
	  attestationObject:(NSString *)attestationObject
			 completion:(void (^)(NSDictionary *passkey,
								 NSString *error))completion;

- (void)removeLoginPasskey:(NSString *)passkeyId
				completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)checkAuthenticationPasskey:(NSString *)credentialId
						clientData:(NSString *)clientData
				   authenticatorData:(NSString *)authenticatorData
						   signature:(NSString *)signature
						userHandle:(NSString *)userHandle
						completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)commandsForScope:(NSString *)scope
				  chatId:(int64_t)chatId
				language:(NSString *)language
			  completion:(void (^)(NSDictionary *commands,
								   NSString *error))completion;

- (void)setCommands:(NSArray *)commands
			  scope:(NSString *)scope
			 chatId:(int64_t)chatId
		   language:(NSString *)language
		 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteCommandsForScope:(NSString *)scope
						chatId:(int64_t)chatId
					  language:(NSString *)language
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)menuButtonForBot:(int64_t)botUserId
			  completion:(void (^)(NSDictionary *button,
								   NSString *error))completion;

- (void)setMenuButtonForBot:(int64_t)botUserId
					   text:(NSString *)text
						url:(NSString *)url
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)managedBotTokenForBot:(int64_t)botUserId
					   revoke:(BOOL)revoke
				   completion:(void (^)(NSString *token,
										NSString *error))completion;

- (void)managedBotAccessSettingsForBot:(int64_t)botUserId
							completion:(void (^)(NSDictionary *settings,
												 NSString *error))completion;

- (void)setManagedBotAccessSettingsForBot:(int64_t)botUserId
							  restricted:(BOOL)restricted
							   addedUserIds:(NSArray *)userIds
								completion:(void (^)(BOOL ok,
													 NSString *error))completion;

- (void)setBotUpdatesStatus:(int32_t)pendingUpdateCount
			   errorMessage:(NSString *)errorMessage
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)answerInlineQuery:(int64_t)inlineQueryId
			   isPersonal:(BOOL)isPersonal
			  resultTitle:(NSString *)title
				 resultId:(NSString *)resultId
					  url:(NSString *)url
				 cacheTime:(int32_t)cacheTime
				nextOffset:(NSString *)nextOffset
				completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)answerCallbackQuery:(int64_t)callbackQueryId
					   text:(NSString *)text
				  showAlert:(BOOL)showAlert
						url:(NSString *)url
				  cacheTime:(int32_t)cacheTime
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)answerCustomQuery:(int64_t)customQueryId
					 data:(NSString *)data
			   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)answerGuestQuery:(int64_t)guestQueryId
			 resultTitle:(NSString *)title
				resultId:(NSString *)resultId
					 url:(NSString *)url
			  completion:(void (^)(NSString *inlineMessageId,
								   NSString *error))completion;

- (void)answerWebAppQuery:(NSString *)webAppQueryId
			  resultTitle:(NSString *)title
				 resultId:(NSString *)resultId
					  url:(NSString *)url
			   completion:(void (^)(NSString *inlineMessageId,
									NSString *error))completion;

- (void)answerPreCheckoutQuery:(int64_t)preCheckoutQueryId
				  errorMessage:(NSString *)errorMessage
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)answerShippingQuery:(int64_t)shippingQueryId
			   errorMessage:(NSString *)errorMessage
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)replyToCallbackQueryWithEphemeralMessage:(int64_t)callbackQueryId
										   text:(NSString *)text
					 replaceCallbackMessage:(BOOL)replaceCallbackMessage
							  protectContent:(BOOL)protectContent
								 completion:(void (^)(BOOL ok,
													  NSString *error))completion;

- (void)openWebAppInChat:(int64_t)chatId
				   bot:(int64_t)botUserId
					 url:(NSString *)url
				  mode:(NSString *)mode
			  completion:(void (^)(NSDictionary *info,
								   NSString *error))completion;

- (void)closeWebApp:(int64_t)launchId
		 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)checkWebAppFileDownload:(int64_t)botUserId
					   fileName:(NSString *)fileName
							url:(NSString *)url
					 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)guardBotWebAppURLForQuery:(int64_t)queryId
							 mode:(NSString *)mode
					   completion:(void (^)(NSString *link,
											NSString *error))completion;

- (void)sendWebAppData:(int64_t)botUserId
			buttonText:(NSString *)buttonText
				  data:(NSString *)data
			completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)sendWebAppCustomRequest:(int64_t)botUserId
						 method:(NSString *)method
					 parameters:(NSString *)parameters
					 completion:(void (^)(NSString *result,
										  NSString *error))completion;

#pragma mark - owned bots

- (void)ownedBotsWithCompletion:(void (^)(NSArray *bots,
										  NSString *error))completion;

- (void)checkBotUsername:(NSString *)username
			  isSecondary:(BOOL)isSecondary
			   completion:(void (^)(NSString *result,
									NSString *error))completion;

- (void)botNameForBot:(int64_t)botUserId
			 language:(NSString *)language
		   completion:(void (^)(NSString *name, NSString *error))completion;

- (void)setBotName:(NSString *)name
			forBot:(int64_t)botUserId
		  language:(NSString *)language
		completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)botDescriptionForBot:(int64_t)botUserId
					language:(NSString *)language
				  completion:(void (^)(NSString *text,
									   NSString *error))completion;

- (void)setBotDescription:(NSString *)text
				   forBot:(int64_t)botUserId
				 language:(NSString *)language
			   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)botShortDescriptionForBot:(int64_t)botUserId
						 language:(NSString *)language
					   completion:(void (^)(NSString *text,
											NSString *error))completion;

- (void)setBotShortDescription:(NSString *)text
						forBot:(int64_t)botUserId
					  language:(NSString *)language
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeBotProfilePhoto:(int64_t)botUserId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)addBotSecondaryUsername:(NSString *)username
						 forBot:(int64_t)botUserId
					 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteBotSecondaryUsernameForBot:(int64_t)botUserId
							  completion:(void (^)(BOOL ok,
												   NSString *error))completion;

- (void)setBotUsername:(NSString *)username
				active:(BOOL)active
				forBot:(int64_t)botUserId
			completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reorderBotActiveUsernames:(NSArray *)usernames
						   forBot:(int64_t)botUserId
					   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)botMediaPreviewsForBot:(int64_t)botUserId
					completion:(void (^)(NSArray *previews,
										 NSString *error))completion;

- (void)botMediaPreviewInfoForBot:(int64_t)botUserId
						 language:(NSString *)language
					   completion:(void (^)(NSDictionary *info,
											NSString *error))completion;

- (void)addBotMediaPreviewForBot:(int64_t)botUserId
						language:(NSString *)language
						  fileId:(int32_t)fileId
						   video:(BOOL)video
					  completion:(void (^)(NSDictionary *preview,
										   NSString *error))completion;

- (void)editBotMediaPreviewForBot:(int64_t)botUserId
						 language:(NSString *)language
						   fileId:(int32_t)fileId
					   newFileId:(int32_t)newFileId
							video:(BOOL)video
					   completion:(void (^)(NSDictionary *preview,
											NSString *error))completion;

- (void)deleteBotMediaPreviewsForBot:(int64_t)botUserId
							language:(NSString *)language
							 fileIds:(NSArray *)fileIds
						  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reorderBotMediaPreviewsForBot:(int64_t)botUserId
							 language:(NSString *)language
							  fileIds:(NSArray *)fileIds
						   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)similarBotCountForBot:(int64_t)botUserId
						local:(BOOL)localOnly
				   completion:(void (^)(int32_t count, NSString *error))completion;

- (void)similarBotsForBot:(int64_t)botUserId
			   completion:(void (^)(NSArray *bots, NSString *error))completion;

- (void)openSimilarBot:(int64_t)openedBotId
			   fromBot:(int64_t)botUserId
			completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setBotCanManageEmojiStatus:(BOOL)allowed
							forBot:(int64_t)botUserId
						completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setBotVerification:(int64_t)botUserId
			 verifiedKind:(NSString *)kind
				 verifiedId:(int64_t)verifiedId
				description:(NSString *)description
				 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeBotVerification:(int64_t)botUserId
				 verifiedKind:(NSString *)kind
					 verifiedId:(int64_t)verifiedId
				   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)createBotNamed:(NSString *)name
			  username:(NSString *)username
			  manager:(int64_t)managerBotId
			completion:(void (^)(NSDictionary *bot, NSString *error))completion;

- (void)recentInlineBotsWithCompletion:(void (^)(NSArray *bots,
												NSString *error))completion;

- (void)startBot:(int64_t)botUserId
		  inChat:(int64_t)chatId
	   parameter:(NSString *)parameter
	  completion:(void (^)(NSDictionary *message,
						   NSString *error))completion;

- (void)attachmentMenuBot:(int64_t)botUserId
			   completion:(void (^)(NSDictionary *bot,
									NSString *error))completion;

- (void)setBotOnAttachmentMenu:(int64_t)botUserId
					   added:(BOOL)added
			 allowWriteAccess:(BOOL)allowWriteAccess
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)canBotSendMessages:(int64_t)botUserId
				completion:(void (^)(BOOL can, NSString *error))completion;

- (void)allowBotToSendMessages:(int64_t)botUserId
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)addInlineResultToQuickReply:(NSString *)shortcutName
						 replyToId:(int64_t)replyToMessageId
						   queryId:(int64_t)queryId
						  resultId:(NSString *)resultId
						 hideViaBot:(BOOL)hideViaBot
						completion:(void (^)(NSDictionary *message,
											 NSString *error))completion;

#pragma mark - Web Apps and browser settings

- (void)setWebBrowserSettingsOpenExternal:(BOOL)openExternal
						displayCloseButton:(BOOL)displayCloseButton
							   completion:(void (^)(BOOL ok,
													NSString *error))completion;

- (void)addWebBrowserException:(NSString *)url
				  openExternal:(BOOL)openExternal
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeWebBrowserException:(NSString *)url
					   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeAllWebBrowserExceptionsWithCompletion:(void (^)(BOOL ok,
															 NSString *error))completion;

- (void)grossingWebAppBotsOffset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *bots, NSString *error))completion;

- (void)searchWebAppForBot:(int64_t)botUserId
				 shortName:(NSString *)shortName
				completion:(void (^)(NSDictionary *app, NSString *error))completion;

- (void)webAppPlaceholderForBot:(int64_t)botUserId
					 completion:(void (^)(NSString *outline, NSString *error))completion;

- (void)webAppURLForBot:(int64_t)botUserId
					url:(NSString *)url
				   mode:(NSString *)mode
			 completion:(void (^)(NSString *link, NSString *error))completion;

- (void)mainWebAppForBot:(int64_t)botUserId
				  chatId:(int64_t)chatId
		  startParameter:(NSString *)startParameter
					mode:(NSString *)mode
			  completion:(void (^)(NSString *link, NSString *error))completion;

- (void)webAppLinkURLForBot:(int64_t)botUserId
					 chatId:(int64_t)chatId
				  shortName:(NSString *)shortName
			 startParameter:(NSString *)startParameter
				 allowWrite:(BOOL)allowWrite
					   mode:(NSString *)mode
				 completion:(void (^)(NSString *link, NSString *error))completion;

- (void)shareChatWithBot:(int64_t)botUserId
			 sourceChat:(int64_t)sourceChatId
		  sourceMessage:(int64_t)sourceMessageId
			   buttonId:(int32_t)buttonId
			  sharedChat:(int64_t)sharedChatId
				checkOnly:(BOOL)checkOnly
			   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)shareUsersWithBot:(int64_t)botUserId
			  sourceChat:(int64_t)sourceChatId
		   sourceMessage:(int64_t)sourceMessageId
				buttonId:(int32_t)buttonId
				 userIds:(NSArray *)userIds
			   checkOnly:(BOOL)checkOnly
			  completion:(void (^)(BOOL ok, NSString *error))completion;

#pragma mark - OAuth

- (void)oauthLinkInfo:(NSString *)url
			   origin:(NSString *)origin
		   completion:(void (^)(NSDictionary *info,
								NSString *error))completion;

- (void)checkOauthMatchCode:(NSString *)code
						forURL:(NSString *)url
					  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)acceptOauthRequest:(NSString *)url
				 matchCode:(NSString *)code
			allowWriteAccess:(BOOL)allowWriteAccess
		 allowPhoneNumberAccess:(BOOL)allowPhoneNumberAccess
				completion:(void (^)(NSString *link, NSString *error))completion;

- (void)declineOauthRequest:(NSString *)url
				 completion:(void (^)(BOOL ok, NSString *error))completion;

#pragma mark - business bot

- (void)businessConnectedBotWithCompletion:(void (^)(NSDictionary *bot,
													 NSString *error))completion;

- (void)setBusinessConnectedBot:(int64_t)botUserId
					 recipients:(NSDictionary *)recipients
					 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)deleteBusinessConnectedBot:(int64_t)botUserId
						completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)confirmBusinessConnectedBot:(int64_t)botUserId
						 completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeBusinessConnectedBotFromChat:(int64_t)chatId
								completion:(void (^)(BOOL ok,
													 NSString *error))completion;

- (void)pauseBusinessConnectedBotInChat:(int64_t)chatId
								 paused:(BOOL)paused
							 completion:(void (^)(BOOL ok, NSString *error))completion;

#pragma mark - environment

- (void)jsonValueForText:(NSString *)text
			  completion:(void (^)(NSDictionary *value,
								   NSString *error))completion;

- (void)jsonTextForValue:(NSDictionary *)value
			  completion:(void (^)(NSString *text,
								   NSString *error))completion;

- (void)themeParametersJSONString:(NSDictionary *)colours
					   completion:(void (^)(NSString *text,
											NSString *error))completion;

- (void)logStreamWithCompletion:(void (^)(NSDictionary *stream,
										  NSString *error))completion;

- (void)logVerbosityLevelWithCompletion:(void (^)(int32_t level,
												  NSString *error))completion;

- (void)logTagsWithCompletion:(void (^)(NSArray *tags, NSString *error))completion;

- (void)logVerbosityForTag:(NSString *)tag
				completion:(void (^)(int32_t level, NSString *error))completion;

- (void)setLogVerbosityForTag:(NSString *)tag
						level:(int32_t)level
				   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)setLogStreamKind:(NSString *)kind
					path:(NSString *)path
			  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)addLogMessage:(NSString *)text
				level:(int32_t)level
		   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)saveApplicationLogEvent:(NSString *)type
						chatId:(int64_t)chatId
						  data:(NSString *)data
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)timeZonesWithCompletion:(void (^)(NSArray *zones,
										  NSString *error))completion;

- (void)currencyExchangeRatesWithCompletion:(void (^)(NSArray *rates,
													 NSString *error))completion;

- (void)currentWeatherAtLatitude:(double)latitude
					   longitude:(double)longitude
					  completion:(void (^)(NSDictionary *weather,
										   NSString *error))completion;

- (void)alarmAfterSeconds:(double)seconds
			   completion:(void (^)(BOOL ok, NSString *error))completion;

#pragma mark - test harness

- (void)testCallEmptyWithCompletion:(void (^)(BOOL ok, NSString *error))completion;

- (void)testCallString:(NSString *)text
			completion:(void (^)(NSString *value, NSString *error))completion;

- (void)testCallBytes:(NSString *)base64
		   completion:(void (^)(NSString *base64, NSString *error))completion;

- (void)testCallVectorInt:(NSArray *)values
			   completion:(void (^)(NSArray *result, NSString *error))completion;

- (void)testCallVectorString:(NSArray *)values
				  completion:(void (^)(NSArray *result, NSString *error))completion;

- (void)testCallVectorIntObject:(NSArray *)values
					 completion:(void (^)(NSArray *result,
										  NSString *error))completion;

- (void)testCallVectorStringObject:(NSArray *)values
						completion:(void (^)(NSArray *result,
											 NSString *error))completion;

- (void)testSquareInt:(int32_t)value
		   completion:(void (^)(int32_t result, NSString *error))completion;

- (void)testReturnErrorCode:(int32_t)code
					message:(NSString *)message
				 completion:(void (^)(int32_t code, NSString *message,
									  NSString *error))completion;

- (void)testGetDifferenceWithCompletion:(void (^)(BOOL ok,
												  NSString *error))completion;

- (void)testNetworkWithCompletion:(void (^)(BOOL ok, NSString *error))completion;

- (void)testUseUpdateWithCompletion:(void (^)(NSDictionary *update,
											 NSString *error))completion;

#pragma mark - web proxy carrier

- (void)processWebProxyCarrierMessage:(NSInteger)carrierId
								 text:(NSString *)text
						   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)processWebProxyCarrierMessage:(NSInteger)carrierId
							  base64:(NSString *)base64
						  completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)reportWebProxyCarrierError:(NSInteger)carrierId
							  kind:(NSString *)kind
						   message:(NSString *)message
						completion:(void (^)(BOOL ok, NSString *error))completion;

@end
