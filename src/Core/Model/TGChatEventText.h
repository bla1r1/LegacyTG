//
// TGChatEventText.h - one line of a group's or channel's Recent Actions in
// official's words (Channel.AdminLog.*), from a chatEvent's action.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// {"title": the sentence with the actor in it, "detail": what changed -
/// the new description, the previous link, the edited text, the permissions
/// turned on and off - or ""}. `name` turns a user id into a name.
NSDictionary *TGChatEventLine(NSDictionary *action, NSString *actor, BOOL isChannel,
		NSString *(^name)(int64_t userId));

#ifdef __cplusplus
}
#endif
