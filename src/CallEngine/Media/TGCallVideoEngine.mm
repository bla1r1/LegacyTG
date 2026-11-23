//
// TGCallVideoEngine.mm - lightweight camera capture, H.264 encode/decode & rendering.
//
#import "TGCallVideoEngine.h"
#import "TGCallVideoRtp.h"
#include "TGCallVP8Codec.h"
#include "TGCallRtcp.h"
#include "TGCallH264Config.h"

/// The iOS 7 parameter-set functions, where they are. On iOS 6 they are NULL
/// and the avcC atom does their job; TG_SHIM_IOS6_H264 makes the host take
/// that road too, so the bench runs the code an iOS 6 phone runs.
static BOOL TGHasParameterSetAPIs(void) {
#if !TARGET_OS_IPHONE
    if (getenv("TG_SHIM_IOS6_H264"))
        return NO;
#endif
    return &CMVideoFormatDescriptionGetH264ParameterSetAtIndex != NULL &&
           &CMVideoFormatDescriptionCreateFromH264ParameterSets != NULL;
}
#include "TGCallVP8Rtp.h"
#import "TGStyle.h"
#import "TGDevice.h"
#include <arpa/inet.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/EAGL.h>
#import <QuartzCore/CAEAGLLayer.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>

#if defined(__arm__)
#define HAS_FFMPEG_FALLBACK 1
#define AVMediaType FFmpegAVMediaType
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
}
#undef AVMediaType
#else
#define HAS_FFMPEG_FALLBACK 0
#endif

static GLuint CompileShader(GLenum type, const char *source) {
    if (!source) return 0;
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint compiled = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

static GLuint CreateProgram(const char *vSrc, const char *fSrc) {
    GLuint vShader = CompileShader(GL_VERTEX_SHADER, vSrc);
    GLuint fShader = CompileShader(GL_FRAGMENT_SHADER, fSrc);
    if (!vShader || !fShader) return 0;
    GLuint program = glCreateProgram();
    glAttachShader(program, vShader);
    glAttachShader(program, fShader);
    glLinkProgram(program);
    glDeleteShader(vShader);
    glDeleteShader(fShader);
    GLint linked = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

static const char *kTGVertexShader =
    "attribute vec4 position;\n"
    "attribute vec2 texCoord;\n"
    "varying vec2 v_texCoord;\n"
    "void main() {\n"
    "    gl_Position = position;\n"
    "    v_texCoord = texCoord;\n"
    "}\n";

// Range: (luma offset, luma scale, chroma scale) - video range is
// (16/255, 255/219, 255/224), full range (0, 1, 1); BT.601 either way.
static const char *kTGFragmentShaderNV12 =
    "precision mediump float;\n"
    "varying highp vec2 v_texCoord;\n"
    "uniform sampler2D SamplerY;\n"
    "uniform sampler2D SamplerUV;\n"
    "uniform mediump vec3 Range;\n"
    "void main() {\n"
    "    mediump vec3 yuv;\n"
    "    highp vec3 rgb;\n"
    "    yuv.x = (texture2D(SamplerY, v_texCoord).r - Range.x) * Range.y;\n"
    "    yuv.yz = (texture2D(SamplerUV, v_texCoord).ra - vec2(0.5, 0.5)) * Range.z;\n"
    "    rgb = mat3( 1.0,    1.0,    1.0,\n"
    "                0.0,   -0.344,  1.772,\n"
    "                1.402, -0.714,  0.0 ) * yuv;\n"
    "    gl_FragColor = vec4(rgb, 1.0);\n"
    "}\n";

static const char *kTGFragmentShaderYUV =
    "precision mediump float;\n"
    "varying highp vec2 v_texCoord;\n"
    "uniform sampler2D SamplerY;\n"
    "uniform sampler2D SamplerU;\n"
    "uniform sampler2D SamplerV;\n"
    "void main() {\n"
    "    mediump vec3 yuv;\n"
    "    highp vec3 rgb;\n"
    "    yuv.x = texture2D(SamplerY, v_texCoord).r;\n"
    "    yuv.y = texture2D(SamplerU, v_texCoord).r - 0.5;\n"
    "    yuv.z = texture2D(SamplerV, v_texCoord).r - 0.5;\n"
    "    rgb = mat3( 1.164,  1.164,  1.164,\n"
    "                0.0,   -0.392,  2.017,\n"
    "                1.596, -0.813,  0.0 ) * (yuv - vec3(0.0625, 0.0, 0.0));\n"
    "    gl_FragColor = vec4(rgb, 1.0);\n"
    "}\n";

@interface TGCallEAGLVideoView : UIView {
    EAGLContext *_context;
    GLuint _framebuffer;
    GLuint _renderbuffer;
    GLint _backingWidth;
    GLint _backingHeight;

    GLuint _programNV12;
    GLint _posNV12;
    GLint _texNV12;
    GLint _ySamplerNV12;
    GLint _uvSamplerNV12;
    GLint _rangeNV12;

    GLuint _programYUV;
    GLint _posYUV;
    GLint _texYUV;
    GLint _ySamplerYUV;
    GLint _uSamplerYUV;
    GLint _vSamplerYUV;
    GLuint _yuvTextures[3];

    CVOpenGLESTextureCacheRef _textureCache;
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
}
- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)renderYUV420pY:(const uint8_t *)y U:(const uint8_t *)u V:(const uint8_t *)v
               strideY:(int)strideY strideU:(int)strideU strideV:(int)strideV
                 width:(int)width height:(int)height;
- (void)clear;
@end

@implementation TGCallEAGLVideoView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = @{
            kEAGLDrawablePropertyRetainedBacking: @NO,
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
        };

        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!_context || ![EAGLContext setCurrentContext:_context]) {
            return nil;
        }

        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
        [self setupShaders];
    }
    return self;
}

- (void)setupShaders {
    _programNV12 = CreateProgram(kTGVertexShader, kTGFragmentShaderNV12);
    if (_programNV12) {
        _posNV12 = glGetAttribLocation(_programNV12, "position");
        _texNV12 = glGetAttribLocation(_programNV12, "texCoord");
        _ySamplerNV12 = glGetUniformLocation(_programNV12, "SamplerY");
        _uvSamplerNV12 = glGetUniformLocation(_programNV12, "SamplerUV");
        _rangeNV12 = glGetUniformLocation(_programNV12, "Range");
    }

    _programYUV = CreateProgram(kTGVertexShader, kTGFragmentShaderYUV);
    if (_programYUV) {
        _posYUV = glGetAttribLocation(_programYUV, "position");
        _texYUV = glGetAttribLocation(_programYUV, "texCoord");
        _ySamplerYUV = glGetUniformLocation(_programYUV, "SamplerY");
        _uSamplerYUV = glGetUniformLocation(_programYUV, "SamplerU");
        _vSamplerYUV = glGetUniformLocation(_programYUV, "SamplerV");
    }

    glGenTextures(3, _yuvTextures);
    for (int i = 0; i < 3; i++) {
        glBindTexture(GL_TEXTURE_2D, _yuvTextures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_context) return;
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    [self destroyBuffers];
    [self createBuffers];
}

- (void)createBuffers {
    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);

    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
}

- (void)destroyBuffers {
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
}

- (void)cleanUpTextures {
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    if (_textureCache) {
        CVOpenGLESTextureCacheFlush(_textureCache, 0);
    }
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer || !_context || !_textureCache || !_programNV12) return;
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    if (_framebuffer == 0 || _backingWidth == 0 || _backingHeight == 0) {
        [self destroyBuffers];
        [self createBuffers];
    }
    if (_framebuffer == 0 || _backingWidth == 0 || _backingHeight == 0) return;

    [self cleanUpTextures];

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);

    glActiveTexture(GL_TEXTURE0);
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        _textureCache,
        pixelBuffer,
        NULL,
        GL_TEXTURE_2D,
        GL_LUMINANCE,
        (GLsizei)width,
        (GLsizei)height,
        GL_LUMINANCE,
        GL_UNSIGNED_BYTE,
        0,
        &_lumaTexture);
    if (err != kCVReturnSuccess || !_lumaTexture) return;
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glActiveTexture(GL_TEXTURE1);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        _textureCache,
        pixelBuffer,
        NULL,
        GL_TEXTURE_2D,
        GL_LUMINANCE_ALPHA,
        (GLsizei)width / 2,
        (GLsizei)height / 2,
        GL_LUMINANCE_ALPHA,
        GL_UNSIGNED_BYTE,
        1,
        &_chromaTexture);
    if (err != kCVReturnSuccess || !_chromaTexture) {
        [self cleanUpTextures];
        return;
    }
    glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(_programNV12);
    glUniform1i(_ySamplerNV12, 0);
    glUniform1i(_uvSamplerNV12, 1);
    if (CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        glUniform3f(_rangeNV12, 0.0f, 1.0f, 1.0f);
    else
        glUniform3f(_rangeNV12, 16.0f / 255.0f, 255.0f / 219.0f, 255.0f / 224.0f);

    static const GLfloat vertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };

    glVertexAttribPointer(_posNV12, 2, GL_FLOAT, 0, 0, vertices);
    glEnableVertexAttribArray(_posNV12);
    glVertexAttribPointer(_texNV12, 2, GL_FLOAT, 0, 0, texCoords);
    glEnableVertexAttribArray(_texNV12);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    [self cleanUpTextures];
}

- (void)renderYUV420pY:(const uint8_t *)y U:(const uint8_t *)u V:(const uint8_t *)v
               strideY:(int)strideY strideU:(int)strideU strideV:(int)strideV
                 width:(int)width height:(int)height {
    if (!y || !u || !v || !_context || !_programYUV) return;
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    if (_framebuffer == 0 || _backingWidth == 0 || _backingHeight == 0) {
        [self destroyBuffers];
        [self createBuffers];
    }
    if (_framebuffer == 0 || _backingWidth == 0 || _backingHeight == 0) return;

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _yuvTextures[0]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, strideY, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, y);

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _yuvTextures[1]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, strideU, height / 2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, u);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _yuvTextures[2]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, strideV, height / 2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, v);

    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(_programYUV);
    glUniform1i(_ySamplerYUV, 0);
    glUniform1i(_uSamplerYUV, 1);
    glUniform1i(_vSamplerYUV, 2);

    static const GLfloat vertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };
    float uMax = (float)width / (float)strideY;
    GLfloat texCoords[] = {
        0.0f, 1.0f,
        uMax, 1.0f,
        0.0f, 0.0f,
        uMax, 0.0f,
    };

    glVertexAttribPointer(_posYUV, 2, GL_FLOAT, 0, 0, vertices);
    glEnableVertexAttribArray(_posYUV);
    glVertexAttribPointer(_texYUV, 2, GL_FLOAT, 0, 0, texCoords);
    glEnableVertexAttribArray(_texYUV);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)clear {
    if (!_context || !_framebuffer) return;
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)dealloc {
    [self cleanUpTextures];
    if (_textureCache) {
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
    if (_yuvTextures[0]) {
        glDeleteTextures(3, _yuvTextures);
    }
    if (_programNV12) {
        glDeleteProgram(_programNV12);
        _programNV12 = 0;
    }
    if (_programYUV) {
        glDeleteProgram(_programYUV);
        _programYUV = 0;
    }
    [self destroyBuffers];
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    _context = nil;
}

@end

@interface TGCallRemoteVideoContainerView : UIView {
    AVSampleBufferDisplayLayer *_sampleLayer;
    TGCallEAGLVideoView *_eaglView;
}
@property (nonatomic, strong, readonly) AVSampleBufferDisplayLayer *sampleLayer;
- (void)displaySampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)displayYUV420pY:(const uint8_t *)y U:(const uint8_t *)u V:(const uint8_t *)v
               strideY:(int)strideY strideU:(int)strideU strideV:(int)strideV
                 width:(int)width height:(int)height;
- (void)flushAndRemoveImage;
@end

@implementation TGCallRemoteVideoContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        BOOL hasSampleLayer = (NSClassFromString(@"AVSampleBufferDisplayLayer") != nil &&
                               [[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0f);
        if (hasSampleLayer) {
            _sampleLayer = [[AVSampleBufferDisplayLayer alloc] init];
            _sampleLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            _sampleLayer.frame = self.bounds;
            [self.layer addSublayer:_sampleLayer];
        } else {
            _eaglView = [[TGCallEAGLVideoView alloc] initWithFrame:self.bounds];
            _eaglView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:_eaglView];
        }
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_sampleLayer) {
        _sampleLayer.frame = self.bounds;
    }
    if (_eaglView) {
        _eaglView.frame = self.bounds;
    }
}

- (AVSampleBufferDisplayLayer *)sampleLayer {
    return _sampleLayer;
}

- (void)displaySampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // One undecodable sample parks the layer in Failed for good; the next
    // keyframe can only show after a flush.
    if (_sampleLayer && _sampleLayer.status == AVQueuedSampleBufferRenderingStatusFailed)
        [_sampleLayer flush];
    if (_sampleLayer && [_sampleLayer isReadyForMoreMediaData]) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
        if (attachments && CFArrayGetCount(attachments) > 0) {
            CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        }
        [_sampleLayer enqueueSampleBuffer:sampleBuffer];
    }
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (_eaglView) {
        [_eaglView renderPixelBuffer:pixelBuffer];
    }
}

- (void)displayYUV420pY:(const uint8_t *)y U:(const uint8_t *)u V:(const uint8_t *)v
               strideY:(int)strideY strideU:(int)strideU strideV:(int)strideV
                 width:(int)width height:(int)height {
    // VP8 from the peer has no sample-buffer path: on iOS 8 and later the
    // GL view is made the first time a VP8 picture comes. Before iOS 8 it
    // is always there, and H.264 reaches it decoded by VideoToolbox.
    if (!_eaglView) {
        _eaglView = [[TGCallEAGLVideoView alloc] initWithFrame:self.bounds];
        _eaglView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_eaglView];
    }
    if (_eaglView) {
        [_eaglView renderYUV420pY:y U:u V:v strideY:strideY strideU:strideU strideV:strideV width:width height:height];
    }
}

- (void)flushAndRemoveImage {
    if (_sampleLayer) {
        [_sampleLayer flushAndRemoveImage];
    }
    if (_eaglView) {
        [_eaglView clear];
    }
}

@end

@interface TGCallPreviewContainerView : UIView
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation TGCallPreviewContainerView
+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}
@end
#else
#define HAS_FFMPEG_FALLBACK 0
#endif

@interface TGCallVideoEngine () <AVCaptureVideoDataOutputSampleBufferDelegate> {
    uint32_t _ssrc;
    TGCallVideoRtpPacketizer *_packetizer;
    TGCallVideoRtpDepacketizer *_depacketizer;

    AVCaptureSession *_captureSession;
    AVCaptureDeviceInput *_cameraInput;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCaptureVideoPreviewLayer *_previewLayer;

    VTCompressionSessionRef _compressionSession;
    VTDecompressionSessionRef _decompressionSession;
    CMVideoFormatDescriptionRef _decompFormatDesc;
    NSData *_decoderSps;
    NSData *_decoderPps;
    volatile uint32_t _decodedFrames;

    // VP8: the encoder on the capture queue, the decoder on the reflector
    // thread; each buffer belongs to one of them.
    TGVP8Encoder *_vp8Encoder;
    int _vp8Width;
    int _vp8Height;
    uint16_t _vp8PictureId;
    uint8_t *_vp8Encoded;
    uint8_t *_vp8Payloads;
    TGVP8Decoder *_vp8Decoder;
    TGVP8Depacketizer _vp8Depacketizer;
    uint8_t *_vp8Frame;

    dispatch_queue_t _captureQueue;
    uint32_t _targetWidth;
    uint32_t _targetHeight;
    BOOL _forceKeyframeNext;
    CVPixelBufferRef _pendingPicture;   // the next picture to draw; under @synchronized(self)
    int _sendKbps;      // 0 until the first report: the tier's ceiling
    int _appliedKbps;   // encoder thread
    double _lastRateChange;
    BOOL _compressionFailed;

#if HAS_FFMPEG_FALLBACK
    AVCodecContext *_ffmpegCodecCtx;
    AVFrame *_ffmpegFrame;
    AVPacket *_ffmpegPacket;
#endif

#if TARGET_OS_IPHONE
    TGCallRemoteVideoContainerView *_remoteView;
    TGCallPreviewContainerView *_previewView;
#else
    id _remoteView;
    id _previewView;
#endif
}

- (void)didCompressSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)didDecodePixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

static void CompressionCallback(void *outputCallbackRefCon,
                                void *sourceFrameRefCon,
                                OSStatus status,
                                VTEncodeInfoFlags infoFlags,
                                CMSampleBufferRef sampleBuffer) {
    if (status != noErr || !sampleBuffer) {
        return;
    }
    if (infoFlags & kVTEncodeInfo_FrameDropped) {
        return;
    }

    TGCallVideoEngine *engine = (__bridge TGCallVideoEngine *)outputCallbackRefCon;
    [engine didCompressSampleBuffer:sampleBuffer];
}

static void DecompressionCallback(void *decompressionOutputRefCon,
                                  void *sourceFrameRefCon,
                                  OSStatus status,
                                  VTDecodeInfoFlags infoFlags,
                                  CVImageBufferRef imageBuffer,
                                  CMTime presentationTimeStamp,
                                  CMTime presentationDuration) {
    TGCallVideoEngine *engine = (__bridge TGCallVideoEngine *)decompressionOutputRefCon;
    if (status != noErr || !imageBuffer) {
        // A frame VideoToolbox refused leaves its references wrong until a
        // keyframe, as on the VP8 path.
        if (status != noErr)
            NSLog(@"TGCallVideoEngine: VideoToolbox refused a peer frame: %d", (int)status);
        if (status != noErr && engine.onUndecodableFrame)
            engine.onUndecodableFrame();
        return;
    }

    [engine didDecodePixelBuffer:(CVPixelBufferRef)imageBuffer];
}

// What the other phone sends grows with our reports, from 360x640 up to
// 720x1280; a bigger keyframe is refused before libvpx allocates for it.
static const int kTGVP8DecodeMaxPixels = 720 * 1280;
static const size_t kTGVP8FrameMax = 512 * 1024;
static const size_t kTGVP8EncodedMax = 128 * 1024;
static const size_t kTGVP8Payload = 1100;
static const int kTGVP8MaxPackets = 128;

@implementation TGCallVideoEngine

- (instancetype)initWithSsrc:(uint32_t)ssrc {
    self = [super init];
    if (self) {
        _ssrc = ssrc;
        _cameraPosition = AVCaptureDevicePositionFront;
        if ([TGDevice tier] <= TGDeviceTierLegacy) {
            _targetWidth = 288;
            _targetHeight = 352;
        } else {
            _targetWidth = 480;
            _targetHeight = 640;
        }
        _packetizer = [[TGCallVideoRtpPacketizer alloc] initWithSsrc:_ssrc];
        _vp8Encoded = (uint8_t *)malloc(kTGVP8EncodedMax);
        _vp8Payloads = (uint8_t *)malloc(kTGVP8MaxPackets * kTGVP8Payload);
        _vp8Frame = (uint8_t *)malloc(kTGVP8FrameMax);
        TGVP8DepacketizerInit(&_vp8Depacketizer, _vp8Frame, kTGVP8FrameMax);
        _depacketizer = [[TGCallVideoRtpDepacketizer alloc] init];
        _captureQueue = dispatch_queue_create("com.itglegacy.call.video.capture", DISPATCH_QUEUE_SERIAL);

        [self setupViews];
        [self setupDepacketizer];
    }
    return self;
}

- (void)setupViews {
#if TARGET_OS_IPHONE
    _remoteView = [[TGCallRemoteVideoContainerView alloc] initWithFrame:CGRectZero];

    _previewView = [[TGCallPreviewContainerView alloc] initWithFrame:CGRectZero];
    _previewView.backgroundColor = [UIColor clearColor];
    _previewView.layer.masksToBounds = YES;
    _previewView.layer.cornerRadius = TGMetricCornerControl;
#endif
}

- (UIView *)remoteVideoView {
    return (UIView *)_remoteView;
}

- (UIView *)localPreviewView {
    return (UIView *)_previewView;
}

- (void)setupDepacketizer {
    __weak TGCallVideoEngine *weakSelf = self;
    _depacketizer.onFrameReceived = ^(NSData *avccFrame, uint32_t timestamp, BOOL isKeyframe, NSData *sps, NSData *pps) {
        [weakSelf didAssembleRemoteFrame:avccFrame isKeyframe:isKeyframe sps:sps pps:pps];
    };
}

#pragma mark - Capture Pipeline

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

- (BOOL)startCapture {
    if (_isCapturing) return YES;

#if TARGET_OS_IPHONE
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
        NSInteger status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (status == 0 /* AVAuthorizationStatusNotDetermined */) {
            __weak TGCallVideoEngine *weakSelf = self;
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf startCapture];
                    });
                }
            }];
            return YES;
        } else if (status == 1 /* Restricted */ || status == 2 /* Denied */) {
            NSLog(@"TGCallVideoEngine: camera access denied");
            return NO;
        }
    }
#endif

    _captureSession = [[AVCaptureSession alloc] init];
    if ([TGDevice tier] <= TGDeviceTierLegacy &&
        [_captureSession canSetSessionPreset:AVCaptureSessionPreset352x288]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset352x288;
    } else if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    } else if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }

    AVCaptureDevice *device = [self cameraWithPosition:_cameraPosition];
    if (!device) return NO;

    int targetFps = ([TGDevice tier] <= TGDeviceTierLegacy) ? 15 : 20;
    if ([device respondsToSelector:@selector(lockForConfiguration:)]) {
        if ([device lockForConfiguration:nil]) {
            if ([device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)]) {
                device.activeVideoMinFrameDuration = CMTimeMake(1, targetFps);
                device.activeVideoMaxFrameDuration = CMTimeMake(1, targetFps);
            }
            [device unlockForConfiguration];
        }
    }

    NSError *err = nil;
    _cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
    if (!_cameraInput || err || ![_captureSession canAddInput:_cameraInput]) {
        return NO;
    }
    [_captureSession addInput:_cameraInput];

    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoOutput.alwaysDiscardsLateVideoFrames = YES;
    _videoOutput.videoSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    };
    [_videoOutput setSampleBufferDelegate:self queue:_captureQueue];

    if ([_captureSession canAddOutput:_videoOutput]) {
        [_captureSession addOutput:_videoOutput];
    }

    AVCaptureConnection *conn = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (conn) {
        if ([conn respondsToSelector:@selector(isVideoOrientationSupported)] && conn.isVideoOrientationSupported) {
            conn.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }

#if TARGET_OS_IPHONE
    _previewLayer = _previewView.previewLayer;
    _previewLayer.session = _captureSession;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
#endif

    // VP8 opens its encoder on the first frame; VideoToolbox is touched
    // only when the call settled on H.264.
    if (self.sendCodec == TGCallVideoCodecH264)
        [self initCompressionSession];

    [_captureSession startRunning];
    _isCapturing = YES;
    _forceKeyframeNext = YES;
    _compressionFailed = NO;

    return YES;
}

- (void)stopCapture {
    if (!_isCapturing) return;

    if (_captureSession && [_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
    _captureSession = nil;
    _cameraInput = nil;
    _videoOutput = nil;

#if TARGET_OS_IPHONE
    if (_previewView) {
        _previewView.previewLayer.session = nil;
    }
    _previewLayer = nil;
#endif

    if (_compressionSession) {
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }

    _compressionFailed = NO;
    _isCapturing = NO;
    dispatch_sync(_captureQueue, ^{
        TGVP8EncoderClose(self->_vp8Encoder);
        self->_vp8Encoder = NULL;
    });
}

- (void)switchCamera {
    if (!_captureSession) {
        _cameraPosition = (_cameraPosition == AVCaptureDevicePositionFront) ?
                           AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
        return;
    }

    [_captureSession beginConfiguration];
    if (_cameraInput) {
        [_captureSession removeInput:_cameraInput];
    }

    _cameraPosition = (_cameraPosition == AVCaptureDevicePositionFront) ?
                       AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;

    AVCaptureDevice *device = [self cameraWithPosition:_cameraPosition];
    NSError *err = nil;
    _cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
    if (_cameraInput && [_captureSession canAddInput:_cameraInput]) {
        [_captureSession addInput:_cameraInput];
    }

    AVCaptureConnection *conn = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (conn) {
        if ([conn respondsToSelector:@selector(isVideoOrientationSupported)] && conn.isVideoOrientationSupported) {
            conn.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }

    [_captureSession commitConfiguration];
    _forceKeyframeNext = YES;
}

#pragma mark - VideoToolbox Compression

- (void)initCompressionSession {
    if (_compressionSession) {
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }

    if (_targetWidth == 0 || _targetHeight == 0) return;

    OSStatus status = VTCompressionSessionCreate(
        kCFAllocatorDefault,
        _targetWidth,
        _targetHeight,
        kCMVideoCodecType_H264,
        NULL,
        NULL,
        NULL,
        CompressionCallback,
        (__bridge void *)self,
        &_compressionSession
    );

    if (status != noErr) {
        NSLog(@"TGCallVideoEngine: VTCompressionSessionCreate(%u, %u) failed: %d, trying fallback...",
              _targetWidth, _targetHeight, (int)status);
        NSDictionary *sourceAttrs = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
        };
        status = VTCompressionSessionCreate(
            kCFAllocatorDefault,
            _targetWidth,
            _targetHeight,
            kCMVideoCodecType_H264,
            NULL,
            (__bridge CFDictionaryRef)sourceAttrs,
            NULL,
            CompressionCallback,
            (__bridge void *)self,
            &_compressionSession
        );
    }

    if (status != noErr || !_compressionSession) {
        NSLog(@"TGCallVideoEngine: VTCompressionSessionCreate failed: %d", (int)status);
        _compressionFailed = YES;
        return;
    }

    _compressionFailed = NO;
    NSLog(@"TGCallVideoEngine: VTCompressionSession initialized (%u x %u)", _targetWidth, _targetHeight);

    int bitrate = ([TGDevice tier] <= TGDeviceTierLegacy) ? 220000 : 350000;
    int keyframeInterval = ([TGDevice tier] <= TGDeviceTierLegacy) ? 15 * 2 : 20 * 2;
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(keyframeInterval));
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bitrate));
    _appliedKbps = bitrate / 1000;
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) return;
    [self encodePixelBuffer:(CVPixelBufferRef)imageBuffer
           presentationTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
}

- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)pts {
    if (self.sendCodec == TGCallVideoCodecVP8) {
        [self encodeVP8:pixelBuffer presentationTime:pts];
        return;
    }
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    if ((!_compressionSession && !_compressionFailed) || _targetWidth != width || _targetHeight != height) {
        _targetWidth = (uint32_t)width;
        _targetHeight = (uint32_t)height;
        [self initCompressionSession];
    }
    if (!_compressionSession) return;
    int kbps = _sendKbps;
    if (kbps && kbps != _appliedKbps) {
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate,
                             (__bridge CFTypeRef)@(kbps * 1000));
        _appliedKbps = kbps;
    }

    NSDictionary *frameProps = nil;
    if (_forceKeyframeNext) {
        frameProps = @{ (id)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES };
        _forceKeyframeNext = NO;
    }

    VTCompressionSessionEncodeFrame(
        _compressionSession,
        pixelBuffer,
        pts,
        kCMTimeInvalid,
        (__bridge CFDictionaryRef)frameProps,
        NULL,
        NULL
    );
}

- (void)encodeVP8:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)pts {
    if (!CVPixelBufferIsPlanar(pixelBuffer) || CVPixelBufferGetPlaneCount(pixelBuffer) < 2)
        return;
    int width = (int)CVPixelBufferGetWidth(pixelBuffer) & ~1;
    int height = (int)CVPixelBufferGetHeight(pixelBuffer) & ~1;
    if (!_vp8Encoder || width != _vp8Width || height != _vp8Height) {
        TGVP8EncoderClose(_vp8Encoder);
        int kbps = ([TGDevice tier] <= TGDeviceTierLegacy) ? 250 : 400;
        int fps = ([TGDevice tier] <= TGDeviceTierLegacy) ? 15 : 20;
        _vp8Encoder = TGVP8EncoderOpen(width, height, fps, kbps);
        _vp8Width = width;
        _vp8Height = height;
        _forceKeyframeNext = YES;
        _appliedKbps = kbps;
        NSLog(@"TGCallVideoEngine: VP8 encoder %dx%d %d kbps: %@", width, height, kbps,
              _vp8Encoder ? @"open" : @"refused");
    }
    if (!_vp8Encoder)
        return;
    int target = _sendKbps;
    if (target && target != _appliedKbps) {
        TGVP8EncoderSetRate(_vp8Encoder, target);
        _appliedKbps = target;
    }

    BOOL force = _forceKeyframeNext;
    _forceKeyframeNext = NO;
    int keyframe = 0;
    int64_t ticks = pts.timescale ? pts.value * 90000 / pts.timescale : 0;
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    size_t length = TGVP8EncodeNV12(_vp8Encoder,
            (const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0),
            (const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1),
            ticks, force, _vp8Encoded, kTGVP8EncodedMax, &keyframe);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (!length)
        return;

    size_t lengths[kTGVP8MaxPackets];
    int count = TGVP8Packetize(_vp8Encoded, length, (uint16_t)(_vp8PictureId++ & 0x7FFF),
                               _vp8Payloads, kTGVP8Payload, lengths, kTGVP8MaxPackets);
    uint32_t timestamp = (uint32_t)ticks;
    @synchronized (_packetizer) {
        for (int i = 0; i < count; i++) {
            NSMutableData *packet = [NSMutableData dataWithLength:12 + lengths[i]];
            uint8_t *bytes = (uint8_t *)packet.mutableBytes;
            uint16_t seq = _packetizer.sequenceNumber;
            _packetizer.sequenceNumber = (uint16_t)(seq + 1);
            bytes[0] = 0x80;
            bytes[1] = (uint8_t)((i == count - 1) ? 0x80 : 0x00);   // marker; the session sets the type
            bytes[2] = (uint8_t)(seq >> 8);
            bytes[3] = (uint8_t)seq;
            bytes[4] = (uint8_t)(timestamp >> 24);
            bytes[5] = (uint8_t)(timestamp >> 16);
            bytes[6] = (uint8_t)(timestamp >> 8);
            bytes[7] = (uint8_t)timestamp;
            memcpy(bytes + 12, _vp8Payloads + i * kTGVP8Payload, lengths[i]);
            if (self.sendVideoRtpBlock)
                self.sendVideoRtpBlock(packet);
        }
    }
    static NSUInteger vp8Count = 0;
    if (++vp8Count % 60 == 1 || keyframe)
        NSLog(@"TGCallVideoEngine: VP8 frame #%lu, %lu bytes, key %d, %d packets",
              (unsigned long)vp8Count, (unsigned long)length, keyframe, count);
}

- (void)requestKeyframe {
    _forceKeyframeNext = YES;
}

- (int)maxSendKbps {
    BOOL legacy = [TGDevice tier] <= TGDeviceTierLegacy;
    if (self.sendCodec == TGCallVideoCodecVP8)
        return legacy ? 250 : 400;
    return legacy ? 220 : 350;
}

- (void)peerReportedLoss:(uint8_t)fraction {
    // A report rides on every NACK too, several a second on a lossy link;
    // WebRTC moves the rate up at most once a second and down at most every
    // 300 ms, and so do we.
    double t = [NSProcessInfo processInfo].systemUptime;
    if (t - _lastRateChange < (fraction < 5 ? 1.0 : 0.3))
        return;
    int max = [self maxSendKbps];
    int now = _sendKbps ? _sendKbps : max;
    int next = TGRateAfterLoss(now, 80, max, fraction);
    if (next != now)
        _lastRateChange = t;
    if (next != now && (next * 10 < now * 9 || next == max || _sendKbps == 0))
        NSLog(@"TGCallVideoEngine: send rate %d kbps after %u/256 lost", next, fraction);
    _sendKbps = next;
}

- (void)remoteVideoLost {
    [_depacketizer dropUntilKeyframe];
    TGVP8DepacketizerDrop(&_vp8Depacketizer);
}

- (uint32_t)decodedFrames {
    return _decodedFrames;
}

- (void)didCompressSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    NSData *sps = nil;
    NSData *pps = nil;

    BOOL isKeyframe = NO;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachments && CFArrayGetCount(attachments) > 0) {
        CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        // The key can be present and false: only a true value means "not a
        // keyframe". Reading presence alone sent IDRs without SPS and PPS.
        CFBooleanRef notSync = (CFBooleanRef)CFDictionaryGetValue(dict, kCMSampleAttachmentKey_NotSync);
        isKeyframe = !(notSync && CFBooleanGetValue(notSync));
    }

    if (isKeyframe && formatDesc && !TGHasParameterSetAPIs()) {
        CFDictionaryRef atoms = (CFDictionaryRef)CMFormatDescriptionGetExtension(
            formatDesc, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
        CFDataRef avcc = atoms ? (CFDataRef)CFDictionaryGetValue(atoms, CFSTR("avcC")) : NULL;
        const uint8_t *spsPtr = NULL, *ppsPtr = NULL;
        size_t spsSize = 0, ppsSize = 0;
        if (avcc && TGAvcCParse(CFDataGetBytePtr(avcc), (size_t)CFDataGetLength(avcc),
                                &spsPtr, &spsSize, &ppsPtr, &ppsSize)) {
            sps = [NSData dataWithBytes:spsPtr length:spsSize];
            pps = [NSData dataWithBytes:ppsPtr length:ppsSize];
        }
    } else if (isKeyframe && formatDesc) {
        size_t spsSize = 0, spsCount = 0;
        const uint8_t *spsPtr = NULL;
        OSStatus status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDesc, 0, &spsPtr, &spsSize, &spsCount, NULL
        );
        if (status == noErr && spsPtr && spsSize > 0) {
            sps = [NSData dataWithBytes:spsPtr length:spsSize];
        }

        size_t ppsSize = 0, ppsCount = 0;
        const uint8_t *ppsPtr = NULL;
        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDesc, 1, &ppsPtr, &ppsSize, &ppsCount, NULL
        );
        if (status == noErr && ppsPtr && ppsSize > 0) {
            pps = [NSData dataWithBytes:ppsPtr length:ppsSize];
        }
    }

    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    if (!dataBuffer) return;

    CMBlockBufferRef contiguousBuffer = NULL;
    size_t lengthAtOffset = 0;
    size_t totalLength = 0;
    char *dataPtr = NULL;
    OSStatus status = CMBlockBufferGetDataPointer(dataBuffer, 0, &lengthAtOffset, &totalLength, &dataPtr);
    if (status == noErr && lengthAtOffset < totalLength) {
        OSStatus contigStatus = CMBlockBufferCreateContiguous(kCFAllocatorDefault, dataBuffer, kCFAllocatorDefault, NULL, 0, 0, 0, &contiguousBuffer);
        if (contigStatus == noErr && contiguousBuffer) {
            dataBuffer = contiguousBuffer;
            status = CMBlockBufferGetDataPointer(dataBuffer, 0, &lengthAtOffset, &totalLength, &dataPtr);
        }
    }
    if (status != noErr || !dataPtr || totalLength == 0) {
        if (contiguousBuffer) CFRelease(contiguousBuffer);
        return;
    }

    NSMutableArray<NSData *> *nalUnits = [NSMutableArray array];
    if (isKeyframe && sps && pps) {
        [nalUnits addObject:sps];
        [nalUnits addObject:pps];
    }

    const uint8_t *bytes = (const uint8_t *)dataPtr;
    size_t offset = 0;
    while (offset + 4 <= totalLength) {
        uint32_t naluLen = ((uint32_t)bytes[offset] << 24) |
                           ((uint32_t)bytes[offset + 1] << 16) |
                           ((uint32_t)bytes[offset + 2] << 8) |
                           (uint32_t)bytes[offset + 3];
        offset += 4;
        if (offset + naluLen > totalLength) break;
        [nalUnits addObject:[NSData dataWithBytes:bytes + offset length:naluLen]];
        offset += naluLen;
    }

    if (contiguousBuffer) {
        CFRelease(contiguousBuffer);
    }

    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    uint32_t rtpTimestamp = (uint32_t)(pts.value * 90000 / pts.timescale);

    // VideoToolbox calls back on whichever thread it likes, and two frames'
    // callbacks can overlap. The packetizer's sequence numbers and the
    // session's SRTP context are one stream each: interleaved, the peer saw
    // a tenth of our packets as lost.
    @synchronized (_packetizer) {
        NSArray<NSData *> *rtpPackets = [_packetizer packetizeAccessUnit:nalUnits
                                                               timestamp:rtpTimestamp];

        static NSUInteger compressCount = 0;
        if (++compressCount % 30 == 1 || isKeyframe) {
            NSLog(@"TGCallVideoEngine: compressed frame #%lu (%lu NALs, %lu bytes, isKey=%d, pkts=%lu)",
                  (unsigned long)compressCount, (unsigned long)nalUnits.count, (unsigned long)totalLength, isKeyframe, (unsigned long)rtpPackets.count);
        }

        if (self.sendVideoRtpBlock) {
            for (NSData *pkt in rtpPackets) {
                self.sendVideoRtpBlock(pkt);
            }
        }
    }
}

#pragma mark - Incoming RTP & Decoding Pipeline

- (void)handleIncomingVideoRtp:(const uint8_t *)bytes length:(size_t)length {
    BOOL vp8 = self.receiveCodec == TGCallVideoCodecVP8;
    // Waiting for a keyframe keeps asking for one: a single PLI lost on the
    // way left the picture frozen until the sender's next periodic keyframe,
    // 6 s on the stand at 8% loss. The session sends at most two a second.
    if ((vp8 ? _vp8Depacketizer.waitingForKeyframe : _depacketizer.waitingForKeyframe) &&
        self.onUndecodableFrame)
        self.onUndecodableFrame();
    if (!vp8) {
        [_depacketizer processRtpPacket:bytes length:length];
        return;
    }
    int keyframe = 0;
    if (!TGVP8DepacketizerPush(&_vp8Depacketizer, bytes, length, &keyframe))
        return;
    if (!_vp8Decoder)
        _vp8Decoder = TGVP8DecoderOpen(kTGVP8DecodeMaxPixels);
    TGVP8Image image;
    if (!TGVP8Decode(_vp8Decoder, _vp8Depacketizer.frame, _vp8Depacketizer.length, &image)) {
        // A frame that does not decode leaves the decoder's references wrong
        // until a keyframe; ask for one instead of drawing garbage.
        TGVP8DepacketizerDrop(&_vp8Depacketizer);
        if (self.onUndecodableFrame)
            self.onUndecodableFrame();
        return;
    }
    _decodedFrames++;
#if TARGET_OS_IPHONE
    // libvpx reuses the planes on the next decode; the drawing is on the main
    // queue, so it gets its own copy.
    int w = image.width, h = image.height;
    NSData *y = [NSData dataWithBytes:image.plane[0] length:(size_t)(image.stride[0] * h)];
    NSData *u = [NSData dataWithBytes:image.plane[1] length:(size_t)(image.stride[1] * ((h + 1) / 2))];
    NSData *v = [NSData dataWithBytes:image.plane[2] length:(size_t)(image.stride[2] * ((h + 1) / 2))];
    int sy = image.stride[0], su = image.stride[1], sv = image.stride[2];
    __weak TGCallVideoEngine *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        TGCallVideoEngine *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf->_remoteView displayYUV420pY:(const uint8_t *)y.bytes U:(const uint8_t *)u.bytes
                                               V:(const uint8_t *)v.bytes
                                         strideY:sy strideU:su strideV:sv width:w height:h];
    });
#endif
    [self markRemoteVideo];
}

- (void)markRemoteVideo {
    if (_hasRemoteVideo)
        return;
    _hasRemoteVideo = YES;
    __weak TGCallVideoEngine *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.onRemoteVideoStateChanged)
            weakSelf.onRemoteVideoStateChanged(YES);
    });
}

- (void)didDecodePixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (++_decodedFrames == 1 || _decodedFrames % 50 == 0) {
        OSType f = CVPixelBufferGetPixelFormatType(pixelBuffer);
        NSLog(@"TGCallVideoEngine: %u peer frames decoded, %dx%d, format %c%c%c%c, iosurface %d", _decodedFrames,
              (int)CVPixelBufferGetWidth(pixelBuffer), (int)CVPixelBufferGetHeight(pixelBuffer),
              (char)(f >> 24), (char)(f >> 16), (char)(f >> 8), (char)f, CVPixelBufferGetIOSurface(pixelBuffer) != NULL);
    }
#if TARGET_OS_IPHONE
    // One picture waits for the main thread at most; a newer one takes its
    // place. A draw queued per frame held a buffer each while the A4's main
    // thread fell behind, VideoToolbox's pool ran dry, and every decode call
    // waited ~54 ms for a buffer to come back - the picture fell seconds
    // behind and the receive thread with it.
    CVPixelBufferRetain(pixelBuffer);
    BOOL queued;
    @synchronized (self) {
        queued = _pendingPicture != NULL;
        if (_pendingPicture)
            CVPixelBufferRelease(_pendingPicture);
        _pendingPicture = pixelBuffer;
    }
    if (!queued) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CVPixelBufferRef picture;
            @synchronized (self) {
                picture = self->_pendingPicture;
                self->_pendingPicture = NULL;
            }
            if (picture) {
                [self->_remoteView displayPixelBuffer:picture];
                CVPixelBufferRelease(picture);
            }
        });
    }
#endif
    if (self.onDecodedPixelBuffer) {
        self.onDecodedPixelBuffer(pixelBuffer);
    }
}

- (void)didAssembleRemoteFrame:(NSData *)avccFrame
                    isKeyframe:(BOOL)isKeyframe
                           sps:(NSData *)sps
                           pps:(NSData *)pps {
    if (!avccFrame || avccFrame.length == 0) return;
    static unsigned assembled, keys, rebuilds;
    static double tRebuild, tDecode;
    keys += isKeyframe;
    if (++assembled % 50 == 1)
        NSLog(@"TGCallVideoEngine: %u peer frames assembled (%u key), %u decoded, decoder %s; %u rebuilds %.0f ms, decode calls %.0f ms",
              assembled, keys, _decodedFrames, _decompressionSession ? "VT" : "none", rebuilds, tRebuild * 1000, tDecode * 1000);
    double tStart = CACurrentMediaTime();

    // Parameter sets come with every keyframe; the decoder is rebuilt only
    // when they change, which is a new resolution or a camera switch.
    if (isKeyframe && sps && pps &&
        (!_decompFormatDesc || ![sps isEqualToData:_decoderSps] || ![pps isEqualToData:_decoderPps])) {
        _decoderSps = sps;
        _decoderPps = pps;
        if (_decompFormatDesc) {
            CFRelease(_decompFormatDesc);
            _decompFormatDesc = NULL;
        }

        OSStatus status;
        if (TGHasParameterSetAPIs()) {
            const uint8_t *pointers[2] = { (const uint8_t *)sps.bytes, (const uint8_t *)pps.bytes };
            const size_t sizes[2] = { sps.length, pps.length };
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                kCFAllocatorDefault, 2, pointers, sizes, 4, &_decompFormatDesc);
        } else {
            // iOS 6: the same description, built from an avcC atom the way
            // decoders did before iOS 7.
            uint8_t avcc[512];
            size_t avccLength = TGAvcCBuild((const uint8_t *)sps.bytes, sps.length,
                                            (const uint8_t *)pps.bytes, pps.length, avcc, sizeof(avcc));
            int width = 0, height = 0;
            if (!avccLength || !TGH264SpsSize((const uint8_t *)sps.bytes, sps.length, &width, &height)) {
                NSLog(@"TGCallVideoEngine: SPS of %lu bytes not understood", (unsigned long)sps.length);
                return;
            }
            NSDictionary *extensions = @{
                (id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms :
                    @{ @"avcC" : [NSData dataWithBytes:avcc length:avccLength] },
            };
            status = CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264,
                                                    width, height, (__bridge CFDictionaryRef)extensions,
                                                    &_decompFormatDesc);
        }
        if (status != noErr) {
            NSLog(@"TGCallVideoEngine: CreateFromH264ParameterSets failed: %d", (int)status);
            return;
        }
        [self initDecompressionSession];
        rebuilds++;
        tRebuild += CACurrentMediaTime() - tStart;
    }

    if (!_decompFormatDesc) return;

    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(
        kCFAllocatorDefault,
        (void *)avccFrame.bytes,
        avccFrame.length,
        kCFAllocatorNull,
        NULL,
        0,
        avccFrame.length,
        0,
        &blockBuffer
    );
    if (status != noErr || !blockBuffer) return;

    CMSampleBufferRef sampleBuffer = NULL;
    status = CMSampleBufferCreate(
        kCFAllocatorDefault,
        blockBuffer,
        true,
        NULL,
        NULL,
        _decompFormatDesc,
        1,
        0,
        NULL,
        0,
        NULL,
        &sampleBuffer
    );
    CFRelease(blockBuffer);
    if (status != noErr || !sampleBuffer) return;

#if TARGET_OS_IPHONE
    if (_remoteView.sampleLayer) {
        // iOS 8 and later: the layer decodes in hardware and draws. Decoding
        // here as well would do the same work twice.
        [_remoteView displaySampleBuffer:sampleBuffer];
        _decodedFrames++;
    } else
#endif
    if (_decompressionSession) {
        // Asynchronous, and no 1xRealTimePlayback: with it VideoToolbox held
        // each call ~75 ms on the iPod touch 4 (the receive thread was busy
        // 99% with the CPU two-thirds idle) and the picture fell seconds
        // behind. The output callback draws whenever a frame is done.
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        double t0 = CACurrentMediaTime();
        VTDecompressionSessionDecodeFrame(_decompressionSession, sampleBuffer, flags, NULL, NULL);
        tDecode += CACurrentMediaTime() - t0;
    }
#if HAS_FFMPEG_FALLBACK
    else if (_ffmpegCodecCtx) {
        [self decodeWithFFmpegAvcc:avccFrame isKeyframe:isKeyframe sps:sps pps:pps];
    }
#endif

    CFRelease(sampleBuffer);

    if (!_hasRemoteVideo) {
        _hasRemoteVideo = YES;
        __weak TGCallVideoEngine *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.onRemoteVideoStateChanged) {
                weakSelf.onRemoteVideoStateChanged(YES);
            }
        });
    }
}

- (void)initDecompressionSession {
    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = NULL;
    }

    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = DecompressionCallback;
    callbackRecord.decompressionOutputRefCon = (__bridge void *)self;

    // IOSurface for the GL texture cache, and no pixel format: the decoder's
    // own is 420f for a full-range stream (official iOS sends one), and
    // asking for 420v had every frame converted - ~55-85 ms a frame on the
    // iPod touch 4 against ~3 ms decoded natively. The shader takes either.
    NSDictionary *destinationImageBufferAttributes = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };

    OSStatus status = VTDecompressionSessionCreate(
        kCFAllocatorDefault,
        _decompFormatDesc,
        NULL,
        (__bridge CFDictionaryRef)destinationImageBufferAttributes,
        &callbackRecord,
        &_decompressionSession
    );

    if (status != noErr) {
        NSLog(@"TGCallVideoEngine: VTDecompressionSessionCreate failed: %d", (int)status);
        _decompressionSession = NULL;
#if HAS_FFMPEG_FALLBACK
        [self initFFmpegDecoder];
#endif
    }
}

#if HAS_FFMPEG_FALLBACK
- (void)initFFmpegDecoder {
    if (_ffmpegCodecCtx) return;
    const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (!codec) return;
    _ffmpegCodecCtx = avcodec_alloc_context3(codec);
    if (!_ffmpegCodecCtx) return;
    _ffmpegCodecCtx->flags |= AV_CODEC_FLAG_LOW_DELAY;
    if (avcodec_open2(_ffmpegCodecCtx, codec, NULL) < 0) {
        avcodec_free_context(&_ffmpegCodecCtx);
        _ffmpegCodecCtx = NULL;
        return;
    }
    _ffmpegFrame = av_frame_alloc();
    _ffmpegPacket = av_packet_alloc();
    NSLog(@"TGCallVideoEngine: initialized FFmpeg H.264 software decoder fallback");
}

- (void)teardownFFmpegDecoder {
    if (_ffmpegPacket) {
        av_packet_free(&_ffmpegPacket);
        _ffmpegPacket = NULL;
    }
    if (_ffmpegFrame) {
        av_frame_free(&_ffmpegFrame);
        _ffmpegFrame = NULL;
    }
    if (_ffmpegCodecCtx) {
        avcodec_free_context(&_ffmpegCodecCtx);
        _ffmpegCodecCtx = NULL;
    }
}

- (void)decodeWithFFmpegAvcc:(NSData *)avccFrame
                  isKeyframe:(BOOL)isKeyframe
                         sps:(NSData *)sps
                         pps:(NSData *)pps {
    if (!_ffmpegCodecCtx || !_ffmpegPacket || !_ffmpegFrame) return;

    NSMutableData *annexB = [NSMutableData data];
    if (isKeyframe && sps && pps) {
        const uint8_t startCode[4] = { 0, 0, 0, 1 };
        [annexB appendBytes:startCode length:4];
        [annexB appendData:sps];
        [annexB appendBytes:startCode length:4];
        [annexB appendData:pps];
    }

    const uint8_t *bytes = (const uint8_t *)avccFrame.bytes;
    size_t len = avccFrame.length;
    size_t offset = 0;
    while (offset + 4 <= len) {
        uint32_t naluLen = ((uint32_t)bytes[offset] << 24) |
                           ((uint32_t)bytes[offset + 1] << 16) |
                           ((uint32_t)bytes[offset + 2] << 8) |
                           (uint32_t)bytes[offset + 3];
        offset += 4;
        if (offset + naluLen > len) break;
        const uint8_t startCode[4] = { 0, 0, 0, 1 };
        [annexB appendBytes:startCode length:4];
        [annexB appendBytes:bytes + offset length:naluLen];
        offset += naluLen;
    }

    _ffmpegPacket->data = (uint8_t *)annexB.bytes;
    _ffmpegPacket->size = (int)annexB.length;

    int ret = avcodec_send_packet(_ffmpegCodecCtx, _ffmpegPacket);
    if (ret < 0) return;

    while (avcodec_receive_frame(_ffmpegCodecCtx, _ffmpegFrame) == 0) {
        const uint8_t *yData = _ffmpegFrame->data[0];
        const uint8_t *uData = _ffmpegFrame->data[1];
        const uint8_t *vData = _ffmpegFrame->data[2];
        int sY = _ffmpegFrame->linesize[0];
        int sU = _ffmpegFrame->linesize[1];
        int sV = _ffmpegFrame->linesize[2];
        int w = _ffmpegFrame->width;
        int h = _ffmpegFrame->height;

        NSData *yCopy = [NSData dataWithBytes:yData length:(size_t)(sY * h)];
        NSData *uCopy = [NSData dataWithBytes:uData length:(size_t)(sU * (h / 2))];
        NSData *vCopy = [NSData dataWithBytes:vData length:(size_t)(sV * (h / 2))];

        __weak TGCallVideoEngine *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            TGCallVideoEngine *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf->_remoteView displayYUV420pY:(const uint8_t *)yCopy.bytes
                                                  U:(const uint8_t *)uCopy.bytes
                                                  V:(const uint8_t *)vCopy.bytes
                                            strideY:sY strideU:sU strideV:sV
                                              width:w height:h];
        });
    }
}
#endif

#pragma mark - Shutdown & Memory Release

- (void)stop {
    [self stopCapture];

    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = NULL;
    }

#if HAS_FFMPEG_FALLBACK
    [self teardownFFmpegDecoder];
#endif

    if (_decompFormatDesc) {
        CFRelease(_decompFormatDesc);
        _decompFormatDesc = NULL;
    }

    [_depacketizer reset];
    TGVP8DepacketizerDrop(&_vp8Depacketizer);
    TGVP8DecoderClose(_vp8Decoder);
    _vp8Decoder = NULL;

#if TARGET_OS_IPHONE
    [_remoteView flushAndRemoveImage];
#endif

    if (_hasRemoteVideo) {
        _hasRemoteVideo = NO;
        __weak TGCallVideoEngine *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.onRemoteVideoStateChanged) {
                weakSelf.onRemoteVideoStateChanged(NO);
            }
        });
    }
}

- (void)dealloc {
    [self stop];
    if (_pendingPicture)
        CVPixelBufferRelease(_pendingPicture);
    // The capture queue has nothing left to run once capture has stopped.
    TGVP8EncoderClose(_vp8Encoder);
    free(_vp8Encoded);
    free(_vp8Payloads);
    free(_vp8Frame);
}

@end
