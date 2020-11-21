/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#include "PLCrashSysctl.h"

#include <string.h>
#include <errno.h>

/**
 * @internal
 * @defgroup plcrash_host Host and Process Info
 * @ingroup plcrash_internal
 *
 * Implements general utility functions for gathering host/process statistics.
 * @{
 */

/*
 * Wrap sysctl(), automatically allocating a sufficiently large buffer for the returned data. The new buffer's
 * length will be returned in @a length.
 *
 * @param name The sysctl MIB name.
 * @param length On success, will be populated with the length of the result. If NULL, length will not be supplied.
 *
 * @return Returns a malloc-allocated buffer containing the sysctl result on success. On failure, NULL is returned
 * and the global variable errno is set to indicate the error. The caller is responsible for free()'ing the returned
 * buffer.
 */
static void *plcrash_sysctl_malloc (const char *name, size_t *length) {
    /* Attempt to fetch the data, looping until our buffer is sufficiently sized. */
    void *result = NULL;
    size_t result_len = 0;
    int ret;
    
    /* If our buffer is too small after allocation, loop until it succeeds -- the requested destination size
     * may change after each iteration. */
    do {
        /* Fetch the expected length */
        if ((ret = sysctlbyname(name, NULL, &result_len, NULL, 0)) == -1)
            break;
        
        /* Allocate the destination buffer */
        if (result != NULL)
            free(result);
        result = malloc(result_len);
        
        /* Fetch the value */
        ret = sysctlbyname(name, result, &result_len, NULL, 0);
    } while (ret == -1 && errno == ENOMEM);
    
    /* Handle failure */
    if (ret == -1) {
        int saved_errno = errno;
        
        if (result != NULL)
            free(result);
        
        errno = saved_errno;
        return NULL;
    }
    
    /* Provide the length */
    if (length != NULL)
        *length = result_len;
    
    return result;
}

/**
 * Wrap sysctl() and fetch a C string, automatically allocating a sufficiently large buffer for the returned data.
 *
 * @param name The sysctl MIB name.
 * @param length On success, will be populated with the length of the result. If NULL, length will not be supplied.
 *
 * @return Returns a malloc-allocated NULL-terminated C string containing the sysctl result on success. On failure,
 * NULL is returned and the global variable errno is set to indicate the error. The caller is responsible for
 * free()'ing the returned buffer.
 */
char *plcrash_sysctl_string (const char *name) {
    return plcrash_sysctl_malloc(name, NULL);
}

/**
 * Wrap sysctl() and fetch an integer value.
 *
 * @param name The sysctl MIB name.
 * @param result On success, the integer result will be provided via this pointer.
 *
 * @return Returns true on success. On failure, false is returned and the global variable errno is set to indicate
 * the error.
 */
bool plcrash_sysctl_int (const char *name, int *result) {
    size_t len = sizeof(*result);

    if (sysctlbyname(name, result, &len, NULL, 0) != 0)
        return false;

    return true;
}


/**
 * Find the byte length of @a s, minus any invalid trailing multibyte sequences.
 *
 * This function is primarily useful for extracting a valid UTF-8 string from a fixed uffer length returned by the kernel;
 * the kernel will copy the UTF-8 string directly into the target buffer, resulting in dangling multi-byte characters that
 * prevent decoding by strict UTF-8 decoders.
 *
 * @param s The string buffer to scan.
 * @param maxlen The maximum number of bytes that will be scanned in @a s.
 * @return Returns the number of valid utf-8 bytes that precede maxlen, or should maxlen exceed the string length, the
 * string's terminating NUL character.
 *
 * @warning This function returns the byte length, not the code point length, of the valid UTF-8 encoded string data.
 */
size_t plcrash_sysctl_valid_utf8_bytes_max (const uint8_t *s, size_t maxlen) {
    /*
     * For the official specification documenting the multibyte encoding, refer to:
     *      The Unicode Standard, Version 6.2 - Core Specification
     *          Chapter 3, Section 9 - Unicode Encoding Forms
     *
     * UTF-8 uses a variable-width encoding, with each code point corresponding to
     * a 1, 2, 3, or 4 byte sequence.
     *
     * +---------------------+----------+----------+----------+----------+
     * | Code Point Bit Size | 1st Byte | 2nd Byte | 3rd Byte | 4th Byte |
     * +---------------------+----------+----------+----------+----------+
     * | 7                   | 0xxxxxxx |          |          |          |
     * | 11                  | 110xxxxx | 10xxxxxx |          |          |
     * | 16                  | 1110xxxx | 10xxxxxx | 10xxxxxx |          |
     * | 21                  | 11110xxx | 10xxxxxx | 10xxxxxx | 10xxxxxx |
     * +---------------------+----------+----------+----------+----------+
     */
    
    /* The currently string byte position */
    size_t len = 0;
    
    /* Handle (and skip) an initial BOM */
    if (maxlen >= 3 && s[0] == 0xEF && s[1] == 0xBB && s[2] == 0xBF)
        len += 3;

    /* Work forwards, validating UTF-8 character ranges as we go. */
    for (; len < maxlen && s[len] != '\0'; len++) {
        uint8_t c = s[len];

        /* Determine the sequence length */
        size_t seqlen = 0;
        if ((c & 0x80) == 0) {
            /* 1 byte sequence. Code point value range is 0 to 127. */
            seqlen = 0;
            continue;
            
        } else if ((c & 0xE0) == 0xC0) {
            /* 1 byte continuation of a 2 byte sequence. Code point value range is 128 to 2047 */
            seqlen = 1;
            
        } else if ((c & 0xF0) == 0xE0) {
            /* 2 byte continuation of a 3 byte sequence. Code point value range is 2048 to 55295 and 57344 to 65535 */
            seqlen = 2;
            
        } else if ((c & 0xF8) == 0xF0) {
            /* 3 byte continuation of a 4 byte sequence. Code point value range is 65536 to 1114111 */
            seqlen = 3;
            
        } else {
            /* Invalid UTF-8 character (eg, >= 128) */
            return len;
        }
        
        /* Verify that the sequence (including the now validated but uncounted leading byte) fits within maxlen */
        if (maxlen - (len + 1) < seqlen)
            return len;
        
        /* Validate the sequence's trailing bytes */
        size_t validated = 0;
        for (size_t i = 0; i < seqlen; i++) {
            uint8_t trailer = s[len + i + 1]; /* len + i + already-validated-byte */

            /* This byte must be a UTF-8 trailing byte. If not, then return the length, minus this
             * incomplete multibyte sequence */
            if (trailer == '\0' || (trailer & 0xC0) != 0x80)
                return len;
            
            /* Mark position as validated */
            validated++;
        }

        if (validated == seqlen) {
            /* Fully validated */
            len += seqlen;
        } else {
            /* Couldn't validate the sequence; return the length up to (but not including) the invalid sequence. */
            return len;
        }
    }
    
    return len;
}

/**
 * Find the byte length of @a s in bytes, minus any invalid truncated multibyte sequences.
 *
 * This function is primarily useful for extracting a valid UTF-8 string from a fixed uffer length returned by the kernel;
 * the kernel will copy the UTF-8 string directly into the target buffer, resulting in dangling multi-byte characters that
 * prevent decoding by strict UTF-8 decoders.
 *
 * @param s The string buffer to scan.
 * @return Returns the number of valid utf-8 bytes that precede the string's terminating NUL character.
 *
 * @warning This function returns the byte length, not the code point length, of the valid UTF-8 encoded string data.
 */
size_t plcrash_sysctl_valid_utf8_bytes (const uint8_t *s) {
    /* We could avoid strlen() by having our own character iterating loop, but this works reliably
     * and performance here is not the primary aim. */
    return plcrash_sysctl_valid_utf8_bytes_max(s, strlen((const char *)s));
}

/*
 * @}
 */
