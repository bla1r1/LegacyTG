Stories: the strip, the viewer, posting, albums, interactions and live stories. Parity rows come from `_parity_audit/s_rest.md`, `profile_media.md` and `changelog.md`; checked against `src/` on 7 November 2026.

Counts: 21 done, 5 partial, 8 missing, 1 dev-only.

Built: M11 (48 story functions: strip, viewer with pause/reactions, info and
statistics, posting with period/privacy, albums, archive, notifications,
stealth mode, public search), M12 (Stories and Archive tabs). Open: M25 (ring
on every row and profile avatar), M39 (camera video, reply/share/repost, live
playback and hosting, comments). Business stories stay behind `TG_DEV`.

| Feature | State | Where | Note |
|---|---|---|---|
| Stories strip on the chat list | done | `src/Features/ChatList/Core/TGChatListTable.m:215` | Horizontal story rings above the first chat. |
| Story ring on every chat row avatar | missing | `Features/Chat/Views/TGChatCell.m:56` | Rows draw a plain avatar; only the strip bubble has a ring. |
| My Story first tile | partial | `src/Features/ChatList/Core/TGChatListReload.m:306` | The plus always draws; no ring around the own tile. |
| Story tile hold menu | done | `src/Features/ChatList/Core/TGChatListReload.m:276` | Hide from row / move to main. |
| Collapsed story beside the title | done | `src/Features/ChatList/Core/TGChatListLifecycle.m:393` | First active story appears once the strip scrolls off. |
| Story viewer | done | `Features/Stories/TGStoryViewerViewController.m:1` | Viewer sends `openStory` / `closeStory` and scores progress per story. |
| Pause on hold | done | `Features/Stories/TGStoryViewerViewController.m:527` | Hold pauses, release resumes. |
| Story reactions | done | `Features/Stories/TGStoryViewerViewController.m:587` | Rail from `getStoryAvailableReactions`; `setStoryReaction` sends or clears. |
| Story info | done | `Features/Stories/TGStoryInfoViewController.m:1` | Reads `getStoryInteractions`, `getStoryPublicForwards` and `getStoryStatistics`. |
| Report a story | done | `Core/Client/Stories/TGClient+StoriesInteractions.m:184` | Two-step `reportStory`. |
| Edit a story | done | `Core/Client/Stories/TGClient+StoriesPosting.m:145` | `editStory`, `editStoryCover`, `setStoryPrivacySettings`, `toggleStoryIsPostedToChatPage`. |
| Delete a story | done | `Core/Client/Stories/TGClient+StoriesPosting.m:199` | `deleteStory`. |
| Pin a story to the chat page | done | `Core/Client/Stories/TGClient+StoriesFeed.m:325` | `setChatPinnedStories`. |
| Post a photo story | done | `Features/Stories/TGStoryComposerViewController.m:453` | Photo, caption, privacy, period, albums and the two flags; `postStory`. |
| Post a video story | partial | `Features/Stories/TGStoryComposerViewController.m:415` | Imported video posts with its duration; the camera captures stills only. |
| Story camera video | missing | `Features/Stories/TGStoryCameraViewController.m:279` | `AVCaptureStillImageOutput` only; no movie file output. |
| Story period | done | `Features/Stories/TGStoryComposerViewController.m:344` | Period picker; paid periods explain the Premium lock. |
| Story privacy | done | `Features/Stories/TGStoryComposerViewController.m:309` | Four privacy choices and a selected-user list. |
| Story albums | done | `Features/Stories/TGStoryAlbumsViewController.m:531` | `getChatStoryAlbums`, `getStoryAlbumStories`, create/rename/delete/reorder. |
| Album story order | done | `Features/Stories/TGStoryAlbumsViewController.m:531` | `reorderStoryAlbumStories` and add/remove story calls. |
| Archive | done | `Features/Stories/TGStoryArchiveViewController.m:1` | `getChatArchivedStories` fills the archive. |
| Story Archive and albums on the profile | partial | `Core/Model/TGProfileTabs.m:6` | Archive is a tab on the own profile; albums are only in the Stories menu. |
| Own-profile Stories tab | done | `Core/Model/TGProfileTabs.m:6` | Own public profile always gets Stories; the empty action posts one. |
| Story ring around the profile avatar | missing | `src/Features/Profile/Core/TGProfileLifecycle.m:380` | Plain avatar; no ring. |
| Story notifications | done | `Features/Stories/TGStorySettingsViewController.m:30` | `getStoryNotificationSettingsExceptions` and the per-chat switch. |
| Stealth mode | done | `Core/Client/Stories/TGClient+StoriesDiscovery.m:104` | `activateStoryStealthMode`; the server's answer is shown. |
| Public stories search | done | `Core/Client/Stories/TGClient+StoriesDiscovery.m:20` | `searchPublicStoriesByTag`, `ByLocation`, `ByVenue` open in the same viewer. |
| Reply to a story with a message | missing | `Features/Stories/TGStoryViewerViewController.m:56` | Viewer has reactions only; no `inputMessageReplyToStory`. |
| Share or repost a story | missing | `Features/Stories/TGStoryViewerViewController.m:888` | Menu offers info, report and owner edits only; no share action. |
| Story in a message bubble | partial | `Core/Model/TGMessageFlatten.m:700` | Card says "Story by …" and Open plays it; the story's own picture is not in the card. |
| Live story screen | partial | `Features/Stories/TGLiveStoryViewController.m:1` | Metadata, RTMP key, join and donor lists are real; no video player or decoder. |
| Live story playback | missing | `Features/Stories/TGLiveStoryViewController.m:1` | Joining copies the tgcalls payload; no RTMP/AVPlayer pipeline. |
| Live story host | missing | `Features/Stories/TGLiveStoryViewController.m:1` | `startLiveStory` is called, but this client has no camera encoder. |
| Story comments and paid pins | missing | `Features/Stories/TGLiveStoryViewController.m:1` | Only donor and reaction records are listed. |
| Business stories | dev-only | `Features/Stories/TGStoryViewerViewController.m:905` | Rows exist and show Telegram's refusal; no business connection is modelled. |
