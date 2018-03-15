//
//  MP4Atom.m
//  Telegram
//
//  Created by Mikhail Filimonov on 08/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

#import "MP4Atom.h"


#import "MP4Atom.h"

static unsigned int to_host(unsigned char* p)
{
    return (p[0] << 24) + (p[1] << 16) + (p[2] << 8) + p[3];
}

@implementation MP4Atom

+ (MP4Atom*) atomAt:(int64_t) offset size:(int) length type:(OSType) fourcc inFile:(NSFileHandle*) handle
{
    MP4Atom* atom = [MP4Atom alloc];
    if (![atom init:offset size:length type:fourcc inFile:handle])
    {
        return nil;
    }
    return atom;
}

- (BOOL) init:(int64_t) offset size:(int) length type:(OSType) fourcc inFile:(NSFileHandle*) handle
{
    _file = handle;
    _offset = offset;
    _length = length;
    _type = fourcc;
    _nextChild = 0;
    
    return YES;
}

- (NSData *)readAt:(int64_t)offset size:(int)length
{
    [_file seekToFileOffset:_offset + offset];
    return [_file readDataOfLength:length];
}

- (BOOL)setChildOffset:(int64_t) offset
{
    _nextChild = offset;
    return YES;
}

- (MP4Atom*) nextChild
{
    if (_nextChild <= (_length - 8))
    {
        [_file seekToFileOffset:_offset + _nextChild];
        NSData *data = [_file readDataOfLength:8];
        if (data == nil || data.length == 0)
            return nil;
        
        int cHeader = 8;
        unsigned char* p = (unsigned char*) [data bytes];
        int64_t len = to_host(p);
        OSType fourcc = to_host(p + 4);
        if (len == 1)
        {
            // 64-bit extended length
            cHeader+= 8;
            data = [_file readDataOfLength:8];
            p = (unsigned char*) [data bytes];
            len = to_host(p);
            len = (len << 32) + to_host(p + 4);
        }
        else if (len == 0)
        {
            // whole remaining parent space
            len = _length - _nextChild;
        }
        if (fourcc == (OSType)('uuid'))
        {
            cHeader += 16;
        }
        if ((len < 0) || ((len + _nextChild) > _length))
        {
            return nil;
        }
        int64_t offset = _nextChild + cHeader;
        _nextChild += len;
        len -= cHeader;
        return [MP4Atom atomAt:offset+_offset size:(int)len type:fourcc inFile:_file];
    }
    return nil;
}

- (MP4Atom*) childOfType:(OSType) fourcc startAt:(int64_t) offset
{
    [self setChildOffset:offset];
    MP4Atom* child = nil;
    do {
        child = [self nextChild];
    } while ((child != nil) && (child.type != fourcc));
    return child;
}

@end

