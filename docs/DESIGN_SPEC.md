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

Light only: Night and Auto-Night were removed in `8e86854`, and a chat theme
file that declares a dark palette is refused. Roles live in `TGTheme+Colours`;
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
