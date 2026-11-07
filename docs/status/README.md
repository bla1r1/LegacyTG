# LegacyTG status, area by area

Audit of 7 November 2026 against `src/` at `1450576`. Each area file has one row per feature with the official behaviour, the state here (`done`, `partial`, `missing`, `dev-only`) and the `file:line` that was checked. A missing feature has `—` in the Where column.

## Areas

- [chat-list](chat-list.md) — 30 done, 16 partial, 22 missing, 0 dev-only. List engine, rows, badges, folders, archive, stories strip and search.
- [chat](chat.md) — 54 done, 16 partial, 21 missing, 0 dev-only. History, bubbles, composer, message actions, search, scheduling and bot controls.
- [message-types](message-types.md) — 86 done, 26 partial, 8 missing, 0 dev-only. Every `MessageContent` type and the content features the parity audit names.
- [profile](profile.md) — 45 done, 32 partial, 29 missing, 0 dev-only. User, group and channel profiles, media panes and editing.
- [groups](groups.md) — 48 done, 29 partial, 11 missing, 0 dev-only. Members, permissions, invite links, topics and group calls.
- [channels](channels.md) — 34 done, 13 partial, 8 missing, 1 dev-only. Posting, admin surface, comments, views, signatures and statistics.
- [contacts](contacts.md) — 18 done, 15 partial, 11 missing, 0 dev-only. The contact list, adding people and the call list that shares the tab.
- [calls](calls.md) — 41 done, 4 partial, 6 missing, 5 dev-only. 1:1 audio, recent calls, group calls and video chats.
- [stories](stories.md) — 21 done, 5 partial, 8 missing, 1 dev-only. Strip, viewer, posting, albums, interactions and live stories.
- [media](media.md) — 19 done, 8 partial, 7 missing, 0 dev-only. Viewer, players, downloads, attachments and stickers.
- [settings](settings.md) — 11 done, 47 partial, 25 missing, 1 dev-only. Every Settings page, the Appearance controls and the shared design tokens.
- [privacy-security](privacy-security.md) — 34 done, 29 partial, 19 missing, 0 dev-only. Passcode, two-step, sessions, blocked users, visibility rules, storage and network.
- [notifications](notifications.md) — 8 done, 6 partial, 11 missing, 1 dev-only. Scopes, exceptions, sounds, the Active list and push.
- [login-accounts](login-accounts.md) — 25 done, 4 partial, 0 missing, 2 dev-only. Every auth step, account slots, sessions and websites.
- [bots-payments](bots-payments.md) — 2 done, 8 partial, 19 missing, 7 dev-only. Bots, invoices, Stars, gifts, boosts and the wallet surfaces.

Totals: 476 done, 258 partial, 205 missing, 18 dev-only across 957 rows.

## Top 15 missing

Ranked by how often an ordinary user would hit it: chat and chat list first, then profile, media, then settings.

1. **Send a file or a music track** — the attach sheet has no document or audio picker and no `inputMessageDocument` request. `chat`, `media`.
2. **Custom emoji cannot be sent, picked or animated** — the composer drops the id, the panel has no custom-emoji tab, and text shows a still picture. `chat`, `media`, `message-types`.
3. **Chat-list previews and badges** — no reaction badge, no poll-vote badge, no compact counts, no photo/video thumbnail and no type glyph. `chat-list`.
4. **No unread badge on the Chats tab** — the root tab bar has no `badgeValue` update. `chat-list`.
5. **No story ring on chat rows or profile avatars** — only the strip bubble has a ring. `chat-list`, `stories`, `profile`.
6. **Chat search cannot filter or jump** — text-only query, no sender/media/date chips, results replace the feed and do not open the hit. `chat`.
7. **A failed send has no failed mark** — the bubble keeps ticks and only the hold menu offers Retry. `chat`.
8. **Profile has no cover, QR code or Premium badge** — the accent gradient, own-profile QR and star are not drawn. `profile`.
9. **Profile media has no GIF or Polls tab, month sections or calendar** — one flat photo grid. `profile`, `media`.
10. **No search in Settings** — there is no field or page index. `settings`.
11. **No Night theme or Auto-Night** — the app is light-only by decision, and the Appearance page has no switch. `settings`.
12. **Notifications have no category pages, in-app banner, permission warning or badge settings** — scopes are three switches and preview cards. `notifications`.
13. **No payment path** — invoice Pay, paid-media unlock, Premium purchase, Stars top-up, sending gifts and TON are absent. `bots-payments`.
14. **Group calls have no audio; video calls are dev-only** — the screens, participants and RTMP exist; the media engine does not. `calls`, `groups`.
15. **Contacts has no Invite Friends and no phone-book import** — only `importedContactCount` is read, for the footer. `contacts`.
