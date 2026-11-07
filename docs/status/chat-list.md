Chats screen: the list engine, rows, folders, archive, stories strip and search. Parity items come from `_parity_audit/chat_list.md`; checked against `src/` on 7 November 2026.

Counts: 30 done, 16 partial, 22 missing, 0 dev-only.

**What is built.** The list engine is M3. `loadChatSnapshot` paints the previous list before
`loadChats` answers, twelve retries fall back to the cached list, and
`onChatsChanged` re-sorts by TDLib order. Rows carry unread and mention
badges, mute and online marks, emoji status, avatar or initials, preview text,
drafts and pins; the archive, folder strip, drag order and bulk actions are in
the same milestone.

M10 added pull-down search with local title hits and appended message hits.
M11 added the stories strip, the collapsed story beside the title and the tile
hold menu; M16 gave the preview every content type, and M17 put emoji status
on the row and in group sender names.

The missing half is M24 (thumbnails, type glyph, reaction and poll badges,
compact counts, tab badge, folder tags) and M25 (a story ring on every row).
Search filters and tokens are M26.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| First paint from a saved snapshot | Official: First paint from a saved snapshot | done | `Controllers/TGChatListViewController.m:121` | `loadChatSnapshot` draws the previous list before `loadChats` answers. |
| `loadChats` retry | Official: `loadChats` retry | done | `Core/TGClient+Chats.mm:196` | Up to 12 attempts, then the cached list stays. |
| Live list update | Official: Live list update | done | `Controllers/TGChatListViewController.m:282` | `onChatsChanged` reloads and re-sorts using TDLib order. |
| Row count and title | Official: Row count and title | done | `Controllers/TGChatListViewController.m:1835` | Header rows (Saved Messages, archive) plus visible chats. |
| Unread count badge | Official: Unread count badge | done | `Controllers/TGChatListViewController.m:1954` | Up to "9999+"; muted chats use the muted colour. |
| Mention badge | Official: Mention badge | done | `Controllers/TGChatListViewController.m:1943` | Separate "@" badge. |
| Blank badge for marked unread | Official: Blank badge for marked unread | done | `Controllers/TGChatListViewController.m:1946` | A marked-read chat with zero messages shows an empty badge. |
| Reaction badge | Official: Reaction badge | missing | `Controllers/TGChatListViewController.m:1941` | Only `unread` and `unreadMentions` are read. |
| Poll-vote badge | Official: Poll-vote badge | missing | `Controllers/TGChatListViewController.m:1941` | `unreadPollVotes` is not a row field. |
| Compact counts ("1.2K") | Official: Compact counts ("1.2K") | missing | `Controllers/TGChatListViewController.m:1954` | Counts are plain decimals. |
| Pinned mark beside a badge | Official: Pinned mark beside a badge | done | `Controllers/TGChatListViewController.m:1950` | Pin and unread count both draw; geometry keeps them apart. |
| Pinned row tint | Official: Pinned row tint | missing | `Views/TGChatCell.m:53` | Every row uses `listBackgroundColour`; only the pin glyph differs. |
| Muted speaker | Official: Muted speaker | done | `Controllers/TGChatListViewController.m:1939` | Mute icon after the title. |
| Online dot on the row | Official: Online dot on the row | done | `Controllers/TGChatListViewController.m:1914` | Shown when the chat row says the peer is online. |
| Emoji status after the title | Official: Emoji status after the title | done | `Controllers/TGChatListViewController.m:1930` | Custom emoji picture, skipped for Saved Messages. |
| Verified and Premium marks beside the title | Official: Verified and Premium marks beside the title | partial | `Controllers/TGChatListViewController.m:1930` | Emoji status draws; `is_verified` and `is_premium` are not read on a row. |
| Story ring on every row avatar | Official: Story ring on every row avatar | missing | `Views/TGChatCell.m:56` | Only the strip tile has a ring; rows draw a plain avatar. |
| Avatar or initials | Official: Avatar or initials | done | `Controllers/TGChatListViewController.m:1964` | Downloaded photo, Saved Messages glyph, or stable initials. |
| Preview text | Official: Preview text | done | `Controllers/TGChatListViewController.m:1904` | `previewText`, sender prefix, two lines. |
| Draft preview | Official: Draft preview | done | `Controllers/TGChatListViewController.m:1902` | Draft wins over the last message and is coloured destructive. |
| Typing preview with sender name | Official: Typing preview with sender name | partial | `Controllers/TGChatListViewController.m:1901` | The action phrase appears but never names who is typing. |
| Delivery ticks on your last message | Official: Delivery ticks on your last message | partial | `Controllers/TGChatListViewController.m:1918` | Sent/read ticks only; no clock and no failed mark. |
| Photo/video thumbnail in the preview | Official: Photo/video thumbnail in the preview | missing | `Controllers/TGChatListViewController.m:1904` | Only text is drawn. |
| Content-type glyph in the preview | Official: Content-type glyph in the preview | missing | `Controllers/TGChatListViewController.m:1904` | No type glyph. |
| Date of the last message | Official: Date of the last message | done | `Controllers/TGChatListViewController.m:1900` | `TGChatDate` keeps today as a clock. |
| Folder tags on the row | Official: Folder tags on the row | missing | `Core/TGClient+Chats.mm:1875` | `chat_lists` is not copied into the row model and no tag strip is drawn. |
| Forum row names its latest topics | Official: Forum row names its latest topics | missing | `Controllers/TGChatListViewController.m:2074` | The row previews the last message; a tap opens the topic list, not a topic. |
| Archive row with unread and story states | Official: Archive row with unread and story states | partial | `Controllers/TGChatListViewController.m:1508` | Appears under the stories strip; the subtitle has a chat count but no archived-story or unread state. |
| Archive screen with its own More menu | Official: Archive screen with its own More menu | partial | `Controllers/TGChatListViewController.m:1652` | Pushes the filtered list, but `buildHeaderButtons` returns early, so the archive has no bar actions. |
| Stories strip | Official: Stories strip | done | `Controllers/TGChatListViewController.m:1785` | Horizontal story rings above the first chat. |
| My Story first tile | Official: My Story first tile | partial | `Controllers/TGChatListViewController.m:1619` | The tile always draws a plus; it does not become a ring when own stories exist. |
| Story tile hold menu | Official: Story tile hold menu | done | `Controllers/TGChatListViewController.m:1589` | Hide from row / move to main. |
| Collapsed story beside the title | Official: Collapsed story beside the title | done | `Controllers/TGChatListViewController.m:467` | First active story appears once the strip scrolls off. |
| Edit mode selection | Official: Edit mode selection | done | `Controllers/TGChatListViewController.m:536` | Checkmarks, Select All, count. |
| Bulk pin / read / mute / archive / delete | Official: Bulk pin / read / mute / archive / delete | done | `Controllers/TGChatListViewController.m:630` | Toolbar actions apply to every selected chat. |
| Drag pinned chats | Official: Drag pinned chats | done | `Controllers/TGChatListViewController.m:2004` | Only pinned rows get a move handle; writes the whole pinned list. |
| Hold menu | Official: Hold menu | partial | `Controllers/TGChatListViewController+Actions.m:109` | Has those actions; no Add to Contacts, Add/Remove Folder or Select. |
| Swipe actions on iOS 8+ | Official: Swipe actions on iOS 8+ | partial | `Controllers/TGChatListViewController+Actions.m:267` | Five text buttons on one swipe; at 320 pt the delete target is very narrow. |
| Delete with undo window | Official: Delete with undo window | done | `Controllers/TGChatListViewController+Actions.m:213` | Row returns if the snackbar is not committed. |
| Compose sheet | Official: Compose sheet | partial | `Controllers/TGChatListViewController.m:1262` | Four choices then the contacts picker; no New Contact row or compose search. |
| Join a chat or folder by link | Official: Join a chat or folder by link | done | `Controllers/TGChatListViewController.m:1322` | Resolves invite links and folder links. |
| Saved Messages row | Official: Saved Messages row | missing | `Controllers/TGChatListViewController.m:1509` | `headerRows` only ever adds the archive; `openSavedMessages` has no reachable caller here. |
| Empty state | Official: Empty state | partial | `Controllers/TGChatListViewController.m:1476` | Main list has illustration and "No chats yet"; the archive and folders return before it and stay blank. |
| Network state as the title subtitle | Official: Network state as the title subtitle | partial | `Controllers/TGChatListViewController.m:293` | "Waiting for network" replaces the second line; no spinner and the line disappears on ready. |
| Proxy and lock marks in the title row | Official: Proxy and lock marks in the title row | missing | `Controllers/TGChatListViewController.m:356` | Only a text subtitle; no proxy mark or passcode lock. |
| Header hierarchy | Official: Header hierarchy | partial | `Controllers/TGChatListViewController.m:954` | Story strip, search and pills all live in `tableHeaderView`; `parkOffset` is zero, so the stack scrolls away. |
| Unread badge on the Chats tab | Official: Unread badge on the Chats tab | missing | `Controllers/RootViewController.m:97` | `tabBarItem` has no badge update anywhere. |
| Folder list on the title chevron | Official: Folder list on the title chevron | done | `Controllers/TGChatListViewController+Actions.m:24` | Lists folders plus "Mark All Read". |
| Folder tabs with counts | Official: Folder tabs with counts | partial | `Controllers/TGChatListViewController.m:743` | Pills draw without a per-folder unread count or edit/delete. |
| Folder bar stays pinned and capsule-selected | Official: Folder bar stays pinned and capsule-selected | missing | `Controllers/TGChatListViewController.m:954` | The strip scrolls away and the selected pill is a solid accent fill. |
| Title stays "Chats" | Official: Title stays "Chats" | missing | `Controllers/TGChatListViewController.m:384` | The title is replaced by the selected folder's name. |
| Long-press folder reorder | Official: Long-press folder reorder | done | `Controllers/TGChatListViewController.m:862` | Drags the strip and persists the order. |
| Create / rename / delete folders | Official: Create / rename / delete folders | done | `Controllers/TGSettingsViewController+NetworkPages.m:249` | Create, rename, add/remove chats, counts, icons, delete. |
| Folder edit/delete in the strip | Official: Folder edit/delete in the strip | missing | `Controllers/TGChatListViewController.m:743` | Editing lives only in Settings; the strip has no edit/delete. |
| Recommended folders | Official: Recommended folders | done | `Controllers/TGSettingsViewController+NetworkPages.m:308` | Suggested folders can be created. |
| Archive appears once | Official: Archive appears once | partial | `Controllers/TGChatListViewController.m:805` | With a folder and archived chats, both an "Archived" pill and an "Archived Chats" row appear. |
| Pull-down search field | Official: Pull-down search field | done | `Controllers/TGChatListViewController.m:1200` | Opens on the stories row; the field appears on pull. |
| Local title search | Official: Local title search | done | `Controllers/TGChatListViewController+Search.m:18` | Case-insensitive title match, instant. |
| Message search from the field | Official: Message search from the field | done | `Controllers/TGChatListViewController+Search.m:18` | `searchMessages:` results are appended below title hits. |
| Global search screen | Official: Global search screen | partial | `Controllers/TGChatListViewController+Search.m:11` | All/Chats/Messages/Media/Links/Files/Music/Voice; no Channels, Apps, Posts or Downloads. |
| Search results use real rows | Official: Search results use real rows | missing | `Controllers/TGSearchViewController.m:938` | Generic subtitle cells with a disclosure chevron for every hit. |
| Search filter bar at the bottom | Official: Search filter bar at the bottom | partial | `Controllers/TGSearchViewController.m:236` | Scope pills sit in `tableHeaderView` and scroll away; selected pill is a plain accent fill. |
| Search tokens for archive, folder, peer and date | Official: Search tokens for archive, folder, peer and date | missing | `Controllers/TGSearchViewController.m:131` | No tokens; every query is global. |
| Downloads shortcut in search | Official: Downloads shortcut in search | missing | `Controllers/TGSearchViewController.m:65` | Nothing; downloads live only under Settings. |
| Header notice panel | Official: Header notice panel | missing | `Controllers/TGChatListViewController.m:954` | `updateSuggestedActions` is read only by the Tier 2 hub, never on the list. |
| Real peek on hold | Official: Real peek on hold | missing | `Controllers/TGChatListViewController+Actions.m:98` | A centred action menu only; no preview card. |
| Group preview with an author prefix stays one line | Official: Group preview with an author prefix stays one line | missing | `Views/TGChatCell.m:73` | `previewLabel.numberOfLines = 2` always, so "Ivan: …" can wrap under the author. |
| Archive intro pages | Official: Archive intro pages | missing | — | No archive intro or empty-archive state. |
