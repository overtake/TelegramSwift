// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSACConstants+Internal.h"
#import "MSACEncrypterPrivate.h"
#import "MSACMockKeychainUtil.h"
#import "MSACMockUserDefaults.h"
#import "MSACTestFrameworks.h"
#import "MSACUtility+Date.h"

@interface MSACEncrypterTests : XCTestCase

@property(nonatomic) id keychainUtilMock;
@property(nonatomic) id settingsMock;

@end

@implementation MSACEncrypterTests

- (void)setUp {
  [super setUp];
  self.keychainUtilMock = [MSACMockKeychainUtil new];
  self.settingsMock = [MSACMockUserDefaults new];
}

- (void)tearDown {
  [self.settingsMock stopMocking];
  [self.keychainUtilMock stopMocking];
  [MSACMockKeychainUtil clear];
}

- (void)testEncryptWithCurrentKey {

  // If
  NSString *clearText = @"clear text";
  NSString *keyTag = kMSACEncryptionKeyTagAlternate;
  NSString *expectedMetadata = [NSString stringWithFormat:@"%@/AES/CBC/PKCS7/32", keyTag];

  // Save metadata to user defaults.
  NSDate *expiration = [NSDate dateWithTimeIntervalSinceNow:10000000];
  NSString *expirationIso = [MSACUtility dateToISO8601:expiration];
  NSString *keyMetadataString = [NSString stringWithFormat:@"%@/%@", keyTag, expirationIso];
  [MSAC_APP_CENTER_USER_DEFAULTS setObject:keyMetadataString forKey:kMSACEncryptionKeyMetadataKey];

  // Save key to the Keychain.
  NSString *currentKey = [self generateTestEncryptionKey];
  [MSACMockKeychainUtil storeString:currentKey forKey:keyTag];
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *encryptedString = [encrypter encryptString:clearText];

  // Then

  // Extract metadata.
  NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
  NSData *separatorAsData = [kMSACEncryptionMetadataSeparator dataUsingEncoding:NSUTF8StringEncoding];
  NSRange entireRange = NSMakeRange(0, [encryptedData length]);
  size_t metadataLength = [encryptedData rangeOfData:separatorAsData options:0 range:entireRange].location;
  NSData *subdata = [encryptedData subdataWithRange:NSMakeRange(0, metadataLength)];
  NSString *metadata = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(metadata, expectedMetadata);

  // Extract cipher text. Add 1 for the delimiter.
  size_t metadataAndIvLength = metadataLength + 1 + kCCBlockSizeAES128;
  NSRange cipherTextRange = NSMakeRange(metadataAndIvLength, [encryptedData length] - metadataAndIvLength);
  NSData *cipherTextSubdata = [encryptedData subdataWithRange:cipherTextRange];
  NSString *cipherText = [[NSString alloc] initWithData:cipherTextSubdata encoding:NSUTF8StringEncoding];
  XCTAssertNotEqualObjects(cipherText, clearText);

  // When
  NSString *decryptedString = [encrypter decryptString:encryptedString];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (void)testKeyRotatedOnFirstRunWithLegacyKeySaved {

  // If
  NSString *clearText = @"clear text";
  NSString *expectedMetadata = [NSString stringWithFormat:@"%@/AES/CBC/PKCS7/32", kMSACEncryptionKeyTagAlternate];

  // Mock NSDate to "freeze" time.
  NSTimeInterval timeSinceReferenceDate = NSDate.timeIntervalSinceReferenceDate;
  NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970:timeSinceReferenceDate];
  id nsdateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([nsdateMock timeIntervalSinceReferenceDate])).andReturn(timeSinceReferenceDate);
  OCMStub(ClassMethod([nsdateMock date])).andReturn(referenceDate);
  NSDate *expectedExpirationDate = [[NSDate date] dateByAddingTimeInterval:kMSACEncryptionKeyLifetimeInSeconds];
  NSString *expectedExpirationDateIso = [MSACUtility dateToISO8601:expectedExpirationDate];

  // Save key to the Keychain.
  NSString *currentKey = [self generateTestEncryptionKey];
  [MSACMockKeychainUtil storeString:currentKey forKey:kMSACEncryptionKeyTagOriginal];
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *encryptedString = [encrypter encryptString:clearText];

  // Then

  // Extract metadata.
  NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
  NSData *separatorAsData = [kMSACEncryptionMetadataSeparator dataUsingEncoding:NSUTF8StringEncoding];
  NSRange entireRange = NSMakeRange(0, [encryptedData length]);
  size_t metadataLength = [encryptedData rangeOfData:separatorAsData options:0 range:entireRange].location;
  NSData *subdata = [encryptedData subdataWithRange:NSMakeRange(0, metadataLength)];
  NSString *metadata = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(metadata, expectedMetadata);

  // Extract cipher text. Add 1 for the delimiter.
  size_t metadataAndIvLength = metadataLength + 1 + kCCBlockSizeAES128;
  NSRange cipherTextRange = NSMakeRange(metadataAndIvLength, [encryptedData length] - metadataAndIvLength);
  NSData *cipherTextSubdata = [encryptedData subdataWithRange:cipherTextRange];
  NSString *cipherText = [[NSString alloc] initWithData:cipherTextSubdata encoding:NSUTF8StringEncoding];
  XCTAssertNotEqualObjects(cipherText, clearText);

  // Ensure a new key and expiration were added to the user defaults.
  NSArray *newKeyAndExpiration = [[MSAC_APP_CENTER_USER_DEFAULTS objectForKey:kMSACEncryptionKeyMetadataKey]
      componentsSeparatedByString:kMSACEncryptionMetadataInternalSeparator];
  NSString *newKey = newKeyAndExpiration[0];
  XCTAssertEqualObjects(newKey, kMSACEncryptionKeyTagAlternate);
  NSString *expirationIso = newKeyAndExpiration[1];
  XCTAssertEqualObjects(expirationIso, expectedExpirationDateIso);

  // When
  NSString *decryptedString = [encrypter decryptString:encryptedString];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (void)testEncryptRotatesKeyWhenExpiredAndTwoKeysSaved {

  // If
  NSString *clearText = @"clear text";
  NSDate *pastDate = [NSDate dateWithTimeIntervalSince1970:0];
  NSString *currentExpirationIso = [MSACUtility dateToISO8601:pastDate];
  NSString *currentKeyTag = kMSACEncryptionKeyTagOriginal;
  NSString *expectedNewKeyTag = kMSACEncryptionKeyTagAlternate;
  NSString *currentKeyMetadataString = [NSString stringWithFormat:@"%@/%@", currentKeyTag, currentExpirationIso];
  [MSAC_APP_CENTER_USER_DEFAULTS setObject:currentKeyMetadataString forKey:kMSACEncryptionKeyMetadataKey];
  NSString *expectedMetadata = [NSString stringWithFormat:@"%@/AES/CBC/PKCS7/32", expectedNewKeyTag];

  // Mock NSDate to "freeze" time.
  NSTimeInterval timeSinceReferenceDate = NSDate.timeIntervalSinceReferenceDate;
  NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970:timeSinceReferenceDate];
  id nsdateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([nsdateMock timeIntervalSinceReferenceDate])).andReturn(timeSinceReferenceDate);
  OCMStub(ClassMethod([nsdateMock date])).andReturn(referenceDate);
  NSDate *expectedExpirationDate = [[NSDate date] dateByAddingTimeInterval:kMSACEncryptionKeyLifetimeInSeconds];
  NSString *expectedExpirationDateIso = [MSACUtility dateToISO8601:expectedExpirationDate];

  // Save both keys to the Keychain.
  NSString *currentKey = [self generateTestEncryptionKey];
  [MSACMockKeychainUtil storeString:currentKey forKey:currentKeyTag];
  NSString *expectedNewKey = [self generateTestEncryptionKey];
  [MSACMockKeychainUtil storeString:expectedNewKey forKey:expectedNewKeyTag];
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *encryptedString = [encrypter encryptString:clearText];

  // Then

  // Extract metadata.
  NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
  NSData *separatorAsData = [kMSACEncryptionMetadataSeparator dataUsingEncoding:NSUTF8StringEncoding];
  NSRange entireRange = NSMakeRange(0, [encryptedData length]);
  size_t metadataLength = [encryptedData rangeOfData:separatorAsData options:0 range:entireRange].location;
  NSData *subdata = [encryptedData subdataWithRange:NSMakeRange(0, metadataLength)];
  NSString *metadata = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(metadata, expectedMetadata);

  // Extract cipher text. Add 1 for the delimiter.
  size_t metadataAndIvLength = metadataLength + 1 + kCCBlockSizeAES128;
  NSRange cipherTextRange = NSMakeRange(metadataAndIvLength, [encryptedData length] - metadataAndIvLength);
  NSData *cipherTextSubdata = [encryptedData subdataWithRange:cipherTextRange];
  NSString *cipherText = [[NSString alloc] initWithData:cipherTextSubdata encoding:NSUTF8StringEncoding];
  XCTAssertNotEqualObjects(cipherText, clearText);

  // Ensure a new key and expiration were added to the user defaults.
  NSArray *newKeyTagAndExpiration = [[MSAC_APP_CENTER_USER_DEFAULTS objectForKey:kMSACEncryptionKeyMetadataKey]
      componentsSeparatedByString:kMSACEncryptionMetadataInternalSeparator];
  NSString *newKeyTag = newKeyTagAndExpiration[0];
  XCTAssertEqualObjects(newKeyTag, expectedNewKeyTag);
  NSString *expirationIso = newKeyTagAndExpiration[1];
  XCTAssertEqualObjects(expirationIso, expectedExpirationDateIso);

  // When
  NSString *decryptedString = [encrypter decryptString:encryptedString];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (void)testEncryptRotatesAndCreatesKeyWhenOnlyKeyIsExpired {

  // If
  NSString *clearText = @"clear text";
  NSDate *pastDate = [NSDate dateWithTimeIntervalSince1970:0];
  NSString *oldExpirationIso = [MSACUtility dateToISO8601:pastDate];
  NSString *oldKey = kMSACEncryptionKeyTagOriginal;
  NSString *expectedNewKeyTag = kMSACEncryptionKeyTagAlternate;
  NSString *keyMetadataString = [NSString stringWithFormat:@"%@/%@", oldKey, oldExpirationIso];
  [MSAC_APP_CENTER_USER_DEFAULTS setObject:keyMetadataString forKey:kMSACEncryptionKeyMetadataKey];
  NSString *expectedMetadata = [NSString stringWithFormat:@"%@/AES/CBC/PKCS7/32", expectedNewKeyTag];

  // Mock NSDate to "freeze" time.
  NSTimeInterval timeSinceReferenceDate = NSDate.timeIntervalSinceReferenceDate;
  NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970:timeSinceReferenceDate];
  id nsdateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([nsdateMock timeIntervalSinceReferenceDate])).andReturn(timeSinceReferenceDate);
  OCMStub(ClassMethod([nsdateMock date])).andReturn(referenceDate);
  NSDate *expectedExpirationDate = [[NSDate date] dateByAddingTimeInterval:kMSACEncryptionKeyLifetimeInSeconds];
  NSString *expectedExpirationDateIso = [MSACUtility dateToISO8601:expectedExpirationDate];

  // Save key to the Keychain.
  NSString *currentKey = [self generateTestEncryptionKey];
  [MSACMockKeychainUtil storeString:currentKey forKey:oldKey];
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *encryptedString = [encrypter encryptString:clearText];

  // Then

  // Extract metadata.
  NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
  NSData *separatorAsData = [kMSACEncryptionMetadataSeparator dataUsingEncoding:NSUTF8StringEncoding];
  NSRange entireRange = NSMakeRange(0, [encryptedData length]);
  size_t metadataLength = [encryptedData rangeOfData:separatorAsData options:0 range:entireRange].location;
  NSData *subdata = [encryptedData subdataWithRange:NSMakeRange(0, metadataLength)];
  NSString *metadata = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(metadata, expectedMetadata);

  // Extract cipher text. Add 1 for the delimiter.
  size_t metadataAndIvLength = metadataLength + 1 + kCCBlockSizeAES128;
  NSRange cipherTextRange = NSMakeRange(metadataAndIvLength, [encryptedData length] - metadataAndIvLength);
  NSData *cipherTextSubdata = [encryptedData subdataWithRange:cipherTextRange];
  NSString *cipherText = [[NSString alloc] initWithData:cipherTextSubdata encoding:NSUTF8StringEncoding];
  XCTAssertNotEqualObjects(cipherText, clearText);

  // Ensure a new key and expiration were added to the user defaults.
  NSArray *newKeyAndExpiration = [[MSAC_APP_CENTER_USER_DEFAULTS objectForKey:kMSACEncryptionKeyMetadataKey]
      componentsSeparatedByString:kMSACEncryptionMetadataInternalSeparator];
  NSString *newKey = newKeyAndExpiration[0];
  XCTAssertEqualObjects(newKey, expectedNewKeyTag);
  NSString *expirationIso = newKeyAndExpiration[1];
  XCTAssertEqualObjects(expirationIso, expectedExpirationDateIso);

  // When
  NSString *decryptedString = [encrypter decryptString:encryptedString];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (void)testDecryptLegacyItem {

  // If
  NSString *clearText = @"Test string";

  // Save the key to disk. This must not change as it was used to encrypt the text.
  NSString *currentKey = @"zlIS50zXq7fm2GqassShXrjkMBsdjlTsmIT+d1D3CTI=";
  [MSACMockKeychainUtil storeString:currentKey forKey:kMSACEncryptionKeyTagOriginal];

  // This cipher text contains no metadata, and no IV was used.
  NSString *cipherText = @"S6uNmq7u0eKGaU2GQPUGMQ==";
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *decryptedString = [encrypter decryptString:cipherText];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (void)testEncryptionCreatesKeyWhenNoKeyIsSaved {

  // If
  NSString *clearText = @"clear text";
  NSString *expectedMetadata = [NSString stringWithFormat:@"%@/AES/CBC/PKCS7/32", kMSACEncryptionKeyTagAlternate];

  // Mock NSDate to "freeze" time.
  NSTimeInterval timeSinceReferenceDate = NSDate.timeIntervalSinceReferenceDate;
  NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970:timeSinceReferenceDate];
  id nsdateMock = OCMClassMock([NSDate class]);
  OCMStub(ClassMethod([nsdateMock timeIntervalSinceReferenceDate])).andReturn(timeSinceReferenceDate);
  OCMStub(ClassMethod([nsdateMock date])).andReturn(referenceDate);
  NSDate *expectedExpirationDate = [[NSDate date] dateByAddingTimeInterval:kMSACEncryptionKeyLifetimeInSeconds];
  NSString *expectedExpirationDateIso = [MSACUtility dateToISO8601:expectedExpirationDate];
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *encryptedString = [encrypter encryptString:clearText];

  // Then

  // Extract metadata.
  NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
  NSData *separatorAsData = [kMSACEncryptionMetadataSeparator dataUsingEncoding:NSUTF8StringEncoding];
  NSRange entireRange = NSMakeRange(0, [encryptedData length]);
  size_t metadataLength = [encryptedData rangeOfData:separatorAsData options:0 range:entireRange].location;
  NSData *subdata = [encryptedData subdataWithRange:NSMakeRange(0, metadataLength)];
  NSString *metadata = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(metadata, expectedMetadata);

  // Extract cipher text. Add 1 for the delimiter.
  size_t metadataAndIvLength = metadataLength + 1 + kCCBlockSizeAES128;
  NSRange cipherTextRange = NSMakeRange(metadataAndIvLength, [encryptedData length] - metadataAndIvLength);
  NSData *cipherTextSubdata = [encryptedData subdataWithRange:cipherTextRange];
  NSString *cipherText = [[NSString alloc] initWithData:cipherTextSubdata encoding:NSUTF8StringEncoding];
  XCTAssertNotEqualObjects(cipherText, clearText);

  // Ensure a new key and expiration were added to the user defaults.
  NSArray *newKeyAndExpiration = [[MSAC_APP_CENTER_USER_DEFAULTS objectForKey:kMSACEncryptionKeyMetadataKey]
      componentsSeparatedByString:kMSACEncryptionMetadataInternalSeparator];
  NSString *newKey = newKeyAndExpiration[0];
  XCTAssertEqualObjects(newKey, kMSACEncryptionKeyTagAlternate);
  NSString *expirationIso = newKeyAndExpiration[1];
  XCTAssertEqualObjects(expirationIso, expectedExpirationDateIso);

  // When
  NSString *decryptedString = [encrypter decryptString:encryptedString];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (void)testDecryptWithExpiredKey {

  // If
  NSString *clearText = @"clear text";

  // Save metadata to user defaults.
  NSDate *expiration = [NSDate dateWithTimeIntervalSinceNow:10000000];
  NSString *keyId = kMSACEncryptionKeyTagOriginal;
  NSString *expirationIso = [MSACUtility dateToISO8601:expiration];
  NSString *keyMetadataString = [NSString stringWithFormat:@"%@/%@", keyId, expirationIso];
  [MSAC_APP_CENTER_USER_DEFAULTS setObject:keyMetadataString forKey:kMSACEncryptionKeyMetadataKey];

  // Save key to the Keychain.
  NSString *currentKey = [self generateTestEncryptionKey];
  [MSACMockKeychainUtil storeString:currentKey forKey:keyId];
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *encryptedString = [encrypter encryptString:clearText];

  // Alter the expiration date of the key so that it is now expired.
  NSDate *pastDate = [NSDate dateWithTimeIntervalSinceNow:-1000000];
  NSString *oldExpirationIso = [MSACUtility dateToISO8601:pastDate];
  NSString *alteredKeyMetadataString = [NSString stringWithFormat:@"%@/%@", keyId, oldExpirationIso];
  [MSAC_APP_CENTER_USER_DEFAULTS setObject:alteredKeyMetadataString forKey:kMSACEncryptionKeyMetadataKey];

  // When
  NSString *decryptedString = [encrypter decryptString:encryptedString];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (void)testEncryptWithCurrentKeyWithEmptyClearText {

  // If
  NSString *clearText = @"";
  NSString *keyTag = kMSACEncryptionKeyTagAlternate;
  NSString *expectedMetadata = [NSString stringWithFormat:@"%@/AES/CBC/PKCS7/32", keyTag];

  // Save metadata to user defaults.
  NSDate *expiration = [NSDate dateWithTimeIntervalSinceNow:10000000];
  NSString *expirationIso = [MSACUtility dateToISO8601:expiration];
  NSString *keyMetadataString = [NSString stringWithFormat:@"%@/%@", keyTag, expirationIso];
  [MSAC_APP_CENTER_USER_DEFAULTS setObject:keyMetadataString forKey:kMSACEncryptionKeyMetadataKey];

  // Save key to the Keychain.
  NSString *currentKey = [self generateTestEncryptionKey];
  [MSACMockKeychainUtil storeString:currentKey forKey:keyTag];
  MSACEncrypter *encrypter = [MSACEncrypter new];

  // When
  NSString *encryptedString = [encrypter encryptString:clearText];

  // Then

  // Extract metadata.
  NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
  NSData *separatorAsData = [kMSACEncryptionMetadataSeparator dataUsingEncoding:NSUTF8StringEncoding];
  NSRange entireRange = NSMakeRange(0, [encryptedData length]);
  size_t metadataLength = [encryptedData rangeOfData:separatorAsData options:0 range:entireRange].location;
  NSData *subdata = [encryptedData subdataWithRange:NSMakeRange(0, metadataLength)];
  NSString *metadata = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(metadata, expectedMetadata);

  // Extract cipher text. Add 1 for the delimiter.
  size_t metadataAndIvLength = metadataLength + 1 + kCCBlockSizeAES128;
  NSRange cipherTextRange = NSMakeRange(metadataAndIvLength, [encryptedData length] - metadataAndIvLength);
  NSData *cipherTextSubdata = [encryptedData subdataWithRange:cipherTextRange];
  NSString *cipherText = [[NSString alloc] initWithData:cipherTextSubdata encoding:NSUTF8StringEncoding];
  XCTAssertNotEqualObjects(cipherText, clearText);

  // When
  NSString *decryptedString = [encrypter decryptString:encryptedString];

  // Then
  XCTAssertEqualObjects(decryptedString, clearText);
}

- (NSString *)generateTestEncryptionKey {
  NSData *resultKey = nil;
  uint8_t *keyBytes = nil;
  keyBytes = malloc(kMSACEncryptionKeySize * sizeof(uint8_t));
  memset((void *)keyBytes, 0x0, kMSACEncryptionKeySize);
  int result = SecRandomCopyBytes(kSecRandomDefault, kMSACEncryptionKeySize, keyBytes);
  if (result != errSecSuccess) {
    return nil;
  }
  resultKey = [[NSData alloc] initWithBytes:keyBytes length:kMSACEncryptionKeySize];
  free(keyBytes);
  return [resultKey base64EncodedStringWithOptions:0];
}

@end
