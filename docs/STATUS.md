# LegacyTG Feature Status Matrix
Unified status of Telegram feature parity on legacy iOS (iOS 6.0–12.5.7).
States: `done` (matches official client), `partial` (partially implemented), `missing` (not yet implemented), `dev-only` (gated under `TG_DEV`).

### Overall Summary
- **Done:** 508
- **Partial:** 248
- **Missing:** 185
- **Dev-only:** 18
- **Total tracked features:** 959

---

## Chat List & Folders

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| First paint from a saved snapshot | `done` | ``Features/ChatList/TGChatListViewController.m`` | `loadChatSnapshot` draws the previous list before `loadChats` answers. |
| `loadChats` retry | `done` | ``Core/Client/Chats/TGClient+Chats.mm`` | Up to 12 attempts, then the cached list stays. |
| Live list update | `done` | ``src/Features/ChatList/Core/TGChatListLifecycle.m`` | `onChatsChanged` reloads and re-sorts using TDLib order. |
| Row count and title | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Header rows (Saved Messages, archive) plus visible chats. |
| Unread count badge | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Compact "99+"; muted chats use the muted colour. |
| Mention badge | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Separate "@" badge. |
| Blank badge for marked unread | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | A marked-read chat with zero messages shows an empty badge. |
| Reaction badge | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | `unreadReactions` and the last message reaction summary feed the compact trailing badge. |
| Poll-vote badge | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | `unreadPollVotes` and the poll total draw as "Poll · N". |
| Compact counts ("99+") | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | `TGChatListStore compactBadgeTextForCount:` caps at 99+. |
| Pinned mark beside a badge | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Pin and unread count both draw; geometry keeps them apart. |
| Pinned row tint | `done` | ``src/UI/Rows/TGChatRowCell.m`` | A pinned row keeps the card plate behind it; the theme repaint follows the row flag. |
| Muted speaker | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Mute icon after the title. |
| Online dot on the row | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Shown when the chat row says the peer is online. |
| Emoji status after the title | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Custom emoji picture, skipped for Saved Messages. |
| Verified and Premium marks beside the title | `partial` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Emoji status draws; `is_verified` and `is_premium` are not read on a row. |
| Story ring on every row avatar | `missing` | ``Features/Chat/Views/TGChatCell.m`` | Only the strip tile has a ring; rows draw a plain avatar. |
| Avatar or initials | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Downloaded photo, Saved Messages glyph, or stable initials. |
| Preview text | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | `previewText`, sender prefix, two lines. |
| Draft preview | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Draft wins over the last message and is coloured destructive. |
| Typing preview with sender name | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | A group action is prefixed with the sender name from `updateChatAction`. |
| Delivery ticks on your last message | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Sent/read ticks, or the failed mark from `TGSendStore`; a pending last message still has no clock. |
| Photo/video thumbnail in the preview | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | `TGChatListStore` downloads and caches the smallest preview file; the cell draws it or falls back to the kind glyph. |
| Content-type glyph in the preview | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Photo/video/voice/sticker/file/poll/location/contact/call/gift map to a TGIcons glyph. |
| Date of the last message | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | `TGChatDate` keeps today as a clock. |
| Folder tags on the row | `done` | ``Core/Client/Chats/TGClient+ChatFolders.mm`` | `chat_lists`/`folderIds` are copied and the folder names ride in the compact trailing badge. |
| Forum row names its latest topics | `missing` | ``src/Features/ChatList/Core/TGChatListSelection.m`` | The row previews the last message; a tap opens the topic list, not a topic. |
| Archive row with unread and story states | `partial` | ``src/Features/ChatList/Core/TGChatListReload.m`` | Appears under the stories strip; the subtitle has a chat count but no archived-story or unread state. |
| Archive screen with its own More menu | `partial` | ``src/Features/ChatList/Core/TGChatListReload.m`` | Pushes the filtered list, but `buildHeaderButtons` returns early, so the archive has no bar actions. |
| Stories strip | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Horizontal story rings above the first chat. |
| My Story first tile | `partial` | ``src/Features/ChatList/Core/TGChatListReload.m`` | The tile always draws a plus; it does not become a ring when own stories exist. |
| Story tile hold menu | `done` | ``src/Features/ChatList/Core/TGChatListReload.m`` | Hide from row / move to main. |
| Collapsed story beside the title | `done` | ``src/Features/ChatList/Core/TGChatListLifecycle.m`` | First active story appears once the strip scrolls off. |
| Edit mode selection | `done` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | Checkmarks, Select All, count. |
| Bulk pin / read / mute / archive / delete | `done` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | Toolbar actions apply to every selected chat. |
| Drag pinned chats | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Only pinned rows get a move handle; writes the whole pinned list. |
| Hold menu | `partial` | ``Features/ChatList/TGChatListViewController+Actions.m`` | Has those actions; no Add to Contacts, Add/Remove Folder or Select. |
| Swipe actions on iOS 8+ | `partial` | ``Features/ChatList/TGChatListViewController+Actions.m`` | Five text buttons on one swipe; at 320 pt the delete target is very narrow. |
| Delete with undo window | `done` | ``Features/ChatList/TGChatListViewController+Actions.m`` | Row returns if the snackbar is not committed. |
| Compose sheet | `partial` | ``src/Features/ChatList/Core/TGChatListCompose.m`` | Four choices then the contacts picker; no New Contact row or compose search. |
| Join a chat or folder by link | `done` | ``src/Features/ChatList/Core/TGChatListCompose.m`` | Resolves invite links and folder links. |
| Saved Messages row | `done` | ``src/Features/ChatList/Core/TGChatListReload.m`` | `headerRows` adds the Saved Messages row and the tap opens it. |
| Empty state | `partial` | ``src/Features/ChatList/Core/TGChatListReload.m`` | Main list has illustration and "No chats yet"; the archive and folders return before it and stay blank. |
| Network state as the title subtitle | `partial` | ``src/Features/ChatList/Core/TGChatListLifecycle.m`` | "Waiting for network" replaces the second line; no spinner and the line disappears on ready. |
| Proxy and lock marks in the title row | `missing` | ``src/Features/ChatList/Core/TGChatListLifecycle.m`` | Only a text subtitle; no proxy mark or passcode lock. |
| Header hierarchy | `partial` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | Story strip, search and pills all live in `tableHeaderView`; `parkOffset` is zero, so the stack scrolls away. |
| Unread badge on the Chats tab | `done` | ``App/RootViewController.m`` | `TGChatListStoreChangedNotification` updates the Chats tab badge. |
| Folder list on the title chevron | `done` | ``Features/ChatList/TGChatListViewController+Actions.m`` | Lists folders plus "Mark All Read". |
| Folder tabs with counts | `partial` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | Pills draw without a per-folder unread count or edit/delete. |
| Folder bar stays pinned and capsule-selected | `missing` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | The strip scrolls away and the selected pill is a solid accent fill. |
| Title stays "Chats" | `missing` | ``src/Features/ChatList/Core/TGChatListLifecycle.m`` | The title is replaced by the selected folder's name. |
| Long-press folder reorder | `done` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | Drags the strip and persists the order. |
| Create / rename / delete folders | `done` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Create, rename, add/remove chats, counts, icons, delete. |
| Folder edit/delete in the strip | `missing` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | Editing lives only in Settings; the strip has no edit/delete. |
| Recommended folders | `done` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Suggested folders can be created. |
| Archive appears once | `partial` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | With a folder and archived chats, both an "Archived" pill and an "Archived Chats" row appear. |
| Pull-down search field | `done` | ``src/Features/ChatList/Core/TGChatListFolders.m`` | Opens on the stories row; the field appears on pull. |
| Local title search | `done` | ``Features/ChatList/TGChatListViewController+Search.m`` | Case-insensitive title match, instant. |
| Message search from the field | `done` | ``Features/ChatList/TGChatListViewController+Search.m`` | `searchMessages:` results are appended below title hits. |
| Global search screen | `partial` | ``Features/ChatList/TGChatListViewController+Search.m`` | All/Chats/Messages/Media/Links/Files/Music/Voice; no Channels, Apps, Posts or Downloads. |
| Search results use real rows | `missing` | ``Features/ChatList/TGSearchViewController.m`` | Generic subtitle cells with a disclosure chevron for every hit. |
| Search filter bar at the bottom | `partial` | ``Features/ChatList/TGSearchViewController.m`` | Scope pills sit in `tableHeaderView` and scroll away; selected pill is a plain accent fill. |
| Search tokens for archive, folder, peer and date | `missing` | ``Features/ChatList/TGSearchViewController.m`` | No tokens; every query is global. |
| Downloads shortcut in search | `missing` | ``Features/ChatList/TGSearchViewController.m`` | Nothing; downloads live only under Settings. |
| Header notice panel | `missing` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | `updateSuggestedActions` is read only by the Tier 2 hub, never on the list. |
| Real peek on hold | `missing` | ``Features/ChatList/TGChatListViewController+Actions.m`` | A centred action menu only; no preview card. |
| Group preview with an author prefix stays one line | `missing` | ``Features/Chat/Views/TGChatCell.m`` | `previewLabel.numberOfLines = 2` always, so "Ivan: …" can wrap under the author. |
| Archive intro pages | `missing` | `—` | No archive intro or empty-archive state. |

## Chat & Composer

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| History load, 60 messages | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | `historyForChat:limit:60` fills the table on open. |
| Older paging | `done` | ``src/Features/Chat/Core/TGChatViewDocumentDelegate.m`` | Scrolling up prepends 60-message pages and keeps the offset. |
| New messages live | `done` | ``src/Features/Chat/Core/TGChatViewLayout.m`` | `onNewMessage` appends and reloads when away from the bottom. |
| Date separators | `done` | ``Features/Chat/Rendering/TGChatViewController+Chrome.m`` | One separator row per calendar day, formatted by `TGDayTitle`. |
| Unread divider | `done` | ``Features/Chat/Rendering/TGChatViewController+Chrome.m`` | Captured once on open and inserted at the first unread message. |
| Album grouping | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Albums collapse to one row with a 2×2 collage and `+N` for the rest. |
| Jump to bottom / unread | `partial` | ``Features/Chat/Rendering/TGChatViewController+Chrome.m`` | One button scrolls to the newest message; no separate mention, reaction or poll-vote button. |
| Jump to date | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Calls `messageAtDate:` and scrolls there. |
| Scroll to replied / pinned message | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Loads history around the id when outside the window and flashes the row. |
| Floating date while scrolling | `done` | ``Features/Chat/Rendering/TGChatViewController+Chrome.m`` | Shows the day of the top visible row and fades it. |
| Group sender name and avatar | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`` | Name is colour-mapped per sender; avatar follows the run start. |
| Member tag under the sender | `done` | ``Features/Chat/Rendering/TGChatViewController+Layout.m`` | `senderTag` is appended after the sender name in the meta line. |
| Incoming/outgoing bubble colours | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`` | Fill comes from `bubbleMineColour` / `bubbleTheirsColour`; tails are always hidden. |
| Time and "edited" stamp | `done` | ``Features/Chat/Rendering/TGChatViewController+Layout.m`` | `TGMessageStamp` puts "edited" after the clock. |
| Sent/read ticks | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`` | `state` selects single or double ticks. |
| Sending clock | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`` | `sending` replaces the ticks with a clock. |
| Failed delivery mark | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`` | Error glyph from `TGSendStore`; tap on the bubble resends and the hold menu keeps Retry. |
| Reply block and swipe-to-reply | `done` | ``Features/Chat/Rendering/TGChatViewController+Chrome.m`` | Quote strip draws author and text; pan on a bubble starts a reply. |
| Reply with a chosen quote | `missing` | ``Core/Client/Messages/TGClient+Messages.m`` | Reply stores only `replyToId`; no text selection or `inputTextQuote`. |
| Forward attribution line | `done` | ``Features/Chat/Rendering/TGChatViewController+Layout.m`` | "Forwarded from …" is drawn above the body. |
| Link preview card | `partial` | ``Features/Chat/Rendering/TGChatViewController+Layout.m`` | Title, site and description only; `linkPreview.type` picture is never fetched. |
| Spoiler text reveal | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`` | Per-message reveal set drives `TGAttributedMessageTextRevealing`. |
| Reaction chips under a bubble | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`` | One reactor shows their face; more show emoji and count. |
| Reaction picker and send | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Bar sends `addMessageReaction`; holding a reaction makes it default. |
| Custom emoji in text | `done` | ``Features/Chat/Views/TGMessageLayout.mm` (`TGCustomEmojiSpacer`, `TGCustomEmojiRectsCoreText`)` | Picture inline on iOS 7+; on iOS 6 a clear "@" holds the place and the picture is drawn over it from CoreText's layout. Fixed 18 November 2026 on the iPod touch 4, Paul Durov's channel: pictures sat lines above or below their places in long posts. Three causes: the body frame was up to 18 pt wider than the width the text was measured at (UILabel centred the shorter text), CoreText got the label's UIFont, which iOS 6 does not bridge, and laid the text out in 12 pt, and the em space that stood in for the emoji hung past the margin in UIKit but wrapped in CoreText. Animated through the sticker pipeline where stickers animate, up to 3 per bubble; animation not yet checked on the 4S. Tests: `TGMessageRowLayoutTests.testWideBubble_BodyKeepsTheWidthItWasMeasuredAt`, `TGMessageCellFactoryTests.testCoreTextFonts_TurnsAForeignFontIntoACTFont`, `testCustomEmojiSpacer_IsNotWhitespace`; the line agreement between UIKit and CoreText is device-only, checked by screenshot. |
| Composer text field and send | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | Trimmed text goes through `TGSendStore sendFormattedText:…`; the store owns the send and its state. |
| Markdown send | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | `markdownParsed:` keeps the typed markup as entities and the store sends the formatted record. |
| Formatted send/edit interface | `done` | ``Core/Stores/TGSendStore.mm`` | `sendFormattedText:…schedulingState:` and `editMessageText:…formattedText:` own the request and track the result. |
| Send custom emoji ids | `done` | ``Core/Model/TGComposerText.m`, `Features/Chat/Composer/TGChatViewController+Input.m`` | `TGComposerText` keeps the ids; Send goes through `parseMarkdown` and `sendFormattedText`; seen on the 4S in Saved Messages on 7 November 2026. |
| File and music picker | `done` | ``Features/Chat/Views/TGAttachSheet.h`` | File uses `UIDocumentPicker` on iOS 8+, music uses `MPMediaPickerController` and exports to .m4a; both send through `TGSendStore` with `inputMessageDocument` / `inputMessageAudio`. |
| Attach sheet | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | Gallery, camera, location, contact, checklist, quick reply, dice, ephemeral. |
| Pick photo / video / album | `done` | ``Features/Chat/Actions/TGChatViewController+Attachments.m`` | Picker accepts images and movies; multi-select sends an album. |
| Voice recording and send | `done` | ``src/Features/Chat/Composer/TGChatAudioVoice.m`` | Hold-to-record, pause, waveform, `sendVoiceAtPath:`. |
| Round video note record/play | `done` | ``src/Features/Chat/Composer/TGChatAudioVoice.m`` | `TGVideoNoteRecorder` writes the file; bubble plays it in a circle. |
| Sticker and GIF send | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | Panel picks send `sendStickerWithFileId:` / `sendAnimation:`. |
| GIF caption | `done` | ``Core/Stores/TGSendStore.mm`` | `sendAnimation:caption:` sends the composer text as `inputMessageAnimation.caption`. |
| Custom emoji tab in picker | `done` | ``Features/Chat/Views/TGEmojiPanel.m`` | Custom tab with the installed packs; without Premium only Saved Messages takes them. |
| Reply | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Sets reply target and opens the composer. |
| Forward | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Single and batched forwards through `TGForwardPicker`. |
| Forward with a new caption | `missing` | ``Features/Chat/TGForwardPicker.m`` | Picker chooses chats only and calls `forwardMessages`; no `copy_options`. |
| Share into a forum topic | `missing` | ``Features/Chat/TGForwardPicker.m`` | Picker lists chats, not topics, and sends no `topic_id`. |
| Edit text | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Prefills with `getMarkdownText` result, then `editMessage:text:`. |
| Edit caption | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | `editCaption:ofMessage:inChat:` when the original has a photo or document. |
| Replace photo | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Picks a new image and keeps the message id. |
| Delete for me / for everyone | `done` | ``Features/Chat/Selection/TGChatViewController+Selection.m`` | One sheet chooses revoke or local delete. |
| Copy text and copy link | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Copy uses the flattened caption/text; Copy Link uses the t.me link. |
| Multi-select mode | `done` | ``Features/Chat/Selection/TGChatViewController+Selection.m`` | Checkboxes, count title, Delete and Forward toolbar. |
| Copy in multi-select | `missing` | ``Features/Chat/Selection/TGChatViewController+Selection.m`` | Toolbar has only Delete and Forward. |
| Pin / unpin a message | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | `pinChatMessage` / `unpinChatMessage`. |
| Pinned banner and Unpin All | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Banner loads the pinned message; hold offers `unpinAllMessagesInChat`. |
| Pinned message list | `missing` | ``src/Features/Chat/Core/TGChatViewData.m`` | The banner loads one message only; no list or index. |
| Search in chat | `partial` | ``Features/Chat/Search/TGChatViewController+Search.m`` | Text-only `searchChatMessages`; no sender, media, date or filter chips. |
| Search result opens the message | `missing` | ``Features/Chat/Search/TGChatViewController+Search.m`` | Results replace the feed; ending search returns to the bottom. |
| Scheduled send | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | Long-press Send offers a time or "When Online". |
| Scheduled queue screen | `done` | ``Features/Chat/TGScheduledViewController.m`` | Lists, reschedules and deletes scheduled messages. |
| Repeated scheduled message | `done` | ``Core/Stores/TGMessageStore.m`` | `scheduledAtDate:repeatPeriod:` and the composer's Repeat row carry the period. |
| Silent send | `done` | ``Core/Stores/TGSendStore.mm`` | `sendText:...silent:` and the hold sheet's Send Without Sound build `messageSendOptions`. |
| Drafts | `done` | ``src/Features/Chat/Core/TGChatViewLayout.m`` | Typed text is written with `setDraft:` and restored on reopen. |
| Remote "draft stopped" | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Shows a snackbar and clears the field when TDLib names the same text. |
| Send typing action | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | One `sendChatAction` per 4 s. |
| Show typing in header | `done` | ``src/Features/Chat/Core/TGChatViewLayout.m`` | `onChatAction` drives the subtitle and an animated dot cycle. |
| Translate a message | `done` | ``Features/Chat/Actions/TGChatViewController+MessageSheets.m`` | `translateText` result is shown in a sheet. |
| Translate the whole chat | `missing` | ``Features/Chat/Actions/TGChatViewController+MessageSheets.m`` | Per-message only; no chat-wide toggle or bar. |
| Message Info / statistics | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Info sheet plus per-message interaction graph. |
| Viewed by / who read | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | "Viewed by N" opens the reader list or Telegram's refusal. |
| Protected content | `done` | ``Features/Chat/Selection/TGChatViewController+Selection.m`` | Copy/Forward disabled in a protected chat and the viewer checks `can_be_saved`. |
| View-once and timer media | `done` | ``Features/Chat/Composer/TGChatViewController+MediaCells.m`` | Blurred veil, one open, `openMessageContent`, no save/share. |
| Paid media preview | `partial` | ``Features/Chat/Composer/TGChatViewController+MediaCells.m`` | Blur and price show; tap says Stars are not available. |
| Polls | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Vote, multi-answer, quiz, retract, voters, close, statistics. |
| Poll creation | `missing` | ``Features/Chat/Views/TGAttachSheet.m`` | The attach sheet has no Poll row and no `inputMessagePoll` request. |
| Poll option links | `partial` | ``Core/Model/TGMessageFlatten.m`` | Option text is flattened to a plain string; entities are dropped. |
| Poll vote timestamps | `partial` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | `pollVoter.date` is stored but the voter sheet prints names only. |
| Checklists | `partial` | ``src/Features/Chat/Core/TGChatViewData.m`` | Tasks toggle; adding tasks from the bubble is not implemented. |
| Cards (invoice/gift/game/story/group call) | `partial` | ``Features/Chat/Rendering/TGChatViewController+ServiceCells.m`` | Card draws; Pay and Join buttons are deliberately removed because the follow-up does not exist. |
| Bot reply keyboard | `done` | ``Features/Chat/Composer/TGChatViewController+Bots.m`` | Keyboard rows/one-time/placeholder are drawn and send text. |
| Bot inline buttons | `partial` | ``Features/Chat/Composer/TGChatViewController+Bots.m`` | Web App, Pay, Game and password callbacks answer "needs a newer Telegram". |
| Inline bot mode (`@bot query`) | `missing` | ``Features/Chat/Composer/TGChatViewController+Bots.m`` | Switch-inline only types the mention; no inline result list or `sendInlineQueryResult`. |
| Bot Web Apps | `missing` | ``Features/Dev/TGDevBotConsoleViewController.m`` | No Web App host; the debug console copies the URL. |
| Ephemeral bot replies | `missing` | ``Core/Model/TGMessageFlatten.m`` | `ephemeral_message_id` is carried; `ephemeral_content` is never read and no "Only you" mark is drawn. |
| Rich message | `partial` | ``Core/Model/TGMessageFlatten.m`` | Paragraphs, headings and lists flatten to plain lines; no formatting, tables, media or button rows. |
| Rich text editor | `missing` | ``Features/Chat/Views/TGAttachSheet.m`` | No composer path; only Message Tools sends a plain-line rich draft. |
| AI Compose from composer | `partial` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | TDLib `composeTextWithAi` / `composeRichMessageWithAi` is a sheet in the composer menu, not an inline button. |
| Message effects | `missing` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | The effect id is only read for a metadata alert; no send option or playback. |
| Time and date entities | `missing` | ``Features/Chat/Views/TGMessageLayout.mm`` | No DateTime branch; it renders as plain text. |
| Coloured bot buttons | `partial` | ``Core/Model/TGMessageFlatten.m`` | Style and icon are dropped; every button uses the default style. |
| Secret chat | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Starts through `createSecretChatWithUser:`; header states the secret state. |
| Auto-delete timer | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Per-chat TTL from the profile menu. |
| Read on open and scroll | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Batched `viewMessages` marks what is visible. |
| Message links open in-app | `done` | ``Features/Chat/Actions/TGChatViewController+Attachments.m`` | `tg://` and `t.me` links route to chat/message/profile. |
| Delete/forward from the list | `done` | ``Features/Chat/Selection/TGChatViewController+Selection.m`` | Local removal plus `deleteMessages:revoke:`. |
| Formatting menu | `partial` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | Format sheet inserts `**`, `*`, `` ` ``, spoiler markup, `~`; no underline, quote or code block. |

## Message Types & Cards

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| messageText | `done` | ``Core/Model/TGMessageFlatten.m`` | Text with entities, spoiler reveal and custom emoji attachments is drawn by the bubble body. |
| messageRichMessage | `partial` | ``Core/Model/TGMessageFlatten.m`` | Paragraphs, headings and lists flattened to plain lines; no formatting, tables or media blocks. |
| messageAnimation | `done` | ``Core/Model/TGMessageFlatten.m`` | GIF bubble with cover, disc, autoplay gate and the media viewer. |
| messageAudio | `done` | ``Core/Model/TGMessageFlatten.m`` | Track bubble with artwork, waveformless row and the music player queue. |
| messageDocument | `done` | ``Core/Model/TGMessageFlatten.m`` | File tile with thumbnail, name and size; tap downloads and opens the document preview. |
| messagePaidMedia | `partial` | ``Core/Model/TGMessageFlatten.m`` | Blurred preview and "Unlock for N Stars"; tapping only reports that Stars are unavailable. |
| messagePhoto | `done` | ``Core/Model/TGMessageFlatten.m`` | Sized thumbnail, caption above/below, spoiler veil, album collage, viewer. |
| messageSticker | `done` | ``Core/Model/TGMessageFlatten.m`` | WebP still, TGS/WebM playback, emoji fallback while the file loads. |
| messageVideo | `done` | ``Core/Model/TGMessageFlatten.m`` | Thumbnail, disc, inline player and viewer; Vintage uses the software decoder. |
| messageVideoNote | `done` | ``Core/Model/TGMessageFlatten.m`` | Round bubble, record/play, mute toggle. |
| messageVoiceNote | `done` | ``Core/Model/TGMessageFlatten.m`` | Waveform, duration, play/pause, speed, transcription line. |
| messageExpiredPhoto | `done` | ``Core/Model/TGServiceMessageText.m`` | "The photo has expired" service line; no tile remains. |
| messageExpiredVideo | `done` | ``Core/Model/TGServiceMessageText.m`` | Service sentence. |
| messageExpiredVideoNote | `done` | ``Core/Model/TGServiceMessageText.m`` | Service sentence. |
| messageExpiredVoiceNote | `done` | ``Core/Model/TGServiceMessageText.m`` | Service sentence. |
| messageLiveLocation | `partial` | ``Core/Model/TGMessageFlatten.m`` | Map card with time left; no heading arrow and the line only moves on reload. |
| messageLocation | `done` | ``Core/Model/TGMessageFlatten.m`` | Static map card with coordinates and Open in Maps. |
| messageVenue | `done` | ``Core/Model/TGMessageFlatten.m`` | Map card with title and address. |
| messageContact | `done` | ``Core/Model/TGMessageFlatten.m`` | Contact card with name, phone, Add Contact and Call. |
| messageAnimatedEmoji | `done` | ``Core/Model/TGMessageFlatten.m`` | Drawn through the sticker path; TGS/WebM animates, WebP stays still. |
| messageDice | `done` | ``Core/Model/TGMessageFlatten.m`` | The throw plays as its sticker animation; slot-machine reels and lever are not drawn. |
| messageGame | `partial` | ``Core/Model/TGMessageFlatten.m`` | Card with title, description and picture; Play asks the bot for a URL and leaves the app. |
| messagePoll | `done` | ``Core/Model/TGMessageFlatten.m`` | Question, options, share bars, quiz marks, retract, voters, close, statistics. |
| messageStakeDice | `missing` | ``Core/Model/TGMessageFlatten.m`` | No branch and no service text; falls back to the derived phrase "Stake dice". |
| messageStory | `partial` | ``Core/Model/TGMessageFlatten.m`` | Card says "Story by …" and Open plays it; the story's own picture is not in the card. |
| messageWidget | `missing` | ``Core/Model/TGMessageFlatten.m`` | No widget renderer: the caption shows as text, or the derived phrase "Widget" as a service line. |
| messageChecklist | `partial` | ``Core/Model/TGMessageFlatten.m`` | Title, tasks and completed count; tapping toggles, adding tasks is missing. |
| messageInvoice | `partial` | ``Core/Model/TGMessageFlatten.m`` | Card with product, description and picture; the Pay button is removed (no payment form). |
| messageCall | `done` | ``Core/Model/TGMessageFlatten.m`` | Row names direction, video and duration; a call is startable from the call screen. |
| messageGroupCall | `partial` | ``Core/Model/TGMessageContentInteractive.m`` | Card with state and duration; Join is suppressed because there is no group-call audio. |
| messageVideoChatScheduled | `partial` | ``Core/Model/TGMessageContentInteractive.m`` | Card says "Ended" because `startDate` is flattened but never shown; no join. |
| messageVideoChatStarted | `partial` | ``Core/Model/TGMessageContentInteractive.m`` | Card "Ongoing"; Join button is removed. |
| messageVideoChatEnded | `done` | ``Core/Model/TGMessageContentInteractive.m`` | Card with "Ended" and the call duration. |
| messageInviteVideoChatParticipants | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming who was invited. |
| messagePollOptionAdded | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the option text. |
| messagePollOptionDeleted | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the option text. |
| messageBasicGroupChatCreate | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the creator and title. |
| messageSupergroupChatCreate | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the creator and title. |
| messageChatChangeTitle | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the old and new title. |
| messageChatChangePhoto | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence only; official also shows the new photo as a tile. |
| messageChatDeletePhoto | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChatOwnerLeft | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the departing owner. |
| messageChatOwnerChanged | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the new owner. |
| messageChatHasProtectedContentToggled | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence says whether protection is on. |
| messageChatHasProtectedContentDisableRequested | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence names the request state. |
| messageChatAddMembers | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the added names. |
| messageChatJoinByLink | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the joiner and link. |
| messageChatJoinByRequest | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChatJoinFromCommunity | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChatDeleteMember | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming who left or was removed. |
| messageChatAddedToCommunity | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChatRemovedFromCommunity | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChatUpgradeTo | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence about the supergroup upgrade. |
| messageChatUpgradeFrom | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the old group title. |
| messagePinMessage | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence only; tapping it does not jump to the pinned message. |
| messageScreenshotTaken | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChatSetBackground | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChatSetTheme | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the theme emoji or name. |
| messageChatSetMessageAutoDeleteTime | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the new TTL. |
| messageChatBoost | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the boost count. |
| messageForumTopicCreated | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the topic name. |
| messageForumTopicEdited | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the rename or icon change. |
| messageForumTopicIsClosedToggled | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence says closed or reopened. |
| messageForumTopicIsHiddenToggled | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence says shown or hidden. |
| messageSuggestProfilePhoto | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence only; no photo thumbnail and no Accept action. |
| messageSuggestBirthdate | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence only; no Accept action. |
| messageCustomServiceAction | `done` | ``Core/Model/TGServiceMessageText.m`` | Draws the bot-supplied text as a service line. |
| messageGameScore | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the score and the game. |
| messageManagedBotCreated | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the bot. |
| messagePaymentSuccessful | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence with amount; no receipt button. |
| messagePaymentSuccessfulBot | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence; no receipt or order view. |
| messagePaymentRefunded | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the amount. |
| messageGiftedPremium | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming giver, recipient and period. |
| messagePremiumGiftCode | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the code and period. |
| messageGiveawayCreated | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the prize and date. |
| messageGiveaway | `done` | ``Core/Model/TGMessageCard.m`` | Card with prize, winners count and date; Learn More reads the giveaway. |
| messageGiveawayCompleted | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with winner count. |
| messageGiveawayWinners | `done` | ``Core/Model/TGMessageCard.m`` | Card with winner count and the winners' names. |
| messageGiftedStars | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the star count. |
| messageGiftedGrams | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the Gram amount. |
| messageGiveawayPrizeStars | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the prize. |
| messageTonWalletTransfer | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with amount and sender. |
| messageTonConnectRequest | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence names the service; no Open/Connect action. |
| messageGift | `partial` | ``Core/Model/TGMessageCard.m`` | Card with artwork still, stars and note; View opens `TGGiftViewer`; artwork does not animate. |
| messageUpgradedGift | `partial` | ``Core/Model/TGMessageCard.m`` | Card with model, number, symbol and backdrop; still artwork only. |
| messageRefundedUpgradedGift | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageUpgradedGiftPurchaseOffer | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the offer amount. |
| messageUpgradedGiftPurchaseOfferRejected | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messagePaidMessagesRefunded | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with message and star counts. |
| messagePaidMessagePriceChanged | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the new price. |
| messageDirectMessagePriceChanged | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the new price. |
| messageUnpaidMessagesAllowedByLink | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageChecklistTasksDone | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the completed count. |
| messageChecklistTasksAdded | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the added tasks. |
| messageSuggestedPostApprovalFailed | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the refusal. |
| messageSuggestedPostApproved | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence; no Open the post action. |
| messageSuggestedPostDeclined | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageSuggestedPostPaid | `partial` | ``Core/Model/TGServiceMessageText.m`` | Sentence with price; no Open the post action. |
| messageSuggestedPostRefunded | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageContactRegistered | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageUsersShared | `done` | ``Core/Model/TGMessageCard.m`` | Card with one user or a name list; Open goes to the profile. |
| messageChatShared | `done` | ``Core/Model/TGMessageCard.m`` | Card with chat title, username and photo; Open goes to the chat. |
| messageBotWriteAccessAllowed | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming the bot and the reason. |
| messageWebAppDataSent | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the button text. |
| messageWebAppDataReceived | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence with the button text. |
| messagePassportDataSent | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence listing the document types. |
| messagePassportDataReceived | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence. |
| messageProximityAlertTriggered | `done` | ``Core/Model/TGServiceMessageText.m`` | Sentence naming both people and the distance. |
| messageUnsupported | `done` | ``Core/Model/TGServiceMessageText.m`` | "This message is not supported by this app" service line. |
| Live and motion photos | `partial` | ``Core/Model/TGMessageFlatten.m`` | The `messagePhoto` branch reads only the still sizes and ignores `content.video`. |
| GIF caption | `done` | ``Core/Stores/TGSendStore.mm`` | Incoming captions draw and outgoing animations carry the composer caption. |
| Inline documents in rich text | `missing` | ``Core/Model/TGMessageFlatten.m`` | No page-block renderer, so `pageBlockDocument` never draws. |
| Buttons inside rich messages | `missing` | ``Core/Model/TGMessageFlatten.m`` | `pageBlockButtonRow` is not handled anywhere. |
| Links in poll options | `partial` | ``Core/Model/TGMessageFlatten.m`` | Option text is flattened to a plain string; entities are dropped. |
| Poll option media | `missing` | ``Core/Model/TGMessageFlatten.m`` | The poll row draws text and bars only. |
| Poll vote timestamps | `partial` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | `pollVoter.date` is stored but the voter sheet prints names only. |
| Ephemeral bot replies | `missing` | ``Core/Model/TGMessageFlatten.m`` | `ephemeral_message_id` is carried; `ephemeral_content` is never read. |
| Signed gift note | `missing` | ``Core/Client/Account/TGClient+AccountSupport.m`` | The flatten reads the wrong text key, so the note is blank. |
| AI summary block | `missing` | ``Core/Model/TGMessageFlatten.m`` | No summary block in a channel post; only Message Tools can ask for one. |
| DateTime entity | `missing` | ``Features/Chat/Views/TGMessageLayout.mm`` | No DateTime branch; the text renders as plain characters. |
| Coloured bot buttons | `partial` | ``Core/Model/TGMessageFlatten.m`` | Style and icon are dropped; every button is default-styled. |

## Media, Stickers & Audio

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Photo viewer | `done` | ``src/Features/Media/Core/TGMediaViewerTransitions.m`` | Paging scroll view, double-tap zoom, one page built lazily per item. |
| Video playback | `done` | ``src/Features/Media/Core/TGMediaViewerVideo.m`` | `AVPlayer` with `TGSoftVideoPlayer` fallback on Vintage. |
| Video cover and scrub preview | `partial` | ``src/Features/Media/Core/TGMediaViewerChrome.m`` | A working scrubber exists; no thumbnail preview while scrubbing. |
| GIF playback | `done` | ``src/Features/Media/Core/TGMediaViewerPresenting.m`` | `messageAnimation` loops with one `AVPlayer`, gated by Power Saving. |
| Voice notes | `done` | ``Features/Chat/Composer/TGChatViewController+AudioCells.m`` | Waveform, play/pause, speed and transcription text. |
| Music player | `done` | ``Audio/TGMusicPlayer.m`` | Queue, next/previous, seek, repeat, shuffle, volume, lock-screen info. |
| Music streaming | `done` | ``Audio/TGMusicStreamer.m`` | `AudioFileStream` + `AudioQueue` play the growing local file while it downloads; m4a with a trailing header falls back to the finished file. |
| Document preview | `done` | ``src/Features/Chat/Core/TGChatViewTaps.m`` | `UIDocumentInteractionController` opens the downloaded file. |
| Save to camera roll | `done` | ``src/Features/Media/Core/TGMediaViewerMoreSheet.m`` | Save appears only when `can_be_saved` allows it. |
| Protected content in the viewer | `done` | ``src/Features/Media/Core/TGMediaViewerMoreSheet.m`` | Menus check `can_be_saved`; one-time and protected media hide the actions. |
| Add to Downloads / delete local copy | `done` | ``src/Features/Media/Core/TGMediaViewerSaving.m`` | Hold menu adds to Downloads, deletes the local file or shows its info. |
| Download progress | `done` | ``Features/Chat/Composer/TGChatViewController+Media.m`` | Progress plate with a percentage. |
| Cancel a download | `done` | ``Features/Chat/Composer/TGChatViewController+Media.m`` | Tap sends `cancelDownloadFile`; snackbar confirms. |
| Downloads manager | `done` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Per-file pause, resume, info, remove, clear all. |
| Photo attachments | `done` | ``Features/Chat/Actions/TGChatViewController+Attachments.m`` | Picker accepts images and movies; multi-select sends an album. |
| Document and audio attachments | `done` | ``Features/Chat/Views/TGAttachSheet.h`` | File and music are in the attach sheet and send as documents/audio through `TGSendStore`. |
| File information | `done` | ``Features/Media/TGFileInfoViewController.m`` | `getFile`, `getRemoteFile`, downloaded-prefix size and name helpers. |
| Link preview picture | `partial` | ``Features/Chat/Rendering/TGChatViewController+Layout.m`` | Site, title and description only; the preview picture is never fetched. |
| Forward with a new caption | `missing` | ``Features/Chat/TGForwardPicker.m`` | Picker sends `forwardMessages` directly; no `copy_options`. |
| Share into a forum topic | `missing` | ``Features/Chat/TGForwardPicker.m`` | Picker lists chats, not topics, and sends no `topic_id`. |
| Sticker pack preview | `partial` | ``Features/Media/TGStickerPacksViewController.m`` | The trending sheet shows a count and Install only. |
| Sticker pack search by keyword | `partial` | ``Features/Media/TGStickerPacksViewController.m`` | Store search accepts a t.me short name only. |
| Sticker install and archive | `done` | ``Features/Media/TGStickerPacksViewController.m`` | Owned, trending, custom emoji, recent, archived; create/edit/search/clear. |
| Sticker authoring | `done` | ``Features/Media/TGStickerEditorViewController.m`` | Rename, short name, type, add/remove/reorder stickers, delete pack. |
| Animated stickers | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m`, `src/Media/TGTLottie.m`, `src/Media/TGLottieRender.mm`` | `TGLottieView` for TGS and the WebM decoder for VP9 alpha. TGS goes to tlottie first, the official client's renderer (`third_party/tlottie`, no_std static libraries from `scripts/build_tlottie.sh`; armv7 is Thumb-2 Cortex-A8 for iOS 6 with Apple's softfp calls): it draws every feature official stickers use. On the iPhone 4 emulator it drew the same 18 frames 2-6x faster than `TGLottieRender` (slot reels 113-129 ms against 589-690 ms at 256 px). A file tlottie refuses goes to `TGLottieRender`, which lays the layer tree out once in C++ and draws shape and precomp layers, skips merge paths as both official renderers do, and keeps the still for trim paths, mattes and solid/image/text layers; past that the still. Frames are flipped to Lottie's y-down, without which every TGS was upside down. A tlottie crash is an app crash (panic = abort, as official; unwinding needs std, which iOS 6 armv7 does not have): `TGCrashGuard` writes the file being drawn to `Caches/tlottie/tlottie.crashed` from the signal handler, and from the next launch that file goes to `TGLottieRender` (`tlottie.refused`); host test `TGCrashGuardTests` aborts a forked child and faults in one. The handler puts the system's handler back and returns instead of raising again: with the raise every crash report of the app was a SIGSEGV on an idle dispatch thread without the faulting stack (three such on the iPod touch 4 on 18 November 2026, none in four runs after). Slot machine verified on the emulator; not checked on a device. |
| Custom emoji images | `done` | ``Features/Chat/Views/TGMessageLayout.mm`, `Core/Stores/TGCustomEmojiStore.m`` | Static on iOS 6 fallback / iOS 7+ picture; tgs and webm animate through the sticker pipeline under its budget. |
| Live and motion photos | `partial` | ``Core/Model/TGMessageFlatten.m`` | The photo branch reads the still sizes and ignores `content.video`. |
| GIF caption | `done` | ``Core/Stores/TGSendStore.mm`` | Outgoing animations carry the composer caption. |
| Sticker/emoji custom tab | `done` | ``src/Features/Chat/Views/EmojiPanel/TGEmojiPanelTabs.m`` | Tabs are Emoji, Stickers, GIFs, and Custom. |
| Album collage | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Albums collapse to one row with a 2×2 collage and `+N` for the rest. |
| Photo strip on a profile | `done` | ``Features/Profile/TGProfileViewController+Media.m`` | Wrapping grid, tap opens the viewer. |
| Video tile marks | `partial` | ``Features/Profile/TGProfileViewController+Media.m`` | A static 16 pt video glyph only. |
| Calendar for media | `missing` | ``Features/Profile/TGProfileViewController+Media.m`` | One flat grid; no calendar. |
| Media multi-select | `missing` | ``src/Features/Profile/Core/TGProfileData.m`` | No selection in the profile media panes. |

## Stories

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Stories strip on the chat list | `done` | ``src/Features/ChatList/Core/TGChatListTable.m`` | Horizontal story rings above the first chat. |
| Story ring on every chat row avatar | `missing` | ``Features/Chat/Views/TGChatCell.m`` | Rows draw a plain avatar; only the strip bubble has a ring. |
| My Story first tile | `partial` | ``src/Features/ChatList/Core/TGChatListReload.m`` | The plus always draws; no ring around the own tile. |
| Story tile hold menu | `done` | ``src/Features/ChatList/Core/TGChatListReload.m`` | Hide from row / move to main. |
| Collapsed story beside the title | `done` | ``src/Features/ChatList/Core/TGChatListLifecycle.m`` | First active story appears once the strip scrolls off. |
| Story viewer | `done` | ``Features/Stories/TGStoryViewerViewController.m`` | Viewer sends `openStory` / `closeStory` and scores progress per story. |
| Pause on hold | `done` | ``Features/Stories/TGStoryViewerViewController.m`` | Hold pauses, release resumes. |
| Story reactions | `done` | ``Features/Stories/TGStoryViewerViewController.m`` | Rail from `getStoryAvailableReactions`; `setStoryReaction` sends or clears. |
| Story info | `done` | ``Features/Stories/TGStoryInfoViewController.m`` | Reads `getStoryInteractions`, `getStoryPublicForwards` and `getStoryStatistics`. |
| Report a story | `done` | ``Core/Client/Stories/TGClient+StoriesInteractions.m`` | Two-step `reportStory`. |
| Edit a story | `done` | ``Core/Client/Stories/TGClient+StoriesPosting.m`` | `editStory`, `editStoryCover`, `setStoryPrivacySettings`, `toggleStoryIsPostedToChatPage`. |
| Delete a story | `done` | ``Core/Client/Stories/TGClient+StoriesPosting.m`` | `deleteStory`. |
| Pin a story to the chat page | `done` | ``Core/Client/Stories/TGClient+StoriesFeed.m`` | `setChatPinnedStories`. |
| Post a photo story | `done` | ``Features/Stories/TGStoryComposerViewController.m`` | Photo, caption, privacy, period, albums and the two flags; `postStory`. |
| Post a video story | `partial` | ``Features/Stories/TGStoryComposerViewController.m`` | Imported video posts with its duration; the camera captures stills only. |
| Story camera video | `missing` | ``Features/Stories/TGStoryCameraViewController.m`` | `AVCaptureStillImageOutput` only; no movie file output. |
| Story period | `done` | ``Features/Stories/TGStoryComposerViewController.m`` | Period picker; paid periods explain the Premium lock. |
| Story privacy | `done` | ``Features/Stories/TGStoryComposerViewController.m`` | Four privacy choices and a selected-user list. |
| Story albums | `done` | ``Features/Stories/TGStoryAlbumsViewController.m`` | `getChatStoryAlbums`, `getStoryAlbumStories`, create/rename/delete/reorder. |
| Album story order | `done` | ``Features/Stories/TGStoryAlbumsViewController.m`` | `reorderStoryAlbumStories` and add/remove story calls. |
| Archive | `done` | ``Features/Stories/TGStoryArchiveViewController.m`` | `getChatArchivedStories` fills the archive. |
| Story Archive and albums on the profile | `partial` | ``Core/Model/TGProfileTabs.m`` | Archive is a tab on the own profile; albums are only in the Stories menu. |
| Own-profile Stories tab | `done` | ``Core/Model/TGProfileTabs.m`` | Own public profile always gets Stories; the empty action posts one. |
| Story ring around the profile avatar | `missing` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Plain avatar; no ring. |
| Story notifications | `done` | ``Features/Stories/TGStorySettingsViewController.m`` | `getStoryNotificationSettingsExceptions` and the per-chat switch. |
| Stealth mode | `done` | ``Core/Client/Stories/TGClient+StoriesDiscovery.m`` | `activateStoryStealthMode`; the server's answer is shown. |
| Public stories search | `done` | ``Core/Client/Stories/TGClient+StoriesDiscovery.m`` | `searchPublicStoriesByTag`, `ByLocation`, `ByVenue` open in the same viewer. |
| Reply to a story with a message | `missing` | ``Features/Stories/TGStoryViewerViewController.m`` | Viewer has reactions only; no `inputMessageReplyToStory`. |
| Share or repost a story | `missing` | ``Features/Stories/TGStoryViewerViewController.m`` | Menu offers info, report and owner edits only; no share action. |
| Story in a message bubble | `partial` | ``Core/Model/TGMessageFlatten.m`` | Card says "Story by …" and Open plays it; the story's own picture is not in the card. |
| Live story screen | `partial` | ``Features/Stories/TGLiveStoryViewController.m`` | Metadata, RTMP key, join and donor lists are real; no video player or decoder. |
| Live story playback | `missing` | ``Features/Stories/TGLiveStoryViewController.m`` | Joining copies the tgcalls payload; no RTMP/AVPlayer pipeline. |
| Live story host | `missing` | ``Features/Stories/TGLiveStoryViewController.m`` | `startLiveStory` is called, but this client has no camera encoder. |
| Story comments and paid pins | `missing` | ``Features/Stories/TGLiveStoryViewController.m`` | Only donor and reaction records are listed. |
| Business stories | `dev-only` | ``Features/Stories/TGStoryViewerViewController.m`` | Rows exist and show Telegram's refusal; no business connection is modelled. |

## Profiles & Contacts

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Profile header | `done` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Name, marks and status line draw from the full-info answer. |
| Tapping the avatar | `partial` | ``Features/Profile/TGProfileViewController+Actions.m`` | Opens a separate photo table; no in-place carousel or story indicator. |
| Verified mark | `done` | ``src/Features/Profile/Core/TGProfileHeader.m`` | Badge beside the name from `is_verified`. |
| Emoji status | `done` | ``src/Features/Profile/Core/TGProfileHeader.m`` | Custom emoji picture beside the name. |
| Scam / fake warning | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Replaces the bio with a warning row. |
| Phone and username rows | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Mobile and @username, copy on hold. |
| Multiple usernames | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Every active username gets a row. |
| Bio row | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Wrapped block with link entities; tapping opens the first link. |
| Birthday row | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Date, year and today state draw; no gift action. |
| Business location row | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Address only; hours, state and map thumbnail are absent. |
| Personal note | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Note visible only to this account; entities are kept. |
| Add to Contacts row | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Shown for a stranger who is not a bot. |
| Personal channel row | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Opens the channel; until 7 November 2026 a `> 0` check on the (negative) channel id kept it from ever loading. |
| Common groups pane | `partial` | ``Features/Profile/TGProfileViewController+Media.m`` | Pane exists but `TGProfileTabKinds` is called with `hasCommonGroups = NO`, so the tab never appears; the More menu still lists titles. |
| Action tiles | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Tiles build per profile kind; own profile has Saved, Story, More. |
| Own profile hides Message/Call | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | `own` branch builds Saved, Story and More only. |
| Video call tile | `partial` | ``Features/Profile/TGProfileViewController+Actions.m`` | Gated by `canEncodeVideoCall`, which is false outside `TG_DEV`; see `calls.md`. |
| Call tile | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | `canCall` from `can_be_called` now gates the tile. |
| Mute tile | `partial` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Tile toggles and redraws; `isChatMuted:` reads the chat cache, not global defaults or thread settings. |
| Share contact | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Opens the share sheet. |
| Copy profile link | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Own and other profiles. |
| Start secret chat | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Confirms and creates the secret chat. |
| Personal note / suggest photo / suggest birthday | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Requests go through `setPersonalNote`, `suggestProfilePhoto`, `suggestBirthday`. |
| Personal photo | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Set, change and remove. |
| Share theme | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Sends a theme link. |
| Block / unblock | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Confirm sheet, then `setUser:blocked:`. |
| Report | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Option list, one step at a time. |
| Delete contact | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Only when the person is a contact. |
| Clear history | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Per-chat history clear. |
| Auto-delete messages | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | TTL applies to new messages. |
| Leave / delete group or channel | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Owner sees Delete, everybody else Leave. |
| Own profile actions | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Story Archive, Copy Profile Link, Add Local Note. |
| Own profile Edit | `done` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Bar button opens Edit Profile. |
| My Profile preview | `done` | ``Features/Settings/TGSettingsViewController+Actions.m`` | `openMyProfile` is wired from Settings and the My Profile row. |
| Edit profile fields | `done` | ``Features/Profile/TGEditProfileViewController.m`` | Photo, first/last name, bio with counter, birthday with year switch, username. |
| Bio character count and limit | `done` | ``Features/Profile/TGEditProfileViewController.m`` | Counter driven by `bio_length_max`. |
| Birthday privacy line | `done` | ``Features/Profile/TGEditProfileViewController.m`` | Row opens the three-choice privacy sheet. |
| Birthday without a year | `done` | ``Features/Profile/TGEditProfileViewController.m`` | Year/No Year switch writes `year = 0`. |
| Save validation | `done` | ``Features/Profile/TGEditProfileViewController.m`` | First name required; requests are sequential and failures stay on screen. |
| Edit screen order and wording | `partial` | ``Features/Profile/TGEditProfileViewController.m`` | Fields are grouped by Name/Bio/Account/Profile; no colour or personal-channel row. |
| Premium star badge | `missing` | ``src/Features/Profile/Core/TGProfileHeader.m`` | Header draws verified and emoji status only; Premium is not read. |
| Profile cover / accent gradient | `missing` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | `profile_accent_color_id` is stored but never painted behind the header. |
| Profile colour screen | `partial` | ``Features/Profile/TGProfileAppearanceViewController.m`` | Accent swatches exist; no two-tab preview, reset step or background emoji. |
| Profile rating | `missing` | ``src/Features/Profile/Core/TGProfileData.m`` | No `rating` / `pending_rating` row. |
| Third-party verification note | `missing` | ``src/Features/Profile/Core/TGProfileHeader.m`` | `bot_verification` is not parsed or drawn. |
| Unofficial app warning | `missing` | ``src/Features/Profile/Core/TGProfileData.m`` | `uses_unofficial_app` is not read. |
| Collectible username info | `missing` | ``Features/Settings/TGUsernameSettingsViewController.m`` | Only active/disabled/editable names are read; no `collectible_usernames`. |
| Personal channel picker | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Personal channel is displayed; Edit Profile has no picker. |
| Profile photo editor | `partial` | ``Features/Profile/TGEditProfileViewController.m`` | Library still only, no crop, camera, video avatar or progress. |
| Own photo history | `partial` | ``Features/Profile/TGProfilePhotosViewController.m`` | History screen exists for others; no entry from your own profile. |
| Emoji-status timer | `missing` | ``Features/Profile/TGEmojiStatusViewController.m`` | Always sends expiration 0 (Forever). |
| Header scale | `partial` | ``Features/Profile/TGProfileViewController.m`` | 80 pt avatar, 22 pt bold name, 14 pt status. |
| Action row shape | `partial` | ``Features/Profile/TGProfileViewController+Actions.m`` | Up to six equal plates with a 22 pt glyph over an 11 pt word. |
| Info card typography | `partial` | ``src/Features/Profile/Core/TGProfileHeader.m`` | Custom detail cell; label and value sizes still smaller than official. |
| Tabs | `partial` | ``Features/Profile/TGProfileViewController+Media.m`` | Scrollable tabs exist with Music and Groups; no GIFs or Polls, and the order differs. |
| Main profile tab honoured | `done` | ``Core/Model/TGProfileTabs.m`` | `main_profile_tab` moves the chosen pane first; unmapped kinds fall back. |
| Empty panes hidden | `done` | ``Core/Model/TGProfileTabs.m`` | A tab is added only when its category has content (own profile uses Stories/Archive). |
| Panes load on open | `done` | ``Features/Profile/TGProfileViewController+Media.m`` | Each tab fetches when selected; `thumbnailsRequested` is cleared per switch. |
| Tab counts | `done` | ``src/Features/Profile/Core/TGProfileDetails.m`` | `mediaCounts` prints a count after each tab title. |
| GIF pane | `missing` | ``Core/Model/TGProfileTabs.m`` | No animation filter pane. |
| Polls pane | `missing` | ``Core/Model/TGProfileTabs.m`` | No poll filter or tab. |
| Photo grid | `done` | ``Features/Profile/TGProfileViewController+Media.m`` | Wrapping grid, tap opens the viewer. |
| Photo / video split | `missing` | ``Features/Profile/TGProfileViewController+Media.m`` | One combined photo-and-video grid. |
| Month sections and calendar | `missing` | ``Features/Profile/TGProfileViewController+Media.m`` | One flat grid; no date landmark or calendar. |
| Video tile marks | `partial` | ``Features/Profile/TGProfileViewController+Media.m`` | A static 16 pt video glyph only. |
| Multi-select in media | `missing` | ``src/Features/Profile/Core/TGProfileData.m`` | No selection in the profile media panes. |
| Pane search | `missing` | ``src/Features/Profile/Core/TGProfileData.m`` | The search tile leaves the profile for whole-chat search. |
| Files rows | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Icon and name only; rows do nothing on tap. |
| Voice rows | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Every row says "Voice message"; tap does nothing. |
| Links rows | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Raw message text and a date; tap does nothing. |
| Stories grid | `done` | ``Features/Profile/TGProfileViewController+Media.m`` | Tiles with poster face and video mark; tap opens the viewer. |
| Own-profile Stories tab | `done` | ``Core/Model/TGProfileTabs.m`` | Own public profile always gets Stories; Add a story is the empty action. |
| Story Archive tab | `done` | ``Core/Model/TGProfileTabs.m`` | Own profile appends the archive tab. |
| Story ring around the avatar | `missing` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Plain avatar; no ring. |
| Story albums on the profile | `partial` | ``Features/Stories/TGStoryAlbumsViewController.m`` | Albums exist but only from the Stories menu, not as profile shelves. |
| Music strip | `done` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | First profile-audio track starts playback. |
| Profile audio player | `done` | ``src/Features/Profile/Core/TGProfileTable.m`` | Play/pause from the strip; opens the full audio list. |
| Music tab | `done` | ``Features/Profile/TGProfileViewController+Media.m`` | Music pane pages `searchChatMessages` with the audio filter. |
| Audio tab rows | `partial` | ``Features/Profile/TGProfileViewController+Media.m`` | Rows reuse the chat track cell; current-track row is not marked. |
| Add / remove from profile | `partial` | ``Features/Profile/TGProfileAudioViewController.m`` | Add from the last 100 Saved Messages; remove and two fixed moves; no drag reorder. |
| Profile audio paging | `partial` | ``Features/Profile/TGProfileAudioViewController.m`` | One page of 100; `total` is shown but no load-more. |
| Gifts pane | `partial` | ``Features/Profile/TGProfileViewController+Media.m`` | Emoji glyph plus stars, first page only; no sticker artwork or model. |
| Common groups as rows | `partial` | ``Features/Profile/TGProfileViewController+Media.m`` | Request and rows exist, but the tab is currently not offered (see above). |
| Similar channels / bots | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Similar chats row for channels; no Similar Bots on a profile. |
| Bot info card | `partial` | ``src/Core/Client/Account/TGClient+AccountLocalNotifications.m`` | Bot short description can stand in for a missing bio; no commands or Add to Chat. |
| Premium row | `partial` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Row opens an alert that reads Premium state; no plan list or purchase. |
| Settings profile area | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Header, My Profile and Edit are separated; the header still opens Edit. |
| Settings account header | `partial` | ``Features/Settings/TGSettingsViewController.m`` | 80 pt avatar in a 168 pt grouped cell, 22 pt name, phone only. |
| Settings QR and Edit bar | `missing` | ``Features/Settings/TGSettingsViewController.m`` | No root bar items. |
| Account rows inline | `partial` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Four account slots | `partial` | ``Core/Client/TGClient+Accounts.m`` | Three slots for every account. |
| Profile header name wraps | `missing` | ``Features/Profile/TGProfileViewController.m`` | Single-line name in a fixed-height header. |
| Opening hours row | `missing` | `—` | `business_info.opening_hours` is not read for another user. |
| Edit in place | `missing` | `—` | Editing remains a separate grouped form, not the profile header. |
| Bio privacy line | `missing` | `—` | No Bio row in Privacy and no line under the field. |
| QR code of the username | `missing` | `—` | The only QR screen is a camera scanner for login. |
| Background emoji on the cover | `missing` | `—` | No UI; both accent setters send zero for the background emoji. |
| Gift-derived name colour | `missing` | `—` | Gift colours are not parsed or applied. |
| Public / fallback photo | `missing` | `—` | No setter UI and `setProfilePhoto` has no `is_public` call path from the editor. |
| Gift collections | `missing` | `—` | TDLib collection calls are never sent. |
| Stars and gifts rows | `missing` | `—` | No Stars row on the profile or Settings; the read-only console is `TG_DEV`. |
| Business hours and map | `missing` | `—` | Only the address is flattened; no hours or map thumbnail. |
| Phone formatting | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Raw plus and digits; no Anonymous Number wording or call/copy choices on tap. |
| Username availability while typing | `missing` | `—` | This TDLib has no account-username availability check; only `setUsername` exists. |
| Tabs stay under the bar | `missing` | ``src/Features/Profile/Core/TGProfileDetails.m`` | The tab strip is a section header and scrolls away with the grid. |
| Tab bar stays stable while loading | `missing` | `—` | Each completion appends a tab and reloads the table. |

## Contacts & User Search

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Contacts list | `done` | ``Features/Contacts/TGContactsViewController.m`` | `contactsWithCompletion:` fills the list; avatars load from the member store. |
| Presence on every row | `done` | ``Features/Contacts/TGContactsViewController.m`` | `TGStatusTextFromTDStatus` fills the subtitle and online uses the accent colour. |
| Sort by last seen or name | `done` | ``Features/Contacts/TGContactsViewController.m`` | "Sort" bar button offers By Last Seen / By Name and persists the choice. |
| Contact order | `done` | ``Features/Contacts/TGContactsViewController.m`` | Presence order when sorting by last seen; A-Z sections and the index rail when by name. |
| Search inside Contacts | `partial` | ``Features/Contacts/TGContactsViewController.m`` | Local search over the loaded contacts; no server or device-book lookup and no Add row. |
| Invite Friends | `missing` | `TBD` | No Invite row and no address-book access. |
| Contacts permission banner | `missing` | `TBD` | The app never reads the address book or asks for permission. |
| Import a phone book | `missing` | `TBD` | No import path; only `importedContactCount` is read for the footer. |
| Import footer | `partial` | ``Features/Contacts/TGContactsViewController.m`` | The old developer-facing line is still the footer, under every list. |
| Add a contact | `done` | ``Features/Contacts/TGNewContactViewController.m`` | Three fields; Done runs `importContacts` / `addContact`. |
| Live phone resolution | `missing` | ``Features/Contacts/TGNewContactViewController.m`` | No `searchUserByPhoneNumber` until the form is submitted. |
| Country code and formatted phone | `missing` | ``Features/Contacts/TGNewContactViewController.m`` | A single unformatted phone-pad field. |
| Note, sync-to-phone and QR add | `missing` | ``Features/Contacts/TGNewContactViewController.m`` | The form is name plus phone only. |
| Delete a contact | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Only when the person is a contact. |
| Block a person | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Confirm sheet, then `setUser:blocked:`. |
| Share a contact | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Opens the share sheet. |
| Start a secret chat | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Confirms and creates the secret chat. |
| Groups in common | `partial` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Card row and a More action sheet of titles; the Groups tab is not offered. |
| Contact rows: name and status typography | `partial` | ``Features/Contacts/TGContactsViewController.m`` | 15 pt regular both names, 13 pt status. |
| Verified, Premium, emoji-status, scam and fake labels | `missing` | ``Features/Contacts/TGContactsViewController.m`` | Initials avatar and text only; no row badges. |
| Own profile: no header actions | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Own profile builds Saved, Story and More only. |
| Info card wording | `partial` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Lowercase keys and no QR control. |
| Premium and private states as badges | `partial` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | Rows such as "personal photo" and "share theme" are still separate detail rows. |
| Rows do what the value means | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Most rows copy their value; the bio opens its first link and the channel/location rows open. |
| Sort is the left navigation item | `done` | ``Features/Contacts/TGContactsViewController.m`` | The left item is "Sort"; the old Import button is gone. |
| Block and Delete Contact are profile rows | `partial` | ``Features/Profile/TGProfileViewController+Actions.m`` | Both remain inside the More menu. |
| Profile music strip | `done` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | First profile-audio track starts playback from a strip. |
| Profile birthday row | `partial` | ``src/Features/Profile/Core/TGProfileData.m`` | Date, year and today state draw; no gift action. |
| Add to Contacts row | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Shown for a stranger who is not a bot. |
| New Call row | `missing` | `TBD` | No action row; the list starts with the Show Calls Tab switch. |
| All / Missed filter | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | `recentCallsFilter` filters the list; the empty state says "No missed calls". |
| Call row shape | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | One subtitle line; no avatar, glyph, right date or info control. |
| Tap a call redials | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Tap redials; there is no info control or details screen. |
| Missed calls say "Missed" | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | `typeLabel` is "Missed" and the row is destructive. |
| Call history paging | `missing` | ``src/Core/Client/Account/TGClient+AccountTwoStep.m`` | One request for 50; `next_offset` is not followed. |
| Empty call list | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | A plain "No recent calls" / "No missed calls" row. |
| Optional Calls tab | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Switch in Recent Calls; the root builds the tab when enabled. |
| Active group calls above Recent Calls | `missing` | `TBD` | No group-call rows in Recent Calls. |
| New Group full form | `partial` | ``Features/Contacts/TGContactsViewController.m`` | Picks members first, then asks for a name in an alert. |
| New Channel form | `partial` | ``src/Features/ChatList/Core/TGChatListCompose.m`` | A single "Channel name" alert after the compose sheet. |
| Compose rows over the contact list | `partial` | ``src/Features/ChatList/Core/TGChatListCompose.m`` | Four-choice alert sheet; no New Contact row and no compose search. |
| Username in the profile header | `missing` | ``Features/Profile/TGProfileViewController.m`` | Header draws name and status only; the username lives in the card. |
| Contact picker for groups and channels | `done` | ``Features/Contacts/TGContactsViewController.m`` | Contact picker with group mode sends `createNewBasicGroupChat`. |
| Contacts tab | `done` | ``App/RootViewController.m`` | Contacts is a tab in the root tab bar. |

## Groups & Forums

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Create a basic group | `done` | ``Features/Contacts/TGContactsViewController.m`` | Contact picker with group mode sends `createNewBasicGroupChat`. |
| Create a supergroup | `done` | ``src/Features/Groups/Core/TGGroupMembers.m`` | Upgrade path from a basic group. |
| New Group full form | `partial` | ``Features/Contacts/TGContactsViewController.m`` | Picks members first, then asks for a name in an alert. |
| Group profile summary | `done` | ``src/Features/Profile/Core/TGProfileHeader.m`` | Description, member count, invite link, linked chat, community. |
| Verified check beside a name | `partial` | ``src/Features/Profile/Core/TGProfileHeader.m`` | User profiles draw the check; group and channel records do not. |
| Group subtitle "N members, M online" | `partial` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | "N members" only; the online count is stored on the chat but not read by the profile. |
| Member list | `partial` | ``Core/Client/Chats/TGClient+ChatMembers.mm`` | The first 50 members load into the profile itself; no paging. |
| Member search with sections | `partial` | ``src/Features/Groups/Core/TGGroupMembers.m`` | One flat `chatMembersFilterMembers` result; no sections or counts. |
| Add members | `done` | ``src/Features/Groups/Core/TGGroupMembers.m`` | Contact picker respects the invite right. |
| Find member | `done` | ``src/Features/Groups/Core/TGGroupMembers.m`` | Search by name or @username. |
| Member actions sheet | `done` | ``Features/Groups/TGGroupMemberActions.m`` | Info, details, message, promote, tag, clear, remove, ban, ownership. |
| Promote to admin | `partial` | ``Features/Groups/TGGroupMemberActions.m`` | Sends the default `TGAdminRights()`; no rights chooser. |
| Dismiss as admin | `done` | ``Features/Groups/TGGroupMemberActions.m`` | Returns the member to plain member status. |
| Ban a member | `done` | ``Features/Groups/TGGroupMemberActions.m`` | Permanent ban with message revoke off. |
| Temporarily restrict a member | `missing` | ``Features/Groups/TGGroupMemberActions.m`` | No restrict path; only ban. |
| Set member tag | `done` | ``Features/Groups/TGGroupMemberActions.m`` | `setChatMemberTag`. |
| Clear their reactions | `done` | ``Features/Groups/TGGroupMemberActions.m`` | `deleteAllReactionsOfSender`. |
| Clear their messages | `done` | ``Features/Groups/TGGroupMemberActions.m`` | `deleteChatMessagesBySender` with revoke. |
| Remove from group | `done` | ``Features/Groups/TGGroupMemberActions.m`` | Sets status left. |
| Hand over ownership | `done` | ``Features/Groups/TGGroupMemberActions.m`` | 2FA password and `canTransferOwnership` pre-check. |
| Per-admin rights editor | `missing` | ``Core/Client/TGClient+Groups.m`` | Promote sends one fixed rights object; no editor screen. |
| Default admin rights | `done` | ``Features/Groups/TGAdminRightsViewController.m`` | Group and channel presets. |
| Granular member permissions | `partial` | ``src/Features/Groups/Core/TGGroupPermissions.m`` | Three presets: everything, messages only, read only. |
| Slow mode | `done` | ``src/Features/Groups/Core/TGGroupPermissions.m`` | 0, 5, 10, 30 s, 1, 5, 15 min, 1 h. |
| Slow mode once | `partial` | ``src/Features/Groups/Core/TGGroupPermissions.m`` | Duplicated in Chat Tools, which also prints 3600 as "3600 s". |
| Sign messages | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch writes `sign_messages`. |
| Join to send | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch writes `join_to_send_messages`. |
| All history visible | `partial` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch only; no Visible/Hidden screen or explanation. |
| Hidden members | `partial` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch in Permissions and Behaviour, away from the member list. |
| Aggressive anti-spam | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch with allow flag and the server's refusal. |
| Anti-spam false positive | `done` | ``Features/Groups/TGAntiSpamViewController.m`` | Report a message deleted by mistake. |
| Join by request | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch plus the requests screen. |
| Join requests row and screen | `partial` | ``src/Features/Groups/Core/TGGroupPermissions.m`` | Sheet of names with Accept/Decline; the date is dropped and the bio is never read. |
| Invite links screen | `partial` | ``src/Features/Groups/Core/TGGroupInvites.m`` | Alert of raw URLs and "N joined"; no dates, limits, QR or separate revoked section. |
| Forum mode | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | `is_forum` switch. |
| Topics list | `done` | ``src/Features/ChatList/Core/TGChatListSelection.m`` | `isForum` routes the row to `TGTopicsViewController`. |
| Create a topic | `done` | ``Features/Groups/TGTopicsViewController.m`` | Name plus custom emoji icon picker. |
| Rename a topic | `done` | ``Features/Groups/TGTopicsViewController.m`` | `renameForumTopic`. |
| Change topic icon | `done` | ``Features/Groups/TGTopicsViewController.m`` | `setForumTopicIcon`; General topic refusal explained. |
| Close / reopen a topic | `done` | ``Features/Groups/TGTopicsViewController.m`` | Hold menu toggles closed. |
| Pin / unpin a topic | `done` | ``Features/Groups/TGTopicsViewController.m`` | Hold menu plus the pinned-topics manager. |
| Delete a topic | `done` | ``Features/Groups/TGTopicsViewController.m`` | Confirmed delete of the topic and its messages. |
| Topic info | `done` | ``Features/Groups/TGTopicsViewController.m`` | Topic Info list with counts and settings. |
| Topic notifications | `done` | ``Features/Groups/TGTopicsViewController.m`` | Mute/sound for one topic. |
| Pinned topics manager | `done` | ``Features/Groups/TGTopicsViewController.m`` | Reorder and unpin from one list. |
| Hide the General topic | `done` | ``Features/Groups/TGTopicsViewController.m`` | Toggle from the topic menu. |
| Topic read state and badges | `done` | ``Features/Groups/TGTopicsViewController.m`` | Mentions, polls and reactions badges; clears reactions. |
| Broadcast group | `done` | ``src/Features/Groups/Core/TGGroupPermissions.m`` | Convert with confirmation. |
| Welcome messages | `partial` | ``src/Features/Groups/Core/TGGroupPermissions.m`` | Text only, and in Group Settings rather than the profile. |
| Automatic translation | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch writes the automatic-translation field. |
| Group usernames | `done` | ``src/Features/Groups/Core/TGGroupUsernames.m`` | Editable, active, disabled; remove and disable all. |
| Subscription links | `done` | ``src/Features/Groups/Core/TGGroupInvites.m`` | Paid invite link creation. |
| Discussion group row | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | "Discussion Group — Linked/None" inside Chat Tools; no peer name. |
| Editable header | `partial` | ``src/Features/Groups/Core/TGGroupIdentity.m`` | Name and description are one-line alert inputs; photo is a separate row. |
| Public link row | `partial` | ``src/Features/Groups/Core/TGGroupSections.m`` | Username and type live in Group Settings; no link row on the profile. |
| Recent actions | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Flat 100-event list; no search, filters or detail. |
| Statistics with graphs | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Flat totals list; no graphs or boosts tab. |
| Boosts | `missing` | ``Features/Chat/TGChatToolsViewController.m`` | No profile or settings surface; calls exist only in the `TG_DEV` Stars console. |
| Bot info card | `partial` | ``Features/Profile/TGProfileViewController+Actions.m`` | Only a Bot Settings row; `bot_info` is read for a description but no commands or Add to Chat. |
| Affiliate program row | `partial` | ``Features/BotsPayments/TGAffiliateProgramsViewController.m`` | Debug console that asks for a bot id, channel id and program id; no commission badge. |
| Statistics and recent actions as settings rows | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Both live behind Group Settings → Tools → Chat Tools. |
| Available-reactions label | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Any non-all set is labelled "Three emoji". |
| Reactions settings | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Two choices only: all, or 👍 ❤️ 🔥. |
| Member rows | `partial` | ``Features/Profile/TGMemberCell.m`` | Name and role badge only; no second line, presence or swipe. |
| Member counts | `partial` | ``src/Features/Profile/Core/TGProfileLifecycle.m`` | "N members" only; other counts are requested but not shown. |
| Member count is a disclosure | `missing` | ``src/Features/Profile/Core/TGProfileData.m`` | Every details row copies its value, including the member count. |
| Join request rows | `partial` | ``src/Features/Groups/Core/TGGroupPermissions.m`` | Name only. |
| Invite-link rows | `partial` | ``src/Features/Groups/Core/TGGroupInvites.m`` | One mixed list; revoked links are prefixed "(revoked)". |
| Group history screen | `partial` | ``src/Features/Groups/Core/TGGroupSections.m`` | One "All History" switch. |
| Group call entry | `done` | ``src/Features/Groups/Core/TGGroupIdentity.m`` | Opens `TGGroupCallViewController` with the chat's call id. |
| Video chat setup | `done` | ``src/Features/Groups/Core/TGGroupIdentity.m`` | Create/schedule, RTMP, recording, screen sharing, participants. |
| Group-call audio | `missing` | ``Features/Calls/TGGroupCallViewController.m`` | The screen says it has no group-call audio engine; no join media. |
| Leave group | `done` | ``src/Features/Groups/Core/TGGroupSwitches.m`` | With confirmation. |
| Delete group for everyone | `done` | ``src/Features/Groups/Core/TGGroupActions.m`` | Owner-only path. |
| Clear history by date | `done` | ``src/Features/Groups/Core/TGGroupTools.m`` | Date picker, then `deleteChatMessagesByDate`. |
| Group sticker set | `done` | ``src/Features/Groups/Core/TGGroupTools.m`` | Pack picker for group stickers or custom emoji. |
| Group location | `done` | ``Features/Chat/TGChatToolsViewController.m`` | `setLocation` with map point. |
| Chat Tools | `done` | ``src/Features/Groups/Core/TGGroupTools.m`` | Event log, statistics, similar chats, moderation and appearance. |
| Group calls tab entry | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | "Calls" row in the group profile menu. |
| View with Topics entry | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | "View with Topics" pushes the topic list. |
| Import migration history | `done` | ``src/Features/Groups/Core/TGGroupTools.m`` | Reads a Telegram export from Documents. |
| Communities | `partial` | ``Features/Profile/TGProfileViewController.m`, `Core/Model/TGMessageCard.m`` | A channel or group profile shows its community (picture, name, chat count) and opens it; "added to a community" draws as a card with View. The communities list itself is still reached only from the dev hub. |
| Scam / fake warning | `missing` | `—` | Group and channel `verification_status` is not read. |
| Members tab / row with total | `missing` | `—` | No tab and no row; the list is a section of the profile. |
| Administrators row and screen | `missing` | `—` | `administratorsOfChat` is only used by the member action sheet. |
| Removed / banned users screen | `missing` | `—` | No banned or restricted filter screen. |
| Linked channel row | `missing` | `—` | Not shown on a group profile. |
| Verification note and verifier tools | `missing` | `—` | Only a debug "Verify A User Or Chat" row exists. |

## Channels & Comments

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Create a channel | `partial` | ``src/Features/ChatList/Core/TGChatListCompose.m`` | Compose sheet sends `createSupergroup` with `is_channel`, then asks for a name in an alert. |
| Post as an administrator | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Composer is enabled only with `can_send_basic_messages` or `can_be_edited`. |
| Read-only channel for subscribers | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Composer is replaced by a "Join" or "Mute" stand-in. |
| Join a channel | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | `joinChat` from the bottom bar. |
| Mute the channel | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Bottom-bar button toggles mute and redraws. |
| Subscriber count | `done` | ``src/Features/Profile/Core/TGProfileHeader.m`` | Header reads "N subscribers". |
| Verified check | `partial` | ``src/Features/Profile/Core/TGProfileHeader.m`` | User check draws; channel `verification_status` is not read. |
| Channel header actions | `missing` | ``Features/Profile/TGProfileViewController+Actions.m`` | Tiles are Add/Mute/Search/More; Leave is in More; no Discussion or Voice Chat tile. |
| Channel Settings entry | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Managers open `TGGroupSettingsViewController` in channel mode. |
| Channel photo / name / description | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Editable through the same identity section as a group. |
| Public / private channel type | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Editable username switches the type. |
| Channel username management | `done` | ``src/Features/Groups/Core/TGGroupUsernames.m`` | Editable, active, disabled names; remove and disable all. |
| Public link on the profile | `partial` | ``src/Features/Groups/Core/TGGroupSections.m`` | No profile link row; the link lives in Group Settings. |
| Invite links | `partial` | ``src/Features/Groups/Core/TGGroupInvites.m`` | Alert of raw URLs and "N joined"; no dates, limits, QR or separate revoked section. |
| Subscription invite links | `done` | ``src/Features/Groups/Core/TGGroupInvites.m`` | Creates a paid subscription link. |
| Sign messages | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | `sign_messages` switch in Permissions and Behaviour. |
| Post author signature | `done` | ``Features/Chat/Rendering/TGChatViewController+Layout.m` (`stampFor:`)` | Signed posts print the signature before the views in the stamp. |
| View count on a bubble | `done` | ``Features/Chat/Rendering/TGChatViewController+Cells.m` (`placeViewsEyeIn:`)` | Eye glyph and compact count (`TGCompactCount`) before the time on every post kind; checked on the 4S on 7 November 2026. |
| Forward count | `missing` | ``Core/Model/TGMessageFlatten.m`` | `forward_count` is not flattened or drawn. |
| Message-level view statistics | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | Views and reaction graphs in the Message Info sheet. |
| Channel statistics screen | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | `getChatStatistics` rows with totals; no graphs or per-post sections. |
| Event log | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Flat list; no search, filters or event detail. |
| Affiliate program | `partial` | ``Features/BotsPayments/TGAffiliateProgramsViewController.m`` | Debug console asking for ids; no commission badge. |
| Comments / discussion thread | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Resolves `linked_chat_id` and message thread, pushes the thread. |
| Comment count on a post | `done` | ``src/Features/Chat/Actions/TGChatActionsHoldMenu.m`` | "Leave a Comment" / "Show N Replies". |
| Linked discussion group row | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Shown as "discussion" on a channel. |
| Create a discussion group | `done` | ``Features/Chat/TGChatToolsViewController.m`` | `chooseDiscussionGroup` links or creates one. |
| Discussion row with the peer name | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | "Discussion Group — Linked/None" in Chat Tools; no peer name. |
| Channel Direct Messages | `done` | ``src/Features/Groups/Core/TGGroupTools.m`` | Enables/manages the channel's DM tab and topics. |
| Direct Messages profile row | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | The "message" tile opens the channel's DM chat; the chat's bottom bar has the same button. |
| Channel admin rights | `partial` | ``Core/Client/TGClient+Groups.m`` | Promote sends the default `TGAdminRights()`; no per-administrator checkbox screen. |
| Default admin rights presets | `done` | ``Features/Groups/TGAdminRightsViewController.m`` | Group and channel defaults chosen from Telegram's presets. |
| Granular member permissions | `partial` | ``src/Features/Groups/Core/TGGroupSections.m`` | Three presets only: all, messages only, read only. |
| Slow mode | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | 0 to 1 hour presets. |
| Protected content | `done` | ``Features/Chat/TGChatToolsViewController.m`` | Toggle plus "answer protected-content request". |
| Translatable channel | `done` | ``Features/Chat/TGChatToolsViewController.m`` | Toggle and automatic translation setting. |
| Aggressive anti-spam | `done` | ``src/Features/Groups/Core/TGGroupSections.m`` | Switch plus false-positive report. |
| Channel reactions setting | `partial` | ``Features/Chat/TGChatToolsViewController.m`` | Two choices: all, or 👍 ❤️ 🔥. |
| Channel sticker set | `done` | ``src/Features/Groups/Core/TGGroupTools.m`` | `groupStickers` / custom emoji pack selection. |
| Channel accent / theme / background | `done` | ``Features/Chat/TGChatToolsViewController.m`` | Accent, profile accent, theme, background, reset. |
| Sponsored messages | `done` | ``Features/BotsPayments/TGSponsoredMessagesViewController.m`` | Channel managers can enable and inspect ads. |
| Affiliate program | `partial` | ``Features/BotsPayments/TGAffiliateProgramsViewController.m`` | Catalogue and connections exist; the entry point is a debug console. |
| Similar channels | `done` | ``src/Features/Profile/Core/TGProfileData.m`` | Row plus a list from `getChatSimilarChats`. |
| Revenue / star statistics | `dev-only` | ``src/Features/Settings/Pages/TGSettingsPagesPayments.m`` | The Premium, Stars and Gifts console is inside the `TG_DEV` debug section. |
| Channel post scheduling | `done` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | Same scheduled-send path as any chat. |
| Send As | `done` | ``src/Features/Groups/Core/TGGroupTools.m`` | Chooses the sender identity for a channel's messages. |
| Delete or leave a channel | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Owner deletes; others leave. |
| Clear channel history | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Per-chat clear with confirmation. |
| View a channel as a reader | `done` | ``src/Features/Chat/Core/TGChatViewData.m`` | Non-managers get the reader chrome and no composer. |
| Channel auto-delete timer | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | TTL applies to new messages. |
| Channel location | `done` | ``Features/Chat/TGChatToolsViewController.m`` | `setLocation` with a map point. |
| Post statistics on the bubble | `missing` | ``Core/Model/TGMessageFlatten.m`` | `viewCount` is flattened but the bubble layout never reads it. |
| Scam / fake warning | `missing` | `—` | Channel `verification_status` is not read. |
| Administrators screen | `missing` | `—` | `administratorsOfChat` is only used by the member action sheet. |
| Removed users screen | `missing` | `—` | No banned/restricted filter screen. |
| Boosts | `missing` | `—` | No channel boosts surface; calls exist only in the `TG_DEV` Stars console. |

## Voice & Video Calls (tgcalls)

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Start a 1:1 call | `done` | ``CallEngine/TGCall.mm`` | `createCall` with the supported protocol. |
| Call and video tiles respect the peer's permissions | `partial` | ``Features/Profile/TGProfileViewController+Actions.m`` | Call is gated by `can_be_called`; Video also needs `canEncodeVideoCall`, which is dev-only. |
| Incoming call ring | `done` | ``App/AppDelegate.m`` | `onIncomingCall` presents the call screen. |
| Accept a call | `done` | ``CallEngine/TGCall.mm`` | `acceptCall` then key exchange and media. |
| Hang up | `done` | ``CallEngine/TGCall.mm`` | `discardCall` with duration and connection id. |
| Call audio | `done` | ``CallEngine/Media/TGCallAudioEngine.mm`` | `VoiceProcessingIO` AudioUnit, Opus encode/decode. |
| Echo cancellation | `done` | ``CallEngine/Media/TGCallAudioEngine.mm`` | Uses `kAudioUnitSubType_VoiceProcessingIO`. |
| Mute microphone | `done` | ``CallEngine/TGCall.mm`` | Flag stops outgoing Opus frames. |
| Speaker / earpiece | `done` | ``CallEngine/TGCall.mm`` | `setSpeaker:` on the audio engine. |
| Call screen | `done` | ``Features/Calls/TGCallViewController.m`` | Avatar, name, status, timer, controls. |
| Minimise / return to call | `done` | ``Features/Calls/TGCallViewController.m`` | Shrinks to a bar and restores. |
| Call emoji key | `done` | ``Features/Calls/TGCallViewController.m`` | Shows the four-emoji key and its card. |
| Call rating after a call | `done` | ``Features/Calls/TGCallViewController.m`` | 1-5 stars, optional comment and problem list. |
| Call duration and status | `done` | ``Features/Calls/TGCallViewController.m`` | Clock plus TGCall state text. |
| Private video calls | `dev-only` | ``Core/Platform/TGCapabilities.m`` | `canEncodeVideoCall` returns NO unless `TG_DEV`. |
| Video call engine | `dev-only` | ``CallEngine/TGCall.mm`` | Camera capture, H.264 RTP, remote preview; release never enables it. |
| Local/remote video layout | `dev-only` | ``Features/Calls/TGCallViewController.m`` | Full-screen remote and corner preview. |
| Switch camera | `dev-only` | ``Features/Calls/TGCallViewController.m`` | Calls the video engine. |
| Call message in the chat | `done` | ``Core/Model/TGMessageFlatten.m`` | Direction, video flag, duration and missed state. |
| Call back from a call message | `done` | ``src/Features/Chat/Core/TGChatViewPinned.m`` | The call button on a call row starts a new call. |
| Recent calls list | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Name and a subtitle line "Outgoing/Incoming/Missed <date> - duration"; no avatar, glyph or right-aligned date. |
| All / Missed filter | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | `recentCallsFilter` filters the list; the empty state says "No missed calls". |
| Tapping a call redials | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Tap redials through `TGCallViewController`; there is no info control or call-details screen. |
| Missed calls labelled "Missed" | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | `typeLabel` is "Missed" for a missed call and the row is destructive. |
| Call history paging | `missing` | ``src/Core/Client/Account/TGClient+AccountTwoStep.m`` | One `searchCallMessages` request for 50; `next_offset` is not followed. |
| Empty call list | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | A plain "No recent calls" / "No missed calls" row. |
| Optional Calls tab | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Switch in Recent Calls; `RootViewController` builds the tab when enabled. |
| Call log and debug diagnostics | `dev-only` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Inside `#if TG_DEV`; the release list has no diagnostics. |
| Clear call history | `done` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Account-wide `clearAllCallMessages`. |
| Group call screen | `done` | ``Features/Calls/TGGroupCallViewController.m`` | State, duration, participants, messages, tools. |
| Join / leave a group call | `done` | ``Features/Calls/TGGroupCallViewController.m`` | Join returns the payload; Leave clears it. |
| End a group call | `done` | ``Features/Calls/TGGroupCallViewController.m`` | Confirmed end for the owner/admin. |
| Group-call participant list | `done` | ``Features/Calls/TGGroupCallViewController.m`` | Avatars, speaking, hand, mute, video, volume state. |
| Participant mute / volume / hand / ban | `done` | ``Features/Calls/TGGroupCallParticipantsViewController.m`` | Per-person actions gated by the server flags. |
| Invite participants | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | `inviteVideoChatParticipants`, one or many. |
| Invite link and revoke | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Get, copy, revoke. |
| Decline an invitation | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Takes the invitation message id. |
| Group-call messages | `done` | ``Features/Calls/TGCallMessagesViewController.m`` | Send, list, delete one, delete all from a sender. |
| Group-call audio | `missing` | ``Features/Calls/TGGroupCallViewController.m`` | The screen says it has no group-call audio engine; no join media. |
| Create a video chat | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Title, start date, video or RTMP. |
| Create a standalone group call | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | `createGroupCall` without a chat binding. |
| Schedule a video chat | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Start Scheduled before the call begins. |
| Default participant | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Server-provided sender list. |
| Video-chat title / messages / mute-new / start notification | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Each switch sends its own flag and reads back. |
| Start / end recording | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Audio, video landscape, video portrait, then stop. |
| RTMP URL get / replace | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Shows and copies URL plus key; replace asks first. |
| Screen sharing start / pause / resume / stop | `done` | ``Features/Calls/TGVideoChatSetupViewController.m`` | Sends the join payload and audio source. |
| Stream channels and segments | `done` | ``Features/Calls/TGVideoChatStreamViewController.m`` | Lists streams, fetches bytes, encrypt/decrypt samples. |
| Encrypt / decrypt group-call payload | `done` | ``Core/Client/TGClient+GroupCalls.m`` | Through `encryptGroupCallData` / `decryptGroupCallData`. |
| Mark myself speaking | `done` | ``Core/Client/TGClient+GroupCalls.m`` | `setGroupCallParticipantIsSpeaking`. |
| Group-call join payload | `done` | ``Core/Client/TGClient+GroupCalls.m`` | `joinGroupCall` returns TDLib's payload; nothing decodes it. |
| Video-chat participants in the chat profile | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | Calls row opens the call screen. |
| Phone-to-phone call acceptance | `missing` | ``CallEngine/TGCall.mm`` | libtgvoip rings, but modern Telegram iOS rejects this client's version. |
| New Call row | `missing` | `—` | No action row; the list starts with the Show Calls Tab switch. |
| Active group calls above Recent Calls | `missing` | `—` | No group-call rows in Recent Calls. |
| Calls tab rows | `missing` | `—` | The optional Calls tab reuses the same subtitle list. |

## Settings & Appearance

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Root list | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Profile card, account rows, app settings, help, This Device, Log out. |
| Settings tab icon is the account photo | `missing` | ``App/RootViewController.m`` | Always the sliders glyph; no badge or avatar. |
| Settings search | `missing` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | No search field or page index. |
| Accounts switcher | `partial` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Four account slots | `partial` | ``Core/Client/TGClient+Accounts.m`` | Three slots for every account. |
| My Profile row | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Opens the account's own profile. |
| Account header | `partial` | ``Features/Settings/TGSettingsViewController.m`` | 80 pt avatar in a 168 pt cell, 22 pt name, phone only. |
| QR and Edit bar items | `missing` | ``Features/Settings/TGSettingsViewController.m`` | No root bar items. |
| Top edit block | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | One "My Profile" row and a separate Edit form; Emoji Status is its own row. |
| Emoji Status | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Shown to every account in the account card; the picker exists. |
| Saved Messages | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Opens the saved-messages chat. |
| Recent Calls page | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Filter and redial exist; no New Call row; rows are subtitle-only. |
| Devices / sessions | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Pushes `TGSessionsViewController`; rows show app name + platform + IP. |
| Devices row value | `partial` | ``Features/Settings/TGSettingsViewController.m`` | "N active" counts only other sessions. |
| Chat Folders page | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Most editing exists; counts are behind a "Chat Count" alert and creation is the last row. |
| Folder rows | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Names only; count is not printed on the row. |
| My Stories | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Opens the profile's Stories tab. |
| Proxy | `done` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Add, enable, edit and remove proxies. |
| Proxy row value | `partial` | ``Features/Settings/TGSettingsViewController.m`` | Shows the server hostname or "On"/"Off"; the row is always present. |
| Notifications and Sounds | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Three mute and three preview switches, exceptions, sounds, reset; no category pages or badge section. |
| Notification warning badge | `missing` | ``Features/Settings/TGSettingsViewController.m`` | No badge or warning. |
| Privacy and Security | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Security, six rules, messages, close friends, contacts, account status, payments, link. |
| Data and Storage | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | All pages exist; File Tools and the network state page are still on the user's path. |
| Appearance | `partial` | ``Features/Settings/TGSettingsViewController+AppearancePages.m`` | Themes (light and dark official files), text size, wallpaper, defaults, emoji themes and Your Color; no Auto-Night, bubbles or icons. |
| Power Saving | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Sticker animation, wallpaper, GIF autoplay and media preloading; no master or threshold. On Vintage (iPod touch 4, 3GS) the page keeps only Autoplay GIFs: that tier shows still stickers and no chat wallpaper whatever the switches say, and Settings > Device says so (19 November 2026). |
| Language | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Pack picker changes TDLib's language; the app's own ~2200 strings stay English. |
| Language row value | `partial` | ``Features/Settings/TGSettingsViewController.m`` | Uses the pack's `name`, never `native_name`. |
| Language pack tools | `dev-only` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | The string editor lives on the dev language page. |
| Stickers and Emoji | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Opens pack management. |
| Telegram Premium | `partial` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Reads the state and explains that purchase happens in an official client. |
| Send a Gift | `missing` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | No release row; the gift console is `TG_DEV`. |
| Telegram Business | `done` | ``Features/Settings/TGSettingsViewController+Tier2.m`` | Opens `TGBusinessViewController`. |
| Business and Premium gating | `missing` | ``Features/Settings/TGSettingsViewController+Tier2.m`` | Business row is always present. |
| Help rows | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Ask a Question, FAQ, Features, Privacy Policy, Get the App; no Tips. |
| Ask a Question intro | `missing` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Opens the support chat immediately. |
| Telegram FAQ in-app | `missing` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Opens `https://telegram.org/faq` in Safari. |
| This Device | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Tier, software, hardware and per-feature availability. |
| Log out | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Confirmation, then `logOut`. |
| Section order | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Header, account card, chat/device card, proxy, app settings, stickers, Premium/Business, Help, This Device, Log out. |
| No duplicate Chat Themes row | `missing` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | "Stickers and Emoji" exists; no duplicate "Chat Themes" now, so the row is gone. |
| Appearance preview | `partial` | ``Features/Settings/TGSettingsViewController.m`` | Two hardcoded lines with a gradient; no reply, sender or date. |
| Theme list | `partial` | ``Features/Settings/TGSettingsViewController+AppearancePages.m`` | Check rows: Classic plus `.tgios-theme` files; no thumbnails or built-in cards. |
| Chat theme picker | `partial` | ``Features/Settings/TGSettingsViewController+AppearancePages.m`` | Lists emoji themes and opens a read-only detail alert; no way to apply one. |
| Accent colour chooser | `partial` | ``Features/Profile/TGProfileAppearanceViewController.m`` | Swatch screen exists for profile/name colour; no background/accent/messages preview. |
| Chat background page | `done` | ``Features/Settings/TGBackgroundsViewController.m`` | Local texture list, server list, and custom color/gradient editor. |
| Background colour, gradient and pattern | `done` | ``Features/Settings/TGBackgroundEditorViewController.m`` | Full color and linear gradient wallpaper editor with live bubble preview and palette presets. |
| Photo wallpaper crop, blur and motion | `partial` | ``Features/Settings/TGSettingsViewController+AppearancePages.m`` | One image picker scaled to 640 px and saved as JPEG; no crop, blur or motion. |
| Your Color row | `done` | ``Features/Settings/TGSettingsViewController+AppearancePages.m`` | One "Your Color" row opens the profile appearance screen. |
| Night Theme and Auto-Night | `partial` | ``Core/Style/TGTheme.h`` | A dark official theme file applies (`isDark`, `9c93e8f`) and Night Blue is built in; no Auto-Night. |
| Bubble corners editor | `missing` | ``Core/Style/TGTheme+Effects.m`` | Fixed radius; `TGMetricCornerBubbleFlat` is never used. |
| Folder editor | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Eight-item action sheet plus add/remove chats; no excluded-read/muted/archived or tag colour. |
| Sticker and emoji settings | `missing` | ``Features/Media/TGStickerPacksViewController.m`` | Sticker page is packs, archive and custom emoji only. |
| Quick reaction setup | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | "Default Reaction" opens the fixed seven-emoji picker; no demo or current-reaction row. |
| Reaction notifications | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | One "Message Reactions" switch; story and poll sources are not exposed. |
| Quick reply list | `partial` | ``Features/Chat/TGQuickRepliesViewController.m`` | Plain rows with a count and preview; no slash name or inline creation. |
| Text size | `partial` | ``Features/Settings/TGSettingsViewController+Actions.m`` | 13/15/17/19 pt; only chat text changes. |
| Sticker pack rows | `partial` | ``Features/Media/TGStickerPacksViewController.m`` | Subtitle row with short name, count and type; no sticker artwork. |
| Root wording | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Root has "Stickers and Emoji"; the sticker page is titled "Stickers". |
| Settings navigation bar | `partial` | ``Features/Settings/TGSettingsViewController.m`` | Hides on scroll down and is not restored in `viewWillAppear:`. |
| Dark background editing | `partial` | ``Features/Settings/TGBackgroundsViewController.m`` | A "Dark Theme Backgrounds" switch picks the dark list by hand instead of following the active theme. |
| Telegram Defaults presentation | `partial` | ``Features/Settings/TGSettingsViewController+AppearancePages.m`` | Alerts print raw ids and type names. |
| Design: iOS 7+ navigation bar | `missing` | ``Core/Style/TGTheme.m`` | Blue `#517DA2` bar with white title on every OS. |
| Design: iOS 7+ tab bar | `missing` | ``Core/Style/TGTheme.m`` | `barTintColor` and `tintColor` are both `#517DA2`. |
| Design: accent and values | `missing` | ``Core/Style/TGTheme+Colours.m`` | Accent `#517DA2`; values `#51AEE7`. |
| Design: text and separators | `missing` | ``Core/Style/TGThemeInternal.h`` | Text `#222222`, separators `#E1E4E9`. |
| Design: section headers and footers | `missing` | ``Features/Settings/TGSettingsViewController.m`` | UIKit uppercase headers; plain string footers with no links. |
| Design: Settings row rhythm | `missing` | ``Core/Style/TGStyle+Metrics.h`` | 44 pt system row, 15 pt gutter. |
| Design: profile header and actions | `partial` | ``Features/Profile/TGProfileViewController.m`` | 80 pt avatar, 22 pt name; up to six equal plates. |
| Design: profile details | `partial` | ``src/Features/Profile/Core/TGProfileHeader.m`` | Custom cell with smaller type; bio wraps. |
| Design: shared-media tabs | `partial` | ``src/Features/Profile/Core/TGProfileDetails.m`` | Scrollable strip exists; type and selection treatment differ. |
| Design: contact rows | `partial` | ``Features/Contacts/TGContactsViewController.m`` | 56 pt rows, 15 pt name, disclosure chevron. |
| Design: avatars | `partial` | ``Views/Icons/TGIcons+Avatars.m`` | One flat colour plus a white oval on every OS. |
| Design: badges | `partial` | ``UI/Controls/TGBadge.m`` | 18 pt glossy bevel, 13 pt bold. |
| Design: large buttons | `partial` | ``UI/Controls/TGButton.m`` | 44 pt high, 8 pt corner, 15 pt bold, etched gloss. |
| Design: empty state | `partial` | ``UI/Overlays/TGEmptyView.m`` | 64 pt icon, 22 pt bold title, 160×36 glossy button. |
| Design: Settings icons | `partial` | ``Views/Icons/TGIcons+Menu.m`` | Some rows share glyphs and a few fall back to the wrong shape. |
| Design: profile has no "Info" title | `missing` | ``Features/Profile/TGProfileViewController.m`` | Every profile and group says "Info" in the bar. |
| Design: iOS 7+ section insets | `missing` | ``Core/Style/TGTheme.m`` | Full-bleed grouped table on every OS. |
| Stars row | `missing` | `—` | No row; a read-only console is in the `TG_DEV` debug section. |
| Telegram Tips | `missing` | `—` | No row. |
| Language translation controls | `missing` | `—` | Language page is a pack inspector only. |
| Show next media on tap | `missing` | `—` | No media setting. |
| App icon picker | `missing` | `—` | No picker; iOS 6 has no alternate-icon API. |
| Settings row badges | `partial` | ``Features/Settings/TGSettingsViewController.m`` | No "New", red "!" or device-count badge model; the notification warning is missing too. |

## Privacy & Security

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Passcode row at the top of Security | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Passcode Lock is the first Security row; the page has on/off/change and auto-lock. |
| Passcode on / off / change | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | 4-digit code with a confirmation step. |
| Auto-lock timeout | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Immediately, 1 min, 5 min, 1 hour or disabled. |
| Lock icon on the chat list | `done` | ``src/Features/ChatList/Core/TGChatListHeader.m`` | Tap locks immediately; the button exists only when a passcode is set. |
| Lock on launch / foreground | `done` | ``App/AppDelegate.m`` | Unlock sheet after launch and when `shouldLockOnForeground`. |
| Touch ID / Face ID | `missing` | ``Core/Platform/TGPasscode.h`` | No `LAContext` or biometric path anywhere. |
| Wrong-passcode data wipe | `missing` | ``Core/Platform/TGPasscode.m`` | Attempts are counted for the shake only; no erase option. |
| Two-step verification | `done` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Set, change, recovery address, turn off, forgot password. |
| Two-step screen detail | `partial` | ``Core/Client/TGClient+Auth.m`` | `getPasswordState` is reduced to a BOOL plus "set"; hint and `pending_reset_date` never reach the user. |
| Login email address | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Set, verify, resend, remove. |
| Login Email row value | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | The row exists with a nil detail, so it looks unset even when set. |
| Change phone number | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Code flow across the auth states. |
| Temporary password | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Create a one-time password for another device. |
| Application verification | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Shows required/none and submits the code. |
| Current session | `partial` | ``Features/Settings/TGSessionsViewController.m`` | Title is `application_name`, subtitle platform + IP; model, location and last active are dropped. |
| Other sessions | `done` | ``Features/Settings/TGSessionsViewController.m`` | Each row opens sign-out and its call/secret-chat switches. |
| Session row detail | `partial` | ``src/Core/Client/Account/TGClient+AccountPeople.m`` | `device_model`, `location` and `last_active_date` are never shown. |
| Terminate one session | `done` | ``Features/Settings/TGSessionsViewController.m`` | Confirms then `terminateSession`. |
| Terminate all other sessions | `done` | ``Features/Settings/TGSessionsViewController.m`` | `terminateAllOtherSessions`. |
| Inactive session timeout | `done` | ``Features/Settings/TGSessionsViewController.m`` | 1 week to 1 year. |
| Connected websites | `done` | ``Features/Settings/TGWebsitesViewController.m`` | Per-site sign-out and sign out all. |
| QR scanner for login links | `done` | ``Features/Settings/TGSessionsViewController.m`` | Camera scanner opens a t.me link. |
| Blocked users list | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Plain text names only; no add, no avatars; tapping unblocks immediately. |
| Blocked users count | `missing` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | The row has no detail value. |
| Block a person | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | From the profile's More menu. |
| Last Seen privacy | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Three choices only; no exception lists. |
| Profile photo privacy | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Three choices only; no public-photo row. |
| Phone number privacy | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Three choices only; `AllowFindingByPhoneNumber` is never read. |
| Calls privacy | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Three choices only; no P2P rule. |
| Group invite privacy | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Group Invites is one of the six three-choice rows. |
| Forwarded-message link privacy | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Forwarded Messages is one of the six three-choice rows. |
| Birthday privacy | `done` | ``Features/Profile/TGEditProfileViewController.m`` | Birthday privacy is chosen in Edit Profile. |
| Bio privacy | `missing` | ``Features/Profile/TGEditProfileViewController.m`` | No Bio row in Privacy and no line under the field. |
| Gifts privacy | `missing` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | No who-may-send, gift button or accepted-types rows. |
| Voice message privacy | `missing` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | No row for who may send voice messages. |
| Added-by-phone privacy | `missing` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | No row for finding the account by phone. |
| Privacy exception lists | `done` | ``Features/Settings/TGPrivacyRuleViewController.m`` | Dedicated privacy rule screen with Always Allow / Never Allow contact pickers and live TDLib sync. |
| Privacy row order and wording | `partial` | ``Features/Settings/TGSettingsViewController.m`` | Six rows: Last Seen, Photo, Phone, Calls, Invites, Forwards. |
| Read receipts | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | A top-level Read Receipts switch in the Messages card. |
| Delete messages by default | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Four fixed choices; any other server value prints plain days, no custom picker. |
| Messages from unknown users | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | One boolean switch; no Premium state or Stars price row. |
| Personal chat | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Choose a personal chat. |
| Inactive groups | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | List and leave. |
| My public chats | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Lists public chats. |
| Close friends | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Picker and count. |
| Close birthdays | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | The row calls `hideContactCloseBirthdays` instead of showing the list. |
| Suggest frequent contacts | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Writes `disable_top_chats`. |
| Delete synced contacts | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Confirmed `clearImportedContacts`. |
| Data sub-screen | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Delete Synced Contacts here; Clear Drafts lives in Data and Storage; no payment-info or secret-chat link-preview row. |
| Freeze state | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Dates, appeal link, open appeal. |
| Subscription state | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Reads the account's subscription record. |
| Age verification | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Shows the parameters Telegram sent. |
| reCAPTCHA request | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Shows the request and says the app has no web view; no solving path. |
| Verify an email address | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Send code, enter it, store the address. |
| Orders and payment data | `partial` | ``src/Features/Settings/Pages/TGSettingsPagesPayments.m`` | Read-only saved checkout; card lookup and offer tools are `TG_DEV`. |
| Delete saved payment credentials | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Account-wide confirmed delete. |
| My link | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Copies the account's t.me link. |
| Protected content flag | `done` | ``Features/Chat/TGChatToolsViewController.m`` | Copy/forward/save are blocked in a protected chat; no screenshot guard. |
| Session secret-chat and call switches | `done` | ``Features/Settings/TGSessionsViewController.m`` | Per-session accept calls / accept secret chats. |
| Storage: KEEP MEDIA per peer type | `missing` | ``Features/Settings/TGStorageViewController.m`` | The page is ring + categories + one Clear Cache row. |
| Storage: maximum cache size | `missing` | ``Features/Settings/TGStorageViewController.m`` | No maximum-cache row. |
| Storage: category rows and selection | `partial` | ``Features/Settings/TGStorageViewController.m`` | Tapping a category clears that whole type after a sheet; no selection or per-type clear button. |
| Storage: chats view and per-chat exceptions | `missing` | ``Features/Settings/TGStorageViewController.m`` | No chats view and no per-chat exceptions. |
| Storage: category split and colours | `partial` | ``Core/Client/TGClient+Files.mm`` | Five buckets plus Other; profile photos and thumbnails sit inside Photos. |
| Clear Cache amount | `partial` | ``Features/Settings/TGStorageViewController.m`` | "Clear Cache" plus the ring total; sends empty `file_types`, so TDLib keeps thumbnails, profile photos, stickers and wallpapers. |
| Data & Storage summaries | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Storage Usage row is nil; Network Usage reads "X in, Y out". |
| Network Usage screen | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | One "X in, Y out" row with a reset confirm. |
| Per-connection auto-download | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | One preset picker plus two network switches. |
| Auto-download summary | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Always prints "Medium" because it reads `presets[@"medium"]`. |
| Mobile/Wi-Fi caps | `partial` | ``Core/Client/TGClient+Files.mm`` | `setAutoDownloadOverMobile` rewrites the caps to 10 MB. |
| Autosave per peer type | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Three sections of two switches; exceptions are read-only "Chat" plus a raw id. |
| Autosave exception rows | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Raw ids, no add or remove. |
| Archive and mute non-contacts | `partial` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Lives in Data and Storage instead. |
| Custom sounds assignment | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Sounds can be added and removed; no row assigns one. |
| Incomplete login attempts | `missing` | `—` | `is_password_pending` is never read; only `is_unconfirmed` is shown. |
| Saved music privacy | `missing` | `—` | `userPrivacySettingShowProfileAudio` is not used. |
| Passkeys | `missing` | `—` | No passkey screen; the calls exist only in the `TG_DEV` bot console. |
| Badge section | `missing` | `—` | No badge settings. |
| In-app notifications | `missing` | `—` | Previews per scope only; no in-app sound, vibration or lock-screen name. |
| Notification permission banner | `missing` | `—` | The page never says notifications are denied. |
| Automatic power saving | `missing` | `—` | Only manual switches; no battery threshold. |
| Contact joined Telegram | `missing` | `—` | Not present. |

## Notifications & Keep-Alive

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Notification scopes | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Three mute switches under "Show notifications for". |
| Message previews per scope | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Three preview switches in a second card. |
| Category sub-pages | `missing` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Switches only; no pushed category page. |
| Notification exceptions list | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | List exists, but every row opens the chat rather than showing mute/sound/preview state. |
| Per-chat notification settings | `partial` | ``Core/Client/Chats/TGClient+ChatFolders.mm`` | Muting a chat sends only `mute_for`; the other fields fall back to defaults. |
| Scope settings preserve fields | `partial` | ``src/Core/Client/Account/TGClient+AccountCore.m`` | `updateScope:` sends only `mute_for`, `sound_id` and `show_preview`; story and mention flags are dropped. |
| Custom sounds list | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Add from bundle or MP3, play, inspect, remove. |
| Assign a custom sound | `missing` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | A sound can be added and removed, but no row assigns one. |
| Message reactions | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Switch, default reaction and clear recent. |
| Reaction source detail | `partial` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | One "Message Reactions" switch; story and poll sources are not exposed. |
| Story notifications | `done` | ``Features/Stories/TGStorySettingsViewController.m`` | Per-chat story notification exceptions. |
| Reset all notifications | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Confirmed `resetAllNotificationSettings`. |
| Active Notifications | `dev-only` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | The screen is reachable only from the `TG_DEV` debug section. |
| In-app notification banner | `missing` | ``Features/Settings/TGActiveNotificationsViewController.m`` | Only the Active table; no banner while using the app. |
| Notification warning badge | `missing` | ``Features/Settings/TGSettingsViewController.m`` | No badge or warning. |
| Push registration | `done` | ``Core/Client/TGClient+Auth.m`` | `registerDevice` on sign-in; needs the APNs certificate to deliver. |
| Push opens the chat | `done` | ``Core/Client/TGClient+Auth.m`` | `processPushNotification` and `getPushReceiverId` route to the chat and message. |
| Push payload privacy | `partial` | ``Core/Client/TGClient+Auth.m`` | The token is registered; the payload privacy is TDLib's and is not tested here. |
| Pinned and mention flags | `partial` | ``Core/Client/Chats/TGClient+ChatFolders.mm`` | Muting replaces the record with two fields, so mention and pinned flags reset. |
| Add an exception | `missing` | `—` | No Add Exception action. |
| Notification permission banner | `missing` | `—` | The page never says notifications are denied. |
| Badge settings | `missing` | `—` | No badge section. |
| In-app sounds and vibration | `missing` | `—` | Previews are server-synced; no in-app sound or vibration setting. |
| Display names on the lock screen | `missing` | `—` | No lock-screen presentation setting. |
| Contact joined Telegram | `missing` | `—` | No switch; TDLib has no server-side field for it. |
| Muted-until wording | `missing` | `—` | The exception list has no state words; rows say "Open". |

## Authentication & Multi-Account

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Sign in by phone and code | `done` | ``Features/Auth/TGLoginViewController+Steps.m`` | Phone, code and password steps are driven by `authorizationStateWait*`. The keyboard closes on a drag or a tap on empty space (`TGKeyboardDismissal`, shared with every TGTableViewController screen); on iOS 6 the phone pad had no way to close. Not host-testable (UIKit gestures). |
| Launch screen | `done` | ``App/TGAuthRoute.m`` | A slot that never reached `authorizationStateReady` starts on a spinner, not the chat list, until TDLib names the step (~1 s); Log Out waits on the same spinner for the next client's phone step. Dev builds keep the showcase chats. B36 covers the signed-out route. |
| Country and phone prefix | `done` | ``Features/Auth/TGCountryPickerViewController.m`` | The Country row pushes official's list: search bar, every country A-Z under letter headers with the index, flag, name and code; it replaced a search alert that listed at most 20 matches. `getCountryCode` preselects; signed out, the guessed country is named from `getCountries`: `getCountry` is 401 before authorization (B38). |
| Sign-up name | `done` | ``Features/Auth/TGLoginViewController+Steps.m`` | `registerUser` with first and last name and the terms text. |
| Terms of service | `done` | ``Features/Auth/TGTermsViewController.m`` | Terms screen; Accept sends `acceptTermsOfService`. |
| Two-step verification password | `done` | ``Core/Client/TGClient+Auth.m`` | `checkAuthenticationPassword`, hint and email recovery steps. |
| Forgot password | `done` | ``Core/Client/TGClient+Auth.m`` | `requestPasswordRecovery`, `checkAuthenticationPasswordRecoveryCode`, `recoverPassword`; hint shown. |
| Email address step | `done` | ``Features/Auth/TGLoginViewController+Steps.m`` | `authorizationStateWaitEmailAddress` / `WaitEmailCode` have steps. |
| QR login | `done` | ``Features/Auth/TGLoginViewController+Steps.m`` | "Log in by QR Code" under the phone step again (official iOS keeps it behind DEBUG; removed in the 8 November parity wave, restored on request); `requestQrCodeAuthentication`, the QR step draws a locally generated code. The QR step no longer offers "QR Code" to paste a link: that is `confirmQrCodeAuthentication`, which TDLib refuses with 401 before sign-in. |
| Scan a QR link | `done` | ``Features/Auth/TGQRViewController.m`` | Camera scanner confirms through `confirmQrCodeAuthentication`. |
| Web login token | `missing` | ``Core/Stores/TGAccountStore+Auth.m`` | `checkAuthenticationWebToken` is in the store, but no login row ever opened it; the unreachable handler was removed. |
| Firebase-delivered SMS code | `done` | ``Core/Client/TGClient+Auth.m`` | `sendAuthenticationFirebaseSms`. |
| Login with Telegram (OAuth) | `dev-only` | ``Core/Client/Audit/TGClient+OAuth.m`` | Only in the `TG_DEV` bot console; `updateNewOauthRequest` has no release screen. |
| Passkeys | `dev-only` | ``Core/Client/TGClient+BotSession.m`` | The calls are in the `TG_DEV` bot console; iOS 6 cannot produce an attestation. |
| Change phone number | `done` | ``Core/Client/TGClient+Auth.m`` | `sendPhoneNumberCode`, `checkPhoneNumberCode`, resend and missing-code report. |
| Temporary password | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | `getTemporaryPasswordState` and `createTemporaryPassword`. |
| Application verification | `done` | ``Features/Settings/TGSettingsViewController+PrivacyPages.m`` | Required/none state and `setApplicationVerificationToken`. |
| Login email | `done` | ``Core/Client/TGClient+Auth.m`` | `setLoginEmailAddress` and `checkLoginEmailAddressCode`. |
| Accounts switcher | `partial` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Account slots | `partial` | ``Core/Client/TGClient+Accounts.m`` | Three slots for every account; each slot has its own TDLib directory. |
| Add Account | `done` | ``Features/Settings/TGSettingsViewController+Actions.m`` | `Add Account` creates a slot and switches to it. |
| Switch account | `done` | ``Core/Client/TGClient+Accounts.m`` | `switchToAccountSlot:` restarts the client on that slot's database. |
| Notifications for inactive accounts | `done` | ``Features/Settings/TGSettingsViewController+Actions.m`` | The sheet says so explicitly; only the active slot runs TDLib. |
| Log out | `done` | ``src/Features/Settings/Pages/TGSettingsPagesCore.m`` | Confirmation, then `logOut`. |
| Delete account | `done` | ``Features/Settings/TGSettingsViewController+Actions.m`` | Delete Account row with reason and password. |
| Current session | `partial` | ``Features/Settings/TGSessionsViewController.m`` | Row shows app name and platform; model, location and last active are dropped. |
| Other sessions | `done` | ``Features/Settings/TGSessionsViewController.m`` | Current and other sessions, terminate one or all. |
| Unconfirmed session | `done` | ``Features/Settings/TGSessionsViewController.m`` | Offers Confirm beside Sign Out and sends `confirmSession`. |
| Inactive session timeout | `done` | ``Features/Settings/TGSessionsViewController.m`` | 1 week to 1 year through `setInactiveSessionTtl`. |
| Connected websites | `done` | ``Features/Settings/TGWebsitesViewController.m`` | Per-site sign-out and sign out all. |
| Proxy at sign-in | `done` | ``Features/Settings/TGSettingsViewController+NetworkPages.m`` | Proxy can be added and enabled; TDLib uses it for auth too. |
| Auth errors as sentences | `partial` | ``Core/Client/TGClient.m`` | Core passes `result[@"message"]` up, so alerts contain TDLib's own text. |

## Bots, Stars & Payments

| Feature | State | Component / Source | Notes |
|---|---|---|---|
| Bot reply keyboard | `done` | ``Features/Chat/Composer/TGChatViewController+Bots.m`` | Keyboard rows/one-time/placeholder are drawn and send text. |
| Bot inline buttons | `partial` | ``Features/Chat/Composer/TGChatViewController+Bots.m`` | Web App, Pay, Game and password callbacks answer "needs a newer Telegram". |
| Inline bot mode (`@bot query`) | `missing` | ``Features/Chat/Composer/TGChatViewController+Bots.m`` | Switch-inline only types the mention; no inline result list or `sendInlineQueryResult`. |
| Bot Web Apps | `missing` | ``Features/Dev/TGDevBotConsoleViewController.m`` | No Web App host; the console copies the URL. |
| Bot info card | `partial` | ``src/Core/Client/Account/TGClient+AccountLocalNotifications.m`` | Short description can stand in for a missing bio; no commands or Add to Chat. |
| Bot commands and menu button | `dev-only` | ``Features/Dev/TGDevBotConsoleViewController.m`` | `getCommands` / `setCommands` / `getMenuButton` are console rows, not a bot settings screen. |
| Owned bots | `done` | ``Features/Profile/TGProfileViewController+Actions.m`` | A bot profile's Bot Settings opens `TGDevBotConsoleViewController`; name, description, photo and similar bots are rows. |
| Guest bots | `missing` | ``Core/Model/TGMessageFlatten.m`` | `guest_bot_caller_id` is not parsed. |
| Bot verification | `dev-only` | ``Features/Dev/TGDevBotConsoleViewController.m`` | Debug "Verify A User Or Chat" row only. |
| Invoices | `partial` | ``Core/Model/TGMessageContentCommerce.m`` | Card draws; the Pay button is removed because there is no payment form. |
| Paid media | `partial` | ``Features/Chat/Composer/TGChatViewController+MediaCells.m`` | Blur and price show; tapping says Stars are unavailable. |
| Paid messages | `missing` | ``Features/Chat/Composer/TGChatViewController+Input.m`` | No price row or `paid_message_star_count` send option. |
| Premium state | `partial` | ``src/Core/Client/Account/TGClient+AccountPeople.m`` | Reads `getPremiumState`; the Settings row reports Active or not in an alert. |
| Gift catalogue | `dev-only` | ``Core/Client/Audit/TGClient+Gifts.m`` | `getAvailableGifts` is a read-only console row. |
| Gift notes and signatures | `missing` | ``Core/Client/Account/TGClient+AccountSupport.m`` | The flatten reads the wrong key, so the note is blank. |
| Giveaways | `partial` | ``Core/Model/TGMessageCard.m`` | Cards and winner lists draw; creating or joining a giveaway is not built. |
| Affiliate programs | `partial` | ``Features/BotsPayments/TGAffiliateProgramsViewController.m`` | Catalogue and connections exist behind a debug entry; no commission badge. |
| Revenue statistics | `dev-only` | ``src/Features/Settings/Pages/TGSettingsPagesPayments.m`` | Read-only rows in the `TG_DEV` Stars console. |
| Saved orders and payment data | `partial` | ``Core/Client/TGClient+Payments.m`` | `getSavedOrderInfo` / `deleteSavedOrderInfo` work; card lookup and offers are `TG_DEV` read-only rows. |
| Bank card lookup | `dev-only` | ``Core/Client/TGClient+Payments.m`` | `getBankCardInfo` is a console row; no release surface. |
| Suggested-post price | `dev-only` | ``Core/Client/TGClient+Payments.m`` | `addOffer` is in the payment dev page. |
| Order validation | `dev-only` | ``Core/Client/TGClient+Payments.m`` | `validateOrderInfo` is a sequence of debug alerts. |
| Pay an invoice | `missing` | `—` | `getPaymentForm` and `sendPaymentForm` are never sent; no StoreKit or provider. |
| Paid reactions | `missing` | `—` | No paid-reaction request or price sheet. |
| Stars balance | `missing` | `—` | No release row; `getStarTransactions` is read only in the `TG_DEV` console. |
| Star subscriptions | `missing` | `—` | No surface. |
| Premium purchase | `missing` | `—` | The Settings row reads the state and says purchase happens in an official client. |
| Send a gift | `missing` | `—` | No release row or send path; `sendGift` is never called. |
| Gift collections | `missing` | `—` | `getGiftCollections` and the collection calls are never sent. |
| Gift auctions and resale | `missing` | `—` | All auction and resale calls are absent. |
| Boosts | `missing` | `—` | No release surface; `getChatBoostStatus` and `boostChat` are read only in the `TG_DEV` console. |
| TON wallet | `missing` | `—` | All 43 wallet, on-ramp and NFT functions are never sent. |
| Passport | `missing` | `—` | All 8 Passport functions are never sent; no capture or 2FA vault. |
| StoreKit purchases | `missing` | `—` | No StoreKit linkage; `canPurchaseFromStore` and `assignStoreTransaction` are never sent. |
| Refund a Star payment | `missing` | `—` | `refundStarPayment` and `editUserStarSubscription` are never sent. |
| Gift privacy | `missing` | `—` | No who-may-send, button or accepted-types rows; `setGiftSettings` is never sent. |


## Unified UI (bar buttons, modals, menus)

Screens in `src/Features` ask `src/UI` for a bar button by role (`TGBarItem`) and open things through `TGPresent`; the action → presentation table is in `docs/DESIGN_SPEC.md`. Counts are `scripts/ui_ownership.txt`, presents in all files and controls in queue files.

| Step | presents | controls (queue) |
|---|---|---|
| Start, fbb5a97e | 143 | 68 |
| Bar buttons, batch 1: 27 places in 22 files (Cancel, Done, Edit, Close, Add, named actions) | 116 | 68 |
| Bar buttons, batch 2: 16 edits in 12 files (chat list Edit/Done and edit bar, profile Edit, selection, Instant View ⋯ and share, albums, login Next, two spinners) | 97 | 66 |
| System pickers: share sheets (4) and photo pickers (12) through `TGPresent`, the library and share sheet in a popover on iPads before iOS 8 | 75 | 66 |
| Bar buttons, batch 3: 21 edits in 15 files (picker toolbars, attach sheet, login Cancel, compose, media search, dev screens) | 46 | 66 |
| Approved list: Done bold after Edit (Usernames, Backgrounds, group names); New Contact Cancel / Done; Close on the left of read-only modals (file info, QR, a screen opened from a group without a stack); system + in Topics; magnifier in Text Styles; Instant View and album ⋯ open the drawn menu under the button | 46 | 66 |
| Modals: 13 hand-built navigation controllers through `TGPresent presentModal:` (forms get Cancel, read-only pages Close, story viewers and the player stay bare); custom-view bar items through `TGBarItem itemWithView:`; camera and dev flows through `presentFlow:` | 1 | 66 |
| Controls: text by role (`TGLabel`: title, header, caption, bar title…), buttons, reader and editor text views, the key catcher, switch, step slider, spinner and the two motion speeds in `TGControls`; bar and content segments in `TGSegmentedControl.h`; the story ring as `TGBarRoleAddStory`; a table's loading spinner in `TGTableViewController showLoading`. The queue in `scripts/ui_ownership.txt` is empty | 1 | 0 |
| Action menus on an object (long press on a chat, profile More, a member, a topic, a scheduled message, a task, an invite or folder link, a download, a proxy, a sound, a sticker, a held photo, …): 27 system action sheets became the drawn card under the row through `TGPresent showMenuTitles:` / `showMenu:atPoint:`; the row glyph comes from the first word (`TGMenuGlyphForTitle`) | 1 | 0 |
| Lists shown as a sheet (poll voters, message positions, public forwards, reactions, recent locations, Saved tags, invite links and their members, member search, join requests, community chats, a file's sticker sets, sent files, folder links): 17 sheets became a pushed list of rows through `TGPresent showList:` ("Name · detail" splits into a title and the row's detail on the right, `TGListEntries`) | 1 | 0 |
| The pencil opens New Message: New Group and New Channel above the contacts, as official's compose screen (was a three-item sheet). A menu card closes when its screen is pushed or popped (`TGNavController`) | 1 | 0 |
| Menus from a source (profile More, a chat row) follow official's context menu: the screen dims in four bands round the source, which stays lit as it is, and the card hangs under it. The selection panel wears the composer's gloss and top line. New Message's rows are accent action rows, no tiles | 1 | 0 |

Checked on the emulator through dev routes injected as `devwalk.txt` (the emulator has no shell): the chat list menu, profile More, New Message and New Group, selection bar, AI compose, forward picker, storage, terms, background editor, ephemeral, profile colours, text styles, passcode, update, a list screen and a menu card from `screen/demolist` and `screen/demomenu`. The batches keep the look: on the iPhone 4 / iOS 6.1.3 emulator, HEAD and the migrated build shot the chat list, its Edit mode and edit bar, Contacts, New Contact, Settings, Edit Profile, a chat and the attach sheet pixel for pixel the same (`scripts/shotdiff.py`). Not yet on a real device, iPad or iOS 7+. The one place left is the call screen, which keeps its design on purpose.
