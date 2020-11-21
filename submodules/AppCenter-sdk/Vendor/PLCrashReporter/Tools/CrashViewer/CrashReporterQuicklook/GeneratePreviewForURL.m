#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <CrashReporter/CrashReporter.h>

OSStatus GeneratePreviewForURL (void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration (void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL (void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    @autoreleasepool {
        NSData *data = [NSData dataWithContentsOfURL: (__bridge NSURL *)url];
        if (!data)
            return noErr;
        
        PLCrashReport *report = [[PLCrashReport alloc] initWithData: data error: NULL];
        if (!report)
            return noErr;
        
        NSString *text = [PLCrashReportTextFormatter stringValueForCrashReport: report
                                                                withTextFormat: PLCrashReportTextFormatiOS];
        NSData *utf8Data = [text dataUsingEncoding: NSUTF8StringEncoding];
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)utf8Data, kUTTypePlainText, NULL);
    }
    return noErr;
}

void CancelPreviewGeneration (void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
