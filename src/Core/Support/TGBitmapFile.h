//
// TGBitmapFile - a decoded picture kept on disk as raw premultiplied BGRA
// behind a 16-byte header, so reading it back is a file read and a CGImage
// over the bytes: no PNG or WebP decoder, which on the iPod touch 4 took
// 10-20 ms per small sticker picture. Any thread.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/// The pixel format of these files: premultiplied BGRA, 8 bits a channel.
FOUNDATION_EXPORT CGBitmapInfo TGBitmapFileInfo(void);
/// Draws `image` into BGRA and writes it to `path`; NO for an empty image.
FOUNDATION_EXPORT BOOL TGBitmapWrite(CGImageRef image, NSString *path);
/// +1 image over the file's bytes, NULL when the file is not one of these.
FOUNDATION_EXPORT CGImageRef TGBitmapCreate(NSString *path);
