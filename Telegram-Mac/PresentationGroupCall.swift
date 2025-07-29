import Cocoa
import Postbox
import TelegramCore
import InAppSettings
import SwiftSignalKit
import AVFoundation
import TelegramVoip
import TGUIKit
import TelegramMedia
import TgVoipWebrtc
import TdBinding



private enum CurrentImpl {
    case call(OngoingGroupCallContext)
    case externalMediaStream(DirectMediaStreamingContext)
}

private extension CurrentImpl {
    var joinPayload: Signal<(String, UInt32), NoError> {
        switch self {
        case let .call(callContext):
            return callContext.joinPayload
        case .externalMediaStream:
            let ssrcId = UInt32.random(in: 0 ..< UInt32(Int32.max - 1))
            let dict: [String: Any] = [
                "fingerprints": [] as [Any],
                "ufrag": "",
                "pwd": "",
                "ssrc": Int32(bitPattern: ssrcId),
                "ssrc-groups": [] as [Any]
            ]
            guard let jsonString = (try? JSONSerialization.data(withJSONObject: dict, options: [])).flatMap({ String(data: $0, encoding: .utf8) }) else {
                return .never()
            }
            return .single((jsonString, ssrcId))
        }
    }
    
    var networkState: Signal<OngoingGroupCallContext.NetworkState, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.networkState
        case .externalMediaStream:
            return .single(OngoingGroupCallContext.NetworkState(isConnected: true, isTransitioningFromBroadcastToRtc: false))
        }
    }
    
    var audioLevels: Signal<[(OngoingGroupCallContext.AudioLevelKey, Float, Bool)], NoError> {
        switch self {
        case let .call(callContext):
            return callContext.audioLevels
        case .externalMediaStream:
            return .single([])
        }
    }
    
    var isMuted: Signal<Bool, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.isMuted
        case .externalMediaStream:
            return .single(true)
        }
    }

    var isNoiseSuppressionEnabled: Signal<Bool, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.isNoiseSuppressionEnabled
        case .externalMediaStream:
            return .single(false)
        }
    }
    
    func stop(account: Account, reportCallId: CallId?, debugLog: Promise<String?>) {
        switch self {
        case let .call(callContext):
            callContext.stop(account: account, reportCallId: reportCallId, debugLog: debugLog)
        case .externalMediaStream:
            debugLog.set(.single(nil))
        }
    }
    
    func setIsMuted(_ isMuted: Bool) {
        switch self {
        case let .call(callContext):
            callContext.setIsMuted(isMuted)
        case .externalMediaStream:
            break
        }
    }

    func setIsNoiseSuppressionEnabled(_ isNoiseSuppressionEnabled: Bool) {
        switch self {
        case let .call(callContext):
            callContext.setIsNoiseSuppressionEnabled(isNoiseSuppressionEnabled)
        case .externalMediaStream:
            break
        }
    }
    
    func requestVideo(_ capturer: OngoingCallVideoCapturer?) {
        switch self {
        case let .call(callContext):
            callContext.requestVideo(capturer)
        case .externalMediaStream:
            break
        }
    }
    
    func disableVideo() {
        switch self {
        case let .call(callContext):
            callContext.disableVideo()
        case .externalMediaStream:
            break
        }
    }
    
    func setVolume(ssrc: UInt32, volume: Double) {
        switch self {
        case let .call(callContext):
            callContext.setVolume(ssrc: ssrc, volume: volume)
        case .externalMediaStream:
            break
        }
    }

    func setRequestedVideoChannels(_ channels: [OngoingGroupCallContext.VideoChannel]) {
        switch self {
        case let .call(callContext):
            callContext.setRequestedVideoChannels(channels)
        case .externalMediaStream:
            break
        }
    }

    func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.video(endpointId: endpointId)
        case .externalMediaStream:
            return .never()
        }
    }

    func addExternalAudioData(data: Data) {
        switch self {
        case let .call(callContext):
            callContext.addExternalAudioData(data: data)
        case .externalMediaStream:
            break
        }
    }

    func getStats(completion: @escaping (OngoingGroupCallContext.Stats) -> Void) {
        switch self {
        case let .call(callContext):
            callContext.getStats(completion: completion)
        case .externalMediaStream:
            break
        }
    }
    
    func setTone(tone: OngoingGroupCallContext.Tone?) {
        switch self {
        case let .call(callContext):
            callContext.setTone(tone: tone)
        case .externalMediaStream:
            break
        }
    }
}


private final class ConferenceCallE2EContextStateImpl: ConferenceCallE2EContextState {
    private let call: TdCall

    init(call: TdCall) {
        self.call = call
    }

    func getEmojiState() -> Data? {
        return self.call.emojiState()
    }
    
    func getParticipantLatencies() -> [Int64: Double] {
        let dict = self.call.participantLatencies()
        var result: [Int64: Double] = [:]
        for (k, v) in dict {
            result[k.int64Value] = v.doubleValue
        }
        return result
    }
    
    func getParticipants() -> [ConferenceCallE2EContext.BlockchainParticipant] {
        return self.call.participants().map { ConferenceCallE2EContext.BlockchainParticipant(userId: $0.userId, internalId: $0.internalId) }
    }

    func getParticipantIds() -> [Int64] {
        return self.call.participants().map { $0.userId }
    }

    func applyBlock(block: Data) -> Bool {
        return self.call.applyBlock(block)
    }

    func applyBroadcastBlock(block: Data) {
        self.call.applyBroadcastBlock(block)
    }

    func generateRemoveParticipantsBlock(participantIds: [Int64]) -> Data? {
        return self.call.generateRemoveParticipantsBlock(participantIds.map { $0 as NSNumber })
    }

    func takeOutgoingBroadcastBlocks() -> [Data] {
        return self.call.takeOutgoingBroadcastBlocks()
    }

    func encrypt(message: Data, channelId: Int32, plaintextPrefixLength: Int) -> Data? {
        return self.call.encrypt(message, channelId: channelId, plaintextPrefixLength: plaintextPrefixLength)
    }


    func decrypt(message: Data, userId: Int64) -> Data? {
        return self.call.decrypt(message, userId: userId)
    }
}

class OngoingGroupCallEncryptionContextImpl: OngoingGroupCallEncryptionContext {
    private let e2eCall: Atomic<ConferenceCallE2EContext.ContextStateHolder>
    private let channelId: Int32
    
    init(e2eCall: Atomic<ConferenceCallE2EContext.ContextStateHolder>, channelId: Int32) {
        self.e2eCall = e2eCall
        self.channelId = channelId
    }
    
    func encrypt(message: Data, plaintextPrefixLength: Int) -> Data? {
        let channelId = self.channelId
        return self.e2eCall.with({ $0.state?.encrypt(message: message, channelId: channelId, plaintextPrefixLength: plaintextPrefixLength) })
    }

    
    func decrypt(message: Data, userId: Int64) -> Data? {
        return self.e2eCall.with({ $0.state?.decrypt(message: message, userId: userId) })
    }
}




public final class TelegramE2EEncryptionProviderImpl: TelegramE2EEncryptionProvider {
    public static let shared = TelegramE2EEncryptionProviderImpl()
    
    public func generateKeyPair() -> TelegramKeyPair? {
        guard let keyPair = TdKeyPair.generate() else {
            return nil
        }
        guard let publicKey = TelegramPublicKey(data: keyPair.publicKey) else {
            return nil
        }
        return TelegramKeyPair(id: keyPair.keyId, publicKey: publicKey)
    }
    
    public func generateCallZeroBlock(keyPair: TelegramKeyPair, userId: Int64) -> Data? {
        guard let keyPair = TdKeyPair(keyId: keyPair.id, publicKey: keyPair.publicKey.data) else {
            return nil
        }
        return tdGenerateZeroBlock(keyPair, userId)
    }
}



func groupCallLogsPath(account: Account) -> String {
    return account.basePath + "/group-calls"
}

private func cleanupGroupCallLogs(account: Account) {
    let path = groupCallLogsPath(account: account)
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path, isDirectory: nil) {
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    var oldest: [(URL, Date)] = []
    var count = 0
    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
        for url in enumerator {
            if let url = url as? URL {
                if let date = (try? url.resourceValues(forKeys: Set([.contentModificationDateKey])))?.contentModificationDate {
                    oldest.append((url, date))
                    count += 1
                }
            }
        }
    }
    let callLogsLimit = 20
    if count > callLogsLimit {
        oldest.sort(by: { $0.1 > $1.1 })
        while oldest.count > callLogsLimit {
            try? fileManager.removeItem(atPath: oldest[oldest.count - 1].0.path)
            oldest.removeLast()
        }
    }
}

func allocateCallLogPath(account: Account) -> String {
    let path = groupCallLogsPath(account: account)
    
    let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true, attributes: nil)
    
    let name = "log-\(Date())".replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    
    return "\(path)/\(name).log"
}


private final class PendingConferenceInvitationContext {
    enum State {
        case ringing
    }
    
    private let engine: TelegramEngine
    private var requestDisposable: Disposable?
    private var stateDisposable: Disposable?
    private(set) var messageId: EngineMessage.Id?
    
    private var hadMessage: Bool = false
    private var didNotifyEnded: Bool = false
    
    init(engine: TelegramEngine, reference: InternalGroupCallReference, peerId: PeerId, isVideo: Bool, onStateUpdated: @escaping (State) -> Void, onEnded: @escaping (Bool) -> Void) {
        self.engine = engine
        self.requestDisposable = (engine.calls.inviteConferenceCallParticipant(reference: reference, peerId: peerId, isVideo: isVideo).startStrict(next: { [weak self] messageId in
            guard let self else {
                return
            }

            self.messageId = messageId
            
            onStateUpdated(.ringing)
            
            let timeout: Double = 30.0
            let timerSignal = Signal<Void, NoError>.single(Void()) |> then(
                Signal<Void, NoError>.single(Void())
                |> delay(1.0, queue: .mainQueue())
            ) |> restart
            
            let startTime = CFAbsoluteTimeGetCurrent()
            self.stateDisposable = (combineLatest(queue: .mainQueue(),
                engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Messages.Message(id: messageId)
                ),
                timerSignal
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] message, _ in
                guard let self else {
                    return
                }
                if let message {
                    self.hadMessage = true
                    if message.timestamp + Int32(timeout) <= Int32(Date().timeIntervalSince1970) {
                        if !self.didNotifyEnded {
                            self.didNotifyEnded = true
                            onEnded(false)
                        }
                    } else {
                        var isActive = false
                        var isAccepted = false
                        var foundAction: TelegramMediaAction?
                        for media in message.media {
                            if let action = media as? TelegramMediaAction {
                                foundAction = action
                                break
                            }
                        }
                        
                        if let action = foundAction, case let .conferenceCall(conferenceCall) = action.action {
                            if conferenceCall.flags.contains(.isMissed) || conferenceCall.duration != nil {
                            } else {
                                if conferenceCall.flags.contains(.isActive) {
                                    isAccepted = true
                                } else {
                                    isActive = true
                                }
                            }
                        }
                        if !isActive {
                            if !self.didNotifyEnded {
                                self.didNotifyEnded = true
                                onEnded(isAccepted)
                            }
                        }
                    }
                } else {
                    if self.hadMessage || CFAbsoluteTimeGetCurrent() > startTime + 1.0 {
                        if !self.didNotifyEnded {
                            self.didNotifyEnded = true
                            onEnded(false)
                        }
                    }
                }
            })
        }))
    }
    
    deinit {
        self.requestDisposable?.dispose()
        self.stateDisposable?.dispose()
    }
}



func getGroupCallPanelData(context: AccountContext, peerId: PeerId) -> Signal<GroupCallPanelData?, NoError> {
    let account = context.account
    let availableGroupCall: Signal<GroupCallPanelData?, NoError>
    if peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
        availableGroupCall = context.account.viewTracker.peerView(peerId)
                        |> map { peerView -> (CachedChannelData.ActiveCall?, Bool) in
                            if let cachedData = peerView.cachedData as? CachedChannelData {
                                return (cachedData.activeCall, peerViewMainPeer(peerView)?.isChannel == true)
                            }
                            if let cachedData = peerView.cachedData as? CachedGroupData {
                                return (cachedData.activeCall, false)
                            }
                            return (nil, false)
                        } |> mapToSignal { (activeCall, isChannel) -> Signal<GroupCallPanelData?, NoError> in
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
                                                        isChannel: isChannel,
                                                        info: summary.info,
                                                        topParticipants: summary.topParticipants,
                                                        participantCount: summary.participantCount,
                                                        activeSpeakers: summary.activeSpeakers,
                                                        groupCall: context
                                                    )
                                                } else {
                                                    return GroupCallPanelData(peerId: peerId, isChannel: isChannel, info: nil, topParticipants: [], participantCount: 0, activeSpeakers: [], groupCall: context)
                                                }
                                            }
                                    } else {
                                        return Signal { subscriber in
                                            let disposable = MetaDisposable()
                                            let callContext = context.cachedGroupCallContexts
                                            callContext.impl.syncWith { impl in
                                                let callContext = impl.get(account: context.account, engine: context.engine, peerId: peerId, isChannel: isChannel, call: .init(activeCall), isMuted: true, e2eContext: nil)
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

protocol AccountGroupCallContext {
}

protocol AccountGroupCallContextCache {
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
        
        public func keep() {
        }
    }
    
    var disposable: Disposable?
    var participantsContext: GroupCallParticipantsContext?
    
    private let panelDataPromise = Promise<GroupCallPanelData?>()
    var panelData: Signal<GroupCallPanelData?, NoError> {
        return self.panelDataPromise.get()
    }
    
    public init(account: Account, engine: TelegramEngine, peerId: PeerId?, isChannel: Bool, call: EngineGroupCallDescription, isMuted: Bool, e2eContext: ConferenceCallE2EContext?) {
        self.panelDataPromise.set(.single(nil))
        let state = engine.calls.getGroupCallParticipants(reference: .id(id: call.id, accessHash: call.accessHash), offset: "", ssrcs: [], limit: 100, sortAscending: nil)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<GroupCallParticipantsContext.State?, NoError> in
            return .single(nil)
        }
        
        let peer: Signal<EnginePeer?, NoError>
        if let peerId {
            peer = engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        } else {
            peer = .single(nil)
        }
        self.disposable = (combineLatest(queue: .mainQueue(),
            state,
            peer
        )
        |> deliverOnMainQueue).start(next: { [weak self] state, peer in
            guard let self, let state = state else {
                return
            }
            let context = engine.calls.groupCall(
                peerId: peerId,
                myPeerId: account.peerId,
                id: call.id,
                reference: .id(id: call.id, accessHash: call.accessHash),
                state: state,
                previousServiceState: nil,
                e2eContext: e2eContext
            )
            
            self.participantsContext = context
            
            if !isMuted {
                self.participantsContext?.updateMuteState(peerId: account.peerId, muteState: nil, volume: nil, raiseHand: nil)
            }
            
            
            if let peerId {
                self.panelDataPromise.set(combineLatest(queue: .mainQueue(),
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
                    
                    var isChannel = false
                    if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                        isChannel = true
                    }
                    
                    return GroupCallPanelData(
                        peerId: peerId,
                        isChannel: isChannel,
                        info: GroupCallInfo(
                            id: call.id,
                            accessHash: call.accessHash,
                            participantCount: state.totalCount,
                            streamDcId: nil,
                            title: state.title,
                            scheduleTimestamp: state.scheduleTimestamp,
                            subscribedToScheduled: state.subscribedToScheduled,
                            recordingStartTimestamp: nil,
                            sortAscending: state.sortAscending,
                            defaultParticipantsAreMuted: state.defaultParticipantsAreMuted,
                            isVideoEnabled: state.isVideoEnabled,
                            unmutedVideoLimit: state.unmutedVideoLimit,
                            isStream: state.isStream,
                            isCreator: state.isCreator
                        ),
                        topParticipants: topParticipants,
                        participantCount: state.totalCount,
                        activeSpeakers: activeSpeakers,
                        groupCall: nil
                    )
                })
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
}


public final class AccountGroupCallContextCacheImpl: AccountGroupCallContextCache {
    public class Impl {
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
        
        func get(account: Account, engine: TelegramEngine, peerId: PeerId, isChannel: Bool, call: EngineGroupCallDescription, isMuted: Bool, e2eContext: ConferenceCallE2EContext?) -> AccountGroupCallContextImpl.Proxy {
            let result: Record
            if let current = self.contexts[call.id] {
                result = current
            } else {
                let context = AccountGroupCallContextImpl(account: account, engine: engine, peerId: peerId, isChannel: isChannel, call: call, isMuted: isMuted, e2eContext: e2eContext)
                result = Record(context: context)
                self.contexts[call.id] = result
            }
            
            let index = result.subscribers.add(Void())
            result.removeTimer?.invalidate()
            result.removeTimer = nil
            return AccountGroupCallContextImpl.Proxy(context: result.context, removed: { [weak self, weak result] in
                Queue.mainQueue().async {
                    if let strongResult = result, let self, self.contexts[call.id] === strongResult {
                        strongResult.subscribers.remove(index)
                        if strongResult.subscribers.isEmpty {
                            let removeTimer = SwiftSignalKit.Timer(timeout: 30, repeat: false, completion: { [weak self] in
                                if let result = result, let self, self.contexts[call.id] === result, result.subscribers.isEmpty {
                                    self.contexts.removeValue(forKey: call.id)
                                }
                            }, queue: .mainQueue())
                            strongResult.removeTimer = removeTimer
                            removeTimer.start()
                        }
                    }
                }
            })
        }

        public func leaveInBackground(engine: TelegramEngine, id: Int64, accessHash: Int64, source: UInt32) {
            let disposable = engine.calls.leaveGroupCall(callId: id, accessHash: accessHash, source: source).start(completed: { [weak self] in
                guard let self else {
                    return
                }
                if let context = self.contexts[id] {
                    context.context.participantsContext?.removeLocalPeerId()
                }
            })
            self.leaveDisposables.add(disposable)
        }
    }
    
    let queue: Queue = .mainQueue()
    public let impl: QueueLocalObject<Impl>
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
}



private extension PresentationGroupCallState {
    static func initialValue(myPeerId: PeerId, title: String?, scheduledTimestamp: Int32?, subscribedToScheduled: Bool, isStream: Bool, isChannel: Bool, isConference: Bool, isMuted: Bool) -> PresentationGroupCallState {
        return PresentationGroupCallState(
            myPeerId: myPeerId,
            networkState: .connecting,
            canManageCall: false,
            adminIds: Set(),
            muteState: isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false) : nil,
            defaultParticipantMuteState: nil,
            recordingStartTimestamp: nil,
            title: title,
            raisedHand: false,
            scheduleTimestamp: scheduledTimestamp,
            subscribedToScheduled: subscribedToScheduled,
            isVideoEnabled: false,
            isStream: isStream,
            isChannel: isChannel,
            isConference: isConference
        )
    }
}

struct GroupCallInitialOutput {
    struct Video {
        var capturer: OngoingCallVideoCapturer
        var source: VideoSourceMac
    }
    var isMuted: Bool
    var video: Video?
    var screencast: Video?
}

final class PresentationGroupCallImpl: PresentationGroupCall {

    var isStream = false
    
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
    
    private var initialCall: (description: EngineGroupCallDescription, reference: InternalGroupCallReference)?
    let internalId: CallSessionInternalId
    let peerId: PeerId?
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
    
    public private(set) var callId: Int64?
    
    public private(set) var hasVideo: Bool
    public private(set) var hasScreencast: Bool

    public var e2eEncryptionKeyHash: Signal<Data?, NoError> {
        return self.e2eContext?.e2eEncryptionKeyHash ?? .single(nil)
    }
        
    private let updateTitleDisposable = MetaDisposable()
    
    private var temporaryJoinTimestamp: Int32
    private var temporaryActivityTimestamp: Double?
    private var temporaryActivityRank: Int?
    private var temporaryRaiseHandRating: Int64?
    private var temporaryHasRaiseHand: Bool = false
    private var temporaryVideoJoined: Bool = true
    private var temporaryMuteState: GroupCallParticipantsContext.Participant.MuteState?
    
    private var internalState: InternalState = .requesting
    private let internalStatePromise = Promise<InternalState>(.requesting)
    private var currentLocalSsrc: UInt32?
    
    private var genericCallContext: OngoingGroupCallContext?
    private var currentConnectionMode: OngoingGroupCallContext.ConnectionMode = .none
    private var screencastCallContext: OngoingGroupCallContext?
    
    private struct SsrcMapping {
            var peerId: PeerId
            var isPresentation: Bool
        }
        private var ssrcMapping: [UInt32: SsrcMapping] = [:]

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
                var bp = 0
                bp += 1
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
    
    private var checkIndex = 0
    
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
    
    private var invitedPeersValue: [PresentationGroupCallInvitedPeer] = [] {
        didSet {
            if self.invitedPeersValue != oldValue {
                self.inivitedPeersPromise.set(self.invitedPeersValue)
            }
        }
    }
    private let inivitedPeersPromise = ValuePromise<[PresentationGroupCallInvitedPeer]>([])
    var invitedPeers: Signal<[PresentationGroupCallInvitedPeer], NoError> {
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
        
    private var removedChannelMembersDisposable: Disposable?
    
    private var didStartConnectingOnce: Bool = false
    private var didConnectOnce: Bool = false
    
    private var videoCapturer: OngoingCallVideoCapturer?
    
    private let initialOutput: GroupCallInitialOutput
    
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

    private let isSpeakingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
        public var isSpeaking: Signal<Bool, NoError> {
            return self.isSpeakingPromise.get()
        }


    private var peerUpdatesSubscription: Disposable?
    
    private let keyPair: TelegramKeyPair?
    let isConference: Bool
    
    private let conferenceSourceId: CallSessionInternalId?
    public var conferenceSource: CallSessionInternalId? {
        return self.conferenceSourceId
    }
    
    public var upgradedConferenceCall: PCallSession?
    public var pendingDisconnedUpgradedConferenceCall: PCallSession?
    private var pendingDisconnedUpgradedConferenceCallTimer: Foundation.Timer?
    private var conferenceInvitationContexts: [PeerId: PendingConferenceInvitationContext] = [:]

    private let e2eContext: ConferenceCallE2EContext?

    
    init(
        accountContext: AccountContext,
        initialCall: (description: EngineGroupCallDescription, reference: InternalGroupCallReference)?,
        internalId: CallSessionInternalId,
        peerId: PeerId?,
        isChannel: Bool,
        invite: String?,
        joinAsPeerId: PeerId?,
        initialInfo: GroupCallInfo?,
        isStream: Bool,
        keyPair: TelegramKeyPair?,
        conferenceSourceId: CallSessionInternalId?,
        isConference: Bool,
        initialOutput: GroupCallInitialOutput
    ) {
        self.account = accountContext.account
        self.accountContext = accountContext
        
        self.initialOutput = initialOutput
        self.initialCall = initialCall
        self.internalId = internalId
        self.peerId = peerId
        self.invite = invite
        self.conferenceSourceId = conferenceSourceId
        self.isStream = isStream
        self.joinAsPeerId = joinAsPeerId ?? accountContext.account.peerId
        self.joinAsPeerIdSignal.set(self.joinAsPeerId)
        self.isConference = isConference
        self.keyPair = keyPair
        
        if let keyPair, let initialCall {
            self.e2eContext = ConferenceCallE2EContext(
                engine: accountContext.engine,
                callId: initialCall.description.id,
                accessHash: initialCall.description.accessHash,
                userId: accountContext.account.peerId.id._internalGetInt64Value(),
                reference: initialCall.reference,
                keyPair: keyPair,
                initializeState: { keyPair, userId, block in
                    guard let keyPair = TdKeyPair(keyId: keyPair.id, publicKey: keyPair.publicKey.data) else {
                        return nil
                    }
                    guard let call = TdCall.make(with: keyPair, userId: userId, latestBlock: block) else {
                        return nil
                    }
                    return ConferenceCallE2EContextStateImpl(call: call)
                }

            )
        } else {
            self.e2eContext = nil
        }

        //        self.stateValue = PresentationGroupCallState.initialValue(myPeerId: self.joinAsPeerId, title: initialCall?.description.title, scheduleTimestamp: initialCall?.description.scheduleTimestamp, subscribedToScheduled: initialCall?.description.subscribedToScheduled ?? false)
        


        self.stateValue = PresentationGroupCallState.initialValue(myPeerId: self.joinAsPeerId, title: initialCall?.description.title, scheduledTimestamp: initialCall?.description.scheduleTimestamp, subscribedToScheduled: initialCall?.description.subscribedToScheduled ?? false, isStream: self.isStream, isChannel: isChannel, isConference: isConference, isMuted: self.initialOutput.isMuted)
        self.statePromise = ValuePromise(self.stateValue)
        
        self.temporaryJoinTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        self.hasVideo = false
        self.hasScreencast = false

        self.devicesContext = accountContext.sharedContext.devicesContext
        
        struct DevicesData: Equatable {
            let networkState: PresentationGroupCallState.NetworkState
            let input: String?
            let output: String?
            let sampleUpdateIndex: Int?
        }
        let signal: Signal<DevicesData, NoError> = combineLatest(queue: .mainQueue(), devicesContext.updater(), state) |> map { devices, state in
            return .init(networkState: state.networkState, input: devices.input, output: devices.output, sampleUpdateIndex: devices.sampleUpdateIndex)
        } |> filter { $0.networkState == .connected } |> distinctUntilChanged

        devicesDisposable.set(signal.start(next: { [weak self] data in
            guard let `self` = self else {
                return
            }
            if let id = data.input {
                self.genericCallContext?.switchAudioInput(id)
            }
            if let id = data.output {
                self.genericCallContext?.switchAudioOutput(id)
            }
        }))
        
        if let peerId {
            let peerSignal = account.postbox.peerView(id: peerId)
                |> map { peerViewMainPeer($0) }
            |> deliverOnMainQueue
            
            self.loadPeerDisposable.set(peerSignal.start(next: { [weak self] peer in
                self?.peer = peer
            }))
        }
        
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
                                    } else {
                                        strongSelf.e2eContext?.synchronizeRemovedParticipants()
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
                        case let .call(isTerminated, _, _, _, _, _, _):
                            if isTerminated {
                                strongSelf.markAsCanBeRemoved()
                            }
                        case let .conferenceChainBlocks(subChainId, blocks, nextOffset):
                            if let e2eContext = strongSelf.e2eContext {
                                e2eContext.addChainBlocksUpdate(subChainId: subChainId, blocks: blocks, nextOffset: nextOffset)
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
        
        
        if let peerId {
            self.displayAsPeersValue.set(accountContext.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId) |> map(Optional.init))
        }

        
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
        
        if let initialCall = initialCall, let peerId {
            let temporaryParticipantsContext = self.accountContext.cachedGroupCallContexts.impl.syncWith({ impl in
                impl.get(account: accountContext.account, engine: accountContext.engine, peerId: peerId, isChannel: isChannel, call: EngineGroupCallDescription(id: initialCall.description.id, accessHash: initialCall.description.accessHash, title: initialCall.description.title, scheduleTimestamp: initialCall.description.scheduleTimestamp, subscribedToScheduled: initialCall.description.subscribedToScheduled, isStream: initialCall.description.isStream), isMuted: initialOutput.isMuted, e2eContext: self.e2eContext)
            })
            self.switchToTemporaryParticipantsContext(sourceContext: temporaryParticipantsContext.context.participantsContext, oldMyPeerId: self.joinAsPeerId)
        } else {
            self.switchToTemporaryParticipantsContext(sourceContext: nil, oldMyPeerId: self.joinAsPeerId)
        }
        
        if let peerId {
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
        }
       
        
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
            let temporaryParticipantsContext = self.accountContext.engine.calls.groupCall(peerId: self.peerId, myPeerId: myPeerId, id: sourceContext.id, reference: sourceContext.reference, state: initialState, previousServiceState: sourceContext.serviceState, e2eContext: self.e2eContext)
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
                        if participants[i].id == .peer(oldMyPeerId) {
                            participants.remove(at: i)
                            break
                        }
                    }
                }

                if !participants.contains(where: { $0.id == .peer(myPeerId) }) {
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
                            id: .peer(myPeerId),
                            peer: .init(myPeer),
                            ssrc: nil,
                            videoDescription: nil,
                            presentationDescription: nil,
                            joinTimestamp: strongSelf.temporaryJoinTimestamp,
                            raiseHandRating: strongSelf.temporaryRaiseHandRating,
                            hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                            activityTimestamp: strongSelf.temporaryActivityTimestamp,
                            activityRank: strongSelf.temporaryActivityRank,
                            muteState: strongSelf.temporaryMuteState ?? (strongSelf.initialOutput.isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false) : nil),
                            volume: nil,
                            about: about,
                            joinedVideo: strongSelf.temporaryVideoJoined
                        ))
                        participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                    }
                }

                for participant in participants {
                    members.participants.append(participant)

                    if topParticipants.count < 3 {
                        topParticipants.append(participant)
                    }

                    if let index = updatedInvitedPeers.firstIndex(where: { .peer($0.id) == participant.id}) {
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
                        id: .peer(myPeerId),
                        peer: .init(myPeer),
                        ssrc: nil,
                        videoDescription: nil,
                        presentationDescription: nil,
                        joinTimestamp: strongSelf.temporaryJoinTimestamp,
                        raiseHandRating: strongSelf.temporaryRaiseHandRating,
                        hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                        activityTimestamp: strongSelf.temporaryActivityTimestamp,
                        activityRank: strongSelf.temporaryActivityRank,
                        muteState: strongSelf.temporaryMuteState ?? (strongSelf.initialOutput.isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false) : nil),
                        volume: nil,
                        about: about,
                        joinedVideo: strongSelf.temporaryVideoJoined
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
        
        
  


        
        var encryptionContext: OngoingGroupCallEncryptionContext?
        if let e2eContext = self.e2eContext {
            encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: e2eContext.state, channelId: 0)
        } else if self.isConference {
            // Prevent non-encrypted conference calls
            encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: Atomic(value: ConferenceCallE2EContext.ContextStateHolder()), channelId: 0)
        }
                                   
        let prioritizeVP8 = self.accountContext.appConfiguration.getBoolValue("macos_calls_prioritize_vp8", orElse: false)
        
        if shouldJoin, let callInfo = activeCallInfo {
            let genericCallContext: OngoingGroupCallContext
            if let current = self.genericCallContext {
                genericCallContext = current
            } else {
                genericCallContext = OngoingGroupCallContext(inputDeviceId: devicesContext.currentMicroId ?? "", outputDeviceId: devicesContext.currentOutputId ?? "", audioSessionActive: .single(true), video: self.videoCapturer, requestMediaChannelDescriptions: { [weak self] ssrcs, completion in
                    let disposable = MetaDisposable()
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        disposable.set(strongSelf.requestMediaChannelDescriptions(ssrcs: ssrcs, completion: completion))
                    }
                    return disposable
                }, rejoinNeeded: { [weak self] in
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        if case .established = strongSelf.internalState {
                            strongSelf.requestCall(movingFromBroadcastToRtc: false)
                        }
                    }
                }, outgoingAudioBitrateKbit: nil, videoContentType: .generic, enableNoiseSuppression: false, disableAudioInput: self.isStream, enableSystemMute: false, prioritizeVP8: prioritizeVP8, logPath: allocateCallLogPath(account: self.account), onMutedSpeechActivityDetected: { _ in }, isConference: isConference, audioIsActiveByDefault: !self.initialOutput.isMuted, isStream: false, sharedAudioDevice: nil, encryptionContext: encryptionContext)
                
                
                
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
                if let peerId {
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        peerAdminIds = Signal { subscriber in
                            let (disposable, _) = strongSelf.accountContext.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { list in
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
                } else {
                    peerAdminIds = .single([])
                }
                var generateE2EData: ((Data?) -> JoinGroupCallE2E?)?
                if let keyPair = strongSelf.keyPair {
                    if let mappedKeyPair = TdKeyPair(keyId: keyPair.id, publicKey: keyPair.publicKey.data) {
                        let userId = strongSelf.joinAsPeerId.id._internalGetInt64Value()
                        var checkIndex = 0
                        generateE2EData = { block -> JoinGroupCallE2E? in
                            
                            checkIndex += 1
                            
                            if checkIndex > 1 {
                                var bp = 0
                                bp += 1
                            }
                            
                            if let block {
                                guard let resultBlock = tdGenerateSelfAddBlock(mappedKeyPair, userId, block) else {
                                    return nil
                                }
                                return JoinGroupCallE2E(
                                    publicKey: keyPair.publicKey,
                                    block: resultBlock
                                )
                            } else {
                                guard let resultBlock = tdGenerateZeroBlock(mappedKeyPair, userId) else {
                                    return nil
                                }
                                return JoinGroupCallE2E(
                                    publicKey: keyPair.publicKey,
                                    block: resultBlock
                                )
                            }
                        }
                    }
                }
                
                let reference: InternalGroupCallReference
                if let initialCall = strongSelf.initialCall {
                    reference = initialCall.reference
                } else {
                    reference = .id(id: callInfo.id, accessHash: callInfo.accessHash)
                }
                

                strongSelf.currentLocalSsrc = ssrc
                strongSelf.checkIndex += 1
                
                if strongSelf.checkIndex > 1 {
                    var bp = 0
                    bp += 1
                }
                strongSelf.requestDisposable.set((strongSelf.accountContext.engine.calls.joinGroupCall(
                    peerId: strongSelf.peerId,
                    joinAs: strongSelf.joinAsPeerId,
                    callId: callInfo.id,
                    reference: reference,
                    preferMuted: true,
                    joinPayload: joinPayload,
                    peerAdminIds: peerAdminIds,
                    inviteHash: strongSelf.invite,
                    generateE2E: generateE2EData
                ) |> deliverOnMainQueue).start(next: { joinCallResult in
                    guard let strongSelf = self else {
                        return
                    }
                    let clientParams = joinCallResult.jsonParams

                    strongSelf.ssrcMapping.removeAll()
                    for participant in joinCallResult.state.participants {
                        if let ssrc = participant.ssrc {
                            if let participantPeer = participant.peer {
                                strongSelf.ssrcMapping[ssrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: false)
                            }
                        }
                        if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                            if let participantPeer = participant.peer {
                                strongSelf.ssrcMapping[presentationSsrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: true)
                            }
                        }
                    }

                    switch joinCallResult.connectionMode {
                    case .rtc:
                        strongSelf.currentConnectionMode = .rtc
                        strongSelf.genericCallContext?.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: false)
                        strongSelf.genericCallContext?.setJoinResponse(payload: clientParams)
                    case let .broadcast(isExternalStream):
                        strongSelf.currentConnectionMode = .broadcast
                        strongSelf.genericCallContext?.setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData(engine: strongSelf.accountContext.engine, callId: callInfo.id, accessHash: callInfo.accessHash, isExternalStream: isExternalStream))
                        strongSelf.genericCallContext?.setConnectionMode(.broadcast, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: isExternalStream)
                    }

                    strongSelf.updateSessionState(internalState: .established(info: joinCallResult.callInfo, connectionMode: joinCallResult.connectionMode, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state))
                    strongSelf.e2eContext?.begin(initialState: joinCallResult.e2eState)

                }, error: { error in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if case .anonymousNotAllowed = error {
                        alert(for: strongSelf.accountContext.window, info: strings().voiceChatAnonymousDisabledAlertText)
                    } else if case .tooManyParticipants = error {
                        alert(for: strongSelf.accountContext.window, info: strings().voiceChatJoinErrorTooMany)
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
                var orignalMyLevelHasVoice: Bool = false
                var missingSsrcs = Set<UInt32>()
                for (ssrcKey, level, hasVoice) in levels {
                    var peerId: PeerId?
                    let ssrcValue: UInt32
                    switch ssrcKey {
                    case .local:
                        peerId = strongSelf.joinAsPeerId
                        ssrcValue = 0
                    case let .source(ssrc):
                        if let mapping = strongSelf.ssrcMapping[ssrc] {
                            if mapping.isPresentation {
                                peerId = nil
                                ssrcValue = 0
                            } else {
                                peerId = mapping.peerId
                                ssrcValue = ssrc
                            }
                        } else {
                            ssrcValue = ssrc
                        }
                    }
                    if let peerId = peerId {
                        if case .local = ssrcKey {
                            orignalMyLevelHasVoice = hasVoice
                            myLevel = level
                            myLevelHasVoice = hasVoice
                        }
                        result.append((peerId, ssrcValue, level, hasVoice))
                    } else if ssrcValue != 0 {
                        missingSsrcs.insert(ssrcValue)
                    }

                }
                            
                strongSelf.speakingParticipantsContext.update(levels: result)
                
                if strongSelf.stateValue.muteState == nil {
                    let mappedLevel = myLevel * 1.5
                    strongSelf.myAudioLevelPipe.putNext(mappedLevel)
                    strongSelf.processMyAudioLevel(level: mappedLevel, hasVoice: myLevelHasVoice && orignalMyLevelHasVoice)
                } else {
                    strongSelf.myAudioLevelPipe.putNext(0)
                    strongSelf.processMyAudioLevel(level: 0, hasVoice: false)
                }
                
                strongSelf.isSpeakingPromise.set(orignalMyLevelHasVoice)
                if !missingSsrcs.isEmpty && !strongSelf.isStream {
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
                let adminIds: Signal<Set<PeerId>, NoError>
                if let peerId {
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        rawAdminIds = Signal { subscriber in
                            let (disposable, _) = accountContext.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { list in
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
                    
                    adminIds = combineLatest(queue: .mainQueue(),
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
                    
                } else {
                    adminIds = .single(Set())
                }
                

                let myPeerId = self.joinAsPeerId
                
                var initialState = initialState
                var serviceState: GroupCallParticipantsContext.ServiceState?
                if let participantsContext = self.participantsContext, let immediateState = participantsContext.immediateState {
                    initialState.mergeActivity(from: immediateState, myPeerId: myPeerId, previousMyPeerId: self.ignorePreviousJoinAsPeerId?.0, mergeActivityTimestamps: true)
                    serviceState = participantsContext.serviceState
                }
                
                let participantsContext = accountContext.engine.calls.groupCall(
                    peerId: self.peerId,
                    myPeerId: self.joinAsPeerId,
                    id: callInfo.id,
                    reference: .id(id: callInfo.id, accessHash: callInfo.accessHash),
                    state: GroupCallParticipantsContext.State(
                        participants: [],
                        nextParticipantsFetchOffset: nil,
                        adminIds: Set(),
                        isCreator: false,
                        defaultParticipantsAreMuted: callInfo.defaultParticipantsAreMuted ?? GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: self.stateValue.defaultParticipantMuteState == .muted, canChange: true),
                        sortAscending: true,
                        recordingStartTimestamp: nil,
                        title: self.stateValue.title,
                        scheduleTimestamp: self.stateValue.scheduleTimestamp,
                        subscribedToScheduled: self.stateValue.subscribedToScheduled,
                        totalCount: 0,
                        isVideoEnabled: callInfo.isVideoEnabled,
                        unmutedVideoLimit: callInfo.unmutedVideoLimit,
                        isStream: callInfo.isStream,
                        version: 0
                    ),
                    previousServiceState: nil,
                    e2eContext: self.e2eContext
                )
                self.temporaryParticipantsContext = nil
                self.participantsContext = participantsContext
                
                if !self.initialOutput.isMuted {
                    self.setIsMuted(action: .unmuted)
                }
                
                if let video = self.initialOutput.video {
                    self.requestVideo(deviceId: video.capturer, source: video.source)
                }
                if let video = self.initialOutput.screencast {
                    self.requestScreencast(deviceId: video.capturer, source: video.source)
                }
                
                let myPeer = self.accountContext.account.postbox.peerView(id: myPeerId)
                |> map { view -> (Peer, CachedPeerData?)? in
                    if let peer = peerViewMainPeer(view) {
                        return (peer, view.cachedData)
                    } else {
                        return nil
                    }
                }
                |> beforeNext { view in
                    if let view = view, view.1 == nil {
                        let _ = accountContext.engine.peers.fetchAndUpdateCachedPeerData(peerId: myPeerId).start()
                    }
                }
                
                let chatPeer: Signal<Peer?, NoError>
                
                if let peerId {
                    chatPeer = self.accountContext.account.postbox.peerView(id: peerId)
                    |> map { view -> Peer? in
                        if let peer = peerViewMainPeer(view), callInfo.isStream {
                            return peer
                        } else {
                            return nil
                        }
                    }
                } else {
                    chatPeer = .single(nil)
                }
                
                let peerView: Signal<PeerView?, NoError>
                if let peerId {
                    peerView = accountContext.account.postbox.peerView(id: peerId) |> map(Optional.init)
                } else {
                    peerView = .single(nil)
                }


                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                    participantsContext.state,
                    participantsContext.activeSpeakers,
                    self.speakingParticipantsContext.get(),
                    adminIds,
                    myPeer,
                    chatPeer,
                    peerView,
                    self.isReconnectingAsSpeakerPromise.get()
                ).start(next: { [weak self] state, activeSpeakers, speakingParticipants, adminIds, myPeerAndCachedData, chatPeer, view, isReconnectingAsSpeaker in
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
                            if participants[i].id == .peer(ignorePeerId) && participants[i].ssrc == ignoreSsrc {
                                participants.remove(at: i)
                                break
                            }
                        }
                    }

                    if !participants.contains(where: { $0.id == .peer(myPeerId) }) && !strongSelf.leaving {
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
                                id: .peer(myPeerId),
                                peer: .init(myPeer),
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
                                about: about,
                                joinedVideo: strongSelf.temporaryVideoJoined
                            ))
                            participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                        }
                    }
                    
                    if let chatPeer = chatPeer {
                        participants.removeAll(where: { $0.id == .peer(chatPeer.id) })
                        participants.append(GroupCallParticipantsContext.Participant(
                            id: .peer(chatPeer.id),
                            peer: .init(chatPeer),
                            ssrc: 100,
                            videoDescription: GroupCallParticipantsContext.Participant.VideoDescription(
                                endpointId: "unified",
                                ssrcGroups: [],
                                audioSsrc: 100,
                                isPaused: false
                            ),
                            presentationDescription: nil,
                            joinTimestamp: strongSelf.temporaryJoinTimestamp,
                            raiseHandRating: nil,
                            hasRaiseHand: false,
                            activityTimestamp: nil,
                            activityRank: nil,
                            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false),
                            volume: nil,
                            about: nil,
                            joinedVideo: false
                        ))
                        participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                    }


                    
                    var otherParticipantsWithVideo = 0
                                        
                    for participant in participants {
                        var participant = participant
                        
                        if topParticipants.count < 3 {
                            topParticipants.append(participant)
                        }
                        
                        if let ssrc = participant.ssrc {
                            if let participantPeer = participant.peer {
                                strongSelf.ssrcMapping[ssrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: false)
                            }
                        }
                        if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                            if let participantPeer = participant.peer {
                                strongSelf.ssrcMapping[presentationSsrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: true)
                            }
                        }

                        
                        if participant.id == .peer(strongSelf.joinAsPeerId) {
                            var filteredMuteState = participant.muteState
                            if isReconnectingAsSpeaker || strongSelf.currentConnectionMode != .rtc {
                                filteredMuteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false)
                                participant.muteState = filteredMuteState
                            }

                            if !(strongSelf.stateValue.muteState?.canUnmute ?? false) {
                                strongSelf.stateValue.raisedHand = participant.hasRaiseHand
                            }

                            
                        } else {
                            if let ssrc = participant.ssrc {
                                if let volume = participant.volume {
                                    strongSelf.genericCallContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    strongSelf.genericCallContext?.setVolume(ssrc: ssrc, volume: 0.0)
                                }
                            }
                            if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                                if let volume = participant.volume {
                                    strongSelf.genericCallContext?.setVolume(ssrc: presentationSsrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    strongSelf.genericCallContext?.setVolume(ssrc: presentationSsrc, volume: 0.0)
                                }
                            }

                            if participant.videoDescription != nil || participant.presentationDescription != nil {
                                otherParticipantsWithVideo += 1
                            }

                        }
                        
                        if let index = updatedInvitedPeers.firstIndex(where: { $0.id == participant.peer?.id }) {
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
                    stateValue.isVideoEnabled = state.isVideoEnabled && otherParticipantsWithVideo < state.unmutedVideoLimit


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
                        isVideoEnabled: state.isVideoEnabled,
                        unmutedVideoLimit: state.unmutedVideoLimit,
                        isStream: callInfo.isStream,
                        isCreator: callInfo.isCreator
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
                let adminIds: Signal<Set<PeerId>, NoError>
                if let peerId {
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        rawAdminIds = Signal { subscriber in
                            let (disposable, _) = accountContext.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { list in
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
                    adminIds = combineLatest(queue: .mainQueue(),
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
                } else {
                    adminIds = .single(Set())
                }
                
                let participantsContext = self.accountContext.engine.calls.groupCall(
                    peerId: self.peerId,
                    myPeerId: self.joinAsPeerId,
                    id: callInfo.id,
                    reference: .id(id: callInfo.id, accessHash: callInfo.accessHash),
                    state: GroupCallParticipantsContext.State(
                        participants: [],
                        nextParticipantsFetchOffset: nil,
                        adminIds: Set(),
                        isCreator: false,
                        defaultParticipantsAreMuted: callInfo.defaultParticipantsAreMuted ?? GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: self.stateValue.defaultParticipantMuteState == .muted, canChange: true),
                        sortAscending: true,
                        recordingStartTimestamp: nil,
                        title: self.stateValue.title,
                        scheduleTimestamp: self.stateValue.scheduleTimestamp,
                        subscribedToScheduled: self.stateValue.subscribedToScheduled,
                        totalCount: 0,
                        isVideoEnabled: callInfo.isVideoEnabled,
                        unmutedVideoLimit: callInfo.unmutedVideoLimit,
                        isStream: callInfo.isStream,
                        version: 0
                    ),
                    previousServiceState: nil,
                    e2eContext: self.e2eContext
                )
                self.temporaryParticipantsContext = nil
                self.participantsContext = participantsContext
                
                let myPeerId = self.joinAsPeerId
                let myPeer = self.accountContext.account.postbox.peerView(id: myPeerId)
                |> map { view -> (Peer, CachedPeerData?)? in
                    if let peer = peerViewMainPeer(view) {
                        return (peer, view.cachedData)
                    } else {
                        return nil
                    }
                }
                |> beforeNext { view in
                    if let view = view, view.1 == nil {
                        let _ = accountContext.engine.peers.fetchAndUpdateCachedPeerData(peerId: myPeerId).start()
                    }
                }
                               

                let chatPeer: Signal<Peer?, NoError>
                
                if let peerId {
                    chatPeer = self.accountContext.account.postbox.peerView(id: peerId)
                    |> map { view -> Peer? in
                        if let peer = peerViewMainPeer(view), callInfo.isStream {
                            return peer
                        } else {
                            return nil
                        }
                    }
                } else {
                    chatPeer = .single(nil)
                }
                
                let peerView: Signal<PeerView?, NoError>
                if let peerId {
                    peerView = accountContext.account.postbox.peerView(id: peerId) |> map(Optional.init)
                } else {
                    peerView = .single(nil)
                }


                
                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                    participantsContext.state,
                    adminIds,
                    myPeer,
                    chatPeer,
                    peerView
                ).start(next: { [weak self] state, adminIds, myPeerAndCachedData, chatPeer, view in
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
                            id: .peer(myPeerId),
                            peer: .init(myPeer),
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
                            about: about,
                            joinedVideo: strongSelf.temporaryVideoJoined
                        ))
                    }
                    
                    if let chatPeer = chatPeer {
                        participants.removeAll(where: { $0.id == .peer(chatPeer.id) })
                        participants.append(GroupCallParticipantsContext.Participant(
                            id: .peer(chatPeer.id),
                            peer: .init(chatPeer),
                            ssrc: 100,
                            videoDescription: GroupCallParticipantsContext.Participant.VideoDescription(
                                endpointId: "unified",
                                ssrcGroups: [],
                                audioSsrc: 100,
                                isPaused: false
                            ),
                            presentationDescription: nil,
                            joinTimestamp: strongSelf.temporaryJoinTimestamp,
                            raiseHandRating: nil,
                            hasRaiseHand: false,
                            activityTimestamp: nil,
                            activityRank: nil,
                            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false),
                            volume: nil,
                            about: nil,
                            joinedVideo: false
                        ))
                        participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
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
                    
                    
                    if let activeCall = (view?.cachedData as? CachedGroupData)?.activeCall {
                        stateValue.title = activeCall.title
                    } else if let activeCall = (view?.cachedData as? CachedChannelData)?.activeCall {
                        stateValue.title = activeCall.title
                    } else {
                        stateValue.title = state.title
                    }
                    
                    
                    stateValue.scheduleTimestamp = strongSelf.isScheduledStarted ? nil : state.scheduleTimestamp

                    strongSelf.stateValue = stateValue
                    
                    if state.scheduleTimestamp == nil && !strongSelf.isScheduledStarted {
                        strongSelf.updateSessionState(internalState: .active(GroupCallInfo(id: callInfo.id, accessHash: callInfo.accessHash, participantCount: state.totalCount, streamDcId: callInfo.streamDcId, title: state.title, scheduleTimestamp: nil, subscribedToScheduled: false, recordingStartTimestamp: nil, sortAscending: true, defaultParticipantsAreMuted: callInfo.defaultParticipantsAreMuted ?? state.defaultParticipantsAreMuted, isVideoEnabled: callInfo.isVideoEnabled, unmutedVideoLimit: callInfo.unmutedVideoLimit, isStream: callInfo.isStream, isCreator: state.isCreator)))
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
                            isVideoEnabled: state.isVideoEnabled,
                            unmutedVideoLimit: state.unmutedVideoLimit,
                            isStream: callInfo.isStream,
                            isCreator: callInfo.isCreator
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
                    if let participantPeer = participant.peer {
                        result.append(OngoingGroupCallContext.MediaChannelDescription(
                            kind: .audio,
                            peerId: participantPeer.id.id._internalGetInt64Value(),
                            audioSsrc: audioSsrc,
                            videoDescription: nil
                        ))
                    }
                }

                if let screencastSsrc = participant.presentationDescription?.audioSsrc {
                    if remainingSsrcs.contains(screencastSsrc) {
                        remainingSsrcs.remove(screencastSsrc)
                        if let participantPeer = participant.peer {
                            result.append(OngoingGroupCallContext.MediaChannelDescription(
                                kind: .audio,
                                peerId: participantPeer.id.id._internalGetInt64Value(),
                                audioSsrc: screencastSsrc,
                                videoDescription: nil
                            ))
                        }
                    }
                }
            }
        }

        var remainingSsrcs = ssrcs
        var result: [OngoingGroupCallContext.MediaChannelDescription] = []

        if let membersValue = self.membersValue {
            extractMediaChannelDescriptions(remainingSsrcs: &remainingSsrcs, participants: membersValue.participants, into: &result)
        }

        if !remainingSsrcs.isEmpty, let callInfo = self.internalState.callInfo {
            return (accountContext.engine.calls.getGroupCallParticipants(reference: .id(id: callInfo.id, accessHash: callInfo.accessHash), offset: "", ssrcs: Array(remainingSsrcs), limit: 100, sortAscending: callInfo.sortAscending)
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
            let checkSignal = accountContext.engine.calls.checkGroupCall(callId: callInfo.id, accessHash: callInfo.accessHash, ssrcs: [ssrc])
            
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
        self.genericCallContext?.stop(account: account, reportCallId: nil, debugLog: .init(nil))
        self.screencastCallContext?.stop(account: account, reportCallId: nil, debugLog: .init(nil))
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
        
        if self.stateValue.scheduleTimestamp != nil, let callPeerId = self.peerId {
            updateGroupCallJoinAsDisposable.set(accountContext.engine.calls.updateGroupCallJoinAsPeer(peerId: callPeerId, joinAs: peerId).start())
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
                    if participant.id == .peer(previousPeerId) {
                        strongSelf.temporaryJoinTimestamp = participant.joinTimestamp
                        strongSelf.temporaryActivityTimestamp = participant.activityTimestamp
                        strongSelf.temporaryVideoJoined = participant.joinedVideo
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
                self.leaveDisposable.set((accountContext.engine.calls.stopGroupCall(peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.markAsCanBeRemoved()
                }))
            } else {
                let contexts = self.accountContext.cachedGroupCallContexts
                let accountContext = self.accountContext
                let id = callInfo.id
                let accessHash = callInfo.accessHash
                let source = localSsrc
                contexts.impl.with { impl in
                    impl.leaveInBackground(engine: accountContext.engine, id: id, accessHash: accessHash, source: source)
                }
                self.markAsCanBeRemoved()
            }
        } else if let callInfo = self.internalState.callInfo, terminateIfPossible {
            self.leaveDisposable.set((accountContext.engine.calls.stopGroupCall(peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
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
            
            if !isEffectivelyMuted {
                if let id = self.devicesContext.currentMicroId {
                    self.genericCallContext?.switchAudioInput(id)
                }
                if let id = self.devicesContext.currentOutputId {
                    self.genericCallContext?.switchAudioOutput(id)
                }
            }
        })
    }
    
    func raiseHand() {
        guard let membersValue = self.membersValue else {
            return
        }
        for participant in membersValue.participants {
            if participant.id == .peer(self.joinAsPeerId) {
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
            if participant.id == .peer(self.joinAsPeerId) {
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
    
    public func requestScreencast(deviceId: OngoingCallVideoCapturer, source: VideoSourceMac) {

        let maybeCallInfo: GroupCallInfo? = self.internalState.callInfo

        guard let callInfo = maybeCallInfo else {
            return
        }

        self.screenCapturer = deviceId
        
        self.stateValue.sources.screencast = source
        
        self.screenCapturer?.setOnFatalError({ [weak self] in
            self?.mustStopSharing?()
        })
        
        self.screenCapturer?.setOnPause({ [weak self] paused in
            guard let strongSelf = self else {
                return
            }
            strongSelf.participantsContext?.updateVideoState(peerId: strongSelf.joinAsPeerId, isVideoMuted: nil, isVideoPaused: false, isPresentationPaused: paused)
        })
        
        var encryptionContext: OngoingGroupCallEncryptionContext?
        if let e2eContext = self.e2eContext {
            encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: e2eContext.state, channelId: 1)
        } else if self.isConference {
            encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: Atomic(value: ConferenceCallE2EContext.ContextStateHolder()), channelId: 1)
        }

        let screencastCallContext = OngoingGroupCallContext(audioSessionActive: .single(true), video: self.screenCapturer, requestMediaChannelDescriptions: { _, completion in
            completion([])
            return EmptyDisposable
        },
            rejoinNeeded: {},
            outgoingAudioBitrateKbit: nil,
            videoContentType: .screencast,
            enableNoiseSuppression: false,
            disableAudioInput: true,
            enableSystemMute: false,
            prioritizeVP8: false,
            logPath: "",
            onMutedSpeechActivityDetected: { _ in },
            isConference: false,
            audioIsActiveByDefault: false,
            isStream: false,
            sharedAudioDevice: nil,
            encryptionContext: encryptionContext
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

            strongSelf.requestDisposable.set((strongSelf.accountContext.engine.calls.joinGroupCallAsScreencast(
                callId: callInfo.id,
                accessHash: callInfo.accessHash,
                joinPayload: joinPayload
            )
            |> deliverOnMainQueue).start(next: { joinCallResult in
                guard let strongSelf = self, let screencastCallContext = strongSelf.screencastCallContext else {
                    return
                }
                let clientParams = joinCallResult.jsonParams

                screencastCallContext.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: false)
                screencastCallContext.setJoinResponse(payload: clientParams)
                
                strongSelf.screencastEndpointId = joinCallResult.endpointId

            }, error: { error in
                guard let _ = self else {
                    return
                }
            }))
        }))
        
    }

    
    public func requestScreencast(deviceId: String, source: VideoSourceMac) {
        if self.screencastCallContext != nil {
            return
        }

        let screenCapturer = OngoingCallVideoCapturer(deviceId)
        requestScreencast(deviceId: screenCapturer, source: source)
    }
    
    public func disableScreencast() {
        self.hasScreencast = false
        
        self.screencastEndpointId = nil
        if let screencastCallContext = self.screencastCallContext {
            self.screencastCallContext = nil
            screencastCallContext.stop(account: account, reportCallId: nil, debugLog: .init(nil))

            let maybeCallInfo: GroupCallInfo? = self.internalState.callInfo

            if let callInfo = maybeCallInfo {
                self.screencastJoinDisposable.set(accountContext.engine.calls.leaveGroupCallAsScreencast(
                    callId: callInfo.id,
                    accessHash: callInfo.accessHash
                ).start())
            }
        }
        if let _ = self.screenCapturer {
            self.screenCapturer = nil
            self.screencastCallContext?.disableVideo()
        }
        
        self.stateValue.sources.screencast = nil
    }
    
    func toggleVideoFailed(failed: Bool) {
        self.stateValue.sources.failed = failed

    }


    public func requestVideo(deviceId: OngoingCallVideoCapturer, source: VideoSourceMac) {
        self.videoCapturer = deviceId

        self.videoCapturer?.setOnFatalError({ [weak self] in
            self?.mustStopVideo?()
        })
        self.hasVideo = true
        self.genericCallContext?.requestVideo(deviceId)
        self.participantsContext?.updateVideoState(peerId: self.joinAsPeerId, isVideoMuted: false, isVideoPaused: false, isPresentationPaused: nil)

        self.stateValue.sources.video = source
    }

    
    public func requestVideo(deviceId: String, source: VideoSourceMac) {
        if self.videoCapturer != nil {
            return
        }

        let videoCapturer = OngoingCallVideoCapturer(deviceId)
        self.requestVideo(deviceId: videoCapturer, source: source)
    }
    
    public func disableVideo() {
        self.hasVideo = false
        if let _ = self.videoCapturer {
            self.videoCapturer = nil
            self.genericCallContext?.disableVideo()
            self.participantsContext?.updateVideoState(peerId: self.joinAsPeerId, isVideoMuted: true, isVideoPaused: false, isPresentationPaused: nil)
        }
        self.stateValue.sources.video = nil
    }


    
    public func setVolume(peerId: PeerId, volume: Int32, sync: Bool) {
        var found = false
        for (ssrc, mapping) in self.ssrcMapping {
            if mapping.peerId == peerId {
                self.genericCallContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                found = true
            }
        }
        if found && sync {
            self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: volume, raiseHand: nil)
        }
        
    }

    public func setRequestedVideoList(items: [PresentationGroupCallRequestedVideo]) {
        self.genericCallContext?.setRequestedVideoChannels(items.compactMap { item -> OngoingGroupCallContext.VideoChannel in
            let mappedMinQuality: OngoingGroupCallContext.VideoChannel.Quality
            let mappedMaxQuality: OngoingGroupCallContext.VideoChannel.Quality
            switch item.minQuality {
            case .thumbnail:
                mappedMinQuality = .thumbnail
            case .medium:
                mappedMinQuality = .medium
            case .full:
                mappedMinQuality = .full
            }
            switch item.maxQuality {
            case .thumbnail:
                mappedMaxQuality = .thumbnail
            case .medium:
                mappedMaxQuality = .medium
            case .full:
                mappedMaxQuality = .full
            }
            return OngoingGroupCallContext.VideoChannel(
                audioSsrc: item.audioSsrc,
                peerId: item.peerId,
                endpointId: item.endpointId,
                ssrcGroups: item.ssrcGroups.map { group in
                    return OngoingGroupCallContext.VideoChannel.SsrcGroup(semantics: group.semantics, ssrcs: group.ssrcs)
                },
                minQuality: mappedMinQuality,
                maxQuality: mappedMaxQuality
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

    func setShouldBeRecording(_ shouldBeRecording: Bool, title: String?, videoOrientation: Bool?) {
        if !self.stateValue.canManageCall {
            return
        }
        if (self.stateValue.recordingStartTimestamp != nil) == shouldBeRecording {
            return
        }
        self.participantsContext?.updateShouldBeRecording(shouldBeRecording, title: title, videoOrientation: videoOrientation)
    }
    
    private func requestCall(movingFromBroadcastToRtc: Bool) {
        self.currentConnectionMode = .none
        self.genericCallContext?.setConnectionMode(.none, keepBroadcastConnectedIfWasEnabled: movingFromBroadcastToRtc, isUnifiedBroadcast: false)
                
        self.internalState = .requesting
        self.internalStatePromise.set(.single(.requesting))
        self.isCurrentlyConnecting = nil
        
        enum CallError {
            case generic
        }
        
        let account = self.account
        
        let currentCall: Signal<GroupCallInfo?, CallError>
        if let initialCall = self.initialCall {
            currentCall = accountContext.engine.calls.getCurrentGroupCall(reference: initialCall.reference)
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
                var reference: InternalGroupCallReference = .id(id: value.id, accessHash: value.accessHash)
                if let current = strongSelf.initialCall {
                    switch current.reference {
                    case .message, .link:
                        reference = current.reference
                    default:
                        break
                    }
                }
                strongSelf.initialCall = (EngineGroupCallDescription(id: value.id, accessHash: value.accessHash, title: value.title, scheduleTimestamp: nil, subscribedToScheduled: false, isStream: value.isStream), reference)
                strongSelf.callId = value.id
                strongSelf.updateSessionState(internalState: .active(value))
                
                strongSelf.isStream = value.isStream
            } else {
                strongSelf.markAsCanBeRemoved()
            }
        }))
    }
    
    func setConferenceInvitedPeers(_ peerIds: [PeerId]) {
        //TODO:release
        /*self.invitedPeersValue = peerIds.map {
            PresentationGroupCallInvitedPeer(id: $0, state: .requesting)
        }*/
    }
    
    
    public func invitePeer(_ peerId: PeerId, isVideo: Bool = false) -> Bool {
        if self.isConference {
            
            guard let initialCall = self.initialCall else {
                return false
            }
            
            if self.conferenceInvitationContexts[peerId] != nil {
                return false
            }
            var onStateUpdated: ((PendingConferenceInvitationContext.State) -> Void)?
            var onEnded: ((Bool) -> Void)?
            var didEndAlready = false
            let invitationContext = PendingConferenceInvitationContext(
                engine: self.accountContext.engine,
                reference: initialCall.reference,
                peerId: peerId,
                isVideo: isVideo,
                onStateUpdated: { state in
                    onStateUpdated?(state)
                },
                onEnded: { success in
                    didEndAlready = true
                    onEnded?(success)
                }
            )
            if !didEndAlready {
                conferenceInvitationContexts[peerId] = invitationContext
                if !self.invitedPeersValue.contains(where: { $0.id == peerId }) {
                    self.invitedPeersValue.append(PresentationGroupCallInvitedPeer(id: peerId, state: .requesting))
                }
                onStateUpdated = { [weak self] state in
                    guard let self else {
                        return
                    }
                    if let index = self.invitedPeersValue.firstIndex(where: { $0.id == peerId }) {
                        var invitedPeer = self.invitedPeersValue[index]
                        switch state {
                        case .ringing:
                            invitedPeer.state = .ringing
                        }
                        self.invitedPeersValue[index] = invitedPeer
                    }
                }
                onEnded = { [weak self, weak invitationContext] success in
                    guard let self, let invitationContext else {
                        return
                    }
                    if self.conferenceInvitationContexts[peerId] === invitationContext {
                        self.conferenceInvitationContexts.removeValue(forKey: peerId)
                        
                        if success {
                            if let index = self.invitedPeersValue.firstIndex(where: { $0.id == peerId }) {
                                var invitedPeer = self.invitedPeersValue[index]
                                invitedPeer.state = .connecting
                                self.invitedPeersValue[index] = invitedPeer
                            }
                        } else {
                            self.invitedPeersValue.removeAll(where: { $0.id == peerId })
                        }
                    }
                }
            }
            
            return true

        } else {
            guard let callInfo = self.internalState.callInfo, !self.invitedPeersValue.contains(where: { $0.id == peerId }) else {
                return false
            }
            
            var updatedInvitedPeers = self.invitedPeersValue
            updatedInvitedPeers.insert(PresentationGroupCallInvitedPeer(id: peerId, state: nil), at: 0)
            self.invitedPeersValue = updatedInvitedPeers
            
            let _ = self.accountContext.engine.calls.inviteToGroupCall(callId: callInfo.id, accessHash: callInfo.accessHash, peerId: peerId).start()
            
            return true
        }
    }
    
    public func kickPeer(id: EnginePeer.Id) {
        if self.isConference {
            self.removedPeer(id)
            self.e2eContext?.kickPeer(id: id)
        }
    }

    
    func removedPeer(_ peerId: PeerId) {
        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.removeAll(where: { $0.id == peerId})
        self.invitedPeersValue = updatedInvitedPeers
        
        if let conferenceInvitationContext = self.conferenceInvitationContexts[peerId] {
            self.conferenceInvitationContexts.removeValue(forKey: peerId)
            if let messageId = conferenceInvitationContext.messageId {
                self.accountContext.engine.account.callSessionManager.dropOutgoingConferenceRequest(messageId: messageId)
            }
        }

    }
    
    func updateTitle(_ title: String, force: Bool) {
        guard let callInfo = self.internalState.callInfo else {
            return
        }
        self.stateValue.title = title.isEmpty ? nil : title
        
        var signal = accountContext.engine.calls.editGroupCallTitle(callId: callInfo.id, accessHash: callInfo.accessHash, title: title)
        if !force {
            signal = signal |> delay(0.2, queue: .mainQueue())
        }
        updateTitleDisposable.set(signal.start())
    }
    
    var inviteLinks: Signal<GroupCallInviteLinks?, NoError> {
        let engine = self.accountContext.engine
        let initialCall = self.initialCall
        let isConference = self.isConference

        return self.state
        |> map { state -> PeerId in
            return state.myPeerId
        }
        |> distinctUntilChanged
        |> mapToSignal { _ -> Signal<GroupCallInviteLinks?, NoError> in
            return self.internalStatePromise.get()
            |> filter { state -> Bool in
                if case .requesting = state {
                    return false
                } else {
                    return true
                }
            }
            |> mapToSignal { state in
                if let callInfo = state.callInfo {
                    let reference: InternalGroupCallReference
                    if let initialCall = initialCall {
                        reference = initialCall.reference
                    } else {
                        reference = .id(id: callInfo.id, accessHash: callInfo.accessHash)
                    }
                    
                    return engine.calls.groupCallInviteLinks(reference: reference, isConference: isConference)
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
        
        guard let peerId = self.peerId else {
            return
        }

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
                    strongSelf.typingDisposable.set(strongSelf.accountContext.account.acquireLocalInputActivity(peerId: PeerActivitySpace(peerId: peerId, category: .voiceChat), activity: .speakingInGroupCall(timestamp: 0)))
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
        
        guard let context = context else {
            return
        }
        
#if arch(arm64)
        let videoView = MetalVideoMakeView(videoStreamSignal: context.video(endpointId: endpointId))
        
        completion(PresentationCallVideoView(holder: videoView, view: videoView, setOnFirstFrameReceived: { [weak videoView] f in
            videoView?.firstFrameRendered = {
                f?(0)
            }
        }, getOrientation: {
            .rotation0
        }, getAspect: {
            return 0
        }, setVideoContentMode: { [weak videoView] gravity in
            videoView?.setGravity(gravity)
        }, setOnOrientationUpdated: { f in
            
        }, setOnIsMirroredUpdated: { f in
        }, setIsPaused: { paused in
        }, renderToSize: { [weak videoView] size, animated in
            videoView?.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .easeOut) : .immediate)
        }))
#else
        context.makeIncomingVideoView(endpointId: endpointId, requestClone: false, completion: { view, _ in
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
                    }, setIsPaused: { [weak view] paused in
                        view?.setIsPaused(paused)
                    }, renderToSize: { [weak view] size, animated in
                        view?.renderToSize(size, animated)
                    }
                ))
            } else {
                completion(nil)
            }
        })
#endif
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
        
        guard let peerId = self.peerId else {
            return
        }

        
        self.isScheduledStarted = true
        self.stateValue.scheduleTimestamp = nil
        
        self.startDisposable.set((accountContext.engine.calls.startScheduledGroupCall(peerId: peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
        |> deliverOnMainQueue).start(next: { [weak self] callInfo in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateSessionState(internalState: .active(callInfo))
        }))
    }
        
    public func toggleScheduledSubscription(_ subscribe: Bool) {
        guard case let .active(callInfo) = self.internalState, callInfo.scheduleTimestamp != nil, let peerId else {
            return
        }
        
        guard let peerId = self.peerId else {
            return
        }
        
        self.stateValue.subscribedToScheduled = subscribe
        
        self.subscribeDisposable.set((accountContext.engine.calls.toggleScheduledGroupCallSubscription(peerId: peerId, reference: .id(id: callInfo.id, accessHash: callInfo.accessHash), subscribe: subscribe)
        |> deliverOnMainQueue).start())
    }

    
}


func requestOrJoinGroupCall(context: AccountContext, peerId: PeerId?, joinAs: PeerId, initialCall: CachedChannelData.ActiveCall?, initialInfo: GroupCallInfo? = nil, joinHash: String? = nil, conferenceFromCallId: CallId? = nil, isConference: Bool = false, reference: InternalGroupCallReference?) -> Signal<RequestOrJoinGroupCallResult, NoError> {
    let sharedContext = context.sharedContext
    let accounts = context.sharedContext.activeAccounts |> take(1)
    let account = context.account

    if let peerId {
        return combineLatest(queue: .mainQueue(), accounts, account.postbox.loadedPeerWithId(peerId)) |> mapToSignal { accounts, peer in
            if let context = context.sharedContext.getCrossAccountGroupCall(), context.call.peerId == peerId, context.call.account.id == account.id {
                return .single(.samePeer(context))
            } else {
                return makeNewCallConfirmation(accountContext: context, newPeerId: peerId, newCallType: .voiceChat)
                |> mapToSignal { _ in
                    return sharedContext.endCurrentCall()
                } |> map { _ in
                    let call: CachedChannelData.ActiveCall?
                    if let info = initialInfo {
                        call = .init(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled, isStream: info.isStream)
                    } else {
                        call = initialCall
                    }
                    return .success(startGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: call, initialInfo: initialInfo, joinHash: joinHash, peer: peer, conferenceFromCallId: conferenceFromCallId, isConference: isConference, isChannel: peer.isChannel, reference: reference))
                }
            }
        }
    } else {
        return .complete()
    }
}

func requestOrJoinConferenceCall(context: AccountContext, initialInfo: GroupCallInfo, reference: InternalGroupCallReference) -> Signal<RequestOrJoinGroupCallResult, NoError> {
    let sharedContext = context.sharedContext
    let accounts = context.sharedContext.activeAccounts |> take(1)
    let account = context.account
    
    //TODO
    let joinAs = context.peerId
    
    let conferenceFromCallId: CallId = .init(id: initialInfo.id, accessHash: initialInfo.accessHash)

    return accounts |> mapToSignal { accounts in
        if let context = context.sharedContext.getCrossAccountGroupCall(), context.call.callId == conferenceFromCallId.id, context.call.account.id == account.id {
            return .single(.samePeer(context))
        } else {
            return makeNewCallConfirmation(accountContext: context, newPeerId: nil, newCallType: .voiceChat)
            |> mapToSignal { _ in
                return sharedContext.endCurrentCall()
            } |> map { _ in
                let call: CachedChannelData.ActiveCall?
                call = .init(id: initialInfo.id, accessHash: initialInfo.accessHash, title: initialInfo.title, scheduleTimestamp: initialInfo.scheduleTimestamp, subscribedToScheduled: initialInfo.subscribedToScheduled, isStream: initialInfo.isStream)

                return .success(startGroupCall(context: context, peerId: nil, joinAs: joinAs, initialCall: call, initialInfo: initialInfo, peer: nil, conferenceFromCallId: conferenceFromCallId, isConference: true, isChannel: false, reference: reference))
            }
        }
    }

}


private func startGroupCall(context: AccountContext, peerId: PeerId?, joinAs: PeerId, initialCall: CachedChannelData.ActiveCall?, initialInfo: GroupCallInfo? = nil, internalId: CallSessionInternalId = CallSessionInternalId(), joinHash: String? = nil, peer: Peer? = nil, conferenceFromCallId: CallId?, isConference: Bool, isChannel: Bool, reference: InternalGroupCallReference?) -> GroupCallContext {
    
    let keyPair: TelegramKeyPair? = isConference ? TelegramE2EEncryptionProviderImpl.shared.generateKeyPair() : nil
    
    var initial: (description: EngineGroupCallDescription, reference: InternalGroupCallReference)?
    
    if let initialCall, let reference {
        initial = (EngineGroupCallDescription(
            id: initialCall.id,
            accessHash: initialCall.accessHash,
            title: initialCall.title,
            scheduleTimestamp: initialCall.scheduleTimestamp,
            subscribedToScheduled: initialCall.subscribedToScheduled,
            isStream: false
        ), reference)
    } else if let initialInfo {
        initial = (EngineGroupCallDescription(
            id: initialInfo.id,
            accessHash: initialInfo.accessHash,
            title: initialInfo.title,
            scheduleTimestamp: initialInfo.scheduleTimestamp,
            subscribedToScheduled: initialInfo.subscribedToScheduled,
            isStream: false
        ), .id(id: initialInfo.id, accessHash: initialInfo.accessHash))
    } else if let initialCall {
        initial = (EngineGroupCallDescription(
            id: initialCall.id,
            accessHash: initialCall.accessHash,
            title: initialCall.title,
            scheduleTimestamp: initialCall.scheduleTimestamp,
            subscribedToScheduled: initialCall.subscribedToScheduled,
            isStream: false
        ), .id(id: initialCall.id, accessHash: initialCall.accessHash))
    }
    
    
    return GroupCallContext(call: PresentationGroupCallImpl(accountContext: context, initialCall: initial, internalId: internalId, peerId: peerId, isChannel: isChannel, invite: joinHash, joinAsPeerId: joinAs, initialInfo: initialInfo, isStream: initialCall?.isStream ?? initialCall?.isStream ?? initialInfo?.isStream ?? false, keyPair: keyPair, conferenceSourceId: nil, isConference: isConference, initialOutput: .init(isMuted: true)), peerMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, window: makeGroupWindow(isStream: false))
}

func createVoiceChat(context: AccountContext, peerId: PeerId, displayAsList: [FoundPeer]? = nil, canBeScheduled: Bool = false) {
    let confirmation = combineLatest(queue: .mainQueue(), makeNewCallConfirmation(accountContext: context, newPeerId: peerId, newCallType: .voiceChat), context.account.postbox.loadedPeerWithId(peerId)) |> mapToSignalPromotingError { _, peer in
        return Signal<(GroupCallInfo?, PeerId), CreateGroupCallError> { subscriber in

            let disposable = MetaDisposable()

            let create:(PeerId, Date?, Bool)->Void = { joinAs, schedule, isStream in
                let scheduleDate: Int32?
                if let timeInterval = schedule?.timeIntervalSince1970 {
                    scheduleDate = Int32(timeInterval)
                } else {
                    scheduleDate = nil
                }
                disposable.set(context.engine.calls.createGroupCall(peerId: peerId, title: nil, scheduleDate: scheduleDate, isExternalStream: isStream).start(next: { info in
                    subscriber.putNext((info, joinAs))
                    subscriber.putCompletion()
                }, error: { error in
                    subscriber.putError(error)
                }))
            }
            if let displayAsList = displayAsList {
                if displayAsList.count > 1 || canBeScheduled {
                    showModal(with: GroupCallDisplayAsController(context: context, mode: .create, peerId: peerId, list: displayAsList, completion: create, canBeScheduled: canBeScheduled, isCreator: peer.groupAccess.isCreator), for: context.window)
                } else {
                    create(context.peerId, nil, false)
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
            initialCall = .init(id: call.id, accessHash: call.accessHash, title: call.title, scheduleTimestamp: call.scheduleTimestamp, subscribedToScheduled: call.subscribedToScheduled, isStream: call.isStream)
        } else {
            initialCall = nil
        }
        
        return showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: initialCall, reference: nil) |> castError(CreateGroupCallError.self), for: context.window)
    } |> deliverOnMainQueue
    
    _ = requestCall.start(next: { result in
        switch result {
        case let .success(callContext), let .samePeer(callContext):
            applyGroupCallResult(context.sharedContext, callContext)
        default:
            alert(for: context.window, info: strings().errorAnError)
        }
    }, error: { error in
        if case .anonymousNotAllowed = error {
            alert(for: context.window, info: strings().voiceChatAnonymousDisabledAlertText)
        } else {
            alert(for: context.window, info: strings().errorAnError)
        }
    })
}
