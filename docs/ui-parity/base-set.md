# Base set of screen parts

Screens that follow one template looked different because each built the
missing parts itself: a page header, an empty state, a list of people. This
file is the list of those parts and of the screens moved onto them. The user
approved the direction on 2026-11-14 ("делай, посмотрим как это будет
выглядеть"); each further screen moved goes on this list first.

## The parts

| Part | Where | What is fixed | What a screen supplies |
|---|---|---|---|
| Page shell | `TGRowsViewController` (`TGTableViewController`) | background, separators, header and footer labels, theme repaint | style (grouped settings page or plain list), sections |
| Page header | `TGPageHeaderView` | centred column: picture, title (`TGFontTitle`), line under it (`TGFontSubhead`), paragraph (`TGFontBody`), gaps from `TGCentredStackPlace` | picture or animation, the strings |
| Empty state | `TGEmptyView` through `-showEmptyWithImage:title:subtitle:` | the same column centred in the table (`TGEmptyStatePlace`), icon tint, fonts | icon (optional), title, subtitle |
| Page intro row | `TGKindPageHeader` (`TGPageHeaderRow`) | the page header's column as the first row, no card behind it | picture (or a settings icon name), paragraph |
| Person row | `TGPeerRow` | photo, name, the line under it, chevron | peer id, name, line, title colour for a warning |
| Rows | `TGRows.h` kinds | cell look per kind | row content |

A part without content is left out together with the gap before it, so a
header with no picture or an empty state with no title still sits evenly.

## Moved in this pass

- Gift: art, title and sender are a `TGPageHeaderView` (was hand-placed
  labels with fixed heights).
- File Info: icon, name and size are a centred `TGPageHeaderView` (was an
  icon left of two labels in `TGFontHeader`).
- Search, forward picker, contacts search: "No Results" is the shared empty
  state (were three hand-made `UILabel`s in `TGFontBody`).
- `TGEmptyView` lays out with `TGEmptyStatePlace`; a missing icon or title
  no longer leaves a hole, and the subtitle is measured instead of being two
  fixed lines.
- Scheduled Messages and Sticker Editor no longer paint their grouped table
  with the plain-list colour; Ephemeral no longer repeats the base's paint.
- `TGFormViewController` is deleted: no screen used it.

## Moved in the second pass

- Chat Folders opens with the official intro (folder icon, "Create folders
  for different groups of chats and quickly switch between them."), in the
  page model so the host suite checks it.
- Recent Calls draws each call as a `TGPeerRow`: photo, name (red for a
  missed call), the call line. The empty list says the official "Your recent
  calls will appear here" / "You have no missed calls" under the switch.
- An empty state survives a theme change: `TGTheme` replaces only the plain
  fill it puts in `backgroundView`, so "No Results" stays and repaints.

## Kept on purpose

- Update keeps the official `UpdateInfoController` shape: icon left of the
  version, the changelog below it, left-aligned.
- Topics and Saved Topics keep their own repaint: the base's dark repaint
  replaces `backgroundView`, which is where they hold their empty view.

## Next, not done

- Devices keeps its own session rows (official draws a device tile, not a
  person); a session row kind would match Websites too.
- Passcode Lock intro: the pack has no header sentence for it, only the
  existing footer.
- `TGGroupData` keeps a private row model (`TGRow`, `TGInfoRow`,
  `TGSection`) that is turned into shared rows later; it can build `TGRows`
  directly.
