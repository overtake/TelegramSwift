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

#include "PLCrashAsync.h"

#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <inttypes.h>

/**
 * @internal
 * @defgroup plcrash_async Async Safe Utilities
 * @ingroup plcrash_internal
 *
 * Implements async-safe utility functions
 *
 * @{
 */


/* Simple byteswap wrappers */
static uint16_t plcr_swap16 (uint16_t input) {
    return OSSwapInt16(input);
}

static uint16_t plcr_nswap16 (uint16_t input) {
    return input;
}

static uint32_t plcr_swap32 (uint32_t input) {
    return OSSwapInt32(input);
}

static uint32_t plcr_nswap32 (uint32_t input) {
    return input;
}

static uint64_t plcr_swap64 (uint64_t input) {
    return OSSwapInt64(input);
}

static uint64_t plcr_nswap64 (uint64_t input) {
    return input;
}

/**
 * Byte swap functions for a target using the reverse of the host's byte order.
 */
const plcrash_async_byteorder_t plcrash_async_byteorder_swapped = {
    .swap16 = plcr_swap16,
    .swap32 = plcr_swap32,
    .swap64 = plcr_swap64
};

/**
 * Byte swap functions for a target using the host's byte order. No swapping will be performed.
 */
const plcrash_async_byteorder_t plcrash_async_byteorder_direct = {
    .swap16 = plcr_nswap16,
    .swap32 = plcr_nswap32,
    .swap64 = plcr_nswap64
};

/**
 * Return byte order functions that may be used to swap to/from little endian to host byte order.
 */
extern const plcrash_async_byteorder_t *plcrash_async_byteorder_little_endian (void) {
#if defined(__LITTLE_ENDIAN__)
    return &plcrash_async_byteorder_direct;
#elif defined(__BIG_ENDIAN__)
    return &plcrash_async_byteorder_swapped;
#else
#error Unknown byte order
#endif
}

/**
 * Return byte order functions that may be used to swap to/from big endian to host byte order.
 */
extern const plcrash_async_byteorder_t *plcrash_async_byteorder_big_endian (void) {
#if defined(__LITTLE_ENDIAN__)
    return &plcrash_async_byteorder_swapped;
#elif defined(__BIG_ENDIAN__)
    return &plcrash_async_byteorder_direct;
#else
#error Unknown byte order
#endif
}

/**
 * Return an error description for the given plcrash_error_t.
 */
const char *plcrash_async_strerror (plcrash_error_t error) {
    switch (error) {
        case PLCRASH_ESUCCESS:
            return "No error";
        case PLCRASH_EUNKNOWN:
            return "Unknown error";
        case PLCRASH_OUTPUT_ERR:
            return "Output file can not be opened (or written to)";
        case PLCRASH_ENOMEM:
            return "No memory available";
        case PLCRASH_ENOTSUP:
            return "Operation not supported";
        case PLCRASH_EINVAL:
            return "Invalid argument";
        case PLCRASH_EINTERNAL:
            return "Internal error";
        case PLCRASH_EACCESS:
            return "Access denied";
        case PLCRASH_ENOTFOUND:
            return "Not found";
        case PLCRASH_EINVALID_DATA:
            return "The input data is in an unknown or invalid format.";
    }
    
    /* Should be unreachable */
    return "Unhandled error code";
}

/**
 * Safely add @a offset to @a base_address, returning the result in @a result. If an overflow would occur, false is returned.
 *
 * @param base_address The base address from which @a result will be computed.
 * @param offset The offset to apply to @a base_address.
 * @param result The location in which to store the result.
 */
bool plcrash_async_address_apply_offset (pl_vm_address_t base_address, pl_vm_off_t offset, pl_vm_address_t *result) {
    /* Check for overflow */
    if (offset > 0 && PL_VM_ADDRESS_MAX - offset < base_address) {
        return false;
    } else if (offset < 0 && (offset * -1) > base_address) {
        return false;
    }
    
    if (result != NULL)
        *result = base_address + offset;
    
    return true;
}


/**
 * Return a borrowed reference to the current thread's mach port. This differs
 * from mach_thread_self(), which acquires a new reference to the backing thread.
 *
 * @note The mach_thread_self() reference counting semantics differ from mach_task_self();
 * mach_task_self() returns a borrowed reference, and will not leak -- a wrapper
 * function such as this is not required for mach_task_self().
 */
thread_t pl_mach_thread_self (void) {
    thread_t result = mach_thread_self();
    mach_port_deallocate(mach_task_self(), result);
    return result;
}

/**
 * Copy @a len bytes from @a task, at @a address + @a offset, storing in @a dest. If the page(s) at the
 * given @a address + @a offset are unmapped or unreadable, no copy will be performed and an error will
 * be returned.
 *
 * @param task The task from which data from address @a source will be read.
 * @param address The base address within @a task from which the data will be read.
 * @param offset The offset from @a address at which data will be read.
 * @param dest The destination address to which copied data will be written.
 * @param len The number of bytes to be read.
 *
 * @return On success, returns PLCRASH_ESUCCESS. If the pages containing @a source + len are unmapped, PLCRASH_ENOTFOUND
 * will be returned. If the pages can not be read due to access restrictions, PLCRASH_EACCESS will be returned. If
 * the proivded address + offset would overflow pl_vm_address_t, PLCRASH_ENOMEM is returned.
 */
plcrash_error_t plcrash_async_task_memcpy (mach_port_t task, pl_vm_address_t address, pl_vm_off_t offset, void *dest, pl_vm_size_t len) {
    pl_vm_address_t target;
    kern_return_t kt;

    /* Compute the target address and check for overflow */
    if (!plcrash_async_address_apply_offset(address, offset, &target))
        return PLCRASH_ENOMEM;

#ifdef PL_HAVE_MACH_VM
    pl_vm_size_t read_size = len;
    kt = mach_vm_read_overwrite(task, target, len, (pointer_t) dest, &read_size);
#else
    vm_size_t read_size = len;
    kt = vm_read_overwrite(task, target, len, (pointer_t) dest, &read_size);
#endif
    
    switch (kt) {
        case KERN_SUCCESS:
            return PLCRASH_ESUCCESS;

        case KERN_INVALID_ADDRESS:
            return PLCRASH_ENOTFOUND;
            
        case KERN_PROTECTION_FAILURE:
            return PLCRASH_EACCESS;

        default:
            PLCF_DEBUG("Unexpected error from vm_read_overwrite: %d", kt);
            return PLCRASH_EUNKNOWN;
    }
}

/**
 * Read an 8-bit value from @a task, at @a address + @a offset, storing in @a dest. If the page(s) at the
 * given @a address + @a offset are unmapped or unreadable, no copy will be performed and an error will
 * be returned.
 *
 * @param task Task from which to read the value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written, after @a byteorder has been applied.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_task_read_uint8 (task_t task, pl_vm_address_t address, pl_vm_off_t offset, uint8_t *result) {
    return plcrash_async_task_memcpy(task, address, offset, result, sizeof(*result));
}

/**
 * Read a 16-bit value from @a task, at @a address + @a offset, performing byte-swapping using @a byteorder,
 * and store in @a dest.
 *
 * If the page(s) at the given @a address + @a offset are unmapped or unreadable, no copy will be performed and an error will
 * be returned.
 *
 * @param task Task from which to read the value.
 * @param byteorder Byte order of the target value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written, after @a byteorder has been applied.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_task_read_uint16 (task_t task, const plcrash_async_byteorder_t *byteorder,
                                                pl_vm_address_t address, pl_vm_off_t offset, uint16_t *result)
{
    plcrash_error_t err = plcrash_async_task_memcpy(task, address, offset, result, sizeof(*result));
    *result = byteorder->swap16(*result);
    return err;
}

/**
 * Read a 32-bit value from @a task, at @a address + @a offset, performing byte-swapping using @a byteorder,
 * and store in @a dest.
 *
 * If the page(s) at the given @a address + @a offset are unmapped or unreadable, no copy will be performed and an error will
 * be returned.
 *
 * @param task Task from which to read the value.
 * @param byteorder Byte order of the target value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written, after @a byteorder has been applied.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_task_read_uint32 (task_t task, const plcrash_async_byteorder_t *byteorder,
                                                pl_vm_address_t address, pl_vm_off_t offset, uint32_t *result)
{
    plcrash_error_t err = plcrash_async_task_memcpy(task, address, offset, result, sizeof(*result));
    *result = byteorder->swap32(*result);
    return err;
}

/**
 * Read a 64-bit value from @a task, at @a address + @a offset, performing byte-swapping using @a byteorder,
 * and store in @a dest.
 *
 * If the page(s) at the given @a address + @a offset are unmapped or unreadable, no copy will be performed and an error will
 * be returned.
 *
 * @param task Task from which to read the value.
 * @param byteorder Byte order of the target value.
 * @param address The base address to be read. This address should be relative to the target task's address space.
 * @param offset An offset to be applied to @a address.
 * @param result The destination to which the data will be written, after @a byteorder has been applied.
 *
 * @return Returns PLCRASH_ESUCCESS on success, PLCRASH_EINVAL if the target address does not fall within the @a mobj address
 * range, or one of the plcrash_error_t constants for other error conditions.
 */
plcrash_error_t plcrash_async_task_read_uint64 (task_t task, const plcrash_async_byteorder_t *byteorder,
                                                pl_vm_address_t address, pl_vm_off_t offset, uint64_t *result)
{
    plcrash_error_t err = plcrash_async_task_memcpy(task, address, offset, result, sizeof(*result));
    *result = byteorder->swap64(*result);
    return err;
}

/**
 * An intentionally naive async-safe implementation of strcmp(). strcmp() itself is not declared to be async-safe,
 * though in reality, it is.
 *
 * @param s1 First string.
 * @param s2 Second string.
 * @return Return an integer greater than, equal to, or less than 0, according as the string @a s1 is greater than,
 * equal to, or less than the string @a s2.
 */
int plcrash_async_strcmp(const char *s1, const char *s2) {
    while (*s1 == *s2++) {
        if (*s1++ == 0)
            return (0);
    }
    
    return (*(const unsigned char *)s1 - *(const unsigned char *)(s2 - 1));
}

/**
 * An intentionally naive async-safe implementation of strncmp(). strncmp() itself is not declared to be async-safe,
 * though in reality, it is.
 *
 * @param s1 First string.
 * @param s2 Second string.
 * @param n No more than n characters will be compared.
 * @return Return an integer greater than, equal to, or less than 0, according as the string @a s1 is greater than,
 * equal to, or less than the string @a s2.
 */
int plcrash_async_strncmp(const char *s1, const char *s2, size_t n) {
    while (*s1 == *s2++ && n-- > 0) {
        if (*s1++ == 0)
            return (0);
    }
    
    if (n == 0)
        return 0;

    return (*(const unsigned char *)s1 - *(const unsigned char *)(s2 - 1));
}

/**
 * An intentionally naive async-safe implementation of memcpy(). memcpy() itself is not declared to be async-safe,
 * though in reality, it is.
 *
 * @param dest Destination.
 * @param source Source.
 * @param n Number of bytes to copy.
 */
void *plcrash_async_memcpy (void *dest, const void *source, size_t n) {
    uint8_t *s = (uint8_t *) source;
    uint8_t *d = (uint8_t *) dest;

    for (size_t count = 0; count < n; count++)
        *d++ = *s++;

    return (void *) source;
}

/**
 * An intentionally naive async-safe implementation of memset(). memset() itself is not declared to be async-safe,
 * though in reality, it is.
 *
 * @param dest Destination.
 * @param value Value to write to @a dest.
 * @param n Number of bytes to copy.
 */
void *plcrash_async_memset(void *dest, uint8_t value, size_t n) {
    uint8_t *d = (uint8_t *) dest;
    
    for (size_t count = 0; count < n; count++)
        *d++ = value;

    return (void *) dest;
}

/**
 * @internal
 * @ingroup plcrash_async
 * @defgroup plcrash_async_bufio Async-safe Buffered IO
 * @{
 */

/**
 * 
 * Write len bytes to fd, looping until all bytes are written
 * or an error occurs. For the local file system, only one call to write()
 * should be necessary
 */
ssize_t plcrash_async_writen (int fd, const void *data, size_t len) {
    const uint8_t *p;
    size_t left;
    ssize_t written = 0;
    
    /* Loop until all bytes are written */
    p = (const uint8_t *) data;
    left = len;
    while (left > 0) {
        if ((written = write(fd, p, left)) <= 0) {
            if (errno == EINTR) {
                // Try again
                written = 0;
            } else {
                return -1;
            }
        }
        
        left -= written;
        p += written;
    }
    
    return written;
}


/**
 * Initialize the plcrash_async_file_t instance.
 *
 * @param file File structure to initialize.
 * @param output_limit Maximum number of bytes that will be written to disk. Intended as a
 * safety measure prevent a run-away crash log writer from filling the disk. Specify
 * 0 to disable any limits. Once the limit is reached, all data will be dropped.
 * @param fd Open file descriptor.
 */
void plcrash_async_file_init (plcrash_async_file_t *file, int fd, off_t output_limit) {
    file->fd = fd;
    file->buflen = 0;
    file->total_bytes = 0;
    file->limit_bytes = output_limit;
}


/**
 * Write all bytes from @a data to the file buffer. Returns true on success,
 * or false if an error occurs.
 */
bool plcrash_async_file_write (plcrash_async_file_t *file, const void *data, size_t len) {
    /* Check and update output limit */
    if (file->limit_bytes != 0 && len + file->total_bytes > file->limit_bytes) {
        return false;
    } else if (file->limit_bytes != 0) {
        file->total_bytes += len;
    }

    /* Check if the buffer will fill */
    if (file->buflen + len > sizeof(file->buffer)) {
        /* Flush the buffer */
        if (plcrash_async_writen(file->fd, file->buffer, file->buflen) < 0) {
            PLCF_DEBUG("Error occured writing to crash log: %s", strerror(errno));
            return false;
        }
        
        file->buflen = 0;
    }
    
    /* Check if the new data fits within the buffer, if so, buffer it */
    if (len + file->buflen <= sizeof(file->buffer)) {
        plcrash_async_memcpy(file->buffer + file->buflen, data, len);
        file->buflen += len;
        
        return true;
        
    } else {
        /* Won't fit in the buffer, just write it */
        if (plcrash_async_writen(file->fd, data, len) < 0) {
            PLCF_DEBUG("Error occured writing to crash log: %s", strerror(errno));
            return false;
        }
        
        return true;
    } 
}


/**
 * Flush all buffered bytes from the file buffer.
 */
bool plcrash_async_file_flush (plcrash_async_file_t *file) {
    /* Anything to do? */
    if (file->buflen == 0)
        return true;
    
    /* Write remaining */
    if (plcrash_async_writen(file->fd, file->buffer, file->buflen) < 0) {
        PLCF_DEBUG("Error occured writing to crash log: %s", strerror(errno));
        return false;
    }
    
    file->buflen = 0;
    
    return true;
}


/**
 * Close the backing file descriptor.
 */
bool plcrash_async_file_close (plcrash_async_file_t *file) {
    /* Flush any pending data */
    if (!plcrash_async_file_flush(file))
        return false;

    /* Close the file descriptor */
    if (close(file->fd) != 0) {
        PLCF_DEBUG("Error closing file: %s", strerror(errno));
        return false;
    }

    return true;
}

/*
 * @} plcrash_async_bufio
 */

/*
 * @} plcrash_async
 */
