//
//  CallSession.swift
//  Telegram
//
//  Created by keepcoder on 03/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox
import TGUIKit
import TgVoipWebrtc

enum CallTone {
    case callToneUndefined
    case callToneRingback
    case callToneBusy
    case callToneConnecting
    case callToneFailed
    case callToneEnded
}


public struct CallAuxiliaryServer {
    public enum Connection {
        case stun
        case turn(username: String, password: String)
    }
    
    public let host: String
    public let port: Int
    public let connection: Connection
    
    public init(
        host: String,
        port: Int,
        connection: Connection
        ) {
        self.host = host
        self.port = port
        self.connection = connection
    }
}



enum VoIPState : Int {
    case waitInit = 1
    case waitInitAck = 2
    case established = 3
    case failed = 4
}


private final class OngoingCallThreadLocalContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueue, OngoingCallThreadLocalContextQueueWebrtc /*, OngoingCallThreadLocalContextQueueWebrtcCustom*/ {
    private let queue: Queue
    
    init(queue: Queue) {
        self.queue = queue
        
        super.init()
    }
    
    func dispatch(_ f: @escaping () -> Void) {
        self.queue.async {
            f()
        }
    }
    
    func dispatch(after seconds: Double, block f: @escaping () -> Void) {
        self.queue.after(seconds, f)
    }
    
    func isCurrent() -> Bool {
        return self.queue.isCurrent()
    }
}


let callQueue = Queue(name: "VoIPQueue")

private var callSession:PCallSession? = nil

func pullCurrentSession(_ f:@escaping (PCallSession?)->Void) {
    callQueue.async {
        f(callSession)
    }
}


private func getAuxiliaryServers(appConfiguration: AppConfiguration) -> [CallAuxiliaryServer] {
    guard let data = appConfiguration.data else {
        return []
    }
    guard let servers = data["rtc_servers"] as? [[String: Any]] else {
        return []
    }
    var result: [CallAuxiliaryServer] = []
    for server in servers {
        guard let host = server["host"] as? String else {
            continue
        }
        guard let portString = server["port"] as? String else {
            continue
        }
        guard let username = server["username"] as? String else {
            continue
        }
        guard let password = server["password"] as? String else {
            continue
        }
        guard let port = Int(portString) else {
            continue
        }
        result.append(CallAuxiliaryServer(
            host: host,
            port: port,
            connection: .stun
        ))
        result.append(CallAuxiliaryServer(
            host: host,
            port: port,
            connection: .turn(
                username: username,
                password: password
            )
        ))
    }
    return result
}


struct CallAccessData : Equatable {
    let isMuted: Bool
    let isVideoEnabled: Bool
    let isVerticalVideo: Bool
}

class PCallSession {
    let peerId:PeerId
    let account: Account
    let sharedContext: SharedAccountContext
    let id:CallSessionInternalId
    
    private(set) var peer: Peer?
    private let peerDisposable = MetaDisposable()
    private var ongoingContext: OngoingCallContext?
    private var ongoingContextStateDisposable: Disposable?
    

    private let serializedData: String?
    private let dataSaving: VoiceCallDataSaving
    private let derivedState: VoipDerivedState
    private let proxyServer: ProxyServerSettings?
    private let auxiliaryServers: [OngoingCallContext.AuxiliaryServer]
    private let currentNetworkType: NetworkType
    private let updatedNetworkType: Signal<NetworkType, NoError>

    
    private let stateDisposable = MetaDisposable()
    private let timeoutDisposable = MetaDisposable()
    
    let state:Promise<CallSessionState> = Promise()
    
    
    private let dataSignal:ValuePromise<CallAccessData> = ValuePromise(CallAccessData(isMuted: false, isVideoEnabled: true, isVerticalVideo: false))
    
    var dataValue:Signal<CallAccessData, NoError> {
        return dataSignal.get()
    }
    private(set) var data: CallAccessData = CallAccessData(isMuted: false, isVideoEnabled: true, isVerticalVideo: false) {
        didSet {
            dataSignal.set(data)
        }
    }
    
    private var player:CallAudioPlayer? = nil
    private var playingRingtone:Bool = false
    
    private var startTime:Double = 0
    private var callAcceptedTime:Double = 0
    
    private var tranmissionState:VoIPState = .waitInit
    private var completed: Bool = false
    let durationPromise:Promise<TimeInterval> = Promise()
    private var callSessionValue:CallSession? = nil
    private let proxyDisposable = MetaDisposable()
    private let requestMicroAccessDisposable = MetaDisposable()
    
    
    private let callSessionManager: CallSessionManager
        
    
    var isVideo: Bool {
        return callSessionValue?.type == .video
    }
    
    init(account: Account, sharedContext: SharedAccountContext, peerId:PeerId, id: CallSessionInternalId) {
        
        Queue.mainQueue().async {
            _ = globalAudio?.pause()
        }
        
        assert(callQueue.isCurrent())
        
        self.account = account
        self.sharedContext = sharedContext
        self.peerId = peerId
        self.id = id
        self.callSessionManager = account.callSessionManager
        self.updatedNetworkType = account.networkType
        
        let semaphore = DispatchSemaphore(value: 0)
        var data: (PreferencesView, Peer?, ProxyServerSettings?, NetworkType)!
        let _ = combineLatest(
            account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration, ApplicationSpecificPreferencesKeys.voipDerivedState, PreferencesKeys.appConfiguration])
                |> take(1),
            account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            },
            proxySettings(accountManager: sharedContext.accountManager) |> take(1),
            account.networkType |> take(1)
            ).start(next: { preferences, peer, proxy, networkType in
                data = (preferences, peer, proxy.effectiveActiveServer, networkType)
                semaphore.signal()
            })
        semaphore.wait()

        
       

        let configuration = data.0.values[PreferencesKeys.voipConfiguration] as? VoipConfiguration ?? VoipConfiguration.defaultValue
        let appConfiguration = data.0.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? AppConfiguration.defaultValue
        let derivedState =  data.0.values[ApplicationSpecificPreferencesKeys.voipDerivedState] as? VoipDerivedState ?? VoipDerivedState.default
        
        self.serializedData = configuration.serializedData
        self.dataSaving = .never
        self.derivedState = derivedState
        self.proxyServer = data.2
        self.peer = data.1
        self.currentNetworkType = data.3
        
        
        self.auxiliaryServers = getAuxiliaryServers(appConfiguration: appConfiguration).map { server -> OngoingCallContext.AuxiliaryServer in
            let mappedConnection: OngoingCallContext.AuxiliaryServer.Connection
            switch server.connection {
            case .stun:
                mappedConnection = .stun
            case let .turn(username, password):
                mappedConnection = .turn(username: username, password: password)
            }
            return OngoingCallContext.AuxiliaryServer(
                host: server.host,
                port: server.port,
                connection: mappedConnection
            )
        }
        
        let signal = account.callSessionManager.callState(internalId: id) |> deliverOn(callQueue) |> beforeNext { [weak self] session in
            self?.proccessState(session, configuration)
        }
        
        state.set(signal |> map { $0.state })
    }
    
    private func voipStateChanged(_ state:OngoingCallContextState) {
        switch state.state {
        case .connected:
            if (startTime < Double.ulpOfOne) {
                stopAudio()
                startTime = CFAbsoluteTimeGetCurrent();
                durationPromise.set((.single(duration) |> deliverOnMainQueue) |> then (Signal<()->TimeInterval, NoError>.single({[weak self] in return self?.duration ?? 0}) |> map {$0()} |> delay(1.01, queue: Queue.mainQueue()) |> restart))
            }
        case .failed:
            playTone(.callToneFailed)
            discardCurrentCallWithReason(.error(.disconnected))
        default:
            break
        }
    }
    
    private func startTimeout(_ duration:TimeInterval, discardReason: CallSessionTerminationReason) {
        timeoutDisposable.set((Signal<Void, NoError>.complete() |> delay(duration, queue: Queue.mainQueue())).start(completed: { [weak self] in
            self?.discardCurrentCallWithReason(discardReason)
        }))
    }
    



    
    private func invalidateTimeout() {
        timeoutDisposable.set(nil)
    }
    
    private var callReceiveTimeout:TimeInterval {
        return 30
    }
    private var callRingTimeout:TimeInterval {
        return 30
    }
    private var callConnectTimeout:TimeInterval {
        return 30
    }
    private var callPacketTimeout:TimeInterval {
        return 30
    }
    
    var callConnectionDuration: TimeInterval {
        if callAcceptedTime > Double.ulpOfOne && startTime > Double.ulpOfOne {
            return startTime - callAcceptedTime
        }
        return 0.0
    }
    
    var duration: TimeInterval {
        if startTime > Double.ulpOfOne {
            return CFAbsoluteTimeGetCurrent() - startTime;
        }
        return 0.0;
    }
    
    func stopTransmission(_ id: CallId?) {
        durationPromise.set(.complete())
        ongoingContext?.stop(callId: id, sendDebugLogs: false, debugLogValue: Promise())
    }
    
    func drop(_ reason:DropCallReason) {
        account.callSessionManager.drop(internalId: id, reason: reason, debugLog: .single(nil))
    }
    private func acceptAfterAccess() {
        callAcceptedTime = CFAbsoluteTimeGetCurrent()
        account.callSessionManager.accept(internalId: id)
    }
    
    func acceptCallSession() {
        requestMicroAccessDisposable.set((requestAudioPermission() |> deliverOnMainQueue).start(next: { [weak self] access in
            if access {
                self?.acceptAfterAccess()
            } else {
                confirm(for: mainWindow, information: L10n.requestAccesErrorHaveNotAccessCall, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
                    switch result {
                    case .thrid:
                        openSystemSettings(.microphone)
                    default:
                        break
                    }
                })
            }
        }))
        
    }
    
    func mute() {
        data = CallAccessData(isMuted: true, isVideoEnabled: data.isVideoEnabled, isVerticalVideo: data.isVerticalVideo)
        ongoingContext?.setIsMuted(data.isMuted)
    }
    func setVideoEnabled(_ isEnabled: Bool) {
        data = CallAccessData(isMuted: data.isMuted, isVideoEnabled: isEnabled, isVerticalVideo: data.isVerticalVideo)
        ongoingContext?.setEnableVideo(data.isVideoEnabled)
    }
    func toggleVideoEnabled() {
        data = CallAccessData(isMuted: data.isMuted, isVideoEnabled: !data.isVideoEnabled, isVerticalVideo: data.isVerticalVideo)
        ongoingContext?.setEnableVideo(data.isVideoEnabled)
    }
    
    func unmute() {
        data = CallAccessData(isMuted: false, isVideoEnabled: data.isVideoEnabled, isVerticalVideo: data.isVerticalVideo)
        ongoingContext?.setIsMuted(data.isMuted)
    }
    
    func toggleMute() {
        data = CallAccessData(isMuted: !data.isMuted, isVideoEnabled: data.isVideoEnabled, isVerticalVideo: data.isVerticalVideo)
        ongoingContext?.setIsMuted(data.isMuted)
    }
    
    private func proccessState(_ session: CallSession, _ configuration: VoipConfiguration) {
        self.callSessionValue = session
        
        switch session.state {
        case let .active(id, key, _, connections, maxLayer, version, allowP2P):
            playTone(.callToneConnecting)
            
            let logName = "\(id.id)_\(id.accessHash)"

            let ongoingContext = OngoingCallContext(account: account, callSessionManager: self.callSessionManager, internalId: self.id, proxyServer: proxyServer, auxiliaryServers: auxiliaryServers, initialNetworkType: self.currentNetworkType, updatedNetworkType: self.updatedNetworkType, serializedData: self.serializedData, dataSaving: dataSaving, derivedState: self.derivedState, key: key, isOutgoing: session.isOutgoing, isVideo: session.type == .video, connections: connections, maxLayer: maxLayer, version: version, allowP2P: allowP2P, logName: logName)
            self.ongoingContext = ongoingContext
            
            ongoingContext.setEnableVideo(self.data.isVideoEnabled && session.type == .video)
            
            stateDisposable.set((ongoingContext.state |> deliverOn(callQueue)).start(next: { [weak self] state in
                if let state = state {
                    self?.voipStateChanged(state)
                }
            }))
            
            invalidateTimeout()
        case .ringing:
            playRingtone()
        case .requesting(let ringing):
            if ringing {
                playTone(.callToneRingback)
                startTimeout(callReceiveTimeout, discardReason: .ended(.busy))
            }
            
        case .dropping:
            invalidateTimeout()
            stopAudio()
            break
        case let .terminated(callId, reason, report):
            stopTransmission(callId)
            invalidateTimeout()
            switch reason {
            case .error:
                playTone(.callToneFailed)
            default:
                playTone(.callToneEnded)
            }
        default:
            break
        }
    }
    
    deinit {
        peerDisposable.dispose()
        stateDisposable.dispose()
        drop(.disconnect)
        proxyDisposable.dispose()
    }
    
    private func playRingtone() {
        playingRingtone = true
        if let path = Bundle.main.path(forResource: "opening", ofType:"m4a") {
            playTone(URL(fileURLWithPath: path), loops: -1)
        }
        
    }
    
    
  
    func hangUpCurrentCall() {
        hangUpCurrentCall(false)
    }
    
    func hangUpCurrentCall(_ external: Bool) {
        completed = external
        var reason:CallSessionTerminationReason = .ended(.hungUp)
        if let session = callSessionValue {
            if case .terminated = session.state {
                reason = session.isOutgoing ? .ended(.missed) : .ended(.busy)
            }
        }
        discardCurrentCallWithReason(reason)
    }
    
    private func discardCurrentCallWithReason(_ reason: CallSessionTerminationReason) {
        
        let dropReason:DropCallReason
        
        switch reason {
        case .ended(let ended):
            switch ended {
            case .busy, .missed:
                dropReason = .busy
            case .hungUp:
                dropReason = .hangUp
            }
        case .error:
            dropReason = .disconnect
        }

        drop(dropReason)
    }
    
    
    private func pathForTone(_ tone:CallTone) -> URL?
    {
        let path:String?
        switch tone
        {
        case .callToneBusy:
            path = Bundle.main.path(forResource: "voip_busy", ofType:"caf")
        case .callToneRingback:
            path = Bundle.main.path(forResource: "voip_ringback", ofType:"caf")
        case .callToneConnecting:
            path = Bundle.main.path(forResource: "voip_connecting", ofType:"mp3")
        case .callToneFailed:
            path = Bundle.main.path(forResource: "voip_fail", ofType:"caf")
        case .callToneEnded:
            path = Bundle.main.path(forResource: "voip_end", ofType:"caf")
        default:
            path = nil;
        }
        if let path = path {
            return URL(fileURLWithPath: path)
        } else {
            return nil
        }
    }
    
    private func loopsForTone(_ tone:CallTone) -> Int
    {
        switch tone
        {
        case .callToneBusy:
            return 3;
            
        case .callToneRingback:
            return -1;
            
        case .callToneConnecting:
            return -1;
            
        case .callToneFailed:
            return 1;
            
        case .callToneEnded:
            return 1;
            
        default:
            return 0;
        }
    }
    
    private func playTone(_ tone:URL, loops:Int, completion:(()->Void)? = nil) {
        self.player = CallAudioPlayer(tone, loops: loops, completion: completion)
        self.player?.play()
    }
    
    private func playTone(_ tone:CallTone) {
        if let url = pathForTone(tone) {
            playTone(url, loops: loopsForTone(tone))
        }
    }
    
    private func stopAudio() {
        playingRingtone = false
        player?.stop()
        player = nil
    }
    
    func makeIncomingVideoView(completion: @escaping (NSView?) -> Void) {
        self.ongoingContext?.makeIncomingVideoView(completion: completion)
    }
    
    func makeOutgoingVideoView(completion: @escaping (NSView?) -> Void) {
        self.ongoingContext?.makeOutgoingVideoView(completion: completion)
    }
    
}

enum PCallResult {
    case success(PCallSession)
    case fail
    case samePeer(PCallSession)
}

func phoneCall(account: Account, sharedContext: SharedAccountContext, peerId:PeerId, ignoreSame:Bool = false, isVideo: Bool = false) -> Signal<PCallResult, NoError> {
    return requestAudioPermission() |> deliverOnMainQueue |> mapToSignal { hasAccess -> Signal<PCallResult, NoError> in
        if hasAccess {
            return Signal { subscriber in
                
                assert(callQueue.isCurrent())
                
                if let session = callSession, session.peerId == peerId, !ignoreSame {
                    subscriber.putNext(.samePeer(session))
                    subscriber.putCompletion()
                } else {
                    let confirmation:Signal<Bool, NoError>
                    if let sessionPeerId = callSession?.peerId {
                        confirmation = account.postbox.loadedPeerWithId(peerId) |> mapToSignal { peer -> Signal<(new:Peer, previous:Peer), NoError> in
                            return account.postbox.loadedPeerWithId(sessionPeerId) |> map { (new: peer, previous: $0) }
                            } |> mapToSignal { value in
                                return confirmSignal(for: mainWindow, header: L10n.callConfirmDiscardCurrentHeader, information: L10n.callConfirmDiscardCurrentDescription(value.previous.compactDisplayTitle, value.new.displayTitle))
                        }
                        
                    } else {
                        confirmation = .single(true)
                    }
                    
                    return (confirmation |> filter {$0} |> map { _ in
                        callSession?.hangUpCurrentCall()
                    } |> mapToSignal { _ in
                        return account.callSessionManager.request(peerId: peerId, isVideo: isVideo)
                    } |> deliverOn(callQueue) ).start(next: { id in
                        subscriber.putNext(.success(PCallSession(account: account, sharedContext: sharedContext, peerId: peerId, id: id)))
                        subscriber.putCompletion()
                    })
                }
                
                return EmptyDisposable
                
            } |> runOn(callQueue)
        } else {
            confirm(for: mainWindow, information: L10n.requestAccesErrorHaveNotAccessCall, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
                switch result {
                case .thrid:
                    openSystemSettings(.microphone)
                default:
                    break
                }
                //[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"]];
            })
            return .complete()
        }
    }

    
}

func _callSession() -> Signal<PCallSession?, NoError> {
    return Signal { subscriber in
        var cancel: Bool = false
        pullCurrentSession({ session in
            if !cancel {
                subscriber.putNext(session)
                subscriber.putCompletion()
            }
        })
        return ActionDisposable {
            cancel = true
        }
    }
}
