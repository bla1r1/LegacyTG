# Layers

See [ARCHITECTURE_CORE.md](ARCHITECTURE_CORE.md) for the current core diagram.

TDLib speaks JSON updates. `TGTransport` owns the socket and the receive loop;
`TGClient`, `TGUpdateRouter`, `TGUpdateHandlers` and `TGState` turn those
updates into the caches and notifications the stores read.

Screens do not read those caches. `src/Core/Stores` is the layer between them:

```
TDLib -> TGClient -> TGPeerStore / TGStickerStore / TGMediaStore / TGUpdateStore / TGSendStore / TGMessageStore / TGChatListStore / TGSearchStore / TGProfileStore / TGGroupStore / TGContactsStore / TGChannelStore / TGDevStore / TGBusinessStore / TGCallStore / TGStoryStore / TGStarsStore -> screens
```

`TGClient+Peers` is the small seam `TGPeerStore` reads through; it is not a
screen header.

`TGSendStore` owns outbound messages and their `sending -> sent / failed`
state. `TGMessageStore` is the rest of the Chat message surface: actions,
history, tools and the chat callbacks. `TGMessageStore+History.m` owns the
history requests and page flattening. `TGChatListStore` owns the list data,
folders, unread total, tab badge and the M24 preview/row facts; `TGSearchStore`
owns the search screen; `TGProfileStore` owns the profile, edit, photo, emoji-status and appearance surfaces; `TGGroupStore` owns members, invites, forum topics, permissions, usernames, communities, welcomes and import. The categories hold the request bodies, with only `send:`/`request:` left as transport. All stores write their methods out
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
2. Groups: `TGGroupStore` now owns members, invites, forum topics,
   permissions, usernames, communities, welcomes and import. All 19 Groups
   allow-list entries are gone; only `send:`/`request:` remain as transport.
3. Settings: account, privacy, notifications and appearance. These are mostly
   request-write screens, so the store is a narrow command surface.
4. Calls: call state and group-call participants, the last domain because the
   call screen keeps its current design on purpose.

Order matters because messages feed the chat list and chats feed people; a
settings or call store can land without touching either.

# Counts at the end of this step

- `src/Features/Chat` files importing `TGClient*`: 0 (was 345 direct
  `[TGClient shared]` calls across 38 files).
- `scripts/lint_layers.sh` enforces the direction
  `Features/UI -> Stores -> Client -> TDLib`: screens never import the client,
  Core never imports a view, store headers import no UIKit/AVFoundation/
  MediaPlayer, stores never import a feature screen, and the client never
  imports a store. The old Client->Store forwarders are gone.
- `Core/Client/TGTransport.m` is the only file that loads libtdjson and calls
  `td_json_client_*`: one client, one receive thread, outbox and `@extra`
  correlation.
- `Core/Client/TGUpdateRouter.m` decides what an incoming object is: a request
  reply goes to its completion, a real update is batched on the main queue and
  handed to `TGClient.handleUpdate:`, with the 100 ms coalescer owned here.
- `Core/Client/TGUpdateHandlers.m` owns the whole `update*` switch (authorization,
  users, chats, messages, files, stories, calls, business, stars). `TGClient`
  keeps only the dispatcher and its caches accessors.
- `Core/Client/TGState.m` owns the account caches (chats, users, photos,
  communities, folders, quick replies, checklists, revenue, saved topics).
  `TGClient` keeps forwarding accessors so the update handlers and categories
  read one shared state object.
- `Core/Client/TGAccountSession.m` owns `authState`, the auth facts
  (code/password/email/QR/phone) and the background close/restart state
  machine. Close and restart are two blocks installed by `TGClient`.
- `TGClient` keeps the caches and the update handlers; it forwards transport,
  routing and session calls to the modules above.
- `make -f tests/Makefile corekit` links the client and stores as a headless
  macOS binary with no feature screen. It sends one text request and prints the
  resulting `sendMessage` shape; this is the CoreKit smoke test for a second UI.
- `scripts/lint_client.sh` allow list: 0 files (was 122). Every Feature and UI
  file now goes through a store, including Chat, ChatList, Profile, Groups,
  Settings, Media, Contacts, Channels, Dev, Business, Calls, Stories, Auth and
  BotsPayments.
- `TGMessageStore.h`: 227 selectors and 14 properties, the whole surface the
  Chat feature actually asks for.
