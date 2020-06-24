//
//  CallsBridge.m
//  Telegram
//
//  Created by keepcoder on 03/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#import "OngoingCallThreadLocalContext.h"
#import "VoIPController.h"
#import "VoIPServerConfig.h"
#import "TGCallUtils.h"
#import "OngoingCallConnectionDescription.h"
#import "TgVoip.h"
#define CVoIPController tgvoip::VoIPController

#import <memory>
#import <MtProtoKit/MtProtoKit.h>

void TGCallAesIgeEncrypt(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv) {
    MTAesEncryptRaw(inBytes, outBytes, length, key, iv);
}

void TGCallAesIgeDecrypt(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv) {
    MTAesDecryptRaw(inBytes, outBytes, length, key, iv);
}

void TGCallSha1(uint8_t *msg, size_t length, uint8_t *output) {
    MTRawSha1(msg, length, output);
}

void TGCallSha256(uint8_t *msg, size_t length, uint8_t *output) {
    MTRawSha256(msg, length, output);
}

void TGCallAesCtrEncrypt(uint8_t *inOut, size_t length, uint8_t *key, uint8_t *iv, uint8_t *ecount, uint32_t *num) {
    uint8_t *outData = (uint8_t *)malloc(length);
    MTAesCtr *aesCtr = [[MTAesCtr alloc] initWithKey:key keyLength:32 iv:iv ecount:ecount num:*num];
    [aesCtr encryptIn:inOut out:outData len:length];
    memcpy(inOut, outData, length);
    free(outData);
    
    [aesCtr getIv:iv];
    
    memcpy(ecount, [aesCtr ecount], 16);
    *num = [aesCtr num];
}

void TGCallRandomBytes(uint8_t *buffer, size_t length) {
    arc4random_buf(buffer, length);
}

static TgVoipNetworkType callControllerNetworkTypeForType(OngoingCallNetworkType type) {
    switch (type) {
        case OngoingCallNetworkTypeWifi:
            return TgVoipNetworkType::WiFi;
        case OngoingCallNetworkTypeCellularGprs:
            return TgVoipNetworkType::Gprs;
        case OngoingCallNetworkTypeCellular3g:
            return TgVoipNetworkType::ThirdGeneration;
        case OngoingCallNetworkTypeCellularLte:
            return TgVoipNetworkType::Lte;
        default:
            return TgVoipNetworkType::ThirdGeneration;
    }
}

static TgVoipDataSaving callControllerDataSavingForType(OngoingCallDataSaving type) {
    switch (type) {
        case OngoingCallDataSavingNever:
            return TgVoipDataSaving::Never;
        case OngoingCallDataSavingCellular:
            return TgVoipDataSaving::Mobile;
        case OngoingCallDataSavingAlways:
            return TgVoipDataSaving::Always;
        default:
            return TgVoipDataSaving::Never;
    }
}



@implementation CProxy
-(id)initWithHost:(NSString*)host port:(int32_t)port user:(NSString *)user pass:(NSString *)pass {
    self = [super init];
    _host = host;
    _port = port;
    _user = user;
    _pass = pass;
    return self;
}
@end

@interface VoIPControllerHolder : NSObject {
    tgvoip::VoIPController *_controller;
}

@property (nonatomic, assign, readonly)  tgvoip::VoIPController *controller;

@end

@implementation AudioDevice
-(id)initWithDeviceId:(NSString *)deviceId deviceName:(NSString *)deviceName {
    if (self = [super init]) {
        _deviceId = deviceId;
        _deviceName = deviceName;
    }
    return self;
}
@end

const NSTimeInterval TGCallReceiveTimeout = 20;
const NSTimeInterval TGCallRingTimeout = 90;
const NSTimeInterval TGCallConnectTimeout = 30;
const NSTimeInterval TGCallPacketTimeout = 10;

@implementation VoIPControllerHolder

- (instancetype)initWithController:( tgvoip::VoIPController *)controller {
    self = [super init];
    if (self != nil) {
        _controller = controller;
    }
    return self;
}

- ( tgvoip::VoIPController *)controller {
    return _controller;
}

-(void)dealloc {
    _controller->Stop();
    delete _controller;
    
    int bp = 0;
    bp++;
}


@end

@interface OngoingCallThreadLocalContext () {
    int32_t _contextId;
    
    OngoingCallNetworkType _networkType;
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    
    TgVoip *_tgVoip;
    
    OngoingCallState _state;
    int32_t _signalBars;
    NSData *_lastDerivedState;

}
@property (nonatomic, strong) VoIPControllerHolder *controller;
@property (nonatomic, assign) BOOL _isMuted;
- (void)controllerStateChanged:(int)state;



@end

static void controllerStateCallback(tgvoip::VoIPController *controller, int state)
{
    OngoingCallThreadLocalContext *session = (__bridge OngoingCallThreadLocalContext *)controller->implData;
    [session controllerStateChanged:state];
}

static MTAtomic *callContexts() {
    static MTAtomic *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MTAtomic alloc] initWithValue:[[NSMutableDictionary alloc] init]];
    });
    return instance;
}


@interface OngoingCallThreadLocalContextReference : NSObject

@property (nonatomic, weak) OngoingCallThreadLocalContext *context;
@property (nonatomic, strong, readonly) id<OngoingCallThreadLocalContextQueue> queue;

@end


@implementation OngoingCallThreadLocalContextReference

- (instancetype)initWithContext:(OngoingCallThreadLocalContext *)context queue:(id<OngoingCallThreadLocalContextQueue>)queue {
    self = [super init];
    if (self != nil) {
        self.context = context;
        _queue = queue;
    }
    return self;
}

@end


static int32_t nextId = 1;

static int32_t addContext(OngoingCallThreadLocalContext *context, id<OngoingCallThreadLocalContextQueue> queue) {
    int32_t contextId = OSAtomicIncrement32(&nextId);
    [callContexts() with:^id(NSMutableDictionary *dict) {
        dict[@(contextId)] = [[OngoingCallThreadLocalContextReference alloc] initWithContext:context queue:queue];
        return nil;
    }];
    return contextId;
}

static void removeContext(int32_t contextId) {
    [callContexts() with:^id(NSMutableDictionary *dict) {
        [dict removeObjectForKey:@(contextId)];
        return nil;
    }];
}

static void withContext(int32_t contextId, void (^f)(OngoingCallThreadLocalContext *)) {
    __block OngoingCallThreadLocalContextReference *reference = nil;
    [callContexts() with:^id(NSMutableDictionary *dict) {
        reference = dict[@(contextId)];
        return nil;
    }];
    if (reference != nil) {
        [reference.queue dispatch:^{
            __strong OngoingCallThreadLocalContext *context = reference.context;
            if (context != nil) {
                f(context);
            }
        }];
    }
}



@implementation OngoingCallThreadLocalContext

+ (int32_t)maxLayer {
    return 92;
}


- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueue> _Nonnull)queue networkType:(OngoingCallNetworkType)networkType dataSaving:(OngoingCallDataSaving)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescription * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescription *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath {
    self = [super init];
    if (self != nil) {
        
        _contextId = addContext(self, queue);
        
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _networkType = networkType;

        
        
        std::unique_ptr<TgVoipProxy> proxyValue = nullptr;
        if (proxy != nil) {
            TgVoipProxy *proxyObject = new TgVoipProxy();
            proxyObject->host = proxy.host.UTF8String;
            proxyObject->port = (uint16_t)proxy.port;
            proxyObject->login = proxy.user.UTF8String ?: "";
            proxyObject->password = proxy.pass.UTF8String ?: "";
            proxyValue = std::unique_ptr<TgVoipProxy>(proxyObject);
        }
        
        
        
        TgVoipCrypto crypto;
        crypto.sha1 = &TGCallSha1;
        crypto.sha256 = &TGCallSha256;
        crypto.rand_bytes = &TGCallRandomBytes;
        crypto.aes_ige_encrypt = &TGCallAesIgeEncrypt;
        crypto.aes_ige_decrypt = &TGCallAesIgeDecrypt;
        crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;
        
        std::vector<TgVoipEndpoint> endpoints;
        NSArray<OngoingCallConnectionDescription *> *connections = [@[primaryConnection] arrayByAddingObjectsFromArray:alternativeConnections];
        for (OngoingCallConnectionDescription *connection in connections) {
            unsigned char peerTag[16];
            [connection.peerTag getBytes:peerTag length:16];
            
            TgVoipEndpoint endpoint;
            endpoint.endpointId = connection.identifier;
            endpoint.host = {
                .ipv4 = std::string(connection.ipv4.UTF8String),
                .ipv6 = std::string(connection.ipv6.UTF8String)
            };
            endpoint.port = (uint16_t)connection.port;
            endpoint.type = TgVoipEndpointType::UdpRelay;
            memcpy(endpoint.peerTag, peerTag, 16);
            endpoints.push_back(endpoint);
        }
        
        TgVoipConfig config = {
            .initializationTimeout = _callConnectTimeout,
            .receiveTimeout = _callPacketTimeout,
            .dataSaving = callControllerDataSavingForType(dataSaving),
            .enableP2P = static_cast<bool>(allowP2P),
            .enableAEC = false,
            .enableNS = true,
            .enableAGC = true,
            .enableCallUpgrade = false,
            .logPath = logPath.length == 0 ? "" : std::string(logPath.UTF8String),
            .maxApiLayer = [OngoingCallThreadLocalContext maxLayer]
        };
        
        std::vector<uint8_t> encryptionKeyValue;
        encryptionKeyValue.resize(key.length);
        memcpy(encryptionKeyValue.data(), key.bytes, key.length);
        
        TgVoipEncryptionKey encryptionKey = {
            .value = encryptionKeyValue,
            .isOutgoing = isOutgoing,
        };
        
        
        _tgVoip = TgVoip::makeInstance(
                                       config,
                                       { derivedStateValue },
                                       endpoints,
                                       proxyValue,
                                       callControllerNetworkTypeForType(networkType),
                                       encryptionKey,
                                       crypto
                                       );
        
        _state = OngoingCallStateInitializing;
        _signalBars = -1;
        
        __weak OngoingCallThreadLocalContext *weakSelf = self;
        _tgVoip->setOnStateUpdated([weakSelf](TgVoipState state) {
            __strong OngoingCallThreadLocalContext *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf controllerStateChanged:state];
            }
        });
        _tgVoip->setOnSignalBarsUpdated([weakSelf](int signalBars) {
            __strong OngoingCallThreadLocalContext *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf signalBarsChanged:signalBars];
            }
        });

        
//
//        CVoIPController *controller = new CVoIPController();
//        controller->implData = (__bridge void *)self;
//        tgvoip::VoIPController::Callbacks callbacks={0};
//        callbacks.connectionStateChanged=&controllerStateCallback;
//        controller->SetCallbacks(callbacks);
//        if (proxy != nil) {
//            controller->SetProxy(tgvoip::PROXY_SOCKS5, std::string([proxy.host UTF8String]), proxy.port, std::string([proxy.user UTF8String]), std::string([proxy.pass UTF8String]));
//        }
//
//        CVoIPController::crypto.sha1 = &TGCallSha1;
//        CVoIPController::crypto.sha256 = &TGCallSha256;
//        CVoIPController::crypto.rand_bytes = &TGCallRandomBytes;
//        CVoIPController::crypto.aes_ige_encrypt = &TGCallAesIgeEncryptInplace;
//        CVoIPController::crypto.aes_ige_decrypt = &TGCallAesIgeDecryptInplace;
//        CVoIPController::crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;
//        _controller = [[VoIPControllerHolder alloc] initWithController:controller];
        
    }
    return self;
}

-(void)mute {
    self._isMuted = true;
    _controller.controller->SetMicMute(true);
}

-(void)unmute {
    self._isMuted = false;
    _controller.controller->SetMicMute(false);
}

-(BOOL)isMuted {
    return self._isMuted;
}

- (void)controllerStateChanged:(int)state
{
    if (_stateChangeHandler != nil) {
        _stateChangeHandler(state);
    }
}

+(int32_t)voipMaxLayer {
    return tgvoip::VoIPController::GetConnectionMaxLayer();
}
+(NSString *)voipVersion {
    return [NSString stringWithUTF8String:tgvoip::VoIPController::GetVersion()];
}

+(NSArray<AudioDevice *> *)inputDevices {
    
    std::vector<tgvoip::AudioInputDevice> vector = tgvoip::VoIPController::EnumerateAudioInputs();
    
    NSMutableArray <AudioDevice *> * devices = [[NSMutableArray alloc] init];
    [devices addObject:[[AudioDevice alloc] initWithDeviceId:nil deviceName:@"Default"]];
    for(std::vector<tgvoip::AudioInputDevice>::iterator it = vector.begin(); it != vector.end(); ++it) {
        std::string deviceId = it->id;
        std::string deviceName = it->displayName;
        AudioDevice *device = [[AudioDevice alloc] initWithDeviceId:[NSString stringWithCString:deviceId.c_str() encoding:NSUTF8StringEncoding] deviceName:[NSString stringWithCString:deviceName.c_str() encoding:NSUTF8StringEncoding]];
        [devices addObject:device];
    }
    return devices;
}

+(NSArray<AudioDevice *> *)outputDevices {
    
    std::vector<tgvoip::AudioOutputDevice> vector = tgvoip::VoIPController::EnumerateAudioOutputs();
    
    NSMutableArray <AudioDevice *> * devices = [[NSMutableArray alloc] init];
    [devices addObject:[[AudioDevice alloc] initWithDeviceId:nil deviceName:@"Default"]];
    for(std::vector<tgvoip::AudioOutputDevice>::iterator it = vector.begin(); it != vector.end(); ++it) {
        std::string deviceId = it->id;
        std::string deviceName = it->displayName;
        AudioDevice *device = [[AudioDevice alloc] initWithDeviceId:[NSString stringWithCString:deviceId.c_str() encoding:NSUTF8StringEncoding] deviceName:[NSString stringWithCString:deviceName.c_str() encoding:NSUTF8StringEncoding]];
        [devices addObject:device];
    }
    return devices;
}

-(NSString *)currentInputDeviceId {
    return [NSString stringWithCString:_controller.controller->GetCurrentAudioInputID().c_str() encoding:NSUTF8StringEncoding];
}

-(NSString *)currentOutputDeviceId {
    return [NSString stringWithCString:_controller.controller->GetCurrentAudioOutputID().c_str() encoding:NSUTF8StringEncoding];
}

-(void)setCurrentInputDeviceId:(NSString *)deviceId {
    _controller.controller->SetCurrentAudioInput(std::string([deviceId UTF8String]));
}
-(void)setCurrentOutputDeviceId:(NSString *)deviceId {
    _controller.controller->SetCurrentAudioOutput(std::string([deviceId UTF8String]));
}

-(void)setMutedOtherSounds:(BOOL)mute {
    _controller.controller->SetAudioOutputDuckingEnabled(mute);
}

//
-(void)startTransmissionIfNeeded:(bool)outgoing allowP2p:(bool)allowP2p serializedData:(NSString *)serializedData connection:(TGCallConnection *)connection {
    
    tgvoip::VoIPController::Config config = tgvoip::VoIPController::Config();
    config.initTimeout = TGCallConnectTimeout;
    config.recvTimeout = TGCallPacketTimeout;
    config.dataSaving = tgvoip::DATA_SAVING_NEVER;
    config.enableAEC = false;
    config.enableNS = true;
    config.enableAGC = true;
    
    config.logFilePath = [[@"~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/voip.log" stringByExpandingTildeInPath] UTF8String];
    
  //  strncpy(config.logFilePath, [[@"~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/voip.log" stringByExpandingTildeInPath] UTF8String], sizeof(config.logFilePath));    //memset(config.logFilePath, 0, sizeof(config.logFilePath));
    
    _controller.controller->SetConfig(config);
    tgvoip::ServerConfig::GetSharedInstance()->Update(serializedData.UTF8String);
    
    std::vector<tgvoip::Endpoint> endpoints {};
    std::vector<tgvoip::Endpoint>::iterator it = endpoints.begin();
    
    NSArray *connections = [@[connection.defaultConnection] arrayByAddingObjectsFromArray:connection.alternativeConnections];
    for (NSUInteger i = 0; i < connections.count; i++)
    {
        OngoingCallConnectionDescription *desc = connections[i];
        
        tgvoip::Endpoint endpoint {};
        
        endpoint.id = desc.identifier;
        endpoint.port = (uint32_t)desc.port;
        
        tgvoip::IPv4Address address(std::string(desc.ipv4.UTF8String));
        tgvoip::IPv6Address addressv6(std::string(desc.ipv6.UTF8String));

        
//        endpoint.address = tgvoip::NetworkAddress::IPv4(desc.ipv4.UTF8String);
//        endpoint.v6address = tgvoip::NetworkAddress::IPv4(desc.ipv6.UTF8String);
        endpoint.type = tgvoip::Endpoint::Type::UDP_RELAY;
        endpoint.address = address;
        endpoint.v6address = addressv6;
        [desc.peerTag getBytes:&endpoint.peerTag length:16];
        
        it = endpoints.insert ( it , endpoint );
    }
    
    _controller.controller->SetEncryptionKey((char *)connection.key.bytes, outgoing);
    _controller.controller->SetRemoteEndpoints(endpoints, allowP2p, connection.maxLayer);
    
    
    _controller.controller->Start();
    
    _controller.controller->Connect();
}

-(void)dealloc {
    
    int bp = 0;
    bp += 1;
}


@end

