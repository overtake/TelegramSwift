import Cocoa
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AVFoundation
import TelegramVoip
import TGUIKit

func getGroupCallPanelData(context: AccountContext, peerId: PeerId) -> Signal<GroupCallPanelData?, NoError> {
    let account = context.account
    let availableGroupCall: Signal<GroupCallPanelData?, NoError>
    if peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
        availableGroupCall = context.account.viewTracker.peerView(peerId)
                        |> map { peerView -> CachedChannelData.ActiveCall? in
                            if let cachedData = peerView.cachedData as? CachedChannelData {
                                return cachedData.activeCall
                            }
                            if let cachedData = peerView.cachedData as? CachedGroupData {
                                return cachedData.activeCall
                            }
                            return nil
                        }
                        |> distinctUntilChanged
                           |> mapToSignal { activeCall -> Signal<GroupCallPanelData?, NoError> in
                               guard let activeCall = activeCall else {
                                   return .single(nil)
                               }
                                return context.sharedContext.groupCallContext |> mapToSignal { groupCall in
                                    if let context = groupCall, context.call.peerId == peerId && context.call.account.id == account.id {
                                        return context.call.summaryState
                                            |> map { summary -> GroupCallPanelData in
                                                if let summary = summary {
                                                    return GroupCallPanelData(
                                                        peerId: peerId,
                                                        info: summary.info,
                                                        topParticipants: summary.topParticipants,
                                                        participantCount: summary.participantCount,
                                                        activeSpeakers: summary.activeSpeakers,
                                                        groupCall: context
                                                    )
                                                } else {
                                                    return GroupCallPanelData(peerId: peerId, info: nil, topParticipants: [], participantCount: 0, activeSpeakers: [], groupCall: context)
                                                }
                                            }
                                    } else {
                                        return Signal { subscriber in
                                            let disposable = MetaDisposable()
                                            let callContext = context.cachedGroupCallContexts
                                            callContext.impl.syncWith { impl in
                                                let callContext = impl.get(account: context.account, peerId: peerId, myPeerId: context.peerId, call: activeCall)
                                                disposable.set((callContext.context.panelData
                                                |> deliverOnMainQueue).start(next: { panelData in
                                                    callContext.keep()
                                                    subscriber.putNext(panelData)
                                                }))
                                            }
                                            return disposable
                                        }
                                    }
                                }
                           }

    } else {
        availableGroupCall = .single(nil)
    }
    return availableGroupCall
}


private extension GroupCallParticipantsContext.Participant {
    var allSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let ssrc = self.ssrc {
            participantSsrcs.insert(ssrc)
        }
        if let jsonParams = self.jsonParams, let jsonData = jsonParams.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            if let groups = json["ssrc-groups"] as? [Any] {
                for group in groups {
                    if let group = group as? [String: Any] {
                        if let groupSources = group["sources"] as? [UInt32] {
                            for source in groupSources {
                                participantSsrcs.insert(source)
                            }
                        }
                    }
                }
            }
        }
        return participantSsrcs
    }
}

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
    
    init(account: Account, peerId: PeerId, myPeerId: PeerId, call: CachedChannelData.ActiveCall) {
        self.panelDataPromise.set(.single(GroupCallPanelData(
            peerId: peerId,
            info: GroupCallInfo(
                id: call.id,
                accessHash: call.accessHash,
                participantCount: 0,
                clientParams: nil,
                streamDcId: nil,
                title: nil,
                recordingStartTimestamp: nil
            ),
            topParticipants: [],
            participantCount: 0,
            activeSpeakers: Set(),
            groupCall: nil
        )))
        
        self.disposable = (getGroupCallParticipants(account: account, callId: call.id, accessHash: call.accessHash, offset: "", ssrcs: [], limit: 100)
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
                peerId: peerId, myPeerId: myPeerId,
                id: call.id,
                accessHash: call.accessHash,
                state: state,
                previousServiceState: nil
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
                    info: GroupCallInfo(id: call.id, accessHash: call.accessHash, participantCount: state.totalCount, clientParams: nil, streamDcId: nil, title: state.title, recordingStartTimestamp: state.recordingStartTimestamp),
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
        
        func get(account: Account, peerId: PeerId, myPeerId: PeerId, call: CachedChannelData.ActiveCall) -> AccountGroupCallContextImpl.Proxy {
            let result: Record
            if let current = self.contexts[call.id] {
                result = current
            } else {
                let context = AccountGroupCallContextImpl(account: account, peerId: peerId, myPeerId: myPeerId, call: call)
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
    static func initialValue(_ myPeerId: PeerId) -> PresentationGroupCallState {
        return PresentationGroupCallState(
            myPeerId: myPeerId,
            networkState: .connecting,
            canManageCall: false,
            adminIds: Set(),
            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
            defaultParticipantMuteState: nil,
            title: nil,
            recordingStartTimestamp: nil,
            isRaisedHand: false
        )
    }
}

final class PresentationGroupCallImpl: PresentationGroupCall {
    private enum InternalState {
        case requesting
        case active(GroupCallInfo)
        case established(info: GroupCallInfo, connectionMode: JoinGroupCallResult.ConnectionMode, clientParams: String, localSsrc: UInt32, initialState: GroupCallParticipantsContext.State)
        
        var callInfo: GroupCallInfo? {
            switch self {
            case .requesting:
                return nil
            case let .active(info):
                return info
            case let .established(info, _, _, _, _):
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
            let ssrc: UInt32
            let timestamp: Int32
            let level: Float
        }

        private var participants: [PeerId: Participant] = [:]
        private let speakingParticipantsPromise = ValuePromise<[PeerId: UInt32]>()
        private var speakingParticipants = [PeerId: UInt32]() {
            didSet {
                self.speakingParticipantsPromise.set(self.speakingParticipants)
            }
        }

        private let audioLevelsPromise = Promise<[(PeerId, Float, Bool)]>()


        init() {
        }
       
        func update(levels: [(PeerId, UInt32, Float, Bool)]) {
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            let currentParticipants: [PeerId: Participant] = self.participants

            var validSpeakers: [PeerId: Participant] = [:]
            var silentParticipants = Set<PeerId>()
            var speakingParticipants = [PeerId: UInt32]()
            for (peerId, ssrc, level, hasVoice) in levels {
                if level > speakingLevelThreshold && hasVoice {
                    validSpeakers[peerId] = Participant(ssrc: ssrc, timestamp: timestamp, level: level)
                    speakingParticipants[peerId] = ssrc
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
                            speakingParticipants[peerId] = participant.ssrc
                        }
                    } else if delta < cutoffTimeout {
                        validSpeakers[peerId] = participant
                        speakingParticipants[peerId] = participant.ssrc
                    }
                }
            }

            var audioLevels: [(PeerId, Float, Bool)] = []
            for (peerId, _, level, hasVoice) in levels {
                if level > 0.001 {
                    audioLevels.append((peerId, level, hasVoice))
                }
            }

            self.participants = validSpeakers
            self.speakingParticipants = speakingParticipants
            self.audioLevelsPromise.set(.single(audioLevels))
        }
       
        func get() -> Signal<[PeerId: UInt32], NoError> {
            return self.speakingParticipantsPromise.get()
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
    
    private var joinAsPeerIdValue:ValuePromise<PeerId> = ValuePromise(ignoreRepeated: true)
    private(set) var joinAsPeerId: PeerId {
        didSet {
            joinAsPeerIdValue.set(joinAsPeerId)
        }
    }
    var joinAsPeer:Signal<(Peer, String?), NoError> {
        let account = self.account
        return joinAsPeerIdValue.get() |> mapToSignal {
            return account.postbox.peerView(id: $0) |> map { view in
                if let cachedData = view.cachedData as? CachedChannelData {
                    return (peerViewMainPeer(view)!, cachedData.about)
                } else if let cachedData = view.cachedData as? CachedUserData {
                    return (peerViewMainPeer(view)!, cachedData.about)
                } else {
                    return (peerViewMainPeer(view)!, nil)
                }
            }
        }
    }
    
    private let displayAsPeersValue: Promise<[FoundPeer]?> = Promise(nil)
    var displayAsPeers: Signal<[FoundPeer]?, NoError> {
        return displayAsPeersValue.get()
    }
    private let loadDisplayAsPeerDisposable = MetaDisposable()
    
    
    private(set) var initialCall: CachedChannelData.ActiveCall?
    private var internalState: InternalState = .requesting
    private var ignorePreviousJoinAsPeerId: (PeerId, UInt32)?
    private var currentLocalSsrc: UInt32?
    
    private var callContext: OngoingGroupCallContext?
    private var currentConnectionMode: OngoingGroupCallContext.ConnectionMode = .none
    private var ssrcMapping: [UInt32: PeerId] = [:]
    
    private var summaryInfoState = Promise<SummaryInfoState?>(nil)
    private var summaryParticipantsState = Promise<SummaryParticipantsState?>(nil)
   
    private let summaryStatePromise = Promise<PresentationGroupCallSummaryState?>(nil)
    var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> {
        return self.summaryStatePromise.get()
    }
    private var summaryStateDisposable: Disposable?

    var activeCall: CachedChannelData.ActiveCall? {
        return self.initialCall
    }
    
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


    private let updateTitleDisposable = MetaDisposable()

    
   private var audioLevelsDisposable = MetaDisposable()

   private var participantsContextStateDisposable = MetaDisposable()
   private var temporaryParticipantsContext: GroupCallParticipantsContext?

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
    
    private var stateValue:PresentationGroupCallState {
       didSet {
           if self.stateValue != oldValue {
               self.statePromise.set(self.stateValue)
           }
       }
   }
   private let statePromise = ValuePromise<PresentationGroupCallState>()
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
    
    
    private var isReconnectingAsSpeaker = false {
        didSet {
            if self.isReconnectingAsSpeaker != oldValue {
                self.isReconnectingAsSpeakerPromise.set(self.isReconnectingAsSpeaker)
            }
        }
    }
    private let isReconnectingAsSpeakerPromise = ValuePromise<Bool>(false)


    private let groupCallInviteLinksPromise = Promise<GroupCallInviteLinks?>(nil)
    var groupCallInviteLinks:Signal<GroupCallInviteLinks?, NoError> {
        return groupCallInviteLinksPromise.get() |> deliverOnMainQueue
    }
    
    private let devicesContext: DevicesContext
    
    private var myAudioLevelTimer: SwiftSignalKit.Timer?
    private let typingDisposable = MetaDisposable()


    private let peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager
    
    private var videoCapturer: OngoingCallVideoCapturer? {
        didSet {
            outgoingStreamExists.set(videoCapturer != nil)
        }
    }
    private let incomingVideoSourcePromise = Promise<[PeerId: UInt32]>([:])
    public var incomingVideoSources: Signal<[PeerId: UInt32], NoError> {
        return self.incomingVideoSourcePromise.get()
    }
    
    private let outgoingStreamExists:ValuePromise<Bool> = ValuePromise(false)
    
    private var missingSsrcs = Set<UInt32>()
    private var processedMissingSsrcs = Set<UInt32>()
    private let missingSsrcsDisposable = MetaDisposable()
    private var isRequestingMissingSsrcs: Bool = false


    private var joinHash: String?
    
    private var temporaryJoinTimestamp: Int32
    private var temporaryActivityTimestamp: Double?
    private var temporaryActivityRank: Int?
    private var temporaryRaiseHandRating: Int64?
    private var temporaryHasRaiseHand: Bool = false
    private var temporaryMuteState: GroupCallParticipantsContext.Participant.MuteState?

    
    
    init(
        account: Account,
        peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager,
        sharedContext: SharedAccountContext,
        internalId: CallSessionInternalId,
        initialCall:CachedChannelData.ActiveCall?,
        initialInfo: GroupCallInfo?,
        joinAs: PeerId,
        joinHash: String?,
        peerId: PeerId,
        peer: Peer?
    ) {
        self.account = account
        self.sharedContext = sharedContext
        self.internalId = internalId
        self.peerId = peerId
        self.peer = peer
        self.joinAsPeerId = joinAs
        self.joinHash = joinHash
        self.joinAsPeerIdValue.set(joinAs)
        self.initialCall = initialCall
        
        self.stateValue = PresentationGroupCallState.initialValue(joinAs)
        self.statePromise.set(self.stateValue)
        
        self.temporaryJoinTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)

        
        if let initialInfo = initialInfo {
            self.summaryInfoState.set(.single(SummaryInfoState(info: initialInfo)))
        }
        
        self.peerChannelMemberCategoriesContextsManager = peerChannelMemberCategoriesContextsManager
        self.devicesContext = sharedContext.devicesContext
        
        
       // self.videoCapturer = OngoingCallVideoCapturer()

        self.groupCallParticipantUpdatesDisposable = (self.account.stateManager.groupCallParticipantUpdates
        |> deliverOnMainQueue).start(next: { [weak self] updates in
           guard let strongSelf = self else {
               return
           }
           if case let .established(callInfo, _, _, _, _) = strongSelf.internalState {
                var addedParticipants: [(UInt32, String?)] = []
                var removedSsrc: [UInt32] = []
                for (callId, update) in updates {
                    if callId == callInfo.id {
                        switch update {
                        case let .state(update):
                            for participantUpdate in update.participantUpdates {
                                if case .left = participantUpdate.participationStatusChange {
                                    if let ssrc = participantUpdate.ssrc {
                                        removedSsrc.append(ssrc)
                                    }
                                    
                                    if participantUpdate.peerId == strongSelf.joinAsPeerId {
                                        if case let .established(_, _, _, ssrc, _) = strongSelf.internalState, ssrc == participantUpdate.ssrc {
                                            strongSelf.markAsCanBeRemoved()
                                        }
                                    }
                                } else if participantUpdate.peerId == strongSelf.joinAsPeerId {
                                    if case let .established(_, connectionMode, _, ssrc, _) = strongSelf.internalState {
                                        if ssrc != participantUpdate.ssrc {
                                            strongSelf.markAsCanBeRemoved()
                                        } else if case .broadcast = connectionMode {
                                            let canUnmute: Bool
                                            if let muteState = participantUpdate.muteState {
                                                canUnmute = muteState.canUnmute
                                            } else {
                                                canUnmute = true
                                            }
                                            
                                            if canUnmute {
                                                strongSelf.requestCall(movingFromBroadcastToRtc: true)
                                            }
                                        }
                                    }
                                } else if case .joined = participantUpdate.participationStatusChange {
                                    if let ssrc = participantUpdate.ssrc {
                                        addedParticipants.append((ssrc, participantUpdate.jsonParams))
                                    }
                                } else if let ssrc = participantUpdate.ssrc, strongSelf.ssrcMapping[ssrc] == nil {
                                    addedParticipants.append((ssrc, participantUpdate.jsonParams))
                                }
                            }
                        case let .call(isTerminated, _, _, _):
                            if isTerminated {
                                strongSelf.markAsCanBeRemoved()
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
        
        self.displayAsPeersValue.set(cachedGroupCallDisplayAsAvailablePeers(account: account, peerId: peerId) |> map(Optional.init))
        
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
        
        
        self.requestCall(movingFromBroadcastToRtc: false)

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
        self.missingSsrcsDisposable.dispose()
        self.updateTitleDisposable.dispose()
        self.loadDisplayAsPeerDisposable.dispose()
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
                let callContext:OngoingGroupCallContext
                if let current = self.callContext {
                    callContext = current
                } else {
                    callContext = OngoingGroupCallContext(inputDeviceId: devicesContext.currentMicroId ?? "", outputDeviceId: devicesContext.currentOutputId ?? "", video: videoCapturer, participantDescriptionsRequired: { [weak self] ssrcs in
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.maybeRequestParticipants(ssrcs: ssrcs)
                        }
                    }, audioStreamData: OngoingGroupCallContext.AudioStreamData(account: account, callId: callInfo.id, accessHash: callInfo.accessHash), rejoinNeeded: { [weak self] in
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            if case .established = strongSelf.internalState {
                                strongSelf.requestCall(movingFromBroadcastToRtc: false)
                            }
                        }
                    })
                }
                self.incomingVideoSourcePromise.set(combineLatest(outgoingStreamExists.get(), callContext.videoSources)
                |> deliverOnMainQueue
                |> map { [weak self] hasOutgoing, sources -> [PeerId: UInt32] in
                    guard let strongSelf = self else {
                        return [:]
                    }
                    var result: [PeerId: UInt32] = [:]
                    for source in sources {
                        if let peerId = strongSelf.ssrcMapping[source] {
                            result[peerId] = source
                        }
                    }
                    if hasOutgoing {
                        result[strongSelf.joinAsPeerId] = 0
                    }
                    return result
                })

                self.callContext = callContext
                self.requestDisposable.set((callContext.joinPayload
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] joinPayload, ssrc in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let peerAdminIds: Signal<[PeerId], NoError>
                    let peerId = strongSelf.peerId
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudChannel {
                        peerAdminIds = .single([])
                    } else {
                        peerAdminIds = strongSelf.account.postbox.transaction { transaction -> [PeerId] in
                            var result: [PeerId] = []
                            if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedGroupData {
                                if let participants = cachedData.participants {
                                    for participant in participants.participants {
                                        if case .creator = participant {
                                            result.append(participant.peerId)
                                        } else if case .admin = participant {
                                            result.append(participant.peerId)
                                        }
                                    }
                                }
                            }
                            return result
                        }
                    }

                    strongSelf.currentLocalSsrc = ssrc
                    strongSelf.requestDisposable.set((joinGroupCall(
                        account: strongSelf.account,
                        peerId: strongSelf.peerId,
                        joinAs: strongSelf.joinAsPeerId,
                        callId: callInfo.id,
                        accessHash: callInfo.accessHash,
                        preferMuted: true,
                        joinPayload: joinPayload,
                        peerAdminIds: peerAdminIds,
                        inviteHash: strongSelf.joinHash
                    )
                    |> deliverOnMainQueue).start(next: { joinCallResult in
                        guard let strongSelf = self else {
                            return
                        }
                        if let clientParams = joinCallResult.callInfo.clientParams {
                            strongSelf.ssrcMapping.removeAll()
                            var addedParticipants: [(UInt32, String?)] = []
                            for participant in joinCallResult.state.participants {
                                if let ssrc = participant.ssrc {
                                    strongSelf.ssrcMapping[ssrc] = participant.peer.id
                                }
                            }
                            switch joinCallResult.connectionMode {
                            case .rtc:
                                strongSelf.currentConnectionMode = .rtc
                                strongSelf.callContext?.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false)
                                strongSelf.callContext?.setJoinResponse(payload: clientParams, participants: addedParticipants)
                            case .broadcast:
                                strongSelf.currentConnectionMode = .broadcast
                                strongSelf.callContext?.setConnectionMode(.broadcast, keepBroadcastConnectedIfWasEnabled: false)
                            }
                            strongSelf.updateSessionState(internalState: .established(info: joinCallResult.callInfo, connectionMode: joinCallResult.connectionMode, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state))
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
                        strongSelf.markAsCanBeRemoved()
                    }))
                }))
                
                self.networkStateDisposable.set((callContext.networkState
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let strongSelf = self else {
                        return
                    }
                    let mappedState: PresentationGroupCallState.NetworkState
                    if state.isConnected {
                        mappedState = .connected
                    } else {
                        mappedState = .connecting
                    }

                    let wasConnecting = strongSelf.stateValue.networkState == .connecting
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

                    strongSelf.isReconnectingAsSpeaker = state.isTransitioningFromBroadcastToRtc
                                        
                }))

                
                self.audioLevelsDisposable.set((callContext.audioLevels
                |> deliverOnMainQueue).start(next: { [weak self] levels in
                    guard let strongSelf = self else {
                        return
                    }
                    var result: [(PeerId, UInt32, Float, Bool)] = []
                    var myLevel: Float = 0.0
                    var myLevelHasVoice: Bool = false
                    var missingSsrcs = Set<UInt32>()
                    for (ssrcKey, level, hasVoice) in levels {
                        var peerId: PeerId?
                        let ssrcValue: UInt32
                        switch ssrcKey {
                        case .local:
                            peerId = strongSelf.joinAsPeerId
                            ssrcValue = 0
                        case let .source(ssrc):
                            peerId = strongSelf.ssrcMapping[ssrc]
                            ssrcValue = ssrc
                        }
                        if let peerId = peerId {
                            if case .local = ssrcKey {
                                if !strongSelf.isMutedValue.isEffectivelyMuted {
                                    myLevel = level
                                    myLevelHasVoice = hasVoice
                                }
                            }
                            result.append((peerId, ssrcValue, level, hasVoice))
                        } else if ssrcValue != 0 {
                            missingSsrcs.insert(ssrcValue)
                        }
                    }


                    let mappedLevel = Float(truncate(double: Double((myLevel * 1.5)), places: 2))

                    result.removeAll(where: { $0.0 == strongSelf.joinAsPeerId})
                    result.append((strongSelf.joinAsPeerId, 0, mappedLevel, myLevelHasVoice))

                    strongSelf.speakingParticipantsContext.update(levels: result)

                    strongSelf.myAudioLevelPipe.putNext(mappedLevel)
                    strongSelf.processMyAudioLevel(level: mappedLevel, hasVoice: myLevelHasVoice)

                    if !missingSsrcs.isEmpty {
                        strongSelf.participantsContext?.ensureHaveParticipants(ssrcs: missingSsrcs)
                    }

                }))
            }
        }
        
        switch previousInternalState {
        case .established:
            break
        default:
            if case let .established(callInfo, _, _, _, initialState) = internalState {
                self.summaryInfoState.set(.single(SummaryInfoState(info: callInfo)))
                
                self.groupCallInviteLinksPromise.set(TelegramCore.groupCallInviteLinks(account: account, callId: callInfo.id, accessHash: callInfo.accessHash))
                
                self.stateValue.canManageCall = initialState.isCreator || initialState.adminIds.contains(self.account.peerId)
                if self.stateValue.canManageCall && initialState.defaultParticipantsAreMuted.canChange {
                    self.stateValue.defaultParticipantMuteState = initialState.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                }

                
                let peerChannelMemberCategoriesContextsManager = self.peerChannelMemberCategoriesContextsManager
                let peerId = self.peerId
                let account = self.account
                let joinAs = self.joinAsPeerId

                let rawAdminIds: Signal<Set<PeerId>, NoError>
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    rawAdminIds = Signal { subscriber in
                        let (disposable, _) = peerChannelMemberCategoriesContextsManager.admins(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, updated: { list in
                            var peerIds = Set<PeerId>()
                            for item in list.list {
                                if let adminInfo = item.participant.adminInfo, adminInfo.rights.rights.contains(.canManageCalls) {
                                    peerIds.insert(item.peer.id)
                                }
                            }
                            subscriber.putNext(peerIds)
                        })
                        return disposable
                    }
                    |> distinctUntilChanged
                    |> runOn(.mainQueue())
                } else {
                    rawAdminIds = account.postbox.combinedView(keys: [.cachedPeerData(peerId: peerId)])
                        |> map { views -> Set<PeerId> in
                            guard let view = views.views[.cachedPeerData(peerId: peerId)] as? CachedPeerDataView else {
                                return Set()
                            }
                            guard let cachedData = view.cachedPeerData as? CachedGroupData, let participants = cachedData.participants else {
                                return Set()
                            }
                            return Set(participants.participants.compactMap { item -> PeerId? in
                                switch item {
                                case .creator, .admin:
                                    return item.peerId
                                default:
                                    return nil
                                }
                            })
                        }
                        |> distinctUntilChanged
                }


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

                let myPeerId = self.joinAsPeerId

                
                var initialState = initialState
                var serviceState: GroupCallParticipantsContext.ServiceState?
                if let participantsContext = self.participantsContext, let immediateState = participantsContext.immediateState {
                    initialState.mergeActivity(from: immediateState, myPeerId: myPeerId, previousMyPeerId: self.ignorePreviousJoinAsPeerId?.0)
                    serviceState = participantsContext.serviceState
                }

                let participantsContext = GroupCallParticipantsContext(
                    account: self.account,
                    peerId: peerId,
                    myPeerId: joinAs,
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    state: initialState,
                    previousServiceState: serviceState
                )
                self.temporaryParticipantsContext = nil
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
                    var topParticipants: [GroupCallParticipantsContext.Participant] = []

                    var reportSpeakingParticipants: [PeerId: UInt32] = [:]
                    let timestamp = CACurrentMediaTime()
                    for (peerId, ssrc) in speakingParticipants {
                        let shouldReport: Bool
                        if let previousTimestamp = strongSelf.speakingParticipantsReportTimestamp[peerId] {
                            shouldReport = previousTimestamp + 1.0 < timestamp
                        } else {
                            shouldReport = true
                        }
                        if shouldReport {
                            strongSelf.speakingParticipantsReportTimestamp[peerId] = timestamp
                            reportSpeakingParticipants[peerId] = ssrc
                        }
                    }

                    if !reportSpeakingParticipants.isEmpty {
                        Queue.mainQueue().justDispatch {
                            self?.participantsContext?.reportSpeakingParticipants(ids: reportSpeakingParticipants)
                        }
                    }



                   var members = PresentationGroupCallMembers(
                       participants: [],
                       speakingParticipants: Set(speakingParticipants.keys),
                       totalCount: 0,
                       loadMoreToken: nil
                   )
                   for participant in state.participants {
                       members.participants.append(participant)
                       
                       
                       if topParticipants.count < 3 {
                           topParticipants.append(participant)
                       }
                       if let ssrc = participant.ssrc {
                           strongSelf.ssrcMapping[ssrc] = participant.peer.id
                       }
                   }
                   
                   members.totalCount = state.totalCount
                   members.loadMoreToken = state.nextParticipantsFetchOffset
                   
                   strongSelf.membersValue = members
                
                    let member = members.participants.first(where: { $0.peer.id == strongSelf.joinAsPeerId })
                
                    strongSelf.stateValue.isRaisedHand = member?.hasRaiseHand == true
                
                    strongSelf.stateValue.title = state.title
                    strongSelf.stateValue.recordingStartTimestamp = state.recordingStartTimestamp
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
                       if participant.peer.id == strongSelf.joinAsPeerId {
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
                            strongSelf.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
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
    
    
    
    private func maybeRequestParticipants(ssrcs: Set<UInt32>) {
        var missingSsrcs = ssrcs
        missingSsrcs.subtract(self.processedMissingSsrcs)
        if missingSsrcs.isEmpty {
            return
        }
        self.processedMissingSsrcs.formUnion(ssrcs)
        
        var addedParticipants: [(UInt32, String?)] = []
        
        if let membersValue = self.membersValue {
            for participant in membersValue.participants {
                let participantSsrcs = participant.allSsrcs
                
                if !missingSsrcs.intersection(participantSsrcs).isEmpty {
                    missingSsrcs.subtract(participantSsrcs)
                    self.processedMissingSsrcs.formUnion(participantSsrcs)
                    
                    if let ssrc = participant.ssrc {
                        addedParticipants.append((ssrc, participant.jsonParams))
                    }
                }
            }
        }
        
        if !addedParticipants.isEmpty {
            self.callContext?.addParticipants(participants: addedParticipants)
        }
        
        if !missingSsrcs.isEmpty {
            self.missingSsrcs.formUnion(missingSsrcs)
            self.maybeRequestMissingSsrcs()
        }
    }
    
    private func maybeRequestMissingSsrcs() {
        if self.isRequestingMissingSsrcs {
            return
        }
        if self.missingSsrcs.isEmpty {
            return
        }
        if case let .established(callInfo, _, _, _, _) = self.internalState {
            self.isRequestingMissingSsrcs = true
            
            let requestedSsrcs = self.missingSsrcs
            self.missingSsrcsDisposable.set((getGroupCallParticipants(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, offset: "", ssrcs: Array(requestedSsrcs), limit: 100)
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isRequestingMissingSsrcs = false
                strongSelf.missingSsrcs.subtract(requestedSsrcs)
                
                var addedParticipants: [(UInt32, String?)] = []
                
                for participant in state.participants {
                    if let ssrc = participant.ssrc {
                         addedParticipants.append((ssrc, participant.jsonParams))
                    }
                }
                
                if !addedParticipants.isEmpty {
                    strongSelf.callContext?.addParticipants(participants: addedParticipants)
                }
                
                strongSelf.maybeRequestMissingSsrcs()
            }))
        }
    }
    

    
    private func startCheckingCallIfNeeded() {
        if self.checkCallDisposable != nil {
            return
        }
        if case let .established(callInfo, connectionMode, _, ssrc, _) = self.internalState, case .rtc = connectionMode {
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
                strongSelf.requestCall(movingFromBroadcastToRtc: false)
            })
        }
    }
        
    func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError> {
        if case let .established(callInfo, _, _, localSsrc, _) = self.internalState {
            if terminateIfPossible {
                self.leaveDisposable.set((stopGroupCall(account: self.account, peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    self?.markAsCanBeRemoved()
                }))
            } else {
                self.leaveDisposable.set((leaveGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, source: localSsrc)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    self?.markAsCanBeRemoved()
                }))
            }
        } else {
            self.requestDisposable.set(nil)
            self.markAsCanBeRemoved()
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
                self.updateMuteState(peerId: self.joinAsPeerId, isMuted: true)
            case .unmuted:
                isEffectivelyMuted = false
                self.updateMuteState(peerId: self.joinAsPeerId, isMuted: false)
            }
            self.callContext?.setIsMuted(isEffectivelyMuted)

            if isEffectivelyMuted {
                self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
            } else {
                self.stateValue.muteState = nil
            }

        })
    }
    
    private func muteState(peerId: PeerId, isMuted: Bool) -> GroupCallParticipantsContext.Participant.MuteState? {
        let canThenUnmute: Bool
        if isMuted {
            var mutedByYou = false
            if peerId == self.joinAsPeerId {
                canThenUnmute = self.stateValue.muteState?.canUnmute ?? true
            } else if self.stateValue.canManageCall {
                if self.stateValue.adminIds.contains(peerId) {
                    canThenUnmute = true
                } else {
                    canThenUnmute = false
                }
            } else if self.stateValue.adminIds.contains(self.account.peerId) {
                canThenUnmute = true
            } else {
                mutedByYou = true
                canThenUnmute = true
            }
            return isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: canThenUnmute, mutedByYou: mutedByYou) : nil
        } else {
            if peerId == self.joinAsPeerId {
                return nil
            } else if self.stateValue.canManageCall || self.stateValue.adminIds.contains(self.account.peerId) {
                return GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
            } else {
                return nil
            }
          }
    }
    
    
    func updateMuteState(peerId: PeerId, isMuted: Bool, volume: Int32? = nil, raiseHand: Bool? = nil) {
        self.participantsContext?.updateMuteState(peerId: peerId, muteState: muteState(peerId: peerId, isMuted: isMuted), volume: volume, raiseHand: raiseHand)
    }
    
    func joinAsSpeakerIfNeeded(_ joinHash: String) {
        self.joinHash = joinHash
        if let muteState = self.stateValue.muteState, !muteState.canUnmute {
            requestCall(movingFromBroadcastToRtc: false)
        }
    }
    
    public func raiseHand() {
        guard let membersValue = self.membersValue else {
            return
        }
        for participant in membersValue.participants {
            if participant.peer.id == self.joinAsPeerId {
                if participant.hasRaiseHand {
                    return
                }
                break
            }
        }
        
        self.participantsContext?.raiseHand()
    }
        
    public func lowerHand() {
        guard let membersValue = self.membersValue else {
            return
        }
        for participant in membersValue.participants {
            if participant.peer.id == self.joinAsPeerId {
                if !participant.hasRaiseHand {
                    return
                }
                break
            }
        }
        
        self.participantsContext?.lowerHand()
    }
    
    func resetListenerLink() {
        self.participantsContext?.resetInviteLinks()
    }

    
    private func requestCall(movingFromBroadcastToRtc: Bool) {
        self.callContext?.setConnectionMode(.none, keepBroadcastConnectedIfWasEnabled: movingFromBroadcastToRtc)
        
        self.missingSsrcsDisposable.set(nil)
        self.missingSsrcs.removeAll()
        self.processedMissingSsrcs.removeAll()


        
        self.internalState = .requesting
        self.isCurrentlyConnecting = nil
        
        enum CallError {
            case generic
        }
        
        let account = self.account
        let peerId = self.peerId
        let joinAs = self.joinAsPeerId
        
        let updateCachedData = account.postbox.transaction { transaction in
            transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, current in
                if peerId.namespace == Namespaces.Peer.CloudGroup {
                    var current = current as? CachedGroupData ?? CachedGroupData()
                    current = current.withUpdatedCallJoinPeerId(joinAs)
                    return current
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    var current = current as? CachedChannelData ?? CachedChannelData()
                    current = current.withUpdatedCallJoinPeerId(joinAs)
                    return current
                } else {
                    return current
                }
            })
        }
        _ = updateCachedData.start()
        
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
          |> mapToSignal { callInfo -> Signal<GroupCallInfo?, CallError> in
              if let callInfo = callInfo {
                  return .single(callInfo)
              } else {
                  return .single(nil)
              }
          }

        self.networkStateDisposable.set(nil)
        self.requestDisposable.set(nil)
       
        self.checkCallDisposable?.dispose()
        self.checkCallDisposable = nil
       
        if movingFromBroadcastToRtc {
            self.stateValue.networkState = .connected
        } else {
            self.stateValue.networkState = .connecting
        }
       
        self.requestDisposable.set((currentOrRequestedCall
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if let value = value {
                strongSelf.initialCall = CachedChannelData.ActiveCall(id: value.id, accessHash: value.accessHash, title: value.title)
               
                strongSelf.updateSessionState(internalState: .active(value))
            } else {
                strongSelf.markAsCanBeRemoved()
            }
       }))

    }
    
    private func markAsCanBeRemoved() {
        self.callContext?.stop()
        self._canBeRemoved.set(.single(true))
    }

    func loadMore() {
        if let token = self.membersValue?.loadMoreToken {
            self.participantsContext?.loadMore(token: token)
        }
    }
    
    func updateTitle(_ title: String, force: Bool) {
        guard case let .established(callInfo, _, _, _, _) = self.internalState else {
            return
        }
        var signal = editGroupCallTitle(account: account, callId: callInfo.id, accessHash: callInfo.accessHash, title: title)
        if !force {
            signal = signal |> delay(0.2, queue: .mainQueue())
        }
        updateTitleDisposable.set(signal.start())
    }
    
    func invitePeer(_ peerId: PeerId) {
        guard case let .established(callInfo, _, _, _, _) = self.internalState, !self.invitedPeersValue.contains(peerId) else {
            return
        }
        if let channel = self.peer as? TelegramChannel {
            if channel.isChannel {
                return
            }
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
    func setVolume(peerId: PeerId, volume: Int32, sync: Bool) {
        for (ssrc, id) in self.ssrcMapping {
            if id == peerId {
                self.callContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000)
                if sync {
                    self.participantsContext?.updateMuteState(peerId: peerId, muteState: muteState(peerId: peerId, isMuted: volume == 0), volume: volume, raiseHand: nil)
                }
                break
            }
        }
    }


    func updateDefaultParticipantsAreMuted(isMuted: Bool) {
        self.participantsContext?.updateDefaultParticipantsAreMuted(isMuted: isMuted)
        self.stateValue.defaultParticipantMuteState = isMuted ? .muted : .unmuted
    }

    
    func switchVideoInput(_ deviceId: String) {
        videoCapturer?.switchVideoInput(deviceId)
    }
    
    func makeOutgoingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void) {
        videoCapturer?.makeOutgoingVideoView(completion: { view in
            if let view = view {
                let setOnFirstFrameReceived = view.setOnFirstFrameReceived
                let setOnOrientationUpdated = view.setOnOrientationUpdated
                let setOnIsMirroredUpdated = view.setOnIsMirroredUpdated
                completion(PresentationCallVideoView(
                    holder: view,
                    view: view.view,
                    setOnFirstFrameReceived: { f in
                        setOnFirstFrameReceived(f)
                    },
                    getOrientation: { [weak view] in
                        if let view = view {
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch view.getOrientation() {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            return mappedValue
                        } else {
                            return .rotation0
                        }
                    },
                    getAspect: { [weak view] in
                        if let view = view {
                            return view.getAspect()
                        } else {
                            return 0.0
                        }
                    },
                    setOnOrientationUpdated: { f in
                        setOnOrientationUpdated { value, aspect in
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch value {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            f?(mappedValue, aspect)
                        }
                    },
                    setOnIsMirroredUpdated: { f in
                        setOnIsMirroredUpdated { value in
                            f?(value)
                        }
                    }
                ))
            } else {
                completion(nil)
            }
        })
    }
    
    func makeVideoView(source: UInt32, completion: @escaping (PresentationCallVideoView?) -> Void) {
        if source == 0 {
            self.makeOutgoingVideoView(completion: completion)
        } else {
            self.callContext?.makeIncomingVideoView(source: source, completion: { view in
                if let view = view {
                    let setOnFirstFrameReceived = view.setOnFirstFrameReceived
                    let setOnOrientationUpdated = view.setOnOrientationUpdated
                    let setOnIsMirroredUpdated = view.setOnIsMirroredUpdated
                    completion(PresentationCallVideoView(
                        holder: view,
                        view: view.view,
                        setOnFirstFrameReceived: { f in
                            setOnFirstFrameReceived(f)
                        },
                        getOrientation: { [weak view] in
                            if let view = view {
                                let mappedValue: PresentationCallVideoView.Orientation
                                switch view.getOrientation() {
                                case .rotation0:
                                    mappedValue = .rotation0
                                case .rotation90:
                                    mappedValue = .rotation90
                                case .rotation180:
                                    mappedValue = .rotation180
                                case .rotation270:
                                    mappedValue = .rotation270
                                }
                                return mappedValue
                            } else {
                                return .rotation0
                            }
                        },
                        getAspect: { [weak view] in
                            if let view = view {
                                return view.getAspect()
                            } else {
                                return 0.0
                            }
                        },
                        setOnOrientationUpdated: { f in
                            setOnOrientationUpdated { value, aspect in
                                let mappedValue: PresentationCallVideoView.Orientation
                                switch value {
                                case .rotation0:
                                    mappedValue = .rotation0
                                case .rotation90:
                                    mappedValue = .rotation90
                                case .rotation180:
                                    mappedValue = .rotation180
                                case .rotation270:
                                    mappedValue = .rotation270
                                }
                                f?(mappedValue, aspect)
                            }
                        },
                        setOnIsMirroredUpdated: { f in
                            setOnIsMirroredUpdated { value in
                                f?(value)
                            }
                        }
                    ))
                } else {
                    completion(nil)
                }
            })
        }
    }
    
    func setFullSizeVideo(peerId: PeerId?) {
        var resolvedSsrc: UInt32?
        if let peerId = peerId {
            for (ssrc, id) in self.ssrcMapping {
                if id == peerId {
                    resolvedSsrc = ssrc
                    break
                }
            }
        }
        self.callContext?.setFullSizeVideoSsrc(ssrc: resolvedSsrc)
    }
    
    func requestVideo(deviceId: String) {
        if self.videoCapturer == nil {
            let videoCapturer = OngoingCallVideoCapturer(deviceId, keepLandscape: true)
            self.videoCapturer = videoCapturer
            self.callContext?.requestVideo(videoCapturer)
        } else {
            self.switchVideoInput(deviceId)
        }
        //self.isVideo = true
        
    }
       
    func disableVideo() {
     //  self.isVideo = false
       if let _ = self.videoCapturer {
           self.videoCapturer = nil
           self.callContext?.disableVideo()
       }
    }
    
    func switchAccount(_ peerId: PeerId) -> Void {
        if peerId == self.joinAsPeerId {
            return
        }
        
        let _ = (self.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] myPeer in
            guard let strongSelf = self, let _ = myPeer else {
                return
            }
            
            let previousPeerId = strongSelf.joinAsPeerId
            if let localSsrc = strongSelf.currentLocalSsrc {
                strongSelf.ignorePreviousJoinAsPeerId = (previousPeerId, localSsrc)
            }
            strongSelf.joinAsPeerId = peerId
            strongSelf.stateValue.myPeerId = peerId
            
            if let participantsContext = strongSelf.participantsContext, let immediateState = participantsContext.immediateState {
                for participant in immediateState.participants {
                    if participant.peer.id == previousPeerId {
                        strongSelf.temporaryJoinTimestamp = participant.joinTimestamp
                        strongSelf.temporaryActivityTimestamp = participant.activityTimestamp
                        strongSelf.temporaryActivityRank = participant.activityRank
                        strongSelf.temporaryRaiseHandRating = participant.raiseHandRating
                        strongSelf.temporaryHasRaiseHand = participant.hasRaiseHand
                        strongSelf.temporaryMuteState = participant.muteState
                    }
                }
                strongSelf.switchToTemporaryParticipantsContext(sourceContext: participantsContext, oldMyPeerId: previousPeerId)
            } else {
                strongSelf.stateValue.myPeerId = peerId
            }

            
            strongSelf.requestCall(movingFromBroadcastToRtc: false)
        })
        
        
    }
    
    private func switchToTemporaryParticipantsContext(sourceContext: GroupCallParticipantsContext?, oldMyPeerId: PeerId) {
        let myPeerId = self.joinAsPeerId
        let myPeer = self.account.postbox.transaction { transaction -> (Peer, CachedPeerData?)? in
            if let peer = transaction.getPeer(myPeerId) {
                return (peer, transaction.getPeerCachedData(peerId: myPeerId))
            } else {
                return nil
            }
        }
        if let sourceContext = sourceContext, let initialState = sourceContext.immediateState {
           let temporaryParticipantsContext = GroupCallParticipantsContext(account: self.account, peerId: self.peerId, myPeerId: myPeerId, id: sourceContext.id, accessHash: sourceContext.accessHash, state: initialState, previousServiceState: sourceContext.serviceState)
           self.temporaryParticipantsContext = temporaryParticipantsContext
           self.participantsContextStateDisposable.set((combineLatest(queue: .mainQueue(),
               myPeer,
               temporaryParticipantsContext.state,
               temporaryParticipantsContext.activeSpeakers
           )
           |> take(1)).start(next: { [weak self] myPeerAndCachedData, state, activeSpeakers in
               guard let strongSelf = self else {
                   return
               }

               var topParticipants: [GroupCallParticipantsContext.Participant] = []

               var members = PresentationGroupCallMembers(
                   participants: [],
                   speakingParticipants: [],
                   totalCount: 0,
                   loadMoreToken: nil
               )

               var updatedInvitedPeers = strongSelf.invitedPeersValue
               var didUpdateInvitedPeers = false

               var participants = state.participants

               if oldMyPeerId != myPeerId {
                   for i in 0 ..< participants.count {
                       if participants[i].peer.id == oldMyPeerId {
                           participants.remove(at: i)
                           break
                       }
                   }
               }

               if !participants.contains(where: { $0.peer.id == myPeerId }) {
                   if let (myPeer, cachedData) = myPeerAndCachedData {
                       let about: String?
                       if let cachedData = cachedData as? CachedUserData {
                           about = cachedData.about
                       } else if let cachedData = cachedData as? CachedUserData {
                           about = cachedData.about
                       } else {
                           about = nil
                       }
                       participants.append(GroupCallParticipantsContext.Participant(
                           peer: myPeer,
                           ssrc: nil,
                           jsonParams: nil,
                           joinTimestamp: strongSelf.temporaryJoinTimestamp,
                           raiseHandRating: strongSelf.temporaryRaiseHandRating,
                           hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                           activityTimestamp: strongSelf.temporaryActivityTimestamp,
                           activityRank: strongSelf.temporaryActivityRank,
                           muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                           volume: nil,
                           about: about
                       ))
                       participants.sort()
                   }
               }

               for participant in participants {
                   members.participants.append(participant)

                   if topParticipants.count < 3 {
                       topParticipants.append(participant)
                   }

                   if let index = updatedInvitedPeers.firstIndex(of: participant.peer.id) {
                       updatedInvitedPeers.remove(at: index)
                       didUpdateInvitedPeers = true
                   }
               }

               members.totalCount = state.totalCount
               members.loadMoreToken = state.nextParticipantsFetchOffset

               strongSelf.membersValue = members

               var stateValue = strongSelf.stateValue
               stateValue.myPeerId = strongSelf.joinAsPeerId
               stateValue.adminIds = state.adminIds

               strongSelf.stateValue = stateValue

               strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
                   participantCount: state.totalCount,
                   topParticipants: topParticipants,
                   activeSpeakers: activeSpeakers
               )))

               if didUpdateInvitedPeers {
                   strongSelf.invitedPeersValue = updatedInvitedPeers
               }
           }))
       } else {
           self.temporaryParticipantsContext = nil
           self.participantsContextStateDisposable.set((myPeer
           |> deliverOnMainQueue
           |> take(1)).start(next: { [weak self] myPeerAndCachedData in
               guard let strongSelf = self else {
                   return
               }

               var topParticipants: [GroupCallParticipantsContext.Participant] = []

               var members = PresentationGroupCallMembers(
                   participants: [],
                   speakingParticipants: [],
                   totalCount: 0,
                   loadMoreToken: nil
               )

               var participants: [GroupCallParticipantsContext.Participant] = []

               if !participants.contains(where: { $0.peer.id == myPeerId }) {
                   if let (myPeer, cachedData) = myPeerAndCachedData {
                       let about: String?
                       if let cachedData = cachedData as? CachedUserData {
                           about = cachedData.about
                       } else if let cachedData = cachedData as? CachedUserData {
                           about = cachedData.about
                       } else {
                           about = nil
                       }
                       participants.append(GroupCallParticipantsContext.Participant(
                           peer: myPeer,
                           ssrc: nil,
                           jsonParams: nil,
                           joinTimestamp: strongSelf.temporaryJoinTimestamp,
                           raiseHandRating: strongSelf.temporaryRaiseHandRating,
                           hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                           activityTimestamp: strongSelf.temporaryActivityTimestamp,
                           activityRank: strongSelf.temporaryActivityRank,
                           muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                           volume: nil,
                           about: about
                       ))
                       participants.sort()
                   }
               }

               for participant in participants {
                   members.participants.append(participant)

                   if topParticipants.count < 3 {
                       topParticipants.append(participant)
                   }
               }

               strongSelf.membersValue = members

               var stateValue = strongSelf.stateValue
               stateValue.myPeerId = strongSelf.joinAsPeerId

               strongSelf.stateValue = stateValue
           }))
       }
    }

    
    func updateShouldBeRecording(_ shouldBeRecording: Bool, title: String? = nil) {
        self.participantsContext?.updateShouldBeRecording(shouldBeRecording, title: title)
    }
}

func requestOrJoinGroupCall(context: AccountContext, peerId: PeerId, joinAs: PeerId, initialCall: CachedChannelData.ActiveCall?, initialInfo: GroupCallInfo? = nil, joinHash: String? = nil) -> Signal<RequestOrJoinGroupCallResult, NoError> {
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
                return .success(startGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: initialCall, initialInfo: initialInfo, joinHash: joinHash, peer: peer))
            }
        }
    }
    
}


private func startGroupCall(context: AccountContext, peerId: PeerId, joinAs: PeerId, initialCall: CachedChannelData.ActiveCall?, initialInfo: GroupCallInfo? = nil, internalId: CallSessionInternalId = CallSessionInternalId(), joinHash: String? = nil, peer: Peer? = nil) -> GroupCallContext {
    return GroupCallContext(call: PresentationGroupCallImpl(
        account: context.account,
        peerChannelMemberCategoriesContextsManager: context.peerChannelMemberCategoriesContextsManager,
        sharedContext: context.sharedContext,
        internalId: internalId,
        initialCall: initialCall,
        initialInfo: initialInfo,
        joinAs: joinAs,
        joinHash: joinHash,
        peerId: peerId,
        peer: peer
    ), peerMemberContextsManager: context.peerChannelMemberCategoriesContextsManager)
}

func createVoiceChat(context: AccountContext, peerId: PeerId, displayAsList: [FoundPeer]? = nil) {
    let confirmation = makeNewCallConfirmation(account: context.account, sharedContext: context.sharedContext, newPeerId: peerId, newCallType: .voiceChat) |> mapToSignalPromotingError { _ in
        return Signal<(GroupCallInfo, PeerId), CreateGroupCallError> { subscriber in
            
            let disposable = MetaDisposable()
            
            let create:(PeerId)->Void = { joinAs in
                disposable.set(createGroupCall(account: context.account, peerId: peerId).start(next: { info in
                    subscriber.putNext((info, joinAs))
                    subscriber.putCompletion()
                }, error: { error in
                    subscriber.putError(error)
                }))
            }
            if let displayAsList = displayAsList {
                if !displayAsList.isEmpty {
                    showModal(with: GroupCallDisplayAsController(context: context, mode: .create, peerId: peerId, list: displayAsList, completion: create), for: context.window)
                } else {
                    create(context.peerId)
                }
            } else {
                selectGroupCallJoiner(context: context, peerId: peerId, completion: create)
            }
            
            return ActionDisposable {
                disposable.dispose()
            }
        } |> runOn(.mainQueue())
    }

    let requestCall = confirmation |> mapToSignal { call, joinAs in
        return showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: CachedChannelData.ActiveCall(id: call.id, accessHash: call.accessHash, title: call.title)) |> mapError { _ in .generic }, for: context.window)
    } |> deliverOnMainQueue
    _ = requestCall.start(next: { result in
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




