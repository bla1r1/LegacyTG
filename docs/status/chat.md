Chat screen: history, bubbles, composer, message actions, search, scheduling and bot controls. Parity rows come from `_parity_audit/s_chat.md` and the chat half of `changelog.md`; checked against `src/` on 7 November 2026. Message content types have their own file, `message-types.md`.

Counts: 54 done, 16 partial, 21 missing, 0 dev-only.

**What is built.** The chat screen is M4: 60-message pages, live appends, date separators,
unread divider, album collage, sender names and avatars, bubbles, stamps,
reply/forward/edit/delete, drafts, typing, pins, reactions and multi-select.
Read state is batched on open and scroll; scheduled sends and the queue screen
came from the same work.

M10 added text search, M16 rebuilt polls, cards and veils for every content
type, and M17 added the composer text model that keeps custom emoji ids and
sends or edits formatted text. Search filters are M26, the failed-send mark
M27, and poll creation, silent/repeated send and forward options M23 and M35.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| History load, 60 messages | Official: History load, 60 messages | done | `Controllers/TGChatViewController.m:658` | `historyForChat:limit:60` fills the table on open. |
| Older paging | Official: Older paging | done | `Controllers/TGChatViewController.m:2094` | Scrolling up prepends 60-message pages and keeps the offset. |
| New messages live | Official: New messages live | done | `Controllers/TGChatViewController.m:179` | `onNewMessage` appends and reloads when away from the bottom. |
| Date separators | Official: Date separators | done | `Controllers/TGChatViewController+Chrome.m:57` | One separator row per calendar day, formatted by `TGDayTitle`. |
| Unread divider | Official: Unread divider | done | `Controllers/TGChatViewController+Chrome.m:82` | Captured once on open and inserted at the first unread message. |
| Album grouping | Official: Album grouping | done | `Controllers/TGChatViewController.m:537` | Albums collapse to one row with a 2×2 collage and `+N` for the rest. |
| Jump to bottom / unread | Official: Jump to bottom / unread | partial | `Controllers/TGChatViewController+Chrome.m:517` | One button scrolls to the newest message; no separate mention, reaction or poll-vote button. |
| Jump to date | Official: Jump to date | done | `Controllers/TGChatViewController.m:1069` | Calls `messageAtDate:` and scrolls there. |
| Scroll to replied / pinned message | Official: Scroll to replied / pinned message | done | `Controllers/TGChatViewController.m:1181` | Loads history around the id when outside the window and flashes the row. |
| Floating date while scrolling | Official: Floating date while scrolling | done | `Controllers/TGChatViewController+Chrome.m:583` | Shows the day of the top visible row and fades it. |
| Group sender name and avatar | Official: Group sender name and avatar | done | `Controllers/TGChatViewController+Cells.m:44` | Name is colour-mapped per sender; avatar follows the run start. |
| Member tag under the sender | Official: Member tag under the sender | done | `Controllers/TGChatViewController+Layout.m:668` | `senderTag` is appended after the sender name in the meta line. |
| Incoming/outgoing bubble colours | Official: Incoming/outgoing bubble colours | done | `Controllers/TGChatViewController+Cells.m:76` | Fill comes from `bubbleMineColour` / `bubbleTheirsColour`; tails are always hidden. |
| Time and "edited" stamp | Official: Time and "edited" stamp | done | `Controllers/TGChatViewController+Layout.m:76` | `TGMessageStamp` puts "edited" after the clock. |
| Sent/read ticks | Official: Sent/read ticks | done | `Controllers/TGChatViewController+Cells.m:316` | `state` selects single or double ticks. |
| Sending clock | Official: Sending clock | done | `Controllers/TGChatViewController+Cells.m:319` | `sending` replaces the ticks with a clock. |
| Failed delivery mark | Official: Failed delivery mark | missing | `Controllers/TGChatViewController+Cells.m:316` | No failed icon; the hold menu offers Retry only. |
| Reply block and swipe-to-reply | Official: Reply block and swipe-to-reply | done | `Controllers/TGChatViewController+Chrome.m:641` | Quote strip draws author and text; pan on a bubble starts a reply. |
| Reply with a chosen quote | Official: Reply with a chosen quote | missing | `Core/TGClient+Messages.m:417` | Reply stores only `replyToId`; no text selection or `inputTextQuote`. |
| Forward attribution line | Official: Forward attribution line | done | `Controllers/TGChatViewController+Layout.m:104` | "Forwarded from …" is drawn above the body. |
| Link preview card | Official: Link preview card | partial | `Controllers/TGChatViewController+Layout.m:678` | Title, site and description only; `linkPreview.type` picture is never fetched. |
| Spoiler text reveal | Official: Spoiler text reveal | done | `Controllers/TGChatViewController+Cells.m:136` | Per-message reveal set drives `TGAttributedMessageTextRevealing`. |
| Reaction chips under a bubble | Official: Reaction chips under a bubble | done | `Controllers/TGChatViewController+Cells.m:577` | One reactor shows their face; more show emoji and count. |
| Reaction picker and send | Official: Reaction picker and send | done | `Controllers/TGChatViewController+Actions.m:1558` | Bar sends `addMessageReaction`; holding a reaction makes it default. |
| Custom emoji in text | Official: Custom emoji in text | done | `Views/TGMessageLayout.mm:512` | Picture inline on iOS 7+ (iOS 6 shows the fallback); animated through the sticker pipeline where stickers animate, up to 3 per bubble; animation not yet checked on the 4S. |
| Composer text field and send | Official: Composer text field and send | done | `Controllers/TGChatViewController+Input.m:352` | Trimmed text goes through `sendText:thread:replyTo:`. |
| Markdown send | Official: Markdown send | partial | `Controllers/TGChatViewController+Input.m:410` | `sendText` parses markup, but the new `sendFormattedText:` path is an empty stub. |
| Formatted send/edit interface | Official: Formatted send/edit interface | partial | `Core/TGClient+Messages.m:526` | `sendFormattedText:` and `editMessage:…formattedText:` are empty stubs added at HEAD. |
| Send custom emoji ids | Official: Send custom emoji ids | done | `Core/TGComposerText.m`, `Controllers/TGChatViewController+Input.m` | `TGComposerText` keeps the ids; Send goes through `parseMarkdown` and `sendFormattedText`; seen on the 4S in Saved Messages on 7 November 2026. |
| File and music picker | Official: File and music picker | missing | `Views/TGAttachSheet.h:8` | No document picker and no `inputMessageDocument` / `inputMessageAudio` request. |
| Attach sheet | Official: Attach sheet | done | `Controllers/TGChatViewController+Input.m:747` | Gallery, camera, location, contact, checklist, quick reply, dice, ephemeral. |
| Pick photo / video / album | Official: Pick photo / video / album | done | `Controllers/TGChatViewController+Actions.m:1741` | Picker accepts images and movies; multi-select sends an album. |
| Voice recording and send | Official: Voice recording and send | done | `Controllers/TGChatViewController+Audio.m:539` | Hold-to-record, pause, waveform, `sendVoiceAtPath:`. |
| Round video note record/play | Official: Round video note record/play | done | `Controllers/TGChatViewController+Audio.m:736` | `TGVideoNoteRecorder` writes the file; bubble plays it in a circle. |
| Sticker and GIF send | Official: Sticker and GIF send | done | `Controllers/TGChatViewController+Input.m:717` | Panel picks send `sendStickerWithFileId:` / `sendAnimation:`. |
| GIF caption | Official: GIF caption | missing | `Core/TGClient+Stickers.m:405` | `sendAnimation` has no caption parameter or caption step. |
| Custom emoji tab in picker | Official: Custom emoji tab in picker | done | `Views/TGEmojiPanel.m` | Custom tab with the installed packs; without Premium only Saved Messages takes them. |
| Reply | Official: Reply | done | `Controllers/TGChatViewController+Actions.m:746` | Sets reply target and opens the composer. |
| Forward | Official: Forward | done | `Controllers/TGChatViewController+Actions.m:772` | Single and batched forwards through `TGForwardPicker`. |
| Forward with a new caption | Official: Forward with a new caption | missing | `Controllers/TGForwardPicker.m:154` | Picker chooses chats only and calls `forwardMessages`; no `copy_options`. |
| Share into a forum topic | Official: Share into a forum topic | missing | `Controllers/TGForwardPicker.m:154` | Picker lists chats, not topics, and sends no `topic_id`. |
| Edit text | Official: Edit text | done | `Controllers/TGChatViewController+Actions.m:1325` | Prefills with `getMarkdownText` result, then `editMessage:text:`. |
| Edit caption | Official: Edit caption | done | `Controllers/TGChatViewController+Input.m:360` | `editCaption:ofMessage:inChat:` when the original has a photo or document. |
| Replace photo | Official: Replace photo | done | `Controllers/TGChatViewController+Actions.m:1323` | Picks a new image and keeps the message id. |
| Delete for me / for everyone | Official: Delete for me / for everyone | done | `Controllers/TGChatViewController+Selection.m:219` | One sheet chooses revoke or local delete. |
| Copy text and copy link | Official: Copy text and copy link | done | `Controllers/TGChatViewController+Actions.m:546` | Copy uses the flattened caption/text; Copy Link uses the t.me link. |
| Multi-select mode | Official: Multi-select mode | done | `Controllers/TGChatViewController+Selection.m:42` | Checkboxes, count title, Delete and Forward toolbar. |
| Copy in multi-select | Official: Copy in multi-select | missing | `Controllers/TGChatViewController+Selection.m:148` | Toolbar has only Delete and Forward. |
| Pin / unpin a message | Official: Pin / unpin a message | done | `Controllers/TGChatViewController+Actions.m:554` | `pinChatMessage` / `unpinChatMessage`. |
| Pinned banner and Unpin All | Official: Pinned banner and Unpin All | done | `Controllers/TGChatViewController.m:1498` | Banner loads the pinned message; hold offers `unpinAllMessagesInChat`. |
| Pinned message list | Official: Pinned message list | missing | `Controllers/TGChatViewController.m:1500` | The banner loads one message only; no list or index. |
| Search in chat | Official: Search in chat | partial | `Controllers/TGChatViewController+Search.m:68` | Text-only `searchChatMessages`; no sender, media, date or filter chips. |
| Search result opens the message | Official: Search result opens the message | missing | `Controllers/TGChatViewController+Search.m:68` | Results replace the feed; ending search returns to the bottom. |
| Scheduled send | Official: Scheduled send | done | `Controllers/TGChatViewController+Input.m:451` | Long-press Send offers a time or "When Online". |
| Scheduled queue screen | Official: Scheduled queue screen | done | `Controllers/TGScheduledViewController.m:72` | Lists, reschedules and deletes scheduled messages. |
| Repeated scheduled message | Official: Repeated scheduled message | missing | `Core/TGClient+Messages.m:454` | `repeat_period` is hardcoded to 0; no repeat control. |
| Silent send | Official: Silent send | missing | `Core/TGClient+Messages.m:405` | The normal send path builds no `messageSendOptions`. |
| Drafts | Official: Drafts | done | `Controllers/TGChatViewController.m:406` | Typed text is written with `setDraft:` and restored on reopen. |
| Remote "draft stopped" | Official: Remote "draft stopped" | done | `Controllers/TGChatViewController.m:505` | Shows a snackbar and clears the field when TDLib names the same text. |
| Send typing action | Official: Send typing action | done | `Controllers/TGChatViewController+Input.m:198` | One `sendChatAction` per 4 s. |
| Show typing in header | Official: Show typing in header | done | `Controllers/TGChatViewController.m:313` | `onChatAction` drives the subtitle and an animated dot cycle. |
| Translate a message | Official: Translate a message | done | `Controllers/TGChatViewController+Actions.m:2681` | `translateText` result is shown in a sheet. |
| Translate the whole chat | Official: Translate the whole chat | missing | `Controllers/TGChatViewController+Actions.m:2598` | Per-message only; no chat-wide toggle or bar. |
| Message Info / statistics | Official: Message Info / statistics | done | `Controllers/TGChatViewController+Actions.m:1106` | Info sheet plus per-message interaction graph. |
| Viewed by / who read | Official: Viewed by / who read | done | `Controllers/TGChatViewController+Actions.m:579` | "Viewed by N" opens the reader list or Telegram's refusal. |
| Protected content | Official: Protected content | done | `Controllers/TGChatViewController+Selection.m:160` | Copy/Forward disabled in a protected chat and the viewer checks `can_be_saved`. |
| View-once and timer media | Official: View-once and timer media | done | `Controllers/TGChatViewController+MediaCells.m:306` | Blurred veil, one open, `openMessageContent`, no save/share. |
| Paid media preview | Official: Paid media preview | partial | `Controllers/TGChatViewController+MediaCells.m:306` | Blur and price show; tap says Stars are not available. |
| Polls | Official: Polls | done | `Controllers/TGChatViewController.m:1259` | Vote, multi-answer, quiz, retract, voters, close, statistics. |
| Poll creation | Official: Poll creation | missing | `Views/TGAttachSheet.m:260` | The attach sheet has no Poll row and no `inputMessagePoll` request. |
| Poll option links | Official: Poll option links | partial | `Core/TGMessageFlatten.m:458` | Option text is flattened to a plain string; entities are dropped. |
| Poll vote timestamps | Official: Poll vote timestamps | partial | `Controllers/TGChatViewController+Actions.m:884` | `pollVoter.date` is stored but the voter sheet prints names only. |
| Checklists | Official: Checklists | partial | `Controllers/TGChatViewController.m:1326` | Tasks toggle; adding tasks from the bubble is not implemented. |
| Cards (invoice/gift/game/story/group call) | Official: Cards (invoice/gift/game/story/group call) | partial | `Controllers/TGChatViewController+ServiceCells.m:17` | Card draws; Pay and Join buttons are deliberately removed because the follow-up does not exist. |
| Bot reply keyboard | Official: Bot reply keyboard | done | `Controllers/TGChatViewController+Bots.m:103` | Keyboard rows/one-time/placeholder are drawn and send text. |
| Bot inline buttons | Official: Bot inline buttons | partial | `Controllers/TGChatViewController+Bots.m:30` | Web App, Pay, Game and password callbacks answer "needs a newer Telegram". |
| Inline bot mode (`@bot query`) | Official: Inline bot mode (`@bot query`) | missing | `Controllers/TGChatViewController+Bots.m:87` | Switch-inline only types the mention; no inline result list or `sendInlineQueryResult`. |
| Bot Web Apps | Official: Bot Web Apps | missing | `Controllers/TGBotConsoleViewController.m:214` | No Web App host; the debug console copies the URL. |
| Ephemeral bot replies | Official: Ephemeral bot replies | missing | `Core/TGMessageFlatten.m:696` | `ephemeral_message_id` is carried; `ephemeral_content` is never read and no "Only you" mark is drawn. |
| Rich message | Official: Rich message | partial | `Core/TGMessageFlatten.m:694` | Paragraphs, headings and lists flatten to plain lines; no formatting, tables, media or button rows. |
| Rich text editor | Official: Rich text editor | missing | `Controllers/TGAttachSheet.m` | No composer path; only Message Tools sends a plain-line rich draft. |
| AI Compose from composer | Official: AI Compose from composer | partial | `Controllers/TGChatViewController+Input.m:472` | TDLib `composeTextWithAi` / `composeRichMessageWithAi` is a sheet in the composer menu, not an inline button. |
| Message effects | Official: Message effects | missing | `Controllers/TGChatViewController+Actions.m:1091` | The effect id is only read for a metadata alert; no send option or playback. |
| Time and date entities | Official: Time and date entities | missing | `Views/TGMessageLayout.mm:309` | No DateTime branch; it renders as plain text. |
| Coloured bot buttons | Official: Coloured bot buttons | partial | `Core/TGMessageFlatten.m:108` | Style and icon are dropped; every button uses the default style. |
| Secret chat | Official: Secret chat | done | `Controllers/TGProfileViewController+Actions.m:581` | Starts through `createSecretChatWithUser:`; header states the secret state. |
| Auto-delete timer | Official: Auto-delete timer | done | `Controllers/TGProfileViewController+Actions.m:533` | Per-chat TTL from the profile menu. |
| Read on open and scroll | Official: Read on open and scroll | done | `Controllers/TGChatViewController.m:710` | Batched `viewMessages` marks what is visible. |
| Message links open in-app | Official: Message links open in-app | done | `Controllers/TGChatViewController+Actions.m:2061` | `tg://` and `t.me` links route to chat/message/profile. |
| Delete/forward from the list | Official: Delete/forward from the list | done | `Controllers/TGChatViewController+Selection.m:246` | Local removal plus `deleteMessages:revoke:`. |
| Formatting menu | Official: Formatting menu | partial | `Controllers/TGChatViewController+Input.m:410` | Format sheet inserts `**`, `*`, `` ` ``, spoiler markup, `~`; no underline, quote or code block. |
