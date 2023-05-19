//
//  UserInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

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
    
    func giftPremium(_ options: [CachedPremiumGiftOption]) {
        showModal(with: PremiumGiftController(context: context, peerId: self.peerId, options: options), for: context.window)
    }
    
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
                confirm(for: context.window, information: strings().peerInfoConfirmShareInfo(peer.displayTitle), successHandler: { [weak self] _ in
                    let signal: Signal<Void, NoError> = context.account.postbox.loadedPeerWithId(context.peerId) |> map { $0 as! TelegramUser } |> mapToSignal { peer in
                        let signal = Sender.enqueue(message: EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil)), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []), context: context, peerId: peerId)
                        return signal  |> map { _ in}
                    }
                    self?.shareDisposable.set(showModalProgress(signal: signal, for: context.window).start())
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
                controller.genericView.tableView.item(stableId: IntPeerInfoEntryStableId(value: 1).hashValue)?.view?.shakeView()
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
            
            
            
            let updateNames: Signal<Void, UpdateContactNameError>
            
            if let firstName = updateValues.firstName {
                updateNames = showModalProgress(signal: context.engine.contacts.updateContactName(peerId: peerId, firstName: firstName, lastName: updateValues.lastName ?? "") |> deliverOnMainQueue, for: context.window)
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
    
    func reportReaction(_ messageId: MessageId) {
        let block: Signal<Never, NoError> = context.blockedPeersContext.add(peerId: peerId) |> `catch` { _ in .complete() }
        let report = context.engine.peers.reportPeerReaction(authorId: self.peerId, messageId: messageId) |> ignoreValues
        let context = self.context
        _ = showModalProgress(signal: combineLatest(block, report), for: context.window).start(completed: {
            showModalText(for: context.window, text: strings().peerInfoReportReactionSuccess)
        })
    }
    
    func call(_ isVideo: Bool) {
        let context = self.context
        let peer = context.account.postbox.peerView(id: peerId) |> take(1) |> map {
            return peerViewMainPeer($0)?.id
        } |> filter { $0 != nil } |> map { $0! }
        
        let call = peer |> mapToSignal {
            phoneCall(context: context, peerId: $0, isVideo: isVideo)
        } |> deliverOnMainQueue
        
        self.callDisposable.set(call.start(next: { result in
            applyUIPCallResult(context, result)
        }))
    }
        
    func botAddToGroup() {
        let context = self.context
        let peerId = self.peerId
        
        let result = selectModalPeers(window: context.window, context: context, title: strings().selectPeersTitleSelectGroupOrChannel, behavior: SelectGroupOrChannelBehavior(limit: 1), confirmation: { peerIds -> Signal<Bool, NoError> in
            return .single(true)
        })
        |> filter { $0.first != nil }
        |> map { $0.first! }
        |> mapToSignal { sourceId in
            return combineLatest(context.account.postbox.loadedPeerWithId(peerId), context.account.postbox.loadedPeerWithId(sourceId)) |> map {
                (dest: $0, source: $1)
            }
        } |> deliverOnMainQueue
        
        
        _ = result.start(next: { [weak self] values in
            
            let addAdmin:()->Void = {
                showModal(with: ChannelBotAdminController(context: context, peer: values.source, admin: values.dest, callback: { [weak self] peerId in
                    self?.peerChat(peerId)
                }), for: context.window)
            }
            let addSimple:()->Void = {
                confirm(for: context.window, information: strings().confirmAddBotToGroup(values.dest.displayTitle), successHandler: { [weak self] _ in
                    addBotAsMember(context: context, peer: values.source, to: values.dest, completion: { [weak self] peerId in
                        self?.peerChat(peerId, postId: nil)
                    }, error: { error in 
                        alert(for: context.window, info: error)
                    })
                })
            }
            if let peer = values.source as? TelegramChannel {
                if peer.groupAccess.isCreator {
                    addAdmin()
                } else if let adminRights = peer.adminRights, adminRights.rights.contains(.canAddAdmins) {
                    addAdmin()
                } else {
                    addSimple()
                }
            } else if let peer = values.source as? TelegramGroup {
                switch peer.role {
                case .creator:
                    addAdmin()
                default:
                    addSimple()
                }
            }
        })
    }
    func botShare(_ botName: String) {
        showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/\(botName)")), for: context.window)
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
                let confirm = confirmSignal(for: context.window, header: strings().peerInfoConfirmSecretChatHeader, information: strings().peerInfoConfirmStartSecretChat(peer.displayTitle), okTitle: strings().peerInfoConfirmSecretChatOK)
                return confirm |> filter {$0} |> mapToSignal { (_) -> Signal<PeerId, NoError> in
                    return showModalProgress(signal: context.engine.peers.createSecretChat(peerId: peer.id) |> `catch` { _ in return .complete()}, for: context.window)
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
        var peerId = peer.id
        if let peer = peer as? TelegramSecretChat {
            peerId = peer.regularPeerId
        }
        if blocked {
            confirm(for: context.window, header: strings().peerInfoBlockHeader, information: strings().peerInfoBlockText(peer.displayTitle), okTitle: strings().peerInfoBlockOK, successHandler: { [weak self] _ in
                let signal = showModalProgress(signal: context.blockedPeersContext.add(peerId: peerId) |> deliverOnMainQueue, for: context.window)
                self?.blockDisposable.set(signal.start(error: { error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: strings().unknownError)
                    }
                }, completed: {
                    
                }))
            })
        } else {
            let signal = showModalProgress(signal: context.blockedPeersContext.remove(peerId: peerId) |> deliverOnMainQueue, for: context.window)
            blockDisposable.set(signal.start(error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: strings().unknownError)
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
        deletePeerContactDisposable.set((confirmSignal(for: context.window, information: strings().peerInfoConfirmDeleteContact)
            |> filter {$0}
            |> mapToSignal { _ in
                showModalProgress(signal: context.engine.contacts.deleteContactPeerInteractively(peerId: peerId) |> deliverOnMainQueue, for: context.window)
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
    case bio(sectionId:Int, text: String, PeerEquatable, viewType: GeneralViewType)
    case scam(sectionId:Int, title: String, text: String, viewType: GeneralViewType)
    case phoneNumber(sectionId:Int, index: Int, value: PhoneNumberWithLabel, canCopy: Bool, viewType: GeneralViewType)
    case userName(sectionId:Int, value: [String], viewType: GeneralViewType)
    case reportReaction(sectionId: Int, value: MessageId, viewType: GeneralViewType)
    case sendMessage(sectionId:Int, viewType: GeneralViewType)
    case shareContact(sectionId:Int, viewType: GeneralViewType)
    case shareMyInfo(sectionId:Int, viewType: GeneralViewType)
    case addContact(sectionId:Int, viewType: GeneralViewType)
    case botAddToGroup(sectionId: Int, viewType: GeneralViewType)
    case botAddToGroupInfo(sectionId: Int, viewType: GeneralViewType)
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
        case let .bio(sectionId, text, peer, _): return .bio(sectionId: sectionId, text: text, peer, viewType: viewType)
        case let .scam(sectionId, title, text, _): return .scam(sectionId: sectionId, title: title, text: text, viewType: viewType)
        case let .phoneNumber(sectionId, index, value, canCopy, _): return .phoneNumber(sectionId: sectionId, index: index, value: value, canCopy: canCopy, viewType: viewType)
        case let .userName(sectionId, value, _): return .userName(sectionId: sectionId, value: value, viewType: viewType)
        case let .reportReaction(sectionId, value, _): return .reportReaction(sectionId: sectionId, value: value, viewType: viewType)
        case let .sendMessage(sectionId, _): return .sendMessage(sectionId: sectionId, viewType: viewType)
        case let .shareContact(sectionId, _): return .shareContact(sectionId: sectionId, viewType: viewType)
        case let .shareMyInfo(sectionId, _): return .shareMyInfo(sectionId: sectionId, viewType: viewType)
        case let .addContact(sectionId, _): return .addContact(sectionId: sectionId, viewType: viewType)
        case let .botAddToGroup(sectionId, _): return .botAddToGroup(sectionId: sectionId, viewType: viewType)
        case let .botAddToGroupInfo(sectionId, _): return .botAddToGroupInfo(sectionId: sectionId, viewType: viewType)
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
                } else if (lhsPeer != nil) != (rhsPeer != nil) {
                    return false
                }
                
                if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                    if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                        return false
                    }
                } else if (lhsNotificationSettings != nil) != (rhsNotificationSettings != nil) {
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
        case let .bio(sectionId, text, peer, viewType):
            switch entry {
            case .bio(sectionId, text, peer, viewType):
                return true
            default:
                return false
            }
        case let .scam(sectionId, title, text, viewType):
            switch entry {
            case .scam(sectionId, title, text, viewType):
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
        case let .reportReaction(sectionId, value, viewType):
            switch entry {
            case .reportReaction(sectionId, value, viewType):
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
        case let .botAddToGroupInfo(sectionId, viewType):
            switch entry {
            case .botAddToGroupInfo(sectionId, viewType):
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
            return 100
        case .setFirstName:
            return 101
        case .setLastName:
            return 102
        case .scam:
            return 103
        case .about:
            return 104
        case .bio:
            return 105
        case .phoneNumber:
            return 106
        case .userName:
            return 107
        case .sendMessage:
            return 108
        case .botAddToGroup:
            return 109
        case .botAddToGroupInfo:
            return 110
        case .botShare:
            return 111
        case .botSettings:
            return 112
        case .botHelp:
            return 113
        case .botPrivacy:
            return 114
        case .shareContact:
            return 115
        case .shareMyInfo:
            return 116
        case .addContact:
            return 117
        case .startSecretChat:
            return 118
        case .sharedMedia:
            return 119
        case .notifications:
            return 120
        case .encryptionKey:
            return 121
        case .groupInCommon:
            return 122
        case .block:
            return 123
        case .reportReaction:
            return 124
        case .deleteChat:
            return 125
        case .deleteContact:
            return 126
        case .media:
            return 127
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
        case let .bio(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .phoneNumber(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .userName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .reportReaction(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .scam(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .sendMessage(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botAddToGroup(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botAddToGroupInfo(sectionId, _):
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
        var state:UserInfoState {
            return arguments.state as! UserInfoState
        }
        
        switch self {
        case let .info(_, peerView, editable, viewType):
            return PeerInfoHeadItem(initialSize, stableId:stableId.hashValue, context: arguments.context, arguments: arguments, peerView: peerView, threadData: nil, viewType: viewType, editing: editable)
        case let .setFirstName(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: strings().peerInfoFirstNamePlaceholder, filter: { $0 }, updated: {
                arguments.updateEditingNames(firstName: $0, lastName: state.editingState?.editingLastName)
            }, limit: 255)
        case let .setLastName(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: strings().peerInfoLastNamePlaceholder, filter: { $0 }, updated: {
                arguments.updateEditingNames(firstName: state.editingState?.editingFirstName, lastName: $0)
            }, limit: 255)
        case let .about(_, text, viewType):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: strings().peerInfoAbout, copyMenuText: strings().textCopyLabelAbout, text:text, context: arguments.context, viewType: viewType, detectLinks: true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            }, hashtag: arguments.context.bindings.globalSearch)
        case let .bio(_, text, peer, viewType):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: strings().peerInfoBio, copyMenuText: strings().textCopyLabelBio, text:text, context: arguments.context, viewType: viewType, detectLinks: true, onlyInApp: !peer.peer.isPremium, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            })
        case let .phoneNumber(_, _, value, canCopy, viewType):
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:value.label, copyMenuText: strings().textCopyLabelPhoneNumber, text: formatPhoneNumber(value.number), context: arguments.context, viewType: viewType, canCopy: canCopy, _copyToClipboard: {
                arguments.copy("+\(value.number)")
            })
        case let .userName(_, value, viewType):
            let link = "https://t.me/\(value[0])"
            
            let text: String
            if value.count > 1 {
                text = strings().peerInfoUsernamesList("@\(value[0])", value.suffix(value.count - 1).map { "@\($0)" }.joined(separator: ", "))
            } else {
                text = "@\(value[0])"
            }
            
            let interactions = TextViewInteractions()
            interactions.processURL = { value in
                if let value = value as? inAppLink {
                    arguments.copy(value.link)
                }
            }
            interactions.localizeLinkCopy = globalLinkExecutor.localizeLinkCopy
            
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: strings().peerInfoUsername, copyMenuText: strings().textCopyLabelUsername, labelColor: theme.colors.text, text: text, context: arguments.context, viewType: viewType, detectLinks: value.count > 1, isTextSelectable: value.count > 1, _copyToClipboard: {
                arguments.copy(link)
            }, linkInteractions: interactions)
        case let .reportReaction(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoReportReaction, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.reportReaction(value)
            })
        case let .scam(_, title, text, viewType):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: title, copyMenuText: strings().textCopy, labelColor: theme.colors.redUI, text: text, context: arguments.context, viewType: viewType, detectLinks:false)
        case let .sendMessage(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoSendMessage, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.peerChat(arguments.peerId)
            })
        case let .botAddToGroup(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotAddTo, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botAddToGroup()
            })
        case let .botAddToGroupInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: strings().peerInfoBotAddToInfo, viewType: viewType)
        case let .botShare(_, name, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotShare, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botShare(name)
            })
        case let .botSettings(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotSettings, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botSettings()
            })
        case let .botHelp(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotHelp, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botHelp()
            })
        case let .botPrivacy(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotPrivacy, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.botPrivacy()
            })
        case let .shareContact(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoShareContact, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.shareContact()
            })
        case let .shareMyInfo(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoShareMyInfo, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.shareMyInfo()
            })
        case let .addContact(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoAddContact, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.addContact()
            })
        case let .startSecretChat(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoStartSecretChat, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.startSecretChat()
            })
        case let .sharedMedia(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoSharedMedia, type: .next, viewType: viewType, action: {
                arguments.sharedMedia()
            })
        case let .groupInCommon(sectionId: _, count, peerId, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoGroupsInCommon, type: .nextContext("\(count)"), viewType: viewType, action: {
                arguments.groupInCommon(peerId)
            })
            
        case let .notifications(_, settings, viewType):
            
            let settings = settings as? TelegramPeerNotificationSettings
            let enabled = !(settings?.isMuted ?? false)
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoNotifications, type: .switchable(enabled), viewType: viewType, action: {}, enabled: settings != nil)
        case let .encryptionKey(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoEncryptionKey, type: .next, viewType: viewType, action: {
                arguments.encryptionKey()
            })
        case let .block(_, peer, isBlocked, isBot, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: isBot ? (!isBlocked ? strings().peerInfoStopBot : strings().peerInfoRestartBot) : (!isBlocked ? strings().peerInfoBlockUser : strings().peerInfoUnblockUser), nameStyle:redActionButton, type: .none, viewType: viewType, action: {
                arguments.updateBlocked(peer: peer, !isBlocked, isBot)
            })
        case let .deleteChat(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoDeleteSecretChat, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.delete()
            })
        case let .deleteContact(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoDeleteContact, nameStyle: redActionButton, type: .none, viewType: viewType, action: {
                arguments.deleteContact()
            })
        case let .media(_, controller, isVisible, viewType):
            return PeerMediaBlockRowItem(initialSize, stableId: stableId.hashValue, controller: controller, isVisible: isVisible, viewType: viewType)
        case .section(_):
            return GeneralRowItem(initialSize, height: 30, stableId: stableId.hashValue, viewType: .separator)
        }
        
    }
    
}



func userInfoEntries(view: PeerView, arguments: PeerInfoArguments, mediaTabsData: PeerMediaTabsData, source: PeerInfoController.Source) -> [PeerInfoEntry] {
    
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
    
    var headerBlock: [UserInfoEntry] = []
    
    let editing = state.editingState != nil && (view.peers[view.peerId] as? TelegramUser)?.botInfo == nil && view.peerIsContact
    
    headerBlock.append(.info(sectionId: sectionId, peerView: view, editable: editing, viewType: .singleItem))
    
    if editing {
        headerBlock.append(.setFirstName(sectionId: sectionId, text: state.editingState?.editingFirstName ?? "", viewType: .singleItem))
        headerBlock.append(.setLastName(sectionId: sectionId, text: state.editingState?.editingLastName ?? "", viewType: .singleItem))
    }
    
    applyBlock(headerBlock)
    
    
    
    entries.append(UserInfoEntry.section(sectionId: sectionId))
    sectionId += 1
    

    
    if let peer = view.peers[view.peerId] {
        
        if let user = peerViewMainPeer(view) as? TelegramUser {
            
            var destructBlock:[UserInfoEntry] = []
            var infoBlock:[UserInfoEntry] = []
            
            if state.editingState == nil {
                if user.isScam {
                    infoBlock.append(UserInfoEntry.scam(sectionId: sectionId, title: strings().peerInfoScam, text: strings().peerInfoScamWarning, viewType: .singleItem))
                } else if user.isFake {
                    infoBlock.append(UserInfoEntry.scam(sectionId: sectionId, title: strings().peerInfoFake, text: strings().peerInfoFakeWarning, viewType: .singleItem))
                }
                
                if let cachedUserData = view.cachedData as? CachedUserData {
                    if let about = cachedUserData.about, !about.isEmpty, !user.isScam && !user.isFake {
                        if peer.isBot {
                            infoBlock.append(UserInfoEntry.about(sectionId: sectionId, text: about, viewType: .singleItem))
                        } else {
                            infoBlock.append(UserInfoEntry.bio(sectionId: sectionId, text: about, PeerEquatable(peer), viewType: .singleItem))
                        }
                    }
                }
                
                if let phoneNumber = user.phone, !phoneNumber.isEmpty {
                    infoBlock.append(.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: strings().peerInfoPhone, number: phoneNumber), canCopy: true, viewType: .singleItem))
                } else if view.peerIsContact {
                    infoBlock.append(.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: strings().peerInfoPhone, number: strings().newContactPhoneHidden), canCopy: false, viewType: .singleItem))
                }
                
                var usernames = user.usernames.filter { $0.isActive }.map {
                    $0.username
                }
                if usernames.isEmpty, let address = user.addressName {
                    usernames.append(address)
                }
                if !usernames.isEmpty {
                    infoBlock.append(.userName(sectionId: sectionId, value: usernames, viewType: .singleItem))
                }
                
                if !user.isBot {
                    if !view.peerIsContact {
                        infoBlock.append(.addContact(sectionId: sectionId, viewType: .singleItem))
                    }
                }
                if (peer is TelegramSecretChat) {
                    infoBlock.append(.encryptionKey(sectionId: sectionId, viewType: .singleItem))
                }
                if !user.isBot {
                    if !view.peerIsContact {
                        if let cachedData = view.cachedData as? CachedUserData {
                            var addBlock = true
                            switch source {
                            case let .reaction(messageId):
                                if !cachedData.isBlocked {
                                    infoBlock.append(.reportReaction(sectionId: sectionId, value: messageId, viewType: .singleItem))
                                    addBlock = false
                                }
                            default:
                                break
                            }
                            if addBlock {
                                infoBlock.append(.block(sectionId: sectionId, peer: peer, blocked: cachedData.isBlocked, isBot: peer.isBot, viewType: .singleItem))
                            }
                        }
                    }
                } else if let botInfo = user.botInfo, botInfo.flags.contains(.worksWithGroups) {
                    infoBlock.append(.botAddToGroup(sectionId: sectionId, viewType: .singleItem))
                }
               
                
                
                applyBlock(infoBlock)
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.worksWithGroups) {
                    entries.append(UserInfoEntry.botAddToGroupInfo(sectionId: sectionId, viewType: .textBottomItem))
                }
                
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
            } else {
                entries.append(UserInfoEntry.section(sectionId: sectionId))
                sectionId += 1
            }
        }
    }
    
    
    return entries.sorted(by: { (p1, p2) -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
