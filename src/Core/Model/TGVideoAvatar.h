//
// TGVideoAvatar.h - the clip a profile picture plays where the device can
// (official PeerInfoAvatarListNode plays a chatPhoto's animation).
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Whether a photo record says it moves: profilePhoto or chatPhotoInfo
/// has_animation. Cheap, read before asking for the full photo.
BOOL TGVideoAvatarAnnounced(NSDictionary *photoRecord);

/// From a full chatPhoto: @{fileId, frame} - the small 160 px clip when there
/// is one (a header avatar is smaller than that), else the large one, and
/// main_frame_timestamp, the frame official starts on and rests on. nil for a
/// still photo.
NSDictionary *TGVideoAvatarFrom(NSDictionary *chatPhoto);

/// A photo made from a sticker of a set: @{setId, stickerId, colours} with the
/// background fill's 0xRRGGBB colours; nil for any other photo (official
/// AvatarVideoNode emojiMarkup .sticker).
NSDictionary *TGStickerAvatarFrom(NSDictionary *chatPhoto);

/// That sticker in its set's getStickerSet answer: @{fileId, format}, the
/// format "tgs", "webm" or "webp". nil when the set no longer has it.
NSDictionary *TGStickerAvatarPick(NSArray *stickers, int64_t stickerId);

#ifdef __cplusplus
}
#endif
