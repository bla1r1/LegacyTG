Chat screen: history, bubbles, composer, message actions, search, scheduling and bot controls. Parity rows come from `_parity_audit/s_chat.md` and the chat half of `changelog.md`; checked against `src/` on 7 November 2026. Message content types have their own file, `message-types.md`.

Counts: 61 done, 14 partial, 16 missing, 0 dev-only.

Built: M4 (60-message pages, bubbles, actions, drafts, pins, reactions,
multi-select, scheduled sends), M10 (text search), M16 (polls, cards, veils),
M17 (custom emoji in the text model), M23 (silent and repeated sends, GIF
caption, file and music picker), M27 (failed-send mark). Open: M26 (search
filters), M35 (poll creation, copy in multi-select, forward options).

| Feature | State | Where | Note |
|---|---|---|---|
| History load, 60 messages | done | `src/Features/Chat/Core/TGChatViewData.m:240` | `historyForChat:limit:60` fills the table on open. |
| Older paging | done | `src/Features/Chat/Core/TGChatViewDocumentDelegate.m:74` | Scrolling up prepends 60-message pages and keeps the offset. |
| New messages live | done | `src/Features/Chat/Core/TGChatViewLayout.m:176` | `onNewMessage` appends and reloads when away from the bottom. |
| Date separators | done | `Features/Chat/Rendering/TGChatViewController+Chrome.m:57` | One separator row per calendar day, formatted by `TGDayTitle`. |
| Unread divider | done | `Features/Chat/Rendering/TGChatViewController+Chrome.m:82` | Captured once on open and inserted at the first unread message. |
| Album grouping | done | `src/Features/Chat/Core/TGChatViewData.m:119` | Albums collapse to one row with a 2×2 collage and `+N` for the rest. |
| Jump to bottom / unread | partial | `Features/Chat/Rendering/TGChatViewController+Chrome.m:517` | One button scrolls to the newest message; no separate mention, reaction or poll-vote button. |
| Jump to date | done | `src/Features/Chat/Core/TGChatViewData.m:651` | Calls `messageAtDate:` and scrolls there. |
| Scroll to replied / pinned message | done | `src/Features/Chat/Core/TGChatViewData.m:763` | Loads history around the id when outside the window and flashes the row. |
| Floating date while scrolling | done | `Features/Chat/Rendering/TGChatViewController+Chrome.m:583` | Shows the day of the top visible row and fades it. |
| Group sender name and avatar | done | `Features/Chat/Rendering/TGChatViewController+Cells.m:44` | Name is colour-mapped per sender; avatar follows the run start. |
| Member tag under the sender | done | `Features/Chat/Rendering/TGChatViewController+Layout.m:668` | `senderTag` is appended after the sender name in the meta line. |
| Incoming/outgoing bubble colours | done | `Features/Chat/Rendering/TGChatViewController+Cells.m:76` | Fill comes from `bubbleMineColour` / `bubbleTheirsColour`; tails are always hidden. |
| Time and "edited" stamp | done | `Features/Chat/Rendering/TGChatViewController+Layout.m:76` | `TGMessageStamp` puts "edited" after the clock. |
| Sent/read ticks | done | `Features/Chat/Rendering/TGChatViewController+Cells.m:316` | `state` selects single or double ticks. |
| Sending clock | done | `Features/Chat/Rendering/TGChatViewController+Cells.m:319` | `sending` replaces the ticks with a clock. |
| Failed delivery mark | done | `Features/Chat/Rendering/TGChatViewController+Cells.m:419` | Error glyph from `TGSendStore`; tap on the bubble resends and the hold menu keeps Retry. |
| Reply block and swipe-to-reply | done | `Features/Chat/Rendering/TGChatViewController+Chrome.m:641` | Quote strip draws author and text; pan on a bubble starts a reply. |
| Reply with a chosen quote | missing | `Core/Client/Messages/TGClient+Messages.m:287` | Reply stores only `replyToId`; no text selection or `inputTextQuote`. |
| Forward attribution line | done | `Features/Chat/Rendering/TGChatViewController+Layout.m:104` | "Forwarded from …" is drawn above the body. |
| Link preview card | partial | `Features/Chat/Rendering/TGChatViewController+Layout.m:678` | Title, site and description only; `linkPreview.type` picture is never fetched. |
| Spoiler text reveal | done | `Features/Chat/Rendering/TGChatViewController+Cells.m:136` | Per-message reveal set drives `TGAttributedMessageTextRevealing`. |
| Reaction chips under a bubble | done | `Features/Chat/Rendering/TGChatViewController+Cells.m:577` | One reactor shows their face; more show emoji and count. |
| Reaction picker and send | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:1400` | Bar sends `addMessageReaction`; holding a reaction makes it default. |
| Custom emoji in text | done | `Features/Chat/Views/TGMessageLayout.mm:512` | Picture inline on iOS 7+ (iOS 6 shows the fallback); animated through the sticker pipeline where stickers animate, up to 3 per bubble; animation not yet checked on the 4S. |
| Composer text field and send | done | `Features/Chat/Composer/TGChatViewController+Input.m:352` | Trimmed text goes through `TGSendStore sendFormattedText:…`; the store owns the send and its state. |
| Markdown send | done | `Features/Chat/Composer/TGChatViewController+Input.m:728` | `markdownParsed:` keeps the typed markup as entities and the store sends the formatted record. |
| Formatted send/edit interface | done | `Core/Stores/TGSendStore.mm:104` | `sendFormattedText:…schedulingState:` and `editMessageText:…formattedText:` own the request and track the result. |
| Send custom emoji ids | done | `Core/Model/TGComposerText.m`, `Features/Chat/Composer/TGChatViewController+Input.m` | `TGComposerText` keeps the ids; Send goes through `parseMarkdown` and `sendFormattedText`; seen on the 4S in Saved Messages on 7 November 2026. |
| File and music picker | done | `Features/Chat/Views/TGAttachSheet.h:8` | File uses `UIDocumentPicker` on iOS 8+, music uses `MPMediaPickerController` and exports to .m4a; both send through `TGSendStore` with `inputMessageDocument` / `inputMessageAudio`. |
| Attach sheet | done | `Features/Chat/Composer/TGChatViewController+Input.m:747` | Gallery, camera, location, contact, checklist, quick reply, dice, ephemeral. |
| Pick photo / video / album | done | `Features/Chat/Actions/TGChatViewController+Attachments.m:182` | Picker accepts images and movies; multi-select sends an album. |
| Voice recording and send | done | `src/Features/Chat/Composer/TGChatAudioVoice.m:539` | Hold-to-record, pause, waveform, `sendVoiceAtPath:`. |
| Round video note record/play | done | `src/Features/Chat/Composer/TGChatAudioVoice.m:736` | `TGVideoNoteRecorder` writes the file; bubble plays it in a circle. |
| Sticker and GIF send | done | `Features/Chat/Composer/TGChatViewController+Input.m:717` | Panel picks send `sendStickerWithFileId:` / `sendAnimation:`. |
| GIF caption | done | `Core/Stores/TGSendStore.mm:141` | `sendAnimation:caption:` sends the composer text as `inputMessageAnimation.caption`. |
| Custom emoji tab in picker | done | `Features/Chat/Views/TGEmojiPanel.m` | Custom tab with the installed packs; without Premium only Saved Messages takes them. |
| Reply | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:588` | Sets reply target and opens the composer. |
| Forward | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:614` | Single and batched forwards through `TGForwardPicker`. |
| Forward with a new caption | missing | `Features/Chat/TGForwardPicker.m:154` | Picker chooses chats only and calls `forwardMessages`; no `copy_options`. |
| Share into a forum topic | missing | `Features/Chat/TGForwardPicker.m:154` | Picker lists chats, not topics, and sends no `topic_id`. |
| Edit text | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:1167` | Prefills with `getMarkdownText` result, then `editMessage:text:`. |
| Edit caption | done | `Features/Chat/Composer/TGChatViewController+Input.m:360` | `editCaption:ofMessage:inChat:` when the original has a photo or document. |
| Replace photo | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:1165` | Picks a new image and keeps the message id. |
| Delete for me / for everyone | done | `Features/Chat/Selection/TGChatViewController+Selection.m:219` | One sheet chooses revoke or local delete. |
| Copy text and copy link | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:388` | Copy uses the flattened caption/text; Copy Link uses the t.me link. |
| Multi-select mode | done | `Features/Chat/Selection/TGChatViewController+Selection.m:42` | Checkboxes, count title, Delete and Forward toolbar. |
| Copy in multi-select | missing | `Features/Chat/Selection/TGChatViewController+Selection.m:148` | Toolbar has only Delete and Forward. |
| Pin / unpin a message | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:396` | `pinChatMessage` / `unpinChatMessage`. |
| Pinned banner and Unpin All | done | `src/Features/Chat/Core/TGChatViewData.m:1080` | Banner loads the pinned message; hold offers `unpinAllMessagesInChat`. |
| Pinned message list | missing | `src/Features/Chat/Core/TGChatViewData.m:1082` | The banner loads one message only; no list or index. |
| Search in chat | partial | `Features/Chat/Search/TGChatViewController+Search.m:68` | Text-only `searchChatMessages`; no sender, media, date or filter chips. |
| Search result opens the message | missing | `Features/Chat/Search/TGChatViewController+Search.m:68` | Results replace the feed; ending search returns to the bottom. |
| Scheduled send | done | `Features/Chat/Composer/TGChatViewController+Input.m:451` | Long-press Send offers a time or "When Online". |
| Scheduled queue screen | done | `Features/Chat/TGScheduledViewController.m:72` | Lists, reschedules and deletes scheduled messages. |
| Repeated scheduled message | done | `Core/Stores/TGMessageStore.m:26` | `scheduledAtDate:repeatPeriod:` and the composer's Repeat row carry the period. |
| Silent send | done | `Core/Stores/TGSendStore.mm:112` | `sendText:...silent:` and the hold sheet's Send Without Sound build `messageSendOptions`. |
| Drafts | done | `src/Features/Chat/Core/TGChatViewLayout.m:403` | Typed text is written with `setDraft:` and restored on reopen. |
| Remote "draft stopped" | done | `src/Features/Chat/Core/TGChatViewData.m:87` | Shows a snackbar and clears the field when TDLib names the same text. |
| Send typing action | done | `Features/Chat/Composer/TGChatViewController+Input.m:198` | One `sendChatAction` per 4 s. |
| Show typing in header | done | `src/Features/Chat/Core/TGChatViewLayout.m:310` | `onChatAction` drives the subtitle and an animated dot cycle. |
| Translate a message | done | `Features/Chat/Actions/TGChatViewController+MessageSheets.m:193` | `translateText` result is shown in a sheet. |
| Translate the whole chat | missing | `Features/Chat/Actions/TGChatViewController+MessageSheets.m:110` | Per-message only; no chat-wide toggle or bar. |
| Message Info / statistics | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:948` | Info sheet plus per-message interaction graph. |
| Viewed by / who read | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:421` | "Viewed by N" opens the reader list or Telegram's refusal. |
| Protected content | done | `Features/Chat/Selection/TGChatViewController+Selection.m:160` | Copy/Forward disabled in a protected chat and the viewer checks `can_be_saved`. |
| View-once and timer media | done | `Features/Chat/Composer/TGChatViewController+MediaCells.m:306` | Blurred veil, one open, `openMessageContent`, no save/share. |
| Paid media preview | partial | `Features/Chat/Composer/TGChatViewController+MediaCells.m:306` | Blur and price show; tap says Stars are not available. |
| Polls | done | `src/Features/Chat/Core/TGChatViewData.m:841` | Vote, multi-answer, quiz, retract, voters, close, statistics. |
| Poll creation | missing | `Features/Chat/Views/TGAttachSheet.m:260` | The attach sheet has no Poll row and no `inputMessagePoll` request. |
| Poll option links | partial | `Core/Model/TGMessageFlatten.m:458` | Option text is flattened to a plain string; entities are dropped. |
| Poll vote timestamps | partial | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:726` | `pollVoter.date` is stored but the voter sheet prints names only. |
| Checklists | partial | `src/Features/Chat/Core/TGChatViewData.m:908` | Tasks toggle; adding tasks from the bubble is not implemented. |
| Cards (invoice/gift/game/story/group call) | partial | `Features/Chat/Rendering/TGChatViewController+ServiceCells.m:17` | Card draws; Pay and Join buttons are deliberately removed because the follow-up does not exist. |
| Bot reply keyboard | done | `Features/Chat/Composer/TGChatViewController+Bots.m:103` | Keyboard rows/one-time/placeholder are drawn and send text. |
| Bot inline buttons | partial | `Features/Chat/Composer/TGChatViewController+Bots.m:30` | Web App, Pay, Game and password callbacks answer "needs a newer Telegram". |
| Inline bot mode (`@bot query`) | missing | `Features/Chat/Composer/TGChatViewController+Bots.m:87` | Switch-inline only types the mention; no inline result list or `sendInlineQueryResult`. |
| Bot Web Apps | missing | `Features/Dev/TGDevBotConsoleViewController.m:214` | No Web App host; the debug console copies the URL. |
| Ephemeral bot replies | missing | `Core/Model/TGMessageFlatten.m:696` | `ephemeral_message_id` is carried; `ephemeral_content` is never read and no "Only you" mark is drawn. |
| Rich message | partial | `Core/Model/TGMessageFlatten.m:694` | Paragraphs, headings and lists flatten to plain lines; no formatting, tables, media or button rows. |
| Rich text editor | missing | `Features/Chat/Views/TGAttachSheet.m` | No composer path; only Message Tools sends a plain-line rich draft. |
| AI Compose from composer | partial | `Features/Chat/Composer/TGChatViewController+Input.m:472` | TDLib `composeTextWithAi` / `composeRichMessageWithAi` is a sheet in the composer menu, not an inline button. |
| Message effects | missing | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:933` | The effect id is only read for a metadata alert; no send option or playback. |
| Time and date entities | missing | `Features/Chat/Views/TGMessageLayout.mm:309` | No DateTime branch; it renders as plain text. |
| Coloured bot buttons | partial | `Core/Model/TGMessageFlatten.m:108` | Style and icon are dropped; every button uses the default style. |
| Secret chat | done | `Features/Profile/TGProfileViewController+Actions.m:581` | Starts through `createSecretChatWithUser:`; header states the secret state. |
| Auto-delete timer | done | `Features/Profile/TGProfileViewController+Actions.m:533` | Per-chat TTL from the profile menu. |
| Read on open and scroll | done | `src/Features/Chat/Core/TGChatViewData.m:292` | Batched `viewMessages` marks what is visible. |
| Message links open in-app | done | `Features/Chat/Actions/TGChatViewController+Attachments.m:502` | `tg://` and `t.me` links route to chat/message/profile. |
| Delete/forward from the list | done | `Features/Chat/Selection/TGChatViewController+Selection.m:246` | Local removal plus `deleteMessages:revoke:`. |
| Formatting menu | partial | `Features/Chat/Composer/TGChatViewController+Input.m:410` | Format sheet inserts `**`, `*`, `` ` ``, spoiler markup, `~`; no underline, quote or code block. |
