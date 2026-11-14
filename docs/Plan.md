## Release 1.4

Status: `planning`. 1.3 (3) shipped on 2026-11-14; its notes are in `CHANGELOG.md` and its work in the git history since the `1.2` tag. Below is what 1.3 left open, then the milestones 1.4 can take on top.

### Carried over from 1.3

#### Coverage and the decoders (was phase 9)
- [ ] `planned` Build the host suite with `-fprofile-instr-generate -fcoverage-mapping` and report per file through `llvm-cov`. "Compiled into the suite" is an upper bound; this shows the holes inside `Core`.
- [ ] `planned` Tests for `src/Media` (WebP, WebM, patterns: 14% today) and `src/Audio` (0%). Both parse data from outside and neither needs UIKit.

#### Logic out of the screens (rest of phase 8)
- [ ] `planned` The rest of `Features/Profile` and `Features/Settings` as they are touched: a calculation that needs no `UIView` becomes a function with a test.
- [ ] `planned` `TGGroupData` builds its own row model (`TGRow`, `TGInfoRow`, `TGSection`) and converts it later; it can build `TGRows` directly.
- [ ] `planned` Chat tools and settings, Saved Messages and DM topics, quick replies, link and media downloads and the name, title and emoji-status caches still delegate to the client from explicit store methods; give them their own request bodies.

#### Screens on the base set
- [ ] `planned` Move existing screens onto `TGPageViewController` one at a time, each through a list in `docs/ui-parity/` approved first: forward picker (Picker), contacts (List), File Info (Detail), sticker editor (Form), profile media (Gallery).
- [ ] `planned` One row kind for sessions and websites: Devices and Active Websites keep their own rows.
- [ ] `planned` The empty state knows the keyboard: "No matching contacts found" centres on the whole table and the keyboard covers its second line.
- [ ] `planned` Topics and Saved Topics paint their table themselves and skip the base's repaint.

#### Found in 1.3, not fixed
- [ ] `planned` The composer's "Message" placeholder stays shifted after a long draft is cleared.
- [ ] `planned` The first `itglegacy://saved` after a cold launch does nothing; the second opens Saved Messages.
- [ ] `planned` The Russian pack shows "Кэш Кеш Мест…" on one storage row: two keys joined.
- [ ] `planned` The group call and the video player write `00:07`; every other clock writes `0:07`.
- [ ] `planned` The Calls and Forwarded Messages privacy pages have no help text: the pack has no sentence for them. Find the official keys or leave them empty on purpose.
- [ ] `planned` The Lottie renderer has no trim paths, merge paths or precomps: 14 of 31 `.tgs` files on the bench phone keep their still. Trim paths alone bring 8 back (M38).

#### Not checked on a device
- [ ] `planned` 26 of the 27 `UILabel` background fixes.
- [ ] `planned` The passcode after the Keychain access-group fix; an incoming message with the chat open; a live call; an account switch.
- [ ] `planned` A chat opened on return from the background once stayed empty.
- [ ] `planned` The dev component gallery is killed for memory at about 39 MB on the iPod touch 4.
- [ ] `planned` Dragging chat folders (the row mapping is tested, the drag was not); swiping between profile photos in the viewer; the new privacy help texts.

### Milestones to choose from

The open milestones of `docs/ROADMAP.md`, in the order the roadmap gives. 1.4 takes the ones picked here; the rest stay on the roadmap.

| Milestone | State | Left |
|---|---|---|
| M20 Payments, Stars and gifts | `planned` | Pay path, Premium purchase, Stars, gifts, TON, Passport, StoreKit |
| M21 Group-call audio | `planned` | RTP mixing and AudioUnit playback in the group-call screen |
| M22 Video calls | `partial` | Dev-only engine; picture to an official client, release gate |
| M25 Story rings | `planned` | Ring on every row and profile avatar, own-story tile |
| M26 Chat search filters | `planned` | Sender, media and date chips, result opens the hit, search tokens |
| M28 Profile cover, QR and Premium badge | `partial` | Accent gradient, background emoji, star badge, rating |
| M29 Profile media tabs | `partial` | GIF and Polls panes, photo/video split, month sections, calendar, counts |
| M30 Settings search | `planned` | A page index and a search field over every Settings row |
| M31 Notification pages | `partial` | Permission warning, badge settings, exception editing |
| M32 Contacts invite and import | `planned` | Invite Friends, address-book permission, phone-book import |
| M33 Localisation | `partial` | 170 strings with no official match, gender forms, `native_name` |
| M35 Message actions still missing | `planned` | Poll creation, copy in multi-select, forward with caption, reply quote, pinned list |
| M36 Group administration and channel tools | `partial` | Admin rights editor, invite-link detail, removed users, statistics graphs |
| M37 Settings and appearance detail | `partial` | Privacy exception lists, storage maximum, theme thumbnails, background colours |
| M38 Media polish | `partial` | Live photos, scrub preview, Lottie mattes and trim paths, sticker keyword search |
| M39 Stories after the strip | `partial` | Camera video, reply/share/repost, live stories, comments |
| M40 Bots and mini apps | `planned` | Inline mode, Web App host, bot commands, game scores |
| M41 Dark theme | `partial` | A device pass over every screen in the dark theme |
| M43 Platform delivery and device coverage | `partial` | 4-inch check, background fetch, crash reporting |
| M44 Message detail and unread TDLib fields | `partial` | Rich-message blocks, view/forward counts, service-action buttons |
| M45 Updates, changelog and usage | `partial` | Usage counts by version and device |
