/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 * Author: Gwynne Raskind <gwynne@darkrainfall.org>
 *
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
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

#include "PLCrashAsyncCompactUnwindEncoding.h"

#include "PLCrashFeatureConfig.h"
#include "PLCrashCompatConstants.h"
#include "PLCrashMacros.h"

#include <inttypes.h>

#if PLCRASH_FEATURE_UNWIND_COMPACT

/**
 * @internal
 * @ingroup plcrash_async
 * @defgroup plcrash_async_cfe Compact Frame Encoding
 *
 * Implements async-safe parsing of compact frame unwind encodings.
 * @{
 */

/* Extract @a mask bits from @a value. */
#define EXTRACT_BITS(value, mask) ((value >> __builtin_ctz(mask)) & (((1 << __builtin_popcount(mask)))-1))

#pragma mark CFE Reader

/**
 * Initialize a new CFE reader using the provided memory object. Any resources held by a successfully initialized
 * instance must be freed via plcrash_async_cfe_reader_free();
 *
 * @param reader The reader instance to initialize.
 * @param mobj The memory object containing CFE data at the start address. This instance must survive for the lifetime
 * of the reader.
 * @param cputype The target architecture of the CFE data, encoded as a Mach-O CPU type. Interpreting CFE data is
 * architecture-specific, and Apple has not defined encodings for all supported architectures.
 */
plcrash_error_t plcrash_async_cfe_reader_init (plcrash_async_cfe_reader_t *reader, plcrash_async_mobject_t *mobj, cpu_type_t cputype) {
    reader->mobj = mobj;
    reader->cpu_type = cputype;

    /* Determine the expected encoding */
    switch (cputype) {
        case CPU_TYPE_X86:
        case CPU_TYPE_X86_64:
        case CPU_TYPE_ARM64:
            reader->byteorder = plcrash_async_byteorder_little_endian();
            break;

        default:
            PLCF_DEBUG("Unsupported CPU type: %" PRIu32, cputype);
            return PLCRASH_ENOTSUP;
    }

    /* Fetch and verify the header */
    pl_vm_address_t base_addr = plcrash_async_mobject_base_address(mobj);
    struct unwind_info_section_header *header = plcrash_async_mobject_remap_address(mobj, base_addr, 0, sizeof(*header));
    if (header == NULL) {
        PLCF_DEBUG("Could not map the unwind info section header");
        return PLCRASH_EINVAL;
    }

    /* Verify the format version */
    uint32_t version = reader->byteorder->swap32(header->version);
    if (version != 1) {
        PLCF_DEBUG("Unsupported CFE version: %" PRIu32, version);
        return PLCRASH_ENOTSUP;
    }

    reader->header = *header;
    return PLCRASH_ESUCCESS;
}

/**
 * @internal
 *
 * Binary search in macro form. Pass the table, count, and result
 * pointers.
 *
 * CFE_FUN_BINARY_SEARCH_ENTVAL must also be defined, and it must
 * return the integer value to be compared.
 */
#define CFE_FUN_BINARY_SEARCH(_pc, _table, _count, _result) do { \
    uint32_t min = 0; \
    uint32_t mid = 0; \
    uint32_t max = _count - 1; \
\
    /* Search while _table[min:max] is not empty */ \
    while (max >= min) { \
        /* Calculate midpoint */ \
        mid = (min + max) / 2; \
\
        /* Determine which half of the array to search */ \
        uint32_t mid_fun_offset = CFE_FUN_BINARY_SEARCH_ENTVAL(_table[mid]); \
        if (mid_fun_offset < _pc) { \
            /* Check for inclusive equality */ \
            if (mid == max || CFE_FUN_BINARY_SEARCH_ENTVAL(_table[mid+1]) > _pc) { \
                _result = &_table[mid]; \
                break; \
            } \
\
            /* Base our search on the upper array */ \
            min = mid + 1; \
        } else if (mid_fun_offset > _pc) { \
            /* Check for range exclusion; if we hit 0, then the range starts after our PC. */ \
            if (mid == 0) { \
                break; \
            } \
            \
            /* Base our search on the lower array */ \
            max = mid - 1; \
        } else if (mid_fun_offset == _pc) { \
            /* Direct match found */ \
            _result = &_table[mid]; \
            break; \
        } \
    } \
} while (0)

/* Evaluates to true if the length of @a _ecount * @a sizof(_etype) can not be represented
 * by size_t. */
#define VERIFY_SIZE_T(_etype, _ecount) (SIZE_MAX / sizeof(_etype) < (size_t) _ecount)

/**
 * Return the compact frame encoding entry for @a pc via @a encoding, if available.
 *
 * @param reader The initialized CFE reader which will be searched for the entry.
 * @param pc The PC value to search for within the CFE data. Note that this value must be relative to
 * the target Mach-O image's __TEXT vmaddr.
 * @param function_base On success, will be populated with the base address of the function. This value is relative to
 * the image's load address, rather than the in-memory address of the loaded image.
 * @param encoding On success, will be populated with the compact frame encoding entry.
 *
 * @return Returns PLFRAME_ESUCCCESS on success, or one of the remaining error codes if a CFE parsing error occurs. If
 * the entry can not be found, PLFRAME_ENOTFOUND will be returned.
 */
plcrash_error_t plcrash_async_cfe_reader_find_pc (plcrash_async_cfe_reader_t *reader, pl_vm_address_t pc, pl_vm_address_t *function_base, uint32_t *encoding) {
    const plcrash_async_byteorder_t *byteorder = reader->byteorder;
    const pl_vm_address_t base_addr = plcrash_async_mobject_base_address(reader->mobj);

    /* Find and map the common encodings table */
    uint32_t common_enc_count = byteorder->swap32(reader->header.commonEncodingsArrayCount);
    uint32_t *common_enc;
    {
        if (VERIFY_SIZE_T(uint32_t, common_enc_count)) {
            PLCF_DEBUG("CFE common encoding count extends beyond the range of size_t");
            return PLCRASH_EINVAL;
        }

        size_t common_enc_len = common_enc_count * sizeof(uint32_t);
        uint32_t common_enc_off = byteorder->swap32(reader->header.commonEncodingsArraySectionOffset);
        common_enc = plcrash_async_mobject_remap_address(reader->mobj, base_addr, common_enc_off, common_enc_len);
        if (common_enc == NULL) {
            PLCF_DEBUG("The declared common table lies outside the mapped CFE range");
            return PLCRASH_EINVAL;
        }
    }

    /* Find and load the first level entry */
    struct unwind_info_section_header_index_entry *first_level_entry = NULL;
    {
        /* Find and map the index */
        uint32_t index_off = byteorder->swap32(reader->header.indexSectionOffset);
        uint32_t index_count = byteorder->swap32(reader->header.indexCount);
        
        if (VERIFY_SIZE_T(sizeof(struct unwind_info_section_header_index_entry), index_count)) {
            PLCF_DEBUG("CFE index count extends beyond the range of size_t");
            return PLCRASH_EINVAL;
        }
        
        if (index_count == 0) {
            PLCF_DEBUG("CFE index contains no entries");
            return PLCRASH_ENOTFOUND;
        }
        
        /*
         * NOTE: CFE includes an extra entry in the total count of second-level pages, ie, from ld64:
         * const uint32_t indexCount = secondLevelPageCount+1;
         *
         * There's no explanation as to why, and tools appear to explicitly ignore the entry entirely. We do the same
         * here.
         */
        PLCF_ASSERT(index_count != 0);
        index_count--;
        
        /* Load the index entries */
        size_t index_len = index_count * sizeof(struct unwind_info_section_header_index_entry);
        struct unwind_info_section_header_index_entry *index_entries = plcrash_async_mobject_remap_address(reader->mobj, base_addr, index_off, index_len);
        if (index_entries == NULL) {
            PLCF_DEBUG("The declared entries table lies outside the mapped CFE range");
            return PLCRASH_EINVAL;
        }
        
        /* Binary search for the first-level entry */
#define CFE_FUN_BINARY_SEARCH_ENTVAL(_tval) (byteorder->swap32(_tval.functionOffset))
        CFE_FUN_BINARY_SEARCH(pc, index_entries, index_count, first_level_entry);
#undef CFE_FUN_BINARY_SEARCH_ENTVAL
        
        if (first_level_entry == NULL) {
            PLCF_DEBUG("Could not find a first level CFE entry for pc=%" PRIx64, (uint64_t) pc);
            return PLCRASH_ENOTFOUND;
        }
    }

    /* Locate and decode the second-level entry */
    uint32_t second_level_offset = byteorder->swap32(first_level_entry->secondLevelPagesSectionOffset);
    uint32_t *second_level_kind = plcrash_async_mobject_remap_address(reader->mobj, base_addr, second_level_offset, sizeof(uint32_t));
    switch (byteorder->swap32(*second_level_kind)) {
        case UNWIND_SECOND_LEVEL_REGULAR: {
            struct unwind_info_regular_second_level_page_header *header;
            header = plcrash_async_mobject_remap_address(reader->mobj, base_addr, second_level_offset, sizeof(*header));
            if (header == NULL) {
                PLCF_DEBUG("The second-level page header lies outside the mapped CFE range");
                return PLCRASH_EINVAL;
            }

            /* Find the entries array */
            uint32_t entries_offset = byteorder->swap16(header->entryPageOffset);
            uint32_t entries_count = byteorder->swap16(header->entryCount);
            
            if (VERIFY_SIZE_T(sizeof(struct unwind_info_regular_second_level_entry), entries_count)) {
                PLCF_DEBUG("CFE second level entry count extends beyond the range of size_t");
                return PLCRASH_EINVAL;
            }
            
            if (!plcrash_async_mobject_verify_local_pointer(reader->mobj, (uintptr_t)header, entries_offset, entries_count * sizeof(struct unwind_info_regular_second_level_entry))) {
                PLCF_DEBUG("CFE entries table lies outside the mapped CFE range");
                return PLCRASH_EINVAL;
            }
            
            /* Binary search for the target entry */
            struct unwind_info_regular_second_level_entry *entries = (struct unwind_info_regular_second_level_entry *) (((uintptr_t)header) + entries_offset);
            struct unwind_info_regular_second_level_entry *entry = NULL;
            
#define CFE_FUN_BINARY_SEARCH_ENTVAL(_tval) (byteorder->swap32(_tval.functionOffset))
            CFE_FUN_BINARY_SEARCH(pc, entries, entries_count, entry);
#undef CFE_FUN_BINARY_SEARCH_ENTVAL
            
            if (entry == NULL) {
                PLCF_DEBUG("Could not find a second level regular CFE entry for pc=%" PRIx64, (uint64_t) pc);
                return PLCRASH_ENOTFOUND;
            }

            *encoding = byteorder->swap32(entry->encoding);
            *function_base = byteorder->swap32(entry->functionOffset);
            return PLCRASH_ESUCCESS;
        }

        case UNWIND_SECOND_LEVEL_COMPRESSED: {
            struct unwind_info_compressed_second_level_page_header *header;
            header = plcrash_async_mobject_remap_address(reader->mobj, base_addr, second_level_offset, sizeof(*header));
            if (header == NULL) {
                PLCF_DEBUG("The second-level page header lies outside the mapped CFE range");
                return PLCRASH_EINVAL;
            }
            
            /* Record the base offset */
            uint32_t base_foffset = byteorder->swap32(first_level_entry->functionOffset);

            /* Find the entries array */
            uint32_t entries_offset = byteorder->swap16(header->entryPageOffset);
            uint32_t entries_count = byteorder->swap16(header->entryCount);

            if (VERIFY_SIZE_T(sizeof(uint32_t), entries_count)) {
                PLCF_DEBUG("CFE second level entry count extends beyond the range of size_t");
                return PLCRASH_EINVAL;
            }
            
            if (!plcrash_async_mobject_verify_local_pointer(reader->mobj, (uintptr_t)header, entries_offset, entries_count * sizeof(uint32_t))) {
                PLCF_DEBUG("CFE entries table lies outside the mapped CFE range");
                return PLCRASH_EINVAL;
            }

            /* Binary search for the target entry */
            uint32_t *compressed_entries = (uint32_t *) (((uintptr_t)header) + entries_offset);
            uint32_t *c_entry_ptr = NULL;

#define CFE_FUN_BINARY_SEARCH_ENTVAL(_tval) (base_foffset + UNWIND_INFO_COMPRESSED_ENTRY_FUNC_OFFSET(byteorder->swap32(_tval)))
            CFE_FUN_BINARY_SEARCH(pc, compressed_entries, entries_count, c_entry_ptr);
#undef CFE_FUN_BINARY_SEARCH_ENTVAL
            
            if (c_entry_ptr == NULL) {
                PLCF_DEBUG("Could not find a second level compressed CFE entry for pc=%" PRIx64, (uint64_t) pc);
                return PLCRASH_ENOTFOUND;
            }

            /* Find the actual encoding */
            uint32_t c_entry = byteorder->swap32(*c_entry_ptr);
            uint8_t c_encoding_idx = UNWIND_INFO_COMPRESSED_ENTRY_ENCODING_INDEX(c_entry);
            
            /* Save the function base */
            *function_base = base_foffset + UNWIND_INFO_COMPRESSED_ENTRY_FUNC_OFFSET(byteorder->swap32(c_entry));
            
            /* Handle common table entries */
            if (c_encoding_idx < common_enc_count) {
                /* Found in the common table. The offset is verified as being within the mapped memory range by
                 * the < common_enc_count check above. */
                *encoding = byteorder->swap32(common_enc[c_encoding_idx]);
                return PLCRASH_ESUCCESS;
            }

            /* Map in the encodings table */
            uint32_t encodings_offset = byteorder->swap16(header->encodingsPageOffset);
            uint32_t encodings_count = byteorder->swap16(header->encodingsCount);
            
            if (VERIFY_SIZE_T(sizeof(uint32_t), encodings_count)) {
                PLCF_DEBUG("CFE second level entry count extends beyond the range of size_t");
                return PLCRASH_EINVAL;
            }

            if (!plcrash_async_mobject_verify_local_pointer(reader->mobj, (uintptr_t)header, encodings_offset, encodings_count * sizeof(uint32_t))) {
                PLCF_DEBUG("CFE compressed encodings table lies outside the mapped CFE range");
                return PLCRASH_EINVAL;
            }

            uint32_t *encodings = (uint32_t *) (((uintptr_t)header) + encodings_offset);

            /* Verify that the entry is within range */
            c_encoding_idx -= common_enc_count;
            if (c_encoding_idx >= encodings_count) {
                PLCF_DEBUG("Encoding index lies outside the second level encoding table");
                return PLCRASH_EINVAL;
            }

            /* Save the results */
            *encoding = byteorder->swap32(encodings[c_encoding_idx]);
            return PLCRASH_ESUCCESS;
        }

        default:
            PLCF_DEBUG("Unsupported second-level CFE table kind: 0x%" PRIx32 " at 0x%" PRIx32, byteorder->swap32(*second_level_kind), second_level_offset);
            return PLCRASH_EINVAL;
    }

    // Unreachable
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"
    __builtin_trap();
    return PLCRASH_ENOTFOUND;
#pragma clang diagnostic pop
}

/**
 * Free all resources associated with @a reader.
 */
void plcrash_async_cfe_reader_free (plcrash_async_cfe_reader_t *reader) {
    // noop
}

#pragma mark CFE Entry


/**
 * @internal
 * Encode a ordered register list using the 10 bit register encoding as defined by the CFE format.
 *
 * @param registers The ordered list of registers to encode. These values must correspond to the CFE register values,
 * <em>not</em> the register values as defined in the PLCrashReporter thread state APIs.
 * @param count The number of registers in @a registers. This must not exceed the maximum number of registers supported by the
 * permutation encoding (PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX).
 *
 * @warning This API is unlikely to be useful outside the CFE encoder implementation, and should not generally be used.
 * Callers must be careful to pass only literal register values defined in the CFE format (eg, values 1-6).
 */
uint32_t plcrash_async_cfe_register_encode (const uint32_t registers[], uint32_t count) {
    /* Supplied count must be within supported range */
    PLCF_ASSERT(count <= PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX);

    /*
     * Use a positional encoding to encode each integer in the list as an integer value
     * that is less than the previous greatest integer in the list. We know that each
     * integer (numbered 1-6) may appear only once in the list.
     *
     * For example:
     *   6 5 4 3 2 1 ->
     *   5 4 3 2 1 0
     *
     *   6 3 5 2 1 ->
     *   5 2 3 1 0
     *
     *   1 2 3 4 5 6 ->
     *   0 0 0 0 0 0
     */
    uint32_t renumbered[PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX];
    for (int i = 0; i < count; ++i) {
        unsigned countless = 0;
        for (int j = 0; j < i; ++j)
            if (registers[j] < registers[i])
                countless++;
        
        renumbered[i] = registers[i] - countless - 1;
    }
    
    uint32_t permutation = 0;
    
    /*
     * Using the renumbered list, we map each element of the list (positionally) into a range large enough to represent
     * the range of any valid element, as well as be subdivided to represent the range of later elements.
     *
     * For example, if we use a factor of 120 for the first position (encoding multiples, decoding divides), that
     * provides us with a range of 0-719. There are 6 possible values that may be encoded in 0-719 (assuming later
     * division by 120), the range is broken down as:
     *
     *   0   - 119: 0
     *   120 - 239: 1
     *   240 - 359: 2
     *   360 - 479: 3
     *   480 - 599: 4
     *   600 - 719: 5
     *
     * Within that range, further positions may be encoded. Assuming a value of 1 in position 0, and a factor of
     * 24 for position 1, the range breakdown would be as follows:
     *   120 - 143: 0
     *   144 - 167: 1
     *   168 - 191: 2
     *   192 - 215: 3
     *   216 - 239: 4
     *
     * Note that due to the positional renumbering performed prior to this step, we know that each subsequent position
     * in the list requires fewer elements; eg, position 0 may include 0-5, position 1 0-4, and position 2 0-3. This
     * allows us to allocate smaller overall ranges to represent all possible elements.
     */
    
    /* Assert that the maximum register count matches our switch() statement. */
    PLCR_ASSERT_STATIC(expected_max_register_count, PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX == 6);
    switch (count) {
        case 1:
            permutation |= renumbered[0];
            break;
            
        case 2:
            permutation |= (5*renumbered[0] + renumbered[1]);
            break;
            
        case 3:
            permutation |= (20*renumbered[0] + 4*renumbered[1] + renumbered[2]);
            break;
            
        case 4:
            permutation |= (60*renumbered[0] + 12*renumbered[1] + 3*renumbered[2] + renumbered[3]);
            break;
            
        case 5:
            permutation |= (120*renumbered[0] + 24*renumbered[1] + 6*renumbered[2] + 2*renumbered[3] + renumbered[4]);
            break;
            
        case 6:
            /*
             * There are 6 elements in the list, 6 possible values for each element, and values may not repeat. The
             * value of the last element can be derived from the values previously seen (and due to the positional
             * renumbering performed above, the value of the last element will *always* be 0.
             */
            permutation |= (120*renumbered[0] + 24*renumbered[1] + 6*renumbered[2] + 2*renumbered[3] + renumbered[4]);
            break;
    }
    
    PLCF_ASSERT((permutation & 0x3FF) == permutation);
    return permutation;
}

/**
 * @internal
 * Decode a ordered register list from the 10 bit register encoding as defined by the CFE format.
 *
 * @param permutation The 10-bit encoded register list.
 * @param count The number of registers to decode from @a permutation.
 * @param registers On return, the ordered list of decoded register values. These values must correspond to the CFE
 * register values, <em>not</em> the register values as defined in the PLCrashReporter thread state APIs.
 *
 * @return Returns PLCRASH_ESUCCESS on success, or an appropriate error on failure. This function may fail if @a count
 * exceeds the total number of register values supported by the permutation encoding; this should only occur in the
 * case that the register count supplied from the binary is invalid.
 *
 * @warning This API is unlikely to be useful outside the CFE encoder implementation, and should not generally be used.
 * Callers must be careful to pass only literal register values defined in the CFE format (eg, values 1-6).
 */
plcrash_error_t plcrash_async_cfe_register_decode (uint32_t permutation, uint32_t count, uint32_t registers[]) {
    /* Validate that count falls within the supported range */
    if (count > PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX) {
        PLCF_DEBUG("Register permutation decoding attempted with an unsupported count of %" PRIu32, count);
        return PLCRASH_EINVAL;
    }

    /*
     * Each register is encoded by mapping the values to a 10-bit range, and then further sub-ranges within that range,
     * with a subrange allocated to each position. See the encoding function for full documentation.
     */
    int permunreg[PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX];
#define PERMUTE(pos, factor) do { \
permunreg[pos] = permutation/factor; \
permutation -= (permunreg[pos]*factor); \
} while (0)

    /* Assert that the maximum register count matches our switch() statement. */
    PLCR_ASSERT_STATIC(expected_max_register_count, PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX == 6);
	switch (count) {
		case 6:
            PERMUTE(0, 120);
            PERMUTE(1, 24);
            PERMUTE(2, 6);
            PERMUTE(3, 2);
            PERMUTE(4, 1);
            
            /*
             * There are 6 elements in the list, 6 possible values for each element, and values may not repeat. The
             * value of the last element can be derived from the values previously seen (and due to the positional
             * renumbering performed, the value of the last element will *always* be 0).
             */
            permunreg[5] = 0;
			break;
		case 5:
            PERMUTE(0, 120);
            PERMUTE(1, 24);
            PERMUTE(2, 6);
            PERMUTE(3, 2);
            PERMUTE(4, 1);
			break;
		case 4:
            PERMUTE(0, 60);
            PERMUTE(1, 12);
            PERMUTE(2, 3);
            PERMUTE(3, 1);
			break;
		case 3:
            PERMUTE(0, 20);
            PERMUTE(1, 4);
            PERMUTE(2, 1);
			break;
		case 2:
            PERMUTE(0, 5);
            PERMUTE(1, 1);
			break;
		case 1:
            PERMUTE(0, 1);
			break;
	}
#undef PERMUTE
    
	/* Recompute the actual register values based on the position-relative values. */
	bool position_used[PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX+1] = { 0 };
    
	for (uint32_t i = 0; i < count; ++i) {
		int renumbered = 0;
		for (int u = 1; u < 7; u++) {
			if (!position_used[u]) {
				if (renumbered == permunreg[i]) {
					registers[i] = u;
					position_used[u] = true;
					break;
				}
				renumbered++;
			}
		}
	}
    
    return PLCRASH_ESUCCESS;
}

/**
 * @internal
 *
 * Map the @a orig_reg CFE register name to a PLCrashReporter PLCRASH_* register name constant.
 *
 * @param orig_reg Register name as decoded from a CFE entry.
 * @param cpu_type The CPU type that should be used when interpreting @a orig_reg;
 */
static plcrash_error_t plcrash_async_map_register_name (uint32_t orig_reg, plcrash_regnum_t *result, cpu_type_t cpu_type) {
    if (cpu_type == CPU_TYPE_X86) {
        switch (orig_reg) {
            case UNWIND_X86_REG_NONE:
                *result = PLCRASH_REG_INVALID;
                return PLCRASH_ESUCCESS;
    
            case UNWIND_X86_REG_EBX:
                *result = PLCRASH_X86_EBX;
                return PLCRASH_ESUCCESS;

            case UNWIND_X86_REG_ECX:
                *result = PLCRASH_X86_ECX;
                return PLCRASH_ESUCCESS;
                
            case UNWIND_X86_REG_EDX:
                *result = PLCRASH_X86_EDX;
                return PLCRASH_ESUCCESS;
                
            case UNWIND_X86_REG_EDI:
                *result = PLCRASH_X86_EDI;
                return PLCRASH_ESUCCESS;
                
            case UNWIND_X86_REG_ESI:
                *result = PLCRASH_X86_ESI;
                return PLCRASH_ESUCCESS;
                
            case UNWIND_X86_REG_EBP:
                *result = PLCRASH_X86_EBP;
                return PLCRASH_ESUCCESS;
            default:
                PLCF_DEBUG("Requested register mapping for unknown register %" PRId32, orig_reg);
                return PLCRASH_EINVAL;
        }
    } else if (cpu_type == CPU_TYPE_X86_64) {
        switch (orig_reg) {
            case UNWIND_X86_64_REG_NONE:
                *result = PLCRASH_REG_INVALID;
                return PLCRASH_ESUCCESS;
    
            case UNWIND_X86_64_REG_RBX:
                *result = PLCRASH_X86_64_RBX;
                return PLCRASH_ESUCCESS;
            case UNWIND_X86_64_REG_R12:
                *result = PLCRASH_X86_64_R12;
                return PLCRASH_ESUCCESS;
            case UNWIND_X86_64_REG_R13:
                *result = PLCRASH_X86_64_R13;
                return PLCRASH_ESUCCESS;
            case UNWIND_X86_64_REG_R14:
                *result = PLCRASH_X86_64_R14;
                return PLCRASH_ESUCCESS;
            case UNWIND_X86_64_REG_R15:
                *result = PLCRASH_X86_64_R15;
                return PLCRASH_ESUCCESS;
            case UNWIND_X86_64_REG_RBP:
                *result = PLCRASH_X86_64_RBP;
                return PLCRASH_ESUCCESS;
            default:
                PLCF_DEBUG("Requested register mapping for unknown register %" PRId32, orig_reg);
                return PLCRASH_EINVAL;
        }
    } else {
        PLCF_DEBUG("Requested register mapping for unknown cpu type %" PRIu32, cpu_type);
        return PLCRASH_ENOTSUP;
    }
}

/**
 * Initialize a new decoded CFE entry using the provided encoded CFE data. Any resources held by a successfully
 * initialized instance must be freed via plcrash_async_cfe_entry_free();
 *
 * @param entry The entry instance to initialize.
 * @param cpu_type The target architecture of the CFE data, encoded as a Mach-O CPU type. Interpreting CFE data is
 * architecture-specific, and Apple has not defined encodings for all supported architectures.
 * @param encoding The CFE entry data, in the hosts' native byte order.
 *
 * @internal
 * This code supports sparse register lists for the EBP_FRAME and RBP_FRAME modes. It's unclear as to whether these
 * actually ever occur in the wild, but they are supported by Apple's unwinddump tool.
 */
plcrash_error_t plcrash_async_cfe_entry_init (plcrash_async_cfe_entry_t *entry, cpu_type_t cpu_type, uint32_t encoding) {
    plcrash_error_t ret;
    
    /* Target-neutral initialization */
    entry->cpu_type = cpu_type;
    entry->stack_adjust = 0;
    entry->return_address_register = PLCRASH_REG_INVALID;

    /* Perform target-specific decoding */
    if (cpu_type == CPU_TYPE_X86) {
        uint32_t mode = encoding & UNWIND_X86_MODE_MASK;
        switch (mode) {
            case UNWIND_X86_MODE_EBP_FRAME: {
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAME_PTR;

                /* Extract the register frame offset */
                entry->stack_offset = -(EXTRACT_BITS(encoding, UNWIND_X86_EBP_FRAME_OFFSET) * sizeof(uint32_t));

                /* Extract the register values. They're stored as a bitfield of of 3 bit values. We support
                 * sparse entries, but terminate the loop if no further entries remain. */
                uint32_t regs = EXTRACT_BITS(encoding, UNWIND_X86_EBP_FRAME_REGISTERS);
                entry->register_count = 0;
                for (uint32_t i = 0; i < PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX; i++) {
                    /* Check for completion */
                    uint32_t remaining = regs >> (3 * i);
                    if (remaining == 0)
                        break;

                    /* Map to the correct PLCrashReporter register name */
                    uint32_t reg = remaining & 0x7;
                    ret = plcrash_async_map_register_name(reg, &entry->register_list[i], cpu_type);
                    if (ret != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to map register value of %" PRIx32, reg);
                        return ret;
                    }

                    /* Update the register count */
                    entry->register_count++;
                }
                
                return PLCRASH_ESUCCESS;
            }

            case UNWIND_X86_MODE_STACK_IMMD:
            case UNWIND_X86_MODE_STACK_IND: {
                /* These two types are identical except for the interpretation of the stack offset and adjustment values */
                if (mode == UNWIND_X86_MODE_STACK_IMMD) {
                    entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD;
                    entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_X86_FRAMELESS_STACK_SIZE) * sizeof(uint32_t);
                } else {
                    entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT;
                    entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_X86_FRAMELESS_STACK_SIZE);
                    entry->stack_adjust = EXTRACT_BITS(encoding, UNWIND_X86_FRAMELESS_STACK_ADJUST) * sizeof(uint32_t);
                }

                /* Extract the register values */
                entry->register_count = EXTRACT_BITS(encoding, UNWIND_X86_FRAMELESS_STACK_REG_COUNT);
                uint32_t encoded_regs = EXTRACT_BITS(encoding, UNWIND_X86_FRAMELESS_STACK_REG_PERMUTATION);
                uint32_t decoded_regs[PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX];
                
                ret = plcrash_async_cfe_register_decode(encoded_regs, entry->register_count, decoded_regs);
                if (ret != PLCRASH_ESUCCESS) {
                    PLCF_DEBUG("Failed to decode register list: %d", ret);
                    return ret;
                }
                
                /* Map to the correct PLCrashReporter register names */
                for (uint32_t i = 0; i < entry->register_count; i++) {
                    ret = plcrash_async_map_register_name(decoded_regs[i], &entry->register_list[i], cpu_type);
                    if (ret != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to map register value of %" PRIx32, entry->register_list[i]);
                        return ret;
                    }
                }

                return PLCRASH_ESUCCESS;
            }

            case UNWIND_X86_MODE_DWARF:
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_DWARF;

                /* Extract the register frame offset */
                entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_X86_DWARF_SECTION_OFFSET);
                entry->register_count = 0;

                return PLCRASH_ESUCCESS;

            case 0:
                /* Handle a NULL encoding. This interpretation is derived from Apple's actual implementation; the correct interpretation of
                 * a 0x0 value is not defined in what documentation exists. */
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_NONE;
                entry->stack_offset = 0;
                entry->register_count = 0;
                return PLCRASH_ESUCCESS;
                
            default:
                PLCF_DEBUG("Unexpected entry mode of %" PRIx32, mode);
                return PLCRASH_ENOTSUP;
        }
        
        // Unreachable
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"
        __builtin_trap();
        return PLCRASH_EINTERNAL;
#pragma clang diagnostic pop
    } else if (cpu_type == CPU_TYPE_X86_64) {
        uint32_t mode = encoding & UNWIND_X86_64_MODE_MASK;
        switch (mode) {
            case UNWIND_X86_64_MODE_RBP_FRAME: {
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAME_PTR;
                
                /* Extract the register frame offset */
                entry->stack_offset = -(EXTRACT_BITS(encoding, UNWIND_X86_64_RBP_FRAME_OFFSET) * sizeof(uint64_t));

                /* Extract the register values. They're stored as a bitfield of of 3 bit values. We support
                 * sparse entries, but terminate the loop if no further entries remain. */
                uint32_t regs = EXTRACT_BITS(encoding, UNWIND_X86_64_RBP_FRAME_REGISTERS);
                entry->register_count = 0;
                for (uint32_t i = 0; i < PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX; i++) {
                    /* Check for completion */
                    uint32_t remaining = regs >> (3 * i);
                    if (remaining == 0)
                        break;
                    
                    /* Map to the correct PLCrashReporter register name */
                    uint32_t reg = remaining & 0x7;
                    ret = plcrash_async_map_register_name(reg, &entry->register_list[i], cpu_type);
                    if (ret != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to map register value of %" PRIx32, reg);
                        return ret;
                    }
                    
                    /* Update the register count */
                    entry->register_count++;
                }
                
                return PLCRASH_ESUCCESS;
            }
    
            case UNWIND_X86_64_MODE_STACK_IMMD:
            case UNWIND_X86_64_MODE_STACK_IND: {
                /* These two types are identical except for the interpretation of the stack offset and adjustment values */
                if (mode == UNWIND_X86_64_MODE_STACK_IMMD) {
                    entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD;
                    entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_X86_64_FRAMELESS_STACK_SIZE) * sizeof(uint64_t);
                } else {
                    entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT;
                    entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_X86_64_FRAMELESS_STACK_SIZE);
                    entry->stack_adjust = EXTRACT_BITS(encoding, UNWIND_X86_64_FRAMELESS_STACK_ADJUST) * sizeof(uint64_t);
                }
                
                /* Extract the register values */
                entry->register_count = EXTRACT_BITS(encoding, UNWIND_X86_64_FRAMELESS_STACK_REG_COUNT);
                uint32_t encoded_regs = EXTRACT_BITS(encoding, UNWIND_X86_64_FRAMELESS_STACK_REG_PERMUTATION);
                uint32_t decoded_regs[PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX];

                ret = plcrash_async_cfe_register_decode(encoded_regs, entry->register_count, decoded_regs);
                if (ret != PLCRASH_ESUCCESS) {
                    PLCF_DEBUG("Failed to decode register list: %d", ret);
                    return ret;
                }

                /* Map to the correct PLCrashReporter register names */
                for (uint32_t i = 0; i < entry->register_count; i++) {
                    ret = plcrash_async_map_register_name(decoded_regs[i], &entry->register_list[i], cpu_type);
                    if (ret != PLCRASH_ESUCCESS) {
                        PLCF_DEBUG("Failed to map register value of %" PRIx32, entry->register_list[i]);
                        return ret;
                    }
                }
                
                return PLCRASH_ESUCCESS;
            }
                
            case UNWIND_X86_64_MODE_DWARF:
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_DWARF;
                
                /* Extract the register frame offset */
                entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_X86_64_DWARF_SECTION_OFFSET);
                entry->register_count = 0;
                
                return PLCRASH_ESUCCESS;
            
            case 0:
                /* Handle a NULL encoding. This interpretation is derived from Apple's actual implementation; the correct interpretation of
                 * a 0x0 value is not defined in what documentation exists. */
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_NONE;
                entry->stack_offset = 0;
                entry->register_count = 0;
                return PLCRASH_ESUCCESS;
                
                
            default:
                PLCF_DEBUG("Unexpected entry mode of %" PRIx32, mode);
                return PLCRASH_ENOTSUP;
        }
        
        // Unreachable
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"
        __builtin_trap();
        return PLCRASH_EINTERNAL;
#pragma clang diagnostic pop
    } else if (cpu_type == CPU_TYPE_ARM64) {
        uint32_t mode = encoding & UNWIND_ARM64_MODE_MASK;
        switch (mode) {
            case UNWIND_ARM64_MODE_FRAME:
                // Fall through
            case UNWIND_ARM64_MODE_FRAMELESS:
                if (mode == UNWIND_ARM64_MODE_FRAME) {
                    entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAME_PTR;
                    /* The stack offset will be calculated below */
                } else {
                    /*
                     * The compact_unwind header documents this as UNWIND_ARM64_MODE_LEAF, but actually defines UNWIND_ARM64_MODE_FRAMELESS.
                     * Reviewing the libunwind stepWithCompactEncodingFrameless() assembly demonstrates that this actually uses the
                     * i386/x86-64 frameless immediate style of encoding an offset from the stack pointer. Unlike x86, however, the
                     * offset is multipled by 16 bytes (since each register is stored in pairs), rather than the platform word size.
                     *
                     * The header discrepancy was reported as rdar://15057141
                     */
                    entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD;
                    entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_ARM64_FRAMELESS_STACK_SIZE_MASK) * (sizeof(uint64_t) * 2);
                    entry->return_address_register = PLCRASH_ARM64_LR;
                }
                
                
                /* Extract the register values */
                size_t reg_pos = 0;
                entry->register_count = 0;
                #define CHECK_REG(name, val1, val2) do { \
                    if ((encoding & name) == name) { \
                        PLCF_ASSERT(entry->register_count+2 <= PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX); \
                        entry->register_list[reg_pos++] = val2; \
                        entry->register_list[reg_pos++] = val1; \
                        entry->register_count += 2; \
                    } \
                } while(0)
                CHECK_REG(UNWIND_ARM64_FRAME_X27_X28_PAIR, PLCRASH_ARM64_X27, PLCRASH_ARM64_X28);
                CHECK_REG(UNWIND_ARM64_FRAME_X25_X26_PAIR, PLCRASH_ARM64_X25, PLCRASH_ARM64_X26);
                CHECK_REG(UNWIND_ARM64_FRAME_X23_X24_PAIR, PLCRASH_ARM64_X23, PLCRASH_ARM64_X24);
                CHECK_REG(UNWIND_ARM64_FRAME_X21_X22_PAIR, PLCRASH_ARM64_X21, PLCRASH_ARM64_X22);
                CHECK_REG(UNWIND_ARM64_FRAME_X19_X20_PAIR, PLCRASH_ARM64_X19, PLCRASH_ARM64_X20);
                #undef CHECK_REG

                /* Offset depends on the number of saved registers */
                if (mode == UNWIND_ARM64_MODE_FRAME)
                    entry->stack_offset = -(entry->register_count * sizeof(uint64_t));
            
                return PLCRASH_ESUCCESS;
                
            case UNWIND_ARM64_MODE_DWARF:
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_DWARF;
                
                /* Extract the register frame offset */
                entry->stack_offset = EXTRACT_BITS(encoding, UNWIND_ARM64_DWARF_SECTION_OFFSET);
                entry->register_count = 0;
                return PLCRASH_ESUCCESS;
                
            case 0:
                /* Handle a NULL encoding. This interpretation is derived from Apple's actual implementation; the correct interpretation of
                 * a 0x0 value is not defined in what documentation exists. */
                entry->type = PLCRASH_ASYNC_CFE_ENTRY_TYPE_NONE;
                entry->stack_offset = 0;
                entry->register_count = 0;
                return PLCRASH_ESUCCESS;
                
            default:
                PLCF_DEBUG("Unexpected entry mode of %" PRIx32, mode);
                return PLCRASH_ENOTSUP;
        }

    }

    PLCF_DEBUG("Unsupported CPU type: %" PRIu32, cpu_type);
    return PLCRASH_ENOTSUP;
}

/**
 * Return the CFE entry type.
 *
 * @param entry The entry for which the type should be returned.
 */
plcrash_async_cfe_entry_type_t plcrash_async_cfe_entry_type (plcrash_async_cfe_entry_t *entry) {
    return entry->type;
}

/**
 * Return the stack offset value. Interpretation of this value depends on the CFE type:
 * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAME_PTR: Unused.
 * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD: The return address may be found at ± offset from the stack
 *   pointer (eg, esp/rsp), and is followed all non-volatile registers that need to be restored.
 * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT: The actual offset may be loaded from the target function's
 *   instruction prologue. The offset given here must be added to the start address of the function to determine
 *   the location of the actual stack size as encoded in the prologue.
 *
 *   The return address may be found at ± offset from the stack pointer (eg, esp/rsp), and is followed all
 *   non-volatile registers that need to be restored.
 *
 *   TODO: Need a mechanism to define the actual size of the offset. For x86-32/x86-64, it is defined as being
 *   encoded in a subl instruction.
 * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_DWARF: Unused.
 *
 * @param entry The entry from which the stack offset value will be fetched.
 */
intptr_t plcrash_async_cfe_entry_stack_offset (plcrash_async_cfe_entry_t *entry) {
    return entry->stack_offset;
}

/**
 * Return the stack adjustment value. This is an offset to be applied to the final stack value read via
 * PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT.
 *
 * This value is unused for all other CFE types.
 */
uint32_t plcrash_async_cfe_entry_stack_adjustment (plcrash_async_cfe_entry_t *entry) {
    return entry->stack_adjust;
}

/**
 * The register to be used for the return address (eg, such as in a ARM leaf frame, where the return address may be found in lr),
 * or PLCRASH_REG_INVALID if the return address is found on the stack. This value is only supported for the following CFE types:
 *
 * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD and
 * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT
 */
plcrash_regnum_t plcrash_async_cfe_entry_return_address_register (plcrash_async_cfe_entry_t *entry) {
    PLCF_ASSERT(entry->return_address_register == PLCRASH_REG_INVALID || entry->type == PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD || entry->type == PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT);
    return entry->return_address_register;
}

/**
 * The number of non-volatile registers that need to be restored from the stack.
 */
uint32_t plcrash_async_cfe_entry_register_count (plcrash_async_cfe_entry_t *entry) {
    return entry->register_count;
}

/**
 * Copy the ordered list of non-volatile registers that must be restored from the stack to @a register_list. These
 * values are specific to the target platform, and are defined in the @a plcrash_async_thread API.
 * @sa plcrash_x86_regnum_t and @sa plcrash_x86_64_regnum_t.
 *
 * Note that the list may be sparse; some entries may be set to a value of PLCRASH_REG_INVALID.
 *
 * @param entry The entry from which the register list should be copied.
 * @param register_list An array to which the registers will be copied. plcrash_async_cfe_register_count() may be used
 * to determine the number of registers to be copied.
 */
void plcrash_async_cfe_entry_register_list (plcrash_async_cfe_entry_t *entry, plcrash_regnum_t *register_list) {
    memcpy(register_list, entry->register_list, sizeof(entry->register_list[0]) * entry->register_count);
}

/**
 * Apply the decoded @a entry to @a thread_state, fetching data from @a task, populating @a new_thread_state
 * with the result.
 *
 * @param task The task containing any data referenced by @a thread_state.
 * @param function_address The task-relative in-memory address of the function containing @a entry. This may be computed
 * by adding the function_base returned by plcrash_async_cfe_reader_find_pc() to the base address of the loaded image.
 * @param thread_state The current thread state corresponding to @a entry.
 * @param entry A CFE unwind entry.
 * @param new_thread_state The new thread state to be initialized.
 *
 * @return Returns PLCRASH_ESUCCESS on success, or a standard plcrash_error_t code if an error occurs.
 *
 * @todo This implementation assumes downwards stack growth.
 */
plcrash_error_t plcrash_async_cfe_entry_apply (task_t task,
                                               pl_vm_address_t function_address,
                                               const plcrash_async_thread_state_t *thread_state,
                                               plcrash_async_cfe_entry_t *entry,
                                               plcrash_async_thread_state_t *new_thread_state)
{
    /* Set up register load target */
    size_t greg_size = plcrash_async_thread_state_get_greg_size(thread_state);
    bool x64 = (greg_size == sizeof(uint64_t));
    void *dest;
    union {
        /* Room for (frame pointer, return address) + saved registers */
        uint64_t greg64[PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX];
        uint32_t greg32[PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX];
    } regs;

    if (x64)
        dest = regs.greg64;
    else
        dest = regs.greg32;
    
    /* Sanity check: We'll use this buffer for popping the fp and pc, as well as restoring the saved registers. */
    PLCF_ASSERT(PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX >= 2);

    /* Initialize the new thread state */
    *new_thread_state = *thread_state;
    plcrash_async_thread_state_clear_volatile_regs(new_thread_state);

    pl_vm_address_t saved_reg_addr = 0x0;
    plcrash_async_cfe_entry_type_t entry_type = plcrash_async_cfe_entry_type(entry);
    switch (entry_type) {
        case PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAME_PTR: {
            plcrash_error_t err;

            /* Fetch the current frame pointer */
            if (!plcrash_async_thread_state_has_reg(thread_state, PLCRASH_REG_FP)) {
                PLCF_DEBUG("Can't apply FRAME_PTR unwind type without a valid frame pointer");
                return PLCRASH_ENOTFOUND;
            }

            plcrash_greg_t fp = plcrash_async_thread_state_get_reg(thread_state, PLCRASH_REG_FP);
            
            /* Address of saved registers */
            saved_reg_addr = (pl_vm_address_t)(fp + entry->stack_offset);
            
            /* Restore the previous frame's stack pointer from the saved frame pointer. This is
             * the FP + saved FP + return address. */
            pl_vm_address_t new_sp;
            if (!plcrash_async_address_apply_offset((pl_vm_address_t) fp, greg_size * 2, &new_sp)) {
                PLCF_DEBUG("Current frame pointer falls outside of addressable bounds");
                return PLCRASH_EINVAL;
            }
    
            plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_SP, new_sp);

            /* Read the saved fp and retaddr */
            err = plcrash_async_task_memcpy(task, (pl_vm_address_t) fp, 0, dest, greg_size * 2);
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("Failed to read frame data at address 0x%" PRIx64 ": %d", (uint64_t) fp, err);
                return err;
            }

            // XXX: This assumes downward stack growth.
            if (x64) {
                plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_FP, regs.greg64[0]);
                plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_IP, regs.greg64[1]);
            } else {
                plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_FP, regs.greg32[0]);
                plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_IP, regs.greg32[1]);
            }
            break;
        }
            
        case PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT:
            // Fallthrough
            
        case PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD: {
            plcrash_error_t err;

            /* Fetch the current stack pointer */
            if (!plcrash_async_thread_state_has_reg(thread_state, PLCRASH_REG_SP)) {
                PLCF_DEBUG("Can't apply FRAME_IMMD unwind type without a valid stack pointer");
                return PLCRASH_ENOTFOUND;
            }

            /* Extract the stack size */
            pl_vm_address_t stack_size = entry->stack_offset;
            if (entry_type == PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT) {
                /* Stack size is encoded as a 32-bit value within the target process' TEXT segment; the value
                 * provided from the entry is used as an offset from the start of the function to the actual
                 * stack size. */
                uint32_t indirect;

                err = plcrash_async_task_memcpy(task, function_address, stack_size, &indirect, sizeof(indirect));
                if (err != PLCRASH_ESUCCESS) {
                    PLCF_DEBUG("Failed to read indirect stack size from 0x%" PRIx64 " + 0x%" PRIx64 ": %d",
                               (uint64_t) function_address, (uint64_t)stack_size, err);
                    return err;
                }

                stack_size = indirect + entry->stack_adjust;
            }

            /* Compute the stack pointer address */
            plcrash_greg_t sp = stack_size + plcrash_async_thread_state_get_reg(thread_state, PLCRASH_REG_SP);
            plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_SP, sp);

            if (entry->return_address_register == PLCRASH_REG_INVALID) {
                /* Return address is on the stack */
                pl_vm_address_t retaddr = (pl_vm_address_t)(sp - greg_size);
                saved_reg_addr = retaddr - (greg_size * entry->register_count); /* retaddr - [saved registers] */

                /* Original SP is found just before the return address. */
                plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_SP, retaddr + greg_size);

                /* Read the saved return address */
                err = plcrash_async_task_memcpy(task, (pl_vm_address_t) retaddr, 0, dest, greg_size);
                if (err != PLCRASH_ESUCCESS) {
                    PLCF_DEBUG("Failed to read return address from 0x%" PRIx64 ": %d", (uint64_t) retaddr, err);
                    return err;
                }
                
                if (x64) {
                    plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_IP, regs.greg64[0]);
                } else {
                    plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_IP, regs.greg32[0]);
                }
            } else {
                /* Return address is in a register; verify that the register is available */
                if (!plcrash_async_thread_state_has_reg(thread_state, entry->return_address_register)) {
                    PLCF_DEBUG("The specified return_address_register '%s' is not available", plcrash_async_thread_state_get_reg_name(thread_state, entry->return_address_register));
                    return PLCRASH_ENOTFOUND;
                }
                
                /* Copy the return address value to the new thread state's IP */
                plcrash_async_thread_state_set_reg(new_thread_state, PLCRASH_REG_IP, plcrash_async_thread_state_get_reg(thread_state, entry->return_address_register));
                
                /* Saved registers are found below the new stack pointer. */
                saved_reg_addr = (pl_vm_address_t) sp - (greg_size * entry->register_count); /* sp - [saved registers] */
            }

            break;
        }

            
        case PLCRASH_ASYNC_CFE_ENTRY_TYPE_DWARF:
            return PLCRASH_ENOTSUP;
            
        case PLCRASH_ASYNC_CFE_ENTRY_TYPE_NONE:
            return PLCRASH_ENOTSUP;
    }

    /* Extract the saved registers */
    uint32_t register_count = plcrash_async_cfe_entry_register_count(entry);
    plcrash_regnum_t register_list[PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX];
    plcrash_async_cfe_entry_register_list(entry, register_list);
    for (uint32_t i = 0; i < register_count; i++) {
        /* The register list may be sparse */
        if (register_list[i] == PLCRASH_REG_INVALID)
            continue;

        /* Fetch and save register data */
        plcrash_error_t err;
        err = plcrash_async_task_memcpy(task, (pl_vm_address_t) saved_reg_addr, i*greg_size, dest, greg_size);
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("Failed to read register data for index %s: %d", plcrash_async_thread_state_get_reg_name(thread_state, register_list[i]), err);
            return err;
        }

        if (x64) {
            plcrash_async_thread_state_set_reg(new_thread_state, register_list[i], regs.greg64[0]);
        } else {
            plcrash_async_thread_state_set_reg(new_thread_state, register_list[i], regs.greg32[0]);
        }
    }
    

    return PLCRASH_ESUCCESS;
}

/**
 * Free all resources associated with @a entry.
 */
void plcrash_async_cfe_entry_free (plcrash_async_cfe_entry_t *entry) {
    // noop
}

/*
 * @} plcrash_async_cfe
 */

#endif /* PLCRASH_FEATURE_UNWIND_COMPACT */
