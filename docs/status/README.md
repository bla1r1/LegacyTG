# LegacyTG status

Audit of 7 November 2026 against `src/` at `1450576`. One row per feature: state
here (`done`, `partial`, `missing`, `dev-only`), the `file:line` that was checked
and a note on what works or what is absent. A missing feature has `—` in the
Where column.

| File | Area |
|---|---|
| [chat-list](chat-list.md) | List engine, rows, badges, folders, archive, stories strip, search |
| [chat](chat.md) | History, bubbles, composer, actions, search, scheduling, bot controls |
| [message-types](message-types.md) | Every `MessageContent` type and the content features the parity audit names |
| [profile](profile.md) | User, group and channel profiles, media panes, editing |
| [groups](groups.md) | Members, permissions, invite links, topics, group calls, administration |
| [channels](channels.md) | Posting, admin surface, comments, views, signatures, statistics |
| [contacts](contacts.md) | Contacts, adding people, the shared call list |
| [calls](calls.md) | 1:1 audio, recent calls, group calls, video chats, tgcalls wire notes |
| [stories](stories.md) | Strip, viewer, posting, albums, interactions, live stories |
| [media](media.md) | Viewer, players, downloads, attachments, stickers |
| [settings](settings.md) | Settings pages, appearance, design tokens |
| [privacy-security](privacy-security.md) | Passcode, two-step, sessions, blocked users, visibility, storage, network |
| [notifications](notifications.md) | Scopes, exceptions, sounds, Active list, push |
| [login-accounts](login-accounts.md) | Auth steps, account slots, sessions, websites |
| [bots-payments](bots-payments.md) | Bots, invoices, Stars, gifts, boosts, wallet |
| [checks.md](checks.md) | Device checks: tap, see, wait, log |
| [bugs.md](bugs.md) | Closed bug queue, B1 onwards |

Totals: 476 done, 258 partial, 205 missing, 18 dev-only across 957 rows.

## Milestones

M1–M19 closed; M20–M44 open, in the order they are meant to be taken. Counts per
area are in each file's header.

| Milestone | State | What it is | Blocked by |
|---|---|---|---|
| M1 Build and TDLib bridge | done | armv7 Makefile, TDLib submodule, `libtdjson.dylib` split, `tools/machofix.c`, opus | — |
| M2 Login and accounts | done | Phone, code, 2FA, email, QR, sign-up, recovery, three account slots | — |
| M3 Chat list | done | Snapshot first paint, 12 `loadChats` retries, live re-sort, archive, folders, bulk actions | — |
| M4 Chat core | done | Paged history, bubbles, reply/forward/edit/delete, drafts, pins, reactions, scheduled sends | — |
| M5 Media and files | done | Viewer, video/GIF, document preview, camera roll, downloads, file info | — |
| M6 Stickers and GIFs | done | WebP, TGS Lottie, WebM VP9, packs, favourites, editor, custom emoji packs | — |
| M7 Groups, forums and channels | done | Member actions, permissions, invite links, topics, comments, send-as | — |
| M8 Voice and video notes | done | Opus record/play, waveform, speed, round video recorder | — |
| M9 Themes, icons and tokens | done | UIKit chrome on every iOS, procedural SVG icons, `TGStyle`, `TGTheme+Colours` | — |
| M10 Search | done | In-chat text search, global search, local-first results | — |
| M11 Stories | done | 48 story functions on screens: strip, viewer, posting, albums, archive | — |
| M12 Profiles and contacts | done | Profiles, own profile, editing, media panes, contacts | — |
| M13 1:1 calls | done | tgcalls 9.0.0 signalling and media, VoiceProcessingIO, call screen | — |
| M14 Settings and privacy | done | Settings tree, passcode, two-step, sessions, blocked users, storage | — |
| M15 Notifications and push | done | Scopes, previews, exceptions, sounds, `registerDevice`, push routing | APNs certificate for the official bundle ID |
| M16 Message types, cards and veils | done | Service sentences, previews, cards, veils, rebuilt polls | — |
| M17 Custom emoji | done | Custom emoji in composer, picker, reactions, names, sticker pipeline | — |
| M18 Device tiers, delivery and iOS 6 | done | Tier gates, This Device, `devrun.sh`, `TG_DEV` fence, iOS 6 fixes | — |
| M19 Performance and C/C++ migration | done | yyjson, streaming Opus, vector Lottie, update coalescing, controller split | — |
| M20 Payments, Stars and gifts | planned | Checkout, Premium, Stars, gifts, TON, Passport, StoreKit | No App Store receipt or payment provider for this bundle ID |
| M21 Group-call audio | planned | RTP mixing, AudioUnit playback, recording in `TGGroupCallViewController` | No armv7 WebRTC/C++17 build; iOS 7 has no VideoToolbox encoder |
| M22 Video calls | partial | Dev-only engine; picture to an official client, release gate | No second-party test; same WebRTC stack limit |
| M23 Sending files, music and options | planned | Document/audio picker, streaming, silent and repeated sends, GIF caption | Nothing beyond screen work |
| M24 Chat-list previews and badges | planned | Thumbnails, type glyph, reaction/poll badges, compact counts, tab badge, folder tags | Row model lacks `unreadPollVotes`, `chat_lists`, story state |
| M25 Story rings | planned | Ring on every row and profile avatar, own-story tile | No shared ring view |
| M26 Chat search filters | planned | Sender/media/date chips, result opens the hit, search tokens, global scopes | `TGSearchViewController` has no result-to-message route |
| M27 Failed-send mark | planned | Failed icon in bubble and row, retry without the hold menu | Cell reads only sent/read state |
| M28 Profile cover, QR, Premium | planned | Accent gradient, background emoji, QR screen, star badge, rating, verifier note | Header layout; no QR generator |
| M29 Profile media tabs | planned | GIF/Polls panes, photo/video split, month sections, calendar, multi-select | `TGProfileTabs` has no kind for either filter; flat grid |
| M30 Settings search | planned | Page index and search field over every Settings row | None; tree is built in code with no registry |
| M31 Notification pages | planned | Category pages, in-app banner, permission warning, badge settings | Notification screen has no model beyond switches |
| M32 Contacts invite and import | planned | Invite Friends, contacts permission, phone-book import, formatted add | App never asks for contacts permission |
| M33 Localisation | planned | About 2200 hard-coded English strings, plural and gender forms | Literal English everywhere; no key table |
| M34 Developer talk on the user's path | partial | Error table for 157 alerts, harness pages behind `TG_DEV`, footers | Harness screens are the only route to their TDLib calls |
| M35 Message actions still missing | planned | Poll creation, copy in multi-select, forward with caption, share to topic, reply quote | Core wrappers do not expose the request shapes |
| M36 Group admin and channel tools | partial | Admin rights editor, invite-link detail, removed users, statistics graphs, boosts | Flat 100-event list; TDLib returns the data |
| M37 Settings and appearance detail | partial | Privacy exceptions, storage maximum, theme thumbnails, background colour/gradient | One light palette; no background editor |
| M38 Media polish | partial | Live photos, scrub preview, music streaming, Lottie mattes, keyword search, link preview | Decoder and layout work; no new TDLib call |
| M39 Stories after the strip | partial | Camera video, reply/share/repost, live playback and hosting, comments | Same media stack as M21; camera movie output |
| M40 Bots and mini apps | planned | Inline mode, Web App host, commands, guest bots, game scores, web-app buttons | Web Apps need a browser view this target does not carry |
| M41 Dark theme | deferred | Night and Auto-Night removed; the app is light-only by decision | Design decision |
| M42 Landscape and iPad | deferred | Portrait iPhone layout only | No design for either size class |
| M43 Platform delivery | partial | iOS 6 run, 4-inch check, background fetch, crash reporting, arm64 TDLib | Bench hardware; second architecture in TDLib |
| M44 Message detail and unread fields | partial | Rich-message blocks, signature, view/forward counts, gift counts, action buttons | Flatten model drops fields or bubble has no slot |

## Top gaps

Ranked by how often an ordinary user hits it: chat and chat list first, then
profile, media, then settings. Each line names the status area that holds the row.

1. **Send a file or a music track** — no document/audio picker, no `inputMessageDocument`. `chat`, `media`.
2. **Custom emoji are not everywhere** — composer and panel yes; animation on a 4S unchecked, member rows draw no status emoji. `chat`, `media`, `message-types`.
3. **Chat-list previews and badges** — no reaction or poll badge, compact counts, thumbnail or type glyph. `chat-list`.
4. **No unread badge on the Chats tab** — root tab bar has no `badgeValue` update. `chat-list`.
5. **No story ring on chat rows or profile avatars** — only the strip bubble has a ring. `chat-list`, `stories`, `profile`.
6. **Chat search cannot filter or jump** — text-only query, results replace the feed and do not open the hit. `chat`.
7. **A failed send has no failed mark** — the bubble keeps ticks; Retry is in the hold menu only. `chat`.
8. **Profile has no cover, QR code or Premium badge.** `profile`.
9. **Profile media has no GIF or Polls tab, sections or calendar** — one flat grid. `profile`, `media`.
10. **No search in Settings.** `settings`.
11. **No Night theme or Auto-Night** — light-only by decision. `settings`.
12. **Notifications have no category pages, banner or badge settings.** `notifications`.
13. **No payment path** — invoice Pay, paid media, Premium, Stars, gifts, TON absent. `bots-payments`.
14. **Group calls have no audio; video calls are dev-only.** `calls`, `groups`.
15. **No Invite Friends and no phone-book import.** `contacts`.

## TDLib coverage

Counted from string literals in `src/`; updates from `src/Core/Support/TGUpdateType.h`.
Anything outside that list is dropped in the receive loop before a Foundation
tree exists, so a dropped update leaves no trace in the log. Both numbers are
floors. As of 2026-11-01: 1076 functions declared, 972 covered (90%), 104 out of
scope; 197 updates, 136 covered (69%), 61 out of scope.

```sh
sh scripts/tdlib_coverage.sh            # counts and gap by area
sh scripts/tdlib_coverage.sh --relevant # missing functions worth having
sh scripts/tdlib_coverage.sh --bare     # called names with no caller
sh scripts/tdlib_coverage.sh --updates  # updates the receive loop drops
python3 scripts/tdlib_tiers.py --tier3  # skipped, and never for this client
```
