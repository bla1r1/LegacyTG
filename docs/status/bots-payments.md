Bots, payments, Stars, gifts and the wallet surfaces. No file in `src/` sends the remaining TDLib functions; the matrix below groups them into user-visible features. Checked against `src/` and `td_api.tl` on 7 November 2026.

Counts: 2 done, 8 partial, 19 missing, 7 dev-only.

**What is built.** Bots and payments are the least built area: two rows done (bot reply keyboards
and owned-bot settings), eight partial and nineteen missing. M16 draws invoice,
gift, giveaway, paid-media and Stars message types as cards; M40 owns inline
mode, Web Apps, commands and guest bots.

M20 owns the money path: checkout, Premium, Stars, gifts, boosts, TON,
Passport and StoreKit. Until it exists, the release UI reads state and
explains that purchase happens in an official client.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Bot reply keyboard | Official: Bot reply keyboard | done | `Controllers/TGChatViewController+Bots.m:103` | Keyboard rows/one-time/placeholder are drawn and send text. |
| Bot inline buttons | Official: Bot inline buttons | partial | `Controllers/TGChatViewController+Bots.m:30` | Web App, Pay, Game and password callbacks answer "needs a newer Telegram". |
| Inline bot mode (`@bot query`) | Official: Inline bot mode (`@bot query`) | missing | `Controllers/TGChatViewController+Bots.m:87` | Switch-inline only types the mention; no inline result list or `sendInlineQueryResult`. |
| Bot Web Apps | Official: Bot Web Apps | missing | `Controllers/TGBotConsoleViewController.m:214` | No Web App host; the console copies the URL. |
| Bot info card | Official: Bot info card | partial | `Core/TGClient+Account.m:565` | Short description can stand in for a missing bio; no commands or Add to Chat. |
| Bot commands and menu button | Official: Bot commands and menu button | dev-only | `Controllers/TGBotConsoleViewController.m:170` | `getCommands` / `setCommands` / `getMenuButton` are console rows, not a bot settings screen. |
| Owned bots | Official: Owned bots | done | `Controllers/TGProfileViewController+Actions.m:640` | A bot profile's Bot Settings opens `TGBotConsoleViewController`; name, description, photo and similar bots are rows. |
| Guest bots | Official: Guest bots | missing | `Core/TGMessageFlatten.m:609` | `guest_bot_caller_id` is not parsed. |
| Bot verification | Official: Bot verification | dev-only | `Controllers/TGBotConsoleViewController.m:116` | Debug "Verify A User Or Chat" row only. |
| Invoices | Official: Invoices | partial | `Core/TGMessageContentCommerce.m:203` | Card draws; the Pay button is removed because there is no payment form. |
| Paid media | Official: Paid media | partial | `Controllers/TGChatViewController+MediaCells.m:303` | Blur and price show; tapping says Stars are unavailable. |
| Paid messages | Official: Paid messages | missing | `Controllers/TGChatViewController+Input.m:348` | No price row or `paid_message_star_count` send option. |
| Premium state | Official: Premium state | partial | `Core/TGClient+Account.m:292` | Reads `getPremiumState`; the Settings row reports Active or not in an alert. |
| Gift catalogue | Official: Gift catalogue | dev-only | `Core/TGClient+Tier3.m:2828` | `getAvailableGifts` is a read-only console row. |
| Gift notes and signatures | Official: Gift notes and signatures | missing | `Core/TGClient+Account.m:36` | The flatten reads the wrong key, so the note is blank. |
| Giveaways | Official: Giveaways | partial | `Core/TGMessageCard.m:174` | Cards and winner lists draw; creating or joining a giveaway is not built. |
| Affiliate programs | Official: Affiliate programs | partial | `Controllers/TGAffiliateProgramsViewController.m:20` | Catalogue and connections exist behind a debug entry; no commission badge. |
| Revenue statistics | Official: Revenue statistics | dev-only | `Controllers/TGSettingsViewController+Pages.m:1277` | Read-only rows in the `TG_DEV` Stars console. |
| Saved orders and payment data | Official: Saved orders and payment data | partial | `Core/TGClient+Payments.m:25` | `getSavedOrderInfo` / `deleteSavedOrderInfo` work; card lookup and offers are `TG_DEV` read-only rows. |
| Bank card lookup | Official: Bank card lookup | dev-only | `Core/TGClient+Payments.m:52` | `getBankCardInfo` is a console row; no release surface. |
| Suggested-post price | Official: Suggested-post price | dev-only | `Core/TGClient+Payments.m:74` | `addOffer` is in the payment dev page. |
| Order validation | Official: Order validation | dev-only | `Core/TGClient+Payments.m:124` | `validateOrderInfo` is a sequence of debug alerts. |
| Pay an invoice | Official: Pay an invoice | missing | — | `getPaymentForm` and `sendPaymentForm` are never sent; no StoreKit or provider. |
| Paid reactions | Official: Paid reactions | missing | — | No paid-reaction request or price sheet. |
| Stars balance | Official: Stars balance | missing | — | No release row; `getStarTransactions` is read only in the `TG_DEV` console. |
| Star subscriptions | Official: Star subscriptions | missing | — | No surface. |
| Premium purchase | Official: Premium purchase | missing | — | The Settings row reads the state and says purchase happens in an official client. |
| Send a gift | Official: Send a gift | missing | — | No release row or send path; `sendGift` is never called. |
| Gift collections | Official: Gift collections | missing | — | `getGiftCollections` and the collection calls are never sent. |
| Gift auctions and resale | Official: Gift auctions and resale | missing | — | All auction and resale calls are absent. |
| Boosts | Official: Boosts | missing | — | No release surface; `getChatBoostStatus` and `boostChat` are read only in the `TG_DEV` console. |
| TON wallet | Official: TON wallet | missing | — | All 43 wallet, on-ramp and NFT functions are never sent. |
| Passport | Official: Passport | missing | — | All 8 Passport functions are never sent; no capture or 2FA vault. |
| StoreKit purchases | Official: StoreKit purchases | missing | — | No StoreKit linkage; `canPurchaseFromStore` and `assignStoreTransaction` are never sent. |
| Refund a Star payment | Official: Refund a Star payment | missing | — | `refundStarPayment` and `editUserStarSubscription` are never sent. |
| Gift privacy | Official: Gift privacy | missing | — | No who-may-send, button or accepted-types rows; `setGiftSettings` is never sent. |
