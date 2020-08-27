//
//  Mozjpeg.h
//  Mozjpeg
//
//  Created by Mikhail Filimonov on 27/08/2020.
//  Copyright © 2020 Mikhail Filimonov. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for Mozjpeg.
FOUNDATION_EXPORT double MozjpegVersionNumber;

//! Project version string for Mozjpeg.
FOUNDATION_EXPORT const unsigned char MozjpegVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <Mozjpeg/PublicHeader.h>


NSData * _Nullable compressJPEGData(CGImageRef _Nonnull sourceImage);
NSArray<NSNumber *> * _Nonnull extractJPEGDataScans(NSData * _Nonnull data);
NSData * _Nullable compressMiniThumbnail(CGImageRef _Nonnull image);
