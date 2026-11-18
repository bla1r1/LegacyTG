## Release 1.5: one look for messages and screens

Status: `planned`. 1.4 (4) shipped on 2026-11-16 as a sign-in and fixes release (`CHANGELOG.md`); this visual scope moved to 1.5 unchanged.

1.5 is a visual release. The core was standardised in 1.3 (stores, one TDLib boundary, tested functions); the UI was not. Messages are laid out by one function, `TGMessageRowLayout`, and still draw badly in places: the view count drifts, the stamp sits on a picture that is not the last thing in the bubble, every picture has a hard 1 pt frame no iOS release draws. Screens share `TGRowsViewController`, and `TGPageViewController` exists, but no screen uses it yet. Each item below that changes how something looks starts as a fix list the user approves, with before and after shots from `scripts/shots.sh`; the lists stay out of the repository, and what changed goes into `docs/status/`.

Most people on the channel run iOS 6. A screen that is only checked on iOS 12, or only in the light theme, is not checked.

### 1. Messages: one bubble, drawn the same way for every kind

- [ ] `planned` Audit. Dump every message kind in the Dev Showcase, Saved Messages and @telegram with `itglegacy://dumplayout` and shoot them light and dark on the iPod touch 4. List each defect with its shot; nothing moves before that list is approved.
- [ ] `planned` The stamp (time, ticks, edited, views) is measured in one place. `TGMessageRowLayout.m` sizes the eye and the count twice (around lines 239 and 544), and the two disagree; one function returns the stamp's width and parts, with a test per combination.
- [ ] `planned` The stamp goes on a picture only when the picture is the last thing in the bubble. With a caption under it, or a reply, reactions or a link preview after it, the stamp sits on the text line, as the official client does. A rule in `TGMessageStampOnPicture` with tests.
- [ ] `planned` Pictures in bubbles: no hard 1 pt frame (`TGMessageBubbleCell.m:73`). The corner follows the bubble's own corner; where a frame is needed against a white picture, a hairline in the bubble's colour from `TGStyle`, the same in light and dark.
- [ ] `planned` The bubble's parts as one set: sender line, reply quote, picture or collage, caption, card, link preview, stamp, reactions. Each is placed by `TGMessageRowLayout` and drawn by one cell method, so a kind cannot draw its own variant. Layout tests per part and per kind.
- [ ] `planned` Lottie trim paths: 8 of the 14 `.tgs` files on the bench phone that keep their still would animate (M38). Merge paths and precomps after that.

### 2. Screens: one page, filled differently

- [ ] `planned` Move screens onto `TGPageViewController`, one approved list each: forward picker (Picker), contacts (List), File Info (Detail), sticker editor (Form), profile media (Gallery). Then the Settings pages, which already sit on the shared rows.
- [ ] `planned` One row kind for sessions and websites (Devices, Active Websites).
- [ ] `planned` The empty state knows the keyboard: "No matching contacts found" centres on the whole table and the keyboard covers its second line.
- [ ] `planned` Topics and Saved Topics stop painting their table themselves and take the base's paint.
- [ ] `planned` A dark-theme pass over every screen on iOS 6 (M41): `scripts/walk.sh` and the `itglegacy://screen/` routes, shot and compared. The dark theme closed the app at launch on iOS 6 until 1.3.

### 3. Small things that spoil the look (found in 1.3)

- [ ] `planned` The composer's "Message" placeholder stays shifted after a long draft is cleared.
- [ ] `planned` The Russian pack shows "Кэш Кеш Мест…" on one storage row: two keys joined.
- [ ] `planned` The group call and the video player write `00:07`; every other clock writes `0:07`.
- [ ] `planned` The Calls and Forwarded Messages privacy pages have no help text; find the official keys or leave them empty on purpose.
- [ ] `planned` The first `itglegacy://saved` after a cold launch does nothing (dev route).

### 4. Checked on a device before the release

- [ ] `planned` The passcode after the Keychain change; an incoming message with the chat open; an account switch; a live call.
- [ ] `planned` A chat opened on return from the background once stayed empty.
- [ ] `planned` Dragging chat folders; swiping between profile photos; the privacy help texts; 26 of the 27 `UILabel` background fixes.
- [ ] `planned` The dev component gallery is killed for memory at about 39 MB on the iPod touch 4.

### 5. Under the hood, only what protects the look

- [ ] `planned` Tests for `src/Media` (WebP, WebM, patterns: 14%) and `src/Audio` (0%): they parse data from outside, and a broken sticker or voice note on an old device is a crash, not a blank.
- [ ] `planned` Line coverage per file through `llvm-cov` (`-fprofile-instr-generate -fcoverage-mapping`).
- [ ] `planned` The rest of `Features/Profile` and `Features/Settings` logic into tested functions as those screens are touched; `TGGroupData` builds `TGRows` directly.

### 6. If there is room

- [ ] `planned` M35 message actions: poll creation, forward with a caption, reply with a quote, the pinned messages list.
- [ ] `planned` M26 chat search filters: sender, media type, date.
- [ ] `planned` M33 localisation: 170 strings with no official match.

### 7. Data TDLib hands us and no screen shows

`scripts/lint_fields.sh` (in `make test`) lists every field of 1700+ reachable TDLib object types that `src/` never reads, in `scripts/tdlib_fields.txt`: `todo <screen>` where official shows it, `skip` with a reason, `open` not looked at. A field that is drawn leaves the list; a new unread one fails the build. Work proceeds in groups of about 20 fields with one build, install and shot run, each item placed where official has it.

- [x] `done` (15-16 November 2026): online expiry, story rings, chat-list notices, the hold menu from getMessageProperties, sessions, data usage date, SMS word codes, call status and rating, extra usernames, bot "Add to Group or Channel" and verification, join request bar, slow mode.
- [x] `done` Part 3: jump buttons for unread reactions and poll votes, failed-send reasons, bot keyboard size and persistence, date and media timestamp entities, link preview pictures, boost badge, imported date, commenter faces. Two left as todo with the reason: the inline bot placeholder and linkPreview.display_url.
- [x] `done` Part 4: auto-delete timers in the hold menu, restricted messages, video start time, manual quotes, bot commands key and list, inviter rule, group sticker set row, business hours, public photo, free transcriptions left, email reset state. Left as todo with the reason: the Add Email screen, the boost level badge, collectible usernames.
- [ ] `planned` The remaining `todo` fields (21 after previous updates, 16 of them statistics graphs): chat (unread reactions and poll votes, failed-send reasons, bot keyboard, link preview layout, media timestamps, date entities, inline bot placeholder), bubbles (commenter avatars, boost badge, imported date, timers, restriction notice, manual quotes, video start), groups (bot commands, inviter, boost level, restricted count), profile (business hours, public photo, collectible and secondary usernames), settings (transcription trial), sign-in (email reset), statistics graphs.
- [x] `done` Part 6: the first 100 open fields sorted (todo with the screen, skip with the reason); drawn from them: the new-contact card, Unarchive in the bar, the join request notice, the paid-message placeholder, the track cover minithumbnail.
- [x] `done` All open fields sorted (15 November 2026): 285 `todo <screen>` where the screen already exists (chat 60, admin log 59, bubble 38, links 26, profile 23, Instant View 20, group 16, statistics 13, stories 10, Stars 10, the rest under 5), 239 `todo later` for screens this client has not built (gift shop and auctions, boosts, attachment-menu bots, payments form and receipts, downloads list, revenue pages, managed and guest bots, keyboard request buttons), 269 `skip` with the reason (TON wallet, Passport, Mini Apps and the in-app browser, Premium purchase, call engine internals, push payloads, bot-side updates, animated avatars, HLS and storyboards, list updates the screens re-read).
- [x] `done` (17 November 2026), bubble: service lines lead to the game, checklist, poll, suggested post or earlier wallpaper they are about; "set the same wallpaper", the default self-destruct timer, official's payment line with subscription words, giveaway results with unclaimed links and Stars, the unclaimed prize code. The payment receipt and the giveaway sheet's "N other channels" stay todo: the receipt screen is not built, and the sheet has only its status part. Not run on a device or through the host suite (Linux session; compile-checked for armv7 and arm64).
- [x] `done` (17 November 2026), bubble: secret chat media veiled and opened once, the poll's per-account option order, hidden results and restricted voting, the Business bot's name by the time, the "Stars Will Be Lost" warning on a paid suggested post, the paid media caption in an invoice. Add an Option in someone else's poll waits for the owner's answer (inline field or alert); the quiz explanation picture, 18+ media, checklist-task replies and the giveaway sheet's channel count are the next bubble update. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), profile: "support" and "N users" in the status line, the unofficial client warning, Share My Phone Number when adding a contact who hides their number. Private calls and "hidden by your settings" wait for the group-call invite screen and the Premium last-seen sheet; the bot owner's rows, the verification icon and the stories flags are the next profile update. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), profile: a bot's affiliate program row with its commission and footer. Ten bot owner fields (edit links, verification parameters, revenue, media previews) wait for the owner's Edit screen, the verify sheet, the revenue pages and the preview pane. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), group: forum topics paged to the end, a bot member's message access under its name. Eleven group fields sorted (eight wait for the administrators list, the invite-link screen, the per-right permissions screen, the reactions screen and paid media; three are never shown by official). Not run on a device or through the host suite.
- [x] `done` (17 November 2026), links: TDLib's link type decides where Instant View (with its fallback), story, live story, channel direct messages, Settings section, contacts, calls and profile links open. Bot start autostart and Passport are skipped as official does; managed bots and the Stars purchase wait for their screens; background, theme, story album, new story, gift collection, message draft, video chat and the add-bot rights links are the next links update. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), stories: tappable link and message areas with official's hit test and menu, the latest viewers' faces by the views line, pinned stories first. The "only you" mark and the flipped reaction widget stay todo. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), Stars: subscription fee, Bot API message count and withdrawal state on the transaction row. Commissions wait for the transaction details screen; the sticker set outline is skipped as an effect and the emoji-status set filter waits for installed sets in the channel status picker. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), settings and sign-in: Downloads split into Downloading and Recently Downloaded with the right Pause All / Resume All, zero and two plural forms, the age check on terms of service. Download update counts, the language pack size and Passport data are skipped as official does; the chat list downloads button and group call key emoji wait for their features. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), bubble, profile and links: replies quote the checklist task they answer, 18+ media under official's veil and alert, the third-party verification mark in the profile header. Thirteen link, profile and reply fields sorted (six skipped as official does, seven wait for the bot rights screen, gift collection and story album profile modes, the theme and wallpaper previews). Not run on a device or through the host suite.
- [x] `done` (17 November 2026), statistics: change against the previous period on every overview number, story means, RECENT POSTS, TOP MEMBERS, TOP ADMINS and TOP INVITERS. The reaction widget's flip, the "only you" story badge and the message draft link wait for parts not built. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), Instant View: anchor and reference links, folding details, button rows, bold header cells, "Wrong layout?". The table grid and media blocks are later; bot commands and cashtags are skipped as official does. Not run on a device or through the host suite.
- [x] `done` (17 November 2026), bubble: the ended giveaway sheet's draw sentence with other channels; the quiz explanation picture waits for the quiz answer bubble. One `todo` field is left, messagePoll.can_add_option, with a question for the owner (inline field in the bubble as official, or an alert with a field at the same row). The parity additions were compile-checked on Linux only: neither the host suite nor a device has run them.
- [x] `done` Review of `skip` and `todo later` (17 November 2026): 70 fields back to `todo <screen>` where the screen exists or official shows the field and only our choice kept it out - the received gift screen's rarity, issued count, owner, original details and publisher (gift 10), Recent Actions colour lines (adminlog 8), the link preview button, Saved Messages tags, Share to Story, Copy Link at a time, migrated group history, emoji suggestions, outside track covers, greeting sticker, AI summary, slot machine reels, big emoji size, premium sticker effect (bubble 28), star rating and video avatars on tiers that can play them (profile 9), the theme's animated gradient (settings 2), embedded web content in Instant View (iv 4), settings link subsections (links 9), a sticker as the group photo (group 1). Sponsored messages and video ads are todo with a question for the owner. The "Premium, Stars and Gifts" console under Settings > Telegram Stars is a tools screen in a release build (Chat ID prompts, raw text); it does not count as the boosts, revenue or subscriptions screens.
- [x] `done` (17 November 2026), bubble: "Add an Option" row under an open poll's options when TDLib says messagePoll.can_add_option (official ChatMessagePollAddOptionNode); an alert holds the field, the text is cut at official's 100-character limit. The hold menu's "Add an Option" now follows the same flag instead of authorship. Host tests for it pass on Linux; not checked on a device. Sponsored messages and video ads are skipped by the owner's decision.
- [x] `done` (17 November 2026), links: a tg://settings link with a subsection opens that subsection's page where this client has one (official handleSettingsPathUrl): Blocked Users, Passcode, each privacy rule, Proxy, Save to Photos, Storage, Chat Wallpaper, Auto-Night Mode; any other subsection opens its section page. Host test passes on Linux; not checked on a device.
- [x] `done` (17 November 2026), Recent Actions: a channel's name or profile colour change reads as official's sentence with the new colour as a painted dot and the new icon as its emoji ("Ann changed the channel name color and icon to ● 🐱"). Host tests pass on Linux; not checked on a device.
- [x] `done` (17 November 2026), gift: a unique gift's page gains official's Owner and Telegram (host) rows, the rarity beside Model, Symbol and Backdrop ("Pepe · 1.2%", "epic"), Availability ("1,500/20,000 issued") and the "Gifted by X to Y on DATE" line. "released by @channel" waits for a chat username lookup (upgradedGift.publisher_chat_id stays todo). Host tests pass on Linux; not checked on a device.
- [x] `done` bubble: official's button under a Telegram link's preview (SEND MESSAGE, OPEN PROFILE, VIEW CHANNEL, VIEW GROUP, REQUEST TO JOIN, VIEW MESSAGE, JOIN AS SPEAKER / LISTENER, VIEW BACKGROUND, VIEW THEME, OPEN APP, VIEW CHAT LIST, OPEN STORY, BOOST, VIEW STICKERS / EMOJIS, VIEW COLLECTIBLE, JOIN GROUP CALL); a voice chat, background or theme link is retitled as official does. The wallpaper and theme pictures in those previews are still `todo`. Host tests pass on Linux; not checked on a device.
- [x] `done` bubble: Saved Messages reactions drawn as tags: no count and no reactor face, the tag's label in the count's place when it has one (labels from updateSavedMessagesTags). The tag shape itself is decoration and stays a chip. Host tests pass on Linux; not checked on a device.
- [x] `done` bubble: a big emoji whose sticker TDLib has not sent yet holds its expected size (animatedEmoji.sticker_width / sticker_height), so the row does not jump when the file lands. Host test passes on Linux; not checked on a device.
- [x] `done` bubble: a track without its own cover shows one of the covers TDLib found outside (audio.external_album_covers), the smallest wide enough for the bubble. Host test passes on Linux; not checked on a device.
- [x] `done` gift: a unique gift published by a channel says "released by @channel" under its title when no sender line takes the place. Host tests pass on Linux; not checked on a device.
- [x] `done` settings: a chat theme's outgoing accent applies only when the theme has one (has_outgoing_message_accent_color); without it the 0 TDLib sends had drawn outgoing accents transparent black. Host test passes on Linux; not checked on a device.
- [x] `done` bubble: the slot machine dice draws its three reels and lever over the background, played together, as official stacks them; a half-arrived machine shows the background only. Host test passes on Linux; not checked on a device.
- [x] `done` profile: the star rating's level badge after the status line, and the Rating screen it opens: the level and points to the next one, your own pending change ("The rating updates today. 200 points are pending."), and the three things that move the rating. Official's "Preview" of the future rating is not built; its link is dropped from the sentence. Host tests pass on Linux; not checked on a device.
- [x] `done` bubble: a background link's preview pictures the wallpaper: a plain or gradient background as a swatch of its colours, an image or pattern as its thumbnail. Host test passes on Linux; not checked on a device.
- [x] `done` profile: a moving profile picture plays in the header, silent and looped from its main frame, on Modern and Full devices (Settings > This device lists "Video profile pictures"); Vintage and Legacy keep the still. The clip is rounded by a ring image, not a mask. Host tests pass on Linux; not checked on a device.
- [x] `done` bubble: a premium sticker plays its effect once around it when it first shows in a chat visit, mirrored for incoming, on the Full tier only (Settings > This device lists "Premium sticker effects"). Host test passes on Linux; not checked on a device.
- [x] `done` profile: a profile picture made from a sticker of a set plays that sticker over its fill in the header, on the same Modern and Full devices as video pictures; the rest keep the still. Host tests pass on Linux; not checked on a device.
- [x] `done` bubble: a theme link's preview pictures the theme: the swatch of its outgoing bubble fill (or its accent) when the settings are known, else the theme file's thumbnail. Host test passes on Linux; not checked on a device.

### 8. Rendering: fewer layers, drawn off the main thread

Scroll jank on the iPod touch 4 is the render server (backboardd), which pays for every layer, not our Objective-C. A bubble is 15-30 views today. Core Graphics and Core Text are C APIs, so the content can be laid out and drawn in C++ on a background queue and shown as one layer, as official's Texture does; UIKit stays the shell and the look does not change.

- [ ] `planned` Measure first: layers per cell, frame time in backboardd and layout time while scrolling a long chat on the iPod touch 4, light and dark.
- [ ] `planned` `TGMessageRowLayout` in C++ behind an Objective-C++ facade, computed ahead of the visible rows on a background queue; host tests keep their numbers.
- [ ] `planned` Text bubbles drawn into one bitmap (text, background, time, ticks, sender, quote) in C++, set as `layer.contents`; taps resolved through `TGMessageTapPartAt`; an LRU cache inside the 16 MB ceiling. Compare against the first measurement before going further.
- [ ] `planned` The other kinds one at a time; video, animated stickers, buttons and text selection stay live views.
- [ ] `planned` TDLib updates parsed into C++ structs instead of `NSDictionary`, where the measurement shows the allocations cost the first paint.
- [ ] `planned` The message stream keyed by (chat, message id), with every action taking its chat from the message. Then a supergroup shows the basic group's history before the upgrade in the same list, as official does (supergroupFullInfo.upgraded_from_basic_group_id / upgraded_from_max_message_id); today the two chats' ids can collide and every action goes to one chat.

### 9. The hold menu as official's

Proposed from the comparison with official screenshots (15 November 2026), waiting for the user's approval: the card aligned to the bubble's edge, sized to its longest row; official's rows and order (no Quote, Translate only when enabled, no Speak, "Report"); Select after a divider; the "edited" header; the custom emoji footer; the reaction bar's tail; emoji tags in Saved Messages. The card's look stays ours unless the user decides otherwise.

### Not in 1.5

M20 payments and Stars, M21 group-call audio, M22 video calls and M40 bots and mini apps are each a release of their own; M42 iPad and landscape stays deferred. The other open milestones stay on `docs/ROADMAP.md`.
