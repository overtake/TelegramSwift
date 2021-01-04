#import "BuildConfig.h"

#import <Security/Security.h>
#import <AppKit/AppKit.h>

#import <MurMurHash32/MurMurHash32.h>
#import <CryptoUtils/CryptoUtils.h>

static NSString *telegramApplicationSecretKey = @"telegramApplicationSecretKey_v7";


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
    
- (NSData * _Nullable)getPublicKey {
    NSData *result = CFBridgingRelease(SecKeyCopyExternalRepresentation(_publicKey, nil));
    return result;
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
    
- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data cancelled:(bool *)cancelled {
    CFErrorRef error = NULL;
    NSData *plainText = (NSData *)CFBridgingRelease(SecKeyCreateDecryptedData(_privateKey, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM, (__bridge CFDataRef)data, &error));
    
    if (!plainText) {
        __unused NSError *err = CFBridgingRelease(error);
        if (err.code == -2) {
            if (cancelled) {
                *cancelled = true;
            }
        }
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


@interface AppEncryptionParameters () {
    NSString * _Nonnull _rootPath;
    NSData * _Nonnull key;
    NSData * _Nonnull iv;
}

@end

@implementation AppEncryptionParameters

-(id _Nonnull)initWithPath:(NSString * _Nonnull)path {
    self = [super init];
    if (self != nil) {
        self->_rootPath = path;
        if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
            [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
        [self applyPasscode:AppEncryptionParameters.defaultKey];
        [self upgradeLegacyIfNeeded];
        [self initializeIfNeeded];
    }
    return self;
}

+(NSString * _Nonnull)defaultKey {
    return @"no-matter-key";
}

-(void)applyPasscode:(NSString * _Nonnull)passcode {
    NSData *keyData = [passcode dataUsingEncoding:NSUTF8StringEncoding];
    NSData *sha512 = CryptoSHA512(keyData.bytes, keyData.length);
    self->key = [sha512 subdataWithRange:NSMakeRange(0, 32)];
    self->iv = [sha512 subdataWithRange:NSMakeRange(sha512.length - 16, 16)];
}

-(void)initializeIfNeeded {
    NSData *currentData = [NSData dataWithContentsOfFile:self.path];
    NSMutableData *resultData = nil;
    if (currentData != nil && currentData.length == 64) {
        resultData = [currentData mutableCopy];
    }
    if (resultData == nil) {
        NSMutableData *randomData = [[NSMutableData alloc] initWithLength:32 + 16];
        int result = SecRandomCopyBytes(kSecRandomDefault, randomData.length, [randomData mutableBytes]);
        resultData = randomData;
        
        int hash = murMurHash32Data(resultData);
        NSMutableData *hashData = [[NSMutableData alloc] initWithBytes:&hash length:4];
        [resultData appendData:hashData];

        while (resultData.length % 16 != 0) {
            int zero = 0;
            [resultData appendBytes:&zero length:1];
        }
        NSData *encrypted = CryptoAES(YES, self->key, self->iv, resultData);
        [encrypted writeToFile:self.path atomically:true];
    }
}

-(NSString *)path {
    return [self->_rootPath stringByAppendingPathComponent:@".tempkeyEncrypted"];
}

-(NSString *)legacyPath {
    return [self->_rootPath stringByAppendingPathComponent:@".tempkey"];
}

-(void)change:(NSString * _Nonnull)passcode {
    DeviceSpecificEncryptionParameters *parameters = [self decrypt];
    [self applyPasscode:passcode];
    [self reencrypt: parameters];

}
-(void)remove {
    DeviceSpecificEncryptionParameters *parameters = [self decrypt];
    [self applyPasscode:[AppEncryptionParameters defaultKey]];
    [self reencrypt: parameters];
}

-(NSData * _Nullable)encryptData:(NSData * _Nonnull)data {
    return CryptoAES(YES, self->key, self->iv, data);
}
-(NSData * _Nullable)decryptData:(NSData * _Nonnull)data {
    return CryptoAES(NO, self->key, self->iv, data);
}

-(void)upgradeLegacyIfNeeded {
    NSData *currentData = [NSData dataWithContentsOfFile:self.legacyPath];
    NSData *resultData = nil;
    if (currentData != nil && currentData.length == 32 + 16) {
        resultData = currentData;
    }
    if (resultData != nil) {
        int hash = murMurHash32Data(resultData);
        
        NSMutableData *hashData = [[NSMutableData alloc] initWithBytes:&hash length:4];
       
        
        NSData *key = [resultData subdataWithRange:NSMakeRange(0, 32)];
        NSData *salt = [resultData subdataWithRange:NSMakeRange(32, 16)];

        NSMutableData *finalData = [[NSMutableData alloc] init];
        
        [finalData appendData:key];
        [finalData appendData:salt];
        [finalData appendData:hashData];
        
        
        while (finalData.length % 16 != 0) {
            int zero = 0;
            [finalData appendBytes:&zero length:1];
        }
        
        NSData *encrypted = CryptoAES(YES, self->key, self->iv, finalData);
        [encrypted writeToFile:self.path atomically:YES];
        [[NSFileManager defaultManager] removeItemAtPath:self.legacyPath error:nil];
    }
}

-(void)reencrypt:(DeviceSpecificEncryptionParameters * _Nullable)parameters {
    
    if (parameters == nil) {
        [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
        [self initializeIfNeeded];
    }
    
    NSMutableData *resultData = [[NSMutableData alloc] init];
    [resultData appendData:parameters.key];
    [resultData appendData:parameters.salt];
    
    int hash = murMurHash32Data(resultData);
    
    NSMutableData *hashData = [[NSMutableData alloc] initWithBytes:&hash length:4];
    
    
    NSData *key = [resultData subdataWithRange:NSMakeRange(0, 32)];
    NSData *salt = [resultData subdataWithRange:NSMakeRange(32, 16)];
    
    NSMutableData *finalData = [[NSMutableData alloc] init];
    
    [finalData appendData:key];
    [finalData appendData:salt];
    [finalData appendData:hashData];
    
    
    while (finalData.length % 16 != 0) {
        int zero = 0;
        [finalData appendBytes:&zero length:1];
    }
    
    NSData *encrypted = CryptoAES(YES, self->key, self->iv, finalData);
    [encrypted writeToFile:self.path atomically:YES];
}

-(BOOL)hasPasscode {
    AppEncryptionParameters *params = [[AppEncryptionParameters alloc] initWithPath:self->_rootPath];
    return [params decrypt] == nil;
}

-(DeviceSpecificEncryptionParameters * _Nullable)decrypt {
    NSData *currentData = [NSData dataWithContentsOfFile:self.path];
    NSData *decrypted = CryptoAES(NO, self->key, self->iv, currentData);
    if (decrypted == nil || decrypted.length < 32 + 16 + 4) {
        return nil;
    }
    
    NSData *key = [decrypted subdataWithRange:NSMakeRange(0, 32)];
    NSData *salt = [decrypted subdataWithRange:NSMakeRange(32, 16)];;
    
    int innerHash = 0;
    [decrypted getBytes:&innerHash range:NSMakeRange(32 + 16, 4)];
    
    int hash = murMurHash32Data([decrypted subdataWithRange:NSMakeRange(0, 32 + 16)]);
    
    if (innerHash == hash) {
        return [[DeviceSpecificEncryptionParameters alloc] initWithKey:key salt:salt];
    }
    
    return nil;
    
}

@end


@implementation BuildConfig
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
    return @"6N38VWS5BX";
}



+ (NSString * _Nullable)bundleSeedId {
    return @"6N38VWS5BX";
}

+ (NSData * _Nonnull)applicationSecretTag:(bool)isCheckKey {
    if (isCheckKey) {
        return [[telegramApplicationSecretKey stringByAppendingString:@"_check"] dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        return [telegramApplicationSecretKey dataUsingEncoding:NSUTF8StringEncoding];
    }
}
    
+ (LocalPrivateKey * _Nullable)getApplicationSecretKey:(NSString * _Nonnull)baseAppBundleId isCheckKey:(bool)isCheckKey  {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [self applicationSecretTag:isCheckKey];
    NSString *accessGroup = bundleSeedId;//[bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassKey,
                            (id)kSecAttrApplicationTag: applicationTag,
                            (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                           // (id)kSecAttrAccessGroup: (id)accessGroup,
                            (id)kSecReturnRef: @YES
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
    
+ (bool)removeApplicationSecretKey:(NSString * _Nonnull)baseAppBundleId isCheckKey:(bool)isCheckKey  {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [self applicationSecretTag:isCheckKey];
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    NSDictionary *query = @{
                            (id)kSecClass: (id)kSecClassKey,
                            (id)kSecAttrApplicationTag: applicationTag,
                            (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                          //  (id)kSecAttrAccessGroup: (id)accessGroup
                            };
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status != errSecSuccess) {
        return false;
    }
    return true;
}
    
+ (LocalPrivateKey * _Nullable)createApplicationSecretKey  {
    
    NSDictionary *attributes = @{
                                 (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
                                 (id)kSecAttrKeySizeInBits: @256,
                                 (id)kSecPrivateKeyAttrs: @{
                                         (id)kSecAttrIsPermanent: @YES,
                                         },
                                 };
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
    if (!privateKey) {
        
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (!publicKey) {
        if (privateKey) {
            CFRelease(privateKey);
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
    return result;
}
    
+ (DeviceSpecificEncryptionParameters * _Nonnull)deviceSpecificEncryptionParameters:(NSString * _Nonnull)rootPath baseAppBundleId:(NSString * _Nonnull)baseAppBundleId {
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    NSString *filePath = [rootPath stringByAppendingPathComponent:@".tempkey"];
    
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
        resultData = randomData;
        [resultData writeToFile:filePath atomically:false];
    }
    
    
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    NSLog(@"deviceSpecificEncryptionParameters took %f ms", (endTime - startTime) * 1000.0);
    
    NSData *key = [resultData subdataWithRange:NSMakeRange(0, 32)];
    NSData *salt = [resultData subdataWithRange:NSMakeRange(32, 16)];
    return [[DeviceSpecificEncryptionParameters alloc] initWithKey:key salt:salt];
}


    
+ (dispatch_queue_t)encryptionQueue {
    static dispatch_queue_t instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = dispatch_queue_create("encryptionQueue", 0);
    });
    return instance;
}
//    
//    
//+ (void)encryptApplicationSecret:(NSData * _Nonnull)secret baseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^)(NSData * _Nullable, NSData * _Nullable))completion {
//    dispatch_async([self encryptionQueue], ^{
//        LocalPrivateKey *privateKey = [self getApplicationSecretKey:baseAppBundleId isCheckKey:false];
//        if (privateKey == nil) {
//            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:false];
//            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:true];
//            privateKey = [self addApplicationSecretKey:baseAppBundleId isCheckKey:false];
//            privateKey = [self addApplicationSecretKey:baseAppBundleId isCheckKey:true];
//        }
//        if (privateKey == nil) {
//            completion(nil, nil);
//            return;
//        }
//        NSData *result = [privateKey encrypt:secret];
//        completion(result, [privateKey getPublicKey]);
//    });
//}
//    
//+ (void)decryptApplicationSecret:(NSData * _Nonnull)secret publicKey:(NSData * _Nonnull)publicKey baseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^)(NSData * _Nullable))completion {
//    dispatch_async([self encryptionQueue], ^{
//        LocalPrivateKey *privateKey = [self getApplicationSecretKey:baseAppBundleId isCheckKey:false];
//        if (privateKey == nil) {
//            completion(nil);
//            return;
//        }
//        if (privateKey == nil) {
//            completion(nil);
//            return;
//        }
//        NSData *currentPublicKey = [privateKey getPublicKey];
//        if (currentPublicKey == nil) {
//            completion(nil);
//            return;
//        }
//        if (![publicKey isEqualToData:currentPublicKey]) {
//            completion(nil);
//            return;
//        }
//        NSData *result = [privateKey decrypt:secret cancelled:nil];
//        completion(result);
//    });
//}
//    
//


@end
