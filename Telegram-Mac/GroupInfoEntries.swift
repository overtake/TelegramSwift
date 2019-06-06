//
//  GroupInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit



private func valuesRequiringUpdate(state: GroupInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramGroup {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedGroupData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        
        return (titleValue, descriptionValue)
    } else if let peer = view.peers[view.peerId] as? TelegramChannel {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        
        return (titleValue, descriptionValue)
    } else {
        return (nil, nil)
    }
}

struct GroupInfoEditingState: Equatable {
    let editingName: String?
    let editingDescriptionText: String
    
    init(editingName:String? = nil, editingDescriptionText:String = "") {
        self.editingName = editingName
        self.editingDescriptionText = editingDescriptionText
    }
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> GroupInfoEditingState {
        return GroupInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
}

final class GroupInfoArguments : PeerInfoArguments {
    
    private let addMemberDisposable = MetaDisposable()
    private let removeMemberDisposable = MetaDisposable()
    private let updatePeerNameDisposable = MetaDisposable()
    private let updatePhotoDisposable = MetaDisposable()
    func updateState(_ f: (GroupInfoState) -> GroupInfoState) -> Void {
        updateInfoState { state -> PeerInfoState in
            let result = f(state as! GroupInfoState)
            return result
        }
    }
    
    override func updateEditable(_ editable:Bool, peerView:PeerView) {
        
        let context = self.context
        let peerId = self.peerId
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        if editable {
            if let peer = peerViewMainPeer(peerView) {
                 if peer.isSupergroup, let cachedData = peerView.cachedData as? CachedChannelData {
                    updateState { state -> GroupInfoState in
                        return state.withUpdatedEditingState(GroupInfoEditingState(editingName: peer.displayTitle, editingDescriptionText: cachedData.about ?? ""))
                    }
                } else if let cachedData = peerView.cachedData as? CachedGroupData {
                    updateState { state -> GroupInfoState in
                        return state.withUpdatedEditingState(GroupInfoEditingState(editingName: peer.displayTitle, editingDescriptionText: cachedData.about ?? ""))
                    }
                }
            }
        } else {
            var updateValues: (title: String?, description: String?) = (nil, nil)
            updateState { state in
                updateValues = valuesRequiringUpdate(state: state, view: peerView)
                if updateValues.0 != nil || updateValues.1 != nil {
                    return state.withUpdatedSavingData(true)
                } else {
                    return state.withUpdatedEditingState(nil)
                }
            }
            
            let updateTitle: Signal<Void, NoError>
            if let titleValue = updateValues.title {
                updateTitle = updatePeerTitle(account: context.account, peerId: peerId, title: titleValue)
                     |> `catch` {_ in return .complete()}
            } else {
                updateTitle = .complete()
            }
            
            let updateDescription: Signal<Void, NoError>
            if let descriptionValue = updateValues.description {
                updateDescription = updatePeerDescription(account: context.account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                     |> `catch` {_ in return .complete()}
            } else {
                updateDescription = .complete()
            }
            
            let signal = combineLatest(updateTitle, updateDescription)
            
            updatePeerNameDisposable.set(showModalProgress(signal: (signal |> deliverOnMainQueue), for: mainWindow).start(error: { _ in
                updateState { state in
                    return state.withUpdatedSavingData(false)
                }
            }, completed: {
                updateState { state in
                    return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                }
            }))
        }
    }
    
    override func dismissEdition() {
        updateState { state in
            return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
        }
    }
    
    func updateEditingName(_ name:String) -> Void {
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(GroupInfoEditingState(editingName: name, editingDescriptionText: editingState.editingDescriptionText))
            } else {
                return state
            }
        }
    }
    func updateEditingDescriptionText(_ text:String) -> Void {
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(text))
            }
            return state
        }
    }
    
    func visibilitySetup() {
        let setup = ChannelVisibilityController(context, peerId: peerId)
        _ = (setup.onComplete.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peerId in
            self?.changeControllers(peerId)
            self?.pullNavigation()?.back()
        })
        pushViewController(setup)
    }
    
    private func changeControllers(_ peerId: PeerId?) {
        guard let navigationController = self.pullNavigation() else {
            return
        }
        if let peerId = peerId {
            var chatController: ChatController? = ChatController(context: context, chatLocation: .peer(peerId))
            
            navigationController.removeAll()
            
            chatController!.navigationController = navigationController
            chatController!.loadViewIfNeeded(navigationController.bounds)
            
            var signal = chatController!.ready.get() |> filter {$0} |> take(1) |> ignoreValues
            
            var controller: PeerInfoController? = PeerInfoController(context: context, peerId: peerId)
            
            
            controller!.navigationController = navigationController
            controller!.loadViewIfNeeded(navigationController.bounds)
            
            let mainSignal = controller!.ready.get() |> filter {$0} |> take(1) |> ignoreValues
            
            signal = combineLatest(queue: .mainQueue(), signal, mainSignal) |> ignoreValues
            
            _ = signal.start(completed: { [weak navigationController] in
                guard let navigationController = navigationController else { return }
                
                
                navigationController.stackInsert(chatController!, at: 0)
                navigationController.stackInsert(controller!, at: 1)
                navigationController.stackInsert(navigationController.controller, at: 2)
                navigationController.back()
                chatController = nil
                controller = nil
            })
        } else {
            navigationController.back()
        }
        
        
    }
    
    func preHistorySetup() {
        let setup = PreHistorySettingsController(context, peerId: peerId)
        _ = (setup.onComplete.get() |> deliverOnMainQueue).start(next: { [weak self] peerId in
            self?.changeControllers(peerId)
        })
        pushViewController(setup)
    }
    
    func blacklist() {
        pushViewController(ChannelPermissionsController(context, peerId: peerId))
    }
    
    
    func admins() {
        pushViewController(ChannelAdminsViewController(context, peerId: peerId))
    }
    
    func invation() {
        pushViewController(LinkInvationController(context, peerId: peerId))
    }
    
    func updatePhoto(_ path:String) -> Void {
        
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let cancel = { [weak self] in
            self?.updatePhotoDisposable.dispose()
            updateState { state -> GroupInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }
        
        let context = self.context
        let peerId = self.peerId
        
        let updateSignal = Signal<String, NoError>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
            } |> beforeNext { resource in
                
                updateState { (state) -> GroupInfoState in
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
                    }
                }
                
            } |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                return  updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.account.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                })
        }
        
        
        updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
            updateState { state -> GroupInfoState in
                switch status {
                case .complete:
                    return state
                case let .progress(progress):
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return previous?.withUpdatedProgress(progress)
                    }
                }
            }
        }, error: { error in
            updateState { (state) -> GroupInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }, completed: {
            updateState { (state) -> GroupInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }))
        
        
    }
    
    func setupDiscussion() {
        _ = (self.context.account.postbox.loadedPeerWithId(self.peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let `self` = self {
                self.pushViewController(ChannelDiscussionSetupController(context: self.context, peer: peer))
            }
        })
    }
    
    func addMember(_ canInviteByLink: Bool) -> Void {
        let context = self.context
        let peerId = self.peerId
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        let confirmationImpl:([PeerId])->Signal<Bool, NoError> = { peerIds in
            if let first = peerIds.first, peerIds.count == 1 {
                return context.account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                    return confirmSignal(for: mainWindow, information: L10n.peerInfoConfirmAddMember(peer.displayTitle), okTitle: L10n.peerInfoConfirmAdd)
                }
            }
            return confirmSignal(for: mainWindow, information: L10n.peerInfoConfirmAddMembers1Countable(peerIds.count), okTitle: L10n.peerInfoConfirmAdd)
        }
        
        
        let addMember = context.account.viewTracker.peerView(peerId) |> take(1) |> deliverOnMainQueue |> mapToSignal{ view -> Signal<Void, NoError> in
            
            var excludePeerIds:[PeerId] = []
            if let cachedData = view.cachedData as? CachedChannelData {
                excludePeerIds = Array(cachedData.peerIds)
            } else if let cachedData = view.cachedData as? CachedGroupData {
                excludePeerIds = Array(cachedData.peerIds)
            }
            
            var linkInvation: (()->Void)? = nil
            if canInviteByLink {
                linkInvation = { [weak self] in
                    self?.invation()
                }
            }
            
            
            return selectModalPeers(context: context, title: L10n.peerInfoAddMember, settings: [.contacts, .remote], excludePeerIds:excludePeerIds, limit: peerId.namespace == Namespaces.Peer.CloudGroup ? 1 : 100, confirmation: confirmationImpl, linkInvation: linkInvation)
                |> deliverOnMainQueue
                |> mapToSignal { memberIds -> Signal<Void, NoError> in
                    return context.account.postbox.multiplePeersView(memberIds + [peerId])
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { view -> Signal<Void, NoError> in
                            updateState { state in
                                var state = state
                                for (memberId, peer) in view.peers {
                                    var found = false
                                    for participant in state.temporaryParticipants {
                                        if participant.peer.id == memberId {
                                            found = true
                                            break
                                        }
                                    }
                                    if !found {
                                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                        var temporaryParticipants = state.temporaryParticipants
                                        temporaryParticipants.append(TemporaryParticipant(peer: peer, presence: view.presences[memberId], timestamp: timestamp))
                                        state = state.withUpdatedTemporaryParticipants(temporaryParticipants)
                                    }
                                }
                                
                                return state
                                
                            }
                            
                            if let peer = view.peers[peerId] {
                                if peer.isGroup, let memberId = memberIds.first {
                                    return addGroupMember(account: context.account, peerId: peerId, memberId: memberId)
                                        |> deliverOnMainQueue
                                        |> afterCompleted {
                                            updateState { state in
                                                var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                                successfullyAddedParticipantIds.insert(memberId)
                                                
                                                return state.withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                            }
                                        } |> `catch` { _ -> Signal<Void, NoError> in
                                            updateState { state in
                                                var temporaryParticipants = state.temporaryParticipants
                                                for i in 0 ..< temporaryParticipants.count {
                                                    if temporaryParticipants[i].peer.id == memberId {
                                                        temporaryParticipants.remove(at: i)
                                                        break
                                                    }
                                                }
                                                var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                                                successfullyAddedParticipantIds.remove(memberId)
                                                
                                                return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds)
                                            }
                                            
                                            return .complete()
                                    }
                                    
                                } else if peer.isSupergroup {
                                    return context.peerChannelMemberCategoriesContextsManager.addMembers(account: context.account, peerId: peerId, memberIds: memberIds) |> `catch` { _ in return .complete() }
                                }
                            }
                            
                            return .complete()
                    }
            }
        }
        
        addMemberDisposable.set(addMember.start())
        
    }
    func removePeer(_ memberId:PeerId) -> Void {
        
        let context = self.context
        let peerId = self.peerId
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        
        
        
        let signal = context.account.postbox.loadedPeerWithId(memberId)
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Bool, NoError> in
                let result = ValuePromise<Bool>()
                result.set(true)
                return result.get()
            }
            |> mapToSignal { value -> Signal<Void, NoError> in
                if value {
                    updateState { state in
                        var temporaryParticipants = state.temporaryParticipants
                        for i in 0 ..< state.temporaryParticipants.count {
                            if state.temporaryParticipants[i].peer.id == memberId {
                                temporaryParticipants.remove(at: i)
                                break
                            }
                        }
                        var successfullyAddedParticipantIds = state.successfullyAddedParticipantIds
                        successfullyAddedParticipantIds.remove(memberId)
                        
                        var removingParticipantIds = state.removingParticipantIds
                        removingParticipantIds.insert(memberId)
                        
                        return state.withUpdatedTemporaryParticipants(temporaryParticipants).withUpdatedSuccessfullyAddedParticipantIds(successfullyAddedParticipantIds).withUpdatedRemovingParticipantIds(removingParticipantIds)
                    }
                    
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        return context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max))
                            |> afterDisposed {
                                Queue.mainQueue().async {
                                    updateState { state in
                                        var removingParticipantIds = state.removingParticipantIds
                                        removingParticipantIds.remove(memberId)
                                        
                                        return state.withUpdatedRemovingParticipantIds(removingParticipantIds)
                                    }
                                }
                        }
                    }
                    
                    return removePeerMember(account: context.account, peerId: peerId, memberId: memberId)
                        |> deliverOnMainQueue
                        |> afterDisposed {
                            updateState { state in
                                var removingParticipantIds = state.removingParticipantIds
                                removingParticipantIds.remove(memberId)
                                
                                return state.withUpdatedRemovingParticipantIds(removingParticipantIds)
                            }
                    }
                } else {
                    return .complete()
                }
        }
        removeMemberDisposable.set(signal.start())
    }

    
    func setGroupStickerset() {
        pullNavigation()?.push(GroupStickerSetController(context, peerId: peerId))
        
    }
    
    func eventLog() {
        pullNavigation()?.push(ChannelEventLogController(context, peerId: peerId))
    }
    
    deinit {
        removeMemberDisposable.dispose()
        addMemberDisposable.dispose()
        updatePeerNameDisposable.dispose()
        updatePhotoDisposable.dispose()
    }
    
}

class GroupInfoState: PeerInfoState {
    
    let editingState: GroupInfoEditingState?
    let updatingName: String?
    let temporaryParticipants: [TemporaryParticipant]
    let successfullyAddedParticipantIds: Set<PeerId>
    let removingParticipantIds: Set<PeerId>
    let updatingPhotoState:PeerInfoUpdatingPhotoState?
    
    let savingData: Bool
    
    init(editingState: GroupInfoEditingState?, updatingName:String?, temporaryParticipants:[TemporaryParticipant], successfullyAddedParticipantIds:Set<PeerId>, removingParticipantIds:Set<PeerId>, savingData: Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?) {
        self.editingState = editingState
        self.updatingName = updatingName
        self.temporaryParticipants = temporaryParticipants
        self.successfullyAddedParticipantIds = successfullyAddedParticipantIds
        self.removingParticipantIds = removingParticipantIds
        self.savingData = savingData
        self.updatingPhotoState = updatingPhotoState
    }
    
    override init() {
        self.editingState = nil
        self.updatingName = nil
        self.temporaryParticipants = []
        self.successfullyAddedParticipantIds = Set()
        self.removingParticipantIds = Set()
        self.savingData = false
        self.updatingPhotoState = nil
    }
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? GroupInfoState {
            return self == to
        }
        return false
    }
    
    func withUpdatedEditingState(_ editingState: GroupInfoEditingState?) -> GroupInfoState {
        return GroupInfoState(editingState: editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedUpdatingName(_ updatingName: String?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    
    func withUpdatedTemporaryParticipants(_ temporaryParticipants: [TemporaryParticipant]) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedSuccessfullyAddedParticipantIds(_ successfullyAddedParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedRemovingParticipantIds(_ removingParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedUpdatingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: f(self.updatingPhotoState))
    }
    func withoutUpdatingPhotoState() -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: nil)
    }
    
}


enum GroupInfoMemberStatus {
    case member
    case admin
}

private struct GroupPeerEntryStableId: PeerInfoEntryStableId {
    let peerId: PeerId
    
    func isEqual(to: PeerInfoEntryStableId) -> Bool {
        if let to = to as? GroupPeerEntryStableId, to.peerId == self.peerId {
            return true
        } else {
            return false
        }
    }
    
    var hashValue: Int {
        return self.peerId.hashValue
    }
}



enum GroupInfoEntry: PeerInfoEntry {
    case info(section:Int, view: PeerView, editingState: GroupInfoEditingState?, updatingPhotoState:PeerInfoUpdatingPhotoState?)
    case setGroupPhoto(section:Int)
    case scam(section:Int, text: String)
    case about(section:Int, text: String)
    case addressName(section:Int, name:String)
    case sharedMedia(section:Int)
    case notifications(section:Int, settings: PeerNotificationSettings?)
    case usersHeader(section:Int, count:Int)
    case addMember(section:Int, inviteViaLink: Bool)
    case groupTypeSetup(section:Int, isPublic: Bool)
    case linkedChannel(section:Int, channel: Peer, subscribers: Int32?)
    case groupDescriptionSetup(section:Int, text: String)
    case groupAboutDescription(section:Int)
    case groupStickerset(section:Int, packName: String)
    case preHistory(section:Int, enabled: Bool)
    case groupManagementInfoLabel(section:Int, text: String)
    case administrators(section:Int, count: String)
    case permissions(section:Int, count: String)
    
    case member(section:Int, index: Int, peerId: PeerId, peer: Peer?, presence: PeerPresence?, activity: PeerInputActivity?, memberStatus: GroupInfoMemberStatus, editing: ShortPeerDeleting?, enabled:Bool)
    case leave(section:Int, text: String)
    case section(Int)
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? GroupInfoEntry else {
            return false
        }
        
        switch self {
        case let .info(_, lhsPeerView, lhsEditingState, lhsUpdatingPhotoState):
            switch entry {
            case let .info(_, rhsPeerView, rhsEditingState, rhsUpdatingPhotoState):
                
                if lhsUpdatingPhotoState != rhsUpdatingPhotoState {
                    return false
                }
                
                if lhsEditingState != rhsEditingState {
                    return false
                }
                
                let lhsPeer = peerViewMainPeer(lhsPeerView)
                let lhsCachedData = lhsPeerView.cachedData
                
                let rhsPeer = peerViewMainPeer(rhsPeerView)
                let rhsCachedData = rhsPeerView.cachedData
                
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer == nil) != (rhsPeer != nil) {
                    return false
                }
                if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                    if !lhsCachedData.isEqual(to: rhsCachedData) {
                        return false
                    }
                } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case .setGroupPhoto:
            if case .setGroupPhoto = entry {
                return true
            } else {
                return false
            }
        case let .addressName(_, addressName):
            if case .addressName(_, addressName) = entry {
                return true
            } else {
                return false
            }
        case let .scam(_, text):
            if case .scam(_, text) = entry {
                return true
            } else {
                return false
            }
        case let .about(_, text):
            if case .about(_, text) = entry {
                return true
            } else {
                return false
            }
        case .sharedMedia:
            if case .sharedMedia = entry {
                return true
            } else {
                return false
            }
        case let .preHistory(sectionId, enabled):
            if case .preHistory(sectionId, enabled) = entry {
                return true
            } else {
                return false
            }
        case let .administrators(section, count):
            if case .administrators(section, count) = entry {
                return true
            } else {
                return false
            }
        case let .permissions(section, count):
            if case .permissions(section, count) = entry {
                return true
            } else {
                return false
            }
        case let .groupStickerset(sectionId, packName):
            if case .groupStickerset(sectionId, packName) = entry {
                return true
            } else {
                return false
            }
        case let .notifications(_, lhsSettings):
            switch entry {
            case let .notifications(_, rhsSettings):
                
                if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                    return lhsSettings.isEqual(to: rhsSettings)
                } else if (lhsSettings != nil) != (rhsSettings != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case let .groupTypeSetup(_, isPublic):
            if case .groupTypeSetup(_, isPublic) = entry {
                return true
            } else {
                return false
            }
        case let .linkedChannel(sectionId, lhsChannel, subscribers):
            if case .linkedChannel(sectionId, let rhsChannel, subscribers) = entry {
                return lhsChannel.isEqual(rhsChannel)
            } else {
                return false
            }
        case .groupDescriptionSetup:
            if case .groupDescriptionSetup = entry {
                return true
            } else {
                return false
            }
        case .groupAboutDescription:
            if case .groupAboutDescription = entry {
                return true
            } else {
                return false
            }
        case let .groupManagementInfoLabel(_, text):
            if case .groupManagementInfoLabel(_, text) = entry {
                return true
            } else {
                return false
            }
        case let .usersHeader(_, count):
            if case .usersHeader(_, count) = entry {
                return true
            } else {
                return false
            }
        case .addMember:
            if case .addMember = entry {
                return true
            } else {
                return false
            }
        case let .member(_, lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsActivity, lhsMemberStatus, lhsEditing, lhsEnabled):
            if case let .member(_, rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsActivity, rhsMemberStatus, rhsEditing, rhsEnabled) = entry {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsMemberStatus != rhsMemberStatus {
                    return false
                }
                if lhsPeerId != rhsPeerId {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer != nil) != (rhsPeer != nil) {
                    return false
                }
                if lhsActivity != rhsActivity {
                    return false
                }
                if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                    if !lhsPresence.isEqual(to: rhsPresence) {
                        return false
                    }
                } else if (lhsPresence != nil) != (rhsPresence != nil) {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                
                return true
            } else {
                return false
            }
        case let .leave(sectionId, text):
            if case .leave(sectionId, text) = entry {
                return true
            } else {
                return false
            }
        case let .section(lhsId):
            switch entry {
            case let .section(rhsId):
                return lhsId == rhsId
            default:
                return false
            }
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        switch self {
        case let .member(_, _, peerId, _, _, _, _, _, _):
            return GroupPeerEntryStableId(peerId: peerId)
        default:
            return IntPeerInfoEntryStableId(value: stableIndex)
        }
    }
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .scam:
            return 1
        case .about:
            return 2
        case .addressName:
            return 3
        case .setGroupPhoto:
            return 4
        case .groupDescriptionSetup:
            return 5
        case .groupAboutDescription:
            return 6
        case .notifications:
            return 7
        case .sharedMedia:
            return 8
        case .groupTypeSetup:
            return 9
        case .linkedChannel:
            return 10
        case .preHistory:
            return 11
        case .groupStickerset:
            return 12
        case .groupManagementInfoLabel:
            return 13
        case .permissions:
            return 14
        case .administrators:
            return 15
        case .usersHeader:
            return 16
        case .addMember:
            return 17
        case .member:
            fatalError("no stableIndex")
        case .leave:
            return 19
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    
    
    var sortIndex: Int {
        switch self {
        case let .info(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .scam(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .about(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .addressName(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .setGroupPhoto(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .addMember(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .notifications(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .sharedMedia(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .groupTypeSetup(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .linkedChannel(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .preHistory(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .groupStickerset(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .administrators(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .permissions(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .groupDescriptionSetup(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .groupAboutDescription(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .groupManagementInfoLabel(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .usersHeader(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .member(sectionId, index, _, _, _, _, _, _, _):
            return (sectionId * 1000) + index + 200
        case let .leave(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let other = entry as? GroupInfoEntry else {
            return false
        }
        
        return self.sortIndex < other.sortIndex
    }
    
    func item(initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem {
        let arguments = arguments as! GroupInfoArguments
        
        switch self {
        case let .info(_, peerView, editingState, updatingPhotoState):
            return PeerInfoHeaderItem(initialSize, stableId:stableId.hashValue, context: arguments.context, peerView:peerView, editable: editingState != nil, updatingPhotoState: updatingPhotoState, firstNameEditableText: editingState?.editingName, textChangeHandler: { name, _ in
                arguments.updateEditingName(name)
            })
        case let .scam(_, text):
            return TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoScam, labelColor: theme.colors.redUI, text: text, context: arguments.context, detectLinks:false)
        case let .about(_, text):
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoInfo, text: text, context: arguments.context, detectLinks:true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
        }, hashtag: arguments.context.sharedContext.bindings.globalSearch)
        case let .addressName(_, value):
            let link = "https://t.me/\(value)"
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoSharelink, text: link, context: arguments.context, isTextSelectable:false, callback:{
                showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: link)), for: mainWindow)
            }, selectFullWord: true)
        case .setGroupPhoto:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSetGroupPhoto, nameStyle: blueActionButton, type: .none, action: {
                
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: mainWindow, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: mainWindow)
                            _ = controller.result.start(next: { url, _ in
                                arguments.updatePhoto(url.path)
                            })
                            
                            controller.onClose = {
                                removeFile(at: path)
                            }
                        })
                    }
                })
                
//                pickImage(for: mainWindow, completion: { image in
//                    if let image = image {
//                        _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { path in
//                            arguments.updatePhoto(path)
//                        })
//                    }
//                })
                
            })
        case let .notifications(_, settings):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoNotifications, type: .switchable(!((settings as? TelegramPeerNotificationSettings)?.isMuted ?? true)), action: {
                arguments.toggleNotifications()
            })
            
        case .sharedMedia:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSharedMedia, type: .none, action: { () in
                arguments.sharedMedia()
            })
        case let .groupDescriptionSetup(section: _, text: text):
            return GeneralInputRowItem(initialSize, stableId: stableId.hashValue, placeholder: L10n.peerInfoAboutPlaceholder, text: text, limit: 255, insets: NSEdgeInsets(left:25,right:25,top:8,bottom:3), textChangeHandler: { updatedText in
                arguments.updateEditingDescriptionText(updatedText)
            }, font: .normal(.title))
        case let .preHistory(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoPreHistory, type: .context(enabled ? L10n.peerInfoPreHistoryVisible : L10n.peerInfoPreHistoryHidden), action: {
                arguments.preHistorySetup()
            })
        case .groupAboutDescription:
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSetAboutDescription)
            
        case let .groupTypeSetup(section: _, isPublic: isPublic):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoGroupType, type: .context(isPublic ? L10n.peerInfoGroupTypePublic : L10n.peerInfoGroupTypePrivate), action: { () in
                arguments.visibilitySetup()
            })
        case let .linkedChannel(_, channel, _):
            let title: String
            if let address = channel.addressName {
                title = "@\(address)"
            } else {
                title = channel.displayTitle
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoLinkedChannel, type: .nextContext(title), action: { () in
                arguments.setupDiscussion()
            })
        case .groupStickerset(_, let name):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSetGroupStickersSet, type: .context(name), action: { () in
                arguments.setGroupStickerset()
            })
        case let .permissions(section: _, count: count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoPermissions, icon: theme.icons.peerInfoPermissions, type: .context(count), action: { () in
                arguments.blacklist()
            })
        case let .administrators(section: _, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAdministrators, icon: theme.icons.peerInfoAdmins, type: .context(count), action: { () in
                arguments.admins()
            })
        case let .usersHeader(section: _, count: count):
            var countValue = L10n.peerInfoMembersHeaderCountable(count)
            countValue = countValue.replacingOccurrences(of: "\(count)", with: count.separatedNumber)
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: countValue)
        case .addMember(_, let inviteViaLink):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAddMember, nameStyle: blueActionButton, type: .none, action: { () in
                arguments.addMember(inviteViaLink)
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 36), inset:NSEdgeInsets(left: 40, right: 30))
        case let .member(_, _, _, peer, presence, inputActivity, memberStatus, editing, enabled):
            let label: String
            switch memberStatus {
            case .admin:
                label = L10n.peerInfoAdminLabel
            case .member:
                label = ""
            }
            
            var string:String = L10n.peerStatusRecently
            var color:NSColor = theme.colors.grayText
            
            if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
                string = botInfo.flags.contains(.hasAccessToChatHistory) ? L10n.peerInfoBotStatusHasAccess : L10n.peerInfoBotStatusHasNoAccess
            } else if let presence = presence as? TelegramUserPresence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
            }
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { memberId in
                    arguments.removePeer(memberId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: peer!, account: arguments.context.account, stableId: stableId.hashValue, enabled: enabled, height: 46, photoSize: NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(12.5), foregroundColor: theme.colors.text), statusStyle: ControlStyle(font: NSFont.normal(12.5), foregroundColor:color), status: string, inset:NSEdgeInsets(left:30.0,right:30.0), interactionType: interactionType, generalType: .context(label), action:{
                arguments.peerInfo(peer!.id)
            }, inputActivity: inputActivity)
            
        case .leave(_, let text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: text, nameStyle: redActionButton, type: .none, action: {
                arguments.delete()
            })
        case .section(_):
            return GeneralRowItem(initialSize, height:20, stableId: stableId.hashValue)
        default:
            preconditionFailure()
        }
    }
}




func groupInfoEntries(view: PeerView, arguments: PeerInfoArguments, inputActivities: [PeerId: PeerInputActivity], channelMembers: [RenderedChannelParticipant] = []) -> [PeerInfoEntry] {
    var entries: [PeerInfoEntry] = []
    if let group = peerViewMainPeer(view), let arguments = arguments as? GroupInfoArguments, let state = arguments.state as? GroupInfoState {
        
        var sectionId:Int = 0
        let access = group.groupAccess
        
        
        entries.append(GroupInfoEntry.info(section: sectionId, view: view, editingState: access.canEditGroupInfo ? state.editingState : nil, updatingPhotoState: state.updatingPhotoState))
        
        
        if let editingState = state.editingState {
                        
            
            if access.canEditGroupInfo {
                entries.append(GroupInfoEntry.setGroupPhoto(section: sectionId))
                entries.append(GroupInfoEntry.groupDescriptionSetup(section: sectionId, text: editingState.editingDescriptionText))
                entries.append(GroupInfoEntry.groupAboutDescription(section: sectionId))
                
                entries.append(GroupInfoEntry.section(sectionId))
                sectionId += 1
            }
            entries.append(GroupInfoEntry.notifications(section: sectionId, settings: view.notificationSettings))

 
            if let group = view.peers[view.peerId] as? TelegramGroup, let cachedGroupData = view.cachedData as? CachedGroupData {
                if case .creator = group.role {
                    if cachedGroupData.flags.contains(.canChangeUsername) {
                        entries.append(GroupInfoEntry.groupTypeSetup(section: sectionId, isPublic: group.addressName != nil))
                        
                       entries.append(GroupInfoEntry.preHistory(section: sectionId, enabled: false))
                    }
                    
                    var activePermissionCount: Int?
                    if let defaultBannedRights = group.defaultBannedRights {
                        var count = 0
                        for right in allGroupPermissionList {
                            if !defaultBannedRights.flags.contains(right) {
                                count += 1
                            }
                        }
                        activePermissionCount = count
                    }
                    
                    entries.append(GroupInfoEntry.section(sectionId))
                    sectionId += 1
                    
                    entries.append(GroupInfoEntry.permissions(section: sectionId, count: activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""))
                    entries.append(GroupInfoEntry.administrators(section: sectionId, count: ""))
                }
            } else if let channel = view.peers[view.peerId] as? TelegramChannel, let cachedChannelData = view.cachedData as? CachedChannelData {
                
                if access.isCreator {
                    entries.append(GroupInfoEntry.groupTypeSetup(section: sectionId, isPublic: group.addressName != nil))
                }
                if (channel.adminRights != nil || channel.flags.contains(.isCreator)), let linkedDiscussionPeerId = cachedChannelData.linkedDiscussionPeerId, let peer = view.peers[linkedDiscussionPeerId] {
                    entries.append(GroupInfoEntry.linkedChannel(section: sectionId, channel: peer, subscribers: cachedChannelData.participantsSummary.memberCount))
                } else if channel.hasPermission(.banMembers) {
                    if !access.isPublic {
                        entries.append(GroupInfoEntry.preHistory(section: sectionId, enabled: cachedChannelData.flags.contains(.preHistoryEnabled)))
                    }
                }
                
                if cachedChannelData.flags.contains(.canSetStickerSet) && access.canEditGroupInfo {
                    entries.append(GroupInfoEntry.groupStickerset(section: sectionId, packName: cachedChannelData.stickerPack?.title ?? ""))
                }
                
                var canViewAdminsAndBanned = false
                if let channel = view.peers[view.peerId] as? TelegramChannel {
                    if let adminRights = channel.adminRights, !adminRights.isEmpty {
                        canViewAdminsAndBanned = true
                    } else if channel.flags.contains(.isCreator) {
                        canViewAdminsAndBanned = true
                    }
                }
                
                if canViewAdminsAndBanned {
                    var activePermissionCount: Int?
                    if let defaultBannedRights = channel.defaultBannedRights {
                        var count = 0
                        for right in allGroupPermissionList {
                            if !defaultBannedRights.flags.contains(right) {
                                count += 1
                            }
                        }
                        activePermissionCount = count
                    }
                    
                    entries.append(GroupInfoEntry.section(sectionId))
                    sectionId += 1
                    
                    entries.append(GroupInfoEntry.permissions(section: sectionId, count: activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""))
                    entries.append(GroupInfoEntry.administrators(section: sectionId, count: cachedChannelData.participantsSummary.adminCount.flatMap { "\($0)" } ?? ""))
                }
            }

        } else {
            
            if group.isScam {
                entries.append(GroupInfoEntry.scam(section: sectionId, text: L10n.groupInfoScamWarning))
            }
            
            if let cachedChannelData = view.cachedData as? CachedChannelData {
                if let about = cachedChannelData.about, !about.isEmpty, !group.isScam {
                    entries.append(GroupInfoEntry.about(section: sectionId, text: about))
                }
            }
            
            if let cachedGroupData = view.cachedData as? CachedGroupData {
                if let about = cachedGroupData.about, !about.isEmpty, !group.isScam {
                    entries.append(GroupInfoEntry.about(section: sectionId, text: about))
                }
            }
            
            
            
            if let addressName = group.addressName {
                entries.append(GroupInfoEntry.addressName(section: sectionId, name: addressName))
            }
            
            if entries.count > 1 {
                entries.append(GroupInfoEntry.section(sectionId))
                sectionId += 1
            }
            entries.append(GroupInfoEntry.notifications(section: sectionId, settings: view.notificationSettings))
            entries.append(GroupInfoEntry.sharedMedia(section: sectionId))
        }
        
        
        
        if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
            
            entries.append(GroupInfoEntry.section(sectionId))
            sectionId = 10
            
            entries.append(GroupInfoEntry.usersHeader(section: sectionId, count: participants.participants.count))
            
            
           
            
            if access.canAddMembers {
                entries.append(GroupInfoEntry.addMember(section: sectionId, inviteViaLink: access.canCreateInviteLink))
            }
            
            
            var updatedParticipants = participants.participants
            let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
            
            
            var peerPresences: [PeerId: PeerPresence] = view.peerPresences
            var peers: [PeerId: Peer] = view.peers
            var disabledPeerIds = state.removingParticipantIds
            
            if !state.temporaryParticipants.isEmpty {
                for participant in state.temporaryParticipants {
                    if !existingParticipantIds.contains(participant.peer.id) {
                        updatedParticipants.append(.member(id: participant.peer.id, invitedBy: arguments.context.account.peerId, invitedAt: participant.timestamp))
                        if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                            peerPresences[participant.peer.id] = presence
                        }
                        if peers[participant.peer.id] == nil {
                            peers[participant.peer.id] = participant.peer
                        }
                        disabledPeerIds.insert(participant.peer.id)
                    }
                }
            }
            
            let sortedParticipants = participants.participants.filter({peers[$0.peerId]?.displayTitle != nil}).sorted(by: { lhs, rhs in
                let lhsPresence = view.peerPresences[lhs.peerId] as? TelegramUserPresence
                let rhsPresence = view.peerPresences[rhs.peerId] as? TelegramUserPresence
                
                let lhsActivity = inputActivities[lhs.peerId]
                let rhsActivity = inputActivities[rhs.peerId]
                
                if lhsActivity != nil && rhsActivity == nil {
                    return true
                } else if rhsActivity != nil && lhsActivity == nil {
                    return false
                }
                
                if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                    return lhsPresence.status > rhsPresence.status
                } else if let _ = lhsPresence {
                    return true
                } else if let _ = rhsPresence {
                    return false
                }
                
                return lhs < rhs
            })
            
            for i in 0 ..< sortedParticipants.count {
                if let peer = view.peers[sortedParticipants[i].peerId] {
                    let memberStatus: GroupInfoMemberStatus
                    if access.highlightAdmins {
                        switch sortedParticipants[i] {
                        case .admin, .creator:
                            memberStatus = .admin
                        case .member:
                            memberStatus = .member
                        }
                    } else {
                        memberStatus = .member
                    }
                    
                    let editing:ShortPeerDeleting?
                    
                    if state.editingState != nil, let group = group as? TelegramGroup {
                        let deletable:Bool = group.canRemoveParticipant(sortedParticipants[i])
                        editing = ShortPeerDeleting(editable: deletable)
                    } else {
                        editing = nil
                    }
                    
                    entries.append(GroupInfoEntry.member(section: sectionId, index: i, peerId: peer.id, peer: peer, presence: view.peerPresences[peer.id], activity: inputActivities[peer.id], memberStatus: memberStatus, editing: editing, enabled: !disabledPeerIds.contains(peer.id)))
                }
            }
        }
        
        if let cachedGroupData = view.cachedData as? CachedChannelData {
            
            let participants = channelMembers
            
            var updatedParticipants = participants
            let existingParticipantIds = Set(updatedParticipants.map { $0.peer.id })
            var peerPresences: [PeerId: PeerPresence] = view.peerPresences
            var peers: [PeerId: Peer] = view.peers
            var disabledPeerIds = state.removingParticipantIds
            
            
            if !state.temporaryParticipants.isEmpty {
                for participant in state.temporaryParticipants {
                    if !existingParticipantIds.contains(participant.peer.id) {
                        updatedParticipants.append(RenderedChannelParticipant(participant: .member(id: participant.peer.id, invitedAt: participant.timestamp, adminInfo: nil, banInfo: nil), peer: participant.peer))
                        if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                            peerPresences[participant.peer.id] = presence
                        }
                        if peers[participant.peer.id] == nil {
                            peers[participant.peer.id] = participant.peer
                        }
                        disabledPeerIds.insert(participant.peer.id)
                    }
                }
            }
            
            entries.append(GroupInfoEntry.section(sectionId))
            sectionId = 10
            
            if let membersCount = cachedGroupData.participantsSummary.memberCount {
                entries.append(GroupInfoEntry.usersHeader(section: sectionId, count: Int(membersCount)))
            }
            
            if access.canAddMembers  {
                entries.append(GroupInfoEntry.addMember(section: sectionId, inviteViaLink: access.canCreateInviteLink))
            }
            
            let sortedParticipants = participants.filter({$0.peer.displayTitle != L10n.peerDeletedUser}).sorted(by: { lhs, rhs in
                let lhsPresence = lhs.presences[lhs.peer.id] as? TelegramUserPresence
                let rhsPresence = rhs.presences[rhs.peer.id] as? TelegramUserPresence
                
                let lhsActivity = inputActivities[lhs.peer.id]
                let rhsActivity = inputActivities[rhs.peer.id]
                
                if lhsActivity != nil && rhsActivity == nil {
                    return true
                } else if rhsActivity != nil && lhsActivity == nil {
                    return false
                }
                
                if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                    return lhsPresence.status > rhsPresence.status
                } else if let _ = lhsPresence {
                    return true
                } else if let _ = rhsPresence {
                    return false
                }
                
                return lhs < rhs
            })
            
            for i in 0 ..< sortedParticipants.count {
                let memberStatus: GroupInfoMemberStatus
                if access.highlightAdmins {
                    switch sortedParticipants[i].participant {
                    case .creator:
                        memberStatus = .admin
                    case .member(_, _, let adminRights, _):
                        memberStatus = adminRights != nil ? .admin : .member
                    }
                } else {
                    memberStatus = .member
                }
                
                let editing:ShortPeerDeleting?
                
                if state.editingState != nil, let group = group as? TelegramChannel {
                    let deletable:Bool = group.canRemoveParticipant(sortedParticipants[i].participant, accountId: arguments.context.account.peerId)
                    editing = ShortPeerDeleting(editable: deletable)
                } else {
                    editing = nil
                }
                
                entries.append(GroupInfoEntry.member(section: sectionId, index: i, peerId: sortedParticipants[i].peer.id, peer: sortedParticipants[i].peer, presence: sortedParticipants[i].presences[sortedParticipants[i].peer.id], activity: inputActivities[sortedParticipants[i].peer.id], memberStatus: memberStatus, editing: editing, enabled: !disabledPeerIds.contains(sortedParticipants[i].peer.id)))
            }
        }
        
        entries.append(GroupInfoEntry.section(sectionId))
        sectionId += 1
        
        if let group = peerViewMainPeer(view) as? TelegramGroup {
            if case .Member = group.membership {
                entries.append(GroupInfoEntry.leave(section: sectionId, text: L10n.peerInfoDeleteAndExit))
            }
        } else if let channel = peerViewMainPeer(view) as? TelegramChannel {
            if case .member = channel.participationStatus {
                if state.editingState != nil, access.isCreator {
                    entries.append(GroupInfoEntry.leave(section: sectionId, text: L10n.peerInfoDeleteGroup))
                } else {
                    entries.append(GroupInfoEntry.leave(section: sectionId, text: L10n.peerInfoLeaveGroup))
                }
            }
        }
        
    }
    
    
    return entries.sorted(by: { p1, p2 -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
