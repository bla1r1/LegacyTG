#include "TGCallVP8Codec.h"

#include <stdlib.h>
#include <string.h>

#include "vpx/vp8cx.h"
#include "vpx/vp8dx.h"
#include "vpx/vpx_decoder.h"
#include "vpx/vpx_encoder.h"

struct TGVP8Encoder {
	vpx_codec_ctx_t codec;
	vpx_codec_enc_cfg_t cfg;
	vpx_image_t image;
	uint8_t *i420;
	int width;
	int height;
	int frameTicks;
};

struct TGVP8Decoder {
	vpx_codec_ctx_t codec;
	int maxPixels;
};

TGVP8Encoder *TGVP8EncoderOpen(int width, int height, int fps, int kbps) {
	if (width < 16 || height < 16 || (width & 1) || (height & 1) || fps <= 0)
		return NULL;
	vpx_codec_enc_cfg_t cfg;
	if (vpx_codec_enc_config_default(vpx_codec_vp8_cx(), &cfg, 0) != VPX_CODEC_OK)
		return NULL;
	cfg.g_w = (unsigned)width;
	cfg.g_h = (unsigned)height;
	cfg.g_timebase.num = 1;
	cfg.g_timebase.den = 90000;
	cfg.g_threads = 1;
	cfg.g_lag_in_frames = 0;
	cfg.g_error_resilient = VPX_ERROR_RESILIENT_DEFAULT;
	cfg.g_pass = VPX_RC_ONE_PASS;
	cfg.rc_end_usage = VPX_CBR;
	cfg.rc_target_bitrate = (unsigned)kbps;
	cfg.rc_min_quantizer = 4;
	cfg.rc_max_quantizer = 56;
	cfg.rc_undershoot_pct = 100;
	cfg.rc_overshoot_pct = 15;
	cfg.rc_buf_initial_sz = 500;
	cfg.rc_buf_optimal_sz = 600;
	cfg.rc_buf_sz = 1000;
	cfg.rc_dropframe_thresh = 30;
	// A keyframe every four seconds bounds how long a picture stays broken
	// when a PLI is lost too.
	cfg.kf_mode = VPX_KF_AUTO;
	cfg.kf_max_dist = (unsigned)(fps * 4);

	TGVP8Encoder *encoder = calloc(1, sizeof(*encoder));
	if (!encoder)
		return NULL;
	encoder->i420 = malloc((size_t)width * height * 3 / 2);
	if (!encoder->i420 ||
	    vpx_codec_enc_init(&encoder->codec, vpx_codec_vp8_cx(), &cfg, 0) != VPX_CODEC_OK){
		free(encoder->i420);
		free(encoder);
		return NULL;
	}
	// -12 is the fastest real-time speed that still looks like a picture on
	// the A5; the rest keep the encoder from spending cycles we do not have.
	vpx_codec_control(&encoder->codec, VP8E_SET_CPUUSED, -12);
	vpx_codec_control(&encoder->codec, VP8E_SET_NOISE_SENSITIVITY, 0);
	vpx_codec_control(&encoder->codec, VP8E_SET_STATIC_THRESHOLD, 1);
	vpx_codec_control(&encoder->codec, VP8E_SET_TOKEN_PARTITIONS, VP8_ONE_TOKENPARTITION);
	vpx_codec_control(&encoder->codec, VP8E_SET_MAX_INTRA_BITRATE_PCT, 300);
	encoder->cfg = cfg;
	vpx_img_wrap(&encoder->image, VPX_IMG_FMT_I420, (unsigned)width, (unsigned)height, 1, encoder->i420);
	encoder->width = width;
	encoder->height = height;
	encoder->frameTicks = 90000 / fps;
	return encoder;
}

size_t TGVP8EncodeNV12(TGVP8Encoder *e,
                       const uint8_t *luma, size_t lumaStride,
                       const uint8_t *chroma, size_t chromaStride,
                       int64_t pts, int forceKeyframe,
                       uint8_t *out, size_t capacity, int *keyframe) {
	if (!e || !luma || !chroma || !out)
		return 0;
	int w = e->width, h = e->height;
	uint8_t *y = e->i420, *u = y + w * h, *v = u + (w / 2) * (h / 2);
	for (int row = 0; row < h; row++)
		memcpy(y + row * w, luma + row * lumaStride, (size_t)w);
	// NV12 interleaves U and V; I420 keeps them apart.
	for (int row = 0; row < h / 2; row++){
		const uint8_t *src = chroma + row * chromaStride;
		uint8_t *du = u + row * (w / 2), *dv = v + row * (w / 2);
		for (int col = 0; col < w / 2; col++){
			du[col] = src[2 * col];
			dv[col] = src[2 * col + 1];
		}
	}
	vpx_enc_frame_flags_t flags = forceKeyframe ? VPX_EFLAG_FORCE_KF : 0;
	if (vpx_codec_encode(&e->codec, &e->image, pts, (unsigned long)e->frameTicks,
	                     flags, VPX_DL_REALTIME) != VPX_CODEC_OK)
		return 0;
	size_t written = 0;
	vpx_codec_iter_t iter = NULL;
	const vpx_codec_cx_pkt_t *packet;
	while ((packet = vpx_codec_get_cx_data(&e->codec, &iter))){
		if (packet->kind != VPX_CODEC_CX_FRAME_PKT)
			continue;
		if (written + packet->data.frame.sz > capacity)
			return 0;
		memcpy(out + written, packet->data.frame.buf, packet->data.frame.sz);
		written += packet->data.frame.sz;
		if (keyframe)
			*keyframe = (packet->data.frame.flags & VPX_FRAME_IS_KEY) != 0;
	}
	return written;
}

void TGVP8EncoderSetRate(TGVP8Encoder *e, int kbps) {
	if (!e || kbps <= 0)
		return;
	e->cfg.rc_target_bitrate = (unsigned)kbps;
	vpx_codec_enc_config_set(&e->codec, &e->cfg);
}

void TGVP8EncoderClose(TGVP8Encoder *e) {
	if (!e)
		return;
	vpx_codec_destroy(&e->codec);
	free(e->i420);
	free(e);
}

TGVP8Decoder *TGVP8DecoderOpen(int maxPixels) {
	TGVP8Decoder *d = calloc(1, sizeof(*d));
	if (!d)
		return NULL;
	vpx_codec_dec_cfg_t cfg = { .threads = 1 };
	if (vpx_codec_dec_init(&d->codec, vpx_codec_vp8_dx(), &cfg, 0) != VPX_CODEC_OK){
		free(d);
		return NULL;
	}
	d->maxPixels = maxPixels;
	return d;
}

int TGVP8Decode(TGVP8Decoder *d, const uint8_t *frame, size_t length, TGVP8Image *image) {
	if (!d || !frame || length < 3)
		return 0;
	// A keyframe states its size in bytes 6..9 (RFC 6386 9.1).
	if ((frame[0] & 0x01) == 0 && length >= 10){
		int w = (frame[6] | (frame[7] << 8)) & 0x3FFF;
		int h = (frame[8] | (frame[9] << 8)) & 0x3FFF;
		if ((long)w * h > d->maxPixels)
			return 0;
	}
	if (vpx_codec_decode(&d->codec, frame, (unsigned)length, NULL, 0) != VPX_CODEC_OK)
		return 0;
	vpx_codec_iter_t iter = NULL;
	vpx_image_t *img = vpx_codec_get_frame(&d->codec, &iter);
	if (!img)
		return 0;
	for (int i = 0; i < 3; i++){
		image->plane[i] = img->planes[i];
		image->stride[i] = img->stride[i];
	}
	image->width = (int)img->d_w;
	image->height = (int)img->d_h;
	return 1;
}

void TGVP8DecoderClose(TGVP8Decoder *d) {
	if (!d)
		return;
	vpx_codec_destroy(&d->codec);
	free(d);
}
