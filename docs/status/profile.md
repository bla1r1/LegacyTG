User, group and channel profiles: header, details, action tiles, media panes and editing. Sources: `_parity_audit/profile_user.md`, `profile_group.md`, `profile_media.md`, `profile_edit.md` and `design.md`, checked against `src/` on 7 November 2026. Group-only rows live in `groups.md` and `channels.md`.

Counts: 45 done, 32 partial, 29 missing, 0 dev-only.

**What is built.** Profiles came together across M12: header and details, verified and
emoji-status marks, action tiles, block/report/share, edit fields and birthday
privacy, and the media panes with stories, archive, media, music, voice, links
and groups. M11 added the stories tab and archive, and M13 the call tile and
its permission gate.

The missing surfaces are M28 (cover, QR, Premium star, rating, verifier note)
and M29 (GIF and Polls panes, photo/video split, month sections, calendar,
multi-select, pane search). Most remaining rows are layout differences, not
missing data.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Profile header | Official: Profile header | done | `Controllers/TGProfileViewController.m:380` | Name, marks and status line draw from the full-info answer. |
| Tapping the avatar | Official: Tapping the avatar | partial | `Controllers/TGProfileViewController+Actions.m:37` | Opens a separate photo table; no in-place carousel or story indicator. |
| Verified mark | Official: Verified mark | done | `Controllers/TGProfileViewController.m:431` | Badge beside the name from `is_verified`. |
| Emoji status | Official: Emoji status | done | `Controllers/TGProfileViewController.m:433` | Custom emoji picture beside the name. |
| Scam / fake warning | Official: Scam / fake warning | done | `Controllers/TGProfileViewController.m:877` | Replaces the bio with a warning row. |
| Phone and username rows | Official: Phone and username rows | done | `Controllers/TGProfileViewController.m:839` | Mobile and @username, copy on hold. |
| Multiple usernames | Official: Multiple usernames | done | `Controllers/TGProfileViewController.m:853` | Every active username gets a row. |
| Bio row | Official: Bio row | done | `Controllers/TGProfileViewController.m:853` | Wrapped block with link entities; tapping opens the first link. |
| Birthday row | Official: Birthday row | partial | `Controllers/TGProfileViewController.m:853` | Date, year and today state draw; no gift action. |
| Business location row | Official: Business location row | partial | `Controllers/TGProfileViewController.m:887` | Address only; hours, state and map thumbnail are absent. |
| Personal note | Official: Personal note | done | `Controllers/TGProfileViewController.m:890` | Note visible only to this account; entities are kept. |
| Add to Contacts row | Official: Add to Contacts row | done | `Controllers/TGProfileViewController.m:894` | Shown for a stranger who is not a bot. |
| Personal channel row | Official: Personal channel row | done | `Controllers/TGProfileViewController.m:941` | Opens the channel; until 7 November 2026 a `> 0` check on the (negative) channel id kept it from ever loading. |
| Common groups pane | Official: Common groups pane | partial | `Controllers/TGProfileViewController+Media.m:180` | Pane exists but `TGProfileTabKinds` is called with `hasCommonGroups = NO`, so the tab never appears; the More menu still lists titles. |
| Action tiles | Official: Action tiles | done | `Controllers/TGProfileViewController+Actions.m:107` | Tiles build per profile kind; own profile has Saved, Story, More. |
| Own profile hides Message/Call | Official: Own profile hides Message/Call | done | `Controllers/TGProfileViewController+Actions.m:107` | `own` branch builds Saved, Story and More only. |
| Video call tile | Official: Video call tile | partial | `Controllers/TGProfileViewController+Actions.m:123` | Gated by `canEncodeVideoCall`, which is false outside `TG_DEV`; see `calls.md`. |
| Call tile | Official: Call tile | done | `Controllers/TGProfileViewController+Actions.m:120` | `canCall` from `can_be_called` now gates the tile. |
| Mute tile | Official: Mute tile | partial | `Controllers/TGProfileViewController.m:342` | Tile toggles and redraws; `isChatMuted:` reads the chat cache, not global defaults or thread settings. |
| Share contact | Official: Share contact | done | `Controllers/TGProfileViewController+Actions.m:334` | Opens the share sheet. |
| Copy profile link | Official: Copy profile link | done | `Controllers/TGProfileViewController+Actions.m:338` | Own and other profiles. |
| Start secret chat | Official: Start secret chat | done | `Controllers/TGProfileViewController+Actions.m:349` | Confirms and creates the secret chat. |
| Personal note / suggest photo / suggest birthday | Official: Personal note / suggest photo / suggest birthday | done | `Controllers/TGProfileViewController+Actions.m:352` | Requests go through `setPersonalNote`, `suggestProfilePhoto`, `suggestBirthday`. |
| Personal photo | Official: Personal photo | done | `Controllers/TGProfileViewController+Actions.m:358` | Set, change and remove. |
| Share theme | Official: Share theme | done | `Controllers/TGProfileViewController+Actions.m:363` | Sends a theme link. |
| Block / unblock | Official: Block / unblock | done | `Controllers/TGProfileViewController+Actions.m:413` | Confirm sheet, then `setUser:blocked:`. |
| Report | Official: Report | done | `Controllers/TGProfileViewController+Actions.m:441` | Option list, one step at a time. |
| Delete contact | Official: Delete contact | done | `Controllers/TGProfileViewController+Actions.m:408` | Only when the person is a contact. |
| Clear history | Official: Clear history | done | `Controllers/TGProfileViewController+Actions.m:403` | Per-chat history clear. |
| Auto-delete messages | Official: Auto-delete messages | done | `Controllers/TGProfileViewController+Actions.m:533` | TTL applies to new messages. |
| Leave / delete group or channel | Official: Leave / delete group or channel | done | `Controllers/TGProfileViewController+Actions.m:418` | Owner sees Delete, everybody else Leave. |
| Own profile actions | Official: Own profile actions | done | `Controllers/TGProfileViewController+Actions.m:326` | Story Archive, Copy Profile Link, Add Local Note. |
| Own profile Edit | Official: Own profile Edit | done | `Controllers/TGProfileViewController.m:270` | Bar button opens Edit Profile. |
| My Profile preview | Official: My Profile preview | done | `Controllers/TGSettingsViewController+Actions.m:10` | `openMyProfile` is wired from Settings and the My Profile row. |
| Edit profile fields | Official: Edit profile fields | done | `Controllers/TGEditProfileViewController.m:79` | Photo, first/last name, bio with counter, birthday with year switch, username. |
| Bio character count and limit | Official: Bio character count and limit | done | `Controllers/TGEditProfileViewController.m:208` | Counter driven by `bio_length_max`. |
| Birthday privacy line | Official: Birthday privacy line | done | `Controllers/TGEditProfileViewController.m:480` | Row opens the three-choice privacy sheet. |
| Birthday without a year | Official: Birthday without a year | done | `Controllers/TGEditProfileViewController.m:415` | Year/No Year switch writes `year = 0`. |
| Save validation | Official: Save validation | done | `Controllers/TGEditProfileViewController.m:275` | First name required; requests are sequential and failures stay on screen. |
| Edit screen order and wording | Official: Edit screen order and wording | partial | `Controllers/TGEditProfileViewController.m:340` | Fields are grouped by Name/Bio/Account/Profile; no colour or personal-channel row. |
| Premium star badge | Official: Premium star badge | missing | `Controllers/TGProfileViewController.m:431` | Header draws verified and emoji status only; Premium is not read. |
| Profile cover / accent gradient | Official: Profile cover / accent gradient | missing | `Controllers/TGProfileViewController.m:380` | `profile_accent_color_id` is stored but never painted behind the header. |
| Profile colour screen | Official: Profile colour screen | partial | `Controllers/TGProfileAppearanceViewController.m:156` | Accent swatches exist; no two-tab preview, reset step or background emoji. |
| Profile rating | Official: Profile rating | missing | `Controllers/TGProfileViewController.m:839` | No `rating` / `pending_rating` row. |
| Third-party verification note | Official: Third-party verification note | missing | `Controllers/TGProfileViewController.m:431` | `bot_verification` is not parsed or drawn. |
| Unofficial app warning | Official: Unofficial app warning | missing | `Controllers/TGProfileViewController.m:839` | `uses_unofficial_app` is not read. |
| Collectible username info | Official: Collectible username info | missing | `Controllers/TGUsernameSettingsViewController.m:72` | Only active/disabled/editable names are read; no `collectible_usernames`. |
| Personal channel picker | Official: Personal channel picker | partial | `Controllers/TGProfileViewController.m:926` | Personal channel is displayed; Edit Profile has no picker. |
| Profile photo editor | Official: Profile photo editor | partial | `Controllers/TGEditProfileViewController.m:257` | Library still only, no crop, camera, video avatar or progress. |
| Own photo history | Official: Own photo history | partial | `Controllers/TGProfilePhotosViewController.m:139` | History screen exists for others; no entry from your own profile. |
| Emoji-status timer | Official: Emoji-status timer | missing | `Controllers/TGEmojiStatusViewController.m:421` | Always sends expiration 0 (Forever). |
| Header scale | Official: Header scale | partial | `Controllers/TGProfileViewController.m:147` | 80 pt avatar, 22 pt bold name, 14 pt status. |
| Action row shape | Official: Action row shape | partial | `Controllers/TGProfileViewController+Actions.m:96` | Up to six equal plates with a 22 pt glyph over an 11 pt word. |
| Info card typography | Official: Info card typography | partial | `Controllers/TGProfileViewController.m:565` | Custom detail cell; label and value sizes still smaller than official. |
| Tabs | Official: Tabs | partial | `Controllers/TGProfileViewController+Media.m:169` | Scrollable tabs exist with Music and Groups; no GIFs or Polls, and the order differs. |
| Main profile tab honoured | Official: Main profile tab honoured | done | `Core/TGProfileTabs.m:6` | `main_profile_tab` moves the chosen pane first; unmapped kinds fall back. |
| Empty panes hidden | Official: Empty panes hidden | done | `Core/TGProfileTabs.m:6` | A tab is added only when its category has content (own profile uses Stories/Archive). |
| Panes load on open | Official: Panes load on open | done | `Controllers/TGProfileViewController+Media.m:188` | Each tab fetches when selected; `thumbnailsRequested` is cleared per switch. |
| Tab counts | Official: Tab counts | done | `Controllers/TGProfileViewController.m:1037` | `mediaCounts` prints a count after each tab title. |
| GIF pane | Official: GIF pane | missing | `Core/TGProfileTabs.m:6` | No animation filter pane. |
| Polls pane | Official: Polls pane | missing | `Core/TGProfileTabs.m:6` | No poll filter or tab. |
| Photo grid | Official: Photo grid | done | `Controllers/TGProfileViewController+Media.m:282` | Wrapping grid, tap opens the viewer. |
| Photo / video split | Official: Photo / video split | missing | `Controllers/TGProfileViewController+Media.m:35` | One combined photo-and-video grid. |
| Month sections and calendar | Official: Month sections and calendar | missing | `Controllers/TGProfileViewController+Media.m:282` | One flat grid; no date landmark or calendar. |
| Video tile marks | Official: Video tile marks | partial | `Controllers/TGProfileViewController+Media.m:240` | A static 16 pt video glyph only. |
| Multi-select in media | Official: Multi-select in media | missing | `Controllers/TGProfileViewController.m:814` | No selection in the profile media panes. |
| Pane search | Official: Pane search | missing | `Controllers/TGProfileViewController.m:730` | The search tile leaves the profile for whole-chat search. |
| Files rows | Official: Files rows | partial | `Controllers/TGProfileViewController.m:725` | Icon and name only; rows do nothing on tap. |
| Voice rows | Official: Voice rows | partial | `Controllers/TGProfileViewController.m:729` | Every row says "Voice message"; tap does nothing. |
| Links rows | Official: Links rows | partial | `Controllers/TGProfileViewController.m:733` | Raw message text and a date; tap does nothing. |
| Stories grid | Official: Stories grid | done | `Controllers/TGProfileViewController+Media.m:271` | Tiles with poster face and video mark; tap opens the viewer. |
| Own-profile Stories tab | Official: Own-profile Stories tab | done | `Core/TGProfileTabs.m:6` | Own public profile always gets Stories; Add a story is the empty action. |
| Story Archive tab | Official: Story Archive tab | done | `Core/TGProfileTabs.m:6` | Own profile appends the archive tab. |
| Story ring around the avatar | Official: Story ring around the avatar | missing | `Controllers/TGProfileViewController.m:380` | Plain avatar; no ring. |
| Story albums on the profile | Official: Story albums on the profile | partial | `Controllers/TGStoryAlbumsViewController.m:531` | Albums exist but only from the Stories menu, not as profile shelves. |
| Music strip | Official: Music strip | done | `Controllers/TGProfileViewController.m:312` | First profile-audio track starts playback. |
| Profile audio player | Official: Profile audio player | done | `Controllers/TGProfileViewController.m:1655` | Play/pause from the strip; opens the full audio list. |
| Music tab | Official: Music tab | done | `Controllers/TGProfileViewController+Media.m:578` | Music pane pages `searchChatMessages` with the audio filter. |
| Audio tab rows | Official: Audio tab rows | partial | `Controllers/TGProfileViewController+Media.m:503` | Rows reuse the chat track cell; current-track row is not marked. |
| Add / remove from profile | Official: Add / remove from profile | partial | `Controllers/TGProfileAudioViewController.m:267` | Add from the last 100 Saved Messages; remove and two fixed moves; no drag reorder. |
| Profile audio paging | Official: Profile audio paging | partial | `Controllers/TGProfileAudioViewController.m:62` | One page of 100; `total` is shown but no load-more. |
| Gifts pane | Official: Gifts pane | partial | `Controllers/TGProfileViewController+Media.m:298` | Emoji glyph plus stars, first page only; no sticker artwork or model. |
| Common groups as rows | Official: Common groups as rows | partial | `Controllers/TGProfileViewController+Media.m:147` | Request and rows exist, but the tab is currently not offered (see above). |
| Similar channels / bots | Official: Similar channels / bots | partial | `Controllers/TGChatToolsViewController.m:322` | Similar chats row for channels; no Similar Bots on a profile. |
| Bot info card | Official: Bot info card | partial | `Core/TGClient+Account.m:565` | Bot short description can stand in for a missing bio; no commands or Add to Chat. |
| Premium row | Official: Premium row | partial | `Controllers/TGSettingsViewController+Actions.m:122` | Row opens an alert that reads Premium state; no plan list or purchase. |
| Settings profile area | Official: Settings profile area | done | `Controllers/TGSettingsViewController+Pages.m:121` | Header, My Profile and Edit are separated; the header still opens Edit. |
| Settings account header | Official: Settings account header | partial | `Controllers/TGSettingsViewController.m:990` | 80 pt avatar in a 168 pt grouped cell, 22 pt name, phone only. |
| Settings QR and Edit bar | Official: Settings QR and Edit bar | missing | `Controllers/TGSettingsViewController.m:61` | No root bar items. |
| Account rows inline | Official: Account rows inline | partial | `Controllers/TGSettingsViewController+Actions.m:37` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Four account slots | Official: Four account slots | partial | `Core/TGClient+Accounts.m:16` | Three slots for every account. |
| Profile header name wraps | Official: Profile header name wraps | missing | `Controllers/TGProfileViewController.m:180` | Single-line name in a fixed-height header. |
| Opening hours row | Official: Opening hours row | missing | — | `business_info.opening_hours` is not read for another user. |
| Edit in place | Official: Edit in place | missing | — | Editing remains a separate grouped form, not the profile header. |
| Bio privacy line | Official: Bio privacy line | missing | — | No Bio row in Privacy and no line under the field. |
| QR code of the username | Official: QR code of the username | missing | — | The only QR screen is a camera scanner for login. |
| Background emoji on the cover | Official: Background emoji on the cover | missing | — | No UI; both accent setters send zero for the background emoji. |
| Gift-derived name colour | Official: Gift-derived name colour | missing | — | Gift colours are not parsed or applied. |
| Public / fallback photo | Official: Public / fallback photo | missing | — | No setter UI and `setProfilePhoto` has no `is_public` call path from the editor. |
| Gift collections | Official: Gift collections | missing | — | TDLib collection calls are never sent. |
| Stars and gifts rows | Official: Stars and gifts rows | missing | — | No Stars row on the profile or Settings; the read-only console is `TG_DEV`. |
| Business hours and map | Official: Business hours and map | missing | — | Only the address is flattened; no hours or map thumbnail. |
| Phone formatting | Official: Phone formatting | partial | `Controllers/TGProfileViewController.m:839` | Raw plus and digits; no Anonymous Number wording or call/copy choices on tap. |
| Username availability while typing | Official: Username availability while typing | missing | — | This TDLib has no account-username availability check; only `setUsername` exists. |
| Tabs stay under the bar | Official: Tabs stay under the bar | missing | `Controllers/TGProfileViewController.m:1030` | The tab strip is a section header and scrolls away with the grid. |
| Tab bar stays stable while loading | Official: Tab bar stays stable while loading | missing | — | Each completion appends a tab and reloads the table. |
