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
        if let editingState = state.editingState {
            if let title = editingState.editingName, title != peer.title {
                return (title, nil)
            }
        }
        return (nil, nil)
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
    
    static func ==(lhs: GroupInfoEditingState, rhs: GroupInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}

final class GroupInfoArguments : PeerInfoArguments {
    
    private let addMemberDisposable = MetaDisposable()
    private let removeMemberDisposable = MetaDisposable()
    private let updatePeerNameDisposable = MetaDisposable()
    private let updatePhotoDisposable = MetaDisposable()
    func updateState(_ f: (GroupInfoState) -> GroupInfoState) -> Void {
        updateInfoState { state -> PeerInfoState in
            return f(state as! GroupInfoState)
        }
    }
    
    override func updateEditable(_ editable:Bool, peerView:PeerView) {
        
        let account = self.account
        let peerId = self.peerId
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        if editable {
            if let peer = peerViewMainPeer(peerView) {
                if peer.isGroup {
                    updateState { state -> GroupInfoState in
                        return state.withUpdatedEditingState(GroupInfoEditingState(editingName: peer.displayTitle))
                    }
                } else if peer.isSupergroup, let cachedData = peerView.cachedData as? CachedChannelData {
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
            
            let updateTitle: Signal<Void, Void>
            if let titleValue = updateValues.title {
                updateTitle = updatePeerTitle(account: account, peerId: peerId, title: titleValue)
                    |> mapError { _ in return Void() }
            } else {
                updateTitle = .complete()
            }
            
            let updateDescription: Signal<Void, Void>
            if let descriptionValue = updateValues.description {
                updateDescription = updatePeerDescription(account: account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                    |> mapError { _ in return Void() }
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
        let setup = ChannelVisibilityController(account: account, peerId: peerId)
        _ = (setup.onComplete.get() |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.pullNavigation()?.back()
        })
        pushViewController(setup)
    }
    
    func preHistorySetup() {
        let setup = PreHistorySettingsController(account, peerId: peerId)
        _ = (setup.onComplete.get() |> deliverOnMainQueue).start(next: { [weak self] enabled in
            if let strongSelf = self {
                _ = showModalProgress(signal: updateChannelHistoryAvailabilitySettingsInteractively(postbox: strongSelf.account.postbox, network: strongSelf.account.network, peerId: strongSelf.peerId, historyAvailableForNewMembers: enabled), for: mainWindow).start()

            }
        })
        pushViewController(setup)
    }
    
    func blacklist() {
        pushViewController(ChannelBlacklistViewController(account: account, peerId: peerId))
    }
    
    func convert() {
        pushViewController(ConvertGroupViewController(account: account, peerId: peerId))
    }
    
    func admins() {
        pushViewController(ChannelAdminsViewController(account: account, peerId: peerId))
    }
    
    func invation() {
        pushViewController(LinkInvationController(account: account, peerId: peerId))
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
        
        let account = self.account
        let peerId = self.peerId
        
        
        
//        let updateSignal = filethumb(with: URL(fileURLWithPath: path), account: account, scale: System.backingScale) |> mapToSignal { res -> Signal<String, Void> in
//            guard let image = NSImage(contentsOf: URL(fileURLWithPath: path)) else {
//                return .complete()
//            }
//            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: image.size, boundingSize: NSMakeSize(640, 640), intrinsicInsets: NSEdgeInsets())
//            if let image = res(arguments)?.generateImage() {
//                return putToTemp(image: NSImage(cgImage: image, size: image.backingSize))
//            }
//            return .complete()
//        } |> map { path -> TelegramMediaResource in
//                return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
//            }
        
        let updateSignal = Signal<String, Void>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
        } |> beforeNext { resource in
                
                updateState { (state) -> GroupInfoState in
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
                    }
                }
                
            } |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                return  updatePeerPhoto(account: account, peerId: peerId, resource: resource)
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
    
    func addMember() -> Void {
        let account = self.account
        let peerId = self.peerId
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        let confirmationImpl:([PeerId])->Signal<Bool,Void> = { peerIds in
            if let first = peerIds.first, peerIds.count == 1 {
                return account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                    return confirmSignal(for: mainWindow, header: appName, information: tr(.peerInfoConfirmAddMember(peer.displayTitle)))
                }
            }
            return confirmSignal(for: mainWindow, header: appName, information: tr(.peerInfoConfirmAddMembers(peerIds.count)))
        }
        
        let addMember = account.viewTracker.peerView( peerId) |> take(1) |> deliverOnMainQueue |> mapToSignal{ view -> Signal<Void, Void> in
            
            var excludePeerIds:[PeerId] = []
            if let cachedData = view.cachedData as? CachedChannelData {
                excludePeerIds = Array(cachedData.peerIds)
            } else if let cachedData = view.cachedData as? CachedGroupData {
                excludePeerIds = Array(cachedData.peerIds)
            }
            
            return selectModalPeers(account: account, title: tr(.peerInfoAddMember), settings: [.contacts, .remote], excludePeerIds:excludePeerIds, limit: peerId.namespace == Namespaces.Peer.CloudGroup ? 1 : 100, confirmation: confirmationImpl)
                |> deliverOnMainQueue
                |> mapToSignal { memberIds -> Signal<Void, NoError> in
                    return account.postbox.multiplePeersView(memberIds + [peerId])
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
                                    return addPeerMember(account: account, peerId: peerId, memberId: memberId)
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
                                    return addChannelMembers(account: account, peerId: peerId, memberIds: memberIds)
                                }
                            }
                            
                            return .complete()
                    }
            }
        }
        
        addMemberDisposable.set(addMember.start())
        
    }
    func removePeer(_ memberId:PeerId) -> Void {
        
        let account = self.account
        let peerId = self.peerId
        let updateState:((GroupInfoState)->GroupInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let signal = account.postbox.loadedPeerWithId(memberId)
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Bool, NoError> in
                return confirmSignal(for: mainWindow, header: appName, information: tr(.peerInfoConfirmRemovePeer(peer.displayTitle)))
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
                    
                    return (peerId.namespace == Namespaces.Peer.CloudChannel ? updateChannelMemberBannedRights(account: account, peerId: peerId, memberId: memberId, rights: TelegramChannelBannedRights(flags: [.banReadMessages], untilDate: 0)) : removePeerMember(account: account, peerId: peerId, memberId: memberId))
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
    
    func setGroupAdmins() {
        pullNavigation()?.push(GroupAdminsController(account: account, peerId: peerId))
    }
    
    func setGroupStickerset() {
        pullNavigation()?.push(GroupStickerSetController(account: account, peerId: peerId))
        
    }
    
    func eventLog() {
        pullNavigation()?.push(ChannelEventLogController(account, peerId: peerId))
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
    
    static func ==(lhs: GroupInfoState, rhs: GroupInfoState) -> Bool {
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        if lhs.temporaryParticipants != rhs.temporaryParticipants {
            return false
        }
        if lhs.successfullyAddedParticipantIds != rhs.successfullyAddedParticipantIds {
            return false
        }
        if lhs.removingParticipantIds != rhs.removingParticipantIds {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        
        if lhs.updatingPhotoState != rhs.updatingPhotoState {
            return false
        }
        
        return true
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
    case info(section:Int, view: PeerView, editable:Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?)
    case setGroupPhoto(section:Int)
    case about(section:Int, text: String)
    case addressName(section:Int, name:String)
    case sharedMedia(section:Int)
    case notifications(section:Int, settings: PeerNotificationSettings?)
    case usersHeader(section:Int, count:Int)
    case addMember(section:Int)
    case inviteLink(section:Int)
    case convertToSuperGroup(section:Int)
    case groupTypeSetup(section:Int, isPublic: Bool)
    case groupDescriptionSetup(section:Int, text: String)
    case groupAboutDescription(section:Int)
    case groupStickerset(section:Int, packName: String)
    case preHistory(section:Int, enabled: Bool)
    case groupManagementInfoLabel(section:Int, text: String)
    case setAdmins(section:Int)
    case membersAdmins(section:Int, count: Int)
    case membersBlacklist(section:Int, count: Int)
    
    case member(section:Int, index: Int, peerId: PeerId, peer: Peer?, presence: PeerPresence?, memberStatus: GroupInfoMemberStatus, editing: ShortPeerDeleting?, enabled:Bool)
    case leave(section:Int)
    case section(Int)
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? GroupInfoEntry else {
            return false
        }
        
        switch self {
        case let .info(_, lhsPeerView, lhsEditable, lhsUpdatingPhotoState):
            switch entry {
            case let .info(_, rhsPeerView, rhsEditable, rhsUpdatingPhotoState):
                
                if lhsEditable != rhsEditable {
                    return false
                }
                if lhsUpdatingPhotoState != rhsUpdatingPhotoState {
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
        case .setAdmins:
            if case .setAdmins = entry {
                return true
            } else {
                return false
            }

        case .inviteLink:
            if case .inviteLink = entry {
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
        case .convertToSuperGroup:
            if case .convertToSuperGroup = entry {
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
        case let .membersAdmins(_, count):
            if case .membersAdmins(_, count) = entry {
                return true
            } else {
                return false
            }
        case let .membersBlacklist(_, count):
            if case .membersBlacklist(_, count) = entry {
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
        case let .member(_, lhsIndex, lhsPeerId, lhsPeer, lhsPresence, lhsMemberStatus, lhsEditing, lhsEnabled):
            if case let .member(_, rhsIndex, rhsPeerId, rhsPeer, rhsPresence, rhsMemberStatus, rhsEditing, rhsEnabled) = entry {
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
        case .leave:
            if case .leave = entry {
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
        case let .member(_, _, peerId, _, _, _, _, _):
            return GroupPeerEntryStableId(peerId: peerId)
        default:
            return IntPeerInfoEntryStableId(value: stableIndex)
        }
    }
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .about:
            return 1
        case .addressName:
            return 2
        case .setGroupPhoto:
            return 3
        case .inviteLink:
            return 4
        case .notifications:
            return 5
        case .sharedMedia:
            return 6
        case .groupTypeSetup:
            return 7
        case .preHistory:
            return 8
        case .setAdmins:
            return 9
        case .groupDescriptionSetup:
            return 10
        case .groupAboutDescription:
            return 11
        case .groupStickerset:
            return 12
        case .groupManagementInfoLabel:
            return 13
        case .membersAdmins:
            return 14
        case .membersBlacklist:
            return 15
        case .usersHeader:
            return 16
        case .addMember:
            return 17
        case .member:
            fatalError("no stableIndex")
        case .convertToSuperGroup:
            return 18
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
        case let .about(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .addressName(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .setGroupPhoto(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .inviteLink(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .addMember(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .notifications(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .sharedMedia(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .groupTypeSetup(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .preHistory(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .groupStickerset(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .setAdmins(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .groupDescriptionSetup(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .groupAboutDescription(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .groupManagementInfoLabel(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .membersAdmins(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .membersBlacklist(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .usersHeader(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .member(sectionId, index, _, _, _, _, _, _):
            return (sectionId * 1000) + index + 200
        case let .leave(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .convertToSuperGroup(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let other = entry as? GroupInfoEntry else {
            return false
        }
        
        return self.sortIndex > other.sortIndex
    }
    
    func item(initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem {
        let arguments = arguments as! GroupInfoArguments
        let state = arguments.state as! GroupInfoState
        
        switch self {
        case let .info(_, peerView, editable, updatingPhotoState):
            return PeerInfoHeaderItem(initialSize, stableId:stableId.hashValue, account: arguments.account, peerView:peerView, editable: editable, updatingPhotoState: updatingPhotoState, firstNameEditableText: state.editingState?.editingName, textChangeHandler: { name, _ in
                arguments.updateEditingName(name)
            })
        case let .about(_, text):
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:tr(.peerInfoInfo), text:text, account: arguments.account, detectLinks:true, openInfo: { peerId, toChat, _, _ in
                if toChat {
                    arguments.peerChat(peerId)
                } else {
                    arguments.peerInfo(peerId)
                }
            })
        case let .addressName(_, value):
            let link = "https://t.me/\(value)"
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:tr(.peerInfoSharelink), text: link, account: arguments.account, isTextSelectable:false, callback:{
                showModal(with: ShareModalController(ShareLinkObject(arguments.account, link: link)), for: mainWindow)
            })
        case .setGroupPhoto:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoSetGroupPhoto), nameStyle: blueActionButton, type: .none, action: {
                
                pickImage(for: mainWindow, completion: { image in
                    if let image = image {
                        _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { path in
                            arguments.updatePhoto(path)
                        })
                    }
                })
                
            })
        case let .notifications(_, settings):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoNotifications), type: .switchable(stateback: { () -> Bool in
                
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    return false
                } else {
                    return true
                }
                
            }), action: {
               arguments.toggleNotifications()
            })

        case .sharedMedia:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoSharedMedia), type: .none, action: { () in
                arguments.sharedMedia()
            })
        case let .groupDescriptionSetup(section: _, text: text):
            return GeneralInputRowItem(initialSize, stableId: stableId.hashValue, placeholder: tr(.peerInfoAboutPlaceholder), text: text, limit: 255, insets: NSEdgeInsets(left:25,right:25,top:8,bottom:3), textChangeHandler: { updatedText in
                arguments.updateEditingDescriptionText(updatedText)
            })
        case let .preHistory(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoPreHistory), type: .context(stateback: { () -> String in
                return enabled ? tr(.peerInfoPreHistoryVisible) : tr(.peerInfoPreHistoryHidden)
            }), action: { () in
                arguments.preHistorySetup()
            })
        case .groupAboutDescription:
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: tr(.peerInfoSetAboutDescription))

        case let .groupTypeSetup(section: _, isPublic: isPublic):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoGroupType), type: .context(stateback: { () -> String in
                return isPublic ? tr(.peerInfoGroupTypePublic) : tr(.peerInfoGroupTypePrivate)
            }), action: { () in
                arguments.visibilitySetup()
            })
        case .setAdmins:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoSetAdmins), type: .none, action: { () in
                arguments.setGroupAdmins()
            })
        case .groupStickerset(_, let name):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoSetGroupStickersSet), type: .context(stateback: {
                return name
            }), action: { () in
                arguments.setGroupStickerset()
            })
        case let .membersBlacklist(section: _, count: count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoBlackList), type: .context(stateback: { () -> String in
                return "\(count)"
            }), action: { () in
                arguments.blacklist()
            })
        case let .membersAdmins(section: _, count: count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoAdmins), type: .context(stateback: { () -> String in
                return "\(count)"
            }), action: { () in
                arguments.admins()
            })
        case let .usersHeader(section: _, count: count):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: tr(.peerInfoMembersHeaderCountable(count)))
        case .addMember:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoAddMember), nameStyle: blueActionButton, type: .none, action: { () in
            
                arguments.addMember()
                
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 36), inset:NSEdgeInsets(left: 40, right: 30))
        case .inviteLink:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoInviteLink), nameStyle: blueActionButton, type: .none, action: { () in
                arguments.invation()
            })
            
        case let .member(_, _, _, peer, presence, memberStatus, editing, enabled):
            let label: String
            switch memberStatus {
            case .admin:
                label = tr(.peerInfoAdminLabel)
            case .member:
                label = ""
            }
                        
            var string:String = tr(.peerStatusRecently)
            var color:NSColor = theme.colors.grayText
            
            if let presence = presence as? TelegramUserPresence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string, _, color) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
            } else if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
                string = botInfo.flags.contains(.hasAccessToChatHistory) ? tr(.peerInfoBotStatusHasAccess) : tr(.peerInfoBotStatusHasNoAccess)
            }
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { memberId in
                    arguments.removePeer(memberId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: peer!, account: arguments.account, stableId: stableId.hashValue, enabled: enabled, height: 46, photoSize: NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(.custom(12.5)), foregroundColor: theme.colors.text), statusStyle: ControlStyle(font: NSFont.normal(.custom(12.5)), foregroundColor:color), status: string, inset:NSEdgeInsets(left:30.0,right:30.0), interactionType: interactionType, generalType:.context( stateback: {
                return label
            }), action:{
                arguments.peerInfo(peer!.id)
            })

        case .leave:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoDeleteAndExit), nameStyle: redActionButton, type: .none, action: {
                arguments.delete()
            })
        case .convertToSuperGroup:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoConvertToSupergroup), nameStyle: blueActionButton, type: .none, action: { () in
                arguments.convert()
            })
        case .section(_):
            return GeneralRowItem(initialSize, height:20, stableId: stableId.hashValue)
        default:
            preconditionFailure()
        }
    }
}




func groupInfoEntries(view: PeerView, arguments: PeerInfoArguments) -> [PeerInfoEntry] {
    var entries: [PeerInfoEntry] = []
    if let group = peerViewMainPeer(view), let arguments = arguments as? GroupInfoArguments, let state = arguments.state as? GroupInfoState {
        
        var sectionId:Int = 0
            let access = group.groupAccess
        var canInviteByLink = access.isCreator
        
        var canEditInfo = state.editingState != nil
        if let group = group as? TelegramChannel {
            canEditInfo = state.editingState != nil && group.hasAdminRights(.canChangeInfo)
            canInviteByLink = group.hasAdminRights(.canChangeInviteLink)
        }
        
        entries.append(GroupInfoEntry.info(section: sectionId, view: view, editable: canEditInfo, updatingPhotoState: state.updatingPhotoState))
        

        
        
        if let editingState = state.editingState {
            if canEditInfo {
                entries.append(GroupInfoEntry.setGroupPhoto(section: sectionId))
            }
            if canInviteByLink {
                entries.append(GroupInfoEntry.inviteLink(section: sectionId))
            }
            
            entries.append(GroupInfoEntry.section(sectionId))
            sectionId += 1
            
            if let cachedChannelData = view.cachedData as? CachedChannelData {
                
                if access.isCreator {
                    entries.append(GroupInfoEntry.groupTypeSetup(section: sectionId, isPublic: group.addressName != nil))
                    if group.addressName == nil {
                        entries.append(GroupInfoEntry.preHistory(section: sectionId, enabled: cachedChannelData.flags.contains(.preHistoryEnabled)))
                    }
                }
                
                if canEditInfo {
                    entries.append(GroupInfoEntry.groupDescriptionSetup(section: sectionId, text: editingState.editingDescriptionText))
                    entries.append(GroupInfoEntry.groupAboutDescription(section: sectionId))
                    
                    entries.append(GroupInfoEntry.section(sectionId))
                    sectionId += 1
                    
                    if cachedChannelData.flags.contains(.canSetStickerSet) {
                        entries.append(GroupInfoEntry.groupStickerset(section: sectionId, packName: cachedChannelData.stickerPack?.title ?? ""))
                        
                        entries.append(GroupInfoEntry.section(sectionId))
                        sectionId += 1
                    }
                    
                    
                }
                
                
                if access.canManageGroup {
                    let adminCount = cachedChannelData.participantsSummary.adminCount ?? 0
                    entries.append(GroupInfoEntry.membersAdmins(section: sectionId, count: Int(adminCount)))
                    let bannedCount = (cachedChannelData.participantsSummary.bannedCount ?? 0) + (cachedChannelData.participantsSummary.kickedCount ?? 0)
                    entries.append(GroupInfoEntry.membersBlacklist(section: sectionId, count: Int(bannedCount)))
                    
                }
                
            } else if group.isGroup {
                if access.isCreator {
                    entries.append(GroupInfoEntry.setAdmins(section: sectionId))
                }
            }
        } else {
            
            if let cachedChannelData = view.cachedData as? CachedChannelData {
                if let about = cachedChannelData.about, !about.isEmpty {
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
            
            entries.append(GroupInfoEntry.sharedMedia(section: sectionId))
        }

        entries.append(GroupInfoEntry.notifications(section: sectionId, settings: view.notificationSettings))

        
        if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
            
            entries.append(GroupInfoEntry.section(sectionId))
            sectionId = 10
            
            entries.append(GroupInfoEntry.usersHeader(section: sectionId, count: participants.participants.count))
            
            if access.canManageMembers {
                entries.append(GroupInfoEntry.addMember(section: sectionId))
            }
            
            
            var updatedParticipants = participants.participants
            let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
            var peerPresences: [PeerId: PeerPresence] = view.peerPresences
            var peers: [PeerId: Peer] = view.peers
            var disabledPeerIds = state.removingParticipantIds
            
            if !state.temporaryParticipants.isEmpty {
                for participant in state.temporaryParticipants {
                    if !existingParticipantIds.contains(participant.peer.id) {
                        updatedParticipants.append(.member(id: participant.peer.id, invitedBy: arguments.account.peerId, invitedAt: participant.timestamp))
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
            
            let sortedParticipants = participants.participants.sorted(by: { lhs, rhs in
                let lhsPresence = view.peerPresences[lhs.peerId] as? TelegramUserPresence
                let rhsPresence = view.peerPresences[rhs.peerId] as? TelegramUserPresence
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
                    
                    entries.append(GroupInfoEntry.member(section: sectionId, index: i, peerId: peer.id, peer: peer, presence: view.peerPresences[peer.id], memberStatus: memberStatus, editing: editing, enabled: !disabledPeerIds.contains(peer.id)))
                }
            }
        }
        
        if let cachedGroupData = view.cachedData as? CachedChannelData, let participants = cachedGroupData.topParticipants, let channel = group as? TelegramChannel {
            
            var updatedParticipants = participants.participants
            let existingParticipantIds = Set(updatedParticipants.map { $0.peerId })
            var peerPresences: [PeerId: PeerPresence] = view.peerPresences
            var peers: [PeerId: Peer] = view.peers
            var disabledPeerIds = state.removingParticipantIds
            
            if !state.temporaryParticipants.isEmpty {
                for participant in state.temporaryParticipants {
                    if !existingParticipantIds.contains(participant.peer.id) {
                        //member(id: participant.peer.id, invitedAt: participant.timestamp)
                        updatedParticipants.append(.member(id: participant.peer.id, invitedAt: participant.timestamp, adminInfo: nil, banInfo: nil))
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
            
            if channel.hasAdminRights(.canInviteUsers) {
                entries.append(GroupInfoEntry.addMember(section: sectionId))
            }
            
            let sortedParticipants = participants.participants.sorted(by: { lhs, rhs in
                let lhsPresence = view.peerPresences[lhs.peerId] as? TelegramUserPresence
                let rhsPresence = view.peerPresences[rhs.peerId] as? TelegramUserPresence
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
                        let deletable:Bool = group.canRemoveParticipant(sortedParticipants[i], accountId: arguments.account.peerId)
                        editing = ShortPeerDeleting(editable: deletable)
                    } else {
                        editing = nil
                    }
                    
                    entries.append(GroupInfoEntry.member(section: sectionId, index: i, peerId: peer.id, peer: peer, presence: view.peerPresences[peer.id], memberStatus: memberStatus, editing: editing, enabled: !disabledPeerIds.contains(peer.id)))
                }
            }
        }
        
        entries.append(GroupInfoEntry.section(sectionId))
        sectionId += 1
        
        if let group = peerViewMainPeer(view) as? TelegramGroup {
            if case .Member = group.membership {
                if state.editingState != nil && access.isCreator {
                    entries.append(GroupInfoEntry.convertToSuperGroup(section: sectionId))
                }
                entries.append(GroupInfoEntry.leave(section: sectionId))
            }
        } else if let channel = peerViewMainPeer(view) as? TelegramChannel {
            if case .member = channel.participationStatus {
                entries.append(GroupInfoEntry.leave(section: sectionId))
            }
        }

    }
    
    
    return entries.sorted(by: { p1, p2 -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
