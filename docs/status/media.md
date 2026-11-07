Media: the viewer, players, downloads, attachments and sticker handling. Parity rows come from `_parity_audit/s_rest.md`, `profile_media.md` and `changelog.md`; checked against `src/` on 7 November 2026. Chat bubbles are in `message-types.md`, profile panes in `profile.md`.

Counts: 19 done, 8 partial, 7 missing, 0 dev-only.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Photo viewer | Official: Photo viewer | done | `Views/TGMediaViewer.m:226` | Paging scroll view, double-tap zoom, one page built lazily per item. |
| Video playback | Official: Video playback | done | `Views/TGMediaViewer.m:1340` | `AVPlayer` with `TGSoftVideoPlayer` fallback on Vintage. |
| Video cover and scrub preview | Official: Video cover and scrub preview | partial | `Views/TGMediaViewer.m:630` | A working scrubber exists; no thumbnail preview while scrubbing. |
| GIF playback | Official: GIF playback | done | `Views/TGMediaViewer.m:129` | `messageAnimation` loops with one `AVPlayer`, gated by Power Saving. |
| Voice notes | Official: Voice notes | done | `Controllers/TGChatViewController+AudioCells.m:66` | Waveform, play/pause, speed and transcription text. |
| Music player | Official: Music player | done | `Audio/TGMusicPlayer.m:40` | Queue, next/previous, seek, repeat, shuffle, volume, lock-screen info. |
| Music streaming | Official: Music streaming | missing | `Audio/TGMusicPlayer.m:91` | The whole file is downloaded before playback; no `AudioFileStream` path. |
| Document preview | Official: Document preview | done | `Controllers/TGChatViewController.m:1960` | `UIDocumentInteractionController` opens the downloaded file. |
| Save to camera roll | Official: Save to camera roll | done | `Views/TGMediaViewer.m:1628` | Save appears only when `can_be_saved` allows it. |
| Protected content in the viewer | Official: Protected content in the viewer | done | `Views/TGMediaViewer.m:1628` | Menus check `can_be_saved`; one-time and protected media hide the actions. |
| Add to Downloads / delete local copy | Official: Add to Downloads / delete local copy | done | `Views/TGMediaViewer.m:1826` | Hold menu adds to Downloads, deletes the local file or shows its info. |
| Download progress | Official: Download progress | done | `Controllers/TGChatViewController+Media.m:386` | Progress plate with a percentage. |
| Cancel a download | Official: Cancel a download | done | `Controllers/TGChatViewController+Media.m:452` | Tap sends `cancelDownloadFile`; snackbar confirms. |
| Downloads manager | Official: Downloads manager | done | `Controllers/TGSettingsViewController+NetworkPages.m:635` | Per-file pause, resume, info, remove, clear all. |
| Photo attachments | Official: Photo attachments | done | `Controllers/TGChatViewController+Actions.m:1741` | Picker accepts images and movies; multi-select sends an album. |
| Document and audio attachments | Official: Document and audio attachments | missing | `Views/TGAttachSheet.h:8` | No document picker and no `inputMessageDocument` / `inputMessageAudio` request. |
| File information | Official: File information | done | `Controllers/TGFileInfoViewController.m:1` | `getFile`, `getRemoteFile`, downloaded-prefix size and name helpers. |
| Link preview picture | Official: Link preview picture | partial | `Controllers/TGChatViewController+Layout.m:678` | Site, title and description only; the preview picture is never fetched. |
| Forward with a new caption | Official: Forward with a new caption | missing | `Controllers/TGForwardPicker.m:154` | Picker sends `forwardMessages` directly; no `copy_options`. |
| Share into a forum topic | Official: Share into a forum topic | missing | `Controllers/TGForwardPicker.m:154` | Picker lists chats, not topics, and sends no `topic_id`. |
| Sticker pack preview | Official: Sticker pack preview | partial | `Controllers/TGStickerPacksViewController.m:495` | The trending sheet shows a count and Install only. |
| Sticker pack search by keyword | Official: Sticker pack search by keyword | partial | `Controllers/TGStickerPacksViewController.m:394` | Store search accepts a t.me short name only. |
| Sticker install and archive | Official: Sticker install and archive | done | `Controllers/TGStickerPacksViewController.m:21` | Owned, trending, custom emoji, recent, archived; create/edit/search/clear. |
| Sticker authoring | Official: Sticker authoring | done | `Controllers/TGStickerEditorViewController.m:30` | Rename, short name, type, add/remove/reorder stickers, delete pack. |
| Animated stickers | Official: Animated stickers | done | `Controllers/TGChatViewController+Cells.m` | `TGLottieView` for TGS and the WebM decoder for VP9 alpha. |
| Custom emoji images | Official: Custom emoji images | partial | `Views/TGMessageLayout.mm:512` | Static attachment on iOS 7+, fallback emoji on iOS 6; no animation. |
| Live and motion photos | Official: Live and motion photos | partial | `Core/TGMessageFlatten.m:226` | The photo branch reads the still sizes and ignores `content.video`. |
| GIF caption | Official: GIF caption | partial | `Core/TGMessageFlatten.m:530` | Incoming captions draw; `sendAnimation` has no caption. |
| Sticker/emoji custom tab | Official: Sticker/emoji custom tab | missing | `Views/TGEmojiPanel.m:243` | Tabs are Emoji, Stickers and GIFs only. |
| Album collage | Official: Album collage | done | `Controllers/TGChatViewController.m:537` | Albums collapse to one row with a 2×2 collage and `+N` for the rest. |
| Photo strip on a profile | Official: Photo strip on a profile | done | `Controllers/TGProfileViewController+Media.m:282` | Wrapping grid, tap opens the viewer. |
| Video tile marks | Official: Video tile marks | partial | `Controllers/TGProfileViewController+Media.m:240` | A static 16 pt video glyph only. |
| Calendar for media | Official: Calendar for media | missing | `Controllers/TGProfileViewController+Media.m:282` | One flat grid; no calendar. |
| Media multi-select | Official: Media multi-select | missing | `Controllers/TGProfileViewController.m:814` | No selection in the profile media panes. |
