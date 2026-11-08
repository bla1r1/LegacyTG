Every Settings page and the rows that actually open something, plus the Appearance controls and the shared design tokens. Parity rows come from `_parity_audit/settings_main.md`, `settings_look.md` and `design.md`; checked against `src/` on 7 November 2026. Notification and privacy detail live in `notifications.md` and `privacy-security.md`.

Counts: 11 done, 47 partial, 25 missing, 1 dev-only.

Built: M14 (tree and pages: account, sessions, folders, proxy, notifications,
privacy, data and storage, appearance, power saving, language, stickers,
Premium state, Business, Help, This Device, log out), M9 (appearance controls
and tokens), M15 (notification switches). Open: M30 search, M33 localisation,
M34 harness pages and TDLib footers, M37 appearance/privacy detail.

| Feature | State | Where | Note |
|---|---|---|---|
| Root list | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:82` | Profile card, account rows, app settings, help, This Device, Log out. |
| Settings tab icon is the account photo | missing | `App/RootViewController.m:60` | Always the sliders glyph; no badge or avatar. |
| Settings search | missing | `src/Features/Settings/Pages/TGSettingsPagesCore.m:82` | No search field or page index. |
| Accounts switcher | partial | `Features/Settings/TGSettingsViewController+Actions.m:37` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Four account slots | partial | `Core/Client/TGClient+Accounts.m:16` | Three slots for every account. |
| My Profile row | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:121` | Opens the account's own profile. |
| Account header | partial | `Features/Settings/TGSettingsViewController.m:990` | 80 pt avatar in a 168 pt cell, 22 pt name, phone only. |
| QR and Edit bar items | missing | `Features/Settings/TGSettingsViewController.m:61` | No root bar items. |
| Top edit block | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:126` | One "My Profile" row and a separate Edit form; Emoji Status is its own row. |
| Emoji Status | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:126` | Shown to every account in the account card; the picker exists. |
| Saved Messages | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:142` | Opens the saved-messages chat. |
| Recent Calls page | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:732` | Filter and redial exist; no New Call row; rows are subtitle-only. |
| Devices / sessions | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:148` | Pushes `TGSessionsViewController`; rows show app name + platform + IP. |
| Devices row value | partial | `Features/Settings/TGSettingsViewController.m:84` | "N active" counts only other sessions. |
| Chat Folders page | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:249` | Most editing exists; counts are behind a "Chat Count" alert and creation is the last row. |
| Folder rows | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:249` | Names only; count is not printed on the row. |
| My Stories | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:158` | Opens the profile's Stories tab. |
| Proxy | done | `Features/Settings/TGSettingsViewController+NetworkPages.m:722` | Add, enable, edit and remove proxies. |
| Proxy row value | partial | `Features/Settings/TGSettingsViewController.m:97` | Shows the server hostname or "On"/"Off"; the row is always present. |
| Notifications and Sounds | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:82` | Three mute and three preview switches, exceptions, sounds, reset; no category pages or badge section. |
| Notification warning badge | missing | `Features/Settings/TGSettingsViewController.m:161` | No badge or warning. |
| Privacy and Security | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | Security, six rules, messages, close friends, contacts, account status, payments, link. |
| Data and Storage | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:27` | All pages exist; File Tools and the network state page are still on the user's path. |
| Appearance | partial | `Features/Settings/TGSettingsViewController+AppearancePages.m:37` | Themes, text size, wallpaper, defaults, emoji themes and Your Color; no Night, bubbles or icons. |
| Power Saving | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:192` | Sticker animation, wallpaper, GIF autoplay and media preloading; no master or threshold. |
| Language | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:258` | Pack picker changes TDLib's language; the app's own ~2200 strings stay English. |
| Language row value | partial | `Features/Settings/TGSettingsViewController.m:95` | Uses the pack's `name`, never `native_name`. |
| Language pack tools | dev-only | `src/Features/Settings/Pages/TGSettingsPagesCore.m:289` | The string editor lives on the dev language page. |
| Stickers and Emoji | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:195` | Opens pack management. |
| Telegram Premium | partial | `Features/Settings/TGSettingsViewController+Actions.m:122` | Reads the state and explains that purchase happens in an official client. |
| Send a Gift | missing | `src/Features/Settings/Pages/TGSettingsPagesCore.m:205` | No release row; the gift console is `TG_DEV`. |
| Telegram Business | done | `Features/Settings/TGSettingsViewController+Tier2.m:18` | Opens `TGBusinessViewController`. |
| Business and Premium gating | missing | `Features/Settings/TGSettingsViewController+Tier2.m:21` | Business row is always present. |
| Help rows | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:212` | Ask a Question, FAQ, Features, Privacy Policy, Get the App; no Tips. |
| Ask a Question intro | missing | `Features/Settings/TGSettingsViewController+Actions.m:412` | Opens the support chat immediately. |
| Telegram FAQ in-app | missing | `src/Features/Settings/Pages/TGSettingsPagesCore.m:223` | Opens `https://telegram.org/faq` in Safari. |
| This Device | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:241` | Tier, software, hardware and per-feature availability. |
| Log out | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:246` | Confirmation, then `logOut`. |
| Section order | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:82` | Header, account card, chat/device card, proxy, app settings, stickers, Premium/Business, Help, This Device, Log out. |
| No duplicate Chat Themes row | missing | `src/Features/Settings/Pages/TGSettingsPagesCore.m:195` | "Stickers and Emoji" exists; no duplicate "Chat Themes" now, so the row is gone. |
| Appearance preview | partial | `Features/Settings/TGSettingsViewController.m:751` | Two hardcoded lines with a gradient; no reply, sender or date. |
| Theme list | partial | `Features/Settings/TGSettingsViewController+AppearancePages.m:41` | Check rows: Classic plus `.tgios-theme` files; no thumbnails or built-in cards. |
| Chat theme picker | partial | `Features/Settings/TGSettingsViewController+AppearancePages.m:75` | Lists emoji themes and opens a read-only detail alert; no way to apply one. |
| Accent colour chooser | partial | `Features/Profile/TGProfileAppearanceViewController.m:156` | Swatch screen exists for profile/name colour; no background/accent/messages preview. |
| Chat background page | partial | `Features/Settings/TGSettingsViewController+AppearancePages.m:100` | Local texture list plus a server list; no colour/gradient controls. |
| Background colour, gradient and pattern | partial | `Features/Settings/TGSettingsViewController+AppearancePages.m:127` | Six fixed textures and a photo; no colour, gradient or pattern controls. |
| Photo wallpaper crop, blur and motion | partial | `Features/Settings/TGSettingsViewController+AppearancePages.m:127` | One image picker scaled to 640 px and saved as JPEG; no crop, blur or motion. |
| Your Color row | done | `Features/Settings/TGSettingsViewController+AppearancePages.m:88` | One "Your Color" row opens the profile appearance screen. |
| Night Theme and Auto-Night | missing | `Core/Style/TGTheme.m:43` | Night was removed deliberately; the app is light-only. |
| Bubble corners editor | missing | `Core/Style/TGTheme+Effects.m:95` | Fixed radius; `TGMetricCornerBubbleFlat` is never used. |
| Folder editor | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:249` | Eight-item action sheet plus add/remove chats; no excluded-read/muted/archived or tag colour. |
| Sticker and emoji settings | missing | `Features/Media/TGStickerPacksViewController.m:21` | Sticker page is packs, archive and custom emoji only. |
| Quick reaction setup | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:108` | "Default Reaction" opens the fixed seven-emoji picker; no demo or current-reaction row. |
| Reaction notifications | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:108` | One "Message Reactions" switch; story and poll sources are not exposed. |
| Quick reply list | partial | `Features/Chat/TGQuickRepliesViewController.m:1` | Plain rows with a count and preview; no slash name or inline creation. |
| Text size | partial | `Features/Settings/TGSettingsViewController+Actions.m:464` | 13/15/17/19 pt; only chat text changes. |
| Sticker pack rows | partial | `Features/Media/TGStickerPacksViewController.m:21` | Subtitle row with short name, count and type; no sticker artwork. |
| Root wording | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:195` | Root has "Stickers and Emoji"; the sticker page is titled "Stickers". |
| Settings navigation bar | partial | `Features/Settings/TGSettingsViewController.m:947` | Hides on scroll down and is not restored in `viewWillAppear:`. |
| Dark background editing | partial | `Features/Settings/TGBackgroundsViewController.m:1` | A "Dark Theme Backgrounds" switch exists in a light-only app. |
| Telegram Defaults presentation | partial | `Features/Settings/TGSettingsViewController+AppearancePages.m:183` | Alerts print raw ids and type names. |
| Design: iOS 7+ navigation bar | missing | `Core/Style/TGTheme.m:338` | Blue `#517DA2` bar with white title on every OS. |
| Design: iOS 7+ tab bar | missing | `Core/Style/TGTheme.m:238` | `barTintColor` and `tintColor` are both `#517DA2`. |
| Design: accent and values | missing | `Core/Style/TGTheme+Colours.m:54` | Accent `#517DA2`; values `#51AEE7`. |
| Design: text and separators | missing | `Core/Style/TGThemeInternal.h:30` | Text `#222222`, separators `#E1E4E9`. |
| Design: section headers and footers | missing | `Features/Settings/TGSettingsViewController.m:666` | UIKit uppercase headers; plain string footers with no links. |
| Design: Settings row rhythm | missing | `Core/Style/TGStyle+Metrics.h:36` | 44 pt system row, 15 pt gutter. |
| Design: profile header and actions | partial | `Features/Profile/TGProfileViewController.m:147` | 80 pt avatar, 22 pt name; up to six equal plates. |
| Design: profile details | partial | `src/Features/Profile/Core/TGProfileHeader.m:388` | Custom cell with smaller type; bio wraps. |
| Design: shared-media tabs | partial | `src/Features/Profile/Core/TGProfileDetails.m:285` | Scrollable strip exists; type and selection treatment differ. |
| Design: contact rows | partial | `Features/Contacts/TGContactsViewController.m:445` | 56 pt rows, 15 pt name, disclosure chevron. |
| Design: avatars | partial | `Views/Icons/TGIcons+Avatars.m:120` | One flat colour plus a white oval on every OS. |
| Design: badges | partial | `UI/Controls/TGBadge.m:53` | 18 pt glossy bevel, 13 pt bold. |
| Design: large buttons | partial | `UI/Controls/TGButton.m:72` | 44 pt high, 8 pt corner, 15 pt bold, etched gloss. |
| Design: empty state | partial | `UI/Overlays/TGEmptyView.m:10` | 64 pt icon, 22 pt bold title, 160×36 glossy button. |
| Design: Settings icons | partial | `Views/Icons/TGIcons+Menu.m:479` | Some rows share glyphs and a few fall back to the wrong shape. |
| Design: profile has no "Info" title | missing | `Features/Profile/TGProfileViewController.m:82` | Every profile and group says "Info" in the bar. |
| Design: iOS 7+ section insets | missing | `Core/Style/TGTheme.m:198` | Full-bleed grouped table on every OS. |
| Stars row | missing | — | No row; a read-only console is in the `TG_DEV` debug section. |
| Telegram Tips | missing | — | No row. |
| Language translation controls | missing | — | Language page is a pack inspector only. |
| Show next media on tap | missing | — | No media setting. |
| App icon picker | missing | — | No picker; iOS 6 has no alternate-icon API. |
| Settings row badges | partial | `Features/Settings/TGSettingsViewController.m:161` | No "New", red "!" or device-count badge model; the notification warning is missing too. |
