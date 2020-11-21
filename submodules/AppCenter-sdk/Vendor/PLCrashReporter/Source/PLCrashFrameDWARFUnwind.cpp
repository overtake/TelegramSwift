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


#include "PLCrashFrameDWARFUnwind.h"

#include "PLCrashAsyncMachOImage.h"

#include "PLCrashAsyncDwarfEncoding.hpp"
#include "PLCrashAsyncDwarfCFAState.hpp"

#include "PLCrashFeatureConfig.h"

#include <inttypes.h>

#include <limits>

#if PLCRASH_FEATURE_UNWIND_DWARF

using namespace plcrash::async;

/**
 * @internal
 *
 * Attempt to fetch next frame using compact frame unwinding data from @a image.
 *
 * @param task The task containing the target frame stack.
 * @param pc The current frame's PC value.
 * @param image The Mach-O image for the current stack frame.
 * @param current_frame The current stack frame.
 * @param previous_frame The previous stack frame, or NULL if this is the first frame.
 * @param next_frame The new frame to be initialized.
 *
 * @tparam machine_ptr The native machine pointer type for the target data.
 * @tparam machine_ptr_s The native machine signed pointer type for the target data.
 *
 * @return Returns PLFRAME_ESUCCESS on success, PLFRAME_ENOFRAME is no additional frames are available, or a standard plframe_error_t code if an error occurs.
 */
template<typename machine_ptr, typename machine_ptr_s>
static plframe_error_t plframe_cursor_read_dwarf_unwind_int (task_t task,
                                                             machine_ptr pc,
                                                             plcrash_async_macho_t *image,
                                                             const plframe_stackframe_t *current_frame,
                                                             const plframe_stackframe_t *previous_frame,
                                                             plframe_stackframe_t *next_frame)
{
    gnu_ehptr_reader<machine_ptr> ptr_state(image->byteorder);

    /* Mapped DWARF sections; only one of eh_frame/debug_frame will be mapped */
    plcrash_async_mobject_t eh_frame;
    plcrash_async_mobject_t debug_frame;
    plcrash_async_mobject_t *dwarf_section = NULL;
    bool is_debug_frame = false;
    
    /* Reader state */
    dwarf_frame_reader reader;

    plcrash_async_dwarf_fde_info_t fde_info;
    bool did_init_fde = false;
    
    plcrash_async_dwarf_cie_info_t cie_info;
    bool did_init_cie = false;
    
    /* CFA evaluation stack */
    plcrash::async::dwarf_cfa_state<machine_ptr, machine_ptr_s> cfa_state;
    
    plframe_error_t result;
    plcrash_error_t err;
        
    /*
     * Map the eh_frame or debug_frame DWARF sections. Apple doesn't seem to use debug_frame at all;
     * as such, we prefer eh_frame, but allow falling back on debug_frame.
     */
    {
        err = plcrash_async_macho_map_section(image, "__TEXT", "__eh_frame", &eh_frame);
        if (err == PLCRASH_ESUCCESS) {
            dwarf_section = &eh_frame;
        }
        
        if (dwarf_section == NULL) {
            err = plcrash_async_macho_map_section(image, "__DWARF", "__debug_frame", &debug_frame);
            if (err == PLCRASH_ESUCCESS) {
                dwarf_section = &debug_frame;
                is_debug_frame = true;
            }
        }
        
        /* If neither, there's nothing to do */
        if (dwarf_section == NULL) {
            /* The lack of debug_frame/eh_frame is not an error, but we can't proceed. */
            result = PLFRAME_ENOFRAME;
            goto cleanup;
        }
    }
    
    /* Initialize the reader. */
    if ((err = reader.init(dwarf_section, image->byteorder, image->m64, is_debug_frame)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Could not initialize a %s DWARF parser for the current frame pc 0x%" PRIx64 " in %s: %d", (is_debug_frame ? "debug_frame" : "eh_frame"), (uint64_t) pc, PLCF_DEBUG_IMAGE_NAME(image), err);
        result = PLFRAME_EINVAL;
        goto cleanup;
    }
    
    /* Find the FDE (if any) */
    {
        err = reader.find_fde(0x0 /* offset hint */, (pl_vm_address_t) pc, &fde_info);
        if (err != PLCRASH_ESUCCESS) {
            if (err != PLCRASH_ENOTFOUND)
                PLCF_DEBUG("Failed to find FDE the current frame pc 0x%" PRIx64 " in %s: %d", (uint64_t) pc, PLCF_DEBUG_IMAGE_NAME(image), err);
            result = PLFRAME_ENOTSUP;
            goto cleanup;
        }
        did_init_fde = true;
    }
    
    /* Initialize pointer state */
    {
        // TODO - configure the pointer state */
    }
    
    /* Parse CIE info */
    {
        err = plcrash_async_dwarf_cie_info_init(&cie_info, dwarf_section, image->byteorder, &ptr_state, plcrash_async_mobject_base_address(dwarf_section) + fde_info.cie_offset);
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("Failed to parse CIE at offset of 0x%" PRIx64 ": %d", (uint64_t) fde_info.cie_offset, err);
            result = PLFRAME_ENOTSUP;
            
            plcrash_async_dwarf_fde_info_free(&fde_info);
            goto cleanup;
        }
        did_init_cie = true;
    }
    
    /* Evaluate the CFA instruction opcodes */
    {
        /* Assert that pc_start won't overflow machine_ptr. This could only occur if we were to use a 64-bit FDE parser with 32-bit CFA evaluation
         * TODO: The FDE pc_start value should probably by typed for the target architecture. */
        PLCF_ASSERT(fde_info.pc_start < std::numeric_limits<machine_ptr>::max());

        /* Initial instructions */
        err = cfa_state.eval_program(dwarf_section, pc, (uint32_t)fde_info.pc_start, &cie_info, &ptr_state, image->byteorder, plcrash_async_mobject_base_address(dwarf_section), cie_info.initial_instructions_offset, cie_info.initial_instructions_length);
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("Failed to evaluate CFA at offset of 0x%" PRIx64 ": %d", (uint64_t) fde_info.instructions_offset, err);
            result = PLFRAME_ENOTSUP;
            goto cleanup;
        }
        
        /*  FDE instructions */
        err = cfa_state.eval_program(dwarf_section, pc, (uint32_t)fde_info.pc_start, &cie_info, &ptr_state, image->byteorder, plcrash_async_mobject_base_address(dwarf_section), fde_info.instructions_offset, fde_info.instructions_length);
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("Failed to evaluate CFA at offset of 0x%" PRIx64 ": %d", (uint64_t) fde_info.instructions_offset, err);
            result = PLFRAME_ENOTSUP;
            goto cleanup;
        }
    }
    
    /* Apply the frame delta -- this may fail. */
    if ((err = cfa_state.apply_state(task, &cie_info, &current_frame->thread_state, image->byteorder, &next_frame->thread_state)) == PLCRASH_ESUCCESS) {
        result = PLFRAME_ESUCCESS;
    } else {
        PLCF_DEBUG("Failed to apply CFA state for PC 0x%" PRIx64 ": %d", (uint64_t) pc, err);
        result = PLFRAME_ENOFRAME;
    }
    
    // Fall-through
    
cleanup:
    if (dwarf_section != NULL)
        plcrash_async_mobject_free(dwarf_section);
    
    if (did_init_cie)
        plcrash_async_dwarf_cie_info_free(&cie_info);
    
    if (did_init_fde)
        plcrash_async_dwarf_fde_info_free(&fde_info);
    
    return result;
}

/**
 * Attempt to fetch next frame using compact frame unwinding data from @a image_list.
 *
 * @param task The task containing the target frame stack.
 * @param image_list The list of images loaded in the target @a task.
 * @param current_frame The current stack frame.
 * @param previous_frame The previous stack frame, or NULL if this is the first frame.
 * @param next_frame The new frame to be initialized.
 *
 * @return Returns PLFRAME_ESUCCESS on success, PLFRAME_ENOFRAME is no additional frames are available, or a standard plframe_error_t code if an error occurs.
 */
plframe_error_t plframe_cursor_read_dwarf_unwind (task_t task,
                                                  plcrash_async_image_list_t *image_list,
                                                  const plframe_stackframe_t *current_frame,
                                                  const plframe_stackframe_t *previous_frame,
                                                  plframe_stackframe_t *next_frame)
{
    plframe_error_t ferr;

    /* Fetch the IP. It should always be available */
    if (!plcrash_async_thread_state_has_reg(&current_frame->thread_state, PLCRASH_REG_IP)) {
        PLCF_DEBUG("Frame is missing a valid IP register, skipping compact unwind encoding");
        return PLFRAME_EBADFRAME;
    }
    plcrash_greg_t pc = plcrash_async_thread_state_get_reg(&current_frame->thread_state, PLCRASH_REG_IP);
    if (pc == 0) {
        return PLFRAME_ENOTSUP;
    }

    /*
     * Mark the list as being read; this prevents any deallocation of our borrowed reference to a plcrash_async_image_t,
     * and must be balanced by a call (in our cleanup section below) to mark reading as completed.
     */
    plcrash_async_image_list_set_reading(image_list, true);
    
    /* Find the corresponding image */
    plcrash_async_image_t *image = plcrash_async_image_containing_address(image_list, (pl_vm_address_t) pc);
    if (image == NULL) {
        PLCF_DEBUG("Could not find a loaded image for the current frame pc: 0x%" PRIx64, (uint64_t) pc);
        plcrash_async_image_list_set_reading(image_list, false);
        return PLFRAME_ENOTSUP;
    }
    
    /* Perform the actual read */
    if (image->macho_image.m64) {
        /* Could only happen due to programmer error; eg, an image that doesn't actually match our thread state */
        PLCF_ASSERT(pc <= UINT64_MAX);

        ferr = plframe_cursor_read_dwarf_unwind_int<uint64_t, int64_t>(task, pc, &image->macho_image, current_frame, previous_frame, next_frame);
    } else {
        /* Could only happen due to programmer error; eg, an image that doesn't actually match our thread state */
        PLCF_ASSERT(pc <= UINT32_MAX);

        ferr = plframe_cursor_read_dwarf_unwind_int<uint32_t, int32_t>(task, (uint32_t)pc, &image->macho_image, current_frame, previous_frame, next_frame);
    }
    
    plcrash_async_image_list_set_reading(image_list, false);
    return ferr;
}

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
