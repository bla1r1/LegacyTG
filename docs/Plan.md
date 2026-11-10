## Release 1.3: Unified Message Core & Essential Gaps

Status: `planned`.

Consolidates the 351 direct `TGClient` calls across `src/Features/Chat` into domain stores (`TGSendStore`, `TGMessageStreamStore`, `TGMediaStore`), enforces the 16 MB memory ceiling on 32-bit devices, and lands the top messaging gaps (M27, M23, M24) on top of the unified core.

### Phase 1: Outbound message lifecycle and retry (`TGSendStore`)
- [ ] `planned` Extract `sendMessage`, `editMessageText`, `deleteMessages` and transient send state tracking from `TGChatViewController+Input.m` and `TGChatActionsHoldMenu.m` into `TGSendStore`.
- [ ] `planned` Track pending outbound messages, state transitions (`sending` -> `sent` / `failed`), and failure causes in a single C++ state table.
- [ ] `planned` Wire M27: failed delivery mark on bubbles and rows, one-tap retry invoking `[TGSendStore retryMessageId:]`.
- [ ] `planned` Drop `TGChatViewController+Input.m` from `scripts/lint_client.sh` allow list.

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

**Closes:** `lint_client.sh` Chat allow entries; M27 (Failed-send mark), M23 (Sending files, music), M24 (Chat-list previews and badges).
