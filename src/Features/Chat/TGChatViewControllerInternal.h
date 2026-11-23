//
// TGChatViewControllerInternal.h - Private class extension for TGChatViewController categories
//
#ifndef TGCHATVIEWCONTROLLERINTERNAL_H
#define TGCHATVIEWCONTROLLERINTERNAL_H

#import "TGChatViewController.h"
#import "TGUI.h"
#import "TGMessageStore.h"
#import "TGVideoNoteViewController.h"
#import "TGRecordBar.h"
#import "TGSheet.h"
#import "TGTheme.h"
#import "TGMessageCard.h"
#import "TGComposerText.h"
#import "TGIcons.h"
#import "TGSnackbar.h"
#import "TGMessageLayout.h"
#import "TGBubbleCell.h"
#import "TGChatCell.h"
#import "TGMediaViewer.h"
#import "TGEmojiPanel.h"
#import "TGStreamingVoicePlayer.h"
#import "TGImageLruCache.h"
#import "TGCustomEmojiStore.h"
@class TGLottieView;
#import "TGSendStore.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "TGStyle.h"

#import "TGChatGeometry.h"
#import "TGChatParityModel.h"
#import "TGUIFormat.h"

static const NSInteger kChatMuteBarTag = 0x9020;
static const NSInteger kChatJoinGroupBarTag = 0x9021;
static const NSInteger kChatUnblockBarTag = 0x9025;
static const NSInteger kChatJoinChannelBarTag = 0x9022;
static const NSInteger kChatDiscussBarTag = 0x9023;
static const NSInteger kChatChannelBottomBarTag = 0x9024;

@class TGMessageStreamStore;

FOUNDATION_EXPORT TGMessageCard *TGChatCardForRow(NSDictionary *m);

/// The composer's text view. UITextView has no placeholder or enabled flag,
/// and the rest of the chat already speaks those two; the composer class
/// implements them without a second text model.
@interface UITextView (TGComposerInput)
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
/// The bot keyboard's toggle used to ride in a text field's rightView. The
/// composer keeps the same call site by drawing it inside the text view.
@property (nonatomic, strong) UIView *rightView;
@property (nonatomic, assign) UITextFieldViewMode rightViewMode;
@end

/// A TDLib minithumbnail (its base64 "data", or raw bytes) as a picture.
UIImage *TGImageFromMinithumbnail(id mini);

@interface TGChatViewController () <UISearchBarDelegate, CLLocationManagerDelegate, TGEmojiPanelDelegate,
		UIScrollViewDelegate, AVAudioPlayerDelegate, TGStreamingVoicePlayerDelegate,
		ABPeoplePickerNavigationControllerDelegate, UIDocumentInteractionControllerDelegate,
		UIDocumentPickerDelegate, MPMediaPickerControllerDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIDocumentInteractionController *docInteractionController;

@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) UITextView *input;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UIButton *aiButton;
@property (nonatomic, strong) UIImageView *composerWell;
@property (nonatomic, strong) UIButton *sendButton;
/// The input bar's current height: the old capsule plus whatever the field
/// has grown by. Keyboard and panel shifts read it instead of kInputHeight.
@property (nonatomic, assign) CGFloat composerBarHeight;
@property (nonatomic, strong) NSArray *messages;          // flattened TDLib dicts (may contain grouped album composites)
@property (nonatomic, strong) NSArray *rawMessages;       // raw flattened messages before grouping
@property (nonatomic, strong) TGImageLruCache *images;    // fileId -> UIImage (cap 40)
@property (nonatomic, strong) NSMutableSet *imagesRequested;
@property (nonatomic, strong) TGStreamingVoicePlayer *voicePlayer;
@property (nonatomic, assign) BOOL anchorToBottom;
@property (nonatomic, assign) BOOL isChannel;
@property (nonatomic, assign) BOOL isChannelMember;
/// The composer's placeholder follows what the next send would do. Silent
/// posting and anonymous admin posting are both allowed states; the field
/// says which one the message will use.
@property (nonatomic, assign) BOOL silentPosting;
@property (nonatomic, assign) BOOL canBeAnonymous;
@property (nonatomic, strong) NSMutableDictionary *lottiePaths;   // fileId -> path
/// Messages whose premium sticker effect already played in this visit.
@property (nonatomic, strong) NSMutableSet *playedStickerEffects;
/// Slot machines (message ids) that spun this chat visit; they rest on the result.
@property (nonatomic, strong) NSMutableSet *spunSlotMachines;
/// Animation files that have run their one loop since this chat was opened.
@property (nonatomic, strong) NSMutableSet *playedAnimations;
@property (nonatomic, strong) TGImageLruCache *maps;             // messageId -> UIImage (cap 20)
@property (nonatomic, strong) NSMutableSet *mapsRequested;
@property (nonatomic, strong) NSMutableDictionary *quotes;       // messageId -> flattened
@property (nonatomic, strong) NSMutableSet *quotesRequested;
@property (nonatomic, strong) NSDictionary *actionMessage;   // long-pressed
/// TDLib's messageProperties for actionMessage, fetched before its card opens.
@property (nonatomic, strong) NSDictionary *actionProperties;
@property (nonatomic, assign) int64_t actionPropertiesFor;
/// The held message's presentation: the dimmed chat behind it. Official keeps
/// the bubble in place; the cell never moves and the dim is the only view the
/// hold owns.
@property (nonatomic, strong) UIView *holdBackdropView;
/// The held bubble's picture over the blurred chat, and where it came from.
@property (nonatomic, strong) UIImageView *holdLiftView;
@property (nonatomic, assign) CGRect holdLiftOrigin;
/// Bumped for every hold and every dismissal; a late animation completion
/// that no longer matches this belongs to a hold that is gone.
@property (nonatomic, assign) NSInteger holdGeneration;
/// Whether the table was scrolling before the hold pinned it, so a dismiss
/// gives the chat back exactly as it was.
@property (nonatomic, assign) BOOL holdTableWasScrollable;
/// True while the dim is animating away. A second dismiss in that window is
/// the same dismissal, not a new one.
@property (nonatomic, assign) BOOL holdReturning;
@property (nonatomic, assign) int64_t replyToId;             // composing a reply
@property (nonatomic, assign) int64_t editingId;             // editing instead
@property (nonatomic, strong) UIView *composeBanner;         // "Reply to ..."
@property (nonatomic, strong) UIButton *micButton;
/// NO records a voice note, YES a round video note. A tap on the mic
/// switches the mode; a hold records the selected one.
@property (nonatomic, assign) BOOL videoNoteMode;
/// The wait before the touch turns into a recording, so a short tap can stay
/// a mode switch instead of beginning to write.
@property (nonatomic, strong) NSTimer *recordStartPendingTimer;
/// YES while the note being recorded was toggled view-once ("1"): one open
/// and it is gone, per Telegram's self destruct immediately.
@property (nonatomic, assign) BOOL recordOnce;
@property (nonatomic, strong) NSDate *recordBeganAt;
@property (nonatomic, assign) BOOL videoNoteOverlayActive;
@property (nonatomic, strong) TGVideoNoteViewController *videoNoteOverlay;
/// The local row a round note shows while it is still being transcoded, and
/// the pending message id TDLib gives it once sendMessage answers.
@property (nonatomic, assign) int64_t pendingNoteRowId;
@property (nonatomic, assign) int64_t pendingNoteRealId;
/// The same line the ring draws: transcode is the first half, upload the
/// second. Voice has no transcode, so its fraction is used as it is.
@property (nonatomic, assign) CGFloat pendingNoteProgress;
/// Set when the local row is cancelled while the transcode has already ended
/// and sendMessage is in flight; the answer is deleted instead of sent.
@property (nonatomic, assign) BOOL pendingNoteCancelled;
- (NSArray *)groupedMessagesFromMessages:(NSArray *)messages;
- (void)resumeGifAutoplayAfterScrolling;
- (void)refreshSendRings;
- (CGFloat)ringProgressForMessage:(NSDictionary *)m;
- (void)cancelSendingRow:(NSDictionary *)m;
// The bar over a chat nobody has spoken to: report spam, add to contacts.
@property (nonatomic, strong) UIView *actionBarView;
@property (nonatomic, strong) UILabel *actionBarLabel;
/// The requests strip closed for this visit (official hides it until the
/// count changes).
@property (nonatomic, assign) NSInteger joinRequestsDismissedAt;
/// When slow mode next lets this account post here (0: no wait known).
@property (nonatomic, assign) NSTimeInterval slowModeUntil;
- (void)refreshSlowModeWait;
/// Following a reply: the quote header is the button; this is where it lands.
- (void)jumpToReplyById:(int64_t)replyId;
- (void)refreshActionBar;
- (void)blockActionBarUser;
- (void)openProfile;
- (void)headerHeld:(UILongPressGestureRecognizer *)hold;
- (void)titleHeld:(UILongPressGestureRecognizer *)hold;
@property (nonatomic, strong) UISearchBar *chatSearchBar;
@property (nonatomic, strong) UIView *searchSavedTitleView;
@property (nonatomic, strong) NSArray *searchSavedRightItems;
@property (nonatomic, strong) NSArray *messagesBeforeSearch;
@property (nonatomic, strong) NSTimer *recordTimer;
@property (nonatomic, strong) TGRecordBar *recordPanel;      // shown while holding
/// Bumped on every show, so a hide still sliding knows it has been overtaken.
/// Not the views' tags: the banner finds its labels with viewWithTag:, which
/// also looks at the banner itself.
@property (nonatomic, assign) NSUInteger composeBannerShows;
@property (nonatomic, assign) NSUInteger stickerPanelShows;
@property (nonatomic, strong) UIView *recordLockView;
@property (nonatomic, strong) UIButton *recordCancelButton;
@property (nonatomic, strong) UIButton *recordSendButton;
@property (nonatomic, strong) UIButton *recordPauseButton;
@property (nonatomic, strong) UIButton *recordOnceButton;
@property (nonatomic, strong) UILabel *recordCancelSlideLabel;
@property (nonatomic, assign) int64_t playingMessageId;
/// The other end of the same thing: the history is open to its first message
/// and asking for more only costs a round trip.
@property (nonatomic, strong) TGMessageStreamStore *streamStore;
@property (nonatomic, strong) NSTimer *playbackTimer;
@property (nonatomic, strong) MPMoviePlayerController *videoNotePlayer;
@property (nonatomic, strong) CAShapeLayer *videoNoteProgressLayer;
@property (nonatomic, strong) UIView *playerBar;        // the strip under the header
@property (nonatomic, strong) UIView *playerProgress;   // its line
@property (nonatomic, strong) UIButton *playerToggle;
@property (nonatomic, strong) UIButton *playerSpeed;
/// The speed chosen on the strip. It carries over to the next note in the queue.
@property (nonatomic, assign) float playbackRate;
@property (nonatomic, strong) UIButton *musicPrevious;
@property (nonatomic, strong) UIButton *musicNext;
@property (nonatomic, strong) UILabel *playerLabel;
@property (nonatomic, strong) TGImageLruCache *senderAvatars;   // userId -> UIImage (cap 120)
@property (nonatomic, strong) NSMutableSet *senderAvatarsRequested;
@property (nonatomic, strong) UIView *downloadHUD;
@property (nonatomic, assign) NSInteger downloadingFileId;
@property (nonatomic, strong) CLLocationManager *locationManager;
/// The own live location this screen is holding open while it watches the
/// GPS: the message id that gets edited, the period it was sent for, and
/// the marks it is being edited against.
@property (nonatomic, assign) int64_t liveLocationMessageId;
@property (nonatomic, assign) NSInteger liveLocationSeconds;
@property (nonatomic, assign) NSTimeInterval liveLocationSince;
@property (nonatomic, assign) BOOL liveLocationInFlight;
@property (nonatomic, assign) NSInteger liveLocationRestarts;
@property (nonatomic, strong) UIImage *fullScreenImage;
@property (nonatomic, strong) UIImageView *wallpaperView;
@property (nonatomic, strong) UIButton *stickerButton;
@property (nonatomic, strong) TGEmojiPanel *stickerPanel;   // emoji, stickers, GIFs
@property (nonatomic, strong) TGMessageLayoutCache *layoutCache;
/// Row heights (CGFloat per row, 0 = not measured yet) for `heightsMessages`
/// while the layout cache's generation, the table width and the font size are
/// the ones they were measured with. Every debounced reloadData asked the
/// height of every row again, and each answer ran the run checks and the
/// layout lookup: ~15% of the main thread scrolling a chat on the iPod touch 4.
@property (nonatomic, strong) NSMutableData *rowHeights;
@property (nonatomic, strong) NSArray *heightsMessages;
@property (nonatomic, assign) NSUInteger heightsGeneration;
@property (nonatomic, assign) CGFloat heightsWidth;
@property (nonatomic, assign) CGFloat heightsFontSize;
/// When the table last moved; rows waiting for a redraw wait for it to stop.
@property (nonatomic, assign) double lastScrollTime;
/// Text pictures and emoji decodes are held while the table moves.
@property (nonatomic, assign) BOOL backgroundHeld;
- (void)releaseBackgroundWhenStill;
/// lastScrollTime as the last still check saw it (tableStillOrRetry:).
@property (nonatomic, assign) double stillCheckedAt;
/// When that check ran; a late second look does not confirm it.
@property (nonatomic, assign) double stillCheckedWhen;
@property (nonatomic, strong) NSMutableDictionary *gifPaths;       // docId -> local MP4
/// Draft answers of a multiple-answer poll, per message id, before the Vote
/// button sends them all at once.
@property (nonatomic, strong) NSMutableDictionary *pendingPollVotes;
/// Ids of spoiler pictures tapped open in this visit, as official keeps them.
@property (nonatomic, strong) NSMutableSet *revealedSpoilers;
/// The composer's text with its custom emoji ids; follows every edit of self.input.
@property (nonatomic, strong) TGComposerText *composerText;
/// Image view overlays placed over custom emoji fallback glyphs in the composer.
@property (nonatomic, strong) NSMutableArray *composerEmojiViews;
// Chrome (TGChatViewController+Chrome)
@property (nonatomic, assign) int64_t readInboxAtOpen;   // where you had read up to
@property (nonatomic, assign) int64_t unreadFromId;      // the "Unread Messages" bar goes above it
@property (nonatomic, assign) BOOL unreadChecked;
/// The chat's saved newest page is on screen until TDLib's answer replaces it.
@property (nonatomic, assign) BOOL pageFromCache;
/// TDLib answered the first history request (a saved page measured later is dropped).
@property (nonatomic, assign) BOOL historyArrived;
/// TDLib's first page, waiting for the table to stand still over a saved one.
@property (nonatomic, strong) NSArray *pendingHistoryPage;
@property (nonatomic, assign) BOOL pendingHistoryMeasured;
/// The saved page lacks newer messages and was all read: TDLib's page finds
/// the unread line and scrolls there, as a first load does.
@property (nonatomic, assign) BOOL unreadLeftToTDLib;
/// When the current bottom hold ends (holdBottomWhileMediaSettles).
@property (nonatomic, assign) double anchorToBottomUntil;
- (void)holdBottomWhileMediaSettles;
/// When the screen began to load and whether a page reached it: the open's
/// time to first content, which is what a reader waits for.
@property (nonatomic, assign) double openStart;
@property (nonatomic, assign) BOOL firstPageShown;
@property (nonatomic, strong) UILabel *floatingDate;
@property (nonatomic, strong) UIButton *jumpButton;
@property (nonatomic, strong) UILabel *jumpBadge;
@property (nonatomic, assign) NSInteger newWhileAway;
/// Over the down arrow: jump to the oldest unread reaction, then to the
/// oldest unread poll vote. Each carries its chat counter as a badge.
@property (nonatomic, strong) UIButton *mentionsJumpButton;
@property (nonatomic, assign) NSInteger unreadMentionJumps;
@property (nonatomic, strong) UIButton *reactionsJumpButton;
@property (nonatomic, strong) UIButton *pollVotesJumpButton;
@property (nonatomic, assign) NSInteger unreadReactionJumps;
@property (nonatomic, assign) NSInteger unreadPollVoteJumps;
/// Ids already reported seen for their reactions or votes this visit.
@property (nonatomic, strong) NSMutableSet *unreadMarksSeen;
- (void)refreshUnreadJumps;
- (void)retryFailedMessage:(NSDictionary *)m;
- (void)openMediaOfMessage:(NSDictionary *)m atSeconds:(int32_t)seconds;
- (void)noteUnreadMarksOfMessage:(NSDictionary *)m;
@property (nonatomic, strong) UIPanGestureRecognizer *replyPanRecognizer;
@property (nonatomic, weak) UITableViewCell *replySwipeCell;
@property (nonatomic, assign) NSInteger replySwipeRow;
@property (nonatomic, strong) UIImageView *replyHint;
@property (nonatomic, strong) NSTimer *typingTimer;
@property (nonatomic, copy) NSString *typingBase;
@property (nonatomic, assign) NSInteger typingStep;
// The three owners of the header subtitle. The resting status is what the
// last-seen answered; the network line shows whenever TDLib is not ready
// (B4 - a chat opened offline used to freeze at "last seen...").
@property (nonatomic, strong) NSString *restingSubtitle;
@property (nonatomic, strong) NSString *networkSubtitle;
- (void)titleSubtitleOwnerChanged:(NSNotification *)note;
@property (nonatomic, strong) NSMutableSet *gifsRequested;
@property (nonatomic, strong) UILabel *titleNameLabel;
@property (nonatomic, strong) UIImageView *titleStatusIcon;
@property (nonatomic, strong) UILabel *titleSubtitleLabel;
/// The message the chat has pinned, so the menu offers Unpin on that one and
/// Pin on every other. Zero when nothing is pinned.
@property (nonatomic, assign) int64_t pinnedMessageId;
@property (nonatomic, assign) int64_t pinnedThumbnailFileId;
/// Scroll to a message, fetching history around it when it is not loaded.
- (void)showMessageId:(int64_t)messageId gone:(NSString *)gone;
- (void)showJumpToDateSheet;
- (void)openCommentsForMessage:(NSDictionary *)m;

// Bots (TGChatViewController+Bots.m)
@property (nonatomic, strong) NSDictionary *replyKeyboard;
@property (nonatomic, strong) UIScrollView *botKeyboardPanel;
@property (nonatomic, strong) UIButton *botKeyboardToggle;
- (void)botButtonTapped:(UIButton *)key;
- (void)refreshReplyKeyboard;
- (void)replyMarkupChanged:(NSNotification *)note;
- (void)hideBotKeyboard;
/// The chat's bot commands and official's "/" key in the field that lists
/// them over the composer.
@property (nonatomic, strong) NSArray *botCommands;
/// The other side of this private chat refuses voice and round messages.
@property (nonatomic, assign) BOOL voiceRestricted;
@property (nonatomic, strong) UIButton *botCommandsToggle;
@property (nonatomic, strong) UIScrollView *botCommandsPanel;
- (void)hideBotCommands;
- (BOOL)botKeyboardShown;
- (void)toggleBotKeyboard;
@property (nonatomic, strong) UIView *pinnedBannerView;
@property (nonatomic, strong) UIView *pinnedBannerHair;
@property (nonatomic, assign) BOOL isEditingMessages;
/// Where the last finger came down on the table. didSelectRowAtIndexPath
/// carries only the row, and a file opened from a tap anywhere on it.
@property (nonatomic, strong) UITapGestureRecognizer *touchRecorder;
@property (nonatomic, assign) CGPoint lastTouchPoint;
@property (nonatomic, assign) BOOL hasTouchPoint;
@property (nonatomic, strong) NSMutableSet *selectedMessageIds;
@property (nonatomic, strong) UIView *editToolbar;
@property (nonatomic, strong) UIButton *editDeleteButton;
@property (nonatomic, strong) UIButton *editForwardButton;
/// When "typing..." was last reported, so it is sent at most once every
/// four seconds while the composer is being typed into.
@property (nonatomic, assign) NSTimeInterval lastTypingReport;
/// True while the composer is editing a caption rather than a message's
/// text, which is a different request.
@property (nonatomic, assign) BOOL editingIsCaption;
/// True while the photo picker is choosing a replacement for an already
/// sent picture; the pick is an editMessageMedia, not a new message.
@property (nonatomic, assign) BOOL replacingPhoto;
/// The caption the replaced picture has to keep, since the picker may come
/// back long after the menu that named the message closed.
@property (nonatomic, copy) NSString *replacingPhotoCaption;
/// The link the composer has already asked Telegram about, so a second
/// keystroke on the same one does not ask again.
@property (nonatomic, copy) NSString *previewedLink;
/// The player strip's own parts. It is 48 points tall because a track needs
/// its cover, its title and who it is by, which one 36-point line could not
/// hold.
@property (nonatomic, strong) UIImageView *playerArtwork;
@property (nonatomic, strong) UILabel *playerDetail;
@property (nonatomic, strong) UILabel *playerClock;
@property (nonatomic, strong) UIView *playerThumb;
@property (nonatomic, strong) UIButton *playerClose;

@property (nonatomic, strong) UIView *savedTitleView;
@property (nonatomic, strong) UIBarButtonItem *savedRightBarButtonItem;

/// The secret chat behind this chat, 0 when it is not one. Its state is the
/// header subtitle, and updates to it arrive while the chat is open.
@property (nonatomic, assign) NSInteger secretChatId;
/// How far the composer stands above the bottom: the keyboard's, the emoji
/// panel's or the bot keyboard's height, 0 with none. Every layout pass
/// places the bar from it; iOS 7 lays the chat out again after the keyboard
/// arrives, and a pass that put the bar at the bottom hid it behind them.
@property (nonatomic, assign) CGFloat composerLift;
/// The other person in a secret chat: its chat id is not their user id.
@property (nonatomic, assign) int64_t secretUserId;
/// Official's "secret chats" panel while the chat has no messages.
@property (nonatomic, strong) UIView *secretPlaceholder;
/// The token of this chat's live feed (TGMessageStore addListenerForChat:).
@property (nonatomic, strong) id liveListener;
/// Ids of messages that arrived while this screen was covered.
@property (nonatomic, strong) NSMutableArray *readWhenShown;
- (void)refreshSecretState;
- (void)secretScreenshotTaken:(NSNotification *)note;

/// The scheduled queue's size, known when the send was last held, and the
/// picker sheet the hold's "Send At a Time..." opens.
@property (nonatomic, assign) NSInteger scheduledCount;
@property (nonatomic, copy) NSString *suppressedPreviewLink;
@property (nonatomic, strong) UIDatePicker *pickPicker;
@property (nonatomic, strong) UIButton *schedulePrimaryButton;
@property (nonatomic, assign) NSInteger pickRepeatSeconds;
@property (nonatomic, strong) TGSheet *pickSheet;
/// Jump-to-date sheet: the "N messages" line, filled when the count lands.
@property (nonatomic, strong) UILabel *pickCountLabel;
- (void)holdScheduledSheet;
- (void)showSendOptionsSheet;
- (void)openScheduledMessages;
- (void)updateComposerPlaceholder;
- (void)dismissPreviewOrCompose;
- (void)schedulePickerChanged:(UIDatePicker *)picker;
- (void)scheduleWhenOnline:(UIButton *)sender;
- (void)sendHeldText:(NSDictionary *)state;
- (void)sendHeldTextSilently;

- (void)reload;
- (void)showPlaybackFailure;
- (void)inputChanged;
/// Recomputes the field and bar height from the text's line count. The bar
/// grows up to TGMetricComposerMaxLines and the text view scrolls after.
- (void)updateComposerHeightAnimated:(BOOL)animated;
- (void)reportTyping;
- (void)refreshLinkPreview;
- (void)sendImageAlbum:(NSArray *)images;
- (UIImage *)artworkForTrack:(NSDictionary *)m;
- (void)layoutPlayerBarForMusic:(BOOL)music;
- (void)joinChatByInviteLink:(NSString *)link;
- (void)openChatWithPhoneNumber:(NSString *)phone;
- (void)openChatWithUserToken:(NSString *)token;
- (void)presentExternalLink:(NSString *)link;
/// Opens a TGInternalLinkRoute; NO when the route is nil or has no screen.
- (BOOL)openInternalLinkRoute:(NSDictionary *)route;
- (void)classifyTelegramLink:(NSString *)clean
			  isTelegramHost:(BOOL)isTelegramHost
			isTelegramScheme:(BOOL)isTelegramScheme;
- (void)showExternalLink:(NSString *)link browser:(NSString *)browser info:(NSDictionary *)info;
- (void)openInstantViewForLink:(NSString *)link;
- (void)openInstantViewForLink:(NSString *)link view:(NSDictionary *)view;
- (void)showLinkChoices:(NSString *)link host:(NSString *)host
				message:(NSMutableString *)message write:(BOOL)write;
- (void)resolveInternalLinkKind:(NSString *)kind value:(NSString *)value
					   original:(NSString *)original
				 isTelegramHost:(BOOL)isTelegramHost
			   isTelegramScheme:(BOOL)isTelegramScheme;
- (void)continueInternalLinkKind:(NSString *)kind value:(NSString *)value
							link:(NSString *)link
				   isTelegramHost:(BOOL)isTelegramHost
				 isTelegramScheme:(BOOL)isTelegramScheme;
- (void)openPlainLink:(NSURL *)url;
- (void)openTelegramLinkByPath:(NSString *)clean
						   url:(NSURL *)u
				isTelegramHost:(BOOL)isTelegramHost
			  isTelegramScheme:(BOOL)isTelegramScheme
						  host:(NSString *)host;
- (void)loadPinnedMessage;
- (void)showPinnedBanner:(NSString *)text;
- (void)showPinnedBanner:(NSString *)text entities:(NSArray *)entities;
- (void)hidePinnedBanner;
- (void)pinnedCloseTapped;
- (void)pinnedBannerTapped;
- (void)stopPlayback;
- (void)stopVideoNote;
- (BOOL)showsUnplayedMarkFor:(NSDictionary *)m;
- (void)playVideoNoteForMessage:(NSDictionary *)m atRow:(NSInteger)row;
- (void)playVideoNoteAtPath:(NSString *)path row:(NSInteger)row;
- (void)togglePlayback;
- (void)cyclePlaybackSpeed;
- (void)showMusicBar;
- (void)playVoiceNoteForMessage:(NSDictionary *)m atRow:(NSInteger)row;
- (void)scrollToBottomAnimated:(BOOL)animated;
- (TGBubbleCell *)finalizeCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine;
- (void)promptDeleteMessages:(NSArray *)ids;
- (void)executeDeleteMessages:(NSArray *)ids revoke:(BOOL)revoke;
- (void)updateEditToolbar;
- (void)reloadTableDebounced;
- (void)playOnce:(TGLottieView *)view path:(NSString *)path settled:(BOOL)settled;
- (void)showChannelBottomBar;
- (UIImage *)composerBarBackgroundImageForHeight:(CGFloat)height;
- (void)directMessagesFromChat:(UIButton *)sender;
- (void)showViewersOfActionMessage;
- (void)showPublicForwardsOfActionMessage;
- (void)showReactorsOfActionMessage;
- (void)showAuthorOfActionMessage;
- (void)translateActionMessage;
- (void)findQuoteInActionMessage;
- (void)showRecentLocationsInActionMessage;
- (void)pickReplacementPhoto;
- (void)showPlayerBar;
- (void)hidePlayerBar;
- (void)startPlaybackTimer;
- (void)videoNoteEnded;
- (void)applyVideoNoteRate;
- (void)playNextAfterMessage:(int64_t)messageId;
- (NSArray *)commonActionItemsForMessage:(NSDictionary *)m mine:(BOOL)mine heldId:(int64_t)heldId;
- (NSArray *)reactionsWithDefaultFirst:(NSArray *)reactions;
- (void)buildAvatarButton;
- (void)loadChatKindAndChrome;
- (void)downloadAndPresentDocument:(NSString *)path fromCell:(id)cell;

@end

@interface TGChatViewController (Audio)

- (void)updateRecordModeIcon;
- (void)toggleRecordMode;
- (void)recordStart;
- (void)recordFinish;
- (void)sendRecordedNoteOnce:(BOOL)once;
- (void)removeLocalNoteRow;
- (void)removeLocalNoteRowWithId:(int64_t)rowId;
- (void)recordPauseToggled;
- (void)toggleRecordOnce;
- (void)recordCancel;
- (void)recordTouchDown:(UIButton *)btn withEvent:(UIEvent *)event;
- (void)recordTouchUp:(UIButton *)btn withEvent:(UIEvent *)event;
- (void)recordTouchCancel;
- (void)recordDrag:(UIButton *)btn withEvent:(UIEvent *)event;
- (void)lockRecording;

@end

@interface TGChatViewController (Actions)

- (void)showActionsForRow:(NSInteger)row;
- (void)showActionsForRow:(NSInteger)row atPoint:(CGPoint)point;
- (void)messageHeld:(UILongPressGestureRecognizer *)hold;
/// Take the lift, the backdrop and the table's scroll state down. Safe to
/// call when nothing is lifted; the hold menu calls it as its dismissal.
- (void)endHoldPresentation;
/// Blur and dim the chat behind `cell`'s bubble and hold a sharp copy of the
/// bubble over it, moved only as far as the menu's room (`above` for the
/// reaction bar, `below` for the card) needs. Returns the rect it lands on -
/// the menu's anchor - or CGRectZero when the cell is not a bubble, in which
/// case the caller keeps the point-anchored menu. `didLift` runs when the
/// copy has landed.
- (CGRect)beginHoldPresentationForCell:(TGBubbleCell *)cell
								 above:(CGFloat)above
								 below:(CGFloat)below
                              didLift:(void (^)(CGRect anchor))didLift;
/// Remove any lift still on screen without its return animation. Used when a
/// new hold replaces one that is still fading, so its backdrop is not baked
/// into the next capture.
- (void)discardHoldPresentation;
- (void)runMessageAction:(NSString *)action;
/// The read/reaction line at the top of the hold card, or nil when official
/// does not put one on this message. Built from the message and the existing
/// getMessageViewers call, never from a cell.
- (UIView *)readSummaryHeaderForMessage:(NSDictionary *)m;
- (void)showReactorsOfMessage:(NSDictionary *)m;
- (void)showReactorsOfMessage:(NSDictionary *)m
						emoji:(NSString *)emoji
				customEmojiId:(int64_t)customEmojiId;
- (void)pickMedia;
- (void)sendCurrentLocation;
- (void)pickContact;
- (void)presentAddContactForMessage:(NSDictionary *)m;
- (void)handleOpenLink:(NSString *)urlStr;

@end

@interface TGChatViewController (Search)

- (void)toggleChatSearch;
- (void)endChatSearch;

@end

@interface TGChatViewController (Input)

- (void)sendTapped;
- (void)pickDocument;
- (void)pickAudio;
- (void)buildInputBar:(CGRect)b;
- (void)clearComposeState;
- (void)showComposeBanner:(NSString *)text;
- (void)showComposeBanner:(NSString *)text subtitle:(NSString *)subtitle;
- (void)toggleStickerPanel;
- (void)openStickerPanelTab:(NSString *)name;
- (void)hideStickerPanel;
- (void)attachTapped;
/// Puts the AI screen's result into the field without sending it.
- (void)applyComposerText:(NSString *)text;
- (void)shiftForKeyboardHeight:(CGFloat)height;
- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;

@end

@interface TGChatViewController (Media)

- (void)fetchMissingMaps;
- (void)resolveUnknownSenders;
- (void)fetchMissingQuotes;
- (void)fetchMissingImages;
- (void)applyThemeFromMessage:(NSDictionary *)m;
- (UIImage *)avatarForUser:(int64_t)userId name:(NSString *)name;
- (UIImage *)replierFaces:(NSArray *)peerIds;
- (UIImage *)mapCardForLatitude:(double)lat longitude:(double)lon;
- (void)beginDownloadHUDForFile:(NSInteger)fileId;
- (void)endDownloadHUD;

@end

@interface TGChatViewController ()

// Layout and cell helpers
- (CGFloat)layoutForwardIn:(TGBubbleCell *)cell message:(NSDictionary *)m width:(CGFloat)width;
/// The final service line: who did it, plus the pinned message quoted when
/// that message is loaded. Layout and cell both draw this one string.
- (NSString *)serviceLineForMessage:(NSDictionary *)m;
- (UIImage *)imageFor:(NSDictionary *)m;
- (void)fetchImageForMessage:(NSDictionary *)m;
- (CGSize)imageSizeFor:(NSDictionary *)m;
- (TGMessageLayout *)layoutForMessage:(NSDictionary *)m atRow:(NSInteger)row;
/// Measures the bodies of `messages` off the main thread, then runs `then`
/// on it: the reloadData after is left with cache hits.
- (void)measureTextsOf:(NSArray *)messages then:(dispatch_block_t)then;
/// YES when the table has stood still long enough to rebuild rows or start
/// held work; otherwise `action` is scheduled to ask again.
- (BOOL)tableStillOrRetry:(SEL)action;
/// -reload once the table stands still; for changes that arrive on their own.
- (void)reloadWhenStill;
/// The cache key of a message body's picture (TGRenderedLabel, iOS 6).
- (NSString *)bodyRenderKeyFor:(NSDictionary *)m layout:(TGMessageLayout *)layout
						  mine:(BOOL)mine revealed:(BOOL)revealed;
/// Draws the body pictures of the rows next to `row` ahead, off the main thread.
- (void)prefetchBodyTextsAroundRow:(NSInteger)row;
/// Runs: neighbouring bubbles from one sender a few minutes apart.
- (BOOL)runStartsAtRow:(NSInteger)row;
- (BOOL)runEndsAtRow:(NSInteger)row;
- (CGFloat)runHeightChangeAtRow:(NSInteger)row layout:(TGMessageLayout *)layout;
- (UIImage *)ticksForMessage:(NSDictionary *)m white:(BOOL)white;
- (BOOL)continuesAlbumAtRow:(NSInteger)row;
- (BOOL)albumContinuesAfterRow:(NSInteger)row;
- (void)pollOptionTapped:(UIButton *)option;
- (void)checklistTaskTapped:(UIButton *)taskRow;
- (void)pollVoteTapped:(UIButton *)button;
- (void)pollAddOptionTapped:(UIButton *)button;
- (void)pollFooterTapped:(UIButton *)button;
/// The card button of a message row: open the person, chat, gift, story, game or giveaway.
- (void)openCard:(TGMessageCard *)card ofMessage:(int64_t)messageId;
/// Puts a custom emoji at the cursor: the field shows its fallback (or its
/// picture on iOS 7+), composerText keeps the id. Called by the emoji panel.
- (void)insertCustomEmoji:(int64_t)emojiId fallback:(NSString *)fallback;
/// Updates invisible fallback ranges and places picture overlays for custom emoji in self.input.
- (void)refreshComposerEmojiOverlay;
- (void)docRowTapped:(UIButton *)sender;
- (void)callCellButtonTapped:(UIButton *)btn;
- (void)contactCallButtonTapped:(UIButton *)btn;
- (void)contactAddButtonTapped:(UIButton *)btn;
- (void)videoNoteDiscTapped:(UITapGestureRecognizer *)tap;
- (float)playedFraction;
- (void)voiceDiscTapped:(UITapGestureRecognizer *)tap;
- (void)waveformScrubbed:(UIGestureRecognizer *)gesture;

// Chrome
- (NSArray *)messagesWithSeparators:(NSArray *)grouped;
- (void)noteFirstUnreadIn:(NSArray *)raw;
- (NSInteger)unreadSeparatorRow;
- (void)buildChrome;
- (void)applyChromeTheme:(TGTheme *)theme;
- (void)layoutChrome;
- (void)showChatStatistics;
- (void)speakActionMessage;
- (void)updateTitleEmojiStatus;
- (int64_t)quoteAuthorStatusIdFor:(NSDictionary *)m;
- (BOOL)isNearBottom;
- (void)noteArrivedWhileAway;
- (void)chromeDidScroll;
- (void)installSwipeToReply;
- (void)showChatAction:(NSString *)action resting:(NSString *)resting;
- (void)stopChrome;
- (void)sendImage:(UIImage *)image;
- (void)sendImage:(UIImage *)image viewOnce:(BOOL)viewOnce;
/// Asks whether the picture or video goes as a normal message or a one-time
/// one before staging the file.
- (void)confirmSendingImage:(UIImage *)image;
- (void)confirmSendingVideoAtPath:(NSString *)path;
- (void)sendVideoAtPath:(NSString *)path viewOnce:(BOOL)viewOnce;

- (BOOL)configureServiceCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine indexPath:(NSIndexPath *)indexPath;
- (BOOL)configureAudioCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine indexPath:(NSIndexPath *)indexPath;
- (BOOL)configureRoundOrStickerCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine;
- (void)configureMediaForCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout isMine:(BOOL)mine;
- (void)configureReactionChipsForCell:(TGBubbleCell *)cell message:(NSDictionary *)m layout:(TGMessageLayout *)layout;
- (void)reactionChipTapped:(UITapGestureRecognizer *)tap;
- (void)placeStickerEmoji:(TGBubbleCell *)cell message:(NSDictionary *)m inFrame:(CGRect)frame;
- (void)startGifIfWantedIn:(TGBubbleCell *)cell message:(NSDictionary *)m;

@end

// Cell placers and the sender colour palette live in TGChatGeometry.h.

#endif // TGCHATVIEWCONTROLLERINTERNAL_H
