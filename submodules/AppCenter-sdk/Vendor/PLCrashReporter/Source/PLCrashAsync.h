/*
 * Author: Landon Fuller <landonf@plausible.coop>
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

#ifndef PLCRASH_ASYNC_H
#define PLCRASH_ASYNC_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h> // for snprintf
#include <unistd.h>
#include <stdbool.h>
#include <stddef.h>
#include <assert.h>

#include <TargetConditionals.h>
#include <mach/mach.h>

#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST

/*
 * iOS does not provide the mach_vm_* APIs, and as such, we can't support both
 * 32-bit/64-bit tasks via the same APIs.
 *
 * In practice, this currently does not matter for iOS as out-of-process execution
 * is not permitted; in-process reporting will always target the host process'
 * address width.
 */

/** The largest address value that can be represented via the pl_vm_address_t type. */
#ifdef __LP64__
#define PL_VM_ADDRESS_MAX UINT64_MAX
#else
#define PL_VM_ADDRESS_MAX UINT32_MAX
#endif

/** The largest address value that can be represented via the pl_vm_size_t type. */
#ifdef __LP64__
#define PL_VM_SIZE_MAX UINT64_MAX
#else
#define PL_VM_SIZE_MAX UINT32_MAX
#endif

/** The largest offset value that can be represented via the pl_vm_off_t type. */
#define PL_VM_OFF_MAX PTRDIFF_MAX

/** The smallest offset value that can be represented via the pl_vm_off_t type. */
#define PL_VM_OFF_MIN PTRDIFF_MIN

/** VM address type. 
 * @ingroup plcrash_async */
typedef vm_address_t pl_vm_address_t;

/** VM size type.
 * @ingroup plcrash_async */
typedef vm_size_t pl_vm_size_t;

/** VM offset type.
 * @ingroup plcrash_async */
typedef ptrdiff_t pl_vm_off_t;

#else

#include <mach/mach_vm.h>
#define PL_HAVE_MACH_VM 1

/** The largest address value that can be represented via the pl_vm_address_t type. */
#define PL_VM_ADDRESS_MAX UINT64_MAX

/** The largest address value that can be represented via the pl_vm_size_t type. */
#define PL_VM_SIZE_MAX UINT64_MAX

/** The largest offset value that can be represented via the pl_vm_off_t type. */
#define PL_VM_OFF_MAX INT64_MAX

/** The smallest offset value that can be represented via the pl_vm_off_t type. */
#define PL_VM_OFF_MIN INT64_MIN

/** Architecture-independent VM address type.
 * @ingroup plcrash_async */
typedef mach_vm_address_t pl_vm_address_t;

/** Architecture-independent VM size type. 
 * @ingroup plcrash_async */
typedef mach_vm_size_t pl_vm_size_t;

/** Architecture-independent VM offset type.
 * @ingroup plcrash_async */
typedef int64_t pl_vm_off_t;

#endif /* TARGET_OS_IPHONE */

/** An invalid address value. */
#define PL_VM_ADDRESS_INVALID PL_VM_ADDRESS_MAX

// assert() support. We prefer to leave assertions on in release builds, but need
// to disable them in async-safe code paths.
#ifdef PLCF_RELEASE_BUILD

#define PLCF_ASSERT(expr)

#else

#define PLCF_ASSERT(expr) assert(expr)

#endif /* PLCF_RELEASE_BUILD */

// Debug output support. Lines are capped at 128 (stack space is scarce). This implemention
// is not async-safe and should not be enabled in release builds
#ifdef PLCF_RELEASE_BUILD

#define PLCF_DEBUG(msg, args...)

#else

#define PLCF_DEBUG(msg, args...) {\
    char __tmp_output[128];\
    snprintf(__tmp_output, sizeof(__tmp_output), "[PLCrashReporter] "); \
    plcrash_async_writen(STDERR_FILENO, __tmp_output, strlen(__tmp_output));\
    \
    snprintf(__tmp_output, sizeof(__tmp_output), ":%d: ", __LINE__); \
    plcrash_async_writen(STDERR_FILENO, __func__, strlen(__func__));\
    plcrash_async_writen(STDERR_FILENO, __tmp_output, strlen(__tmp_output));\
    \
    snprintf(__tmp_output, sizeof(__tmp_output), msg, ## args); \
    plcrash_async_writen(STDERR_FILENO, __tmp_output, strlen(__tmp_output));\
    \
    __tmp_output[0] = '\n'; \
    plcrash_async_writen(STDERR_FILENO, __tmp_output, 1); \
}

#endif /* PLCF_RELEASE_BUILD */


/**
 * @ingroup plcrash_async
 * Error return codes.
 */
typedef enum  {
    /** Success */
    PLCRASH_ESUCCESS = 0,
    
    /** Unknown error (if found, is a bug) */
    PLCRASH_EUNKNOWN,
    
    /** The output file can not be opened or written to */
    PLCRASH_OUTPUT_ERR,
    
    /** No memory available (allocation failed) */
    PLCRASH_ENOMEM,
    
    /** Unsupported operation */
    PLCRASH_ENOTSUP,
    
    /** Invalid argument */
    PLCRASH_EINVAL,
    
    /** Internal error */
    PLCRASH_EINTERNAL,

    /** Access to the specified resource is denied. */
    PLCRASH_EACCESS,

    /** The requested resource could not be found. */
    PLCRASH_ENOTFOUND,
    
    /** The input data is in an unknown or invalid format. */
    PLCRASH_EINVALID_DATA,
} plcrash_error_t;

const char *plcrash_async_strerror (plcrash_error_t error);

bool plcrash_async_address_apply_offset (pl_vm_address_t base_address, pl_vm_off_t offset, pl_vm_address_t *result);
    
thread_t pl_mach_thread_self (void);

/**
 * @internal
 * @ingroup plcrash_async
 *
 * Provides a set of byteswap functions that will swap from the target byte order to the host byte order.
 * This is used to provide byte order neutral polymorphism when parsing Mach-O and other file formats.
 */
typedef struct plcrash_async_byteorder {
    /** The byte-swap function to use for 16-bit values. */
    uint16_t (*swap16)(uint16_t);
    
    /** The byte-swap function to use for 32-bit values. */
    uint32_t (*swap32)(uint32_t);
    
    /** The byte-swap function to use for 64-bit values. */
    uint64_t (*swap64)(uint64_t);
    
#ifdef __cplusplus
public:
    /** Byte swap a 16-bit value */
    uint16_t swap (uint16_t v) const { return swap16(v); }
    
    /** Byte swap a 32-bit value */
    uint32_t swap (uint32_t v) const { return swap32(v); }
    
    /** Byte swap a 64-bit value */
    uint64_t swap (uint64_t v) const { return swap64(v); }
#endif
} plcrash_async_byteorder_t;

extern const plcrash_async_byteorder_t plcrash_async_byteorder_swapped;
extern const plcrash_async_byteorder_t plcrash_async_byteorder_direct;

extern const plcrash_async_byteorder_t *plcrash_async_byteorder_little_endian (void);
extern const plcrash_async_byteorder_t *plcrash_async_byteorder_big_endian (void);


plcrash_error_t plcrash_async_task_memcpy (mach_port_t task, pl_vm_address_t address, pl_vm_off_t offset, void *dest, pl_vm_size_t len);

plcrash_error_t plcrash_async_task_read_uint8 (task_t task, pl_vm_address_t address, pl_vm_off_t offset, uint8_t *result);

plcrash_error_t plcrash_async_task_read_uint16 (task_t task, const plcrash_async_byteorder_t *byteorder,
                                                pl_vm_address_t address, pl_vm_off_t offset, uint16_t *result);

plcrash_error_t plcrash_async_task_read_uint32 (task_t task, const plcrash_async_byteorder_t *byteorder,
                                                pl_vm_address_t address, pl_vm_off_t offset, uint32_t *result);

plcrash_error_t plcrash_async_task_read_uint64 (task_t task, const plcrash_async_byteorder_t *byteorder,
                                                pl_vm_address_t address, pl_vm_off_t offset, uint64_t *result);

int plcrash_async_strcmp(const char *s1, const char *s2);
int plcrash_async_strncmp(const char *s1, const char *s2, size_t n);
void *plcrash_async_memcpy(void *dest, const void *source, size_t n);
void *plcrash_async_memset(void *dest, uint8_t value, size_t n);

ssize_t plcrash_async_writen (int fd, const void *data, size_t len);

/**
 * @internal
 * @ingroup plcrash_async_bufio
 *
 * Async-safe buffered file output. This implementation is only intended for use
 * within signal handler execution of crash log output.
 */
typedef struct plcrash_async_file {
    /** Output file descriptor */
    int fd;

    /** Output limit */
    off_t limit_bytes;

    /** Total bytes written */
    off_t total_bytes;

    /** Current length of data in buffer */
    size_t buflen;

    /** Buffered output */
    char buffer[256];
} plcrash_async_file_t;


void plcrash_async_file_init (plcrash_async_file_t *file, int fd, off_t output_limit);
bool plcrash_async_file_write (plcrash_async_file_t *file, const void *data, size_t len);
bool plcrash_async_file_flush (plcrash_async_file_t *file);
bool plcrash_async_file_close (plcrash_async_file_t *file);
    
#ifdef __cplusplus
}
#endif

#endif /* PLCRASH_ASYNC_H */
