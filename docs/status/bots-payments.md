Bots, payments, Stars, gifts and the wallet surfaces. No file in `src/` sends the remaining TDLib functions; the matrix below groups them into user-visible features. Checked against `src/` and `td_api.tl` on 7 November 2026.

Counts: 2 done, 8 partial, 19 missing, 7 dev-only.

Built: M16 message cards; a bot's reply keyboard and owned-bot settings. Open:
M20 the money path (checkout, Premium, Stars, gifts, boosts, TON, Passport,
StoreKit); M40 inline mode, Web Apps, commands, guest bots. Until M20 the
release UI reads state and says purchase happens in an official client.

| Feature | State | Where | Note |
|---|---|---|---|
| Bot reply keyboard | done | `Features/Chat/Composer/TGChatViewController+Bots.m:103` | Keyboard rows/one-time/placeholder are drawn and send text. |
| Bot inline buttons | partial | `Features/Chat/Composer/TGChatViewController+Bots.m:30` | Web App, Pay, Game and password callbacks answer "needs a newer Telegram". |
| Inline bot mode (`@bot query`) | missing | `Features/Chat/Composer/TGChatViewController+Bots.m:87` | Switch-inline only types the mention; no inline result list or `sendInlineQueryResult`. |
| Bot Web Apps | missing | `Features/Dev/TGDevBotConsoleViewController.m:214` | No Web App host; the console copies the URL. |
| Bot info card | partial | `src/Core/Client/Account/TGClient+AccountLocalNotifications.m:50` | Short description can stand in for a missing bio; no commands or Add to Chat. |
| Bot commands and menu button | dev-only | `Features/Dev/TGDevBotConsoleViewController.m:170` | `getCommands` / `setCommands` / `getMenuButton` are console rows, not a bot settings screen. |
| Owned bots | done | `Features/Profile/TGProfileViewController+Actions.m:640` | A bot profile's Bot Settings opens `TGDevBotConsoleViewController`; name, description, photo and similar bots are rows. |
| Guest bots | missing | `Core/Model/TGMessageFlatten.m:609` | `guest_bot_caller_id` is not parsed. |
| Bot verification | dev-only | `Features/Dev/TGDevBotConsoleViewController.m:116` | Debug "Verify A User Or Chat" row only. |
| Invoices | partial | `Core/Model/TGMessageContentCommerce.m:203` | Card draws; the Pay button is removed because there is no payment form. |
| Paid media | partial | `Features/Chat/Composer/TGChatViewController+MediaCells.m:303` | Blur and price show; tapping says Stars are unavailable. |
| Paid messages | missing | `Features/Chat/Composer/TGChatViewController+Input.m:348` | No price row or `paid_message_star_count` send option. |
| Premium state | partial | `src/Core/Client/Account/TGClient+AccountPeople.m:109` | Reads `getPremiumState`; the Settings row reports Active or not in an alert. |
| Gift catalogue | dev-only | `Core/Client/Audit/TGClient+Gifts.m:9` | `getAvailableGifts` is a read-only console row. |
| Gift notes and signatures | missing | `Core/Client/Account/TGClient+AccountSupport.m:39` | The flatten reads the wrong key, so the note is blank. |
| Giveaways | partial | `Core/Model/TGMessageCard.m:174` | Cards and winner lists draw; creating or joining a giveaway is not built. |
| Affiliate programs | partial | `Features/BotsPayments/TGAffiliateProgramsViewController.m:20` | Catalogue and connections exist behind a debug entry; no commission badge. |
| Revenue statistics | dev-only | `src/Features/Settings/Pages/TGSettingsPagesPayments.m:473` | Read-only rows in the `TG_DEV` Stars console. |
| Saved orders and payment data | partial | `Core/Client/TGClient+Payments.m:25` | `getSavedOrderInfo` / `deleteSavedOrderInfo` work; card lookup and offers are `TG_DEV` read-only rows. |
| Bank card lookup | dev-only | `Core/Client/TGClient+Payments.m:52` | `getBankCardInfo` is a console row; no release surface. |
| Suggested-post price | dev-only | `Core/Client/TGClient+Payments.m:74` | `addOffer` is in the payment dev page. |
| Order validation | dev-only | `Core/Client/TGClient+Payments.m:124` | `validateOrderInfo` is a sequence of debug alerts. |
| Pay an invoice | missing | — | `getPaymentForm` and `sendPaymentForm` are never sent; no StoreKit or provider. |
| Paid reactions | missing | — | No paid-reaction request or price sheet. |
| Stars balance | missing | — | No release row; `getStarTransactions` is read only in the `TG_DEV` console. |
| Star subscriptions | missing | — | No surface. |
| Premium purchase | missing | — | The Settings row reads the state and says purchase happens in an official client. |
| Send a gift | missing | — | No release row or send path; `sendGift` is never called. |
| Gift collections | missing | — | `getGiftCollections` and the collection calls are never sent. |
| Gift auctions and resale | missing | — | All auction and resale calls are absent. |
| Boosts | missing | — | No release surface; `getChatBoostStatus` and `boostChat` are read only in the `TG_DEV` console. |
| TON wallet | missing | — | All 43 wallet, on-ramp and NFT functions are never sent. |
| Passport | missing | — | All 8 Passport functions are never sent; no capture or 2FA vault. |
| StoreKit purchases | missing | — | No StoreKit linkage; `canPurchaseFromStore` and `assignStoreTransaction` are never sent. |
| Refund a Star payment | missing | — | `refundStarPayment` and `editUserStarSubscription` are never sent. |
| Gift privacy | missing | — | No who-may-send, button or accepted-types rows; `setGiftSettings` is never sent. |
