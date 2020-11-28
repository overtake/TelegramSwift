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

#import "SenTestCompat.h"

#import "PLCrashAsyncMachOImage.h"

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <objc/runtime.h>
#import <execinfo.h>

@interface PLCrashAsyncMachOImageTests : SenTestCase {
    /** The image containing our class. */
    plcrash_async_macho_t _image;
}
@end


@implementation PLCrashAsyncMachOImageTests

- (void) setUp {
    /* Fetch our containing image's dyld info */
    Dl_info info;
    STAssertTrue(dladdr((__bridge void *)([self class]), &info) > 0, @"Could not fetch dyld info for %p", [self class]);
    /* Look up the vmaddr and slide for our image */
    uintptr_t text_vmaddr;
    pl_vm_off_t vmaddr_slide = 0;
    bool found_image = false;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i) == info.dli_fbase) {
            vmaddr_slide = _dyld_get_image_vmaddr_slide(i);
            text_vmaddr = (uintptr_t) (info.dli_fbase - vmaddr_slide);
            found_image = true;
            break;
        }
    }
    STAssertTrue(found_image, @"Could not find dyld image record");

    plcrash_nasync_macho_init(&_image, mach_task_self(), info.dli_fname, (pl_vm_address_t) info.dli_fbase);

    /* Basic test of the initializer */
    STAssertEqualCStrings(_image.name, info.dli_fname, @"Incorrect name");
    STAssertEquals(_image.header_addr, (pl_vm_address_t) info.dli_fbase, @"Incorrect header address");
    STAssertEquals(_image.vmaddr_slide, (pl_vm_off_t) vmaddr_slide, @"Incorrect vmaddr_slide value");
    
    unsigned long text_size;
    STAssertNotNULL(getsegmentdata(info.dli_fbase, SEG_TEXT, &text_size), @"Failed to find segment");
    STAssertEquals(_image.text_size, (pl_vm_size_t) text_size, @"Incorrect text segment size computed");
    STAssertEquals(_image.text_vmaddr, (pl_vm_address_t) text_vmaddr, @"Incorrect text segment address computed");
}

- (void) tearDown {
    plcrash_nasync_macho_free(&_image);
}

/**
 * Test byte order getter.
 */
- (void) testByteOrder {
    STAssertEquals(_image.byteorder, plcrash_async_macho_byteorder(&_image), @"Returned incorrect byte order");
}

/**
 * Test Mach header getters.
 */
- (void) testMachHeader {
    STAssertEquals((const struct mach_header *)&_image.header, plcrash_async_macho_header(&_image), @"Returned incorrect header");

    if (_image.m64) {
        STAssertEquals((pl_vm_size_t)sizeof(struct mach_header_64), plcrash_async_macho_header_size(&_image), @"Incorrect header size");
    } else {
        STAssertEquals((pl_vm_size_t)sizeof(struct mach_header), plcrash_async_macho_header_size(&_image), @"Incorrect header size");
    }
}

/** Address range testing. */
- (void) testContainsAddress {
    STAssertTrue(plcrash_async_macho_contains_address(&_image, _image.header_addr), @"The base address should be contained within the image");
    STAssertTrue(_image.header_addr > 0, @"This should always be true ...");
    STAssertFalse(plcrash_async_macho_contains_address(&_image, _image.header_addr-1), @"Returned true for an address outside the mapped range");

    STAssertFalse(plcrash_async_macho_contains_address(&_image, _image.header_addr+_image.text_size), @"Returned true for an address outside the mapped range");
    STAssertTrue(plcrash_async_macho_contains_address(&_image, _image.header_addr+_image.text_size-1), @"The final byte should be within the mapped range");
}

/**
 * Test CPU type/subtype getters.
 */
- (void) testCPUType {
    /* Modify the image to enable byte order handling */
    _image.byteorder = &plcrash_async_byteorder_swapped;
    _image.header.cputype = plcrash_async_byteorder_swapped.swap32(CPU_TYPE_X86);
    _image.header.cpusubtype = plcrash_async_byteorder_swapped.swap32(CPU_SUBTYPE_586);

    /* Verify the result */
    STAssertEquals(CPU_TYPE_X86, plcrash_async_macho_cpu_type(&_image), @"Incorrect CPU type");
    STAssertEquals(CPU_SUBTYPE_586, plcrash_async_macho_cpu_subtype(&_image), @"Incorrect CPU subtype");
}

/**
 * Test iteration of Mach-O load commands.
 */
- (void) testIterateCommand {

    plcrash_async_macho_t image;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        plcrash_nasync_macho_init(&image, mach_task_self(), _dyld_get_image_name(i), (pl_vm_address_t) _dyld_get_image_header(i));
        struct load_command *cmd = NULL;

        for (uint32_t ncmd = 0; ncmd < image.ncmds; ncmd++) {
            cmd = plcrash_async_macho_next_command(&image, cmd);
            STAssertNotNULL(cmd, @"Failed to fetch load command %" PRIu32 " of %" PRIu32 "in %s", ncmd, image.ncmds, image.name);

            if (cmd == NULL)
                break;

            STAssertNotEquals((uint32_t)0, cmd->cmdsize, @"This test simply ensures that dereferencing the cmd pointer doesn't crash: %d:%d:%s", ncmd, image.ncmds, image.name);
        }

        plcrash_nasync_macho_free(&image);
    }
}

/**
 * Test type-specific iteration of Mach-O load commands.
 */
- (void) testIterateSpecificCommand {
    struct load_command *cmd = 0;
    
    bool found_uuid = false;

    while ((cmd = plcrash_async_macho_next_command_type(&_image, cmd, LC_UUID)) != 0) {
        /* Validate the command type and size */
        STAssertEquals(_image.byteorder->swap32(cmd->cmd), (uint32_t)LC_UUID, @"Incorrect load command returned");
        STAssertEquals((size_t)_image.byteorder->swap32(cmd->cmdsize), sizeof(struct uuid_command), @"Incorrect load command size returned by iterator");

        STAssertFalse(found_uuid, @"Duplicate LC_UUID load commands iterated");
        found_uuid = true;
    }

    STAssertTrue(found_uuid, @"Failed to iterate LC_CMD structures");
    
    /* Test the case where there are no matches. LC_SUB_UMBRELLA should never be used in a unit tests binary. */
    cmd = plcrash_async_macho_next_command_type(&_image, NULL, LC_SUB_UMBRELLA);
    STAssertNULL(cmd, @"Should not have found the requested load command");
}

/**
 * Test type-specific iteration of Mach-O load commands when a NULL size argument is provided.
 */
- (void) testIterateSpecificCommandNULLSize {
    struct load_command *cmd = NULL;
    
    /* If the following doesn't crash dereferencing the NULL cmdsize argument, success! */
    bool found_uuid = false;
    while ((cmd = plcrash_async_macho_next_command_type(&_image, cmd, LC_UUID)) != 0) {
        STAssertFalse(found_uuid, @"Duplicate LC_UUID load commands iterated");
        found_uuid = true;
    }
    
    STAssertTrue(found_uuid, @"Failed to iterate LC_CMD structures");
}

/**
 * Test simple short-cut for finding a single load_command.
 */
- (void) testFindCommand {
    struct load_command *cmd = plcrash_async_macho_find_command(&_image, LC_UUID);
    STAssertNotNULL(cmd, @"Failed to find command");
    STAssertEquals(_image.byteorder->swap32(cmd->cmd), (uint32_t)LC_UUID, @"Incorrect load command returned");
    STAssertEquals(_image.byteorder->swap32(cmd->cmdsize), (uint32_t)sizeof(struct uuid_command), @"Incorrect load command size returned");
    
    /* Test the case where there are no matches. LC_SUB_UMBRELLA should never be used in a unit tests binary. */
    cmd = plcrash_async_macho_find_command(&_image, LC_SUB_UMBRELLA);
    STAssertNULL(cmd, @"Should not have found the requested load command");
}

/**
 * Test memory mapping of a Mach-O segment
 */
- (void) testMapSegment {
    pl_async_macho_mapped_segment_t seg;

    /* Try to map the segment */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_macho_map_segment(&_image, "__TEXT", &seg), @"Failed to map segment");
    
    /* Fetch the segment directly for comparison */
    unsigned long segsize = 0;
    uint8_t *data = getsegmentdata((void *)_image.header_addr, "__TEXT", &segsize);
    STAssertNotNULL(data, @"Could not fetch segment data");

    /* Compare the address and length. We have to apply the slide to determine the original source address. */    
    STAssertEquals((pl_vm_address_t)data, (pl_vm_address_t) (seg.mobj.address + seg.mobj.vm_slide), @"Addresses do not match");
    STAssertEquals((pl_vm_size_t)segsize, seg.mobj.length, @"Sizes do not match");
    
    /* Fetch the segment command for further comparison */
    struct load_command *cmd = plcrash_async_macho_find_segment_cmd(&_image, "__TEXT");
    STAssertNotNULL(data, @"Could not fetch segment command");
    if (_image.byteorder->swap32(cmd->cmd) == LC_SEGMENT) {
        struct segment_command *segcmd = (struct segment_command *) cmd;
        STAssertEquals(seg.fileoff, (uint64_t) _image.byteorder->swap32(segcmd->fileoff), @"File offset does not match");
        STAssertEquals(seg.filesize, (uint64_t) _image.byteorder->swap32(segcmd->filesize), @"File size does not match");

    } else if (_image.byteorder->swap32(cmd->cmd) == LC_SEGMENT_64) {
        struct segment_command_64 *segcmd = (struct segment_command_64 *) cmd;
        STAssertEquals(seg.fileoff, _image.byteorder->swap64(segcmd->fileoff), @"File offset does not match");
        STAssertEquals(seg.filesize, _image.byteorder->swap64(segcmd->filesize), @"File size does not match");
    } else {
        STFail(@"Unsupported command type!");
    }

    /* Compare the contents */
    uint8_t *mapped_data = plcrash_async_mobject_remap_address(&seg.mobj, (pl_vm_address_t) data, 0, segsize);
    STAssertNotNULL(mapped_data, @"Could not get pointer for mapped data");

    STAssertNotEquals(mapped_data, data, @"Should not be the same pointer!");
    STAssertTrue(memcmp(data, mapped_data, segsize) == 0, @"The mapped data is not equal");

    /* Clean up */
    plcrash_async_macho_mapped_segment_free(&seg);

    /* Test handling of a missing segment */
    STAssertEquals(PLCRASH_ENOTFOUND, plcrash_async_macho_map_segment(&_image, "__NO_SUCH_SEG", &seg), @"Should have failed to map the segment");
}

/**
 * Test memory mapping of a Mach-O section
 */
- (void) testMapSection {
    plcrash_async_mobject_t mobj;
    
    /* Try to map the section */
    const char *segname = "__DATA";
    const char *sectname = "__const";
    plcrash_error_t err = plcrash_async_macho_map_section(&_image, segname, sectname, &mobj);
    if (err == PLCRASH_ENOTFOUND) {
        segname = "__DATA_CONST";
        err = plcrash_async_macho_map_section(&_image, segname, sectname, &mobj);
    }
    STAssertEquals(PLCRASH_ESUCCESS, err, @"Failed to map section");
    
    /* Fetch the section directly for comparison */
    unsigned long sectsize = 0;
    uint8_t *data = getsectiondata((void *)_image.header_addr, segname, sectname, &sectsize);
    STAssertNotNULL(data, @"Could not fetch section data");

    /* Compare the address and length. We have to apply the slide to determine the original source address. */
    STAssertEquals((pl_vm_address_t)data, (pl_vm_address_t) (mobj.address + mobj.vm_slide), @"Addresses do not match");
    STAssertEquals((pl_vm_size_t)sectsize, mobj.length, @"Sizes do not match");
    
    /* Compare the contents */
    uint8_t *mapped_data = plcrash_async_mobject_remap_address(&mobj, (pl_vm_address_t) data, 0, sectsize);
    STAssertNotNULL(mapped_data, @"Could not get pointer for mapped data");
    
    STAssertNotEquals(mapped_data, data, @"Should not be the same pointer!");
    STAssertTrue(memcmp(data, mapped_data, sectsize) == 0, @"The mapped data is not equal");

    /* Clean up */
    plcrash_async_mobject_free(&mobj);
    
    /* Test handling of a missing section */
    STAssertEquals(PLCRASH_ENOTFOUND, plcrash_async_macho_map_section(&_image, "__DATA", "__NO_SUCH_SECT", &mobj), @"Should have failed to map the section");
}


/**
 * Test memory mapping of a missing Mach-O segment
 */
- (void) testMapMissingSegment {
    pl_async_macho_mapped_segment_t seg;
    STAssertEquals(PLCRASH_ENOTFOUND, plcrash_async_macho_map_segment(&_image, "__NO_SUCH_SEG", &seg), @"Should have failed to map the segment");
}

/* testFindSymbol callback handling */

struct testFindSymbol_cb_ctx {
    pl_vm_address_t addr;
    char *name;
};

static void testFindSymbol_cb (pl_vm_address_t address, const char *name, void *ctx) {
    struct testFindSymbol_cb_ctx *cb_ctx = ctx;
    cb_ctx->addr = address;
    cb_ctx->name = strdup(name);
}

/**
 * Test basic initialization of the symbol table reader.
 */
- (void) testInitSymtabReader {
    plcrash_async_macho_symtab_reader_t reader;
    plcrash_error_t ret = plcrash_async_macho_symtab_reader_init(&reader, &_image);
    STAssertEquals(ret, PLCRASH_ESUCCESS, @"Failed to initializer reader");
    
    STAssertNotNULL(reader.symtab, @"Failed to map symtab");
    STAssertNotNULL(reader.symtab_global, @"Failed to map global symtab");
    STAssertNotNULL(reader.symtab_local, @"Failed to map global symtab");
    STAssertNotNULL(reader.string_table, @"Failed to map string table");
    
    /* Try iterating the tables. If we don't crash, we're doing well. */
    plcrash_async_macho_symtab_entry_t entry;
    for (uint32_t i = 0; i <reader.nsyms; i++) {
        entry = plcrash_async_macho_symtab_reader_read(&reader, reader.symtab, i);
        
        /* If the symbol is not within a section, or a debugging symbol, skip the remaining tests */
        if ((entry.n_type & N_TYPE) != N_SECT || ((entry.n_type & N_STAB) != 0))
            continue;

        const char *sym = plcrash_async_macho_symtab_reader_symbol_name(&reader, entry.n_strx);
        STAssertNotNULL(sym, @"Symbol name read failed");
    }

    for (uint32_t i = 0; i <reader.nsyms_global; i++)
        entry = plcrash_async_macho_symtab_reader_read(&reader, reader.symtab_global, i);
    
    for (uint32_t i = 0; i <reader.nsyms_local; i++)
        entry = plcrash_async_macho_symtab_reader_read(&reader, reader.symtab_local, i);

    plcrash_async_macho_symtab_reader_free(&reader);
}

/**
 * Test symbol name reading.
 */
- (void) testReadSymbolName {
    /* Fetch the our IMP address and symbolicate it using dladdr(). */
    IMP localIMP = class_getMethodImplementation([self class], _cmd);
    Dl_info dli;
    STAssertTrue(dladdr((void *)localIMP, &dli) != 0, @"Failed to look up symbol");
    STAssertNotNULL(dli.dli_sname, @"Symbol name was stripped!");
    
    /* Now walk the Mach-O table ourselves */
    plcrash_async_macho_symtab_reader_t reader;
    plcrash_error_t ret = plcrash_async_macho_symtab_reader_init(&reader, &_image);
    STAssertEquals(ret, PLCRASH_ESUCCESS, @"Failed to initializer reader");

    /* Find the symbol entry and extract the name name */
    const char *sym = NULL;
    plcrash_async_macho_symtab_entry_t entry;
    for (uint32_t i = 0; i < reader.nsyms; i++) {
        entry = plcrash_async_macho_symtab_reader_read(&reader, reader.symtab, i);
        /* Skip non-matching symbols */
        if (entry.normalized_value != (pl_vm_address_t) dli.dli_saddr - _image.vmaddr_slide)
            continue;
        
        /* If the symbol is not within a section, or a debugging symbol, skip the remaining tests */
        if ((entry.n_type & N_TYPE) != N_SECT || ((entry.n_type & N_STAB) != 0))
            continue;
        
        /* Verify the name */
        sym = plcrash_async_macho_symtab_reader_symbol_name(&reader, entry.n_strx);
    }
    
    STAssertNotNULL(sym, @"Symbol name read failed");
    if (sym != NULL)
        STAssertTrue(strcmp(sym, dli.dli_sname) == 0, @"Returned incorrect symbol name: %s != %s", sym, dli.dli_sname);

    plcrash_async_macho_symtab_reader_free(&reader);
}

/**
 * Test symbol lookup.
 */
- (void) testFindSymbol {
    /* Fetch our current PC, to be used for symbol lookup */
    void *callstack[1];
    int frames = backtrace(callstack, 1);
    STAssertEquals(1, frames, @"Could not fetch our PC");

    /* Perform our symbol lookup */
    struct testFindSymbol_cb_ctx ctx;
    plcrash_error_t res = plcrash_async_macho_find_symbol_by_pc(&_image, (pl_vm_address_t) callstack[0], testFindSymbol_cb, &ctx);
    STAssertEquals(res, PLCRASH_ESUCCESS, @"Failed to locate symbol");
    
    /* The following tests will crash if the above did not succeed */
    if (res != PLCRASH_ESUCCESS)
        return;
    
    /* Fetch the our IMP address and symbolicate it using dladdr(). */
    IMP localIMP = class_getMethodImplementation([self class], _cmd);
    Dl_info dli;
    STAssertTrue(dladdr((void *)localIMP, &dli) != 0, @"Failed to look up symbol");
    
    /* Compare the results */
    STAssertEqualCStrings(dli.dli_sname, ctx.name, @"Returned incorrect symbol name");
    STAssertEquals(dli.dli_saddr, (void *) ctx.addr, @"Returned incorrect symbol address with slide %" PRId64, (int64_t) _image.vmaddr_slide);
}

/**
 * Test lookup of symbols by name.
 */
- (void) testFindSymbolByName {
    /* Fetch our current symbol name, to be used for symbol lookup */
    IMP localIMP = class_getMethodImplementation([self class], _cmd);
    Dl_info dli;
    STAssertTrue(dladdr((void *)localIMP, &dli) != 0, @"Failed to look up symbol");
    
    /* Perform our symbol lookup */
    pl_vm_address_t pc;
    plcrash_error_t res = plcrash_async_macho_find_symbol_by_name(&_image, (const char *) dli.dli_sname, &pc);
    STAssertEquals(res, PLCRASH_ESUCCESS, @"Failed to locate symbol %s", dli.dli_sname);

    /* Compare the results */
    STAssertEquals((pl_vm_address_t) localIMP, pc, @"Returned incorrect symbol address");
}

@end
