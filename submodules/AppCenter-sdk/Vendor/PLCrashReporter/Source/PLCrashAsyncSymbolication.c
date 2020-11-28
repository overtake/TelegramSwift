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

#include "PLCrashAsyncSymbolication.h"

#include <inttypes.h>

/**
 * @internal
 * @ingroup plcrash_async_symbol
 * @{
 */

/* Maximum symbol name size */
#define SYMBOL_NAME_BUFLEN 256

struct symbol_lookup_ctx {
    /** Buffer to which the symbol name should be written. */
    char buffer[SYMBOL_NAME_BUFLEN];

    /** If true, the symbol was found. If false, no symbol was found */
    bool found;

    /** Address of the discovered symbol, or 0x0 if not found. */
    pl_vm_address_t symbol_address;
};

static void macho_symbol_callback (pl_vm_address_t address, const char *name, void *ctx);
static void objc_symbol_callback (bool isClassMethod, plcrash_async_macho_string_t *className, plcrash_async_macho_string_t *methodName, pl_vm_address_t imp, void *ctx);

/**
 * Initialize a symbol-finding context object.
 *
 * @param cache A pointer to the cache object to initialize.
 * @return An error code.
 */
plcrash_error_t plcrash_async_symbol_cache_init (plcrash_async_symbol_cache_t *cache) {
    return plcrash_async_objc_cache_init(&cache->objc_cache);
}

/**
 * Free a symbol-finding context object.
 *
 * @param cache A pointer to the cache object to free.
 */
void plcrash_async_symbol_cache_free (plcrash_async_symbol_cache_t *cache) {
    plcrash_async_objc_cache_free(&cache->objc_cache);
}

/**
 * Find the best-guess matching symbol name for a given @a pc address, using heuristics based on symbol and @a pc address locality.
 *
 * @param image The Mach-O image to search for this symbol.
 * @param strategy The look-up strategy to be used to find the symbol.
 * @param cache The task-specific cache to use for lookups.
 * @param pc The program counter (instruction pointer) address for which a symbol will be searched.
 * @param callback The callback to be issued when a matching symbol is found. If no symbol is found, the provided function will not be called, and an error other than PLCRASH_ESUCCESS
 * will be returned.
 * @param ctx The context to be provided to @a callback.
 *
 * @return Calls @a callback and returns PLCRASH_ESUCCESS if a matching symbol is found. Otherwise, returns one of the other defined plcrash_error_t error values.
 */
plcrash_error_t plcrash_async_find_symbol (plcrash_async_macho_t *image,
                                           plcrash_async_symbol_strategy_t strategy,
                                           plcrash_async_symbol_cache_t *cache,
                                           pl_vm_address_t pc,
                                           plcrash_async_found_symbol_cb callback,
                                           void *ctx)
{
    struct symbol_lookup_ctx lookup_ctx;
    plcrash_error_t machoErr = PLCRASH_ENOTFOUND;
    plcrash_error_t objcErr = PLCRASH_ENOTFOUND;

    lookup_ctx.symbol_address = 0x0;
    lookup_ctx.found = false;

    /* Perform lookups; our callbacks will only update the lookup_ctx if they find a better match than the
     * previously run callbacks */
    if (strategy & PLCRASH_ASYNC_SYMBOL_STRATEGY_SYMBOL_TABLE)
        machoErr = plcrash_async_macho_find_symbol_by_pc(image, pc, macho_symbol_callback, &lookup_ctx);
    
    if (strategy & PLCRASH_ASYNC_SYMBOL_STRATEGY_OBJC)
        objcErr = plcrash_async_objc_find_method(image, &cache->objc_cache, pc, objc_symbol_callback, &lookup_ctx);

    if (machoErr != PLCRASH_ESUCCESS && objcErr != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("Could not find symbol for pc 0x%" PRIx64 " in %s", (uint64_t) pc, PLCF_DEBUG_IMAGE_NAME(image));
        return PLCRASH_ENOTFOUND;
    }

    /* Even if a symbol was found above, our callbacks could have errored out, in which case they would have
     * logged a debug message, not set 'found' */
    if (!lookup_ctx.found) {
        PLCF_DEBUG("Unexpected error occured in symbol lookup callbacks for pc %" PRIx64 " in %s", (uint64_t) pc, PLCF_DEBUG_IMAGE_NAME(image));
        return PLCRASH_EINTERNAL;
    }

    callback(lookup_ctx.symbol_address, lookup_ctx.buffer, ctx);
    return PLCRASH_ESUCCESS;
}

/**
 * Append a character to the given @a str, enforcing byte @a limit.
 *
 * @param str String to which character should be appended.
 * @param c Character to append.
 * @param cursor Cursor used to store the current write position.
 * @param limit Maximum number of bytes that may be written to @a str.
 *
 * @return Returns true if the character was appended successfully, false
 * if the character limit was reached.
 */
static inline bool append_char(char *str, char c, int *cursor, int limit) {
    if (*cursor >= limit)
        return false;
    
    str[(*cursor)++] = c;
    return true;
}

/**
 * @internal
 *
 * Record the Mach-O symbol in @a ctx.
 */
static void macho_symbol_callback (pl_vm_address_t address, const char *name, void *ctx) {
    struct symbol_lookup_ctx *lookup_ctx = ctx;

    /* Skip this match if a better match has already been found */
    if (lookup_ctx->found && address < lookup_ctx->symbol_address)
        return;
    
    /* Mark as found */
    lookup_ctx->symbol_address = address;
    lookup_ctx->found = true;

    /* Write out the symbol name; we set the limit with room for a terminating NULL */
    int limit = SYMBOL_NAME_BUFLEN - 1;
    int cursor = 0;

    for (const char *p = name; *p != '\0'; p++)
        if (!append_char(lookup_ctx->buffer, *p, &cursor, limit))
            break;

    append_char(lookup_ctx->buffer, '\0', &cursor, limit+1);
}


/**
 * @internal
 *
 * Record the Objective-C symbol in @a ctx.
 */
static void objc_symbol_callback (bool isClassMethod, plcrash_async_macho_string_t *className, plcrash_async_macho_string_t *methodName, pl_vm_address_t imp, void *ctx) {
    struct symbol_lookup_ctx *lookup_ctx = ctx;
    plcrash_error_t err;

    /* Skip this match if a better match has already been found */
    if (lookup_ctx->found && imp < lookup_ctx->symbol_address)
        return;

    /* Get the string data. */
    pl_vm_size_t classNameLength;
    const char *classNamePtr;    
    if ((err = plcrash_async_macho_string_get_length(className, &classNameLength)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("plcrash_async_macho_string_get_length(className) error %d", err);
        return;
    }

    if ((err = plcrash_async_macho_string_get_pointer(className, &classNamePtr)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("plcrash_async_macho_string_get_pointer(className) error %d", err);
        return;
    }

    pl_vm_size_t methodNameLength;
    const char *methodNamePtr;
    
    if ((err = plcrash_async_macho_string_get_length(methodName, &methodNameLength)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("plcrash_async_macho_string_get_length(methodName) error %d", err);
        return;
    }
    
    if ((err = plcrash_async_macho_string_get_pointer(methodName, &methodNamePtr)) != PLCRASH_ESUCCESS) {
        PLCF_DEBUG("plcrash_async_macho_string_get_pointer(methodName) error %d", err);
        return;
    }

    /* Write out the symbol name; we set the limit with room for a terminating NULL */
    int limit = SYMBOL_NAME_BUFLEN - 1;
    int cursor = 0;

    append_char(lookup_ctx->buffer, isClassMethod ? '+' : '-', &cursor, limit);
    append_char(lookup_ctx->buffer, '[', &cursor, limit);

    for (pl_vm_size_t i = 0; i < classNameLength; i++) {
        bool success = append_char(lookup_ctx->buffer, classNamePtr[i], &cursor, limit);
        if (!success)
            break;
    }
    
    append_char(lookup_ctx->buffer, ' ', &cursor, limit);
    
    for (pl_vm_size_t i = 0; i < methodNameLength; i++) {
        bool success = append_char(lookup_ctx->buffer, methodNamePtr[i], &cursor, limit);
        if (!success)
            break;
    }

    append_char(lookup_ctx->buffer, ']', &cursor, limit);

    /* NULL terminate */
    append_char(lookup_ctx->buffer, '\0', &cursor, limit+1);

    /* Save the address. */
    lookup_ctx->symbol_address = imp;

    /* Mark as found */
    lookup_ctx->found = true;
}

/*
 * @}
 */
