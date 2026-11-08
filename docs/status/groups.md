Groups and forums: creating, the member list, member actions, permissions, invite links, topics, group calls and administration. Parity items from `_parity_audit/profile_group.md`; checked against `src/` on 7 November 2026.

Counts: 48 done, 29 partial, 11 missing, 0 dev-only.

Built: M7 (creation, member list and actions, ownership transfer, permissions,
slow mode, invite links, join requests, topics, group-call entry). Open: M36
(admin rights editor, member paging, invite-link detail, administrators and
removed users, statistics graphs, boosts); M21 group-call audio.

| Feature | State | Where | Note |
|---|---|---|---|
| Create a basic group | done | `Features/Contacts/TGContactsViewController.m:620` | Contact picker with group mode sends `createNewBasicGroupChat`. |
| Create a supergroup | done | `src/Features/Groups/Core/TGGroupMembers.m:138` | Upgrade path from a basic group. |
| New Group full form | partial | `Features/Contacts/TGContactsViewController.m:535` | Picks members first, then asks for a name in an alert. |
| Group profile summary | done | `src/Features/Profile/Core/TGProfileHeader.m:435` | Description, member count, invite link, linked chat, community. |
| Verified check beside a name | partial | `src/Features/Profile/Core/TGProfileHeader.m:254` | User profiles draw the check; group and channel records do not. |
| Group subtitle "N members, M online" | partial | `src/Features/Profile/Core/TGProfileLifecycle.m:244` | "N members" only; the online count is stored on the chat but not read by the profile. |
| Member list | partial | `Core/Client/Chats/TGClient+ChatMembers.mm:36` | The first 50 members load into the profile itself; no paging. |
| Member search with sections | partial | `src/Features/Groups/Core/TGGroupMembers.m:178` | One flat `chatMembersFilterMembers` result; no sections or counts. |
| Add members | done | `src/Features/Groups/Core/TGGroupMembers.m:168` | Contact picker respects the invite right. |
| Find member | done | `src/Features/Groups/Core/TGGroupMembers.m:178` | Search by name or @username. |
| Member actions sheet | done | `Features/Groups/TGGroupMemberActions.m:95` | Info, details, message, promote, tag, clear, remove, ban, ownership. |
| Promote to admin | partial | `Features/Groups/TGGroupMemberActions.m:215` | Sends the default `TGAdminRights()`; no rights chooser. |
| Dismiss as admin | done | `Features/Groups/TGGroupMemberActions.m:219` | Returns the member to plain member status. |
| Ban a member | done | `Features/Groups/TGGroupMemberActions.m:271` | Permanent ban with message revoke off. |
| Temporarily restrict a member | missing | `Features/Groups/TGGroupMemberActions.m:126` | No restrict path; only ban. |
| Set member tag | done | `Features/Groups/TGGroupMemberActions.m:223` | `setChatMemberTag`. |
| Clear their reactions | done | `Features/Groups/TGGroupMemberActions.m:239` | `deleteAllReactionsOfSender`. |
| Clear their messages | done | `Features/Groups/TGGroupMemberActions.m:252` | `deleteChatMessagesBySender` with revoke. |
| Remove from group | done | `Features/Groups/TGGroupMemberActions.m:267` | Sets status left. |
| Hand over ownership | done | `Features/Groups/TGGroupMemberActions.m:284` | 2FA password and `canTransferOwnership` pre-check. |
| Per-admin rights editor | missing | `Core/Client/TGClient+Groups.m:22` | Promote sends one fixed rights object; no editor screen. |
| Default admin rights | done | `Features/Groups/TGAdminRightsViewController.m:115` | Group and channel presets. |
| Granular member permissions | partial | `src/Features/Groups/Core/TGGroupPermissions.m:168` | Three presets: everything, messages only, read only. |
| Slow mode | done | `src/Features/Groups/Core/TGGroupPermissions.m:191` | 0, 5, 10, 30 s, 1, 5, 15 min, 1 h. |
| Slow mode once | partial | `src/Features/Groups/Core/TGGroupPermissions.m:191` | Duplicated in Chat Tools, which also prints 3600 as "3600 s". |
| Sign messages | done | `src/Features/Groups/Core/TGGroupSections.m:354` | Switch writes `sign_messages`. |
| Join to send | done | `src/Features/Groups/Core/TGGroupSections.m:356` | Switch writes `join_to_send_messages`. |
| All history visible | partial | `src/Features/Groups/Core/TGGroupSections.m:358` | Switch only; no Visible/Hidden screen or explanation. |
| Hidden members | partial | `src/Features/Groups/Core/TGGroupSections.m:377` | Switch in Permissions and Behaviour, away from the member list. |
| Aggressive anti-spam | done | `src/Features/Groups/Core/TGGroupSections.m:360` | Switch with allow flag and the server's refusal. |
| Anti-spam false positive | done | `Features/Groups/TGAntiSpamViewController.m:20` | Report a message deleted by mistake. |
| Join by request | done | `src/Features/Groups/Core/TGGroupSections.m:372` | Switch plus the requests screen. |
| Join requests row and screen | partial | `src/Features/Groups/Core/TGGroupPermissions.m:240` | Sheet of names with Accept/Decline; the date is dropped and the bio is never read. |
| Invite links screen | partial | `src/Features/Groups/Core/TGGroupInvites.m:168` | Alert of raw URLs and "N joined"; no dates, limits, QR or separate revoked section. |
| Forum mode | done | `src/Features/Groups/Core/TGGroupSections.m:384` | `is_forum` switch. |
| Topics list | done | `src/Features/ChatList/Core/TGChatListSelection.m:135` | `isForum` routes the row to `TGTopicsViewController`. |
| Create a topic | done | `Features/Groups/TGTopicsViewController.m:383` | Name plus custom emoji icon picker. |
| Rename a topic | done | `Features/Groups/TGTopicsViewController.m:534` | `renameForumTopic`. |
| Change topic icon | done | `Features/Groups/TGTopicsViewController.m:511` | `setForumTopicIcon`; General topic refusal explained. |
| Close / reopen a topic | done | `Features/Groups/TGTopicsViewController.m:451` | Hold menu toggles closed. |
| Pin / unpin a topic | done | `Features/Groups/TGTopicsViewController.m:451` | Hold menu plus the pinned-topics manager. |
| Delete a topic | done | `Features/Groups/TGTopicsViewController.m:451` | Confirmed delete of the topic and its messages. |
| Topic info | done | `Features/Groups/TGTopicsViewController.m:179` | Topic Info list with counts and settings. |
| Topic notifications | done | `Features/Groups/TGTopicsViewController.m:181` | Mute/sound for one topic. |
| Pinned topics manager | done | `Features/Groups/TGTopicsViewController.m:183` | Reorder and unpin from one list. |
| Hide the General topic | done | `Features/Groups/TGTopicsViewController.m:361` | Toggle from the topic menu. |
| Topic read state and badges | done | `Features/Groups/TGTopicsViewController.m:189` | Mentions, polls and reactions badges; clears reactions. |
| Broadcast group | done | `src/Features/Groups/Core/TGGroupPermissions.m:215` | Convert with confirmation. |
| Welcome messages | partial | `src/Features/Groups/Core/TGGroupPermissions.m:288` | Text only, and in Group Settings rather than the profile. |
| Automatic translation | done | `src/Features/Groups/Core/TGGroupSections.m:402` | Switch writes the automatic-translation field. |
| Group usernames | done | `src/Features/Groups/Core/TGGroupUsernames.m:168` | Editable, active, disabled; remove and disable all. |
| Subscription links | done | `src/Features/Groups/Core/TGGroupInvites.m:420` | Paid invite link creation. |
| Discussion group row | partial | `Features/Chat/TGChatToolsViewController.m:184` | "Discussion Group — Linked/None" inside Chat Tools; no peer name. |
| Editable header | partial | `src/Features/Groups/Core/TGGroupIdentity.m:196` | Name and description are one-line alert inputs; photo is a separate row. |
| Public link row | partial | `src/Features/Groups/Core/TGGroupSections.m:271` | Username and type live in Group Settings; no link row on the profile. |
| Recent actions | partial | `Features/Chat/TGChatToolsViewController.m:273` | Flat 100-event list; no search, filters or detail. |
| Statistics with graphs | partial | `Features/Chat/TGChatToolsViewController.m:301` | Flat totals list; no graphs or boosts tab. |
| Boosts | missing | `Features/Chat/TGChatToolsViewController.m:149` | No profile or settings surface; calls exist only in the `TG_DEV` Stars console. |
| Bot info card | partial | `Features/Profile/TGProfileViewController+Actions.m:292` | Only a Bot Settings row; `bot_info` is read for a description but no commands or Add to Chat. |
| Affiliate program row | partial | `Features/BotsPayments/TGAffiliateProgramsViewController.m:50` | Debug console that asks for a bot id, channel id and program id; no commission badge. |
| Statistics and recent actions as settings rows | partial | `Features/Chat/TGChatToolsViewController.m:149` | Both live behind Group Settings → Tools → Chat Tools. |
| Available-reactions label | partial | `Features/Chat/TGChatToolsViewController.m:161` | Any non-all set is labelled "Three emoji". |
| Reactions settings | partial | `Features/Chat/TGChatToolsViewController.m:486` | Two choices only: all, or 👍 ❤️ 🔥. |
| Member rows | partial | `Features/Profile/TGMemberCell.m:55` | Name and role badge only; no second line, presence or swipe. |
| Member counts | partial | `src/Features/Profile/Core/TGProfileLifecycle.m:247` | "N members" only; other counts are requested but not shown. |
| Member count is a disclosure | missing | `src/Features/Profile/Core/TGProfileData.m:417` | Every details row copies its value, including the member count. |
| Join request rows | partial | `src/Features/Groups/Core/TGGroupPermissions.m:249` | Name only. |
| Invite-link rows | partial | `src/Features/Groups/Core/TGGroupInvites.m:223` | One mixed list; revoked links are prefixed "(revoked)". |
| Group history screen | partial | `src/Features/Groups/Core/TGGroupSections.m:358` | One "All History" switch. |
| Group call entry | done | `src/Features/Groups/Core/TGGroupIdentity.m:168` | Opens `TGGroupCallViewController` with the chat's call id. |
| Video chat setup | done | `src/Features/Groups/Core/TGGroupIdentity.m:182` | Create/schedule, RTMP, recording, screen sharing, participants. |
| Group-call audio | missing | `Features/Calls/TGGroupCallViewController.m:338` | The screen says it has no group-call audio engine; no join media. |
| Leave group | done | `src/Features/Groups/Core/TGGroupSwitches.m:308` | With confirmation. |
| Delete group for everyone | done | `src/Features/Groups/Core/TGGroupActions.m:137` | Owner-only path. |
| Clear history by date | done | `src/Features/Groups/Core/TGGroupTools.m:238` | Date picker, then `deleteChatMessagesByDate`. |
| Group sticker set | done | `src/Features/Groups/Core/TGGroupTools.m:265` | Pack picker for group stickers or custom emoji. |
| Group location | done | `Features/Chat/TGChatToolsViewController.m:188` | `setLocation` with map point. |
| Chat Tools | done | `src/Features/Groups/Core/TGGroupTools.m:168` | Event log, statistics, similar chats, moderation and appearance. |
| Group calls tab entry | done | `Features/Profile/TGProfileViewController+Actions.m:384` | "Calls" row in the group profile menu. |
| View with Topics entry | done | `Features/Profile/TGProfileViewController+Actions.m:385` | "View with Topics" pushes the topic list. |
| Import migration history | done | `src/Features/Groups/Core/TGGroupTools.m:318` | Reads a Telegram export from Documents. |
| Communities | partial | `Features/Profile/TGProfileViewController.m`, `Core/Model/TGMessageCard.m` | A channel or group profile shows its community (picture, name, chat count) and opens it; "added to a community" draws as a card with View. The communities list itself is still reached only from the dev hub. |
| Scam / fake warning | missing | — | Group and channel `verification_status` is not read. |
| Members tab / row with total | missing | — | No tab and no row; the list is a section of the profile. |
| Administrators row and screen | missing | — | `administratorsOfChat` is only used by the member action sheet. |
| Removed / banned users screen | missing | — | No banned or restricted filter screen. |
| Linked channel row | missing | — | Not shown on a group profile. |
| Verification note and verifier tools | missing | — | Only a debug "Verify A User Or Chat" row exists. |
