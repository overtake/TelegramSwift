/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "PLCrashReportBinaryImageInfo.h"

/**
 * Crash Log binary image info. Represents an executable or shared library.
 */
@implementation PLCrashReportBinaryImageInfo

@synthesize codeType = _processorInfo;
@synthesize imageBaseAddress = _baseAddress;
@synthesize imageSize = _imageSize;
@synthesize imageName = _imageName;
@synthesize hasImageUUID = _hasImageUUID;
@synthesize imageUUID = _imageUUID;

/**
 * Initialize with the given binary image properties.
 *
 * @param processorInfo The image's code type, or nil if unavailable.
 * @param baseAddress The image's base address.
 * @param size The image's segment size.
 * @param name The image's name (absolute path).
 * @param uuid The image's UUID, or nil if unavailable. In the case of Mach-O, this will be the 128-bit
 * object UUID, which is also used to match against the corresponding Mach-O DWARF dSYM file.
 */
- (id) initWithCodeType: (PLCrashReportProcessorInfo *) processorInfo
            baseAddress: (uint64_t) baseAddress 
                   size: (uint64_t) size
                   name: (NSString *) name
                   uuid: (NSData *) uuid
{
    if ((self = [super init]) == nil)
        return nil;

    _baseAddress = baseAddress;
    _imageSize = size;
    _imageName = name;
    _processorInfo = processorInfo;

    if (uuid != nil) {
        _hasImageUUID = YES;

        /* Convert UUID to ASCII hex representation. */
        size_t inlen = [uuid length];
        size_t outlen = inlen * 2;
        char *output = malloc(outlen);
        const char hex[] = "0123456789abcdef";
        const uint8_t *bytes = [uuid bytes];

        for (int i = 0; i < inlen; i++) {
            uint8_t c = bytes[i];
            output[i * 2 + 0] = hex[c >> 4];
            output[i * 2 + 1] = hex[c & 0x0F];
        }

       _imageUUID = [[NSString alloc] initWithBytesNoCopy: output 
                                                   length: outlen 
                                                 encoding: NSASCIIStringEncoding
                                             freeWhenDone: YES];
    }

    return self;
}

@end
