## Release 1.4: one look for messages and screens

Status: `planned`. 1.3 (3) shipped on 2026-11-14; its notes are in `CHANGELOG.md` and its work in the git history since the `1.2` tag.

1.4 is a visual release. The core was standardised in 1.3 (stores, one TDLib boundary, tested functions); the UI was not. Messages are laid out by one function, `TGMessageRowLayout`, and still draw badly in places: the view count drifts, the stamp sits on a picture that is not the last thing in the bubble, every picture has a hard 1 pt frame no iOS release draws. Screens share `TGRowsViewController`, and `TGPageViewController` exists, but no screen uses it yet. Each item below that changes how something looks starts as a list in `docs/ui-parity/` that the user approves, with before and after shots from `scripts/shots.sh`.

Most people on the channel run iOS 6. A screen that is only checked on iOS 12, or only in the light theme, is not checked.

### 1. Messages: one bubble, drawn the same way for every kind

- [ ] `planned` Audit. Dump every message kind in the Dev Showcase, Saved Messages and @telegram with `itglegacy://dumplayout` and shoot them light and dark on the iPod touch 4. Write each defect into `docs/ui-parity/messages.md` with its shot; nothing moves before that list is approved.
- [ ] `planned` The stamp (time, ticks, edited, views) is measured in one place. `TGMessageRowLayout.m` sizes the eye and the count twice (around lines 239 and 544), and the two disagree; one function returns the stamp's width and parts, with a test per combination.
- [ ] `planned` The stamp goes on a picture only when the picture is the last thing in the bubble. With a caption under it, or a reply, reactions or a link preview after it, the stamp sits on the text line, as the official client does. A rule in `TGMessageStampOnPicture` with tests.
- [ ] `planned` Pictures in bubbles: no hard 1 pt frame (`TGMessageBubbleCell.m:73`). The corner follows the bubble's own corner; where a frame is needed against a white picture, a hairline in the bubble's colour from `TGStyle`, the same in light and dark.
- [ ] `planned` The bubble's parts as one set: sender line, reply quote, picture or collage, caption, card, link preview, stamp, reactions. Each is placed by `TGMessageRowLayout` and drawn by one cell method, so a kind cannot draw its own variant. Layout tests per part and per kind.
- [ ] `planned` Lottie trim paths: 8 of the 14 `.tgs` files on the bench phone that keep their still would animate (M38). Merge paths and precomps after that.

### 2. Screens: one page, filled differently

- [ ] `planned` Move screens onto `TGPageViewController`, one list in `docs/ui-parity/` each: forward picker (Picker), contacts (List), File Info (Detail), sticker editor (Form), profile media (Gallery). Then the Settings pages, which already sit on the shared rows.
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

### Not in 1.4

M20 payments and Stars, M21 group-call audio, M22 video calls and M40 bots and mini apps are each a release of their own; M42 iPad and landscape stays deferred. The other open milestones stay on `docs/ROADMAP.md`.
