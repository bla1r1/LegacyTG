//
// TGSearchScope.h - which search hits each scope pill of the global search
// shows. The screen draws the pills and the lists; these decide what goes in.
//
#import <Foundation/Foundation.h>

/// Telegram's scopes, in the order its search shows them. The integers are
/// the tag on each pill; the array index is the same, so a tag is the scope.
typedef NS_ENUM(NSInteger, TGSearchScope) {
	TGSearchScopeAll = 0,
	TGSearchScopeChats,
	TGSearchScopeMessages,
	TGSearchScopeMedia,
	TGSearchScopeLinks,
	TGSearchScopeFiles,
	TGSearchScopeMusic,
	TGSearchScopeVoice,
	TGSearchScopeDownloads,
};

FOUNDATION_EXPORT NSArray *TGSearchScopeTitles(void);

/// A flattened message ("kind", "text") belongs to the scope: Media is photos,
/// videos, GIFs and round videos; Links is text with an address in it.
FOUNDATION_EXPORT BOOL TGSearchMessageMatchesScope(NSDictionary *message,
		TGSearchScope scope);

/// The message hits a scope shows: All and Messages keep the list as it is.
FOUNDATION_EXPORT NSArray *TGSearchScopedMessages(NSArray *messages, TGSearchScope scope);

FOUNDATION_EXPORT BOOL TGSearchScopeShowsChats(TGSearchScope scope);
FOUNDATION_EXPORT BOOL TGSearchScopeShowsMessages(TGSearchScope scope);
/// Public posts are only in All.
FOUNDATION_EXPORT BOOL TGSearchScopeShowsPublic(TGSearchScope scope);

/// The line under Public Posts: when free search unlocks, or how many free
/// searches are left today. Nil otherwise: with the limit spent and no wait
/// known the screen's own "No Results" already says it, and a second one sat
/// in the footer as a bar over Stories.
FOUNDATION_EXPORT NSString *TGSearchPublicFooter(TGSearchScope scope, BOOL limitExceeded,
		NSInteger nextFreeIn, NSInteger remainingFree);

/// A raw td_api public post's line: its text or caption, trimmed, or the
/// content type without the "message" prefix when it has neither.
FOUNDATION_EXPORT NSString *TGPublicPostText(NSDictionary *message);
