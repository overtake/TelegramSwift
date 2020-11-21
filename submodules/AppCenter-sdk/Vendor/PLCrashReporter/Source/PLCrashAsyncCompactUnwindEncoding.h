/*
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

#ifndef PLCRASH_ASYNC_COMPACT_UNWIND_ENCODING_H
#define PLCRASH_ASYNC_COMPACT_UNWIND_ENCODING_H 1

#include "PLCrashAsync.h"
#include "PLCrashAsyncImageList.h"
#include "PLCrashAsyncThread.h"

#include "PLCrashFeatureConfig.h"

#include <mach-o/compact_unwind_encoding.h>

#if PLCRASH_FEATURE_UNWIND_COMPACT

/**
 * @internal
 * @ingroup plcrash_async_cfe
 * @{
 */

/**
 * @internal
 * A CFE reader instance. Performs CFE data parsing from a backing memory object.
 */
typedef struct plcrash_async_cfe_reader {
    /** A memory object containing the CFE data at the starting address. */
    plcrash_async_mobject_t *mobj;

    /** The target CPU type. */
    cpu_type_t cpu_type;

    /** The unwind info header. Note that the header values may require byte-swapping for the local process' use. */
    struct unwind_info_section_header header;

    /** The byte order of the encoded data (including the header). */
    const plcrash_async_byteorder_t *byteorder;
} plcrash_async_cfe_reader_t;

/**
 * Supported CFE entry formats.
 */
typedef enum {
    /**
     * The frame pointer (fp) is valid. To walk the stack, the previous frame pointer may be popped from
     * the current frame pointer, followed by the return address.
     *
     * All non-volatile registers that need to be restored will be saved on the stack, ranging from fp±regsize through
     * fp±1020. The actual direction depends on the stack growth direction of the target platform.
     */
    PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAME_PTR = 1,

    /**
     * The frame pointer (eg, ebp/rbp) is invalid, but the stack size is constant and is small enough (<= 1024) that it
     * may be encoded in the CFE entry itself.
     *
     * The return address may be found at the provided ± offset from the stack pointer, followed all non-volatile
     * registers that need to be restored. The actual direction of the offset depends on the stack growth direction of
     * the target platform.
     */
    PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD = 2,

    /**
     * The frame pointer (eg, ebp/rbp) is invalid, but the stack size is constant and is too large (>= 1024) to be
     * encoded in the CFE entry itself. Instead, the fixed stack size value must be extracted from an actual instruction
     * (eg, subl) within the target function, and used as the constant stack size. The decoded stack offset may be
     * added to the start address of the function to determine the location of the actual stack size.
     *
     * The return address may be found at the derived ± offset from the stack pointer, followed all non-volatile
     * registers that need to be restored. The actual direction of the offset epends on the stack growth direction of
     * the target platform.
     */
    PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT = 3,

    /**
     * The unwinding information for the target address could not be encoded using the CFE format. Instead, DWARF
     * frame information must be used.
     *
     * An offset to the DWARF FDE in the __eh_frame section is be provided.
     */
    PLCRASH_ASYNC_CFE_ENTRY_TYPE_DWARF = 4,
    
    
    /**
     * No unwind information is available for the target address. This value is only returned in the case where an
     * unwind table entry exists for the given address, but the entry is empty.
     */
    PLCRASH_ASYNC_CFE_ENTRY_TYPE_NONE = 5
} plcrash_async_cfe_entry_type_t;

/** Maximum number of registers supported by the permutation register encoding. @sa plcrash_async_cfe_register_decode and plcrash_async_cfe_register_encode. */
#define PLCRASH_ASYNC_CFE_PERMUTATION_REGISTER_MAX 6

/** Maximum number of saved non-volatile registers that may be represented in an i386 or x86-64 CFE entry */
#define PLCRASH_ASYNC_CFE_SAVED_REGISTER_X86_MAX 6

/** Maximum number of saved non-volatile registers that may be represented in an ARM64 CFE entry */
#define PLCRASH_ASYNC_CFE_SAVED_REGISTER_ARM64_MAX 10

#define _PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX(a, b) (((a) > (b)) ? (a) : (b))

/** Maximum number of saved non-volatile registers that may be represented in a CFE entry */
#define PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX _PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX(PLCRASH_ASYNC_CFE_SAVED_REGISTER_X86_MAX, PLCRASH_ASYNC_CFE_SAVED_REGISTER_ARM64_MAX)

/**
 * @internal
 *
 * A decoded CFE entry. The entry represents the data necessary to unwind the stack frame at a given PC, including
 * restoration of saved registers.
 */
typedef struct plcrash_async_cfe_entry {
    /** The CFE entry type. */
    plcrash_async_cfe_entry_type_t type;

    /** The target CPU type. */
    cpu_type_t cpu_type;

    /**
     * Encoded stack offset. Interpretation of this value depends on the CFE type:
     * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAME_PTR: Saved non-volatile registers may be found at ± offset from the frame
     *   pointer (eg, ebp/rbp).
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
     * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_DWARF: The offset to the DWARF FDE in the __eh_frame section.
     * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_NONE: Unused.
     */
    intptr_t stack_offset;

    /**
     * Stack adjustment offset. This is an offset to be applied to the final stack value read via
     * PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT.
     *
     * This value is unused for all other CFE types.
     */
    uint32_t stack_adjust;
    
    /**
     * The link register to be used for the return address (eg, such as in a ARM leaf frame), or PLCRASH_REG_INVALID if the return address
     * is found on the stack. This value is only supported for the following CFE types:
     * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_IMMD and
     * - PLCRASH_ASYNC_CFE_ENTRY_TYPE_FRAMELESS_INDIRECT
     */
    plcrash_regnum_t return_address_register;

    /**
     * The number of non-volatile registers that need to be restored from the stack.
     */
    uint32_t register_count;

    /**
     * The ordered list of register_count non-volatile registers that must be restored from the stack. These values are
     * specific to the target platform, and are defined in the @a plcrash_async_thread API. @sa plcrash_x86_regnum_t
     * and @sa plcrash_x86_64_regnum_t. Note that the list may be sparse; some entries may be set to a value of
     * PLCRASH_REG_INVALID.
     */
    plcrash_regnum_t register_list[PLCRASH_ASYNC_CFE_SAVED_REGISTER_MAX];
} plcrash_async_cfe_entry_t;

plcrash_error_t plcrash_async_cfe_reader_init (plcrash_async_cfe_reader_t *reader, plcrash_async_mobject_t *mobj, cpu_type_t cputype);

plcrash_error_t plcrash_async_cfe_reader_find_pc (plcrash_async_cfe_reader_t *reader, pl_vm_address_t pc, pl_vm_address_t *function_base, uint32_t *encoding);

void plcrash_async_cfe_reader_free (plcrash_async_cfe_reader_t *reader);


plcrash_error_t plcrash_async_cfe_entry_init (plcrash_async_cfe_entry_t *entry, cpu_type_t cpu_type, uint32_t encoding);

plcrash_async_cfe_entry_type_t plcrash_async_cfe_entry_type (plcrash_async_cfe_entry_t *entry);
intptr_t plcrash_async_cfe_entry_stack_offset (plcrash_async_cfe_entry_t *entry);
uint32_t plcrash_async_cfe_entry_stack_adjustment (plcrash_async_cfe_entry_t *entry);
plcrash_regnum_t plcrash_async_cfe_entry_return_address_register (plcrash_async_cfe_entry_t *entry);
uint32_t plcrash_async_cfe_entry_register_count (plcrash_async_cfe_entry_t *entry);
void plcrash_async_cfe_entry_register_list (plcrash_async_cfe_entry_t *entry, plcrash_regnum_t register_list[]);

plcrash_error_t plcrash_async_cfe_entry_apply (task_t task,
                                               pl_vm_address_t function_address,
                                               const plcrash_async_thread_state_t *thread_state,
                                               plcrash_async_cfe_entry_t *entry,
                                               plcrash_async_thread_state_t *new_thread_state);

void plcrash_async_cfe_entry_free (plcrash_async_cfe_entry_t *entry);

uint32_t plcrash_async_cfe_register_encode (const uint32_t registers[], uint32_t count);
plcrash_error_t plcrash_async_cfe_register_decode (uint32_t permutation, uint32_t count, uint32_t registers[]);

/*
 * @} plcrash_async_cfe
 */

#endif /* PLCRASH_FEATURE_UNWIND_COMPACT */

#endif /* PLCRASH_ASYNC_COMPACT_UNWIND_ENCODING_H */
