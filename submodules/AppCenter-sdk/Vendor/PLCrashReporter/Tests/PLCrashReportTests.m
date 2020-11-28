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
#import "PLCrashReport.h"
#import "PLCrashReporter.h"
#import "PLCrashFrameWalker.h"
#import "PLCrashLogWriter.h"
#import "PLCrashAsyncImageList.h"
#import "PLCrashTestThread.h"

#import "PLCrashHostInfo.h"

#import <fcntl.h>
#import <dlfcn.h>

#import <objc/runtime.h>

#import <mach-o/arch.h>
#import <mach-o/dyld.h>

@interface PLCrashReportTests : SenTestCase {
@private
    /* Path to crash log */
    __strong NSString *_logPath;
}

@end

@implementation PLCrashReportTests

- (void) setUp {
    
    /* Create a temporary log path */
    _logPath = [NSTemporaryDirectory() stringByAppendingString: [[NSProcessInfo processInfo] globallyUniqueString]];
}

- (void) tearDown {
    NSError *error;
    
    /* Delete the file */
    STAssertTrue([[NSFileManager defaultManager] removeItemAtPath: _logPath error: &error], @"Could not remove log file");
    _logPath = nil;
}

struct plcr_live_report_context {
    plcrash_log_writer_t *writer;
    plcrash_async_file_t *file;
    plcrash_async_image_list_t *images;
    plcrash_log_signal_info_t *info;
};
static plcrash_error_t plcr_live_report_callback (plcrash_async_thread_state_t *state, void *ctx) {
    struct plcr_live_report_context *plcr_ctx = ctx;
    return plcrash_log_writer_write(plcr_ctx->writer, pl_mach_thread_self(), plcr_ctx->images, plcr_ctx->file, plcr_ctx->info, state);
}

- (void) testWriteReport {
    plcrash_log_writer_t writer;
    plcrash_async_file_t file;
    plcrash_async_image_list_t image_list;
    NSError *error = nil;
    
    /* Initialze faux crash data */
    plcrash_log_signal_info_t info;
    plcrash_log_bsd_signal_info_t bsd_info;
    plcrash_log_mach_signal_info_t mach_info;
    mach_exception_data_type_t mach_codes[2];
    {
        bsd_info.address = method_getImplementation(class_getInstanceMethod([self class], _cmd));
        bsd_info.code = SEGV_MAPERR;
        bsd_info.signo = SIGSEGV;
        
        mach_info.type = EXC_BAD_ACCESS;
        mach_info.code = mach_codes;
        mach_info.code_count = sizeof(mach_codes) / sizeof(mach_codes[0]);
        mach_codes[0] = KERN_PROTECTION_FAILURE;
        mach_codes[1] = (uintptr_t) bsd_info.address;

        info.mach_info = &mach_info;
        info.bsd_info = &bsd_info;
    }

    /* Open the output file */
    int fd = open([_logPath UTF8String], O_RDWR|O_CREAT|O_EXCL, 0644);
    plcrash_async_file_init(&file, fd, 0);
    
    /* Initialize a writer */
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_log_writer_init(&writer, @"test.id", @"1.0", @"1.0", PLCRASH_ASYNC_SYMBOL_STRATEGY_ALL, false), @"Initialization failed");
    
    /* Set an exception with a valid return address call stack. */
    NSException *exception;
    @try {
        [NSException raise: @"TestException" format: @"TestReason"];
    }
    @catch (NSException *e) {
        exception = e;
    }
    plcrash_log_writer_set_exception(&writer, exception);

    /* Set user defined data */
    NSData *customData = [@"DummyInfo" dataUsingEncoding:NSUTF8StringEncoding];
    plcrash_log_writer_set_custom_data(&writer, customData);

    /* Provide binary image info */
    plcrash_nasync_image_list_init(&image_list, mach_task_self());
    uint32_t image_count = _dyld_image_count();
    for (uint32_t i = 0; i < image_count; i++) {
        plcrash_nasync_image_list_append(&image_list, (uintptr_t) _dyld_get_image_header(i), _dyld_get_image_name(i));
    }

    /* Write the crash report */
    struct plcr_live_report_context ctx = {
        .writer = &writer,
        .file = &file,
        .images = &image_list,
        .info = &info
    };
    STAssertEquals(PLCRASH_ESUCCESS, plcrash_async_thread_state_current(plcr_live_report_callback, &ctx), @"Writing crash log failed");

    /* Close it */
    plcrash_log_writer_close(&writer);
    plcrash_log_writer_free(&writer);
    plcrash_nasync_image_list_free(&image_list);

    plcrash_async_file_flush(&file);
    plcrash_async_file_close(&file);

    /* Try to parse it */
    NSData *data = [NSData dataWithContentsOfFile:_logPath options:NSDataReadingMappedIfSafe error:nil];
    PLCrashReport *crashLog = [[PLCrashReport alloc] initWithData: data error: &error];
    STAssertNotNil(crashLog, @"Could not decode crash log: %@", error);

    /* Report info */
    STAssertNotNULL(crashLog.uuidRef, @"No report UUID");
    
    /* System info */
    STAssertNotNil(crashLog.systemInfo, @"No system information available");
    STAssertNotNil(crashLog.systemInfo.operatingSystemVersion, @"OS version is nil");
    STAssertNotNil(crashLog.systemInfo.operatingSystemBuild, @"OS build is nil");
    STAssertNotNil(crashLog.systemInfo.timestamp, @"Timestamp is nil");
    STAssertEquals(crashLog.systemInfo.operatingSystem, PLCrashReportHostOperatingSystem, @"Operating system incorrect");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    STAssertEquals(crashLog.systemInfo.architecture, PLCrashReportHostArchitecture, @"Architecture incorrect");
#pragma clang diagnostic pop
    STAssertNotNil(crashLog.systemInfo.processorInfo, @"Processor info is nil");
    
    /* Machine info */
    const NXArchInfo *archInfo = NXGetLocalArchInfo();
    STAssertTrue(crashLog.hasMachineInfo, @"No machine information available");
    STAssertNotNil(crashLog.machineInfo, @"No machine information available");
    STAssertNotNil(crashLog.machineInfo.modelName, @"Model is nil");
    STAssertEquals(PLCrashReportProcessorTypeEncodingMach, crashLog.machineInfo.processorInfo.typeEncoding, @"Incorrect processor type encoding");
    STAssertEquals((uint64_t)archInfo->cputype, crashLog.machineInfo.processorInfo.type, @"Incorrect processor type");
    STAssertEquals((uint64_t)archInfo->cpusubtype, crashLog.machineInfo.processorInfo.subtype, @"Incorrect processor subtype");
    STAssertNotEquals((NSUInteger)0, crashLog.machineInfo.processorCount, @"No processor count");
    STAssertNotEquals((NSUInteger)0, crashLog.machineInfo.logicalProcessorCount, @"No logical processor count");

    /* App info */
    STAssertNotNil(crashLog.applicationInfo, @"No application information available");
    STAssertNotNil(crashLog.applicationInfo.applicationIdentifier, @"No application identifier available");
    STAssertNotNil(crashLog.applicationInfo.applicationVersion, @"No application version available");
    
    /* Process info */
    STAssertNotNil(crashLog.processInfo, @"No process information available");
    STAssertNotNil(crashLog.processInfo.processName, @"No process name available");
    STAssertNotNil(crashLog.processInfo.processPath, @"No process path available");

    STAssertNotNil(crashLog.processInfo.processStartTime, @"No process start time available");
    NSTimeInterval startTimeInterval = [[NSDate date] timeIntervalSinceDate: crashLog.processInfo.processStartTime];
    STAssertTrue(startTimeInterval >= 0, @"Date occured in the future");
    STAssertTrue(startTimeInterval < 60, @"Date occured more than 60 second in the past");

    /* This is expected to fail on tvOS and iOS 9+ due to new sandbox constraints */
    if (PLCrashReportHostOperatingSystem == PLCrashReportOperatingSystemAppleTVOS ||
        (PLCrashReportHostOperatingSystem == PLCrashReportOperatingSystemiPhoneOS &&
         PLCrashHostInfo.currentHostInfo.darwinVersion.major >= PLCRASH_HOST_IOS_DARWIN_MAJOR_VERSION_9))
    {
        STAssertNil(crashLog.processInfo.parentProcessName, @"Fetching the parent process name unexpectedly succeeded on iOS 9+");
    } else {
        STAssertNotNil(crashLog.processInfo.parentProcessName, @"No parent process name available");
    }

        
    STAssertTrue(crashLog.processInfo.native, @"Process should be native");
    
    /* Signal info */
    STAssertEqualStrings(@"SIGSEGV", crashLog.signalInfo.name, @"Signal is incorrect");
    STAssertEqualStrings(@"SEGV_MAPERR", crashLog.signalInfo.code, @"Signal code is incorrect");
    
    /* Mach exception info */
    STAssertNotNil(crashLog.machExceptionInfo, @"Missing mach exception info");
    STAssertEquals((exception_type_t) crashLog.machExceptionInfo.type, EXC_BAD_ACCESS, @"Type is incorrect");
    STAssertEquals((NSUInteger)2, [crashLog.machExceptionInfo.codes count], @"Incorrect number of exception codes");
    STAssertEquals((mach_exception_data_type_t) [[crashLog.machExceptionInfo.codes objectAtIndex: 0] unsignedLongLongValue], mach_info.code[0], @"Incorrect code[0]");
    STAssertEquals((mach_exception_data_type_t) [[crashLog.machExceptionInfo.codes objectAtIndex: 1] unsignedLongLongValue], mach_info.code[1], @"Incorrect code[0]");

    /* Exception info */
    STAssertNotNil(crashLog.exceptionInfo, @"Exception info is nil");
    STAssertEqualStrings(crashLog.exceptionInfo.exceptionName, [exception name], @"Exceptio name is incorrect");
    STAssertEqualStrings(crashLog.exceptionInfo.exceptionReason, [exception reason], @"Exception name is incorrect");
    NSUInteger exceptionFrameCount = [[exception callStackReturnAddresses] count];
    for (NSUInteger i = 0; i < exceptionFrameCount; i++) {
        NSNumber *retAddr = [[exception callStackReturnAddresses] objectAtIndex: i];
        PLCrashReportStackFrameInfo *sf = [crashLog.exceptionInfo.stackFrames objectAtIndex: i];
        STAssertEquals(sf.instructionPointer, [retAddr unsignedLongLongValue], @"Stack frame address is incorrect");
    }

    /* Custom data */
    STAssertNotNil(crashLog.customData, @"No custom data");
    NSString *dataString = [[NSString alloc] initWithData:crashLog.customData encoding:NSUTF8StringEncoding];
    STAssertTrue([dataString isEqualToString:@"DummyInfo"], @"Incorrect custom data");

    /* Thread info */
    STAssertNotNil(crashLog.threads, @"Thread list is nil");
    STAssertNotEquals((NSUInteger)0, [crashLog.threads count], @"No thread values returned");

    NSUInteger thrNumber = 0;
    NSInteger lastThreadNumber;
    BOOL crashedFound = NO;
    for (PLCrashReportThreadInfo *threadInfo in crashLog.threads) {
        STAssertNotNil(threadInfo.stackFrames, @"Thread stackframe list is nil");
        STAssertNotNil(threadInfo.registers, @"Thread register list is nil");
        if (thrNumber > 0) {
            STAssertTrue(lastThreadNumber < threadInfo.threadNumber, @"Threads are listed out of order.");
        }
        lastThreadNumber = threadInfo.threadNumber;

        if (threadInfo.crashed) {
            STAssertNotEquals((NSUInteger)0, [threadInfo.registers count], @"No registers recorded for the crashed thread");
            for (PLCrashReportRegisterInfo *registerInfo in threadInfo.registers) {
                STAssertNotNil(registerInfo.registerName, @"Register name is nil");
            }

            /* Symbol information should be available for an ObjC frame in our binary */
            STAssertNotEquals((NSUInteger)0, [threadInfo.stackFrames count], @"Zero stack frames returned");
            PLCrashReportStackFrameInfo *stackFrame = [threadInfo.stackFrames objectAtIndex: 0];
            STAssertNotNil(stackFrame.symbolInfo, @"No symbol info found");
            
            NSString *symName = [NSString stringWithFormat: @"-[%@ %@]", [self class], NSStringFromSelector(_cmd)];
            STAssertEqualStrings(stackFrame.symbolInfo.symbolName, symName, @"Incorrect symbol name");

            crashedFound = YES;
        }
        
        thrNumber++;
    }
    STAssertTrue(crashedFound, @"No crashed thread was found in the crash log");

    /* Image info */
    STAssertNotEquals((NSUInteger)0, [crashLog.images count], @"Crash log should contain at least one image");
    for (PLCrashReportBinaryImageInfo *imageInfo in crashLog.images) {
        STAssertNotNil(imageInfo.imageName, @"Image name is nil");
        if (imageInfo.hasImageUUID == YES) {
            STAssertNotNil(imageInfo.imageUUID, @"Image UUID is nil");
            STAssertEquals((NSUInteger)32, [imageInfo.imageUUID length], @"UUID should be 32 characters (16 bytes)");
        } else if (!imageInfo.hasImageUUID) {
            STAssertNil(imageInfo.imageUUID, @"Info declares no UUID, but the imageUUID property is non-nil");
        }
        
        STAssertNotNil(imageInfo.codeType, @"Image code type is nil");
        STAssertEquals(imageInfo.codeType.typeEncoding, PLCrashReportProcessorTypeEncodingMach, @"Incorrect type encoding");

        // FIXME: dyld_sim is problematic binary.
        if ([imageInfo.imageName hasSuffix:@"/usr/lib/dyld_sim"]) {
          continue;
        }

        /*
         * Find the in-memory mach header for the image record. We'll compare this against the serialized data.
         *
         * The 32-bit and 64-bit mach_header structures are equivalent for our purposes.
         *
         * The (uint64_t)(uint32_t) casting is prevent improper sign extension when casting the signed cpusubtype integer_t
         * to a larger, unsigned uint64_t value.
         */
        Dl_info dlInfo;
        STAssertNotEquals(dladdr((void *)(uintptr_t)imageInfo.imageBaseAddress, &dlInfo), 0, @"dladdr() failed to find image of %@", imageInfo.imageName);
        struct mach_header *hdr = dlInfo.dli_fbase;
        if (hdr != NULL) {
            STAssertEquals(imageInfo.codeType.type, (uint64_t)(uint32_t)hdr->cputype, @"Incorrect CPU type");
            STAssertEquals(imageInfo.codeType.subtype, (uint64_t)(uint32_t)hdr->cpusubtype, @"Incorrect CPU subtype");
        }
    }
}


@end
