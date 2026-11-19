//
// TGJSONCache - small app records (a chat's last page, a list of sticker
// packs) kept on disk as JSON. JSON, not a keyed archive: unarchiving thirty
// messages took 380-470 ms of the main thread on the iPod touch 4. Bytes
// (a voice note's waveform, a thumbnail) travel as {"$data": base64}.
//
#import <Foundation/Foundation.h>

/// Writes `object` (dictionaries, arrays, strings, numbers, NSNull, NSData)
/// to `path`; NO when something in it has no JSON form. Any thread.
FOUNDATION_EXPORT BOOL TGJSONCacheWrite(id object, NSString *path);
/// What TGJSONCacheWrite wrote, or nil. Any thread.
FOUNDATION_EXPORT id TGJSONCacheRead(NSString *path);
