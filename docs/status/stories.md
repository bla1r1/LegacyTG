Stories: the strip, the viewer, posting, albums, interactions and live stories. Parity rows come from `_parity_audit/s_rest.md`, `profile_media.md` and `changelog.md`; checked against `src/` on 7 November 2026.

Counts: 21 done, 5 partial, 8 missing, 1 dev-only.

| Feature | Official | Here | Where | Note |
|---|---|---|---|---|
| Stories strip on the chat list | Official: Stories strip on the chat list | done | `Controllers/TGChatListViewController.m:1785` | Horizontal story rings above the first chat. |
| Story ring on every chat row avatar | Official: Story ring on every chat row avatar | missing | `Views/TGChatCell.m:56` | Rows draw a plain avatar; only the strip bubble has a ring. |
| My Story first tile | Official: My Story first tile | partial | `Controllers/TGChatListViewController.m:1619` | The plus always draws; no ring around the own tile. |
| Story tile hold menu | Official: Story tile hold menu | done | `Controllers/TGChatListViewController.m:1589` | Hide from row / move to main. |
| Collapsed story beside the title | Official: Collapsed story beside the title | done | `Controllers/TGChatListViewController.m:467` | First active story appears once the strip scrolls off. |
| Story viewer | Official: Story viewer | done | `Controllers/TGStoryViewerViewController.m:1` | Viewer sends `openStory` / `closeStory` and scores progress per story. |
| Pause on hold | Official: Pause on hold | done | `Controllers/TGStoryViewerViewController.m:527` | Hold pauses, release resumes. |
| Story reactions | Official: Story reactions | done | `Controllers/TGStoryViewerViewController.m:587` | Rail from `getStoryAvailableReactions`; `setStoryReaction` sends or clears. |
| Story info | Official: Story info | done | `Controllers/TGStoryInfoViewController.m:1` | Reads `getStoryInteractions`, `getStoryPublicForwards` and `getStoryStatistics`. |
| Report a story | Official: Report a story | done | `Core/TGClient+Stories.m:1437` | Two-step `reportStory`. |
| Edit a story | Official: Edit a story | done | `Core/TGClient+Stories.m:934` | `editStory`, `editStoryCover`, `setStoryPrivacySettings`, `toggleStoryIsPostedToChatPage`. |
| Delete a story | Official: Delete a story | done | `Core/TGClient+Stories.m:988` | `deleteStory`. |
| Pin a story to the chat page | Official: Pin a story to the chat page | done | `Core/TGClient+Stories.m:654` | `setChatPinnedStories`. |
| Post a photo story | Official: Post a photo story | done | `Controllers/TGStoryComposerViewController.m:453` | Photo, caption, privacy, period, albums and the two flags; `postStory`. |
| Post a video story | Official: Post a video story | partial | `Controllers/TGStoryComposerViewController.m:415` | Imported video posts with its duration; the camera captures stills only. |
| Story camera video | Official: Story camera video | missing | `Controllers/TGStoryCameraViewController.m:279` | `AVCaptureStillImageOutput` only; no movie file output. |
| Story period | Official: Story period | done | `Controllers/TGStoryComposerViewController.m:344` | Period picker; paid periods explain the Premium lock. |
| Story privacy | Official: Story privacy | done | `Controllers/TGStoryComposerViewController.m:309` | Four privacy choices and a selected-user list. |
| Story albums | Official: Story albums | done | `Controllers/TGStoryAlbumsViewController.m:531` | `getChatStoryAlbums`, `getStoryAlbumStories`, create/rename/delete/reorder. |
| Album story order | Official: Album story order | done | `Controllers/TGStoryAlbumsViewController.m:531` | `reorderStoryAlbumStories` and add/remove story calls. |
| Archive | Official: Archive | done | `Controllers/TGStoryArchiveViewController.m:1` | `getChatArchivedStories` fills the archive. |
| Story Archive and albums on the profile | Official: Story Archive and albums on the profile | partial | `Core/TGProfileTabs.m:6` | Archive is a tab on the own profile; albums are only in the Stories menu. |
| Own-profile Stories tab | Official: Own-profile Stories tab | done | `Core/TGProfileTabs.m:6` | Own public profile always gets Stories; the empty action posts one. |
| Story ring around the profile avatar | Official: Story ring around the profile avatar | missing | `Controllers/TGProfileViewController.m:380` | Plain avatar; no ring. |
| Story notifications | Official: Story notifications | done | `Controllers/TGStorySettingsViewController.m:30` | `getStoryNotificationSettingsExceptions` and the per-chat switch. |
| Stealth mode | Official: Stealth mode | done | `Core/TGClient+Stories.m:1625` | `activateStoryStealthMode`; the server's answer is shown. |
| Public stories search | Official: Public stories search | done | `Core/TGClient+Stories.m:1541` | `searchPublicStoriesByTag`, `ByLocation`, `ByVenue` open in the same viewer. |
| Reply to a story with a message | Official: Reply to a story with a message | missing | `Controllers/TGStoryViewerViewController.m:56` | Viewer has reactions only; no `inputMessageReplyToStory`. |
| Share or repost a story | Official: Share or repost a story | missing | `Controllers/TGStoryViewerViewController.m:888` | Menu offers info, report and owner edits only; no share action. |
| Story in a message bubble | Official: Story in a message bubble | partial | `Core/TGMessageFlatten.m:700` | Card says "Story by …" and Open plays it; the story's own picture is not in the card. |
| Live story screen | Official: Live story screen | partial | `Controllers/TGLiveStoryViewController.m:1` | Metadata, RTMP key, join and donor lists are real; no video player or decoder. |
| Live story playback | Official: Live story playback | missing | `Controllers/TGLiveStoryViewController.m:1` | Joining copies the tgcalls payload; no RTMP/AVPlayer pipeline. |
| Live story host | Official: Live story host | missing | `Controllers/TGLiveStoryViewController.m:1` | `startLiveStory` is called, but this client has no camera encoder. |
| Story comments and paid pins | Official: Story comments and paid pins | missing | `Controllers/TGLiveStoryViewController.m:1` | Only donor and reaction records are listed. |
| Business stories | Official: Business stories | dev-only | `Controllers/TGStoryViewerViewController.m:905` | Rows exist and show Telegram's refusal; no business connection is modelled. |
