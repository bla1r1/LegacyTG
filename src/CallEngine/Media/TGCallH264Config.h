//
// TGCallH264Config - H.264 parameter sets in and out of the avcC record.
// iOS 7 added CMVideoFormatDescriptionGetH264ParameterSetAtIndex and
// ...CreateFromH264ParameterSets; on iOS 6 they are NULL weak imports and
// calling the first one crashed the encoder callback (iPod touch 4, 6.1.6).
// The format description's avcC atom carries the same sets on every iOS.
//
#ifndef TG_CALL_H264_CONFIG_H
#define TG_CALL_H264_CONFIG_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// The first SPS and PPS in an avcC record (ISO 14496-15 5.2.4.1), pointing
/// into it. 1 when both were found.
int TGAvcCParse(const uint8_t *avcc, size_t length,
                const uint8_t **sps, size_t *spsLength,
                const uint8_t **pps, size_t *ppsLength);

/// An avcC record for one SPS and one PPS, with 4-byte NAL lengths. Returns
/// its length, 0 when `capacity` is too small or the SPS is too short.
size_t TGAvcCBuild(const uint8_t *sps, size_t spsLength,
                   const uint8_t *pps, size_t ppsLength,
                   uint8_t *out, size_t capacity);

/// Picture size from an SPS NAL (header byte included), after cropping.
/// 1 on success.
int TGH264SpsSize(const uint8_t *sps, size_t length, int *width, int *height);

#ifdef __cplusplus
}
#endif

#endif
