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
import SyncCore
import TelegramCore
import HotKey
import TgVoipWebrtc

let fullScreenThreshold: CGFloat = 500

final class GroupCallUIArguments {
    let leave:()->Void
    let settings:()->Void
    let invite:(PeerId)->Void
    let mute:(PeerId, Bool)->Void
    let toggleSpeaker:()->Void
    let remove:(Peer)->Void
    let openInfo: (Peer)->Void
    let inviteMembers:()->Void
    let shareSource:(VideoSourceMacMode)->Void
    let takeVideo:(PeerId, VideoSourceMacMode?)->NSView?
    let isStreamingVideo:(PeerId)->Bool
    let canUnpinVideo:(PeerId, VideoSourceMacMode)->Bool
    let setVolume: (PeerId, Double, Bool) -> Void
    let pinVideo:(DominantVideo)->Void
    let unpinVideo:(VideoSourceMacMode)->Void
    let isPinnedVideo:(PeerId, VideoSourceMacMode)->Bool
    let getAccountPeerId: ()->PeerId?
    let cancelShareScreencast: ()->Void
    let cancelShareVideo: ()->Void
    let toggleRaiseHand:()->Void
    let recordClick:(PresentationGroupCallState)->Void
    let audioLevel:(PeerId)->Signal<Float?, NoError>?
    let startVoiceChat:()->Void
    let toggleReminder:(Bool)->Void
    let toggleScreenMode:()->Void
    let futureWidth:()->CGFloat?
    init(leave:@escaping()->Void,
    settings:@escaping()->Void,
    invite:@escaping(PeerId)->Void,
    mute:@escaping(PeerId, Bool)->Void,
    toggleSpeaker:@escaping()->Void,
    remove:@escaping(Peer)->Void,
    openInfo: @escaping(Peer)->Void,
    inviteMembers:@escaping()->Void,
    shareSource: @escaping(VideoSourceMacMode)->Void,
    takeVideo:@escaping(PeerId, VideoSourceMacMode?)->NSView?,
    isStreamingVideo: @escaping(PeerId)->Bool,
    canUnpinVideo:@escaping(PeerId, VideoSourceMacMode)->Bool,
    pinVideo:@escaping(DominantVideo)->Void,
    unpinVideo:@escaping(VideoSourceMacMode)->Void,
    isPinnedVideo:@escaping(PeerId, VideoSourceMacMode)->Bool,
    setVolume: @escaping(PeerId, Double, Bool)->Void,
    getAccountPeerId: @escaping()->PeerId?,
    cancelShareScreencast: @escaping()->Void,
    cancelShareVideo: @escaping()->Void,
    toggleRaiseHand:@escaping()->Void,
    recordClick:@escaping(PresentationGroupCallState)->Void,
    audioLevel:@escaping(PeerId)->Signal<Float?, NoError>?,
    startVoiceChat:@escaping()->Void,
    toggleReminder:@escaping(Bool)->Void,
    toggleScreenMode:@escaping()->Void,
    futureWidth:@escaping()->CGFloat?) {
        self.leave = leave
        self.invite = invite
        self.mute = mute
        self.settings = settings
        self.toggleSpeaker = toggleSpeaker
        self.remove = remove
        self.openInfo = openInfo
        self.inviteMembers = inviteMembers
        self.shareSource = shareSource
        self.takeVideo = takeVideo
        self.isStreamingVideo = isStreamingVideo
        self.canUnpinVideo = canUnpinVideo
        self.pinVideo = pinVideo
        self.unpinVideo = unpinVideo
        self.isPinnedVideo = isPinnedVideo
        self.setVolume = setVolume
        self.getAccountPeerId = getAccountPeerId
        self.cancelShareVideo = cancelShareVideo
        self.cancelShareScreencast = cancelShareScreencast
        self.toggleRaiseHand = toggleRaiseHand
        self.recordClick = recordClick
        self.audioLevel = audioLevel
        self.startVoiceChat = startVoiceChat
        self.toggleReminder = toggleReminder
        self.toggleScreenMode = toggleScreenMode
        self.futureWidth = futureWidth
    }
}




struct PeerGroupCallData : Equatable, Comparable {

    
    struct AudioLevel {
        let timestamp: Int32
        let value: Float
    }

    let peer: Peer
    let state: GroupCallParticipantsContext.Participant?
    let isSpeaking: Bool
    let isInvited: Bool
    let unsyncVolume: Int32?
    let pinnedMode: VideoSourceMacMode?
    let accountPeerId: PeerId
    let accountAbout: String?
    let canManageCall: Bool
    let hideWantsToSpeak: Bool
    let activityTimestamp: Int32
    let firstTimestamp: Int32
    let videoMode: Bool
    let isVertical: Bool
    let hasVideo: Bool
    var isRaisedHand: Bool {
        return self.state?.hasRaiseHand == true
    }
    var wantsToSpeak: Bool {
        return isRaisedHand && !hideWantsToSpeak
    }
    
    var videoEndpoint: String? {
        return state?.videoEndpointId
    }
    var screencastEndPoint: String? {
        return state?.presentationEndpointId
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
    
    var status: (String, NSColor) {
        var string:String = L10n.peerStatusRecently
        var color:NSColor = GroupCallTheme.grayStatusColor
        if let state = state {
            if wantsToSpeak, let _ = state.muteState {
                string = L10n.voiceChatStatusWantsSpeak
                color = GroupCallTheme.blueStatusColor
            } else if let muteState = state.muteState, muteState.mutedByYou {
                string = muteState.mutedByYou ? L10n.voiceChatStatusMutedForYou : L10n.voiceChatStatusMuted
                color = GroupCallTheme.speakLockedColor
            } else if isSpeaking {
                string = L10n.voiceChatStatusSpeaking
                color = GroupCallTheme.greenStatusColor
            } else {
                if let about = about {
                    string = about
                    color = GroupCallTheme.grayStatusColor
                } else {
                    string = L10n.voiceChatStatusListening
                    color = GroupCallTheme.grayStatusColor
                }
            }
        } else if peer.id == accountPeerId {
            if let about = about {
                string = about
                color = GroupCallTheme.grayStatusColor.withAlphaComponent(0.6)
            } else {
                string = L10n.voiceChatStatusConnecting.lowercased()
                color = GroupCallTheme.grayStatusColor.withAlphaComponent(0.6)
            }
        } else if isInvited {
            string = L10n.voiceChatStatusInvited
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
        if lhs.isInvited != rhs.isInvited {
            return false
        }
        if lhs.pinnedMode != rhs.pinnedMode {
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
        return true
    }
    
    static func <(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        if lhs.pinnedMode != nil && rhs.pinnedMode == nil {
            return true
        }
        if lhs.activityTimestamp != rhs.activityTimestamp {
            return lhs.activityTimestamp > rhs.activityTimestamp
        }
        return lhs.firstTimestamp > rhs.firstTimestamp
    }
}





private func _id_peer_id(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_peer_id_\(id.toInt64())")
}

private func makeState(peerView: PeerView, state: PresentationGroupCallState, isMuted: Bool, invitedPeers: [Peer], peerStates: PresentationGroupCallMembers?, myAudioLevel: Float, summaryState: PresentationGroupCallSummaryState?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, accountPeer: (Peer, String?), unsyncVolumes: [PeerId: Int32], currentDominantSpeakerWithVideo: DominantVideo?, activeVideoSources: Set<String>, hideWantsToSpeak: Set<PeerId>, isFullScreen: Bool, mode: GroupCallUIState.Mode, videoSources: GroupCallUIState.VideoSources) -> GroupCallUIState {
    
    var memberDatas: [PeerGroupCallData] = []
    
    let accountPeerId = accountPeer.0.id
    let accountPeerAbout = accountPeer.1
    var activeParticipants: [GroupCallParticipantsContext.Participant] = []
    
    activeParticipants = peerStates?.participants ?? []
    var index: Int32 = 0
    
    let currentDominantSpeakerWithVideo = currentDominantSpeakerWithVideo

    
    func hasVideo(_ peerId: PeerId) -> Bool {
        return activeParticipants.first(where: { participant in
            if participant.peer.id != peerId {
                return false
            }
            if let endpoint = participant.presentationEndpointId {
                if activeVideoSources.contains(endpoint) {
                    return true
                }
            }
            if let endpoint = participant.videoEndpointId {
                if activeVideoSources.contains(endpoint) {
                    return true
                }
            }
            return false
        }) != nil
    }
    
    if !activeParticipants.contains(where: { $0.peer.id == accountPeerId }) {
        let pinnedMode: VideoSourceMacMode?
        if let current = currentDominantSpeakerWithVideo, current.peerId == accountPeerId {
            pinnedMode = current.mode
        } else {
            pinnedMode = nil
        }
        memberDatas.append(PeerGroupCallData(peer: accountPeer.0, state: nil, isSpeaking: false, isInvited: false, unsyncVolume: unsyncVolumes[accountPeerId], pinnedMode: pinnedMode, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(accountPeerId), activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: currentDominantSpeakerWithVideo != nil, isVertical: isFullScreen && currentDominantSpeakerWithVideo != nil, hasVideo: hasVideo(accountPeerId)))
        index += 1
    } 

    let pinned = activeParticipants.firstIndex(where: { $0.peer.id == currentDominantSpeakerWithVideo?.peerId })

    if let pinnedIndex = pinned {
        activeParticipants.insert(activeParticipants.remove(at: pinnedIndex), at: 0)
    }
    
    for value in activeParticipants {
        var isSpeaking = peerStates?.speakingParticipants.contains(value.peer.id) ?? false
        if accountPeerId == value.peer.id, isMuted {
            isSpeaking = false
        }
        let pinnedMode: VideoSourceMacMode?
        if let current = currentDominantSpeakerWithVideo, current.peerId == value.peer.id {
            pinnedMode = current.mode
        } else {
            pinnedMode = nil
        }
        memberDatas.append(PeerGroupCallData(peer: value.peer, state: value, isSpeaking: isSpeaking, isInvited: false, unsyncVolume: unsyncVolumes[value.peer.id], pinnedMode: pinnedMode, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(value.peer.id), activityTimestamp: Int32.max - 1 - index, firstTimestamp: value.joinTimestamp, videoMode: currentDominantSpeakerWithVideo != nil, isVertical: isFullScreen && currentDominantSpeakerWithVideo != nil, hasVideo: hasVideo(value.peer.id)))
        index += 1
    }
    
    for invited in invitedPeers {
        if !activeParticipants.contains(where: { $0.peer.id == invited.id}) {
            memberDatas.append(PeerGroupCallData(peer: invited, state: nil, isSpeaking: false, isInvited: true, unsyncVolume: nil, pinnedMode: nil, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: false, activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: currentDominantSpeakerWithVideo != nil, isVertical: isFullScreen && currentDominantSpeakerWithVideo != nil, hasVideo: false))
            index += 1
        }
    }

    return GroupCallUIState(memberDatas: memberDatas.sorted(), state: state, isMuted: isMuted, summaryState: summaryState, myAudioLevel: myAudioLevel, peer: peerViewMainPeer(peerView)!, cachedData: peerView.cachedData as? CachedChannelData, voiceSettings: voiceSettings, isWindowVisible: isWindowVisible, currentDominantSpeakerWithVideo: currentDominantSpeakerWithVideo, activeVideoSources: activeVideoSources, isFullScreen: isFullScreen, mode: mode, videoSources: videoSources)
}


private func peerEntries(state: GroupCallUIState, account: Account, arguments: GroupCallUIArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
        
    let canInvite: Bool = true//!state.isFullScreen || state.currentDominantSpeakerWithVideo == nil
    
    if canInvite {
        
        struct Tuple : Equatable {
            let viewType: GeneralViewType
            let videoMode: Bool
        }
        let viewType = GeneralViewType.singleItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 0, 0))
        let tuple = Tuple(viewType: viewType, videoMode: state.currentDominantSpeakerWithVideo != nil)
        
        entries.append(.custom(sectionId: 0, index: index, value: .none, identifier: InputDataIdentifier("invite"), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return GroupCallInviteRowItem(initialSize, height: 42, stableId: stableId, videoMode: tuple.videoMode, viewType: viewType, action: arguments.inviteMembers, futureWidth: arguments.futureWidth)
        }))
        index += 1

    }




    for (i, data) in state.memberDatas.enumerated() {

        let drawLine = i != state.memberDatas.count - 1

        var viewType: GeneralViewType = bestGeneralViewType(state.memberDatas, for: i)
        if i == 0, canInvite {
            viewType = i != state.memberDatas.count - 1 ? .innerItem : .lastItem
        }

        struct Tuple : Equatable {
            let drawLine: Bool
            let data: PeerGroupCallData
            let canManageCall:Bool
            let adminIds: Set<PeerId>
            let viewType: GeneralViewType
        }

        let tuple = Tuple(drawLine: drawLine, data: data, canManageCall: state.state.canManageCall, adminIds: state.state.adminIds, viewType: viewType)


        let comparable = InputDataComparableIndex(data: data, compare: { lhs, rhs in
            let lhs = lhs as? PeerGroupCallData
            let rhs = rhs as? PeerGroupCallData
            if let lhs = lhs, let rhs = rhs {
                return lhs < rhs
            } else {
                return false
            }
        }, equatable: { lhs, rhs in
            let lhs = lhs as? PeerGroupCallData
            let rhs = rhs as? PeerGroupCallData
            if let lhs = lhs, let rhs = rhs {
                return lhs.state == rhs.state
            } else {
                return false
            }
        })
        
        entries.append(.custom(sectionId: 0, index: index, value: .none, identifier: _id_peer_id(data.peer.id), equatable: InputDataEquatable(tuple), comparable: comparable, item: { initialSize, stableId in
            return GroupCallParticipantRowItem(initialSize, stableId: stableId, account: account, data: tuple.data, canManageCall: tuple.canManageCall, isInvited: tuple.data.isInvited, isLastItem: false, drawLine: drawLine, viewType: viewType, action: {
                
            }, invite: arguments.invite, contextMenu: {
                var items: [ContextMenuItem] = []

                let data = tuple.data
                if let state = tuple.data.state {
                    
                    if data.peer.id == arguments.getAccountPeerId(), data.isRaisedHand {
                        items.append(ContextMenuItem(L10n.voiceChatDownHand, handler: arguments.toggleRaiseHand))
                    }
                    
                    if data.peer.id != arguments.getAccountPeerId(), state.muteState == nil || state.muteState?.canUnmute == true {
                        let volume: ContextMenuItem = .init("Volume", handler: {

                        })

                        let volumeControl = VolumeMenuItemView(frame: NSMakeRect(0, 0, 160, 26))
                        volumeControl.stateImages = (on: NSImage(named: "Icon_VolumeMenu_On")!.precomposed(.white),
                                                     off: NSImage(named: "Icon_VolumeMenu_Off")!.precomposed(.white))
                        volumeControl.value = CGFloat((state.volume ?? 10000)) / 10000.0
                        volumeControl.lineColor = GroupCallTheme.memberSeparatorColor.lighter()
                        volume.view = volumeControl

                        volumeControl.didUpdateValue = { value, sync in
                            if value == 0 {
                                arguments.mute(data.peer.id, true)
                            } else {
                                arguments.setVolume(data.peer.id, Double(value), sync)
                            }
                        }

                        items.append(volume)
                        items.append(ContextSeparatorItem())
                    }
                    if let endpointId = data.videoEndpoint {
                        if !arguments.isPinnedVideo(data.peer.id, .video) {
                            items.append(ContextMenuItem(L10n.voiceChatPinVideo, handler: {
                                arguments.pinVideo(.init(data.peer.id, endpointId, .video))
                            }))
                        } else if arguments.canUnpinVideo(data.peer.id, .video) {
                            items.append(ContextMenuItem(L10n.voiceChatUnpinVideo, handler: {
                                arguments.unpinVideo(.video)
                            }))
                        }
                    }
                    if let endpointId = data.screencastEndPoint {
                        if !arguments.isPinnedVideo(data.peer.id, .screencast) {
                            items.append(ContextMenuItem(L10n.voiceChatPinScreencast, handler: {
                                arguments.pinVideo(.init(data.peer.id, endpointId, .screencast))
                            }))
                        } else if arguments.canUnpinVideo(data.peer.id, .screencast) {
                            items.append(ContextMenuItem(L10n.voiceChatUnpinScreencast, handler: {
                                arguments.unpinVideo(.screencast)
                            }))
                        }
                    }
                    
                    
                    
                    if !tuple.canManageCall, data.peer.id != arguments.getAccountPeerId() {
                        if let muteState = state.muteState {
                            if muteState.mutedByYou {
                                items.append(.init(L10n.voiceChatUnmuteForMe, handler: {
                                    arguments.mute(data.peer.id, false)
                                }))
                            } else {
                                items.append(.init(L10n.voiceChatMuteForMe, handler: {
                                    arguments.mute(data.peer.id, true)
                                }))
                            }
                        } else {
                            items.append(.init(L10n.voiceChatMuteForMe, handler: {
                                arguments.mute(data.peer.id, true)
                            }))
                        }                        
                        items.append(ContextSeparatorItem())
                    }
                    
                    if tuple.canManageCall, data.peer.id != arguments.getAccountPeerId() {
                        if tuple.adminIds.contains(data.peer.id) {
                            if state.muteState == nil {
                                items.append(.init(L10n.voiceChatMutePeer, handler: {
                                    arguments.mute(data.peer.id, true)
                                }))
                            }
                            if !tuple.adminIds.contains(data.peer.id), !tuple.data.peer.isChannel {
                                items.append(.init(L10n.voiceChatRemovePeer, handler: {
                                    arguments.remove(data.peer)
                                }))
                            }
                            if !items.isEmpty {
                                items.append(ContextSeparatorItem())
                            }
                        } else if let muteState = state.muteState, !muteState.canUnmute {
                            items.append(.init(L10n.voiceChatUnmutePeer, handler: {
                                arguments.mute(data.peer.id, false)
                            }))
                        } else {
                            items.append(.init(L10n.voiceChatMutePeer, handler: {
                                arguments.mute(data.peer.id, true)
                            }))
                        }
                        if !tuple.adminIds.contains(data.peer.id), !tuple.data.peer.isChannel {
                            items.append(.init(L10n.voiceChatRemovePeer, handler: {
                                arguments.remove(data.peer)
                            }))
                        }
                        if !items.isEmpty {
                            items.append(ContextSeparatorItem())
                        }
                    }
                    
                    if data.peer.id != arguments.getAccountPeerId() {
                        items.append(.init(L10n.voiceChatShowInfo, handler: {
                            arguments.openInfo(data.peer)
                        }))
                    }
                }
                return .single(items)
            }, takeVideo: arguments.takeVideo, audioLevel: arguments.audioLevel, futureWidth: arguments.futureWidth)
        }))
//        index += 1

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
    private weak var sharing: DesktopCapturerWindow?

    private var requestedVideoSources = Set<String>()
    private var videoViews: [(DominantVideo, GroupVideoView)] = []
    private var currentDominantSpeakerWithVideoSignal:Promise<DominantVideo?> = Promise(nil)
    private var pinnedDominantSpeaker: DominantVideo? = nil
    private var currentDominantSpeakerWithVideo: DominantVideo? {
        didSet {
            currentDominantSpeakerWithVideoSignal.set(.single(currentDominantSpeakerWithVideo))
        }
    }
    private var idleTimer: SwiftSignalKit.Timer?

    
    var disableSounds: Bool = false
    init(_ data: UIData, size: NSSize) {
        self.data = data
        super.init(frame: NSMakeRect(0, 0, size.width, size.height))
        bar = .init(height: 0)
        isFullScreen.set(size.width >= fullScreenThreshold)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        self.isFullScreen.set(size.width >= fullScreenThreshold)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let actionsDisposable = self.actionsDisposable
                
        let peerId = self.data.call.peerId
        let account = self.data.call.account
                
       
        
        
        let videoSources = ValuePromise<GroupCallUIState.VideoSources>(.init())
        let videoSourcesValue: Atomic<GroupCallUIState.VideoSources> = Atomic(value: .init())
        let updateVideoSources:(@escaping(GroupCallUIState.VideoSources)->GroupCallUIState.VideoSources)->Void = { f in
            videoSources.set(videoSourcesValue.modify(f))
        }
        
        let mode: Signal<GroupCallUIState.Mode, NoError> = combineLatest(videoSources.get(), self.data.call.callInfo) |> map { videoSources, info in
            let isVideoEnabled = info?.isVideoEnabled ?? false
            switch isVideoEnabled || !videoSources.isEmpty {
            case true:
                return .video
            case false:
                return .voice
            }
        } |> distinctUntilChanged
        
//
//        actionsDisposable.add((mode |> deliverOnMainQueue).start(next: { [weak self] mode in
//            switch mode {
//            case .voice:
//                if videoSourcesValue.with ({ $0.screencast != nil }) {
//                    self?.data.call.disableScreencast()
//                }
//                if videoSourcesValue.with ({ $0.video != nil }) {
//                    self?.data.call.disableVideo()
//                }
//                updateVideoSources { current in
//                    var current = current
//                    current.screencast = nil
//                    current.video = nil
//                    return current
//                }
//            default:
//                break
//            }
//        }))
                
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
        
        
        let bestDominantSpeakerWithVideo:(Bool)->DominantVideo? = { [weak self] ignorePinned in
            guard let strongSelf = self else {
                return nil
            }
            guard let state = strongSelf.genericView.state else {
                return nil
            }
            
            let members = state.memberDatas.filter { member in
                if let endpointId = member.state?.videoEndpointId {
                    if state.activeVideoSources.contains(endpointId) {
                        return true
                    }
                }
                if let endpointId = member.state?.presentationEndpointId {
                    if state.activeVideoSources.contains(endpointId) {
                        return true
                    }
                }
                return false
            }
            if !ignorePinned {
                if let pinned = strongSelf.pinnedDominantSpeaker {
                    let isActive = members.contains(where: { value in
                        if value.peer.id == pinned.peerId {
                            if value.videoEndpoint == pinned.endpointId {
                                return true
                            }
                            if value.screencastEndPoint == pinned.endpointId {
                                return true
                            }
                        }
                        return false
                    })
                    if state.activeVideoSources.contains(pinned.endpointId), isActive {
                        return pinned
                    }
                }
            }
            
            
            
            for member in members {
                if let endpointId = member.videoEndpoint {
                    let hasVideo = member.hasVideo
                    if hasVideo && member.peer.id == member.accountPeerId, members.count > 1 {
                        continue
                    }
                    if hasVideo {
                        return DominantVideo(member.peer.id, endpointId, .video)
                    }
                }
                if let endpointId = member.screencastEndPoint {
                    let hasVideo = member.hasVideo
                    if hasVideo && member.peer.id == member.accountPeerId, members.count > 1 {
                        continue
                    }
                    if hasVideo {
                        return DominantVideo(member.peer.id, endpointId, .screencast)
                    }
                }
            }
            return nil
        }
        
        let selectBestDominantSpeakerWithVideo:()->Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let current = bestDominantSpeakerWithVideo(false) {
                strongSelf.pinnedDominantSpeaker = current
                if strongSelf.currentDominantSpeakerWithVideo != current {
                    if current.peerId == strongSelf.data.call.joinAsPeerId {
                        strongSelf.currentDominantSpeakerWithVideo = current
                        strongSelf.data.call.setFullSizeVideo(endpointId: nil)
                    } else {
                        strongSelf.currentDominantSpeakerWithVideo = current
                        strongSelf.data.call.setFullSizeVideo(endpointId: current.endpointId)
                    }
                }
            } else {
                strongSelf.pinnedDominantSpeaker = nil
                strongSelf.currentDominantSpeakerWithVideo = nil
                strongSelf.data.call.setFullSizeVideo(endpointId: nil)
            }
            
            
        }
        
        var futureWidth: CGFloat? = nil
        
        
        let arguments = GroupCallUIArguments(leave: { [weak self] in

            guard let `self` = self, let window = self.window else {
                return
            }
            if self.canManageCall {
                modernConfirm(for: window, account: account, peerId: nil, header: L10n.voiceChatEndTitle, information: L10n.voiceChatEndText, okTitle: L10n.voiceChatEndOK, thridTitle: L10n.voiceChatEndThird, thridAutoOn: false, successHandler: {
                    [weak self] result in
                    _ = self?.data.call.sharedContext.endGroupCall(terminate: result == .thrid).start()
                })
            } else {
                _ = self.data.call.sharedContext.endGroupCall(terminate: false).start()
            }
        }, settings: { [weak self] in
            guard let `self` = self else {
                return
            }
            self.navigationController?.push(GroupCallSettingsController(sharedContext: sharedContext, account: account, call: self.data.call))
        }, invite: { [weak self] peerId in
            _ = self?.data.call.invitePeer(peerId)
        }, mute: { [weak self] peerId, isMuted in
            _ = self?.data.call.updateMuteState(peerId: peerId, isMuted: isMuted)
        }, toggleSpeaker: { [weak self] in
            self?.data.call.toggleIsMuted()
        }, remove: { [weak self] peer in
            guard let window = self?.window else {
                return
            }
            let isChannel = self?.data.call.peer?.isChannel == true
            
            modernConfirm(for: window, account: account, peerId: peer.id, information: isChannel ? L10n.voiceChatRemovePeerConfirmChannel(peer.displayTitle) : L10n.voiceChatRemovePeerConfirm(peer.displayTitle), okTitle: L10n.voiceChatRemovePeerConfirmOK, cancelTitle: L10n.voiceChatRemovePeerConfirmCancel, successHandler: { [weak window] _ in

                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    _ = self?.data.peerMemberContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: 0)).start()
                } else if let window = window {
                    _ = showModalProgress(signal: removePeerMember(account: account, peerId: peerId, memberId: peer.id), for: window).start()
                }

            }, appearance: darkPalette.appearance)
        }, openInfo: { [weak self] peer in
            guard let window = self?.window else {
                return
            }
            showModal(with: GroupCallPeerController(account: account, peer: peer), for: window)
        }, inviteMembers: { [weak self] in
            guard let window = self?.window, let data = self?.data else {
                return
            }
            actionsDisposable.add(GroupCallAddmembers(data, window: window).start(next: { [weak window, weak self] peerId in
                if let peerId = peerId.first, let window = window, let `self` = self {
                    if self.data.call.invitePeer(peerId) {
                        _ = showModalSuccess(for: window, icon: theme.icons.successModalProgress, delay: 2.0).start()
                    }
                }
            }))
        }, shareSource: { [weak self] mode in
            if let sharing = self?.sharing, sharing.mode == mode {
                sharing.orderFront(nil)
            } else {
                self?.sharing?.orderOut(nil)
                let sharing = presentDesktopCapturerWindow(mode: mode, select: { source in
                    updateVideoSources { current in
                        var current = current
                        switch source.mode {
                        case .screencast:
                            current.screencast = source
                        case .video:
                            current.video = source
                        }
                        return current
                    }
                    switch source.mode {
                    case .screencast:
                        self?.data.call.requestScreencast(deviceId: source.deviceIdKey())
                    case .video:
                        self?.data.call.requestVideo(deviceId: source.deviceIdKey())
                    }
                }, devices: sharedContext.devicesContext)
                self?.sharing = sharing
                if sharing == nil, let window = self?.window {
                    switch mode {
                    case .video:
                        showModalText(for: window, text: L10n.voiceChatTooltipNoCameraFound)
                    default:
                        break
                    }
                }
            }
        }, takeVideo: { [weak self] peerId, mode in
            if let dominant = self?.currentDominantSpeakerWithVideo {
                if dominant.peerId == peerId {
                    if let mode = mode {
                        if dominant.mode == mode {
                            return nil
                        }
                    } else {
                        return nil
                    }
                }
            }
            let view = self?.videoViews.first(where: { $0.0.peerId == peerId && $0.0.mode == mode })?.1
            if let view = view {
                return view
            } else {
                return nil
            }
        }, isStreamingVideo: { [weak self] peerId in
            return self?.videoViews.first(where: { $0.0.peerId == peerId }) != nil
        }, canUnpinVideo: { peerId, mode in
            if let current = bestDominantSpeakerWithVideo(true) {
                return current.peerId != peerId
            }
            return false
        }, pinVideo: { [weak self] video in
            if video.peerId == self?.data.call.joinAsPeerId {
                self?.data.call.setFullSizeVideo(endpointId: nil)
            } else {
                self?.data.call.setFullSizeVideo(endpointId: video.endpointId)
            }
            self?.pinnedDominantSpeaker = video
            self?.currentDominantSpeakerWithVideo = video
            self?.genericView.peersTable.scroll(to: .up(true))
        }, unpinVideo: { [weak self] mode in
            self?.pinnedDominantSpeaker = nil
            selectBestDominantSpeakerWithVideo()
        }, isPinnedVideo: { [weak self] peerId, mode in
            if let current = self?.currentDominantSpeakerWithVideo {
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
        }, cancelShareScreencast: { [weak self] in
            updateVideoSources {current in
                var current = current
                current.screencast = nil
                return current
            }
            self?.data.call.disableScreencast()
        }, cancelShareVideo: { [weak self] in
            updateVideoSources {current in
                var current = current
                current.video = nil
                return current
            }
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
                    confirm(for: window, header: L10n.voiceChatRecordingStopTitle, information: L10n.voiceChatRecordingStopText, okTitle: L10n.voiceChatRecordingStopOK, successHandler: { [weak window] _ in
                        self?.data.call.setShouldBeRecording(false, title: nil)
                        if let window = window {
                            showModalText(for: window, text: L10n.voiceChatToastStop)
                        }
                    })
                } else {
                    showModalText(for: window, text: L10n.voiceChatAlertRecording)
                }
            }
        }, audioLevel: { [weak self] peerId in
            if let call = self?.data.call {
                if peerId == call.joinAsPeerId {
                    return combineLatest(animate, call.myAudioLevel)
                        |> map (Optional.init)
                        |> map { $0?.1 == 0 || $0?.0 == false ? nil : $0?.1 }
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
                showModalText(for: window, text: L10n.voiceChatTooltipSubscribe)
            }
            self?.data.call.toggleScheduledSubscription(subscribe)
        }, toggleScreenMode: { [weak self, weak window] in
            guard let strongSelf = self, let window = window else {
                return
            }
            let isFullScreen = strongSelf.genericView.isFullScreen && strongSelf.genericView.state?.currentDominantSpeakerWithVideo != nil
            
            var rect: CGRect
            if isFullScreen {
                rect = CGRect(origin: window.frame.origin, size: GroupCallTheme.minSize)
            } else {
                rect = CGRect(origin: window.frame.origin, size: GroupCallTheme.minFullScreenSize)
            }
            rect.size.height = window.frame.height

            
            strongSelf.genericView.tempFullScreen = !isFullScreen
            futureWidth = rect.width
            let state = strongSelf.genericView.state!.withUpdatedFullScreen(!isFullScreen)
            
            

            strongSelf.genericView.peersTable.enumerateItems(with: { item in
                _ = item.makeSize()
                item.redraw(animated: true, options: .effectFade)
                return true
            })
            strongSelf.genericView.peersTable.beginTableUpdates()

            strongSelf.isFullScreen.set(!isFullScreen)

            strongSelf.applyUpdates(state, .init(deleted: [], inserted: [], updated: [], animated: true), strongSelf.data.call, animated: true)
            window.setFrame(rect, display: true, animate: true)
            strongSelf.genericView.tempFullScreen = nil
            futureWidth = nil
            
            strongSelf.genericView.peersTable.endTableUpdates()

            
        }, futureWidth: {
            return futureWidth
        })
        

        genericView.arguments = arguments
        
        
        let members = data.call.members
        
        self.voiceSourcesDisposable.set((combineLatest(self.data.call.incomingVideoSources, members, data.call.joinAsPeerIdValue) |> deliverOnMainQueue).start(next: { [weak self] endpointIds, members, accountId in
            guard let strongSelf = self else {
                return
            }
        
            var updated = false
            var validSources = Set<String>()
            for endpointId in endpointIds {
                
                let member = members?.participants.first(where: {
                    $0.videoEndpointId == endpointId || $0.presentationEndpointId == endpointId
                })
                if let member = member {
                    validSources.insert(endpointId)
                    if !strongSelf.requestedVideoSources.contains(endpointId) {
                        strongSelf.requestedVideoSources.insert(endpointId)
                        
                        let isScreencast = member.presentationEndpointId == endpointId
                        let videoMode: VideoSourceMacMode = isScreencast ? .screencast : .video
                        let takeVideoMode: GroupCallVideoMode = isScreencast && member.peer.id == accountId ? .screencast : .video
                                                
                        strongSelf.data.call.makeVideoView(endpointId: endpointId, videoMode: takeVideoMode, completion: { videoView in
                            Queue.mainQueue().async {
                                guard let strongSelf = self, let videoView = videoView else {
                                    return
                                }
                                let videoViewValue = GroupVideoView(videoView: videoView)
                                videoView.setVideoContentMode(.resizeAspectFill)

                                strongSelf.videoViews.append((DominantVideo(member.peer.id, endpointId, videoMode), videoViewValue))
                                strongSelf.genericView.peersTable.enumerateItems(with: { item in
                                    item.redraw(animated: true)
                                    return true
                                })
                            }
                        })
                    }
                }
            }

            for i in (0 ..< strongSelf.videoViews.count).reversed() {
                if !validSources.contains(strongSelf.videoViews[i].0.endpointId) {
                    let ssrc = strongSelf.videoViews[i].0.endpointId
                    strongSelf.videoViews.remove(at: i)
                    strongSelf.requestedVideoSources.remove(ssrc)
                    updated = true
               }
           }


            if updated {
                DispatchQueue.main.async {
                    selectBestDominantSpeakerWithVideo()
                }
                strongSelf.genericView.peersTable.enumerateItems(with: { item in
                    item.redraw(animated: true)
                    return true
                })
            }
        }))

        


        
        let invited: Signal<[Peer], NoError> = self.data.call.invitedPeers |> mapToSignal { ids in
            return account.postbox.transaction { transaction -> [Peer] in
                var peers:[Peer] = []
                for id in ids {
                    if let peer = transaction.getPeer(id) {
                        peers.append(peer)
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
        
        let some = combineLatest(queue: .mainQueue(), self.data.call.isMuted, animate, joinAsPeer, unsyncVolumes.get(), currentDominantSpeakerWithVideoSignal.get(), self.data.call.incomingVideoSources, isFullScreen.get())


        let state: Signal<GroupCallUIState, NoError> = combineLatest(queue: .mainQueue(), self.data.call.state, members, (.single(0) |> then(data.call.myAudioLevel)), account.viewTracker.peerView(peerId), invited, self.data.call.summaryState, voiceCallSettings(data.call.sharedContext.accountManager), some, displayedRaisedHandsPromise.get(), mode, videoSources.get()) |> mapToQueue { values in
            return .single(makeState(peerView: values.3,
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
                                     currentDominantSpeakerWithVideo: values.7.4,
                                     activeVideoSources: values.7.5,
                                     hideWantsToSpeak: values.8,
                                     isFullScreen: values.7.6,
                                     mode: values.9,
                                     videoSources: values.10))
        } |> distinctUntilChanged
        
        
//        var invokeAfterTransaction:()
//        window.processFullScreen = { f in
//
//        }
//
        let initialSize = self.atomicSize
        var previousIsFullScreen: Bool = initialSize.with { $0.width >= fullScreenThreshold }
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let animated: Atomic<Bool> = Atomic(value: false)
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {})
        
                
        let transition: Signal<(GroupCallUIState, TableUpdateTransition), NoError> = combineLatest(state, appearanceSignal) |> mapToQueue { state, appAppearance in
            let current = peerEntries(state: state, account: account, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appAppearance) }
            let previous = previousEntries.swap(current)
            
            let signal = prepareInputDataTransition(left: previous, right: current, animated: abs(current.count - previous.count) <= 10 && state.isWindowVisible && state.isFullScreen == previousIsFullScreen, searchState: nil, initialSize: initialSize.with { $0 - NSMakeSize(40, 0) }, arguments: inputArguments, onMainQueue: false)
            
            previousIsFullScreen = state.isFullScreen
            
            return combineLatest(.single(state), signal)
        } |> deliverOnMainQueue
        
        var currentState: GroupCallUIState?
        
        self.disposable.set(transition.start { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            let state = value.0
            
            switch value.0.state.networkState {
            case .connected:
                var notifyCanSpeak: Bool = false
                var notifyStartRecording: Bool = false
                
                if let previous = currentState {
                    if previous.state.muteState != value.0.state.muteState {
                        if askedForSpeak, let muteState = state.state.muteState, muteState.canUnmute {
                            notifyCanSpeak = true
                        }
                    }
                    if previous.state.recordingStartTimestamp == nil && state.state.recordingStartTimestamp != nil {
                        notifyStartRecording = true
                    }
                    if let window = strongSelf.window {
                        if (previous.videoSources.screencast != nil) != (state.videoSources.screencast != nil) {
                            if let _ = state.videoSources.screencast {
                                showModalText(for: window, text: L10n.voiceChatTooltipShareScreen)
                            } else if let _ = previous.videoSources.screencast {
                                showModalText(for: window, text: L10n.voiceChatTooltipStopScreen)
                            }
                        }
                        if (previous.videoSources.video != nil) != (state.videoSources.video != nil) {
                            if let _ = state.videoSources.video {
                                showModalText(for: window, text: L10n.voiceChatTooltipShareVideo)
                            } else if let _ = previous.videoSources.video {
                                showModalText(for: window, text: L10n.voiceChatTooltipStopVideo)
                            }
                        }
                    }
                }
                if notifyCanSpeak {
                    askedForSpeak = false
                    SoundEffectPlay.play(postbox: account.postbox, name: "voip_group_unmuted")
                    if let window = strongSelf.window {
                        showModalText(for: window, text: L10n.voiceChatToastYouCanSpeak)
                    }
                }
                if notifyStartRecording {
                    SoundEffectPlay.play(postbox: account.postbox, name: "voip_group_recording_started")
                    if let window = strongSelf.window {
                        showModalText(for: window, text: L10n.voiceChatAlertRecording)
                    }
                }
            case .connecting:
                break
            }
            
            if currentState == nil {
                _ = strongSelf.disableScreenSleep()
            }
            
            currentState = state
            
            strongSelf.applyUpdates(value.0, value.1, strongSelf.data.call, animated: animated.swap(true))
            strongSelf.readyOnce()
            
            
            
            for member in value.0.memberDatas {
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
                    updateDisplayedRaisedHands { current in
                        var current = current
                        current.remove(member.peer.id)
                        return current
                    }
                }
            }
            DispatchQueue.main.async {
                displayedRaisedHandsPromise.set(displayedRaisedHands.with { $0 })
                selectBestDominantSpeakerWithVideo()
            }
        })
        

        self.onDeinit = {
            currentState = nil
            _ = previousEntries.swap([])
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
            confirm(for: window, information: L10n.voiceChatRequestAccess, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
                switch result {
                case .thrid:
                    openSystemSettings(.microphone)
                default:
                    break
                }
            }, appearance: darkPalette.appearance)
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
            let timer = SwiftSignalKit.Timer(timeout: 5.0, repeat: false, completion: { [weak self] in
                self?.genericView.idleHide()
            }, queue: .mainQueue())
            
            self?.idleTimer = timer
            timer.start()
        }
        
        window.set(mouseHandler: { [weak self] event in
            self?.genericView.updateMouse(event: event, animated: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseEntered, priority: .modal)
        
        window.set(mouseHandler: { [weak self]  event in
            self?.genericView.updateMouse(event: event, animated: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseMoved, priority: .modal)
        
        window.set(mouseHandler: { [weak self]  event in
            self?.genericView.updateMouse(event: event, animated: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseExited, priority: .modal)
        
       
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
        self.genericView.applyUpdates(state, transition, call, animated: transition.animated)
        canManageCall = state.state.canManageCall
        
       // if genericView.inLiveResize {
//            for view in genericView.peersTable.view.subviews {
//                if let view = view as? TableRowView {
//                    let rowIndex = genericView.peersTable.view.row(for: view)
//                    if rowIndex < 0 {
//                        view.removeFromSuperview()
//                    }
//                }
//            }
      //  }
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
