/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2011-2013 Plausible Labs Cooperative, Inc.
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

#include "PLCrashAsyncMachOImage.h"

#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <assert.h>

#include <mach-o/fat.h>

/* Size of the field in the structure. struct.h is not available here */
#ifndef fldsiz
#define fldsiz(name, field) \
    (sizeof(((struct name *)0)->field))
#endif

/**
 * @internal
 * @ingroup plcrash_async
 * @defgroup plcrash_async_image Binary Image Parsing
 *
 * Implements async-safe Mach-O binary parsing, for use at crash time when extracting binary information
 * from the crashed process.
 * @{
 */

/**
 * Initialize a new Mach-O binary image parser.
 *
 * @param image The image structure to be initialized.
 * @param name The file name or path for the Mach-O image.
 * @param header The task-local address of the image's Mach-O header.
 *
 * @return PLCRASH_ESUCCESS on success. PLCRASH_EINVAL will be returned in the Mach-O file can not be parsed,
 * or PLCRASH_EINTERNAL if an error occurs reading from the target task.
 *
 * @warning This method is not async safe.
 */
plcrash_error_t plcrash_nasync_macho_init (plcrash_async_macho_t *image, mach_port_t task, const char *name, pl_vm_address_t header) {
    plcrash_error_t ret;

    /* Defaults checked in the  error cleanup handler */
    bool mobj_initialized = false;
    bool task_initialized = false;
    image->name = NULL;

    /* Basic initialization */
    image->task = task;
    image->header_addr = header;
    image->name = strdup(name);

    mach_port_mod_refs(mach_task_self(), image->task, MACH_PORT_RIGHT_SEND, 1);
    task_initialized = true;

    /* Read in the Mach-O header */
    if ((ret = plcrash_async_task_memcpy(image->task, image->header_addr, 0, &image->header, sizeof(image->header))) != PLCRASH_ESUCCESS) {
        /* NOTE: The image struct must be fully initialized before returning here, as otherwise our _free() function
         * will crash */
        PLCF_DEBUG("Failed to read Mach-O header from 0x%" PRIx64 " for image %s, ret=%d", (uint64_t) image->header_addr, name, ret);
        ret = PLCRASH_EINTERNAL;
        goto error;
    }
    
    /* Set the default byte order*/
    image->byteorder = &plcrash_async_byteorder_direct;

    /* Parse the Mach-O magic identifier. */
    switch (image->header.magic) {
        case MH_CIGAM:
            // Enable byte swapping
            image->byteorder = &plcrash_async_byteorder_swapped;
            // Fall-through

        case MH_MAGIC:
            image->m64 = false;
            break;            
            
        case MH_CIGAM_64:
            // Enable byte swapping
            image->byteorder = &plcrash_async_byteorder_swapped;
            // Fall-through
            
        case MH_MAGIC_64:
            image->m64 = true;
            break;

        case FAT_CIGAM:
        case FAT_MAGIC:
            PLCF_DEBUG("%s called with an unsupported universal Mach-O archive in: %s", __func__, PLCF_DEBUG_IMAGE_NAME(image));
            return PLCRASH_EINVAL;
            break;

        default:
            PLCF_DEBUG("Unknown Mach-O magic: 0x%" PRIx32 " in: %s", image->header.magic, PLCF_DEBUG_IMAGE_NAME(image));
            return PLCRASH_EINVAL;
    }

    /* Save the header size */
    if (image->m64) {
        image->header_size = sizeof(struct mach_header_64);
    } else {
        image->header_size = sizeof(struct mach_header);
    }
    
    /* Map in header + load commands */
    pl_vm_size_t cmd_len = image->byteorder->swap32(image->header.sizeofcmds);
    pl_vm_size_t cmd_offset = image->header_addr + image->header_size;
    image->ncmds = image->byteorder->swap32(image->header.ncmds);

    ret = plcrash_async_mobject_init(&image->load_cmds, image->task, cmd_offset, cmd_len, true);
    if (ret != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Failed to map Mach-O load commands in image %s", PLCF_DEBUG_IMAGE_NAME(image));
        goto error;
    } else {
        mobj_initialized = true;
    }

    /* Now that the image has been sufficiently initialized, determine the __TEXT segment size */
    void *cmdptr = NULL;
    image->text_size = 0x0;
    bool found_text_seg = false;
    while ((cmdptr = plcrash_async_macho_next_command_type(image, cmdptr, image->m64 ? LC_SEGMENT_64 : LC_SEGMENT)) != 0) {
        if (image->m64) {
            struct segment_command_64 *segment = cmdptr;
            if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t) segment, 0, sizeof(*segment))) {
                PLCF_DEBUG("LC_SEGMENT command was too short");
                ret = PLCRASH_EINVAL;
                goto error;
            }
            
            if (plcrash_async_strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) != 0)
                continue;

            image->text_size = (pl_vm_size_t) image->byteorder->swap64(segment->vmsize);
            image->text_vmaddr = (pl_vm_address_t) image->byteorder->swap64(segment->vmaddr);
            found_text_seg = true;
            break;
        } else {
            struct segment_command *segment = cmdptr;
            if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t) segment, 0, sizeof(*segment))) {
                PLCF_DEBUG("LC_SEGMENT command was too short");
                ret = PLCRASH_EINVAL;
                goto error;
            }
            
            if (plcrash_async_strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) != 0)
                continue;
            
            image->text_size = image->byteorder->swap32(segment->vmsize);
            image->text_vmaddr = image->byteorder->swap32(segment->vmaddr);
            found_text_seg = true;
            break;
        }
    }

    if (!found_text_seg) {
        PLCF_DEBUG("Could not find __TEXT segment!");
        ret = PLCRASH_EINVAL;
        goto error;
    }

    /* Compute the vmaddr slide */
    if (image->text_vmaddr < header) {
        image->vmaddr_slide = header - image->text_vmaddr;
    } else if (image->text_vmaddr > header) {
        image->vmaddr_slide = -((pl_vm_off_t) (image->text_vmaddr - header));
    } else {
        image->vmaddr_slide = 0;
    }

    return PLCRASH_ESUCCESS;
    
error:
    if (mobj_initialized)
        plcrash_async_mobject_free(&image->load_cmds);
    
    if (image->name != NULL)
        free(image->name);
    
    if (task_initialized)
        mach_port_mod_refs(mach_task_self(), image->task, MACH_PORT_RIGHT_SEND, -1);

    return ret;
}

/**
 * Return a borrowed reference to the byte order functions to use when parsing data from
 * @a image.
 *
 * @param image The image from which the byte order functions should be returned.
 */
const plcrash_async_byteorder_t *plcrash_async_macho_byteorder (plcrash_async_macho_t *image) {
    return image->byteorder;
}

/**
 * Return a borrowed reference to the image's Mach-O header. For our purposes, the 32-bit and 64-bit headers
 * are identical. Note that the header values may require byte-swapping for the local process'
 * use (@sa plcrash_async_macho_byteorder).
 *
 * @param image The image from which the mach header should be returned.
 */
const struct mach_header *plcrash_async_macho_header (plcrash_async_macho_t *image) {
    return &image->header;
}

/**
 * Return the total size, in bytes, of the image's in-memory Mach-O header. This may differ from the header
 * field returned by plcrash_async_macho_header(), as the returned value does not include the full mach_header_64
 * extensions to the mach_header.
 *
 * @param image The image from which the mach header should be returned.
 */
pl_vm_size_t plcrash_async_macho_header_size (plcrash_async_macho_t *image) {
    return image->header_size;
}

/**
 * Return true if @a address is mapped within @a image's __TEXT segment, false otherwise.
 *
 * @param image The Mach-O image.
 * @param address The address to be searched for.
 */
bool plcrash_async_macho_contains_address (plcrash_async_macho_t *image, pl_vm_address_t address) {
    if (address >= image->header_addr && address < image->header_addr + image->text_size)
        return true;
    
    return false;
}

/**
 * Return the Mach CPU type of @a image.
 *
 * @param image The image from which the CPU type should be returned.
 */
cpu_type_t plcrash_async_macho_cpu_type (plcrash_async_macho_t *image) {
    return image->byteorder->swap32(image->header.cputype);
}

/**
 * Return the Mach CPU subtype of @a image.
 *
 * @param image The image from which the CPU subtype should be returned.
 */
cpu_subtype_t plcrash_async_macho_cpu_subtype (plcrash_async_macho_t *image) {
    return image->byteorder->swap32(image->header.cpusubtype);
}


/**
 * Iterate over the available Mach-O LC_CMD entries.
 *
 * @param image The image to iterate
 * @param previous The previously returned LC_CMD address value, or 0 to iterate from the first LC_CMD.
 * @return Returns the address of the next load_command on success, or NULL on failure.
 *
 * @note A returned command is gauranteed to be readable, and fully within mapped address space. If the command
 * command can not be verified to have available MAX(sizeof(struct load_command), cmd->cmdsize) bytes, NULL will be
 * returned.
 */
void *plcrash_async_macho_next_command (plcrash_async_macho_t *image, void *previous) {
    struct load_command *cmd;

    /* On the first iteration, determine the LC_CMD offset from the Mach-O header. */
    if (previous == NULL) {
        /* Sanity check */
        if (image->byteorder->swap32(image->header.sizeofcmds) < sizeof(struct load_command)) {
            PLCF_DEBUG("Mach-O sizeofcmds is less than sizeof(struct load_command) in %s", PLCF_DEBUG_IMAGE_NAME(image));
            return NULL;
        }

        return plcrash_async_mobject_remap_address(&image->load_cmds, image->header_addr, image->header_size, sizeof(struct load_command));
    }

    /* We need the size from the previous load command; first, verify the pointer. */
    cmd = previous;
    if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t) cmd, 0, sizeof(*cmd))) {
        PLCF_DEBUG("Failed to map LC_CMD at address %p in: %s", cmd, PLCF_DEBUG_IMAGE_NAME(image));
        return NULL;
    }

    /* Advance to the next command */
    uint32_t cmdsize = image->byteorder->swap32(cmd->cmdsize);
    
    /* Sanity check the cmdsize */
    if (cmdsize < sizeof(struct load_command)) {
        /* This was observed in iOS 9 betas, in which a zero-length LC_CMD triggered an infinite loop. This is absolutely invalid, and
         * there's nothing we can do but give up trying to iterate over the image. */
        PLCF_DEBUG("Found invalid 0-length cmdsize in LC_CMD at address %p in: %s (terminating further iteration)", cmd, PLCF_DEBUG_IMAGE_NAME(image));
        return NULL;
    }
    
    /* Verify that the address won't overflow */
    if (UINTPTR_MAX - cmdsize < (uintptr_t) previous) {
        PLCF_DEBUG("Found invalid cmdsize in LC_CMD at address %p in: %s", cmd, PLCF_DEBUG_IMAGE_NAME(image));
        return NULL;
    }
    
    void *next = ((uint8_t *)previous) + cmdsize;

    /* Avoid walking off the end of the cmd buffer */
    if ((uintptr_t)next >= image->load_cmds.address + image->load_cmds.length)
        return NULL;

    /* Verify that it holds at least load_command */
    if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t) next, 0, sizeof(struct load_command))) {
        PLCF_DEBUG("Failed to map LC_CMD at address %p in: %s", cmd, PLCF_DEBUG_IMAGE_NAME(image));
        return NULL;
    }

    /* Verify the actual size. */
    cmd = next;
    if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t) next, 0, image->byteorder->swap32(cmd->cmdsize))) {
        PLCF_DEBUG("Failed to map LC_CMD at address %p in: %s", cmd, PLCF_DEBUG_IMAGE_NAME(image));
        return NULL;
    }

    return next;
}

/**
 * Iterate over the available Mach-O LC_CMD entries.
 *
 * @param image The image to iterate
 * @param previous The previously returned LC_CMD address value, or 0 to iterate from the first LC_CMD.
 * @param expectedCommand The LC_* command type to be returned. Only commands matching this type will be returned by the iterator.
 * @return Returns the address of the next load_command on success, or 0 on failure. 
 *
 * @note A returned command is gauranteed to be readable, and fully within mapped address space. If the command
 * command can not be verified to have available MAX(sizeof(struct load_command), cmd->cmdsize) bytes, NULL will be
 * returned.
 */
void *plcrash_async_macho_next_command_type (plcrash_async_macho_t *image, void *previous, uint32_t expectedCommand) {
    struct load_command *cmd = previous;

    /* Iterate commands until we either find a match, or reach the end */
    while ((cmd = plcrash_async_macho_next_command(image, cmd)) != NULL) {
        /* Return a match */
        if (image->byteorder->swap32(cmd->cmd) == expectedCommand) {
            return cmd;
        }
    }

    /* No match found */
    return NULL;
}

/**
 * Find the first LC_CMD matching the given @a cmd type.
 *
 * @param image The image to search.
 * @param expectedCommand The LC_CMD type to find.
 *
 * @return Returns the address of the matching load_command on success, or 0 on failure.
 *
 * @note A returned command is gauranteed to be readable, and fully within mapped address space. If the command
 * command can not be verified to have available MAX(sizeof(struct load_command), cmd->cmdsize) bytes, NULL will be
 * returned.
 */
void *plcrash_async_macho_find_command (plcrash_async_macho_t *image, uint32_t expectedCommand) {
    struct load_command *cmd = NULL;

    /* Iterate commands until we either find a match, or reach the end */
    while ((cmd = plcrash_async_macho_next_command(image, cmd)) != NULL) {
        /* Read the load command type */
        if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t) cmd, 0, sizeof(*cmd))) {
            PLCF_DEBUG("Failed to map LC_CMD at address %p in: %s", cmd, PLCF_DEBUG_IMAGE_NAME(image));
            return NULL;
        }

        /* Return a match */
        if (image->byteorder->swap32(cmd->cmd) == expectedCommand) {
            return cmd;
        }
    }
    
    /* No match found */
    return NULL;
}

/**
 * Find a named segment.
 *
 * @param image The image to search for @a segname.
 * @param segname The name of the segment to search for.
 *
 * @return Returns a mapped pointer to the segment on success, or NULL on failure.
 */
void *plcrash_async_macho_find_segment_cmd (plcrash_async_macho_t *image, const char *segname) {
    void *seg = NULL;

    while ((seg = plcrash_async_macho_next_command_type(image, seg, image->m64 ? LC_SEGMENT_64 : LC_SEGMENT)) != 0) {

        /* Read the load command */
        if (image->m64) {
            struct segment_command_64 *cmd_64 = seg;
            if (plcrash_async_strncmp(segname, cmd_64->segname, sizeof(cmd_64->segname)) == 0)
                return seg;
        } else {
            struct segment_command *cmd_32 = seg;
            if (plcrash_async_strncmp(segname, cmd_32->segname, sizeof(cmd_32->segname)) == 0)
                return seg;
        }
    }

    return NULL;
}

/**
 * Find and map a named segment, initializing @a mobj. It is the caller's responsibility to dealloc @a mobj after
 * a successful initialization
 *
 * @param image The image to search for @a segname.
 * @param segname The name of the segment to be mapped.
 * @param seg The segment data to be initialized. It is the caller's responsibility to dealloc @a seg after
 * a successful initialization.
 *
 * @warning Due to bugs in the update_dyld_shared_cache(1), the segment vmsize defined in the Mach-O load commands may
 * be invalid, and the declared size may be unmappable. As such, it is possible that this function will return a mapping
 * that is less than the total requested size. All accesses to this mapping should be done (as is already the norm)
 * through range-checked pointer validation (eg, plcrash_async_mobject_remap_address()). This bug appears to be caused
 * by a bug in computing the correct vmsize when update_dyld_shared_cache(1) generates the single shared LINKEDIT
 * segment, and has been reported to Apple as rdar://13707406.
 *
 * @return Returns PLCRASH_ESUCCESS on success, or an error result on failure.
 */
plcrash_error_t plcrash_async_macho_map_segment (plcrash_async_macho_t *image, const char *segname, pl_async_macho_mapped_segment_t *seg) {
    struct segment_command *cmd_32;
    struct segment_command_64 *cmd_64;
    
    void *segment =  plcrash_async_macho_find_segment_cmd(image, segname);
    if (segment == NULL)
        return PLCRASH_ENOTFOUND;

    cmd_32 = segment;
    cmd_64 = segment;

    /* Calculate the in-memory address and size */
    pl_vm_address_t segaddr;
    pl_vm_size_t segsize;
    if (image->m64) {
        segaddr = (pl_vm_address_t) image->byteorder->swap64(cmd_64->vmaddr) + image->vmaddr_slide;
        segsize = (pl_vm_size_t) image->byteorder->swap64(cmd_64->vmsize);

        seg->fileoff = image->byteorder->swap64(cmd_64->fileoff);
        seg->filesize = image->byteorder->swap64(cmd_64->filesize);
    } else {
        segaddr = image->byteorder->swap32(cmd_32->vmaddr) + image->vmaddr_slide;
        segsize = image->byteorder->swap32(cmd_32->vmsize);
        
        seg->fileoff = image->byteorder->swap32(cmd_32->fileoff);
        seg->filesize = image->byteorder->swap32(cmd_32->filesize);
    }

    /* Perform and return the mapping (permitting shorter mappings, as documented above). */
    return plcrash_async_mobject_init(&seg->mobj, image->task, segaddr, segsize, false);
}

static uint32_t plcrash_async_macho_read_sections_count (plcrash_async_macho_t *image, uintptr_t *cursor) {
    uint32_t nsects;
    if (image->m64) {
        struct segment_command_64 *cmd_64 = (void *)*cursor;
        nsects = image->byteorder->swap32(cmd_64->nsects);
        *cursor += sizeof(*cmd_64);
    } else {
        struct segment_command *cmd_32 = (void *)*cursor;
        nsects = image->byteorder->swap32(cmd_32->nsects);
        *cursor += sizeof(*cmd_32);
    }
    return nsects;
}

static bool plcrash_async_macho_read_section (plcrash_async_macho_t *image, uintptr_t *cursor, const char **sectname, pl_vm_address_t *sectaddr, pl_vm_size_t *sectsize) {
    if (image->m64) {
        struct section_64 *sect_64 = (void *)*cursor;
        if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t)sect_64, 0, sizeof(*sect_64))) {
            return false;
        }
        /* Calculate the in-memory address and size. */
        *sectname = sect_64->sectname;
        *sectaddr = (pl_vm_address_t) image->byteorder->swap64(sect_64->addr) + image->vmaddr_slide;
        *sectsize = (pl_vm_size_t) image->byteorder->swap64(sect_64->size);
        *cursor += sizeof(*sect_64);
    } else {
        struct section *sect_32 = (void *)*cursor;
        if (!plcrash_async_mobject_verify_local_pointer(&image->load_cmds, (uintptr_t)sect_32, 0, sizeof(*sect_32))) {
            return false;
        }
        /* Calculate the in-memory address and size. */
        *sectname = sect_32->sectname;
        *sectaddr = image->byteorder->swap32(sect_32->addr) + image->vmaddr_slide;
        *sectsize = image->byteorder->swap32(sect_32->size);
        *cursor += sizeof(*sect_32);
    }
    return true;
}

/**
 * Find and map a named section within a named segment, initializing @a mobj.
 * It is the caller's responsibility to dealloc @a mobj after a successful
 * initialization
 *
 * @param image The image to search for @a segname.
 * @param segname The name of the segment to search.
 * @param sectname The name of the section to map.
 * @param mobj The mobject to be initialized with a mapping of the section's data. It is the caller's responsibility to dealloc @a mobj after
 * a successful initialization.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_ENOTFOUND if the section is not found, or an error result on failure.
 */
plcrash_error_t plcrash_async_macho_map_section (plcrash_async_macho_t *image, const char *segname, const char *sectname, plcrash_async_mobject_t *mobj) {
    void *segment =  plcrash_async_macho_find_segment_cmd(image, segname);
    if (segment == NULL) {
        return PLCRASH_ENOTFOUND;
    }
    uintptr_t cursor = (uintptr_t) segment;
    uint32_t nsects = plcrash_async_macho_read_sections_count(image, &cursor);
    for (uint32_t i = 0; i < nsects; i++) {
        const char *image_sectname;
        pl_vm_address_t sectaddr;
        pl_vm_size_t sectsize;
        if (!plcrash_async_macho_read_section(image, &cursor, &image_sectname, &sectaddr, &sectsize)) {
            PLCF_DEBUG("Section table entry outside of expected range; searching for (%s,%s)", segname, sectname);
            return PLCRASH_EINVAL;
        }
        if (plcrash_async_strncmp(sectname, image_sectname, fldsiz(section_64, sectname)) == 0) {
            /* Perform and return the mapping */
            // PLCF_DEBUG("%s (%s,%.*s): 0x%lx - 0x%lx", PLCF_DEBUG_IMAGE_NAME(image), segname, (int)fldsiz(section_64, sectname), image_sectname, sectaddr, sectaddr + sectsize);
            return plcrash_async_mobject_init(mobj, image->task, sectaddr, sectsize, true);
        }
    }
    
    return PLCRASH_ENOTFOUND;
}

/**
 * @internal
 * Common wrapper of nlist/nlist_64. We verify that this union is valid for our purposes in pl_async_macho_find_symtab_symbol().
 */
typedef union {
    struct nlist_64 n64;
    struct nlist n32;
} pl_nlist_common;

/**
 * Attempt to locate a symbol address for @a symbol name within @a image.
 *
 * @param image The Mach-O image to search for @a symbol
 * @param symbol The symbol name to search for.
 * @param pc On success, will be set to the address of the symbol. The address will be normalized, and
 * will include any required bit flags -- such as the ARM thumb high-order bit -- which are not included in the symbol
 * table by default.
 *
 * @return Returns PLCRASH_ESUCCESS if the symbol is found, or PLCRASH_ENOTFOUND if not found. If the symbol is not
 * found, the contents of @a pc are undefined.
 *
 * @todo Migrate this API to use the plcrash_async_macho_symtab_reader types when returning symbol data.
 */
plcrash_error_t plcrash_async_macho_find_symbol_by_name (plcrash_async_macho_t *image, const char *symbol, pl_vm_address_t *pc) {
    /* Now walk the Mach-O table ourselves */
    plcrash_async_macho_symtab_reader_t reader;
    plcrash_error_t ret;

    /* Initialize the reader */
    ret = plcrash_async_macho_symtab_reader_init(&reader, image);
    if (ret != PLCRASH_ESUCCESS)
        return ret;

    /* Walk all symbol entries and return on the first name match */
    const char *sym = NULL;
    plcrash_async_macho_symtab_entry_t entry;
    for (uint32_t i = 0; i < reader.nsyms; i++) {
        entry = plcrash_async_macho_symtab_reader_read(&reader, reader.symtab, i);

        /* Symbol must be within a section, and must not be a debugging entry. */
        if ((entry.n_type & N_TYPE) != N_SECT || ((entry.n_type & N_STAB) != 0))
            continue;

        /* Check the name */
        sym = plcrash_async_macho_symtab_reader_symbol_name(&reader, entry.n_strx);
        if (sym != NULL && plcrash_async_strcmp(sym, symbol) == 0) {
            plcrash_async_macho_symtab_reader_free(&reader);

            *pc = entry.normalized_value + image->vmaddr_slide;
            return PLCRASH_ESUCCESS;
        }
    }

    plcrash_async_macho_symtab_reader_free(&reader);
    return PLCRASH_ENOTFOUND;
}

/**
 * Initialize a new symbol table reader, mapping the LINKEDIT segment from @a image into the current process.
 *
 * @param reader The reader to be initialized.
 * @param image The image from which the symbol table will be mapped.
 *
 * @return On success, returns PLCRASH_ESUCCESS. On failure, one of the plcrash_error_t error values will be returned, and no
 * mapping will be performed.
 */
plcrash_error_t plcrash_async_macho_symtab_reader_init (plcrash_async_macho_symtab_reader_t *reader, plcrash_async_macho_t *image) {
    plcrash_error_t retval;

    /* Fetch the symtab commands, if available. */
    struct symtab_command *symtab_cmd = plcrash_async_macho_find_command(image, LC_SYMTAB);
    struct dysymtab_command *dysymtab_cmd = plcrash_async_macho_find_command(image, LC_DYSYMTAB);

    /* The symtab command is required */
    if (symtab_cmd == NULL) {
        PLCF_DEBUG("could not find LC_SYMTAB load command");
        return PLCRASH_ENOTFOUND;
    }
    
    /* Map in the __LINKEDIT segment, which includes the symbol and string tables */
    plcrash_error_t err = plcrash_async_macho_map_segment(image, "__LINKEDIT", &reader->linkedit);
    if (err != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("plcrash_async_mobject_init() failure: %d in %s", err, PLCF_DEBUG_IMAGE_NAME(image));
        return PLCRASH_EINTERNAL;
    }
    
    /* Determine the string and symbol table sizes. */
    uint32_t nsyms = image->byteorder->swap32(symtab_cmd->nsyms);
    size_t nlist_struct_size = image->m64 ? sizeof(struct nlist_64) : sizeof(struct nlist);
    size_t nlist_table_size = nsyms * nlist_struct_size;
    
    size_t string_size = image->byteorder->swap32(symtab_cmd->strsize);
    
    /* Fetch pointers to the symbol and string tables, and verify their size values */
    void *nlist_table;
    char *string_table;
    
    nlist_table = plcrash_async_mobject_remap_address(&reader->linkedit.mobj, reader->linkedit.mobj.task_address, (pl_vm_off_t)(image->byteorder->swap32(symtab_cmd->symoff) - reader->linkedit.fileoff), nlist_table_size);
    if (nlist_table == NULL) {
        PLCF_DEBUG("plcrash_async_mobject_remap_address(mobj, %" PRIx64 ", %" PRIx64") returned NULL mapping __LINKEDIT.symoff in %s",
                   (uint64_t) reader->linkedit.mobj.address + image->byteorder->swap32(symtab_cmd->symoff), (uint64_t) nlist_table_size, PLCF_DEBUG_IMAGE_NAME(image));
        retval = PLCRASH_EINTERNAL;
        goto cleanup;
    }
    
    string_table = plcrash_async_mobject_remap_address(&reader->linkedit.mobj, reader->linkedit.mobj.task_address, (pl_vm_off_t)(image->byteorder->swap32(symtab_cmd->stroff) - reader->linkedit.fileoff), string_size);
    if (string_table == NULL) {
        PLCF_DEBUG("plcrash_async_mobject_remap_address(mobj, %" PRIx64 ", %" PRIx64") returned NULL mapping __LINKEDIT.stroff in %s",
                   (uint64_t) reader->linkedit.mobj.address + image->byteorder->swap32(symtab_cmd->stroff), (uint64_t) string_size, PLCF_DEBUG_IMAGE_NAME(image));
        retval = PLCRASH_EINTERNAL;
        goto cleanup;
    }

    /* Initialize common elements. */
    reader->image = image;
    reader->string_table = string_table;
    reader->string_table_size = string_size;
    reader->symtab = nlist_table;
    reader->nsyms = nsyms;

    /* Initialize the local/global table pointers, if available */
    if (dysymtab_cmd != NULL) {
        /* dysymtab is available; use it to constrain our symbol search to the global and local sections of the symbol table. */
        
        uint32_t idx_syms_global = image->byteorder->swap32(dysymtab_cmd->iextdefsym);
        uint32_t idx_syms_local = image->byteorder->swap32(dysymtab_cmd->ilocalsym);
        
        uint32_t nsyms_global = image->byteorder->swap32(dysymtab_cmd->nextdefsym);
        uint32_t nsyms_local = image->byteorder->swap32(dysymtab_cmd->nlocalsym);
        
        /* Sanity check the symbol offsets to ensure they're within our known-valid ranges */
        if (idx_syms_global + nsyms_global > nsyms || idx_syms_local + nsyms_local > nsyms) {
            PLCF_DEBUG("iextdefsym=%" PRIx32 ", ilocalsym=%" PRIx32 " out of range nsym=%" PRIx32, idx_syms_global+nsyms_global, idx_syms_local+nsyms_local, nsyms);
            retval = PLCRASH_EINVAL;
            goto cleanup;
        }

        /* Initialize reader state */
        reader->nsyms_global = nsyms_global;
        reader->nsyms_local = nsyms_local;

        if (image->m64) {
            struct nlist_64 *n64 = nlist_table;
            reader->symtab_global = (pl_nlist_common *) (n64 + idx_syms_global);
            reader->symtab_local = (pl_nlist_common *) (n64 + idx_syms_local);
        } else {
            struct nlist *n32 = nlist_table;
            reader->symtab_global = (pl_nlist_common *) (n32 + idx_syms_global);
            reader->symtab_local = (pl_nlist_common *) (n32 + idx_syms_local);
        }        
    }

    return PLCRASH_ESUCCESS;
    
cleanup:
    plcrash_async_macho_mapped_segment_free(&reader->linkedit);
    return retval;
}

/**
 * Fetch the entry corresponding to @a index.
 *
 * @param reader The reader from which @a table was mapped.
 * @param symtab The symbol table to read.
 * @param index The index of the entry to return.
 *
 * @warning The implementation implements no bounds checking on @a index, and it is the caller's responsibility to ensure
 * that they do not read an invalid entry.
 */
plcrash_async_macho_symtab_entry_t plcrash_async_macho_symtab_reader_read (plcrash_async_macho_symtab_reader_t *reader, void *symtab, uint32_t index) {
    const plcrash_async_byteorder_t *byteorder = reader->image->byteorder;

    /* nlist_64 and nlist are identical other than the trailing address field, so we use
     * a union to share a common implementation of symbol lookup. The following asserts
     * provide a sanity-check of that assumption, in the case where this code is moved
     * to a new platform ABI. */
    {
#define pl_m_sizeof(type, field) sizeof(((type *)NULL)->field)
        
        PLCF_ASSERT(__offsetof(struct nlist_64, n_type) == __offsetof(struct nlist, n_type));
        PLCF_ASSERT(pl_m_sizeof(struct nlist_64, n_type) == pl_m_sizeof(struct nlist, n_type));
        
        PLCF_ASSERT(__offsetof(struct nlist_64, n_un.n_strx) == __offsetof(struct nlist, n_un.n_strx));
        PLCF_ASSERT(pl_m_sizeof(struct nlist_64, n_un.n_strx) == pl_m_sizeof(struct nlist, n_un.n_strx));
        
        PLCF_ASSERT(__offsetof(struct nlist_64, n_value) == __offsetof(struct nlist, n_value));
        
#undef pl_m_sizeof
    }

#define pl_sym_value(image, nl) (image->m64 ? image->byteorder->swap64((nl)->n64.n_value) : image->byteorder->swap32((nl)->n32.n_value))

    /* Perform 32-bit/64-bit dependent aliased pointer math. */
    pl_nlist_common *symbol;
    if (reader->image->m64) {
        symbol = (pl_nlist_common *) &(((struct nlist_64 *) symtab)[index]);
    } else {
        symbol = (pl_nlist_common *) &(((struct nlist *) symtab)[index]);
    }
    
    plcrash_async_macho_symtab_entry_t entry = {
        .n_strx = byteorder->swap32(symbol->n32.n_un.n_strx),
        .n_type = symbol->n32.n_type,
        .n_sect = symbol->n32.n_sect,
        .n_desc = byteorder->swap16(symbol->n32.n_desc),
        .n_value = (pl_vm_address_t) pl_sym_value(reader->image, symbol)
    };
    
    entry.normalized_value = entry.n_value;
    
    /* Normalize the symbol address. We have to set the low-order bit ourselves for ARM THUMB functions. */
    if (entry.n_desc & N_ARM_THUMB_DEF)
        entry.normalized_value = (entry.n_value|1);
    else
        entry.normalized_value = entry.n_value;
    
#undef pl_sym_value
    
    return entry;
}

/**
 * Given a string table offset for @a reader, returns the pointer to the validated NULL terminated string, or returns
 * NULL if the string does not fall within the reader's mapped string table.
 *
 * @param reader The reader containing a mapped string table.
 * @param n_strx The index within the @a reader string table to a symbol name.
 */
const char *plcrash_async_macho_symtab_reader_symbol_name (plcrash_async_macho_symtab_reader_t *reader, uint32_t n_strx) {
    /* 
     * It's possible, though unlikely, that the n_strx index value is invalid. To handle this,
     * we walk the string until \0 is hit, verifying that it can be found in its entirety within
     *
     * TODO: Evaluate effeciency of per-byte calling of plcrash_async_mobject_verify_local_pointer(). We should
     * probably validate whole pages at a time instead.
     */
    const char *sym_name = reader->string_table + n_strx;
    const char *p = sym_name;
    do {
        if (!plcrash_async_mobject_verify_local_pointer(&reader->linkedit.mobj, (uintptr_t) p, 0, 1)) {
            PLCF_DEBUG("End of mobject reached while walking string\n");
            return NULL;
        }
        p++;
    } while (*p != '\0');

    return sym_name;
}

/**
 * Free all mapped reader resources.
 *
 * @note Unlike most free() functions in this API, this function is async-safe.
 */
void plcrash_async_macho_symtab_reader_free (plcrash_async_macho_symtab_reader_t *reader) {
    plcrash_async_macho_mapped_segment_free(&reader->linkedit);
}

/*
 * Locate a symtab entry for @a slide_pc within @a symbtab. This is performed using best-guess heuristics, and may
 * be incorrect.
 *
 * @param reader The Mach-O symbol table reader to search for @a pc
 * @param slide_pc The PC value within the target process for which symbol information should be found. The VM slide
 * address should have already been applied to this value.
 * @param symtab The symtab to search.
 * @param nsyms The number of nlist entries available via @a symtab.
 * @param found_symbol On success, will be set to the discovered symbol value.
 * @param prev_symbol A reference to the previous best match symbol.
 * @param did_find_symbol On success, will be set to true. This value must be passed to
 * the next call in which @a found_symbol is used.
 *
 * @return Returns true if a symbol was found, false otherwise.
 */
static void plcrash_async_macho_find_best_symbol (plcrash_async_macho_symtab_reader_t *reader,
                                                  pl_vm_address_t slide_pc,
                                                  pl_nlist_common *symtab, uint32_t nsyms,
                                                  plcrash_async_macho_symtab_entry_t *found_symbol,
                                                  plcrash_async_macho_symtab_entry_t *prev_symbol,
                                                  bool *did_find_symbol)
{
    plcrash_async_macho_symtab_entry_t new_entry;
    
    /* Set did_find_symbol to false by default */
    if (prev_symbol == NULL)
        *did_find_symbol = false;

    /* Walk the symbol table. We know that symbols[i] is valid, since we fetched a pointer+len based on the value using
     * plcrash_async_mobject_remap_address() above. */
    for (uint32_t i = 0; i < nsyms; i++) {
        new_entry = plcrash_async_macho_symtab_reader_read(reader, symtab, i);
        
        /* Symbol must be within a section, and must not be a debugging entry. */
        if ((new_entry.n_type & N_TYPE) != N_SECT || ((new_entry.n_type & N_STAB) != 0))
            continue;

        /* Search for the best match. We're looking for the closest symbol occuring before PC. */
        if (new_entry.n_value <= slide_pc && (!*did_find_symbol || prev_symbol->n_value < new_entry.n_value)) {
            *found_symbol = new_entry;

            /* The newly found symbol is now the symbol to be matched against */
            prev_symbol = found_symbol;
            *did_find_symbol = true;
        }
    }
}

/**
 * Attempt to locate a symbol address and name for @a pc within @a image. This is performed using best-guess heuristics, and may
 * be incorrect.
 *
 * @param image The Mach-O image to search for @a pc
 * @param pc The PC value within the target process for which symbol information should be found.
 * @param symbol_cb A callback to be called if the symbol is found.
 * @param context Context to be passed to @a found_symbol.
 *
 * @return Returns PLCRASH_ESUCCESS if the symbol is found. If the symbol is not found, @a found_symbol will not be called.
 *
 * @todo Migrate this API to use the new non-callback based plcrash_async_macho_symtab_reader support for symbol (and symbol name)
 * reading.
 */
plcrash_error_t plcrash_async_macho_find_symbol_by_pc (plcrash_async_macho_t *image, pl_vm_address_t pc, pl_async_macho_found_symbol_cb symbol_cb, void *context) {
    plcrash_error_t retval;
    
    /* Initialize a symbol table reader */
    plcrash_async_macho_symtab_reader_t reader;
    retval = plcrash_async_macho_symtab_reader_init(&reader, image);
    if (retval != PLCRASH_ESUCCESS)
        return retval;

    /* Compute the on-disk PC. */
    pl_vm_address_t slide_pc = pc - image->vmaddr_slide;

    /* Walk the symbol table. */
    plcrash_async_macho_symtab_entry_t found_symbol;
    bool did_find_symbol;

    if (reader.symtab_global != NULL && reader.symtab_local != NULL) {
        /* dysymtab is available; use it to constrain our symbol search to the global and local sections of the symbol table. */
        plcrash_async_macho_find_best_symbol(&reader, slide_pc, reader.symtab_global, reader.nsyms_global, &found_symbol, NULL, &did_find_symbol);
        plcrash_async_macho_find_best_symbol(&reader, slide_pc, reader.symtab_local, reader.nsyms_local, &found_symbol, &found_symbol, &did_find_symbol);
    } else {
        /* If dysymtab is not available, search all symbols */
        plcrash_async_macho_find_best_symbol(&reader, slide_pc, reader.symtab, reader.nsyms, &found_symbol, NULL, &did_find_symbol);
    }

    /* No symbol found. */
    if (!did_find_symbol) {
        retval = PLCRASH_ENOTFOUND;
        goto cleanup;
    }

    /* Symbol found! */
    const char *sym_name = plcrash_async_macho_symtab_reader_symbol_name(&reader, found_symbol.n_strx);
    if (sym_name == NULL) {
        PLCF_DEBUG("Failed to read symbol name\n");
        retval = PLCRASH_EINVAL;
        goto cleanup;
    }

    /* Inform our caller */
    symbol_cb(found_symbol.normalized_value + image->vmaddr_slide, sym_name, context);

    // fall through to cleanup
    retval = PLCRASH_ESUCCESS;

cleanup:
    plcrash_async_macho_symtab_reader_free(&reader);
    return retval;
}

/**
 * Free all mapped segment resources.
 *
 * @note Unlike most free() functions in this API, this function is async-safe.
 */
void plcrash_async_macho_mapped_segment_free (pl_async_macho_mapped_segment_t *segment) {
    plcrash_async_mobject_free(&segment->mobj);
}

/**
 * Free all Mach-O binary image resources.
 *
 * @warning This method is not async safe.
 */
void plcrash_nasync_macho_free (plcrash_async_macho_t *image) {
    if (image->name != NULL)
        free(image->name);
    
    plcrash_async_mobject_free(&image->load_cmds);

    mach_port_mod_refs(mach_task_self(), image->task, MACH_PORT_RIGHT_SEND, -1);
}


/*
 * @} pl_async_macho
 */
