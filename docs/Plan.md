## Release 1.3: Unified Message Core & Essential Gaps

Status: `in progress`; Phase 1 done, plus the whole Chat message boundary (off-plan).

Consolidates the 351 direct `TGClient` calls across `src/Features/Chat` into domain stores (`TGSendStore`, `TGMessageStreamStore`, `TGMediaStore`), enforces the 16 MB memory ceiling on 32-bit devices, and lands the top messaging gaps (M27, M23, M24) on top of the unified core.

### Phase 1: Outbound message lifecycle and retry (`TGSendStore`) — done
- [x] `done` Extract `sendMessage`, `editMessageText`, `deleteMessages` and transient send state tracking from `TGChatViewController+Input.m` and `TGChatActionsHoldMenu.m` into `TGSendStore`.
  `TGSendStore.h` is the plain Objective-C surface; `TGSendStore.mm` owns the request shapes and the state table. Input sends/edits through it, the hold menu's Retry and the selection delete path call it too.
- [x] `done` Track pending outbound messages, state transitions (`sending` -> `sent` / `failed`), and failure causes in a single C++ state table.
  Keyed by `(chatId, messageId)`, capped at 256 records; `TGClient` reposts `updateMessageSendSucceeded/Failed` as `TGMessageSendStateChangedNotification`, the store publishes `TGSendStoreMessageStateChangedNotification` with the reason and `canRetry`.
- [x] `done` Wire M27: failed delivery mark on bubbles and rows, one-tap retry invoking `[TGSendStore retryMessageId:]`.
  Error glyph in the bubble and the chat-list row; tap on a failed bubble resends. History pages seed the table through `adoptMessages:inChat:`.
- [x] `done` Drop `TGChatViewController+Input.m` from `scripts/lint_client.sh` allow list.
  The file was not on the list at HEAD; checked `make -f tests/Makefile client` — clean.
- [x] `done` Regression tests: `tests/TGSendStoreTests.m` covers send -> failed -> retry -> sent, the update-level error fallback, delete, history adoption and scheduled sends.
  `make -f tests/Makefile test`: 2,239 passed, 0 failed.

Phase 1 itself moved only the outbound text path; the off-plan section below extends the same boundary to every message action in the Chat feature.

### Off-plan: whole Chat message boundary (done)
- [x] `done` Every `TGClient` reference under `src/Features/Chat` is gone: 345 direct calls across 38 files now go through `TGSendStore` (outbound) or `TGMessageStore` (everything else).
- [x] `done` `TGMessageStore.h` declares the selectors and properties the Chat feature actually uses; `TGMessageStore.m` and `TGMessageStore+History.m` write every method out explicitly (no runtime forwarding). Outbound media, voice/video notes, delete/resend/retry, the core message actions and history requests own their request bodies; chat tools, topic screens and cache accessors remain explicit store methods that delegate to the client.
- [x] `done` `scripts/lint_client.sh`: all 23 `src/Features/Chat` allow entries removed; the allow list is down to 98 files.
- [x] `done` `tests/TGMessageStoreTests.m` covers property forwarding, an action request, callback slots, class helpers and runtime `respondsToSelector:`.
- [x] `done` `make -f tests/Makefile test`: 2,245 passed, 0 failed. All 53 Chat translation units and both stores compile against the iOS SDK.
- [ ] `planned` The separate domains stay on the client for now: chat tools/settings, Saved Messages/DM topics, quick replies, link/media downloads and the name/title/emoji-status caches. They are no longer reached from a view, only from an explicit store method.


### Off-plan: chat list store and M24 (done)
- [x] `done` `TGChatListStore` owns the list data seam: chats, archive, folders, unread total, list callbacks, chat actions and story-list calls. Main `src/Features/ChatList` files import the store, not `TGClient`.
- [x] `done` M24 row facts: preview kind and thumbnail file, reaction/poll/folder trailing badge, compact `99+` counts, Chats-tab badge, typing sender, Saved Messages row, pinned tint and scalar stripping.
- [x] `done` `TGChatListStoreTests` covers compact counts, folder tag mapping, the row-model keys and the group typing sender; `make -f tests/Makefile test` is 2,271 passed, 0 failed.
- [x] `done` `TGSearchStore` owns the search screen; `TGSearchViewController` no longer imports `TGClient` and the ChatList allow entries are gone.


### Off-plan: Profile store (done)
- [x] `done` `TGProfileStore` owns the Profile feature's 92 methods: profile/full-info reads, edit name/bio/birthday/username, photos, emoji status, audio, appearance, gifts, media tabs, blocks and chat actions.
- [x] `done` All 148 `TGClient` calls in 15 Profile files moved behind the store; `src/Features/Profile` no longer mentions the client.
- [x] `done` `TGProfileSupport.h` carries the two C helpers the screens still share (`TGFirstUsername`, `TGMediaPageAppending`).
- [x] `done` `TGProfileStoreTests` covers properties, `setBio`, blocking and accent ids; `make -f tests/Makefile test` is 2,271 passed, 0 failed.
- [x] `done` Request bodies for edit/photo/audio/action methods moved into `TGProfileStore` and its categories. Only `send:`, `request:` and the `supergroupIdForChat:` helper remain in the store.


### Off-plan: media store and M23 picker (done)
- [x] `done` `TGMediaStore` owns file facts, local deletion, Downloads registration, cancel and the 16 MB decoded-buffer cache (32 MB on 64-bit). `TGStickerStore+Stickers.m` owns the sticker shelf and authoring bodies; Media feature allow-list is empty.
- [x] `done` M23 file and music picker: `UIDocumentPicker` on iOS 8+, `MPMediaPickerController` with .m4a export, both sending through `TGSendStore`; GIF caption and view-once timer choices included.
- [x] `done` `TGSendStore` owns `inputMessageDocument` and `inputMessageAudio` shapes; `TGFileInfoViewController` and the media viewer save/add-download paths use `TGMediaStore`.
- [x] `done` `make -f tests/Makefile test`: 2,271 passed, 0 failed.
- [x] `done` M23 remainder: `TGMusicStreamer` streams the growing file through `AudioFileStream`/`AudioQueue`; `TGSendStore` silent sends and `TGMessageStore scheduledAtDate:repeatPeriod:` are wired through `messageSendOptions`.
- [x] `done` `TGGroupStore` owns the group request bodies (`+Groups`, `+Topics`, `+Invites`, `+Usernames`, `+Community`, `+Tools`); all 19 `src/Features/Groups` allow-list entries are gone, the list is down to 58 files, and `TGGroupStoreTests` checks the request shapes.

### Phase 2: Attachment pipeline and file cache (`TGMediaStore`)
- [ ] `planned` Move all direct `downloadFile:` / `cancelDownloadFile:` invocations from `TGChatViewController+Attachments.m` and `TGChatViewDocumentDelegate.m` to `TGMediaStore`.
- [ ] `planned` Enforce strict 16 MB LRU eviction ceiling on 32-bit devices for media and document buffers.
- [ ] `planned` Wire M23: implement `inputMessageDocument` and `inputMessageAudio` in `TGSendStore` / `TGMediaStore`, connecting the system document/audio picker.
- [ ] `planned` Drop `TGChatViewController+Attachments.m` from `scripts/lint_client.sh` allow list.

### Phase 3: History stream and pagination (`TGMessageStreamStore`)
- [ ] `planned` Migrate paging, window offset math, and history loading from `TGChatViewData.m` and `TGChatViewPagination.m` into `TGMessageStreamStore`.
- [ ] `planned` Maintain deduplicated message indices in C++, eliminating intermediate `NSDictionary` allocations during scrolling.
- [ ] `planned` Screens observe coalesced `TGMessageStoreChangedNotification` batches.

### Phase 4: Chat-list integration (`TGChatListStore`)
- [ ] `planned` Decouple `src/Features/ChatList` (86 calls) from direct `TGClient` polling; consume cached store state.
- [ ] `planned` Wire M24: content-type glyphs, compact counts, reaction/poll badges, and update `badgeValue` on the root Chats tab.

**Blocked by:** nothing. Pure domain store contracts over existing TDLib methods.

**Closes:** M27 (Failed-send mark) — `chat.md` failed delivery mark and
`chat-list.md` delivery ticks. M23 and M24 close with Phases 2 and 4.
