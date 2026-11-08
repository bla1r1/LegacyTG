Login, sign-up and account switching: every auth step, the account slots, sessions and websites. Sources are `_parity_audit/settings_main.md` and `changelog.md`; checked against `src/` on 7 November 2026. Sessions detail is in `privacy-security.md`.

Counts: 25 done, 4 partial, 0 missing, 2 dev-only.

Built: M2 (phone/code, sign-up, 2FA and recovery, email, QR, web token,
Firebase SMS, change phone, temporary password, application verification; three
account slots with their own TDLib directory). Open: M34 (auth errors as
sentences); the account UI is flat (names with a check, no avatars or
per-account logout). Passkeys and OAuth stay in the `TG_DEV` console.

| Feature | State | Where | Note |
|---|---|---|---|
| Sign in by phone and code | done | `Features/Auth/TGLoginViewController+Steps.m:1` | Phone, code and password steps are driven by `authorizationStateWait*`. |
| Country and phone prefix | done | `Features/Auth/TGLoginViewController+Phone.m:14` | `getCountries`, `getCountryCode` and a searchable country picker. |
| Sign-up name | done | `Features/Auth/TGLoginViewController+Steps.m:537` | `registerUser` with first and last name and the terms text. |
| Terms of service | done | `Features/Auth/TGTermsViewController.m:1` | Terms screen; Accept sends `acceptTermsOfService`. |
| Two-step verification password | done | `Core/Client/TGClient+Auth.m:71` | `checkAuthenticationPassword`, hint and email recovery steps. |
| Forgot password | done | `Core/Client/TGClient+Auth.m:104` | `requestPasswordRecovery`, `checkAuthenticationPasswordRecoveryCode`, `recoverPassword`; hint shown. |
| Email address step | done | `Features/Auth/TGLoginViewController+Steps.m:1` | `authorizationStateWaitEmailAddress` / `WaitEmailCode` have steps. |
| QR login | done | `Core/Client/TGClient+Auth.m:48` | `requestQrCodeAuthentication`; the QR step draws a locally generated code. |
| Scan a QR link | done | `Features/Auth/TGQRViewController.m:65` | Camera scanner confirms through `confirmQrCodeAuthentication`. |
| Web login token | done | `Core/Client/TGClient+Auth.m:363` | `checkAuthenticationWebToken`; the step is on the login screen. |
| Firebase-delivered SMS code | done | `Core/Client/TGClient+Auth.m:548` | `sendAuthenticationFirebaseSms`. |
| Login with Telegram (OAuth) | dev-only | `Core/Client/Audit/TGClient+OAuth.m:9` | Only in the `TG_DEV` bot console; `updateNewOauthRequest` has no release screen. |
| Passkeys | dev-only | `Core/Client/TGClient+BotSession.m:186` | The calls are in the `TG_DEV` bot console; iOS 6 cannot produce an attestation. |
| Change phone number | done | `Core/Client/TGClient+Auth.m:501` | `sendPhoneNumberCode`, `checkPhoneNumberCode`, resend and missing-code report. |
| Temporary password | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:554` | `getTemporaryPasswordState` and `createTemporaryPassword`. |
| Application verification | done | `Features/Settings/TGSettingsViewController+PrivacyPages.m:558` | Required/none state and `setApplicationVerificationToken`. |
| Login email | done | `Core/Client/TGClient+Auth.m:323` | `setLoginEmailAddress` and `checkLoginEmailAddressCode`. |
| Accounts switcher | partial | `Features/Settings/TGSettingsViewController+Actions.m:37` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Account slots | partial | `Core/Client/TGClient+Accounts.m:16` | Three slots for every account; each slot has its own TDLib directory. |
| Add Account | done | `Features/Settings/TGSettingsViewController+Actions.m:52` | `Add Account` creates a slot and switches to it. |
| Switch account | done | `Core/Client/TGClient+Accounts.m:143` | `switchToAccountSlot:` restarts the client on that slot's database. |
| Notifications for inactive accounts | done | `Features/Settings/TGSettingsViewController+Actions.m:57` | The sheet says so explicitly; only the active slot runs TDLib. |
| Log out | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:246` | Confirmation, then `logOut`. |
| Delete account | done | `Features/Settings/TGSettingsViewController+Actions.m:390` | Delete Account row with reason and password. |
| Current session | partial | `Features/Settings/TGSessionsViewController.m:140` | Row shows app name and platform; model, location and last active are dropped. |
| Other sessions | done | `Features/Settings/TGSessionsViewController.m:265` | Current and other sessions, terminate one or all. |
| Unconfirmed session | done | `Features/Settings/TGSessionsViewController.m:338` | Offers Confirm beside Sign Out and sends `confirmSession`. |
| Inactive session timeout | done | `Features/Settings/TGSessionsViewController.m:228` | 1 week to 1 year through `setInactiveSessionTtl`. |
| Connected websites | done | `Features/Settings/TGWebsitesViewController.m:29` | Per-site sign-out and sign out all. |
| Proxy at sign-in | done | `Features/Settings/TGSettingsViewController+NetworkPages.m:722` | Proxy can be added and enabled; TDLib uses it for auth too. |
| Auth errors as sentences | partial | `Core/Client/TGClient.m` | Core passes `result[@"message"]` up, so alerts contain TDLib's own text. |
