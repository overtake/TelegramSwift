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
    case undefined
    case ringback
    case busy
    case connecting
    case failed
    case ended
    case ringing
}


enum CallControllerStatusValue: Equatable {
    case text(String)
    case timer(Double)
}


extension CallState.State {
    func statusText(_ accountPeer: Peer?) -> CallControllerStatusValue {
        let statusValue: CallControllerStatusValue
        switch self {
        case .waiting, .connecting:
            statusValue = .text(L10n.callStatusConnecting)
        case let .requesting(ringing):
            if ringing {
                statusValue = .text(L10n.callStatusRinging)
            } else {
                statusValue = .text(L10n.callStatusRequesting)
            }
        case .terminating:
            statusValue = .text(L10n.callStatusEnded)
        case let .terminated(_, reason, _):
            if let reason = reason {
                switch reason {
                case let .ended(type):
                    switch type {
                    case .busy:
                        statusValue = .text(L10n.callStatusBusy)
                    case .hungUp, .missed:
                        statusValue = .text(L10n.callStatusEnded)
                    }
                case .error:
                    statusValue = .text(L10n.callStatusFailed)
                }
            } else {
                statusValue = .text(L10n.callStatusEnded)
            }
        case .ringing:
            if let accountPeer = accountPeer {
                statusValue = .text(L10n.callStatusCallingAccount(accountPeer.addressName ?? accountPeer.compactDisplayTitle))
            } else {
                statusValue = .text(L10n.callStatusCalling)
            }
        case .active(let timestamp, _, _), .reconnecting(let timestamp, _, _):
            if case .reconnecting = self {
                statusValue = .text(L10n.callStatusConnecting)
            } else {
                statusValue = .timer(timestamp)
            }
        }
        return statusValue
    }
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
 struct CallState: Equatable {
    enum State: Equatable {
        case waiting
        case ringing
        case requesting(Bool)
        case connecting(Data?)
        case active(Double, Int32?, Data)
        case reconnecting(Double, Int32?, Data)
        case terminating
        case terminated(CallId?, CallSessionTerminationReason?, Bool)
    }
    
    
    enum VideoState: Equatable {
        case notAvailable
        case possible
        case outgoingRequested
        case incomingRequested
        case active
    }
    
    enum RemoteVideoState: Equatable {
        case inactive
        case active
    }
    
    let state: State
    let videoState: VideoState
    let remoteVideoState: RemoteVideoState
    let isMuted: Bool
    let isOutgoingVideoPaused: Bool
    
    init(state: State, videoState: VideoState, remoteVideoState: RemoteVideoState, isMuted: Bool, isOutgoingVideoPaused: Bool) {
        self.state = state
        self.videoState = videoState
        self.remoteVideoState = remoteVideoState
        self.isMuted = isMuted
        self.isOutgoingVideoPaused = isOutgoingVideoPaused
    }
}


private final class OngoingCallThreadLocalContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueue, OngoingCallThreadLocalContextQueueWebrtc  {
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



class PCallSession {
    let peerId:PeerId
    let account: Account
    let sharedContext: SharedAccountContext
    let internalId:CallSessionInternalId
    
    private(set) var peer: Peer?
    private let peerDisposable = MetaDisposable()
    private var sessionState: CallSession?
    
    private var ongoingContext: OngoingCallContext?
    private var callContextState: OngoingCallContextState?
    private var ongoingContextStateDisposable: Disposable?
    private var reception: Int32?
    private var receptionDisposable: Disposable?


    private let serializedData: String?
    private let dataSaving: VoiceCallDataSaving
    private let derivedState: VoipDerivedState
    private let proxyServer: ProxyServerSettings?
    private let auxiliaryServers: [OngoingCallContext.AuxiliaryServer]
    private let currentNetworkType: NetworkType
    private let updatedNetworkType: Signal<NetworkType, NoError>

    
    private let stateDisposable = MetaDisposable()
    private let timeoutDisposable = MetaDisposable()
    
    private let sessionStateDisposable = MetaDisposable()
    
    private let statePromise:ValuePromise<CallState> = ValuePromise()
    
    var state:Signal<CallState, NoError> {
        return statePromise.get()
    }
    
    private let canBeRemovedPromise = Promise<Bool>(false)
    private var didSetCanBeRemoved = false
    public var canBeRemoved: Signal<Bool, NoError> {
        return self.canBeRemovedPromise.get()
    }
    
    private let hungUpPromise = ValuePromise<Bool>()
    
    private var activeTimestamp: Double?

    
    private var player:CallAudioPlayer? = nil
    private var playingRingtone:Bool = false
    
    private var startTime:Double = 0
    private var callAcceptedTime:Double = 0
    
    private var completed: Bool = false
    private let requestMicroAccessDisposable = MetaDisposable()
    
    
    private let callSessionManager: CallSessionManager
    
    private var videoCapturer: OngoingCallVideoCapturer?
    
    let isOutgoing: Bool
    private(set) var isVideo: Bool
    private var isVideoPossible: Bool

    private var callWasActive = false
    private var videoWasActive = false

    
    private var droppedCall = false
    private var dropCallKitCallTimer: SwiftSignalKit.Timer?
    

    
    init(account: Account, sharedContext: SharedAccountContext, isOutgoing: Bool, peerId:PeerId, id: CallSessionInternalId, initialState:CallSession?, startWithVideo: Bool, isVideoPossible: Bool) {
        
        Queue.mainQueue().async {
            _ = globalAudio?.pause()
        }
                
        self.account = account
        self.sharedContext = sharedContext
        self.peerId = peerId
        self.internalId = id
        self.callSessionManager = account.callSessionManager
        self.updatedNetworkType = account.networkType
        self.isOutgoing = isOutgoing
        self.isVideoPossible = isVideoPossible


        self.isVideo = initialState?.type == .video
        self.isVideo = self.isVideo || startWithVideo
        
        if self.isVideo {
            self.videoCapturer = OngoingCallVideoCapturer()
            self.statePromise.set(CallState(state: isOutgoing ? .waiting : .ringing, videoState: .active, remoteVideoState: .inactive, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused))
        } else {
            self.statePromise.set(CallState(state: isOutgoing ? .waiting : .ringing, videoState: .notAvailable, remoteVideoState: .inactive, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused))
        }
        
        
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
        
        var callSessionState: Signal<CallSession, NoError> = .complete()
        if let initialState = initialState {
            callSessionState = .single(initialState)
        }
        callSessionState = callSessionState
            |> then(callSessionManager.callState(internalId: id))
        
        let signal = callSessionState |> deliverOn(callQueue)
        
        self.sessionStateDisposable.set(signal.start(next: { [weak self] sessionState in
            if let strongSelf = self {
                strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, reception: strongSelf.reception)
            }
        })
)
        
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
        ongoingContext?.stop(callId: id, sendDebugLogs: false, debugLogValue: Promise())
    }
    
    func drop(_ reason:DropCallReason) {
        account.callSessionManager.drop(internalId: internalId, reason: reason, debugLog: .single(nil))
    }
    private func acceptAfterAccess() {
        callAcceptedTime = CFAbsoluteTimeGetCurrent()
        account.callSessionManager.accept(internalId: internalId)
    }
    
    func acceptCallSession() {
        requestMicroAccessDisposable.set((requestMicrophonePermission() |> deliverOnMainQueue).start(next: { [weak self] access in
            if access {
                self?.acceptAfterAccess()
            } else {
                confirm(for: mainWindow, information: L10n.requestAccesErrorHaveNotAccessCall, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { [weak self] result in
                    switch result {
                    case .thrid:
                        openSystemSettings(.microphone)
                    default:
                        break
                    }
                    self?.drop(.hangUp)
                })
            }
        }))
        
    }
    
    public func setEnableVideo(_ value: Bool) {
        self.ongoingContext?.setEnableVideo(value)
    }

    
    private var isOutgoingVideoPaused: Bool = false
    private var isMuted: Bool = false
    
    func mute() {
        self.isMuted = true
        ongoingContext?.setIsMuted(self.isMuted)
    }
    
    func unmute() {
        self.isMuted = false
        ongoingContext?.setIsMuted(self.isMuted)
    }
    
    func toggleMute() {
        self.isMuted = !self.isMuted
        ongoingContext?.setIsMuted(self.isMuted)
        if let state = self.sessionState {
            self.updateSessionState(sessionState: state, callContextState: self.callContextState, reception: self.reception)
        }
    }
    func setOutgoingVideoIsPaused(_ isEnabled: Bool) {
        self.isOutgoingVideoPaused = isEnabled
        self.videoCapturer?.setIsVideoEnabled(!self.isOutgoingVideoPaused)
        if let state = self.sessionState {
            self.updateSessionState(sessionState: state, callContextState: self.callContextState, reception: self.reception)
        }
    }
    func toggleOutgoingVideo() {
        self.isOutgoingVideoPaused = !self.isOutgoingVideoPaused
        self.videoCapturer?.setIsVideoEnabled(!self.isOutgoingVideoPaused)
        if let state = self.sessionState {
            self.updateSessionState(sessionState: state, callContextState: self.callContextState, reception: self.reception)
        }
    }

    
    private func updateSessionState(sessionState: CallSession, callContextState: OngoingCallContextState?, reception: Int32?) {
        if case .video = sessionState.type {
            self.isVideo = true
        }
        let previous = self.sessionState
        self.sessionState = sessionState
        self.callContextState = callContextState
        self.reception = reception
        
        
        let presentationState: CallState?
        
        var wasActive = false
        var wasTerminated = false
        if let previous = previous {
            switch previous.state {
            case .active:
                wasActive = true
            case .terminated:
                wasTerminated = true
            default:
                break
            }
        }
        
        
        let mappedVideoState: CallState.VideoState
        let mappedRemoteVideoState: CallState.RemoteVideoState
        if let callContextState = callContextState {
            switch callContextState.videoState {
            case .notAvailable:
                mappedVideoState = .notAvailable
            case .possible:
                mappedVideoState = .possible
            case .outgoingRequested:
                mappedVideoState = .outgoingRequested
            case .incomingRequested:
                mappedVideoState = .incomingRequested
            case .active:
                mappedVideoState = .active
                self.videoWasActive = true
            }
            switch callContextState.remoteVideoState {
            case .inactive:
                mappedRemoteVideoState = .inactive
            case .active:
                mappedRemoteVideoState = .active
            }
        } else {
            if self.isVideo {
                mappedVideoState = .outgoingRequested
            } else if self.isVideoPossible {
                mappedVideoState = .possible
            } else {
                mappedVideoState = .notAvailable
            }
            if videoWasActive {
                mappedRemoteVideoState = .active
            } else {
                mappedRemoteVideoState = .inactive
            }
        }
        
        switch sessionState.state {
        case .ringing:
            presentationState = CallState(state: .ringing, videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
        case .accepting:
            self.callWasActive = true
            presentationState = CallState(state: .connecting(nil), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
        case .dropping:
            presentationState = CallState(state: .terminating, videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
        case let .terminated(id, reason, options):
            presentationState = CallState(state: .terminated(id, reason, false), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
        case let .requesting(ringing):
            presentationState = CallState(state: .requesting(ringing), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
        case let .active(_, _, keyVisualHash, _, _, _, _):
            self.callWasActive = true
            if let callContextState = callContextState {
                switch callContextState.state {
                case .initializing:
                    presentationState = CallState(state: .connecting(keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
                case .failed:
                    presentationState = nil
                    self.callSessionManager.drop(internalId: self.internalId, reason: .disconnect, debugLog: .single(nil))
                case .connected:
                    let timestamp: Double
                    if let activeTimestamp = self.activeTimestamp {
                        timestamp = activeTimestamp
                    } else {
                        timestamp = CFAbsoluteTimeGetCurrent()
                        self.activeTimestamp = timestamp
                    }
                    presentationState = CallState(state: .active(timestamp, reception, keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
                case .reconnecting:
                    let timestamp: Double
                    if let activeTimestamp = self.activeTimestamp {
                        timestamp = activeTimestamp
                    } else {
                        timestamp = CFAbsoluteTimeGetCurrent()
                        self.activeTimestamp = timestamp
                    }
                    presentationState = CallState(state: .reconnecting(timestamp, reception, keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
                }
            } else {
                presentationState = CallState(state: .connecting(keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, isMuted: self.isMuted, isOutgoingVideoPaused: self.isOutgoingVideoPaused)
            }
        }
        
        switch sessionState.state {
        case .requesting:
            break
        case let .active(id, key, _, connections, maxLayer, version, allowsP2P):
            if !wasActive {
                let logName = "\(id.id)_\(id.accessHash)"
                
                let ongoingContext = OngoingCallContext(account: account, callSessionManager: self.callSessionManager, internalId: self.internalId, proxyServer: proxyServer, auxiliaryServers: auxiliaryServers, initialNetworkType: self.currentNetworkType, updatedNetworkType: self.updatedNetworkType, serializedData: self.serializedData, dataSaving: dataSaving, derivedState: self.derivedState, key: key, isOutgoing: sessionState.isOutgoing, video: self.videoCapturer, connections: connections, maxLayer: maxLayer, version: version, allowP2P: allowsP2P, logName: logName)
                self.ongoingContext = ongoingContext
                
                
                self.ongoingContextStateDisposable = (ongoingContext.state
                    |> deliverOnMainQueue).start(next: { [weak self] contextState in
                        if let strongSelf = self {
                            if let sessionState = strongSelf.sessionState {
                                strongSelf.updateSessionState(sessionState: sessionState, callContextState: contextState, reception: strongSelf.reception)
                            } else {
                                strongSelf.callContextState = contextState
                            }
                        }
                    })
                
                self.receptionDisposable = (ongoingContext.reception
                    |> deliverOnMainQueue).start(next: { [weak self] reception in
                        if let strongSelf = self {
                            if let sessionState = strongSelf.sessionState {
                                strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, reception: reception)
                            } else {
                                strongSelf.reception = reception
                            }
                        }
                    })
                
            }
        case let .terminated(id, _, options):
            if wasActive {
                let debugLogValue = Promise<String?>()
                self.ongoingContext?.stop(callId: id, sendDebugLogs: options.contains(.sendDebugLogs), debugLogValue: debugLogValue)
            }
        default:
            if wasActive {
                let debugLogValue = Promise<String?>()
                self.ongoingContext?.stop(debugLogValue: debugLogValue)
            }
        }
        if case .terminated = sessionState.state, !wasTerminated {
            if !self.didSetCanBeRemoved {
                self.didSetCanBeRemoved = true
                self.canBeRemovedPromise.set(.single(true) |> delay(1.6, queue: Queue.mainQueue()))
            }
            self.hungUpPromise.set(true)
            if sessionState.isOutgoing {
                if !self.droppedCall {
                    let dropCallKitCallTimer = SwiftSignalKit.Timer(timeout: 1.6, repeat: false, completion: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.dropCallKitCallTimer = nil
                            if !strongSelf.droppedCall {
                                strongSelf.droppedCall = true
                            }
                        }
                    }, queue: Queue.mainQueue())
                    self.dropCallKitCallTimer = dropCallKitCallTimer
                    dropCallKitCallTimer.start()
                }
            }
        }
        if let presentationState = presentationState {
            self.statePromise.set(presentationState)
            self.updateTone(presentationState, callContextState: callContextState, previous: previous)
        }

    }
    
    private func updateTone(_ state: CallState, callContextState: OngoingCallContextState?, previous: CallSession?) {
        var tone: CallTone?
        if let callContextState = callContextState, case .reconnecting = callContextState.state {
            tone = .connecting
        } else if let previous = previous {
            switch previous.state {
            case .accepting, .active, .dropping, .requesting:
                switch state.state {
                case .connecting:
                    if case .requesting = previous.state {
                        tone = .ringback
                    } else {
                        tone = .connecting
                    }
                case .requesting(true):
                    tone = .ringback
                case let .terminated(_, reason, _):
                    if let reason = reason {
                        switch reason {
                        case let .ended(type):
                            switch type {
                            case .busy:
                                tone = .busy
                            case .hungUp, .missed:
                                tone = .ended
                            }
                        case .error:
                            tone = .failed
                        }
                    }
                case .ringing:
                    tone = .ringing
                default:
                    break
                }
            default:
                break
            }
        } else if previous == nil && !isOutgoing {
            tone = .ringing
        }
        if let tone = tone {
            playTone(tone)
        } else {
            stopTone()
        }
    }
    

    
    deinit {
        peerDisposable.dispose()
        stateDisposable.dispose()
        drop(.disconnect)
        sessionStateDisposable.dispose()
        ongoingContextStateDisposable?.dispose()
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
        if let session = sessionState {
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
        case .busy:
            path = Bundle.main.path(forResource: "voip_busy", ofType:"caf")
        case .ringback:
            path = Bundle.main.path(forResource: "voip_ringback", ofType:"caf")
        case .connecting:
            path = Bundle.main.path(forResource: "voip_connecting", ofType:"mp3")
        case .failed:
            path = Bundle.main.path(forResource: "voip_fail", ofType:"caf")
        case .ended:
            path = Bundle.main.path(forResource: "voip_end", ofType:"caf")
        case .ringing:
            path = Bundle.main.path(forResource: "opening", ofType:"m4a")
        default:
            path = nil;
        }
        if let path = path {
            return URL(fileURLWithPath: path)
        } else {
            return nil
        }
    }
    
    private func loopsForTone(_ tone:CallTone) -> Int {
        switch tone {
        case .busy:
            return 3;
        case .ringback:
            return -1
        case .connecting:
            return -1
        case .failed:
            return 1
        case .ended:
            return 1
        case .ringing:
            return -1
        default:
            return 0
        }
    }
    
    private func playTone(_ tone:URL, loops:Int, completion:(()->Void)? = nil) {
        if self.player?.tone.path != tone.path {
            self.player = CallAudioPlayer(tone, loops: loops, completion: completion)
            self.player?.play()
        }
    }
    
    private func playTone(_ tone:CallTone) {
        if let url = pathForTone(tone) {
            playTone(url, loops: loopsForTone(tone))
        }
    }
    
    private func stopTone() {
        playingRingtone = false
        player?.stop()
        player = nil
    }
    
    func makeIncomingVideoView(completion: @escaping (NSView?) -> Void) {
        self.ongoingContext?.makeIncomingVideoView(completion: completion)
    }
    
    func makeOutgoingVideoView(completion: @escaping (NSView?) -> Void) {
        self.videoCapturer?.makeOutgoingVideoView(completion: completion)
    }
    
}

enum PCallResult {
    case success(PCallSession)
    case fail
    case samePeer(PCallSession)
}

func phoneCall(account: Account, sharedContext: SharedAccountContext, peerId:PeerId, ignoreSame:Bool = false, isVideo: Bool = false) -> Signal<PCallResult, NoError> {
    
    let signal: Signal<(Bool, Bool?), NoError>
    if isVideo {
        signal = combineLatest(queue: .mainQueue(), requestMicrophonePermission(), requestCameraPermission() |> map(Optional.init))
    } else {
        signal = combineLatest(queue: .mainQueue(), requestMicrophonePermission(), .single(nil))
    }
    
    return signal |> mapToSignal { microAccess, cameraAccess -> Signal<PCallResult, NoError> in
        
        if microAccess {
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
                        subscriber.putNext(.success(PCallSession(account: account, sharedContext: sharedContext, isOutgoing: true, peerId: peerId, id: id, initialState: nil, startWithVideo: isVideo, isVideoPossible: true)))
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
