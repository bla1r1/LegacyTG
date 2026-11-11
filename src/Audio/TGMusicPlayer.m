#import "TGMusicPlayer.h"
#import "TGClient.h"
#import "TGIcons.h"
#import "TGPlaybackQueue.h"
#import "TGMediaStore.h"
#import "TGMusicStreamer.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#import "TGStarsStore.h"
#import "TGDownloadStore.h"

NSString *const TGMusicPlayerChangedNotification = @"TGMusicPlayerChanged";

@interface TGMusicPlayer () <AVAudioPlayerDelegate, TGMusicStreamerDelegate>
@property (nonatomic, strong) AVAudioPlayer *player;
/// Progressive playback of the file as it downloads. When it is running the
/// AVAudioPlayer stays nil; a format it cannot parse clears it and leaves the
/// existing download-then-play path to take over.
@property (nonatomic, strong) TGMusicStreamer *streamer;
@property (nonatomic, strong) NSTimer *streamTimer;
@property (nonatomic, assign) NSInteger streamFileId;
@property (nonatomic, assign) BOOL streamFailed;
@property (nonatomic, assign) BOOL streamPollInFlight;
@property (nonatomic, assign) float storedVolume;
@property (nonatomic, strong) NSArray *tracks;
/// The track being fetched to play. Skipping on cancels it: TDLib runs a few
/// downloads at once, and a skipped track held the slot of the wanted one.
@property (nonatomic, assign) NSInteger pendingFileId;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSDictionary *current;
@property (nonatomic, strong) UIImage *currentArtwork;
@property (nonatomic, copy) NSString *currentArtworkPath;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;
@end

@implementation TGMusicPlayer

+ (instancetype)shared {
	static TGMusicPlayer *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ s = [[TGMusicPlayer alloc] init]; });
	return s;
}

- (id)init {
	if ((self = [super init])){
		_index = NSNotFound;
		_backgroundTask = UIBackgroundTaskInvalid;
		_storedVolume = 1.0f;
	}
	return self;
}

#pragma mark - queue

- (void)playTracks:(NSArray *)tracks atIndex:(NSInteger)index inChat:(int64_t)chatId {
	// Only the audio, in the order the chat has it: the queue is "the rest of
	// the music in this conversation", which is what a client means by next.
	NSMutableArray *queue = [NSMutableArray array];
	NSInteger adjusted = 0;
	for (NSUInteger i = 0; i < tracks.count; i++){
		if (![tracks[i][@"kind"] isEqualToString:@"messageAudio"])
			continue;
		if ((NSInteger)i <= index)
			adjusted = queue.count;
		[queue addObject:tracks[i]];
	}
	if (!queue.count)
		return;

	self.tracks = queue;
	self.chatId = chatId;
	[self playIndex:MIN(MAX(adjusted, 0), (NSInteger)queue.count - 1)];
}

- (void)playIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.tracks.count){
		[self stop];
		return;
	}

	self.index = index;
	self.current = self.tracks[index];
	// The old track stops now, not when the new file has arrived: the cover
	// changed at once and the sound went on for seconds.
	[self stopStreaming];
	[self.player stop];
	self.player = nil;
	[self announce];

	NSNumber *docId = self.current[@"docId"];
	if (![docId isKindOfClass:NSNumber.class]){
		[self next];
		return;
	}

	if (self.pendingFileId && self.pendingFileId != docId.integerValue)
		[[TGDownloadStore shared] cancelDownloadOfFile:self.pendingFileId onlyIfPending:NO];
	self.pendingFileId = docId.integerValue;

	__weak typeof(self) weakSelf = self;
	NSInteger wanted = index;

	// Two paths at once: the parser reads the growing local file and starts
	// the track in seconds, while the download completion stays as the
	// fallback for a format or a layout the parser cannot stream.
	[self startStreamingFileId:docId.integerValue];

	CFAbsoluteTime asked = CFAbsoluteTimeGetCurrent();
	[[TGDownloadStore shared] downloadFile:docId.integerValue priority:TGDownloadPriorityOnScreen
						 completion:^(NSString *path){
		TGMusicPlayer *me = weakSelf;
		// The user may have skipped on while this was downloading.
		if (!me || me.index != wanted)
			return;
		me.pendingFileId = 0;
		// The streamer already owns the sound; a second player would fight it.
		if (me.streamer)
			return;
		NSLog(@"music: file ready in %.1f s", CFAbsoluteTimeGetCurrent() - asked);
		if (!path.length){
			[me next];
			return;
		}
		[me startFile:path];
	}];
}

#pragma mark - progressive playback

- (void)startStreamingFileId:(NSInteger)fileId {
	self.streamFileId = fileId;
	self.streamFailed = NO;
	self.streamPollInFlight = NO;
	TGMusicStreamer *streamer = [[TGMusicStreamer alloc] initWithDelegate:self];
	streamer.volume = self.storedVolume;
	self.streamer = streamer;
	[streamer play];
	[self.streamTimer invalidate];
	self.streamTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
													   target:self
													 selector:@selector(pollStream:)
													 userInfo:nil
													  repeats:YES];
}

- (void)pollStream:(NSTimer *)timer {
	if (self.streamFailed || !self.streamer || self.streamPollInFlight){
		if (self.streamFailed || !self.streamer)
			[timer invalidate];
		return;
	}
	NSInteger fileId = self.streamFileId;
	NSInteger wanted = self.index;
	self.streamPollInFlight = YES;
	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared] fileInfo:fileId completion:^(NSDictionary *info){
		TGMusicPlayer *me = weakSelf;
		if (!me)
			return;
		me.streamPollInFlight = NO;
		if (me.index != wanted || me.streamFileId != fileId || !me.streamer)
			return;

		NSString *path = info[@"localPath"];
		long long downloaded = [info[@"downloadedSize"] longLongValue];
		long long expected = [info[@"expectedSize"] longLongValue];
		if (expected <= 0)
			expected = [info[@"size"] longLongValue];
		BOOL complete = [info[@"completed"] boolValue];
		if (!path.length || downloaded <= 0)
			return;

		BOOL ok = [me.streamer feedFileAtPath:path downloadedSize:downloaded
								expectedSize:expected complete:complete];
		if (!ok || complete){
			[me.streamTimer invalidate];
			me.streamTimer = nil;
		}
	}];
}

- (void)musicStreamerDidFinish:(TGMusicStreamer *)streamer {
	if (streamer != self.streamer)
		return;
	NSNumber *fileId = self.current[@"docId"];
	if ([fileId isKindOfClass:NSNumber.class] && fileId.intValue > 0 &&
		streamer.duration > 0){
		[[TGStarsStore shared] markAudioListened:fileId.intValue
									duration:(int32_t)streamer.duration
								  completion:nil];
	}
	if (self.repeatMode == TGMusicRepeatOne){
		[streamer seekToFraction:0.0f];
		[streamer play];
		streamer.delegate = self;
		[self announce];
		return;
	}
	[self next];
}

- (void)musicStreamer:(TGMusicStreamer *)streamer didFail:(NSError *)error {
	if (streamer != self.streamer)
		return;
	NSLog(@"music: streaming unavailable, waiting for the file: %@",
			error.localizedDescription);
	self.streamFailed = YES;
	[self.streamTimer invalidate];
	self.streamTimer = nil;
	self.streamer = nil;
	// The download may have finished while the parser was trying: in that
	// case its completion already returned (the streamer owned the sound),
	// and nothing else would start the file.
	NSInteger fileId = self.streamFileId;
	NSInteger wanted = self.index;
	__weak typeof(self) weakSelf = self;
	[[TGMediaStore shared] fileInfo:fileId completion:^(NSDictionary *info){
		TGMusicPlayer *me = weakSelf;
		if (!me || me.index != wanted || me.streamer)
			return;
		NSString *path = info[@"localPath"];
		if ([info[@"completed"] boolValue] && path.length)
			[me startFile:path];
	}];
}

/// The fallback player and the streamer never share the sound.
- (void)stopStreaming {
	[self.streamTimer invalidate];
	self.streamTimer = nil;
	self.streamer.delegate = nil;
	[self.streamer stop];
	self.streamer = nil;
	self.streamFailed = NO;
	self.streamPollInFlight = NO;
}

- (void)startFile:(NSString *)path {
	[self stopStreaming];
	[self.player stop];

	NSError *err = nil;
	// Playback, not ambient: this has to keep going with the screen off, which
	// is the whole difference between a track and a voice note.
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
	[[AVAudioSession sharedInstance] setActive:YES error:nil];

	self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:
			[NSURL fileURLWithPath:path] error:&err];
	if (!self.player){
		NSLog(@"music: cannot play %@: %@", path.lastPathComponent, err);
		[self next];
		return;
	}
	self.player.delegate = self;
	self.player.enableRate = YES;
	[self.player play];

	[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	[self holdBackground];
	[self announce];

	NSNumber *following = TGTrackToPrefetch(self.tracks, self.index, self.shuffle,
			self.repeatMode == TGMusicRepeatAll);
	if (following)
		[[TGDownloadStore shared] downloadFile:following.integerValue
							   priority:TGDownloadPriorityBackground
							 completion:^(NSString *ignored){}];
}

#pragma mark - transport

- (void)cycleRepeatMode {
	_repeatMode = (TGMusicRepeatMode)((_repeatMode + 1) % 3);
	[self announce];
}

- (void)toggleShuffle {
	_shuffle = !_shuffle;
	[self announce];
}

- (float)volume {
	if (self.streamer)
		return self.streamer.volume;
	return self.player ? self.player.volume : self.storedVolume;
}

- (void)setVolume:(float)volume {
	self.storedVolume = MIN(MAX(volume, 0.0f), 1.0f);
	if (self.streamer)
		self.streamer.volume = self.storedVolume;
	if (self.player)
		self.player.volume = self.storedVolume;
}

- (void)togglePlayPause {
	if (self.streamer){
		if (self.streamer.playing)
			[self.streamer pause];
		else
			[self.streamer play];
		[self announce];
		return;
	}
	if (!self.player)
		return;
	if (self.player.playing)
		[self.player pause];
	else
		[self.player play];
	[self announce];
}

- (void)next {
	if (!self.tracks.count)
		return;

	if (self.shuffle && self.tracks.count > 1) {
		NSInteger nextIdx = self.index;
		while (nextIdx == self.index) {
			nextIdx = (NSInteger)(arc4random_uniform((uint32_t)self.tracks.count));
		}
		[self playIndex:nextIdx];
		return;
	}

	NSInteger nextIdx = self.index + 1;
	if (nextIdx >= (NSInteger)self.tracks.count) {
		if (self.repeatMode == TGMusicRepeatAll) {
			[self playIndex:0];
		} else {
			[self stop];
		}
		return;
	}
	[self playIndex:nextIdx];
}

- (void)previous {
	// Their previous restarts the track first and only steps back when it has
	// barely begun, which is what every player does.
	if (self.streamer && self.streamer.position > 3.0){
		[self.streamer seekToFraction:0.0f];
		[self announce];
		return;
	}
	if (self.player && self.player.currentTime > 3.0){
		self.player.currentTime = 0;
		[self announce];
		return;
	}
	if (self.index > 0) {
		[self playIndex:self.index - 1];
	} else if (self.repeatMode == TGMusicRepeatAll && self.tracks.count > 0) {
		[self playIndex:(NSInteger)self.tracks.count - 1];
	} else {
		[self playIndex:0];
	}
}

- (void)seekToFraction:(CGFloat)fraction {
	if (self.streamer){
		[self.streamer seekToFraction:fraction];
		[self announce];
		return;
	}
	if (!self.player)
		return;
	self.player.currentTime = MIN(MAX(fraction, 0.0f), 1.0f) * self.player.duration;
	[self announce];
}

- (void)stop {
	[self stopStreaming];
	[self.player stop];
	self.player = nil;
	self.current = nil;
	self.currentArtwork = nil;
	self.currentArtworkPath = nil;
	self.index = NSNotFound;
	self.tracks = nil;
	[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	[self releaseBackground];
	[self clearNowPlaying];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGMusicPlayerChangedNotification object:nil];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)ok {
	// A finished track is a listened track: Telegram's only use for the audio
	// file id here is the listened mark and its recommendations.
	NSNumber *fileId = self.current[@"docId"];
	if ([fileId isKindOfClass:NSNumber.class] && fileId.intValue > 0){
		[[TGStarsStore shared] markAudioListened:fileId.intValue
									duration:(int32_t)MAX(0.0, player.duration)
								  completion:nil];
	}
	if (self.repeatMode == TGMusicRepeatOne) {
		self.player.currentTime = 0;
		[self.player play];
		[self announce];
		return;
	}
	[self next];
}

#pragma mark - state

- (BOOL)playing            {
	return self.streamer ? self.streamer.playing : self.player.playing;
}
- (NSTimeInterval)duration {
	if (self.streamer)
		return self.streamer.duration;
	return self.player ? self.player.duration : 0;
}
- (NSTimeInterval)position {
	if (self.streamer)
		return self.streamer.position;
	return self.player ? self.player.currentTime : 0;
}
- (int64_t)currentMessageId { return [self.current[@"id"] longLongValue]; }

- (NSString *)titleForTrack:(NSDictionary *)track {
	NSString *title = track[@"audioTitle"];
	if (title.length)
		return title;
	NSString *name = track[@"docName"];
	return name.length ? name : @"Audio";
}

- (NSString *)performerForTrack:(NSDictionary *)track {
	NSString *performer = track[@"audioPerformer"];
	return performer.length ? performer : @"Unknown artist";
}

- (void)announce {
	[self updateNowPlaying];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:TGMusicPlayerChangedNotification object:nil];
}

#pragma mark - lock screen

/// MPNowPlayingInfoCenter is what puts the title, the artist and the position
/// on the lock screen and behind the double-tap tray on this OS.
- (void)updateNowPlaying {
	if (!self.current)
		return;
	MPNowPlayingInfoCenter *centre = [MPNowPlayingInfoCenter defaultCenter];

	NSMutableDictionary *info = [@{
		MPMediaItemPropertyTitle  : [self titleForTrack:self.current],
		MPMediaItemPropertyArtist : [self performerForTrack:self.current],
		MPMediaItemPropertyPlaybackDuration : @(self.duration),
		MPNowPlayingInfoPropertyElapsedPlaybackTime : @(self.position),
		MPNowPlayingInfoPropertyPlaybackRate : @(self.playing ? 1.0 : 0.0),
	} mutableCopy];

	NSNumber *coverId = self.current[@"albumCoverId"];
	if ([coverId isKindOfClass:NSNumber.class]){
		__weak typeof(self) weakSelf = self;
		int64_t forMessage = self.currentMessageId;
		[[TGDownloadStore shared] downloadFile:coverId.integerValue completion:^(NSString *path){
			TGMusicPlayer *me = weakSelf;
			if (!me || me.currentMessageId != forMessage || !path.length)
				return;
			UIImage *cover = [UIImage imageWithContentsOfFile:path];
			if (!cover)
				return;
			me.currentArtwork = cover;
			me.currentArtworkPath = path;
			MPNowPlayingInfoCenter *now = [MPNowPlayingInfoCenter defaultCenter];
			NSMutableDictionary *withArt = now.nowPlayingInfo
					? [now.nowPlayingInfo mutableCopy] : [NSMutableDictionary dictionary];
			withArt[MPMediaItemPropertyArtwork] =
					[[MPMediaItemArtwork alloc] initWithImage:cover];
			now.nowPlayingInfo = withArt;
			[[NSNotificationCenter defaultCenter]
					postNotificationName:TGMusicPlayerChangedNotification object:nil];
		}];
	}

	centre.nowPlayingInfo = info;
}

- (void)clearNowPlaying {
	[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
}

#pragma mark - background

/// Info.plist declares the audio background mode, which is what actually keeps
/// the sound going. The task is only so the app is not suspended between one
/// track finishing and the next one being fetched.
- (void)holdBackground {
	if (self.backgroundTask != UIBackgroundTaskInvalid)
		return;
	__weak typeof(self) weakSelf = self;
	self.backgroundTask = [[UIApplication sharedApplication]
			beginBackgroundTaskWithExpirationHandler:^{ [weakSelf releaseBackground]; }];
}

- (void)releaseBackground {
	if (self.backgroundTask == UIBackgroundTaskInvalid)
		return;
	[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
	self.backgroundTask = UIBackgroundTaskInvalid;
}

@end

// vim:ft=objc
