//
// TGMediaSupport.h - file-record helpers the media store shares.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
NSString *TGFileTextAnswer(NSDictionary *result);
NSDictionary *TGFlattenFileRecord(NSDictionary *file);
#ifdef __cplusplus
}
#endif
