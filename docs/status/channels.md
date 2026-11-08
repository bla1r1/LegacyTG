Channel-specific behaviour: posting, admin surface, comments, views, signatures, statistics and the channel-only tools. Parity rows come from `_parity_audit/profile_group.md` and `channels.md`; checked against `src/` on 7 November 2026.

Counts: 34 done, 13 partial, 8 missing, 1 dev-only.

Built: M7 (posting, chrome, join/mute, settings, usernames, comments, direct
messages, send-as, reactions, accent). Open: M36 admin detail (rights editor,
invite-link rows, statistics graphs, boosts, event log); M44 author and
forward counts. Views and the signature are in the stamp as of 7 November 2026.

| Feature | State | Where | Note |
|---|---|---|---|
| Create a channel | partial | `src/Features/ChatList/Core/TGChatListCompose.m:132` | Compose sheet sends `createSupergroup` with `is_channel`, then asks for a name in an alert. |
| Post as an administrator | done | `src/Features/Chat/Core/TGChatViewData.m:427` | Composer is enabled only with `can_send_basic_messages` or `can_be_edited`. |
| Read-only channel for subscribers | done | `src/Features/Chat/Core/TGChatViewData.m:529` | Composer is replaced by a "Join" or "Mute" stand-in. |
| Join a channel | done | `src/Features/Chat/Core/TGChatViewData.m:553` | `joinChat` from the bottom bar. |
| Mute the channel | done | `src/Features/Chat/Core/TGChatViewData.m:574` | Bottom-bar button toggles mute and redraws. |
| Subscriber count | done | `src/Features/Profile/Core/TGProfileHeader.m:332` | Header reads "N subscribers". |
| Verified check | partial | `src/Features/Profile/Core/TGProfileHeader.m:254` | User check draws; channel `verification_status` is not read. |
| Channel header actions | missing | `Features/Profile/TGProfileViewController+Actions.m:107` | Tiles are Add/Mute/Search/More; Leave is in More; no Discussion or Voice Chat tile. |
| Channel Settings entry | done | `Features/Profile/TGProfileViewController+Actions.m:371` | Managers open `TGGroupSettingsViewController` in channel mode. |
| Channel photo / name / description | done | `src/Features/Groups/Core/TGGroupSections.m:238` | Editable through the same identity section as a group. |
| Public / private channel type | done | `src/Features/Groups/Core/TGGroupSections.m:278` | Editable username switches the type. |
| Channel username management | done | `src/Features/Groups/Core/TGGroupUsernames.m:168` | Editable, active, disabled names; remove and disable all. |
| Public link on the profile | partial | `src/Features/Groups/Core/TGGroupSections.m:271` | No profile link row; the link lives in Group Settings. |
| Invite links | partial | `src/Features/Groups/Core/TGGroupInvites.m:168` | Alert of raw URLs and "N joined"; no dates, limits, QR or separate revoked section. |
| Subscription invite links | done | `src/Features/Groups/Core/TGGroupInvites.m:420` | Creates a paid subscription link. |
| Sign messages | done | `src/Features/Groups/Core/TGGroupSections.m:354` | `sign_messages` switch in Permissions and Behaviour. |
| Post author signature | done | `Features/Chat/Rendering/TGChatViewController+Layout.m` (`stampFor:`) | Signed posts print the signature before the views in the stamp. |
| View count on a bubble | done | `Features/Chat/Rendering/TGChatViewController+Cells.m` (`placeViewsEyeIn:`) | Eye glyph and compact count (`TGCompactCount`) before the time on every post kind; checked on the 4S on 7 November 2026. |
| Forward count | missing | `Core/Model/TGMessageFlatten.m:906` | `forward_count` is not flattened or drawn. |
| Message-level view statistics | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:1306` | Views and reaction graphs in the Message Info sheet. |
| Channel statistics screen | partial | `Features/Chat/TGChatToolsViewController.m:301` | `getChatStatistics` rows with totals; no graphs or per-post sections. |
| Event log | partial | `Features/Chat/TGChatToolsViewController.m:149` | Flat list; no search, filters or event detail. |
| Affiliate program | partial | `Features/BotsPayments/TGAffiliateProgramsViewController.m:50` | Debug console asking for ids; no commission badge. |
| Comments / discussion thread | done | `src/Features/Chat/Core/TGChatViewData.m:740` | Resolves `linked_chat_id` and message thread, pushes the thread. |
| Comment count on a post | done | `src/Features/Chat/Actions/TGChatActionsHoldMenu.m:410` | "Leave a Comment" / "Show N Replies". |
| Linked discussion group row | done | `src/Features/Profile/Core/TGProfileData.m:245` | Shown as "discussion" on a channel. |
| Create a discussion group | done | `Features/Chat/TGChatToolsViewController.m:634` | `chooseDiscussionGroup` links or creates one. |
| Discussion row with the peer name | partial | `Features/Chat/TGChatToolsViewController.m:184` | "Discussion Group — Linked/None" in Chat Tools; no peer name. |
| Channel Direct Messages | done | `src/Features/Groups/Core/TGGroupTools.m:217` | Enables/manages the channel's DM tab and topics. |
| Direct Messages profile row | done | `Features/Profile/TGProfileViewController+Actions.m` | The "message" tile opens the channel's DM chat; the chat's bottom bar has the same button. |
| Channel admin rights | partial | `Core/Client/TGClient+Groups.m:395` | Promote sends the default `TGAdminRights()`; no per-administrator checkbox screen. |
| Default admin rights presets | done | `Features/Groups/TGAdminRightsViewController.m:115` | Group and channel defaults chosen from Telegram's presets. |
| Granular member permissions | partial | `src/Features/Groups/Core/TGGroupSections.m:343` | Three presets only: all, messages only, read only. |
| Slow mode | done | `src/Features/Groups/Core/TGGroupSections.m:349` | 0 to 1 hour presets. |
| Protected content | done | `Features/Chat/TGChatToolsViewController.m:163` | Toggle plus "answer protected-content request". |
| Translatable channel | done | `Features/Chat/TGChatToolsViewController.m:165` | Toggle and automatic translation setting. |
| Aggressive anti-spam | done | `src/Features/Groups/Core/TGGroupSections.m:360` | Switch plus false-positive report. |
| Channel reactions setting | partial | `Features/Chat/TGChatToolsViewController.m:161` | Two choices: all, or 👍 ❤️ 🔥. |
| Channel sticker set | done | `src/Features/Groups/Core/TGGroupTools.m:265` | `groupStickers` / custom emoji pack selection. |
| Channel accent / theme / background | done | `Features/Chat/TGChatToolsViewController.m:173` | Accent, profile accent, theme, background, reset. |
| Sponsored messages | done | `Features/BotsPayments/TGSponsoredMessagesViewController.m:34` | Channel managers can enable and inspect ads. |
| Affiliate program | partial | `Features/BotsPayments/TGAffiliateProgramsViewController.m:20` | Catalogue and connections exist; the entry point is a debug console. |
| Similar channels | done | `src/Features/Profile/Core/TGProfileData.m:271` | Row plus a list from `getChatSimilarChats`. |
| Revenue / star statistics | dev-only | `src/Features/Settings/Pages/TGSettingsPagesPayments.m:473` | The Premium, Stars and Gifts console is inside the `TG_DEV` debug section. |
| Channel post scheduling | done | `Features/Chat/Composer/TGChatViewController+Input.m:451` | Same scheduled-send path as any chat. |
| Send As | done | `src/Features/Groups/Core/TGGroupTools.m:179` | Chooses the sender identity for a channel's messages. |
| Delete or leave a channel | done | `Features/Profile/TGProfileViewController+Actions.m:418` | Owner deletes; others leave. |
| Clear channel history | done | `Features/Profile/TGProfileViewController+Actions.m:403` | Per-chat clear with confirmation. |
| View a channel as a reader | done | `src/Features/Chat/Core/TGChatViewData.m:373` | Non-managers get the reader chrome and no composer. |
| Channel auto-delete timer | done | `Features/Profile/TGProfileViewController+Actions.m:533` | TTL applies to new messages. |
| Channel location | done | `Features/Chat/TGChatToolsViewController.m:188` | `setLocation` with a map point. |
| Post statistics on the bubble | missing | `Core/Model/TGMessageFlatten.m:906` | `viewCount` is flattened but the bubble layout never reads it. |
| Scam / fake warning | missing | — | Channel `verification_status` is not read. |
| Administrators screen | missing | — | `administratorsOfChat` is only used by the member action sheet. |
| Removed users screen | missing | — | No banned/restricted filter screen. |
| Boosts | missing | — | No channel boosts surface; calls exist only in the `TG_DEV` Stars console. |
