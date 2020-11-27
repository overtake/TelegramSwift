import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

struct PresentationGroupCallSummaryState: Equatable {
    var info: GroupCallInfo
    var participantCount: Int
    var callState: PresentationGroupCallState
    var topParticipants: [GroupCallParticipantsContext.Participant]
    
    init(
        info: GroupCallInfo,
        participantCount: Int,
        callState: PresentationGroupCallState,
        topParticipants: [GroupCallParticipantsContext.Participant]
    ) {
        self.info = info
        self.participantCount = participantCount
        self.callState = callState
        self.topParticipants = topParticipants
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
}

public struct PresentationGroupCallState: Equatable {
    public enum NetworkState {
        case connecting
        case connected
    }
    
    public var networkState: NetworkState
    public var canManageCall: Bool
    public var adminIds: Set<PeerId>
    public var muteState: GroupCallParticipantsContext.Participant.MuteState?
    
    public init(
        networkState: NetworkState,
        canManageCall: Bool,
        adminIds: Set<PeerId>,
        muteState: GroupCallParticipantsContext.Participant.MuteState?
    ) {
        self.networkState = networkState
        self.canManageCall = canManageCall
        self.adminIds = adminIds
        self.muteState = muteState
    }
}



struct PresentationGroupCallMemberState: Equatable {

    var ssrc: UInt32
    var muteState: GroupCallParticipantsContext.Participant.MuteState?
    var peer: Peer
    var joinTimestamp:Int32
    init(
        ssrc: UInt32,
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        peer: Peer,
        joinTimestamp: Int32
    ) {
        self.ssrc = ssrc
        self.muteState = muteState
        self.peer = peer
        self.joinTimestamp = joinTimestamp
    }

    public static func == (lhs: PresentationGroupCallMemberState, rhs: PresentationGroupCallMemberState) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if lhs.ssrc != rhs.ssrc {
            return false
        }
        if lhs.muteState != rhs.muteState {
            return false
        }
        if lhs.joinTimestamp != rhs.joinTimestamp {
            return false
        }
        return true
    }
}


protocol PresentationGroupCall: class {
    var account: Account { get }
    var sharedContext: SharedAccountContext { get }
    var internalId: CallSessionInternalId { get }
    var peerId: PeerId { get }
    var peer: Peer? { get }
    var canBeRemoved: Signal<Bool, NoError> { get }
    var state: Signal<PresentationGroupCallState, NoError> { get }
    var members: Signal<[PeerId: PresentationGroupCallMemberState], NoError> { get }
    var audioLevels: Signal<[(PeerId, Float)], NoError> { get }
    var myAudioLevel: Signal<Float, NoError> { get }
    var invitedPeers: Signal<Set<PeerId>, NoError> { get }

    var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> { get }

    func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError>
    
    func toggleIsMuted()
    func setIsMuted(action: PresentationGroupCallMuteAction)
    func updateMuteState(peerId: PeerId, isMuted: Bool)
    func invitePeer(_ peerId: PeerId)
}
