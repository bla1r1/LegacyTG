//
// TGMusicStreamer.h - progressive MP3/AAC playback while the file downloads.
//
// `downloadFile` only answers when the whole file is on disk, which for a
// long track means silence for a minute. This reads the growing local file,
// parses it with AudioFileStream and plays the packets through AudioQueue, so
// the first seconds are audible while the rest arrives.
//
// Formats the parser cannot handle (or whose header arrives at the end, like
// an m4a whose moov atom is last) report a failure and the caller falls back
// to its download-then-AVAudioPlayer path.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGMusicStreamer;

@protocol TGMusicStreamerDelegate <NSObject>
- (void)musicStreamerDidFinish:(TGMusicStreamer *)streamer;
- (void)musicStreamer:(TGMusicStreamer *)streamer didFail:(NSError *)error;
@end

@interface TGMusicStreamer : NSObject

- (instancetype)initWithDelegate:(id<TGMusicStreamerDelegate>)delegate;

@property (nonatomic, weak) id<TGMusicStreamerDelegate> delegate;

@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) BOOL ready;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval position;
@property (nonatomic, assign) float volume;

/// Reads everything from the last offset up to `downloadedSize` and parses
/// it. `complete` says the download is finished, so a drained queue ends the
/// track instead of waiting for more. Returns NO once the streamer has failed.
- (BOOL)feedFileAtPath:(NSString *)path
		downloadedSize:(long long)downloadedSize
		  expectedSize:(long long)expectedSize
			  complete:(BOOL)complete;

- (void)play;
- (void)pause;
- (void)seekToFraction:(CGFloat)fraction;
- (void)stop;

@end
