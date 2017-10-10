//
//  OpusObjcBridge.h
//  TelegramMac
//
//  Created by keepcoder on 25/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpusObjcBridge : NSObject

@end

@protocol OpusBridgeDelegate <NSObject>
- (void)audioPlayerDidFinishPlaying:(OpusObjcBridge *)audioPlayer;
- (void)audioPlayerDidStartPlaying:(OpusObjcBridge *)audioPlayer;
- (void)audioPlayerDidPause:(OpusObjcBridge *)audioPlayer;

@end

@interface OpusObjcBridge ()

@property (nonatomic, weak) id<OpusBridgeDelegate> delegate;

- (instancetype)initWithPath:(NSString *)path;
+ (bool)canPlayFile:(NSString *)path;
+ (NSTimeInterval)durationFile:(NSString *)path;
- (void)play;
- (void)playFromPosition:(NSTimeInterval)position;
- (void)pause;
- (void)stop;
- (void)reset;
- (NSTimeInterval)currentPositionSync:(bool)sync;
- (NSTimeInterval)duration;
-(void)setCurrentPosition:(NSTimeInterval)position;
- (BOOL)isPaused;
- (BOOL)isEqualToPath:(NSString *)path;
@end
