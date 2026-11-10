Media: the viewer, players, downloads, attachments and sticker handling. Parity rows come from `_parity_audit/s_rest.md`, `profile_media.md` and `changelog.md`; checked against `src/` on 7 November 2026. Chat bubbles are in `message-types.md`, profile panes in `profile.md`.

Counts: 22 done, 7 partial, 5 missing, 0 dev-only.

Built: M5 (viewer, AVPlayer with Vintage software fallback, GIF, music queue,
document preview, camera roll, downloads), M6 (WebP, TGS, WebM VP9, packs,
archive, editor, favourites), M8 (voice notes, round video), M23
(document/audio attach, AudioFileStream streaming). Open: M38 (live photos,
scrub preview, Lottie detail).

| Feature | State | Where | Note |
|---|---|---|---|
| Photo viewer | done | `src/Features/Media/Core/TGMediaViewerTransitions.m:102` | Paging scroll view, double-tap zoom, one page built lazily per item. |
| Video playback | done | `src/Features/Media/Core/TGMediaViewerVideo.m:214` | `AVPlayer` with `TGSoftVideoPlayer` fallback on Vintage. |
| Video cover and scrub preview | partial | `src/Features/Media/Core/TGMediaViewerChrome.m:308` | A working scrubber exists; no thumbnail preview while scrubbing. |
| GIF playback | done | `src/Features/Media/Core/TGMediaViewerPresenting.m:84` | `messageAnimation` loops with one `AVPlayer`, gated by Power Saving. |
| Voice notes | done | `Features/Chat/Composer/TGChatViewController+AudioCells.m:66` | Waveform, play/pause, speed and transcription text. |
| Music player | done | `Audio/TGMusicPlayer.m:40` | Queue, next/previous, seek, repeat, shuffle, volume, lock-screen info. |
| Music streaming | done | `Audio/TGMusicStreamer.m` | `AudioFileStream` + `AudioQueue` play the growing local file while it downloads; m4a with a trailing header falls back to the finished file. |
| Document preview | done | `src/Features/Chat/Core/TGChatViewTaps.m:271` | `UIDocumentInteractionController` opens the downloaded file. |
| Save to camera roll | done | `src/Features/Media/Core/TGMediaViewerMoreSheet.m:167` | Save appears only when `can_be_saved` allows it. |
| Protected content in the viewer | done | `src/Features/Media/Core/TGMediaViewerMoreSheet.m:167` | Menus check `can_be_saved`; one-time and protected media hide the actions. |
| Add to Downloads / delete local copy | done | `src/Features/Media/Core/TGMediaViewerSaving.m:177` | Hold menu adds to Downloads, deletes the local file or shows its info. |
| Download progress | done | `Features/Chat/Composer/TGChatViewController+Media.m:386` | Progress plate with a percentage. |
| Cancel a download | done | `Features/Chat/Composer/TGChatViewController+Media.m:452` | Tap sends `cancelDownloadFile`; snackbar confirms. |
| Downloads manager | done | `Features/Settings/TGSettingsViewController+NetworkPages.m:635` | Per-file pause, resume, info, remove, clear all. |
| Photo attachments | done | `Features/Chat/Actions/TGChatViewController+Attachments.m:182` | Picker accepts images and movies; multi-select sends an album. |
| Document and audio attachments | done | `Features/Chat/Views/TGAttachSheet.h:8` | File and music are in the attach sheet and send as documents/audio through `TGSendStore`. |
| File information | done | `Features/Media/TGFileInfoViewController.m:1` | `getFile`, `getRemoteFile`, downloaded-prefix size and name helpers. |
| Link preview picture | partial | `Features/Chat/Rendering/TGChatViewController+Layout.m:678` | Site, title and description only; the preview picture is never fetched. |
| Forward with a new caption | missing | `Features/Chat/TGForwardPicker.m:154` | Picker sends `forwardMessages` directly; no `copy_options`. |
| Share into a forum topic | missing | `Features/Chat/TGForwardPicker.m:154` | Picker lists chats, not topics, and sends no `topic_id`. |
| Sticker pack preview | partial | `Features/Media/TGStickerPacksViewController.m:495` | The trending sheet shows a count and Install only. |
| Sticker pack search by keyword | partial | `Features/Media/TGStickerPacksViewController.m:394` | Store search accepts a t.me short name only. |
| Sticker install and archive | done | `Features/Media/TGStickerPacksViewController.m:21` | Owned, trending, custom emoji, recent, archived; create/edit/search/clear. |
| Sticker authoring | done | `Features/Media/TGStickerEditorViewController.m:30` | Rename, short name, type, add/remove/reorder stickers, delete pack. |
| Animated stickers | done | `Features/Chat/Rendering/TGChatViewController+Cells.m` | `TGLottieView` for TGS and the WebM decoder for VP9 alpha. |
| Custom emoji images | done | `Features/Chat/Views/TGMessageLayout.mm:512`, `Core/Stores/TGCustomEmojiStore.m` | Static on iOS 6 fallback / iOS 7+ picture; tgs and webm animate through the sticker pipeline under its budget. |
| Live and motion photos | partial | `Core/Model/TGMessageFlatten.m:226` | The photo branch reads the still sizes and ignores `content.video`. |
| GIF caption | done | `Core/Stores/TGSendStore.mm:141` | Outgoing animations carry the composer caption. |
| Sticker/emoji custom tab | missing | `src/Features/Chat/Views/EmojiPanel/TGEmojiPanelBase.m:244` | Tabs are Emoji, Stickers and GIFs only. |
| Album collage | done | `src/Features/Chat/Core/TGChatViewData.m:119` | Albums collapse to one row with a 2×2 collage and `+N` for the rest. |
| Photo strip on a profile | done | `Features/Profile/TGProfileViewController+Media.m:282` | Wrapping grid, tap opens the viewer. |
| Video tile marks | partial | `Features/Profile/TGProfileViewController+Media.m:240` | A static 16 pt video glyph only. |
| Calendar for media | missing | `Features/Profile/TGProfileViewController+Media.m:282` | One flat grid; no calendar. |
| Media multi-select | missing | `src/Features/Profile/Core/TGProfileData.m:412` | No selection in the profile media panes. |
