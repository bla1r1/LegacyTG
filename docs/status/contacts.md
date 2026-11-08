Contacts: the list, presence, sorting, search, adding and importing people, and the call list that shares the tab. Parity rows come from `_parity_audit/contacts.md`; checked against `src/` on 7 November 2026. Profile detail lives in `profile.md`, calls in `calls.md`.

Counts: 18 done, 15 partial, 11 missing, 0 dev-only.

Built: M12 (list, presence, sort with A-Z rail, search, add, block, share,
delete, secret chat), M13 (shared call list with All/Missed, redial, optional
fourth tab). Open: M32 (Invite Friends, contacts permission, phone-book
import, formatted country code, live phone resolution).

| Feature | State | Where | Note |
|---|---|---|---|
| Contacts list | done | `Features/Contacts/TGContactsViewController.m:293` | `contactsWithCompletion:` fills the list; avatars load from the member store. |
| Presence on every row | done | `Features/Contacts/TGContactsViewController.m:504` | `TGStatusTextFromTDStatus` fills the subtitle and online uses the accent colour. |
| Sort by last seen or name | done | `Features/Contacts/TGContactsViewController.m:218` | "Sort" bar button offers By Last Seen / By Name and persists the choice. |
| Contact order | done | `Features/Contacts/TGContactsViewController.m:237` | Presence order when sorting by last seen; A-Z sections and the index rail when by name. |
| Search inside Contacts | partial | `Features/Contacts/TGContactsViewController.m:384` | Local search over the loaded contacts; no server or device-book lookup and no Add row. |
| Invite Friends | missing | TBD | No Invite row and no address-book access. |
| Contacts permission banner | missing | TBD | The app never reads the address book or asks for permission. |
| Import a phone book | missing | TBD | No import path; only `importedContactCount` is read for the footer. |
| Import footer | partial | `Features/Contacts/TGContactsViewController.m:270` | The old developer-facing line is still the footer, under every list. |
| Add a contact | done | `Features/Contacts/TGNewContactViewController.m:94` | Three fields; Done runs `importContacts` / `addContact`. |
| Live phone resolution | missing | `Features/Contacts/TGNewContactViewController.m:94` | No `searchUserByPhoneNumber` until the form is submitted. |
| Country code and formatted phone | missing | `Features/Contacts/TGNewContactViewController.m:236` | A single unformatted phone-pad field. |
| Note, sync-to-phone and QR add | missing | `Features/Contacts/TGNewContactViewController.m:183` | The form is name plus phone only. |
| Delete a contact | done | `Features/Profile/TGProfileViewController+Actions.m:408` | Only when the person is a contact. |
| Block a person | done | `Features/Profile/TGProfileViewController+Actions.m:413` | Confirm sheet, then `setUser:blocked:`. |
| Share a contact | done | `Features/Profile/TGProfileViewController+Actions.m:334` | Opens the share sheet. |
| Start a secret chat | done | `Features/Profile/TGProfileViewController+Actions.m:349` | Confirms and creates the secret chat. |
| Groups in common | partial | `src/Features/Profile/Core/TGProfileLifecycle.m:404` | Card row and a More action sheet of titles; the Groups tab is not offered. |
| Contact rows: name and status typography | partial | `Features/Contacts/TGContactsViewController.m:445` | 15 pt regular both names, 13 pt status. |
| Verified, Premium, emoji-status, scam and fake labels | missing | `Features/Contacts/TGContactsViewController.m:440` | Initials avatar and text only; no row badges. |
| Own profile: no header actions | done | `Features/Profile/TGProfileViewController+Actions.m:107` | Own profile builds Saved, Story and More only. |
| Info card wording | partial | `src/Features/Profile/Core/TGProfileLifecycle.m:380` | Lowercase keys and no QR control. |
| Premium and private states as badges | partial | `src/Features/Profile/Core/TGProfileLifecycle.m:389` | Rows such as "personal photo" and "share theme" are still separate detail rows. |
| Rows do what the value means | partial | `src/Features/Profile/Core/TGProfileData.m:417` | Most rows copy their value; the bio opens its first link and the channel/location rows open. |
| Sort is the left navigation item | done | `Features/Contacts/TGContactsViewController.m:176` | The left item is "Sort"; the old Import button is gone. |
| Block and Delete Contact are profile rows | partial | `Features/Profile/TGProfileViewController+Actions.m:307` | Both remain inside the More menu. |
| Profile music strip | done | `src/Features/Profile/Core/TGProfileLifecycle.m:312` | First profile-audio track starts playback from a strip. |
| Profile birthday row | partial | `src/Features/Profile/Core/TGProfileData.m:451` | Date, year and today state draw; no gift action. |
| Add to Contacts row | done | `src/Features/Profile/Core/TGProfileData.m:492` | Shown for a stranger who is not a bot. |
| New Call row | missing | TBD | No action row; the list starts with the Show Calls Tab switch. |
| All / Missed filter | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:731` | `recentCallsFilter` filters the list; the empty state says "No missed calls". |
| Call row shape | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:759` | One subtitle line; no avatar, glyph, right date or info control. |
| Tap a call redials | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:781` | Tap redials; there is no info control or details screen. |
| Missed calls say "Missed" | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:764` | `typeLabel` is "Missed" and the row is destructive. |
| Call history paging | missing | `src/Core/Client/Account/TGClient+AccountTwoStep.m:44` | One request for 50; `next_offset` is not followed. |
| Empty call list | partial | `src/Features/Settings/Pages/TGSettingsPagesCore.m:750` | A plain "No recent calls" / "No missed calls" row. |
| Optional Calls tab | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:736` | Switch in Recent Calls; the root builds the tab when enabled. |
| Active group calls above Recent Calls | missing | TBD | No group-call rows in Recent Calls. |
| New Group full form | partial | `Features/Contacts/TGContactsViewController.m:535` | Picks members first, then asks for a name in an alert. |
| New Channel form | partial | `src/Features/ChatList/Core/TGChatListCompose.m:132` | A single "Channel name" alert after the compose sheet. |
| Compose rows over the contact list | partial | `src/Features/ChatList/Core/TGChatListCompose.m:112` | Four-choice alert sheet; no New Contact row and no compose search. |
| Username in the profile header | missing | `Features/Profile/TGProfileViewController.m:180` | Header draws name and status only; the username lives in the card. |
| Contact picker for groups and channels | done | `Features/Contacts/TGContactsViewController.m:620` | Contact picker with group mode sends `createNewBasicGroupChat`. |
| Contacts tab | done | `App/RootViewController.m:107` | Contacts is a tab in the root tab bar. |
