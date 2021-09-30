//
//  GroupCallUIState.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox

import TelegramCore
import TgVoipWebrtc

final class GroupCallUIState : Equatable {

    struct RecentActive : Equatable {
        let peerId: PeerId
        let timestamp: TimeInterval
    }
    
    enum ControlsTooltip : Equatable {
        case camera
        case micro
    }
    
    enum Mode : Equatable {
        case voice
        case video
    }
    struct ActiveVideo : Hashable {
        enum Mode : Int {
            case main
            case list
            case profile
        }
        
        static var allModes:[Mode] {
            return [.list, .main]
        }
 
        let endpointId: String
        let mode: Mode
        let index: Int
        func hash(into hasher: inout Hasher) {
            hasher.combine(endpointId)
            hasher.combine(mode.hashValue)
            hasher.combine(index)
        }
    }
    
    struct VideoSources : Equatable {
        static func == (lhs: GroupCallUIState.VideoSources, rhs: GroupCallUIState.VideoSources) -> Bool {
            if let lhsVideo = lhs.video, let rhsVideo = rhs.video {
                if !lhsVideo.isEqual(rhsVideo) {
                    return false
                }
            } else if (lhs.video != nil) != (rhs.video != nil) {
                return false
            }
            if let lhsScreencast = lhs.screencast, let rhsScreencast = rhs.screencast {
                if !lhsScreencast.isEqual(rhsScreencast) {
                    return false
                }
            } else if (lhs.screencast != nil) != (rhs.screencast != nil) {
                return false
            }
            if lhs.failed != rhs.failed {
                return false
            }
            return true
        }
        
        var video: VideoSourceMac? = nil
        var screencast: VideoSourceMac? = nil
        
        var failed: Bool = false
        
        var isEmpty: Bool {
            return video == nil && screencast == nil
        }
    }
    
    struct PinnedData : Equatable {
        struct Focused: Equatable {
            var id: String
            var time: TimeInterval
        }
        var permanent: String? = nil
        var focused: Focused? = nil
        var excludePins: Set<String> = Set()
        var focusedTime: TimeInterval?
        
        var isEmpty: Bool {
            return permanent != nil || focused != nil
        }
    }

    let memberDatas:[PeerGroupCallData]
    let isMuted: Bool
    let state: PresentationGroupCallState
    let summaryState: PresentationGroupCallSummaryState?
    let peer: Peer
    let cachedData: CachedChannelData?
    let myAudioLevel: Float
    let voiceSettings: VoiceCallSettings
    let isWindowVisible: Bool
    let dominantSpeaker: DominantVideo?
    let pinnedData: PinnedData
    let isFullScreen: Bool
    let mode: Mode
    let videoSources: VideoSources
    let version: Int
    let activeVideoViews: [ActiveVideo]
    let hideParticipants: Bool
    let isVideoEnabled: Bool
    
    let videoJoined: Bool
    
    let tooltipSpeaker: PeerGroupCallData?
    let activeVideoMembers: [GroupCallUIState.ActiveVideo.Mode : [PeerGroupCallData]]
    
    let controlsTooltip: ControlsTooltip?
    let dismissedTooltips: Set<ControlsTooltip>
    
    let myPeer: PeerGroupCallData?
        
    init(memberDatas: [PeerGroupCallData], state: PresentationGroupCallState, isMuted: Bool, summaryState: PresentationGroupCallSummaryState?, myAudioLevel: Float, peer: Peer, cachedData: CachedChannelData?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, dominantSpeaker: DominantVideo?, pinnedData: PinnedData, isFullScreen: Bool, mode: Mode, videoSources: VideoSources, version: Int, activeVideoViews: [ActiveVideo], hideParticipants: Bool, isVideoEnabled: Bool, tooltipSpeaker: PeerGroupCallData?, controlsTooltip: ControlsTooltip?, dismissedTooltips: Set<ControlsTooltip>, videoJoined: Bool) {
        self.summaryState = summaryState
        self.memberDatas = memberDatas
        self.peer = peer
        self.isMuted = isMuted
        self.cachedData = cachedData
        self.state = state
        self.myAudioLevel = myAudioLevel
        self.voiceSettings = voiceSettings
        self.isWindowVisible = isWindowVisible
        self.dominantSpeaker = dominantSpeaker
        self.pinnedData = pinnedData
        self.isFullScreen = isFullScreen
        self.mode = activeVideoViews.isEmpty ? mode : .video
        self.videoSources = videoSources
        self.version = version
        self.activeVideoViews = activeVideoViews
        self.hideParticipants = hideParticipants
        self.isVideoEnabled = isVideoEnabled
        self.tooltipSpeaker = tooltipSpeaker
        self.controlsTooltip = controlsTooltip
        self.dismissedTooltips = dismissedTooltips
        self.videoJoined = videoJoined
        self.myPeer = memberDatas.first(where: { $0.peer.id == $0.accountPeerId })
        var modeMembers:[GroupCallUIState.ActiveVideo.Mode : [PeerGroupCallData]] = [:]
        
        let modes:[GroupCallUIState.ActiveVideo.Mode] = [.list, .main]
        
        for mode in modes {
            var members:[PeerGroupCallData] = []
            for activeVideo in activeVideoViews.filter({ $0.mode == mode }) {
                let member = memberDatas.first(where: { peer in
                    
                    if let endpoint = peer.videoEndpoint {
                        if activeVideo.endpointId == endpoint {
                            return true
                        }
                    }
                    if let endpoint = peer.presentationEndpoint {
                        if activeVideo.endpointId == endpoint {
                            return true
                        }
                    }
                    return false
                })
                if let member = member, !members.contains(where: { $0.peer.id == member.peer.id }) {
                    members.append(member)
                }
            }
            modeMembers[mode] = members
        }
        self.activeVideoMembers = modeMembers
    }
    
    var hasVideo: Bool {
        return videoSources.video != nil
    }
    var hasScreencast: Bool {
        return videoSources.screencast != nil
    }
    
    deinit {
        
    }
    
    var cantRunVideo: Bool {
        if isVideoEnabled {
            return false
        }
        return (!videoJoined) && !memberDatas.filter({ $0.videoEndpointId != nil || $0.presentationEndpointId != nil }).isEmpty
    }
    
    var title: String {
        if state.scheduleTimestamp != nil {
            return L10n.voiceChatTitleScheduled
        } else if let custom = state.title, !custom.isEmpty {
            return custom
        } else {
            return peer.displayTitle
        }
    }
    
    static func == (lhs: GroupCallUIState, rhs: GroupCallUIState) -> Bool {
        if lhs.memberDatas != rhs.memberDatas {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.myAudioLevel != rhs.myAudioLevel {
            return false
        }
        if lhs.summaryState != rhs.summaryState {
            return false
        }
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if lhs.voiceSettings != rhs.voiceSettings {
            return false
        }
        if let lhsCachedData = lhs.cachedData, let rhsCachedData = rhs.cachedData {
            if !lhsCachedData.isEqual(to: rhsCachedData) {
                return false
            }
        } else if (lhs.cachedData != nil) != (rhs.cachedData != nil) {
            return false
        }
        if lhs.isWindowVisible != rhs.isWindowVisible {
            return false
        }
        if lhs.dominantSpeaker != rhs.dominantSpeaker {
            return false
        }
        if lhs.pinnedData != rhs.pinnedData {
            return false
        }
        if lhs.isFullScreen != rhs.isFullScreen {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.hasVideo != rhs.hasVideo {
            return false
        }
        if lhs.isMuted != rhs.isMuted {
            return false
        }
        if lhs.videoSources != rhs.videoSources {
            return false
        }
        if lhs.version != rhs.version {
            return false
        }
        if lhs.activeVideoViews != rhs.activeVideoViews {
            return false
        }
        if lhs.hideParticipants != rhs.hideParticipants {
            return false
        }
        if lhs.isVideoEnabled != rhs.isVideoEnabled {
            return false
        }
        if lhs.isMuted != rhs.isMuted {
            return false
        }
        if lhs.activeVideoMembers != rhs.activeVideoMembers {
            return false
        }
        if lhs.tooltipSpeaker != rhs.tooltipSpeaker {
            return false
        }
        if lhs.controlsTooltip != rhs.controlsTooltip {
            return false
        }
        if lhs.dismissedTooltips != rhs.dismissedTooltips {
            return false
        }
        if lhs.videoJoined != rhs.videoJoined {
            return false
        }
        return true
    }
    
    func videoActive(_ mode: ActiveVideo.Mode) -> [PeerGroupCallData] {
        return activeVideoMembers[mode] ?? []
    }
    
    func withUpdatedFullScreen(_ isFullScreen: Bool) -> GroupCallUIState {
        return .init(memberDatas: self.memberDatas, state: self.state, isMuted: self.isMuted, summaryState: self.summaryState, myAudioLevel: self.myAudioLevel, peer: self.peer, cachedData: self.cachedData, voiceSettings: self.voiceSettings, isWindowVisible: self.isWindowVisible, dominantSpeaker: self.dominantSpeaker, pinnedData: self.pinnedData, isFullScreen: isFullScreen, mode: self.mode, videoSources: self.videoSources, version: self.version, activeVideoViews: self.activeVideoViews, hideParticipants: self.hideParticipants, isVideoEnabled: self.isVideoEnabled, tooltipSpeaker: self.tooltipSpeaker, controlsTooltip: self.controlsTooltip, dismissedTooltips: self.dismissedTooltips, videoJoined: self.videoJoined)
    }
}


extension GroupCallUIState.ControlsTooltip {
    var text: String {
        switch self {
        case .camera:
            return L10n.voiceChatTooltipEnableCamera
        case .micro:
            return L10n.voiceChatTooltipEnableMicro
        }
    }
}
