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
import SyncCore
import TelegramCore
import TgVoipWebrtc

final class GroupCallUIState : Equatable {

    struct RecentActive : Equatable {
        let peerId: PeerId
        let timestamp: TimeInterval
    }
    
    enum Mode : Equatable {
        case voice
        case video
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
    let currentDominantSpeakerWithVideo: DominantVideo?
    let activeVideoSources: Set<String>
    let isFullScreen: Bool
    let mode: Mode
    let hasVideo: Bool
    let videoSource: VideoSourceMac?
    init(memberDatas: [PeerGroupCallData], state: PresentationGroupCallState, isMuted: Bool, summaryState: PresentationGroupCallSummaryState?, myAudioLevel: Float, peer: Peer, cachedData: CachedChannelData?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, currentDominantSpeakerWithVideo: DominantVideo?, activeVideoSources: Set<String>, isFullScreen: Bool, mode: Mode, hasVideo: Bool, videoSource: VideoSourceMac?) {
        self.summaryState = summaryState
        self.memberDatas = memberDatas
        self.peer = peer
        self.isMuted = isMuted
        self.cachedData = cachedData
        self.state = state
        self.myAudioLevel = myAudioLevel
        self.voiceSettings = voiceSettings
        self.isWindowVisible = isWindowVisible
        self.currentDominantSpeakerWithVideo = currentDominantSpeakerWithVideo
        self.activeVideoSources = activeVideoSources
        self.isFullScreen = isFullScreen
        self.mode = mode
        self.hasVideo = hasVideo
        self.videoSource = videoSource
    }
    
    deinit {
        
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
        if lhs.currentDominantSpeakerWithVideo != rhs.currentDominantSpeakerWithVideo {
            return false
        }
        if lhs.activeVideoSources != rhs.activeVideoSources {
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
        if let lhsSource = lhs.videoSource, let rhsSource = rhs.videoSource {
            if !lhsSource.isEqual(rhsSource) {
                return false
            }
        } else if (lhs.videoSource != nil) != (rhs.videoSource != nil) {
            return false
        }
        return true
    }
    
    func withUpdatedFullScreen(_ isFullScreen: Bool) -> GroupCallUIState {
        return .init(memberDatas: self.memberDatas, state: self.state, isMuted: self.isMuted, summaryState: self.summaryState, myAudioLevel: self.myAudioLevel, peer: self.peer, cachedData: self.cachedData, voiceSettings: self.voiceSettings, isWindowVisible: self.isWindowVisible, currentDominantSpeakerWithVideo: self.currentDominantSpeakerWithVideo, activeVideoSources: self.activeVideoSources, isFullScreen: isFullScreen, mode: self.mode, hasVideo: self.hasVideo, videoSource: self.videoSource)
    }
}
