# Design Spec — iOS 6 Reimagined

**Project:** LegacyTG · **Target:** iOS 6.0–12.5.7, armv7 & arm64

## Concept

A Telegram client that looks like the iOS it runs on. Since the November 2026
pass (`996512d`, `8e0d1b4`, `8e86854`) the chrome — bars, grouped tables,
settings cells, switches, search, alerts — is the system's own UIKit drawing
on every supported version. The app draws only what the system has no analogue
for: the chat canvas, custom sheets, snackbars, the media viewer, the player,
the call screen and the procedural icon engine. Light only: a theme file
recolours the chat, never the chrome.

Drawing that the app still does is CoreGraphics, `@1x`/`@2x` cached, targeting
60 FPS on A5/A6.

No neon gradients, no card-in-card layouts, no emoji as UI icons.

## Token system

All colours from `TGTheme+Colours`. All sizes and metrics from
`src/Core/Style/TGStyle.h`. Screens ask for a role, never a number.
`scripts/lint_tokens.sh` enforces this.

### Type scale

| Role | Size | Weight | Usage |
|---|---|---|---|
| `TGFontTitle` | 17pt | Semibold | Navigation titles |
| `TGFontRow` | 16pt | Regular | List rows |
| `TGFontCaption` | 13pt | Regular | Subtitles, timestamps |
| `TGFontFootnote` | 11pt | Regular | Badges, labels |
| `TGFontMono` | 13pt | Regular | Code spans |

### Colour roles

Light by default. Night was removed in `8e86854` while the only palettes were
home-made; since `9c93e8f` an official theme file that declares a dark
palette is accepted, and Night Blue ships built in. There is no Auto-Night.
Roles live in `TGTheme+Colours`;
the app draws no hue the running OS does not also know:

| Token | Role |
|---|---|
| `groupedBackgroundColour` / `listBackgroundColour` | screen and list plates |
| `cardBackgroundColour` | cards over a grouped screen |
| `primaryTextColour` / `secondaryTextColour` | text |
| `accentColour` / `onAccentColour` | buttons, links, unread badges; content over them |
| `destructiveColour` | delete actions |
| `separatorColour` | hairlines, bubble borders |
| `bubbleMineColour` / `bubbleTheirsColour` | the chat — the only surface a theme file recolours |
| `barTitleColour` / `barSubtitleColour` / `barButtonColour` | content the system bar draws |

### Metrics

| Token | Value |
|---|---|
| `TGMetricListAvatar` | 40 pt |
| `TGMetricTabBarH` | 49 pt (the system tab bar's own height) |
| `TGMetricInputBarHeight` | 48 pt |
| `TGMetricCallButtonSide` | 60 pt |
| `TGMetricCornerControl` | 8 pt |

The navigation bar has no metric of ours — the system draws it.

## Messages & feedback

| Component | Behaviour |
|---|---|
| `TGSnackbar` | Bar above the chrome, countdown ring, Undo |
| `TGAlertSheet` | The system alert under iOS 7, `UIAlertController` from iOS 8, behind one block API: message, confirm, choices, input (incl. secure entry) |
| `TGAlertSheet` (destructive) | Destructive confirms are asked from an action sheet with a red button |
| `TGStatusBanner` | Pinned under nav bar — Connecting / Updating + native spinner |
| `TGEmptyView` | Centered illustration, headline, action button |
| Form errors | Red input border, red caption + warning glyph |

## Action → presentation

One kind of action opens one way everywhere. A screen calls the left column's
API and never builds the thing itself (`scripts/lint_presentation.sh`). The
right column is where official Telegram iOS does it (`submodules/…`), which is
what each row was checked against.

### Navigation bar

| Action | Call | Official |
|---|---|---|
| Leave a pushed screen | system Back from `TGNavController` | `NavigationController`, title "Back" (`Common.Back`) |
| Leave a form without saving | `TGBarItem TGBarRoleCancel`, left | `ItemListController` left `.icon(.close)` / `Common.Cancel` |
| Save a form, end editing | `TGBarRoleDone`, right, bold | right `.icon(.done)` / `Common.Done`, `.bold` |
| Edit a list | `TGBarRoleEdit`, right; Done replaces it | `Common.Edit`, `.regular`, right (12 lists) |
| Leave a sheet with nothing to save | `TGBarRoleClose`, left | left `.icon(.close)` / `Common.Close` |
| A screen's actions (⋯) | `TGBarRoleMore` → `TGPresent showMenu:fromBarItem:` | `MoreHeaderButton` → `ContextController` `.reference` (PeerInfoScreen, ChatListController header) |
| Add to the list | `TGBarRoleAdd`, right, UIKit's own + | `.icon(.add)` |
| Share what is shown | `TGBarRoleShare`, right | `.icon(.action)` |
| Search the screen | `TGBarRoleSearch`, UIKit's magnifier | `.icon(.search)` |
| New message | `TGBarRoleCompose`, UIKit's compose | chat list compose button |
| Cancel and Done over a picker in a toolbar | `TGBarItem plainItemWithTitle:` + `itemWithTitle:primary:YES` | date and time pickers |
| Next step of a flow, Send, Create | `TGBarItem itemWithTitle:primary:YES` | `Common.Next` / `Compose.Create` / `ShareMenu.Send`, `.bold` |
| Saving in progress | `TGBarItem activityItem` | `.activity` |

### Opening things

| Action | Call | Official |
|---|---|---|
| A form to fill in (new contact, edit profile, new link) | `TGPresent presentModal:kind:TGModalForm` | modal `ItemListController`, Cancel left, Done/Create right |
| A page to read over the current one (file info) | `presentModal:kind:TGModalInfo` | modal with Close left |
| A screen from a place with or without a stack | `TGPresent openController:from:` | `push` on the nearest `NavigationController` |
| Actions of a long-pressed row (chat list, member, link) | `TGPresent showMenu:fromView:` / `showMenuTitles:` → `TGPopupMenu` card | `ContextController` `.extracted` (ChatContextMenus, PeerInfoScreen) |
| Actions of a long-pressed message, with reactions | `TGPopupMenu showItems:anchoredAt:…reactions:` | `ContextController` with the reaction bar (ChatControllerNode) |
| Actions of the media viewer and stories (⋯) | `showMenu:fromBarItem:` / `fromView:` | `ContextController` `.reference` (GalleryUI, StoryContainerScreen) |
| Confirming a delete, leave, block, clear | `TGAlertSheet showConfirm:… destructive:YES` | `ActionSheetController`, red button + Cancel (ChatListController delete, ChatControllerReport) |
| Delete for me / for everyone, other 2–4 way picks | `TGAlertSheet showChoices:` | `ActionSheetController` buttons (ChatList.DeleteForCurrentUser / DeleteForEveryone) |
| Something to read, one OK | `TGAlertSheet showMessage:` | `textAlertController` with `Common.OK` |
| A question with two real answers | `TGAlertSheet showAlertActions:` / `showConfirm:… destructive:NO` | `textAlertController` (LogoutOptionsController, ChangePhoneNumberController) |
| A list of things (voters, reactions, members, links) | `TGPresent showList:` → pushed `TGRowsViewController` | peer / item list screens |
| Attachments, scheduled messages, bottom pickers | a `TGSheet` subclass | `AttachmentController` / sheet screens |
| A photo or video from the library, the camera | `TGPresent pickMediaFrom:` | `MediaPickerScreen` (ours: the system picker; iPad before iOS 8 in a popover) |
| Sharing a file or link outside Telegram | `TGPresent shareItems:` | `ShareController` → system activity sheet for external apps |
| A file another app opens | `TGPresent openDocument:` | Quick Look, else Open In |

Our differences on purpose: the bar uses iOS 6 bordered text buttons where
official now draws round glass ✕ / ✓ icons, and the photo picker is the
system one, since `MediaPickerScreen`'s live grid does not run on the A4.
