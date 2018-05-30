//
//  CallsBridge.h
//  Telegram
//
//  Created by keepcoder on 03/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TGCallConnectionDescription.h"


@interface CProxy : NSObject
@property(nonatomic, strong, readonly) NSString *host;
@property(nonatomic, assign, readonly) int32_t port;
@property(nonatomic, strong, readonly) NSString *user;
@property(nonatomic, strong, readonly) NSString *pass;
-(id)initWithHost:(NSString*)host port:(int32_t)port user:(NSString *)user pass:(NSString *)pass;
@end

@interface AudioDevice : NSObject
@property(nonatomic, strong, readonly) NSString *deviceId;
@property(nonatomic, strong, readonly) NSString *deviceName;
-(id)initWithDeviceId:(NSString*)deviceId deviceName:(NSString *)deviceName;
@end

@interface CallBridge : NSObject
-(void)startTransmissionIfNeeded:(bool)outgoing connection:(TGCallConnection *)connection;

-(void)mute;
-(void)unmute;
-(BOOL)isMuted;

-(NSString *)currentOutputDeviceId;
-(NSString *)currentInputDeviceId;
-(NSArray<AudioDevice *> *)outputDevices;
-(NSArray<AudioDevice *> *)inputDevices;
-(void)setCurrentOutputDeviceId:(NSString *)deviceId;
-(void)setCurrentInputDeviceId:(NSString *)deviceId;
@property (nonatomic, copy) void (^stateChangeHandler)(int);

@end
