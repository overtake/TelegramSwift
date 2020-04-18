//
//  UserInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit


struct UserInfoEditingState: Equatable {
    let editingFirstName: String?
    let editingLastName: String?
    
    init(editingFirstName:String? = nil, editingLastName:String? = nil ) {
        self.editingFirstName = editingFirstName
        self.editingLastName = editingLastName
    }
    
    func withUpdatedEditingFirstNameText(_ editingFirstName: String?) -> UserInfoEditingState {
        return UserInfoEditingState(editingFirstName: editingFirstName, editingLastName: self.editingLastName)
    }
    func withUpdatedEditingLastNameText(_ editingLastName: String?) -> UserInfoEditingState {
        return UserInfoEditingState(editingFirstName: self.editingFirstName, editingLastName: editingLastName)
    }
    
    static func ==(lhs: UserInfoEditingState, rhs: UserInfoEditingState) -> Bool {
        if lhs.editingFirstName != rhs.editingFirstName {
            return false
        }
        if lhs.editingLastName != rhs.editingLastName {
            return false
        }
        return true
    }
}



final class UserInfoState : PeerInfoState {
    let editingState: UserInfoEditingState?
    let savingData: Bool
    
    init(editingState: UserInfoEditingState?, savingData: Bool) {
        self.editingState = editingState
        self.savingData = savingData
        
        
    }
    
    override init() {
        self.editingState = nil
        self.savingData = false
    }
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? UserInfoState {
            return self == to
        }
        return false
    }
    
    static func ==(lhs: UserInfoState, rhs: UserInfoState) -> Bool {
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        
        return true
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: savingData)
    }
    
    func withUpdatedEditingState(_ editingState: UserInfoEditingState?) -> UserInfoState {
        return UserInfoState(editingState: editingState, savingData: self.savingData)
    }
    
}

class UserInfoArguments : PeerInfoArguments {
    
    
    private let shareDisposable = MetaDisposable()
    private let blockDisposable = MetaDisposable()
    private let startSecretChatDisposable = MetaDisposable()
    private let updatePeerNameDisposable = MetaDisposable()
    private let deletePeerContactDisposable = MetaDisposable()
    private let callDisposable = MetaDisposable()
    
    func shareContact() {
        let context = self.context
        let peer = context.account.postbox.peerView(id: peerId) |> take(1) |> map {
            return peerViewMainPeer($0)
        } |> deliverOnMainQueue
        

        
        shareDisposable.set(peer.start(next: { [weak self] peer in
            if let context = self?.context, let peer = peer as? TelegramUser {
                showModal(with: ShareModalController(ShareContactObject(context, user: peer)), for: context.window)
            }
        }))
    }
    
    override init(context: AccountContext, peerId: PeerId, state: PeerInfoState, isAd: Bool, pushViewController: @escaping (ViewController) -> Void, pullNavigation: @escaping () -> NavigationViewController?, mediaController: @escaping()->PeerMediaController?) {
        super.init(context: context, peerId: peerId, state: state, isAd: isAd, pushViewController: pushViewController, pullNavigation: pullNavigation, mediaController: mediaController)
        
        let updateState:((UserInfoState)->UserInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
    }
    
    func shareMyInfo() {
        
        
        let context = self.context
        let peerId = self.peerId
        
        
        let peer = context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        } |> deliverOnMainQueue
        
        _ = peer.start(next: { [weak self] peer in
            if let peer = peer {
                confirm(for: mainWindow, information: L10n.peerInfoConfirmShareInfo(peer.displayTitle), successHandler: { [weak self] _ in
                    let signal: Signal<Void, NoError> = context.account.postbox.loadedPeerWithId(context.peerId) |> map { $0 as! TelegramUser } |> mapToSignal { peer in
                        let signal = Sender.enqueue(message: EnqueueMessage.message(text: "", attributes: [], mediaReference: AnyMediaReference.standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil)), replyToMessageId: nil, localGroupingKey: nil), context: context, peerId: peerId)
                        return signal  |> map { _ in}
                    }
                    self?.shareDisposable.set(showModalProgress(signal: signal, for: mainWindow).start())
                })
            }
        })
        
        
    }
    
    func addContact() {
        let context = self.context
        let peerView = context.account.postbox.peerView(id: self.peerId) |> take(1) |> deliverOnMainQueue
        _ = peerView.start(next: { peerView in
            if let peer = peerViewMainPeer(peerView) {
                showModal(with: NewContactController(context: context, peerId: peer.id), for: context.window)
            }
        })
    }
    
    override func updateEditable(_ editable:Bool, peerView:PeerView, controller: PeerInfoController) -> Bool {
        
        let context = self.context
        let peerId = self.peerId
        let updateState:((UserInfoState)->UserInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        if editable {
            if let peer = peerViewMainPeer(peerView) as? TelegramUser {
                updateState { state -> UserInfoState in
                    return state.withUpdatedEditingState(UserInfoEditingState(editingFirstName: peer.firstName, editingLastName: peer.lastName))
                }
            }
        } else {
            var updateValues: (firstName: String?, lastName: String?) = (nil, nil)
            updateState { state in
                if let peer = peerViewMainPeer(peerView) as? TelegramUser, peer.firstName != state.editingState?.editingFirstName || peer.lastName != state.editingState?.editingLastName  {
                    updateValues.firstName = state.editingState?.editingFirstName
                    updateValues.lastName = state.editingState?.editingLastName
                    return state.withUpdatedSavingData(true)
                } else {
                    return state.withUpdatedEditingState(nil)
                }
            }
            
            if let firstName = updateValues.firstName, firstName.isEmpty {
                controller.genericView.item(stableId: IntPeerInfoEntryStableId(value: 1).hashValue)?.view?.shakeView()
                return false
            }
            
            
            if updateValues.firstName != nil || updateValues.lastName != nil {
                updateState { state in
                    return state.withUpdatedSavingData(true)
                }
            } else {
                updateState { state in
                    return state.withUpdatedEditingState(nil)
                }
            }
            
            
            
            let updateNames: Signal<Void, NoError>
            
            if let firstName = updateValues.firstName, let lastName = updateValues.lastName {
                updateNames = showModalProgress(signal: updateContactName(account: context.account, peerId: peerId, firstName: firstName, lastName: lastName) |> `catch` {_ in .complete()} |> deliverOnMainQueue, for: mainWindow)
            } else {
                updateNames = .complete()
            }
            
            self.updatePeerNameDisposable.set(updateNames.start(error: { _ in
                updateState { state in
                    return state.withUpdatedSavingData(false)
                }
            }, completed: {
                updateState { state in
                    return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                }
            }))
            
        }
        
        return true
    }
    
    func sendMessage() {
        self.peerChat(self.peerId)
    }
    
    func call() {
        let context = self.context
        let peer = context.account.postbox.peerView(id: peerId) |> take(1) |> map {
            return peerViewMainPeer($0)?.id
        } |> filter { $0 != nil } |> map { $0! }
        
        let call = peer |> mapToSignal {
            phoneCall(account: context.account, sharedContext: context.sharedContext, peerId: $0)
        } |> deliverOnMainQueue
        
        self.callDisposable.set(call.start(next: { result in
            applyUIPCallResult(context.sharedContext, result)
        }))
    }
    
    func botAddToGroup() {
        let context = self.context
        let peerId = self.peerId
        
        let result = selectModalPeers(context: context, title: L10n.selectPeersTitleSelectChat, behavior: SelectChatsBehavior(limit: 1), confirmation: { peerIds -> Signal<Bool, NoError> in
            if let peerId = peerIds.first {
                return context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer -> Signal<Bool, NoError> in
                    return confirmSignal(for: context.window, information: L10n.confirmAddBotToGroup(peer.displayTitle))
                }
            }
            return .single(false)
        }) |> deliverOnMainQueue |> filter {$0.first != nil} |> map {$0.first!} |> mapToSignal { groupId -> Signal<PeerId, NoError> in
            if groupId.namespace == Namespaces.Peer.CloudGroup {
                return showModalProgress(signal: addGroupMember(account: context.account, peerId: groupId, memberId: peerId), for: context.window) |> `catch` {_ in .complete()} |> map {groupId}
            } else {
                return showModalProgress(signal: context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: groupId, memberId: peerId), for: context.window) |> map { groupId }
            }
        }
        
        _ = result.start(next: { [weak self] peerId in
            self?.peerChat(peerId)
        })
    }
    func botShare(_ botName: String) {
        showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/\(botName)")), for: mainWindow)
    }
    func botSettings() {
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/settings"), context: context, peerId: peerId, replyId: nil).start()
        pullNavigation()?.back()
    }
    func botHelp() {
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/help"), context: context, peerId: peerId, replyId: nil).start()
        pullNavigation()?.back()
    }
    
    func botPrivacy() {
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/privacy"), context: context, peerId: peerId, replyId: nil).start()
        pullNavigation()?.back()
    }
    
    func startSecretChat() {
        let context = self.context
        let peerId = self.peerId
        let signal = context.account.postbox.transaction { transaction -> Peer? in
            
            return transaction.getPeer(peerId)
            
        } |> deliverOnMainQueue  |> mapToSignal { peer -> Signal<PeerId, NoError> in
            if let peer = peer {
                let confirm = confirmSignal(for: context.window, header: L10n.peerInfoConfirmSecretChatHeader, information: L10n.peerInfoConfirmStartSecretChat(peer.displayTitle), okTitle: L10n.peerInfoConfirmSecretChatOK)
                return confirm |> filter {$0} |> mapToSignal { (_) -> Signal<PeerId, NoError> in
                    return showModalProgress(signal: createSecretChat(account: context.account, peerId: peer.id) |> `catch` { _ in return .complete()}, for: mainWindow)
                }
            } else {
                return .complete()
            }
        } |> deliverOnMainQueue
        
        
        
        startSecretChatDisposable.set(signal.start(next: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.pushViewController(ChatController(context: strongSelf.context, chatLocation: .peer(peerId)))
            }
        }))
    }
    
    func updateState(_ f: (UserInfoState) -> UserInfoState) -> Void {
        updateInfoState { state -> PeerInfoState in
            return f(state as! UserInfoState)
        }
    }
    
    func updateEditingNames(firstName: String?, lastName:String?) -> Void {
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingFirstNameText(firstName).withUpdatedEditingLastNameText(lastName))
            } else {
                return state
            }
        }
    }
    
    func updateBlocked(peer: Peer,_ blocked:Bool, _ isBot: Bool) {
        let context = self.context
        if blocked {
            let signal = showModalProgress(signal: context.blockedPeersContext.add(peerId: peer.id) |> deliverOnMainQueue, for: context.window)
            blockDisposable.set(signal.start(error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.unknownError)
                }
            }, completed: {
                
            }))
        } else {
            let signal = showModalProgress(signal: context.blockedPeersContext.remove(peerId: peer.id) |> deliverOnMainQueue, for: context.window)
            blockDisposable.set(signal.start(error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.unknownError)
                }
            }, completed: {
                
            }))
        }
        
        if !blocked && isBot {
            pushViewController(ChatController(context: context, chatLocation: .peer(peer.id), initialAction: ChatInitialAction.start(parameter: "", behavior: .automatic)))
        }

    }
    
    func deleteContact() {
        let context = self.context
        let peerId = self.peerId
        deletePeerContactDisposable.set((confirmSignal(for: context.window, information: tr(L10n.peerInfoConfirmDeleteContact))
            |> filter {$0}
            |> mapToSignal { _ in
                showModalProgress(signal: deleteContactPeerInteractively(account: context.account, peerId: peerId) |> deliverOnMainQueue, for: context.window)
            }).start(completed: { [weak self] in
                self?.pullNavigation()?.back()
            }))
    }
    
    func encryptionKey() {
        pushViewController(SecretChatKeyViewController(context, peerId: peerId))
    }
    
    func groupInCommon(_ peerId: PeerId) -> Void {
    }
    
    deinit {
        shareDisposable.dispose()
        blockDisposable.dispose()
        startSecretChatDisposable.dispose()
        updatePeerNameDisposable.dispose()
        deletePeerContactDisposable.dispose()
        callDisposable.dispose()
    }
    
}



enum UserInfoEntry: PeerInfoEntry {
    case info(sectionId:Int, peerView: PeerView, editable:Bool, viewType: GeneralViewType)
    case setFirstName(sectionId:Int, text: String, viewType: GeneralViewType)
    case setLastName(sectionId:Int, text: String, viewType: GeneralViewType)
    case about(sectionId:Int, text: String, viewType: GeneralViewType)
    case bio(sectionId:Int, text: String, viewType: GeneralViewType)
    case scam(sectionId:Int, text: String, viewType: GeneralViewType)
    case phoneNumber(sectionId:Int, index: Int, value: PhoneNumberWithLabel, canCopy: Bool, viewType: GeneralViewType)
    case userName(sectionId:Int, value: String, viewType: GeneralViewType)
    case sendMessage(sectionId:Int, viewType: GeneralViewType)
    case shareContact(sectionId:Int, viewType: GeneralViewType)
    case shareMyInfo(sectionId:Int, viewType: GeneralViewType)
    case addContact(sectionId:Int, viewType: GeneralViewType)
    case botAddToGroup(sectionId: Int, viewType: GeneralViewType)
    case botShare(sectionId: Int, name: String, viewType: GeneralViewType)
    case botHelp(sectionId: Int, viewType: GeneralViewType)
    case botSettings(sectionId: Int, viewType: GeneralViewType)
    case botPrivacy(sectionId: Int, viewType: GeneralViewType)
    case startSecretChat(sectionId:Int, viewType: GeneralViewType)
    case sharedMedia(sectionId:Int, viewType: GeneralViewType)
    case notifications(sectionId:Int, settings: PeerNotificationSettings?, viewType: GeneralViewType)
    case groupInCommon(sectionId:Int, count:Int, peerId: PeerId, viewType: GeneralViewType)
    case block(sectionId:Int, peer: Peer, blocked: Bool, isBot: Bool, viewType: GeneralViewType)
    case deleteChat(sectionId: Int, viewType: GeneralViewType)
    case deleteContact(sectionId: Int, viewType: GeneralViewType)
    case encryptionKey(sectionId: Int, viewType: GeneralViewType)
    case media(sectionId: Int, controller: PeerMediaController, isVisible: Bool, viewType: GeneralViewType)
    case section(sectionId:Int)
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> UserInfoEntry {
        switch self {
        case let .info(sectionId, peerView, editable, _): return .info(sectionId: sectionId, peerView: peerView, editable: editable, viewType: viewType)
        case let .setFirstName(sectionId, text, _): return .setFirstName(sectionId: sectionId, text: text, viewType: viewType)
        case let .setLastName(sectionId, text, _): return .setLastName(sectionId: sectionId, text: text, viewType: viewType)
        case let .about(sectionId, text, _): return .about(sectionId: sectionId, text: text, viewType: viewType)
        case let .bio(sectionId, text, _): return .bio(sectionId: sectionId, text: text, viewType: viewType)
        case let .scam(sectionId, text, _): return .scam(sectionId: sectionId, text: text, viewType: viewType)
        case let .phoneNumber(sectionId, index, value, canCopy, _): return .phoneNumber(sectionId: sectionId, index: index, value: value, canCopy: canCopy, viewType: viewType)
        case let .userName(sectionId, value: String, _): return .userName(sectionId: sectionId, value: String, viewType: viewType)
        case let .sendMessage(sectionId, _): return .sendMessage(sectionId: sectionId, viewType: viewType)
        case let .shareContact(sectionId, _): return .shareContact(sectionId: sectionId, viewType: viewType)
        case let .shareMyInfo(sectionId, _): return .shareMyInfo(sectionId: sectionId, viewType: viewType)
        case let .addContact(sectionId, _): return .addContact(sectionId: sectionId, viewType: viewType)
        case let .botAddToGroup(sectionId, _): return .botAddToGroup(sectionId: sectionId, viewType: viewType)
        case let .botShare(sectionId, name, _): return .botShare(sectionId: sectionId, name: name, viewType: viewType)
        case let .botHelp(sectionId, _): return .botHelp(sectionId: sectionId, viewType: viewType)
        case let .botSettings(sectionId, _): return .botSettings(sectionId: sectionId, viewType: viewType)
        case let .botPrivacy(sectionId, _): return .botPrivacy(sectionId: sectionId, viewType: viewType)
        case let .startSecretChat(sectionId, _): return .startSecretChat(sectionId: sectionId, viewType: viewType)
        case let .sharedMedia(sectionId, _): return .sharedMedia(sectionId: sectionId, viewType: viewType)
        case let .notifications(sectionId, settings, _): return .notifications(sectionId: sectionId, settings: settings, viewType: viewType)
        case let .groupInCommon(sectionId, count, peerId, _): return .groupInCommon(sectionId: sectionId, count: count, peerId: peerId, viewType: viewType)
        case let .block(sectionId, peer, blocked, isBot, _): return .block(sectionId: sectionId, peer: peer, blocked: blocked, isBot: isBot, viewType: viewType)
        case let .deleteChat(sectionId, _): return .deleteChat(sectionId: sectionId, viewType: viewType)
        case let .deleteContact(sectionId, _): return .deleteContact(sectionId: sectionId, viewType: viewType)
        case let .encryptionKey(sectionId, _): return .encryptionKey(sectionId: sectionId, viewType: viewType)
        case let .media(sectionId, controller, isVisible, _): return .media(sectionId: sectionId, controller: controller, isVisible: isVisible, viewType: viewType)
        case .section: return self
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        return IntPeerInfoEntryStableId(value: self.stableIndex)
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? UserInfoEntry else {
            return false
        }
        
        switch self {
        case let .info(lhsSectionId, lhsPeerView, lhsEditable, lhsViewType):
            switch entry {
            case let .info(rhsSectionId, rhsPeerView, rhsEditable, rhsViewType):
                
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if lhsViewType != rhsViewType {
                    return false
                }
                
                if lhsEditable != rhsEditable {
                    return false
                }
                
                let lhsPeer = peerViewMainPeer(lhsPeerView)
                let lhsCachedData = lhsPeerView.cachedData
                let lhsNotificationSettings = lhsPeerView.notificationSettings

                let rhsPeer = peerViewMainPeer(rhsPeerView)
                let rhsCachedData = rhsPeerView.cachedData
                let rhsNotificationSettings = rhsPeerView.notificationSettings
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer == nil) != (rhsPeer != nil) {
                    return false
                }
                
                if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                    if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                        return false
                    }
                } else if (lhsNotificationSettings == nil) != (rhsNotificationSettings == nil) {
                    return false
                }
                
                if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                    if !lhsCachedData.isEqual(to: rhsCachedData) {
                        return false
                    }
                } else if (lhsCachedData == nil) != (rhsCachedData == nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case let .setFirstName(sectionId, text, viewType):
            switch entry {
            case .setFirstName(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .setLastName(sectionId, text, viewType):
            switch entry {
            case .setLastName(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .about(sectionId, text, viewType):
            switch entry {
            case .about(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .bio(sectionId, text, viewType):
            switch entry {
            case .bio(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .scam(sectionId, text, viewType):
            switch entry {
            case .scam(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .phoneNumber(sectionid, index, value, canCopy, viewType):
            switch entry {
            case .phoneNumber(sectionid, index, value, canCopy, viewType):
                return true
            default:
                return false
            }
        case let .userName(sectionId, value, viewType):
            switch entry {
            case .userName(sectionId, value, viewType):
                return true
            default:
                return false
            }
        case let .sendMessage(sectionId, viewType):
            switch entry {
            case .sendMessage(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .botAddToGroup(sectionId, viewType):
            switch entry {
            case .botAddToGroup(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .botShare(sectionId, botName, viewType):
            switch entry {
            case .botShare(sectionId, botName, viewType):
                return true
            default:
                return false
            }
        case let .botHelp(sectionId, viewType):
            switch entry {
            case .botHelp(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .botSettings(sectionId, viewType):
            switch entry {
            case .botSettings(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .botPrivacy(sectionId, viewType):
            if case .botPrivacy(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .shareContact(sectionId, viewType):
            switch entry {
            case .shareContact(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .shareMyInfo(sectionId, viewType):
            switch entry {
            case .shareMyInfo(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .addContact(sectionId, viewType):
            switch entry {
            case .addContact(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .startSecretChat(sectionId, viewType):
            switch entry {
            case .startSecretChat(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .sharedMedia(sectionId, viewType):
            switch entry {
            case .sharedMedia(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .notifications(sectionId, lhsSettings, viewType):
            switch entry {
            case  .notifications(sectionId, let rhsSettings, viewType):
                if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                    return lhsSettings.isEqual(to: rhsSettings)
                } else if (lhsSettings != nil) != (rhsSettings != nil) {
                    return false
                } else {
                    return true
                }
            default:
                return false
            }
        case let .block(sectionId, lhsPeer, isBlocked, isBot, viewType):
            switch entry {
            case .block(sectionId, let rhsPeer, isBlocked, isBot, viewType):
                return lhsPeer.isEqual(rhsPeer)
            default:
                return false
            }
        case let .groupInCommon(sectionId, count, peerId, viewType):
            switch entry {
            case .groupInCommon(sectionId, count, peerId, viewType):
                return true
            default:
                return false
            }
        case let .deleteChat(sectionId, viewType):
            switch entry {
            case .deleteChat(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .deleteContact(sectionId, viewType):
            switch entry {
            case .deleteContact(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .encryptionKey(sectionId, viewType):
            switch entry {
            case .encryptionKey(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .media(sectionId, _, isVisible, viewType):
            switch entry {
            case .media(sectionId, _, isVisible, viewType):
                return true
            default:
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
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .setFirstName:
            return 1
        case .setLastName:
            return 2
        case .scam:
            return 3
        case .about:
            return 4
        case .bio:
            return 5
        case .phoneNumber:
            return 6
        case .userName:
            return 7
        case .sendMessage:
            return 8
        case .botAddToGroup:
            return 9
        case .botShare:
            return 10
        case .botSettings:
            return 11
        case .botHelp:
            return 12
        case .botPrivacy:
            return 13
        case .shareContact:
            return 14
        case .shareMyInfo:
            return 15
        case .addContact:
            return 16
        case .startSecretChat:
            return 17
        case .sharedMedia:
            return 18
        case .notifications:
            return 19
        case .encryptionKey:
            return 20
        case .groupInCommon:
            return 21
        case .block:
            return 22
        case .deleteChat:
            return 23
        case .deleteContact:
            return 24
        case .media:
            return 25
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    private var sortIndex:Int {
        switch self {
        case let .info(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setFirstName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setLastName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .about(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .bio(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .phoneNumber(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .userName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .scam(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .sendMessage(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botAddToGroup(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botShare(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botSettings(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botPrivacy(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botHelp(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .shareContact(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .shareMyInfo(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .addContact(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .startSecretChat(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .sharedMedia(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .groupInCommon(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .notifications(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .encryptionKey(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .block(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .deleteChat(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .deleteContact(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .media(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .section(id):
            return (id + 1) * 1000 - id
        }
        
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let other = entry as? UserInfoEntry else {
            return false
        }
        
        return self.sortIndex < other.sortIndex
    }
    
    
    
    func item( initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem {
        
        let arguments = arguments as! UserInfoArguments
        let state = arguments.state as! UserInfoState
        switch self {
        case let .info(_, peerView, editable, viewType):
            return PeerInfoHeadItem(initialSize, stableId:stableId.hashValue, context: arguments.context, arguments: arguments, peerView: peerView, viewType: viewType, editing: editable)
        case let .setFirstName(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: L10n.peerInfoFirstNamePlaceholder, filter: { $0 }, updated: {
                arguments.updateEditingNames(firstName: $0, lastName: state.editingState?.editingLastName)
            }, limit: 255)
        case let .setLastName(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: L10n.peerInfoLastNamePlaceholder, filter: { $0 }, updated: {
                arguments.updateEditingNames(firstName: state.editingState?.editingFirstName, lastName: $0)
            }, limit: 255)
        case let .about(_, text, viewType):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoAbout, text:text, context: arguments.context, viewType: viewType, detectLinks:true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            }, hashtag: arguments.context.sharedContext.bindings.globalSearch)
        case let .bio(_, text, viewType):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoBio, text:text, context: arguments.context, viewType: viewType, detectLinks:false)
        case let .phoneNumber(_, _, value, canCopy, viewType):
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:value.label, text: value.number, context: arguments.context, viewType: viewType, canCopy: canCopy)
        case let .userName(_, value, viewType):
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoUsername, text:"@\(value)", context: arguments.context, viewType: viewType)
        case let .scam(_, text, viewType):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoScam, labelColor: theme.colors.redUI, text: text, context: arguments.context, viewType: viewType, detectLinks:false)
        case let .sendMessage(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSendMessage, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.peerChat(arguments.peerId)
            })
        case let .botAddToGroup(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotAddToGroup, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botAddToGroup()
            })
        case let .botShare(_, name, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotShare, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botShare(name)
            })
        case let .botSettings(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotSettings, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botSettings()
            })
        case let .botHelp(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotHelp, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botHelp()
            })
        case let .botPrivacy(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotPrivacy, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botPrivacy()
            })
        case let .shareContact(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoShareContact, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.shareContact()
            })
        case let .shareMyInfo(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoShareMyInfo, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.shareMyInfo()
            })
        case let .addContact(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAddContact, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.addContact()
            })
        case let .startSecretChat(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoStartSecretChat, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.startSecretChat()
            })
        case let .sharedMedia(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSharedMedia, type: .next, viewType: viewType, action: {
                arguments.sharedMedia()
            })
        case let .groupInCommon(sectionId: _, count, peerId, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoGroupsInCommon, type: .nextContext("\(count)"), viewType: viewType, action: {
                arguments.groupInCommon(peerId)
            })
            
        case let .notifications(_, settings, viewType):
            
            let settings = settings as? TelegramPeerNotificationSettings
            let enabled = !(settings?.isMuted ?? false)
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoNotifications, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleNotifications()
            }, enabled: settings != nil)
        case let .encryptionKey(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoEncryptionKey, type: .next, viewType: viewType, action: {
                arguments.encryptionKey()
            })
        case let .block(_, peer, isBlocked, isBot, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: isBot ? (!isBlocked ? L10n.peerInfoStopBot : L10n.peerInfoRestartBot) : (!isBlocked ? L10n.peerInfoBlockUser : L10n.peerInfoUnblockUser), nameStyle:redActionButton, type: .none, viewType: viewType, action: {
                arguments.updateBlocked(peer: peer, !isBlocked, isBot)
            })
        case let .deleteChat(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoDeleteSecretChat, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.delete()
            })
        case let .deleteContact(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoDeleteContact, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.deleteContact()
            })
        case let .media(_, controller, isVisible, viewType):
            return PeerMediaBlockRowItem(initialSize, stableId: stableId.hashValue, controller: controller, isVisible: isVisible, viewType: viewType)
        case .section(_):
            return GeneralRowItem(initialSize, height: 30, stableId: stableId.hashValue, viewType: .separator)
        }
        
    }
    
}



func userInfoEntries(view: PeerView, arguments: PeerInfoArguments, mediaTabsData: PeerMediaTabsData) -> [PeerInfoEntry] {
    
    let arguments = arguments as! UserInfoArguments
    let state = arguments.state as! UserInfoState
    
    var entries: [PeerInfoEntry] = []
    
    var sectionId:Int = 0
    entries.append(UserInfoEntry.section(sectionId: sectionId))
    sectionId += 1
    
    
    func applyBlock(_ block:[UserInfoEntry]) {
        var block = block
        for (i, item) in block.enumerated() {
            block[i] = item.withUpdatedViewType(bestGeneralViewType(block, for: i))
        }
        entries.append(contentsOf: block)
    }
    
    var infoBlock: [UserInfoEntry] = []
    
    let editing = state.editingState != nil && (view.peers[view.peerId] as? TelegramUser)?.botInfo == nil && view.peerIsContact
    
    infoBlock.append(.info(sectionId: sectionId, peerView: view, editable: editing, viewType: .singleItem))
    
    if editing {
        infoBlock.append(.setFirstName(sectionId: sectionId, text: state.editingState?.editingFirstName ?? "", viewType: .singleItem))
        infoBlock.append(.setLastName(sectionId: sectionId, text: state.editingState?.editingLastName ?? "", viewType: .singleItem))
    }
    
    applyBlock(infoBlock)
    
    entries.append(UserInfoEntry.section(sectionId: sectionId))
    sectionId += 1
    
    if let peer = view.peers[view.peerId] {
        
        if let user = peerViewMainPeer(view) as? TelegramUser {
            
            var destructBlock:[UserInfoEntry] = []
            var infoBlock:[UserInfoEntry] = []
            
            if state.editingState == nil {
                if user.isScam {
                    infoBlock.append(UserInfoEntry.scam(sectionId: sectionId, text: L10n.peerInfoScamWarning, viewType: .singleItem))
                }
                if let cachedUserData = view.cachedData as? CachedUserData {
                    if let about = cachedUserData.about, !about.isEmpty, !user.isScam {
                        if peer.isBot {
                            infoBlock.append(UserInfoEntry.about(sectionId: sectionId, text: about, viewType: .singleItem))
                        } else {
                            infoBlock.append(UserInfoEntry.bio(sectionId: sectionId, text: about, viewType: .singleItem))
                        }
                    }
                }
                
                if let phoneNumber = user.phone, !phoneNumber.isEmpty {
                    infoBlock.append(.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: L10n.peerInfoPhone, number: formatPhoneNumber(phoneNumber)), canCopy: true, viewType: .singleItem))
                } else if view.peerIsContact {
                    infoBlock.append(.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: L10n.peerInfoPhone, number: L10n.newContactPhoneHidden), canCopy: false, viewType: .singleItem))
                }
                if let username = user.username, !username.isEmpty {
                    infoBlock.append(.userName(sectionId: sectionId, value: username, viewType: .singleItem))
                }
                
                
                if !user.isBot {
                    if !view.peerIsContact {
                        infoBlock.append(.addContact(sectionId: sectionId, viewType: .singleItem))
                        if let cachedData = view.cachedData as? CachedUserData {
                            infoBlock.append(.block(sectionId: sectionId, peer: peer, blocked: cachedData.isBlocked, isBot: peer.isBot, viewType: .singleItem))
                        }
                    }
                }
                if (peer is TelegramSecretChat) {
                    infoBlock.append(.encryptionKey(sectionId: sectionId, viewType: .singleItem))
                }
                
                applyBlock(infoBlock)
            }
            
            if let _ = view.cachedData as? CachedUserData, arguments.context.account.peerId != arguments.peerId {
                if state.editingState != nil {
                    if peer is TelegramSecretChat {
                        destructBlock.append(.deleteChat(sectionId: sectionId, viewType: .singleItem))
                    }
                    if view.peerIsContact {
                        destructBlock.append(.deleteContact(sectionId: sectionId, viewType: .singleItem))
                    }
                }
               
            }
            applyBlock(destructBlock)
            
            
            if mediaTabsData.loaded && !mediaTabsData.collections.isEmpty, let controller = arguments.mediaController() {
                entries.append(UserInfoEntry.media(sectionId: sectionId, controller: controller, isVisible: state.editingState == nil, viewType: .singleItem))
            }
        }
    }
    
    
    return entries.sorted(by: { (p1, p2) -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
