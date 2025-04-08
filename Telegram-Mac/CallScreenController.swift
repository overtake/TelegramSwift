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



private func mapCallState(_ state: CallState, canBeRemoved: Bool) -> ExternalPeerCallState {
    
    
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
    case let .terminating(callSessionTerminationReason):
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
                case .switchedToConference:
                    reason = .ended(.switchedToConference)
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
        externalState = .terminating(reason)
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
                case .switchedToConference:
                    reason = .ended(.switchedToConference)
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
    
    return .init(state: externalState, videoState: videoState, remoteVideoState: remoteVideoState, isMuted: state.isMuted, isOutgoingVideoPaused: state.isOutgoingVideoPaused, remoteAspectRatio: state.remoteAspectRatio, remoteAudioState: remoteAudioState, remoteBatteryLevel: remoteBatteryLevel, isScreenCapture: state.isScreenCapture, canBeRemoved: canBeRemoved, participants: state.participants, conferenceReference: state.conferenceReference, supportsConferenceCalls: state.supportsConferenceCalls)
}


func callScreen(_ context: AccountContext, _ result:PCallResult) {
    
    switch result {
    case let .samePeer(session), let .success(session):
        
        var getScreen:(()->Window?)? = nil
        
        let arguments: PeerCallArguments = PeerCallArguments(engine: context.engine, peerId: session.peerId, makeAvatar: { view, peer in
            let control = view as? AvatarControl ?? AvatarControl(font: .avatar(17))
            control.setFrameSize(NSMakeSize(120, 120))
            control.userInteractionEnabled = false
            control.setPeer(account: context.account, peer: peer)
            return control
        }, makeParticipants: { previous, participants in
            let view = (previous as? CallParticipantsView) ?? CallParticipantsView(frame: .zero)
            view.update(participants: participants, context: context, animated: false)
            return view
        }, toggleMute: { [weak session] in
            session?.toggleMute()
        }, toggleCamera: { [weak session] callState in
            
            guard let screen = getScreen?() else {
                return
            }
            
            switch callState.videoState {
            case let .active(available), let .paused(available), let .inactive(available):
                if available {
                    if callState.isOutgoingVideoPaused || callState.isScreenCapture || callState.videoState == .inactive(available) {
                        session?.requestVideo()
                    } else {
                        session?.disableVideo()
                    }
                } else {
                    verifyAlert_button(for: screen, information: strings().callCameraError, ok: strings().modalOK, cancel: "", option: strings().requestAccesErrorConirmSettings, successHandler: { result in
                        switch result {
                        case .thrid:
                            openSystemSettings(.camera)
                        default:
                            break
                        }
                    }, presentation: darkAppearance)
                }
            default:
                break
            }
            
        }, toggleScreencast: { [weak session] callState in
            
            guard let screen = getScreen?() else {
                return
            }
            let result = session?.toggleScreenCapture()
            
            if let result = result {
                switch result {
                case .permission:
                    verifyAlert_button(for: screen, information: strings().callScreenError, ok: strings().modalOK, cancel: "", option: strings().requestAccesErrorConirmSettings, successHandler: { result in
                        switch result {
                        case .thrid:
                            openSystemSettings(.sharing)
                        default:
                            break
                        }
                    }, presentation: darkAppearance)
                }
            }
        }, endcall: { [weak session] state in
            
            switch state.state {
            case let .terminated(reason):
                if let reason = reason, reason.recall {
                    session?.setToRemovableState()
                }
            default:
                session?.setToRemovableState()
                _ = session?.hangUpCurrentCall().start()
            }
            
        }, recall: { [weak session] in
            guard let session = session else {
                return
            }
            let redial = phoneCall(context: session.accountContext, peerId: session.peerId, ignoreSame: true) |> deliverOnMainQueue
            
            _ = redial.startStandalone(next: { result in
                callScreen(context, result)
            })
        }, acceptcall: { [weak session] in
            session?.acceptCallSession()
        }, video: { [weak session] isIncoming in
            return session?.makeVideo(isIncoming: isIncoming)
        }, audioLevel: { [weak session] in
            return session?.audioLevel ?? .single(0)
        }, openSettings: { window in
            showModal(with: CallSettingsModalController(context.sharedContext, presentation: darkAppearance), for: window)
        }, upgradeToConference: { [weak session] window in
            if let session {
                let peerIds = [session.peerId]
                _ = selectModalPeers(window: window, context: context, title: strings().voiceChatInviteChannelsTitle, selectedPeerIds: Set(peerIds)).start(next: { [weak session, weak window] peerIds in
                    if let session, let window {
                        _ = session.upgradeToConference(invitePeerIds: peerIds, completion: { groupCall in
                            window.minSize = GroupCallTheme.minFullScreenSize
                        })
                    }
                })
            }
        })
        
        let screen: PeerCallScreen
        if let shared = context.sharedContext.peerCall, shared.onCompletion != nil {
            screen = shared
        } else {
            screen = PeerCallScreen(external: arguments, isConference: session.isIncomingConference)
        }
        
        
        
        screen.update(arguments: arguments)
        screen.show()
        
        session.window = screen.window
        
        screen.contextObject = session
        
        screen.setState(combineLatest(session.state, session.canBeRemoved) |> map { state, canBeRemoved in
            return mapCallState(state, canBeRemoved: canBeRemoved)
        })
        
        screen.onCompletion = {
            context.sharedContext.peerCall = nil
        }
        context.sharedContext.peerCall = screen
        
        getScreen = { [weak screen] in
            return screen?.window
        }
        
    default:
        break
    }
    
}
