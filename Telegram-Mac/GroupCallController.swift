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
    let takeVideo:(PeerId, VideoSourceMacMode?, GroupCallUIState.ActiveVideo.Mode)->NSView?
    let isSharingVideo:(PeerId)->Bool
    let isSharingScreencast:(PeerId)->Bool
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
    let switchCamera:(PeerGroupCallData)->Void
    let togglePeersHidden:()->Void
    let contextMenuItems:(PeerGroupCallData)->[ContextMenuItem]
    init(leave:@escaping()->Void,
    settings:@escaping()->Void,
    invite:@escaping(PeerId)->Void,
    mute:@escaping(PeerId, Bool)->Void,
    toggleSpeaker:@escaping()->Void,
    remove:@escaping(Peer)->Void,
    openInfo: @escaping(Peer)->Void,
    inviteMembers:@escaping()->Void,
    shareSource: @escaping(VideoSourceMacMode)->Void,
    takeVideo:@escaping(PeerId, VideoSourceMacMode?, GroupCallUIState.ActiveVideo.Mode)->NSView?,
    isSharingVideo: @escaping(PeerId)->Bool,
    isSharingScreencast: @escaping(PeerId)->Bool,
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
    futureWidth:@escaping()->CGFloat?,
    switchCamera:@escaping(PeerGroupCallData)->Void,
    togglePeersHidden: @escaping()->Void,
    contextMenuItems:@escaping(PeerGroupCallData)->[ContextMenuItem]) {
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
        self.isSharingVideo = isSharingVideo
        self.isSharingScreencast = isSharingScreencast
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
        self.switchCamera = switchCamera
        self.togglePeersHidden = togglePeersHidden
        self.contextMenuItems = contextMenuItems
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
    
    
    let peer: Peer
    let state: GroupCallParticipantsContext.Participant?
    let isSpeaking: Bool
    let isInvited: Bool
    let unsyncVolume: Int32?
    let pinnedMode: PinnedMode?
    let accountPeerId: PeerId
    let accountAbout: String?
    let canManageCall: Bool
    let hideWantsToSpeak: Bool
    let activityTimestamp: Int32
    let firstTimestamp: Int32
    let videoMode: Bool
    let isVertical: Bool
    let hasVideo: Bool
    let layoutMode: GroupCallUIState.LayoutMode
    let dominantSpeaker: DominantVideo?
    let activeVideos:Set<String>
    let adminIds: Set<PeerId>
    
    
    let videoEndpointId: String?
    let presentationEndpointId: String?
    
    var isRaisedHand: Bool {
        return self.state?.hasRaiseHand == true
    }
    var wantsToSpeak: Bool {
        return isRaisedHand && !hideWantsToSpeak
    }
    
    var videoEndpoint: String? {
        return activeVideos.first(where: { $0 == videoEndpointId })
    }
    var screencastEndpoint: String? {
        return activeVideos.first(where: { $0 == presentationEndpointId })
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
    
    
    func videoStatus(_ mode: VideoSourceMacMode) -> String {
        var string:String = L10n.peerStatusRecently
        switch mode {
        case .video:
            string = self.status.0
        case .screencast:
            string = L10n.voiceChatStatusScreensharing
        }
        return string
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
        if lhs.layoutMode != rhs.layoutMode {
            return false
        }
        if lhs.dominantSpeaker != rhs.dominantSpeaker {
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
        
        return true
    }
    
    static func <(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        
        let lhsScreencast = lhs.activeVideos.contains(where: { $0 == lhs.screencastEndpoint})
        let rhsScreencast = lhs.activeVideos.contains(where: { $0 == rhs.screencastEndpoint})

        let lhsVideo = lhs.activeVideos.contains(where: { $0 == lhs.videoEndpoint})
        let rhsVideo = lhs.activeVideos.contains(where: { $0 == rhs.videoEndpoint})
        
        if lhsScreencast, !rhsScreencast {
            return true
        } else if lhsVideo, !rhsVideo {
            return true
        }
        
        
//        if (lhs.pinnedMode != nil && lhs.pinnedMode?.temporary == false) && rhs.pinnedMode == nil {
//            return true
//        }
        if lhs.activityTimestamp != rhs.activityTimestamp {
            return lhs.activityTimestamp > rhs.activityTimestamp
        }
        return lhs.firstTimestamp > rhs.firstTimestamp
    }
}





private func _id_peer_id(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_peer_id_\(id.toInt64())")
}

private func makeState(previous:GroupCallUIState?, peerView: PeerView, state: PresentationGroupCallState, isMuted: Bool, invitedPeers: [Peer], peerStates: PresentationGroupCallMembers?, myAudioLevel: Float, summaryState: PresentationGroupCallSummaryState?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, accountPeer: (Peer, String?), unsyncVolumes: [PeerId: Int32], dominantSpeaker: DominantVideo?, hideWantsToSpeak: Set<PeerId>, isFullScreen: Bool, videoSources: GroupCallUIState.VideoSources, layoutMode: GroupCallUIState.LayoutMode, activeVideoViews: [GroupCallUIState.ActiveVideo], hideParticipants: Bool, excludedPins: Set<String>, version: Int) -> GroupCallUIState {
    
    var memberDatas: [PeerGroupCallData] = []
    
    let accountPeerId = accountPeer.0.id
    let accountPeerAbout = accountPeer.1
    var activeParticipants: [GroupCallParticipantsContext.Participant] = []
    
    activeParticipants = peerStates?.participants ?? []
    var index: Int32 = 0
    
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
    
    var handbyDominant = dominantSpeaker
    
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
            return !excludedPins.contains($0.presentationEndpointId!)
        })
        if let first = intersection.first {
            let master: DominantVideo = DominantVideo(first.peer.id, first.presentationEndpointId!, .screencast, true)
            current = master
        }
    } else {
        if handbyDominant != previous?.handbyDominant {
            current = handbyDominant
        }
    }
    if let dominant = current {
        if !activeVideoViews.contains(where: { $0.endpointId == dominant.endpointId && $0.mode == .main }) {
            current = nil
        }
        if excludedPins.contains(dominant.endpointId), dominant.temporary {
            current = nil
        }
    }
    
    let isVertical = isFullScreen && activeVideoViews.count > 0
    
    func hasVideo(_ peerId: PeerId) -> Bool {
        return activeParticipants.first(where: { participant in
            if participant.peer.id != peerId {
                return false
            }
            if let _ = participant.presentationEndpointId {
                return true
            }
            if let _ = participant.videoEndpointId {
                return true
            }
            return false
        }) != nil
    }
    
    if !activeParticipants.contains(where: { $0.peer.id == accountPeerId }) {
        let pinnedMode: PeerGroupCallData.PinnedMode?
        if let current = dominantSpeaker, current.peerId == accountPeerId {
            pinnedMode = .init(mode: current.mode, temporary: current.temporary)
        } else {
            pinnedMode = nil
        }
                
        memberDatas.append(PeerGroupCallData(peer: accountPeer.0, state: nil, isSpeaking: false, isInvited: false, unsyncVolume: unsyncVolumes[accountPeerId], pinnedMode: pinnedMode, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(accountPeerId), activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: !activeVideoViews.isEmpty, isVertical: isVertical, hasVideo: hasVideo(accountPeerId), layoutMode: layoutMode, dominantSpeaker: dominantSpeaker, activeVideos: Set(), adminIds: state.adminIds, videoEndpointId: nil, presentationEndpointId: nil))
        index += 1
    } 

    for value in activeParticipants {
        var isSpeaking = peerStates?.speakingParticipants.contains(value.peer.id) ?? false
        if accountPeerId == value.peer.id, isMuted {
            isSpeaking = false
        }
        let pinnedMode: PeerGroupCallData.PinnedMode?
        if let current = dominantSpeaker, current.peerId == value.peer.id {
            pinnedMode = .init(mode: current.mode, temporary: current.temporary)
        } else {
            pinnedMode = nil
        }
        
        let activeVideos = Set(activeVideoViews.filter({ active in
            return active.endpointId == value.presentationEndpointId || active.endpointId == value.videoEndpointId
        }).map { $0.endpointId })
        
        memberDatas.append(PeerGroupCallData(peer: value.peer, state: value, isSpeaking: isSpeaking, isInvited: false, unsyncVolume: unsyncVolumes[value.peer.id], pinnedMode: pinnedMode, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(value.peer.id), activityTimestamp: Int32.max - 1 - index, firstTimestamp: value.joinTimestamp, videoMode: !activeVideoViews.isEmpty, isVertical: isVertical, hasVideo: hasVideo(value.peer.id), layoutMode: layoutMode, dominantSpeaker: dominantSpeaker, activeVideos: activeVideos, adminIds: state.adminIds, videoEndpointId: value.videoEndpointId, presentationEndpointId: value.presentationEndpointId))
        index += 1
    }
    
    for invited in invitedPeers {
        if !activeParticipants.contains(where: { $0.peer.id == invited.id}) {
            memberDatas.append(PeerGroupCallData(peer: invited, state: nil, isSpeaking: false, isInvited: true, unsyncVolume: nil, pinnedMode: nil, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: false, activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: !activeVideoViews.isEmpty, isVertical: isVertical, hasVideo: false, layoutMode: layoutMode, dominantSpeaker: dominantSpeaker, activeVideos: Set(), adminIds: state.adminIds, videoEndpointId: nil, presentationEndpointId: nil))
            index += 1
        }
    }

    
    let mode: GroupCallUIState.Mode
    let isVideoEnabled = summaryState?.info?.isVideoEnabled ?? false
    
    if !isVideoEnabled {
        var bp = 0
        bp += 1
    }
    
    switch isVideoEnabled || !videoSources.isEmpty || !activeVideoViews.isEmpty  {
    case true:
        mode = .video
    case false:
        mode = .voice
    }
    
    return GroupCallUIState(memberDatas: memberDatas.sorted(), state: state, isMuted: isMuted, summaryState: summaryState, myAudioLevel: myAudioLevel, peer: peerViewMainPeer(peerView)!, cachedData: peerView.cachedData as? CachedChannelData, voiceSettings: voiceSettings, isWindowVisible: isWindowVisible, dominantSpeaker: current, handbyDominant: handbyDominant, isFullScreen: isFullScreen, mode: mode, videoSources: videoSources, layoutMode: layoutMode, version: version, activeVideoViews: activeVideoViews.sorted(by: { $0.index < $1.index }), hideParticipants: hideParticipants, isVideoEnabled: summaryState?.info?.isVideoEnabled ?? false)
}


private func peerEntries(state: GroupCallUIState, account: Account, arguments: GroupCallUIArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
        
    let canInvite: Bool = true
    
    if canInvite {
        
        struct Tuple : Equatable {
            let viewType: GeneralViewType
            let videoMode: Bool
        }
        let viewType = GeneralViewType.singleItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 0, 0))
        let tuple = Tuple(viewType: viewType, videoMode: state.dominantSpeaker != nil && state.layoutMode == .classic)
        
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
                arguments.openInfo(data.peer)
            }, invite: arguments.invite, contextMenu: {
                return .single(arguments.contextMenuItems(tuple.data))
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
    private var videoViews: [(DominantVideo, GroupCallUIState.ActiveVideo.Mode, GroupVideoView)] = []
    private var dominantSpeakerSignal:ValuePromise<DominantVideo?> = ValuePromise(nil, ignoreRepeated: true)

    private var idleTimer: SwiftSignalKit.Timer?

    let size: ValuePromise<NSSize> = ValuePromise(.zero, ignoreRepeated: true)
    
    var disableSounds: Bool = false
    init(_ data: UIData, size: NSSize) {
        self.data = data
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(_viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: genericView.peersTable)

        let layoutMode: ValuePromise<GroupCallUIState.LayoutMode> = ValuePromise(.tile, ignoreRepeated: true)
        
        
        let excludedPins:Atomic<Set<String>> = Atomic(value: Set())
        let excludedPinsValue:ValuePromise<Set<String>> = ValuePromise(Set(), ignoreRepeated: true)
        let insertExcludedPin:(String)->Void = { endpointId in
            excludedPinsValue.set(excludedPins.modify { current in
                var current = current
                current.insert(endpointId)
                return current
            })
        }
        
        let hideParticipantsValue:Atomic<Bool> = Atomic(value: false)
        let hideParticipants:Promise<Bool> = Promise(false)
        let updateHideParticipants:((Bool)->Bool)->Void = { f in
            hideParticipants.set(.single(hideParticipantsValue.modify(f)))
        }
        
        
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
                
        let videoSources = ValuePromise<GroupCallUIState.VideoSources>(.init())
        let videoSourcesValue: Atomic<GroupCallUIState.VideoSources> = Atomic(value: .init())
        let updateVideoSources:(@escaping(GroupCallUIState.VideoSources)->GroupCallUIState.VideoSources)->Void = { f in
            videoSources.set(videoSourcesValue.modify(f))
        }
        
        
     
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
            guard let state = self?.genericView.state, let window = self?.window else {
                return
            }
            
            if state.state.networkState == .connecting {
                NSSound.beep()
                return
            }
            
            if !state.isVideoEnabled {
                switch mode {
                case .video:
                    alert(for: window, info: L10n.voiceChatTooltipErrorVideoUnavailable)
                case .screencast:
                    alert(for: window, info: L10n.voiceChatTooltipErrorScreenUnavailable)
                }
                return
            }
            let confirmSource:(VideoSourceMacMode, @escaping(Bool)->Void)->Void = { [weak state, weak window] source, f in
                if let state = state, let window = window {
                    switch mode {
                    case .screencast:
                        let presentingPeer = state.videoActive(.main).first(where: { $0.screencastEndpoint != nil })
                        if let peer = presentingPeer {
                            confirm(for: window, header: L10n.voiceChatScreencastConfirmHeader, information: L10n.voiceChatScreencastConfirmText(peer.peer.compactDisplayTitle), okTitle: L10n.voiceChatScreencastConfirmOK, successHandler: { _ in
                                f(true)
                            }, cancelHandler: {
                                f(false)
                            })
                        } else {
                            f(true)
                        }
                    case .video:
                        f(true)
                    }
                }
            }
            if let sharing = self?.sharing, sharing.mode == mode {
                sharing.orderFront(nil)
            } else {
                self?.sharing?.orderOut(nil)
                confirmSource(mode, { accept in
                    if accept {
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
                        sharing?.level = self?.window?.level ?? .normal
                        if sharing == nil, let window = self?.window {
                            switch mode {
                            case .video:
                                showModalText(for: window, text: L10n.voiceChatTooltipNoCameraFound)
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
            self?.dominantSpeakerSignal.set(video)
            self?.genericView.peersTable.scroll(to: .up(true))
        }, unpinVideo: { [weak self] mode in
            if let dominant = self?.genericView.state?.dominantSpeaker {
                if dominant.temporary {
                    insertExcludedPin(dominant.endpointId)
                }
            }
            self?.dominantSpeakerSignal.set(nil)
        }, isPinnedVideo: { [weak self] peerId, mode in
            if let current = self?.genericView.state?.dominantSpeaker {
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
            updateVideoSources { current in
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
            
            let invoke:()->Void = { [weak strongSelf, weak window] in
                guard let strongSelf = strongSelf, let window = window, let state = strongSelf.genericView.state else {
                    return
                }
                let isFullScreen = strongSelf.genericView.isFullScreen
                var rect: CGRect
                if isFullScreen {
                    rect = CGRect(origin: window.frame.origin, size: GroupCallTheme.minSize)
                } else {
                    rect = CGRect(origin: window.frame.origin, size: GroupCallTheme.minFullScreenSize)
                }
                rect.size.height = window.frame.height

                strongSelf.genericView.tempFullScreen = !isFullScreen
                strongSelf.applyUpdates(state.withUpdatedFullScreen(!isFullScreen), .init(deleted: [], inserted: [], updated: []), strongSelf.data.call, animated: true)
                window.setFrame(rect, display: true, animate: true)
                strongSelf.genericView.tempFullScreen = nil
            }
            if window.isFullScreen {
                window.toggleFullScreen(nil)
                window._windowDidExitFullScreen = invoke
            } else {
                invoke()
            }
            
        }, futureWidth: {
            return nil
        }, switchCamera: { [weak self] peer in
            var video: DominantVideo? = nil
            if let mode = peer.pinnedMode {
                switch mode.mode.viceVersa {
                case .video:
                    if let endpoint = peer.videoEndpoint {
                        video = .init(peer.peer.id, endpoint, .video, mode.temporary)
                    }
                case .screencast:
                    if let endpoint = peer.screencastEndpoint {
                        video = .init(peer.peer.id, endpoint, .screencast, mode.temporary)
                    }
                }
            } else if peer.hasVideo {
                if let endpoint = peer.videoEndpoint {
                    video = .init(peer.peer.id, endpoint, .video, true)
                } else if let endpoint = peer.screencastEndpoint {
                    video = .init(peer.peer.id, endpoint, .screencast, true)
                }
            }
            guard let _video = video else {
                return
            }
            self?.dominantSpeakerSignal.set(_video)
            self?.genericView.peersTable.scroll(to: .up(true))
        }, togglePeersHidden: {
            updateHideParticipants {
                !$0
            }
        }, contextMenuItems: { data in
            return contextMenuItems?(data) ?? []
        })
        
        contextMenuItems = { [weak arguments] data in
            
            guard let arguments = arguments else {
                return []
            }
            
            var items: [ContextMenuItem] = []

            if let state = data.state {
                
                let headerItem: ContextMenuItem = .init("headerItem", handler: {

                })
                let headerView = GroupCallContextMenuHeaderView(frame: NSMakeRect(0, 0, 200, 200))
                
                headerView.setPeer(state.peer, about: data.about, account: account)
                headerItem.view = headerView


                items.append(headerItem)
                items.append(ContextSeparatorItem())

                if data.peer.id == data.accountPeerId, data.isRaisedHand {
                    items.append(ContextMenuItem(L10n.voiceChatDownHand, handler: arguments.toggleRaiseHand))
                }
                
                if data.peer.id != data.accountPeerId, state.muteState == nil || state.muteState?.canUnmute == true {
                    let volume: ContextMenuItem = .init("Volume", handler: {

                    })

                    let volumeControl = VolumeMenuItemView(frame: NSMakeRect(0, 0, 200, 26))
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
                            arguments.pinVideo(.init(data.peer.id, endpointId, .video, false))
                        }))
                    } else if arguments.canUnpinVideo(data.peer.id, .video) {
                        items.append(ContextMenuItem(L10n.voiceChatUnpinVideo, handler: {
                            arguments.unpinVideo(.video)
                        }))
                    }
                }
                if let endpointId = data.screencastEndpoint {
                    if !arguments.isPinnedVideo(data.peer.id, .screencast) {
                        items.append(ContextMenuItem(L10n.voiceChatPinScreencast, handler: {
                            arguments.pinVideo(.init(data.peer.id, endpointId, .screencast, false))
                        }))
                    } else if arguments.canUnpinVideo(data.peer.id, .screencast) {
                        items.append(ContextMenuItem(L10n.voiceChatUnpinScreencast, handler: {
                            arguments.unpinVideo(.screencast)
                        }))
                    }
                }
                
                
                
                if !data.canManageCall, data.peer.id != data.accountPeerId {
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
                
                if data.canManageCall, data.peer.id != data.accountPeerId {
                    if data.adminIds.contains(data.peer.id) {
                        if state.muteState == nil {
                            items.append(.init(L10n.voiceChatMutePeer, handler: {
                                arguments.mute(data.peer.id, true)
                            }))
                        }
                        if !data.adminIds.contains(data.peer.id), !data.peer.isChannel {
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
                    if !data.adminIds.contains(data.peer.id), !data.peer.isChannel {
                        items.append(.init(L10n.voiceChatRemovePeer, handler: {
                            arguments.remove(data.peer)
                        }))
                    }

                }
            }
            return items
            
        }
        
        self.data.call.mustStopVideo = { [weak arguments, weak window] in
            updateVideoSources { current in
                var current = current
                current.failed = true
                return current
            }
            arguments?.cancelShareVideo()
            if let window = window {
                showModalText(for: window, text: L10n.voiceChatTooltipVideoFailed)
            }
            delay(0.2, closure: {
                updateVideoSources { current in
                    var current = current
                    current.failed = false
                    return current
                }
            })
        }
        self.data.call.mustStopSharing = { [weak arguments, weak window] in
            updateVideoSources { current in
                var current = current
                current.failed = true
                return current
            }
            arguments?.cancelShareScreencast()
            if let window = window {
                showModalText(for: window, text: L10n.voiceChatTooltipScreencastFailed)
            }
            delay(0.2, closure: {
                updateVideoSources { current in
                    var current = current
                    current.failed = false
                    return current
                }
            })
        }
        
        genericView.arguments = arguments
        let members = data.call.members
        
        
        let videoData = combineLatest(queue: .mainQueue(), members, layoutMode.get(), dominantSpeakerSignal.get(), isFullScreen.get(), self.data.call.joinAsPeerIdValue, self.data.call.stateVersion |> filter { $0 > 0 }, size.get())
        
                
        actionsDisposable.add(videoData.start(next: { [weak self] members, layoutMode, dominant, isFullScreen, accountId, stateVersion, size in
            
            guard let strongSelf = self else {
                return
            }
            let types:[GroupCallUIState.ActiveVideo.Mode] = [.backstage, .list, .main]

            
            let videoMembers: [GroupCallParticipantsContext.Participant] = members?.participants.filter { member in
                return member.videoEndpointId != nil || member.presentationEndpointId != nil
            } ?? []
            
            let tiles = tileViews(videoMembers.count, isFullscreen: isFullScreen, frameSize: strongSelf.genericView.mainVideoRect.size)

            
            var items:[PresentationGroupCallRequestedVideo] = []
                        
            switch layoutMode {
            case .tile:
                for (i, member) in videoMembers.enumerated() {
                    
                    var videoQuality: PresentationGroupCallRequestedVideo.Quality = tiles[i].bestQuality
                    var screencastQuality: PresentationGroupCallRequestedVideo.Quality = tiles[i].bestQuality

                    if let dominant = dominant {
                        videoQuality = .thumbnail
                        screencastQuality = .thumbnail
                        
                        if dominant.peerId == member.peer.id {
                            switch dominant.mode {
                            case .video:
                                videoQuality = .full
                            case .screencast:
                                screencastQuality = .full
                            }
                        }
                    }
                    
                    if let item = member.requestedVideoChannel(quality: videoQuality) {
                        items.append(item)
                    }
                    if let item = member.requestedPresentationVideoChannel(quality: screencastQuality) {
                        items.append(item)
                    }
                }
            case .classic:
                for member in videoMembers {
                    if member.peer.id == dominant?.peerId {
                        if dominant?.endpointId == member.videoEndpointId {
                            if let item = member.requestedVideoChannel(quality: .full) {
                                items.append(item)
                            }
                        } else if dominant?.endpointId == member.presentationEndpointId {
                            if let item = member.requestedPresentationVideoChannel(quality: isFullScreen ? .medium : .thumbnail) {
                                items.append(item)
                            }
                        }
                    } else {
                        if let item = member.requestedVideoChannel(quality: isFullScreen ? .medium : .thumbnail) {
                            items.append(item)
                        }
                        if let item = member.requestedPresentationVideoChannel(quality: isFullScreen ? .medium : .thumbnail) {
                            items.append(item)
                        }
                    }
                }
            }
            
            var validSources = Set<String>()
            for item in items {
                let endpointId = item.endpointId
                let member = members?.participants.first(where: {
                    $0.videoEndpointId == item.endpointId || $0.presentationEndpointId == item.endpointId
                })

                if let member = member {
                    validSources.insert(endpointId)
                    if !strongSelf.requestedVideoSources.contains(endpointId) {
                        strongSelf.requestedVideoSources.insert(endpointId)
                        
                        let isScreencast = member.presentationEndpointId == endpointId
                        let videoMode: VideoSourceMacMode = isScreencast ? .screencast : .video
                        let takeVideoMode: GroupCallVideoMode = isScreencast && member.peer.id == accountId ? .screencast : .video
                                            
                        
                        
                        for type in types {
                            strongSelf.data.call.makeVideoView(endpointId: endpointId, videoMode: takeVideoMode, completion: { videoView in
                                DispatchQueue.main.async {
                                    guard let videoView = videoView else {
                                        return
                                    }
                                    var videoViewValue: GroupVideoView? = GroupVideoView(videoView: videoView)
                                    
                                    switch type {
                                    case .main:
                                        videoView.setVideoContentMode(.resizeAspect)
                                    case .list:
                                        videoView.setVideoContentMode(.resizeAspectFill)
                                    case .backstage:
                                        videoView.setVideoContentMode(.resizeAspectFill)
                                    }
                                    
                                    videoView.setOnFirstFrameReceived( { [weak self] f in
                                        if let videoViewValue = videoViewValue {
                                            self?.videoViews.append((DominantVideo(member.peer.id, endpointId, videoMode, true), type, videoViewValue))
                                            updateActiveVideoViews { current in
                                                var current = current
                                                current.set.append(.init(endpointId: endpointId, mode: type, index: current.index))
                                                current.index -= 1
                                                return current
                                            }
                                        }
                                        videoViewValue = nil
                                    })
                                }
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
            
            self?.data.call.setRequestedVideoList(items: items)

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
        
        let some = combineLatest(queue: .mainQueue(), self.data.call.isMuted, animate, joinAsPeer, unsyncVolumes.get(), dominantSpeakerSignal.get(), activeVideoViews.get() |> distinctUntilChanged, isFullScreen.get(), layoutMode.get(), self.data.call.stateVersion, hideParticipants.get(), excludedPinsValue.get())

        
        var currentState: GroupCallUIState?

        let previousState: Atomic<GroupCallUIState?> = Atomic(value: nil)
        
        let state: Signal<GroupCallUIState, NoError> = combineLatest(queue: .mainQueue(), self.data.call.state, members, (.single(0) |> then(data.call.myAudioLevel)) |> distinctUntilChanged, account.viewTracker.peerView(peerId), invited, self.data.call.summaryState, voiceCallSettings(data.call.sharedContext.accountManager), some, displayedRaisedHandsPromise.get(), videoSources.get()) |> mapToQueue { values in
            let value = previousState.modify { previous in
                return makeState(previous: previous, peerView: values.3,
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
                                         dominantSpeaker: values.7.4,
                                         hideWantsToSpeak: values.8,
                                         isFullScreen: values.7.6,
                                         videoSources: values.9,
                                         layoutMode: values.7.7,
                                         activeVideoViews: values.7.5.set,
                                         hideParticipants: values.7.9,
                                         excludedPins: values.7.10,
                                         version: values.7.8)
            }
            return .single(value!)
        } |> distinctUntilChanged
        
        

        let initialSize = self.atomicSize
        var previousIsFullScreen: Bool = initialSize.with { $0.width >= GroupCallTheme.fullScreenThreshold }
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let animated: Atomic<Bool> = Atomic(value: false)
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {})
        
                
        let transition: Signal<(GroupCallUIState, TableUpdateTransition), NoError> = combineLatest(state, appearanceSignal) |> mapToQueue { state, appAppearance in
            let current = peerEntries(state: state, account: account, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appAppearance) }
            let previous = previousEntries.swap(current)
            
            let signal = prepareInputDataTransition(left: previous, right: current, animated: abs(current.count - previous.count) <= 10 && state.isWindowVisible && state.isFullScreen == previousIsFullScreen, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputArguments, onMainQueue: false)
            
            previousIsFullScreen = state.isFullScreen
            
            return combineLatest(.single(state), signal)
        } |> deliverOnMainQueue
        
        
        self.disposable.set(transition.start { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            let state = value.0
            
            switch state.state.networkState {
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
                        if !state.videoSources.failed {
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
            
            if currentState?.dominantSpeaker != state.dominantSpeaker {
                guard let window = strongSelf.window else {
                    return
                }
                let dominantSpeaker = state.dominantSpeaker
                let dominant = dominantSpeaker ?? currentState?.dominantSpeaker
                if let dominant = dominant {
                    let isPinned = dominantSpeaker != nil
                    let participant = state.memberDatas.first(where: { $0.peer.id == dominant.peerId })
                    if let participant = participant {
                        let text: String = participant.peer.compactDisplayTitle
                        switch dominant.mode {
                        case .video:
                            if isPinned {
                                if participant.accountPeerId == participant.peer.id {
                                    showModalText(for: window, text: L10n.voiceChatTooltipYourVideoPinned)
                                } else {
                                    showModalText(for: window, text: L10n.voiceChatTooltipVideoPinned(text))
                                }
                            } else {
                                if participant.accountPeerId == participant.peer.id {
                                    showModalText(for: window, text: L10n.voiceChatTooltipYourVideoUnpinned)
                                } else {
                                    showModalText(for: window, text: L10n.voiceChatTooltipVideoUnpinned(text))
                                }
                            }
                        case .screencast:
                            if isPinned {
                                if participant.accountPeerId == participant.peer.id {
                                    showModalText(for: window, text: L10n.voiceChatTooltipYourScreenPinned)
                                } else {
                                    showModalText(for: window, text: L10n.voiceChatTooltipScreenPinned(text))
                                }
                            } else {
                                if participant.accountPeerId == participant.peer.id {
                                    showModalText(for: window, text: L10n.voiceChatTooltipYourScreenUnpinned)
                                } else {
                                    showModalText(for: window, text: L10n.voiceChatTooltipScreenUnpinned(text))
                                }
                            }
                        }
                    }
                }

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
            DispatchQueue.main.async { [weak strongSelf] in
                displayedRaisedHandsPromise.set(displayedRaisedHands.with { $0 })
                strongSelf?.dominantSpeakerSignal.set(state.dominantSpeaker)
            }

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
            let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
                self?.genericView.idleHide()
            }, queue: .mainQueue())
            
            self?.idleTimer = timer
            timer.start()
        }
        
        window.set(mouseHandler: { [weak self] event in
            self?.genericView.updateMouse(event: event, animated: true, isReal: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseEntered, priority: .modal)
        
        window.set(mouseHandler: { [weak self]  event in
            self?.genericView.updateMouse(event: event, animated: true, isReal: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseMoved, priority: .modal)
        
        window.set(mouseHandler: { [weak self]  event in
            self?.genericView.updateMouse(event: event, animated: true, isReal: true)
            launchIdleTimer()
            return .rejected
        }, with: self, for: .mouseExited, priority: .modal)
        
        
        window.set(handler: { [weak self] event in
            if let state = self?.genericView.state {
                layoutMode.set(state.layoutMode.viceVerse)
            }
            return .invokeNext
        }, with: self, for: .T, priority: .modal, modifierFlags: [.command])
        
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

