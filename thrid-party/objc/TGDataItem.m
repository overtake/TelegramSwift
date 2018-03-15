#import "TGDataItem.h"

#import "ATQueue.h"

@interface TGDataItem ()
{
    ATQueue *_queue;
    NSUInteger _length;
    
    NSString *_fileName;
    bool _fileExists;
    
    NSMutableData *_data;
}

@end



@implementation TGDataItem

- (void)_commonInit
{
    _queue = [[ATQueue alloc] initWithPriority:ATQueuePriorityLow];
    _data = [[NSMutableData alloc] init];
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self != nil)
    {
        [self _commonInit];
        int64_t randomId = 0;
        arc4random_buf(&randomId, 8);
        _fileName = filePath;
        _fileExists = false;
    }
    return self;
}


- (void)moveToPath:(NSString *)path
{
    [_queue dispatch:^
    {   
        [[NSFileManager defaultManager] moveItemAtPath:_fileName toPath:path error:nil];
        _fileName = path;
    }];
}

- (void)remove
{
    [_queue dispatch:^
    {
        [[NSFileManager defaultManager] removeItemAtPath:_fileName error:nil];
    }];
}

- (void)appendData:(NSData *)data
{
    [_queue dispatch:^
    {
        if (!_fileExists)
        {
            [[NSFileManager defaultManager] createFileAtPath:_fileName contents:nil attributes:nil];
            _fileExists = true;
        }
        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_fileName];
        [file seekToEndOfFile];
        [file writeData:data];
        [file synchronizeFile];
        [file closeFile];
        _length += data.length;
        [_data appendData:data];
    }];
}

- (NSData *)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length
{
    __block NSData *data = nil;
    
    [_queue dispatch:^
    {
        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_fileName];
        [file seekToFileOffset:(unsigned long long)offset];
        data = [file readDataOfLength:length];
        if (data.length != length)
            NSLog(@"Read data length mismatch");
        [file closeFile];
    } synchronous:true];
    
    return data;
}

- (NSUInteger)length
{
    __block NSUInteger result = 0;
    [_queue dispatch:^
    {
        result = _length;
    } synchronous:true];
    
    return result;
}

- (NSString *)path {
    return _fileName;
}

@end
