Chats screen: the list engine, rows, folders, archive, stories strip and search. Parity items come from `_parity_audit/chat_list.md`; checked against `src/` on 7 November 2026.

Counts: 31 done, 15 partial, 22 missing, 0 dev-only.

Built: M3 (snapshot first paint, 12 retries, live re-sort, badges, archive,
folders, bulk actions), M10 (pull-down search), M11 (stories strip, collapsed
story), M16 (preview for every content type), M17 (emoji status). Open: M24
(thumbnails, type glyph, reaction/poll badges, compact counts, tab badge,
folder tags) and M25 (story ring on every row).
Search filters and tokens are M26.

| Feature | State | Where | Note |
|---|---|---|---|
| First paint from a saved snapshot | done | `Features/ChatList/TGChatListViewController.m:121` | `loadChatSnapshot` draws the previous list before `loadChats` answers. |
| `loadChats` retry | done | `Core/Client/Chats/TGClient+Chats.mm:8` | Up to 12 attempts, then the cached list stays. |
| Live list update | done | `src/Features/ChatList/Core/TGChatListLifecycle.m:208` | `onChatsChanged` reloads and re-sorts using TDLib order. |
| Row count and title | done | `src/Features/ChatList/Core/TGChatListTable.m:265` | Header rows (Saved Messages, archive) plus visible chats. |
| Unread count badge | done | `src/Features/ChatList/Core/TGChatListTable.m:384` | Up to "9999+"; muted chats use the muted colour. |
| Mention badge | done | `src/Features/ChatList/Core/TGChatListTable.m:373` | Separate "@" badge. |
| Blank badge for marked unread | done | `src/Features/ChatList/Core/TGChatListTable.m:376` | A marked-read chat with zero messages shows an empty badge. |
| Reaction badge | missing | `src/Features/ChatList/Core/TGChatListTable.m:371` | Only `unread` and `unreadMentions` are read. |
| Poll-vote badge | missing | `src/Features/ChatList/Core/TGChatListTable.m:371` | `unreadPollVotes` is not a row field. |
| Compact counts ("1.2K") | missing | `src/Features/ChatList/Core/TGChatListTable.m:384` | Counts are plain decimals. |
| Pinned mark beside a badge | done | `src/Features/ChatList/Core/TGChatListTable.m:380` | Pin and unread count both draw; geometry keeps them apart. |
| Pinned row tint | missing | `Features/Chat/Views/TGChatCell.m:53` | Every row uses `listBackgroundColour`; only the pin glyph differs. |
| Muted speaker | done | `src/Features/ChatList/Core/TGChatListTable.m:369` | Mute icon after the title. |
| Online dot on the row | done | `src/Features/ChatList/Core/TGChatListTable.m:344` | Shown when the chat row says the peer is online. |
| Emoji status after the title | done | `src/Features/ChatList/Core/TGChatListTable.m:360` | Custom emoji picture, skipped for Saved Messages. |
| Verified and Premium marks beside the title | partial | `src/Features/ChatList/Core/TGChatListTable.m:360` | Emoji status draws; `is_verified` and `is_premium` are not read on a row. |
| Story ring on every row avatar | missing | `Features/Chat/Views/TGChatCell.m:56` | Only the strip tile has a ring; rows draw a plain avatar. |
| Avatar or initials | done | `src/Features/ChatList/Core/TGChatListTable.m:394` | Downloaded photo, Saved Messages glyph, or stable initials. |
| Preview text | done | `src/Features/ChatList/Core/TGChatListTable.m:334` | `previewText`, sender prefix, two lines. |
| Draft preview | done | `src/Features/ChatList/Core/TGChatListTable.m:332` | Draft wins over the last message and is coloured destructive. |
| Typing preview with sender name | partial | `src/Features/ChatList/Core/TGChatListTable.m:331` | The action phrase appears but never names who is typing. |
| Delivery ticks on your last message | done | `src/Features/ChatList/Core/TGChatListTable.m:348` | Sent/read ticks, or the failed mark from `TGSendStore`; a pending last message still has no clock. |
| Photo/video thumbnail in the preview | missing | `src/Features/ChatList/Core/TGChatListTable.m:334` | Only text is drawn. |
| Content-type glyph in the preview | missing | `src/Features/ChatList/Core/TGChatListTable.m:334` | No type glyph. |
| Date of the last message | done | `src/Features/ChatList/Core/TGChatListTable.m:330` | `TGChatDate` keeps today as a clock. |
| Folder tags on the row | missing | `Core/Client/Chats/TGClient+ChatFolders.mm:483` | `chat_lists` is not copied into the row model and no tag strip is drawn. |
| Forum row names its latest topics | missing | `src/Features/ChatList/Core/TGChatListSelection.m:130` | The row previews the last message; a tap opens the topic list, not a topic. |
| Archive row with unread and story states | partial | `src/Features/ChatList/Core/TGChatListReload.m:195` | Appears under the stories strip; the subtitle has a chat count but no archived-story or unread state. |
| Archive screen with its own More menu | partial | `src/Features/ChatList/Core/TGChatListReload.m:339` | Pushes the filtered list, but `buildHeaderButtons` returns early, so the archive has no bar actions. |
| Stories strip | done | `src/Features/ChatList/Core/TGChatListTable.m:215` | Horizontal story rings above the first chat. |
| My Story first tile | partial | `src/Features/ChatList/Core/TGChatListReload.m:306` | The tile always draws a plus; it does not become a ring when own stories exist. |
| Story tile hold menu | done | `src/Features/ChatList/Core/TGChatListReload.m:276` | Hide from row / move to main. |
| Collapsed story beside the title | done | `src/Features/ChatList/Core/TGChatListLifecycle.m:393` | First active story appears once the strip scrolls off. |
| Edit mode selection | done | `src/Features/ChatList/Core/TGChatListHeader.m:172` | Checkmarks, Select All, count. |
| Bulk pin / read / mute / archive / delete | done | `src/Features/ChatList/Core/TGChatListHeader.m:266` | Toolbar actions apply to every selected chat. |
| Drag pinned chats | done | `src/Features/ChatList/Core/TGChatListTable.m:434` | Only pinned rows get a move handle; writes the whole pinned list. |
| Hold menu | partial | `Features/ChatList/TGChatListViewController+Actions.m:109` | Has those actions; no Add to Contacts, Add/Remove Folder or Select. |
| Swipe actions on iOS 8+ | partial | `Features/ChatList/TGChatListViewController+Actions.m:267` | Five text buttons on one swipe; at 320 pt the delete target is very narrow. |
| Delete with undo window | done | `Features/ChatList/TGChatListViewController+Actions.m:213` | Row returns if the snackbar is not committed. |
| Compose sheet | partial | `src/Features/ChatList/Core/TGChatListCompose.m:112` | Four choices then the contacts picker; no New Contact row or compose search. |
| Join a chat or folder by link | done | `src/Features/ChatList/Core/TGChatListCompose.m:172` | Resolves invite links and folder links. |
| Saved Messages row | missing | `src/Features/ChatList/Core/TGChatListReload.m:196` | `headerRows` only ever adds the archive; `openSavedMessages` has no reachable caller here. |
| Empty state | partial | `src/Features/ChatList/Core/TGChatListReload.m:163` | Main list has illustration and "No chats yet"; the archive and folders return before it and stay blank. |
| Network state as the title subtitle | partial | `src/Features/ChatList/Core/TGChatListLifecycle.m:219` | "Waiting for network" replaces the second line; no spinner and the line disappears on ready. |
| Proxy and lock marks in the title row | missing | `src/Features/ChatList/Core/TGChatListLifecycle.m:282` | Only a text subtitle; no proxy mark or passcode lock. |
| Header hierarchy | partial | `src/Features/ChatList/Core/TGChatListHeader.m:590` | Story strip, search and pills all live in `tableHeaderView`; `parkOffset` is zero, so the stack scrolls away. |
| Unread badge on the Chats tab | missing | `App/RootViewController.m:97` | `tabBarItem` has no badge update anywhere. |
| Folder list on the title chevron | done | `Features/ChatList/TGChatListViewController+Actions.m:24` | Lists folders plus "Mark All Read". |
| Folder tabs with counts | partial | `src/Features/ChatList/Core/TGChatListHeader.m:379` | Pills draw without a per-folder unread count or edit/delete. |
| Folder bar stays pinned and capsule-selected | missing | `src/Features/ChatList/Core/TGChatListHeader.m:590` | The strip scrolls away and the selected pill is a solid accent fill. |
| Title stays "Chats" | missing | `src/Features/ChatList/Core/TGChatListLifecycle.m:310` | The title is replaced by the selected folder's name. |
| Long-press folder reorder | done | `src/Features/ChatList/Core/TGChatListHeader.m:498` | Drags the strip and persists the order. |
| Create / rename / delete folders | done | `Features/Settings/TGSettingsViewController+NetworkPages.m:249` | Create, rename, add/remove chats, counts, icons, delete. |
| Folder edit/delete in the strip | missing | `src/Features/ChatList/Core/TGChatListHeader.m:379` | Editing lives only in Settings; the strip has no edit/delete. |
| Recommended folders | done | `Features/Settings/TGSettingsViewController+NetworkPages.m:308` | Suggested folders can be created. |
| Archive appears once | partial | `src/Features/ChatList/Core/TGChatListHeader.m:441` | With a folder and archived chats, both an "Archived" pill and an "Archived Chats" row appear. |
| Pull-down search field | done | `src/Features/ChatList/Core/TGChatListFolders.m:252` | Opens on the stories row; the field appears on pull. |
| Local title search | done | `Features/ChatList/TGChatListViewController+Search.m:18` | Case-insensitive title match, instant. |
| Message search from the field | done | `Features/ChatList/TGChatListViewController+Search.m:18` | `searchMessages:` results are appended below title hits. |
| Global search screen | partial | `Features/ChatList/TGChatListViewController+Search.m:11` | All/Chats/Messages/Media/Links/Files/Music/Voice; no Channels, Apps, Posts or Downloads. |
| Search results use real rows | missing | `Features/ChatList/TGSearchViewController.m:938` | Generic subtitle cells with a disclosure chevron for every hit. |
| Search filter bar at the bottom | partial | `Features/ChatList/TGSearchViewController.m:236` | Scope pills sit in `tableHeaderView` and scroll away; selected pill is a plain accent fill. |
| Search tokens for archive, folder, peer and date | missing | `Features/ChatList/TGSearchViewController.m:131` | No tokens; every query is global. |
| Downloads shortcut in search | missing | `Features/ChatList/TGSearchViewController.m:65` | Nothing; downloads live only under Settings. |
| Header notice panel | missing | `src/Features/ChatList/Core/TGChatListHeader.m:590` | `updateSuggestedActions` is read only by the Tier 2 hub, never on the list. |
| Real peek on hold | missing | `Features/ChatList/TGChatListViewController+Actions.m:98` | A centred action menu only; no preview card. |
| Group preview with an author prefix stays one line | missing | `Features/Chat/Views/TGChatCell.m:73` | `previewLabel.numberOfLines = 2` always, so "Ivan: …" can wrap under the author. |
| Archive intro pages | missing | — | No archive intro or empty-archive state. |
