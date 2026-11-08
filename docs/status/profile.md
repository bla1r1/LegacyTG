User, group and channel profiles: header, details, action tiles, media panes and editing. Sources: `_parity_audit/profile_user.md`, `profile_group.md`, `profile_media.md`, `profile_edit.md` and `design.md`, checked against `src/` on 7 November 2026. Group-only rows live in `groups.md` and `channels.md`.

Counts: 45 done, 32 partial, 29 missing, 0 dev-only.

Built: M12 (header and details, verified/emoji-status marks, action tiles,
block/report/share, edit fields, birthday privacy, media panes), M11 (stories
and archive tabs), M13 (call tile and permission gate). Open: M28 (cover, QR,
Premium star, rating, verifier note) and M29 (GIF/Polls panes, photo/video
split, month sections, calendar, multi-select, pane search). Most remaining
rows are layout, not missing data.

| Feature | State | Where | Note |
|---|---|---|---|
| Profile header | done | `src/Features/Profile/Core/TGProfileLifecycle.m:380` | Name, marks and status line draw from the full-info answer. |
| Tapping the avatar | partial | `Features/Profile/TGProfileViewController+Actions.m:37` | Opens a separate photo table; no in-place carousel or story indicator. |
| Verified mark | done | `src/Features/Profile/Core/TGProfileHeader.m:254` | Badge beside the name from `is_verified`. |
| Emoji status | done | `src/Features/Profile/Core/TGProfileHeader.m:256` | Custom emoji picture beside the name. |
| Scam / fake warning | done | `src/Features/Profile/Core/TGProfileData.m:475` | Replaces the bio with a warning row. |
| Phone and username rows | done | `src/Features/Profile/Core/TGProfileData.m:437` | Mobile and @username, copy on hold. |
| Multiple usernames | done | `src/Features/Profile/Core/TGProfileData.m:451` | Every active username gets a row. |
| Bio row | done | `src/Features/Profile/Core/TGProfileData.m:451` | Wrapped block with link entities; tapping opens the first link. |
| Birthday row | partial | `src/Features/Profile/Core/TGProfileData.m:451` | Date, year and today state draw; no gift action. |
| Business location row | partial | `src/Features/Profile/Core/TGProfileData.m:485` | Address only; hours, state and map thumbnail are absent. |
| Personal note | done | `src/Features/Profile/Core/TGProfileData.m:488` | Note visible only to this account; entities are kept. |
| Add to Contacts row | done | `src/Features/Profile/Core/TGProfileData.m:492` | Shown for a stranger who is not a bot. |
| Personal channel row | done | `src/Features/Profile/Core/TGProfileData.m:539` | Opens the channel; until 7 November 2026 a `> 0` check on the (negative) channel id kept it from ever loading. |
| Common groups pane | partial | `Features/Profile/TGProfileViewController+Media.m:180` | Pane exists but `TGProfileTabKinds` is called with `hasCommonGroups = NO`, so the tab never appears; the More menu still lists titles. |
| Action tiles | done | `Features/Profile/TGProfileViewController+Actions.m:107` | Tiles build per profile kind; own profile has Saved, Story, More. |
| Own profile hides Message/Call | done | `Features/Profile/TGProfileViewController+Actions.m:107` | `own` branch builds Saved, Story and More only. |
| Video call tile | partial | `Features/Profile/TGProfileViewController+Actions.m:123` | Gated by `canEncodeVideoCall`, which is false outside `TG_DEV`; see `calls.md`. |
| Call tile | done | `Features/Profile/TGProfileViewController+Actions.m:120` | `canCall` from `can_be_called` now gates the tile. |
| Mute tile | partial | `src/Features/Profile/Core/TGProfileLifecycle.m:342` | Tile toggles and redraws; `isChatMuted:` reads the chat cache, not global defaults or thread settings. |
| Share contact | done | `Features/Profile/TGProfileViewController+Actions.m:334` | Opens the share sheet. |
| Copy profile link | done | `Features/Profile/TGProfileViewController+Actions.m:338` | Own and other profiles. |
| Start secret chat | done | `Features/Profile/TGProfileViewController+Actions.m:349` | Confirms and creates the secret chat. |
| Personal note / suggest photo / suggest birthday | done | `Features/Profile/TGProfileViewController+Actions.m:352` | Requests go through `setPersonalNote`, `suggestProfilePhoto`, `suggestBirthday`. |
| Personal photo | done | `Features/Profile/TGProfileViewController+Actions.m:358` | Set, change and remove. |
| Share theme | done | `Features/Profile/TGProfileViewController+Actions.m:363` | Sends a theme link. |
| Block / unblock | done | `Features/Profile/TGProfileViewController+Actions.m:413` | Confirm sheet, then `setUser:blocked:`. |
| Report | done | `Features/Profile/TGProfileViewController+Actions.m:441` | Option list, one step at a time. |
| Delete contact | done | `Features/Profile/TGProfileViewController+Actions.m:408` | Only when the person is a contact. |
| Clear history | done | `Features/Profile/TGProfileViewController+Actions.m:403` | Per-chat history clear. |
| Auto-delete messages | done | `Features/Profile/TGProfileViewController+Actions.m:533` | TTL applies to new messages. |
| Leave / delete group or channel | done | `Features/Profile/TGProfileViewController+Actions.m:418` | Owner sees Delete, everybody else Leave. |
| Own profile actions | done | `Features/Profile/TGProfileViewController+Actions.m:326` | Story Archive, Copy Profile Link, Add Local Note. |
| Own profile Edit | done | `src/Features/Profile/Core/TGProfileLifecycle.m:270` | Bar button opens Edit Profile. |
| My Profile preview | done | `Features/Settings/TGSettingsViewController+Actions.m:10` | `openMyProfile` is wired from Settings and the My Profile row. |
| Edit profile fields | done | `Features/Profile/TGEditProfileViewController.m:79` | Photo, first/last name, bio with counter, birthday with year switch, username. |
| Bio character count and limit | done | `Features/Profile/TGEditProfileViewController.m:208` | Counter driven by `bio_length_max`. |
| Birthday privacy line | done | `Features/Profile/TGEditProfileViewController.m:480` | Row opens the three-choice privacy sheet. |
| Birthday without a year | done | `Features/Profile/TGEditProfileViewController.m:415` | Year/No Year switch writes `year = 0`. |
| Save validation | done | `Features/Profile/TGEditProfileViewController.m:275` | First name required; requests are sequential and failures stay on screen. |
| Edit screen order and wording | partial | `Features/Profile/TGEditProfileViewController.m:340` | Fields are grouped by Name/Bio/Account/Profile; no colour or personal-channel row. |
| Premium star badge | missing | `src/Features/Profile/Core/TGProfileHeader.m:254` | Header draws verified and emoji status only; Premium is not read. |
| Profile cover / accent gradient | missing | `src/Features/Profile/Core/TGProfileLifecycle.m:380` | `profile_accent_color_id` is stored but never painted behind the header. |
| Profile colour screen | partial | `Features/Profile/TGProfileAppearanceViewController.m:156` | Accent swatches exist; no two-tab preview, reset step or background emoji. |
| Profile rating | missing | `src/Features/Profile/Core/TGProfileData.m:437` | No `rating` / `pending_rating` row. |
| Third-party verification note | missing | `src/Features/Profile/Core/TGProfileHeader.m:254` | `bot_verification` is not parsed or drawn. |
| Unofficial app warning | missing | `src/Features/Profile/Core/TGProfileData.m:437` | `uses_unofficial_app` is not read. |
| Collectible username info | missing | `Features/Settings/TGUsernameSettingsViewController.m:72` | Only active/disabled/editable names are read; no `collectible_usernames`. |
| Personal channel picker | partial | `src/Features/Profile/Core/TGProfileData.m:524` | Personal channel is displayed; Edit Profile has no picker. |
| Profile photo editor | partial | `Features/Profile/TGEditProfileViewController.m:257` | Library still only, no crop, camera, video avatar or progress. |
| Own photo history | partial | `Features/Profile/TGProfilePhotosViewController.m:139` | History screen exists for others; no entry from your own profile. |
| Emoji-status timer | missing | `Features/Profile/TGEmojiStatusViewController.m:421` | Always sends expiration 0 (Forever). |
| Header scale | partial | `Features/Profile/TGProfileViewController.m:147` | 80 pt avatar, 22 pt bold name, 14 pt status. |
| Action row shape | partial | `Features/Profile/TGProfileViewController+Actions.m:96` | Up to six equal plates with a 22 pt glyph over an 11 pt word. |
| Info card typography | partial | `src/Features/Profile/Core/TGProfileHeader.m:388` | Custom detail cell; label and value sizes still smaller than official. |
| Tabs | partial | `Features/Profile/TGProfileViewController+Media.m:169` | Scrollable tabs exist with Music and Groups; no GIFs or Polls, and the order differs. |
| Main profile tab honoured | done | `Core/Model/TGProfileTabs.m:6` | `main_profile_tab` moves the chosen pane first; unmapped kinds fall back. |
| Empty panes hidden | done | `Core/Model/TGProfileTabs.m:6` | A tab is added only when its category has content (own profile uses Stories/Archive). |
| Panes load on open | done | `Features/Profile/TGProfileViewController+Media.m:188` | Each tab fetches when selected; `thumbnailsRequested` is cleared per switch. |
| Tab counts | done | `src/Features/Profile/Core/TGProfileDetails.m:292` | `mediaCounts` prints a count after each tab title. |
| GIF pane | missing | `Core/Model/TGProfileTabs.m:6` | No animation filter pane. |
| Polls pane | missing | `Core/Model/TGProfileTabs.m:6` | No poll filter or tab. |
| Photo grid | done | `Features/Profile/TGProfileViewController+Media.m:282` | Wrapping grid, tap opens the viewer. |
| Photo / video split | missing | `Features/Profile/TGProfileViewController+Media.m:35` | One combined photo-and-video grid. |
| Month sections and calendar | missing | `Features/Profile/TGProfileViewController+Media.m:282` | One flat grid; no date landmark or calendar. |
| Video tile marks | partial | `Features/Profile/TGProfileViewController+Media.m:240` | A static 16 pt video glyph only. |
| Multi-select in media | missing | `src/Features/Profile/Core/TGProfileData.m:412` | No selection in the profile media panes. |
| Pane search | missing | `src/Features/Profile/Core/TGProfileData.m:328` | The search tile leaves the profile for whole-chat search. |
| Files rows | partial | `src/Features/Profile/Core/TGProfileData.m:323` | Icon and name only; rows do nothing on tap. |
| Voice rows | partial | `src/Features/Profile/Core/TGProfileData.m:327` | Every row says "Voice message"; tap does nothing. |
| Links rows | partial | `src/Features/Profile/Core/TGProfileData.m:331` | Raw message text and a date; tap does nothing. |
| Stories grid | done | `Features/Profile/TGProfileViewController+Media.m:271` | Tiles with poster face and video mark; tap opens the viewer. |
| Own-profile Stories tab | done | `Core/Model/TGProfileTabs.m:6` | Own public profile always gets Stories; Add a story is the empty action. |
| Story Archive tab | done | `Core/Model/TGProfileTabs.m:6` | Own profile appends the archive tab. |
| Story ring around the avatar | missing | `src/Features/Profile/Core/TGProfileLifecycle.m:380` | Plain avatar; no ring. |
| Story albums on the profile | partial | `Features/Stories/TGStoryAlbumsViewController.m:531` | Albums exist but only from the Stories menu, not as profile shelves. |
| Music strip | done | `src/Features/Profile/Core/TGProfileLifecycle.m:312` | First profile-audio track starts playback. |
| Profile audio player | done | `src/Features/Profile/Core/TGProfileTable.m:414` | Play/pause from the strip; opens the full audio list. |
| Music tab | done | `Features/Profile/TGProfileViewController+Media.m:578` | Music pane pages `searchChatMessages` with the audio filter. |
| Audio tab rows | partial | `Features/Profile/TGProfileViewController+Media.m:503` | Rows reuse the chat track cell; current-track row is not marked. |
| Add / remove from profile | partial | `Features/Profile/TGProfileAudioViewController.m:267` | Add from the last 100 Saved Messages; remove and two fixed moves; no drag reorder. |
| Profile audio paging | partial | `Features/Profile/TGProfileAudioViewController.m:62` | One page of 100; `total` is shown but no load-more. |
| Gifts pane | partial | `Features/Profile/TGProfileViewController+Media.m:298` | Emoji glyph plus stars, first page only; no sticker artwork or model. |
| Common groups as rows | partial | `Features/Profile/TGProfileViewController+Media.m:147` | Request and rows exist, but the tab is currently not offered (see above). |
| Similar channels / bots | partial | `Features/Chat/TGChatToolsViewController.m:322` | Similar chats row for channels; no Similar Bots on a profile. |
| Bot info card | partial | `src/Core/Client/Account/TGClient+AccountLocalNotifications.m:50` | Bot short description can stand in for a missing bio; no commands or Add to Chat. |
| Premium row | partial | `Features/Settings/TGSettingsViewController+Actions.m:122` | Row opens an alert that reads Premium state; no plan list or purchase. |
| Settings profile area | done | `src/Features/Settings/Pages/TGSettingsPagesCore.m:121` | Header, My Profile and Edit are separated; the header still opens Edit. |
| Settings account header | partial | `Features/Settings/TGSettingsViewController.m:990` | 80 pt avatar in a 168 pt grouped cell, 22 pt name, phone only. |
| Settings QR and Edit bar | missing | `Features/Settings/TGSettingsViewController.m:61` | No root bar items. |
| Account rows inline | partial | `Features/Settings/TGSettingsViewController+Actions.m:37` | Action sheet of names with a check; no avatars, badges or per-account logout. |
| Four account slots | partial | `Core/Client/TGClient+Accounts.m:16` | Three slots for every account. |
| Profile header name wraps | missing | `Features/Profile/TGProfileViewController.m:180` | Single-line name in a fixed-height header. |
| Opening hours row | missing | — | `business_info.opening_hours` is not read for another user. |
| Edit in place | missing | — | Editing remains a separate grouped form, not the profile header. |
| Bio privacy line | missing | — | No Bio row in Privacy and no line under the field. |
| QR code of the username | missing | — | The only QR screen is a camera scanner for login. |
| Background emoji on the cover | missing | — | No UI; both accent setters send zero for the background emoji. |
| Gift-derived name colour | missing | — | Gift colours are not parsed or applied. |
| Public / fallback photo | missing | — | No setter UI and `setProfilePhoto` has no `is_public` call path from the editor. |
| Gift collections | missing | — | TDLib collection calls are never sent. |
| Stars and gifts rows | missing | — | No Stars row on the profile or Settings; the read-only console is `TG_DEV`. |
| Business hours and map | missing | — | Only the address is flattened; no hours or map thumbnail. |
| Phone formatting | partial | `src/Features/Profile/Core/TGProfileData.m:437` | Raw plus and digits; no Anonymous Number wording or call/copy choices on tap. |
| Username availability while typing | missing | — | This TDLib has no account-username availability check; only `setUsername` exists. |
| Tabs stay under the bar | missing | `src/Features/Profile/Core/TGProfileDetails.m:285` | The tab strip is a section header and scrolls away with the grid. |
| Tab bar stays stable while loading | missing | — | Each completion appends a tab and reloads the table. |
