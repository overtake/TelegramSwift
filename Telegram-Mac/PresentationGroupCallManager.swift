import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit


final class PresentationCallVideoView {
    public enum Orientation {
        case rotation0
        case rotation90
        case rotation180
        case rotation270
    }
    
    public let holder: AnyObject
    public let view: NSView
    public let setOnFirstFrameReceived: (((Float) -> Void)?) -> Void
    
    public let getOrientation: () -> Orientation
    public let getAspect: () -> CGFloat
    public let setOnOrientationUpdated: (((Orientation, CGFloat) -> Void)?) -> Void
    public let setOnIsMirroredUpdated: (((Bool) -> Void)?) -> Void
    
    public init(
        holder: AnyObject,
        view: NSView,
        setOnFirstFrameReceived: @escaping (((Float) -> Void)?) -> Void,
        getOrientation: @escaping () -> Orientation,
        getAspect: @escaping () -> CGFloat,
        setOnOrientationUpdated: @escaping (((Orientation, CGFloat) -> Void)?) -> Void,
        setOnIsMirroredUpdated: @escaping (((Bool) -> Void)?) -> Void
    ) {
        self.holder = holder
        self.view = view
        self.setOnFirstFrameReceived = setOnFirstFrameReceived
        self.getOrientation = getOrientation
        self.getAspect = getAspect
        self.setOnOrientationUpdated = setOnOrientationUpdated
        self.setOnIsMirroredUpdated = setOnIsMirroredUpdated
    }
}


struct PresentationGroupCallSummaryState: Equatable {
    var info: GroupCallInfo?
    var participantCount: Int
    var callState: PresentationGroupCallState
    var topParticipants: [GroupCallParticipantsContext.Participant]
    var activeSpeakers: Set<PeerId>
    init(
        info: GroupCallInfo?,
        participantCount: Int,
        callState: PresentationGroupCallState,
        topParticipants: [GroupCallParticipantsContext.Participant],
        activeSpeakers: Set<PeerId>
    ) {
        self.info = info
        self.participantCount = participantCount
        self.callState = callState
        self.topParticipants = topParticipants
        self.activeSpeakers = activeSpeakers
    }
}



enum RequestOrJoinGroupCallResult {
    case success(GroupCallContext)
    case fail
    case samePeer(GroupCallContext)
}

public enum PresentationGroupCallMuteAction: Equatable {
    case muted(isPushToTalkActive: Bool)
    case unmuted
    
    var isEffectivelyMuted: Bool {
       switch self {
           case let .muted(isPushToTalkActive):
               return !isPushToTalkActive
           case .unmuted:
               return false
       }
   }

}

public struct PresentationGroupCallState: Equatable {
    public enum NetworkState {
        case connecting
        case connected
    }
    
    public enum DefaultParticipantMuteState {
        case unmuted
        case muted
    }
    
    public var myPeerId: PeerId
    public var networkState: NetworkState
    public var canManageCall: Bool
    public var adminIds: Set<PeerId>
    public var muteState: GroupCallParticipantsContext.Participant.MuteState?
    public var defaultParticipantMuteState: DefaultParticipantMuteState?
    public var recordingStartTimestamp: Int32?
    public var title: String?
    public var raisedHand: Bool
    
    public init(
        myPeerId: PeerId,
        networkState: NetworkState,
        canManageCall: Bool,
        adminIds: Set<PeerId>,
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        defaultParticipantMuteState: DefaultParticipantMuteState?,
        recordingStartTimestamp: Int32?,
        title: String?,
        raisedHand: Bool
    ) {
        self.myPeerId = myPeerId
        self.networkState = networkState
        self.canManageCall = canManageCall
        self.adminIds = adminIds
        self.muteState = muteState
        self.defaultParticipantMuteState = defaultParticipantMuteState
        self.recordingStartTimestamp = recordingStartTimestamp
        self.title = title
        self.raisedHand = raisedHand
    }
}
final class PresentationGroupCallMemberEvent {
    let peer: Peer
    let joined: Bool
    
    init(peer: Peer, joined: Bool) {
        self.peer = peer
        self.joined = joined
    }
}




struct PresentationGroupCallMembers: Equatable {
    public var participants: [GroupCallParticipantsContext.Participant]
    public var speakingParticipants: Set<PeerId>
    public var totalCount: Int
    public var loadMoreToken: String?
    
    public init(
        participants: [GroupCallParticipantsContext.Participant],
        speakingParticipants: Set<PeerId>,
        totalCount: Int,
        loadMoreToken: String?
    ) {
        self.participants = participants
        self.speakingParticipants = speakingParticipants
        self.totalCount = totalCount
        self.loadMoreToken = loadMoreToken
    }
}




protocol PresentationGroupCall: class {
    var account: Account { get }
    var sharedContext: SharedAccountContext { get }
    var internalId: CallSessionInternalId { get }
    var peerId: PeerId { get }
    var peer: Peer? { get }
    var joinAsPeerId: PeerId { get }
    var joinAsPeerIdValue:Signal<PeerId, NoError> { get }
    var canBeRemoved: Signal<Bool, NoError> { get }
    var state: Signal<PresentationGroupCallState, NoError> { get }
    var members: Signal<PresentationGroupCallMembers?, NoError> { get }
    var audioLevels: Signal<[(PeerId, UInt32, Float, Bool)], NoError> { get }
    var myAudioLevel: Signal<Float, NoError> { get }
    var invitedPeers: Signal<[PeerId], NoError> { get }
    var isMuted: Signal<Bool, NoError> { get }
    var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> { get }
    
//    var activeCall: CachedChannelData.ActiveCall? { get }
    var inviteLinks:Signal<GroupCallInviteLinks?, NoError> { get }

    var permissions:(PresentationGroupCallMuteAction, @escaping(Bool)->Void)->Void { get set }
    
    var displayAsPeers: Signal<[FoundPeer]?, NoError> { get }
    
    func raiseHand()
    func lowerHand()
    func resetListenerLink()

    func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError>
    func toggleIsMuted()
    func setVolume(peerId: PeerId, volume: Int32, sync: Bool)
    func setIsMuted(action: PresentationGroupCallMuteAction)
    func updateMuteState(peerId: PeerId, isMuted: Bool) -> GroupCallParticipantsContext.Participant.MuteState?
    func invitePeer(_ peerId: PeerId) -> Bool
    func updateDefaultParticipantsAreMuted(isMuted: Bool)
    
    func setFullSizeVideo(peerId: PeerId?)
    func makeVideoView(source: UInt32, completion: @escaping (PresentationCallVideoView?) -> Void)
    var incomingVideoSources: Signal<[PeerId: UInt32], NoError> { get }
    
    func requestVideo(deviceId: String)
    func disableVideo()
    func loadMore()

    func joinAsSpeakerIfNeeded(_ joinHash: String)
    func reconnect(as peerId: PeerId) -> Void
    func updateTitle(_ title: String, force: Bool) -> Void
    func setShouldBeRecording(_ shouldBeRecording: Bool, title: String?) -> Void
    
}
