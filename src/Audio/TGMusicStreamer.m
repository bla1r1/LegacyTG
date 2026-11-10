//
// TGMusicStreamer.m - AudioFileStream + AudioQueue progressive playback.
//
#import "TGMusicStreamer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

enum { kTGMusicBuffers = 3 };
static const long long kTGMusicReadChunk = 512 * 1024;

/// One packet as the parser handed it over. VBR formats carry a description
/// whose start offset has to be rewritten as the packets are packed into a
/// queue buffer; CBR data has none.
@interface TGMusicPacket : NSObject
@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) AudioStreamPacketDescription packetDescription;
@property (nonatomic, assign) BOOL hasDescription;
@end
@implementation TGMusicPacket
@end

@interface TGMusicStreamer () {
	AudioFileStreamID _stream;
	AudioQueueRef _queue;
	AudioQueueBufferRef _buffers[kTGMusicBuffers];
	BOOL _bufferBusy[kTGMusicBuffers];
	AudioStreamPacketDescription *_descriptions[kTGMusicBuffers];

	AudioStreamBasicDescription _format;
	BOOL _formatReady;
	NSData *_magicCookie;

	NSMutableArray *_pending;
	NSFileHandle *_file;
	long long _readOffset;
	long long _downloadedSize;
	long long _expectedSize;
	BOOL _inputComplete;
	BOOL _finished;
	BOOL _failed;
	BOOL _playing;
	BOOL _playedAnything;
	NSInteger _inFlight;
	UInt32 _nextParseFlags;
	NSUInteger _packetCount;

	NSTimeInterval _packetDuration;
	NSTimeInterval _baseTime;
	NSTimeInterval _audioDataByteCount;
	double _bitRate;
	NSTimeInterval _duration;
}

- (void)propertyChanged:(AudioFileStreamPropertyID)property;
- (void)packetsParsed:(UInt32)numBytes packets:(UInt32)numPackets
				 data:(const void *)inputData
		 descriptions:(AudioStreamPacketDescription *)packetDescriptions;
- (void)bufferFinished:(AudioQueueBufferRef)buffer;
- (void)fillBuffers;
- (void)finishIfDrained;
- (void)resetQueue;
- (void)updateDuration;
- (BOOL)createQueue;
- (void)applyVolume;

@end

static void TGMusicStreamerPropertyCallback(void *clientData, AudioFileStreamID stream,
		AudioFileStreamPropertyID property, UInt32 *flags) {
	[(__bridge TGMusicStreamer *)clientData propertyChanged:property];
}

static void TGMusicStreamerPacketCallback(void *clientData, UInt32 numBytes,
		UInt32 numPackets, const void *inputData,
		AudioStreamPacketDescription *packetDescriptions) {
	[(__bridge TGMusicStreamer *)clientData packetsParsed:numBytes
												  packets:numPackets
													 data:inputData
											 descriptions:packetDescriptions];
}

static void TGMusicStreamerBufferCallback(void *clientData, AudioQueueRef queue,
		AudioQueueBufferRef buffer) {
	[(__bridge TGMusicStreamer *)clientData bufferFinished:buffer];
}

@implementation TGMusicStreamer

- (instancetype)initWithDelegate:(id<TGMusicStreamerDelegate>)delegate {
	if ((self = [super init])){
		_delegate = delegate;
		_pending = [NSMutableArray array];
		_playing = YES;
		_expectedSize = 0;
	}
	return self;
}

- (void)dealloc {
	[self stop];
}

#pragma mark - input

- (BOOL)feedFileAtPath:(NSString *)path
		downloadedSize:(long long)downloadedSize
		  expectedSize:(long long)expectedSize
			  complete:(BOOL)complete {
	if (_failed || _finished)
		return NO;

	if (!_stream){
		// iOS 6's parser does not always sniff a bare MP3 stream from an
		// unknown hint, so name the container when the extension does.
		AudioFileTypeID hint = 0;
		NSString *extension = path.pathExtension.lowercaseString;
		if ([extension isEqualToString:@"mp3"])
			hint = kAudioFileMP3Type;
		else if ([extension isEqualToString:@"m4a"] || [extension isEqualToString:@"aac"])
			hint = kAudioFileM4AType;
		OSStatus status = AudioFileStreamOpen((__bridge void *)self,
				TGMusicStreamerPropertyCallback, TGMusicStreamerPacketCallback,
				hint, &_stream);
		if (status != noErr){
			[self failWithStatus:status text:@"AudioFileStreamOpen failed"];
			return NO;
		}
	}
	if (!_file && path.length){
		_file = [NSFileHandle fileHandleForReadingAtPath:path];
		if (!_file){
			[self failWithStatus:-1 text:@"cannot open the partial file"];
			return NO;
		}
	}
	if (!_file)
		return YES;

	_downloadedSize = downloadedSize;
	if (expectedSize > 0)
		_expectedSize = expectedSize;

	// Catch up in chunks; a poll may arrive after more than one chunk has
	// landed, and reading it all keeps playback close to the download.
	while (_readOffset < _downloadedSize && !_failed){
		long long remaining = _downloadedSize - _readOffset;
		NSUInteger length = (NSUInteger)MIN(remaining, kTGMusicReadChunk);
		NSData *data = nil;
		@try {
			[_file seekToFileOffset:(unsigned long long)_readOffset];
			data = [_file readDataOfLength:length];
		} @catch (NSException *exception) {
			[self failWithStatus:-1 text:exception.reason ?: @"cannot read the partial file"];
			return NO;
		}
		if (!data.length)
			break;
		_readOffset += (long long)data.length;

		UInt32 flags = _nextParseFlags;
		_nextParseFlags = 0;
		NSUInteger before = _packetCount;
		OSStatus status = AudioFileStreamParseBytes(_stream, (UInt32)data.length,
				data.bytes, flags);
		if (status != noErr){
			// iOS 6 reports an unspecified error after the packets of a
			// chunk that ends mid-frame, where newer parsers say "more data
			// needed". The packets are already delivered, so keep them and
			// carry on with the next chunk.
			if (status == kAudioFileStreamError_UnspecifiedError && _packetCount > before){
				NSLog(@"music: parser stopped at a chunk edge (%u packets kept)",
						(unsigned)(_packetCount - before));
			} else {
				[self failWithStatus:status text:@"AudioFileStreamParseBytes failed"];
				return NO;
			}
		}
		if (_formatReady && !_queue)
			[self createQueue];
	}

	if (_formatReady && !_queue)
		[self createQueue];
	if (complete){
		_inputComplete = YES;
		if (_downloadedSize > 0)
			_expectedSize = _downloadedSize;
	}
	[self fillBuffers];
	[self finishIfDrained];
	return YES;
}

#pragma mark - parser callbacks

- (void)propertyChanged:(AudioFileStreamPropertyID)property {
	UInt32 size = 0;
	OSStatus status = AudioFileStreamGetPropertyInfo(_stream, property, &size, NULL);

	if (property == kAudioFileStreamProperty_DataFormat && status == noErr &&
		size == sizeof(AudioStreamBasicDescription)){
		AudioStreamBasicDescription format;
		if (AudioFileStreamGetProperty(_stream, property, &size, &format) == noErr){
			_format = format;
			_packetDuration = (_format.mSampleRate > 0 && _format.mFramesPerPacket > 0)
					? (NSTimeInterval)_format.mFramesPerPacket / _format.mSampleRate : 0;
			[self updateDuration];
		}
		return;
	}

	if (property == kAudioFileStreamProperty_MagicCookieData && status == noErr && size > 0){
		void *cookie = malloc(size);
		if (cookie && AudioFileStreamGetProperty(_stream, property, &size, cookie) == noErr)
			_magicCookie = [NSData dataWithBytes:cookie length:size];
		if (cookie)
			free(cookie);
		return;
	}

	if (property == kAudioFileStreamProperty_BitRate && status == noErr && size == sizeof(UInt32)){
		UInt32 rate = 0;
		if (AudioFileStreamGetProperty(_stream, property, &size, &rate) == noErr)
			_bitRate = rate > 0 && rate < 10000 ? rate * 1000.0 : rate;
		[self updateDuration];
		return;
	}

	if (property == kAudioFileStreamProperty_AudioDataByteCount && status == noErr &&
		size == sizeof(UInt64)){
		UInt64 bytes = 0;
		if (AudioFileStreamGetProperty(_stream, property, &size, &bytes) == noErr)
			_audioDataByteCount = (NSTimeInterval)bytes;
		[self updateDuration];
		return;
	}

	if (property == kAudioFileStreamProperty_ReadyToProducePackets){
		// The queue is created after ParseBytes returns: making one from
		// inside the parser callback re-enters CoreAudio on iOS 6 and the
		// parse then fails with an unspecified error.
		_formatReady = YES;
	}
}

- (void)updateDuration {
	if (_format.mSampleRate <= 0){
		_duration = 0;
		return;
	}
	if (_bitRate > 0 && _audioDataByteCount > 0){
		_duration = _audioDataByteCount * 8.0 / _bitRate;
	} else if (_packetDuration > 0 && _expectedSize > 0 && _format.mBytesPerPacket > 0){
		// A rough fallback for CBR data whose byte count has not arrived yet.
		_duration = ((NSTimeInterval)_expectedSize / _format.mBytesPerPacket) * _packetDuration;
	} else {
		_duration = 0;
	}
}

- (void)packetsParsed:(UInt32)numBytes packets:(UInt32)numPackets
				 data:(const void *)inputData
		 descriptions:(AudioStreamPacketDescription *)packetDescriptions {
	if (!numPackets || !inputData)
		return;
	_packetCount += numPackets;

	const uint8_t *bytes = (const uint8_t *)inputData;
	UInt32 defaultSize = numPackets ? numBytes / numPackets : 0;
	for (UInt32 i = 0; i < numPackets; i++){
		TGMusicPacket *packet = [[TGMusicPacket alloc] init];
		AudioStreamPacketDescription description;
		if (packetDescriptions){
			description = packetDescriptions[i];
			packet.hasDescription = YES;
		} else {
			description.mStartOffset = 0;
			description.mDataByteSize = defaultSize;
			description.mVariableFramesInPacket = 0;
			packet.hasDescription = NO;
		}
		if (description.mDataByteSize == 0 ||
			description.mStartOffset + description.mDataByteSize > numBytes)
			continue;
		packet.data = [NSData dataWithBytes:bytes + description.mStartOffset
									 length:description.mDataByteSize];
		packet.packetDescription = description;
		[_pending addObject:packet];
	}
	[self fillBuffers];
}

#pragma mark - audio queue

- (BOOL)createQueue {
	if (_queue || _format.mSampleRate <= 0 || _format.mFormatID == 0)
		return NO;

	// Playback, not ambient: the queue has to keep going with the screen off.
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
	[[AVAudioSession sharedInstance] setActive:YES error:nil];
	OSStatus status = AudioQueueNewOutput(&_format, TGMusicStreamerBufferCallback,
			(__bridge void *)self, CFRunLoopGetMain(), kCFRunLoopCommonModes, 0, &_queue);
	if (status != noErr){
		[self failWithStatus:status text:@"AudioQueueNewOutput failed"];
		return NO;
	}

	if (_magicCookie.length){
		AudioQueueSetProperty(_queue, kAudioQueueProperty_MagicCookie,
				_magicCookie.bytes, (UInt32)_magicCookie.length);
	}

	// Big enough for a few seconds of a normal track; the packet packing
	// splits anything larger across buffers.
	UInt32 bufferSize = 64 * 1024;
	for (int i = 0; i < kTGMusicBuffers; i++){
		AudioQueueAllocateBuffer(_queue, bufferSize, &_buffers[i]);
		_bufferBusy[i] = NO;
		_descriptions[i] = NULL;
	}
	_volume = _volume ?: 1.0f;
	[self applyVolume];
	NSLog(@"music: streaming ready %.0f Hz %.1f s", _format.mSampleRate, _duration);
	[self fillBuffers];
	return YES;
}

- (void)applyVolume {
	if (!_queue)
		return;
	Float32 value = MIN(MAX(_volume, 0.0f), 1.0f);
	AudioQueueSetParameter(_queue, kAudioQueueParam_Volume, value);
}

- (void)setVolume:(float)volume {
	_volume = MIN(MAX(volume, 0.0f), 1.0f);
	[self applyVolume];
}

- (NSInteger)freeBuffer {
	for (int i = 0; i < kTGMusicBuffers; i++)
		if (!_bufferBusy[i])
			return i;
	return -1;
}

/// Packs pending packets into whichever queue buffers are free. A packet that
/// does not fit starts the next buffer; one larger than any buffer gets a
/// buffer of its own.
- (void)fillBuffers {
	if (!_queue)
		return;
	NSInteger index = [self freeBuffer];
	while (index >= 0 && _pending.count){
		AudioQueueBufferRef buffer = _buffers[index];
		UInt32 capacity = buffer->mAudioDataBytesCapacity;
		UInt32 used = 0;
		UInt32 count = 0;
		NSMutableData *descriptions = [NSMutableData data];

		while (_pending.count){
			TGMusicPacket *packet = _pending[0];
			UInt32 packetSize = (UInt32)packet.data.length;
			if (used + packetSize > capacity){
				if (count == 0){
					// A single packet above the buffer: allocate a larger one
					// and restart this fill with it.
					AudioQueueFreeBuffer(_queue, buffer);
					if (AudioQueueAllocateBuffer(_queue, packetSize + 16, &buffer) != noErr){
						[self failWithStatus:-1 text:@"AudioQueueAllocateBuffer failed"];
						return;
					}
					_buffers[index] = buffer;
					capacity = buffer->mAudioDataBytesCapacity;
				} else {
					break;
				}
			}
			memcpy((uint8_t *)buffer->mAudioData + used, packet.data.bytes, packetSize);
			if (packet.hasDescription){
				AudioStreamPacketDescription description = packet.packetDescription;
				description.mStartOffset = used;
				[descriptions appendBytes:&description length:sizeof(description)];
				count++;
			}
			used += packetSize;
			[_pending removeObjectAtIndex:0];
		}

		if (used == 0)
			break;

		buffer->mAudioDataByteSize = used;
		AudioStreamPacketDescription *copies = NULL;
		if (count > 0){
			copies = malloc(count * sizeof(*copies));
			memcpy(copies, descriptions.bytes, count * sizeof(*copies));
			_descriptions[index] = copies;
		} else {
			_descriptions[index] = NULL;
		}

		_bufferBusy[index] = YES;
		_inFlight++;
		OSStatus status = AudioQueueEnqueueBuffer(_queue, buffer, count, copies);
		if (status != noErr){
			_bufferBusy[index] = NO;
			_inFlight--;
			[self failWithStatus:status text:@"AudioQueueEnqueueBuffer failed"];
			return;
		}
		if (_playing && !_playedAnything){
			OSStatus started = AudioQueueStart(_queue, NULL);
			if (started != noErr)
				NSLog(@"music: AudioQueueStart failed %d", (int)started);
			_playedAnything = YES;
		}
		index = [self freeBuffer];
	}
}

- (void)bufferFinished:(AudioQueueBufferRef)buffer {
	if (!_queue)
		return;
	for (int i = 0; i < kTGMusicBuffers; i++){
		if (_buffers[i] != buffer)
			continue;
		if (_descriptions[i]){
			free(_descriptions[i]);
			_descriptions[i] = NULL;
		}
		_bufferBusy[i] = NO;
		if (_inFlight > 0)
			_inFlight--;
		break;
	}
	[self fillBuffers];
	[self finishIfDrained];
}

- (void)finishIfDrained {
	if (_finished || _failed || !_inputComplete)
		return;
	if (_pending.count || _inFlight > 0)
		return;
	if (!_playedAnything)
		return;
	_finished = YES;
	_playing = NO;
	NSLog(@"music: streaming finished");
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate musicStreamerDidFinish:self];
	});
}

#pragma mark - transport

- (BOOL)ready {
	return _formatReady && _queue != NULL;
}

- (BOOL)isPlaying {
	return _playing;
}

- (void)play {
	if (_finished || _failed)
		return;
	_playing = YES;
	if (_queue){
		if (_playedAnything)
			AudioQueueStart(_queue, NULL);
		else
			[self fillBuffers];
	}
}

- (void)pause {
	_playing = NO;
	if (_queue)
		AudioQueuePause(_queue);
}

- (NSTimeInterval)duration {
	return _duration;
}

- (NSTimeInterval)position {
	if (!_queue || !_playedAnything)
		return _baseTime;
	AudioTimeStamp stamp;
	memset(&stamp, 0, sizeof(stamp));
	if (AudioQueueGetCurrentTime(_queue, NULL, &stamp, NULL) != noErr)
		return _baseTime;
	NSTimeInterval played = _format.mSampleRate > 0
			? stamp.mSampleTime / _format.mSampleRate : 0;
	NSTimeInterval position = _baseTime + MAX(0.0, played);
	if (_duration > 0)
		position = MIN(position, _duration);
	return position;
}

- (void)seekToFraction:(CGFloat)fraction {
	if (!_formatReady || !_stream || _duration <= 0 || _packetDuration <= 0)
		return;
	_finished = NO;
	fraction = MIN(MAX(fraction, 0.0f), 1.0f);

	SInt64 targetPacket = (SInt64)((fraction * _duration) / _packetDuration);
	SInt64 byteOffset = 0;
	UInt32 flags = 0;
	OSStatus status = AudioFileStreamSeek(_stream, targetPacket, &byteOffset, &flags);
	if (status != noErr)
		return;
	// Never read before the file has arrived; if the seek point is still
	// ahead of the download, stay where playback is instead of going silent.
	if (byteOffset > _downloadedSize){
		SInt64 previousPacket = _packetDuration > 0
				? (SInt64)([self position] / _packetDuration) : 0;
		SInt64 back = 0;
		UInt32 backFlags = 0;
		if (AudioFileStreamSeek(_stream, previousPacket, &back, &backFlags) == noErr){
			[_pending removeAllObjects];
			[self resetQueue];
			_baseTime = MAX(0.0, (NSTimeInterval)previousPacket * _packetDuration);
			_readOffset = back;
			_nextParseFlags = kAudioFileStreamParseFlag_Discontinuity;
		}
		return;
	}

	[_pending removeAllObjects];
	[self resetQueue];
	_baseTime = MAX(0.0, (NSTimeInterval)targetPacket * _packetDuration);
	_readOffset = byteOffset;
	_nextParseFlags = kAudioFileStreamParseFlag_Discontinuity;

	// The bytes between the seek point and the download head are parsed on
	// the next poll; one immediate pass makes the seek feel instant.
	if (_file && _readOffset < _downloadedSize){
		NSData *data = nil;
		@try {
			[_file seekToFileOffset:(unsigned long long)_readOffset];
			data = [_file readDataOfLength:(NSUInteger)MIN(_downloadedSize - _readOffset,
					kTGMusicReadChunk)];
		} @catch (NSException *exception) {
			data = nil;
		}
		if (data.length){
			_readOffset += (long long)data.length;
			UInt32 parseFlags = _nextParseFlags;
			_nextParseFlags = 0;
			AudioFileStreamParseBytes(_stream, (UInt32)data.length, data.bytes, parseFlags);
		}
	}
	[self fillBuffers];
}

- (void)resetQueue {
	for (int i = 0; i < kTGMusicBuffers; i++){
		if (_descriptions[i]){
			free(_descriptions[i]);
			_descriptions[i] = NULL;
		}
		_bufferBusy[i] = NO;
	}
	_inFlight = 0;
	_playedAnything = NO;
	if (_queue){
		AudioQueueStop(_queue, true);
		AudioQueueDispose(_queue, true);
		_queue = NULL;
	}
	memset(_buffers, 0, sizeof(_buffers));
	if (_formatReady && !_finished)
		[self createQueue];
}

- (void)stop {
	_finished = YES;
	_playing = NO;
	[self resetQueue];
	if (_stream){
		AudioFileStreamClose(_stream);
		_stream = NULL;
	}
	[_file closeFile];
	_file = nil;
	[_pending removeAllObjects];
	_magicCookie = nil;
}


- (void)failWithStatus:(OSStatus)status text:(NSString *)text {
	if (_failed)
		return;
	_failed = YES;
	_playing = NO;
	NSLog(@"music: streamer failed: %@ (%d)", text, (int)status);
	NSDictionary *info = @{NSLocalizedDescriptionKey : text ?: @"music streaming failed"};
	NSError *error = [NSError errorWithDomain:@"TGMusicStreamer"
										 code:status userInfo:info];
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate musicStreamer:self didFail:error];
	});
}

@end

// vim:ft=objc
