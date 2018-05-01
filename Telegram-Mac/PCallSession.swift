//
//  CallSession.swift
//  Telegram
//
//  Created by keepcoder on 03/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac
import TGUIKit

enum CallTone {
    case callToneUndefined
    case callToneRingback
    case callToneBusy
    case callToneConnecting
    case callToneFailed
    case callToneEnded
}




enum VoIPState : Int {
    case waitInit = 1
    case waitInitAck = 2
    case established = 3
    case failed = 4
}

let callQueue = Queue(name: "VoIPQueue")

private var callSession:PCallSession? = nil

func pullCurrentSession(_ f:@escaping (PCallSession?)->Void) {
    callQueue.async {
        f(callSession)
    }
}



class PCallSession {
    let peerId:PeerId
    let account:Account
    let id:CallSessionInternalId
    
    private var contextRef: Unmanaged<CallBridge>?
    
    private let stateDisposable = MetaDisposable()
    private let timeoutDisposable = MetaDisposable()
    
    let state:Promise<CallSessionState> = Promise()
    private(set) var isMute:Bool = false
    private var player:CallAudioPlayer? = nil
    private var playingRingtone:Bool = false
    
    private var startTime:Double = 0
    private var callAcceptedTime:Double = 0
    
    private var tranmissionState:VoIPState = .waitInit
    private var completed: Bool = false
    let durationPromise:Promise<TimeInterval> = Promise()
    private var callSessionValue:CallSession? = nil
    private let proxyDisposable = MetaDisposable()
    init(account:Account, peerId:PeerId, id: CallSessionInternalId) {
        
        Queue.mainQueue().async {
            _ = globalAudio?.pause()
        }
        
        assert(callQueue.isCurrent())
        
        self.account = account
        self.peerId = peerId
        self.id = id

        let signal = account.callSessionManager.callState(internalId: id) |> deliverOnMainQueue |> beforeNext { [weak self] session in
            self?.proccessState(session)
        }
        
        state.set(signal |> map {$0.state})
        
        proxyDisposable.set((proxySettingsSignal(account.postbox) |> deliverOn(callQueue) |> take(1)).start(next: { [weak self] settings in
            guard let `self` = self else {return}
            callSession = self
            let bridge:CallBridge
            if let server = settings.effectiveActiveServer {
                switch server.connection {
                case let .socks5(username, password):
                    bridge = CallBridge(proxy: CProxy(host: server.host, port: server.port, user: username != nil ? username : "", pass: password != nil ? password : ""))
                default:
                    bridge = CallBridge(proxy: nil)
                }
            } else {
                bridge = CallBridge(proxy: nil)
            }
            
            if let inputDeviceId = UserDefaults.standard.object(forKey: "call_inputDevice") as? String {
                bridge.setCurrentInputDeviceId(inputDeviceId)
            }
            if let outputDeviceId = UserDefaults.standard.object(forKey: "call_outputDevice") as? String {
                bridge.setCurrentOutputDeviceId(outputDeviceId)
            }
            
            
            self.contextRef = Unmanaged.passRetained(bridge)
            bridge.stateChangeHandler = { value in
                callQueue.async {
                    if let state = VoIPState(rawValue: Int(value)) {
                        self.voipStateChanged(state)
                    }
                }
            }
        }))
        
        callQueue.async {
           
        }
        
       
        
    }
    
    private func voipStateChanged(_ state:VoIPState) {
        switch state {
        case .established:
            if (startTime < Double.ulpOfOne) {
                stopAudio()
                startTime = CFAbsoluteTimeGetCurrent();
                durationPromise.set((.single(duration) |> deliverOnMainQueue) |> then (Signal<()->TimeInterval, Void>.single({[weak self] in return self?.duration ?? 0}) |> map {$0()} |> delay(1.01, queue: Queue.mainQueue()) |> restart))
            }
        case .failed:
            playTone(.callToneFailed)
            discardCurrentCallWithReason(.error(.disconnected))
        default:
            break
        }
    }
    
    private func startTimeout(_ duration:TimeInterval, discardReason: CallSessionTerminationReason) {
        timeoutDisposable.set((Signal<Void, Void>.complete() |> delay(duration, queue: Queue.mainQueue())).start(completed: { [weak self] in
            self?.discardCurrentCallWithReason(discardReason)
        }))
    }
    
    func inputDevices() -> Signal<[AudioDevice], Void> {
        return Signal { [weak self] subscriber in
            var cancel = false
            self?.withContext { context in
                if !cancel {
                    subscriber.putNext(context.inputDevices())
                    subscriber.putCompletion()
                }
            }
            return ActionDisposable {
                cancel = true
            }
        }
    }
    
    func currentInputDeviceId()-> Signal<String, Void> {
        return Signal { [weak self] subscriber in
            var cancel = false
            self?.withContext { context in
                if !cancel {
                    subscriber.putNext(context.currentInputDeviceId())
                    subscriber.putCompletion()
                }
            }
            return ActionDisposable {
                cancel = true
            }
        }
    }
    func currentOutputDeviceId()-> Signal<String, Void> {
        return Signal { [weak self] subscriber in
            var cancel = false
            self?.withContext { context in
                if !cancel {
                    subscriber.putNext(context.currentOutputDeviceId())
                    subscriber.putCompletion()
                }
            }
            return ActionDisposable {
                cancel = true
            }
        }
    }
    func setCurrentInputDevice(_ device:AudioDevice) {
        UserDefaults.standard.set(device.deviceId, forKey: "call_inputDevice")
        UserDefaults.standard.synchronize()
        withContext { context in
            context.setCurrentInputDeviceId(device.deviceId);
        }
    }
    
    func setCurrentOutputDevice(_ device:AudioDevice) {
        UserDefaults.standard.set(device.deviceId, forKey: "call_outputDevice")
        UserDefaults.standard.synchronize()
        withContext { context in
            context.setCurrentOutputDeviceId(device.deviceId);
        }
    }
    
    func outputDevices() -> Signal<[AudioDevice], Void> {
        return Signal { [weak self] subscriber in
            var cancel = false
            self?.withContext { context in
                if !cancel {
                    subscriber.putNext(context.outputDevices())
                    subscriber.putCompletion()
                }
            }
            return ActionDisposable {
                cancel = true
            }
        }
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
    
    func stopTransmission() {
        durationPromise.set(.complete())
        callQueue.async {
            callSession = nil
            self.contextRef?.release()
            self.contextRef = nil
        }
    }
    
    func drop(_ reason:DropCallReason) {
        account.callSessionManager.drop(internalId: id, reason: reason)
    }
    
    func acceptCallSession() {
        callAcceptedTime = CFAbsoluteTimeGetCurrent()
        account.callSessionManager.accept(internalId: id)
    }
    
    func mute() {
        isMute = true
        withContext { context in
            context.mute()
        }
    }
    
    func unmute() {
        isMute = false
        withContext { context in
            context.unmute()
        }
    }
    
    func toggleMute() {
        self.isMute = !self.isMute
        withContext { context in
            if context.isMuted() {
                context.unmute()
            } else {
                context.mute()
            }
        }
    }
    
    private func proccessState(_ session: CallSession) {
        self.callSessionValue = session
        
        switch session.state {
        case .active(let key, _, let connection, let maxLayer):
            playTone(.callToneConnecting)
            
            let cdata = TGCallConnection(key: key, keyHash: key, defaultConnection: TGCallConnectionDescription(identifier: connection.primary.id, ipv4: connection.primary.ip, ipv6: connection.primary.ipv6, port: connection.primary.port, peerTag: connection.primary.peerTag), alternativeConnections: connection.alternatives.map {TGCallConnectionDescription(identifier: $0.id, ipv4: $0.ip, ipv6: $0.ipv6, port: $0.port, peerTag: $0.peerTag)}, maxLayer: maxLayer)
            
            withContext { context in
                context.startTransmissionIfNeeded(session.isOutgoing, connection: cdata)
            }
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
        case .terminated(let reason, let report):
            stopTransmission()
            invalidateTimeout()
            switch reason {
            case .error:
                playTone(.callToneFailed)
            default:
                playTone(.callToneEnded)
            }
//            if let report = report {
//                let account = self.account
//                Queue.mainQueue().async {
//                    showModal(with: CallRatingModalViewController(account, report: report), for: mainWindow)
//                }
//            }
            
        default:
            break
        }
    }
    
    deinit {
        stateDisposable.dispose()
        drop(.disconnect)
        proxyDisposable.dispose()
        let contextRef = self.contextRef
        callQueue.async {
            contextRef?.release()
        }
    }
    
    private func playRingtone() {
        playingRingtone = true
        if let path = Bundle.main.path(forResource: "opening", ofType:"m4a") {
            playTone(URL(fileURLWithPath: path), loops: -1)
        }
        
    }
    
    
    private func withContext(_ f: @escaping (CallBridge) -> Void) {
        callQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                f(context)
            }
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
    
}

enum PCallResult {
    case success(PCallSession)
    case fail
    case samePeer(PCallSession)
}

func phoneCall(_ account:Account, peerId:PeerId, ignoreSame:Bool = false) -> Signal<PCallResult, Void> {
    return Signal { subscriber in
        
        assert(callQueue.isCurrent())
        
        if let session = callSession, session.peerId == peerId, !ignoreSame {
            subscriber.putNext(.samePeer(session))
            subscriber.putCompletion()
        } else {
            let confirmation:Signal<Bool, Void>
            if let session = callSession {
                confirmation = account.postbox.loadedPeerWithId(peerId) |> mapToSignal { peer -> Signal<(new:Peer, previous:Peer), Void> in
                    return account.postbox.loadedPeerWithId(session.peerId) |> map {(new:peer, previous:$0)}
                } |> mapToSignal { value in
                    return confirmSignal(for: mainWindow, header: tr(L10n.callConfirmDiscardCurrentHeader), information: tr(L10n.callConfirmDiscardCurrentDescription(value.previous.compactDisplayTitle, value.new.displayTitle)))
                }

            } else {
                confirmation = .single(true)
            }
            
            return (confirmation |> filter {$0} |> map { _ in
                callSession?.hangUpCurrentCall()
            } |> mapToSignal { _ in return account.callSessionManager.request(peerId: peerId) } |> deliverOn(callQueue) ).start(next: { id in
                subscriber.putNext(.success(PCallSession(account: account, peerId: peerId, id: id)))
                subscriber.putCompletion()
            })
        }
        
        return EmptyDisposable
        
    } |> runOn(callQueue)
}

func _callSession() -> Signal<PCallSession?, Void> {
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
