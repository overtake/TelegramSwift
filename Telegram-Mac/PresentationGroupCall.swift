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
        case estabilished(info: GroupCallInfo, clientParams: String, localSsrc: UInt32, initialState: GroupCallParticipantsContext.State)
        
        var callInfo: GroupCallInfo? {
            switch self {
            case .requesting:
                return nil
            case let .active(info):
                return info
            case let .estabilished(info, _, _, _):
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
   public var audioLevels: Signal<[(PeerId, Float)], NoError> {
       return self.audioLevelsPipe.signal()
   }
   private var audioLevelsDisposable = MetaDisposable()
   
   private var participantsContextStateDisposable = MetaDisposable()
   private var participantsContext: GroupCallParticipantsContext?
   
   private let myAudioLevelPipe = ValuePipe<Float>()
   public var myAudioLevel: Signal<Float, NoError> {
       return self.myAudioLevelPipe.signal()
   }
   private var myAudioLevelDisposable = MetaDisposable()

    
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
            if case let .estabilished(callInfo, _, _, _) = strongSelf.internalState {
                /*var addedSsrc: [UInt32] = []
                var removedSsrc: [UInt32] = []*/
                for (callId, update) in updates {
                    if callId == callInfo.id {
                        strongSelf.participantsContext?.addUpdates(updates: [update])
                    }
                }
                /*if !addedSsrc.isEmpty {
                    strongSelf.callContext?.addSsrcs(ssrcs: addedSsrc)
                }
                if !removedSsrc.isEmpty {
                    strongSelf.callContext?.removeSsrcs(ssrcs: removedSsrc)
                }*/
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
        self.participantsContextStateDisposable.dispose()
        self.myAudioLevelDisposable.dispose()
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
                            strongSelf.updateSessionState(internalState: .estabilished(info: joinCallResult.callInfo, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state))
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
                    if !result.isEmpty {
                        strongSelf.audioLevelsPipe.putNext(result)
                    }
                }))
                
                self.myAudioLevelDisposable.set((callContext.myAudioLevel
                |> deliverOnMainQueue).start(next: { [weak self] level in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.myAudioLevelPipe.putNext(level)
                }))
            }
        }
        
        switch previousInternalState {
        case .estabilished:
            break
        default:
            if case let .estabilished(callInfo, clientParams, _, initialState) = internalState {
                self.ssrcMapping.removeAll()
                var ssrcs: [UInt32] = []
                for participant in initialState.participants {
                    self.ssrcMapping[participant.ssrc] = participant.peer.id
                    ssrcs.append(participant.ssrc)
                }
                self.callContext?.setJoinResponse(payload: clientParams, ssrcs: ssrcs)
                
                let participantsContext = GroupCallParticipantsContext(
                    account: self.account,
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    state: initialState
                )
                self.participantsContext = participantsContext
                self.participantsContextStateDisposable.set((participantsContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var memberStates: [PeerId: PresentationGroupCallMemberState] = [:]
                    for participant in state.participants {
                        strongSelf.ssrcMapping[participant.ssrc] = participant.peer.id
                        
                        memberStates[participant.peer.id] = PresentationGroupCallMemberState(
                            ssrc: participant.ssrc,
                            muteState: participant.muteState
                        )
                    }
                    strongSelf.membersValue = memberStates
                }))
                
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
        if case let .estabilished(callInfo, _, ssrc, _) = self.internalState {
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

    
    
    public func leave() -> Signal<Bool, NoError> {
        if case let .estabilished(callInfo, _, _, _) = self.internalState {
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
    
    public func updateMuteState(peerId: PeerId, isMuted: Bool) {
        self.participantsContext?.updateMuteState(peerId: peerId, muteState: isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: peerId == self.account.peerId) : nil)
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
       
       /*let restartedCall = currentOrRequestedCall
       |> mapToSignal { value -> Signal<GroupCallInfo, CallError> in
           let stopped: Signal<GroupCallInfo, CallError> = stopGroupCall(account: account, callId: value.id, accessHash: value.accessHash)
           |> mapError { _ -> CallError in
               return .generic
           }
           |> map { _ -> GroupCallInfo in
           }
               
           return stopped
           |> then(currentOrRequestedCall)
       }*/
       
       self.requestDisposable.set((currentOrRequestedCall
       |> deliverOnMainQueue).start(next: { [weak self] value in
           guard let strongSelf = self else {
               return
           }
           strongSelf.updateSessionState(internalState: .active(value))
       }))
   }

}

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
