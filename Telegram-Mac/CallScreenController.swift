//
//  CallScreenController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 15.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import TelegramCore
import ObjcUtils
import Postbox
import SwiftSignalKit
import TgVoipWebrtc
import TelegramVoip
import ColorPalette
import PrivateCallScreen
import Emoji

private func insertSpacesBetweenEmojis(in text: String) -> String {
    var newString = ""
    var previousCharacterWasEmoji = false

    for character in text {
        if character.isEmoji {
            if previousCharacterWasEmoji {
                // Insert a space before the current emoji
                newString += " "
            }
            previousCharacterWasEmoji = true
        } else {
            previousCharacterWasEmoji = false
        }
        newString += String(character)
    }

    return newString
}



private func mapCallState(_ state: CallState) -> ExternalPeerCallState {
    
    
    let externalState: ExternalPeerCallState.State
    switch state.state {
    case .waiting:
        externalState = .waiting
    case .ringing:
        externalState = .ringing
    case .requesting(let bool):
        externalState = .requesting(ringing: bool)
    case .connecting:
        externalState = .connecting
    case .active(let startTime, let reception, let data):
        externalState = .active(startTime: startTime, reception: reception, emoji: insertSpacesBetweenEmojis(in: ObjcUtils.callEmojies(data)))
    case .reconnecting(let startTime, let reception, let data):
        externalState = .reconnecting(startTime: startTime, reception: reception, emoji: insertSpacesBetweenEmojis(in: ObjcUtils.callEmojies(data)))
    case .terminating:
        externalState = .terminating
    case .terminated(_, let callSessionTerminationReason, _):
        let reason: PeerCallSessionTerminationReason?
        if let callSessionTerminationReason {
            switch callSessionTerminationReason {
            case .ended(let callSessionEndedType):
                switch callSessionEndedType {
                case .hungUp:
                    reason = .ended(.hungUp)
                case .busy:
                    reason = .ended(.busy)
                case .missed:
                    reason = .ended(.missed)
                }
            case .error(let callSessionError):
                switch callSessionError {
                case .generic:
                    reason = .error(.generic)
                case .privacyRestricted:
                    reason = .error(.privacyRestricted)
                case .notSupportedByPeer(let isVideo):
                    reason = .error(.notSupportedByPeer(isVideo: isVideo))
                case .serverProvided(let text):
                    reason = .error(.serverProvided(text: text))
                case .disconnected:
                    reason = .error(.disconnected)
                }
            }
        } else {
            reason = nil
        }
        externalState = .terminated(reason)
    }
    
    let videoState: ExternalPeerCallState.VideoState
    switch state.videoState {
    case .notAvailable:
        videoState = .notAvailable
    case .inactive(let bool):
        videoState = .inactive(bool)
    case .active(let bool):
        videoState = .active(bool)
    case .paused(let bool):
        videoState = .paused(bool)
    }
    let remoteVideoState: ExternalPeerCallState.RemoteVideoState
    switch state.remoteVideoState {
    case .active:
        remoteVideoState = .active
    case .inactive:
        remoteVideoState = .inactive
    case .paused:
        remoteVideoState = .paused
    }
    
    let remoteAudioState: ExternalPeerCallState.RemoteAudioState
    switch state.remoteAudioState {
    case .active:
        remoteAudioState = .active
    case .muted:
        remoteAudioState = .muted
    }
    
    let remoteBatteryLevel: ExternalPeerCallState.RemoteBatteryLevel
    switch state.remoteBatteryLevel {
    case .normal:
        remoteBatteryLevel = .normal
    case .low:
        remoteBatteryLevel = .low
    }
    
    return .init(state: externalState, videoState: videoState, remoteVideoState: remoteVideoState, isMuted: state.isMuted, isOutgoingVideoPaused: state.isOutgoingVideoPaused, remoteAspectRatio: state.remoteAspectRatio, remoteAudioState: remoteAudioState, remoteBatteryLevel: remoteBatteryLevel, isScreenCapture: state.isScreenCapture)
}

private var peerCall: PeerCallScreen?


func callScreen(_ context: AccountContext, _ result:PCallResult) {
    
    
    
    
    switch result {
    case let .samePeer(session), let .success(session):
        let screen = peerCall ?? PeerCallScreen(external: PeerCallArguments(engine: context.engine, peerId: session.peerId, makeAvatar: { view, peer in
            let control = view as? AvatarControl ?? AvatarControl(font: .avatar(17))
            control.setFrameSize(NSMakeSize(120, 120))
            control.userInteractionEnabled = false
            control.setPeer(account: context.account, peer: peer)
            return control
        }, toggleMute: { [weak session] in
            session?.toggleMute()
        }, toggleCamera: {
            
        }, toggleScreencast: {
            
        }, endcall: {
            
        }, recall: {
            
        }))
        screen.show()
        
        screen.setState(session.state |> map {
            mapCallState($0)
        })
        
        peerCall = screen

    default:
        break
    }
    
}
