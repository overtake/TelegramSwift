//
//  CoreMediaVideoHAL.h
//  CoreMediaMacCapture
//
//  Created by Mikhail Filimonov on 21.06.2021.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
NS_ASSUME_NONNULL_BEGIN

typedef void(^RenderBlock)(CMSampleBufferRef);

@interface Device : NSObject

+(Device * __nullable)FindDeviceByUniqueId:(NSString *)pUID;

-(void)run:(RenderBlock)render;
-(void)stop;
@end




NS_ASSUME_NONNULL_END
