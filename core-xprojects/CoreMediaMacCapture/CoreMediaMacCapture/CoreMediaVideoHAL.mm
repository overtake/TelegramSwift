//
//  CoreMediaVideoHAL.m
//  CoreMediaMacCapture
//
//  Created by Mikhail Filimonov on 21.06.2021.
//

#import "CoreMediaVideoHAL.h"

#import <CoreMediaIO/CMIOHardware.h>
#import <CoreMediaIO/CMIOHardwareStream.h>



@interface Device ()
{
    CMIODeviceID _deviceId;
    CMIOStreamID _streamId;
    CMSimpleQueueRef _queueRef;
    RenderBlock _renderBlock;
}

-(CMSimpleQueueRef)queue;
-(RenderBlock)block;

@end

static void handleStreamQueueAltered(CMIOStreamID streamID, void* token, void* refCon) {
    CMSampleBufferRef sb = 0;

    Device *renderBlock = (__bridge Device *)refCon;
    CMSimpleQueueRef queueRef = [renderBlock queue];

    while(0 != (sb = (CMSampleBufferRef)CMSimpleQueueDequeue(queueRef))) {
        renderBlock.block(sb);
        CFRelease(sb);
    }
}

OSStatus GetPropertyData(CMIOObjectID objID, int32_t sel, CMIOObjectPropertyScope scope,
                         UInt32 qualifierDataSize, const void* qualifierData, UInt32 dataSize,
                         UInt32& dataUsed, void* data) {
    CMIOObjectPropertyAddress addr={ (CMIOObjectPropertySelector)sel, scope,
                                     kCMIOObjectPropertyElementMaster };
    return CMIOObjectGetPropertyData(objID, &addr, qualifierDataSize, qualifierData,
                                     dataSize, &dataUsed, data);
}
OSStatus GetPropertyData(CMIOObjectID objID, int32_t selector, UInt32 qualifierDataSize,
                         const void* qualifierData, UInt32 dataSize, UInt32& dataUsed,
                         void* data) {
    return GetPropertyData(objID, selector, 0, qualifierDataSize,
                         qualifierData, dataSize, dataUsed, data);
}
 
OSStatus GetPropertyDataSize(CMIOObjectID objID, int32_t sel,
                             CMIOObjectPropertyScope scope, uint32_t& size) {
    CMIOObjectPropertyAddress addr={ (CMIOObjectPropertySelector)sel, scope,
                                     kCMIOObjectPropertyElementMaster };
    return CMIOObjectGetPropertyDataSize(objID, &addr, 0, 0, &size);
}
 
OSStatus GetPropertyDataSize(CMIOObjectID objID, int32_t selector, uint32_t& size) {
    return GetPropertyDataSize(objID, selector, 0, size);
}
 
OSStatus GetNumberDevices(uint32_t& cnt) {
    if(0 != GetPropertyDataSize(kCMIOObjectSystemObject, kCMIOHardwarePropertyDevices, cnt))
        return -1;
    cnt /= sizeof(CMIODeviceID);
    return 0;
}
 
OSStatus GetDevices(uint32_t& cnt, CMIODeviceID* pDevs) {
    OSStatus status;
    uint32_t numberDevices = 0, used = 0;
    if((status = GetNumberDevices(numberDevices)) < 0)
        return status;
    if(numberDevices > (cnt = numberDevices))
        return -1;
    uint32_t size = numberDevices * sizeof(CMIODeviceID);
    return GetPropertyData(kCMIOObjectSystemObject, kCMIOHardwarePropertyDevices,
                         0, NULL, size, used, pDevs);
}
 
template< const int C_Size >
OSStatus GetDeviceStrProp(CMIOObjectID objID, CMIOObjectPropertySelector sel,
                         char (&pValue)[C_Size]) {
    CFStringRef answer = NULL;
    UInt32     dataUsed= 0;
    OSStatus    status = GetPropertyData(objID, sel, 0, NULL, sizeof(answer),
                                         dataUsed, &answer);
    if(0 == status)// SUCCESS
        CFStringCopyUTF8String(answer, pValue);
    return status;
}
 
template< const int C_Size >
Boolean CFStringCopyUTF8String(CFStringRef aString, char (&pText)[C_Size]) {
    CFIndex length = CFStringGetLength(aString);
    if(sizeof(pText) < (length + 1))
        return false;
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
    return CFStringGetCString(aString, pText, maxSize, kCFStringEncodingUTF8);
}



uint32_t GetNumberInputStreams(CMIODeviceID devID)
{
    uint32 size = 0;
    GetPropertyDataSize(devID, kCMIODevicePropertyStreams,
                        kCMIODevicePropertyScopeInput, size);
    return size / sizeof(CMIOStreamID);
}
OSStatus GetInputStreams(CMIODeviceID devID, uint32_t&
                        ioNumberStreams, CMIOStreamID* streamList)
{
    ioNumberStreams = MIN(GetNumberInputStreams(devID), ioNumberStreams);
    uint32_t size     = ioNumberStreams * sizeof(CMIOStreamID);
    uint32_t dataUsed = 0;
    OSStatus err = GetPropertyData(devID, kCMIODevicePropertyStreams,
                                    kCMIODevicePropertyScopeInput, 0,
                                    NULL, size, dataUsed, streamList);
    if(0 != err)
        return err;
    ioNumberStreams = size / sizeof(CMIOStreamID);
    CMIOStreamID* firstItem = &(streamList[0]);
    CMIOStreamID* lastItem = firstItem + ioNumberStreams;
    
    //std::sort(firstItem, lastItem);
    return 0;
}



@implementation Device

-(id)initWithDeviceId:(CMIODeviceID)deviceId streamId:(CMIOStreamID)streamId {
    if (self = [super init]) {
        _deviceId = deviceId;
        _streamId = streamId;
    }
    return self;
}

-(CMIODeviceID)cmioDevice {
    return  _deviceId;
}

+(Device *)FindDeviceByUniqueId:(NSString *)pUID {
    OSStatus status = 0;
    uint32_t numDev = 0;
    if(((status = GetNumberDevices(numDev)) < 0) || (0 == numDev))
        return nil;
    // Allocate memory on the stack
    CMIODeviceID* pDevs = (CMIODeviceID*)alloca(numDev * sizeof(*pDevs));
    if((status = GetDevices(numDev, pDevs)) < 0)
        return nil;
    for(uint32_t i = 0; i < numDev; i++) {
        char pUniqueID[64];
        if((status = GetDeviceStrProp(pDevs[i], kCMIODevicePropertyDeviceUID, pUniqueID)) < 0)
            break;
        status = afpObjectNotFound;// Not Found…
        if(0 != strcmp([pUID UTF8String], pUniqueID))
            continue;
        
        uint32_t numStreams = GetNumberInputStreams(pDevs[i]);
        CMIOStreamID* pStreams = (CMIOStreamID*)alloca(numStreams * sizeof(CMIOStreamID));
        GetInputStreams(pDevs[i], numStreams, pStreams);
        if (numStreams <= 0)
            return nil;

        
        CMIOStreamID streamId = pStreams[0];
//
        return [[Device alloc] initWithDeviceId:pDevs[i] streamId:streamId];
    }
    
    return nil;
}

-(CMSimpleQueueRef)queue {
    return _queueRef;
}
-(RenderBlock)block {
    return _renderBlock;
}

-(void)run:(RenderBlock)render {
    _renderBlock = render;
    

    
    CMIOStreamCopyBufferQueue(_streamId, handleStreamQueueAltered, (void*)CFBridgingRetain(self), &_queueRef);

    CMIODeviceStartStream(_deviceId, _streamId);
    
}

/*
 
 */

-(void)stop {
    CMIODeviceStopStream(_deviceId, _streamId);
    CMIOStreamCopyBufferQueue(_streamId, nil, nil, &_queueRef);
    if (_queueRef)
        CFRelease(_queueRef);
}

-(void)dealloc {
    [self stop];
}

@end
