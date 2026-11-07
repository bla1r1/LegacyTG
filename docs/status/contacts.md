Contacts: the list, presence, sorting, search, adding and importing people, and the call list that shares the tab. Parity rows come from `_parity_audit/contacts.md`; checked against `src/` on 7 November 2026. Profile detail lives in `profile.md`, calls in `calls.md`.

Counts: 18 done, 15 partial, 11 missing, 0 dev-only.

**What is built.** M12 built the contact list: server-loaded contacts, presence on every row,
sorting by last seen or name with an A-Z rail, local search, add contact,
block, share, delete and secret chat. The call list that shares the tab is
M13: All/Missed filter, redial and the optional fourth tab.

M32 adds what is absent: Invite Friends, contacts permission, phone-book
import, formatted country code and live phone resolution.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Contacts list | Official: Contacts list | done | `Controllers/TGContactsViewController.m:293` | `contactsWithCompletion:` fills the list; avatars load from the member store. |
| Presence on every row | Official: Presence on every row | done | `Controllers/TGContactsViewController.m:504` | `TGStatusTextFromTDStatus` fills the subtitle and online uses the accent colour. |
| Sort by last seen or name | Official: Sort by last seen or name | done | `Controllers/TGContactsViewController.m:218` | "Sort" bar button offers By Last Seen / By Name and persists the choice. |
| Contact order | Official: Contact order | done | `Controllers/TGContactsViewController.m:237` | Presence order when sorting by last seen; A-Z sections and the index rail when by name. |
| Search inside Contacts | Official: Search inside Contacts | partial | `Controllers/TGContactsViewController.m:384` | Local search over the loaded contacts; no server or device-book lookup and no Add row. |
| Invite Friends | Official: Invite Friends | missing | TBD | No Invite row and no address-book access. |
| Contacts permission banner | Official: Contacts permission banner | missing | TBD | The app never reads the address book or asks for permission. |
| Import a phone book | Official: Import a phone book | missing | TBD | No import path; only `importedContactCount` is read for the footer. |
| Import footer | Official: Import footer | partial | `Controllers/TGContactsViewController.m:270` | The old developer-facing line is still the footer, under every list. |
| Add a contact | Official: Add a contact | done | `Controllers/TGNewContactViewController.m:94` | Three fields; Done runs `importContacts` / `addContact`. |
| Live phone resolution | Official: Live phone resolution | missing | `Controllers/TGNewContactViewController.m:94` | No `searchUserByPhoneNumber` until the form is submitted. |
| Country code and formatted phone | Official: Country code and formatted phone | missing | `Controllers/TGNewContactViewController.m:236` | A single unformatted phone-pad field. |
| Note, sync-to-phone and QR add | Official: Note, sync-to-phone and QR add | missing | `Controllers/TGNewContactViewController.m:183` | The form is name plus phone only. |
| Delete a contact | Official: Delete a contact | done | `Controllers/TGProfileViewController+Actions.m:408` | Only when the person is a contact. |
| Block a person | Official: Block a person | done | `Controllers/TGProfileViewController+Actions.m:413` | Confirm sheet, then `setUser:blocked:`. |
| Share a contact | Official: Share a contact | done | `Controllers/TGProfileViewController+Actions.m:334` | Opens the share sheet. |
| Start a secret chat | Official: Start a secret chat | done | `Controllers/TGProfileViewController+Actions.m:349` | Confirms and creates the secret chat. |
| Groups in common | Official: Groups in common | partial | `Controllers/TGProfileViewController.m:404` | Card row and a More action sheet of titles; the Groups tab is not offered. |
| Contact rows: name and status typography | Official: Contact rows: name and status typography | partial | `Controllers/TGContactsViewController.m:445` | 15 pt regular both names, 13 pt status. |
| Verified, Premium, emoji-status, scam and fake labels | Official: Verified, Premium, emoji-status, scam and fake labels | missing | `Controllers/TGContactsViewController.m:440` | Initials avatar and text only; no row badges. |
| Own profile: no header actions | Official: Own profile: no header actions | done | `Controllers/TGProfileViewController+Actions.m:107` | Own profile builds Saved, Story and More only. |
| Info card wording | Official: Info card wording | partial | `Controllers/TGProfileViewController.m:380` | Lowercase keys and no QR control. |
| Premium and private states as badges | Official: Premium and private states as badges | partial | `Controllers/TGProfileViewController.m:389` | Rows such as "personal photo" and "share theme" are still separate detail rows. |
| Rows do what the value means | Official: Rows do what the value means | partial | `Controllers/TGProfileViewController.m:819` | Most rows copy their value; the bio opens its first link and the channel/location rows open. |
| Sort is the left navigation item | Official: Sort is the left navigation item | done | `Controllers/TGContactsViewController.m:176` | The left item is "Sort"; the old Import button is gone. |
| Block and Delete Contact are profile rows | Official: Block and Delete Contact are profile rows | partial | `Controllers/TGProfileViewController+Actions.m:307` | Both remain inside the More menu. |
| Profile music strip | Official: Profile music strip | done | `Controllers/TGProfileViewController.m:312` | First profile-audio track starts playback from a strip. |
| Profile birthday row | Official: Profile birthday row | partial | `Controllers/TGProfileViewController.m:853` | Date, year and today state draw; no gift action. |
| Add to Contacts row | Official: Add to Contacts row | done | `Controllers/TGProfileViewController.m:894` | Shown for a stranger who is not a bot. |
| New Call row | Official: New Call row | missing | TBD | No action row; the list starts with the Show Calls Tab switch. |
| All / Missed filter | Official: All / Missed filter | done | `Controllers/TGSettingsViewController+Pages.m:731` | `recentCallsFilter` filters the list; the empty state says "No missed calls". |
| Call row shape | Official: Call row shape | partial | `Controllers/TGSettingsViewController+Pages.m:759` | One subtitle line; no avatar, glyph, right date or info control. |
| Tap a call redials | Official: Tap a call redials | partial | `Controllers/TGSettingsViewController+Pages.m:781` | Tap redials; there is no info control or details screen. |
| Missed calls say "Missed" | Official: Missed calls say "Missed" | done | `Controllers/TGSettingsViewController+Pages.m:764` | `typeLabel` is "Missed" and the row is destructive. |
| Call history paging | Official: Call history paging | missing | `Core/TGClient+Account.m:1062` | One request for 50; `next_offset` is not followed. |
| Empty call list | Official: Empty call list | partial | `Controllers/TGSettingsViewController+Pages.m:750` | A plain "No recent calls" / "No missed calls" row. |
| Optional Calls tab | Official: Optional Calls tab | done | `Controllers/TGSettingsViewController+Pages.m:736` | Switch in Recent Calls; the root builds the tab when enabled. |
| Active group calls above Recent Calls | Official: Active group calls above Recent Calls | missing | TBD | No group-call rows in Recent Calls. |
| New Group full form | Official: New Group full form | partial | `Controllers/TGContactsViewController.m:535` | Picks members first, then asks for a name in an alert. |
| New Channel form | Official: New Channel form | partial | `Controllers/TGChatListViewController.m:1282` | A single "Channel name" alert after the compose sheet. |
| Compose rows over the contact list | Official: Compose rows over the contact list | partial | `Controllers/TGChatListViewController.m:1262` | Four-choice alert sheet; no New Contact row and no compose search. |
| Username in the profile header | Official: Username in the profile header | missing | `Controllers/TGProfileViewController.m:180` | Header draws name and status only; the username lives in the card. |
| Contact picker for groups and channels | Official: Contact picker for groups and channels | done | `Controllers/TGContactsViewController.m:620` | Contact picker with group mode sends `createNewBasicGroupChat`. |
| Contacts tab | Official: Contacts tab | done | `Controllers/RootViewController.m:107` | Contacts is a tab in the root tab bar. |
