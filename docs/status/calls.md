Calls: 1:1 audio, the call UI, recent calls, group calls and video chats. Parity rows come from `_parity_audit/contacts.md` and `s_rest.md`; checked against `src/` on 7 November 2026.

Counts: 41 done, 4 partial, 6 missing, 5 dev-only.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Start a 1:1 call | Official: Start a 1:1 call | done | `Calls/TGCall.mm:615` | `createCall` with the supported protocol. |
| Call and video tiles respect the peer's permissions | Official: Call and video tiles respect the peer's permissions | partial | `Controllers/TGProfileViewController+Actions.m:120` | Call is gated by `can_be_called`; Video also needs `canEncodeVideoCall`, which is dev-only. |
| Incoming call ring | Official: Incoming call ring | done | `App/AppDelegate.m:40` | `onIncomingCall` presents the call screen. |
| Accept a call | Official: Accept a call | done | `Calls/TGCall.mm:627` | `acceptCall` then key exchange and media. |
| Hang up | Official: Hang up | done | `Calls/TGCall.mm:681` | `discardCall` with duration and connection id. |
| Call audio | Official: Call audio | done | `Calls/TGCallAudioEngine.mm:123` | `VoiceProcessingIO` AudioUnit, Opus encode/decode. |
| Echo cancellation | Official: Echo cancellation | done | `Calls/TGCallAudioEngine.mm:141` | Uses `kAudioUnitSubType_VoiceProcessingIO`. |
| Mute microphone | Official: Mute microphone | done | `Calls/TGCall.mm:1678` | Flag stops outgoing Opus frames. |
| Speaker / earpiece | Official: Speaker / earpiece | done | `Calls/TGCall.mm:236` | `setSpeaker:` on the audio engine. |
| Call screen | Official: Call screen | done | `Controllers/TGCallViewController.m:306` | Avatar, name, status, timer, controls. |
| Minimise / return to call | Official: Minimise / return to call | done | `Controllers/TGCallViewController.m:1094` | Shrinks to a bar and restores. |
| Call emoji key | Official: Call emoji key | done | `Controllers/TGCallViewController.m:716` | Shows the four-emoji key and its card. |
| Call rating after a call | Official: Call rating after a call | done | `Controllers/TGCallViewController.m:1158` | 1-5 stars, optional comment and problem list. |
| Call duration and status | Official: Call duration and status | done | `Controllers/TGCallViewController.m:846` | Clock plus TGCall state text. |
| Private video calls | Official: Private video calls | dev-only | `Core/TGCapabilities.m:83` | `canEncodeVideoCall` returns NO unless `TG_DEV`. |
| Video call engine | Official: Video call engine | dev-only | `Calls/TGCall.mm:1451` | Camera capture, H.264 RTP, remote preview; release never enables it. |
| Local/remote video layout | Official: Local/remote video layout | dev-only | `Controllers/TGCallViewController.m:888` | Full-screen remote and corner preview. |
| Switch camera | Official: Switch camera | dev-only | `Controllers/TGCallViewController.m:884` | Calls the video engine. |
| Call message in the chat | Official: Call message in the chat | done | `Core/TGMessageFlatten.m:564` | Direction, video flag, duration and missed state. |
| Call back from a call message | Official: Call back from a call message | done | `Controllers/TGChatViewController.m:1653` | The call button on a call row starts a new call. |
| Recent calls list | Official: Recent calls list | partial | `Controllers/TGSettingsViewController+Pages.m:759` | Name and a subtitle line "Outgoing/Incoming/Missed <date> - duration"; no avatar, glyph or right-aligned date. |
| All / Missed filter | Official: All / Missed filter | done | `Controllers/TGSettingsViewController+Pages.m:731` | `recentCallsFilter` filters the list; the empty state says "No missed calls". |
| Tapping a call redials | Official: Tapping a call redials | partial | `Controllers/TGSettingsViewController+Pages.m:781` | Tap redials through `TGCallViewController`; there is no info control or call-details screen. |
| Missed calls labelled "Missed" | Official: Missed calls labelled "Missed" | done | `Controllers/TGSettingsViewController+Pages.m:764` | `typeLabel` is "Missed" for a missed call and the row is destructive. |
| Call history paging | Official: Call history paging | missing | `Core/TGClient+Account.m:1062` | One `searchCallMessages` request for 50; `next_offset` is not followed. |
| Empty call list | Official: Empty call list | partial | `Controllers/TGSettingsViewController+Pages.m:750` | A plain "No recent calls" / "No missed calls" row. |
| Optional Calls tab | Official: Optional Calls tab | done | `Controllers/TGSettingsViewController+Pages.m:736` | Switch in Recent Calls; `RootViewController` builds the tab when enabled. |
| Call log and debug diagnostics | Official: Call log and debug diagnostics | dev-only | `Controllers/TGSettingsViewController+Pages.m:770` | Inside `#if TG_DEV`; the release list has no diagnostics. |
| Clear call history | Official: Clear call history | done | `Controllers/TGSettingsViewController+NetworkPages.m:165` | Account-wide `clearAllCallMessages`. |
| Group call screen | Official: Group call screen | done | `Controllers/TGGroupCallViewController.m:364` | State, duration, participants, messages, tools. |
| Join / leave a group call | Official: Join / leave a group call | done | `Controllers/TGGroupCallViewController.m:388` | Join returns the payload; Leave clears it. |
| End a group call | Official: End a group call | done | `Controllers/TGGroupCallViewController.m:477` | Confirmed end for the owner/admin. |
| Group-call participant list | Official: Group-call participant list | done | `Controllers/TGGroupCallViewController.m:433` | Avatars, speaking, hand, mute, video, volume state. |
| Participant mute / volume / hand / ban | Official: Participant mute / volume / hand / ban | done | `Controllers/TGGroupCallParticipantsViewController.m:213` | Per-person actions gated by the server flags. |
| Invite participants | Official: Invite participants | done | `Controllers/TGVideoChatSetupViewController.m:355` | `inviteVideoChatParticipants`, one or many. |
| Invite link and revoke | Official: Invite link and revoke | done | `Controllers/TGVideoChatSetupViewController.m:395` | Get, copy, revoke. |
| Decline an invitation | Official: Decline an invitation | done | `Controllers/TGVideoChatSetupViewController.m:605` | Takes the invitation message id. |
| Group-call messages | Official: Group-call messages | done | `Controllers/TGCallMessagesViewController.m:115` | Send, list, delete one, delete all from a sender. |
| Group-call audio | Official: Group-call audio | missing | `Controllers/TGGroupCallViewController.m:338` | The screen says it has no group-call audio engine; no join media. |
| Create a video chat | Official: Create a video chat | done | `Controllers/TGVideoChatSetupViewController.m:180` | Title, start date, video or RTMP. |
| Create a standalone group call | Official: Create a standalone group call | done | `Controllers/TGVideoChatSetupViewController.m:223` | `createGroupCall` without a chat binding. |
| Schedule a video chat | Official: Schedule a video chat | done | `Controllers/TGVideoChatSetupViewController.m:277` | Start Scheduled before the call begins. |
| Default participant | Official: Default participant | done | `Controllers/TGVideoChatSetupViewController.m:327` | Server-provided sender list. |
| Video-chat title / messages / mute-new / start notification | Official: Video-chat title / messages / mute-new / start notification | done | `Controllers/TGVideoChatSetupViewController.m:563` | Each switch sends its own flag and reads back. |
| Start / end recording | Official: Start / end recording | done | `Controllers/TGVideoChatSetupViewController.m:473` | Audio, video landscape, video portrait, then stop. |
| RTMP URL get / replace | Official: RTMP URL get / replace | done | `Controllers/TGVideoChatSetupViewController.m:432` | Shows and copies URL plus key; replace asks first. |
| Screen sharing start / pause / resume / stop | Official: Screen sharing start / pause / resume / stop | done | `Controllers/TGVideoChatSetupViewController.m:509` | Sends the join payload and audio source. |
| Stream channels and segments | Official: Stream channels and segments | done | `Controllers/TGVideoChatStreamViewController.m:1` | Lists streams, fetches bytes, encrypt/decrypt samples. |
| Encrypt / decrypt group-call payload | Official: Encrypt / decrypt group-call payload | done | `Core/TGClient+GroupCalls.m:1117` | Through `encryptGroupCallData` / `decryptGroupCallData`. |
| Mark myself speaking | Official: Mark myself speaking | done | `Core/TGClient+GroupCalls.m:578` | `setGroupCallParticipantIsSpeaking`. |
| Group-call join payload | Official: Group-call join payload | done | `Core/TGClient+GroupCalls.m:375` | `joinGroupCall` returns TDLib's payload; nothing decodes it. |
| Video-chat participants in the chat profile | Official: Video-chat participants in the chat profile | done | `Controllers/TGProfileViewController+Actions.m:384` | Calls row opens the call screen. |
| Phone-to-phone call acceptance | Official: Phone-to-phone call acceptance | missing | `Calls/TGCall.mm` | libtgvoip rings, but modern Telegram iOS rejects this client's version. |
| New Call row | Official: New Call row | missing | — | No action row; the list starts with the Show Calls Tab switch. |
| Active group calls above Recent Calls | Official: Active group calls above Recent Calls | missing | — | No group-call rows in Recent Calls. |
| Calls tab rows | Official: Calls tab rows | missing | — | The optional Calls tab reuses the same subtitle list. |
