/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
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

#import "SenTestCompat.h"
#import "PLCrashAsync.h"
#import "PLCrashLogWriterEncoding.h"

#import "protobuf-c.h"
#import "PLCrashLogWriterEncodingTests.pb-c.h"

@interface PLCrashLogWriterEncodingTests : SenTestCase {
@private
    plcrash_async_file_t _file;
    __strong NSString *_filePath;
}
@end


@implementation PLCrashLogWriterEncodingTests

- (void) setUp {
    _filePath = [NSTemporaryDirectory() stringByAppendingString: [[NSProcessInfo processInfo] globallyUniqueString]];
    int fd = open([_filePath fileSystemRepresentation], O_RDWR|O_CREAT|O_TRUNC, 0644);
    STAssertTrue(fd >= 0, @"Could not open output file: %s", strerror(errno));

    plcrash_async_file_init(&_file, fd, OFF_MAX);
}

- (void) tearDown {
    STAssertTrue(plcrash_async_file_close(&_file), @"Failed to close file");
    _filePath = nil;
}

#define TEST_PACK(ctype, fieldname, type, test_value, tag, type_constant) \
- (void) test_ ## type ## _ ## test_value { \
    ctype v = test_value; \
    plcrash_writer_pack(&_file, tag, type_constant, &v); \
    STAssertTrue(plcrash_async_file_flush(&_file), @"Failed to flush file"); \
\
    NSData *data = [NSData dataWithContentsOfFile: _filePath]; \
    STAssertNotNil(data, @"Failed to load encoded data"); \
    if (data == nil) \
        return; \
\
    EncoderTest *et = encoder_test__unpack(NULL, [data length], [data bytes]); \
    STAssertNotNULL(et, @"Failed to decode test data"); \
    if (et == NULL) \
        return; \
\
    STAssertTrue(et->has_ ## fieldname, @"Did not encode correct type for " # fieldname); \
    STAssertEquals(et->fieldname, (ctype) test_value, @"Did not encode correct value in " # fieldname); \
}

#define TEST_PACK_INT(ctype, type, const_name, base_tag, type_constant, fixed_type_constant) \
    /* int min/max */ \
    TEST_PACK(ctype, int ## type, int ## type, const_name ## _MIN, base_tag, PLPROTOBUF_C_TYPE_ ## type_constant); \
    TEST_PACK(ctype, int ## type, int ## type, const_name ## _MAX, base_tag, PLPROTOBUF_C_TYPE_ ## type_constant); \
    /* uint min/max */ \
    TEST_PACK(u ## ctype, uint ## type, uint ## type, 0, base_tag+1, PLPROTOBUF_C_TYPE_U ## type_constant); \
    TEST_PACK(u ## ctype, uint ## type, uint ## type, U ## const_name ## _MAX, base_tag+1, PLPROTOBUF_C_TYPE_U ## type_constant); \
    /* sint min/max */ \
    TEST_PACK(ctype, sint ## type, sint ## type, const_name ## _MIN, base_tag+2, PLPROTOBUF_C_TYPE_S ## type_constant); \
    TEST_PACK(ctype, sint ## type, sint ## type, const_name ## _MAX, base_tag+2, PLPROTOBUF_C_TYPE_S ## type_constant); \
    /* fixed min/max */ \
    TEST_PACK(u ## ctype, fixed ## type, fixed ## type, 0, base_tag+3, PLPROTOBUF_C_TYPE_ ## fixed_type_constant); \
    TEST_PACK(u ## ctype, fixed ## type, fixed ## type, U ## const_name ## _MAX, base_tag+3, PLPROTOBUF_C_TYPE_ ## fixed_type_constant); \
    /* sfixed min/max */ \
    TEST_PACK(ctype, sfixed ## type, sfixed ## type, const_name ## _MIN, base_tag+4, PLPROTOBUF_C_TYPE_ ## fixed_type_constant); \
    TEST_PACK(ctype, sfixed ## type, sfixed ## type, const_name ## _MAX, base_tag+4, PLPROTOBUF_C_TYPE_ ## fixed_type_constant);

TEST_PACK_INT(int32_t, 32, INT32, 1, INT32, FIXED32);
TEST_PACK_INT(int64_t, 64, INT64, 6, INT64, FIXED64);

TEST_PACK(float, float_, float, FLT_MAX, 11, PLPROTOBUF_C_TYPE_FLOAT);
TEST_PACK(float, float_, float, FLT_MIN, 11, PLPROTOBUF_C_TYPE_FLOAT);

TEST_PACK(double, double_, double, DBL_MAX, 12, PLPROTOBUF_C_TYPE_DOUBLE);
TEST_PACK(double, double_, double, DBL_MIN, 12, PLPROTOBUF_C_TYPE_DOUBLE);

TEST_PACK(protobuf_c_boolean, bool_, bool, false, 13, PLPROTOBUF_C_TYPE_BOOL);
TEST_PACK(protobuf_c_boolean, bool_, bool, true, 13, PLPROTOBUF_C_TYPE_BOOL);

TEST_PACK(EncoderTest__Enum, enum_, enum, ENCODER_TEST__ENUM__Value1, 14, PLPROTOBUF_C_TYPE_ENUM);
TEST_PACK(EncoderTest__Enum, enum_, enum, ENCODER_TEST__ENUM__Value2, 14, PLPROTOBUF_C_TYPE_ENUM);

- (void) testPackBytes {
    uint8_t bytes[] = { 0xC, 0xA, 0xF, 0xE };
    PLProtobufCBinaryData binary = {
        .len = sizeof(bytes),
        .data = bytes
    } ;
    plcrash_writer_pack(&_file, 15, PLPROTOBUF_C_TYPE_BYTES, &binary);
    STAssertTrue(plcrash_async_file_flush(&_file), @"Failed to flush file");

    NSData *data = [NSData dataWithContentsOfFile: _filePath];
    STAssertNotNil(data, @"Failed to load encoded data");
    if (data == nil)
        return;

    EncoderTest *et = encoder_test__unpack(NULL, [data length], [data bytes]);
    STAssertNotNULL(et, @"Failed to decode test data");
    if (et == NULL)
        return;

    STAssertTrue(et->has_bytes, @"Did not encode correct type");
    STAssertEquals(et->bytes.len, sizeof(bytes), @"Encoded incorrect size");
    STAssertTrue((memcmp(et->bytes.data, bytes, sizeof(bytes)) == 0), @"Did not encode correct value");
}

- (void) testPackString {
    const char *str = "cafe";
    plcrash_writer_pack(&_file, 16, PLPROTOBUF_C_TYPE_STRING, str);
    STAssertTrue(plcrash_async_file_flush(&_file), @"Failed to flush file");

    NSData *data = [NSData dataWithContentsOfFile: _filePath];
    STAssertNotNil(data, @"Failed to load encoded data");
    if (data == nil)
        return;
    
    EncoderTest *et = encoder_test__unpack(NULL, [data length], [data bytes]);
    STAssertNotNULL(et, @"Failed to decode test data");
    if (et == NULL)
        return;
    
    STAssertNotNULL(et->string, @"Did not encode correct type");
    STAssertTrue(strcmp(et->string, str) == 0, @"Did not encode correct value");
}

@end
