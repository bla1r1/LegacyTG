Login, sign-up and account switching: every auth step, the account slots, sessions and websites. Sources are `docs/feature_backlog.md` (auth waves), `_parity_audit/settings_main.md` (accounts) and `changelog.md`; checked against `src/` on 7 November 2026. Sessions detail is also in `privacy-security.md`.

Counts: 25 done, 4 partial, 0 missing, 2 dev-only.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Sign in by phone and code | Official: Sign in by phone and code | done | `Controllers/TGLoginViewController+Steps.m:1` | Phone, code and password steps are driven by `authorizationStateWait*`. |
| Country and phone prefix | Official: Country and phone prefix | done | `Controllers/TGLoginViewController+Phone.m:14` | `getCountries`, `getCountryCode` and a searchable country picker. |
| Sign-up name | Official: Sign-up name | done | `Controllers/TGLoginViewController+Steps.m:537` | `registerUser` with first and last name and the terms text. |
| Terms of service | Official: Terms of service | done | `Controllers/TGTermsViewController.m:1` | Terms screen; Accept sends `acceptTermsOfService`. |
| Two-step verification password | Official: Two-step verification password | done | `Core/TGClient+Auth.m:71` | `checkAuthenticationPassword`, hint and email recovery steps. |
| Forgot password | Official: Forgot password | done | `Core/TGClient+Auth.m:104` | `requestPasswordRecovery`, `checkAuthenticationPasswordRecoveryCode`, `recoverPassword`; hint shown. |
| Email address step | Official: Email address step | done | `Controllers/TGLoginViewController+Steps.m:1` | `authorizationStateWaitEmailAddress` / `WaitEmailCode` have steps. |
| QR login | Official: QR login | done | `Core/TGClient+Auth.m:48` | `requestQrCodeAuthentication`; the QR step draws a locally generated code. |
| Scan a QR link | Official: Scan a QR link | done | `Controllers/TGQRViewController.m:65` | Camera scanner confirms through `confirmQrCodeAuthentication`. |
| Web login token | Official: Web login token | done | `Core/TGClient+Auth.m:363` | `checkAuthenticationWebToken`; the step is on the login screen. |
| Firebase-delivered SMS code | Official: Firebase-delivered SMS code | done | `Core/TGClient+Auth.m:548` | `sendAuthenticationFirebaseSms`. |
| Login with Telegram (OAuth) | Official: Login with Telegram (OAuth) | dev-only | `Core/TGClient+Tier3.m:1729` | Only in the `TG_DEV` bot console; `updateNewOauthRequest` has no release screen. |
| Passkeys | Official: Passkeys | dev-only | `Core/TGClient+BotSession.m:186` | The calls are in the `TG_DEV` bot console; iOS 6 cannot produce an attestation. |
| Change phone number | Official: Change phone number | done | `Core/TGClient+Auth.m:501` | `sendPhoneNumberCode`, `checkPhoneNumberCode`, resend and missing-code report. |
| Temporary password | Official: Temporary password | done | `Controllers/TGSettingsViewController+PrivacyPages.m:554` | `getTemporaryPasswordState` and `createTemporaryPassword`. |
| Application verification | Official: Application verification | done | `Controllers/TGSettingsViewController+PrivacyPages.m:558` | Required/none state and `setApplicationVerificationToken`. |
| Login email | Official: Login email | done | `Core/TGClient+Auth.m:323` | `setLoginEmailAddress` and `checkLoginEmailAddressCode`. |
| Accounts switcher | Official: Accounts switcher | partial | `Controllers/TGSettingsViewController+Actions.m:37` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Account slots | Official: Account slots | partial | `Core/TGClient+Accounts.m:16` | Three slots for every account; each slot has its own TDLib directory. |
| Add Account | Official: Add Account | done | `Controllers/TGSettingsViewController+Actions.m:52` | `Add Account` creates a slot and switches to it. |
| Switch account | Official: Switch account | done | `Core/TGClient+Accounts.m:143` | `switchToAccountSlot:` restarts the client on that slot's database. |
| Notifications for inactive accounts | Official: Notifications for inactive accounts | done | `Controllers/TGSettingsViewController+Actions.m:57` | The sheet says so explicitly; only the active slot runs TDLib. |
| Log out | Official: Log out | done | `Controllers/TGSettingsViewController+Pages.m:246` | Confirmation, then `logOut`. |
| Delete account | Official: Delete account | done | `Controllers/TGSettingsViewController+Actions.m:390` | Delete Account row with reason and password. |
| Current session | Official: Current session | partial | `Controllers/TGSessionsViewController.m:140` | Row shows app name and platform; model, location and last active are dropped. |
| Other sessions | Official: Other sessions | done | `Controllers/TGSessionsViewController.m:265` | Current and other sessions, terminate one or all. |
| Unconfirmed session | Official: Unconfirmed session | done | `Controllers/TGSessionsViewController.m:338` | Offers Confirm beside Sign Out and sends `confirmSession`. |
| Inactive session timeout | Official: Inactive session timeout | done | `Controllers/TGSessionsViewController.m:228` | 1 week to 1 year through `setInactiveSessionTtl`. |
| Connected websites | Official: Connected websites | done | `Controllers/TGWebsitesViewController.m:29` | Per-site sign-out and sign out all. |
| Proxy at sign-in | Official: Proxy at sign-in | done | `Controllers/TGSettingsViewController+NetworkPages.m:722` | Proxy can be added and enabled; TDLib uses it for auth too. |
| Auth errors as sentences | Official: Auth errors as sentences | partial | `Core/TGClient.m` | Core passes `result[@"message"]` up, so alerts contain TDLib's own text. |
