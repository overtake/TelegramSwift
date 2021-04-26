#import "libwebp.h"
#import <AppKit/AppKit.h>
#import "decode.h"
#import "encode.h"
#import "demux.h"
#import "mux.h"

NSImage * _Nullable convertFromWebP(NSData *imgData) {
   
    if (imgData == nil) {
        return nil;
    }
    WebPImageDecoder *decoder = [WebPImageDecoder decoderWithData:imgData scale: 2];
    
    return [decoder frameAtIndex:0 decodeForDisplay:YES].image;
    
}
