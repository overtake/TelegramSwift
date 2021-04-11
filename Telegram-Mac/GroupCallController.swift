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
    let shareSource:()->Void
    let takeVideo:(PeerId)->NSView?
    let isStreamingVideo:(PeerId)->Bool
    let canUnpinVideo:(PeerId)->Bool
    let setVolume: (PeerId, Double, Bool) -> Void
    let pinVideo:(DominantVideo)->Void
    let unpinVideo:()->Void
    let isPinnedVideo:(PeerId)->Bool
    let getAccountPeerId: ()->PeerId?
    let cancelSharing: ()->Void
    let toggleRaiseHand:()->Void
    let recordClick:(PresentationGroupCallState)->Void
    let audioLevel:(PeerId)->Signal<Float?, NoError>?
    let startVoiceChat:()->Void
    let toggleReminder:(Bool)->Void
    init(leave:@escaping()->Void,
    settings:@escaping()->Void,
    invite:@escaping(PeerId)->Void,
    mute:@escaping(PeerId, Bool)->Void,
    toggleSpeaker:@escaping()->Void,
    remove:@escaping(Peer)->Void,
    openInfo: @escaping(Peer)->Void,
    inviteMembers:@escaping()->Void,
    shareSource: @escaping()->Void,
    takeVideo:@escaping(PeerId)->NSView?,
    isStreamingVideo: @escaping(PeerId)->Bool,
    canUnpinVideo:@escaping(PeerId)->Bool,
    pinVideo:@escaping(DominantVideo)->Void,
    unpinVideo:@escaping()->Void,
    isPinnedVideo:@escaping(PeerId)->Bool,
    setVolume: @escaping(PeerId, Double, Bool)->Void,
    getAccountPeerId: @escaping()->PeerId?,
    cancelSharing: @escaping()->Void,
    toggleRaiseHand:@escaping()->Void,
    recordClick:@escaping(PresentationGroupCallState)->Void,
    audioLevel:@escaping(PeerId)->Signal<Float?, NoError>?,
    startVoiceChat:@escaping()->Void,
    toggleReminder:@escaping(Bool)->Void) {
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
        self.cancelSharing = cancelSharing
        self.toggleRaiseHand = toggleRaiseHand
        self.recordClick = recordClick
        self.audioLevel = audioLevel
        self.startVoiceChat = startVoiceChat
        self.toggleReminder = toggleReminder
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
    let isPinned: Bool
    let accountPeerId: PeerId
    let accountAbout: String?
    let canManageCall: Bool
    let hideWantsToSpeak: Bool
    let activityTimestamp: Int32
    let firstTimestamp: Int32
    let videoMode: Bool
    let isVertical: Bool
    var isRaisedHand: Bool {
        return self.state?.hasRaiseHand == true
    }
    var wantsToSpeak: Bool {
        return isRaisedHand && !hideWantsToSpeak
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
        if lhs.isPinned != rhs.isPinned {
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
        return true
    }
    
    static func <(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        if lhs.isPinned && !rhs.isPinned {
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

private func makeState(peerView: PeerView, state: PresentationGroupCallState, isMuted: Bool, invitedPeers: [Peer], peerStates: PresentationGroupCallMembers?, myAudioLevel: Float, summaryState: PresentationGroupCallSummaryState?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, accountPeer: (Peer, String?), unsyncVolumes: [PeerId: Int32], currentDominantSpeakerWithVideo: DominantVideo?, activeVideoSources: [PeerId: UInt32], hideWantsToSpeak: Set<PeerId>, isFullScreen: Bool) -> GroupCallUIState {
    
    var memberDatas: [PeerGroupCallData] = []
    
    let accountPeerId = accountPeer.0.id
    let accountPeerAbout = accountPeer.1
    var activeParticipants: [GroupCallParticipantsContext.Participant] = []
    
    activeParticipants = peerStates?.participants ?? []
    var index: Int32 = 0
    
    let currentDominantSpeakerWithVideo = currentDominantSpeakerWithVideo

    
    if !activeParticipants.contains(where: { $0.peer.id == accountPeerId }) {
        
        memberDatas.append(PeerGroupCallData(peer: accountPeer.0, state: nil, isSpeaking: false, isInvited: false, unsyncVolume: unsyncVolumes[accountPeerId], isPinned: currentDominantSpeakerWithVideo?.peerId == accountPeerId, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(accountPeerId), activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: currentDominantSpeakerWithVideo != nil, isVertical: isFullScreen && currentDominantSpeakerWithVideo != nil))
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
        memberDatas.append(PeerGroupCallData(peer: value.peer, state: value, isSpeaking: isSpeaking, isInvited: false, unsyncVolume: unsyncVolumes[value.peer.id], isPinned: currentDominantSpeakerWithVideo?.peerId == value.peer.id, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(value.peer.id), activityTimestamp: Int32.max - 1 - index, firstTimestamp: value.joinTimestamp, videoMode: currentDominantSpeakerWithVideo != nil, isVertical: isFullScreen && currentDominantSpeakerWithVideo != nil))
        index += 1
    }
    
    for invited in invitedPeers {
        if !activeParticipants.contains(where: { $0.peer.id == invited.id}) {
            memberDatas.append(PeerGroupCallData(peer: invited, state: nil, isSpeaking: false, isInvited: true, unsyncVolume: nil, isPinned: false, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: false, activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: currentDominantSpeakerWithVideo != nil, isVertical: isFullScreen && currentDominantSpeakerWithVideo != nil))
            index += 1
        }
    }

    return GroupCallUIState(memberDatas: memberDatas.sorted(), state: state, isMuted: isMuted, summaryState: summaryState, myAudioLevel: myAudioLevel, peer: peerViewMainPeer(peerView)!, cachedData: peerView.cachedData as? CachedChannelData, voiceSettings: voiceSettings, isWindowVisible: isWindowVisible, currentDominantSpeakerWithVideo: currentDominantSpeakerWithVideo, activeVideoSources: activeVideoSources, isFullScreen: isFullScreen)
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
            return GroupCallInviteRowItem(initialSize, height: 42, stableId: stableId, videoMode: tuple.videoMode, viewType: viewType, action: arguments.inviteMembers)
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
                   // if data.peer.id != arguments.getAccountPeerId() {
                    //, let ssrc = state.ssrc
                    if arguments.isStreamingVideo(data.peer.id), let ssrc = state.ssrc {
                            if !arguments.isPinnedVideo(data.peer.id) {
                                items.append(ContextMenuItem(L10n.voiceChatPinVideo, handler: {
                                    arguments.pinVideo(.init(data.peer.id, ssrc))
                                }))
                            } else if arguments.canUnpinVideo(data.peer.id) {
                                items.append(ContextMenuItem(L10n.voiceChatUnpinVideo, handler: {
                                    arguments.unpinVideo()
                                }))
                            }
                        }
                  //  }
                    
                    
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
            }, takeVideo: {
                return arguments.takeVideo(data.peer.id)
            }, audioLevel: arguments.audioLevel)
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
    
    private var requestedVideoSources = Set<UInt32>()
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
        isFullScreen.set(size.width > fullScreenThreshold)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        self.isFullScreen.set(size.width > fullScreenThreshold)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let actionsDisposable = self.actionsDisposable
                
        let peerId = self.data.call.peerId
        let account = self.data.call.account

                
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
                return state.activeVideoSources.contains(where: { $0.key == member.peer.id })
                    && member.state != nil
            }
            if !ignorePinned {
                if let pinned = strongSelf.pinnedDominantSpeaker {
                    if state.activeVideoSources[pinned.peerId] == pinned.ssrc {
                        return pinned
                    }
                }
            }
            
            
            for member in members {
                if let state = member.state, let ssrc = state.ssrc {
                    let hasVideo = strongSelf.videoViews.contains(where: { $0.0.peerId == member.peer.id })
                    if hasVideo && member.peer.id == member.accountPeerId, strongSelf.videoViews.count > 1 {
                        continue
                    }
                    if hasVideo {
                        return DominantVideo(member.peer.id, ssrc)
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
                        strongSelf.currentDominantSpeakerWithVideo = DominantVideo(current.peerId, 0)
                        strongSelf.data.call.setFullSizeVideo(ssrc: nil)
                    } else {
                        strongSelf.currentDominantSpeakerWithVideo = current
                        strongSelf.data.call.setFullSizeVideo(ssrc: current.ssrc)
                    }
                }
            } else {
                strongSelf.pinnedDominantSpeaker = nil
                strongSelf.currentDominantSpeakerWithVideo = nil
                strongSelf.data.call.setFullSizeVideo(ssrc: nil)
            }
            
            
        }
        
        
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
//            appDelegate?.navigateProfile(peerId, account: account)
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
                
        }, shareSource: { [weak self] in
            self?.sharing = presentDesktopCapturerWindow(select: { [weak self] source in
                self?.data.call.requestVideo(deviceId: source.deviceIdKey())
            }, devices: sharedContext.devicesContext)
        }, takeVideo: { [weak self] peerId in
            if self?.currentDominantSpeakerWithVideo?.peerId == peerId {
                return nil
            } else {
                return self?.videoViews.first(where: { $0.0.peerId == peerId })?.1
            }
        }, isStreamingVideo: { [weak self] peerId in
            return self?.videoViews.first(where: { $0.0.peerId == peerId }) != nil
        }, canUnpinVideo: { peerId in
            return bestDominantSpeakerWithVideo(true)?.peerId != peerId
        }, pinVideo: { [weak self] video in
            if video.peerId == self?.data.call.joinAsPeerId {
                self?.data.call.setFullSizeVideo(ssrc: nil)
                self?.pinnedDominantSpeaker = .init(video.peerId, 0)
                self?.currentDominantSpeakerWithVideo = .init(video.peerId, 0)
            } else {
                self?.pinnedDominantSpeaker = video
                self?.currentDominantSpeakerWithVideo = video
                self?.data.call.setFullSizeVideo(ssrc: video.ssrc)
            }
        }, unpinVideo: { [weak self] in
            self?.pinnedDominantSpeaker = nil
            selectBestDominantSpeakerWithVideo()
        }, isPinnedVideo: { [weak self] peerId in
            return self?.currentDominantSpeakerWithVideo?.peerId == peerId
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
        }, cancelSharing: { [weak self] in
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
        })
        

        genericView.arguments = arguments
        
        self.voiceSourcesDisposable.set((self.data.call.incomingVideoSources |> deliverOnMainQueue).start(next: { [weak self] sources in
                    guard let strongSelf = self else {
                        return
                    }
                    var updated = false
                    var validSources = Set<UInt32>()
                    for (peerId, source) in sources {
                        validSources.insert(source)
                        if !strongSelf.requestedVideoSources.contains(source) {
                            strongSelf.requestedVideoSources.insert(source)
                            strongSelf.data.call.makeVideoView(source: source, completion: { videoView in
                                Queue.mainQueue().async {
                                    guard let strongSelf = self, let videoView = videoView else {
                                        return
                                    }
                                    let videoViewValue = GroupVideoView(videoView: videoView)
                                    videoView.setVideoContentMode(.resizeAspectFill)

                                    strongSelf.videoViews.append((DominantVideo(peerId, source), videoViewValue))
                                    strongSelf.genericView.peersTable.enumerateItems(with: { item in
                                        item.redraw(animated: true)
                                        return true
                                    })
                                }
                            })
                        }
                    }

                    for i in (0 ..< strongSelf.videoViews.count).reversed() {
                        if !validSources.contains(strongSelf.videoViews[i].0.ssrc) {
                            let ssrc = strongSelf.videoViews[i].0.ssrc
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

        
        
        let members: Signal<PresentationGroupCallMembers?, NoError> = self.data.call.members
        

        
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
        
               
        let queue = Queue(name: "voicechat.ui")

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


        let state: Signal<GroupCallUIState, NoError> = combineLatest(queue: .mainQueue(), self.data.call.state, members, (.single(0) |> then(data.call.myAudioLevel)), account.viewTracker.peerView(peerId), invited, self.data.call.summaryState, voiceCallSettings(data.call.sharedContext.accountManager), some, displayedRaisedHandsPromise.get()) |> mapToQueue { values in
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
                                     isFullScreen: values.7.6))
        } |> distinctUntilChanged
        
        
//        var invokeAfterTransaction:()
//        window.processFullScreen = { f in
//
//        }
//
        let initialSize = self.atomicSize
        var previousIsFullScreen: Bool = initialSize.with { $0.width > fullScreenThreshold }
        
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
        
        var currentState: PresentationGroupCallState?
        
        self.disposable.set(transition.start { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            switch value.0.state.networkState {
            case .connected:
                var notifyCanSpeak: Bool = false
                var notifyStartRecording: Bool = false
                
                if let previous = currentState {
                    if previous.muteState != value.0.state.muteState {
                        if askedForSpeak, let muteState = value.0.state.muteState, muteState.canUnmute {
                            notifyCanSpeak = true
                        }
                    }
                    if previous.recordingStartTimestamp == nil && value.0.state.recordingStartTimestamp != nil {
                        notifyStartRecording = true
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
            currentState = value.0.state
            
            
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
            for view in genericView.peersTable.view.subviews {
                if let view = view as? TableRowView {
                    let rowIndex = genericView.peersTable.view.row(for: view)
                    if rowIndex < 0 {
                        view.removeFromSuperview()
                    }
                }
            }
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
}
