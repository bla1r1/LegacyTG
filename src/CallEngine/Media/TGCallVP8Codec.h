//
// TGCallVP8Codec - libvpx VP8 for calls on iOS 6 and 7, where VideoToolbox's
// H.264 is not public. Software on the A5: small pictures, one pass, the
// fastest real-time setting, no look-ahead.
//
#ifndef TG_CALL_VP8_CODEC_H
#define TG_CALL_VP8_CODEC_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TGVP8Encoder TGVP8Encoder;
typedef struct TGVP8Decoder TGVP8Decoder;

typedef struct {
	const uint8_t *plane[3];   // Y, U, V
	int stride[3];
	int width;
	int height;
} TGVP8Image;

/// NULL when libvpx refuses the size or the memory is not there.
TGVP8Encoder *TGVP8EncoderOpen(int width, int height, int fps, int kbps);

/// One NV12 picture of the opened size (the camera's format). Writes the frame
/// to `out` and returns its length; 0 when the encoder dropped the picture
/// to keep to the rate, or on error. `pts` is in 90 kHz ticks.
size_t TGVP8EncodeNV12(TGVP8Encoder *encoder,
                       const uint8_t *luma, size_t lumaStride,
                       const uint8_t *chroma, size_t chromaStride,
                       int64_t pts, int forceKeyframe,
                       uint8_t *out, size_t capacity, int *keyframe);

/// A new target rate, from the next frame on.
void TGVP8EncoderSetRate(TGVP8Encoder *encoder, int kbps);

void TGVP8EncoderClose(TGVP8Encoder *encoder);

/// `maxPixels` refuses a keyframe that announces a bigger picture before
/// libvpx allocates for it.
TGVP8Decoder *TGVP8DecoderOpen(int maxPixels);

/// 1 when `image` holds a decoded picture, valid until the next call.
int TGVP8Decode(TGVP8Decoder *decoder, const uint8_t *frame, size_t length, TGVP8Image *image);

void TGVP8DecoderClose(TGVP8Decoder *decoder);

#ifdef __cplusplus
}
#endif

#endif
