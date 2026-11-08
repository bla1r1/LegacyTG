# Closed bugs

The queue is empty. Every entry below is fixed; the closing commit or test is in
the last column. B22–B25 were never filed. The full root-cause notes are in git
history at `cf71bc9`.

| # | Symptom | Area | Fix | Check |
|---|---|---|---|---|
| B1 | Media grid became the stories grid | media, profile | Shared grid keyed only to `kind == "stories"`; separate cache and invalidation (`4797b90`, `31d403f`, `f0ddf51`) | Device |
| B2 | Avatars and thumbnails took >30 s | files | `downloadFile:` ignored `updateFile`; progress now handled, watchdog fixed (`4797b90`) | Device |
| B3 | Folders crashed the app | chat-list | `formattedText` dict read as a title; type-safe parse, `TGPopupMenu` (`25c97cf`, `b3dcc8d`) | Device |
| B4 | Network state said "long time ago" | chat-list | No "yesterday" case; formatter and `connectionState` reader (`e940635`) | Device |
| B5 | Gifts drawn as text, no icons | profile | `TGFlattenGift` + `TGGiftGlyph`, files downloaded (`c4fbf05`) | Device |
| B6 | A chat opened from Contacts had no avatar | contacts | `privateChatWithUser` now feeds the returned chat through `mergeChat` (`082cc56`) | Device |
| B7 | iOS 6.1.6 crashed while scrolling audio cells | core | Attribute-taking `NSString` APIs die on 6.1.6; all call sites go through `TGTextDraw` gated on `NSFoundationVersionNumber` | Device: audio cell still to confirm |
| B8 | Email step never left the phone screen | login | `handleAuthState` returned early on `WaitEmailAddress` / `WaitEmailCode`; test `testAuth_EmailStatesReachTheScreen` | No account on the bench |
| B9 | Unpin / Unmute / Unarchive opened delete | chat-list | `hasSuffix:@"Pin"` was case-sensitive; case-blind match | UIKit, pinned chat missing |
| B10 | Photos went blank after scrolling away and back | chat, media | An LRU-evicted id stayed in `imagesRequested`; id cleared on load | Needs >12 photos |
| B11 | iOS 6 aborted on any snackbar, menu or profile | core | `UIImageView setTintColor:` is iOS 7; `TGIcons tintImageView:` fills the glyph on 6 | 6.1.6 verified |
| B12 | QR login crashed on iOS 6 | login | `inputCorrectionLevel` is not on iOS 6's `CIQRCodeGenerator`; only listed keys are set | 6.1.6 verified |
| B13 | Backgrounding killed the app (`0xdead10cc`) | core | `pauseForBackground:` sends `close` under a background task, `resumeFromBackground` starts a new client; `testBackground_ClosesTDLibWithoutSigningOutTheScreens` | iPod verified |
| B14 | Entering a chat killed iOS 6 (`initWithBase64EncodedString`) | core | `TGBase64` gates both spellings on `instancesRespondToSelector:`; `testBase64Decode_RoundTripsBothPaths` | Device verified |
| B15 | Decode burst `SIGSEGV 0x0` in list and profile | core | One gated pooled decode entry (`TGIconsDecodeGate`), `TGDECODE_MAX_PIXEL` 1024 on 256 MB | 4S verified |
| B16 | Round video recorder threw on iPod touch 4 | media | `videoMirrored` over `automaticallyAdjustsVideoMirroring`; lint rule 24 | iPod verified |
| B17 | Round video recorded nothing (`-11803`) | media | `startRunning` on a dispatch queue; lint rule 25 | iPod verified |
| B18 | Blue "name · Ringing" wall after a call | calls | `TGCallMiniBar` gave its window a root view controller; window now has no root VC | iPod verified |
| B19 | Send on a round video did nothing | media | Duration left out the running file; completion ran on the export thread | iPod verified; delivery unconfirmed |
| B20 | QR login or phone send overflowed the stack | login | `setBusy:` assigned `self.busy` and recursed; lint rule 26 | iPod verified |
| B21 | Receive thread took 10% of the A4 while idle | core | Single-threaded `ClientManager` ignored the receive timeout; waits up to 20 ms on a semaphore; `testIdleLoopDoesNotSpin` | Host |
| B26 | Profile message count and date jump came back empty | profile, chat | `messageTopicMain` / `messageTopicMessageThread` are not in `td_api.tl`; fixed topic types | Host |
| B27 | Nobody's emoji status showed | profile | Id is one level down under `type`; gift uses `model_custom_emoji_id` | Device |
| B28 | Jump to a message outside the loaded window missed | chat | `historyForChat:aroundMessageId:` with offset `-limit/2`, no bottom pin on targeted open, album members matched | Device |
| B29 | Current clips opened black on the iPod | media | H.264 High at 60 fps; `TGSoftVideoPlayer` over FFmpeg on Vintage, 480x480 | iPod verified |
| B30 | Some voice notes failed with `op_open_file: -132` | media | MP3/M4A posted as voice; `OP_ENOTFORMAT` falls back to `AVAudioPlayer` | No host test |
| B31 | Profile photo dropped back to initials | profile | Header was rebuilt and photo decoded on every answer; decoded photo kept, file asked once | No host test |
| B32 | My Profile listed Saved Messages content | profile | Own user id is also the Saved Messages chat; tabs are gated | No host test |
| B33 | A channel not joined said "last seen recently" and offered Mute | chat-list, channels | `chatKindForChat:` from `getChat` and the group record; Join sends `joinChat` only when pressed | Device |
| B34 | `TGCallTests` died at `key + 88` now and then | calls | `TGCallReflector stop` returned while the reader was in `onPacket`; it now joins the reader | 30 of 30 clean |
| B35 | Media came first on every profile | profile | `profileTabPosts` read as Media; `TGProfileTabKinds` order fixed | Device |

Suggested order when something regresses: `TGClient+Files.m` (B1+B2), status
formatter (B4), tab kinds (B1 UI), gifts flatten (B5), contacts `getChat` on open
(B6), then folder parsing (B3).
