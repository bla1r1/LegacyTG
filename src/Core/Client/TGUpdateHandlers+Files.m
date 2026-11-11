//
// TGUpdateHandlers+Files.m - one family of update* branches.
//
#import "TGUpdateHandlers.h"
#import "TGUpdateHandlersSupport.h"
#import "TGClient.h"
#import "TGClientInternal.h"
#import "TGState.h"
#import "TGTransport.h"
#import "TGUpdateRouter.h"
#import "TGAccountSession.h"
#import "TGJson.h"
#import "TGOptions.h"
#import "TGBase64.h"
#import "TGCall.h"
#include "TGUpdateType.h"

@interface TGClient (TGUpdateHandlerPrivate)
- (void)markSavedMessagesRow;
@end

@implementation TGUpdateHandlers (Files)

- (BOOL)handleFilesUpdates:(NSString *)type obj:(NSDictionary *)obj {
	switch (TGUpdateTypeFor(type.UTF8String, type.length)){
	case TGUpdateFileAddedToDownloads:
	case TGUpdateFileDownload:
	case TGUpdateFileDownloads:
	case TGUpdateFileRemovedFromDownloads:
	case TGUpdateSpeedLimitNotification: {
		// Settings > Downloads is the one screen built from a single
		// searchFileDownloads answer, so it had no way of noticing a download
		// that finished, paused or was removed from another device.
		// updateFile carries the bytes; the list membership is only here.
		// The speed limit rides along: throttled progress is a change the
		// rows should re-read too.
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGDownloadsChangedNotification object:self];
		return YES;
	}
	case TGUpdateUserFullInfo:
	case TGUpdateBasicGroup:
	case TGUpdateBasicGroupFullInfo:
	case TGUpdateSupergroupFullInfo: {
		// Bios, member counts and admin rights live in the full record, which
		// is fetched per screen and never refreshed. updateSupergroup was
		// handled, none of the full infos were - so a bio edited elsewhere
		// needed the profile closed and reopened.
		NSString *kind = @"user";
		NSNumber *peerId = obj[@"user_id"];
		if (!peerId){
			peerId = obj[@"basic_group_id"] ?: obj[@"basic_group"][@"id"];
			kind = @"basicGroup";
		}
		if (!peerId){
			peerId = obj[@"supergroup_id"];
			kind = @"supergroup";
		}
		if (!peerId)
			return YES;
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGFullInfoChangedNotification object:self
							userInfo:@{@"kind" : kind, @"id" : peerId}];
		return YES;
	}
	case TGUpdateOption: {
		// Limits, flags and the server clock. Kept in the C++ store rather
		// than answered once by getOption and never corrected.
		NSString *name = obj[@"name"];
		NSDictionary *value = obj[@"value"];
		if (!name.length || ![value isKindOfClass:NSDictionary.class])
			return YES;
		NSString *kind = value[@"@type"];
		const char *key = name.UTF8String;
		if ([kind isEqualToString:@"optionValueBoolean"]){
			TGOptionSetBoolean(key, [value[@"value"] boolValue]);
		} else if ([kind isEqualToString:@"optionValueInteger"]){
			// int64 comes over JSON as a string; both shapes answer this.
			TGOptionSetInteger(key, [value[@"value"] longLongValue]);
		} else if ([kind isEqualToString:@"optionValueString"]){
			TGOptionSetString(key, [value[@"value"] UTF8String]);
		} else {
			TGOptionClear(key);
		}
		return YES;
	}
	case TGUpdateConnectionState: {
		NSString *st = obj[@"state"][@"@type"];
		NSLog(@"TGClient: connection %@", st);

		TGConnectionState state = TGConnectionStateUnknown;
		NSString *text = nil;
		if ([st isEqualToString:@"connectionStateWaitingForNetwork"]){
			state = TGConnectionStateWaitingForNetwork; text = @"Waiting for network";
		} else if ([st isEqualToString:@"connectionStateConnecting"] ||
				   [st isEqualToString:@"connectionStateConnectingToProxy"]){
			state = TGConnectionStateConnecting; text = @"Connecting";
		} else if ([st isEqualToString:@"connectionStateUpdating"]){
			state = TGConnectionStateUpdating; text = @"Updating...";
		} else if ([st isEqualToString:@"connectionStateReady"]){
			state = TGConnectionStateReady; text = nil;
		}

		self.client.connectionState = state;
		if (self.client.onConnectionState)
			self.client.onConnectionState(state, text);
		[[NSNotificationCenter defaultCenter]
				postNotificationName:TGConnectionStateChangedNotification
							  object:nil
							userInfo:@{@"state" : @(state),
									   @"text"  : text ?: @""}];
		return YES;
	}
	// The state of a secret chat - whether the other device has answered
	// the exchange yet - is the one thing its header has to breathe.
	case TGUpdateSecretChat: {
		NSDictionary *sc = obj[@"secret_chat"];
		NSString *st = sc[@"state"][@"@type"] ?: @"";
		NSString *word = @"pending";
		if ([st isEqualToString:@"secretChatStatePending"])      word = @"pending";
		else if ([st isEqualToString:@"secretChatStateReady"])   word = @"ready";
		else if ([st isEqualToString:@"secretChatStateClosed"])  word = @"closed";
		else                                                     word = @"unknown";
		if (self.client.onSecretChat)
			self.client.onSecretChat([sc[@"id"] integerValue], word);
		return YES;
	}

	case TGUpdateNewCallSignalingData: {
		NSData *data = TGBase64Decode(obj[@"data"]);
		NSLog(@"TGClient: <<< updateNewCallSignalingData call_id=%@ len=%lu", obj[@"call_id"], (unsigned long)data.length);
		[[TGCall shared] handleSignalingData:data];
		return YES;
	}

	case TGUpdateCall: {
		NSLog(@"TGClient: <<< updateCall: %@", obj[@"call"]);
		// TDLib signals the call; TGCall owns the audio.
		[[TGCall shared] handleUpdate:obj[@"call"]];
		return YES;
	}

	default:
		break;
	}
	return NO;
}

@end

// vim:ft=objc
