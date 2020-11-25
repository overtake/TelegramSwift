import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit


enum RequestOrJoinGroupCallResult {
    case success(GroupCallContext)
    case fail
    case samePeer(GroupCallContext)
}


struct PresentationGroupCallState: Equatable {
    public enum NetworkState {
        case connecting
        case connected
    }
    
    public var networkState: NetworkState
    public var isMuted: Bool
    
    public init(
        networkState: NetworkState,
        isMuted: Bool
    ) {
        self.networkState = networkState
        self.isMuted = isMuted
    }
}

struct PresentationGroupCallMemberState: Equatable {
    public var ssrc: UInt32
    public var isSpeaking: Bool
    
    public init(
        ssrc: UInt32,
        isSpeaking: Bool
    ) {
        self.ssrc = ssrc
        self.isSpeaking = isSpeaking
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
    
    func leave() -> Signal<Bool, NoError>
    
    func toggleIsMuted()
    func setIsMuted(_ value: Bool)
    func setCurrentAudioOutput(_ output: AudioSessionOutput)
}
