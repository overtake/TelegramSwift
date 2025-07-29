//
//  GroupCallController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import ColorPalette
import TelegramCore
import HotKey
import TgVoipWebrtc
import InAppSettings
import ObjcUtils

final class GroupCallsConfig {
    let videoLimit: Int
    init(_ config: AppConfiguration) {
        if let data = config.data, let value = data["groupcall_video_participants_max"] as? Double {
            self.videoLimit = Int(value)
        } else {
            videoLimit = 30
        }
    }
}

private struct Tooltips : Equatable {
    var dismissed: Set<GroupCallUIState.ControlsTooltip.`Type`>
    var speachDetected: Bool
    
    static var initialValue: Tooltips {
        return Tooltips(dismissed: Set(), speachDetected: false)
    }
}

final class GroupCallUIArguments {
    let leave:()->Void
    let settings:()->Void
    let invite:(PeerId)->Void
    let mute:(PeerId, Bool)->Void
    let toggleSpeaker:()->Void
    let remove:(Peer)->Void
    let openInfo: (Peer)->Void
    let inviteMembers:()->Void
    let shareInviteLinks:()->Void
    let shareSource:(VideoSourceMacMode, Bool)->Void
    let takeVideo:(PeerId, VideoSourceMacMode?, GroupCallUIState.ActiveVideo.Mode)->NSView?
    let isSharingVideo:(PeerId)->Bool
    let isSharingScreencast:(PeerId)->Bool
    let canUnpinVideo:(PeerId, VideoSourceMacMode)->Bool
    let setVolume: (PeerId, Double, Bool) -> Void
    let pinVideo:(DominantVideo)->Void
    let unpinVideo:()->Void
    let isPinnedVideo:(PeerId, VideoSourceMacMode)->Bool
    let getAccountPeerId: ()->PeerId?
    let getAccount:()->Account
    let cancelShareScreencast: ()->Void
    let cancelShareVideo: ()->Void
    let toggleRaiseHand:()->Void
    let recordClick:(PresentationGroupCallState)->Void
    let audioLevel:(PeerId)->Signal<Float?, NoError>?
    let startVoiceChat:()->Void
    let toggleReminder:(Bool)->Void
    let toggleScreenMode:()->Void
    let switchCamera:(PeerGroupCallData)->Void
    let togglePeersHidden:()->Void
    let contextMenuItems:(PeerGroupCallData)->[ContextMenuItem]
    let dismissTooltip:(GroupCallUIState.ControlsTooltip)->Void
    let focusVideo: (String?)->Void
    let takeTileView:() -> (NSSize, GroupCallTileView)?
    let getSource:(VideoSourceMacMode)->VideoSourceMac?
    let toggleShowConferenceKey: (Bool)->Void
    let getConferenceLimit: ()->Int32
    init(leave:@escaping()->Void,
    settings:@escaping()->Void,
    invite:@escaping(PeerId)->Void,
    mute:@escaping(PeerId, Bool)->Void,
    toggleSpeaker:@escaping()->Void,
    remove:@escaping(Peer)->Void,
    openInfo: @escaping(Peer)->Void,
    inviteMembers:@escaping()->Void,
    shareInviteLinks:@escaping()->Void,
    shareSource: @escaping(VideoSourceMacMode, Bool)->Void,
    takeVideo:@escaping(PeerId, VideoSourceMacMode?, GroupCallUIState.ActiveVideo.Mode)->NSView?,
    isSharingVideo: @escaping(PeerId)->Bool,
    isSharingScreencast: @escaping(PeerId)->Bool,
    canUnpinVideo:@escaping(PeerId, VideoSourceMacMode)->Bool,
    pinVideo:@escaping(DominantVideo)->Void,
    unpinVideo:@escaping()->Void,
    isPinnedVideo:@escaping(PeerId, VideoSourceMacMode)->Bool,
    setVolume: @escaping(PeerId, Double, Bool)->Void,
    getAccountPeerId: @escaping()->PeerId?,
    getAccount: @escaping() -> Account,
    cancelShareScreencast: @escaping()->Void,
    cancelShareVideo: @escaping()->Void,
    toggleRaiseHand:@escaping()->Void,
    recordClick:@escaping(PresentationGroupCallState)->Void,
    audioLevel:@escaping(PeerId)->Signal<Float?, NoError>?,
    startVoiceChat:@escaping()->Void,
    toggleReminder:@escaping(Bool)->Void,
    toggleScreenMode:@escaping()->Void,
    switchCamera:@escaping(PeerGroupCallData)->Void,
    togglePeersHidden: @escaping()->Void,
    contextMenuItems:@escaping(PeerGroupCallData)->[ContextMenuItem],
    dismissTooltip:@escaping(GroupCallUIState.ControlsTooltip)->Void,
    focusVideo: @escaping(String?)->Void,
    takeTileView:@escaping() -> (NSSize, GroupCallTileView)?,
    getSource:@escaping(VideoSourceMacMode)->VideoSourceMac?,
    toggleShowConferenceKey: @escaping(Bool)->Void,
    getConferenceLimit: @escaping()->Int32) {
        self.leave = leave
        self.invite = invite
        self.mute = mute
        self.settings = settings
        self.toggleSpeaker = toggleSpeaker
        self.remove = remove
        self.openInfo = openInfo
        self.inviteMembers = inviteMembers
        self.shareInviteLinks = shareInviteLinks
        self.shareSource = shareSource
        self.takeVideo = takeVideo
        self.isSharingVideo = isSharingVideo
        self.isSharingScreencast = isSharingScreencast
        self.canUnpinVideo = canUnpinVideo
        self.pinVideo = pinVideo
        self.unpinVideo = unpinVideo
        self.isPinnedVideo = isPinnedVideo
        self.setVolume = setVolume
        self.getAccountPeerId = getAccountPeerId
        self.getAccount = getAccount
        self.cancelShareVideo = cancelShareVideo
        self.cancelShareScreencast = cancelShareScreencast
        self.toggleRaiseHand = toggleRaiseHand
        self.recordClick = recordClick
        self.audioLevel = audioLevel
        self.startVoiceChat = startVoiceChat
        self.toggleReminder = toggleReminder
        self.toggleScreenMode = toggleScreenMode
        self.switchCamera = switchCamera
        self.togglePeersHidden = togglePeersHidden
        self.contextMenuItems = contextMenuItems
        self.dismissTooltip = dismissTooltip
        self.focusVideo = focusVideo
        self.takeTileView = takeTileView
        self.getSource = getSource
        self.toggleShowConferenceKey = toggleShowConferenceKey
        self.getConferenceLimit = getConferenceLimit
    }
}




struct PeerGroupCallData : Equatable, Comparable {

    
    struct AudioLevel {
        let timestamp: Int32
        let value: Float
    }

    struct PinnedMode : Equatable {
        let mode: VideoSourceMacMode
        let temporary: Bool
        
        var viceVersa: VideoSourceMacMode {
            return mode.viceVersa
        }
    }
    
    struct ActiveVideo : Hashable {
        let endpoint: String
        let index: Int
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.endpoint)
            hasher.combine(self.index)
        }
    }
    
    let peer: Peer
    let state: GroupCallParticipantsContext.Participant?
    let isSpeaking: Bool
    let inviteState: PresentationGroupCallInvitedPeer?
    let unsyncVolume: Int32?
    let accountPeerId: PeerId
    let accountAbout: String?
    let canManageCall: Bool
    let hideWantsToSpeak: Bool
    let activityTimestamp: Int
    let firstTimestamp: Int32
    let videoMode: Bool
    let isVertical: Bool
    let hasVideo: Bool
    let activeVideos:Set<ActiveVideo>
    let adminIds: Set<PeerId>
    let isFullscreen: Bool
    
    var isInvited: Bool {
        return self.inviteState != nil
    }
    
    let videoEndpointId: String?
    let presentationEndpointId: String?

    var isRaisedHand: Bool {
        return self.state?.hasRaiseHand == true
    }
    var wantsToSpeak: Bool {
        return isRaisedHand && !hideWantsToSpeak
    }
    
    var videoEndpoint: String? {
        return activeVideos.first(where: { $0.endpoint == videoEndpointId })?.endpoint
    }
    var presentationEndpoint: String? {
        return activeVideos.first(where: { $0.endpoint == presentationEndpointId })?.endpoint
    }
    
    var about: String? {
        let about: String?
        if self.peer.id == accountPeerId {
            about = accountAbout
        } else {
            about = self.state?.about
        }
        if let about = about, about.isEmpty {
            return nil
        } else {
            return about
        }
    }
    
    func isVideoPaused(_ endpointId: String?) -> Bool {
        if self.state?.videoDescription?.endpointId == endpointId {
            return self.state?.videoDescription?.isPaused == true
        }
        if self.state?.presentationDescription?.endpointId == endpointId {
            return self.state?.presentationDescription?.isPaused == true
        }
        return false
    }
    
    func videoStatus(_ mode: VideoSourceMacMode) -> String {
        var string:String = strings().voiceChatStatusListening
        switch mode {
        case .video:
            string = self.status.0
            if string == self.about {
                string = strings().voiceChatStatusListening
            }
        case .screencast:
            string = strings().voiceChatStatusScreensharing
        }
        return string
    }
    
    var status: (String, NSColor) {
        var string:String = strings().peerStatusRecently
        var color:NSColor = GroupCallTheme.grayStatusColor
        if let state = state {
            if wantsToSpeak, let _ = state.muteState {
                string = strings().voiceChatStatusWantsSpeak
                color = GroupCallTheme.blueStatusColor
            } else if let muteState = state.muteState, muteState.mutedByYou {
                string = muteState.mutedByYou ? strings().voiceChatStatusMutedForYou : strings().voiceChatStatusMuted
                color = GroupCallTheme.speakLockedColor
            } else if isSpeaking, state.muteState == nil {
                string = strings().voiceChatStatusSpeaking
                color = GroupCallTheme.greenStatusColor
            } else {
                if let about = about {
                    string = about
                    color = GroupCallTheme.grayStatusColor
                } else {
                    string = strings().voiceChatStatusListening
                    color = GroupCallTheme.grayStatusColor
                }
            }
        } else if peer.id == accountPeerId {
            if let about = about {
                string = about
                color = GroupCallTheme.grayStatusColor.withAlphaComponent(0.6)
            } else {
                string = strings().voiceChatStatusConnecting.lowercased()
                color = GroupCallTheme.grayStatusColor.withAlphaComponent(0.6)
            }
        } else if let inviteState {
            switch inviteState.state {
            case .requesting:
                string = strings().voiceChatStatusInvited
            case .ringing:
                string = strings().voiceChatStatusCalling
            case .connecting:
                string = strings().voiceChatStatusConnecting
            case .none:
                string = strings().voiceChatStatusInvited
            }
        }
        return (string, color)
    }
    
    static func ==(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if lhs.activityTimestamp != rhs.activityTimestamp {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.isSpeaking != rhs.isSpeaking {
            return false
        }
        if lhs.inviteState != rhs.inviteState {
            return false
        }
        if lhs.unsyncVolume != rhs.unsyncVolume {
            return false
        }
        if lhs.firstTimestamp != rhs.firstTimestamp {
            return false
        }
        if lhs.accountPeerId != rhs.accountPeerId {
            return false
        }
        if lhs.accountAbout != rhs.accountAbout {
            return false
        }
        if lhs.hideWantsToSpeak != rhs.hideWantsToSpeak {
            return false
        }
        if lhs.videoMode != rhs.videoMode {
            return false
        }
        if lhs.isVertical != rhs.isVertical {
            return false
        }
        if lhs.hasVideo != rhs.hasVideo {
            return false
        }
        if lhs.activeVideos != rhs.activeVideos {
            return false
        }
        if lhs.adminIds != rhs.adminIds {
            return false
        }
        
        if lhs.videoEndpointId != rhs.videoEndpointId {
            return false
        }
        if lhs.presentationEndpointId != rhs.presentationEndpointId {
            return false
        }
        if lhs.isFullscreen != rhs.isFullscreen {
            return false
        }
        return true
    }
    
    static func <(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        if lhs.activityTimestamp != rhs.activityTimestamp {
            return lhs.activityTimestamp > rhs.activityTimestamp
        }
        return lhs.firstTimestamp > rhs.firstTimestamp
    }
}





private func _id_peer_id(_ data: PeerGroupCallData, endpoint: String? = nil) -> InputDataIdentifier {
    if let endpoint = endpoint {
        return InputDataIdentifier("_peer_id_\(data.peer.id.toInt64())_\(endpoint)")
    } else {
        return InputDataIdentifier("_peer_id_\(data.peer.id.toInt64())_")
    }
}

private func makeState(previous:GroupCallUIState?, peerView: PeerView?, state: PresentationGroupCallState, isMuted: Bool, invitedPeers: [(Peer, PresentationGroupCallInvitedPeer)], peerStates: PresentationGroupCallMembers?, myAudioLevel: Float, summaryState: PresentationGroupCallSummaryState?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, accountPeer: (Peer, String?), unsyncVolumes: [PeerId: Int32], pinnedData: GroupCallUIState.PinnedData, hideWantsToSpeak: Set<PeerId>, isFullScreen: Bool, videoSources: VideoSources, activeVideoViews: [GroupCallUIState.ActiveVideo], hideParticipants: Bool, tooltips: Tooltips, version: Int, isStream: Bool, windowIsFullscreen: Bool, initialTimestamp: TimeInterval, showConferenceKey: Bool, e2eEncryptionKeyHash: Data?) -> GroupCallUIState {
    
    var memberDatas: [PeerGroupCallData] = []
    
    let accountPeerId = accountPeer.0.id
    let accountPeerAbout = accountPeer.1
    var activeParticipants: [GroupCallParticipantsContext.Participant] = []
    
    activeParticipants = peerStates?.participants ?? []
    var index: Int = 0
    let startIndex: Int = (Int.max - 10000000000)
    
   
    
    var current: DominantVideo?
    
    let dominantSpeaker = pinnedData.permanent ?? pinnedData.focused?.id
    let videoExists = activeVideoViews.contains(where: { $0.endpointId == dominantSpeaker && $0.mode == .main })
    if let dominantSpeaker = dominantSpeaker, videoExists {
        let peer = activeParticipants.first(where: { $0.videoEndpointId == dominantSpeaker || $0.presentationEndpointId == dominantSpeaker })
        
        if let peer = peer, let participantPeer = peer.peer {
            let pinMode: DominantVideo.PinMode = dominantSpeaker == pinnedData.permanent ? .permanent : .focused
            current = .init(participantPeer.id, dominantSpeaker, peer.videoEndpointId == dominantSpeaker ? .video : .screencast, pinMode)
        }
    }
    
    
    func hasVideo(_ peerId: PeerId) -> Bool {
        return activeParticipants.first(where: { participant in
            if participant.id != .peer(peerId) {
                return false
            }
            if let endpointId = participant.presentationEndpointId {
                if activeVideoViews.contains(where: { $0.endpointId == endpointId && $0.mode == .list }) {
                    return true
                }
            }
            if let endpointId = participant.videoEndpointId {
                if activeVideoViews.contains(where: { $0.endpointId == endpointId && $0.mode == .list }) {
                    return true
                }
            }
            return false
        }) != nil
    }
    
    
    if !activeParticipants.contains(where: { $0.id == .peer(accountPeerId) }) {

        memberDatas.append(PeerGroupCallData(peer: accountPeer.0, state: nil, isSpeaking: false, inviteState: nil, unsyncVolume: unsyncVolumes[accountPeerId], accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(accountPeerId), activityTimestamp: startIndex - 1 - index, firstTimestamp: 0, videoMode: !activeVideoViews.isEmpty, isVertical: false, hasVideo: hasVideo(accountPeerId), activeVideos: Set(), adminIds: state.adminIds, isFullscreen: isFullScreen, videoEndpointId: nil, presentationEndpointId: nil))
        index += 1
    }

    let addMember:(GroupCallParticipantsContext.Participant, Int, Bool)->Void = { value, activityIndex, isVertical in
        
        guard let participantPeer = value.peer?._asPeer() else {
            return
        }
        
        var isSpeaking = peerStates?.speakingParticipants.contains(participantPeer.id) ?? false
        if .peer(accountPeerId) == value.id, isMuted {
            isSpeaking = false
        }
        let activeVideos = Set(activeVideoViews.filter({ active in
            return active.endpointId == value.presentationEndpointId || active.endpointId == value.videoEndpointId
        }).map { PeerGroupCallData.ActiveVideo(endpoint: $0.endpointId, index: $0.index) })
        
        
        
        memberDatas.append(PeerGroupCallData(peer: participantPeer, state: value, isSpeaking: isSpeaking, inviteState: nil, unsyncVolume: unsyncVolumes[participantPeer.id], accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(participantPeer.id), activityTimestamp: activityIndex, firstTimestamp: value.joinTimestamp, videoMode: !activeVideoViews.isEmpty, isVertical: isVertical, hasVideo: hasVideo(participantPeer.id), activeVideos: activeVideos, adminIds: state.adminIds, isFullscreen: isFullScreen, videoEndpointId: value.videoEndpointId, presentationEndpointId: value.presentationEndpointId))
    }
    
    var indexes:[PeerId: Int] = [:]
    
    for value in activeParticipants {
        if let participantPeer = value.peer {
            var peerIndex = startIndex - 1 - index
            if activeVideoViews.contains(where: { $0.endpointId == value.videoEndpointId || $0.endpointId == value.presentationEndpointId }) {
                peerIndex += 1000
            }
            indexes[participantPeer.id] = peerIndex
            index += 1
        }
    }
    
    
    let vertical = activeParticipants.filter { member in
        guard let peer = member.peer else {
            return false
        }
        var isVertical = isFullScreen && current != nil && hasVideo(peer.id)
        if isVertical, current?.peerId == peer.id {
            if member.videoEndpointId == nil || member.presentationEndpointId == nil {
                isVertical = false
            }
        }
        return isVertical
    }
    let rest = activeParticipants.filter { member in
        return !vertical.contains(where: { $0.id == member.id })
    }
    
    
    for value in vertical {
        if let peer = value.peer {
            var activityIndex: Int = indexes[peer.id]!
            if let activeVideo = activeVideoViews.first(where: { $0.endpointId == value.presentationEndpointId }) {
                activityIndex += (10000000 + (Int.max - activeVideo.index))
            }
            if let activeVideo = activeVideoViews.first(where: { $0.endpointId == value.videoEndpointId }) {
                activityIndex += (1000000 + (Int.max - activeVideo.index))
            }
            addMember(value, activityIndex, true)
        }
    }
    for value in rest {
        if let peer = value.peer {
            addMember(value, indexes[peer.id]!, false)
        }
    }

    
    for invited in invitedPeers {
        if !activeParticipants.contains(where: { $0.id == .peer(invited.0.id) }) {
            memberDatas.append(PeerGroupCallData(peer: invited.0, state: nil, isSpeaking: false, inviteState: invited.1, unsyncVolume: nil, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: false, activityTimestamp: startIndex - 1 - index, firstTimestamp: 0, videoMode: !activeVideoViews.isEmpty, isVertical: false, hasVideo: false, activeVideos: Set(), adminIds: state.adminIds, isFullscreen: isFullScreen, videoEndpointId: nil, presentationEndpointId: nil))
            index += 1
        }
    }

    
    let mode: GroupCallUIState.Mode
    let isVideoEnabled = summaryState?.info?.isVideoEnabled ?? false
    
    let main = activeParticipants.first(where: { $0.id == .peer(accountPeerId) })

    if isStream || state.isConference {
        mode = .video
    } else {
        if main?.joinedVideo == false {
            mode = .voice
        } else {
            switch isVideoEnabled || !videoSources.isEmpty || !activeVideoViews.isEmpty  {
            case true:
                mode = .video
            case false:
                mode = .voice
            }
        }
    }
    
    var tooltipSpeaker: PeerGroupCallData? = nil
    if !activeVideoViews.isEmpty && isFullScreen && hideParticipants {
        if current != nil {
            if let previous = previous?.tooltipSpeaker {
                let member = memberDatas.first(where: { $0.peer.id == previous.peer.id })
                if let member = member, member.isSpeaking, member.hasVideo {
                    if current?.peerId != previous.peer.id {
                        tooltipSpeaker = previous
                    }
                }
            }
            if tooltipSpeaker == nil {
                tooltipSpeaker = memberDatas.first(where: { $0.isSpeaking && $0.hasVideo && $0.peer.id != $0.accountPeerId && $0.peer.id != current?.peerId })
            }
            
        }
        if tooltipSpeaker == nil && current == nil {
            tooltipSpeaker = memberDatas.first(where: { $0.isSpeaking && $0.hasVideo && $0.peer.id != $0.accountPeerId && $0.peer.id != current?.peerId && $0.videoEndpoint == nil && $0.presentationEndpointId == nil })
        }
    }
    
    var controlsTooltip: GroupCallUIState.ControlsTooltip? = previous?.controlsTooltip
    
    
    if let current = controlsTooltip, tooltips.dismissed.contains(current.type) {
        controlsTooltip = nil
    }
    
    if controlsTooltip == nil {
        if let member = memberDatas.first(where: { $0.peer.id == $0.accountPeerId }) {
            if member.isSpeaking, !member.hasVideo, !activeVideoViews.isEmpty {
                if !tooltips.dismissed.contains(.camera) {
                    controlsTooltip = .init(type: .camera, timestamp: Date().timeIntervalSince1970)
                }
            }
        }
    }
        
    if controlsTooltip == nil {
        if tooltips.speachDetected, !tooltips.dismissed.contains(.micro) {
            controlsTooltip = .init(type: .micro, timestamp: Date().timeIntervalSince1970)
        }
    }
    
    if let current = controlsTooltip, current.timestamp + 30 < Date().timeIntervalSince1970 {
        controlsTooltip = nil
    }
    
    if state.networkState == .connecting {
        controlsTooltip = nil
    }
    
    var encryptionKeyEmoji: [String]?
    if let e2eEncryptionKeyHash, e2eEncryptionKeyHash.count >= 32 {
        let value = ObjcUtils.callEmojies(e2eEncryptionKeyHash.prefix(32))
        encryptionKeyEmoji = value.emojis
    }

        
    return GroupCallUIState(memberDatas: memberDatas.sorted(by: <), state: state, isMuted: isMuted, summaryState: summaryState, myAudioLevel: myAudioLevel, peer: peerView.flatMap { peerViewMainPeer($0) }, cachedData: peerView?.cachedData as? CachedChannelData, voiceSettings: voiceSettings, isWindowVisible: isWindowVisible, dominantSpeaker: current, pinnedData: pinnedData, isFullScreen: isFullScreen, mode: mode, videoSources: videoSources, version: version, activeVideoViews: activeVideoViews.sorted(by: { $0.index < $1.index }), hideParticipants: hideParticipants || isStream, isVideoEnabled: main?.joinedVideo ?? summaryState?.info?.isVideoEnabled ?? false, tooltipSpeaker: tooltipSpeaker, controlsTooltip: controlsTooltip, dismissedTooltips: tooltips.dismissed, videoJoined: main?.joinedVideo ?? isVideoEnabled, isStream: isStream, windowIsFullscreen: windowIsFullscreen, initialTimestamp: initialTimestamp, isConference: state.isConference, showConferenceKey: showConferenceKey, encryptionKeyEmoji: encryptionKeyEmoji)
}


private func peerEntries(state: GroupCallUIState, account: Account, arguments: GroupCallUIArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    let index: Int32 = 0
    
    let conferenceLimit = arguments.getConferenceLimit()
    
    if state.isStream {
        return []
    }
    
    let members = state.memberDatas

    var canInvite: Bool = !members.contains(where: { $0.isVertical })
    
    if canInvite, state.isConference {
        if members.count == conferenceLimit {
            canInvite = false
        }
    }
    
    let pushInvite: ()->Void = {
        if canInvite {
            struct Tuple : Equatable {
                let viewType: GeneralViewType
                let videoMode: Bool
                let text: String
            }
            
            let viewType: GeneralViewType
            if !state.isConference {
                if entries.isEmpty {
                    viewType = GeneralViewType.singleItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 0, 0))
                } else {
                    viewType = GeneralViewType.firstItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 0, 0))
                }
            } else {
                if entries.isEmpty {
                    viewType = GeneralViewType.firstItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 0, 0))
                } else {
                    viewType = GeneralViewType.innerItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 0, 0))
                }
            }
            
            let tuple = Tuple(viewType: viewType, videoMode: false, text: state.isConference ? strings().voiceChatInviteAddMember : strings().voiceChatInviteInviteMembers)
            
            entries.append(.custom(sectionId: 0, index: index, value: .none, identifier: InputDataIdentifier("invite"), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return GroupCallInviteRowItem(initialSize, height: 42, stableId: stableId, text: tuple.text, videoMode: tuple.videoMode, share: false, viewType: viewType, action: arguments.inviteMembers)
            }))
            
            if state.isConference {
                
                let viewType = GeneralViewType.lastItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 0, 0))
                let tuple = Tuple(viewType: viewType, videoMode: false, text: strings().voiceChatShareInviteLink)

                entries.append(.custom(sectionId: 0, index: index, value: .none, identifier: InputDataIdentifier("share_invite"), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return GroupCallInviteRowItem(initialSize, height: 42, stableId: stableId, text: tuple.text, videoMode: tuple.videoMode, share: true, viewType: viewType, action: arguments.shareInviteLinks)
                }))
            }
        }
    }
    
    if !state.isConference {
        pushInvite()
    }
    
    
    for (i, data) in members.enumerated() {

        var drawLine = i != members.count - 1
        
        if state.isConference, canInvite {
            drawLine = true
        }
        

        var viewType: GeneralViewType = bestGeneralViewType(members, for: i)
        if i == 0, canInvite {
            viewType = i != members.count - 1 ? .innerItem : .lastItem
        } else if !canInvite, !data.isVertical, i > 0 {
            if members[i - 1].isVertical {
                viewType = i != members.count - 1 ? .firstItem : .singleItem
            }
        }

        struct Tuple : Equatable {
            let drawLine: Bool
            let data: PeerGroupCallData
            let canManageCall:Bool
            let adminIds: Set<PeerId>
            let viewType: GeneralViewType
            let baseEndpoint: String?
        }
        
        var duplicates:[(InputDataIdentifier, String?)] = []
        
        if data.isVertical {
            if let endpoint = data.presentationEndpoint {
                if state.dominantSpeaker?.endpointId != endpoint {
                    duplicates.append((_id_peer_id(data, endpoint: endpoint), endpoint))
                }
            }
            if let endpoint = data.videoEndpoint {
                if state.dominantSpeaker?.endpointId != endpoint {
                    duplicates.append((_id_peer_id(data, endpoint: endpoint), endpoint))
                }
            }
        } else {
            duplicates.append((_id_peer_id(data), nil))
        }

        
       
        for (i, (stableId, baseEndpoint)) in duplicates.enumerated() {
            
            let tuple = Tuple(drawLine: drawLine, data: data, canManageCall: state.state.canManageCall, adminIds: state.state.adminIds, viewType: viewType, baseEndpoint: baseEndpoint)

            struct TupleIndex {
                let data: PeerGroupCallData
                let index: Int
            }
            
            let index = TupleIndex(data: data, index: i)
            
            let comparable = InputDataComparableIndex(data: index, compare: { lhs, rhs in
                let lhs = lhs as? TupleIndex
                let rhs = rhs as? TupleIndex
                if let lhs = lhs, let rhs = rhs {
                    if lhs.data == rhs.data {
                        return lhs.index < rhs.index
                    } else {
                        return lhs.data < rhs.data
                    }
                } else {
                    return false
                }
            }, equatable: { lhs, rhs in
                let lhs = lhs as? TupleIndex
                let rhs = rhs as? TupleIndex
                if let lhs = lhs, let rhs = rhs {
                    return lhs.data == rhs.data && lhs.index == rhs.index
                } else {
                    return false
                }
            })
            
            entries.append(.custom(sectionId: 0, index: 1, value: .none, identifier: stableId, equatable: InputDataEquatable(tuple), comparable: comparable, item: { initialSize, stableId in
                return GroupCallParticipantRowItem(initialSize, stableId: stableId, account: account, data: tuple.data, baseEndpoint: tuple.baseEndpoint, canManageCall: tuple.canManageCall, inviteState: tuple.data.inviteState, isLastItem: false, drawLine: drawLine, viewType: viewType, action: {
                    arguments.openInfo(data.peer)
                }, invite: arguments.invite, contextMenu: {
                    return .single(arguments.contextMenuItems(tuple.data))
                }, takeVideo: arguments.takeVideo, audioLevel: arguments.audioLevel, focusVideo: arguments.focusVideo)
            }))
        }
        

    }
    
    if state.isConference {
        pushInvite()
    }

    return entries
}



final class GroupCallUIController : ViewController {
    
    final class UIData {
        let call: PresentationGroupCall
        let peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager
        init(call: PresentationGroupCall, peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager) {
            self.call = call
            self.peerMemberContextsManager = peerMemberContextsManager
        }
    }
    private let data: UIData
    private let disposable = MetaDisposable()
    private let pushToTalkDisposable = MetaDisposable()
    private let requestPermissionDisposable = MetaDisposable()
    private let voiceSourcesDisposable = MetaDisposable()
    private var pushToTalk: PushToTalk?
    private let actionsDisposable = DisposableSet()
    private var canManageCall: Bool = false
    private let connecting = MetaDisposable()
    private let isFullScreen = ValuePromise(false, ignoreRepeated: true)
    private let showConferenceKey = ValuePromise(false, ignoreRepeated: true)
    private weak var sharing: DesktopCapturerWindow?
    private var statusBar: GroupCallStatusBar?
    private var requestedVideoSources = Set<String>()
    private var videoViews: [(DominantVideo, GroupCallUIState.ActiveVideo.Mode, GroupVideoView)] = []

    private var idleTimer: SwiftSignalKit.Timer?
//    private var speakController: MicroListenerContext
    
    let size: ValuePromise<NSSize> = ValuePromise(.zero, ignoreRepeated: true)
    
    
    private let tooltips:Atomic<Tooltips> = Atomic(value: Tooltips.initialValue)
    private let tooltipsValue:ValuePromise<Tooltips> = ValuePromise(Tooltips.initialValue, ignoreRepeated: true)
    private func updateTooltips(_ f: (Tooltips)->Tooltips)->Void {
        tooltipsValue.set(tooltips.modify(f))
    }
    

    
    var disableSounds: Bool = false
    init(_ data: UIData, size: NSSize) {
        self.data = data
//        self.speakController = MicroListenerContext(devices: data.call.sharedContext.devicesContext, accountManager: data.call.sharedContext.accountManager)
        super.init(frame: NSMakeRect(0, 0, size.width, size.height))
        bar = .init(height: 0)
        isFullScreen.set(size.width >= GroupCallTheme.fullScreenThreshold)
        self.size.set(size)
    }
    
    
    override func viewDidResized(_ size: NSSize) {
        
        
    }

    @objc private func _viewFrameChanged(_ notification:Notification) {
        let size = self.genericView.frame.size
        _ = self.atomicSize.swap(genericView.peersTable.frame.size)
        self.isFullScreen.set(size.width >= GroupCallTheme.fullScreenThreshold)
        self.size.set(size)
    }
    
    override func defaultInitializer() -> NSView {
        return GroupCallView(frame: _frameRect, callMode: self.data.call.isConference ? .video : .voice)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(_viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: genericView.peersTable)
        
        
        let dominantSpeakerSignal:ValuePromise<GroupCallUIState.PinnedData> = ValuePromise(GroupCallUIState.PinnedData(), ignoreRepeated: true)
        let dominantSpeakerValue:Atomic<GroupCallUIState.PinnedData> = Atomic(value: GroupCallUIState.PinnedData())
        let updateDominant:((GroupCallUIState.PinnedData)->GroupCallUIState.PinnedData)->Void = { f in
            dominantSpeakerSignal.set(dominantSpeakerValue.modify(f))
        }
        
        
        let hideParticipantsValue:Atomic<Bool> = Atomic(value: false)
        let hideParticipants:Promise<Bool> = Promise(false)
        let updateHideParticipants:((Bool)->Bool)->Void = { f in
            hideParticipants.set(.single(hideParticipantsValue.modify(f)))
        }
        
        
        let callState: ValuePromise<GroupCallUIState> = ValuePromise(ignoreRepeated: true)
        
        
        
        struct ActiveVideos : Equatable {
            var set: [GroupCallUIState.ActiveVideo]
            var index: Int
        }
        let activeVideoViewsValue:Atomic<ActiveVideos> = Atomic(value: ActiveVideos(set: [], index: Int.max))
        let activeVideoViews = Promise(ActiveVideos(set: [], index: Int.max))
        let updateActiveVideoViews:((ActiveVideos)->ActiveVideos)->Void = { f in
            let updated = activeVideoViewsValue.modify(f)
            activeVideoViews.set(.single(updated) |> delay(0.15, queue: .mainQueue()))
        }
                
        let actionsDisposable = self.actionsDisposable
                
        let peerId = self.data.call.peerId
        let account = self.data.call.account
        let context = self.data.call.accountContext

        
        
     
        let displayedRaisedHandsPromise = ValuePromise<Set<PeerId>>([], ignoreRepeated: true)
        let displayedRaisedHands: Atomic<Set<PeerId>> = Atomic(value: [])
        
        var raisedHandDisplayDisposables: [PeerId: Disposable] = [:]

        let updateDisplayedRaisedHands:(@escaping(Set<PeerId>)->Set<PeerId>)->Void = { f in
            _ = displayedRaisedHands.modify(f)
        }
        
        guard let window = self.navigationController?.window else {
            fatalError()
        }
        let animate: Signal<Bool, NoError> = window.takeOcclusionState |> map {
            $0.contains(.visible)
        }
        self.pushToTalk = PushToTalk(sharedContext: data.call.sharedContext, window: window)
        let sharedContext = self.data.call.sharedContext
        let unsyncVolumes = ValuePromise<[PeerId: Int32]>([:])
        var askedForSpeak: Bool = false
        
        var contextMenuItems:((PeerGroupCallData)->[ContextMenuItem])? = nil
        
        let arguments = GroupCallUIArguments(leave: { [weak self] in
            guard let `self` = self, let window = self.window else {
                return
            }
            if self.canManageCall {
                verifyAlert(for: window, header: strings().voiceChatEndTitle, information: strings().voiceChatEndText, ok: strings().voiceChatEndOK, option: strings().voiceChatEndThird, optionIsSelected: false, successHandler: {
                    [weak self] result in
                    _ = self?.data.call.sharedContext.endGroupCall(terminate: result == .thrid).start()
                }, presentation: darkAppearance)
            } else {
                _ = self.data.call.sharedContext.endGroupCall(terminate: false).start()
            }
        }, settings: { [weak self] in
            guard let `self` = self else {
                return
            }
            self.navigationController?.push(GroupCallSettingsController(sharedContext: sharedContext, context: context, callState: callState.get(), call: self.data.call))
        }, invite: { [weak self] peerId in
            let invite = self?.data.call.invitePeer(peerId, isVideo: false)
            
            if invite == false {
                var bp = 0
                bp += 1
            }
        }, mute: { [weak self] peerId, isMuted in
            _ = self?.data.call.updateMuteState(peerId: peerId, isMuted: isMuted)
        }, toggleSpeaker: { [weak self] in
            if let value = self?.genericView.state?.isMuted {
                self?.sharing?.updateDefaultMuted(!value)
            }
            self?.data.call.toggleIsMuted()
        }, remove: { [weak self] peer in
            guard let window = self?.window, let accountContext = self?.data.call.accountContext, let peerId = peerId else {
                return
            }
            let isChannel = self?.data.call.peer?.isChannel == true
            verifyAlert(for: window, information: isChannel ? strings().voiceChatRemovePeerConfirmChannel(peer.displayTitle) : strings().voiceChatRemovePeerConfirm(peer.displayTitle), ok: strings().voiceChatRemovePeerConfirmOK, cancel: strings().voiceChatRemovePeerConfirmCancel, successHandler: { [weak window] _ in
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    _ = self?.data.peerMemberContextsManager.updateMemberBannedRights(peerId: peerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: 0)).start()
                } else if let window = window {
                    _ = showModalProgress(signal: accountContext.engine.peers.removePeerMember(peerId: peerId, memberId: peer.id), for: window).start()
                }
            }, presentation: darkAppearance)
        }, openInfo: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            let navigation = strongSelf.data.call.accountContext.bindings.rootNavigation()
            PeerInfoController.push(navigation: navigation, context: strongSelf.data.call.accountContext, peerId: peer.id)
            strongSelf.data.call.accountContext.window.orderFrontRegardless()
        }, inviteMembers: { [weak self] in
            guard let window = self?.window, let data = self?.data else {
                return
            }
            actionsDisposable.add(GroupCallAddmembers(data, window: window).start(next: { [weak window, weak self] peerId, isVideo in
                if let peerId = peerId.first, let window = window, let `self` = self {
                    if self.data.call.invitePeer(peerId, isVideo: isVideo) {
                        _ = showModalSuccess(for: window, icon: theme.icons.successModalProgress, delay: 2.0).start()
                    } else {
                        showModalText(for: window, text: strings().unknownError)
                    }
                }
            }))
        }, shareInviteLinks: { [weak self] in
            guard let self, let window = self.window else {
                return
            }
            
            let state = combineLatest(self.data.call.state, self.data.call.callInfo, self.data.call.inviteLinks) |> take(1) |> deliverOnMainQueue
            
            _ = state.startStandalone(next: { state, info, inviteLinks in
                guard let info, let inviteLinks else {
                    return
                }
                showModal(with: GroupCallInviteLinkController(context: context, source: .groupCall(.init(slug: "", link: inviteLinks.listenerLink, callInfo: info)), mode: .share, presentation: darkAppearance), for: window)

            })
        }, shareSource: { [weak self] mode, takeFirst in
            guard let state = self?.genericView.state, let window = self?.window, let data = self?.data else {
                return
            }
            
            if state.state.muteState?.canUnmute == false {
                let text: String
                switch mode {
                case .screencast:
                    text = strings().voiceChatShareVideoMutedError
                case .video:
                    text = strings().voiceChatShareScreenMutedError
                }
                alert(for: window, info: text)
                return
            }
            
            if state.state.networkState == .connecting {
                NSSound.beep()
                return
            }
            
            if !state.isVideoEnabled {
                let config = GroupCallsConfig(data.call.accountContext.appConfiguration)
                switch mode {
                case .video:
                    alert(for: window, info: strings().voiceChatTooltipErrorVideoUnavailable(config.videoLimit))
                case .screencast:
                    alert(for: window, info: strings().voiceChatTooltipErrorScreenUnavailable(config.videoLimit))
                }
                return
            }
            let confirmSource:(VideoSourceMacMode, @escaping(Bool)->Void)->Void = { [weak state, weak window] source, f in
                if let state = state, let window = window {
                    switch mode {
                    case .screencast:
                        let presentingPeer = state.videoActive(.main).first(where: { $0.presentationEndpoint != nil })
                        if let peer = presentingPeer {
                            verifyAlert_button(for: window, header: strings().voiceChatScreencastConfirmHeader, information: strings().voiceChatScreencastConfirmText(peer.peer.compactDisplayTitle), ok: strings().voiceChatScreencastConfirmOK, successHandler: { _ in
                                f(true)
                            }, cancelHandler: {
                                f(false)
                            }, presentation: darkAppearance)
                        } else {
                            f(true)
                        }
                    case .video:
                        f(true)
                    }
                }
            }
            
            let toggleMicro:(Bool, @escaping()->Void)->Void = { [weak self] value, f in
                if let strongSelf = self {
                    if !value != strongSelf.genericView.state?.isMuted {
                        let signal = strongSelf.data.call.state
                            |> map {
                                ($0.muteState == nil && value) || ($0.muteState != nil && !value)
                            } |> filter {
                                $0
                            } |> take(1)
                            |> deliverOnMainQueue
                        
                        _ = signal.start(completed: f)
                        
                        strongSelf.data.call.toggleIsMuted()
                    } else {
                        f()
                    }
                }
            }
            
            let select:(VideoSourceMac)->Void = { source in
                switch source.mode {
                case .screencast:
                    self?.data.call.requestScreencast(deviceId: source.deviceIdKey(), source: source)
                case .video:
                    self?.data.call.requestVideo(deviceId: source.deviceIdKey(), source: source)
                }
                self?.updateTooltips { current in
                    var current = current
                    current.dismissed.insert(.camera)
                    return current
                }
            }
            
            if takeFirst {
                switch mode {
                case .video:
                    let devicesSignal = sharedContext.devicesContext.signal
                        |> take(1)
                        |> deliverOnMainQueue
                    
                    let deviceId = sharedContext.devicesContext.currentCameraId
                    
                    actionsDisposable.add(devicesSignal.start(next: { devices in
                        let preselectedDevice = devices.camera.first(where: { FastSettings.defaultVideoShare() == $0.uniqueID })
                        let device = preselectedDevice ?? devices.camera.first(where: { deviceId == $0.uniqueID })
                        if let device = device {
                            select(CameraCaptureDevice(device))
                        }
                    }))
                case .screencast:
                    let screens = DesktopCaptureSourceManagerMac(_s: ())
                    let windows = DesktopCaptureSourceManagerMac(_w: ())
                    let sf = screens.list().first(where: { $0.uniqueKey() == FastSettings.defaultScreenShare() })
                    let wf = windows.list().first(where: { $0.uniqueKey() == FastSettings.defaultScreenShare() })
                    if let first = sf ?? wf ?? screens.list().first {
                        select(first)
                    }
                }
                return
            }
            if let sharing = self?.sharing, sharing.mode == mode {
                sharing.orderFront(nil)
            } else {
                self?.sharing?.orderOut(nil)
                confirmSource(mode, { accept in
                    if accept {
                        let sharing = presentDesktopCapturerWindow(mode: mode, select: { source, wantsToSpeak in
                            toggleMicro(wantsToSpeak, {
                                select(source)
                            })
                        }, devices: sharedContext.devicesContext, microIsOff: self?.genericView.state?.isMuted ?? true)
                        self?.sharing = sharing
                        sharing?.level = self?.window?.level ?? .normal
                        if sharing == nil, let window = self?.window {
                            switch mode {
                            case .video:
                                showModalText(for: window, text: strings().voiceChatTooltipNoCameraFound)
                            default:
                                break
                            }
                        }
                    }
                })
            }
        }, takeVideo: { [weak self] peerId, mode, listMode in
            let views = self?.videoViews.filter { $0.0.peerId == peerId && $0.1 == listMode }
            var view: NSView? = nil
            if let views = views {
                if let mode = mode {
                    view = views.first(where: { $0.0.mode == mode })?.2
                } else {
                    view = views.first(where: { $0.0.mode == .video })?.2 ?? views.first?.2
                }
            }
            view?.layer?.removeAllAnimations()
            return view
        }, isSharingVideo: { [weak self] peerId in
            return self?.videoViews.first(where: { $0.0.peerId == peerId && $0.0.mode == .video }) != nil
        }, isSharingScreencast: { [weak self] peerId in
            return self?.videoViews.first(where: { $0.0.peerId == peerId && $0.0.mode == .screencast }) != nil
        }, canUnpinVideo: { [weak self] peerId, mode in
            let dominant = self?.genericView.state?.dominantSpeaker
            return dominant?.peerId == peerId
        }, pinVideo: { [weak self] video in
            updateDominant { current in
                var current = current
                current.permanent = video.endpointId
                current.focused = .init(id: video.endpointId, time: Date().timeIntervalSince1970)
                return current
            }
            self?.genericView.peersTable.scroll(to: .up(true))
        }, unpinVideo: {
            updateDominant { current in
                var current = current
                if let permanent = current.permanent {
                    current.permanent = nil
                    current.excludePins.insert(permanent)
                }
                return current
            }
        }, isPinnedVideo: { [weak self] peerId, mode in
            if let current = self?.genericView.state?.dominantSpeaker, current.pinMode == .permanent {
                return current.peerId == peerId && current.mode == mode
            }
            return false
        }, setVolume: { [weak self] peerId, volume, sync in
            let value = Int32(volume * 10000)
            self?.data.call.setVolume(peerId: peerId, volume: value, sync: sync)
            if sync {
                unsyncVolumes.set([:])
            } else {
                unsyncVolumes.set([peerId : value])
            }
        }, getAccountPeerId:{ [weak self] in
            return self?.data.call.joinAsPeerId
        }, getAccount: {
            return account
        }, cancelShareScreencast: { [weak self] in
            self?.data.call.disableScreencast()
        }, cancelShareVideo: { [weak self] in
            self?.data.call.disableVideo()
        }, toggleRaiseHand: { [weak self] in
            if let strongSelf = self, let state = self?.genericView.state {
                let call = strongSelf.data.call
                if !state.state.raisedHand {
                    askedForSpeak = true
                    call.raiseHand()
                } else {
                    askedForSpeak = false
                    call.lowerHand()
                }
            }
        }, recordClick: { [weak self] state in
            if let window = self?.window {
                if state.canManageCall {
                    verifyAlert_button(for: window, header: strings().voiceChatRecordingStopTitle, information: strings().voiceChatRecordingStopText, ok: strings().voiceChatRecordingStopOK, successHandler: { [weak window] _ in
                        self?.data.call.setShouldBeRecording(false, title: nil, videoOrientation: nil)
                        if let window = window {
                            showModalText(for: window, text: strings().voiceChatToastStop)
                        }
                    }, presentation: darkAppearance)
                } else {
                    showModalText(for: window, text: strings().voiceChatAlertRecording)
                }
            }
        }, audioLevel: { [weak self] peerId in
            if let call = self?.data.call {
                if peerId == call.joinAsPeerId {
                    return combineLatest(animate, call.myAudioLevel)
                        |> map (Optional.init)
                        |> map { $0?.1 == 0 || $0?.0 == false ? nil : $0?.1 }
                        |> mapToThrottled { value in
                            return .single(value) |> delay(0.1, queue: .mainQueue())
                        }
                        |> deliverOnMainQueue
                } else {
                    return combineLatest(animate, call.audioLevels) |> map { (visible, values) in
                        if visible {
                            for value in values {
                                if value.0 == peerId {
                                    return value.2
                                }
                            }
                        }
                        return nil
                    } |> deliverOnMainQueue
                }
            }
            return nil
        }, startVoiceChat: { [weak self] in
            self?.data.call.startScheduled()
        }, toggleReminder: { [weak self] subscribe in
            if subscribe, let window = self?.window {
                showModalText(for: window, text: strings().voiceChatTooltipSubscribe)
            }
            self?.data.call.toggleScheduledSubscription(subscribe)
        }, toggleScreenMode: {
        }, switchCamera: { _ in
        }, togglePeersHidden: {
            updateHideParticipants {
                !$0
            }
        }, contextMenuItems: { data in
            return contextMenuItems?(data) ?? []
        }, dismissTooltip: { [weak self] tooltip in
            self?.updateTooltips { current in
                var current = current
                current.dismissed.insert(tooltip.type)
                return current
            }
        }, focusVideo: { [weak self] endpointId in
            updateDominant { current in
                var current = current
                if current.focused?.id == endpointId && endpointId != nil {
                    current.focused = nil
                } else {
                    if let endpointId = endpointId {
                        current.focused = .init(id: endpointId, time: Date().timeIntervalSince1970)
                    } else {
                        current.focused = nil
                    }
                    current.permanent = nil
                }
                return current
            }
            self?.genericView.peersTable.scroll(to: .up(true))
        }, takeTileView: { [weak self] in
            if let `self` = self, let view = self.genericView.tileView {
                return (self.genericView.videoRect.size, view)
            }
            return nil
        }, getSource: { [weak self] mode in
            switch mode {
            case .screencast:
                return self?.genericView.state?.state.sources.screencast
            case .video:
                return self?.genericView.state?.state.sources.video
            }
        }, toggleShowConferenceKey: { [weak self] value in
            self?.showConferenceKey.set(value)
        }, getConferenceLimit: { [weak self] in
            return self?.data.call.accountContext.appConfiguration.getGeneralValue("conference_call_size_limit", orElse: 10) ?? 10
        })
        
        self.statusBar = .init(callState.get() |> deliverOnMainQueue, arguments: arguments, sharedContext: data.call.sharedContext)
        
        contextMenuItems = { [weak arguments, weak self] data in
            
            guard let arguments = arguments else {
                return []
            }
            
            let isStream = self?.data.call.isStream ?? false
            
            var firstBlock:[ContextMenuItem] = []
            var secondBlock:[ContextMenuItem] = []
            var thirdBlock: [ContextMenuItem] = []


            if let accountContext = self?.data.call.accountContext {
                
                firstBlock.append(GroupCallAvatarMenuItem(data.peer, context: accountContext))
                
                firstBlock.append(ContextMenuItem(data.peer.displayTitle, handler: {
                    arguments.openInfo(data.peer)
                }, itemImage: MenuAnimation.menu_open_profile.value))
                
                if let about = data.about {
                    firstBlock.append(ContextMenuItem(about, handler: {
                        arguments.openInfo(data.peer)
                    }, itemImage: MenuAnimation.menu_bio.value, removeTail: false, overrideWidth: 200))
                }

                if let state = data.state {
                    if data.peer.id != data.accountPeerId, state.muteState == nil || state.muteState?.canUnmute == true {
                        secondBlock.append(SliderContextMenuItem(volume: CGFloat((state.volume ?? 10000)) / 10000.0, { value, sync in
                            if value == 0 {
                                arguments.mute(data.peer.id, true)
                            } else {
                                arguments.setVolume(data.peer.id, Double(value), sync)
                            }
                        }))
                    }
                    if data.peer.id == data.accountPeerId, data.isRaisedHand {
                        secondBlock.append(ContextMenuItem(strings().voiceChatDownHand, handler: arguments.toggleRaiseHand, itemImage: MenuAnimation.menu_unblock.value))
                    }
                    
                    if let endpointId = data.videoEndpoint, !isStream {
                        if !arguments.isPinnedVideo(data.peer.id, .video) {
                            secondBlock.append(ContextMenuItem(strings().voiceChatPinVideo, handler: {
                                arguments.pinVideo(.init(data.peer.id, endpointId, .video, .permanent))
                            }, itemImage: MenuAnimation.menu_pin.value))
                        } else if arguments.canUnpinVideo(data.peer.id, .video) {
                            secondBlock.append(ContextMenuItem(strings().voiceChatUnpinVideo, handler: {
                                arguments.unpinVideo()
                            }, itemImage: MenuAnimation.menu_unpin.value))
                        }
                    }
                    if let endpointId = data.presentationEndpoint, !isStream {
                        if !arguments.isPinnedVideo(data.peer.id, .screencast) {
                            secondBlock.append(ContextMenuItem(strings().voiceChatPinScreencast, handler: {
                                arguments.pinVideo(.init(data.peer.id, endpointId, .screencast, .permanent))
                            }, itemImage: MenuAnimation.menu_sharescreen.value))
                        } else if arguments.canUnpinVideo(data.peer.id, .screencast) {
                            secondBlock.append(ContextMenuItem(strings().voiceChatUnpinScreencast, handler: {
                                arguments.unpinVideo()
                            }, itemImage: MenuAnimation.menu_sharescreen_slash.value))
                        }
                    }
                    
                    
                    
                    if !data.canManageCall, data.peer.id != data.accountPeerId, !isStream {
                        if let muteState = state.muteState {
                            if muteState.mutedByYou {
                                secondBlock.append(.init(strings().voiceChatUnmuteForMe, handler: {
                                    arguments.mute(data.peer.id, false)
                                }, itemImage: MenuAnimation.menu_speaker.value))
                            } else {
                                secondBlock.append(.init(strings().voiceChatMuteForMe, handler: {
                                    arguments.mute(data.peer.id, true)
                                }, itemImage: MenuAnimation.menu_speaker_muted.value))
                            }
                        } else {
                            secondBlock.append(.init(strings().voiceChatMuteForMe, handler: {
                                arguments.mute(data.peer.id, true)
                            }, itemImage: MenuAnimation.menu_mute.value))
                        }
                    }
                    
                    if data.canManageCall, data.peer.id != data.accountPeerId, !isStream {
                        if data.adminIds.contains(data.peer.id) {
                            if state.muteState == nil {
                                secondBlock.append(.init(strings().voiceChatMutePeer, handler: {
                                    arguments.mute(data.peer.id, true)
                                }, itemImage: MenuAnimation.menu_mute.value))
                            }
                            if !data.adminIds.contains(data.peer.id), !data.peer.isChannel {
                                thirdBlock.append(.init(strings().voiceChatRemovePeer, handler: {
                                    arguments.remove(data.peer)
                                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                            }
                        } else if let muteState = state.muteState, !muteState.canUnmute {
                            secondBlock.append(.init(strings().voiceChatUnmutePeer, handler: {
                                arguments.mute(data.peer.id, false)
                            }, itemImage: MenuAnimation.menu_voice.value))
                        } else {
                            secondBlock.append(.init(strings().voiceChatMutePeer, handler: {
                                arguments.mute(data.peer.id, true)
                            }, itemImage: MenuAnimation.menu_mute.value))
                        }
                        if !data.adminIds.contains(data.peer.id), !data.peer.isChannel {
                            thirdBlock.append(.init(strings().voiceChatRemovePeer, handler: {
                                arguments.remove(data.peer)
                            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                        }
                        if data.canManageCall {
                            thirdBlock.append(ContextMenuItem(strings().voiceChatRemovePeer, handler: {
                                self?.data.call.removedPeer(data.peer.id)
                            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                        }
                    }
                } else if let inviteState = data.inviteState?.state {
                    switch inviteState {
                    case .ringing, .requesting:
                        thirdBlock.append(ContextMenuItem(strings().voiceChatConferenceStopCalling, handler: {
                            self?.data.call.removedPeer(data.peer.id)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_clear_history.value))
                        
                        thirdBlock.append(ContextMenuItem(strings().voiceChatConferenceDiscardInvite, handler: {
                            self?.data.call.kickPeer(id: data.peer.id)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    case .connecting:
                        thirdBlock.append(ContextMenuItem(strings().voiceChatRemovePeer, handler: {
                            self?.data.call.removedPeer(data.peer.id)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    }
                }
                
            }
            
            let blocks:[[ContextMenuItem]] = [firstBlock,
                                              secondBlock,
                                              thirdBlock].filter { !$0.isEmpty }
            var items: [ContextMenuItem] = []

            for (i, block) in blocks.enumerated() {
                if i != 0 {
                    items.append(ContextSeparatorItem())
                }
                items.append(contentsOf: block)
            }
            return items
            
        }
        
        
        let pinUpdater:(GroupCallUIState?, GroupCallUIState) -> Void = { previous, state in
                        
            let videoMembers: [PeerGroupCallData] = state.memberDatas
                .filter { member in
                return member.presentationEndpoint != nil && member.peer.id != member.accountPeerId
            }
            
            let prevPresenting = previous?.memberDatas
                .filter { member in
                    return member.presentationEndpoint != nil && member.peer.id != member.accountPeerId
            } ?? []
            let presenting = videoMembers
            
            var current: DominantVideo? = previous?.dominantSpeaker
                
            if presenting.count != prevPresenting.count {
                var intersection:[PeerGroupCallData] = []
                if presenting.count > prevPresenting.count {
                    intersection = presenting
                    intersection.removeAll(where: { value in
                        if prevPresenting.contains(where: { $0.peer.id == value.peer.id }) {
                            return true
                        } else {
                            return false
                        }
                    })
                } else if current != nil {
                    if !presenting.contains(where: { $0.presentationEndpoint == current?.endpointId }) {
                        if let first = presenting.first {
                            intersection.append(first)
                        }
                    }
                }
                intersection = intersection.filter({
                    return !state.pinnedData.excludePins.contains($0.presentationEndpointId!)
                })
                if let first = intersection.first {
                    let master: DominantVideo = DominantVideo(first.peer.id, first.presentationEndpointId!, .screencast, .permanent)
                    current = master
                }
                
                if let value = current, value != previous?.dominantSpeaker {
                    DispatchQueue.main.async {
                        updateDominant { current in
                            var current = current
                            current.permanent = value.endpointId
                            current.focused = nil
                            return current
                        }
                    }
                }
            } else if state.pinnedData.permanent == nil {
                let members = state.activeVideoMembers[.main] ?? []
                if let active = members.first(where: { $0.isSpeaking && $0.accountPeerId != $0.peer.id }) {
                    var endpointId: String
                    if let endpoint = active.videoEndpoint {
                        endpointId = endpoint
                    } else if let endpoint = active.presentationEndpoint {
                        endpointId = endpoint
                    } else {
                        fatalError("sounds impossible, but at the end it happened.")
                    }
                    var canSwitch: Bool = false
                    if let current = state.pinnedData.focused {
                        let member = members.first(where: { $0.videoEndpoint == current.id || $0.presentationEndpoint == current.id })
                        if active.peer.id != member?.peer.id {
                            canSwitch = current.id != endpointId && (Date().timeIntervalSince1970 - current.time) > 5.0
                        }
                    }
                    if canSwitch {
                        DispatchQueue.main.async {
                            updateDominant { current in
                                var current = current
                                current.permanent = nil
                                current.focused = .init(id: endpointId, time: Date().timeIntervalSince1970)
                                return current
                            }
                        }
                    }
                }
            }
        }
        
        let checkRaiseHand:(GroupCallUIState)->Void = { state in
            for member in state.memberDatas {
                if member.isRaisedHand {
                    let displayedRaisedHands = displayedRaisedHands.with { $0 }
                    let signal: Signal<Never, NoError> = Signal.complete() |> delay(3.0, queue: Queue.mainQueue())
                    if !displayedRaisedHands.contains(member.peer.id) {
                        if raisedHandDisplayDisposables[member.peer.id] == nil {
                            raisedHandDisplayDisposables[member.peer.id] = signal.start(completed: {
                                updateDisplayedRaisedHands { current in
                                    var current = current
                                    current.insert(member.peer.id)
                                    return current
                                }
                                raisedHandDisplayDisposables[member.peer.id] = nil
                            })
                        }
                    }
                } else {
                    raisedHandDisplayDisposables[member.peer.id]?.dispose()
                    raisedHandDisplayDisposables[member.peer.id] = nil
                    DispatchQueue.main.async {
                        updateDisplayedRaisedHands { current in
                            var current = current
                            current.remove(member.peer.id)
                            return current
                        }
                    }
                    
                }
            }
            DispatchQueue.main.async {
                displayedRaisedHandsPromise.set(displayedRaisedHands.with { $0 })
            }
        }
        
        let checkVideo:(GroupCallUIState?, GroupCallUIState) -> Void = { [weak self] currentState, state in
            if let currentState, state.state.muteState?.canUnmute == false || currentState.state.myPeerId != state.state.myPeerId {
                if !state.videoSources.isEmpty {
                    DispatchQueue.main.async {
                        self?.data.call.disableVideo()
                        self?.data.call.disableScreencast()
                    }
                }
            }
        }

        
        let applyTooltipsAndSounds:(GroupCallUIState?, GroupCallUIState) -> Void = { [weak self] currentState, state in
            
            guard let window = self?.window else {
                return
            }
            
            switch state.state.networkState {
            case .connected:
                var notifyCanSpeak: Bool = false
                var notifyStartRecording: Bool = false
                
                if let previous = currentState {
                    
                    if previous.state.muteState != state.state.muteState {
                        if askedForSpeak, let muteState = state.state.muteState, muteState.canUnmute {
                            notifyCanSpeak = true
                        }
                    }
                    if previous.state.recordingStartTimestamp == nil && state.state.recordingStartTimestamp != nil {
                        notifyStartRecording = true
                    }
                    if !state.videoSources.failed {
                        if (previous.videoSources.screencast != nil) != (state.videoSources.screencast != nil) {
                            if let _ = state.videoSources.screencast {
                                showModalText(for: window, text: strings().voiceChatTooltipShareScreen)
                            } else if let _ = previous.videoSources.screencast {
                                showModalText(for: window, text: strings().voiceChatTooltipStopScreen)
                            }
                        }
                        if (previous.videoSources.video != nil) != (state.videoSources.video != nil) {
                            if let _ = state.videoSources.video {
                                showModalText(for: window, text: strings().voiceChatTooltipShareVideo)
                            } else if let _ = previous.videoSources.video {
                                showModalText(for: window, text: strings().voiceChatTooltipStopVideo)
                            }
                        }
                    }
                }
                if notifyCanSpeak {
                    askedForSpeak = false
                    SoundEffectPlay.play(postbox: account.postbox, name: "voip_group_unmuted")
                    showModalText(for: window, text: strings().voiceChatToastYouCanSpeak)
                }
                if notifyStartRecording {
                    SoundEffectPlay.play(postbox: account.postbox, name: "voip_group_recording_started")
                    showModalText(for: window, text: strings().voiceChatAlertRecording)
                }
            case .connecting:
                break
            }
        }
        
        self.data.call.mustStopVideo = { [weak arguments, weak window, weak self] in
            self?.data.call.toggleVideoFailed(failed: true)
            arguments?.cancelShareVideo()
            if let window = window {
                showModalText(for: window, text: strings().voiceChatTooltipVideoFailed)
            }
            delay(0.2, closure: {
                self?.data.call.toggleVideoFailed(failed: false)
            })
        }
        self.data.call.mustStopSharing = { [weak self, weak arguments, weak window] in
            self?.data.call.toggleVideoFailed(failed: true)
            arguments?.cancelShareScreencast()
            if let window = window {
                showModalText(for: window, text: strings().voiceChatTooltipScreencastFailed)
            }
            delay(0.2, closure: {
                self?.data.call.toggleVideoFailed(failed: false)
            })
        }
        
        genericView.arguments = arguments
        let members = data.call.members
        
        let signal: Signal<Bool, NoError> = (.single(true) |> then(.single(true) |> delay(1.0, queue: Queue.mainQueue()))) |> restart
        
        let videoData = combineLatest(queue: .mainQueue(), members, dominantSpeakerSignal.get(), isFullScreen.get(), self.data.call.joinAsPeerIdValue, self.data.call.stateVersion |> filter { $0 > 0 }, size.get(), signal, self.data.call.state)
        
                
        actionsDisposable.add(videoData.start(next: { [weak self] members, dominant, isFullScreen, accountId, stateVersion, size, _, state in
            
            let videoSources = state.sources
            
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                
                let types:[GroupCallUIState.ActiveVideo.Mode] = GroupCallUIState.ActiveVideo.allModes

                let mainMember = members?.participants.first(where: { $0.id == .peer(accountId) })
                
                let videoMembers: [GroupCallParticipantsContext.Participant] = members?.participants.filter { member in
                    return (member.videoEndpointId != nil || member.presentationEndpointId != nil)
                } ?? []
                
                let tiles = tileViews(videoMembers.count, isFullscreen: isFullScreen, frameSize: strongSelf.genericView.videoRect.size)
                
                let selectBest = videoMembers.filter { $0.id != .peer(accountId) }.count == 1
                
                var items:[PresentationGroupCallRequestedVideo] = []
                            
                for (i, member) in videoMembers.enumerated() {
                    var videoQuality: PresentationGroupCallRequestedVideo.Quality = selectBest ? .full : tiles[i].bestQuality
                    var screencastQuality: PresentationGroupCallRequestedVideo.Quality = selectBest ? .full : tiles[i].bestQuality

                    var dominant = dominant.permanent ?? dominant.focused?.id
                    
                    let hasDominant = members?.participants.contains(where: { participant in
                        return participant.videoEndpointId == dominant || participant.presentationEndpointId == dominant
                    }) == true
                    
                    if !hasDominant {
                        dominant = nil
                    }
                    
                    if let dominant = dominant {
                        videoQuality = .thumbnail
                        screencastQuality = .thumbnail
                        if dominant == member.videoEndpointId || dominant == member.presentationEndpointId {
                            videoQuality = .full
                            screencastQuality = .full
                        } else {
                            videoQuality = .thumbnail
                            screencastQuality = .thumbnail
                        }
                    }
                    
                    var minVideo: PresentationGroupCallRequestedVideo.Quality = .thumbnail

                    
                    if state.isStream {
                        videoQuality = .full
                        screencastQuality = .full
                        minVideo = .full
                    }
                    let maxVideo: PresentationGroupCallRequestedVideo.Quality = videoQuality
                    
                    if let item = member.requestedVideoChannel(minQuality: minVideo, maxQuality: maxVideo) {
                        items.append(item)
                    }
                    
                    var minScreencast: PresentationGroupCallRequestedVideo.Quality = .thumbnail
                    var maxScreencast: PresentationGroupCallRequestedVideo.Quality = screencastQuality

                    if maxScreencast == .medium {
                        maxScreencast = .full
                    }
                    
                    if maxScreencast == .full {
                        minScreencast = .full
                    }
                    if let item = member.requestedPresentationVideoChannel(minQuality: minScreencast, maxQuality: maxScreencast) {
                        items.append(item)
                    }
                }
                
                var validSources = Set<String>()
                for item in items {
                    let endpointId = item.endpointId
                    let member = members?.participants.first(where: { participant in
                        if participant.id == .peer(accountId), !state.isStream {
                            if participant.videoEndpointId == item.endpointId {
                                return videoSources.video != nil
                            }
                            if participant.presentationEndpointId == item.endpointId {
                                return videoSources.screencast != nil
                            }
                        }
                        return participant.videoEndpointId == item.endpointId || participant.presentationEndpointId == item.endpointId
                    })

                    if let member = member {
                        validSources.insert(endpointId)
                        if !strongSelf.requestedVideoSources.contains(endpointId) {
                            strongSelf.requestedVideoSources.insert(endpointId)
                            
                            let isScreencast = member.presentationEndpointId == endpointId
                            let videoMode: VideoSourceMacMode = isScreencast ? .screencast : .video
                            let takeVideoMode: GroupCallVideoMode = isScreencast && member.id == .peer(accountId) ? .screencast : .video
                                                
                            
                            
                            for type in types {
                               
                                strongSelf.data.call.makeVideoView(endpointId: endpointId, videoMode: takeVideoMode, completion: { videoView in
                                    guard let videoView = videoView else {
                                        return
                                    }
                                    var videoViewValue: GroupVideoView? = GroupVideoView(videoView: videoView)
                                    
                                    switch type {
                                    case .main:
                                        videoView.setVideoContentMode(.resizeAspect)
                                    case .list:
                                        videoView.setVideoContentMode(.resizeAspectFill)
                                    case .profile:
                                        videoView.setVideoContentMode(.resizeAspectFill)
                                    }
                                    
                                    if let videoViewValue = videoViewValue, let peer = member.peer?._asPeer() {
                                        self?.videoViews.append((DominantVideo(peer.id, endpointId, videoMode, nil), type, videoViewValue))
                                        updateActiveVideoViews { current in
                                            var current = current
                                            current.set.append(.init(endpointId: endpointId, mode: type, index: current.index))
                                            current.index -= 1
                                            return current
                                        }
                                    }
                                    videoViewValue = nil
                                    
//                                    videoView.setOnFirstFrameReceived( { [weak self] f in
//                                       
//                                    })
                                })
                            }
                        }
                    }
                }
                for i in (0 ..< strongSelf.videoViews.count).reversed() {
                    if !validSources.contains(strongSelf.videoViews[i].0.endpointId) {
                        let endpointId = strongSelf.videoViews[i].0.endpointId
                        strongSelf.videoViews.remove(at: i)
                        strongSelf.requestedVideoSources.remove(endpointId)
                        updateActiveVideoViews { current in
                            var current = current
                            current.set.removeAll(where: {
                                $0.endpointId == endpointId
                            })
                            return current
                        }
                    }
                }
                
                items = items.filter({ item in
                    if let mainMember = mainMember {
                        if mainMember.videoEndpointId == item.endpointId {
                            return false
                        }
                        if mainMember.presentationEndpointId == item.endpointId {
                            return false
                        }
                    }
                    return true
                })
                
                self?.data.call.setRequestedVideoList(items: items)
            }
        }))
        
      
                
        let invited: Signal<[(Peer, PresentationGroupCallInvitedPeer)], NoError> = self.data.call.invitedPeers |> mapToSignal { invited in
            return account.postbox.transaction { transaction -> [(Peer, PresentationGroupCallInvitedPeer)] in
                var peers:[(Peer, PresentationGroupCallInvitedPeer)] = []
                for invited in invited {
                    if let peer = transaction.getPeer(invited.id) {
                        peers.append((peer, invited))
                    }
                }
                return peers
            }
        }
        
               
        let joinAsPeer:Signal<(Peer, String?), NoError> = self.data.call.joinAsPeerIdValue |> mapToSignal {
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
        
        
        let some = combineLatest(queue: .mainQueue(), self.data.call.isMuted, animate, joinAsPeer, unsyncVolumes.get(), dominantSpeakerSignal.get(), activeVideoViews.get() |> distinctUntilChanged, isFullScreen.get(), self.data.call.stateVersion, hideParticipants.get(), showConferenceKey.get(), self.data.call.e2eEncryptionKeyHash)

        
        var currentState: GroupCallUIState?

        let previousState: Atomic<GroupCallUIState?> = Atomic(value: nil)
        
        let initialTimestamp = Date().timeIntervalSince1970
        
        let peerView: Signal<PeerView?, NoError>
        if let peerId {
            peerView = context.account.postbox.peerView(id: peerId) |> map(Optional.init)
        } else {
            peerView = .single(nil)
        }
        
        let state: Signal<GroupCallUIState, NoError> = combineLatest(queue: .mainQueue(), self.data.call.state, members, (.single(0) |> then(data.call.myAudioLevel)) |> distinctUntilChanged, peerView, invited, self.data.call.summaryState, voiceCallSettings(data.call.sharedContext.accountManager), some, displayedRaisedHandsPromise.get(), tooltipsValue.get(), window.fullScreen) |> mapToQueue { values in
            let value = previousState.modify { previous in
                return makeState(previous: previous,
                                        peerView: values.3,
                                        state: values.0,
                                        isMuted: values.7.0,
                                        invitedPeers: values.4,
                                        peerStates: values.1,
                                        myAudioLevel: values.2,
                                        summaryState: values.5,
                                        voiceSettings: values.6,
                                        isWindowVisible: values.7.1,
                                        accountPeer: values.7.2,
                                        unsyncVolumes: values.7.3,
                                        pinnedData: values.7.4,
                                        hideWantsToSpeak: values.8,
                                        isFullScreen: values.7.6,
                                        videoSources: values.0.sources,
                                        activeVideoViews: values.7.5.set,
                                        hideParticipants: values.7.8,
                                        tooltips: values.9,
                                        version: values.7.7,
                                        isStream: values.0.isStream,
                                        windowIsFullscreen: values.10,
                                        initialTimestamp: initialTimestamp,
                                        showConferenceKey: values.7.9,
                                        e2eEncryptionKeyHash: values.7.10)
            }
            return .single(value!)
        } |> distinctUntilChanged
        
        

        let initialSize = self.atomicSize
        var previousIsFullScreen: Bool = initialSize.with { $0.width >= GroupCallTheme.fullScreenThreshold }
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let animated: Atomic<Bool> = Atomic(value: false)
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {})
        
                
        let transition: Signal<(GroupCallUIState, TableUpdateTransition), NoError> = combineLatest(state, appearanceSignal) |> deliverOnPrepareQueue |> mapToQueue { state, appAppearance in
            let current = peerEntries(state: state, account: account, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appAppearance) }
            let previous = previousEntries.swap(current)
            let signal = prepareInputDataTransition(left: previous, right: current, animated: abs(current.count - previous.count) <= 10 && state.isWindowVisible && state.isFullScreen == previousIsFullScreen, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputArguments, onMainQueue: false, animateEverything: true)
            
            previousIsFullScreen = state.isFullScreen
            
            return combineLatest(.single(state), signal)
        } |> deliverOnMainQueue
        
        self.disposable.set(transition.start { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            let state = value.0
            
            if currentState == nil {
                _ = strongSelf.disableScreenSleep()
            }
            strongSelf.applyUpdates(state, value.1, strongSelf.data.call, animated: animated.swap(true))
            strongSelf.readyOnce()
                        
            checkRaiseHand(state)
            applyTooltipsAndSounds(currentState, state)
            checkVideo(currentState, state)
            pinUpdater(currentState, state)
            
            
            currentState = state
            
            callState.set(state)

        })
        

        self.onDeinit = {
            currentState = nil
            _ = previousEntries.swap([])
            _ = previousState.swap(nil)
        }

        genericView.peersTable.setScrollHandler { [weak self] position in
            switch position.direction {
            case .bottom:
                self?.data.call.loadMore()
            default:
                break
            }
        }

        var connectedMusicPlayed: Bool = false
        
        let connecting = self.connecting
                
        pushToTalkDisposable.set(combineLatest(queue: .mainQueue(), data.call.state, data.call.isMuted, data.call.canBeRemoved).start(next: { [weak self] state, isMuted, canBeRemoved in
            
            let disableSounds = self?.disableSounds ?? true
            
            switch state.networkState {
            case .connected:
                if !connectedMusicPlayed && !disableSounds {
                    SoundEffectPlay.play(postbox: account.postbox, name: "call up")
                    connectedMusicPlayed = true
                }
                if canBeRemoved, connectedMusicPlayed  && !disableSounds {
                    SoundEffectPlay.play(postbox: account.postbox, name: "call down")
                }
                connecting.set(nil)
            case .connecting:
                if state.scheduleTimestamp == nil {
                    connecting.set((Signal<Void, NoError>.single(Void()) |> delay(3.0, queue: .mainQueue()) |> restart).start(next: {
                        SoundEffectPlay.play(postbox: account.postbox, name: "reconnecting")
                    }))
                } else {
                    connecting.set(nil)
                }
            }

            self?.pushToTalk?.update = { [weak self] mode in
                switch state.networkState {
                case .connected:
                    switch mode {
                    case .speaking:
                        if isMuted {
                            if let muteState = state.muteState {
                                if muteState.canUnmute {
                                    self?.data.call.setIsMuted(action: .muted(isPushToTalkActive: true))
                                    self?.pushToTalkIsActive = true
                                }
                            }
                        }
                    case .waiting:
                        if !isMuted, self?.pushToTalkIsActive == true {
                            self?.data.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                        }
                        self?.pushToTalkIsActive = false
                    case .toggle:
                        if let muteState = state.muteState {
                            if muteState.canUnmute {
                                self?.data.call.setIsMuted(action: .unmuted)
                            }
                        } else {
                            self?.data.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                        }
                    }
                case .connecting:
                    break
                }
            }
        }))
        
        var hasMicroPermission: Bool? = nil
        
        let alertPermission = { [weak self] in
            guard let window = self?.window else {
                return
            }
            verifyAlert_button(for: window, information: strings().voiceChatRequestAccess, ok: strings().modalOK, cancel: "", option: strings().requestAccesErrorConirmSettings, successHandler: { result in
                switch result {
                case .thrid:
                    openSystemSettings(.microphone)
                default:
                    break
                }
            }, presentation: darkAppearance)
        }
        
        data.call.permissions = { action, f in
            switch action {
            case .unmuted, .muted(isPushToTalkActive: true):
                if let permission = hasMicroPermission {
                    f(permission)
                    if !permission {
                        alertPermission()
                    }
                } else {
                    _ = requestMicrophonePermission().start(next: { permission in
                        hasMicroPermission = permission
                        f(permission)
                        if !permission {
                            alertPermission()
                        }
                    })
                }
            default:
                f(true)
            }
        }
        
        let launchIdleTimer:()->Void = { [weak self] in
            let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
                self?.genericView.idleHide()
            }, queue: .mainQueue())
            
            self?.idleTimer = timer
            timer.start()
        }
        
//        window.set(mouseHandler: { [weak self] event in
//            self?.genericView.updateMouse(animated: true, isReal: true)
//            launchIdleTimer()
//            return .rejected
//        }, with: self, for: .mouseEntered, priority: .modal)
        
        window.set(mouseHandler: { [weak self]  event in
            self?.genericView.updateMouse(animated: true, isReal: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseMoved, priority: .modal)
        
        window.set(mouseHandler: { [weak self] event in
            self?.genericView.updateMouse(animated: true, isReal: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseExited, priority: .modal)
        
        
//        window.set(handler: { [weak arguments, weak self] event in
//            if self?.data.call.isStream == false {
//                if videoSourcesValue.with ({ $0.screencast == nil }) {
//                    arguments?.shareSource(.screencast, true)
//                } else {
//                    arguments?.cancelShareScreencast()
//                }
//            }
//            return .invokeNext
//        }, with: self, for: .T, priority: .modal, modifierFlags: [.command])
        
        window.set(handler: { [weak arguments, weak self] event in
            if self?.data.call.isStream == false {
                if self?.genericView.state?.videoSources.video == nil {
                    arguments?.shareSource(.video, true)
                } else {
                    arguments?.cancelShareVideo()
                }
            }
            return .invokeNext
        }, with: self, for: .E, priority: .modal, modifierFlags: [.command])
        
        window.set(handler: { [weak arguments, weak self] event in
            let settings = self?.navigationController?.controller as? GroupCallSettingsController
            if self?.genericView.state?.showConferenceKey == true {
                self?.showConferenceKey.set(false)
                return .invokeNext
            }
            if let _ = settings {
                self?.navigationController?.back()
            } else {
                arguments?.focusVideo(nil)
            }
            return .invokeNext
        }, with: self, for: .Escape, priority: .modal)
        
    }
    
    override func readyOnce() {
        let was = self.didSetReady
        super.readyOnce()
        if didSetReady, !was {
            requestPermissionDisposable.set(requestMicrophonePermission().start())
        }
    }
    
    private var pushToTalkIsActive: Bool = false

    
    private func applyUpdates(_ state: GroupCallUIState, _ transition: TableUpdateTransition, _ call: PresentationGroupCall, animated: Bool) {
        CATransaction.begin()
        self.genericView.applyUpdates(state, transition, call, animated: transition.animated)
        CATransaction.commit()
        canManageCall = state.summaryState?.info?.isCreator == true || state.state.canManageCall
        
        
        self.checkMicro(state)
    }

    
    private func checkMicro(_ state: GroupCallUIState) {
//        
//        
//        switch state.state.networkState {
//        case .connecting:
//            speakController.pause()
//        case .connected:
//            if !state.dismissedTooltips.contains(.micro), state.controlsTooltip == nil {
//                if state.isMuted && state.state.muteState?.canUnmute == true {
//                    speakController.resume(onSpeaking: { [weak self] _ in
//                        self?.updateTooltips { current in
//                            var current = current
//                            current.speachDetected = true
//                            return current
//                        }
//                    })
//                } else {
//                    speakController.pause()
//                }
//            } else {
//                speakController.pause()
//            }
//            if !state.isMuted {
//                if !state.isMuted {
//                    DispatchQueue.main.async { [weak self] in
//                        self?.updateTooltips { current in
//                            var current = current
//                            current.dismissed.insert(.micro)
//                            return current
//                        }
//                    }
//                }
//            }
//        }
    }
    
    deinit {
        disposable.dispose()
        pushToTalkDisposable.dispose()
        requestPermissionDisposable.dispose()
        actionsDisposable.dispose()
        connecting.dispose()
        sharing?.orderOut(nil)
        idleTimer?.invalidate()
        _ = enableScreenSleep()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    private var genericView: GroupCallView {
        return self.view as! GroupCallView
    }
    
    
    override func viewClass() -> AnyClass {
        return GroupCallView.self
    }
    
    private var assertionID: IOPMAssertionID = 0
    private var success: IOReturn?
    
    private func disableScreenSleep() -> Bool? {
        guard success == nil else { return nil }
        success = IOPMAssertionCreateWithName( kIOPMAssertionTypeNoDisplaySleep as CFString,
                                               IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "Group Call" as CFString,
                                               &assertionID )
        return success == kIOReturnSuccess
    }
    
    private func enableScreenSleep() -> Bool {
        if success != nil {
            success = IOPMAssertionRelease(assertionID)
            success = nil
            return true
        }
        return false
    }

    
}



/*
 
 let videoMembers: [GroupCallParticipantsContext.Participant] = activeParticipants
     .filter { member in
     return member.presentationEndpointId != nil
 }.filter { member in
     return activeVideoViews.contains(where: {
         $0.endpointId == member.presentationEndpointId && $0.mode == .main
     })
 }
 
 let prevPresenting = previous?.memberDatas
     .compactMap { $0.state }
     .filter { member in
     return member.presentationEndpointId != nil
 }.filter { member in
     return previous?.activeVideoViews.contains(where: {
         $0.endpointId == member.presentationEndpointId && $0.mode == .main
     }) ?? false
 } ?? []
 let presenting = videoMembers
 
 var current: DominantVideo? = previous?.dominantSpeaker
     
 if presenting.count != prevPresenting.count {
     var intersection:[GroupCallParticipantsContext.Participant] = []
     if presenting.count > prevPresenting.count {
         intersection = presenting
         intersection.removeAll(where: { value in
             if prevPresenting.contains(where: { $0.peer.id == value.peer.id }) {
                 return true
             } else {
                 return false
             }
         })
     } else if current != nil {
         if !presenting.contains(where: { $0.presentationEndpointId == current?.endpointId }) {
             if let first = presenting.first {
                 intersection.append(first)
             }
         }
     }
     
     intersection = intersection.filter({
         return !pinnedData.excludePins.contains($0.presentationEndpointId!)
     })
     if let first = intersection.first {
         let master: DominantVideo = DominantVideo(first.peer.id, first.presentationEndpointId!, .screencast, .permanent)
         current = master
     }
 }
 */


//            if currentState?.dominantSpeaker != state.dominantSpeaker {
//
//                let current = state.dominantSpeaker
//                let prev = currentState?.dominantSpeaker
//
//                let dominantSpeaker = state.dominantSpeaker
//                let dominant = dominantSpeaker ?? currentState?.dominantSpeaker
//                if let dominant = dominant {
//                    let isPinned = dominantSpeaker != nil
//                    let participant = state.memberDatas.first(where: { $0.peer.id == dominant.peerId })
//                    if let participant = participant {
//                        let text: String = participant.peer.compactDisplayTitle
//                        switch dominant.mode {
//                        case .video:
//                            if isPinned {
//                                if participant.accountPeerId == participant.peer.id {
//                                    showModalText(for: window, text: strings().voiceChatTooltipYourVideoPinned)
//                                } else {
//                                    showModalText(for: window, text: strings().voiceChatTooltipVideoPinned(text))
//                                }
//                            } else {
//                                if participant.accountPeerId == participant.peer.id {
//                                    showModalText(for: window, text: strings().voiceChatTooltipYourVideoUnpinned)
//                                } else {
//                                    showModalText(for: window, text: strings().voiceChatTooltipVideoUnpinned(text))
//                                }
//                            }
//                        case .screencast:
//                            if isPinned {
//                                if participant.accountPeerId == participant.peer.id {
//                                    showModalText(for: window, text: strings().voiceChatTooltipYourScreenPinned)
//                                } else {
//                                    showModalText(for: window, text: strings().voiceChatTooltipScreenPinned(text))
//                                }
//                            } else {
//                                if participant.accountPeerId == participant.peer.id {
//                                    showModalText(for: window, text: strings().voiceChatTooltipYourScreenUnpinned)
//                                } else {
//                                    showModalText(for: window, text: strings().voiceChatTooltipScreenUnpinned(text))
//                                }
//                            }
//                        }
//                    }
//                }
//            }
