Every Settings page and the rows that actually open something, plus the Appearance controls and the shared design tokens. Parity rows come from `_parity_audit/settings_main.md`, `settings_look.md` and `design.md`; checked against `src/` on 7 November 2026. Notification and privacy detail live in `notifications.md` and `privacy-security.md`.

Counts: 11 done, 47 partial, 25 missing, 1 dev-only.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Root list | Official: Root list | done | `Controllers/TGSettingsViewController+Pages.m:82` | Profile card, account rows, app settings, help, This Device, Log out. |
| Settings tab icon is the account photo | Official: Settings tab icon is the account photo | missing | `Controllers/RootViewController.m:60` | Always the sliders glyph; no badge or avatar. |
| Settings search | Official: Settings search | missing | `Controllers/TGSettingsViewController+Pages.m:82` | No search field or page index. |
| Accounts switcher | Official: Accounts switcher | partial | `Controllers/TGSettingsViewController+Actions.m:37` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Four account slots | Official: Four account slots | partial | `Core/TGClient+Accounts.m:16` | Three slots for every account. |
| My Profile row | Official: My Profile row | done | `Controllers/TGSettingsViewController+Pages.m:121` | Opens the account's own profile. |
| Account header | Official: Account header | partial | `Controllers/TGSettingsViewController.m:990` | 80 pt avatar in a 168 pt cell, 22 pt name, phone only. |
| QR and Edit bar items | Official: QR and Edit bar items | missing | `Controllers/TGSettingsViewController.m:61` | No root bar items. |
| Top edit block | Official: Top edit block | partial | `Controllers/TGSettingsViewController+Pages.m:126` | One "My Profile" row and a separate Edit form; Emoji Status is its own row. |
| Emoji Status | Official: Emoji Status | partial | `Controllers/TGSettingsViewController+Pages.m:126` | Shown to every account in the account card; the picker exists. |
| Saved Messages | Official: Saved Messages | done | `Controllers/TGSettingsViewController+Pages.m:142` | Opens the saved-messages chat. |
| Recent Calls page | Official: Recent Calls page | partial | `Controllers/TGSettingsViewController+Pages.m:732` | Filter and redial exist; no New Call row; rows are subtitle-only. |
| Devices / sessions | Official: Devices / sessions | partial | `Controllers/TGSettingsViewController+Pages.m:148` | Pushes `TGSessionsViewController`; rows show app name + platform + IP. |
| Devices row value | Official: Devices row value | partial | `Controllers/TGSettingsViewController.m:84` | "N active" counts only other sessions. |
| Chat Folders page | Official: Chat Folders page | partial | `Controllers/TGSettingsViewController+NetworkPages.m:249` | Most editing exists; counts are behind a "Chat Count" alert and creation is the last row. |
| Folder rows | Official: Folder rows | partial | `Controllers/TGSettingsViewController+NetworkPages.m:249` | Names only; count is not printed on the row. |
| My Stories | Official: My Stories | done | `Controllers/TGSettingsViewController+Pages.m:158` | Opens the profile's Stories tab. |
| Proxy | Official: Proxy | done | `Controllers/TGSettingsViewController+NetworkPages.m:722` | Add, enable, edit and remove proxies. |
| Proxy row value | Official: Proxy row value | partial | `Controllers/TGSettingsViewController.m:97` | Shows the server hostname or "On"/"Off"; the row is always present. |
| Notifications and Sounds | Official: Notifications and Sounds | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:82` | Three mute and three preview switches, exceptions, sounds, reset; no category pages or badge section. |
| Notification warning badge | Official: Notification warning badge | missing | `Controllers/TGSettingsViewController.m:161` | No badge or warning. |
| Privacy and Security | Official: Privacy and Security | done | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | Security, six rules, messages, close friends, contacts, account status, payments, link. |
| Data and Storage | Official: Data and Storage | partial | `Controllers/TGSettingsViewController+NetworkPages.m:27` | All pages exist; File Tools and the network state page are still on the user's path. |
| Appearance | Official: Appearance | partial | `Controllers/TGSettingsViewController+AppearancePages.m:37` | Themes, text size, wallpaper, defaults, emoji themes and Your Color; no Night, bubbles or icons. |
| Power Saving | Official: Power Saving | partial | `Controllers/TGSettingsViewController+NetworkPages.m:192` | Sticker animation, wallpaper, GIF autoplay and media preloading; no master or threshold. |
| Language | Official: Language | partial | `Controllers/TGSettingsViewController+Pages.m:258` | Pack picker changes TDLib's language; the app's own ~2200 strings stay English. |
| Language row value | Official: Language row value | partial | `Controllers/TGSettingsViewController.m:95` | Uses the pack's `name`, never `native_name`. |
| Language pack tools | Official: Language pack tools | dev-only | `Controllers/TGSettingsViewController+Pages.m:289` | The string editor lives on the dev language page. |
| Stickers and Emoji | Official: Stickers and Emoji | done | `Controllers/TGSettingsViewController+Pages.m:195` | Opens pack management. |
| Telegram Premium | Official: Telegram Premium | partial | `Controllers/TGSettingsViewController+Actions.m:122` | Reads the state and explains that purchase happens in an official client. |
| Send a Gift | Official: Send a Gift | missing | `Controllers/TGSettingsViewController+Pages.m:205` | No release row; the gift console is `TG_DEV`. |
| Telegram Business | Official: Telegram Business | done | `Controllers/TGSettingsViewController+Tier2.m:18` | Opens `TGBusinessViewController`. |
| Business and Premium gating | Official: Business and Premium gating | missing | `Controllers/TGSettingsViewController+Tier2.m:21` | Business row is always present. |
| Help rows | Official: Help rows | partial | `Controllers/TGSettingsViewController+Pages.m:212` | Ask a Question, FAQ, Features, Privacy Policy, Get the App; no Tips. |
| Ask a Question intro | Official: Ask a Question intro | missing | `Controllers/TGSettingsViewController+Actions.m:412` | Opens the support chat immediately. |
| Telegram FAQ in-app | Official: Telegram FAQ in-app | missing | `Controllers/TGSettingsViewController+Pages.m:223` | Opens `https://telegram.org/faq` in Safari. |
| This Device | Official: This Device | done | `Controllers/TGSettingsViewController+Pages.m:241` | Tier, software, hardware and per-feature availability. |
| Log out | Official: Log out | done | `Controllers/TGSettingsViewController+Pages.m:246` | Confirmation, then `logOut`. |
| Section order | Official: Section order | partial | `Controllers/TGSettingsViewController+Pages.m:82` | Header, account card, chat/device card, proxy, app settings, stickers, Premium/Business, Help, This Device, Log out. |
| No duplicate Chat Themes row | Official: No duplicate Chat Themes row | missing | `Controllers/TGSettingsViewController+Pages.m:195` | "Stickers and Emoji" exists; no duplicate "Chat Themes" now, so the row is gone. |
| Appearance preview | Official: Appearance preview | partial | `Controllers/TGSettingsViewController.m:751` | Two hardcoded lines with a gradient; no reply, sender or date. |
| Theme list | Official: Theme list | partial | `Controllers/TGSettingsViewController+AppearancePages.m:41` | Check rows: Classic plus `.tgios-theme` files; no thumbnails or built-in cards. |
| Chat theme picker | Official: Chat theme picker | partial | `Controllers/TGSettingsViewController+AppearancePages.m:75` | Lists emoji themes and opens a read-only detail alert; no way to apply one. |
| Accent colour chooser | Official: Accent colour chooser | partial | `Controllers/TGProfileAppearanceViewController.m:156` | Swatch screen exists for profile/name colour; no background/accent/messages preview. |
| Chat background page | Official: Chat background page | partial | `Controllers/TGSettingsViewController+AppearancePages.m:100` | Local texture list plus a server list; no colour/gradient controls. |
| Background colour, gradient and pattern | Official: Background colour, gradient and pattern | partial | `Controllers/TGSettingsViewController+AppearancePages.m:127` | Six fixed textures and a photo; no colour, gradient or pattern controls. |
| Photo wallpaper crop, blur and motion | Official: Photo wallpaper crop, blur and motion | partial | `Controllers/TGSettingsViewController+AppearancePages.m:127` | One image picker scaled to 640 px and saved as JPEG; no crop, blur or motion. |
| Your Color row | Official: Your Color row | done | `Controllers/TGSettingsViewController+AppearancePages.m:88` | One "Your Color" row opens the profile appearance screen. |
| Night Theme and Auto-Night | Official: Night Theme and Auto-Night | missing | `Core/TGTheme.m:43` | Night was removed deliberately; the app is light-only. |
| Bubble corners editor | Official: Bubble corners editor | missing | `Core/TGTheme+Effects.m:95` | Fixed radius; `TGMetricCornerBubbleFlat` is never used. |
| Folder editor | Official: Folder editor | partial | `Controllers/TGSettingsViewController+NetworkPages.m:249` | Eight-item action sheet plus add/remove chats; no excluded-read/muted/archived or tag colour. |
| Sticker and emoji settings | Official: Sticker and emoji settings | missing | `Controllers/TGStickerPacksViewController.m:21` | Sticker page is packs, archive and custom emoji only. |
| Quick reaction setup | Official: Quick reaction setup | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:108` | "Default Reaction" opens the fixed seven-emoji picker; no demo or current-reaction row. |
| Reaction notifications | Official: Reaction notifications | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:108` | One "Message Reactions" switch; story and poll sources are not exposed. |
| Quick reply list | Official: Quick reply list | partial | `Controllers/TGQuickRepliesViewController.m:1` | Plain rows with a count and preview; no slash name or inline creation. |
| Text size | Official: Text size | partial | `Controllers/TGSettingsViewController+Actions.m:464` | 13/15/17/19 pt; only chat text changes. |
| Sticker pack rows | Official: Sticker pack rows | partial | `Controllers/TGStickerPacksViewController.m:21` | Subtitle row with short name, count and type; no sticker artwork. |
| Root wording | Official: Root wording | partial | `Controllers/TGSettingsViewController+Pages.m:195` | Root has "Stickers and Emoji"; the sticker page is titled "Stickers". |
| Settings navigation bar | Official: Settings navigation bar | partial | `Controllers/TGSettingsViewController.m:947` | Hides on scroll down and is not restored in `viewWillAppear:`. |
| Dark background editing | Official: Dark background editing | partial | `Controllers/TGBackgroundsViewController.m:1` | A "Dark Theme Backgrounds" switch exists in a light-only app. |
| Telegram Defaults presentation | Official: Telegram Defaults presentation | partial | `Controllers/TGSettingsViewController+AppearancePages.m:183` | Alerts print raw ids and type names. |
| Design: iOS 7+ navigation bar | Official: Design: iOS 7+ navigation bar | missing | `Core/TGTheme.m:338` | Blue `#517DA2` bar with white title on every OS. |
| Design: iOS 7+ tab bar | Official: Design: iOS 7+ tab bar | missing | `Core/TGTheme.m:238` | `barTintColor` and `tintColor` are both `#517DA2`. |
| Design: accent and values | Official: Design: accent and values | missing | `Core/TGTheme+Colours.m:54` | Accent `#517DA2`; values `#51AEE7`. |
| Design: text and separators | Official: Design: text and separators | missing | `Core/TGThemeInternal.h:30` | Text `#222222`, separators `#E1E4E9`. |
| Design: section headers and footers | Official: Design: section headers and footers | missing | `Controllers/TGSettingsViewController.m:666` | UIKit uppercase headers; plain string footers with no links. |
| Design: Settings row rhythm | Official: Design: Settings row rhythm | missing | `Core/TGStyle+Metrics.h:36` | 44 pt system row, 15 pt gutter. |
| Design: profile header and actions | Official: Design: profile header and actions | partial | `Controllers/TGProfileViewController.m:147` | 80 pt avatar, 22 pt name; up to six equal plates. |
| Design: profile details | Official: Design: profile details | partial | `Controllers/TGProfileViewController.m:565` | Custom cell with smaller type; bio wraps. |
| Design: shared-media tabs | Official: Design: shared-media tabs | partial | `Controllers/TGProfileViewController.m:1030` | Scrollable strip exists; type and selection treatment differ. |
| Design: contact rows | Official: Design: contact rows | partial | `Controllers/TGContactsViewController.m:445` | 56 pt rows, 15 pt name, disclosure chevron. |
| Design: avatars | Official: Design: avatars | partial | `Views/TGIcons+Avatars.m:120` | One flat colour plus a white oval on every OS. |
| Design: badges | Official: Design: badges | partial | `UI/TGBadge.m:53` | 18 pt glossy bevel, 13 pt bold. |
| Design: large buttons | Official: Design: large buttons | partial | `UI/TGButton.m:72` | 44 pt high, 8 pt corner, 15 pt bold, etched gloss. |
| Design: empty state | Official: Design: empty state | partial | `UI/TGEmptyView.m:10` | 64 pt icon, 22 pt bold title, 160×36 glossy button. |
| Design: Settings icons | Official: Design: Settings icons | partial | `Views/TGIcons+Menu.m:479` | Some rows share glyphs and a few fall back to the wrong shape. |
| Design: profile has no "Info" title | Official: Design: profile has no "Info" title | missing | `Controllers/TGProfileViewController.m:82` | Every profile and group says "Info" in the bar. |
| Design: iOS 7+ section insets | Official: Design: iOS 7+ section insets | missing | `Core/TGTheme.m:198` | Full-bleed grouped table on every OS. |
| Stars row | Official: Stars row | missing | — | No row; a read-only console is in the `TG_DEV` debug section. |
| Telegram Tips | Official: Telegram Tips | missing | — | No row. |
| Language translation controls | Official: Language translation controls | missing | — | Language page is a pack inspector only. |
| Show next media on tap | Official: Show next media on tap | missing | — | No media setting. |
| App icon picker | Official: App icon picker | missing | — | No picker; iOS 6 has no alternate-icon API. |
| Settings row badges | Official: Settings row badges | partial | `Controllers/TGSettingsViewController.m:161` | No "New", red "!" or device-count badge model; the notification warning is missing too. |
