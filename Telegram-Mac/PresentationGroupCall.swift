import Cocoa
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AVFoundation
import TelegramVoip
import TGUIKit

protocol AccountGroupCallContext: class {
}

protocol AccountGroupCallContextCache: class {
}



final class AccountGroupCallContextImpl: AccountGroupCallContext {
    final class Proxy {
        let context: AccountGroupCallContextImpl
        let removed: () -> Void
        
        init(context: AccountGroupCallContextImpl, removed: @escaping () -> Void) {
            self.context = context
            self.removed = removed
        }
        
        deinit {
            self.removed()
        }
        
        func keep() {
        }
    }
    
    var disposable: Disposable?
    var participantsContext: GroupCallParticipantsContext?
    
    private let panelDataPromise = Promise<GroupCallPanelData>()
    var panelData: Signal<GroupCallPanelData, NoError> {
        return self.panelDataPromise.get()
    }
    
    init(account: Account, peerId: PeerId, call: CachedChannelData.ActiveCall) {
        self.panelDataPromise.set(.single(GroupCallPanelData(
            peerId: peerId,
            info: GroupCallInfo(
                id: call.id,
                accessHash: call.accessHash,
                participantCount: 0,
                clientParams: nil
            ),
            topParticipants: [],
            participantCount: 0,
            activeSpeakers: Set(),
            groupCall: nil
        )))
        
        self.disposable = (getGroupCallParticipants(account: account, callId: call.id, accessHash: call.accessHash, offset: "", limit: 100)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<GroupCallParticipantsContext.State?, NoError> in
            return .single(nil)
        }
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self, let state = state else {
                return
            }
            let context = GroupCallParticipantsContext(
                account: account,
                peerId: peerId,
                id: call.id,
                accessHash: call.accessHash,
                state: state
            )
            strongSelf.participantsContext = context
            strongSelf.panelDataPromise.set(combineLatest(queue: .mainQueue(),
                context.state,
                context.activeSpeakers
            )
            |> map { state, activeSpeakers -> GroupCallPanelData in
                var topParticipants: [GroupCallParticipantsContext.Participant] = []
                for participant in state.participants {
                    if topParticipants.count >= 3 {
                        break
                    }
                    topParticipants.append(participant)
                }
                return GroupCallPanelData(
                    peerId: peerId,
                    info: GroupCallInfo(id: call.id, accessHash: call.accessHash, participantCount: state.totalCount, clientParams: nil),
                    topParticipants: topParticipants,
                    participantCount: state.totalCount,
                    activeSpeakers: activeSpeakers,
                    groupCall: nil
                )
            })
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

final class AccountGroupCallContextCacheImpl: AccountGroupCallContextCache {
    class Impl {
        private class Record {
            let context: AccountGroupCallContextImpl
            let subscribers = Bag<Void>()
            var removeTimer: SwiftSignalKit.Timer?
            
            init(context: AccountGroupCallContextImpl) {
                self.context = context
            }
        }
        
        private let queue: Queue
        private var contexts: [Int64: Record] = [:]
        
        init(queue: Queue) {
            self.queue = queue
        }
        
        func get(account: Account, peerId: PeerId, call: CachedChannelData.ActiveCall) -> AccountGroupCallContextImpl.Proxy {
            let result: Record
            if let current = self.contexts[call.id] {
                result = current
            } else {
                let context = AccountGroupCallContextImpl(account: account, peerId: peerId, call: call)
                result = Record(context: context)
                self.contexts[call.id] = result
            }
            
            let index = result.subscribers.add(Void())
            result.removeTimer?.invalidate()
            result.removeTimer = nil
            return AccountGroupCallContextImpl.Proxy(context: result.context, removed: { [weak self, weak result] in
                Queue.mainQueue().async {
                    if let strongResult = result, let strongSelf = self, strongSelf.contexts[call.id] === strongResult {
                        strongResult.subscribers.remove(index)
                        if strongResult.subscribers.isEmpty {
                            let removeTimer = SwiftSignalKit.Timer(timeout: 30, repeat: false, completion: {
                                if let result = result, let strongSelf = self, strongSelf.contexts[call.id] === result, result.subscribers.isEmpty {
                                    strongSelf.contexts.removeValue(forKey: call.id)
                                }
                            }, queue: .mainQueue())
                            strongResult.removeTimer = removeTimer
                            removeTimer.start()
                        }
                    }
                }
            })
        }
    }
    
    let queue: Queue = .mainQueue()
    let impl: QueueLocalObject<Impl>
    
    init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
}



private extension PresentationGroupCallState {
    static var initialValue: PresentationGroupCallState {
        return PresentationGroupCallState(
            networkState: .connecting,
            canManageCall: false,
            adminIds: Set(),
            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true),
            defaultParticipantMuteState: nil
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
    
    private struct SummaryInfoState: Equatable {
          var info: GroupCallInfo
          
          init(
              info: GroupCallInfo
          ) {
              self.info = info
          }
      }
      
    private struct SummaryParticipantsState: Equatable {
           var participantCount: Int
           var topParticipants: [GroupCallParticipantsContext.Participant]
           var activeSpeakers: Set<PeerId>
           
           init(
               participantCount: Int,
               topParticipants: [GroupCallParticipantsContext.Participant],
               activeSpeakers: Set<PeerId>
           ) {
               self.participantCount = participantCount
               self.topParticipants = topParticipants
               self.activeSpeakers = activeSpeakers
           }
       }

    private class SpeakingParticipantsContext {
       private let speakingLevelThreshold: Float = 0.1
       private let cutoffTimeout: Int32 = 3
       private let silentTimeout: Int32 = 2
       
       struct Participant {
           let timestamp: Int32
           let level: Float
       }
       
       private var participants: [PeerId: Participant] = [:]
       private let speakingParticipantsPromise = ValuePromise<Set<PeerId>>()
       private var speakingParticipants = Set<PeerId>() {
           didSet {
               self.speakingParticipantsPromise.set(self.speakingParticipants)
           }
       }
       
       private let audioLevelsPromise = Promise<[(PeerId, Float, Bool)]>()

       init() {
       }
       
        func update(levels: [(PeerId, Float, Bool)]) {
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            let currentParticipants: [PeerId: Participant] = self.participants

            var validSpeakers: [PeerId: Participant] = [:]
            var silentParticipants = Set<PeerId>()
            var speakingParticipants = Set<PeerId>()
            for (peerId, level, hasVoice) in levels {
                if level > speakingLevelThreshold && hasVoice {
                    validSpeakers[peerId] = Participant(timestamp: timestamp, level: level)
                    speakingParticipants.insert(peerId)
                } else {
                    silentParticipants.insert(peerId)
                }
            }

            for (peerId, participant) in currentParticipants {
                if let _ = validSpeakers[peerId] {
                } else {
                    let delta = timestamp - participant.timestamp
                    if silentParticipants.contains(peerId) {
                        if delta < silentTimeout {
                            validSpeakers[peerId] = participant
                            speakingParticipants.insert(peerId)
                        }
                    } else if delta < cutoffTimeout {
                        validSpeakers[peerId] = participant
                        speakingParticipants.insert(peerId)
                    }
                }
            }

            var audioLevels: [(PeerId, Float, Bool)] = []
            for (peerId, level, hasVoice) in levels {
                if level > 0.001 {
                    audioLevels.append((peerId, level, hasVoice))
                }
            }
        
            self.participants = validSpeakers
            self.speakingParticipants = speakingParticipants
            self.audioLevelsPromise.set(.single(audioLevels))
        }

       
       func get() -> Signal<Set<PeerId>, NoError> {
           return self.speakingParticipantsPromise.get() |> distinctUntilChanged
       }
       
        func getAudioLevels() -> Signal<[(PeerId, Float, Bool)], NoError> {
            return self.audioLevelsPromise.get()
        }
   }



    
    let account: Account
    let sharedContext: SharedAccountContext
    
    let internalId: CallSessionInternalId
    let peerId: PeerId
    let peer: Peer?
    let initialCall: CachedChannelData.ActiveCall?
    
    private var internalState: InternalState = .requesting
    
    private var callContext: OngoingGroupCallContext?
    private var ssrcMapping: [UInt32: PeerId] = [:]
    
    private var summaryInfoState = Promise<SummaryInfoState?>(nil)
    private var summaryParticipantsState = Promise<SummaryParticipantsState?>(nil)
   
    private let summaryStatePromise = Promise<PresentationGroupCallSummaryState?>(nil)
    var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> {
        return self.summaryStatePromise.get()
    }
    private var summaryStateDisposable: Disposable?

    
    private var isMutedValue: PresentationGroupCallMuteAction = .muted(isPushToTalkActive: false) {
        didSet {
            var bp:Int = 0
            bp += 1
        }
    }
    private let isMutedPromise = ValuePromise<PresentationGroupCallMuteAction>(.muted(isPushToTalkActive: false))
    var isMuted: Signal<Bool, NoError> {
        return self.isMutedPromise.get()
        |> map { value -> Bool in
            switch value {
            case let .muted(isPushToTalkActive):
                return !isPushToTalkActive
            case .unmuted:
                return false
            }
        }
    }
    
    var permissions: (PresentationGroupCallMuteAction, @escaping(Bool)->Void)->Void = { _, f in f(true) }

        
    
    private let speakingParticipantsContext = SpeakingParticipantsContext()
    private var speakingParticipantsReportTimestamp: [PeerId: Double] = [:]
    public var audioLevels: Signal<[(PeerId, Float, Bool)], NoError> {
        return self.speakingParticipantsContext.getAudioLevels()
    }



    
   private var audioLevelsDisposable = MetaDisposable()

   private var participantsContextStateDisposable = MetaDisposable()
   private var participantsContext: GroupCallParticipantsContext?
   
   private let myAudioLevelPipe = ValuePipe<Float>()
   var myAudioLevel: Signal<Float, NoError> {
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
       
    
    private var membersValue: PresentationGroupCallMembers? {
        didSet {
            if self.membersValue != oldValue {
                self.membersPromise.set(self.membersValue)
            }
        }
    }
    private let membersPromise = ValuePromise<PresentationGroupCallMembers?>(nil, ignoreRepeated: true)
    var members: Signal<PresentationGroupCallMembers?, NoError> {
        return self.membersPromise.get()
    }

    
    private var invitedPeersValue: Set<PeerId> = Set() {
        didSet {
            if self.invitedPeersValue != oldValue {
                self.inivitedPeersPromise.set(self.invitedPeersValue)
            }
        }
    }
    private let inivitedPeersPromise = ValuePromise<Set<PeerId>>(Set())
    var invitedPeers: Signal<Set<PeerId>, NoError> {
        return self.inivitedPeersPromise.get()
    }

    
    private let requestDisposable = MetaDisposable()
    private var groupCallParticipantUpdatesDisposable: Disposable?
    
    private let networkStateDisposable = MetaDisposable()
    private let isMutedDisposable = MetaDisposable()
    private let memberStatesDisposable = MetaDisposable()
    private let leaveDisposable = MetaDisposable()
    private let devicesDisposable = MetaDisposable()
    private let muteStateDisposable = MetaDisposable()
    
    private var checkCallDisposable: Disposable?
    private var isCurrentlyConnecting: Bool?
    
    private let devicesContext: DevicesContext
    
    private var myAudioLevelTimer: SwiftSignalKit.Timer?
    private let typingDisposable = MetaDisposable()


    private let peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager
    
    
    init(
        account: Account,
        peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager,
        sharedContext: SharedAccountContext,
        internalId: CallSessionInternalId,
        initialCall:CachedChannelData.ActiveCall?,
        peerId: PeerId,
        peer: Peer?
    ) {
        self.account = account
        self.sharedContext = sharedContext
        self.internalId = internalId
        self.peerId = peerId
        self.peer = peer
        self.initialCall = initialCall
        self.peerChannelMemberCategoriesContextsManager = peerChannelMemberCategoriesContextsManager
        self.devicesContext = sharedContext.devicesContext

        self.groupCallParticipantUpdatesDisposable = (self.account.stateManager.groupCallParticipantUpdates
        |> deliverOnMainQueue).start(next: { [weak self] updates in
           guard let strongSelf = self else {
               return
           }
           if case let .estabilished(callInfo, _, _, _) = strongSelf.internalState {
               var removedSsrc: [UInt32] = []
                for (callId, update) in updates {
                    if callId == callInfo.id {
                        switch update {
                        case let .state(update):
                            for participantUpdate in update.participantUpdates {
                                if case .left = participantUpdate.participationStatusChange {
                                    removedSsrc.append(participantUpdate.ssrc)
                                    
                                    if participantUpdate.peerId == strongSelf.account.peerId {
                                        if case let .estabilished(_, _, ssrc, _) = strongSelf.internalState, ssrc == participantUpdate.ssrc {
                                            strongSelf._canBeRemoved.set(.single(true))
                                        }
                                    }
                                } else if participantUpdate.peerId == strongSelf.account.peerId {
                                    if case let .estabilished(_, _, ssrc, _) = strongSelf.internalState, ssrc != participantUpdate.ssrc {
                                        strongSelf._canBeRemoved.set(.single(true))
                                    }
                                } else if case .joined = participantUpdate.participationStatusChange {
                                }
                            }
                        case let .call(isTerminated, _):
                            if isTerminated {
                                strongSelf._canBeRemoved.set(.single(true))
                            }
                        }
                    }
                }
               if !removedSsrc.isEmpty {
                   strongSelf.callContext?.removeSsrcs(ssrcs: removedSsrc)
               }
           }
       })

        devicesDisposable.set(devicesContext.updater().start(next: { [weak self] values in
            guard let `self` = self else {
                return
            }
            if let id = values.input {
                self.callContext?.switchAudioInput(id)
            }
            if let id = values.output {
                self.callContext?.switchAudioOutput(id)
            }
        }))
        
        self.summaryStatePromise.set(combineLatest(queue: .mainQueue(),
            self.summaryInfoState.get(),
            self.summaryParticipantsState.get(),
            self.statePromise.get()
        )
        |> map { infoState, participantsState, callState -> PresentationGroupCallSummaryState? in
            guard let infoState = infoState else {
                return nil
            }
            guard let participantsState = participantsState else {
                return nil
            }
            return PresentationGroupCallSummaryState(
                info: infoState.info,
                participantCount: participantsState.participantCount,
                callState: callState,
                topParticipants: participantsState.topParticipants,
                activeSpeakers: participantsState.activeSpeakers
            )
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
        self.summaryStateDisposable?.dispose()
        self.myAudioLevelTimer?.invalidate()
        self.typingDisposable.dispose()
        self.devicesDisposable.dispose()
        self.muteStateDisposable.dispose()
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
                let callContext = OngoingGroupCallContext(inputDeviceId: devicesContext.currentMicroId ?? "", outputDeviceId: devicesContext.currentOutputId ?? "")
                self.callContext = callContext
                self.requestDisposable.set((callContext.joinPayload
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] joinPayload, ssrc in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.requestDisposable.set((joinGroupCall(
                        account: strongSelf.account,
                        peerId: strongSelf.peerId,
                        callId: callInfo.id,
                        accessHash: callInfo.accessHash,
                        preferMuted: true,
                        joinPayload: joinPayload
                    )
                    |> deliverOnMainQueue).start(next: { joinCallResult in
                        guard let strongSelf = self else {
                            return
                        }
                        if let clientParams = joinCallResult.callInfo.clientParams {
                            strongSelf.updateSessionState(internalState: .estabilished(info: joinCallResult.callInfo, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state))
                        }
                    }, error: { [weak self] error in
                        guard let strongSelf = self else {
                            return
                        }
                        guard let window = strongSelf.sharedContext.bindings.mainController().window else {
                            return
                        }
                        if case .anonymousNotAllowed = error {
                            alert(for: window, info: L10n.voiceChatAnonymousDisabledAlertText)
                        } else if case .tooManyParticipants = error {
                            alert(for: window, info: L10n.voiceChatJoinErrorTooMany)
                        }
                        strongSelf._canBeRemoved.set(.single(true))
                    }))
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
                    var result: [(PeerId, Float, Bool)] = []
                    var myLevel: Float = 0.0
                    var myLevelHasVoice: Bool = false
                    for (ssrcKey, level, hasVoice) in levels {
                           var peerId: PeerId?
                           switch ssrcKey {
                           case .local:
                               peerId = strongSelf.account.peerId
                           case let .source(ssrc):
                               peerId = strongSelf.ssrcMapping[ssrc]
                           }
                           if let peerId = peerId {
                               if case .local = ssrcKey {
                                   if !strongSelf.isMutedValue.isEffectivelyMuted {
                                       myLevel = level
                                       myLevelHasVoice = hasVoice
                                   }
                               }
                               result.append((peerId, level, hasVoice))
                           }
                       }


                    let mappedLevel = Float(truncate(double: Double((myLevel * 1.5)), places: 2))

                    result.removeAll(where: { $0.0 == strongSelf.account.peerId})
                    result.append((strongSelf.account.peerId, mappedLevel, myLevelHasVoice))

                    strongSelf.speakingParticipantsContext.update(levels: result)

                    strongSelf.myAudioLevelPipe.putNext(mappedLevel)
                    strongSelf.processMyAudioLevel(level: mappedLevel, hasVoice: myLevelHasVoice)
                }))
            }
        }
        
        switch previousInternalState {
        case .estabilished:
            break
        default:
            if case let .estabilished(callInfo, clientParams, _, initialState) = internalState {
                self.summaryInfoState.set(.single(SummaryInfoState(info: callInfo)))
                
                self.stateValue.canManageCall = initialState.isCreator || initialState.adminIds.contains(self.account.peerId)
                if self.stateValue.canManageCall && initialState.defaultParticipantsAreMuted.canChange {
                    self.stateValue.defaultParticipantMuteState = initialState.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                }

                
                self.ssrcMapping.removeAll()
                var ssrcs: [UInt32] = []
                for participant in initialState.participants {
                    self.ssrcMapping[participant.ssrc] = participant.peer.id
                    ssrcs.append(participant.ssrc)
                }
                self.callContext?.setJoinResponse(payload: clientParams, ssrcs: ssrcs)

                let peerChannelMemberCategoriesContextsManager = self.peerChannelMemberCategoriesContextsManager
                let peerId = self.peerId
                let account = self.account

                let rawAdminIds = Signal<Set<PeerId>, NoError> { subscriber in
                    let (disposable, _) = peerChannelMemberCategoriesContextsManager.admins(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, updated: { list in
                        subscriber.putNext(Set(list.list.map { $0.peer.id }))
                    })
                    return disposable
                }
                |> runOn(.mainQueue())

                let adminIds = combineLatest(queue: .mainQueue(),
                    rawAdminIds,
                    account.postbox.combinedView(keys: [.basicPeer(peerId)])
                )
                |> map { rawAdminIds, view -> Set<PeerId> in
                    var rawAdminIds = rawAdminIds
                    if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer as? TelegramChannel {
                        if peer.hasPermission(.manageCalls) {
                            rawAdminIds.insert(account.peerId)
                        } else {
                            rawAdminIds.remove(account.peerId)
                        }
                    }
                    return rawAdminIds
                }
                |> distinctUntilChanged



                let participantsContext = GroupCallParticipantsContext(
                    account: self.account,
                    peerId: peerId,
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    state: initialState
                )
                self.participantsContext = participantsContext
                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                   participantsContext.state,
                   participantsContext.activeSpeakers,
                   self.speakingParticipantsContext.get(),
                   adminIds
               ).start(next: { [weak self] state, activeSpeakers, speakingParticipants, adminIds in
                   guard let strongSelf = self else {
                       return
                   }
                   //id    Postbox.PeerId.Id    557531797
                   var topParticipants: [GroupCallParticipantsContext.Participant] = []

                    var reportSpeakingParticipants: [PeerId] = []
                    let timestamp = CACurrentMediaTime()
                    for peerId in speakingParticipants {
                        let shouldReport: Bool
                        if let previousTimestamp = strongSelf.speakingParticipantsReportTimestamp[peerId] {
                            shouldReport = previousTimestamp + 1.0 < timestamp
                        } else {
                            shouldReport = true
                        }
                        if shouldReport {
                            strongSelf.speakingParticipantsReportTimestamp[peerId] = timestamp
                            reportSpeakingParticipants.append(peerId)
                        }
                    }

                    if !reportSpeakingParticipants.isEmpty {
                        Queue.mainQueue().justDispatch {
                            self?.participantsContext?.reportSpeakingParticipants(ids: reportSpeakingParticipants)
                        }
                    }



                   var members = PresentationGroupCallMembers(
                       participants: [],
                       speakingParticipants: speakingParticipants,
                       totalCount: 0,
                       loadMoreToken: nil
                   )
                   for participant in state.participants {
                       members.participants.append(participant)
                       
                       
                       if topParticipants.count < 3 {
                           topParticipants.append(participant)
                       }
                       
                       strongSelf.ssrcMapping[participant.ssrc] = participant.peer.id
                   }
                   
                   members.totalCount = state.totalCount
                   members.loadMoreToken = state.nextParticipantsFetchOffset
                   
                   strongSelf.membersValue = members
                   
                   strongSelf.stateValue.adminIds = adminIds
                   strongSelf.stateValue.canManageCall = initialState.isCreator || adminIds.contains(strongSelf.account.peerId)
                   if (state.isCreator || adminIds.contains(strongSelf.account.peerId)) && state.defaultParticipantsAreMuted.canChange {
                       strongSelf.stateValue.defaultParticipantMuteState = state.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                   }

                   strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
                       participantCount: state.totalCount,
                       topParticipants: topParticipants,
                       activeSpeakers: activeSpeakers
                   )))
               }))


                self.muteStateDisposable.set((participantsContext.state |> deliverOnMainQueue).start(next: { [weak self] state in
                   guard let strongSelf = self else {
                       return
                   }
                   for participant in state.participants {
                       if participant.peer.id == strongSelf.account.peerId {
                        if let muteState = participant.muteState {
                            if muteState.canUnmute {
                                switch strongSelf.isMutedValue {
                                case let .muted(isPushToTalkActive):
                                    if !isPushToTalkActive {
                                        strongSelf.callContext?.setIsMuted(true)
                                    }
                                case .unmuted:
                                    strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                    strongSelf.isMutedPromise.set(strongSelf.isMutedValue)
                                    strongSelf.callContext?.setIsMuted(true)
                                }
                            } else {
                                strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                strongSelf.isMutedPromise.set(strongSelf.isMutedValue)
                                strongSelf.callContext?.setIsMuted(true)
                            }
                            strongSelf.stateValue.muteState = muteState
                        } else if let currentMuteState = strongSelf.stateValue.muteState, !currentMuteState.canUnmute {
                            strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                            strongSelf.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true)
                            strongSelf.isMutedPromise.set(strongSelf.isMutedValue)
                            strongSelf.callContext?.setIsMuted(true)
                        }

                       }
                   }
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
        
    func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError> {
        if case let .estabilished(callInfo, _, localSsrc, _) = self.internalState {
            if terminateIfPossible {
                self.leaveDisposable.set((stopGroupCall(account: self.account, peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    self?._canBeRemoved.set(.single(true))
                }))
            } else {
                self.leaveDisposable.set((leaveGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, source: localSsrc)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    self?._canBeRemoved.set(.single(true))
                }))
            }
        } else {
            self.requestDisposable.set(nil)
            self._canBeRemoved.set(.single(true))
        }
        return self._canBeRemoved.get()
    }
    
    func toggleIsMuted() {
        switch self.isMutedValue {
        case .muted:
            self.setIsMuted(action: .unmuted)
        case .unmuted:
            self.setIsMuted(action: .muted(isPushToTalkActive: false))
        }
    }
    
    
    func setIsMuted(action: PresentationGroupCallMuteAction) {
        self.permissions(action, { [weak self] permission in
            guard let `self` = self else {
                return
            }
            if !permission {
                return
            }
            if self.isMutedValue == action {
                return
            }
            if let muteState = self.stateValue.muteState, !muteState.canUnmute {
                return
            }
            self.isMutedValue = action
            self.isMutedPromise.set(self.isMutedValue)
            let isEffectivelyMuted: Bool
            switch self.isMutedValue {
            case let .muted(isPushToTalkActive):
                isEffectivelyMuted = !isPushToTalkActive
                self.updateMuteState(peerId: self.account.peerId, isMuted: true)
            case .unmuted:
                isEffectivelyMuted = false
                self.updateMuteState(peerId: self.account.peerId, isMuted: false)
            }
            self.callContext?.setIsMuted(isEffectivelyMuted)

            if isEffectivelyMuted {
                self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true)
            } else {
                self.stateValue.muteState = nil
            }

        })
    }
    
    
    func updateMuteState(peerId: PeerId, isMuted: Bool) {
        let canThenUnmute: Bool
        if isMuted {
            if peerId == self.account.peerId {
                canThenUnmute = true
            } else if self.stateValue.canManageCall {
                if self.stateValue.adminIds.contains(peerId) {
                    canThenUnmute = true
                } else {
                    canThenUnmute = false
                }
            } else if self.stateValue.adminIds.contains(self.account.peerId) {
                canThenUnmute = true
            } else {
                canThenUnmute = true
            }
            self.participantsContext?.updateMuteState(peerId: peerId, muteState: isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: canThenUnmute) : nil)
        } else {
            if peerId == self.account.peerId {
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil)
            } else {
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true))
            }
        }
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
        
        let currentCall: Signal<GroupCallInfo?, CallError>
        if let initialCall = self.initialCall {
            currentCall = getCurrentGroupCall(account: account, callId: initialCall.id, accessHash: initialCall.accessHash)
            |> mapError { _ -> CallError in
                return .generic
            }
            |> map { summary -> GroupCallInfo? in
                return summary?.info
            }
        } else {
            currentCall = .single(nil)
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
    
    func invitePeer(_ peerId: PeerId) {
        guard case let .estabilished(callInfo, _, _, _) = self.internalState, !self.invitedPeersValue.contains(peerId) else {
            return
        }

        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.insert(peerId)
        self.invitedPeersValue = updatedInvitedPeers
        
        let _ = inviteToGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, peerId: peerId).start()
    }
    
    private var currentMyAudioLevel: Float = 0.0
      private var currentMyAudioLevelTimestamp: Double = 0.0
      private var isSendingTyping: Bool = false
      
      private func restartMyAudioLevelTimer() {
          self.myAudioLevelTimer?.invalidate()
          let myAudioLevelTimer = SwiftSignalKit.Timer(timeout: 0.1, repeat: false, completion: { [weak self] in
              guard let strongSelf = self else {
                  return
              }
              strongSelf.myAudioLevelTimer = nil
              
              let timestamp = CACurrentMediaTime()
              
              var shouldBeSendingTyping = false
              if strongSelf.currentMyAudioLevel > 0.01 && timestamp < strongSelf.currentMyAudioLevelTimestamp + 1.0 {
                  strongSelf.restartMyAudioLevelTimer()
                  shouldBeSendingTyping = true
              } else {
                  if timestamp < strongSelf.currentMyAudioLevelTimestamp + 1.0 {
                      strongSelf.restartMyAudioLevelTimer()
                      shouldBeSendingTyping = true
                  }
              }
              if shouldBeSendingTyping != strongSelf.isSendingTyping {
                  strongSelf.isSendingTyping = shouldBeSendingTyping
                  if shouldBeSendingTyping {
                    strongSelf.typingDisposable.set(strongSelf.account.acquireLocalInputActivity(peerId: PeerActivitySpace(peerId: strongSelf.peerId, category: .voiceChat), activity: .speakingInGroupCall(timestamp: 0)))
                    strongSelf.restartMyAudioLevelTimer()
                  } else {
                      strongSelf.typingDisposable.set(nil)
                  }
              }
          }, queue: .mainQueue())
          self.myAudioLevelTimer = myAudioLevelTimer
          myAudioLevelTimer.start()
      }
      
    private func processMyAudioLevel(level: Float, hasVoice: Bool) {
        self.currentMyAudioLevel = level

        if level > 0.01 && hasVoice {
            self.currentMyAudioLevelTimestamp = CACurrentMediaTime()

            if self.myAudioLevelTimer == nil {
                self.restartMyAudioLevelTimer()
            }
        }
    }

    func updateDefaultParticipantsAreMuted(isMuted: Bool) {
        self.participantsContext?.updateDefaultParticipantsAreMuted(isMuted: isMuted)
        self.stateValue.defaultParticipantMuteState = isMuted ? .muted : .unmuted
    }

}

func requestOrJoinGroupCall(context: AccountContext, peerId: PeerId, initialCall: CachedChannelData.ActiveCall?) -> Signal<RequestOrJoinGroupCallResult, NoError> {
    let sharedContext = context.sharedContext
    let accounts = context.sharedContext.activeAccounts |> take(1)
    let account = context.account
    return combineLatest(queue: .mainQueue(), accounts, account.postbox.loadedPeerWithId(peerId)) |> mapToSignal { accounts, peer in
        if let context = sharedContext.bindings.groupCall(), context.call.peerId == peerId, context.call.account.id == account.id {
            return .single(.samePeer(context))
        } else {
            return makeNewCallConfirmation(account: account, sharedContext: sharedContext, newPeerId: peerId, newCallType: .voiceChat)
            |> mapToSignal { _ in
                return sharedContext.endCurrentCall()
            } |> map { _ in
                return .success(startGroupCall(context: context, peerId: peerId, initialCall: initialCall, peer: peer))
            }
        }
    }
    
}


private func startGroupCall(context: AccountContext, peerId: PeerId, initialCall: CachedChannelData.ActiveCall?, internalId: CallSessionInternalId = CallSessionInternalId(), peer: Peer? = nil) -> GroupCallContext {
    return GroupCallContext(call: PresentationGroupCallImpl(
        account: context.account,
        peerChannelMemberCategoriesContextsManager: context.peerChannelMemberCategoriesContextsManager,
        sharedContext: context.sharedContext,
        internalId: internalId, initialCall: initialCall,
        peerId: peerId,
        peer: peer
    ), peerMemberContextsManager: context.peerChannelMemberCategoriesContextsManager)
}

func createVoiceChat(context: AccountContext, peerId: PeerId) {
    let confirmation = makeNewCallConfirmation(account: context.account, sharedContext: context.sharedContext, newPeerId: peerId, newCallType: .voiceChat) |> mapToSignalPromotingError { _ in
        return createGroupCall(account: context.account, peerId: peerId)
    }

    let requestCall = confirmation |> mapToSignal { call in
        return requestOrJoinGroupCall(context: context, peerId: peerId, initialCall: CachedChannelData.ActiveCall(id: call.id, accessHash: call.accessHash)) |> mapError { _ in .generic }
    }
    
    _ = showModalProgress(signal: requestCall, for: context.window).start(next: { result in
        switch result {
        case let .success(callContext), let .samePeer(callContext):
            applyGroupCallResult(context.sharedContext, callContext)
        default:
            alert(for: context.window, info: L10n.errorAnError)
        }
    }, error: { error in
        if case .anonymousNotAllowed = error {
            alert(for: context.window, info: L10n.voiceChatAnonymousDisabledAlertText)
        } else {
            alert(for: context.window, info: L10n.errorAnError)
        }
    })
}
