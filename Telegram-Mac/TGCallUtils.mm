#import "TGCallUtils.h"

#import <CoreTelephony/CTCall.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>


# define AES_MAXNR 14
# define AES_BLOCK_SIZE 16

#define N_WORDS (AES_BLOCK_SIZE / sizeof(unsigned long))
typedef struct {
    unsigned long data[N_WORDS];
} aes_block_t;

/* XXX: probably some better way to do this */
#if defined(__i386__) || defined(__x86_64__)
# define UNALIGNED_MEMOPS_ARE_FAST 1
#else
# define UNALIGNED_MEMOPS_ARE_FAST 0
#endif

#if UNALIGNED_MEMOPS_ARE_FAST
# define load_block(d, s)        (d) = *(const aes_block_t *)(s)
# define store_block(d, s)       *(aes_block_t *)(d) = (s)
#else
# define load_block(d, s)        memcpy((d).data, (s), AES_BLOCK_SIZE)
# define store_block(d, s)       memcpy((d), (s).data, AES_BLOCK_SIZE)
#endif

void TGCallAesIgeEncrypt(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv) {
    size_t len;
    size_t n;
    uint8_t const *inB;
    uint8_t *outB;
    
    unsigned char aesIv[AES_BLOCK_SIZE];
    memcpy(aesIv, iv, AES_BLOCK_SIZE);
    unsigned char ccIv[AES_BLOCK_SIZE];
    memcpy(ccIv, (void *)((uint8_t *)iv + AES_BLOCK_SIZE), AES_BLOCK_SIZE);
    
    assert(((size_t)inBytes | (size_t)outBytes | (size_t)aesIv | (size_t)ccIv) % sizeof(long) ==
           0);
    
    void *tmpInBytes = malloc(length);
    len = length / AES_BLOCK_SIZE;
    inB = (uint8_t *)inBytes;
    outB = (uint8_t *)tmpInBytes;
    
    aes_block_t *inp = (aes_block_t *)inB;
    aes_block_t *outp = (aes_block_t *)outB;
    for (n = 0; n < N_WORDS; ++n) {
        outp->data[n] = inp->data[n];
    }
    
    --len;
    inB += AES_BLOCK_SIZE;
    outB += AES_BLOCK_SIZE;
    uint8_t const *inBCC = (uint8_t *)inBytes;
    
    aes_block_t const *iv3p = (aes_block_t *)ccIv;
    
    if (len > 0) {
        while (len) {
            aes_block_t *inp = (aes_block_t *)inB;
            aes_block_t *outp = (aes_block_t *)outB;
            
            for (n = 0; n < N_WORDS; ++n) {
                outp->data[n] = inp->data[n] ^ iv3p->data[n];
            }
            
            iv3p = (const aes_block_t *)inBCC;
            --len;
            inBCC += AES_BLOCK_SIZE;
            inB += AES_BLOCK_SIZE;
            outB += AES_BLOCK_SIZE;
        }
    }
    
    size_t realOutLength = 0;
    CCCryptorStatus result = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, 0, key, 32, aesIv, tmpInBytes, length, outBytes, length, &realOutLength);
    free(tmpInBytes);
    
    assert(result == kCCSuccess);
    
    len = length / AES_BLOCK_SIZE;
    
    aes_block_t const *ivp = (aes_block_t *)inB;
    aes_block_t *iv2p = (aes_block_t *)ccIv;
    
    inB = (uint8_t *)inBytes;
    outB = (uint8_t *)outBytes;
    
    while (len) {
        aes_block_t *inp = (aes_block_t *)inB;
        aes_block_t *outp = (aes_block_t *)outB;
        
        for (n = 0; n < N_WORDS; ++n) {
            outp->data[n] ^= iv2p->data[n];
        }
        ivp = outp;
        iv2p = inp;
        --len;
        inB += AES_BLOCK_SIZE;
        outB += AES_BLOCK_SIZE;
    }
    
    memcpy(iv, ivp->data, AES_BLOCK_SIZE);
    memcpy((void *)((uint8_t *)iv + AES_BLOCK_SIZE), iv2p->data, AES_BLOCK_SIZE);
}

void TGCallAesIgeEncryptInplace(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv)
{
    uint8_t *outData = (uint8_t *)malloc(length);
    TGCallAesIgeEncrypt(inBytes, outData, length, key, iv);
    memcpy(outBytes, outData, length);
    free(outData);
}

void TGCallAesIgeDecrypt(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv) {
    unsigned char aesIv[AES_BLOCK_SIZE];
    memcpy(aesIv, iv, AES_BLOCK_SIZE);
    unsigned char ccIv[AES_BLOCK_SIZE];
    memcpy(ccIv, (void *)((uint8_t *)iv + AES_BLOCK_SIZE), AES_BLOCK_SIZE);
    
    assert(((size_t)inBytes | (size_t)outBytes | (size_t)aesIv | (size_t)ccIv) % sizeof(long) ==
           0);
    
    CCCryptorRef decryptor = NULL;
    CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, 32, nil, &decryptor);
    if (decryptor != NULL) {
        size_t len;
        size_t n;
        
        len = length / AES_BLOCK_SIZE;
        
        aes_block_t *ivp = (aes_block_t *)(aesIv);
        aes_block_t *iv2p = (aes_block_t *)(ccIv);
        
        uint8_t *inB = (uint8_t *)inBytes;
        uint8_t *outB = (uint8_t *)outBytes;
        
        while (len) {
            aes_block_t tmp;
            aes_block_t *inp = (aes_block_t *)inB;
            aes_block_t *outp = (aes_block_t *)outB;
            
            for (n = 0; n < N_WORDS; ++n)
                tmp.data[n] = inp->data[n] ^ iv2p->data[n];
            
            size_t dataOutMoved = 0;
            CCCryptorStatus result = CCCryptorUpdate(decryptor, &tmp, AES_BLOCK_SIZE, outB, AES_BLOCK_SIZE, &dataOutMoved);
            assert(result == kCCSuccess);
            assert(dataOutMoved == AES_BLOCK_SIZE);
            
            for (n = 0; n < N_WORDS; ++n)
                outp->data[n] ^= ivp->data[n];
            
            ivp = inp;
            iv2p = outp;
            
            inB += AES_BLOCK_SIZE;
            outB += AES_BLOCK_SIZE;
            
            --len;
        }
        
        memcpy(iv, ivp->data, AES_BLOCK_SIZE);
        memcpy((void *)((uint8_t *)iv + AES_BLOCK_SIZE), iv2p->data, AES_BLOCK_SIZE);
        
        CCCryptorRelease(decryptor);
    }
}

void TGCallAesIgeDecryptInplace(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv) {
    uint8_t *outData = (uint8_t *)malloc(length);
    TGCallAesIgeDecrypt(inBytes, outData, length, key, iv);
    memcpy(outBytes, outData, length);
    free(outData);
}

void TGCallSha1(uint8_t *msg, size_t length, uint8_t *output)
{
    CC_SHA1(msg, (CC_LONG)length, output);
}

void TGCallSha256(uint8_t *msg, size_t length, uint8_t *output)
{
    CC_SHA256(msg, (CC_LONG)length, output);
}

void TGCallRandomBytes(uint8_t *buffer, size_t length)
{
    arc4random_buf(buffer, length);
}


static void ctr128_inc(unsigned char *counter)
{
    uint32_t n = 16, c = 1;
    
    do {
        --n;
        c += counter[n];
        counter[n] = (uint8_t)c;
        c >>= 8;
    } while (n);
}

static void ctr128_inc_aligned(unsigned char *counter)
{
    size_t *data, c, d, n;
    const union {
        long one;
        char little;
    } is_endian = {
        1
    };
    
    if (is_endian.little || ((size_t)counter % sizeof(size_t)) != 0) {
        ctr128_inc(counter);
        return;
    }
    
    data = (size_t *)counter;
    c = 1;
    n = 16 / sizeof(size_t);
    do {
        --n;
        d = data[n] += c;
        /* did addition carry? */
        c = ((d - c) ^ d) >> (sizeof(size_t) * 8 - 1);
    } while (n);
}

@interface TGCallAesCtr : NSObject {
    CCCryptorRef _cryptor;
    
    unsigned char _ivec[16];
    unsigned int _num;
    unsigned char _ecount[16];
}

@end

@implementation TGCallAesCtr

- (instancetype)initWithKey:(const void *)key keyLength:(int)keyLength iv:(const void *)iv ecount:(void *)ecount num:(uint32_t)num {
    self = [super init];
    if (self != nil) {
        _num = num;
        memcpy(_ecount, ecount, 16);
        memcpy(_ivec, iv, 16);
        
        CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, keyLength, nil, &_cryptor);
    }
    return self;
}

- (void)dealloc {
    if (_cryptor) {
        CCCryptorRelease(_cryptor);
    }
}

- (uint32_t)num {
    return _num;
}

- (void *)ecount {
    return _ecount;
}

- (void)encryptIn:(const unsigned char *)in out:(unsigned char *)out len:(size_t)len {
    unsigned int n;
    size_t l = 0;
    
    assert(in && out);
    assert(_num < 16);
    
    n = _num;
    
    if (16 % sizeof(size_t) == 0) { /* always true actually */
        do {
            while (n && len) {
                *(out++) = *(in++) ^ _ecount[n];
                --len;
                n = (n + 1) % 16;
            }
            
            while (len >= 16) {
                size_t dataOutMoved;
                CCCryptorUpdate(_cryptor, _ivec, 16, _ecount, 16, &dataOutMoved);
                ctr128_inc_aligned(_ivec);
                for (n = 0; n < 16; n += sizeof(size_t))
                    *(size_t *)(out + n) =
                    *(size_t *)(in + n) ^ *(size_t *)(_ecount + n);
                len -= 16;
                out += 16;
                in += 16;
                n = 0;
            }
            if (len) {
                size_t dataOutMoved;
                CCCryptorUpdate(_cryptor, _ivec, 16, _ecount, 16, &dataOutMoved);
                ctr128_inc_aligned(_ivec);
                while (len--) {
                    out[n] = in[n] ^ _ecount[n];
                    ++n;
                }
            }
            _num = n;
            return;
        } while (0);
    }
    /* the rest would be commonly eliminated by x86* compiler */
    
    while (l < len) {
        if (n == 0) {
            size_t dataOutMoved;
            CCCryptorUpdate(_cryptor, _ivec, 16, _ecount, 16, &dataOutMoved);
            ctr128_inc(_ivec);
        }
        out[l] = in[l] ^ _ecount[n];
        ++l;
        n = (n + 1) % 16;
    }
    
    _num = n;
}

@end


void TGCallAesCtrEncrypt(uint8_t *inOut, size_t length, uint8_t *key, uint8_t *iv, uint8_t *ecount, uint32_t *num)
{
    uint8_t *outData = (uint8_t *)malloc(length);
    TGCallAesCtr *aesCtr = [[TGCallAesCtr alloc] initWithKey:key keyLength:32 iv:iv ecount:ecount num:*num];
    [aesCtr encryptIn:inOut out:outData len:length];
    memcpy(inOut, outData, length);
    
    memcpy(ecount, [aesCtr ecount], 16);
    *num = [aesCtr num];
}
