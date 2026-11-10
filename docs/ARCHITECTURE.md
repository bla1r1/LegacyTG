# Layers

TDLib speaks JSON updates. `TGClient` owns that socket and keeps the caches:
users by id, chats by id, photo file ids, stories, folders.

Screens do not read those caches. `src/Core/Stores` is the layer between them:

```
TDLib -> TGClient -> TGPeerStore / TGStickerStore / TGMediaStore / TGUpdateStore / TGSendStore / TGMessageStore -> screens
```

`TGClient+Peers` is the small seam `TGPeerStore` reads through; it is not a
screen header.

`TGSendStore` owns outbound messages and their `sending -> sent / failed`
state. `TGMessageStore` is the rest of the Chat message surface: actions,
history, tools and the chat callbacks. `TGMessageStore+History.m` owns the
history requests and page flattening. Both stores write their methods out
explicitly; the message send/action/history bodies live there, and the
remaining chat-tool, topic and cache methods delegate to `TGClient`. A Chat
screen imports those headers and never a `TGClient` header.

# What a store owns

A store owns the state and the rules for one domain, and its header is the
whole list of what a screen may ask. `TGPeerStore` owns the immutable `TGPeer`
record (title, initials, username, verified, emoji status, presence, member
count) and the avatar cache. A picture is fetched once per file id, decoded off
the main thread, rounded once, and kept in `TGImageLruCache` (120 entries) so a
scrolling member list does not start a download per row. `reset` drops that
cache when the account changes.

# How a screen subscribes

A screen asks `TGPeerStore` for records and pictures. For changes it observes
`TGPeerStoreChangedNotification` on the main queue and reads
`userInfo[@"ids"]`. Updates are collected and posted once per ~100 ms, so an
update burst is one notification with every changed id, not one hop per TDLib
event. A screen re-reads the peers it draws; it does not patch records itself.

# Lints that hold the line

- `scripts/lint_client.sh` fails when a file under `src/Features` or `src/UI`
  imports `TGClient.h` or a `TGClient+*.h`, unless the file is in its allow
  list. The list only shrinks: a listed file that no longer imports the client
  is also an error.
- `scripts/lint_rows.sh` keeps cells in `src/UI/Rows`; a migrated screen leaves
  its allow entry.
- `scripts/lint_tokens.sh` keeps sizes and colours in `TGStyle` / `TGTheme`.
- `scripts/lint_size.sh` fails above 1800 lines.

# The remaining domains

1. Messages: the Chat feature now talks only to `TGSendStore` and
   `TGMessageStore`. What remains inside those stores is the transport body of
   each request and the history/pagination math; the boundary itself is done.
2. Settings: account, privacy, notifications and appearance. These are mostly
   request-write screens, so the store is a narrow command surface.
3. Calls: call state and group-call participants, the last domain because the
   call screen keeps its current design on purpose.

Order matters because messages feed the chat list and chats feed people; a
settings or call store can land without touching either.

# Counts at the end of this step

- `src/Features/Chat` files importing `TGClient*`: 0 (was 345 direct
  `[TGClient shared]` calls across 38 files).
- `scripts/lint_client.sh` allow list: 98 files (was 122); all 23 Chat entries
  are gone.
- `TGMessageStore.h`: 227 selectors and 14 properties, the whole surface the
  Chat feature actually asks for.
