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
                                                let callContext = impl.get(account: context.account, peerId: peerId, call: activeCall)
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

protocol AccountGroupCallContext: class {
}

protocol AccountGroupCallContextCache: class {
}


private extension GroupCallParticipantsContext.Participant {
    var allSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let ssrc = self.ssrc {
            participantSsrcs.insert(ssrc)
        }
        if let videoDescription = self.videoDescription {
            for group in videoDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        if let presentationDescription = self.presentationDescription {
            for group in presentationDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        return participantSsrcs
    }

    var videoSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let videoDescription = self.videoDescription {
            for group in videoDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        return participantSsrcs
    }

    var presentationSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let presentationDescription = self.presentationDescription {
            for group in presentationDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        return participantSsrcs
    }
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
                streamDcId: nil,
                title: call.title,
                scheduleTimestamp: nil,
                subscribedToScheduled: false,
                recordingStartTimestamp: nil,
                sortAscending: true,
                defaultParticipantsAreMuted: nil,
                isVideoEnabled: false
            ),
            topParticipants: [],
            participantCount: 0,
            activeSpeakers: Set(),
            groupCall: nil
        )))
        
        self.disposable = (getGroupCallParticipants(account: account, callId: call.id, accessHash: call.accessHash, offset: "", ssrcs: [], limit: 100, sortAscending: nil)
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
                myPeerId: account.peerId,
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
                    info: GroupCallInfo(id: call.id, accessHash: call.accessHash, participantCount: state.totalCount, streamDcId: nil, title: state.title, scheduleTimestamp: state.scheduleTimestamp, subscribedToScheduled: state.subscribedToScheduled, recordingStartTimestamp: state.recordingStartTimestamp, sortAscending: state.sortAscending, defaultParticipantsAreMuted: state.defaultParticipantsAreMuted, isVideoEnabled: state.isVideoEnabled),
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

        private let leaveDisposables = DisposableSet()
        
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

        func leaveInBackground(account: Account, id: Int64, accessHash: Int64, source: UInt32) {
            let disposable = leaveGroupCall(account: account, callId: id, accessHash: accessHash, source: source).start()
            self.leaveDisposables.add(disposable)
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
    static func initialValue(myPeerId: PeerId, title: String?, scheduledTimestamp: Int32?, subscribedToScheduled: Bool) -> PresentationGroupCallState {
        return PresentationGroupCallState(
            myPeerId: myPeerId,
            networkState: .connecting,
            canManageCall: false,
            adminIds: Set(),
            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
            defaultParticipantMuteState: nil,
            recordingStartTimestamp: nil,
            title: title,
            raisedHand: false,
            scheduleTimestamp: scheduledTimestamp,
            subscribedToScheduled: subscribedToScheduled
        )
    }
}

final class PresentationGroupCallImpl: PresentationGroupCall {

    var peer: Peer? = nil
    private let loadPeerDisposable = MetaDisposable()
//    var activeCall: CachedChannelData.ActiveCall?

    private let startDisposable = MetaDisposable()
    private let subscribeDisposable = MetaDisposable()
    private let updateGroupCallJoinAsDisposable = MetaDisposable()
    
    
    private let devicesContext: DevicesContext
    private let devicesDisposable = MetaDisposable()
    
    private let displayAsPeersValue: Promise<[FoundPeer]?> = Promise(nil)
    var displayAsPeers: Signal<[FoundPeer]?, NoError> {
        return displayAsPeersValue.get()
    }
    private let loadDisplayAsPeerDisposable = MetaDisposable()

    
    var permissions: (PresentationGroupCallMuteAction, @escaping(Bool)->Void)->Void = { _, f in f(true) }

    var sharedContext: SharedAccountContext {
        return accountContext.sharedContext
    }
    
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
        private let speakingParticipantsPromise = ValuePromise<[PeerId: UInt32]>(ignoreRepeated: true)
        private var speakingParticipants = [PeerId: UInt32]() {
            didSet {
                self.speakingParticipantsPromise.set(self.speakingParticipants)
            }
        }
        
        private let audioLevelsPromise = Promise<[(PeerId, UInt32, Float, Bool)]>()
        
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
            
            var audioLevels: [(PeerId, UInt32, Float, Bool)] = []
            for (peerId, source, level, hasVoice) in levels {
                if level > 0.001 {
                    audioLevels.append((peerId, source, level, hasVoice))
                }
            }
            
            self.participants = validSpeakers
            self.speakingParticipants = speakingParticipants
            self.audioLevelsPromise.set(.single(audioLevels))
        }
        
        func get() -> Signal<[PeerId: UInt32], NoError> {
            return self.speakingParticipantsPromise.get()
        }
        
        func getAudioLevels() -> Signal<[(PeerId, UInt32, Float, Bool)], NoError> {
            return self.audioLevelsPromise.get() |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.count != rhs.count {
                    return false
                } else {
                    for (i, lhsValue) in lhs.enumerated() {
                        let rhsValue = rhs[i]
                        if lhsValue != rhsValue {
                            return false
                        }
                    }
                }
                return true
            })
        }
    }
    
    let account: Account
    let accountContext: AccountContext
    
    var engine: TelegramEngine {
        return accountContext.engine
    }
    
    private var initialCall: CachedChannelData.ActiveCall?
    let internalId: CallSessionInternalId
    let peerId: PeerId
    private var invite: String?
    private var joinAsPeerIdSignal:ValuePromise<PeerId> = ValuePromise(ignoreRepeated: true)
    var joinAsPeerIdValue:Signal<PeerId, NoError> {
        return joinAsPeerIdSignal.get()
    }
    private(set) var joinAsPeerId: PeerId {
        didSet {
            joinAsPeerIdSignal.set(joinAsPeerId)
        }
    }
    private var ignorePreviousJoinAsPeerId: (PeerId, UInt32)?
    private var reconnectingAsPeer: Peer?
    
    public private(set) var hasVideo: Bool
    public private(set) var hasScreencast: Bool

    
        
    private let updateTitleDisposable = MetaDisposable()
    
    private var temporaryJoinTimestamp: Int32
    private var temporaryActivityTimestamp: Double?
    private var temporaryActivityRank: Int?
    private var temporaryRaiseHandRating: Int64?
    private var temporaryHasRaiseHand: Bool = false
    private var temporaryMuteState: GroupCallParticipantsContext.Participant.MuteState?
    
    private var internalState: InternalState = .requesting
    private let internalStatePromise = Promise<InternalState>(.requesting)
    private var currentLocalSsrc: UInt32?
    
    private var genericCallContext: OngoingGroupCallContext?
    private var currentConnectionMode: OngoingGroupCallContext.ConnectionMode = .none
    private var screencastCallContext: OngoingGroupCallContext?
    private var ssrcMapping: [UInt32: PeerId] = [:]
    
    private var requestedSsrcs = Set<UInt32>()
    
    private var summaryInfoState = Promise<SummaryInfoState?>(nil)
    
    var callInfo: Signal<GroupCallInfo?, NoError> {
        return summaryInfoState.get() |> map { $0?.info }
    }
    
    private var summaryParticipantsState = Promise<SummaryParticipantsState?>(nil)
    
    private let summaryStatePromise = Promise<PresentationGroupCallSummaryState?>(nil)
    var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> {
        return self.summaryStatePromise.get() |> distinctUntilChanged
    }
    private var summaryStateDisposable: Disposable?
    
    private var isMutedValue: PresentationGroupCallMuteAction = .muted(isPushToTalkActive: false) {
        didSet {
            if self.isMutedValue != oldValue {
            }
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
    
    private var settingsDisposable: Disposable?
        
    private var audioLevelsDisposable = MetaDisposable()
    
    private let speakingParticipantsContext = SpeakingParticipantsContext()
    private var speakingParticipantsReportTimestamp: [PeerId: Double] = [:]
    var audioLevels: Signal<[(PeerId, UInt32, Float, Bool)], NoError> {
        return self.speakingParticipantsContext.getAudioLevels()
    }
    
    private var participantsContextStateDisposable = MetaDisposable()
    private var temporaryParticipantsContext: GroupCallParticipantsContext?
    private var participantsContext: GroupCallParticipantsContext?
    
    private let myAudioLevelPipe = ValuePipe<Float>()
    var myAudioLevel: Signal<Float, NoError> {
        return self.myAudioLevelPipe.signal()
    }
    private var myAudioLevelDisposable = MetaDisposable()
        
    private let typingDisposable = MetaDisposable()
    
    private let _canBeRemoved = Promise<Bool>(false)
    var canBeRemoved: Signal<Bool, NoError> {
        return self._canBeRemoved.get()
    }
    private var markedAsCanBeRemoved = false
    
    private let wasRemoved = Promise<Bool>(false)
    private var leaving = false
    
    private var stateValue: PresentationGroupCallState {
        didSet {
            if self.stateValue != oldValue {
                self.statePromise.set(self.stateValue)
            }
        }
    }
    private let statePromise: ValuePromise<PresentationGroupCallState>
    var state: Signal<PresentationGroupCallState, NoError> {
        return self.statePromise.get()
    }
    
    private var stateVersionValue: Int = 0 {
        didSet {
            if self.stateVersionValue != oldValue {
                self.stateVersionPromise.set(self.stateVersionValue)
            }
        }
    }
    private let stateVersionPromise = ValuePromise<Int>(0)
    public var stateVersion: Signal<Int, NoError> {
        return self.stateVersionPromise.get()
    }

    
    private var membersValue: PresentationGroupCallMembers? {
        didSet {
            if self.membersValue != oldValue {
                self.membersPromise.set(self.membersValue)
            }
        }
    }
    private let membersPromise = ValuePromise<PresentationGroupCallMembers?>(nil)
    var members: Signal<PresentationGroupCallMembers?, NoError> {
        return self.membersPromise.get()
    }
    
    private var invitedPeersValue: [PeerId] = [] {
        didSet {
            if self.invitedPeersValue != oldValue {
                self.inivitedPeersPromise.set(self.invitedPeersValue)
            }
        }
    }
    private let inivitedPeersPromise = ValuePromise<[PeerId]>([])
    var invitedPeers: Signal<[PeerId], NoError> {
        return self.inivitedPeersPromise.get()
    }
    
    private let memberEventsPipe = ValuePipe<PresentationGroupCallMemberEvent>()
    var memberEvents: Signal<PresentationGroupCallMemberEvent, NoError> {
        return self.memberEventsPipe.signal()
    }
    private let memberEventsPipeDisposable = MetaDisposable()

    private let reconnectedAsEventsPipe = ValuePipe<Peer>()
    var reconnectedAsEvents: Signal<Peer, NoError> {
        return self.reconnectedAsEventsPipe.signal()
    }
    
    private let joinDisposable = MetaDisposable()
    private let screencastJoinDisposable = MetaDisposable()
    private let requestDisposable = MetaDisposable()
    private var groupCallParticipantUpdatesDisposable: Disposable?
    
    private let networkStateDisposable = MetaDisposable()
    private let isMutedDisposable = MetaDisposable()
    private let memberStatesDisposable = MetaDisposable()
    private let leaveDisposable = MetaDisposable()

    private var isReconnectingAsSpeaker = false {
        didSet {
            if self.isReconnectingAsSpeaker != oldValue {
                self.isReconnectingAsSpeakerPromise.set(self.isReconnectingAsSpeaker)
            }
        }
    }
    private let isReconnectingAsSpeakerPromise = ValuePromise<Bool>(false)
    
    private var checkCallDisposable: Disposable?
    private var isCurrentlyConnecting: Bool?

    private var myAudioLevelTimer: SwiftSignalKit.Timer?
    
    private var proximityManagerIndex: Int?
    
    private var removedChannelMembersDisposable: Disposable?
    
    private var didStartConnectingOnce: Bool = false
    private var didConnectOnce: Bool = false
    
    private var videoCapturer: OngoingCallVideoCapturer?
    
    private var screenCapturer: OngoingCallVideoCapturer?
    private let screencastEndpointIdValue: ValuePromise<String?> = ValuePromise(nil, ignoreRepeated: true)
    private var screencastEndpointId: String? = nil {
        didSet {
            screencastEndpointIdValue.set(screencastEndpointId)
        }
    }
    
    public private(set) var schedulePending = false
    private var isScheduled = false
    private var isScheduledStarted = false


    private var peerUpdatesSubscription: Disposable?
    
    init(
        accountContext: AccountContext,
        initialCall: CachedChannelData.ActiveCall?,
        internalId: CallSessionInternalId,
        peerId: PeerId,
        invite: String?,
        joinAsPeerId: PeerId?,
        initialInfo: GroupCallInfo?
    ) {
        self.account = accountContext.account
        self.accountContext = accountContext
        
        self.initialCall = initialCall
        self.internalId = internalId
        self.peerId = peerId
        self.invite = invite
        self.joinAsPeerId = joinAsPeerId ?? accountContext.account.peerId
        self.joinAsPeerIdSignal.set(self.joinAsPeerId)
        let peerSignal = account.postbox.peerView(id: peerId)
            |> map { peerViewMainPeer($0) }
            |> deliverOnMainQueue
                
        self.stateValue = PresentationGroupCallState.initialValue(myPeerId: self.joinAsPeerId, title: initialCall?.title, scheduledTimestamp: initialCall?.scheduleTimestamp, subscribedToScheduled: initialCall?.subscribedToScheduled ?? false)
        self.statePromise = ValuePromise(self.stateValue)
        
        self.temporaryJoinTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        self.hasVideo = false
        self.hasScreencast = false

        self.devicesContext = accountContext.sharedContext.devicesContext

        devicesDisposable.set(devicesContext.updater().start(next: { [weak self] values in
            guard let `self` = self else {
                return
            }
            if let id = values.input {
                self.genericCallContext?.switchAudioInput(id)
            }
            if let id = values.output {
                self.genericCallContext?.switchAudioOutput(id)
            }
        }))
        
        self.loadPeerDisposable.set(peerSignal.start(next: { [weak self] peer in
            self?.peer = peer
        }))
        
        self.groupCallParticipantUpdatesDisposable = (self.account.stateManager.groupCallParticipantUpdates
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let strongSelf = self else {
                return
            }
            if case let .established(callInfo, _, _, _, _) = strongSelf.internalState {
                var addedParticipants: [(UInt32, String?, String?)] = []
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
                                } else if let ssrc = participantUpdate.ssrc, strongSelf.ssrcMapping[ssrc] == nil {
                                }
                            }
                        case let .call(isTerminated, _, _, _, _, _):
                            if isTerminated {
                                strongSelf.markAsCanBeRemoved()
                            }
                        }
                    }
                }
                if !removedSsrc.isEmpty {
                    strongSelf.genericCallContext?.removeSsrcs(ssrcs: removedSsrc)
                }
                //strongSelf.callContext?.addParticipants(participants: addedParticipants)
            }
        })
        

        self.displayAsPeersValue.set(cachedGroupCallDisplayAsAvailablePeers(account: account, peerId: peerId) |> map(Optional.init))

        
        self.summaryStatePromise.set(combineLatest(queue: .mainQueue(),
            self.summaryInfoState.get(),
            self.summaryParticipantsState.get(),
            self.statePromise.get()
        )
        |> map { infoState, participantsState, callState -> PresentationGroupCallSummaryState? in
            guard let participantsState = participantsState else {
                return nil
            }
            return PresentationGroupCallSummaryState(
                info: infoState?.info,
                participantCount: participantsState.participantCount,
                callState: callState,
                topParticipants: participantsState.topParticipants,
                activeSpeakers: participantsState.activeSpeakers
            )
        })
        
        if let initialCall = initialCall, let temporaryParticipantsContext = self.accountContext.cachedGroupCallContexts.impl.syncWith({ impl in
            impl.get(account: accountContext.account, peerId: peerId, call: initialCall)
        }) {
            self.switchToTemporaryParticipantsContext(sourceContext: temporaryParticipantsContext.context.participantsContext, oldMyPeerId: self.joinAsPeerId)
        } else {
            self.switchToTemporaryParticipantsContext(sourceContext: nil, oldMyPeerId: self.joinAsPeerId)
        }
        
//        self.removedChannelMembersDisposable = (accountContext.peerChannelMemberCategoriesContextsManager.removedChannelMembers
//        |> deliverOnMainQueue).start(next: { [weak self] pairs in
//            guard let strongSelf = self else {
//                return
//            }
//            for (channelId, memberId) in pairs {
//                if channelId == strongSelf.peerId {
//                    strongSelf.removedPeer(memberId)
//                }
//            }
//        })
        
        let _ = (self.account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            var canManageCall = false
            if let peer = peer as? TelegramGroup {
                if case .creator = peer.role {
                    canManageCall = true
                } else if case let .admin(rights, _) = peer.role, rights.rights.contains(.canManageCalls) {
                    canManageCall = true
                }
            } else if let peer = peer as? TelegramChannel {
                if peer.flags.contains(.isCreator) {
                    canManageCall = true
                } else if (peer.adminRights?.rights.contains(.canManageCalls) == true) {
                    canManageCall = true
                }
                strongSelf.peerUpdatesSubscription = strongSelf.accountContext.account.viewTracker.polledChannel(peerId: peer.id).start()
            }
            var updatedValue = strongSelf.stateValue
            updatedValue.canManageCall = canManageCall
            strongSelf.stateValue = updatedValue
        })
        
      //  if initialCall?.scheduleTimestamp == nil {
            self.requestCall(movingFromBroadcastToRtc: false)
      //  }
        if let initialInfo = initialInfo {
            summaryInfoState.set(.single(.init(info: initialInfo)))
        }
    }
    
    deinit {
        self.summaryStateDisposable?.dispose()
        self.joinDisposable.dispose()
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
        self.memberEventsPipeDisposable.dispose()
        self.screencastJoinDisposable.dispose()
        self.myAudioLevelTimer?.invalidate()
        self.typingDisposable.dispose()
        self.updateTitleDisposable.dispose()
        self.removedChannelMembersDisposable?.dispose()

        self.peerUpdatesSubscription?.dispose()
        self.devicesDisposable.dispose()
        self.loadPeerDisposable.dispose()
        self.startDisposable.dispose()
        self.subscribeDisposable.dispose()
        self.updateGroupCallJoinAsDisposable.dispose()
        self.settingsDisposable?.dispose()
    }
    
    private func switchToTemporaryParticipantsContext(sourceContext: GroupCallParticipantsContext?, oldMyPeerId: PeerId) {
        let myPeerId = self.joinAsPeerId
        let myPeer = self.accountContext.account.postbox.transaction { transaction -> (Peer, CachedPeerData?)? in
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
                            videoDescription: nil,
                            presentationDescription: nil,
                            joinTimestamp: strongSelf.temporaryJoinTimestamp,
                            raiseHandRating: strongSelf.temporaryRaiseHandRating,
                            hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                            activityTimestamp: strongSelf.temporaryActivityTimestamp,
                            activityRank: strongSelf.temporaryActivityRank,
                            muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                            volume: nil,
                            about: about
                        ))
                        participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
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
                
                stateValue.scheduleTimestamp = state.scheduleTimestamp
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
                        videoDescription: nil,
                        presentationDescription: nil,
                        joinTimestamp: strongSelf.temporaryJoinTimestamp,
                        raiseHandRating: strongSelf.temporaryRaiseHandRating,
                        hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                        activityTimestamp: strongSelf.temporaryActivityTimestamp,
                        activityRank: strongSelf.temporaryActivityRank,
                        muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                        volume: nil,
                        about: about
                    ))
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
    
    private func updateSessionState(internalState: InternalState) {
        
        let previousInternalState = self.internalState
        self.internalState = internalState
        self.internalStatePromise.set(.single(internalState))
        
        var shouldJoin = false
        let activeCallInfo: GroupCallInfo?
        switch previousInternalState {
            case let .active(previousCallInfo):
                if case let .active(callInfo) = internalState {
                    shouldJoin = previousCallInfo.scheduleTimestamp != nil && callInfo.scheduleTimestamp == nil
                    activeCallInfo = callInfo
                } else {
                    activeCallInfo = nil
                }
            default:
                if case let .active(callInfo) = internalState {
                    shouldJoin = callInfo.scheduleTimestamp == nil
                    activeCallInfo = callInfo
                } else {
                    activeCallInfo = nil
                }
        }

        
        switch previousInternalState {
        case .requesting:
            break
        default:
            if case .requesting = internalState {
                self.isCurrentlyConnecting = nil
            }
        }
        
        if shouldJoin, let callInfo = activeCallInfo {
            let genericCallContext: OngoingGroupCallContext
            if let current = self.genericCallContext {
                genericCallContext = current
            } else {
                genericCallContext = OngoingGroupCallContext(inputDeviceId: devicesContext.currentMicroId ?? "", outputDeviceId: devicesContext.currentOutputId ?? "", video: self.videoCapturer, requestMediaChannelDescriptions: { [weak self] ssrcs, completion in
                    let disposable = MetaDisposable()
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        disposable.set(strongSelf.requestMediaChannelDescriptions(ssrcs: ssrcs, completion: completion))
                    }
                    return disposable
                }, audioStreamData: OngoingGroupCallContext.AudioStreamData(account: self.accountContext.account, callId: callInfo.id, accessHash: callInfo.accessHash), rejoinNeeded: { [weak self] in
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        if case .established = strongSelf.internalState {
                            strongSelf.requestCall(movingFromBroadcastToRtc: false)
                        }
                    }
                }, outgoingAudioBitrateKbit: nil, videoContentType: .generic, enableNoiseSuppression: false)
                
                self.settingsDisposable = (voiceCallSettings(self.sharedContext.accountManager) |> deliverOnMainQueue).start(next: { [weak self] settings in
                    self?.genericCallContext?.setIsNoiseSuppressionEnabled(settings.noiseSuppression)
                })
                
                self.genericCallContext = genericCallContext
                self.stateVersionValue += 1
            }
            self.joinDisposable.set((genericCallContext.joinPayload
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                return true
            })
            |> deliverOnMainQueue).start(next: { [weak self] joinPayload, ssrc in
                guard let strongSelf = self else {
                    return
                }

                let peerAdminIds: Signal<[PeerId], NoError>
                let peerId = strongSelf.peerId
                if strongSelf.peerId.namespace == Namespaces.Peer.CloudChannel {
                    peerAdminIds = Signal { subscriber in
                        let (disposable, _) = strongSelf.accountContext.peerChannelMemberCategoriesContextsManager.admins(postbox: strongSelf.accountContext.account.postbox, network: strongSelf.accountContext.account.network, accountPeerId: strongSelf.accountContext.account.peerId, peerId: peerId, updated: { list in
                            var peerIds = Set<PeerId>()
                            for item in list.list {
                                if let adminInfo = item.participant.adminInfo, adminInfo.rights.rights.contains(.canManageCalls) {
                                    peerIds.insert(item.peer.id)
                                }
                            }
                            subscriber.putNext(Array(peerIds))
                        })
                        return disposable
                    }
                    |> distinctUntilChanged
                    |> runOn(.mainQueue())
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
                    inviteHash: strongSelf.invite
                )
                |> deliverOnMainQueue).start(next: { joinCallResult in
                    guard let strongSelf = self else {
                        return
                    }
                    let clientParams = joinCallResult.jsonParams

                    strongSelf.ssrcMapping.removeAll()
                    for participant in joinCallResult.state.participants {
                        if let ssrc = participant.ssrc {
                            strongSelf.ssrcMapping[ssrc] = participant.peer.id
                        }
                    }

                    switch joinCallResult.connectionMode {
                    case .rtc:
                        strongSelf.currentConnectionMode = .rtc
                        strongSelf.genericCallContext?.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false)
                        strongSelf.genericCallContext?.setJoinResponse(payload: clientParams)
                    case .broadcast:
                        strongSelf.currentConnectionMode = .broadcast
                        strongSelf.genericCallContext?.setConnectionMode(.broadcast, keepBroadcastConnectedIfWasEnabled: false)
                    }

                    strongSelf.updateSessionState(internalState: .established(info: joinCallResult.callInfo, connectionMode: joinCallResult.connectionMode, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state))

                }, error: { error in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if case .anonymousNotAllowed = error {
                        alert(for: strongSelf.accountContext.window, info: L10n.voiceChatAnonymousDisabledAlertText)
                    } else if case .tooManyParticipants = error {
                        alert(for: strongSelf.accountContext.window, info: L10n.voiceChatJoinErrorTooMany)
                    }
                    strongSelf.markAsCanBeRemoved()
                }))
            }))
            self.networkStateDisposable.set((genericCallContext.networkState
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
                
                if isConnecting {
                    strongSelf.didStartConnectingOnce = true
                }
                
                if state.isConnected {
                    if !strongSelf.didConnectOnce {
                        strongSelf.didConnectOnce = true
                    }

                    if let peer = strongSelf.reconnectingAsPeer {
                        strongSelf.reconnectingAsPeer = nil
                        strongSelf.reconnectedAsEventsPipe.putNext(peer)
                    }
                }
            }))
            
            self.audioLevelsDisposable.set((genericCallContext.audioLevels
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
                            
                strongSelf.speakingParticipantsContext.update(levels: result)
                
                let mappedLevel = myLevel * 1.5
                strongSelf.myAudioLevelPipe.putNext(mappedLevel)
                strongSelf.processMyAudioLevel(level: mappedLevel, hasVoice: myLevelHasVoice)
                
                if !missingSsrcs.isEmpty {
                    strongSelf.participantsContext?.ensureHaveParticipants(ssrcs: missingSsrcs)
                }
            }))
        }
        
        switch previousInternalState {
        case .established:
            break
        default:
            if case let .established(callInfo, _, _, _, initialState) = internalState {
                self.summaryInfoState.set(.single(SummaryInfoState(info: callInfo)))
                
                var stateValue = self.stateValue
                
                stateValue.canManageCall = initialState.isCreator || initialState.adminIds.contains(self.accountContext.account.peerId)
                if stateValue.canManageCall && initialState.defaultParticipantsAreMuted.canChange {
                    stateValue.defaultParticipantMuteState = initialState.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                }
                stateValue.recordingStartTimestamp = initialState.recordingStartTimestamp
                stateValue.title = initialState.title

                stateValue.scheduleTimestamp = initialState.scheduleTimestamp
                stateValue.subscribedToScheduled = initialState.subscribedToScheduled

                self.stateValue = stateValue
                
                let accountContext = self.accountContext
                let peerId = self.peerId
                let rawAdminIds: Signal<Set<PeerId>, NoError>
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    rawAdminIds = Signal { subscriber in
                        let (disposable, _) = accountContext.peerChannelMemberCategoriesContextsManager.admins(postbox: accountContext.account.postbox, network: accountContext.account.network, accountPeerId: accountContext.account.peerId, peerId: peerId, updated: { list in
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
                    rawAdminIds = accountContext.account.postbox.combinedView(keys: [.cachedPeerData(peerId: peerId)])
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
                    accountContext.account.postbox.combinedView(keys: [.basicPeer(peerId)])
                )
                |> map { rawAdminIds, view -> Set<PeerId> in
                    var rawAdminIds = rawAdminIds
                    if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer as? TelegramChannel {
                        if peer.hasPermission(.manageCalls) {
                            rawAdminIds.insert(accountContext.account.peerId)
                        } else {
                            rawAdminIds.remove(accountContext.account.peerId)
                        }
                    }
                    return rawAdminIds
                }
                |> distinctUntilChanged

                let myPeerId = self.joinAsPeerId
                
                var initialState = initialState
                var serviceState: GroupCallParticipantsContext.ServiceState?
                if let participantsContext = self.participantsContext, let immediateState = participantsContext.immediateState {
                    initialState.mergeActivity(from: immediateState, myPeerId: myPeerId, previousMyPeerId: self.ignorePreviousJoinAsPeerId?.0, mergeActivityTimestamps: true)
                    serviceState = participantsContext.serviceState
                }
                
                let participantsContext = GroupCallParticipantsContext(
                    account: self.accountContext.account,
                    peerId: self.peerId,
                    myPeerId: self.joinAsPeerId,
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    state: initialState,
                    previousServiceState: serviceState
                )
                self.temporaryParticipantsContext = nil
                self.participantsContext = participantsContext
                let myPeer = self.accountContext.account.postbox.transaction { transaction -> (Peer, CachedPeerData?)? in
                    if let peer = transaction.getPeer(myPeerId) {
                        return (peer, transaction.getPeerCachedData(peerId: myPeerId))
                    } else {
                        return nil
                    }
                }
                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                    participantsContext.state,
                    participantsContext.activeSpeakers,
                    self.speakingParticipantsContext.get(),
                    adminIds,
                    myPeer,
                    accountContext.account.postbox.peerView(id: peerId),
                    self.isReconnectingAsSpeakerPromise.get()
                ).start(next: { [weak self] state, activeSpeakers, speakingParticipants, adminIds, myPeerAndCachedData, view, isReconnectingAsSpeaker in
                    guard let strongSelf = self else {
                        return
                    }

                    strongSelf.participantsContext?.updateAdminIds(adminIds)
                    
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
                    
                    var updatedInvitedPeers = strongSelf.invitedPeersValue
                    var didUpdateInvitedPeers = false

                    var participants = state.participants

                    if let (ignorePeerId, ignoreSsrc) = strongSelf.ignorePreviousJoinAsPeerId {
                        for i in 0 ..< participants.count {
                            if participants[i].peer.id == ignorePeerId && participants[i].ssrc == ignoreSsrc {
                                participants.remove(at: i)
                                break
                            }
                        }
                    }

                    if !participants.contains(where: { $0.peer.id == myPeerId }) && !strongSelf.leaving {
                        if let (myPeer, cachedData) = myPeerAndCachedData {
                            let about: String?
                            if let cachedData = cachedData as? CachedUserData {
                                about = cachedData.about
                            } else if let cachedData = cachedData as? CachedChannelData {
                                about = cachedData.about
                            } else {
                                about = nil
                            }

                            participants.append(GroupCallParticipantsContext.Participant(
                                peer: myPeer,
                                ssrc: nil,
                                videoDescription: nil,
                                presentationDescription: nil,
                                joinTimestamp: strongSelf.temporaryJoinTimestamp,
                                raiseHandRating: strongSelf.temporaryRaiseHandRating,
                                hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                                activityTimestamp: strongSelf.temporaryActivityTimestamp,
                                activityRank: strongSelf.temporaryActivityRank,
                                muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                                volume: nil,
                                about: about
                            ))
                            participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                        }
                    }
                    
                    for participant in participants {
                        var participant = participant
                        
                        if topParticipants.count < 3 {
                            topParticipants.append(participant)
                        }
                        
                        if let ssrc = participant.ssrc {
                            strongSelf.ssrcMapping[ssrc] = participant.peer.id
                        }
                        
                        if participant.peer.id == strongSelf.joinAsPeerId {
                            var filteredMuteState = participant.muteState
                            if isReconnectingAsSpeaker || strongSelf.currentConnectionMode != .rtc {
                                filteredMuteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false)
                                participant.muteState = filteredMuteState
                            }

                            if !(strongSelf.stateValue.muteState?.canUnmute ?? false) {
                                strongSelf.stateValue.raisedHand = participant.hasRaiseHand
                            }

                            if let muteState = filteredMuteState {
                                if muteState.canUnmute {
                                    switch strongSelf.isMutedValue {
                                    case let .muted(isPushToTalkActive):
                                        if !isPushToTalkActive {
                                            strongSelf.genericCallContext?.setIsMuted(true)
                                        }
                                    case .unmuted:
                                        strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                        strongSelf.genericCallContext?.setIsMuted(true)
                                    }
                                } else {
                                    strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                    strongSelf.genericCallContext?.setIsMuted(true)
                                }
                                strongSelf.stateValue.muteState = muteState
                            } else if let currentMuteState = strongSelf.stateValue.muteState, !currentMuteState.canUnmute {
                                strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                strongSelf.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
                                strongSelf.genericCallContext?.setIsMuted(true)
                            }
                        } else {
                            if let ssrc = participant.ssrc {
                                if let volume = participant.volume {
                                    strongSelf.genericCallContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    strongSelf.genericCallContext?.setVolume(ssrc: ssrc, volume: 0.0)
                                }
                            }
                        }
                        
                        if let index = updatedInvitedPeers.firstIndex(of: participant.peer.id) {
                            updatedInvitedPeers.remove(at: index)
                            didUpdateInvitedPeers = true
                        }

                        members.participants.append(participant)
                    }
                    
                    members.totalCount = state.totalCount
                    members.loadMoreToken = state.nextParticipantsFetchOffset
                    
                    strongSelf.membersValue = members
                    
                    var stateValue = strongSelf.stateValue
                    
                    stateValue.adminIds = adminIds
                    
                    stateValue.canManageCall = state.isCreator || adminIds.contains(strongSelf.accountContext.account.peerId)
                    if (state.isCreator || stateValue.adminIds.contains(strongSelf.accountContext.account.peerId)) && state.defaultParticipantsAreMuted.canChange {
                        stateValue.defaultParticipantMuteState = state.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                    }
                    stateValue.recordingStartTimestamp = state.recordingStartTimestamp
                    stateValue.title = state.title
                    stateValue.scheduleTimestamp = state.scheduleTimestamp
                    stateValue.subscribedToScheduled = state.subscribedToScheduled
                    
                    strongSelf.stateValue = stateValue
                    
                    strongSelf.summaryInfoState.set(.single(SummaryInfoState(info: GroupCallInfo(
                        id: callInfo.id,
                        accessHash: callInfo.accessHash,
                        participantCount: state.totalCount,
                        streamDcId: nil,
                        title: state.title,
                        scheduleTimestamp: state.scheduleTimestamp,
                        subscribedToScheduled: state.subscribedToScheduled,
                        recordingStartTimestamp: state.recordingStartTimestamp,
                        sortAscending: state.sortAscending,
                        defaultParticipantsAreMuted: state.defaultParticipantsAreMuted,
                        isVideoEnabled: state.isVideoEnabled
                    ))))
                    
                    strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
                        participantCount: state.totalCount,
                        topParticipants: topParticipants,
                        activeSpeakers: activeSpeakers
                    )))
                    
                    if didUpdateInvitedPeers {
                        strongSelf.invitedPeersValue = updatedInvitedPeers
                    }
                }))
                
                let postbox = self.accountContext.account.postbox
                self.memberEventsPipeDisposable.set((participantsContext.memberEvents
                |> mapToSignal { event -> Signal<PresentationGroupCallMemberEvent, NoError> in
                    return postbox.transaction { transaction -> Signal<PresentationGroupCallMemberEvent, NoError> in
                        if let peer = transaction.getPeer(event.peerId) {
                            return .single(PresentationGroupCallMemberEvent(peer: peer, joined: event.joined))
                        } else {
                            return .complete()
                        }
                    }
                    |> switchToLatest
                }
                |> deliverOnMainQueue).start(next: { [weak self] event in
                    guard let strongSelf = self else {
                        return
                    }
                    if event.peer.id == strongSelf.stateValue.myPeerId {
                        return
                    }
                    strongSelf.memberEventsPipe.putNext(event)
                }))
                
                if let isCurrentlyConnecting = self.isCurrentlyConnecting, isCurrentlyConnecting {
                    self.startCheckingCallIfNeeded()
                }
            } else if case let .active(callInfo) = internalState, callInfo.scheduleTimestamp != nil {
                let accountContext = self.accountContext
                let peerId = self.peerId
                let rawAdminIds: Signal<Set<PeerId>, NoError>
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    rawAdminIds = Signal { subscriber in
                        let (disposable, _) = accountContext.peerChannelMemberCategoriesContextsManager.admins(postbox: accountContext.account.postbox, network: accountContext.account.network, accountPeerId: accountContext.account.peerId, peerId: peerId, updated: { list in
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
                    rawAdminIds = accountContext.account.postbox.combinedView(keys: [.cachedPeerData(peerId: peerId)])
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
                    accountContext.account.postbox.combinedView(keys: [.basicPeer(peerId)])
                )
                |> map { rawAdminIds, view -> Set<PeerId> in
                    var rawAdminIds = rawAdminIds
                    if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer as? TelegramChannel {
                        if peer.hasPermission(.manageCalls) {
                            rawAdminIds.insert(accountContext.account.peerId)
                        } else {
                            rawAdminIds.remove(accountContext.account.peerId)
                        }
                    }
                    return rawAdminIds
                }
                |> distinctUntilChanged

                let participantsContext = GroupCallParticipantsContext(
                    account: self.accountContext.account,
                    peerId: self.peerId,
                    myPeerId: self.joinAsPeerId,
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    state: GroupCallParticipantsContext.State(
                        participants: [],
                        nextParticipantsFetchOffset: nil,
                        adminIds: Set(),
                        isCreator: false,
                        defaultParticipantsAreMuted: GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: self.stateValue.defaultParticipantMuteState == .muted, canChange: false),
                        sortAscending: true,
                        recordingStartTimestamp: nil,
                        title: self.stateValue.title,
                        scheduleTimestamp: self.stateValue.scheduleTimestamp,
                        subscribedToScheduled: self.stateValue.subscribedToScheduled,
                        totalCount: 0,
                        isVideoEnabled: callInfo.isVideoEnabled,
                        version: 0
                    ),
                    previousServiceState: nil
                )
                self.temporaryParticipantsContext = nil
                self.participantsContext = participantsContext
                
                let myPeerId = self.joinAsPeerId
                let myPeer = self.accountContext.account.postbox.transaction { transaction -> (Peer, CachedPeerData?)? in
                    if let peer = transaction.getPeer(myPeerId) {
                        return (peer, transaction.getPeerCachedData(peerId: myPeerId))
                    } else {
                        return nil
                    }
                }
                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                    participantsContext.state,
                    adminIds,
                    myPeer,
                    accountContext.account.postbox.peerView(id: peerId)
                ).start(next: { [weak self] state, adminIds, myPeerAndCachedData, view in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var members = PresentationGroupCallMembers(
                        participants: [],
                        speakingParticipants: Set(),
                        totalCount: state.totalCount,
                        loadMoreToken: state.nextParticipantsFetchOffset
                    )
                    
                    var participants: [GroupCallParticipantsContext.Participant] = []
                    var topParticipants: [GroupCallParticipantsContext.Participant] = []
                    if let (myPeer, cachedData) = myPeerAndCachedData {
                        let about: String?
                        if let cachedData = cachedData as? CachedUserData {
                            about = cachedData.about
                        } else if let cachedData = cachedData as? CachedChannelData {
                            about = cachedData.about
                        } else {
                            about = nil
                        }
                        participants.append(GroupCallParticipantsContext.Participant(
                            peer: myPeer,
                            ssrc: nil,
                            videoDescription: nil,
                            presentationDescription: nil,
                            joinTimestamp: strongSelf.temporaryJoinTimestamp,
                            raiseHandRating: strongSelf.temporaryRaiseHandRating,
                            hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                            activityTimestamp: strongSelf.temporaryActivityTimestamp,
                            activityRank: strongSelf.temporaryActivityRank,
                            muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                            volume: nil,
                            about: about
                        ))
                    }

                    for participant in participants {
                        members.participants.append(participant)

                        if topParticipants.count < 3 {
                            topParticipants.append(participant)
                        }
                    }
                    
                    strongSelf.membersValue = members
                    
                    var stateValue = strongSelf.stateValue
                    
                    stateValue.adminIds = adminIds
                    stateValue.canManageCall = state.isCreator || adminIds.contains(strongSelf.accountContext.account.peerId)
                    if (state.isCreator || stateValue.adminIds.contains(strongSelf.accountContext.account.peerId)) && state.defaultParticipantsAreMuted.canChange {
                        stateValue.defaultParticipantMuteState = state.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                    }
                    stateValue.recordingStartTimestamp = state.recordingStartTimestamp
                    
                    
                    if let activeCall = (view.cachedData as? CachedGroupData)?.activeCall {
                        stateValue.title = activeCall.title
                    } else if let activeCall = (view.cachedData as? CachedChannelData)?.activeCall {
                        stateValue.title = activeCall.title
                    } else {
                        stateValue.title = state.title
                    }
                    
                    
                    stateValue.scheduleTimestamp = strongSelf.isScheduledStarted ? nil : state.scheduleTimestamp

                    strongSelf.stateValue = stateValue
                    
                    if state.scheduleTimestamp == nil && !strongSelf.isScheduledStarted {
                        strongSelf.updateSessionState(internalState: .active(GroupCallInfo(id: callInfo.id, accessHash: callInfo.accessHash, participantCount: state.totalCount, streamDcId: callInfo.streamDcId, title: state.title, scheduleTimestamp: nil, subscribedToScheduled: false, recordingStartTimestamp: nil, sortAscending: true, defaultParticipantsAreMuted: callInfo.defaultParticipantsAreMuted ?? state.defaultParticipantsAreMuted, isVideoEnabled: callInfo.isVideoEnabled)))
                    } else if !strongSelf.isScheduledStarted {
                        strongSelf.summaryInfoState.set(.single(SummaryInfoState(info: GroupCallInfo(
                            id: callInfo.id,
                            accessHash: callInfo.accessHash,
                            participantCount: state.totalCount,
                            streamDcId: nil,
                            title: state.title,
                            scheduleTimestamp: state.scheduleTimestamp,
                            subscribedToScheduled: state.subscribedToScheduled,
                            recordingStartTimestamp: state.recordingStartTimestamp,
                            sortAscending: state.sortAscending,
                            defaultParticipantsAreMuted: state.defaultParticipantsAreMuted,
                            isVideoEnabled: state.isVideoEnabled
                        ))))
                        
                        strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
                            participantCount: state.totalCount,
                            topParticipants: topParticipants,
                            activeSpeakers: Set()
                        )))
                    }
                }))
            }

        }
    }
        

    private func requestMediaChannelDescriptions(ssrcs: Set<UInt32>, completion: @escaping ([OngoingGroupCallContext.MediaChannelDescription]) -> Void) -> Disposable {
        func extractMediaChannelDescriptions(remainingSsrcs: inout Set<UInt32>, participants: [GroupCallParticipantsContext.Participant], into result: inout [OngoingGroupCallContext.MediaChannelDescription]) {
            for participant in participants {
                guard let audioSsrc = participant.ssrc else {
                    continue
                }

                if remainingSsrcs.contains(audioSsrc) {
                    remainingSsrcs.remove(audioSsrc)

                    result.append(OngoingGroupCallContext.MediaChannelDescription(
                        kind: .audio,
                        audioSsrc: audioSsrc,
                        videoDescription: nil
                    ))
                }
            }
        }

        var remainingSsrcs = ssrcs
        var result: [OngoingGroupCallContext.MediaChannelDescription] = []

        if let membersValue = self.membersValue {
            extractMediaChannelDescriptions(remainingSsrcs: &remainingSsrcs, participants: membersValue.participants, into: &result)
        }

        if !remainingSsrcs.isEmpty, let callInfo = self.internalState.callInfo {
            return (getGroupCallParticipants(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, offset: "", ssrcs: Array(remainingSsrcs), limit: 100, sortAscending: callInfo.sortAscending)
            |> deliverOnMainQueue).start(next: { state in
                extractMediaChannelDescriptions(remainingSsrcs: &remainingSsrcs, participants: state.participants, into: &result)

                completion(result)
            })
        } else {
            completion(result)
            return EmptyDisposable
        }
    }

    
    private func startCheckingCallIfNeeded() {
        if self.checkCallDisposable != nil {
            return
        }
        if case let .established(callInfo, connectionMode, _, ssrc, _) = self.internalState, case .rtc = connectionMode {
            let checkSignal = checkGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, ssrcs: [ssrc])
            
            self.checkCallDisposable = ((
                checkSignal
                |> castError(Bool.self)
                |> delay(4.0, queue: .mainQueue())
                |> mapToSignal { result -> Signal<Bool, Bool> in
                    var foundAll = true
                    for value in [ssrc] {
                        if !result.contains(value) {
                            foundAll = false
                            break
                        }
                    }
                    if foundAll {
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

    private func markAsCanBeRemoved() {
        if self.markedAsCanBeRemoved {
            return
        }
        self.markedAsCanBeRemoved = true

        self.genericCallContext?.stop()
        self.screencastCallContext?.stop()
        self._canBeRemoved.set(.single(true))
        
        if self.didConnectOnce {
        }
    }
    
    func joinAsSpeakerIfNeeded(_ joinHash: String) {
        self.invite = joinHash
        if let muteState = self.stateValue.muteState, !muteState.canUnmute {
            requestCall(movingFromBroadcastToRtc: true)
        }
    }
    func resetListenerLink() {
        self.participantsContext?.resetInviteLinks()
    }
    
    func reconnect(as peerId: PeerId) {
        if peerId == self.joinAsPeerId {
            return
        }
        
        if self.stateValue.scheduleTimestamp != nil {
            updateGroupCallJoinAsDisposable.set(updateGroupCallJoinAsPeer(account: account, peerId: self.peerId, joinAs: peerId).start())
        }
        
        let _ = (self.accountContext.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] myPeer in
            guard let strongSelf = self, let _ = myPeer else {
                return
            }

            strongSelf.reconnectingAsPeer = myPeer
            
            let previousPeerId = strongSelf.joinAsPeerId
            if let localSsrc = strongSelf.currentLocalSsrc {
                strongSelf.ignorePreviousJoinAsPeerId = (previousPeerId, localSsrc)
            }
            strongSelf.joinAsPeerId = peerId
            
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
    
    func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError> {
        self.leaving = true
        if let callInfo = self.internalState.callInfo, let localSsrc = self.currentLocalSsrc {
            if terminateIfPossible {
                self.leaveDisposable.set((stopGroupCall(account: self.account, peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.markAsCanBeRemoved()
                }))
            } else {
                let contexts = self.accountContext.cachedGroupCallContexts
                let account = self.account
                let id = callInfo.id
                let accessHash = callInfo.accessHash
                let source = localSsrc
                contexts.impl.with { impl in
                    impl.leaveInBackground(account: account, id: id, accessHash: accessHash, source: source)
                }
                self.markAsCanBeRemoved()
            }
        } else if let callInfo = self.initialCall, terminateIfPossible {
            self.leaveDisposable.set((stopGroupCall(account: self.account, peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.markAsCanBeRemoved()
            }))
        } else {
            self.markAsCanBeRemoved()
        }
        return self._canBeRemoved.get()
    }
    
    func toggleIsMuted() {
        
        if stateValue.networkState == .connecting || stateValue.scheduleTimestamp != nil {
            return
        }
        
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
            let isVisuallyMuted: Bool
            switch self.isMutedValue {
            case let .muted(isPushToTalkActive):
                isEffectivelyMuted = !isPushToTalkActive
                isVisuallyMuted = true
                let _ = self.updateMuteState(peerId: self.joinAsPeerId, isMuted: true)
            case .unmuted:
                isEffectivelyMuted = false
                isVisuallyMuted = false
                let _ = self.updateMuteState(peerId: self.joinAsPeerId, isMuted: false)
            }
            self.genericCallContext?.setIsMuted(isEffectivelyMuted)
            
            if isVisuallyMuted {
                self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
            } else {
                self.stateValue.muteState = nil
            }
        })
    }
    
    func raiseHand() {
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
    
    func lowerHand() {
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
    
    var mustStopSharing:(()->Void)?
    var mustStopVideo:(()->Void)?
    
    public func requestScreencast(deviceId: String) {
        if self.screencastCallContext != nil {
            return
        }

        let maybeCallInfo: GroupCallInfo? = self.internalState.callInfo

        guard let callInfo = maybeCallInfo else {
            return
        }

        if self.screenCapturer == nil {
            let screenCapturer = OngoingCallVideoCapturer(deviceId)
            self.screenCapturer = screenCapturer
        }
        
        self.screenCapturer?.setOnFatalError({ [weak self] in
            self?.mustStopSharing?()
        })

        let screencastCallContext = OngoingGroupCallContext(
            video: self.screenCapturer,
            requestMediaChannelDescriptions: { _, completion in
                completion([])
                return EmptyDisposable
            },
            audioStreamData: nil,
            rejoinNeeded: {},
            outgoingAudioBitrateKbit: nil,
            videoContentType: .screencast,
            enableNoiseSuppression: false
        )

        self.screencastCallContext = screencastCallContext
        self.hasScreencast = true
        

        self.screencastJoinDisposable.set((screencastCallContext.joinPayload
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.0 != rhs.0 {
                return false
            }
            if lhs.1 != rhs.1 {
                return false
            }
            return true
        })
        |> deliverOnMainQueue).start(next: { [weak self] joinPayload, _ in
            guard let strongSelf = self else {
                return
            }

            strongSelf.requestDisposable.set((joinGroupCallAsScreencast(
                account: strongSelf.account,
                peerId: strongSelf.peerId,
                callId: callInfo.id,
                accessHash: callInfo.accessHash,
                joinPayload: joinPayload
            )
            |> deliverOnMainQueue).start(next: { joinCallResult in
                guard let strongSelf = self, let screencastCallContext = strongSelf.screencastCallContext else {
                    return
                }
                let clientParams = joinCallResult.jsonParams

                screencastCallContext.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false)
                screencastCallContext.setJoinResponse(payload: clientParams)
                
                strongSelf.screencastEndpointId = joinCallResult.endpointId

            }, error: { error in
                guard let _ = self else {
                    return
                }
            }))
        }))
        
    }
    
    public func disableScreencast() {
        self.hasScreencast = false
        
        self.screencastEndpointId = nil
        if let screencastCallContext = self.screencastCallContext {
            self.screencastCallContext = nil
            screencastCallContext.stop()

            let maybeCallInfo: GroupCallInfo? = self.internalState.callInfo

            if let callInfo = maybeCallInfo {
                self.screencastJoinDisposable.set(leaveGroupCallAsScreencast(
                    account: self.account,
                    callId: callInfo.id,
                    accessHash: callInfo.accessHash
                ).start())
            }
        }
        if let _ = self.screenCapturer {
            self.screenCapturer = nil
            self.screencastCallContext?.disableVideo()
        }
    }


    
    public func requestVideo(deviceId: String) {
        if self.videoCapturer == nil {
            let videoCapturer = OngoingCallVideoCapturer(deviceId)
            self.videoCapturer = videoCapturer
        }
        
        self.videoCapturer?.setOnFatalError({ [weak self] in
            self?.mustStopVideo?()
        })
        self.hasVideo = true
        if let videoCapturer = self.videoCapturer {
            self.genericCallContext?.requestVideo(videoCapturer)
            self.participantsContext?.updateVideoState(peerId: self.joinAsPeerId, isVideoMuted: false)
        }
    }
    
    public func disableVideo() {
        self.hasVideo = false
        if let _ = self.videoCapturer {
            self.videoCapturer = nil
            self.genericCallContext?.disableVideo()
            self.participantsContext?.updateVideoState(peerId: self.joinAsPeerId, isVideoMuted: true)
        }
    }


    
    public func setVolume(peerId: PeerId, volume: Int32, sync: Bool) {
        for (ssrc, id) in self.ssrcMapping {
            if id == peerId {
                self.genericCallContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                if sync {
                    self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: volume, raiseHand: nil)
                }
                break
            }
        }
    }

    func setRequestedVideoList(items: [PresentationGroupCallRequestedVideo]) {
        self.genericCallContext?.setRequestedVideoChannels(items.compactMap { item -> OngoingGroupCallContext.VideoChannel in
            let mappedQuality: OngoingGroupCallContext.VideoChannel.Quality
            switch item.quality {
            case .thumbnail:
                mappedQuality = .thumbnail
            case .medium:
                mappedQuality = .medium
            case .full:
                mappedQuality = .full
            }
            return OngoingGroupCallContext.VideoChannel(
                audioSsrc: item.audioSsrc,
                endpointId: item.endpointId,
                ssrcGroups: item.ssrcGroups.map { group in
                    return OngoingGroupCallContext.VideoChannel.SsrcGroup(semantics: group.semantics, ssrcs: group.ssrcs)
                },
                quality: mappedQuality
            )
        })
    }


    
    public func updateMuteState(peerId: PeerId, isMuted: Bool) -> GroupCallParticipantsContext.Participant.MuteState? {
        let canThenUnmute: Bool
        if isMuted {
            var mutedByYou = false
            if peerId == self.joinAsPeerId {
                canThenUnmute = true
            } else if self.stateValue.canManageCall {
                if self.stateValue.adminIds.contains(peerId) {
                    canThenUnmute = true
                } else {
                    canThenUnmute = false
                }
            } else if self.stateValue.adminIds.contains(self.accountContext.account.peerId) {
                canThenUnmute = true
            } else {
                self.setVolume(peerId: peerId, volume: 0, sync: false)
                mutedByYou = true
                canThenUnmute = true
            }
            let muteState = isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: canThenUnmute, mutedByYou: mutedByYou) : nil
            self.participantsContext?.updateMuteState(peerId: peerId, muteState: muteState, volume: nil, raiseHand: nil)
            return muteState
        } else {
            if peerId == self.joinAsPeerId {
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: nil, raiseHand: nil)
                return nil
            } else if self.stateValue.canManageCall || self.stateValue.adminIds.contains(self.accountContext.account.peerId) {
                let muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: muteState, volume: nil, raiseHand: nil)
                return muteState
            } else {
                self.setVolume(peerId: peerId, volume: 10000, sync: true)
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: nil, raiseHand: nil)
                return nil
            }
        }
    }

    func setShouldBeRecording(_ shouldBeRecording: Bool, title: String?) {
        if !self.stateValue.canManageCall {
            return
        }
        if (self.stateValue.recordingStartTimestamp != nil) == shouldBeRecording {
            return
        }
        self.participantsContext?.updateShouldBeRecording(shouldBeRecording, title: title)
    }
    
    private func requestCall(movingFromBroadcastToRtc: Bool) {
        self.currentConnectionMode = .none
        self.genericCallContext?.setConnectionMode(.none, keepBroadcastConnectedIfWasEnabled: movingFromBroadcastToRtc)
                
        self.internalState = .requesting
        self.internalStatePromise.set(.single(.requesting))
        self.isCurrentlyConnecting = nil
        
        enum CallError {
            case generic
        }
        
        let account = self.account
        
        let currentCall: Signal<GroupCallInfo?, CallError>
        if let initialCall = self.initialCall {
            currentCall = getCurrentGroupCall(account: account, callId: initialCall.id, accessHash: initialCall.accessHash, peerId: peerId)
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
        self.joinDisposable.set(nil)
        
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
                strongSelf.initialCall = CachedChannelData.ActiveCall(id: value.id, accessHash: value.accessHash, title: value.title, scheduleTimestamp: value.scheduleTimestamp, subscribedToScheduled: value.subscribedToScheduled)
                strongSelf.updateSessionState(internalState: .active(value))
            } else {
                strongSelf.markAsCanBeRemoved()
            }
        }))
    }
    
    func invitePeer(_ peerId: PeerId) -> Bool {
        guard case let .established(callInfo, _, _, _, _) = self.internalState, !self.invitedPeersValue.contains(peerId) else {
            return false
        }
        if let channel = self.peer as? TelegramChannel {
            if channel.isChannel {
                return false
            }
        }
        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.insert(peerId, at: 0)
        self.invitedPeersValue = updatedInvitedPeers
        
        let _ = inviteToGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, peerId: peerId).start()
        
        return true
    }
    
    func removedPeer(_ peerId: PeerId) {
        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.removeAll(where: { $0 == peerId})
        self.invitedPeersValue = updatedInvitedPeers
    }
    
    func updateTitle(_ title: String, force: Bool) {
        guard let callInfo = self.internalState.callInfo else {
            return
        }
        self.stateValue.title = title.isEmpty ? nil : title

        var signal = editGroupCallTitle(account: account, callId: callInfo.id, accessHash: callInfo.accessHash, title: title)
        if !force {
            signal = signal |> delay(0.2, queue: .mainQueue())
        }
        updateTitleDisposable.set(signal.start())
    }
    
    var inviteLinks: Signal<GroupCallInviteLinks?, NoError> {
        let account = self.account
        let internalStatePromise = self.internalStatePromise
        return self.state  |> take(1)
        |> map { state -> PeerId in
            return state.myPeerId
        }
        |> distinctUntilChanged
        |> mapToSignal { _ -> Signal<GroupCallInviteLinks?, NoError> in
            return internalStatePromise.get()
            |> filter { state -> Bool in
                if case .requesting = state {
                    return false
                } else {
                    return true
                }
            } |> take(1)
            |> mapToSignal { state in
                if let callInfo =  state.callInfo {
                    return groupCallInviteLinks(account: account, callId: callInfo.id, accessHash: callInfo.accessHash)
                } else {
                    return .complete()
                }
            }
        }
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
                    strongSelf.typingDisposable.set(strongSelf.accountContext.account.acquireLocalInputActivity(peerId: PeerActivitySpace(peerId: strongSelf.peerId, category: .voiceChat), activity: .speakingInGroupCall(timestamp: 0)))
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
    }
    
    func switchVideoInput(_ deviceId: String) {
        videoCapturer?.switchVideoInput(deviceId)
    }

    func makeVideoView(endpointId: String, videoMode: GroupCallVideoMode, completion: @escaping (PresentationCallVideoView?) -> Void) {
        let context: OngoingGroupCallContext?
        switch videoMode {
        case .video:
            context = self.genericCallContext
        case .screencast:
            context = self.screencastCallContext
        }
        context?.makeIncomingVideoView(endpointId: endpointId, requestClone: false, completion: { view, _ in
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
                    }, setVideoContentMode: { [weak view] mode in
                        view?.setVideoContentMode(mode)
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

    func loadMore() {
        if let token = self.membersValue?.loadMoreToken {
            self.participantsContext?.loadMore(token: token)
        }
    }
    public func startScheduled() {
        guard case let .active(callInfo) = self.internalState else {
            return
        }
        self.isScheduledStarted = true
        self.stateValue.scheduleTimestamp = nil
        
        self.startDisposable.set((startScheduledGroupCall(account: self.account, peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
        |> deliverOnMainQueue).start(next: { [weak self] callInfo in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateSessionState(internalState: .active(callInfo))
        }))
    }
        
    public func toggleScheduledSubscription(_ subscribe: Bool) {
        guard case let .active(callInfo) = self.internalState, callInfo.scheduleTimestamp != nil else {
            return
        }
        
        self.stateValue.subscribedToScheduled = subscribe
        
        self.subscribeDisposable.set((toggleScheduledGroupCallSubscription(account: self.account, peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash, subscribe: subscribe)
        |> deliverOnMainQueue).start())
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
                let call: CachedChannelData.ActiveCall?
                if let info = initialInfo {
                    call = .init(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled)
                } else {
                    call = initialCall
                }
                return .success(startGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: call, initialInfo: initialInfo, joinHash: joinHash, peer: peer))
            }
        }
    }

}


private func startGroupCall(context: AccountContext, peerId: PeerId, joinAs: PeerId, initialCall: CachedChannelData.ActiveCall?, initialInfo: GroupCallInfo? = nil, internalId: CallSessionInternalId = CallSessionInternalId(), joinHash: String? = nil, peer: Peer? = nil) -> GroupCallContext {
    
    
    
    return GroupCallContext(call: PresentationGroupCallImpl(accountContext: context, initialCall: initialCall, internalId: internalId, peerId: peerId, invite: joinHash, joinAsPeerId: joinAs, initialInfo: initialInfo), peerMemberContextsManager: context.peerChannelMemberCategoriesContextsManager)
}

func createVoiceChat(context: AccountContext, peerId: PeerId, displayAsList: [FoundPeer]? = nil, canBeScheduled: Bool = false) {
    let confirmation = makeNewCallConfirmation(account: context.account, sharedContext: context.sharedContext, newPeerId: peerId, newCallType: .voiceChat) |> mapToSignalPromotingError { _ in
        return Signal<(GroupCallInfo?, PeerId), CreateGroupCallError> { subscriber in

            let disposable = MetaDisposable()

            let create:(PeerId, Date?)->Void = { joinAs, schedule in
                let scheduleDate: Int32?
                if let timeInterval = schedule?.timeIntervalSince1970 {
                    scheduleDate = Int32(timeInterval)
                } else {
                    scheduleDate = nil
                }
                disposable.set(createGroupCall(account: context.account, peerId: peerId, title: nil, scheduleDate: scheduleDate).start(next: { info in
                    subscriber.putNext((info, joinAs))
                    subscriber.putCompletion()
                }, error: { error in
                    subscriber.putError(error)
                }))
            }
            if let displayAsList = displayAsList {
                if !displayAsList.isEmpty || canBeScheduled {
                    showModal(with: GroupCallDisplayAsController(context: context, mode: .create, peerId: peerId, list: displayAsList, completion: create, canBeScheduled: canBeScheduled), for: context.window)
                } else {
                    create(context.peerId, nil)
                }
            } else {
                selectGroupCallJoiner(context: context, peerId: peerId, completion: create, canBeScheduled: canBeScheduled)
            }

            return ActionDisposable {
                disposable.dispose()
            }
        } |> runOn(.mainQueue())
    }

    let requestCall: Signal<RequestOrJoinGroupCallResult, CreateGroupCallError> = confirmation |> mapToSignal { call, joinAs in
        
        let initialCall: CachedChannelData.ActiveCall?
        if let call = call {
            initialCall = .init(id: call.id, accessHash: call.accessHash, title: call.title, scheduleTimestamp: call.scheduleTimestamp, subscribedToScheduled: call.subscribedToScheduled)
        } else {
            initialCall = nil
        }
        
        return showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: initialCall) |> mapError { _ in .generic }, for: context.window)
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
