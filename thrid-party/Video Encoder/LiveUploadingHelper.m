//
//  LiveUploadingHelper.m
//  Telegram
//
//  Created by Mikhail Filimonov on 08/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

#import "LiveUploadingHelper.h"
#import "MP4Atom.h"
#import <sys/stat.h>


@implementation LiveUploadingHelper
+ (void)readFileURL:(NSURL *)fileURL processBlock:(void (^)(NSFileHandle *, struct stat, MP4Atom *))processBlock
{
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:fileURL.path];
    struct stat s;
    fstat([file fileDescriptor], &s);
    
    MP4Atom *fileAtom = [MP4Atom atomAt:0 size:(int)s.st_size type:(OSType)('file') inFile:file];
    MP4Atom *mdatAtom = [LiveUploadingHelper _findMdat:fileAtom];
    if (mdatAtom != nil && processBlock != nil)
        processBlock(file, s, mdatAtom);
    
    [file closeFile];
}

+ (MP4Atom *)_findMdat:(MP4Atom *)atom
{
    if (atom == nil)
        return nil;
    
    if (atom.type == (OSType)'mdat')
        return atom;
    
    while (true)
    {
        MP4Atom *child = [atom nextChild];
        if (child == nil)
            break;
        
        MP4Atom *result = [self _findMdat:child];
        if (result != nil)
            return result;
    }
    
    return nil;
}
@end
