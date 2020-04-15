#import <Foundation/Foundation.h>


@interface TGDataItem : NSObject


- (instancetype)initWithFilePath:(NSString *)filePath;

- (void)moveToPath:(NSString *)path;
- (void)remove;

- (void)appendData:(NSData *)data;
- (NSData *)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length;
- (NSUInteger)length;

- (NSString *)path;

@end
