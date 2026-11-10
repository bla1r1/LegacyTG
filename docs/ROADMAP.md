# LegacyTG roadmap

Status: `done` · `initial` (usable first version) · `partial` · `planned` · `deferred` · `wontfix`.

LegacyTG is a Telegram client for iOS 6.0–12.5.7 on armv7 and arm64: an
Objective-C UIKit UI over TDLib 1.8.66, loaded at runtime as
`libtdjson.dylib`. The hand-written libtg MTProto stack is gone; about 2500
lines written for this app sit on the TDLib API. Features gate by device tier
(Vintage, Legacy, Modern, Full), not by iOS version; Settings > This Device
explains every missing button. Vintage is the iPhone 3GS/4 and iPod touch 4
(256–512 MB, armv7, never past iOS 7); Legacy the 4S/5/5c and iPod touch 5
(armv7, up to iOS 10); Modern the 5s/6/6+ and iPod touch 6 (first 64-bit,
stopped at 12.5); Full the 6s and later (2 GB+).

The closed milestones below are the order the work landed. What each one built
is described by subject in the area guides: [login and accounts](status/login-accounts.md),
[chat list](status/chat-list.md), [chat](status/chat.md),
[message types](status/message-types.md), [media](status/media.md),
[profile](status/profile.md), [groups](status/groups.md),
[channels](status/channels.md), [contacts](status/contacts.md),
[calls](status/calls.md), [stories](status/stories.md),
[settings](status/settings.md), [privacy and security](status/privacy-security.md),
[notifications](status/notifications.md) and
[bots and payments](status/bots-payments.md). Counts and the top gaps are in
[status/README.md](status/README.md). Where this file and a status file
disagree, the status file was checked against `src/` on 7 November 2026;
open milestone states here were updated on 8 November after `ec1284a` and
`9c93e8f`.

## Closed milestones

One line each; the linked guide describes what it built.

| Milestone | Status | Summary |
|---|---|---|
| M1 Build and TDLib bridge | done | armv7 Makefile, TDLib submodule, `libtdjson.dylib` split (static linking exceeds the 16 MB branch limit), `tools/machofix.c`, opus, iOS 7 target. [status overview](status/README.md) |
| M2 Login and accounts | done | Phone, code, 2FA, email and QR steps; sign-up, terms, password recovery; three account slots, each with its own TDLib directory. 1.3 s from launch to authorized on a 4S. [login-accounts](status/login-accounts.md) |
| M3 Chat list | done | Snapshot first paint, 12 `loadChats` retries, live re-sort, rows, archive, folder strip, drag order, bulk actions. [chat-list](status/chat-list.md) |
| M4 Chat core | done | Paged history, bubbles, reply/forward/edit/delete, drafts, typing, pins, reactions, multi-select, scheduled sends, secret chats. [chat](status/chat.md) |
| M5 Media and files | done | Photo viewer, video and GIF playback, document preview, save to camera roll, downloads with cancel, file information. [media](status/media.md) |
| M6 Stickers and GIFs | done | WebP stills, TGS Lottie, WebM VP9 alpha, pack install by link/search, favourites, editor, custom emoji packs. [media](status/media.md) |
| M7 Groups, forums and channels | done | Member actions, permissions, invite links, forum topics, channel comments, direct messages, send-as, channel settings. [groups](status/groups.md), [channels](status/channels.md) |
| M8 Voice and video notes | done | Opus record/play, waveform, speed, transcription line, round video recorder and player; 4 s records to 22 KB on a 4S. [media](status/media.md) |
| M9 Themes, icons and design tokens | done | UIKit draws the chrome on every iOS version (`996512d`, `8e0d1b4`); the app draws only the chat, sheets, snackbars, viewer, player and call screen. Procedural SVG icon set (`6861366`) with outline/filled pairs; `TGStyle`, `TGTheme+Colours`, six-step spacing, light theme. [settings](status/settings.md) |
| M10 Search | done | In-chat text search, global search over chats/messages/media, local-first and server results, no-match states. [chat](status/chat.md), [chat-list](status/chat-list.md) |
| M11 Stories | done | 48 story functions on screens: strip, viewer, reactions, posting, period/privacy, albums, archive, statistics, public search. [stories](status/stories.md) |
| M12 Profiles and contacts | done | User, group and channel profiles; own profile with three tiles, online line and Add a bio; editing, action tiles, media panes, music strip; contacts list, add, block, share. [profile](status/profile.md), [contacts](status/contacts.md) |
| M13 1:1 calls | done | tgcalls 9.0.0 signalling and media, VoiceProcessingIO audio, call screen, emoji key, rating, recent calls. Modern clients still refuse this version; two peers that accept 2.4.4 still work. [calls](status/calls.md) |
| M14 Settings and privacy | done | Telegram-shaped Settings, passcode, two-step, sessions, blocked users, visibility rules, storage, data and network pages. [settings](status/settings.md), [privacy-security](status/privacy-security.md) |
| M15 Notifications and push | done | Three scopes and previews, exceptions, sounds, reaction and story settings, `registerDevice`, push routing to chat and message. Delivery needs the APNs certificate held for the official bundle ID. [notifications](status/notifications.md) |
| M16 Message types, cards and veils | done | Service sentences for about 75 types, previews for every content type, structured fields, one card for commerce and shared peers, one veil for spoilers/view-once/paid media, polls rebuilt, protected chats block copy/forward/save. Checked on the 4S with dev showcase rows, not yet with real messages. [message-types](status/message-types.md) |
| M17 Custom emoji | done | Composer keeps ids and sends or edits real custom emoji; picker tab; reactions, header and sender names; animation through the sticker pipeline, up to 3 per bubble; fallback emoji on iOS 6. Without Premium only Saved Messages accepts them. [chat](status/chat.md), [message-types](status/message-types.md) |
| M18 Device tiers, delivery and iOS 6 | done | Tier gates and This Device, `scripts/devrun.sh`, `TG_DEV` fenced out of release, Mac Catalyst probe, iOS 6 selector/base64/image-decode fixes. [settings](status/settings.md) |
| M19 Performance and C/C++ migration | done | yyjson zero-copy parsing, streaming Opus, vector Lottie math, TDLib update coalescing, controller decomposition, 1271 client and 185 call host tests. The migration plan is in git history at `c7149c0^:docs/C_CPP_MIGRATION_PLAN.md`. |

## Open milestones

In the order they are meant to be taken. Payments and group-call audio unblock
the largest number of dead buttons; the rest are parity work on screens that
already exist.

| Milestone | Status | Left |
|---|---|---|
| M20 Payments, Stars and gifts | `planned` | Pay path, Premium purchase, Stars, gifts, TON, Passport, StoreKit. |
| M21 Group-call audio | `planned` | RTP mixing and AudioUnit playback in the group-call screen. |
| M22 Video calls | `partial` | Dev-only engine; picture to an official client, release gate. |
| M23 Sending files, music and send options | `planned` | Document/audio picker, music streaming, silent and repeated sends, GIF caption. |
| M24 Chat-list previews and badges | `planned` | Thumbnails, type glyph, reaction/poll badges, compact counts, tab badge, folder tags. |
| M25 Story rings | `planned` | Ring on every row and profile avatar, own-story tile. |
| M26 Chat search filters | `planned` | Sender/media/date chips, result opens the hit, search tokens, global scopes. |
| M27 Failed-send mark | `done` | Failed icon in the bubble and row, retry without the hold menu. |
| M28 Profile cover, QR and Premium badge | `partial` | Accent gradient, background emoji, star badge, rating, verifier note. QR screen done. |
| M29 Profile media tabs | `partial` | GIF and Polls panes, photo/video split, month sections, calendar, counts, multi-select. Pane search done. |
| M30 Settings search | `planned` | A page index and a search field over every Settings row. |
| M31 Notification pages | `partial` | Permission warning, badge settings, exception editing. Category pages and in-app banner done. |
| M32 Contacts invite and import | `planned` | Invite Friends row, address-book permission, phone-book import, formatted phone add. |
| M33 Localisation | `partial` | 170 unique strings with no official match, gender forms, `native_name`. 88.6% of UI strings come from the official pack. |
| M34 Developer talk on the user's path | `partial` | Error table for 157 alerts, harness pages behind `TG_DEV`, footers rewritten. |
| M35 Message actions still missing | `planned` | Poll creation, copy in multi-select, forward with caption, share to topic, reply quote, pinned list. |
| M36 Group administration and channel tools | `partial` | Admin rights editor, invite-link detail, removed users, statistics graphs, boosts. Member list screen done. |
| M37 Settings and appearance detail | `partial` | Privacy exception lists, storage maximum, theme thumbnails, background colour/gradient, wallpaper collection. |
| M38 Media polish | `partial` | Live photos, scrub preview, music streaming, Lottie mattes/trim paths, sticker keyword search, link preview picture. |
| M39 Stories after the strip | `partial` | Camera video, reply/share/repost, live-story playback and hosting, comments. |
| M40 Bots and mini apps | `planned` | Inline mode, Web App host, bot commands, guest bots, game scores, web-app buttons. |
| M41 Dark theme | `partial` | Official dark theme files apply; Night Blue built in. Auto-Night and a device pass over every screen left. |
| M42 Landscape and iPad | `deferred` | Portrait iPhone layout only; no iPad or landscape pass. |
| M43 Platform delivery and device coverage | `partial` | iOS 6 device run, 4-inch check, background fetch, crash reporting, arm64 `libtdjson`. Release build script done. |
| M44 Message detail and unread TDLib fields | `partial` | Rich-message blocks, author signature, view/forward counts, gift counts, service-action buttons. Read summary done. |
| M45 Updates, changelog and usage | `partial` | Update check through our bot, official update screen with the changelog, usage counts by version and device, Cydia repo. |

## M20: Payments, Stars and gifts

- [ ] `planned` A checkout form that sends `getPaymentForm` and
  `sendPaymentForm`; invoice Pay and paid-media unlock reuse it.
- [ ] `planned` Premium purchase, Stars balance and top-up, star
  subscriptions, sending gifts, gift collections and resale.
- [ ] `planned` TON wallet, Passport and StoreKit receipt assignment;
  `canPurchaseFromStore` and `assignStoreTransaction` are never sent today.
- [ ] `planned` Paid messages: a Stars price row in the composer for a user
  who charges per message.
- [ ] `planned` Premium server features that need a paid account, including
  translation and transcription beyond the free TDLib path.
- [ ] `planned` TON staking calls stay behind `TG_DEV`; the old stake-dice dump
  is already replaced by the animated dice picker from M16.
- [ ] `planned` Order validation: the eight successive text alerts become one
  checkout form, or move behind `TG_DEV`.

**Blocked by:** no App Store receipt for this bundle ID and no payment
provider. StoreKit and Fragment both require the official app identity.

**Closes:** `bots-payments.md` — Pay an invoice, Paid media, Paid messages,
Premium purchase, Stars balance, Star subscriptions, Send a gift, Gift
collections, Gift auctions and resale, Boosts, TON wallet, Passport, StoreKit
purchases, Refund a Star payment.

## M21: Group-call audio

- [ ] `planned` WebRTC/RTP multi-peer audio, AudioUnit playback and recording,
  per-participant volume and mute in `TGGroupCallViewController`.
- [ ] `planned` Decode the join payload and keep the call in the app, instead
  of returning it to TDLib and leaving `client has no group-call audio engine`
  on screen.
- [ ] `planned` Active-speaker video decode for video chats; screen-share
  payloads stop being pasted by hand, and stream segments stop being raw
  OGG/MP4 files in `/tmp`.
- [ ] `planned` The sample AES buttons in the video-chat tools move behind
  `TG_DEV`; they test crypto, not a call.

**Blocked by:** tgcalls is WebRTC and C++17; there is no armv7 build and iOS 7
has no VideoToolbox encoder. The signalling, participant list, RTMP URLs and
recording flags are already wired.

**Closes:** `calls.md` — Group-call audio; `groups.md` — Group-call audio;
`message-types.md` — Join on group-call and video-chat cards.

## M22: Video calls

- [ ] `partial` `TGCallVideoEngine` captures camera frames, sends H.264 RTP and
  draws the remote preview; `canEncodeVideoCall` returns NO without `TG_DEV`.
- [ ] `planned` A call to an official client and back, plus a video stand on
  the Mac; neither exists, so the engine has only been exercised locally.
- [ ] `planned` Release gate in `TGCapabilities` and the "in progress" label
  replaced by the real tile.

**Blocked by:** the missing second-party test and the same tgcalls/WebRTC
stack limit as M21.

**Closes:** `calls.md` — Private video calls, Video call engine, Local/remote
video layout, Switch camera; `profile.md` — Video call tile.

## M23: Sending files, music and send options

- [ ] `planned` Document and audio pickers in the attach sheet, with
  `inputMessageDocument` and `inputMessageAudio`; today the sheet has gallery,
  camera, location, contact, checklist, quick reply, dice and ephemeral only.
- [ ] `planned` Music streaming: `TGMusicPlayer` downloads the whole file
  before playback; an `AudioFileStream` path is needed for long tracks.
- [ ] `planned` Silent send and repeated scheduled messages through
  `messageSendOptions`; normal send builds no options and `repeat_period` is
  hardcoded to 0.
- [ ] `planned` GIF caption on the way out; incoming captions already draw.
- [ ] `planned` A timer choice when sending a view-once photo or video; the
  view-once send itself exists in private chats.

**Blocked by:** nothing beyond the screen work; TDLib 1.8.66 has the calls.

**Closes:** `chat.md` — File and music picker, Silent send, Repeated scheduled
message, GIF caption; `media.md` — Document and audio attachments, Music
streaming; `message-types.md` — GIF caption.

## M24: Chat-list previews and badges

- [ ] `planned` Photo and video thumbnail at the start of the preview, and a
  content-type glyph beside it.
- [ ] `planned` Reaction and poll-vote badges, compact counts ("1.2K"), folder
  tags on the row, and the unread count on the Chats tab.
- [ ] `planned` A typing preview that names the sender, a Saved Messages row,
  and a pinned-row tint.
- [ ] `planned` Strip undrawable scalars from chat titles, names and previews;
  one such character costs 0.4–2.8 s on a 4S. Only the sticker panel titles
  strip them today.

**Blocked by:** row-model fields (`unreadPollVotes`, `chat_lists`, story state)
that the list does not copy today.

**Closes:** `chat-list.md` — Reaction badge, Poll-vote badge, Compact counts,
Pinned row tint, Photo/video thumbnail in the preview, Content-type glyph in
the preview, Folder tags on the row, Saved Messages row, Unread badge on the
Chats tab; `chat.md` — typing sender; `stories.md` — My Story first tile.

## M25: Story rings

- [ ] `planned` Draw the active-story ring around every chat-row avatar and
  the profile header avatar, with the seen/unseen and close-friends states.
- [ ] `planned` Turn the own-profile tile into a ring when own stories exist;
  the plus always draws today.
- [ ] `planned` Read `user.active_story_state` in list and profile cells; the
  strip already has a ring.

**Blocked by:** no shared ring view; each of the three cells draws its own
avatar.

**Closes:** `chat-list.md` — Story ring on every row avatar; `profile.md` —
Story ring around the avatar; `stories.md` — Story ring on every chat row
avatar; `message-types.md`/old section 8 — `user.active_story_state`.

## M26: Chat search filters

- [ ] `planned` Sender, media and date chips in in-chat search; the query is
  text-only today.
- [ ] `planned` Open the message a result names instead of replacing the feed
  and returning to the bottom.
- [ ] `planned` Search tokens for archive, folder, peer and date, the missing
  global scopes (Channels, Apps, Posts, Downloads), and a Downloads shortcut.

**Blocked by:** `TGSearchViewController` has no result-to-message route.

**Closes:** `chat.md` — Search in chat, Search result opens the message;
`chat-list.md` — Global search screen, Search results use real rows, Search
tokens, Downloads shortcut.

## M27: Failed-send mark

- [x] `done` A failed icon on the bubble and on the chat-list row when
  TDLib reports `messageSendingStateFailed`.
- [x] `done` Tap or hold to retry without opening the full hold menu; keep
  the existing Retry row as the fallback.

**Blocked by:** nothing. `TGSendStore` keeps the failure reason and the
can-retry flag; the bubble and the row read the same table.

**Closes:** `chat.md` — Failed delivery mark; `chat-list.md` — Delivery ticks
on your last message.

## M28: Profile cover, QR and Premium badge

- [ ] `planned` Paint the `profile_accent_color_id` gradient and background
  emoji behind the header; the id is stored and never drawn.
- [x] `done` A QR screen for the account's public link, or its id without a
  username, in Settings (`TGSettingsAccountQRViewController`); the login
  screen and it share `TGQRCodeImage`. Not yet reachable from the profile.
- [ ] `planned` Star badge beside a Premium name, profile rating, the
  third-party verifier note (`bot_verification`) and the
  `uses_unofficial_app` warning.
- [ ] `planned` Gift-derived name colour and the gift count on the header.
- [ ] `planned` Business opening hours, open/closed now and the map thumbnail
  on a business profile; only the address is flattened today.

**Blocked by:** header layout; TDLib already returns the fields.

**Closes:** `profile.md` — Premium star badge, Profile cover, Profile colour
screen, Profile rating, Third-party verification note, Unofficial app warning,
QR code of the username, Background emoji on the cover, Gift-derived name
colour, Gift counts; Business location row, Opening hours row, Business hours
and map; `settings.md` — QR bar item.

## M29: Profile media tabs

- [ ] `planned` GIF (`searchMessagesFilterAnimation`) and Polls panes; the
  tab list has Stories, Archive, Media, Files, Music, Voice, Links and Groups.
- [ ] `planned` Split photos and videos, add month sections and a calendar,
  show pane counts in the subtitle, and keep the tab strip under the bar.
- [x] `done` Search inside a pane (`ec1284a`).
- [ ] `planned` Multi-select inside a pane; Files, Voice and Links rows become
  actionable.

**Blocked by:** `TGProfileTabs` has no kind for either filter and the grid is
one flat page.

**Closes:** `profile.md` — GIF pane, Polls pane, Photo/video split, Month
sections and calendar, Multi-select in media, Pane search, Files rows, Voice
rows, Links rows, Tabs, Tab counts.

## M30: Settings search

- [ ] `planned` One index of every Settings page and row, matched by title and
  synonyms, with a result opening the page.
- [ ] `planned` Keep the index local; no TDLib call is involved.

**Blocked by:** none; the Settings tree is built in code and has no registry.

**Closes:** `settings.md` — Settings search.

## M31: Notification pages

- [x] `done` Category sub-pages (`TGNotificationCategoryViewController`)
  instead of three mute switches.
- [x] `done` An in-app banner for a message that arrives while the app is open
  (`TGInAppNotificationBanner`).
- [ ] `planned` Notification permission warning, badge settings, Add
  Exception, assignment of a custom sound, and lock-screen name display.
- [ ] `planned` Preserve mention, pinned and story flags when muting; today
  muting rewrites the record with two fields.

**Blocked by:** nothing beyond screen work now that the category pages exist.

**Closes:** `notifications.md` — Category sub-pages, In-app notification
banner, Notification warning badge, Badge settings, Add an exception, Assign a
custom sound, Display names on the lock screen, Pinned and mention flags,
Muted-until wording; `settings.md` — Notifications and Sounds, Notification
warning badge.

## M32: Contacts invite and import

- [ ] `planned` Invite Friends as the first Contacts row, sharing the
  account's t.me link.
- [ ] `planned` Address-book permission, phone-book import and the import
  footer; only `importedContactCount` is read today.
- [ ] `planned` Country code and formatted phone in Add Contact, live phone
  resolution and QR add.
- [ ] `planned` A New Call row with a contact picker, and active group calls
  above Recent Calls in the shared calls tab.

**Blocked by:** the app never asks for contacts permission.

**Closes:** `contacts.md` — Invite Friends, Contacts permission banner, Import
a phone book, Import footer, Live phone resolution, Country code and formatted
phone, Note/sync-to-phone/QR add, New Call row, Active group calls above Recent
Calls; `calls.md` — New Call row, Active group calls above Recent Calls.

## M33: Localisation

- [x] `done` `TGLocalized(@"English")` looks the English up in the official
  Telegram language pack, so the Language page changes the interface too.
  `scripts/i18n_match.py --coverage`: 2937 of 3316 strings covered (88.6%),
  170 unique strings with no official match, 119 technical.
- [x] `done` Plural forms through `TGLocalizedPlural`.
- [ ] `planned` Gender forms, and `native_name` in the Language row instead of
  the pack's `name`.
- [ ] `planned` The 170 strings above: reword to the official text where one
  exists, list the rest in `docs/i18n/allowed-english.md`.
- [ ] `planned` Language translation controls on the Language page.

**Blocked by:** nothing; the remaining strings have no official counterpart.

**Closes:** `settings.md` — Language, Language row value, Language translation
controls; old section 8 — Language.

## M34: Developer talk on the user's path

- [ ] `partial` One table from TDLib error code to an English sentence,
  applied where Core returns the error. About 157 alerts and toasts still
  print `PHONE_CODE_INVALID` or "Bad Request: ..."; "Telegram refused that."
  stands in when there is no message.
- [ ] `planned` Move File Tools, the TDLib state page, Active Notifications,
  call diagnostics, the bot console (seven bot-tool rows), the Stars console
  and the test harnesses behind `TG_DEV`.
- [ ] `planned` Rewrite footers that explain TDLib ("not autosaved by TDLib",
  "TDLib's own") as what the setting does; hide or replace footers that
  promise a refusal.
- [ ] `planned` Remove the login "Web Login Token" and "Enter a QR Link" paste
  paths, the sticker "paste ids" path, the "TDLib did not resolve that id to a
  chat." sentence, the raw payment dump and the "no web view" captcha
  sentence.
- [ ] `planned` Hide the group settings Calls footer ("this client has no
  group-call audio engine") until M21 lands.

**Blocked by:** the harness screens are the only route to their TDLib calls
today; they need a dev menu before they leave release Settings.

**Closes:** `login-accounts.md` — Auth errors as sentences; `settings.md` —
Data and Storage (File Tools, network state), Language pack tools;
`notifications.md` — Active Notifications; `calls.md` — Call log and debug
diagnostics; `channels.md` — Revenue/star statistics.

## M35: Message actions still missing

- [ ] `planned` Poll creation in the attach sheet (`inputMessagePoll`).
- [ ] `planned` Copy in multi-select, forward with a new caption
  (`copy_options`), share into a forum topic (`topic_id`) and reply with a
  chosen quote (`inputTextQuote`).
- [ ] `planned` A pinned-message list, not only the one-message banner.
- [ ] `planned` Secret-chat key-verification screens; the chat itself starts
  through `createSecretChatWithUser:`.
- [ ] `planned` Convert the game, protected-content and join-request manual ID
  prompts into structured selection lists.

**Blocked by:** each is a request shape the Core wrappers do not expose.

**Closes:** `chat.md` — Poll creation, Copy in multi-select, Forward with a
new caption, Share into a forum topic, Reply with a chosen quote, Pinned
message list, Inline bot mode; `chat-list.md` — compose search; `groups.md` —
join request rows.

## M36: Group administration and channel tools

- [ ] `partial` A per-administrator rights editor; promote sends one fixed
  `TGAdminRights()` object.
- [x] `done` A member list screen (`TGMemberListViewController`).
- [ ] `partial` Invite-link rows with dates, limits, QR and a revoked section;
  join-request rows with date and bio.
- [ ] `planned` Administrators, removed/banned users, linked channel and
  scam/fake warning rows.
- [ ] `planned` Statistics graphs, boost surfaces, channel post statistics,
  author signature and forward count on the bubble.

**Blocked by:** TDLib returns the data; the screens read a flat 100-event list
or only the first page.

**Closes:** `groups.md` — Per-admin rights editor, Temporarily restrict a
member, Member list, Member search with sections, Invite links screen,
Join requests row and screen, Member rows, Member counts, Administrators row
and screen, Removed / banned users screen, Linked channel row, Boosts,
Statistics with graphs, Recent actions, Available-reactions label,
Reactions settings; `channels.md` — Channel admin rights, Channel statistics
screen, Event log, Invite links, Public link on the profile, Post author
signature, View count on a bubble, Forward count, Post statistics on the
bubble, Boosts.

## M37: Settings and appearance detail

- [ ] `partial` Privacy exception lists (Always/Never Share With), bio and
  gifts privacy, voice-message and added-by-phone rules.
- [ ] `planned` Storage maximum, KEEP MEDIA per peer type, per-chat
  exceptions, and the Data and Storage merge into one page with sections.
- [ ] `partial` Theme thumbnails, a chat-theme picker that applies, accent
  and background colour/gradient/pattern controls, and the official wallpaper
  collection (`getBackgrounds` is never called). Import handles
  `.tgios-theme` and `.attheme`; zipped exports are rejected.
- [ ] `planned` Text size across the UI, not only chat text; fix the mobile
  cap overwrite (`setAutoDownloadOverMobile` writes 10 MB) and the chat-colour
  setter that erases a group's emoji. Folder rows get counts and recommended
  folders appear inline.

**Blocked by:** the theme model has one light palette; background editing is
six fixed textures and a photo.

**Closes:** `privacy-security.md` — Privacy exception lists, Bio privacy,
Gifts privacy, Voice message privacy, Added-by-phone privacy, Storage:
maximum cache size, Storage: KEEP MEDIA per peer type, Storage: chats view;
`settings.md` — Theme list, Chat theme picker, Accent colour chooser, Chat
background page, Background colour/gradient/pattern, Photo wallpaper crop,
Text size, Folder editor, Telegram Defaults presentation; old
section 4 — Telegram wallpaper collection.

## M38: Media polish

- [ ] `partial` Live and motion photos: the photo branch ignores
  `content.video`.
- [ ] `partial` Video cover and scrub preview; the scrubber exists but shows
  no frame.
- [ ] `partial` Lottie mattes, trim paths and repeaters; gradients and mask
  fills are done, the rest is approximate.
- [ ] `planned` Sticker pack search by keyword, link-preview pictures, saved
  GIFs (`getSavedAnimations`) and custom-emoji animation checked on a 4S.

**Blocked by:** decoder and layout work; no new TDLib call for most of it.

**Closes:** `media.md` — Live and motion photos, Video cover and scrub
preview, Sticker pack search by keyword, Link preview picture, Custom emoji
images; `message-types.md` — Live and motion photos, Link preview card.

## M39: Stories after the strip

- [ ] `partial` Camera video: `AVCaptureStillImageOutput` only; imported
  video posts with its duration.
- [ ] `planned` Reply to a story with a message, share/repost a story, and
  story comments.
- [ ] `partial` Live story playback and hosting: metadata, RTMP key, join and
  donor lists work; joining copies the tgcalls payload and there is no RTMP
  player or camera encoder.
- [ ] `planned` Story albums on the profile as shelves, not only in the
  Stories menu.

**Blocked by:** the same media stack as M21, plus the camera movie output.

**Closes:** `stories.md` — Story camera video, Reply to a story with a
message, Share or repost a story, Live story screen, Live story playback,
Live story host, Story comments and paid pins, Story albums on the profile;
`profile.md` — Story albums on the profile.

## M40: Bots and mini apps

- [ ] `planned` Inline bot mode (`@bot query`) with a result list and
  `sendInlineQueryResult`.
- [ ] `planned` A Web App host; `canRunWebApps` needs iOS 9 and WKWebView JS.
- [ ] `planned` Bot commands and menu button screen, guest bots, game scores,
  and the Web App/Pay/Game/password inline buttons that answer "needs a newer
  Telegram" today.
- [ ] `planned` Hide or relocate the bot-only business, Default Admin Rights
  and ephemeral calls that a user account can only be refused.

**Blocked by:** Web Apps need a browser view this target does not carry; the
bot-only calls need a bot session.

**Closes:** `bots-payments.md` — Inline bot mode, Bot Web Apps, Bot commands
and menu button, Guest bots, Owned bots; `chat.md` — Bot inline buttons,
Inline bot mode, Bot Web Apps, Ephemeral bot replies; old section 7 — Bot
Tools, Ephemeral, Business connection harnesses.

## M41: Dark theme

Night was removed in `8e86854` because the app had only home-made palettes
and they looked wrong. Theme colours now come from official Telegram theme
files, the same way the text comes from the official language pack, so a dark
theme is the official one and the reason for the ban is gone.

- [x] `done` A theme file with `isDark` is accepted (`9c93e8f`); its palette
  recolours the chat, navigation and tab bars, lists, input bar and the
  status bar style.
- [x] `done` Night Blue ships as `resources/NightBlue.tgios-theme`.
- [ ] `planned` A device pass over every screen for colours drawn outside
  `TGTheme+Colours`; `scripts/lint_tokens.sh` catches literals, not roles
  that assume a light plate.
- [ ] `planned` Auto-Night: switch to the chosen dark theme by schedule or
  system setting, where the OS has one.
- [ ] `planned` Dark Theme Backgrounds follows the active theme instead of a
  hand switch.

**Blocked by:** nothing.

**Closes:** `settings.md` — Night Theme and Auto-Night, Dark background
editing.

## M42: Landscape and iPad

- [ ] `deferred` The layout is portrait iPhone only. A 4-inch check was never
  run on a 5/5c, and there is no iPad layout.

**Blocked by:** no design for either size class; rotation support was added
for iOS 6 screens but no layout pass followed.

**Closes:** nothing today.

## M43: Platform delivery and device coverage

- [ ] `partial` iOS 6 support: iOS 7-only calls are guarded; the build has
  never run on a real iOS 6 device.
- [ ] `partial` A 4-inch screen check on a 5/5c; the UI was built for
  3.5-inch.
- [x] `done` `scripts/build_all.sh` builds dependencies and the three release
  IPAs with SHA-256 sums (`3d3d647`).
- [ ] `planned` Background fetch and crash reporting; crashes are pulled by
  hand (7 November 2026).
- [ ] `planned` An arm64 `libtdjson.dylib`; `make ipa-arm64` links but the
  dylib is built for armv7 only.

**Blocked by:** hardware on the bench and a second architecture in the TDLib
build script.

**Closes:** old section 5 rows — iOS 6 support, Push delivery, Background
fetch, arm64 build, Crash reporting.

## M44: Message detail and unread TDLib fields

- [ ] `partial` Rich messages: paragraphs, headings and lists flatten to
  plain lines; formatting, tables, media blocks and button rows do not draw.
- [ ] `partial` The story's own picture in its card, poll option media, the
  timer countdown, service-action buttons (set suggested photo, accept
  birthdate, open suggested post), slot-machine reels, adding checklist
  tasks, call discard reasons, live-location heading and per-minute refresh,
  and animated gift artwork. Background live-location updates need iOS 9;
  iOS 7 kills them.
- [x] `done` Read summary in the message menu (`getMessageReadDate`,
  `getMessageViewers`), `ec1284a`.
- [ ] `planned` `message.author_signature`, `view_count`, `forward_count`,
  `via_bot_user_id`, `linkPreview.type`, `messageForwardInfo.source`,
  `chat.background`, gift counts and `supergroupFullInfo.bot_verification`
  are returned by TDLib and never drawn.

**Blocked by:** the flatten model drops the fields or the bubble has no slot
for them; none needs a new request.

**Closes:** `message-types.md` — messageRichMessage, messageStory,
messageGift, messageUpgradedGift, messageChecklist, messageGroupCall,
messageVideoChatScheduled, messageLiveLocation, Live and motion photos,
Buttons inside rich messages, Poll option media, Signed gift note, AI summary
block, DateTime entity; `channels.md` — Post author signature, Post
statistics on the bubble, Forward count; `chat.md` — Message Info; old
section 8 — Data TDLib sends that no screen shows.

## M45: Updates, changelog and usage

Users install LegacyTG from GitHub or by hand, so nobody learns about a new
build and we do not know how many people run which version. Channel views
do not answer that: they count readers, not installs. The app asks our bot
instead, over MTProto, so the old root certificates of iOS 6-9 do not
matter.

How it works. Once a day, and on launch when the last check is older than
that, the app resolves the bot with `searchPublicChat` and calls
`getInlineQueryResults` with the bot as the target, the account's own Saved
Messages as the chat and the query below. Nothing is sent to any chat. The
bot records the ping and answers with the latest release.

Query (one line, space-separated `key=value`, max 256 bytes):
`lt1 v=<CFBundleShortVersionString> b=<CFBundleVersion> ios=<systemVersion>
dev=<hw.machine> tier=<vintage|legacy|modern|full> jb=<0|1> lang=<pack id>
stats=<0|1>`. `lt1` is the protocol version.

Answer: `is_personal`, `cache_time` 0, up to two `article` results.
- `id` `update`: present when a newer build exists. `title` is the version
  text ("1.3"), `description` is one-line JSON: `{"v":"1.3","b":45,
  "min_ios":"6.0","blocking":false,"ipa":"<GitHub asset URL>",
  "cydia":"cydia://package/org.legacy.itg","notes_b":44}`.
- `id` `notes`: `description` is the changelog text for every build newer
  than the client's `b`, newest first, plain text with `\n`, at most 3500
  characters; older entries are cut whole.
No results means up to date. Any error is silent and retried next day.

The bot. A Cloudflare Worker, kept outside this repository with the
owner (`LegacyTG-update-bot`): the Telegram webhook
answers `inline_query`, reads the latest GitHub release of
`bla1r1/LegacyTG` (cached 10 minutes) and `CHANGELOG.md` from the same
tag, and writes one row per user per day to D1 when `stats=1`:
`day, uid_hash, v, b, ios, dev, tier, jb, lang`. `uid_hash` is
SHA-256(secret salt + Telegram user id); the id itself is never stored.
`stats=0` still gets the update answer and writes nothing. `/stats` from
the owner's account returns daily and weekly users, by version, iOS
version, device and tier.

The app.
- [x] `done` `TGUpdateStore` in `src/Core/Stores`: the daily check, the
  query above, parsing the two results, the skipped build in defaults.
- [x] `done` The official update screen (`UpdateInfoController.swift`,
  presented from `ApplicationContext.swift:589-597`): modal, title
  "Telegram Update" style with our name, app icon, "LegacyTG %@", the
  changelog text, "Update" button, "Skip" on the left unless `blocking`.
  Update opens `cydia` on a jailbroken device, otherwise the `ipa` URL.
- [x] `done` A switch in Privacy and Security, "Send anonymous usage
  statistics", on by default, with a footer that says what is sent. Off
  sends `stats=0`.
- [x] `done` Dev route `itglegacy://updatecheck` forcing a check.

Releases.
- [x] `done` `CHANGELOG.md` at the root, one section per build
  (`## 1.2 (2) - 2026-11-09`), the single source for GitHub release
  notes, the Cydia depiction and the bot's `notes`.
- [ ] `partial` Cydia repo on GitHub Pages, its scripts kept outside this
  repository with the owner (`LegacyTG-cydia`): `scripts/build_deb.sh` packs
  `LegacyTG.app` into `/Applications` with `uicache` in `postinst`;
  `scripts/cydia_repo.py` writes `Packages`, `Packages.bz2`, `Release` and
  a depiction page from `CHANGELOG.md`.

**Blocked by:** GitHub Pages for the Cydia repo. The BotFather bot, the
Worker, D1 and `/stats` are live.

**Closes:** nothing in `status/` yet; adds the delivery rows to M43.

