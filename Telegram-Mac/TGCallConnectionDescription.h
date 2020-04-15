//
//  TGCallConnectionDescription.h
//  Telegram
//
//  Created by keepcoder on 03/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TGCallConnectionDescription : NSObject
    
    @property (nonatomic, readonly) int64_t identifier;
    @property (nonatomic, strong, readonly) NSString *ipv4;
    @property (nonatomic, strong, readonly) NSString *ipv6;
    @property (nonatomic, readonly) int32_t port;
    @property (nonatomic, strong, readonly) NSData *peerTag;
    
- (instancetype)initWithIdentifier:(int64_t)identifier ipv4:(NSString *)ipv4 ipv6:(NSString *)ipv6 port:(int32_t)port peerTag:(NSData *)peerTag;
    
    @end


@interface TGCallConnection : NSObject
    
    @property (nonatomic, strong, readonly) NSData *key;
    @property (nonatomic, strong, readonly) NSData *keyHash;
    @property (nonatomic, strong, readonly) TGCallConnectionDescription *defaultConnection;
    @property (nonatomic, strong, readonly) NSArray<TGCallConnectionDescription *> *alternativeConnections;
    @property (nonatomic, readonly) int32_t maxLayer;
- (instancetype)initWithKey:(NSData *)key keyHash:(NSData *)keyHash defaultConnection:(TGCallConnectionDescription *)defaultConnection alternativeConnections:(NSArray<TGCallConnectionDescription *> *)alternativeConnections maxLayer:(int32_t)maxLayer;
    
@end
