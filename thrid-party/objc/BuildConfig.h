#import <Foundation/Foundation.h>

@interface DeviceSpecificEncryptionParameters : NSObject

@property (nonatomic, strong) NSData * _Nonnull key;
@property (nonatomic, strong) NSData * _Nonnull salt;

@end


@interface AppEncryptionParameters : NSObject

-(id _Nonnull)initWithPath:(NSString * _Nonnull)path;
-(void)applyPasscode:(NSString * _Nonnull)passcode;
-(void)change:(NSString * _Nonnull)passcode;
-(void)remove;
-(DeviceSpecificEncryptionParameters * _Nullable)decrypt;

@end

@interface LocalPrivateKey : NSObject {
    SecKeyRef _privateKey;
    SecKeyRef _publicKey;
}
+ (NSString * _Nonnull)defaultKey;
- (NSData * _Nullable)encrypt:(NSData * _Nonnull)data;
- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data cancelled:(bool *)cancelled;

@end

@interface BuildConfig : NSObject

+ (DeviceSpecificEncryptionParameters * _Nonnull)deviceSpecificEncryptionParameters:(NSString * _Nonnull)rootPath baseAppBundleId:(NSString * _Nonnull)baseAppBundleId;

+ (LocalPrivateKey * _Nullable)createApplicationSecretKey;

@end
