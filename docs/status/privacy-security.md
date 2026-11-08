Privacy and security: the lock, two-step, sessions, blocked users, visibility rules, storage and network controls. Parity rows come from `_parity_audit/settings_privacy.md`; checked against `src/` on 7 November 2026. Notification presentation detail is in `notifications.md`.

Counts: 34 done, 29 partial, 19 missing, 0 dev-only.

Built: M14 (passcode and auto-lock, two-step, login email, change phone,
sessions and websites, blocked users, six visibility rules, read receipts,
close friends, data controls, payment records; storage and network pages),
M37 (exception lists, storage maximum, custom wallpaper colors/gradients).
Open: M31 (notification half), M34 (TDLib text in security alerts).

| Feature | State | Where | Note |
|---|---|---|---|
| Passcode row at the top of Security | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:1080` | Passcode Lock is the first Security row; the page has on/off/change and auto-lock. |
| Passcode on / off / change | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:1080` | 4-digit code with a confirmation step. |
| Auto-lock timeout | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:1133` | Immediately, 1 min, 5 min, 1 hour or disabled. |
| Lock icon on the chat list | done | `src/Features/ChatList/Core/TGChatListHeader.m:135` | Tap locks immediately; the button exists only when a passcode is set. |
| Lock on launch / foreground | done | `App/AppDelegate.m:180` | Unlock sheet after launch and when `shouldLockOnForeground`. |
| Touch ID / Face ID | missing | `Core/Platform/TGPasscode.h:12` | No `LAContext` or biometric path anywhere. |
| Wrong-passcode data wipe | missing | `Core/Platform/TGPasscode.m:1` | Attempts are counted for the shake only; no erase option. |
| Two-step verification | done | `Features/Settings/TGSettingsViewController+Actions.m:135` | Set, change, recovery address, turn off, forgot password. |
| Two-step screen detail | partial | `Core/Client/TGClient+Auth.m:142` | `getPasswordState` is reduced to a BOOL plus "set"; hint and `pending_reset_date` never reach the user. |
| Login email address | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:545` | Set, verify, resend, remove. |
| Login Email row value | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:539` | The row exists with a nil detail, so it looks unset even when set. |
| Change phone number | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:549` | Code flow across the auth states. |
| Temporary password | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:554` | Create a one-time password for another device. |
| Application verification | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:558` | Shows required/none and submits the code. |
| Current session | partial | `Features/Settings/TGSessionsViewController.m:140` | Title is `application_name`, subtitle platform + IP; model, location and last active are dropped. |
| Other sessions | done | `Features/Settings/TGSessionsViewController.m:140` | Each row opens sign-out and its call/secret-chat switches. |
| Session row detail | partial | `src/Core/Client/Account/TGClient+AccountPeople.m:103` | `device_model`, `location` and `last_active_date` are never shown. |
| Terminate one session | done | `Features/Settings/TGSessionsViewController.m:307` | Confirms then `terminateSession`. |
| Terminate all other sessions | done | `Features/Settings/TGSessionsViewController.m:265` | `terminateAllOtherSessions`. |
| Inactive session timeout | done | `Features/Settings/TGSessionsViewController.m:228` | 1 week to 1 year. |
| Connected websites | done | `Features/Settings/TGWebsitesViewController.m:29` | Per-site sign-out and sign out all. |
| QR scanner for login links | done | `Features/Settings/TGSessionsViewController.m:220` | Camera scanner opens a t.me link. |
| Blocked users list | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:789` | Plain text names only; no add, no avatars; tapping unblocks immediately. |
| Blocked users count | missing | `Features/Settings/TGSettingsViewController+PrivacyPages.m:570` | The row has no detail value. |
| Block a person | done | `Features/Profile/TGProfileViewController+Actions.m:413` | From the profile's More menu. |
| Last Seen privacy | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; no exception lists. |
| Profile photo privacy | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; no public-photo row. |
| Phone number privacy | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; `AllowFindingByPhoneNumber` is never read. |
| Calls privacy | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; no P2P rule. |
| Group invite privacy | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | Group Invites is one of the six three-choice rows. |
| Forwarded-message link privacy | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | Forwarded Messages is one of the six three-choice rows. |
| Birthday privacy | done | `Features/Profile/TGEditProfileViewController.m:476` | Birthday privacy is chosen in Edit Profile. |
| Bio privacy | missing | `Features/Profile/TGEditProfileViewController.m:534` | No Bio row in Privacy and no line under the field. |
| Gifts privacy | missing | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | No who-may-send, gift button or accepted-types rows. |
| Voice message privacy | missing | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | No row for who may send voice messages. |
| Added-by-phone privacy | missing | `Features/Settings/TGSettingsViewController+PrivacyPages.m:500` | No row for finding the account by phone. |
| Privacy exception lists | done | `Features/Settings/TGPrivacyRuleViewController.m:1` | Dedicated privacy rule screen with Always Allow / Never Allow contact pickers and live TDLib sync. |
| Privacy row order and wording | partial | `Features/Settings/TGSettingsViewController.m:639` | Six rows: Last Seen, Photo, Phone, Calls, Invites, Forwards. |
| Read receipts | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:623` | A top-level Read Receipts switch in the Messages card. |
| Delete messages by default | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:588` | Four fixed choices; any other server value prints plain days, no custom picker. |
| Messages from unknown users | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:601` | One boolean switch; no Premium state or Stars price row. |
| Personal chat | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:610` | Choose a personal chat. |
| Inactive groups | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:614` | List and leave. |
| My public chats | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:618` | Lists public chats. |
| Close friends | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:643` | Picker and count. |
| Close birthdays | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:649` | The row calls `hideContactCloseBirthdays` instead of showing the list. |
| Suggest frequent contacts | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:659` | Writes `disable_top_chats`. |
| Delete synced contacts | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:664` | Confirmed `clearImportedContacts`. |
| Data sub-screen | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:658` | Delete Synced Contacts here; Clear Drafts lives in Data and Storage; no payment-info or secret-chat link-preview row. |
| Freeze state | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:683` | Dates, appeal link, open appeal. |
| Subscription state | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:689` | Reads the account's subscription record. |
| Age verification | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:695` | Shows the parameters Telegram sent. |
| reCAPTCHA request | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:701` | Shows the request and says the app has no web view; no solving path. |
| Verify an email address | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:705` | Send code, enter it, store the address. |
| Orders and payment data | partial | `src/Features/Settings/Pages/TGSettingsPagesPayments.m:83` | Read-only saved checkout; card lookup and offer tools are `TG_DEV`. |
| Delete saved payment credentials | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:722` | Account-wide confirmed delete. |
| My link | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:743` | Copies the account's t.me link. |
| Protected content flag | done | `Features/Chat/TGChatToolsViewController.m:163` | Copy/forward/save are blocked in a protected chat; no screenshot guard. |
| Session secret-chat and call switches | done | `Features/Settings/TGSessionsViewController.m:300` | Per-session accept calls / accept secret chats. |
| Storage: KEEP MEDIA per peer type | missing | `Features/Settings/TGStorageViewController.m:190` | The page is ring + categories + one Clear Cache row. |
| Storage: maximum cache size | missing | `Features/Settings/TGStorageViewController.m:190` | No maximum-cache row. |
| Storage: category rows and selection | partial | `Features/Settings/TGStorageViewController.m:275` | Tapping a category clears that whole type after a sheet; no selection or per-type clear button. |
| Storage: chats view and per-chat exceptions | missing | `Features/Settings/TGStorageViewController.m:190` | No chats view and no per-chat exceptions. |
| Storage: category split and colours | partial | `Core/Client/TGClient+Files.mm:373` | Five buckets plus Other; profile photos and thumbnails sit inside Photos. |
| Clear Cache amount | partial | `Features/Settings/TGStorageViewController.m:280` | "Clear Cache" plus the ring total; sends empty `file_types`, so TDLib keeps thumbnails, profile photos, stickers and wallpapers. |
| Data & Storage summaries | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:40` | Storage Usage row is nil; Network Usage reads "X in, Y out". |
| Network Usage screen | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:72` | One "X in, Y out" row with a reset confirm. |
| Per-connection auto-download | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:90` | One preset picker plus two network switches. |
| Auto-download summary | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:938` | Always prints "Medium" because it reads `presets[@"medium"]`. |
| Mobile/Wi-Fi caps | partial | `Core/Client/TGClient+Files.mm:306` | `setAutoDownloadOverMobile` rewrites the caps to 10 MB. |
| Autosave per peer type | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:987` | Three sections of two switches; exceptions are read-only "Chat" plus a raw id. |
| Autosave exception rows | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:1020` | Raw ids, no add or remove. |
| Archive and mute non-contacts | partial | `Features/Settings/TGSettingsViewController+NetworkPages.m:116` | Lives in Data and Storage instead. |
| Custom sounds assignment | partial | `Features/Settings/TGSettingsViewController+PrivacyPages.m:248` | Sounds can be added and removed; no row assigns one. |
| Incomplete login attempts | missing | — | `is_password_pending` is never read; only `is_unconfirmed` is shown. |
| Saved music privacy | missing | — | `userPrivacySettingShowProfileAudio` is not used. |
| Passkeys | missing | — | No passkey screen; the calls exist only in the `TG_DEV` bot console. |
| Badge section | missing | — | No badge settings. |
| In-app notifications | missing | — | Previews per scope only; no in-app sound, vibration or lock-screen name. |
| Notification permission banner | missing | — | The page never says notifications are denied. |
| Automatic power saving | missing | — | Only manual switches; no battery threshold. |
| Contact joined Telegram | missing | — | Not present. |
