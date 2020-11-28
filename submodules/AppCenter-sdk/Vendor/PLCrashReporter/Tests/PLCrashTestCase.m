/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2012-2013 Plausible Labs Cooperative, Inc.
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

#import "PLCrashTestCase.h"

#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach-o/arch.h>

@implementation PLCrashTestCase

/**
 * Return the full path to the request test resource.
 *
 * @param resourceName Relative resource path.
 *
 * Test resources are located in Bundle/Resources/Tests/TestClass/ResourceName
 */
- (NSString *) pathForTestResource: (NSString *) resourceName {
    NSString *className = NSStringFromClass([self class]);
    NSString *bundleResources = [[NSBundle bundleForClass: [self class]] resourcePath];
    NSString *testResources = [bundleResources stringByAppendingPathComponent: @"Tests"];
    NSString *testRoot = [testResources stringByAppendingPathComponent: className];
    
    return [testRoot stringByAppendingPathComponent: resourceName];
}

/**
 * Find the test resource with the given @a resourceName, and load the resource's data.
 *
 * @param resourceName Relative resource path.
 */
- (NSData *) dataForTestResource: (NSString *) resourceName {
    NSError *error;
    NSString *path = [self pathForTestResource: resourceName];
    NSData *result = [NSData dataWithContentsOfFile: path options: NSDataReadingUncached error: &error];
    NSAssert(result != nil, @"Failed to load resource data: %@", error);
    
    return result;
}

/**
 * Search the Mach-O fat binary with the given @a resourceName for an architecture that best matches the host architecture,
 * returning the mapped thin binary.
 *
 * If a thin binary is loaded, it will be returned directly (regardless of the CPU type).
 */
- (NSData *) nativeBinaryFromTestResource: (NSString *) resourceName {
    NSData *data = [self dataForTestResource: resourceName];
    STAssertNotNil(data, @"Failed to load binary data");

    const uint8_t *bytes = [data bytes];
    const struct fat_header *fh = [data bytes];    
    STAssertTrue([data length] >= sizeof(*fh), @"Image %@ is not large enough to contain a fat header", resourceName);


    /* Handle thin binaries directly */
    if (fh->magic != FAT_MAGIC && fh->magic != FAT_CIGAM) {
        STAssertTrue(fh->magic == MH_MAGIC || fh->magic == MH_MAGIC_64 || fh->magic == MH_CIGAM || fh->magic == MH_CIGAM_64, @"%@ is not a valid Mach-O binary", resourceName);
        return data;
    }

    /* Load all the fat architectures */
    const struct fat_arch *base = (const struct fat_arch *) (bytes + sizeof(struct fat_header));
    uint32_t count = OSSwapBigToHostInt32(fh->nfat_arch);
    struct fat_arch *archs = calloc(count, sizeof(struct fat_arch));
    for (uint32_t i = 0; i < count; i++) {
        const struct fat_arch *fa = &base[i];
        if (((const uint8_t *)fa) + sizeof(*fa) >= bytes + [data length]) {
            STFail(@"Arch pointer for %@ outside of mapped range", resourceName);
        }

        archs[i].cputype = OSSwapBigToHostInt32(fa->cputype);
        archs[i].cpusubtype = OSSwapBigToHostInt32(fa->cpusubtype);
        archs[i].offset = OSSwapBigToHostInt32(fa->offset);
        archs[i].size = OSSwapBigToHostInt32(fa->size);
        archs[i].align = OSSwapBigToHostInt32(fa->align);
    }

    /* Find the right architecture; we based this on the first loaded Mach-O image, as NXGetLocalArchInfo returns
     * the incorrect i386 cpu type on x86-64. */
    const struct mach_header *hdr = _dyld_get_image_header(0);
    const struct fat_arch *best_arch = NXFindBestFatArch(hdr->cputype, hdr->cpusubtype, archs, count);

    STAssertNotNULL(best_arch, @"Could not find a matching architecture for %@", resourceName);
    NSData *result = [data subdataWithRange: NSMakeRange(best_arch->offset, best_arch->size)];
    
    /* Clean up */
    free(archs);
    
    return result;
}

@end
