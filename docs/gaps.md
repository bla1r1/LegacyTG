# Gaps

What LegacyTG does not do, framed by what it costs the person using it. The
milestone list in [ROADMAP.md](ROADMAP.md) says what is planned; this file
says which screen or workflow each gap breaks and how it was observed, so
priorities come from consequences rather than from the size of the TDLib
surface.

Every entry needs three things, or it is not an entry: the gap, what the user
cannot do because of it, and how that was observed. "Probably missing" belongs
in [feature_backlog.md](feature_backlog.md), not here.

## How a gap gets here

1. A screen promises a feature and does less, or an official behaviour has no
   screen at all.
2. The cause is traced to a missing request, a TDLib field the flatten model
   drops, or a controller that was never written.
3. The entry is written with the observation attached: the status row and its
   `file:line`, or the device check named in the old roadmap.
4. It leaves when the milestone closes and the status row turns `done`, or
   the device check passes on the named hardware.

## Open gaps

| Gap | What the user cannot do | Milestone | Observed |
|---|---|---|---|
| Invoice payment | Tap Pay on an invoice; the card draws and the button is removed | M20 | `status/bots-payments.md:25`, `Core/TGMessageContentCommerce.m:203` |
| Paid media | Unlock a blurred paid photo or video with Stars | M20 | `status/bots-payments.md:26`, `Controllers/TGChatViewController+MediaCells.m:303` |
| Paid messages | See or set the price per message for a user who charges Stars | M20 | `status/bots-payments.md:27`, `Controllers/TGChatViewController+Input.m:348` |
| Premium purchase | Buy or renew Premium; the row only reports Active or not | M20 | `status/bots-payments.md:42`, `Controllers/TGSettingsViewController+Actions.m:122` |
| Stars balance and top-up | See a Stars balance or buy more | M20 | `status/bots-payments.md:40`, no `src/` caller |
| Send a gift | Pick a recipient and a gift from Settings or a profile | M20 | `status/bots-payments.md:43`, `sendGift` never called |
| Gift collections and resale | Open collections, auctions or resale; gift artwork is still only | M20 | `status/bots-payments.md:44`, `:45` |
| TON wallet and Passport | Use the TON wallet or Passport vault; all 43 wallet and 8 Passport calls are absent | M20 | `status/bots-payments.md:47`, `:48` |
| StoreKit purchases | Complete a purchase through StoreKit; no receipt path exists | M20 | `status/bots-payments.md:49`, `canPurchaseFromStore` never sent |
| Group-call audio | Hear or speak in a group call; the screen joins signalling and says it has no audio engine | M21 | `status/calls.md:55`, `Controllers/TGGroupCallViewController.m:338`; `status/groups.md:87` |
| Video calls | Call an official client with video; the engine is `TG_DEV` only and the release shows "in progress" | M22 | `status/calls.md:31`, `Core/TGCapabilities.m:83` |
| Send a document or a music track | Attach a file or audio; the attach sheet has no document or audio picker | M23 | `status/chat.md:47`, `Views/TGAttachSheet.h:8`; `status/media.md:32` |
| Music streaming | Start a long track without downloading the whole file first | M23 | `status/media.md:23`, `Audio/TGMusicPlayer.m:91` |
| Silent send | Send without a notification; the normal send path builds no `messageSendOptions` | M23 | `status/chat.md:74`, `Core/TGClient+Messages.m:405` |
| Repeated scheduled message | Set a repeat period; `repeat_period` is hardcoded to 0 | M23 | `status/chat.md:73`, `Core/TGClient+Messages.m:454` |
| GIF caption | Add a caption when sending a GIF | M23 | `status/chat.md:53`, `Core/TGClient+Stickers.m:405` |
| Chat-list thumbnail and type glyph | See a photo/video thumbnail or a content-type glyph in a row preview | M24 | `status/chat-list.md:45`, `:46`, `Controllers/TGChatListViewController.m:1904` |
| Reaction and poll badges | See a reaction or poll-vote badge on a chat row | M24 | `status/chat-list.md:30`, `:31`, `Controllers/TGChatListViewController.m:1941` |
| Compact unread counts | See "1.2K" instead of a plain decimal | M24 | `status/chat-list.md:32`, `Controllers/TGChatListViewController.m:1954` |
| Unread badge on the Chats tab | See the unread count on the root tab | M24 | `status/chat-list.md:69`, `Controllers/RootViewController.m:97` |
| Folder tags on a row | See which folders a chat belongs to | M24 | `status/chat-list.md:48`, `Core/TGClient+Chats.mm:1875` |
| Saved Messages row | Open Saved Messages from the chat list; the header rows only add the archive | M24 | `status/chat-list.md:64`, `Controllers/TGChatListViewController.m:1509` |
| Story rings outside the strip | See an active-story ring on chat rows or the profile avatar | M25 | `status/chat-list.md:39`, `Views/TGChatCell.m:56`; `status/profile.md:91` |
| Chat search filters | Filter in-chat search by sender, media or date, or open the hit | M26 | `status/chat.md:69`, `:70`, `Controllers/TGChatViewController+Search.m:68` |
| Search tokens and scopes | Search an archive, folder, peer or date; open Channels, Apps, Posts or Downloads | M26 | `status/chat-list.md:85`, `TGSearchViewController.m:131` |
| Failed-send mark | See that a message failed without opening the hold menu | M27 | `status/chat.md:34`, `Controllers/TGChatViewController+Cells.m:316` |
| Profile cover | See the accent gradient and background emoji behind a profile header | M28 | `status/profile.md:59`, `Controllers/TGProfileViewController.m:380` |
| QR code of the username | Show or scan the account's own QR from the profile or Settings | M28 | `status/profile.md:113`, no screen |
| Premium star badge | See the star beside a Premium name | M28 | `status/profile.md:58`, `Controllers/TGProfileViewController.m:431` |
| Profile rating and verifier note | See the rating level, `bot_verification` note or unofficial-app warning | M28 | `status/profile.md:61`, `:62`, `:63` |
| Profile GIF and Polls tabs | Browse GIFs or polls from a profile, or jump by month or calendar | M29 | `status/profile.md:77`, `:78`, `:81`, `Core/TGProfileTabs.m:6` |
| Media multi-select and pane search | Select several profile media items or search inside a pane | M29 | `status/profile.md:83`, `:84`, `Controllers/TGProfileViewController.m:814` |
| Settings search | Find a Settings row by name; no field or index exists | M30 | `status/settings.md:19`, `Controllers/TGSettingsViewController+Pages.m:82` |
| Notification category pages | Set notifications per category; the page is three mute switches | M31 | `status/notifications.md:18`, `Controllers/TGSettingsViewController+PrivacyPages.m:82` |
| In-app notification banner | See a banner while using the app | M31 | `status/notifications.md:29`, `Controllers/TGActiveNotificationsViewController.m:76` |
| Notification warning and badge settings | Know notifications are denied or set a badge count | M31 | `status/notifications.md:36`, `:37` |
| Assign a custom sound | Choose a custom sound for a chat or scope | M31 | `status/notifications.md:23`, `Controllers/TGSettingsViewController+PrivacyPages.m:215` |
| Invite Friends and phone-book import | Invite a contact or import the address book; only `importedContactCount` is read | M32 | `status/contacts.md:20`, `:21`, `:22` |
| Formatted Add Contact | Pick a country code, format the phone, resolve it live or add by QR | M32 | `status/contacts.md:25`, `:26`, `:27`, `TGNewContactViewController.m:236` |
| Localisation | Use the interface in any language; about 2200 strings are hard-coded English | M33 | `status/settings.md:42`, `TGSettingsViewController+Pages.m:258` |
| TDLib error text in alerts | Read a sentence instead of `PHONE_CODE_INVALID` or "Bad Request: ..."; about 157 alerts carry the raw message | M34 | `status/login-accounts.md:47`, `Core/TGClient.m` |
| Harness pages in release Settings | Use Data and Storage without File Tools and the TDLib state page | M34 | `status/settings.md:39`, `TGSettingsViewController+NetworkPages.m:55` |
| Active Notifications behind `TG_DEV` | Reach the notification list from release Settings | M34 | `status/notifications.md:28`, `TGSettingsViewController+PrivacyPages.m:409` |
| Poll creation | Create a poll from the attach sheet | M35 | `status/chat.md:87`, `Views/TGAttachSheet.m:260` |
| Copy in multi-select | Copy several selected messages | M35 | `status/chat.md:65`, `Controllers/TGChatViewController+Selection.m:148` |
| Forward with caption or to a topic | Add a caption to a forward or send it into a forum topic | M35 | `status/chat.md:57`, `:58`, `Controllers/TGForwardPicker.m:154` |
| Per-admin rights editor | Choose what a new administrator may do; promote sends one default object | M36 | `status/groups.md:36`, `Core/TGClient+Groups.m:22` |
| Invite-link detail | See dates, limits, QR and revoked links separately | M36 | `status/groups.md:49`, `TGGroupSettingsViewController.m:1908` |
| Administrators and removed users | Open an administrators screen or a banned/restricted list | M36 | `status/groups.md:100`, `:101` |
| Statistics graphs and boosts | See channel statistics as graphs or open a boost surface | M36 | `status/groups.md:73`, `status/channels.md:72` |
| Privacy exception lists | Choose Always Share With / Never Share With, or set bio, gift, voice and phone-discovery privacy | M37 | `status/privacy-security.md:52`, `TGSettingsViewController+Actions.m:447` |
| Storage maximum and per-chat rules | Cap the cache or keep media per peer type | M37 | `status/privacy-security.md:76`, `TGStorageViewController.m:190` |
| Theme thumbnails and background gradient | Apply a chat theme, choose a colour/gradient/pattern, or browse the official wallpaper collection | M37 | `status/settings.md:58`, `:59`, `:62`; `getBackgrounds` never called |
| Live and motion photos | Play the video half of a live photo | M38 | `status/media.md:43`, `Core/TGMessageFlatten.m:226` |
| Video scrub preview | See a frame while scrubbing a video | M38 | `status/media.md:19`, `Views/TGMediaViewer.m:630` |
| Sticker pack keyword search | Search packs by keyword; only a t.me short name is accepted | M38 | `status/media.md:38`, `TGStickerPacksViewController.m:394` |
| Link preview picture | See the preview image; only title, site and description are read | M38 | `status/media.md:34`, `TGChatViewController+Layout.m:678` |
| Story camera video | Record a video story; the camera captures stills only | M39 | `status/stories.md:31`, `TGStoryCameraViewController.m:279` |
| Story reply and share | Reply to a story with a message or repost it | M39 | `status/stories.md:43`, `:44` |
| Live story playback | Watch a live story; joining copies the tgcalls payload | M39 | `status/stories.md:47`, `TGLiveStoryViewController.m:1` |
| Inline bots and Web Apps | Use `@bot query`, open a Web App or a mini app | M40 | `status/chat.md:94`, `:95`; `status/bots-payments.md:18`, `:19` |
| Game and password bot buttons | Press Play, Pay or a password callback; they answer "needs a newer Telegram" | M40 | `status/chat.md:93`, `TGChatViewController+Bots.m:30` |
| iOS 6 on real hardware | Trust the iOS 6 build; iOS 7-only calls are guarded but the app has never run on iOS 6 | M43 | old roadmap device check, section 5 |
| 4-inch screen layout | Use the app on a 5/5c without clipped layout; it was built for 3.5-inch and never checked | M43 | old roadmap device check, section 4 |
| Crash reporting | Send a crash report; crashes are pulled by hand | M43 | old roadmap, section 5 |
| arm64 TDLib | Run the arm64 UI against an arm64 `libtdjson.dylib`; only armv7 is built | M43 | old roadmap, section 6 |
| Rich message formatting | Read bold, tables, media blocks and button rows inside a rich message | M44 | `status/message-types.md:22`, `Core/TGMessageFlatten.m:694` |
| Message detail fields | See a signature under a channel post, view and forward counts, or a service action | M44 | `status/channels.md:33`, `:35`, `:68` |
| Phone-to-phone 1:1 calls | Call another phone running this app and hear audio; modern Telegram iOS rejects the version | M13 (closed, external) | `status/calls.md:69`, `Calls/TGCall.mm` |
| Night theme | Use a dark interface; Night and Auto-Night were removed | M41 (deferred) | `status/settings.md:65`, `Core/TGTheme.m:43` |
