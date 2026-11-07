Groups and forums: creating, the member list, member actions, permissions, invite links, topics, group calls and administration. Parity items from `_parity_audit/profile_group.md`; checked against `src/` on 7 November 2026.

Counts: 48 done, 29 partial, 11 missing, 0 dev-only.

**What is built.** M7 built groups and forums: creation, the member list and action sheet,
ownership transfer, permissions and slow mode, invite links, join requests,
topics with create/rename/icon/close/pin/delete, and the group-call entry.
Channel-side behaviour lives in `channels.md`.

M36 owns the administration half that is still flat: a per-admin rights
editor, member paging, invite-link detail, administrators and removed-user
screens, statistics graphs and boosts. Group-call audio is M21.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Create a basic group | Official: Create a basic group | done | `Controllers/TGContactsViewController.m:620` | Contact picker with group mode sends `createNewBasicGroupChat`. |
| Create a supergroup | Official: Create a supergroup | done | `Controllers/TGGroupSettingsViewController.m:1368` | Upgrade path from a basic group. |
| New Group full form | Official: New Group full form | partial | `Controllers/TGContactsViewController.m:535` | Picks members first, then asks for a name in an alert. |
| Group profile summary | Official: Group profile summary | done | `Controllers/TGProfileViewController.m:612` | Description, member count, invite link, linked chat, community. |
| Verified check beside a name | Official: Verified check beside a name | partial | `Controllers/TGProfileViewController.m:431` | User profiles draw the check; group and channel records do not. |
| Group subtitle "N members, M online" | Official: Group subtitle "N members, M online" | partial | `Controllers/TGProfileViewController.m:244` | "N members" only; the online count is stored on the chat but not read by the profile. |
| Member list | Official: Member list | partial | `Core/TGClient+Chats.mm:302` | The first 50 members load into the profile itself; no paging. |
| Member search with sections | Official: Member search with sections | partial | `Controllers/TGGroupSettingsViewController.m:1408` | One flat `chatMembersFilterMembers` result; no sections or counts. |
| Add members | Official: Add members | done | `Controllers/TGGroupSettingsViewController.m:1398` | Contact picker respects the invite right. |
| Find member | Official: Find member | done | `Controllers/TGGroupSettingsViewController.m:1408` | Search by name or @username. |
| Member actions sheet | Official: Member actions sheet | done | `Controllers/TGGroupMemberActions.m:95` | Info, details, message, promote, tag, clear, remove, ban, ownership. |
| Promote to admin | Official: Promote to admin | partial | `Controllers/TGGroupMemberActions.m:215` | Sends the default `TGAdminRights()`; no rights chooser. |
| Dismiss as admin | Official: Dismiss as admin | done | `Controllers/TGGroupMemberActions.m:219` | Returns the member to plain member status. |
| Ban a member | Official: Ban a member | done | `Controllers/TGGroupMemberActions.m:271` | Permanent ban with message revoke off. |
| Temporarily restrict a member | Official: Temporarily restrict a member | missing | `Controllers/TGGroupMemberActions.m:126` | No restrict path; only ban. |
| Set member tag | Official: Set member tag | done | `Controllers/TGGroupMemberActions.m:223` | `setChatMemberTag`. |
| Clear their reactions | Official: Clear their reactions | done | `Controllers/TGGroupMemberActions.m:239` | `deleteAllReactionsOfSender`. |
| Clear their messages | Official: Clear their messages | done | `Controllers/TGGroupMemberActions.m:252` | `deleteChatMessagesBySender` with revoke. |
| Remove from group | Official: Remove from group | done | `Controllers/TGGroupMemberActions.m:267` | Sets status left. |
| Hand over ownership | Official: Hand over ownership | done | `Controllers/TGGroupMemberActions.m:284` | 2FA password and `canTransferOwnership` pre-check. |
| Per-admin rights editor | Official: Per-admin rights editor | missing | `Core/TGClient+Groups.m:22` | Promote sends one fixed rights object; no editor screen. |
| Default admin rights | Official: Default admin rights | done | `Controllers/TGAdminRightsViewController.m:115` | Group and channel presets. |
| Granular member permissions | Official: Granular member permissions | partial | `Controllers/TGGroupSettingsViewController.m:1445` | Three presets: everything, messages only, read only. |
| Slow mode | Official: Slow mode | done | `Controllers/TGGroupSettingsViewController.m:1468` | 0, 5, 10, 30 s, 1, 5, 15 min, 1 h. |
| Slow mode once | Official: Slow mode once | partial | `Controllers/TGGroupSettingsViewController.m:1468` | Duplicated in Chat Tools, which also prints 3600 as "3600 s". |
| Sign messages | Official: Sign messages | done | `Controllers/TGGroupSettingsViewController.m:576` | Switch writes `sign_messages`. |
| Join to send | Official: Join to send | done | `Controllers/TGGroupSettingsViewController.m:578` | Switch writes `join_to_send_messages`. |
| All history visible | Official: All history visible | partial | `Controllers/TGGroupSettingsViewController.m:580` | Switch only; no Visible/Hidden screen or explanation. |
| Hidden members | Official: Hidden members | partial | `Controllers/TGGroupSettingsViewController.m:599` | Switch in Permissions and Behaviour, away from the member list. |
| Aggressive anti-spam | Official: Aggressive anti-spam | done | `Controllers/TGGroupSettingsViewController.m:582` | Switch with allow flag and the server's refusal. |
| Anti-spam false positive | Official: Anti-spam false positive | done | `Controllers/TGAntiSpamViewController.m:20` | Report a message deleted by mistake. |
| Join by request | Official: Join by request | done | `Controllers/TGGroupSettingsViewController.m:594` | Switch plus the requests screen. |
| Join requests row and screen | Official: Join requests row and screen | partial | `Controllers/TGGroupSettingsViewController.m:1517` | Sheet of names with Accept/Decline; the date is dropped and the bio is never read. |
| Invite links screen | Official: Invite links screen | partial | `Controllers/TGGroupSettingsViewController.m:1908` | Alert of raw URLs and "N joined"; no dates, limits, QR or separate revoked section. |
| Forum mode | Official: Forum mode | done | `Controllers/TGGroupSettingsViewController.m:606` | `is_forum` switch. |
| Topics list | Official: Topics list | done | `Controllers/TGChatListViewController.m:2079` | `isForum` routes the row to `TGTopicsViewController`. |
| Create a topic | Official: Create a topic | done | `Controllers/TGTopicsViewController.m:383` | Name plus custom emoji icon picker. |
| Rename a topic | Official: Rename a topic | done | `Controllers/TGTopicsViewController.m:534` | `renameForumTopic`. |
| Change topic icon | Official: Change topic icon | done | `Controllers/TGTopicsViewController.m:511` | `setForumTopicIcon`; General topic refusal explained. |
| Close / reopen a topic | Official: Close / reopen a topic | done | `Controllers/TGTopicsViewController.m:451` | Hold menu toggles closed. |
| Pin / unpin a topic | Official: Pin / unpin a topic | done | `Controllers/TGTopicsViewController.m:451` | Hold menu plus the pinned-topics manager. |
| Delete a topic | Official: Delete a topic | done | `Controllers/TGTopicsViewController.m:451` | Confirmed delete of the topic and its messages. |
| Topic info | Official: Topic info | done | `Controllers/TGTopicsViewController.m:179` | Topic Info list with counts and settings. |
| Topic notifications | Official: Topic notifications | done | `Controllers/TGTopicsViewController.m:181` | Mute/sound for one topic. |
| Pinned topics manager | Official: Pinned topics manager | done | `Controllers/TGTopicsViewController.m:183` | Reorder and unpin from one list. |
| Hide the General topic | Official: Hide the General topic | done | `Controllers/TGTopicsViewController.m:361` | Toggle from the topic menu. |
| Topic read state and badges | Official: Topic read state and badges | done | `Controllers/TGTopicsViewController.m:189` | Mentions, polls and reactions badges; clears reactions. |
| Broadcast group | Official: Broadcast group | done | `Controllers/TGGroupSettingsViewController.m:1492` | Convert with confirmation. |
| Welcome messages | Official: Welcome messages | partial | `Controllers/TGGroupSettingsViewController.m:1565` | Text only, and in Group Settings rather than the profile. |
| Automatic translation | Official: Automatic translation | done | `Controllers/TGGroupSettingsViewController.m:624` | Switch writes the automatic-translation field. |
| Group usernames | Official: Group usernames | done | `Controllers/TGGroupSettingsViewController.m:2201` | Editable, active, disabled; remove and disable all. |
| Subscription links | Official: Subscription links | done | `Controllers/TGGroupSettingsViewController.m:2160` | Paid invite link creation. |
| Discussion group row | Official: Discussion group row | partial | `Controllers/TGChatToolsViewController.m:184` | "Discussion Group — Linked/None" inside Chat Tools; no peer name. |
| Editable header | Official: Editable header | partial | `Controllers/TGGroupSettingsViewController.m:1244` | Name and description are one-line alert inputs; photo is a separate row. |
| Public link row | Official: Public link row | partial | `Controllers/TGGroupSettingsViewController.m:493` | Username and type live in Group Settings; no link row on the profile. |
| Recent actions | Official: Recent actions | partial | `Controllers/TGChatToolsViewController.m:273` | Flat 100-event list; no search, filters or detail. |
| Statistics with graphs | Official: Statistics with graphs | partial | `Controllers/TGChatToolsViewController.m:301` | Flat totals list; no graphs or boosts tab. |
| Boosts | Official: Boosts | missing | `Controllers/TGChatToolsViewController.m:149` | No profile or settings surface; calls exist only in the `TG_DEV` Stars console. |
| Bot info card | Official: Bot info card | partial | `Controllers/TGProfileViewController+Actions.m:292` | Only a Bot Settings row; `bot_info` is read for a description but no commands or Add to Chat. |
| Affiliate program row | Official: Affiliate program row | partial | `Controllers/TGAffiliateProgramsViewController.m:50` | Debug console that asks for a bot id, channel id and program id; no commission badge. |
| Statistics and recent actions as settings rows | Official: Statistics and recent actions as settings rows | partial | `Controllers/TGChatToolsViewController.m:149` | Both live behind Group Settings → Tools → Chat Tools. |
| Available-reactions label | Official: Available-reactions label | partial | `Controllers/TGChatToolsViewController.m:161` | Any non-all set is labelled "Three emoji". |
| Reactions settings | Official: Reactions settings | partial | `Controllers/TGChatToolsViewController.m:486` | Two choices only: all, or 👍 ❤️ 🔥. |
| Member rows | Official: Member rows | partial | `Views/TGMemberCell.m:55` | Name and role badge only; no second line, presence or swipe. |
| Member counts | Official: Member counts | partial | `Controllers/TGProfileViewController.m:247` | "N members" only; other counts are requested but not shown. |
| Member count is a disclosure | Official: Member count is a disclosure | missing | `Controllers/TGProfileViewController.m:819` | Every details row copies its value, including the member count. |
| Join request rows | Official: Join request rows | partial | `Controllers/TGGroupSettingsViewController.m:1526` | Name only. |
| Invite-link rows | Official: Invite-link rows | partial | `Controllers/TGGroupSettingsViewController.m:1963` | One mixed list; revoked links are prefixed "(revoked)". |
| Group history screen | Official: Group history screen | partial | `Controllers/TGGroupSettingsViewController.m:580` | One "All History" switch. |
| Group call entry | Official: Group call entry | done | `Controllers/TGGroupSettingsViewController.m:1216` | Opens `TGGroupCallViewController` with the chat's call id. |
| Video chat setup | Official: Video chat setup | done | `Controllers/TGGroupSettingsViewController.m:1230` | Create/schedule, RTMP, recording, screen sharing, participants. |
| Group-call audio | Official: Group-call audio | missing | `Controllers/TGGroupCallViewController.m:338` | The screen says it has no group-call audio engine; no join media. |
| Leave group | Official: Leave group | done | `Controllers/TGGroupSettingsViewController.m:1124` | With confirmation. |
| Delete group for everyone | Official: Delete group for everyone | done | `Controllers/TGGroupSettingsViewController.m:1144` | Owner-only path. |
| Clear history by date | Official: Clear history by date | done | `Controllers/TGGroupSettingsViewController.m:1740` | Date picker, then `deleteChatMessagesByDate`. |
| Group sticker set | Official: Group sticker set | done | `Controllers/TGGroupSettingsViewController.m:1767` | Pack picker for group stickers or custom emoji. |
| Group location | Official: Group location | done | `Controllers/TGChatToolsViewController.m:188` | `setLocation` with map point. |
| Chat Tools | Official: Chat Tools | done | `Controllers/TGGroupSettingsViewController.m:1670` | Event log, statistics, similar chats, moderation and appearance. |
| Group calls tab entry | Official: Group calls tab entry | done | `Controllers/TGProfileViewController+Actions.m:384` | "Calls" row in the group profile menu. |
| View with Topics entry | Official: View with Topics entry | done | `Controllers/TGProfileViewController+Actions.m:385` | "View with Topics" pushes the topic list. |
| Import migration history | Official: Import migration history | done | `Controllers/TGGroupSettingsViewController.m:1820` | Reads a Telegram export from Documents. |
| Communities | Official: Communities | partial | `Controllers/TGProfileViewController.m`, `Core/TGMessageCard.m` | A channel or group profile shows its community (picture, name, chat count) and opens it; "added to a community" draws as a card with View. The communities list itself is still reached only from the dev hub. |
| Scam / fake warning | Official: Scam / fake warning | missing | — | Group and channel `verification_status` is not read. |
| Members tab / row with total | Official: Members tab / row with total | missing | — | No tab and no row; the list is a section of the profile. |
| Administrators row and screen | Official: Administrators row and screen | missing | — | `administratorsOfChat` is only used by the member action sheet. |
| Removed / banned users screen | Official: Removed / banned users screen | missing | — | No banned or restricted filter screen. |
| Linked channel row | Official: Linked channel row | missing | — | Not shown on a group profile. |
| Verification note and verifier tools | Official: Verification note and verifier tools | missing | — | Only a debug "Verify A User Or Chat" row exists. |
