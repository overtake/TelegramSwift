//
//  GroupInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
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
    
    var loadMore: (()->Void)? = nil
    
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
            
            updatePeerNameDisposable.set(showModalProgress(signal: (signal |> deliverOnMainQueue), for: context.window).start(error: { _ in
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
    
    func showMore() {
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        updateState {
            return $0.withUpdatedHasShowMoreButton(nil)
        }
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
                                        } |> `catch` { error -> Signal<Void, NoError> in
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
                                    return context.peerChannelMemberCategoriesContextsManager.addMembers(account: context.account, peerId: peerId, memberIds: memberIds) |> deliverOnMainQueue |> `catch` { error in
                                        let text: String
                                        switch error {
                                        case .limitExceeded:
                                            text = L10n.channelErrorAddTooMuch
                                        case .botDoesntSupportGroups:
                                            text = L10n.channelBotDoesntSupportGroups
                                        case .tooMuchBots:
                                            text = L10n.channelTooMuchBots
                                        case .tooMuchJoined:
                                            text = L10n.inviteChannelsTooMuch
                                        case .generic:
                                            text = L10n.unknownError
                                        case let .bot(memberId):
                                            let _ = (context.account.postbox.transaction { transaction in
                                                return transaction.getPeer(peerId)
                                                }
                                                |> deliverOnMainQueue).start(next: { peer in
                                                    guard let peer = peer as? TelegramChannel else {
                                                        alert(for: context.window, info: L10n.unknownError)
                                                        return
                                                    }
                                                    if peer.hasPermission(.addAdmins) {
                                                        confirm(for: context.window, information: L10n.channelAddBotErrorHaveRights, okTitle: L10n.channelAddBotAsAdmin, successHandler: { _ in
                                                            showModal(with: ChannelAdminController(context, peerId: peerId, adminId: memberId, initialParticipant: nil, updated: { _ in }, upgradedToSupergroup: { _, f in f() }), for: context.window)
                                                        })
                                                    } else {
                                                        alert(for: context.window, info: L10n.channelAddBotErrorHaveRights)
                                                    }
                                                })
                                            return .complete()
                                        case .restricted:
                                            text = L10n.channelErrorAddBlocked
                                        }
                                        alert(for: context.window, info: text)
                                        
                                        return .complete()
                                    }
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
    
    let hasShowMoreButton: Bool?
    
    init(editingState: GroupInfoEditingState?, updatingName:String?, temporaryParticipants:[TemporaryParticipant], successfullyAddedParticipantIds:Set<PeerId>, removingParticipantIds:Set<PeerId>, savingData: Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?, hasShowMoreButton: Bool?) {
        self.editingState = editingState
        self.updatingName = updatingName
        self.temporaryParticipants = temporaryParticipants
        self.successfullyAddedParticipantIds = successfullyAddedParticipantIds
        self.removingParticipantIds = removingParticipantIds
        self.savingData = savingData
        self.updatingPhotoState = updatingPhotoState
        self.hasShowMoreButton = hasShowMoreButton
    }
    
    override init() {
        self.editingState = nil
        self.updatingName = nil
        self.temporaryParticipants = []
        self.successfullyAddedParticipantIds = Set()
        self.removingParticipantIds = Set()
        self.savingData = false
        self.updatingPhotoState = nil
        self.hasShowMoreButton = true
    }
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? GroupInfoState {
            return self == to
        }
        return false
    }
    
    func withUpdatedEditingState(_ editingState: GroupInfoEditingState?) -> GroupInfoState {
        return GroupInfoState(editingState: editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, hasShowMoreButton: self.hasShowMoreButton)
    }
    
    func withUpdatedUpdatingName(_ updatingName: String?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, hasShowMoreButton: self.hasShowMoreButton)
    }
    
    
    func withUpdatedTemporaryParticipants(_ temporaryParticipants: [TemporaryParticipant]) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, hasShowMoreButton: self.hasShowMoreButton)
    }
    
    func withUpdatedSuccessfullyAddedParticipantIds(_ successfullyAddedParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, hasShowMoreButton: self.hasShowMoreButton)
    }
    
    func withUpdatedRemovingParticipantIds(_ removingParticipantIds: Set<PeerId>) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, hasShowMoreButton: self.hasShowMoreButton)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: savingData, updatingPhotoState: self.updatingPhotoState, hasShowMoreButton: self.hasShowMoreButton)
    }
    
    func withUpdatedUpdatingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: f(self.updatingPhotoState), hasShowMoreButton: self.hasShowMoreButton)
    }
    func withoutUpdatingPhotoState() -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: nil, hasShowMoreButton: self.hasShowMoreButton)
    }
    func withUpdatedHasShowMoreButton(_ hasShowMoreButton: Bool?) -> GroupInfoState {
        return GroupInfoState(editingState: self.editingState, updatingName: self.updatingName, temporaryParticipants: self.temporaryParticipants, successfullyAddedParticipantIds: self.successfullyAddedParticipantIds, removingParticipantIds: self.removingParticipantIds, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, hasShowMoreButton: hasShowMoreButton)
    }
    
}


enum GroupInfoMemberStatus : Equatable {
    case member
    case admin(rank: String)
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
    case info(section:Int, view: PeerView, editingState: Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?, viewType: GeneralViewType)
    case setGroupPhoto(section:Int, viewType: GeneralViewType)
    case scam(section:Int, text: String, viewType: GeneralViewType)
    case about(section:Int, text: String, viewType: GeneralViewType)
    case addressName(section:Int, name:String, viewType: GeneralViewType)
    case sharedMedia(section:Int, viewType: GeneralViewType)
    case notifications(section:Int, settings: PeerNotificationSettings?, viewType: GeneralViewType)
    case usersHeader(section:Int, count:Int, viewType: GeneralViewType)
    case addMember(section:Int, inviteViaLink: Bool, viewType: GeneralViewType)
    case groupTypeSetup(section:Int, isPublic: Bool, viewType: GeneralViewType)
    case linkedChannel(section:Int, channel: Peer, subscribers: Int32?, viewType: GeneralViewType)
    case groupDescriptionSetup(section:Int, text: String, viewType: GeneralViewType)
    case groupAboutDescription(section:Int, viewType: GeneralViewType)
    case groupStickerset(section:Int, packName: String, viewType: GeneralViewType)
    case preHistory(section:Int, enabled: Bool, viewType: GeneralViewType)
    case groupManagementInfoLabel(section:Int, text: String, viewType: GeneralViewType)
    case administrators(section:Int, count: String, viewType: GeneralViewType)
    case permissions(section:Int, count: String, viewType: GeneralViewType)
    case member(section:Int, index: Int, peerId: PeerId, peer: Peer?, presence: PeerPresence?, activity: PeerInputActivity?, memberStatus: GroupInfoMemberStatus, editing: ShortPeerDeleting?, enabled:Bool, viewType: GeneralViewType)
    case showMore(section:Int, index: Int, viewType: GeneralViewType)
    case leave(section:Int, text: String, viewType: GeneralViewType)
    case section(Int)
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> GroupInfoEntry {
        switch self {
        case let .info(section, view, editingState, updatingPhotoState, _): return .info(section: section, view: view, editingState: editingState, updatingPhotoState: updatingPhotoState, viewType: viewType)
        case let .setGroupPhoto(section, _): return .setGroupPhoto(section: section, viewType: viewType)
        case let .scam(section, text, _): return .scam(section: section, text: text, viewType: viewType)
        case let .about(section, text, _): return .about(section: section, text: text, viewType: viewType)
        case let .addressName(section, name, _): return .addressName(section: section, name: name, viewType: viewType)
        case let .sharedMedia(section, _): return .sharedMedia(section: section, viewType: viewType)
        case let .notifications(section, settings, _): return .notifications(section: section, settings: settings, viewType: viewType)
        case let .usersHeader(section, count, _): return .usersHeader(section: section, count: count, viewType: viewType)
        case let .addMember(section, inviteViaLink, _): return .addMember(section: section, inviteViaLink: inviteViaLink, viewType: viewType)
        case let .groupTypeSetup(section, isPublic, _): return .groupTypeSetup(section: section, isPublic: isPublic, viewType: viewType)
        case let .linkedChannel(section, channel, subscriber, _): return .linkedChannel(section: section, channel: channel, subscribers: subscriber, viewType: viewType)
        case let .groupDescriptionSetup(section, text, _): return .groupDescriptionSetup(section: section, text: text, viewType: viewType)
        case let .groupAboutDescription(section, _): return .groupAboutDescription(section: section, viewType: viewType)
        case let .groupStickerset(section, packName, _): return .groupStickerset(section: section, packName: packName, viewType: viewType)
        case let .preHistory(section, enabled, _): return .preHistory(section: section, enabled: enabled, viewType: viewType)
        case let .groupManagementInfoLabel(section, text, _): return .groupManagementInfoLabel(section: section, text: text, viewType: viewType)
        case let .administrators(section, count, _): return .administrators(section: section, count: count, viewType: viewType)
        case let .permissions(section, count, _): return .permissions(section: section, count: count, viewType: viewType)
        case let .member(section, index, peerId, peer, presence, activity, memberStatus, editing, enabled, _): return .member(section: section, index: index, peerId: peerId, peer: peer, presence: presence, activity: activity, memberStatus: memberStatus, editing: editing, enabled: enabled, viewType: viewType)
        case let .showMore(section, index, _): return .showMore(section: section, index: index, viewType: viewType)
        case let .leave(section, text, _): return  .leave(section: section, text: text, viewType: viewType)
        case .section: return self
        }
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? GroupInfoEntry else {
            return false
        }
        
        switch self {
        case let .info(lhsSection, lhsPeerView, lhsEditingState, lhsUpdatingPhotoState, lhsViewType):
            switch entry {
            case let .info(rhsSection, rhsPeerView, rhsEditingState, rhsUpdatingPhotoState, rhsViewType):
                
                if lhsUpdatingPhotoState != rhsUpdatingPhotoState {
                    return false
                }
                if lhsSection != rhsSection {
                    return false
                }
                if lhsViewType != rhsViewType {
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
        case let .setGroupPhoto(section, viewType):
            if case .setGroupPhoto(section, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .addressName(section, addressName, viewType):
            if case .addressName(section, addressName, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .scam(section, text, viewType):
            if case .scam(section, text, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .about(section, text, viewType):
            if case .about(section, text, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .sharedMedia(sectionId, viewType):
            if case .sharedMedia(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .preHistory(sectionId, enabled, viewType):
            if case .preHistory(sectionId, enabled, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .administrators(section, count, viewType):
            if case .administrators(section, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .permissions(section, count, viewType):
            if case .permissions(section, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .groupStickerset(sectionId, packName, viewType):
            if case .groupStickerset(sectionId, packName, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .notifications(section, lhsSettings, viewType):
            switch entry {
            case .notifications(section, let rhsSettings, viewType):
                
                if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                    return lhsSettings.isEqual(to: rhsSettings)
                } else if (lhsSettings != nil) != (rhsSettings != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case let .groupTypeSetup(sectionId, isPublic, viewType):
            if case .groupTypeSetup(sectionId, isPublic, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .linkedChannel(sectionId, lhsChannel, subscribers, viewType):
            if case .linkedChannel(sectionId, let rhsChannel, subscribers, viewType) = entry {
                return lhsChannel.isEqual(rhsChannel)
            } else {
                return false
            }
        case let .groupDescriptionSetup(section, text, viewType):
            if case .groupDescriptionSetup(section, text, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .groupAboutDescription(section, viewType):
            if case .groupAboutDescription(section, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .groupManagementInfoLabel(section, text, viewType):
            if case .groupManagementInfoLabel(section, text, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .usersHeader(section, count, viewType):
            if case .usersHeader(section, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .addMember(section, inviteViaLink, viewType):
            if case .addMember(section, inviteViaLink, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .member(lhsSection, lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsActivity, lhsMemberStatus, lhsEditing, lhsEnabled, lhsViewType):
            if case let .member(rhsSection, rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsActivity, rhsMemberStatus, rhsEditing, rhsEnabled, rhsViewType) = entry {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsSection != rhsSection {
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
                if lhsViewType != rhsViewType {
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
        case let .showMore(sectionId, index, viewType):
            if case .showMore(sectionId, index, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .leave(sectionId, text, viewType):
            if case .leave(sectionId, text, viewType) = entry {
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
        case let .member(_, _, peerId, _, _, _, _, _, _, _):
            return GroupPeerEntryStableId(peerId: peerId)
        default:
            return IntPeerInfoEntryStableId(value: stableIndex)
        }
    }
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .setGroupPhoto:
            return 1
        case .scam:
            return 2
        case .about:
            return 3
        case .addressName:
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
        case .showMore:
            return 19
        case .leave:
            return 20
        case let .section(id):
            return (id + 1) * 100000 - id
        }
    }
    
    var sectionId: Int {
        switch self {
        case let .info(sectionId, _, _, _, _):
            return sectionId
        case let .scam(sectionId, _, _):
            return sectionId
        case let .about(sectionId, _, _):
            return sectionId
        case let .addressName(sectionId, _, _):
            return sectionId
        case let .setGroupPhoto(sectionId, _):
            return sectionId
        case let .addMember(sectionId, _, _):
            return sectionId
        case let .notifications(sectionId, _, _):
            return sectionId
        case let .sharedMedia(sectionId, _):
            return sectionId
        case let .groupTypeSetup(sectionId, _, _):
            return sectionId
        case let .linkedChannel(sectionId, _, _, _):
            return sectionId
        case let .preHistory(sectionId, _, _):
            return sectionId
        case let .groupStickerset(sectionId, _, _):
            return sectionId
        case let .administrators(sectionId, _, _):
            return sectionId
        case let .permissions(sectionId, _, _):
            return sectionId
        case let .groupDescriptionSetup(sectionId, _, _):
            return sectionId
        case let .groupAboutDescription(sectionId, _):
            return sectionId
        case let .groupManagementInfoLabel(sectionId, _, _):
            return sectionId
        case let .usersHeader(sectionId, _, _):
            return sectionId
        case let .member(sectionId, _, _, _, _, _, _, _, _, _):
            return sectionId
        case let .showMore(sectionId, _, _):
            return sectionId
        case let .leave(sectionId, _, _):
            return sectionId
        case let .section(sectionId):
            return sectionId
        }
    }
    
    var sortIndex: Int {
        switch self {
        case let .info(sectionId, _, _, _, _):
            return (sectionId * 100000) + stableIndex
        case let .scam(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .about(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .addressName(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .setGroupPhoto(sectionId, _):
            return (sectionId * 100000) + stableIndex
        case let .addMember(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .notifications(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .sharedMedia(sectionId, _):
            return (sectionId * 100000) + stableIndex
        case let .groupTypeSetup(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .linkedChannel(sectionId, _, _, _):
            return (sectionId * 100000) + stableIndex
        case let .preHistory(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .groupStickerset(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .administrators(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .permissions(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .groupDescriptionSetup(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .groupAboutDescription(sectionId, _):
            return (sectionId * 100000) + stableIndex
        case let .groupManagementInfoLabel(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .usersHeader(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .member(sectionId, index, _, _, _, _, _, _, _, _):
            return (sectionId * 100000) + index + 200
        case let .showMore(sectionId, index, _):
            return (sectionId * 100000) + index + 200
        case let .leave(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .section(sectionId):
            return (sectionId + 1) * 100000 - sectionId
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
        let state = arguments.state as! GroupInfoState
        switch self {
        case let .info(_, peerView, editable, updatingPhotoState, viewType):
            return PeerInfoHeaderItem(initialSize, stableId:stableId.hashValue, context: arguments.context, peerView:peerView, viewType: viewType, editable: editable, updatingPhotoState: updatingPhotoState, firstNameEditableText: state.editingState?.editingName, textChangeHandler: { name, _ in
                arguments.updateEditingName(name)
            })
        case let .scam(_, text, viewType):
            return TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoScam, labelColor: theme.colors.redUI, text: text, context: arguments.context, viewType: viewType, detectLinks:false)
        case let .about(_, text, viewType):
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoInfo, text: text, context: arguments.context, viewType: viewType, detectLinks:true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
        }, hashtag: arguments.context.sharedContext.bindings.globalSearch)
        case let .addressName(_, value, viewType):
            let link = "https://t.me/\(value)"
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoSharelink, text: link, context: arguments.context, viewType: viewType, isTextSelectable:false, callback:{
                showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: link)), for: mainWindow)
            }, selectFullWord: true)
        case let .setGroupPhoto(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSetGroupPhoto, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: mainWindow, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: mainWindow, animationType: .scaleCenter)
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
        case let .notifications(_, settings, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoNotifications, type: .switchable(!((settings as? TelegramPeerNotificationSettings)?.isMuted ?? true)), viewType: viewType, action: {
                arguments.toggleNotifications()
            })
            
        case let .sharedMedia(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSharedMedia, type: .next, viewType: viewType, action: { () in
                arguments.sharedMedia()
            })
        case let .groupDescriptionSetup(section: _, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: L10n.peerInfoAboutPlaceholder, filter: { $0 }, updated: arguments.updateEditingDescriptionText, limit: 255)
        case let .preHistory(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoPreHistory, type: .context(enabled ? L10n.peerInfoPreHistoryVisible : L10n.peerInfoPreHistoryHidden), viewType: viewType, action: {
                arguments.preHistorySetup()
            })
        case let .groupAboutDescription(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSetAboutDescription, viewType: viewType)
            
        case let .groupTypeSetup(section: _, isPublic: isPublic, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoGroupType, type: .nextContext(isPublic ? L10n.peerInfoGroupTypePublic : L10n.peerInfoGroupTypePrivate), viewType: viewType, action: { () in
                arguments.visibilitySetup()
            })
        case let .linkedChannel(_, channel, _, viewType):
            let title: String
            if let address = channel.addressName {
                title = "@\(address)"
            } else {
                title = channel.displayTitle
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoLinkedChannel, type: .nextContext(title), viewType: viewType, action: { () in
                arguments.setupDiscussion()
            })
        case let .groupStickerset(_, name, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSetGroupStickersSet, type: .nextContext(name), viewType: viewType, action: { () in
                arguments.setGroupStickerset()
            })
        case let .permissions(section: _, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoPermissions, icon: theme.icons.peerInfoPermissions, type: .nextContext(count), viewType: viewType, action: { () in
                arguments.blacklist()
            })
        case let .administrators(section: _, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAdministrators, icon: theme.icons.peerInfoAdmins, type: .nextContext(count), viewType: viewType, action: { () in
                arguments.admins()
            })
        case let .usersHeader(section: _, count, viewType):
            var countValue = L10n.peerInfoMembersHeaderCountable(count)
            countValue = countValue.replacingOccurrences(of: "\(count)", with: count.separatedNumber)
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: countValue, viewType: viewType)
        case let .addMember(_, inviteViaLink, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAddMember, nameStyle: blueActionButton, type: .none, viewType: viewType, action: { () in
                arguments.addMember(inviteViaLink)
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 52, thumbInset: 5))
        case let .member(_, _, _, peer, presence, inputActivity, memberStatus, editing, enabled, viewType):
            let label: String
            switch memberStatus {
            case let .admin(rank):
                label = rank
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
            
            return ShortPeerRowItem(initialSize, peer: peer!, account: arguments.context.account, stableId: stableId.hashValue, enabled: enabled, height: 50, photoSize: NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(12.5), foregroundColor: theme.colors.text), statusStyle: ControlStyle(font: NSFont.normal(12.5), foregroundColor:color), status: string, inset: NSEdgeInsets(left:30.0,right:30.0), interactionType: interactionType, generalType: .context(label), viewType: viewType, action:{
                arguments.peerInfo(peer!.id)
            }, inputActivity: inputActivity)
        case let .showMore(_, _, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoShowMore, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.showMore()
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
        case let .leave(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: text, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.delete()
            })
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId.hashValue, viewType: .separator)
        default:
            preconditionFailure()
        }
    }
}

enum GroupInfoSection : Int {
    case header = 1
    case info = 2
    case desc = 3
    case action = 4
    case addition = 5
    case type = 6
    case admin = 7
    case members = 8
    case destruct = 9
}


func groupInfoEntries(view: PeerView, arguments: PeerInfoArguments, inputActivities: [PeerId: PeerInputActivity], channelMembers: [RenderedChannelParticipant] = [], mediaTabsData: PeerMediaTabsData) -> [PeerInfoEntry] {
    var entries: [GroupInfoEntry] = []
    if let group = peerViewMainPeer(view), let arguments = arguments as? GroupInfoArguments, let state = arguments.state as? GroupInfoState {
        
        let access = group.groupAccess
        
        
        var infoBlock: [GroupInfoEntry] = []
        func applyBlock(_ block:[GroupInfoEntry]) {
            var block = block
            for (i, item) in block.enumerated() {
                block[i] = item.withUpdatedViewType(bestGeneralViewType(block, for: i))
            }
            entries.append(contentsOf: block)
        }
        
        infoBlock.append(.info(section: GroupInfoSection.header.rawValue, view: view, editingState: access.canEditGroupInfo ? state.editingState != nil : false, updatingPhotoState: state.updatingPhotoState, viewType: .singleItem))
        
        
        if let editingState = state.editingState {
            if access.canEditGroupInfo {
                infoBlock.append(GroupInfoEntry.setGroupPhoto(section: GroupInfoSection.header.rawValue, viewType: .singleItem))
                
                applyBlock(infoBlock)
                
                entries.append(GroupInfoEntry.groupDescriptionSetup(section: GroupInfoSection.desc.rawValue, text: editingState.editingDescriptionText, viewType: .singleItem))
                entries.append(GroupInfoEntry.groupAboutDescription(section:  GroupInfoSection.desc.rawValue, viewType: .textBottomItem))
            } else {
                applyBlock(infoBlock)
            }
            
            
            if let group = view.peers[view.peerId] as? TelegramGroup, let cachedGroupData = view.cachedData as? CachedGroupData {
                if case .creator = group.role {
                    if cachedGroupData.flags.contains(.canChangeUsername) {
                        entries.append(GroupInfoEntry.groupTypeSetup(section: GroupInfoSection.type.rawValue, isPublic: group.addressName != nil, viewType: .firstItem))
                        entries.append(GroupInfoEntry.preHistory(section: GroupInfoSection.type.rawValue, enabled: false, viewType: .lastItem))
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
                    
                    entries.append(GroupInfoEntry.permissions(section: GroupInfoSection.admin.rawValue, count: activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? "", viewType: .firstItem))
                    entries.append(GroupInfoEntry.administrators(section: GroupInfoSection.admin.rawValue, count: "", viewType: .lastItem))
                }
            } else if let channel = view.peers[view.peerId] as? TelegramChannel, let cachedChannelData = view.cachedData as? CachedChannelData {
                
                var actionBlock:[GroupInfoEntry] = []
                
                if access.isCreator {
                    actionBlock.append(.groupTypeSetup(section: GroupInfoSection.type.rawValue, isPublic: group.addressName != nil, viewType: .singleItem))
                }
                if (channel.adminRights != nil || channel.flags.contains(.isCreator)), let linkedDiscussionPeerId = cachedChannelData.linkedDiscussionPeerId, let peer = view.peers[linkedDiscussionPeerId] {
                    actionBlock.append(.linkedChannel(section: GroupInfoSection.type.rawValue, channel: peer, subscribers: cachedChannelData.participantsSummary.memberCount, viewType: .singleItem))
                } else if channel.hasPermission(.banMembers) {
                    if !access.isPublic {
                        actionBlock.append(.preHistory(section: GroupInfoSection.type.rawValue, enabled: cachedChannelData.flags.contains(.preHistoryEnabled), viewType: .singleItem))
                    }
                }
                
                if cachedChannelData.flags.contains(.canSetStickerSet) && access.canEditGroupInfo {
                    actionBlock.append(.groupStickerset(section: GroupInfoSection.type.rawValue, packName: cachedChannelData.stickerPack?.title ?? "", viewType: .singleItem))
                }
                
                applyBlock(actionBlock)
                
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
                    

                    entries.append(GroupInfoEntry.permissions(section: GroupInfoSection.admin.rawValue, count: activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? "", viewType: .firstItem))
                    entries.append(GroupInfoEntry.administrators(section: GroupInfoSection.admin.rawValue, count: cachedChannelData.participantsSummary.adminCount.flatMap { "\($0)" } ?? "", viewType: .lastItem))
                    
                }
            }

        } else {
            
            applyBlock(infoBlock)
            
            
            
            var aboutBlock:[GroupInfoEntry] = []
            
            if group.isScam {
                aboutBlock.append(GroupInfoEntry.scam(section: GroupInfoSection.desc.rawValue, text: L10n.groupInfoScamWarning, viewType: .singleItem))
            }
            
            if let cachedChannelData = view.cachedData as? CachedChannelData {
                if let about = cachedChannelData.about, !about.isEmpty, !group.isScam {
                    aboutBlock.append(GroupInfoEntry.about(section: GroupInfoSection.desc.rawValue, text: about, viewType: .singleItem))
                }
            }
            
            if let cachedGroupData = view.cachedData as? CachedGroupData {
                if let about = cachedGroupData.about, !about.isEmpty, !group.isScam {
                    aboutBlock.append(GroupInfoEntry.about(section: GroupInfoSection.desc.rawValue, text: about, viewType: .singleItem))
                }
            }
            
            if let addressName = group.addressName {
                aboutBlock.append(GroupInfoEntry.addressName(section: GroupInfoSection.desc.rawValue, name: addressName, viewType: .singleItem))
            }
            
            applyBlock(aboutBlock)
            
            
            entries.append(GroupInfoEntry.notifications(section: GroupInfoSection.addition.rawValue, settings: view.notificationSettings, viewType: .firstItem))
            entries.append(GroupInfoEntry.sharedMedia(section: GroupInfoSection.addition.rawValue, viewType: .lastItem))
            

        }
        
        
        
        if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
            
            entries.append(GroupInfoEntry.usersHeader(section: GroupInfoSection.members.rawValue, count: participants.participants.count, viewType: .textTopItem))
            
            var usersBlock:[GroupInfoEntry] = []
            
            if access.canAddMembers {
                usersBlock.append(.addMember(section: GroupInfoSection.members.rawValue, inviteViaLink: access.canCreateInviteLink, viewType: .singleItem))
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
                        case .admin:
                            memberStatus = .admin(rank: L10n.chatAdminBadge)
                        case  .creator:
                            memberStatus = .admin(rank: L10n.chatOwnerBadge)
                        case .member:
                            memberStatus = .member
                        }
                    } else {
                        memberStatus = .member
                    }
                    
                    let editing:ShortPeerDeleting?
                    
                    if state.editingState != nil, let group = group as? TelegramGroup {
                        let deletable:Bool = group.canRemoveParticipant(sortedParticipants[i]) || (sortedParticipants[i].invitedBy == arguments.context.peerId && sortedParticipants[i].peerId != arguments.context.peerId)
                        editing = ShortPeerDeleting(editable: deletable)
                    } else {
                        editing = nil
                    }
                    
                    usersBlock.append(.member(section: GroupInfoSection.members.rawValue, index: i, peerId: peer.id, peer: peer, presence: view.peerPresences[peer.id], activity: inputActivities[peer.id], memberStatus: memberStatus, editing: editing, enabled: !disabledPeerIds.contains(peer.id), viewType: .singleItem))
                }
            }
            
           
            applyBlock(usersBlock)
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
                        updatedParticipants.append(RenderedChannelParticipant(participant: .member(id: participant.peer.id, invitedAt: participant.timestamp, adminInfo: nil, banInfo: nil, rank: nil), peer: participant.peer))
                        if let presence = participant.presence, peerPresences[participant.peer.id] == nil {
                            peerPresences[participant.peer.id] = presence
                        }
                        if participant.peer.id == arguments.context.account.peerId {
                            peerPresences[participant.peer.id] = TelegramUserPresence(status: .present(until: Int32.max), lastActivity: Int32.max)
                        }
                        if peers[participant.peer.id] == nil {
                            peers[participant.peer.id] = participant.peer
                        }
                        disabledPeerIds.insert(participant.peer.id)
                    }
                }
            }
            
            if let membersCount = cachedGroupData.participantsSummary.memberCount {
                entries.append(GroupInfoEntry.usersHeader(section: GroupInfoSection.members.rawValue, count: Int(membersCount), viewType: .textTopItem))
            }
            
            var usersBlock:[GroupInfoEntry] = []
            
            if access.canAddMembers  {
                usersBlock.append(.addMember(section: GroupInfoSection.members.rawValue, inviteViaLink: access.canCreateInviteLink, viewType: .singleItem))
            }
            
            
            
            var sortedParticipants = participants.filter({!$0.peer.rawDisplayTitle.isEmpty}).sorted(by: { lhs, rhs in
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
            
            if let hasShowMoreButton = state.hasShowMoreButton, hasShowMoreButton, let memberCount = cachedGroupData.participantsSummary.memberCount, memberCount > 100 {
                sortedParticipants = Array(sortedParticipants.prefix(min(50, sortedParticipants.count)))
            }
            
            for i in 0 ..< sortedParticipants.count {
                let memberStatus: GroupInfoMemberStatus
                if access.highlightAdmins {
                    switch sortedParticipants[i].participant {
                    case let .creator(_, rank):
                        memberStatus = .admin(rank: rank ?? L10n.chatOwnerBadge)
                    case let .member(_, _, adminRights, _, rank):
                        memberStatus = adminRights != nil ? .admin(rank: rank ?? L10n.chatAdminBadge) : .member
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
                
                usersBlock.append(GroupInfoEntry.member(section: GroupInfoSection.members.rawValue, index: i, peerId: sortedParticipants[i].peer.id, peer: sortedParticipants[i].peer, presence: sortedParticipants[i].presences[sortedParticipants[i].peer.id], activity: inputActivities[sortedParticipants[i].peer.id], memberStatus: memberStatus, editing: editing, enabled: !disabledPeerIds.contains(sortedParticipants[i].peer.id), viewType: .singleItem))
            }
            
            if let hasShowMoreButton = state.hasShowMoreButton, hasShowMoreButton, let memberCount = cachedGroupData.participantsSummary.memberCount, memberCount > 100 {
                usersBlock.append(.showMore(section: GroupInfoSection.members.rawValue, index: sortedParticipants.count + 1, viewType: .singleItem))
            }
            applyBlock(usersBlock)
        }
        
        
        var destructBlock:[GroupInfoEntry] = []
        
        if let group = peerViewMainPeer(view) as? TelegramGroup {
            if case .Member = group.membership {
                destructBlock.append(GroupInfoEntry.leave(section: GroupInfoSection.destruct.rawValue, text: L10n.peerInfoDeleteAndExit, viewType: .singleItem))
            }
        } else if let channel = peerViewMainPeer(view) as? TelegramChannel {
            if case .member = channel.participationStatus {
                if state.editingState != nil, access.isCreator {
                    destructBlock.append(GroupInfoEntry.leave(section: GroupInfoSection.destruct.rawValue, text: L10n.peerInfoDeleteGroup, viewType: .singleItem))
                } else {
                    destructBlock.append(GroupInfoEntry.leave(section: GroupInfoSection.destruct.rawValue, text: L10n.peerInfoLeaveGroup, viewType: .singleItem))
                }
            }
        }
        
        applyBlock(destructBlock)
        
        var items:[GroupInfoEntry] = []
        var sectionId:Int = 0
        for entry in entries {
            if entry.sectionId != sectionId {
                items.append(.section(sectionId))
                sectionId = entry.sectionId
            }
            items.append(entry)
        }
        sectionId += 1
        items.append(.section(sectionId))
        
        entries = items
        
    }
    
    
    return entries.sorted(by: { p1, p2 -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
