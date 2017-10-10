#import <CommonCrypto/CommonCrypto.h>

void TGCallAesIgeEncryptInplace(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv);
void TGCallAesIgeDecryptInplace(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv);

void TGCallSha1(uint8_t *msg, size_t length, uint8_t *output);
void TGCallSha256(uint8_t *msg, size_t length, uint8_t *output);

void TGCallRandomBytes(uint8_t *buffer, size_t length);
void TGCallAesCtrEncrypt(uint8_t *inOut, size_t length, uint8_t *key, uint8_t *iv, uint8_t *ecount, uint32_t *num);
