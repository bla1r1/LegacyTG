#import "TGMediaViewer.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TGMediaPlayerView.h"
#import "TGSoftVideoPlayer.h"

@interface TGMediaViewer () <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) BOOL isAlbum;

@property (nonatomic, strong) TGMediaViewer *self_;   // held up while on screen
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *backdrop;
@property (nonatomic, strong) UIScrollView *pager;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIView *statusPlate;
@property (nonatomic, assign) BOOL statusBarWasHidden;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *authorAvatar;
@property (nonatomic, strong) UIButton *moreButton;
/// Hidden on a page whose message TDLib will not let out of the chat.
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) NSNumber *avatarFileId;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UIScrollView *thumbStrip;
@property (nonatomic, strong) NSMutableArray *thumbButtons;
@property (nonatomic, assign) BOOL chromeHidden;
/// Where the drag that may dismiss the viewer started, and the page it is
/// carrying. Zero width means no drag is in progress.
@property (nonatomic, assign) CGPoint dragOrigin;
@property (nonatomic, assign) BOOL dragging;

/// The bubble the picture grew from. Weak: the chat owns it, and a cell can be
/// reused or gone by the time the viewer closes. `startIndex` is the page it
/// stands for - the zoom back only makes sense while that page is still up.
@property (nonatomic, weak) UIView *sourceView;
@property (nonatomic, assign) NSInteger startIndex;
@property (nonatomic, assign) BOOL sourceHidden;
@property (nonatomic, assign) BOOL dismissing;
/// Pages whose picture is a thumbnail standing in for the original, so Share
/// and Save do not hand out the blurry copy.
@property (nonatomic, strong) NSMutableSet *placeholderPages;
/// Work in flight per page (poster, original, video file). A counted set,
/// because a video page has the poster and the movie coming at once.
@property (nonatomic, strong) NSCountedSet *loading;

/// One page per item, built lazily: twenty full-size pictures at once is more
/// memory than this device has.
@property (nonatomic, strong) NSMutableDictionary *pages;     // index -> UIView
@property (nonatomic, strong) NSMutableDictionary *originals; // index -> UIImage
@property (nonatomic, strong) NSMutableSet *requested;

/// AVPlayer rather than MPMoviePlayerController, which is a view controller
/// with opinions: it brings its own chrome, its own rotation, and a
/// currentPlaybackTime that seeks to the nearest keyframe, so dragging the
/// scrubber jumped in half-second steps. A layer plays where it is put.
@property (nonatomic, strong) AVPlayer *player;
/// The software player replaces AVPlayer only after the latter refuses a
/// file on a Vintage device. It sits in the same page and uses the same
/// transport buttons.
@property (nonatomic, strong) TGSoftVideoPlayer *softPlayer;
@property (nonatomic, copy) NSString *currentMoviePath;
@property (nonatomic, assign) BOOL triedMovieCopy;
@property (nonatomic, assign) BOOL triedSoftMovie;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) TGMediaPlayerView *playerView;
@property (nonatomic, assign) NSInteger moviePage;
@property (nonatomic, strong) NSTimer *movieTimer;
@property (nonatomic, assign) BOOL movieLoops;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UILabel *timeLabel;
- (NSDictionary *)currentItem;
- (NSNumber *)currentFileId;
- (void)saveCurrent;
- (void)moreTapped;
- (void)shareCurrent;
- (void)forwardCurrent;
- (void)copyCaption;
- (void)addCurrentToDownloads;
- (void)showFileInfo;
- (void)deleteCurrentFromDevice;
- (void)present;
- (void)dismiss;
- (void)dismissWithZoom:(BOOL)zoom;
- (void)toggleMovie;
- (void)startMovieAtPath:(NSString *)path;
- (void)stopMovie;
- (void)refreshChrome;
- (void)toggleChrome;
- (void)gotoPage:(NSInteger)idx animated:(BOOL)animated;
- (void)loadPagesAround:(NSInteger)centre;
- (void)beginLoadingPage:(NSInteger)page;
- (void)endLoadingPage:(NSInteger)page;
- (void)showOriginal:(UIImage *)image inPicture:(UIImageView *)picture page:(NSInteger)page;
- (void)fetchOriginalForPage:(NSInteger)page into:(UIImageView *)picture;
- (void)relayoutViewer;
- (void)buildChrome;
- (void)buildThumbStrip;
- (void)updateThumbStripSelection:(BOOL)animated;
- (void)fetchThumbnailForIndex:(NSUInteger)idx into:(UIButton *)btn;
- (void)thumbTapped:(UIButton *)btn;
- (void)fadeChromeText;
- (void)tapAt:(UITapGestureRecognizer *)tap;
- (void)presentShareItems:(NSArray *)items;
- (UIViewController *)hostController;
- (NSNumber *)fileIdForItem:(NSDictionary *)item;
- (void)showStickerPacksOfFile:(NSInteger)fileId;
- (void)runOpenTransition;
- (void)fadeInChrome;
- (void)landedWithGhost:(UIImageView *)ghost thumbnail:(UIImage *)thumb;
- (UIImageView *)closingGhostTarget:(CGRect *)target;
- (void)restoreSource;
- (void)movieFailed;
- (void)movieTicked;
- (void)scrubberMoved;
- (void)movieFinished;
- (void)showVideoFormatAlert;
- (void)startSoftPlaybackAfterFailure;
- (void)startSoftMovieAtPath:(NSString *)path;
- (NSTimeInterval)movieDuration;
- (NSTimeInterval)moviePosition;
- (UIImage *)playGlyph;
- (UIImage *)pauseGlyph;
- (UIScrollView *)currentPage;
@end
