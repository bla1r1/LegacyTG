## Release 1.3: Unified Message Core & Essential Gaps

Status: `complete`; Phases 1–5 done. Phase 5 (iOS 6.1 UI runtime parity & smoke gate) closed: 2366 host tests passing, binary selector audit green, 4-phase device smoke implemented.

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
- [x] `done` `TGChatListStoreTests` covers compact counts, folder tag mapping, the row-model keys and the group typing sender; `make -f tests/Makefile test` is 2,313 passed, 0 failed.
- [x] `done` `TGSearchStore` owns the search screen; `TGSearchViewController` no longer imports `TGClient` and the ChatList allow entries are gone.


### Off-plan: Profile store (done)
- [x] `done` `TGProfileStore` owns the Profile feature's 92 methods: profile/full-info reads, edit name/bio/birthday/username, photos, emoji status, audio, appearance, gifts, media tabs, blocks and chat actions.
- [x] `done` All 148 `TGClient` calls in 15 Profile files moved behind the store; `src/Features/Profile` no longer mentions the client.
- [x] `done` `TGProfileSupport.h` carries the two C helpers the screens still share (`TGFirstUsername`, `TGMediaPageAppending`).
- [x] `done` `TGProfileStoreTests` covers properties, `setBio`, blocking and accent ids; `make -f tests/Makefile test` is 2,313 passed, 0 failed.
- [x] `done` Request bodies for edit/photo/audio/action methods moved into `TGProfileStore` and its categories. Only `send:`, `request:` and the `supergroupIdForChat:` helper remain in the store.


### Off-plan: media store and M23 picker (done)
- [x] `done` `TGMediaStore` owns file facts, local deletion, Downloads registration, cancel and the 16 MB decoded-buffer cache (32 MB on 64-bit). `TGStickerStore+Stickers.m` owns the sticker shelf and authoring bodies; Media feature allow-list is empty.
- [x] `done` M23 file and music picker: `UIDocumentPicker` on iOS 8+, `MPMediaPickerController` with .m4a export, both sending through `TGSendStore`; GIF caption and view-once timer choices included.
- [x] `done` `TGSendStore` owns `inputMessageDocument` and `inputMessageAudio` shapes; `TGFileInfoViewController` and the media viewer save/add-download paths use `TGMediaStore`.
- [x] `done` `make -f tests/Makefile test`: 2,313 passed, 0 failed.
- [x] `done` M23 remainder: `TGMusicStreamer` streams the growing file through `AudioFileStream`/`AudioQueue`; `TGSendStore` silent sends and `TGMessageStore scheduledAtDate:repeatPeriod:` are wired through `messageSendOptions`.
- [x] `done` Store headers are UIKit-free (`UIImage`/`UIColor` are opaque `id`), `TGChatThemeStore` no longer imports a view (the UI installs a `.tgs` renderer), and `scripts/lint_layers.sh` enforces the dependency direction; the Client -> Store cycle is gone and the store headers are UIKit-free.
- [x] `done` `TGTransport` is the single TDLib boundary (libtdjson loading, receive loop, outbox, `@extra`); `TGClient` keeps caches, auth state and update routing and forwards transport calls. Tests use transport hooks instead of touching TDLib symbols.
- [x] `done` `make -f tests/Makefile corekit` links Client + Stores without any feature screen and runs a headless send, proving the domain layer is usable without the app UI.
- [x] `done` `TGStarsStore` owns the stars, gifts, ads, boosts, affiliate and Premium request bodies; Auth routes through `TGAccountStore`. The allow list is now **0** (8 -> 0).
- [x] `done` `TGCallStore` and `TGStoryStore` own the group-call and story request bodies; all 16 Calls/Stories allow-list entries are gone (24 -> 8).
- [x] `done` `TGSettingsStore`, `TGSessionsStore`, `TGAccountStore` and `TGTextStylesStore` own the settings, sessions, account and text-style request bodies; all 14 Settings allow-list entries and TGClient in the Settings category files are gone (38 -> 24).
- [x] `done` `TGBusinessStore` owns the business profile, links, away/greeting/hours and business-message requests; the 9 Business allow-list entries are gone (47 -> 38).
- [x] `done` `TGContactsStore`, `TGChannelStore` and `TGDevStore` own the contacts, similar-channels and developer-tool request bodies; 11 allow-list entries removed (58 -> 47).
- [x] `done` `TGGroupStore` owns the group request bodies (`+Groups`, `+Topics`, `+Invites`, `+Usernames`, `+Community`, `+Tools`); all 19 `src/Features/Groups` allow-list entries are gone, the list is down to 58 files, and `TGGroupStoreTests` checks the request shapes.

### Phase 2: Attachment pipeline and file cache (`TGMediaStore`) — done
- [x] `done` `TGChatViewController+Attachments.m` and `TGChatViewDocumentDelegate.m` reach files through `TGMediaStore`; neither imports `TGClient`.
- [x] `done` `TGMediaStore` caps decoded buffers at 16 MB on 32-bit, 32 MB on 64-bit (`TGMediaStore.m:22`).
- [x] `done` M23 document and audio pickers send `inputMessageDocument` / `inputMessageAudio` through `TGSendStore`.
- [x] `done` The allow list is 0: no `src/Features` file imports `TGClient`.

### Phase 3: History stream and pagination (`TGMessageStreamStore`) — done
- [x] `done` `loadOlderInChat:limit:completion:` and `loadNewerInChat:limit:completion:` own the history request, the duplicate filter, the `loadingOlder/Newer` and `reachedStart/End` flags. `TGChatViewPagination.m` only keeps the table offset around the inserted rows.
- [x] `done` `TGMessageStreamStore.mm` keeps a `std::vector<TGFlattenedMessage>` index beside the dictionaries and a `std::unordered_set<int64_t>` of ids, so bounds, de-duplication and the scalar accessors do not touch `NSDictionary`.
- [x] `done` `TGMessagesChangedNotification` is posted by `TGUpdateRouter` once per 100 ms batch; `TGMessageStore` reposts it as `TGMessageStoreChangedNotification`, and the chat observes it and reloads the coalesced rows.

### Phase 4: Chat-list integration (`TGChatListStore`) — done
- [x] `done` `src/Features/ChatList` talks to `TGChatListStore`/`TGSearchStore`; no file imports `TGClient` (allow-list 0).
- [x] `done` M24 is done: content-type glyphs and thumbnails, compact `99+` counts, reaction/poll/folder badges and the Chats-tab badge.

### Phase 5: iOS 6.1 UI runtime parity and release smoke gate — done
- [x] `done` Static Clang API availability gate: `-Wunguarded-availability` added to `CFLAGS_ARMV7` and `CFLAGS_ARM64` in `Makefile`; `CFLAGS_ARMV7_EXTRA` passthrough slot added for `check_release.sh`.
  Ensures any iOS 7.0+ method (`sectionIndexBackgroundColor:`, `barTintColor:`, `interactivePopGestureRecognizer`, `edgesForExtendedLayout`) without an explicit guard triggers a build error instead of shipping to release.
- [x] `done` Audit and isolate grouped selector guards in `src/Core/Style` and `src/UI`.
  `barTintColor` in `-styleNavigationBar:` was the one ungated call in the iOS 7+ else-branch; fixed to `if ([bar respondsToSelector:@selector(setBarTintColor:)])`. Each of the three `UITableView` section-index selectors has its own independent guard.
- [x] `done` Host unit tests: `tests/TGThemeIOS6Tests.m` — 12 tests.
  NSProxy-based `TGIos6Proxy` wraps every component; `respondsToSelector:` returns NO for all 8 dangerous iOS 7+ selectors. Mock objects (`TGMockTable6`, `TGMockNavBar6`, `TGMockSearchBar6`, `TGMockTabBar6`) simulate real iOS 6 guard behaviour. 12 test methods cover sectionIndex triplet isolation, navBar/searchBar/tabBar dark+light paths, proxy blocking, exception type, and end-to-end iOS 6 simulation.
- [x] `done` Deep device smoke in `scripts/devrun.sh` (`--smoke`): 4-phase interactive run.
  Phase 1 cold launch → Phase 2 light-theme screen walk (`/`, `/settings`, `/profile`) → Phase 3 dark-theme switch + re-navigate → Phase 4 Dev Showcase 30-row scroll + Saved Messages. `NSInvalidArgumentException` added to crash pattern; crash report pulled from device on failure.
- [x] `done` Binary selector audit in `scripts/check_release.sh` (gate 2 of 3).
  `otool` extracts `__objc_methname` from the armv7 slice via `lipo -thin`; for each of 8 dangerous selectors found in the binary, grep verifies every call site in `src/` is within 5 lines of a `respondsToSelector:` guard. Script exits 1 on the first unguarded hit.
- [x] `done` Pre-release availability gate in `scripts/check_release.sh` (gate 1 of 3).
  Clean `-Werror=unguarded-availability` armv7 compile required; dev-symbol absence check is gate 3.
- [x] `done` Regression: `make -f tests/Makefile test` — **2366 passed, 0 failed** (2354 prior + 12 new TGThemeIOS6Tests).

**Blocked by:** nothing. Pure toolchain and test runner hardening.

**Closes:** M27 (Failed-send mark) — `chat.md` failed delivery mark and
`chat-list.md` delivery ticks. M23 and M24 are closed (Phases 2 and 4). iOS 6.1 runtime crashes (B1/theme guards) closed by Phase 5.
