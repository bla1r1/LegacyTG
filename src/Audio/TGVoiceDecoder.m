//
// TGVoiceDecoder - decodes Ogg Opus voice notes to 16-bit PCM WAV for AVAudioPlayer.
//
#import "TGVoiceDecoder.h"
#if __has_include(<ogg/ogg.h>) || TARGET_OS_IPHONE
#include "opusfile/opusfile.h"
#else
typedef struct OggOpusFile OggOpusFile;
typedef int16_t opus_int16;
extern OggOpusFile *op_open_file(const char *_path, int *_error);
extern int op_read_stereo(OggOpusFile *_of, opus_int16 *_pcm, int _buf_size);
extern void op_free(OggOpusFile *_of);
#endif
#include <stdio.h>
#include <string.h>

static const uint32_t kTGVoiceMaxDecodedBytes = 64 * 1024 * 1024;

/// Little-endian writers - WAV headers are LE regardless of the host.
static void put32(unsigned char *p, uint32_t v) {
	p[0] = v & 0xff; p[1] = (v >> 8) & 0xff;
	p[2] = (v >> 16) & 0xff; p[3] = (v >> 24) & 0xff;
}
static void put16(unsigned char *p, uint16_t v) {
	p[0] = v & 0xff; p[1] = (v >> 8) & 0xff;
}

@implementation TGVoiceDecoder

+ (NSString *)wavFromOpusFile:(NSString *)opusPath {
	if (!opusPath.length)
		return nil;

	// Refuse files that do not exist, are empty, or lack the Ogg container magic.
	FILE *checkFp = fopen(opusPath.UTF8String, "rb");
	if (!checkFp)
		return nil;
	char magic[4] = {0};
	size_t readMagic = fread(magic, 1, 4, checkFp);
	fclose(checkFp);
	if (readMagic < 4 || memcmp(magic, "OggS", 4) != 0)
		return nil;

	int err = 0;
	OggOpusFile *of = op_open_file(opusPath.UTF8String, &err);
	if (!of){
		NSLog(@"TGVoiceDecoder: op_open_file failed (%d)", err);
		return nil;
	}

	// opusfile always decodes to 48kHz; ask for stereo so the frame size is
	// fixed at 2 channels regardless of what the file carries.
	const int rate = 48000;
	const int channels = 2;

	NSString *out = [NSTemporaryDirectory() stringByAppendingPathComponent:@"voice.wav"];
	FILE *fp = fopen(out.UTF8String, "wb+");
	if (!fp) {
		NSLog(@"TGVoiceDecoder: cannot create %@", out);
		op_free(of);
		return nil;
	}

	// 44-byte placeholder header
	unsigned char header[44] = {0};
	if (fwrite(header, 1, sizeof(header), fp) != sizeof(header)) {
		NSLog(@"TGVoiceDecoder: failed to write header placeholder");
		fclose(fp);
		[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
		op_free(of);
		return nil;
	}

	opus_int16 buffer[1920 * 2];   // 40ms at 48kHz, stereo (<8 KB stack buffer)
	uint32_t totalBytesWritten = 0;
	NSUInteger loopCount = 0;

	for (;;){
		if (++loopCount > 200000) {
			fclose(fp);
			[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
			op_free(of);
			return nil;
		}

		int samples = op_read_stereo(of, buffer, (int)(sizeof(buffer) / sizeof(buffer[0])));
		if (samples < 0){
			NSLog(@"TGVoiceDecoder: op_read_stereo failed (%d)", samples);
			fclose(fp);
			[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
			op_free(of);
			return nil;
		}
		if (samples == 0)
			break;

		size_t bytes = (size_t)samples * channels * sizeof(opus_int16);
		// Cap output to 64 MB to prevent filling device storage or integer overflow in WAV header.
		if ((uint64_t)totalBytesWritten + (uint64_t)bytes > (uint64_t)kTGVoiceMaxDecodedBytes) {
			fclose(fp);
			[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
			op_free(of);
			return nil;
		}

		if (fwrite(buffer, 1, bytes, fp) != bytes) {
			NSLog(@"TGVoiceDecoder: failed to write audio chunk");
			fclose(fp);
			[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
			op_free(of);
			return nil;
		}
		totalBytesWritten += (uint32_t)bytes;
	}
	op_free(of);

	if (totalBytesWritten == 0){
		NSLog(@"TGVoiceDecoder: decoded nothing");
		fclose(fp);
		[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
		return nil;
	}

	// 44-byte canonical WAV header
	uint32_t dataSize = totalBytesWritten;
	uint32_t byteRate = rate * channels * 2;

	memcpy(header, "RIFF", 4);
	put32(header + 4, 36 + dataSize);
	memcpy(header + 8, "WAVEfmt ", 8);
	put32(header + 16, 16);          // PCM header size
	put16(header + 20, 1);           // format: PCM
	put16(header + 22, channels);
	put32(header + 24, rate);
	put32(header + 28, byteRate);
	put16(header + 32, channels * 2); // block align
	put16(header + 34, 16);           // bits per sample
	memcpy(header + 36, "data", 4);
	put32(header + 40, dataSize);

	// Seek back to 0 and write the finalized WAV header
	if (fseek(fp, 0, SEEK_SET) != 0 || fwrite(header, 1, sizeof(header), fp) != sizeof(header)) {
		NSLog(@"TGVoiceDecoder: failed to write finalized WAV header");
		fclose(fp);
		[[NSFileManager defaultManager] removeItemAtPath:out error:nil];
		return nil;
	}

	fclose(fp);
	return out;
}

@end

// vim:ft=objc
