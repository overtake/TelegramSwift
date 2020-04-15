#ifndef Telegram_GZip_h
#define Telegram_GZip_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    NSData *TGGZipData(NSData * __nonnull data, float level);
    NSData * _Nullable TGGUnzipData(NSData *data, uint sizeLimit);
    
#ifdef __cplusplus
}
#endif

#endif
