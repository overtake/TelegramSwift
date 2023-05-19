
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
NSImage * _Nullable drawSvgImageNano(NSData * _Nonnull data, CGSize size);

NSData * _Nullable prepareSvgImage(NSData * _Nonnull data);
NSImage * _Nullable renderPreparedImage(NSData * _Nonnull data, CGSize size, NSColor * _Nonnull backgroundColor, CGFloat scale);
