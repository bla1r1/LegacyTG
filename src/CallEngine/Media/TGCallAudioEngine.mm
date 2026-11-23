#import "TGCallAudioEngine.h"
#import "TGCallPlayout.h"
#import "TGLocklessRingBuffer.hpp"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <opus/opus.h>

enum {
	kSampleRate    = 48000,
	kChannels      = 1,
	// 60 ms a packet, as the official client sends: each packet carries ~60
	// bytes of IP, UDP, SRTP and reflector headers, which at 20 ms was as
	// much as the voice itself (24 kbit/s) on a 3G uplink.
	kFrameSamples  = 2880,
	kPCMBufferSize = 2880 * sizeof(int16_t)
};

static const char *kMorseSOS = "10101000" "11101110111000" "10101000" "0000";
static const float kToneHz        = 800.0f;
static const float kToneAmplitude = 7000.0f;
static const int   kUnitsPerSecond = 8;

#include <pthread.h>
#import "TGDevice.h"

#if TG_DEV
#include <mach/mach.h>
/// Per-thread CPU every 10 s of a call, in dev builds: the A4 has one core
/// and a call is a fight for it.
static void TGLogThreadCPU(void) {
	thread_act_array_t threads;
	mach_msg_type_number_t count = 0;
	if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS)
		return;
	NSMutableString *line = [NSMutableString string];
	int total = 0;
	for (mach_msg_type_number_t i = 0; i < count; i++){
		thread_basic_info_data_t info;
		mach_msg_type_number_t n = THREAD_BASIC_INFO_COUNT;
		if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)&info, &n) == KERN_SUCCESS){
			int cpu = info.cpu_usage * 100 / TH_USAGE_SCALE;
			total += cpu;
			if (cpu >= 3){
				char name[64] = "";
				pthread_t pt = pthread_from_mach_thread_np(threads[i]);
				if (pt)
					pthread_getname_np(pt, name, sizeof(name));
				thread_extended_info_data_t ext;
				mach_msg_type_number_t en = THREAD_EXTENDED_INFO_COUNT;
				int prio = thread_info(threads[i], THREAD_EXTENDED_INFO, (thread_info_t)&ext, &en) == KERN_SUCCESS
					? ext.pth_curpri : -1;
				[line appendFormat:@" [%s p%d %d%%]", name[0] ? name : "?", prio, cpu];
			}
		}
		mach_port_deallocate(mach_task_self(), threads[i]);
	}
	vm_deallocate(mach_task_self(), (vm_address_t)threads, sizeof(thread_t) * count);
	NSLog(@"TGCallAudioEngine: cpu %d%%:%@", total, line);
}
#endif

static int TGFrameLevel(const int16_t *pcm, int count) {
	double sum = 0;
	for (int i = 0; i < count; i++)
		sum += (double)pcm[i] * (double)pcm[i];
	return (int)sqrt(sum / (count > 0 ? count : 1));
}

@interface TGCallAudioEngine () {
	OpusDecoder *_decoder;
	OpusEncoder *_encoder;

    AudioComponentInstance _audioUnit;
	BOOL _running;

	NSMutableData *_inputPCMBuffer;
	// The unit's thread only copies: microphone samples into _micRing for the
	// encoder thread, decoded samples out of _speakerRing that the decoder
	// thread keeps filled. Opus, SRTP and sendto on that thread overran its
	// ~23 ms cycle on the iPod touch 4: the unit skipped 63 of ~430 cycles in
	// 10 s, so 60% of the call went missing both ways - the crackle, and the
	// playout delay stuck at its 400 ms ceiling.
	TGLocklessRingBuffer<int16_t, 16384> _micRing;
	TGLocklessRingBuffer<int16_t, 16384> _speakerRing;
	dispatch_semaphore_t _micReady, _speakerWanted;
	volatile BOOL _workersRun;
	pthread_t _encodeThread, _decodeThread;
	TGJitter *_jitter;
	TGExpand _expand;
	unsigned _underruns;
	uint16_t _loopbackSeq;
	int _lossPercent, _appliedLossPercent;   // capture thread applies
	// Every 10 s, from the unit's thread: samples each way and cycles the unit
	// skipped. 48000/s and 0 is a call keeping real time.
	double _rateStart, _lastSampleTime;
	uint64_t _rateMic, _rateSpeaker;
	unsigned _skips;
	uint32_t _loopbackTimestamp;

	uint64_t _outSamples;
	float _tonePhase;
	int _outFrames, _micLevelSum, _sentLevelSum;
	int _inFrames, _inLevelSum;
}

- (OSStatus)renderPlayback:(AudioBufferList *)ioData numFrames:(UInt32)numFrames;
- (void)decodeLoop;
- (void)encodeLoop;
- (OSStatus)renderRecord:(AudioUnitRenderActionFlags *)ioActionFlags
               timeStamp:(const AudioTimeStamp *)inTimeStamp
               busNumber:(UInt32)inBusNumber
               numFrames:(UInt32)inNumberFrames;

@end

static OSStatus TGPlaybackCallback(void *inRefCon,
                                   AudioUnitRenderActionFlags *ioActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList *ioData) {
    TGCallAudioEngine *engine = (__bridge TGCallAudioEngine *)inRefCon;
    return [engine renderPlayback:ioData numFrames:inNumberFrames];
}

static OSStatus TGRecordCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    TGCallAudioEngine *engine = (__bridge TGCallAudioEngine *)inRefCon;
    return [engine renderRecord:ioActionFlags timeStamp:inTimeStamp busNumber:inBusNumber numFrames:inNumberFrames];
}

@implementation TGCallAudioEngine

- (instancetype)init {
	if ((self = [super init])) {
		_inputPCMBuffer = [NSMutableData data];
	}
	return self;
}

- (BOOL)isRunning {
	return _running;
}

- (OSStatus)renderPlayback:(AudioBufferList *)ioData numFrames:(UInt32)numFrames {
    if (!_running) {
        memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
        return noErr;
    }

	_rateSpeaker += numFrames;
	int16_t *outPCM = (int16_t *)ioData->mBuffers[0].mData;
	size_t got = _speakerRing.read(outPCM, numFrames);
	if (got < numFrames){
		memset(outPCM + got, 0, (numFrames - got) * sizeof(int16_t));
		_underruns++;
	}
	dispatch_semaphore_signal(_speakerWanted);
	return noErr;
}

/// Kept ~80 ms ahead of the unit: one 60 ms packet decodes at a time, a
/// slice is up to ~46 ms, and the rest is slack for a busy CPU.
static const size_t kSpeakerAhead = 3840;

static void *TGDecodeThread(void *context) {
	TGCallAudioEngine *engine = (__bridge TGCallAudioEngine *)context;
	pthread_setname_np("tg.call.decode");
	[engine decodeLoop];
	return NULL;
}

static void *TGEncodeThread(void *context) {
	TGCallAudioEngine *engine = (__bridge TGCallAudioEngine *)context;
	pthread_setname_np("tg.call.encode");
	[engine encodeLoop];
	return NULL;
}

- (void)decodeLoop {
	int16_t pcm[5760];
	while (_workersRun){
		@autoreleasepool {
			while (_workersRun && _speakerRing.available_read() < kSpeakerAhead){
				size_t n = [self decodeNextInto:pcm];
				_speakerRing.write(pcm, n);
			}
		}
		dispatch_semaphore_wait(_speakerWanted, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC));
	}
}

- (void)encodeLoop {
	int16_t pcm[2048];
	while (_workersRun){
		dispatch_semaphore_wait(_micReady, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC));
		@autoreleasepool {
			size_t n;
			while ((n = _micRing.read(pcm, 2048)) > 0)
				[self processCapturedPCM:pcm length:(UInt32)(n * sizeof(int16_t))];
		}
	}
}

/// Started real-time-ish: above the network and UI threads, below the unit's.
- (void)startWorkers {
	_workersRun = YES;
	_micReady = dispatch_semaphore_create(0);
	_speakerWanted = dispatch_semaphore_create(0);
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	struct sched_param param = { .sched_priority = 45 };
	// Without EXPLICIT_SCHED the policy and priority below are ignored and
	// the threads inherit the caller's: the decoder then lost to video
	// encode and decode on the A4 and the speaker ran dry 11-13 times in 10 s.
	pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
	pthread_attr_setschedpolicy(&attr, SCHED_RR);
	pthread_attr_setschedparam(&attr, &param);
	pthread_create(&_decodeThread, &attr, TGDecodeThread, (__bridge void *)self);
	pthread_create(&_encodeThread, &attr, TGEncodeThread, (__bridge void *)self);
	pthread_attr_destroy(&attr);
}

- (void)stopWorkers {
	if (!_workersRun)
		return;
	_workersRun = NO;
	dispatch_semaphore_signal(_micReady);
	dispatch_semaphore_signal(_speakerWanted);
	pthread_join(_encodeThread, NULL);
	pthread_join(_decodeThread, NULL);
}

/// One step of playout. Decoding here and not on arrival is what lets a
/// lost packet be rebuilt from the one after it.
- (size_t)decodeNextInto:(int16_t *)out {
	TGJitterAction action;
	int samples = TGPlayoutStep(_jitter, _decoder, &_expand, out, &action);
	if (action == TGJitterPlay){
		_inLevelSum += TGFrameLevel(out, samples);
		if (++_inFrames >= 50){
			TGJitterStats stats = TGJitterGetStats(_jitter);
			NSLog(@"TGCallAudioEngine: incoming level %d, delay %d ms, fec %u, concealed %u, late %u",
					_inLevelSum / _inFrames, TGJitterTargetMs(_jitter), stats.fec, stats.concealed, stats.late);
			_inFrames = _inLevelSum = 0;
		}
	}
	return (size_t)samples;
}
- (OSStatus)renderRecord:(AudioUnitRenderActionFlags *)ioActionFlags
               timeStamp:(const AudioTimeStamp *)inTimeStamp
               busNumber:(UInt32)inBusNumber
               numFrames:(UInt32)inNumberFrames {
    
    if (!_running) return noErr;
    
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = kChannels;
    
    int16_t buffer[inNumberFrames * kChannels];
    bufferList.mBuffers[0].mData = buffer;
    bufferList.mBuffers[0].mDataByteSize = inNumberFrames * sizeof(int16_t);
    
    OSStatus status = AudioUnitRender(_audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
    if (status != noErr)
        return status;

    _rateMic += inNumberFrames;
    if (inTimeStamp->mFlags & kAudioTimeStampSampleTimeValid) {
        if (_lastSampleTime > 0 && inTimeStamp->mSampleTime - _lastSampleTime > inNumberFrames * 1.5)
            _skips++;
        _lastSampleTime = inTimeStamp->mSampleTime;
    }
    double elapsed = [NSProcessInfo processInfo].systemUptime - _rateStart;
    if (_rateStart > 0 && elapsed > 10) {
        NSLog(@"TGCallAudioEngine: %.0f samples/s in, %.0f out, %u cycles skipped, %u speaker underruns",
              _rateMic / elapsed, _rateSpeaker / elapsed, _skips, _underruns);
        _rateStart += elapsed;
        _rateMic = _rateSpeaker = 0;
        _skips = _underruns = 0;
#if TG_DEV
        TGLogThreadCPU();
#endif
    }
    if (bufferList.mBuffers[0].mDataByteSize > 0) {
        _micRing.write((const int16_t *)bufferList.mBuffers[0].mData,
                       bufferList.mBuffers[0].mDataByteSize / sizeof(int16_t));
        dispatch_semaphore_signal(_micReady);
    }
    return noErr;
}

- (BOOL)start {
	if (_running) return YES;

	int err = 0;
	_decoder = opus_decoder_create(kSampleRate, kChannels, &err);
	if (err != OPUS_OK || !_decoder) return NO;

	_encoder = opus_encoder_create(kSampleRate, kChannels, OPUS_APPLICATION_VOIP, &err);
	if (err != OPUS_OK || !_encoder) {
		opus_decoder_destroy(_decoder);
		return NO;
	}
	opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(24000));
	// The single-core A4 spends 37% of itself encoding at 5 and 29% at 3
	// (iPod touch 4, a 60 ms packet every 60 ms); a 16 kHz band cap saved
	// nothing more.
	opus_encoder_ctl(_encoder, OPUS_SET_COMPLEXITY([TGDevice tier] <= TGDeviceTierVintage ? 3 : 5));
	opus_encoder_ctl(_encoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
	// The official decoder rebuilds a lost frame from the copy in the next
	// one, as we do; the copy is only written when loss is expected.
	opus_encoder_ctl(_encoder, OPUS_SET_INBAND_FEC(1));
	opus_encoder_ctl(_encoder, OPUS_SET_PACKET_LOSS_PERC(10));
	_jitter = TGJitterCreate();
	TGExpandInit(&_expand);
	_micRing.clear();
	_speakerRing.clear();

    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) {
        NSLog(@"TGCallAudioEngine: failed to find VoiceProcessingIO");
        return NO;
    }

    OSStatus status = AudioComponentInstanceNew(comp, &_audioUnit);
    if (status != noErr) {
        NSLog(@"TGCallAudioEngine: failed to create VoiceProcessingIO instance");
        return NO;
    }

    UInt32 enableIO = 1;
    AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, sizeof(enableIO));
    AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableIO, sizeof(enableIO));

    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate       = kSampleRate;
    format.mFormatID         = kAudioFormatLinearPCM;
    format.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBytesPerPacket   = sizeof(int16_t);
    format.mFramesPerPacket  = 1;
    format.mBytesPerFrame    = sizeof(int16_t);
    format.mChannelsPerFrame = kChannels;
    format.mBitsPerChannel   = 16;

    AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format, sizeof(format));
    AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format, sizeof(format));
    // Room for a slice of up to ~85 ms: the default is 1024 frames, and a
    // unit whose hardware cycle is longer than that drops the rest.
    UInt32 maxFrames = 4096;
    AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, sizeof(maxFrames));

    AURenderCallbackStruct renderCb;
    renderCb.inputProc = TGPlaybackCallback;
    renderCb.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCb, sizeof(renderCb));

    AURenderCallbackStruct recordCb;
    recordCb.inputProc = TGRecordCallback;
    recordCb.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &recordCb, sizeof(recordCb));

    status = AudioUnitInitialize(_audioUnit);
    if (status != noErr) {
        NSLog(@"TGCallAudioEngine: AudioUnitInitialize failed");
        return NO;
    }

    status = AudioOutputUnitStart(_audioUnit);
    if (status != noErr) {
        NSLog(@"TGCallAudioEngine: AudioOutputUnitStart failed");
        return NO;
    }

	_running = YES;
	[self startWorkers];
	NSLog(@"TGCallAudioEngine: started VoiceProcessingIO, session %.0f Hz",
	      [AVAudioSession sharedInstance].sampleRate);
	_rateStart = [NSProcessInfo processInfo].systemUptime;
	_rateMic = _rateSpeaker = 0;
	_lastSampleTime = 0;
	return YES;
}

- (void)handleIncomingOpusFrame:(NSData *)opusFrame {
	[self handleIncomingOpusBytes:(const uint8_t *)opusFrame.bytes length:opusFrame.length
						 sequence:_loopbackSeq++ timestamp:(_loopbackTimestamp += 960)];
}

- (void)handleIncomingOpusBytes:(const uint8_t *)bytes length:(size_t)length
					   sequence:(uint16_t)sequence timestamp:(uint32_t)timestamp {
	if (!_running || !_jitter || !bytes || length == 0)
		return;
	int samples = opus_packet_get_nb_samples(bytes, (opus_int32)length, kSampleRate);
	TGJitterPut(_jitter, sequence, timestamp, samples, bytes, length,
				(int64_t)([NSProcessInfo processInfo].systemUptime * 1000.0));
}

- (void)processCapturedPCM:(const int16_t *)pcm length:(UInt32)bytesLength {
	if (!_running || !_encoder)
		return;

	[_inputPCMBuffer appendBytes:pcm length:bytesLength];

	while (_inputPCMBuffer.length >= kPCMBufferSize) {
		int16_t framePCM[kFrameSamples];
		memcpy(framePCM, _inputPCMBuffer.bytes, kPCMBufferSize);

		int micLevel = TGFrameLevel(framePCM, kFrameSamples);

		if (self.emitMorseSignal) {
			const uint32_t samplesPerUnit = kSampleRate / kUnitsPerSecond;
			const size_t units = strlen(kMorseSOS);
			const float phaseInc = 2.0f * M_PI * kToneHz / (float)kSampleRate;

			for (int i = 0; i < kFrameSamples; i++) {
				BOOL on = kMorseSOS[((_outSamples + i) / samplesPerUnit) % units] == '1';
				_tonePhase += phaseInc;
				if (_tonePhase >= 2.0f * M_PI)
					_tonePhase -= 2.0f * M_PI;
				if (!on)
					continue;
				int32_t mixed = (int32_t)framePCM[i] + (int32_t)(sinf(_tonePhase) * kToneAmplitude);
				if (mixed > 32767)  mixed = 32767;
				if (mixed < -32768) mixed = -32768;
				framePCM[i] = (int16_t)mixed;
			}
		}
		_outSamples += kFrameSamples;

		_micLevelSum += micLevel;
		_sentLevelSum += TGFrameLevel(framePCM, kFrameSamples);
		if (++_outFrames >= 17) {
			NSLog(@"TGCallAudioEngine: mic level %d, sending level %d", _micLevelSum / _outFrames, _sentLevelSum / _outFrames);
			_outFrames = _micLevelSum = _sentLevelSum = 0;
		}

		int loss = _lossPercent;
		if (loss && loss != _appliedLossPercent){
			opus_encoder_ctl(_encoder, OPUS_SET_PACKET_LOSS_PERC(loss));
			_appliedLossPercent = loss;
		}
		uint8_t opusOut[1275];
		int encodedBytes = opus_encode(_encoder, framePCM, kFrameSamples, opusOut, sizeof(opusOut));
		if (encodedBytes > 0) {
			NSData *opusFrame = [NSData dataWithBytes:opusOut length:encodedBytes];
			if (self.onOutgoingOpusFrame) {
				self.onOutgoingOpusFrame(opusFrame);
			}
			if (self.loopbackToSpeaker) {
				[self handleIncomingOpusFrame:opusFrame];
			}
		}
		[_inputPCMBuffer replaceBytesInRange:NSMakeRange(0, kPCMBufferSize) withBytes:NULL length:0];
	}
}

- (void)peerReportedLoss:(uint8_t)fraction {
	_lossPercent = TGOpusLossPercent(fraction);
}

- (void)stop {
	_running = NO;

    if (_audioUnit) {
        AudioOutputUnitStop(_audioUnit);
        AudioUnitUninitialize(_audioUnit);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
    }
	[self stopWorkers];

	if (_decoder) {
		opus_decoder_destroy(_decoder);
		_decoder = NULL;
	}

	if (_encoder) {
		opus_encoder_destroy(_encoder);
		_encoder = NULL;
	}

	[_inputPCMBuffer setLength:0];
	TGJitterFree(_jitter);
	_jitter = NULL;
	NSLog(@"TGCallAudioEngine: stopped");
}

@end
