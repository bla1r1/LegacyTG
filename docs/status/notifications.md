Notifications: scopes, per-chat exceptions, sounds, the Active list, push registration and what the app does while open. Parity rows come from `_parity_audit/settings_privacy.md`, `settings_main.md` and `s_rest.md`; checked against `src/` on 7 November 2026.

Counts: 8 done, 6 partial, 11 missing, 1 dev-only.

Built: M15 (three scopes and previews, per-chat exceptions, custom sounds,
reaction/story switches, reset, `registerDevice`, push routing; Active
Notifications in dev builds). Open: M31 (category pages, in-app banner,
permission warning, badge settings, exception editing, sound assignment).
Delivery still needs an APNs certificate for the official bundle ID.

| Feature | State | Where | Note |
|---|---|---|---|
| Notification scopes | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:82` | Three mute switches under "Show notifications for". |
| Message previews per scope | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:96` | Three preview switches in a second card. |
| Category sub-pages | missing | `Features/Settings/TGSettingsViewController+PrivacyPages.m:82` | Switches only; no pushed category page. |
| Notification exceptions list | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:188` | List exists, but every row opens the chat rather than showing mute/sound/preview state. |
| Per-chat notification settings | partial | `Core/Client/Chats/TGClient+ChatFolders.mm:255` | Muting a chat sends only `mute_for`; the other fields fall back to defaults. |
| Scope settings preserve fields | partial | `src/Core/Client/Account/TGClient+AccountCore.m:270` | `updateScope:` sends only `mute_for`, `sound_id` and `show_preview`; story and mention flags are dropped. |
| Custom sounds list | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:248` | Add from bundle or MP3, play, inspect, remove. |
| Assign a custom sound | missing | `Features/Settings/TGSettingsViewController+PrivacyPages.m:215` | A sound can be added and removed, but no row assigns one. |
| Message reactions | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:108` | Switch, default reaction and clear recent. |
| Reaction source detail | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:108` | One "Message Reactions" switch; story and poll sources are not exposed. |
| Story notifications | done | `Features/Stories/TGStorySettingsViewController.m:30` | Per-chat story notification exceptions. |
| Reset all notifications | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:230` | Confirmed `resetAllNotificationSettings`. |
| Active Notifications | dev-only | `Features/Settings/TGSettingsViewController+PrivacyPages.m:409` | The screen is reachable only from the `TG_DEV` debug section. |
| In-app notification banner | missing | `Features/Settings/TGActiveNotificationsViewController.m:76` | Only the Active table; no banner while using the app. |
| Notification warning badge | missing | `Features/Settings/TGSettingsViewController.m:161` | No badge or warning. |
| Push registration | done | `Core/Client/TGClient+Auth.m:233` | `registerDevice` on sign-in; needs the APNs certificate to deliver. |
| Push opens the chat | done | `Core/Client/TGClient+Auth.m:262` | `processPushNotification` and `getPushReceiverId` route to the chat and message. |
| Push payload privacy | partial | `Core/Client/TGClient+Auth.m:233` | The token is registered; the payload privacy is TDLib's and is not tested here. |
| Pinned and mention flags | partial | `Core/Client/Chats/TGClient+ChatFolders.mm:255` | Muting replaces the record with two fields, so mention and pinned flags reset. |
| Add an exception | missing | — | No Add Exception action. |
| Notification permission banner | missing | — | The page never says notifications are denied. |
| Badge settings | missing | — | No badge section. |
| In-app sounds and vibration | missing | — | Previews are server-synced; no in-app sound or vibration setting. |
| Display names on the lock screen | missing | — | No lock-screen presentation setting. |
| Contact joined Telegram | missing | — | No switch; TDLib has no server-side field for it. |
| Muted-until wording | missing | — | The exception list has no state words; rows say "Open". |
