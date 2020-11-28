/*
 * Author: Mike Ash <mikeash@plausiblelabs.com>
 *
 * Copyright (c) 2012-2013 Plausible Labs Cooperative, Inc.
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

#include "PLCrashAsyncObjCSection.h"
#include "PLCrashCompatConstants.h"

#include <Foundation/Foundation.h>

/**
 * @internal
 * @ingroup plcrash_async_image
 * @defgroup plcrash_async_image_objc Objective-C Metadata Parsing
 *
 * Implements async-safe Objective-C binary parsing, for use at crash time when extracting binary information
 * from the crashed process.
 * @{
 */

static const char * const kObjCSegmentName = "__OBJC";
static const char * const kDataSegmentName = "__DATA";
static const char * const kDataConstSegmentName = "__DATA_CONST";
static const char * const kDataDirtySegmentName = "__DATA_DIRTY";

static const char * const kObjCModuleInfoSectionName = "__module_info";
static const char * const kClassListSectionName = "__objc_classlist";
static const char * const kCategoryListSectionName = "__objc_catlist";
static const char * const kObjCConstSectionName = "__objc_const";
static const char * const kObjCConstAxSectionName = "__objc_const_ax";
static const char * const kObjCDataSectionName = "__objc_data";
static const char * const kDataSectionName = "__data";

static uint32_t CLS_NO_METHOD_ARRAY = 0x4000;
static uint32_t END_OF_METHODS_LIST = -1;

/**
 * @internal
 * Flag set for non-ptr ISAs. This flag is not ABI stable, and may change.
 */
#define PLCRASH_ASYNC_OBJC_ISA_NONPTR_FLAG 0x1

/**
 * Return true if the given CPU uses non-pointer isa values.
 *
 * On x64 architectures, isa pointers are masked to
 * allow for refcounting and maintaining bit flags when the LSB is 0x1.
 *
 * @warning  ISA tagging is handled entirely in libobjc, and could be changed in any future release. There
 * are variables vended from libobjc that return the isa pointer mask; we validate these in our
 * tests, but we can't validate the meaning of bitfield checked here.
 *
 * The tagged isa pointers seem to be used even within the writable class data; as such, we must
 * perform masking here, as well. This is another reason we should migrate the code to
 * work directly on the backing unmodified pages, as that provides us with a stable ABI. In
 * the worst case scenario, we'll simply fail to symbolicate a class should the ABI
 * change incompatibly.
 *
 * @sa http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html
 * @sa https://github.com/opensource-apple/objc4/blob/master/runtime/objc-config.h
 */
#if !__LP64__ || TARGET_IPHONE_SIMULATOR
#define PLCRASH_ASYNC_OBJC_SUPPORT_NONPTR_ISA 0
#else
#define PLCRASH_ASYNC_OBJC_SUPPORT_NONPTR_ISA 1
#endif

/**
 * @internal
 * The pointer mask for non-pointer ISAs. This flag is not ABI stable, and may change; it is validated
 * at development time via our unit tests. As per our API invariants, if this flag becomes out-of-sync
 * with the host OS, our symbolication implementation will either fail to find some symbols, or will
 * return incorrect symbols, but it will not crash.
 *
 * @sa https://github.com/opensource-apple/objc4/blob/master/runtime/objc-private.h
 */
#if defined(__arm64__)
#define PLCRASH_ASYNC_OBJC_ISA_NONPTR_CLASS_MASK 0x0000000ffffffff8ULL
#elif defined(__x86_64__)
#define PLCRASH_ASYNC_OBJC_ISA_NONPTR_CLASS_MASK 0x00007ffffffffff8ULL
#else
#define PLCRASH_ASYNC_OBJC_ISA_NONPTR_CLASS_MASK ~1UL
#endif

/**
 * @internal
 * @see https://opensource.apple.com/source/objc4/objc4-750/runtime/objc-runtime-new.h
 *
 * Class's rw data structure has been realized.
 ** If set, data pointers to RW data instead of RO.
 */
static const uint32_t RW_REALIZED = (1U<<31);

/**
 * @internal
 * @see https://opensource.apple.com/source/objc4/objc4-750/runtime/objc-runtime-new.h
 *
 * A realized class' data pointer is a heap-copied copy of class_ro_t.
 */
static const uint32_t RW_COPIED_RO = (1<<27);

/**
 * @internal
 * @see https://opensource.apple.com/source/objc4/objc4-750/runtime/objc-runtime-new.h
 *
 * A class' data pointer mask.
 */
#if !__LP64__
#define FAST_DATA_MASK 0xfffffffcUL
#else
#define FAST_DATA_MASK 0x00007ffffffffff8UL
#endif

struct pl_objc1_module {
    uint32_t version;
    uint32_t size;
    uint32_t name;
    uint32_t symtab;
};

struct pl_objc1_symtab {
    uint32_t sel_ref_cnt;
    uint32_t refs;
    uint16_t cls_def_count;
    uint16_t cat_def_count;
};

struct pl_objc1_class {
    uint32_t isa;
    uint32_t super;
    uint32_t name;
    uint32_t version;
    uint32_t info;
    uint32_t instance_size;
    uint32_t ivars;
    uint32_t methods;
    uint32_t cache;
    uint32_t protocols;
};

struct pl_objc1_method_list {
    uint32_t obsolete;
    uint32_t count;
};

struct pl_objc1_method {
    uint32_t name;
    uint32_t types;
    uint32_t imp;
};

struct pl_objc2_class_32 {
    uint32_t isa;
    uint32_t superclass;
    uint32_t cache;
    uint32_t vtable;
    uint32_t data_rw;
};

struct pl_objc2_class_64 {
    uint64_t isa;
    uint64_t superclass;
    uint64_t cache;
    uint64_t vtable;
    uint64_t data_rw;
};

struct pl_objc2_class_data_rw_32 {
    uint32_t flags;
    uint32_t version;
    uint32_t data_ro;
};

struct pl_objc2_class_data_rw_64 {
    uint32_t flags;
    uint32_t version;
    uint64_t data_ro;
};

struct pl_objc2_class_data_ro_32 {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
    uint32_t ivarLayout;
    uint32_t name;
    uint32_t baseMethods;
    uint32_t baseProtocols;
    uint32_t ivars;
    uint32_t weakIvarLayout;
    uint32_t baseProperties;
};

struct pl_objc2_class_data_ro_64 {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
    uint32_t reserved;
    uint64_t ivarLayout;
    uint64_t name;
    uint64_t baseMethods;
    uint64_t baseProtocols;
    uint64_t ivars;
    uint64_t weakIvarLayout;
    uint64_t baseProperties;
};

/** @internal
 * Category list entry (32-bit representation).
 */
struct pl_objc2_category_32 {
    uint32_t name;
    uint32_t cls;
    uint32_t instanceMethods;
    uint32_t classMethods;
    uint32_t protocols;
    uint32_t instanceProperties;
};

/** @internal
 * Category list entry (64-bit representation).
 */
struct pl_objc2_category_64 {
    uint64_t name;
    uint64_t cls;
    uint64_t instanceMethods;
    uint64_t classMethods;
    uint64_t protocols;
    uint64_t instanceProperties;
};

struct pl_objc2_method_32 {
    uint32_t name;
    uint32_t types;
    uint32_t imp;
};

struct pl_objc2_method_64 {
    uint64_t name;
    uint64_t types;
    uint64_t imp;
};

struct pl_objc2_list_header {
    uint32_t entsize;
    uint32_t count;
};

/**
 * Returns the pointer value for a non-pointer isa. This assumes that the lsb flag of 0x1 will continue to be
 * used to designate a non-pointer isa; see the PLCRASH_ASYNC_OBJC_SUPPORT_NONPTR_ISA documentation for more details.
 */
static pl_vm_address_t plcrash_async_objc_isa_pointer (pl_vm_address_t isa) {
#if PLCRASH_ASYNC_OBJC_SUPPORT_NONPTR_ISA
    if (isa & PLCRASH_ASYNC_OBJC_ISA_NONPTR_FLAG) {
        return isa & PLCRASH_ASYNC_OBJC_ISA_NONPTR_CLASS_MASK;
    }
#endif
    return isa;
}

/**
 * Get the index into the context's cache for the given key. Must only be called
 * if the cache size has been set.
 *
 * @param context The context.
 * @param key The key.
 * @return The index.
 */
static size_t cache_index (plcrash_async_objc_cache_t *context, pl_vm_address_t key) {
    return (key >> 2) % context->classCacheSize;
}

/**
 * Get the context's cache's total memory allocation size, including both keys and values.
 *
 * @param context The context.
 * @return The total number of bytes allocated for the cache.
 */
static size_t cache_allocation_size (plcrash_async_objc_cache_t *context) {
    size_t size = context->classCacheSize;
    return size * sizeof(*context->classCacheKeys) + size * sizeof(*context->classCacheValues);
}

/**
 * Look up a key within the cache.
 *
 * @param context The context.
 * @param key The key to look up.
 * @return The value stored in the cache for that key, or 0 if none was found.
 */
static pl_vm_address_t cache_lookup (plcrash_async_objc_cache_t *context, pl_vm_address_t key) {
    if (context->classCacheSize > 0) {
        size_t index = cache_index(context, key);
        if (context->classCacheKeys[index] == key) {
            return context->classCacheValues[index];
        }
    }
    return 0;
}

/**
 * Store a key/value pair in the cache. The cache is not guaranteed storage so storing may
 * silently fail, and the association can be evicted at any time. It's a CACHE.
 *
 * @param context The context.
 * @param key The key to store.
 * @param value The value to store.
 */
static void cache_set (plcrash_async_objc_cache_t *context, pl_vm_address_t key, pl_vm_address_t value) {
    /* If nothing has used the cache yet, allocate the memory. */
    if (context->classCacheKeys == NULL) {
        size_t size = 1024;
        context->classCacheSize = size;
        
        size_t allocationSize = cache_allocation_size(context);
        
        vm_address_t addr;
        kern_return_t err = vm_allocate(mach_task_self_, &addr, allocationSize, VM_FLAGS_ANYWHERE);
        /* If it fails, just bail out. We don't need the cache for correct operation. */
        if (err != KERN_SUCCESS) {
            PLCF_DEBUG("vm_allocate failed with error %x, the class cache could not be initialized and ObjC parsing will be substantially slower", err);
            context->classCacheSize = 0;
            return;
        }
        
        context->classCacheKeys = (pl_vm_address_t *)addr;
        context->classCacheValues = (pl_vm_address_t *)(context->classCacheKeys + size);
    }
    
    /* Treat the cache as a simple hash table with no chaining whatsoever. If the bucket is already
     * occupied, then don't do anything. The existing entry wins. */
    size_t index = cache_index(context, key);
    if (context->classCacheKeys[index] == 0) {
        context->classCacheKeys[index] = key;
        context->classCacheValues[index] = value;
    }
}

/**
 * Free any initialized memory objects in an ObjC context object.
 *
 * @param context The context.
 */
static void free_mapped_sections (plcrash_async_objc_cache_t *context) {
    if (context->objcConstMobjInitialized) {
        plcrash_async_mobject_free(&context->objcConstMobj);
        context->objcConstMobjInitialized = false;
    }
    if (context->objcConstAxMobjInitialized) {
        plcrash_async_mobject_free(&context->objcConstAxMobj);
        context->objcConstAxMobjInitialized = false;
    }
    if (context->classMobjInitialized) {
        plcrash_async_mobject_free(&context->classMobj);
        context->classMobjInitialized = false;
    }
    if (context->catMobjInitialized) {
        plcrash_async_mobject_free(&context->catMobj);
        context->catMobjInitialized = false;
    }
    if (context->objcDataMobjInitialized) {
        plcrash_async_mobject_free(&context->objcDataMobj);
        context->objcDataMobjInitialized = false;
    }
    if (context->dataMobjInitialized) {
        plcrash_async_mobject_free(&context->dataMobj);
        context->dataMobjInitialized = false;
    }
}

/**
 * @internal
 * @see https://opensource.apple.com/source/objc4/objc4-750/runtime/objc-file.mm
 *
 * Find and map a named section within a __DATA or __DATA_CONST or __DATA_DIRTY segment, initializing @a mobj.
 * It is the caller's responsibility to dealloc @a mobj after a successful initialization.
 *
 * @param image The image to search for @a segname.
 * @param sectname The name of the section to map.
 * @param mobj The mobject to be initialized with a mapping of the section's data. It is the caller's responsibility to dealloc @a mobj after
 * a successful initialization.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_ENOTFOUND if the section is not found, or an error result on failure.
 */
static plcrash_error_t map_data_section (plcrash_async_macho_t *image, const char **segname, const char *sectname, plcrash_async_mobject_t *mobj) {
    *segname = kDataSegmentName;
    plcrash_error_t err = plcrash_async_macho_map_section(image, *segname, sectname, mobj);
    if (err == PLCRASH_ENOTFOUND) {
        *segname = kDataConstSegmentName;
        err = plcrash_async_macho_map_section(image, *segname, sectname, mobj);
    }
    if (err == PLCRASH_ENOTFOUND) {
        *segname = kDataDirtySegmentName;
        err = plcrash_async_macho_map_section(image, *segname, sectname, mobj);
    }
    return err;
}

/**
 * Set up the memory objects in an ObjC context object for the given image. This will
 * map the memory objects in the context to the appropriate sections in the image.
 *
 * @param image The MachO image to map.
 * @param context The context.
 * @return An error code.
 */
static plcrash_error_t map_sections (plcrash_async_macho_t *image, plcrash_async_objc_cache_t *context) {
    if (image == context->lastImage)
        return PLCRASH_ESUCCESS;
    
    /* Clean up the info from the previous image. Free the memory objects and reset the
     * image pointer. The image pointer is reset so that it's not stale in case we return
     * early due to an error. */
    free_mapped_sections(context);
    context->lastImage = NULL;
    
    plcrash_error_t err;
    const char *segname;
    
    /* Map in the __objc_const section, which is where all the read-only class data lives. */
    err = map_data_section(image, &segname, kObjCConstSectionName, &context->objcConstMobj);
    if (err != PLCRASH_ESUCCESS) {
        if (err != PLCRASH_ENOTFOUND)
            PLCF_DEBUG("pl_async_macho_map_section(%p, %s, %s, %p) failure %d", image, segname, kObjCConstSectionName, &context->objcConstMobj, err);
        goto cleanup;
    }
    context->objcConstMobjInitialized = true;

    /* Map in the __objc_const_ax section. */
    err = plcrash_async_macho_map_section(image, kDataSegmentName, kObjCConstAxSectionName, &context->objcConstAxMobj);
    if (err != PLCRASH_ESUCCESS && err != PLCRASH_ENOTFOUND)
        PLCF_DEBUG("pl_async_macho_map_section(%s, %s, %s, %p) failure %d", PLCF_DEBUG_IMAGE_NAME(image), kDataSegmentName, kObjCConstAxSectionName, &context->objcConstAxMobj, err);
    context->objcConstAxMobjInitialized = err == PLCRASH_ESUCCESS;
    
    /* Map in the class list section. */
    err = map_data_section(image, &segname, kClassListSectionName, &context->classMobj);
    if (err != PLCRASH_ESUCCESS) {
        if (err != PLCRASH_ENOTFOUND)
            PLCF_DEBUG("pl_async_macho_map_section(%s, %s, %s, %p) failure %d", PLCF_DEBUG_IMAGE_NAME(image), segname, kClassListSectionName, &context->classMobj, err);
        goto cleanup;
    }
    context->classMobjInitialized = true;
    
    /* Map in the category list section. */
    err = map_data_section(image, &segname, kCategoryListSectionName, &context->catMobj);
    if (err != PLCRASH_ESUCCESS) {
        if (err != PLCRASH_ENOTFOUND)
            PLCF_DEBUG("pl_async_macho_map_section(%s, %s, %s, %p) failure %d", PLCF_DEBUG_IMAGE_NAME(image), segname, kCategoryListSectionName, &context->catMobj, err);
        goto cleanup;
    }
    context->catMobjInitialized = true;
    
    /* Map in the __objc_data section, which is where the actual classes live. */
    err = plcrash_async_macho_map_section(image, kDataSegmentName, kObjCDataSectionName, &context->objcDataMobj);
    if (err != PLCRASH_ESUCCESS) {
        /* If the class list was found, the data section must also be found. */
        PLCF_DEBUG("pl_async_macho_map_section(%s, %s, %s, %p) failure %d", PLCF_DEBUG_IMAGE_NAME(image), kDataSegmentName, kObjCDataSectionName, &context->objcDataMobj, err);
        goto cleanup;
    }
    context->objcDataMobjInitialized = true;

    /* Map in the __data section. */
    err = plcrash_async_macho_map_section(image, kDataSegmentName, kDataSectionName, &context->dataMobj);
    if (err != PLCRASH_ESUCCESS && err != PLCRASH_ENOTFOUND)
        PLCF_DEBUG("pl_async_macho_map_section(%s, %s, %s, %p) failure %d", PLCF_DEBUG_IMAGE_NAME(image), kDataSegmentName, kDataSectionName, &context->dataMobj, err);
    context->dataMobjInitialized = err == PLCRASH_ESUCCESS;
    
    /* Only after all mappings succeed do we set the image. If any failed, the image won't be set,
     * and any mappings that DO succeed will be cleaned up on the next call (or when freeing the
     * context. */
    context->lastImage = image;
    
cleanup:
    return err;
}

static plcrash_error_t pl_async_parse_obj1_class(plcrash_async_macho_t *image, struct pl_objc1_class *cls, bool isMetaClass, plcrash_async_objc_found_method_cb callback, void *ctx) {
    plcrash_error_t err;
    
    /* Get the class's name. */
    pl_vm_address_t namePtr = image->byteorder->swap32(cls->name);
    bool classNameInitialized = false;
    plcrash_async_macho_string_t className;
    err = plcrash_async_macho_string_init(&className, image, namePtr);
    if (err != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("plcrash_async_macho_string_init at 0x%llx error %d", (long long)namePtr, err);
        return err;
    }
    classNameInitialized = true;
    
    /* Grab the method list pointer. This is either a pointer to
     * a single method_list structure, OR a pointer to an array
     * of pointers to method_list structures, depending on the
     * flag in the .info field. Argh. */
    pl_vm_address_t methodListPtr = image->byteorder->swap32(cls->methods);
    
    /* If CLS_NO_METHOD_ARRAY is set, then methodListPtr points to
     * one method_list. If it's not set, then it points to an
     * array of pointers to method lists. */
    bool hasMultipleMethodLists = (image->byteorder->swap32(cls->info) & CLS_NO_METHOD_ARRAY) == 0;
    pl_vm_address_t methodListCursor = methodListPtr;
    
    while (true) {
        /* Grab a method list pointer. How to do that depends on whether
         * CLS_NO_METHOD_ARRAY is set. Once done, thisListPtr contains
         * a pointer to the method_list structure to read. */
        pl_vm_address_t thisListPtr;
        if (hasMultipleMethodLists) {
            /* If there are multiple method lists, then read the list pointer
             * from the current cursor, and advance the cursor. */
            uint32_t ptr;
            err = plcrash_async_task_memcpy(image->task, methodListCursor, 0, &ptr, sizeof(ptr));
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)methodListCursor, err);
                goto cleanup;
            }
            
            thisListPtr = image->byteorder->swap32(ptr);
            /* The end of the list is indicated with NULL or
             * END_OF_METHODS_LIST (the ObjC runtime source checks both). */
            if (thisListPtr == 0 || thisListPtr == END_OF_METHODS_LIST)
                break;
            
            methodListCursor += sizeof(ptr);
        } else {
            /* If CLS_NO_METHOD_ARRAY is set, then the single method_list
             * is pointed to by the cursor. */
            thisListPtr = methodListCursor;
            
            /* The pointer may be NULL, in which case there are no methods. */
            if (thisListPtr == 0)
                break;
        }
        
        /* Read a method_list structure from the current list pointer. */
        struct pl_objc1_method_list methodList;
        err = plcrash_async_task_memcpy(image->task, thisListPtr, 0, &methodList, sizeof(methodList));
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)methodListPtr, err);
            goto cleanup;
        }
        
        /* Find out how many methods are in the list, and iterate. */
        uint32_t count = image->byteorder->swap32(methodList.count);
        for (uint32_t i = 0; i < count; i++) {
            /* Method structures are laid out directly following the
             * method_list structure. */
            struct pl_objc1_method method;
            pl_vm_address_t methodPtr = thisListPtr + sizeof(methodList) + i * sizeof(method);
            err = plcrash_async_task_memcpy(image->task, methodPtr, 0, &method, sizeof(method));
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)methodPtr, err);
                goto cleanup;
            }
            
            /* Load the method name from the .name field pointer. */
            pl_vm_address_t methodNamePtr = image->byteorder->swap32(method.name);
            plcrash_async_macho_string_t methodName;
            err = plcrash_async_macho_string_init(&methodName, image, methodNamePtr);
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_macho_string_init at 0x%llx error %d", (long long)methodNamePtr, err);
                goto cleanup;
            }
            
            /* Grab the method's IMP as well. */
            pl_vm_address_t imp = image->byteorder->swap32(method.imp);
            
            /* Callback! */
            callback(isMetaClass, &className, &methodName, imp, ctx);
            
            /* Clean up the method name object. */
            plcrash_async_macho_string_free(&methodName);
        }
        
        /* Bail out of the loop after a single iteration if
         * CLS_NO_METHOD_ARRAY is set, because there's no need
         * to iterate in that case. */
        if (!hasMultipleMethodLists)
            break;
    }
    
cleanup:
    if (classNameInitialized)
        plcrash_async_macho_string_free(&className);
    
    return err;
}

/**
 * Parse Objective-C class data from an old-style __module_info section containing
 * ObjC1 metadata.
 *
 * @param image The Mach-O image to read from.
 * @param callback The callback to invoke for each method found.
 * @param ctx The context pointer to pass to the callback.
 * @return PLCRASH_ESUCCESS on success, PLCRASH_ENOTFOUND if the image doesn't
 * contain ObjC1 metadata, or another error code if a different error occurred.
 */
static plcrash_error_t pl_async_objc_parse_from_module_info (plcrash_async_macho_t *image, plcrash_async_objc_found_method_cb callback, void *ctx) {
    plcrash_error_t err = PLCRASH_EUNKNOWN;
    struct pl_objc1_module *moduleData;

    /* Map the __module_info section. */
    bool moduleMobjInitialized = false;
    plcrash_async_mobject_t moduleMobj;

    err = plcrash_async_macho_map_section(image, kObjCSegmentName, kObjCModuleInfoSectionName, &moduleMobj);
    if (err != PLCRASH_ESUCCESS) {
        if (err != PLCRASH_ENOTFOUND)
            PLCF_DEBUG("pl_async_macho_map_section(%p, %s, %s, %p) failure %d", image, kObjCSegmentName, kObjCModuleInfoSectionName, &moduleMobj, err);
        goto cleanup;
    }

    /* Successful mapping, so mark the memory object as needing cleanup. */
    moduleMobjInitialized = true;
    
    /* Get a pointer to the module info data. */
    moduleData = (struct pl_objc1_module *) plcrash_async_mobject_remap_address(&moduleMobj, moduleMobj.task_address, 0, sizeof(*moduleData));
    if (moduleData == NULL) {
        PLCF_DEBUG("Failed to obtain pointer from %s memory object", kObjCModuleInfoSectionName);
        err = PLCRASH_ENOTFOUND;
        goto cleanup;
    }
    
    /* Read successive module structs from the section until we run out of data. */
    for (unsigned moduleIndex = 0; moduleIndex < moduleMobj.length / sizeof(*moduleData); moduleIndex++) {
        /* Grab the pointer to the symtab for this module struct. */
        pl_vm_address_t symtabPtr = image->byteorder->swap32(moduleData[moduleIndex].symtab);
        if (symtabPtr == 0)
            continue;
        
        /* Read a symtab struct from that pointer. */
        struct pl_objc1_symtab symtab;
        err = plcrash_async_task_memcpy(image->task, symtabPtr, 0, &symtab, sizeof(symtab));
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)symtabPtr, err);
            goto cleanup;
        }
        
        /* Iterate over the classes in the symtab. */
        uint16_t classCount = image->byteorder->swap16(symtab.cls_def_count);
        for (unsigned i = 0; i < classCount; i++) {
            /* Classes are indicated by pointers laid out sequentially after the
             * symtab structure. */
            uint32_t classPtr;
            pl_vm_address_t cursor = symtabPtr + sizeof(symtab) + i * sizeof(classPtr);
            err = plcrash_async_task_memcpy(image->task, cursor, 0, &classPtr, sizeof(classPtr));
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)cursor, err);
                goto cleanup;
            }
            classPtr = image->byteorder->swap32(classPtr);
            
            /* Read a class structure from the class pointer. */
            struct pl_objc1_class cls;
            err = plcrash_async_task_memcpy(image->task, classPtr, 0, &cls, sizeof(cls));
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)classPtr, err);
                goto cleanup;
            }
            
            err = pl_async_parse_obj1_class(image, &cls, false, callback, ctx);
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("pl_async_parse_obj1_class error %d while parsing class", err);
                goto cleanup;
            }
            
            /* Read a class structure for the metaclass. */
            pl_vm_address_t isa = plcrash_async_objc_isa_pointer(image->byteorder->swap(cls.isa));
            struct pl_objc1_class metaclass;
            err = plcrash_async_task_memcpy(image->task, isa, 0, &metaclass, sizeof(metaclass));
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)isa, err);
                goto cleanup;
            }
            
            err = pl_async_parse_obj1_class(image, &metaclass, true, callback, ctx);
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("pl_async_parse_obj1_class error %d while parsing metaclass", err);
                goto cleanup;
            }
        }
    }
    
cleanup:
    /* Clean up the memory objects before returning if they're initialized. */
    if (moduleMobjInitialized)
        plcrash_async_mobject_free(&moduleMobj);
    
    return err;
}

/**
 * Parse an ObjC 2.0 method_list_t structure at @a method_list_addr and call @a callback with all
 * parsed methods.
 *
 * @param image The image to read from.
 * @param objc_cache The Objective-C cache object.
 * @param class_name The name of the class being parsed.
 * @param is_meta_class true if this is a metaclass.
 * @param method_list_addr The address of the method list data.
 * @param callback The callback to be invoked for each method found.
 * @param ctx A context pointer to pass to the callback.
 * @return Returns PLCRASH_ESUCCESS on success, or an appropriate error on failure.
 */
static plcrash_error_t pl_async_objc_parse_objc2_method_list (plcrash_async_macho_t *image,
                                                              plcrash_async_objc_cache_t *objc_cache,
                                                              plcrash_async_macho_string_t *class_name,
                                                              bool is_meta_class,
                                                              pl_vm_address_t method_list_addr,
                                                              plcrash_async_objc_found_method_cb callback,
                                                              void *ctx)
{
    PLCF_ASSERT(method_list_addr != 0);
    
    /* Read the method list header. */
    struct pl_objc2_list_header *header;
    plcrash_async_mobject_t *section = &objc_cache->objcConstMobj;
    header = (struct pl_objc2_list_header *) plcrash_async_mobject_remap_address(section, method_list_addr, 0, sizeof(*header));
    if (header == NULL) {
        section = &objc_cache->objcConstAxMobj;
        header = (struct pl_objc2_list_header *) plcrash_async_mobject_remap_address(section, method_list_addr, 0, sizeof(*header));
    }
    if (header == NULL) {
        PLCF_DEBUG("plcrash_async_mobject_remap_address in __objc_const and __objc_const_ax failed to map methods pointer 0x%llx", (long long) method_list_addr);
        return PLCRASH_EINVALID_DATA;
    }
    
    /* Extract the entry size and count from the list header. */
    uint32_t entsize = image->byteorder->swap32(header->entsize) & ~(uint32_t)3;
    uint32_t count = image->byteorder->swap32(header->count);
    
    /* Compute the method list start position and length. */
    pl_vm_address_t method_list_start = method_list_addr + sizeof(*header);
    pl_vm_size_t method_list_length = (pl_vm_size_t)entsize * count;
    
    const char *cursor = (const char *) plcrash_async_mobject_remap_address(section, method_list_start, 0, method_list_length);
    if (cursor == NULL) {
        PLCF_DEBUG("plcrash_async_mobject_remap_address at 0x%llx length %llu returned NULL", (long long)method_list_start, (unsigned long long)method_list_length);
        return PLCRASH_EINVALID_DATA;
    }
    
    /* Extract methods from the list. */
    for (uint32_t i = 0; i < count; i++) {
        plcrash_error_t err;

        /* Read an architecture-appropriate method structure from the
         * current cursor. */
        const struct pl_objc2_method_32 *method_32 = (const struct pl_objc2_method_32 *)cursor;
        const struct pl_objc2_method_64 *method_64 = (const struct pl_objc2_method_64 *)cursor;
        
        /* Extract the method name pointer. */
        pl_vm_address_t methodNamePtr = (image->m64
                                         ? (pl_vm_address_t) image->byteorder->swap64(method_64->name)
                                         : image->byteorder->swap32(method_32->name));
        
        /* Read the method name. */
        plcrash_async_macho_string_t method_name;
        if ((err = plcrash_async_macho_string_init(&method_name, image, methodNamePtr)) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("plcrash_async_macho_string_init at 0x%llx error %d", (long long)methodNamePtr, err);
            return err;
        }
    
        /* Extract the method IMP. */
        pl_vm_address_t imp = (image->m64
                               ? (pl_vm_address_t) image->byteorder->swap64(method_64->imp)
                               : image->byteorder->swap32(method_32->imp));
        
        /* Call the callback. */
        callback(is_meta_class, class_name, &method_name, imp, ctx);

        /* Clean up the method name. */
        plcrash_async_macho_string_free(&method_name);
        
        /* Increment the cursor by the entry size for the next iteration of the loop. */
        cursor += entsize;
    }

    return PLCRASH_ESUCCESS;
}

/**
 * Parse a single ObjC 2.0 class structure and return the results.
 *
 * @param image The image to read from.
 * @param objc_cache The Objective-C cache object.
 * @param cls A pointer to the class structure to be parsed
 * @param[out] class_name On success, will be initialized with the class name. It is the caller's responsibility to free
 * the returned value via plcrash_async_macho_string_free(). If the function returns an error, no class_name value
 * will be provided and the caller is not responsible for freeing any associated resources.
 * @param[out] cls_data_ro A buffer to which the class_ro data will be written. Must be at least sizeof(class_ro_t).
 *
 * @tparam class_t The class type, one of pl_objc2_class_32 or pl_objc2_class_64.
 * @tparam class_ro_t The read-only class type, one of pl_objc2_class_data_ro_32 or pl_objc2_class_data_ro_64.
 * @tparam class_rw_t The read-write class type, one of pl_objc2_class_data_rw_32 or pl_objc2_class_data_rw_64.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_ENOTFOUND if the class is unrealized, PLCRASH_EINVALID_DATA if
 * the input format is invalid (including failed pointer dereferencing), or another appropriate error.
 */
template<typename class_t, typename class_ro_t, typename class_rw_t, typename machine_ptr_t>
static plcrash_error_t pl_async_objc_parse_objc2_class (plcrash_async_macho_t *image, plcrash_async_objc_cache_t *objc_cache, class_t *cls, plcrash_async_macho_string_t *class_name, class_ro_t *cls_data_ro) {
    plcrash_error_t err;
    
    /* Grab the class's data_rw pointer. This needs masking because it also
     * can contain flags. */
    pl_vm_address_t data_ptr = (pl_vm_address_t) image->byteorder->swap(cls->data_rw);
    data_ptr &= FAST_DATA_MASK;

    /* Grab the data RO pointer from the cache. If unavailable, we'll fetch the data and populate the class. */
    pl_vm_address_t cached_data_ro_addr = cache_lookup(objc_cache, data_ptr);
    if (cached_data_ro_addr == 0) {
        class_rw_t cls_data_rw;
        
        /* Read the class_rw structure. */
        err = plcrash_async_task_memcpy(image->task, data_ptr, 0, &cls_data_rw, sizeof(cls_data_rw));
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)data_ptr, err);
            return PLCRASH_EINVALID_DATA;
        }

        /* Check the flags. If it's not yet realized, then we need to skip the class. */
        uint32_t flags = image->byteorder->swap(cls_data_rw.flags);
        if ((flags & RW_REALIZED) == 0)  {
            // PLCF_DEBUG("Found unrealized class with RO data at 0x%llx, skipping it", (long long)data_ptr);
            return PLCRASH_ENOTFOUND;
        }

        /* Grab the data_ro pointer. The RO data (read-only) contains the class name
         * and method list. */
        cached_data_ro_addr = (pl_vm_address_t) image->byteorder->swap(cls_data_rw.data_ro);

        /* When objc_class_abi_version >= 1, it's a tagged union based on the low bit:
         * 0: class_ro_t  1: class_rw_ext_t
         * @see https://opensource.apple.com/source/objc4/objc4-781/runtime/objc-runtime-new.h */
        if (cached_data_ro_addr & 0x1) {
            cached_data_ro_addr &= ~0x1;
            /* class_rw_ext_t has a link to R/O data without any offset, so just grab this pointer. */
            machine_ptr_t data_ro_addr;
            err = plcrash_async_task_memcpy(image->task, cached_data_ro_addr, 0, &data_ro_addr, sizeof(data_ro_addr));
            if (err != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx error %d", (long long)cached_data_ro_addr, err);
                return PLCRASH_EINVALID_DATA;
            }
            cached_data_ro_addr = (pl_vm_address_t) image->byteorder->swap(data_ro_addr);
        }

        /* Copy the R/O data; it will either be heap allocated (RW_COPIED_RO), found within the __objc_const section of the current cached image,
         * or found within the __objc_const section of a non-cached image. */
        if ((flags & RW_COPIED_RO) != 0 || !plcrash_async_macho_contains_address(image, cached_data_ro_addr)) {
            if ((err = plcrash_async_task_memcpy(image->task, cached_data_ro_addr, 0, cls_data_ro, sizeof(*cls_data_ro))) != PLCRASH_ESUCCESS) {
                PLCF_DEBUG("plcrash_async_task_memcpy at 0x%llx returned NULL", (long long)cached_data_ro_addr);
                return PLCRASH_EINVALID_DATA;
            }
        } else {
            void *ptr = plcrash_async_mobject_remap_address(&objc_cache->objcConstMobj, cached_data_ro_addr, 0, sizeof(*cls_data_ro));
            if (ptr == NULL) {
                PLCF_DEBUG("plcrash_async_mobject_remap_address in __objc_const for pointer 0x%llx returned NULL", (long long)cached_data_ro_addr);
                return PLCRASH_EINVALID_DATA;
            }
            
            plcrash_async_memcpy(cls_data_ro, ptr, sizeof(*cls_data_ro));
        }
        
        /* Add a new cache entry. */
        cache_set(objc_cache, data_ptr, cached_data_ro_addr);
    } else {
        void *ptr;
        
        /* We know that the address is valid (it wouldn't be in the cache otherwise). We try the cheaper memory mapping first,
         * and then fall back to a memory copy. */
        if ((ptr = plcrash_async_mobject_remap_address(&objc_cache->objcConstMobj, cached_data_ro_addr, 0, sizeof(*cls_data_ro))) != NULL) {
            plcrash_async_memcpy(cls_data_ro, ptr, sizeof(*cls_data_ro));
        } else if (plcrash_async_task_memcpy(image->task, cached_data_ro_addr, 0, cls_data_ro, sizeof(*cls_data_ro)) == PLCRASH_ESUCCESS) {
            /* Do nothing -- success! */
        } else {
            PLCF_DEBUG("Failed to read validated class_ro data at 0x%llx", (long long)cached_data_ro_addr);
            return PLCRASH_EINVALID_DATA;
        }
    }
    
    /* Fetch the pointer to the class name, and make the string. */
    pl_vm_address_t class_name_ptr = (pl_vm_address_t) image->byteorder->swap(cls_data_ro->name);
    err = plcrash_async_macho_string_init(class_name, image, class_name_ptr);
    if (err != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("plcrash_async_macho_string_init at 0x%llx error %d", (long long)class_name_ptr, err);
        return PLCRASH_EINVALID_DATA;
    }

    return err;
}

/**
 * Parse a single ObjC 2.0 class structure and call @a callback with all parsed methods.
 *
 * @param image The image to read from.
 * @param objc_cache The Objective-C cache object.
 * @param cls A pointer to the class structure to be parsed
 * @param is_meta_class true if this is a metaclass.
 * @param callback The callback to invoke for each method found.
 * @param ctx A context pointer to pass to the callback.
 *
 * @tparam class_t The class type, one of pl_objc2_class_32 or pl_objc2_class_64.
 * @tparam class_ro_t The read-only class type, one of pl_objc2_class_data_ro_32 or pl_objc2_class_data_ro_64.
 * @tparam class_rw_t The read-write class type, one of pl_objc2_class_data_rw_32 or pl_objc2_class_data_rw_64.
 *
 * @return An error code.
 */
template<typename class_t, typename class_ro_t, typename class_rw_t, typename machine_ptr_t>
static plcrash_error_t pl_async_objc_parse_objc2_class_methods (plcrash_async_macho_t *image, plcrash_async_objc_cache_t *objc_cache, class_t *cls, bool is_meta_class, plcrash_async_objc_found_method_cb callback, void *ctx) {
    plcrash_async_macho_string_t class_name;
    class_ro_t cls_data_ro;
    plcrash_error_t err;
    
    /* Parse the class */
    if ((err = pl_async_objc_parse_objc2_class<class_t, class_ro_t, class_rw_t, machine_ptr_t>(image, objc_cache, cls, &class_name, &cls_data_ro)) != PLCRASH_ESUCCESS)
        return err;

    /* Fetch and parse the method list. */
    pl_vm_address_t methods_ptr = (pl_vm_address_t) image->byteorder->swap(cls_data_ro.baseMethods);
    if (methods_ptr != 0) {
        err = pl_async_objc_parse_objc2_method_list(image, objc_cache, &class_name, is_meta_class, methods_ptr, callback, ctx);
    } else {
        /* The base method list will be NULL if no methods are defined for the class/metaclass; in that case, we simply skip the class. */
        err = PLCRASH_ESUCCESS;
    }

    /* Clean up */
    plcrash_async_macho_string_free(&class_name);
    return err;
}

/**
 * Parse a single ObjC 2.0 category_t structure and call @a callback with all parsed methods.
 *
 * @param image The image to read from.
 * @param objc_cache The Objective-C cache object.
 * @param category A pointer to a category structure.
 * @param callback The callback to invoke for each method found.
 * @param ctx A context pointer to pass to the callback.
 *
 * @tparam category_t The category type, one of pl_objc2_category_32 or pl_objc2_category_64.
 * @tparam class_t The class type, one of pl_objc2_class_32 or pl_objc2_class_64.
 * @tparam class_ro_t The read-only class type, one of pl_objc2_class_data_ro_32 or pl_objc2_class_data_ro_64.
 * @tparam class_rw_t The read-write class type, one of pl_objc2_class_data_rw_32 or pl_objc2_class_data_rw_64.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_ENOTFOUND if the class referenced by the category is unrealized, PLCRASH_EINVALID_DATA if
 * the input format is invalid (including failed pointer dereferencing), or another appropriate error.
 */
template <typename category_t, typename class_t, typename class_ro_t, typename class_rw_t, typename machine_ptr_t>
static plcrash_error_t pl_async_objc_parse_objc2_category_methods (plcrash_async_macho_t *image, plcrash_async_objc_cache_t *objc_cache, category_t *category, plcrash_async_objc_found_method_cb callback, void *ctx) {
    plcrash_async_macho_string_t class_name;
    class_ro_t cls_data_ro;
    plcrash_error_t err;
    
    /* Grab the class reference and parse the class. We try to simply remap the pointer, but if that fails, we perform a more
     * expensive read. */
    pl_vm_address_t ptr = (pl_vm_address_t) image->byteorder->swap(category->cls);
    class_t *classPtr = (class_t *) plcrash_async_mobject_remap_address(&objc_cache->objcDataMobj, ptr, 0, sizeof(*classPtr));
    class_t class_data;

    if (classPtr == NULL) {
        if ((err = plcrash_async_task_memcpy(image->task, ptr, 0, &class_data, sizeof(class_data))) != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("plcrash_async_task_memcpy() for pointer 0x%llx returned NULL", (long long)ptr);
            return PLCRASH_EINVALID_DATA;
        }
        
        classPtr = &class_data;
    }
    
    if ((err = pl_async_objc_parse_objc2_class<class_t, class_ro_t, class_rw_t, machine_ptr_t>(image, objc_cache, classPtr, &class_name, &cls_data_ro)) != PLCRASH_ESUCCESS)
        return err;
    
    /* Fetch and parse the instance and class method lists. The method list will be NULL if no methods are defined for the category; in that case, we simply skip the category. */
    pl_vm_address_t methods_ptr = (pl_vm_address_t) image->byteorder->swap(category->instanceMethods);
    if (methods_ptr != 0) {
        if ((err = pl_async_objc_parse_objc2_method_list(image, objc_cache, &class_name, false, methods_ptr, callback, ctx)) != PLCRASH_ESUCCESS)
            goto cleanup;
    }
    
    methods_ptr = (pl_vm_address_t) image->byteorder->swap(category->classMethods);
    if (methods_ptr != 0) {
        if ((err = pl_async_objc_parse_objc2_method_list(image, objc_cache, &class_name, true, methods_ptr, callback, ctx)) != PLCRASH_ESUCCESS)
            goto cleanup;
    }
    
    err = PLCRASH_ESUCCESS;

cleanup:
    /* Clean up */
    plcrash_async_macho_string_free(&class_name);
    return err;
}

/**
 * Parse ObjC2 class data from a __objc_classlist section.
 *
 * @param image The Mach-O image to parse.
 * @param objcContext An ObjC context object.
 * @param callback The callback to invoke for each method found.
 * @param ctx A context pointer to pass to the callback.
 * @return PLCRASH_ESUCCESS on success, PLCRASH_ENOTFOUND if no ObjC2 data exists in the image, and another error code if a different error occurred.
 *
 * @tparam class_t The class type, one of pl_objc2_class_32 or pl_objc2_class_64.
 * @tparam class_ro_t The read-only class type, one of pl_objc2_class_data_ro_32 or pl_objc2_class_data_ro_64.
 * @tparam class_rw_t The read-write class type, one of pl_objc2_class_data_rw_32 or pl_objc2_class_data_rw_64.
 * @tparam category_t The category type, one of pl_objc2_category_32 or pl_objc2_category_64.
 * @tparam machine_ptr_t The target's pointer type (eg, uint64_t).
 */
template<typename class_t, typename class_ro_t, typename class_rw_t, typename category_t, typename machine_ptr_t>
static plcrash_error_t pl_async_objc_parse_from_data_section (plcrash_async_macho_t *image, plcrash_async_objc_cache_t *objcContext, plcrash_async_objc_found_method_cb callback, void *ctx) {
    plcrash_error_t err;
    
    /* Map memory objects. */
    err = map_sections(image, objcContext);
    if (err != PLCRASH_ESUCCESS) {
        /* Don't log an error if ObjC data was simply not found */
        if (err != PLCRASH_ENOTFOUND)
            PLCF_DEBUG("Unable to map relevant sections in %s for ObjC2 class parsing, error %d", PLCF_DEBUG_IMAGE_NAME(image), err);
        return err;
    }
    
    /* Get a pointer out of the mapped class list. */
    machine_ptr_t *classPtrs = (machine_ptr_t *) plcrash_async_mobject_remap_address(&objcContext->classMobj, objcContext->classMobj.task_address, 0, objcContext->classMobj.length);
    if (classPtrs == NULL) {
        PLCF_DEBUG("plcrash_async_mobject_remap_address in __objc_classlist for pointer 0x%llx returned NULL", (long long)objcContext->classMobj.address);
        return PLCRASH_EINVALID_DATA;
    }
    
    /* Figure out how many classes are in the class list based on its length and
     * the size of a pointer in the image. */
    pl_vm_size_t classCount = objcContext->classMobj.length / sizeof(machine_ptr_t);
    
    /* Iterate over all classes. */
    for(unsigned i = 0; i < classCount; i++) {
        /* Read the class structure */
        pl_vm_address_t ptr = (pl_vm_address_t) classPtrs[i];
        class_t *classPtr = (class_t *) plcrash_async_mobject_remap_address(&objcContext->objcDataMobj, ptr, 0, sizeof(*classPtr));
        if (classPtr == NULL) {
            classPtr = (class_t *) plcrash_async_mobject_remap_address(&objcContext->dataMobj, ptr, 0, sizeof(*classPtr));
        }
        if (classPtr == NULL) {
            PLCF_DEBUG("plcrash_async_mobject_remap_address in __objc_data and __data for pointer 0x%llx returned NULL", (long long)ptr);
            return PLCRASH_EINVALID_DATA;
        }
        
        /* Parse the class. */
        err = pl_async_objc_parse_objc2_class_methods<class_t, class_ro_t, class_rw_t, machine_ptr_t>(image, objcContext, classPtr, false, callback, ctx);
        if (err != PLCRASH_ESUCCESS) {
            /* Skip unrealized classes; they'll never appear in a live backtrace. */
            if (err == PLCRASH_ENOTFOUND) {
                /* We should reset the error variable to avoid return it from the function. */
                err = PLCRASH_ESUCCESS;
                continue;
            }
            PLCF_DEBUG("pl_async_objc_parse_objc2_class error %d while parsing class", err);
            return err;
        }
        
        /* Read an architecture-appropriate class structure for the metaclass. */
        pl_vm_address_t isa = plcrash_async_objc_isa_pointer((pl_vm_address_t) image->byteorder->swap(classPtr->isa));
        class_t *metaclass = (class_t *) plcrash_async_mobject_remap_address(&objcContext->objcDataMobj, isa, 0, sizeof(*metaclass));
        if (metaclass == NULL) {
            metaclass = (class_t *) plcrash_async_mobject_remap_address(&objcContext->dataMobj, isa, 0, sizeof(*metaclass));
        }
        if (metaclass == NULL) {
            PLCF_DEBUG("plcrash_async_mobject_remap_address in __objc_data and __data for pointer 0x%llx returned NULL", (long long)isa);
            return PLCRASH_EINVALID_DATA;
        }

        /* Parse the metaclass. */
        err = pl_async_objc_parse_objc2_class_methods<class_t, class_ro_t, class_rw_t, machine_ptr_t>(image, objcContext, metaclass, true, callback, ctx);
        if (err != PLCRASH_ESUCCESS) {
            PLCF_DEBUG("pl_async_objc_parse_objc2_class_methods error %d while parsing metaclass", err);
            return err;
        }
    }
    
    /* Get a pointer out of the mapped category list. */
    machine_ptr_t *catPtrs = (machine_ptr_t *) plcrash_async_mobject_remap_address(&objcContext->catMobj, objcContext->catMobj.task_address, 0, objcContext->catMobj.length);
    if (catPtrs == NULL) {
        PLCF_DEBUG("plcrash_async_mobject_remap_address in __objc_catlist for pointer 0x%llx returned NULL", (long long)objcContext->catMobj.address);
        return PLCRASH_EINVALID_DATA;
    }
    
    /* Figure out how many categories are in the category list based on its length and the size of a pointer in the image. */
    pl_vm_size_t catCount = objcContext->catMobj.length / sizeof(*catPtrs);
    
    /* Iterate over all classes. */
    for(unsigned i = 0; i < catCount; i++) {
        /* Read a category pointer at the current index from the appropriate pointer. */
        pl_vm_address_t ptr = (pl_vm_address_t) image->byteorder->swap(catPtrs[i]);
        
        /* Read the category structure. */
        category_t *category = (category_t *) plcrash_async_mobject_remap_address(&objcContext->objcConstMobj, ptr, 0, sizeof(*category));
        if (category == NULL) {
            PLCF_DEBUG("plcrash_async_mobject_remap_address in __objc_const for pointer 0x%llx returned NULL", (long long)ptr);
            return PLCRASH_EINVALID_DATA;
        }

        /* Parse the category. */
        err = pl_async_objc_parse_objc2_category_methods<category_t, class_t, class_ro_t, class_rw_t, machine_ptr_t>(image, objcContext, category, callback, ctx);
        if (err != PLCRASH_ESUCCESS) {
            /* Skip unrealized classes; they'll never appear in a live backtrace. */
            if (err == PLCRASH_ENOTFOUND)
                continue;

            PLCF_DEBUG("pl_async_objc_parse_objc2_class error %d while parsing class", err);
            return err;
        }
    }
    
    return err;
}

/**
 * Initialize an ObjC cache object.
 *
 * @param cache A pointer to the cache object to initialize.
 * @return An error code.
 */
plcrash_error_t plcrash_async_objc_cache_init (plcrash_async_objc_cache_t *cache) {
    cache->gotObjC2Info = false;
    cache->lastImage = NULL;
    cache->objcConstMobjInitialized = false;
    cache->objcConstAxMobjInitialized = false;
    cache->classMobjInitialized = false;
    cache->catMobjInitialized = false;
    cache->objcDataMobjInitialized = false;
    cache->dataMobjInitialized = false;
    cache->classCacheSize = 0;
    cache->classCacheKeys = NULL;
    cache->classCacheValues = NULL;
    return PLCRASH_ESUCCESS;
}

/**
 * Free an ObjC cache object.
 *
 * @param cache A pointer to the cache object to free.
 */
void plcrash_async_objc_cache_free (plcrash_async_objc_cache_t *cache) {
    free_mapped_sections(cache);

    if (cache->classCacheKeys != NULL)
        vm_deallocate(mach_task_self(), (vm_address_t)cache->classCacheKeys, cache_allocation_size(cache));
}

/**
 * @internal
 *
 * Parse Objective-C class data from a Mach-O image, invoking a callback
 * for each method found in the data. This tries both old-style ObjC1
 * class data and new-style ObjC2 data.
 *
 * @param image The image to read class data from.
 * @param cache An ObjC context object.
 * @param callback The callback to invoke for each method.
 * @param ctx The context pointer to pass to the callback.
 * @return An error code.
 */
static plcrash_error_t plcrash_async_objc_parse (plcrash_async_macho_t *image, plcrash_async_objc_cache_t *cache, plcrash_async_objc_found_method_cb callback, void *ctx) {
    plcrash_error_t err;
    
    if (cache == NULL)
        return PLCRASH_EACCESS;
   
    if (!cache->gotObjC2Info) {
        /* Try ObjC1 data. */
        err = pl_async_objc_parse_from_module_info(image, callback, ctx);
    } else {
        /* If it couldn't be found before, don't even bother to try again. */
        err = PLCRASH_ENOTFOUND;
    }
    
    /* If there wasn't any, try ObjC2 data. */
    if (err == PLCRASH_ENOTFOUND) {
        if (image->m64)
            err = pl_async_objc_parse_from_data_section<pl_objc2_class_64, pl_objc2_class_data_ro_64, pl_objc2_class_data_rw_64, pl_objc2_category_64, uint64_t>(image, cache, callback, ctx);
        else
            err = pl_async_objc_parse_from_data_section<pl_objc2_class_32, pl_objc2_class_data_ro_32, pl_objc2_class_data_rw_32, pl_objc2_category_32, uint32_t>(image, cache, callback, ctx);

        if (err == PLCRASH_ESUCCESS) {
            /* ObjC2 info successfully obtained, note that so we can stop trying ObjC1 next time around. */
            cache->gotObjC2Info = true;
        }
    }
    
    return err;
}

struct pl_async_objc_find_method_search_context {
    pl_vm_address_t searchIMP;
    pl_vm_address_t bestIMP;
};

struct pl_async_objc_find_method_call_context {
    pl_vm_address_t searchIMP;
    plcrash_async_objc_found_method_cb outerCallback;
    void *outerCallbackCtx;
};

/**
 * Callback used to search for the method IMP that best matches a search target.
 * The context pointer is a pointer to pl_async_objc_find_method_search_context.
 * The searchIMP field should be set to the IMP to search for. The bestIMP field
 * should be initialized to 0, and will be updated with the best-matching IMP
 * found.
 */
static void pl_async_objc_find_method_search_callback (bool isClassMethod, plcrash_async_macho_string_t *className, plcrash_async_macho_string_t *methodName, pl_vm_address_t imp, void *ctx) {
    struct pl_async_objc_find_method_search_context *ctxStruct = (struct pl_async_objc_find_method_search_context *) ctx;
    
    if (imp >= ctxStruct->bestIMP && imp <= ctxStruct->searchIMP) {
        ctxStruct->bestIMP = imp;
    }
}

/**
 * Callback used to find the method that precisely matches a search target.
 * The context pointer is a pointer to pl_async_objc_find_method_call_context.
 * The searchIMP field should be set to the IMP to search for. The outerCallback
 * will be invoked, passing outerCalblackCtx and the method data for a precise
 * match, if any is found.
 */
static void pl_async_objc_find_method_call_callback (bool isClassMethod, plcrash_async_macho_string_t *className, plcrash_async_macho_string_t *methodName, pl_vm_address_t imp, void *ctx) {
    struct pl_async_objc_find_method_call_context *ctxStruct = (struct pl_async_objc_find_method_call_context *) ctx;
    
    if (imp == ctxStruct->searchIMP && ctxStruct->outerCallback != NULL) {
        ctxStruct->outerCallback(isClassMethod, className, methodName, imp, ctxStruct->outerCallbackCtx);
        ctxStruct->outerCallback = NULL;
    }
}

/**
 * Search for the method that best matches the given code address.
 *
 * @param image The image to search.
 * @param objcContext A pointer to an ObjC context object. Must not be NULL, and must (obviously) be initialized.
 * @param imp The address to search for.
 * @param callback The callback to invoke when the best match is found.
 * @param ctx The context pointer to pass to the callback.
 * @return An error code.
 */
plcrash_error_t plcrash_async_objc_find_method (plcrash_async_macho_t *image, plcrash_async_objc_cache_t *objcContext, pl_vm_address_t imp, plcrash_async_objc_found_method_cb callback, void *ctx) {
    struct pl_async_objc_find_method_search_context searchCtx = {
        .searchIMP = imp
    };

    plcrash_error_t err = plcrash_async_objc_parse(image, objcContext, pl_async_objc_find_method_search_callback, &searchCtx);
    if (err != PLCRASH_ESUCCESS) {
        /* Don't log an error if ObjC data was simply not found */
        if (err != PLCRASH_ENOTFOUND)
            PLCF_DEBUG("pl_async_objc_parse of %p (%s) failure %d", image, PLCF_DEBUG_IMAGE_NAME(image), err);
        return err;
    }
    
    if (searchCtx.bestIMP == 0)
        return PLCRASH_ENOTFOUND;
    
    struct pl_async_objc_find_method_call_context callCtx = {
        .searchIMP = searchCtx.bestIMP,
        .outerCallback = callback,
        .outerCallbackCtx = ctx
    };
    
    return plcrash_async_objc_parse(image, objcContext, pl_async_objc_find_method_call_callback, &callCtx);
}

