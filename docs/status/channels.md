Channel-specific behaviour: posting, admin surface, comments, views, signatures, statistics and the channel-only tools. Parity rows come from `_parity_audit/profile_group.md` and `channels.md`; checked against `src/` on 7 November 2026.

Counts: 34 done, 13 partial, 8 missing, 1 dev-only.

**What is built.** Channels are part of M7 and gained their own tools there: posting, read-only
subscriber chrome, join and mute, subscriber count, settings, usernames and
public/private type, comments through the linked discussion group, direct
messages, send-as, reactions, stickers, accent and theme, and similar
channels.

M36 owns the administration detail: per-admin rights, invite-link rows,
statistics graphs, boosts and the event log. The bubble still drops the author
forward counts, which are M44; views and the signature went into the stamp on 7 November 2026.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Create a channel | Official: Create a channel | partial | `Controllers/TGChatListViewController.m:1282` | Compose sheet sends `createSupergroup` with `is_channel`, then asks for a name in an alert. |
| Post as an administrator | Official: Post as an administrator | done | `Controllers/TGChatViewController.m:845` | Composer is enabled only with `can_send_basic_messages` or `can_be_edited`. |
| Read-only channel for subscribers | Official: Read-only channel for subscribers | done | `Controllers/TGChatViewController.m:947` | Composer is replaced by a "Join" or "Mute" stand-in. |
| Join a channel | Official: Join a channel | done | `Controllers/TGChatViewController.m:971` | `joinChat` from the bottom bar. |
| Mute the channel | Official: Mute the channel | done | `Controllers/TGChatViewController.m:992` | Bottom-bar button toggles mute and redraws. |
| Subscriber count | Official: Subscriber count | done | `Controllers/TGProfileViewController.m:509` | Header reads "N subscribers". |
| Verified check | Official: Verified check | partial | `Controllers/TGProfileViewController.m:431` | User check draws; channel `verification_status` is not read. |
| Channel header actions | Official: Channel header actions | missing | `Controllers/TGProfileViewController+Actions.m:107` | Tiles are Add/Mute/Search/More; Leave is in More; no Discussion or Voice Chat tile. |
| Channel Settings entry | Official: Channel Settings entry | done | `Controllers/TGProfileViewController+Actions.m:371` | Managers open `TGGroupSettingsViewController` in channel mode. |
| Channel photo / name / description | Official: Channel photo / name / description | done | `Controllers/TGGroupSettingsViewController.m:460` | Editable through the same identity section as a group. |
| Public / private channel type | Official: Public / private channel type | done | `Controllers/TGGroupSettingsViewController.m:500` | Editable username switches the type. |
| Channel username management | Official: Channel username management | done | `Controllers/TGGroupSettingsViewController.m:2201` | Editable, active, disabled names; remove and disable all. |
| Public link on the profile | Official: Public link on the profile | partial | `Controllers/TGGroupSettingsViewController.m:493` | No profile link row; the link lives in Group Settings. |
| Invite links | Official: Invite links | partial | `Controllers/TGGroupSettingsViewController.m:1908` | Alert of raw URLs and "N joined"; no dates, limits, QR or separate revoked section. |
| Subscription invite links | Official: Subscription invite links | done | `Controllers/TGGroupSettingsViewController.m:2160` | Creates a paid subscription link. |
| Sign messages | Official: Sign messages | done | `Controllers/TGGroupSettingsViewController.m:576` | `sign_messages` switch in Permissions and Behaviour. |
| Post author signature | Official: Post author signature | done | `Controllers/TGChatViewController+Layout.m` (`stampFor:`) | Signed posts print the signature before the views in the stamp. |
| View count on a bubble | Official: View count on a bubble | done | `Controllers/TGChatViewController+Cells.m` (`placeViewsEyeIn:`) | Eye glyph and compact count (`TGCompactCount`) before the time on every post kind; checked on the 4S on 7 November 2026. |
| Forward count | Official: Forward count | missing | `Core/TGMessageFlatten.m:906` | `forward_count` is not flattened or drawn. |
| Message-level view statistics | Official: Message-level view statistics | done | `Controllers/TGChatViewController+Actions.m:1464` | Views and reaction graphs in the Message Info sheet. |
| Channel statistics screen | Official: Channel statistics screen | partial | `Controllers/TGChatToolsViewController.m:301` | `getChatStatistics` rows with totals; no graphs or per-post sections. |
| Event log | Official: Event log | partial | `Controllers/TGChatToolsViewController.m:149` | Flat list; no search, filters or event detail. |
| Affiliate program | Official: Affiliate program | partial | `Controllers/TGAffiliateProgramsViewController.m:50` | Debug console asking for ids; no commission badge. |
| Comments / discussion thread | Official: Comments / discussion thread | done | `Controllers/TGChatViewController.m:1158` | Resolves `linked_chat_id` and message thread, pushes the thread. |
| Comment count on a post | Official: Comment count on a post | done | `Controllers/TGChatViewController+Actions.m:568` | "Leave a Comment" / "Show N Replies". |
| Linked discussion group row | Official: Linked discussion group row | done | `Controllers/TGProfileViewController.m:647` | Shown as "discussion" on a channel. |
| Create a discussion group | Official: Create a discussion group | done | `Controllers/TGChatToolsViewController.m:634` | `chooseDiscussionGroup` links or creates one. |
| Discussion row with the peer name | Official: Discussion row with the peer name | partial | `Controllers/TGChatToolsViewController.m:184` | "Discussion Group — Linked/None" in Chat Tools; no peer name. |
| Channel Direct Messages | Official: Channel Direct Messages | done | `Controllers/TGGroupSettingsViewController.m:1719` | Enables/manages the channel's DM tab and topics. |
| Direct Messages profile row | Official: Direct Messages profile row | done | `Controllers/TGProfileViewController+Actions.m` | The "message" tile opens the channel's DM chat; the chat's bottom bar has the same button. |
| Channel admin rights | Official: Channel admin rights | partial | `Core/TGClient+Groups.m:395` | Promote sends the default `TGAdminRights()`; no per-administrator checkbox screen. |
| Default admin rights presets | Official: Default admin rights presets | done | `Controllers/TGAdminRightsViewController.m:115` | Group and channel defaults chosen from Telegram's presets. |
| Granular member permissions | Official: Granular member permissions | partial | `Controllers/TGGroupSettingsViewController.m:565` | Three presets only: all, messages only, read only. |
| Slow mode | Official: Slow mode | done | `Controllers/TGGroupSettingsViewController.m:571` | 0 to 1 hour presets. |
| Protected content | Official: Protected content | done | `Controllers/TGChatToolsViewController.m:163` | Toggle plus "answer protected-content request". |
| Translatable channel | Official: Translatable channel | done | `Controllers/TGChatToolsViewController.m:165` | Toggle and automatic translation setting. |
| Aggressive anti-spam | Official: Aggressive anti-spam | done | `Controllers/TGGroupSettingsViewController.m:582` | Switch plus false-positive report. |
| Channel reactions setting | Official: Channel reactions setting | partial | `Controllers/TGChatToolsViewController.m:161` | Two choices: all, or 👍 ❤️ 🔥. |
| Channel sticker set | Official: Channel sticker set | done | `Controllers/TGGroupSettingsViewController.m:1767` | `groupStickers` / custom emoji pack selection. |
| Channel accent / theme / background | Official: Channel accent / theme / background | done | `Controllers/TGChatToolsViewController.m:173` | Accent, profile accent, theme, background, reset. |
| Sponsored messages | Official: Sponsored messages | done | `Controllers/TGSponsoredMessagesViewController.m:34` | Channel managers can enable and inspect ads. |
| Affiliate program | Official: Affiliate program | partial | `Controllers/TGAffiliateProgramsViewController.m:20` | Catalogue and connections exist; the entry point is a debug console. |
| Similar channels | Official: Similar channels | done | `Controllers/TGProfileViewController.m:673` | Row plus a list from `getChatSimilarChats`. |
| Revenue / star statistics | Official: Revenue / star statistics | dev-only | `Controllers/TGSettingsViewController+Pages.m:1277` | The Premium, Stars and Gifts console is inside the `TG_DEV` debug section. |
| Channel post scheduling | Official: Channel post scheduling | done | `Controllers/TGChatViewController+Input.m:451` | Same scheduled-send path as any chat. |
| Send As | Official: Send As | done | `Controllers/TGGroupSettingsViewController.m:1681` | Chooses the sender identity for a channel's messages. |
| Delete or leave a channel | Official: Delete or leave a channel | done | `Controllers/TGProfileViewController+Actions.m:418` | Owner deletes; others leave. |
| Clear channel history | Official: Clear channel history | done | `Controllers/TGProfileViewController+Actions.m:403` | Per-chat clear with confirmation. |
| View a channel as a reader | Official: View a channel as a reader | done | `Controllers/TGChatViewController.m:791` | Non-managers get the reader chrome and no composer. |
| Channel auto-delete timer | Official: Channel auto-delete timer | done | `Controllers/TGProfileViewController+Actions.m:533` | TTL applies to new messages. |
| Channel location | Official: Channel location | done | `Controllers/TGChatToolsViewController.m:188` | `setLocation` with a map point. |
| Post statistics on the bubble | Official: Post statistics on the bubble | missing | `Core/TGMessageFlatten.m:906` | `viewCount` is flattened but the bubble layout never reads it. |
| Scam / fake warning | Official: Scam / fake warning | missing | — | Channel `verification_status` is not read. |
| Administrators screen | Official: Administrators screen | missing | — | `administratorsOfChat` is only used by the member action sheet. |
| Removed users screen | Official: Removed users screen | missing | — | No banned/restricted filter screen. |
| Boosts | Official: Boosts | missing | — | No channel boosts surface; calls exist only in the `TG_DEV` Stars console. |
