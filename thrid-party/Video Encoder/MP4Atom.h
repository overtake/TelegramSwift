//
//  MP4Atom.h
//  Telegram
//
//  Created by Mikhail Filimonov on 08/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MP4Atom : NSObject

{
@public
    NSFileHandle* _file;
    int64_t _offset;
    int64_t _length;
    OSType _type;
    int64_t _nextChild;
}
@property (nonatomic) OSType type;
@property (nonatomic) int64_t length;

+ (MP4Atom*) atomAt:(int64_t) offset size:(int) length type:(OSType) fourcc inFile:(NSFileHandle*) handle;
- (BOOL) init:(int64_t) offset size:(int) length type:(OSType) fourcc inFile:(NSFileHandle*) handle;
- (NSData*) readAt:(int64_t) offset size:(int) length;
- (BOOL) setChildOffset:(int64_t) offset;
- (MP4Atom*) nextChild;
- (MP4Atom*) childOfType:(OSType) fourcc startAt:(int64_t) offset;

@end
