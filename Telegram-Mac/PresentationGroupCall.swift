import Cocoa
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AVFoundation
import TelegramVoip

private extension PresentationGroupCallState {
    static var initialValue: PresentationGroupCallState {
        return PresentationGroupCallState(
            networkState: .connecting,
            isMuted: true
        )
    }
}

final class PresentationGroupCallImpl: PresentationGroupCall {
    private enum InternalState {
        case requesting
        case active(GroupCallInfo)
        case estabilished(GroupCallInfo, String, UInt32, [UInt32], [UInt32: PeerId])
        
        var callInfo: GroupCallInfo? {
            switch self {
            case .requesting:
                return nil
            case let .active(info):
                return info
            case let .estabilished(info, _, _, _, _):
                return info
            }
        }
    }
    
    let account: Account
    let sharedContext: SharedAccountContext
    
    let internalId: CallSessionInternalId
    let peerId: PeerId
    let peer: Peer?
    
    private var internalState: InternalState = .requesting
    
    private var callContext: OngoingGroupCallContext?
    private var ssrcMapping: [UInt32: PeerId] = [:]
    
    
    private let isMutedPromise = ValuePromise<Bool>(true)
    private var isMutedValue = true
    var isMuted: Signal<Bool, NoError> {
        return self.isMutedPromise.get()
    }
        
    private let audioLevelsPipe = ValuePipe<[(PeerId, Float)]>()
    var audioLevels: Signal<[(PeerId, Float)], NoError> {
        return self.audioLevelsPipe.signal()
    }
    private var audioLevelsDisposable = MetaDisposable()
    
    private let _canBeRemoved = Promise<Bool>(false)
    var canBeRemoved: Signal<Bool, NoError> {
        return self._canBeRemoved.get()
    }
    
    private var stateValue = PresentationGroupCallState.initialValue {
        didSet {
            if self.stateValue != oldValue {
                self.statePromise.set(self.stateValue)
            }
        }
    }
    private let statePromise = ValuePromise<PresentationGroupCallState>(PresentationGroupCallState.initialValue)
    var state: Signal<PresentationGroupCallState, NoError> {
        return self.statePromise.get()
    }
    
    private var membersValue: [PeerId: PresentationGroupCallMemberState] = [:] {
        didSet {
            if self.membersValue != oldValue {
                self.membersPromise.set(self.membersValue)
            }
        }
    }
    private let membersPromise = ValuePromise<[PeerId: PresentationGroupCallMemberState]>([:])
    var members: Signal<[PeerId: PresentationGroupCallMemberState], NoError> {
        return self.membersPromise.get()
    }
    
    private let requestDisposable = MetaDisposable()
    private var groupCallParticipantUpdatesDisposable: Disposable?
    
    private let networkStateDisposable = MetaDisposable()
    private let isMutedDisposable = MetaDisposable()
    private let memberStatesDisposable = MetaDisposable()
    private let leaveDisposable = MetaDisposable()
    
    private var checkCallDisposable: Disposable?
    private var isCurrentlyConnecting: Bool?
    
    init(
        account: Account,
        sharedContext: SharedAccountContext,
        internalId: CallSessionInternalId,
        peerId: PeerId,
        peer: Peer?
    ) {
        self.account = account
        self.sharedContext = sharedContext
        self.internalId = internalId
        self.peerId = peerId
        self.peer = peer
                
        
        self.groupCallParticipantUpdatesDisposable = (self.account.stateManager.groupCallParticipantUpdates
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let strongSelf = self else {
                return
            }
            if case let .estabilished(callInfo, _, _, _, _) = strongSelf.internalState {
                var addedSsrc: [UInt32] = []
                var removedSsrc: [UInt32] = []
                for (callId, peerId, ssrc, isAdded) in updates {
                    if callId == callInfo.id {
                        let mappedSsrc = UInt32(bitPattern: ssrc)
                        if isAdded {
                            addedSsrc.append(mappedSsrc)
                            strongSelf.ssrcMapping[mappedSsrc] = peerId
                        } else {
                            removedSsrc.append(mappedSsrc)
                        }
                    }
                }
                if !addedSsrc.isEmpty {
                    strongSelf.callContext?.addSsrcs(ssrcs: addedSsrc)
                }
                if !removedSsrc.isEmpty {
                    strongSelf.callContext?.removeSsrcs(ssrcs: removedSsrc)
                }
            }
        })
        
        self.requestCall()
    }
    
    deinit {
        self.requestDisposable.dispose()
        self.groupCallParticipantUpdatesDisposable?.dispose()
        self.leaveDisposable.dispose()
        self.isMutedDisposable.dispose()
        self.memberStatesDisposable.dispose()
        self.networkStateDisposable.dispose()
        self.checkCallDisposable?.dispose()
        self.audioLevelsDisposable.dispose()
    }
    
    private func updateSessionState(internalState: InternalState) {
        
        let previousInternalState = self.internalState
        self.internalState = internalState
        
        
        switch previousInternalState {
        case .requesting:
            break
        default:
            if case .requesting = internalState {
                self.isCurrentlyConnecting = nil
            }
        }
        
        switch previousInternalState {
        case .active:
            break
        default:
            if case let .active(callInfo) = internalState {
                let callContext = OngoingGroupCallContext()
                self.callContext = callContext
                self.requestDisposable.set((callContext.joinPayload
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] joinPayload, ssrc in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.requestDisposable.set((joinGroupCall(
                        account: strongSelf.account,
                        callId: callInfo.id,
                        accessHash: callInfo.accessHash,
                        joinPayload: joinPayload
                    )
                    |> deliverOnMainQueue).start(next: { joinCallResult in
                        guard let strongSelf = self else {
                            return
                        }
                        if let clientParams = joinCallResult.callInfo.clientParams {
                            strongSelf.updateSessionState(internalState: .estabilished(joinCallResult.callInfo, clientParams, ssrc, joinCallResult.ssrcs, joinCallResult.ssrcMapping))
                        }
                    }))
                }))
                
                self.isMutedDisposable.set((callContext.isMuted
                |> deliverOnMainQueue).start(next: { [weak self] isMuted in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.stateValue.isMuted = isMuted
                }))
                
                self.networkStateDisposable.set((callContext.networkState
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let strongSelf = self else {
                        return
                    }
                    let mappedState: PresentationGroupCallState.NetworkState
                    switch state {
                    case .connecting:
                        mappedState = .connecting
                    case .connected:
                        mappedState = .connected
                    }
                    if strongSelf.stateValue.networkState != mappedState {
                        strongSelf.stateValue.networkState = mappedState
                    }
                    
                    let isConnecting = mappedState == .connecting
                    
                    if strongSelf.isCurrentlyConnecting != isConnecting {
                        strongSelf.isCurrentlyConnecting = isConnecting
                        if isConnecting {
                            strongSelf.startCheckingCallIfNeeded()
                        } else {
                            strongSelf.checkCallDisposable?.dispose()
                            strongSelf.checkCallDisposable = nil
                        }
                    }
                }))
                
                self.memberStatesDisposable.set((callContext.memberStates
                |> deliverOnMainQueue).start(next: { [weak self] memberStates in
                    guard let strongSelf = self else {
                        return
                    }
                    var result: [PeerId: PresentationGroupCallMemberState] = [:]
                    for (ssrc, _) in memberStates {
                        if let peerId = strongSelf.ssrcMapping[ssrc] {
                            result[peerId] = PresentationGroupCallMemberState(
                                ssrc: ssrc,
                                isSpeaking: false
                            )
                        }
                    }
                    strongSelf.membersValue = result
                }))
                
                self.audioLevelsDisposable.set((callContext.audioLevels
                |> deliverOnMainQueue).start(next: { [weak self] levels in
                    guard let strongSelf = self else {
                        return
                    }
                    var result: [(PeerId, Float)] = []
                    for (ssrc, level) in levels {
                        if let peerId = strongSelf.ssrcMapping[ssrc] {
                            result.append((peerId, level))
                        }
                    }
                    strongSelf.audioLevelsPipe.putNext(result)
                }))
            }
        }
        
        switch previousInternalState {
        case .estabilished:
            break
        default:
            if case let .estabilished(_, clientParams, _, ssrcs, ssrcMapping) = internalState {
                self.ssrcMapping = ssrcMapping
                self.callContext?.setJoinResponse(payload: clientParams, ssrcs: ssrcs)
                if let isCurrentlyConnecting = self.isCurrentlyConnecting, isCurrentlyConnecting {
                    self.startCheckingCallIfNeeded()
                }
            }
        }
    }
    
    private func startCheckingCallIfNeeded() {
        if self.checkCallDisposable != nil {
            return
        }
        if case let .estabilished(callInfo, _, ssrc, _, _) = self.internalState {
            let checkSignal = checkGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, ssrc: Int32(bitPattern: ssrc))
            
            self.checkCallDisposable = ((
                checkSignal
                |> castError(Bool.self)
                |> delay(4.0, queue: .mainQueue())
                |> mapToSignal { result -> Signal<Bool, Bool> in
                    if case .success = result {
                        return .fail(true)
                    } else {
                        return .single(true)
                    }
                }
            )
            |> restartIfError
            |> take(1)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.checkCallDisposable = nil
                strongSelf.requestCall()
            })
        }
    }
    
    
    func leave() -> Signal<Bool, NoError> {
        if case let .estabilished(callInfo, _, _, _, _) = self.internalState {
            self.leaveDisposable.set((leaveGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                self?._canBeRemoved.set(.single(true))
            }))
        } else {
        }
        return self._canBeRemoved.get()
    }
    
    func toggleIsMuted() {
        self.setIsMuted(!self.isMutedValue)
    }
    
    func setIsMuted(_ value: Bool) {
        self.isMutedValue = value
        self.isMutedPromise.set(self.isMutedValue)
        self.callContext?.setIsMuted(self.isMutedValue)
    }
    
    func setCurrentAudioOutput(_ output: AudioSessionOutput) {
        
    }
    
    private func requestCall() {
        self.callContext?.stop()
        self.callContext = nil
        
        self.internalState = .requesting
        self.isCurrentlyConnecting = nil
        
        enum CallError {
            case generic
        }
        
        let account = self.account
        let peerId = self.peerId
        
        let currentCall = getCurrentGroupCall(account: account, peerId: peerId)
        |> mapError { _ -> CallError in
            return .generic
        }
        
        let currentOrRequestedCall = currentCall
        |> mapToSignal { callInfo -> Signal<GroupCallInfo, CallError> in
            if let callInfo = callInfo {
                return .single(callInfo)
            } else {
                return createGroupCall(account: account, peerId: peerId)
                |> mapError { _ -> CallError in
                    return .generic
                }
            }
        }
        
        let restartedCall = currentOrRequestedCall
        |> mapToSignal { value -> Signal<GroupCallInfo, CallError> in
            let stopped: Signal<GroupCallInfo, CallError> = stopGroupCall(account: account, callId: value.id, accessHash: value.accessHash)
            |> mapError { _ -> CallError in
                return .generic
            }
            |> map { _ -> GroupCallInfo in
            }
                
            return stopped
            |> then(currentOrRequestedCall)
        }
        
        self.requestDisposable.set((currentOrRequestedCall
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateSessionState(internalState: .active(value))
        }))
    }
}



//
//func phoneGroupCall(account: Account, sharedContext: SharedAccountContext, peerId:PeerId, ignoreSame:Bool = false) -> Signal<PCallResult, NoError> {
//
//    let signal: Signal<Bool, NoError> = requestMicrophonePermission()
//
//    let accounts = sharedContext.activeAccounts |> take(1)
//
//
//    return combineLatest(queue: .mainQueue(), signal, accounts) |> mapToSignal { values -> Signal<PCallResult, NoError> in
//
//        microAccess = values.0
//        let activeAccounts = values.2
//
//        for account in activeAccounts.accounts {
//            if account.1.peerId == peerId {
//                alert(for: mainWindow, info: L10n.callSameDeviceError)
//                return .complete()
//            }
//        }
//
//        if microAccess {
//            if let session = sharedContext.bindings.callSession(), session.peerId == peerId, !ignoreSame {
//                return .single(.samePeer(session))
//            } else {
//                let confirmation:Signal<Bool, NoError>
//                if let sessionPeerId = sharedContext.bindings.callSession()?.peerId {
//                    confirmation = account.postbox.loadedPeerWithId(peerId) |> mapToSignal { peer -> Signal<(new:Peer, previous:Peer), NoError> in
//                        return account.postbox.loadedPeerWithId(sessionPeerId) |> map { (new: peer, previous: $0) }
//                        } |> mapToSignal { value in
//                            return confirmSignal(for: mainWindow, header: L10n.callConfirmDiscardCurrentHeader, information: L10n.callConfirmDiscardCurrentDescription(value.previous.compactDisplayTitle, value.new.displayTitle))
//                    }
//
//                } else {
//                    confirmation = .single(true)
//                }
//
//                return confirmation |> filter {$0} |> map { _ in
//                    sharedContext.bindings.callSession()?.hangUpCurrentCall()
//                    } |> mapToSignal { _ in
//                        return account.callSessionManager.request(peerId: peerId, isVideo: isVideo, enableVideo: isVideoPossible)
//                    }
//                    |> deliverOn(callQueue)
//                    |> map { id in
//                        return .success(PCallSession(account: account, sharedContext: sharedContext, isOutgoing: true, peerId: peerId, id: id, initialState: nil, startWithVideo: isVideo, isVideoPossible: isVideoPossible))
//                }
//            }
//        } else {
//            confirm(for: mainWindow, information: L10n.requestAccesErrorHaveNotAccessCall, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
//                switch result {
//                case .thrid:
//                    openSystemSettings(.microphone)
//                default:
//                    break
//                }
//            })
//            return .complete()
//        }
//    }
//}

func requestOrJoinGroupCall(context: AccountContext, peerId: PeerId) -> Signal<RequestOrJoinGroupCallResult, NoError> {
    let signal: Signal<Bool, NoError> = requestMicrophonePermission()
    let sharedContext = context.sharedContext
    let accounts = context.sharedContext.activeAccounts |> take(1)
    let account = context.account
    
    return combineLatest(queue: .mainQueue(), signal, accounts, account.postbox.loadedPeerWithId(peerId)) |> mapToSignal { micro, accounts, peer in
        if let context = sharedContext.bindings.groupCall(), context.call.peerId == peerId {
            return .single(.samePeer(context))
        } else {
            return .single(.success(startGroupCall(context: context, peerId: peerId, peer: peer)))
        }
    }
    
}


private func startGroupCall(context: AccountContext, peerId: PeerId, internalId: CallSessionInternalId = CallSessionInternalId(), peer: Peer? = nil) -> GroupCallContext {
    return GroupCallContext(call: PresentationGroupCallImpl(
        account: context.account,
        sharedContext: context.sharedContext,
        internalId: internalId,
        peerId: peerId,
        peer: peer
    ), peerMemberContextsManager: context.peerChannelMemberCategoriesContextsManager)
}





/*
 

 public func requestOrJoinGroupCall(context: AccountContext, peerId: PeerId) -> RequestOrJoinGroupCallResult {
     if let currentGroupCall = self.currentGroupCallValue {
         return .alreadyInProgress(currentGroupCall.peerId)
     }
     let _ = self.startGroupCall(accountContext: context, peerId: peerId).start()
     return .requested
 }
 

 */
