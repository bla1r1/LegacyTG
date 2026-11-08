#import "TGClient+Base.h"

@interface TGClient (WebApps)

/// How this account opens links: in the system browser or in an in-app one.
/// This client has no in-app browser, so `displayCloseButton` is sent as NO
/// and the setting still records Telegram's choice.
- (void)setWebBrowserSettingsOpenExternal:(BOOL)openExternal
						displayCloseButton:(BOOL)displayCloseButton
							   completion:(void (^)(BOOL ok,
													NSString *error))completion;

/// One URL handled differently from the default.
- (void)addWebBrowserException:(NSString *)url
				  openExternal:(BOOL)openExternal
					completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeWebBrowserException:(NSString *)url
					   completion:(void (^)(BOOL ok, NSString *error))completion;

- (void)removeAllWebBrowserExceptionsWithCompletion:(void (^)(BOOL ok,
															 NSString *error))completion;

/// The Web App catalogue a user can browse without a Web App host.
- (void)grossingWebAppBotsOffset:(NSString *)offset
						   limit:(int32_t)limit
					  completion:(void (^)(NSArray *bots, NSString *error))completion;

- (void)searchWebAppForBot:(int64_t)botUserId
				 shortName:(NSString *)shortName
				completion:(void (^)(NSDictionary *app, NSString *error))completion;

- (void)webAppPlaceholderForBot:(int64_t)botUserId
					 completion:(void (^)(NSString *outline, NSString *error))completion;

/// The three URL getters. They answer a link; opening it needs a Web App host,
/// which this client does not have, so the screen copies it instead.
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

/// The two keyboard-button answers a person gives a bot: share one chat, or
/// share a list of users. `sourceChat`/`sourceMessage` name the message the
/// button came from.
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

@end
