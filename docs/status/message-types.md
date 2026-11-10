Every `MessageContent` type in `tdlib/td/td/generate/scheme/td_api.tl` (108 on 7 November 2026), in schema order, plus the content features the parity audit names. Checked against `src/` on 7 November 2026.

Counts: 87 done, 25 partial, 8 missing, 0 dev-only.

Built: M16 (service sentences for ~75 types, a preview for every content,
structured flatten fields, `TGMessageCard`, `TGMediaVeil`, rebuilt polls), M17
(custom emoji in text, reactions, names). All 108 `MessageContent` types draw
except stake dice. Open: M36 (member-row status emoji), M44 (rich-message
blocks, story card picture, poll option media, animated gift artwork,
countdowns, service-action buttons).

| Feature | State | Where | Note |
|---|---|---|---|
| messageText | done | `Core/Model/TGMessageFlatten.m:768` | Text with entities, spoiler reveal and custom emoji attachments is drawn by the bubble body. |
| messageRichMessage | partial | `Core/Model/TGMessageFlatten.m:694` | Paragraphs, headings and lists flattened to plain lines; no formatting, tables or media blocks. |
| messageAnimation | done | `Core/Model/TGMessageFlatten.m:443` | GIF bubble with cover, disc, autoplay gate and the media viewer. |
| messageAudio | done | `Core/Model/TGMessageFlatten.m:518` | Track bubble with artwork, waveformless row and the music player queue. |
| messageDocument | done | `Core/Model/TGMessageFlatten.m:482` | File tile with thumbnail, name and size; tap downloads and opens the document preview. |
| messagePaidMedia | partial | `Core/Model/TGMessageFlatten.m:705` | Blurred preview and "Unlock for N Stars"; tapping only reports that Stars are unavailable. |
| messagePhoto | done | `Core/Model/TGMessageFlatten.m:390` | Sized thumbnail, caption above/below, spoiler veil, album collage, viewer. |
| messageSticker | done | `Core/Model/TGMessageFlatten.m:455` | WebP still, TGS/WebM playback, emoji fallback while the file loads. |
| messageVideo | done | `Core/Model/TGMessageFlatten.m:417` | Thumbnail, disc, inline player and viewer; Vintage uses the software decoder. |
| messageVideoNote | done | `Core/Model/TGMessageFlatten.m:435` | Round bubble, record/play, mute toggle. |
| messageVoiceNote | done | `Core/Model/TGMessageFlatten.m:497` | Waveform, duration, play/pause, speed, transcription line. |
| messageExpiredPhoto | done | `Core/Model/TGServiceMessageText.m:440` | "The photo has expired" service line; no tile remains. |
| messageExpiredVideo | done | `Core/Model/TGServiceMessageText.m:442` | Service sentence. |
| messageExpiredVideoNote | done | `Core/Model/TGServiceMessageText.m:444` | Service sentence. |
| messageExpiredVoiceNote | done | `Core/Model/TGServiceMessageText.m:446` | Service sentence. |
| messageLiveLocation | partial | `Core/Model/TGMessageFlatten.m:676` | Map card with time left; no heading arrow and the line only moves on reload. |
| messageLocation | done | `Core/Model/TGMessageFlatten.m:670` | Static map card with coordinates and Open in Maps. |
| messageVenue | done | `Core/Model/TGMessageFlatten.m:546` | Map card with title and address. |
| messageContact | done | `Core/Model/TGMessageFlatten.m:529` | Contact card with name, phone, Add Contact and Call. |
| messageAnimatedEmoji | done | `Core/Model/TGMessageFlatten.m:455` | Drawn through the sticker path; TGS/WebM animates, WebP stays still. |
| messageDice | done | `Core/Model/TGMessageFlatten.m:584` | The throw plays as its sticker animation; slot-machine reels and lever are not drawn. |
| messageGame | partial | `Core/Model/TGMessageFlatten.m:638` | Card with title, description and picture; Play asks the bot for a URL and leaves the app. |
| messagePoll | done | `Core/Model/TGMessageFlatten.m:642` | Question, options, share bars, quiz marks, retract, voters, close, statistics. |
| messageStakeDice | missing | `Core/Model/TGMessageFlatten.m:774` | No branch and no service text; falls back to the derived phrase "Stake dice". |
| messageStory | partial | `Core/Model/TGMessageFlatten.m:700` | Card says "Story by …" and Open plays it; the story's own picture is not in the card. |
| messageChecklist | partial | `Core/Model/TGMessageFlatten.m:737` | Title, tasks and completed count; tapping toggles, adding tasks is missing. |
| messageInvoice | partial | `Core/Model/TGMessageFlatten.m:686` | Card with product, description and picture; the Pay button is removed (no payment form). |
| messageCall | done | `Core/Model/TGMessageFlatten.m:564` | Row names direction, video and duration; a call is startable from the call screen. |
| messageGroupCall | partial | `Core/Model/TGMessageContentInteractive.m:171` | Card with state and duration; Join is suppressed because there is no group-call audio. |
| messageVideoChatScheduled | partial | `Core/Model/TGMessageContentInteractive.m:180` | Card says "Ended" because `startDate` is flattened but never shown; no join. |
| messageVideoChatStarted | partial | `Core/Model/TGMessageContentInteractive.m:184` | Card "Ongoing"; Join button is removed. |
| messageVideoChatEnded | done | `Core/Model/TGMessageContentInteractive.m:188` | Card with "Ended" and the call duration. |
| messageInviteVideoChatParticipants | done | `Core/Model/TGServiceMessageText.m:433` | Sentence naming who was invited. |
| messagePollOptionAdded | done | `Core/Model/TGServiceMessageText.m:557` | Sentence with the option text. |
| messagePollOptionDeleted | done | `Core/Model/TGServiceMessageText.m:564` | Sentence with the option text. |
| messageBasicGroupChatCreate | done | `Core/Model/TGServiceMessageText.m:206` | Sentence naming the creator and title. |
| messageSupergroupChatCreate | done | `Core/Model/TGServiceMessageText.m:207` | Sentence naming the creator and title. |
| messageChatChangeTitle | done | `Core/Model/TGServiceMessageText.m:213` | Sentence with the old and new title. |
| messageChatChangePhoto | partial | `Core/Model/TGServiceMessageText.m:219` | Sentence only; official also shows the new photo as a tile. |
| messageChatDeletePhoto | done | `Core/Model/TGServiceMessageText.m:221` | Sentence. |
| messageChatOwnerLeft | done | `Core/Model/TGServiceMessageText.m:457` | Sentence naming the departing owner. |
| messageChatOwnerChanged | done | `Core/Model/TGServiceMessageText.m:448` | Sentence naming the new owner. |
| messageChatHasProtectedContentToggled | done | `Core/Model/TGServiceMessageText.m:471` | Sentence says whether protection is on. |
| messageChatHasProtectedContentDisableRequested | done | `Core/Model/TGServiceMessageText.m:476` | Sentence names the request state. |
| messageChatAddMembers | done | `Core/Model/TGServiceMessageText.m:223` | Sentence with the added names. |
| messageChatJoinByLink | done | `Core/Model/TGServiceMessageText.m:229` | Sentence naming the joiner and link. |
| messageChatJoinByRequest | done | `Core/Model/TGServiceMessageText.m:231` | Sentence. |
| messageChatJoinFromCommunity | done | `Core/Model/TGServiceMessageText.m:233` | Sentence. |
| messageChatDeleteMember | done | `Core/Model/TGServiceMessageText.m:235` | Sentence naming who left or was removed. |
| messageChatAddedToCommunity | done | `Core/Model/TGServiceMessageText.m:465` | Sentence. |
| messageChatRemovedFromCommunity | done | `Core/Model/TGServiceMessageText.m:468` | Sentence. |
| messageChatUpgradeTo | done | `Core/Model/TGServiceMessageText.m:251` | Sentence about the supergroup upgrade. |
| messageChatUpgradeFrom | done | `Core/Model/TGServiceMessageText.m:253` | Sentence naming the old group title. |
| messagePinMessage | partial | `Core/Model/TGServiceMessageText.m:259` | Sentence only; tapping it does not jump to the pinned message. |
| messageScreenshotTaken | done | `Core/Model/TGServiceMessageText.m:261` | Sentence. |
| messageChatSetBackground | done | `Core/Model/TGServiceMessageText.m:263` | Sentence. |
| messageChatSetTheme | done | `Core/Model/TGServiceMessageText.m:265` | Sentence with the theme emoji or name. |
| messageChatSetMessageAutoDeleteTime | done | `Core/Model/TGServiceMessageText.m:273` | Sentence with the new TTL. |
| messageChatBoost | done | `Core/Model/TGServiceMessageText.m:280` | Sentence with the boost count. |
| messageForumTopicCreated | done | `Core/Model/TGServiceMessageText.m:287` | Sentence with the topic name. |
| messageForumTopicEdited | done | `Core/Model/TGServiceMessageText.m:292` | Sentence with the rename or icon change. |
| messageForumTopicIsClosedToggled | done | `Core/Model/TGServiceMessageText.m:299` | Sentence says closed or reopened. |
| messageForumTopicIsHiddenToggled | done | `Core/Model/TGServiceMessageText.m:304` | Sentence says shown or hidden. |
| messageSuggestProfilePhoto | partial | `Core/Model/TGServiceMessageText.m:309` | Sentence only; no photo thumbnail and no Accept action. |
| messageSuggestBirthdate | partial | `Core/Model/TGServiceMessageText.m:311` | Sentence only; no Accept action. |
| messageCustomServiceAction | done | `Core/Model/TGServiceMessageText.m:313` | Draws the bot-supplied text as a service line. |
| messageGameScore | done | `Core/Model/TGServiceMessageText.m:315` | Sentence with the score and the game. |
| messageManagedBotCreated | done | `Core/Model/TGServiceMessageText.m:571` | Sentence naming the bot. |
| messagePaymentSuccessful | partial | `Core/Model/TGServiceMessageText.m:320` | Sentence with amount; no receipt button. |
| messagePaymentSuccessfulBot | partial | `Core/Model/TGServiceMessageText.m:328` | Sentence; no receipt or order view. |
| messagePaymentRefunded | done | `Core/Model/TGServiceMessageText.m:333` | Sentence with the amount. |
| messageGiftedPremium | done | `Core/Model/TGServiceMessageText.m:338` | Sentence naming giver, recipient and period. |
| messagePremiumGiftCode | done | `Core/Model/TGServiceMessageText.m:350` | Sentence with the code and period. |
| messageGiveawayCreated | done | `Core/Model/TGServiceMessageText.m:378` | Sentence with the prize and date. |
| messageGiveaway | done | `Core/Model/TGMessageCard.m:174` | Card with prize, winners count and date; Learn More reads the giveaway. |
| messageGiveawayCompleted | done | `Core/Model/TGServiceMessageText.m:385` | Sentence with winner count. |
| messageGiveawayWinners | done | `Core/Model/TGMessageCard.m:209` | Card with winner count and the winners' names. |
| messageGiftedStars | done | `Core/Model/TGServiceMessageText.m:359` | Sentence with the star count. |
| messageGiftedGrams | done | `Core/Model/TGServiceMessageText.m:365` | Sentence with the Gram amount. |
| messageGiveawayPrizeStars | done | `Core/Model/TGServiceMessageText.m:371` | Sentence with the prize. |
| messageTonWalletTransfer | done | `Core/Model/TGServiceMessageText.m:586` | Sentence with amount and sender. |
| messageTonConnectRequest | partial | `Core/Model/TGServiceMessageText.m:579` | Sentence names the service; no Open/Connect action. |
| messageGift | partial | `Core/Model/TGMessageCard.m:242` | Card with artwork still, stars and note; View opens `TGGiftViewer`; artwork does not animate. |
| messageUpgradedGift | partial | `Core/Model/TGMessageCard.m:279` | Card with model, number, symbol and backdrop; still artwork only. |
| messageRefundedUpgradedGift | done | `Core/Model/TGServiceMessageText.m:589` | Sentence. |
| messageUpgradedGiftPurchaseOffer | done | `Core/Model/TGServiceMessageText.m:592` | Sentence with the offer amount. |
| messageUpgradedGiftPurchaseOfferRejected | done | `Core/Model/TGServiceMessageText.m:598` | Sentence. |
| messagePaidMessagesRefunded | done | `Core/Model/TGServiceMessageText.m:502` | Sentence with message and star counts. |
| messagePaidMessagePriceChanged | done | `Core/Model/TGServiceMessageText.m:494` | Sentence with the new price. |
| messageDirectMessagePriceChanged | done | `Core/Model/TGServiceMessageText.m:484` | Sentence with the new price. |
| messageUnpaidMessagesAllowedByLink | done | `Core/Model/TGServiceMessageText.m:510` | Sentence. |
| messageChecklistTasksDone | done | `Core/Model/TGServiceMessageText.m:539` | Sentence with the completed count. |
| messageChecklistTasksAdded | done | `Core/Model/TGServiceMessageText.m:533` | Sentence with the added tasks. |
| messageSuggestedPostApprovalFailed | done | `Core/Model/TGServiceMessageText.m:512` | Sentence with the refusal. |
| messageSuggestedPostApproved | partial | `Core/Model/TGServiceMessageText.m:515` | Sentence; no Open the post action. |
| messageSuggestedPostDeclined | done | `Core/Model/TGServiceMessageText.m:518` | Sentence. |
| messageSuggestedPostPaid | partial | `Core/Model/TGServiceMessageText.m:521` | Sentence with price; no Open the post action. |
| messageSuggestedPostRefunded | done | `Core/Model/TGServiceMessageText.m:529` | Sentence. |
| messageContactRegistered | done | `Core/Model/TGServiceMessageText.m:391` | Sentence. |
| messageUsersShared | done | `Core/Model/TGMessageCard.m:333` | Card with one user or a name list; Open goes to the profile. |
| messageChatShared | done | `Core/Model/TGMessageCard.m:375` | Card with chat title, username and photo; Open goes to the chat. |
| messageBotWriteAccessAllowed | done | `Core/Model/TGServiceMessageText.m:393` | Sentence naming the bot and the reason. |
| messageWebAppDataSent | done | `Core/Model/TGServiceMessageText.m:407` | Sentence with the button text. |
| messageWebAppDataReceived | done | `Core/Model/TGServiceMessageText.m:409` | Sentence with the button text. |
| messagePassportDataSent | done | `Core/Model/TGServiceMessageText.m:411` | Sentence listing the document types. |
| messagePassportDataReceived | done | `Core/Model/TGServiceMessageText.m:413` | Sentence. |
| messageProximityAlertTriggered | done | `Core/Model/TGServiceMessageText.m:415` | Sentence naming both people and the distance. |
| messageUnsupported | done | `Core/Model/TGServiceMessageText.m:605` | "This message is not supported by this app" service line. |
| Live and motion photos | partial | `Core/Model/TGMessageFlatten.m:226` | The `messagePhoto` branch reads only the still sizes and ignores `content.video`. |
| GIF caption | done | `Core/Stores/TGSendStore.mm:141` | Incoming captions draw and outgoing animations carry the composer caption. |
| Inline documents in rich text | missing | `Core/Model/TGMessageFlatten.m:694` | No page-block renderer, so `pageBlockDocument` never draws. |
| Buttons inside rich messages | missing | `Core/Model/TGMessageFlatten.m:694` | `pageBlockButtonRow` is not handled anywhere. |
| Links in poll options | partial | `Core/Model/TGMessageFlatten.m:458` | Option text is flattened to a plain string; entities are dropped. |
| Poll option media | missing | `Core/Model/TGMessageFlatten.m:642` | The poll row draws text and bars only. |
| Poll vote timestamps | partial | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:726` | `pollVoter.date` is stored but the voter sheet prints names only. |
| Ephemeral bot replies | missing | `Core/Model/TGMessageFlatten.m:696` | `ephemeral_message_id` is carried; `ephemeral_content` is never read. |
| Signed gift note | missing | `Core/Client/Account/TGClient+AccountSupport.m:39` | The flatten reads the wrong text key, so the note is blank. |
| AI summary block | missing | `Core/Model/TGMessageFlatten.m:694` | No summary block in a channel post; only Message Tools can ask for one. |
| DateTime entity | missing | `Features/Chat/Views/TGMessageLayout.mm:309` | No DateTime branch; the text renders as plain characters. |
| Coloured bot buttons | partial | `Core/Model/TGMessageFlatten.m:108` | Style and icon are dropped; every button is default-styled. |
