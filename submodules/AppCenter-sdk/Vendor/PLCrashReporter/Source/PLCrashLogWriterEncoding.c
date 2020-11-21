/*
 * Copyright 2008, Dave Benson.
 * Copyright 2008 - 2009 Plausible Labs Cooperative, Inc.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with
 * the License. You may obtain a copy of the License
 * at http://www.apache.org/licenses/LICENSE-2.0 Unless
 * required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on
 * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

/*
 * Extracted from protobuf-c and modified to support zero-allocation,
 * async-safe file encoding.
 *
 * -landonf dec 12, 2008
 */

#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "PLCrashLogWriterEncoding.h"

#define MAX_UINT64_ENCODED_SIZE 10

/* --- wire format enums --- */
typedef enum {
        PLPROTOBUF_C_WIRE_TYPE_VARINT,
        PLPROTOBUF_C_WIRE_TYPE_64BIT,
        PLPROTOBUF_C_WIRE_TYPE_LENGTH_PREFIXED,
        PLPROTOBUF_C_WIRE_TYPE_START_GROUP,     /* unsupported */
        PLPROTOBUF_C_WIRE_TYPE_END_GROUP,       /* unsupported */
        PLPROTOBUF_C_WIRE_TYPE_32BIT
} PLProtobufCWireType;

/* === pack() === */
static inline uint32_t
zigzag32 (int32_t v)
{
    if (v < 0)
        return ((uint32_t)(-v)) * 2 - 1;
    else
        return v * 2;
}
static inline uint64_t
zigzag64 (int64_t v)
{
    if (v < 0)
        return ((uint64_t)(-v)) * 2 - 1;
    else
        return v * 2;
}
static inline size_t
uint32_pack (uint32_t value, uint8_t *out)
{
    unsigned rv = 0;
    if (value >= 0x80)
    {
        out[rv++] = value | 0x80;
        value >>= 7;
        if (value >= 0x80)
        {
            out[rv++] = value | 0x80;
            value >>= 7;
            if (value >= 0x80)
            {
                out[rv++] = value | 0x80;
                value >>= 7;
                if (value >= 0x80)
                {
                    out[rv++] = value | 0x80;
                    value >>= 7;
                }
            }
        }
    }
    /* assert: value<128 */
    out[rv++] = value;
    return rv;
}
static inline size_t
int32_pack (int32_t value, uint8_t *out)
{
    if (value < 0)
    {
        out[0] = value | 0x80;
        out[1] = (value>>7) | 0x80;
        out[2] = (value>>14) | 0x80;
        out[3] = (value>>21) | 0x80;
        out[4] = (value>>28) | 0x80;
        out[5] = out[6] = out[7] = out[8] = 0xff;
        out[9] = 0x01;
        return 10;
    }
    else
        return uint32_pack (value, out);
}
static inline size_t sint32_pack (int32_t value, uint8_t *out)
{
    return uint32_pack (zigzag32 (value), out);
}
static size_t
uint64_pack (uint64_t value, uint8_t *out)
{
    uint32_t hi = value>>32;
    uint32_t lo = (uint32_t) value;
    unsigned rv;
    if (hi == 0)
        return uint32_pack (lo, out);
    out[0] = (lo) | 0x80;
    out[1] = (lo>>7) | 0x80;
    out[2] = (lo>>14) | 0x80;
    out[3] = (lo>>21) | 0x80;
    if (hi < 8)
    {
        out[4] = (hi<<4) | (lo>>28);
        return 5;
    }
    else
    {
        out[4] = ((hi&7)<<4) | (lo>>28) | 0x80;
        hi >>= 3;
    }
    rv = 5;
    while (hi >= 128)
    {
        out[rv++] = hi | 0x80;
        hi >>= 7;
    }
    out[rv++] = hi;
    return rv;
}
static inline size_t sint64_pack (int64_t value, uint8_t *out)
{
    return uint64_pack (zigzag64 (value), out);
}
static inline size_t fixed32_pack (uint32_t value, uint8_t *out)
{
#if __LITTLE_ENDIAN__
    plcrash_async_memcpy (out, &value, 4);
#else
    out[0] = value;
    out[1] = value>>8;
    out[2] = value>>16;
    out[3] = value>>24;
#endif
    return 4;
}
static inline size_t fixed64_pack (uint64_t value, uint8_t *out)
{
#if __LITTLE_ENDIAN__
    plcrash_async_memcpy (out, &value, 8);
#else
    fixed32_pack (value, out);
    fixed32_pack (value>>32, out+4);
#endif
    return 8;
}
static inline size_t boolean_pack (bool value, uint8_t *out)
{
    *out = value ? 1 : 0;
    return 1;
}

/* wire-type will be added in required_field_pack() */
static size_t tag_pack (uint32_t id, uint8_t *out)
{
    if (id < (1<<(32-3)))
        return uint32_pack (id<<3, out);
    else
        return uint64_pack (((uint64_t)id) << 3, out);
}

/* === pack_to_buffer() === */
// file argument may be NULL
size_t plcrash_writer_pack (plcrash_async_file_t *file, uint32_t field_id, PLProtobufCType field_type, const void *value) {
    size_t rv;
    uint8_t scratch[MAX_UINT64_ENCODED_SIZE * 2];
    rv = tag_pack (field_id, scratch);
    switch (field_type)
    {
        case PLPROTOBUF_C_TYPE_SINT32:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_VARINT;
            rv += sint32_pack (*(const int32_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        case PLPROTOBUF_C_TYPE_INT32:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_VARINT;
            rv += int32_pack (*(const uint32_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        case PLPROTOBUF_C_TYPE_UINT32:
        case PLPROTOBUF_C_TYPE_ENUM:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_VARINT;
            rv += uint32_pack (*(const uint32_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        case PLPROTOBUF_C_TYPE_SINT64:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_VARINT;
            rv += sint64_pack (*(const int64_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        case PLPROTOBUF_C_TYPE_INT64:
        case PLPROTOBUF_C_TYPE_UINT64:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_VARINT;
            rv += uint64_pack (*(const uint64_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        case PLPROTOBUF_C_TYPE_SFIXED32:
        case PLPROTOBUF_C_TYPE_FIXED32:
        case PLPROTOBUF_C_TYPE_FLOAT:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_32BIT;
            rv += fixed32_pack (*(const uint32_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        case PLPROTOBUF_C_TYPE_SFIXED64:
        case PLPROTOBUF_C_TYPE_FIXED64:
        case PLPROTOBUF_C_TYPE_DOUBLE:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_64BIT;
            rv += fixed64_pack (*(const uint64_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        case PLPROTOBUF_C_TYPE_BOOL:
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_VARINT;
            rv += boolean_pack (*(const bool *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
            
        case PLPROTOBUF_C_TYPE_STRING:
        {
            uint32_t sublen = (uint32_t) strlen (value);
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_LENGTH_PREFIXED;
            rv += uint32_pack (sublen, scratch + rv);
            if (file != NULL) {
                plcrash_async_file_write(file, scratch, rv);
                plcrash_async_file_write(file, value, sublen);
            }
            rv += sublen;
            break;
        }
     
        case PLPROTOBUF_C_TYPE_BYTES:
        {
            const PLProtobufCBinaryData * bd = ((const PLProtobufCBinaryData*) value);
            uint32_t sublen = (uint32_t) bd->len;
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_LENGTH_PREFIXED;
            rv += uint32_pack (sublen, scratch + rv);
            if (file != NULL) {
                plcrash_async_file_write(file, scratch, rv);
                plcrash_async_file_write(file, bd->data, sublen);
            }
            rv += sublen;
            break;
        }
            
            //PLPROTOBUF_C_TYPE_GROUP,          // NOT SUPPORTED
        case PLPROTOBUF_C_TYPE_MESSAGE:
        {
            scratch[0] |= PLPROTOBUF_C_WIRE_TYPE_LENGTH_PREFIXED;
            rv += uint32_pack (*(const uint32_t *) value, scratch + rv);
            if (file != NULL)
                plcrash_async_file_write(file, scratch, rv);
            break;
        }
        default:
            PLCF_DEBUG("Unhandled field type %d", field_type);
            abort();
    }
    return rv;
}
