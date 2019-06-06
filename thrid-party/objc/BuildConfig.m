#import "BuildConfig.h"

#import <Security/Security.h>
#import <AppKit/AppKit.h>

@interface LocalPrivateKey : NSObject {
    SecKeyRef _privateKey;
    SecKeyRef _publicKey;
}

- (NSData * _Nullable)encrypt:(NSData * _Nonnull)data;
- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data;

@end

@implementation LocalPrivateKey

- (instancetype _Nonnull)initWithPrivateKey:(SecKeyRef)privateKey publicKey:(SecKeyRef)publicKey {
    self = [super init];
    if (self != nil) {
        _privateKey = (SecKeyRef)CFRetain(privateKey);
        _publicKey = (SecKeyRef)CFRetain(publicKey);
    }
    return self;
}

- (void)dealloc {
    CFRelease(_privateKey);
    CFRelease(_publicKey);
}

- (NSData * _Nullable)encrypt:(NSData * _Nonnull)data {
    if (data.length % 16 != 0) {
        return nil;
    }
    
    CFErrorRef error = NULL;
    NSData *cipherText = (NSData *)CFBridgingRelease(SecKeyCreateEncryptedData(_publicKey, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM, (__bridge CFDataRef)data, &error));
    
    if (!cipherText) {
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    return cipherText;
}

- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data {
    CFErrorRef error = NULL;
    NSData *plainText = (NSData *)CFBridgingRelease(SecKeyCreateDecryptedData(_privateKey, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM, (__bridge CFDataRef)data, &error));
    
    if (!plainText) {
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    return plainText;
}

@end

@interface BuildConfig () {
    NSData * _Nullable _bundleData;
    int32_t _apiId;
    NSString * _Nonnull _apiHash;
    NSString * _Nullable _hockeyAppId;
}

@end

@implementation DeviceSpecificEncryptionParameters

- (instancetype)initWithKey:(NSData * _Nonnull)key salt:(NSData * _Nonnull)salt {
    self = [super init];
    if (self != nil) {
        _key = key;
        _salt = salt;
    }
    return self;
}

@end

@implementation BuildConfig
//6N38VWS5BX.ru.keepcoder.telegram
+ (NSString *)bundleId {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
        (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
        @"bundleSeedID", kSecAttrAccount,
        @"", kSecAttrService,
        (id)kCFBooleanTrue, kSecReturnAttributes,
    nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    }
    if (status != errSecSuccess) {
        return nil;
    }
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedID = [[components objectEnumerator] nextObject];
    CFRelease(result);
    return bundleSeedID;
}



+ (NSString * _Nullable)bundleSeedId {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
       (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
       @"bundleSeedID", kSecAttrAccount,
       @"", kSecAttrService,
       (id)kCFBooleanTrue, kSecReturnAttributes,
    nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    }
    if (status != errSecSuccess) {
        return nil;
    }
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedID = [[components objectEnumerator] nextObject];
    CFRelease(result);
    return @"6N38VWS5BX";
}

+ (LocalPrivateKey * _Nullable)getLocalPrivateKey:(NSString * _Nonnull)baseAppBundleId {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    NSData *applicationTag = [@"telegramLocalKey" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassKey,
        (id)kSecAttrApplicationTag: applicationTag,
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrAccessGroup: (id)accessGroup,
        (id)kSecReturnRef: @YES,
    };
    SecKeyRef privateKey = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&privateKey);
    if (status != errSecSuccess) {
        return nil;
    }
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (!publicKey) {
        if (privateKey) {
            CFRelease(privateKey);
        }
        return nil;
    }
    
    LocalPrivateKey *result = [[LocalPrivateKey alloc] initWithPrivateKey:privateKey publicKey:publicKey];
    
    if (publicKey) {
        CFRelease(publicKey);
    }
    if (privateKey) {
        CFRelease(privateKey);
    }
    
    return result;
}

+ (bool)removeLocalPrivateKey:(NSString * _Nonnull)baseAppBundleId {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [@"telegramLocalKey" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassKey,
        (id)kSecAttrApplicationTag: applicationTag,
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrAccessGroup: (id)accessGroup
    };
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status != errSecSuccess) {
        return false;
    }
    return true;
}

+ (LocalPrivateKey * _Nullable)addLocalPrivateKey:(NSString * _Nonnull)baseAppBundleId {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [@"telegramLocalKey" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAlwaysThisDeviceOnly, kSecAccessControlPrivateKeyUsage, NULL);
    NSDictionary *attributes = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeySizeInBits: @256,
        (id)kSecAttrTokenID: (id)kSecAttrTokenIDSecureEnclave,
        (id)kSecPrivateKeyAttrs: @{
            (id)kSecAttrIsPermanent: @YES,
            (id)kSecAttrApplicationTag: applicationTag,
            (id)kSecAttrAccessControl: (__bridge id)access,
            (id)kSecAttrAccessGroup: (id)accessGroup,
        },
    };
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
    if (!privateKey) {
        if (access) {
            CFRelease(access);
        }
        
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (!publicKey) {
        if (privateKey) {
            CFRelease(privateKey);
        }
        if (access) {
            CFRelease(access);
        }
        
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    LocalPrivateKey *result = [[LocalPrivateKey alloc] initWithPrivateKey:privateKey publicKey:publicKey];
    
    if (publicKey) {
        CFRelease(publicKey);
    }
    if (privateKey) {
        CFRelease(privateKey);
    }
    if (access) {
        CFRelease(access);
    }
    
    return result;
}

+ (DeviceSpecificEncryptionParameters * _Nonnull)deviceSpecificEncryptionParameters:(NSString * _Nonnull)rootPath baseAppBundleId:(NSString * _Nonnull)baseAppBundleId {
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    
    
    if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_12)  {
        int bytesCount = 32 + 16;
        NSMutableData *data = [[NSMutableData alloc] init];
        
        for (int i = 0; i < bytesCount; i++) {
            int b = 0;
            [data appendBytes:&b length:1];
        }
        NSData *key = [data subdataWithRange:NSMakeRange(0, 32)];
        NSData *salt = [data subdataWithRange:NSMakeRange(32, 16)];
        return [[DeviceSpecificEncryptionParameters alloc] initWithKey:key salt:salt];
    }
    
   
    
    NSString *filePath = [rootPath stringByAppendingPathComponent:@".tempkey"];
    NSString *encryptedPath = [rootPath stringByAppendingPathComponent:@".tempkeyEncrypted"];
    

    NSData *currentData = [NSData dataWithContentsOfFile:filePath];
    NSData *resultData = nil;
    if (currentData != nil && currentData.length == 32 + 16) {
        resultData = currentData;
    }
    if (resultData == nil) {
        NSMutableData *randomData = [[NSMutableData alloc] initWithLength:32 + 16];
        int result = SecRandomCopyBytes(kSecRandomDefault, randomData.length, [randomData mutableBytes]);
        if (currentData != nil && currentData.length == 32) { // upgrade key with salt
            [currentData getBytes:randomData.mutableBytes length:32];
        }
        assert(result == 0);
        resultData = randomData;
        [resultData writeToFile:filePath atomically:false];
    }
    
    NSData *currentEncryptedData = [NSData dataWithContentsOfFile:encryptedPath];
    
    LocalPrivateKey *localPrivateKey = [self getLocalPrivateKey:baseAppBundleId];
    
    if (localPrivateKey == nil) {
        localPrivateKey = [self addLocalPrivateKey:baseAppBundleId];
    }
    
    if (localPrivateKey != nil) {
        if (currentEncryptedData != nil) {
            NSData *decryptedData = [localPrivateKey decrypt:currentEncryptedData];
            
            if (![resultData isEqualToData:decryptedData]) {
                NSData *encryptedData = [localPrivateKey encrypt:resultData];
                [encryptedData writeToFile:encryptedPath atomically:false];
                assert(false);
            }
        } else {
            NSData *encryptedData = [localPrivateKey encrypt:resultData];
            [encryptedData writeToFile:encryptedPath atomically:false];
        }
    }
    
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    NSLog(@"deviceSpecificEncryptionParameters took %f ms", (endTime - startTime) * 1000.0);
    
    NSData *key = [resultData subdataWithRange:NSMakeRange(0, 32)];
    NSData *salt = [resultData subdataWithRange:NSMakeRange(32, 16)];
    return [[DeviceSpecificEncryptionParameters alloc] initWithKey:key salt:salt];
}

@end
