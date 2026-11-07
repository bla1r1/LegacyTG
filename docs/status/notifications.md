Notifications: scopes, per-chat exceptions, sounds, the Active list, push registration and what the app does while open. Parity rows come from `_parity_audit/settings_privacy.md`, `settings_main.md` and `s_rest.md`; checked against `src/` on 7 November 2026.

Counts: 8 done, 6 partial, 11 missing, 1 dev-only.

**What is built.** M15 built notification settings and push: three scopes and their previews,
per-chat exceptions, custom sounds, reaction and story switches, reset,
`registerDevice` and routing from a push to its chat and message. Development
builds also expose the Active Notifications table.

M31 adds category pages, the in-app banner, a permission warning, badge
settings, exception editing and sound assignment. Push delivery still depends
on an APNs certificate for the official bundle ID.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Notification scopes | Official: Notification scopes | done | `Controllers/TGSettingsViewController+PrivacyPages.m:82` | Three mute switches under "Show notifications for". |
| Message previews per scope | Official: Message previews per scope | done | `Controllers/TGSettingsViewController+PrivacyPages.m:96` | Three preview switches in a second card. |
| Category sub-pages | Official: Category sub-pages | missing | `Controllers/TGSettingsViewController+PrivacyPages.m:82` | Switches only; no pushed category page. |
| Notification exceptions list | Official: Notification exceptions list | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:188` | List exists, but every row opens the chat rather than showing mute/sound/preview state. |
| Per-chat notification settings | Official: Per-chat notification settings | partial | `Core/TGClient+Chats.mm:1431` | Muting a chat sends only `mute_for`; the other fields fall back to defaults. |
| Scope settings preserve fields | Official: Scope settings preserve fields | partial | `Core/TGClient+Account.m:539` | `updateScope:` sends only `mute_for`, `sound_id` and `show_preview`; story and mention flags are dropped. |
| Custom sounds list | Official: Custom sounds list | done | `Controllers/TGSettingsViewController+PrivacyPages.m:248` | Add from bundle or MP3, play, inspect, remove. |
| Assign a custom sound | Official: Assign a custom sound | missing | `Controllers/TGSettingsViewController+PrivacyPages.m:215` | A sound can be added and removed, but no row assigns one. |
| Message reactions | Official: Message reactions | done | `Controllers/TGSettingsViewController+PrivacyPages.m:108` | Switch, default reaction and clear recent. |
| Reaction source detail | Official: Reaction source detail | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:108` | One "Message Reactions" switch; story and poll sources are not exposed. |
| Story notifications | Official: Story notifications | done | `Controllers/TGStorySettingsViewController.m:30` | Per-chat story notification exceptions. |
| Reset all notifications | Official: Reset all notifications | done | `Controllers/TGSettingsViewController+PrivacyPages.m:230` | Confirmed `resetAllNotificationSettings`. |
| Active Notifications | Official: Active Notifications | dev-only | `Controllers/TGSettingsViewController+PrivacyPages.m:409` | The screen is reachable only from the `TG_DEV` debug section. |
| In-app notification banner | Official: In-app notification banner | missing | `Controllers/TGActiveNotificationsViewController.m:76` | Only the Active table; no banner while using the app. |
| Notification warning badge | Official: Notification warning badge | missing | `Controllers/TGSettingsViewController.m:161` | No badge or warning. |
| Push registration | Official: Push registration | done | `Core/TGClient+Auth.m:233` | `registerDevice` on sign-in; needs the APNs certificate to deliver. |
| Push opens the chat | Official: Push opens the chat | done | `Core/TGClient+Auth.m:262` | `processPushNotification` and `getPushReceiverId` route to the chat and message. |
| Push payload privacy | Official: Push payload privacy | partial | `Core/TGClient+Auth.m:233` | The token is registered; the payload privacy is TDLib's and is not tested here. |
| Pinned and mention flags | Official: Pinned and mention flags | partial | `Core/TGClient+Chats.mm:1431` | Muting replaces the record with two fields, so mention and pinned flags reset. |
| Add an exception | Official: Add an exception | missing | — | No Add Exception action. |
| Notification permission banner | Official: Notification permission banner | missing | — | The page never says notifications are denied. |
| Badge settings | Official: Badge settings | missing | — | No badge section. |
| In-app sounds and vibration | Official: In-app sounds and vibration | missing | — | Previews are server-synced; no in-app sound or vibration setting. |
| Display names on the lock screen | Official: Display names on the lock screen | missing | — | No lock-screen presentation setting. |
| Contact joined Telegram | Official: Contact joined Telegram | missing | — | No switch; TDLib has no server-side field for it. |
| Muted-until wording | Official: Muted-until wording | missing | — | The exception list has no state words; rows say "Open". |
