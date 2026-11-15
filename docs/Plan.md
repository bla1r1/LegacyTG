## Release 1.4: one look for messages and screens

Status: `planned`. 1.3 (3) shipped on 2026-11-14; its notes are in `CHANGELOG.md` and its work in the git history since the `1.2` tag.

1.4 is a visual release. The core was standardised in 1.3 (stores, one TDLib boundary, tested functions); the UI was not. Messages are laid out by one function, `TGMessageRowLayout`, and still draw badly in places: the view count drifts, the stamp sits on a picture that is not the last thing in the bubble, every picture has a hard 1 pt frame no iOS release draws. Screens share `TGRowsViewController`, and `TGPageViewController` exists, but no screen uses it yet. Each item below that changes how something looks starts as a fix list the user approves, with before and after shots from `scripts/shots.sh`; the lists stay out of the repository, and what changed goes into `docs/status/`.

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

`scripts/lint_fields.sh` (in `make test`) lists every field of 1700+ reachable TDLib object types that `src/` never reads, in `scripts/tdlib_fields.txt`: `todo <screen>` where official shows it, `skip` with a reason, `open` not looked at. A field that is drawn leaves the list; a new unread one fails the build. Work goes in batches of about 20 fields with one build, install and shot run per batch, each item placed where official has it.

- [x] `done` Batches 1-2 (15-16 November 2026): online expiry, story rings, chat-list notices, the hold menu from getMessageProperties, sessions, data usage date, SMS word codes, call status and rating, extra usernames, bot "Add to Group or Channel" and verification, join request bar, slow mode.
- [x] `done` Batch 3: jump buttons for unread reactions and poll votes, failed-send reasons, bot keyboard size and persistence, date and media timestamp entities, link preview pictures, boost badge, imported date, commenter faces. Two left as todo with the reason: the inline bot placeholder and linkPreview.display_url.
- [x] `done` Batch 4: auto-delete timers in the hold menu, restricted messages, video start time, manual quotes, bot commands key and list, inviter rule, group sticker set row, business hours, public photo, free transcriptions left, email reset state. Left as todo with the reason: the Add Email screen, the boost level badge, collectible usernames.
- [ ] `planned` The remaining `todo` fields (21 after batch 4, 16 of them statistics graphs): chat (unread reactions and poll votes, failed-send reasons, bot keyboard, link preview layout, media timestamps, date entities, inline bot placeholder), bubbles (commenter avatars, boost badge, imported date, timers, restriction notice, manual quotes, video start), groups (bot commands, inviter, boost level, restricted count), profile (business hours, public photo, collectible and secondary usernames), settings (transcription trial), sign-in (email reset), statistics graphs.
- [x] `done` Batch 6: the first 100 open fields sorted (todo with the screen, skip with the reason); drawn from them: the new-contact card, Unarchive in the bar, the join request notice, the paid-message placeholder, the track cover minithumbnail.
- [x] `done` All open fields sorted (15 November 2026): 285 `todo <screen>` where the screen already exists (chat 60, admin log 59, bubble 38, links 26, profile 23, Instant View 20, group 16, statistics 13, stories 10, Stars 10, the rest under 5), 239 `todo later` for screens this client has not built (gift shop and auctions, boosts, attachment-menu bots, payments form and receipts, downloads list, revenue pages, managed and guest bots, keyboard request buttons), 269 `skip` with the reason (TON wallet, Passport, Mini Apps and the in-app browser, Premium purchase, call engine internals, push payloads, bot-side updates, animated avatars, HLS and storyboards, list updates the screens re-read).

### 8. Rendering: fewer layers, drawn off the main thread

Scroll jank on the iPod touch 4 is the render server (backboardd), which pays for every layer, not our Objective-C. A bubble is 15-30 views today. Core Graphics and Core Text are C APIs, so the content can be laid out and drawn in C++ on a background queue and shown as one layer, as official's Texture does; UIKit stays the shell and the look does not change.

- [ ] `planned` Measure first: layers per cell, frame time in backboardd and layout time while scrolling a long chat on the iPod touch 4, light and dark.
- [ ] `planned` `TGMessageRowLayout` in C++ behind an Objective-C++ facade, computed ahead of the visible rows on a background queue; host tests keep their numbers.
- [ ] `planned` Text bubbles drawn into one bitmap (text, background, time, ticks, sender, quote) in C++, set as `layer.contents`; taps resolved through `TGMessageTapPartAt`; an LRU cache inside the 16 MB ceiling. Compare against the first measurement before going further.
- [ ] `planned` The other kinds one at a time; video, animated stickers, buttons and text selection stay live views.
- [ ] `planned` TDLib updates parsed into C++ structs instead of `NSDictionary`, where the measurement shows the allocations cost the first paint.

### 9. The hold menu as official's

Proposed from the comparison with official screenshots (15 November 2026), waiting for the user's approval: the card aligned to the bubble's edge, sized to its longest row; official's rows and order (no Quote, Translate only when enabled, no Speak, "Report"); Select after a divider; the "edited" header; the custom emoji footer; the reaction bar's tail; emoji tags in Saved Messages. The card's look stays ours unless the user decides otherwise.

### Not in 1.4

M20 payments and Stars, M21 group-call audio, M22 video calls and M40 bots and mini apps are each a release of their own; M42 iPad and landscape stays deferred. The other open milestones stay on `docs/ROADMAP.md`.
