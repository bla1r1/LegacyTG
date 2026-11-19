//
// TGBackgroundKeeper.m - ultra-light silent audio loop keeping TDLib awake in background.
//
#import "TGBackgroundKeeper.h"
#import <AVFoundation/AVFoundation.h>

#define TG_SILENCE_SAMPLE_RATE 8000
#define TG_SILENCE_SECONDS 1

/// Generates a minimal in-memory WAV file containing 1 second of 8 kHz mono 16-bit silence.
/// Total heap footprint is exactly 16,044 bytes.
static NSData *TGSilentWavData(void) {
	uint32_t sampleRate = TG_SILENCE_SAMPLE_RATE;
	uint32_t dataBytes = sampleRate * TG_SILENCE_SECONDS * 2; // 16-bit = 2 bytes per sample
	uint32_t totalChunk = 36 + dataBytes;
	uint32_t byteRate = sampleRate * 2;
	uint16_t numChannels = 1;
	uint16_t bitsPerSample = 16;
	uint16_t blockAlign = 2;
	uint16_t audioFormat = 1; // PCM
	uint32_t subchunk1Size = 16;

	NSMutableData *data = [NSMutableData dataWithLength:44 + dataBytes];
	uint8_t *p = (uint8_t *)data.mutableBytes;

	memcpy(p, "RIFF", 4);
	memcpy(p + 4, &totalChunk, 4);
	memcpy(p + 8, "WAVEfmt ", 8);
	memcpy(p + 16, &subchunk1Size, 4);
	memcpy(p + 20, &audioFormat, 2);
	memcpy(p + 22, &numChannels, 2);
	memcpy(p + 24, &sampleRate, 4);
	memcpy(p + 28, &byteRate, 4);
	memcpy(p + 32, &blockAlign, 2);
	memcpy(p + 34, &bitsPerSample, 2);
	memcpy(p + 36, "data", 4);
	memcpy(p + 40, &dataBytes, 4);
	// Bytes 44..44+dataBytes are zero-initialized by dataWithLength

	return data;
}

@interface TGBackgroundKeeper () <AVAudioPlayerDelegate> {
	AVAudioPlayer *_player;
	BOOL _listening;
}
@end

@implementation TGBackgroundKeeper

+ (instancetype)shared {
	static TGBackgroundKeeper *keeper = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		keeper = [[TGBackgroundKeeper alloc] init];
	});
	return keeper;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_player stop];
}

- (BOOL)isRunning {
	return _player != nil && [_player isPlaying];
}

- (void)observeInterruptions {
	if (_listening)
		return;
	_listening = YES;
	[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(handleAudioInterruption:)
				   name:AVAudioSessionInterruptionNotification
				 object:nil];
}

- (void)handleAudioInterruption:(NSNotification *)note {
	NSNumber *type = note.userInfo[AVAudioSessionInterruptionTypeKey];
	if (!type)
		return;
	if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeEnded) {
		if (_player && ![_player isPlaying]) {
			AVAudioSession *session = [AVAudioSession sharedInstance];
			if ([session respondsToSelector:@selector(setCategory:withOptions:error:)]) {
				[session setCategory:AVAudioSessionCategoryPlayback
						 withOptions:AVAudioSessionCategoryOptionMixWithOthers
							   error:nil];
			}
			[session setActive:YES error:nil];
			[_player play];
		}
	}
}

- (BOOL)start {
	if (self.running)
		return YES;

	AVAudioSession *session = [AVAudioSession sharedInstance];
	if ([session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
		NSLog(@"[TGBackgroundKeeper] deferred: call/recording owns audio session");
		return NO;
	}

	NSError *error = nil;
	if ([session respondsToSelector:@selector(setCategory:withOptions:error:)]) {
		[session setCategory:AVAudioSessionCategoryPlayback
				 withOptions:AVAudioSessionCategoryOptionMixWithOthers
					   error:&error];
	} else {
		[session setCategory:AVAudioSessionCategoryPlayback error:&error];
	}
	[session setActive:YES error:&error];

	if (!_player) {
		NSData *wav = TGSilentWavData();
		_player = [[AVAudioPlayer alloc] initWithData:wav error:&error];
		if (!_player) {
			NSLog(@"[TGBackgroundKeeper] player init failed: %@", error.localizedDescription);
			return NO;
		}
		_player.numberOfLoops = -1;
		[_player prepareToPlay];
	}

	[self observeInterruptions];

	BOOL ok = [_player play];
	NSLog(@"[TGBackgroundKeeper] started silent audio: %d", ok);
	return ok;
}

- (void)stop {
	if (!_player)
		return;
	[_player stop];
	NSLog(@"[TGBackgroundKeeper] stopped silent audio");
}

@end
