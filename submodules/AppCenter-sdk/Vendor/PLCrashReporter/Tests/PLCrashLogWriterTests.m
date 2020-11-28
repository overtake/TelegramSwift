/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
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

#import "PLCrashLogWriter.h"
#import "PLCrashFrameWalker.h"
#import "PLCrashAsyncImageList.h"
#import "PLCrashReport.h"
#import "PLCrashReport.pb-c.h"

#import "PLCrashProcessInfo.h"
#import "PLCrashHostInfo.h"

#import <sys/stat.h>
#import <sys/mman.h>
#import <fcntl.h>
#import <dlfcn.h>

#import <mach-o/loader.h>
#import <mach-o/dyld.h>

#import "PLCrashTestThread.h"
#import "PLCrashSysctl.h"

@interface PLCrashLogWriterTests : SenTestCase {
@private
    /* Path to crash log */
    __strong NSString *_logPath;
    
    /* Test thread */
    plcrash_test_thread_t _thr_args;
}

@end


@implementation PLCrashLogWriterTests

- (void) setUp {
    /* Create a temporary log path */
    _logPath = [NSTemporaryDirectory() stringByAppendingString: [[NSProcessInfo processInfo] globallyUniqueString]];
    
    /* Create the test thread */
    plcrash_test_thread_spawn(&_thr_args);
}

- (void) tearDown {
    NSError *error;
    
    /* Delete the file */
    if ([[NSFileManager defaultManager] fileExistsAtPath: _logPath]) {
        STAssertTrue([[NSFileManager defaultManager] removeItemAtPath: _logPath error: &error], @"Could not remove log file");
    }
    _logPath = nil;

    /* Stop the test thread */
    plcrash_test_thread_stop(&_thr_args);
}

// check a crash report's system info
- (void) checkSystemInfo: (Plcrash__CrashReport *) crashReport {
    Plcrash__CrashReport__SystemInfo *systemInfo = crashReport->system_info;

    STAssertNotNULL(systemInfo, @"No system info available");
    // Nothing else to do?
    if (systemInfo == NULL)
        return;

    STAssertEquals((int) systemInfo->operating_system, PLCrashReportHostOperatingSystem, @"Unexpected OS value");
    
    STAssertNotNULL(systemInfo->os_version, @"No OS version encoded");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    STAssertEquals((int) systemInfo->architecture, PLCrashReportHostArchitecture, @"Unexpected machine type");
#pragma clang diagnostic pop

    STAssertTrue(systemInfo->timestamp != 0, @"Timestamp uninitialized");
}

// check a crash report's app info
- (void) checkAppInfo: (Plcrash__CrashReport *) crashReport {
    Plcrash__CrashReport__ApplicationInfo *appInfo = crashReport->application_info;
    
    STAssertNotNULL(appInfo, @"No app info available");
    // Nothing else to do?
    if (appInfo == NULL)
        return;

    STAssertTrue(strcmp(appInfo->identifier, "test.id") == 0, @"Incorrect app ID written");
    STAssertTrue(strcmp(appInfo->version, "1.0") == 0, @"Incorrect app version written");
    STAssertTrue(strcmp(appInfo->marketing_version, "2.0") == 0, @"Incorrect app marketing version written");
}

// check a crash report's process info
- (void) checkProcessInfo: (Plcrash__CrashReport *) crashReport {
    Plcrash__CrashReport__ProcessInfo *procInfo = crashReport->process_info;
    
    STAssertNotNULL(procInfo, @"No process info available");
    // Nothing else to do?
    if (procInfo == NULL)
        return;

    STAssertEquals((pid_t)procInfo->process_id, getpid(), @"Incorrect process id written");
    STAssertEquals((pid_t)procInfo->parent_process_id, getppid(), @"Incorrect parent process id written");
    
    STAssertTrue(procInfo->has_start_time, @"Missing start time value");
    STAssertTrue(time(NULL) >= procInfo->start_time, @"Recorded time occured in the future");
    STAssertTrue(time(NULL) - procInfo->start_time <= 60, @"Recorded time differs from the current time by more than 1 minute");

    int retval;
    if (plcrash_sysctl_int("sysctl.proc_native", &retval)) {
        if (retval == 0) {
            STAssertTrue(procInfo->native, @"Our current process is marked as non-native");
        } else {
            STAssertTrue(procInfo->native, @"Our current process is marked as native");
        }
    } else {
        /* If the sysctl is not available, the process can be assumed to be native. */
        STAssertTrue(procInfo->native, @"No proc_native sysctl specified; native should be assumed");
    }

    /* Fetch and verify process data */
    PLCrashProcessInfo *processInfo = [PLCrashProcessInfo currentProcessInfo];
    STAssertNotNil(processInfo, @"Could not retrieve process info");
    STAssertNotNil(processInfo.processName, @"Could not retrieve parent process name");

    NSString *parsedProcessName = [[NSString alloc] initWithCString: procInfo->process_name encoding: NSUTF8StringEncoding];
    STAssertNotNil(parsedProcessName, @"Process name contains invalid UTF-8");
    STAssertEqualStrings(parsedProcessName, processInfo.processName, @"Incorrect process name");


    /* Current process path */
    char *process_path = NULL;
    uint32_t process_path_len = 0;
    
    _NSGetExecutablePath(NULL, &process_path_len);
    if (process_path_len > 0) {
        process_path = malloc(process_path_len);
        _NSGetExecutablePath(process_path, &process_path_len);
        STAssertEqualCStrings(procInfo->process_path, process_path, @"Incorrect process name");
        free(process_path);
    }
    
    /* Parent process; fetching the process info is expected to fail on non-OSX systems (e.g. iOS 9+ and tvOS) due to
     * new sandbox constraints */
    PLCrashProcessInfo *parentProcessInfo = [[PLCrashProcessInfo alloc] initWithProcessID: getppid()];

    if (PLCrashReportHostOperatingSystem == PLCrashReportOperatingSystemAppleTVOS ||
        (PLCrashReportHostOperatingSystem == PLCrashReportOperatingSystemiPhoneOS &&
         PLCrashHostInfo.currentHostInfo.darwinVersion.major >= PLCRASH_HOST_IOS_DARWIN_MAJOR_VERSION_9))
    {
        STAssertNil(parentProcessInfo, @"Fetching parent process info unexpectedly succeeded on iOS-derived OS");
        STAssertNULL(procInfo->parent_process_name, @"Fetching parent process info unexpectedly succeeded on iOS-derived OS");
        
    } else {
        STAssertNotNil(parentProcessInfo, @"Could not retrieve parent process info");
        STAssertNotNil(parentProcessInfo.processName, @"Could not retrieve parent process name");
        STAssertNotNULL(procInfo->parent_process_name, @"Crash log writer could not retrieve parent process name");
        
        NSString *parsedParentProcessName = [[NSString alloc] initWithCString: procInfo->parent_process_name encoding: NSUTF8StringEncoding];
        STAssertNotNil(parsedParentProcessName, @"Process name contains invalid UTF-8");
        STAssertEqualStrings(parsedParentProcessName, parentProcessInfo.processName, @"Incorrect process name");

    }
}

- (void) checkThreads: (Plcrash__CrashReport *) crashReport {
    Plcrash__CrashReport__Thread **threads = crashReport->threads;
    BOOL foundCrashed = NO;

    STAssertNotNULL(threads, @"No thread messages were written");
    STAssertTrue(crashReport->n_threads > 0, @"0 thread messages were written");

    uint32_t lastThreadNumber;
    for (int i = 0; i < crashReport->n_threads; i++) {
        Plcrash__CrashReport__Thread *thread = threads[i];

        /* Check that the threads are provided in order */
        if (i > 0) {
            STAssertTrue(lastThreadNumber < thread->thread_number, @"Threads were encoded out of order (%d vs %d)", i, thread->thread_number);
        }
        lastThreadNumber = thread->thread_number;
        
        /* Check that there is at least one frame */
        STAssertNotEquals((size_t)0, thread->n_frames, @"No frames available in backtrace");
        
        /* Check for crashed thread */
        if (thread->crashed) {
            foundCrashed = YES;
            STAssertNotEquals((size_t)0, thread->n_registers, @"No registers available on crashed thread");
        }
        
        for (int j = 0; j < thread->n_frames; j++) {
            Plcrash__CrashReport__Thread__StackFrame *f = thread->frames[j];

            /* It is possible for a mach thread to have pc=0 in the first frame. This is the case when a mach thread is
             * first created -- its initial state is 0, and it has a suspend count of 1. */
            if (j > 0)
                STAssertNotEquals((uint64_t)0, f->pc, @"Backtrace includes NULL pc");
        }
    }

    STAssertTrue(foundCrashed, @"No crashed thread was provided");
}

- (void) checkBinaryImages: (Plcrash__CrashReport *) crashReport {
    Plcrash__CrashReport__BinaryImage **images = crashReport->binary_images;

    STAssertNotNULL(images, @"No image messages were written");
    STAssertTrue(crashReport->n_binary_images, @"0 thread messages were written");

    for (int i = 0; i < crashReport->n_binary_images; i++) {
        Plcrash__CrashReport__BinaryImage *image = images[i];
        
        STAssertNotNULL(image->name, @"Null image name");
        STAssertTrue(image->name[0] == '/', @"Image is not absolute path");
        STAssertNotNULL(image->code_type, @"Null code type");
        STAssertEquals(image->code_type->encoding, PLCrashReportProcessorTypeEncodingMach, @"Incorrect type encoding");

        /*
         * Find the in-memory mach header for the image record. We'll compare this against the serialized data.
         *
         * The 32-bit and 64-bit mach_header structures are equivalent for our purposes.
         */ 
        Dl_info info;
        STAssertTrue(dladdr((void *)(uintptr_t)image->base_address, &info) != 0, @"dladdr() failed to find image");
        struct mach_header *hdr = info.dli_fbase;
        STAssertEquals(image->code_type->type, hdr->cputype, @"Incorrect CPU type");
        STAssertEquals(image->code_type->subtype, hdr->cpusubtype, @"Incorrect CPU subtype");
    }
}

- (void) checkException: (Plcrash__CrashReport *) crashReport {
    Plcrash__CrashReport__Exception *exception = crashReport->exception;
    
    STAssertNotNULL(exception, @"No exception was written");
    STAssertTrue(strcmp(exception->name, "TestException") == 0, @"Exception name was not correctly serialized");
    STAssertTrue(strcmp(exception->reason, "TestReason") == 0, @"Exception reason was not correctly serialized");

    STAssertTrue(exception->n_frames, @"0 exception frames were written");
    for (int i = 0; i < exception->n_frames; i++) {
        Plcrash__CrashReport__Thread__StackFrame *f = exception->frames[i];
        STAssertNotEquals((uint64_t)0, f->pc, @"Backtrace includes NULL pc");
    }
}

- (void) checkCustomData: (Plcrash__CrashReport *) crashReport {
    STAssertTrue(crashReport->has_custom_data, @"No custom data was written");
    ProtobufCBinaryData customData = crashReport->custom_data;
    NSData *data = [NSData dataWithBytes:customData.data length:customData.len];
    NSString *dataString =[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    STAssertTrue([dataString isEqualToString:@"DummyInfo"],  @"Custom data was not correctly serialized");
}

- (Plcrash__CrashReport *) loadReport {
    /* Reading the report */
    NSData *data = [NSData dataWithContentsOfFile:_logPath options:NSDataReadingMappedAlways error:nil];
    STAssertNotNil(data, @"Could not map pages");
    
    /* Check the file magic. The file must be large enough for the value + version + data */
    const struct PLCrashReportFileHeader *header = [data bytes];
    STAssertTrue([data length] > sizeof(struct PLCrashReportFileHeader), @"File is too small for magic + version + data");
    // verifies correct byte ordering of the file magic
    STAssertTrue(memcmp(header->magic, PLCRASH_REPORT_FILE_MAGIC, strlen(PLCRASH_REPORT_FILE_MAGIC)) == 0, @"File header is not 'plcrash', is: '%s'", (const char *) &header->magic);
    STAssertEquals(header->version, (uint8_t) PLCRASH_REPORT_FILE_VERSION, @"File version is not equal to 0");
    
    /* Try to read the crash report */
    Plcrash__CrashReport *crashReport;
    crashReport = plcrash__crash_report__unpack(NULL, [data length] - sizeof(struct PLCrashReportFileHeader), header->data);
    
    /* If reading the report didn't fail, test the contents */
    STAssertNotNULL(crashReport, @"Could not decode crash report");

    return crashReport;
}

- (void) testDeviceVersionWriter {
    plcrash_log_writer_t writer;

    STAssertEquals(PLCRASH_ESUCCESS, plcrash_log_writer_init(&writer, @"test.id", @"1.0", @"2.0", PLCRASH_ASYNC_SYMBOL_STRATEGY_ALL, false), @"Initialization failed");
    char *version = writer.system_info.version.data;

    STAssertTrue(version && version[0], @"Device version not saved");
}

- (void) testWriteLogWithNilReason {
    plcrash_log_writer_t writer;

    /* Initialize a writer */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_log_writer_init(&writer, @"test.id", @"1.0", @"2.0", PLCRASH_ASYNC_SYMBOL_STRATEGY_ALL, false), @"Initialization failed");

    /* Set an exception without reason */
    NSException *e = [NSException exceptionWithName:@"Exception without reason"
                                             reason:nil
                                           userInfo:nil];

    /* Check that the log entry does not initialize the exception */
    STAssertNoThrow(plcrash_log_writer_set_exception(&writer, e), "Setting an exception failed");
}

- (void) testWriteReport {
    plframe_cursor_t cursor;
    plcrash_log_writer_t writer;
    plcrash_async_file_t file;
    plcrash_async_image_list_t image_list;
    plcrash_async_thread_state_t thread_state;
    thread_t thread;

    /* Initialize the image list */
    plcrash_nasync_image_list_init(&image_list, mach_task_self());
    for (uint32_t i = 0; i < _dyld_image_count(); i++)
        plcrash_nasync_image_list_append(&image_list, (pl_vm_address_t) _dyld_get_image_header(i), _dyld_get_image_name(i));

    /* Initialze faux crash data */
    plcrash_log_signal_info_t info;
    plcrash_log_bsd_signal_info_t bsd_info;
    plcrash_log_mach_signal_info_t mach_info;
    mach_exception_data_type_t mach_codes[2];
    {
        bsd_info.address = (void *) 0x42;
        bsd_info.code = SEGV_MAPERR;
        bsd_info.signo = SIGSEGV;
        
        mach_info.type = EXC_BAD_ACCESS;
        mach_info.code = mach_codes;
        mach_info.code_count = sizeof(mach_codes) / sizeof(mach_codes[0]);
        mach_codes[0] = KERN_PROTECTION_FAILURE;
        mach_codes[1] = 0x42;
    
        info.mach_info = &mach_info;
        info.bsd_info = &bsd_info;
        
        /* Steal the test thread's stack for iteration */
        thread = pthread_mach_thread_np(_thr_args.thread);
        plframe_cursor_thread_init(&cursor, mach_task_self(), thread, &image_list);
        plcrash_async_thread_state_mach_thread_init(&thread_state, thread);
    }

    /* Open the output file */
    int fd = open([_logPath UTF8String], O_RDWR|O_CREAT|O_EXCL, 0644);
    plcrash_async_file_init(&file, fd, 0);

    /* Initialize a writer */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_log_writer_init(&writer, @"test.id", @"1.0", @"2.0", PLCRASH_ASYNC_SYMBOL_STRATEGY_ALL, false), @"Initialization failed");

    /* Set an exception with a valid return address call stack. */
    NSException *e;
    @try {
        [NSException raise: @"TestException" format: @"TestReason"];
    }
    @catch (NSException *exception) {
        e = exception;
    }
    plcrash_log_writer_set_exception(&writer, e);

    /* Set user defined data */
    plcrash_log_writer_set_custom_data(&writer, [@"DummyInfo" dataUsingEncoding:NSUTF8StringEncoding]);

    /* Write the crash report */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_log_writer_write(&writer, thread, &image_list, &file, &info, &thread_state), @"Crash log failed");

    /* Close it */
    plcrash_log_writer_close(&writer);
    plcrash_log_writer_free(&writer);
    plcrash_nasync_image_list_free(&image_list);

    /* Flush the output */
    plcrash_async_file_flush(&file);
    plcrash_async_file_close(&file);

    /* Load and validate the written report */
    Plcrash__CrashReport *crashReport = [self loadReport];
    STAssertNotNULL(crashReport, @"Failed to load report");
    if (crashReport == NULL)
        return;

    STAssertFalse(crashReport->report_info->user_requested, @"Report not correctly marked as non-user-requested");
    STAssertTrue(crashReport->report_info->has_uuid, @"Report missing a UUID value");
    STAssertEquals((size_t)16, crashReport->report_info->uuid.len, @"UUID is not expected 16 bytes");
    {
        CFUUIDBytes uuid_bytes;
        memcpy(&uuid_bytes, crashReport->report_info->uuid.data, sizeof(uuid_bytes));
        CFUUIDRef uuid = CFUUIDCreateFromUUIDBytes(NULL, uuid_bytes);
        STAssertNotNULL(uuid, @"Value not parsable as a UUID");
        if (uuid != NULL)
            CFRelease(uuid);
    }

    /* Test the report */
    [self checkSystemInfo: crashReport];
    [self checkAppInfo: crashReport];
    [self checkProcessInfo: crashReport];
    [self checkThreads: crashReport];
    [self checkException: crashReport];
    [self checkCustomData: crashReport];
    
    /* Check the signal info */
    STAssertTrue(strcmp(crashReport->signal->name, "SIGSEGV") == 0, @"Signal incorrect");
    STAssertTrue(strcmp(crashReport->signal->code, "SEGV_MAPERR") == 0, @"Signal code incorrect");
    STAssertEquals((uint64_t) 0x42, crashReport->signal->address, @"Signal address incorrect");
    
    /* Check the mach exception info */
    STAssertNotNULL(crashReport->signal->mach_exception, @"Missing mach exceptiond info");
    STAssertEquals(crashReport->signal->mach_exception->type, (uint64_t)EXC_BAD_ACCESS, @"Exception type incorrect");
    STAssertEquals((size_t)2, crashReport->signal->mach_exception->n_codes, @"Code count incorrect");
    STAssertEquals((uint64_t) KERN_PROTECTION_FAILURE, crashReport->signal->mach_exception->codes[0], @"code[0] incorrect");
    STAssertEquals((uint64_t) 0x42, crashReport->signal->mach_exception->codes[1], @"code[1] incorrect");


    /* Validate the 'crashed' flag is on a thread with the expected PC. */
    uint64_t expectedPC;
#if __x86_64__
    expectedPC = cursor.frame.thread_state.x86_state.thread.uts.ts64.__rip;
#elif __i386__
    expectedPC = cursor.frame.thread_state.x86_state.thread.uts.ts32.__eip;
#elif __arm__
    expectedPC = cursor.frame.thread_state.arm_state.thread.ts_32.__pc;
#elif __arm64__
#if __DARWIN_OPAQUE_ARM_THREAD_STATE64
    expectedPC = cursor.frame.thread_state.arm_state.thread.ts_64.__opaque_pc;
#else
    expectedPC = cursor.frame.thread_state.arm_state.thread.ts_64.__pc;
#endif
#else
#error Unsupported Platform
#endif
    BOOL foundCrashed = NO;
    for (int i = 0; i < crashReport->n_threads; i++) {
        Plcrash__CrashReport__Thread *reportThread = crashReport->threads[i];        
        if (!reportThread->crashed)
            continue;
        
        foundCrashed = YES;

        /* Load the first frame */
        STAssertNotEquals((size_t)0, reportThread->n_frames, @"No frames available in backtrace");
        Plcrash__CrashReport__Thread__StackFrame *f = reportThread->frames[0];

        /* Validate PC. This check is inexact, as otherwise we would need to carefully instrument the 
         * call to plcrash_log_writer_write_curthread() in order to determine the exact PC value. */
        STAssertTrue(expectedPC - f->pc <= 20, @"PC value not within reasonable range");
    }
   
    STAssertTrue(foundCrashed, @"No thread marked as crashed");
 
    /* Clean up */
    plframe_cursor_free(&cursor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *) crashReport, NULL);
}

@end
