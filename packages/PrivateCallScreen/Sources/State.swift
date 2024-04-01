//
//  File 2.swift
//  
//
//  Created by Mikhail Filimonov on 08.02.2024.
//

import Foundation
import TelegramCore
import Localization
import Postbox
import QuartzCore
import CoreFoundation


public extension PeerCallSessionTerminationReason {
    var recall: Bool {
        let recall:Bool
        switch self {
        case .ended(let reason):
            switch reason {
            case .busy:
                recall = true
            default:
                recall = false
            }
        case .error(let reason):
            switch reason {
            case .disconnected:
                recall = true
            default:
                recall = false
            }
        }
        return recall
    }
}


private extension EnginePeer {
    var compactDisplayTitle: String {
        switch self {
        case let .user(user):
            if let firstName = user.firstName, !firstName.isEmpty {
                return firstName
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return lastName
            } else if let _ = user.phone {
                return ""
            } else {
                return "Deleted Account"
            }
        case let .legacyGroup(group):
            return group.title
        case let .channel(channel):
            return channel.title
        case .secretChat:
            return ""
        }
    }

}


public enum PeerCallSessionError: Equatable {
    case generic
    case privacyRestricted
    case notSupportedByPeer(isVideo: Bool)
    case serverProvided(text: String)
    case disconnected
}

public enum PeerCallSessionEndedType : Equatable {
    case hungUp
    case busy
    case missed
}

public enum PeerCallSessionTerminationReason: Equatable {
    case ended(PeerCallSessionEndedType)
    case error(PeerCallSessionError)
}

enum PeerCallStatusValue: Equatable {
    case text(String, Int32?)
    case timer(Double, Int32?)
    
    var hasTimer: Bool {
        switch self {
        case .timer:
            return true
        default:
            return false
        }
    }
}




public struct ExternalPeerCallState: Equatable {
    public enum State: Equatable {
       case waiting
       case ringing
       case requesting(ringing: Bool)
       case connecting
       case active(startTime: Double, reception: Int32?, emoji: String)
       case reconnecting(startTime: Double, reception: Int32?, emoji: String)
       case terminating
       case terminated(PeerCallSessionTerminationReason?)
   }
   
   
    public enum VideoState: Equatable {
       case notAvailable
       case inactive(Bool)
       case active(Bool)
       case paused(Bool)

   }
   
   
   public enum RemoteAudioState: Equatable {
       case active
       case muted
   }
   
   public enum RemoteBatteryLevel: Equatable {
       case normal
       case low
   }

   
    public enum RemoteVideoState: Equatable {
       case inactive
       case active
       case paused
   }
   
    public var state: State
    public var videoState: VideoState
    public var remoteVideoState: RemoteVideoState
    public var isMuted: Bool
    public var isOutgoingVideoPaused: Bool
    public var remoteAspectRatio: Float
    public var remoteAudioState: RemoteAudioState
    public var remoteBatteryLevel: RemoteBatteryLevel
    public var isScreenCapture: Bool
    public var canBeRemoved: Bool
    public init(state: State, videoState: VideoState, remoteVideoState: RemoteVideoState, isMuted: Bool, isOutgoingVideoPaused: Bool, remoteAspectRatio: Float, remoteAudioState: RemoteAudioState, remoteBatteryLevel: RemoteBatteryLevel, isScreenCapture: Bool, canBeRemoved: Bool) {
        self.state = state
        self.videoState = videoState
        self.remoteVideoState = remoteVideoState
        self.isMuted = isMuted
        self.isOutgoingVideoPaused = isOutgoingVideoPaused
        self.remoteAspectRatio = remoteAspectRatio
        self.remoteAudioState = remoteAudioState
        self.remoteBatteryLevel = remoteBatteryLevel
        self.isScreenCapture = isScreenCapture
        self.canBeRemoved = canBeRemoved
    }
}


extension ExternalPeerCallState.State {
    func statusText(_ accountPeer: EnginePeer?, _ videoState: ExternalPeerCallState.VideoState) -> PeerCallStatusValue {
        let statusValue: PeerCallStatusValue
        switch self {
        case .waiting, .connecting:
            statusValue = .text(L10n.callStatusConnecting, nil)
        case let .requesting(ringing):
            if ringing {
                statusValue = .text(L10n.callStatusRinging, nil)
            } else {
                statusValue = .text(L10n.callStatusRequesting, nil)
            }
        case .terminating:
            statusValue = .text(L10n.callStatusEnded, nil)
        case let .terminated(reason):
            if let reason = reason {
                switch reason {
                case let .ended(type):
                    switch type {
                    case .busy:
                        statusValue = .text(L10n.callStatusBusy, nil)
                    case .hungUp, .missed:
                        statusValue = .text(L10n.callStatusEnded, nil)
                    }
                case .error:
                    statusValue = .text(L10n.callStatusFailed, nil)
                }
            } else {
                statusValue = .text(L10n.callStatusEnded, nil)
            }
        case .ringing:
            if let accountPeer = accountPeer {
                statusValue = .text(L10n.callStatusCallingAccount(accountPeer.addressName ?? accountPeer.compactDisplayTitle), nil)
            } else {
                statusValue = .text(L10n.callStatusCalling, nil)
            }
        case .active(let timestamp, let reception, _), .reconnecting(let timestamp, let reception, _):
            if case .reconnecting = self {
                statusValue = .text(L10n.callStatusConnecting, reception)
            } else {
                statusValue = .timer(timestamp, reception)
            }
        }
        return statusValue
    }
}

enum SmallVideoSource : Equatable {
    case incoming
    case outgoing
}

public struct PeerCallState : Equatable {
    
    public enum SecretKeyViewState : Equatable {
        case revealed
        case concealed
        
        var rev: SecretKeyViewState {
            switch self {
            case .concealed:
                return .revealed
            case .revealed:
                return .concealed
            }
        }
    }
    
    public var peer: EnginePeer?
    public var accountPeer: EnginePeer?
    
    public var secretKeyViewState: SecretKeyViewState = .concealed
    
    var actions: [PeerCallAction] = []
    
    var smallVideo: SmallVideoSource = .outgoing
    
    var statusTooltip: String? = nil
    
    var mouseInside: Bool = true
    
    public var externalState: ExternalPeerCallState = .init(state: .connecting, videoState: .notAvailable, remoteVideoState: .inactive, isMuted: false, isOutgoingVideoPaused: true, remoteAspectRatio: 1.0, remoteAudioState: .active, remoteBatteryLevel: .low, isScreenCapture: false, canBeRemoved: false)
    
    var status: PeerCallStatusValue {
        if self.externalState.canBeRemoved {
            return .text(L10n.callStatusEnded, nil)
        }
        return self.externalState.state.statusText(accountPeer, externalState.videoState)
    }
    
    var isActive: Bool {
        if externalState.canBeRemoved {
            return false
        }
        switch externalState.state {
        case .active, .reconnecting, .connecting, .requesting:
            return true
        default:
            return false
        }
    }
    
    var title: String? {
        if let peer = peer?._asPeer() as? TelegramUser {
            return [peer.firstName, peer.lastName].compactMap { $0 }.joined(separator: " ")
        }
        return nil
    }
    var compactTitle: String {
        if let peer = peer?._asPeer() as? TelegramUser {
            return peer.firstName ?? peer.lastName ?? ""
        }
        return ""
    }
    
    var reception: Int32? {
        switch externalState.state {
        case let .active(_, reception, _):
            return reception
        case let .reconnecting(_, reception, _):
            return reception
        default:
            return nil
        }
    }
    
    var seconds: Int32 {
        switch externalState.state {
        case let .active(referenceTime, _, _):
            return Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
        case let .reconnecting(referenceTime, _, _):
            return Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
        default:
            return 0
        }
    }
    
    var secretKey: String? {
        switch self.externalState.state {
        case .active(_, _, let emoji):
            return emoji
        case .reconnecting(_, _, let emoji):
            return emoji
        default:
            return nil
        }
    }
    
    var stateIndex: Int {
        switch externalState.state {
        case .waiting:
            return 0
        case .ringing:
            return 0
        case .requesting:
            return 0
        case .connecting:
            if seconds > 2 {
                return 2
            } else {
                return 1
            }
        case let .active(_, reception, _):
            if let reception = reception, reception < 2, seconds > 2 {
                return 2
            }
            return 1
        case .reconnecting:
            return 2
        case .terminating:
            return 0
        case .terminated:
            return 0
        }
    }
}
