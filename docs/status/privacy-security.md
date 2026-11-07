Privacy and security: the lock, two-step, sessions, blocked users, visibility rules, storage and network controls. Parity rows come from `_parity_audit/settings_privacy.md`; checked against `src/` on 7 November 2026. Notification presentation detail is in `notifications.md`.

Counts: 34 done, 29 partial, 19 missing, 0 dev-only.

**What is built.** M14 built the lock and security surface: passcode with auto-lock, two-step
verification, login email, change phone, sessions and websites, blocked users,
six visibility rules, read receipts, close friends, data controls and payment
records. The storage page and network page are from M5 and M14.

M37 fills the exception lists, storage maximum and per-chat rules; M31 the
notification half that shares this screen. The raw TDLib text in security
alerts is M34.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Passcode row at the top of Security | Official: Passcode row at the top of Security | done | `Controllers/TGSettingsViewController+PrivacyPages.m:1080` | Passcode Lock is the first Security row; the page has on/off/change and auto-lock. |
| Passcode on / off / change | Official: Passcode on / off / change | done | `Controllers/TGSettingsViewController+PrivacyPages.m:1080` | 4-digit code with a confirmation step. |
| Auto-lock timeout | Official: Auto-lock timeout | done | `Controllers/TGSettingsViewController+PrivacyPages.m:1133` | Immediately, 1 min, 5 min, 1 hour or disabled. |
| Lock icon on the chat list | Official: Lock icon on the chat list | done | `Controllers/TGChatListViewController.m:499` | Tap locks immediately; the button exists only when a passcode is set. |
| Lock on launch / foreground | Official: Lock on launch / foreground | done | `App/AppDelegate.m:180` | Unlock sheet after launch and when `shouldLockOnForeground`. |
| Touch ID / Face ID | Official: Touch ID / Face ID | missing | `Core/TGPasscode.h:12` | No `LAContext` or biometric path anywhere. |
| Wrong-passcode data wipe | Official: Wrong-passcode data wipe | missing | `Core/TGPasscode.m:1` | Attempts are counted for the shake only; no erase option. |
| Two-step verification | Official: Two-step verification | done | `Controllers/TGSettingsViewController+Actions.m:135` | Set, change, recovery address, turn off, forgot password. |
| Two-step screen detail | Official: Two-step screen detail | partial | `Core/TGClient+Auth.m:142` | `getPasswordState` is reduced to a BOOL plus "set"; hint and `pending_reset_date` never reach the user. |
| Login email address | Official: Login email address | done | `Controllers/TGSettingsViewController+PrivacyPages.m:545` | Set, verify, resend, remove. |
| Login Email row value | Official: Login Email row value | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:539` | The row exists with a nil detail, so it looks unset even when set. |
| Change phone number | Official: Change phone number | done | `Controllers/TGSettingsViewController+PrivacyPages.m:549` | Code flow across the auth states. |
| Temporary password | Official: Temporary password | done | `Controllers/TGSettingsViewController+PrivacyPages.m:554` | Create a one-time password for another device. |
| Application verification | Official: Application verification | done | `Controllers/TGSettingsViewController+PrivacyPages.m:558` | Shows required/none and submits the code. |
| Current session | Official: Current session | partial | `Controllers/TGSessionsViewController.m:140` | Title is `application_name`, subtitle platform + IP; model, location and last active are dropped. |
| Other sessions | Official: Other sessions | done | `Controllers/TGSessionsViewController.m:140` | Each row opens sign-out and its call/secret-chat switches. |
| Session row detail | Official: Session row detail | partial | `Core/TGClient+Account.m:286` | `device_model`, `location` and `last_active_date` are never shown. |
| Terminate one session | Official: Terminate one session | done | `Controllers/TGSessionsViewController.m:307` | Confirms then `terminateSession`. |
| Terminate all other sessions | Official: Terminate all other sessions | done | `Controllers/TGSessionsViewController.m:265` | `terminateAllOtherSessions`. |
| Inactive session timeout | Official: Inactive session timeout | done | `Controllers/TGSessionsViewController.m:228` | 1 week to 1 year. |
| Connected websites | Official: Connected websites | done | `Controllers/TGWebsitesViewController.m:29` | Per-site sign-out and sign out all. |
| QR scanner for login links | Official: QR scanner for login links | done | `Controllers/TGSessionsViewController.m:220` | Camera scanner opens a t.me link. |
| Blocked users list | Official: Blocked users list | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:789` | Plain text names only; no add, no avatars; tapping unblocks immediately. |
| Blocked users count | Official: Blocked users count | missing | `Controllers/TGSettingsViewController+PrivacyPages.m:570` | The row has no detail value. |
| Block a person | Official: Block a person | done | `Controllers/TGProfileViewController+Actions.m:413` | From the profile's More menu. |
| Last Seen privacy | Official: Last Seen privacy | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; no exception lists. |
| Profile photo privacy | Official: Profile photo privacy | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; no public-photo row. |
| Phone number privacy | Official: Phone number privacy | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; `AllowFindingByPhoneNumber` is never read. |
| Calls privacy | Official: Calls privacy | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | Three choices only; no P2P rule. |
| Group invite privacy | Official: Group invite privacy | done | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | Group Invites is one of the six three-choice rows. |
| Forwarded-message link privacy | Official: Forwarded-message link privacy | done | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | Forwarded Messages is one of the six three-choice rows. |
| Birthday privacy | Official: Birthday privacy | done | `Controllers/TGEditProfileViewController.m:476` | Birthday privacy is chosen in Edit Profile. |
| Bio privacy | Official: Bio privacy | missing | `Controllers/TGEditProfileViewController.m:534` | No Bio row in Privacy and no line under the field. |
| Gifts privacy | Official: Gifts privacy | missing | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | No who-may-send, gift button or accepted-types rows. |
| Voice message privacy | Official: Voice message privacy | missing | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | No row for who may send voice messages. |
| Added-by-phone privacy | Official: Added-by-phone privacy | missing | `Controllers/TGSettingsViewController+PrivacyPages.m:500` | No row for finding the account by phone. |
| Privacy exception lists | Official: Privacy exception lists | missing | `Controllers/TGSettingsViewController+Actions.m:447` | The rule sheet is only Everybody/Contacts/Nobody. |
| Privacy row order and wording | Official: Privacy row order and wording | partial | `Controllers/TGSettingsViewController.m:639` | Six rows: Last Seen, Photo, Phone, Calls, Invites, Forwards. |
| Read receipts | Official: Read receipts | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:623` | A top-level Read Receipts switch in the Messages card. |
| Delete messages by default | Official: Delete messages by default | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:588` | Four fixed choices; any other server value prints plain days, no custom picker. |
| Messages from unknown users | Official: Messages from unknown users | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:601` | One boolean switch; no Premium state or Stars price row. |
| Personal chat | Official: Personal chat | done | `Controllers/TGSettingsViewController+PrivacyPages.m:610` | Choose a personal chat. |
| Inactive groups | Official: Inactive groups | done | `Controllers/TGSettingsViewController+PrivacyPages.m:614` | List and leave. |
| My public chats | Official: My public chats | done | `Controllers/TGSettingsViewController+PrivacyPages.m:618` | Lists public chats. |
| Close friends | Official: Close friends | done | `Controllers/TGSettingsViewController+PrivacyPages.m:643` | Picker and count. |
| Close birthdays | Official: Close birthdays | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:649` | The row calls `hideContactCloseBirthdays` instead of showing the list. |
| Suggest frequent contacts | Official: Suggest frequent contacts | done | `Controllers/TGSettingsViewController+PrivacyPages.m:659` | Writes `disable_top_chats`. |
| Delete synced contacts | Official: Delete synced contacts | done | `Controllers/TGSettingsViewController+PrivacyPages.m:664` | Confirmed `clearImportedContacts`. |
| Data sub-screen | Official: Data sub-screen | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:658` | Delete Synced Contacts here; Clear Drafts lives in Data and Storage; no payment-info or secret-chat link-preview row. |
| Freeze state | Official: Freeze state | done | `Controllers/TGSettingsViewController+PrivacyPages.m:683` | Dates, appeal link, open appeal. |
| Subscription state | Official: Subscription state | done | `Controllers/TGSettingsViewController+PrivacyPages.m:689` | Reads the account's subscription record. |
| Age verification | Official: Age verification | done | `Controllers/TGSettingsViewController+PrivacyPages.m:695` | Shows the parameters Telegram sent. |
| reCAPTCHA request | Official: reCAPTCHA request | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:701` | Shows the request and says the app has no web view; no solving path. |
| Verify an email address | Official: Verify an email address | done | `Controllers/TGSettingsViewController+PrivacyPages.m:705` | Send code, enter it, store the address. |
| Orders and payment data | Official: Orders and payment data | partial | `Controllers/TGSettingsViewController+Pages.m:887` | Read-only saved checkout; card lookup and offer tools are `TG_DEV`. |
| Delete saved payment credentials | Official: Delete saved payment credentials | done | `Controllers/TGSettingsViewController+PrivacyPages.m:722` | Account-wide confirmed delete. |
| My link | Official: My link | done | `Controllers/TGSettingsViewController+PrivacyPages.m:743` | Copies the account's t.me link. |
| Protected content flag | Official: Protected content flag | done | `Controllers/TGChatToolsViewController.m:163` | Copy/forward/save are blocked in a protected chat; no screenshot guard. |
| Session secret-chat and call switches | Official: Session secret-chat and call switches | done | `Controllers/TGSessionsViewController.m:300` | Per-session accept calls / accept secret chats. |
| Storage: KEEP MEDIA per peer type | Official: Storage: KEEP MEDIA per peer type | missing | `Controllers/TGStorageViewController.m:190` | The page is ring + categories + one Clear Cache row. |
| Storage: maximum cache size | Official: Storage: maximum cache size | missing | `Controllers/TGStorageViewController.m:190` | No maximum-cache row. |
| Storage: category rows and selection | Official: Storage: category rows and selection | partial | `Controllers/TGStorageViewController.m:275` | Tapping a category clears that whole type after a sheet; no selection or per-type clear button. |
| Storage: chats view and per-chat exceptions | Official: Storage: chats view and per-chat exceptions | missing | `Controllers/TGStorageViewController.m:190` | No chats view and no per-chat exceptions. |
| Storage: category split and colours | Official: Storage: category split and colours | partial | `Core/TGClient+Files.mm:373` | Five buckets plus Other; profile photos and thumbnails sit inside Photos. |
| Clear Cache amount | Official: Clear Cache amount | partial | `Controllers/TGStorageViewController.m:280` | "Clear Cache" plus the ring total; sends empty `file_types`, so TDLib keeps thumbnails, profile photos, stickers and wallpapers. |
| Data & Storage summaries | Official: Data & Storage summaries | partial | `Controllers/TGSettingsViewController+NetworkPages.m:40` | Storage Usage row is nil; Network Usage reads "X in, Y out". |
| Network Usage screen | Official: Network Usage screen | partial | `Controllers/TGSettingsViewController+NetworkPages.m:72` | One "X in, Y out" row with a reset confirm. |
| Per-connection auto-download | Official: Per-connection auto-download | partial | `Controllers/TGSettingsViewController+NetworkPages.m:90` | One preset picker plus two network switches. |
| Auto-download summary | Official: Auto-download summary | partial | `Controllers/TGSettingsViewController+NetworkPages.m:938` | Always prints "Medium" because it reads `presets[@"medium"]`. |
| Mobile/Wi-Fi caps | Official: Mobile/Wi-Fi caps | partial | `Core/TGClient+Files.mm:306` | `setAutoDownloadOverMobile` rewrites the caps to 10 MB. |
| Autosave per peer type | Official: Autosave per peer type | partial | `Controllers/TGSettingsViewController+NetworkPages.m:987` | Three sections of two switches; exceptions are read-only "Chat" plus a raw id. |
| Autosave exception rows | Official: Autosave exception rows | partial | `Controllers/TGSettingsViewController+NetworkPages.m:1020` | Raw ids, no add or remove. |
| Archive and mute non-contacts | Official: Archive and mute non-contacts | partial | `Controllers/TGSettingsViewController+NetworkPages.m:116` | Lives in Data and Storage instead. |
| Custom sounds assignment | Official: Custom sounds assignment | partial | `Controllers/TGSettingsViewController+PrivacyPages.m:248` | Sounds can be added and removed; no row assigns one. |
| Incomplete login attempts | Official: Incomplete login attempts | missing | — | `is_password_pending` is never read; only `is_unconfirmed` is shown. |
| Saved music privacy | Official: Saved music privacy | missing | — | `userPrivacySettingShowProfileAudio` is not used. |
| Passkeys | Official: Passkeys | missing | — | No passkey screen; the calls exist only in the `TG_DEV` bot console. |
| Badge section | Official: Badge section | missing | — | No badge settings. |
| In-app notifications | Official: In-app notifications | missing | — | Previews per scope only; no in-app sound, vibration or lock-screen name. |
| Notification permission banner | Official: Notification permission banner | missing | — | The page never says notifications are denied. |
| Automatic power saving | Official: Automatic power saving | missing | — | Only manual switches; no battery threshold. |
| Contact joined Telegram | Official: Contact joined Telegram | missing | — | Not present. |
