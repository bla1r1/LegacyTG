Calls: 1:1 audio, the call UI, recent calls, group calls and video chats. Parity
rows come from `_parity_audit/contacts.md` and `s_rest.md`; checked against
`src/` on 7 November 2026.

Counts: 41 done, 4 partial, 6 missing, 5 dev-only.

Built: M13 (1:1 signalling and media, VoiceProcessingIO, call screen, recent
calls), M7 (group-call screens and video-chat setup). Open: M21 supplies the RTP
mixing, M22 the release video engine. Protocol notes are at the end of this file.

| Feature | State | Where | Note |
|---|---|---|---|
| Start a 1:1 call | done | `CallEngine/TGCall.mm:615` | `createCall` with the supported protocol. |
| Call and video tiles respect the peer's permissions | partial | `Features/Profile/TGProfileViewController+Actions.m:120` | Call is gated by `can_be_called`; Video also needs `canEncodeVideoCall`, which is dev-only. |
| Incoming call ring | done | `App/AppDelegate.m:40` | `onIncomingCall` presents the call screen. |
| Accept a call | done | `CallEngine/TGCall.mm:627` | `acceptCall` then key exchange and media. |
| Hang up | done | `CallEngine/TGCall.mm:681` | `discardCall` with duration and connection id. |
| Call audio | done | `CallEngine/Media/TGCallAudioEngine.mm:123` | `VoiceProcessingIO` AudioUnit, Opus encode/decode. |
| Echo cancellation | done | `CallEngine/Media/TGCallAudioEngine.mm:141` | Uses `kAudioUnitSubType_VoiceProcessingIO`. |
| Mute microphone | done | `CallEngine/TGCall.mm:1678` | Flag stops outgoing Opus frames. |
| Speaker / earpiece | done | `CallEngine/TGCall.mm:236` | `setSpeaker:` on the audio engine. |
| Call screen | done | `Features/Calls/TGCallViewController.m:306` | Avatar, name, status, timer, controls. |
| Minimise / return to call | done | `Features/Calls/TGCallViewController.m:1094` | Shrinks to a bar and restores. |
| Call emoji key | done | `Features/Calls/TGCallViewController.m:716` | Shows the four-emoji key and its card. |
| Call rating after a call | done | `Features/Calls/TGCallViewController.m:1158` | 1-5 stars, optional comment and problem list. |
| Call duration and status | done | `Features/Calls/TGCallViewController.m:846` | Clock plus TGCall state text. |
| Private video calls | dev-only | `Core/Platform/TGCapabilities.m:83` | `canEncodeVideoCall` returns NO unless `TG_DEV`. |
| Video call engine | dev-only | `CallEngine/TGCall.mm:1451` | Camera capture, H.264 RTP, remote preview; release never enables it. |
| Local/remote video layout | dev-only | `Features/Calls/TGCallViewController.m:888` | Full-screen remote and corner preview. |
| Switch camera | dev-only | `Features/Calls/TGCallViewController.m:884` | Calls the video engine. |
| Call message in the chat | done | `Core/Model/TGMessageFlatten.m:564` | Direction, video flag, duration and missed state. |
| Call back from a call message | done | `src/Features/Chat/Core/TGChatViewPinned.m:125` | The call button on a call row starts a new call. |
| Recent calls list | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:759` | Name and a subtitle line "Outgoing/Incoming/Missed <date> - duration"; no avatar, glyph or right-aligned date. |
| All / Missed filter | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:731` | `recentCallsFilter` filters the list; the empty state says "No missed calls". |
| Tapping a call redials | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:781` | Tap redials through `TGCallViewController`; there is no info control or call-details screen. |
| Missed calls labelled "Missed" | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:764` | `typeLabel` is "Missed" for a missed call and the row is destructive. |
| Call history paging | missing | `src/Core/Client/Account/TGClient+AccountTwoStep.m:44` | One `searchCallMessages` request for 50; `next_offset` is not followed. |
| Empty call list | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:750` | A plain "No recent calls" / "No missed calls" row. |
| Optional Calls tab | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:736` | Switch in Recent Calls; `RootViewController` builds the tab when enabled. |
| Call log and debug diagnostics | dev-only | `src/Features/Settings/Pages/TGSettingsPagesCore.m:770` | Inside `#if TG_DEV`; the release list has no diagnostics. |
| Clear call history | done | `Features/Settings/TGSettingsViewController+NetworkPages.m:165` | Account-wide `clearAllCallMessages`. |
| Group call screen | done | `Features/Calls/TGGroupCallViewController.m:364` | State, duration, participants, messages, tools. |
| Join / leave a group call | done | `Features/Calls/TGGroupCallViewController.m:388` | Join returns the payload; Leave clears it. |
| End a group call | done | `Features/Calls/TGGroupCallViewController.m:477` | Confirmed end for the owner/admin. |
| Group-call participant list | done | `Features/Calls/TGGroupCallViewController.m:433` | Avatars, speaking, hand, mute, video, volume state. |
| Participant mute / volume / hand / ban | done | `Features/Calls/TGGroupCallParticipantsViewController.m:213` | Per-person actions gated by the server flags. |
| Invite participants | done | `Features/Calls/TGVideoChatSetupViewController.m:355` | `inviteVideoChatParticipants`, one or many. |
| Invite link and revoke | done | `Features/Calls/TGVideoChatSetupViewController.m:395` | Get, copy, revoke. |
| Decline an invitation | done | `Features/Calls/TGVideoChatSetupViewController.m:605` | Takes the invitation message id. |
| Group-call messages | done | `Features/Calls/TGCallMessagesViewController.m:115` | Send, list, delete one, delete all from a sender. |
| Group-call audio | missing | `Features/Calls/TGGroupCallViewController.m:338` | The screen says it has no group-call audio engine; no join media. |
| Create a video chat | done | `Features/Calls/TGVideoChatSetupViewController.m:180` | Title, start date, video or RTMP. |
| Create a standalone group call | done | `Features/Calls/TGVideoChatSetupViewController.m:223` | `createGroupCall` without a chat binding. |
| Schedule a video chat | done | `Features/Calls/TGVideoChatSetupViewController.m:277` | Start Scheduled before the call begins. |
| Default participant | done | `Features/Calls/TGVideoChatSetupViewController.m:327` | Server-provided sender list. |
| Video-chat title / messages / mute-new / start notification | done | `Features/Calls/TGVideoChatSetupViewController.m:563` | Each switch sends its own flag and reads back. |
| Start / end recording | done | `Features/Calls/TGVideoChatSetupViewController.m:473` | Audio, video landscape, video portrait, then stop. |
| RTMP URL get / replace | done | `Features/Calls/TGVideoChatSetupViewController.m:432` | Shows and copies URL plus key; replace asks first. |
| Screen sharing start / pause / resume / stop | done | `Features/Calls/TGVideoChatSetupViewController.m:509` | Sends the join payload and audio source. |
| Stream channels and segments | done | `Features/Calls/TGVideoChatStreamViewController.m:1` | Lists streams, fetches bytes, encrypt/decrypt samples. |
| Encrypt / decrypt group-call payload | done | `Core/Client/TGClient+GroupCalls.m:1117` | Through `encryptGroupCallData` / `decryptGroupCallData`. |
| Mark myself speaking | done | `Core/Client/TGClient+GroupCalls.m:578` | `setGroupCallParticipantIsSpeaking`. |
| Group-call join payload | done | `Core/Client/TGClient+GroupCalls.m:375` | `joinGroupCall` returns TDLib's payload; nothing decodes it. |
| Video-chat participants in the chat profile | done | `Features/Profile/TGProfileViewController+Actions.m:384` | Calls row opens the call screen. |
| Phone-to-phone call acceptance | missing | `CallEngine/TGCall.mm` | libtgvoip rings, but modern Telegram iOS rejects this client's version. |
| New Call row | missing | — | No action row; the list starts with the Show Calls Tab switch. |
| Active group calls above Recent Calls | missing | — | No group-call rows in Recent Calls. |
| Calls tab rows | missing | — | The optional Calls tab reuses the same subtitle list. |

## Protocol notes

### Which version each side speaks

| Client | Stack | Versions |
|---|---|---|
| This app | `third_party/libtgvoip`, `PROTOCOL_VERSION 9`, `max_layer 92` | Announces `3.0.0`, `2.4.4` |
| Modern Telegram | tgcalls (WebRTC bundled) | Registers `2.7.7`, `5.0.0`, `7.0.0` up; `3.0.0` and `2.4.4` are gone |

Phone→desktop works because tgcalls keeps a legacy tgvoip compatibility layer
(`v2_4_0_0/`, `v2/InstanceV2CompatImpl.cpp`). Phone↔phone fails when the server
picks a version the other side will not serve; signalling establishes and media
stays silent. iPhone calls on `5.0.0` are silent by source: iOS gives every call
a `SharedCallAudioDevice`, and `InstanceImpl` takes `createAudioDeviceModule`,
whose `RegisterAudioCallback` returns 0 without keeping the callback. Only
`createWrappedAudioDeviceModule` (V2) carries sound.

Bench (`scripts/call_bench.sh`, real tgcalls through a reflector): both roles
Established on `2.7.7` and `5.0.0`; their 440 Hz tone reaches us at 0.84–1.00
energy share, ours reaches them at 0.10–0.24 against 0.00–0.01 silence. Tried on
Mac and iPod; not tried between two TDLib accounts.

### tgcalls 9.0.0 = signalling V2

Audio only; 12.0.0+ moves signalling onto SCTP and is out of scope. Full note
with every source line: `git show cf71bc9:docs/calls_v9_spec.md`.

- **Transport.** EncryptedConnection envelope: `[16-byte msgKey][AES-256-CTR]`,
  plaintext `[seq:4 BE][message]…`. `msgKey = SHA256(key+88+x, plaintext)[8..24]`,
  signalling half is `key+128`. Bit 31 = single message, bit 30 = ack required,
  low 30 bits = counter. Message id `127` carries `len:4 BE | JSON`. Acks are
  `[acked_seq:4][FF]`; dedupe window 64. Send plain JSON (V2 has no gzip on
  send, accepts gzip on receive). Resend after 3–5 s; flush acks immediately.
- **Messages.** `InitialSetup` (`fingerprints`, `pwd` 24 chars, `renomination`,
  `ufrag` 4 chars), `NegotiateChannels` (`exchangeId` string, `contents`),
  `Candidates` (`sdpString`), `MediaState`. Ack every message.
  Caller sends first, callee answers, then offers its own audio and the caller
  answers. Unknown fields are ignored; unknown `@type` is dropped.
- **Audio.** Opus only: PT 111, 48 kHz, 2 channels, `minptime=10`,
  `useinbandfec=1`; peer sends 60 ms frames, our 20 ms is accepted. Each side
  offers send-only audio with a non-zero `ssrc`; the answer must echo the peer's
  `ssrc` and `exchangeId`, or the peer creates no channel and stays silent.
  Omit `rtpExtensions` so no transport-cc feedback is owed.
- **ICE.** Reflector envelope is unchanged:
  `[16-byte peer tag][4-byte sender tag][len:4 BE][payload][pad]`. Candidate is
  component 1, priority 41877760, host `reflector-<serverId>-<tag>.reflector`,
  port = reflector port, `ufrag` = `InitialSetup.ufrag`. Caller is controlling,
  callee controlled and never sends `USE-CANDIDATE`.
- **DTLS.** Version 1.2 only, ECDSA P-256 self-signed certificate, SHA-256
  fingerprint in `InitialSetup.fingerprints[0]`. Caller is client
  (`actpass`), callee server (`passive`). Mutual auth: server requires a client
  certificate. Cipher string
  `DEFAULT:!NULL:!aNULL:!SHA256:!SHA384:!aECDH:!AESGCM+AES256:!aPSK:!3DES`;
  with ECDSA this leaves AES-128-GCM-SHA256, AES-128-CBC-SHA and AES-256-CBC-SHA.
- **SRTP.** Profile `SRTP_AES128_CM_SHA1_80` (AES-128 counter, 112-bit salt,
  10-byte HMAC-SHA1). Exporter label `EXTRACTOR-dtls_srtp`, 60 bytes =
  `client key||salt` then `server key||salt`; client sends with the first half.
  RTCP is muxed and SRTCP-protected; receiver reports are optional for audio.
- **SCTP.** Skip it. It carries only `MediaState`, is not part of the established
  test (`ICE connected && DTLS-SRTP writable`), and its absence changes nothing.
- **Timeouts.** ICE+DTLS must connect within 20 s or the call fails; 15 s without
  a STUN answer makes the path unwritable and starts that clock. There is no
  negotiation timeout — "connected but silent" means the peer's
  `NegotiateChannels` was never answered.
- **Order of work.** Framing/JSON (`TGCallMessages.m`, ~250 lines), candidates
  and roles (`TGCallIce`/`TGCallStun`, ~60), DTLS (~450), SRTP/SRTCP (~350),
  audio wiring (~120), RTCP RR (~40, optional), `MediaState` (~30, optional).
  Do not add SCTP.

A4 cost is small at 50 packets/s, but allocate nothing per packet; keep the
DTLS handshake off the main thread.
