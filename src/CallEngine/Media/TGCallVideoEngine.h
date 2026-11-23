//
// TGCallVideoEngine.h - camera capture, H.264 (VideoToolbox) or VP8 (libvpx)
// encode and decode, rendering.
//
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
@class UIView;
#endif

typedef NS_ENUM(NSInteger, TGCallVideoCodec) {
    TGCallVideoCodecH264 = 0,   ///< VideoToolbox: iOS 8 and later
    TGCallVideoCodecVP8,        ///< libvpx in software: iOS 6 and 7
};

@interface TGCallVideoEngine : NSObject

/// What the call agreed on for each direction. Set before media flows.
@property (atomic, assign) TGCallVideoCodec sendCodec;
@property (atomic, assign) TGCallVideoCodec receiveCodec;

@property (nonatomic, assign, readonly) BOOL isCapturing;
@property (nonatomic, assign, readonly) BOOL hasRemoteVideo;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;

/// Block called when an encoded RTP packet is ready to send.
@property (nonatomic, copy) void (^sendVideoRtpBlock)(NSData *rtpPacket);

/// Block called when a decoded frame (CVPixelBufferRef) is produced.
@property (nonatomic, copy) void (^onDecodedPixelBuffer)(CVPixelBufferRef pixelBuffer);

/// Block called on the main queue when remote video active state changes.
@property (nonatomic, copy) void (^onRemoteVideoStateChanged)(BOOL active);

/// The view displaying the remote peer's video (full-screen in video call).
@property (nonatomic, strong, readonly) UIView *remoteVideoView;

/// The view displaying local camera preview (Picture-in-Picture).
@property (nonatomic, strong, readonly) UIView *localPreviewView;

- (instancetype)initWithSsrc:(uint32_t)ssrc;

/// Start local camera capture and hardware H.264 compression.
- (BOOL)startCapture;

/// Stop camera capture and release compression session.
- (void)stopCapture;

/// Switch between front and rear cameras.
- (void)switchCamera;

/// One decrypted RTP packet of the peer's video stream.
- (void)handleIncomingVideoRtp:(const uint8_t *)bytes length:(size_t)length;

/// Packets of the peer's stream were lost: show nothing new until a keyframe.
- (void)remoteVideoLost;

/// A VP8 frame did not decode: the caller asks the peer for a keyframe.
/// Reflector thread.
@property (nonatomic, copy) void (^onUndecodableFrame)(void);

/// The peer asked for a keyframe; the next encoded frame is one.
- (void)requestKeyframe;
/// The peer's loss report on our stream (of 256): the encoder's rate follows
/// it, between 80 kbit/s and the tier's ceiling. Any thread; applied on the
/// next frame.
- (void)peerReportedLoss:(uint8_t)fraction;

/// A frame from somewhere other than the camera: the host bench.
- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)pts;

/// Remote frames handed to a decoder so far.
@property (nonatomic, readonly) uint32_t decodedFrames;

/// Reset and tear down all capture, compression, decompression and view resources.
- (void)stop;

@end
