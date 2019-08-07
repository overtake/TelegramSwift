//
//  UserInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
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
    
    func shareContact() {
        shareDisposable.set((context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let context = self?.context, let peer = peer as? TelegramUser {
                showModal(with: ShareModalController(ShareContactObject(context, user: peer)), for: context.window)
            }
        }))
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
    
    override func updateEditable(_ editable: Bool, peerView: PeerView) {
        
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
        
        
    }
    
    func botAddToGroup() {
        let context = self.context
        let peerId = self.peerId
        
        let result = selectModalPeers(context: context, title: "", behavior: SelectChatsBehavior(limit: 1), confirmation: { peerIds -> Signal<Bool, NoError> in
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
            let signal = showModalProgress(signal: context.blockedPeersContext.add(peerId: peerId) |> deliverOnMainQueue, for: context.window)
            blockDisposable.set(signal.start(error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.unknownError)
                }
            }, completed: {
                
            }))
        } else {
            let signal = showModalProgress(signal: context.blockedPeersContext.remove(peerId: peerId) |> deliverOnMainQueue, for: context.window)
            blockDisposable.set(signal.start(error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.unknownError)
                }
            }, completed: {
                
            }))
        }
        
        if !blocked && isBot {
            pushViewController(ChatController(context: context, chatLocation: .peer(peerId), initialAction: ChatInitialAction.start(parameter: "", behavior: .automatic)))
        }

    }
    
    func deleteContact() {
        let context = self.context
        let peerId = self.peerId
        deletePeerContactDisposable.set((confirmSignal(for: mainWindow, information: tr(L10n.peerInfoConfirmDeleteContact))
            |> filter {$0}
            |> mapToSignal { _ in
                showModalProgress(signal: deleteContactPeerInteractively(account: context.account, peerId: peerId) |> deliverOnMainQueue, for: mainWindow)
            }).start(completed: { [weak self] in
                self?.pullNavigation()?.back()
            }))
    }
    
    func encryptionKey() {
        pushViewController(SecretChatKeyViewController(context, peerId: peerId))
    }
    
    func groupInCommon() -> Void {
        pushViewController(GroupsInCommonViewController(context, peerId: peerId))
    }
    
    deinit {
        shareDisposable.dispose()
        blockDisposable.dispose()
        startSecretChatDisposable.dispose()
        updatePeerNameDisposable.dispose()
        deletePeerContactDisposable.dispose()
    }
    
}



enum UserInfoEntry: PeerInfoEntry {
    case info(sectionId:Int, PeerView, editable:Bool)
    case about(sectionId:Int, text: String)
    case bio(sectionId:Int, text: String)
    case scam(sectionId:Int, text: String)
    case phoneNumber(sectionId:Int, index: Int, value: PhoneNumberWithLabel, canCopy: Bool)
    case userName(sectionId:Int, value: String)
    case sendMessage(sectionId:Int)
    case shareContact(sectionId:Int)
    case shareMyInfo(sectionId:Int)
    case addContact(sectionId:Int)
    case botAddToGroup(sectionId: Int)
    case botShare(sectionId: Int, name: String)
    case botHelp(sectionId: Int)
    case botSettings(sectionId: Int)
    case botPrivacy(sectionId: Int)
    case startSecretChat(sectionId:Int)
    case sharedMedia(sectionId:Int)
    case notifications(sectionId:Int, settings: PeerNotificationSettings?)
    case groupInCommon(sectionId:Int, count:Int)
    case block(sectionId:Int, peer: Peer, blocked: Bool, isBot: Bool)
    case deleteChat(sectionId: Int)
    case deleteContact(sectionId: Int)
    case encryptionKey(sectionId: Int)
    case section(sectionId:Int)
    
    var stableId: PeerInfoEntryStableId {
        return IntPeerInfoEntryStableId(value: self.stableIndex)
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? UserInfoEntry else {
            return false
        }
        
        switch self {
        case let .info(lhsSectionId, lhsPeerView, lhsEditable):
            switch entry {
            case let .info(rhsSectionId, rhsPeerView, rhsEditable):
                
                if lhsSectionId != rhsSectionId {
                    return false
                }
                
                if lhsEditable != rhsEditable {
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
                } else if (lhsCachedData == nil) != (rhsCachedData == nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case let .about(sectionId, text):
            switch entry {
            case .about(sectionId, text):
                return true
            default:
                return false
            }
        case let .bio(sectionId, text):
            switch entry {
            case .bio(sectionId, text):
                return true
            default:
                return false
            }
        case let .scam(sectionId, text):
            switch entry {
            case .scam(sectionId, text):
                return true
            default:
                return false
            }
        case let .phoneNumber(sectionid, index, value, canCopy):
            switch entry {
            case .phoneNumber(sectionid, index, value, canCopy):
                return true
            default:
                return false
            }
        case let .userName(sectionId, value):
            switch entry {
            case .userName(sectionId, value):
                return true
            default:
                return false
            }
        case let .sendMessage(sectionId):
            switch entry {
            case .sendMessage(sectionId):
                return true
            default:
                return false
            }
        case let .botAddToGroup(sectionId):
            switch entry {
            case .botAddToGroup(sectionId):
                return true
            default:
                return false
            }
        case let .botShare(sectionId, botName):
            switch entry {
            case .botShare(sectionId, botName):
                return true
            default:
                return false
            }
        case let .botHelp(sectionId):
            switch entry {
            case .botHelp(sectionId):
                return true
            default:
                return false
            }
        case let .botSettings(sectionId):
            switch entry {
            case .botSettings(sectionId):
                return true
            default:
                return false
            }
        case let .botPrivacy(sectionId):
            if case .botPrivacy(sectionId) = entry {
                return true
            } else {
                return false
            }
        case let .shareContact(sectionId):
            switch entry {
            case .shareContact(sectionId):
                return true
            default:
                return false
            }
        case let .shareMyInfo(sectionId):
            switch entry {
            case .shareMyInfo(sectionId):
                return true
            default:
                return false
            }
        case let .addContact(sectionId):
            switch entry {
            case .addContact(sectionId):
                return true
            default:
                return false
            }
        case let .startSecretChat(sectionId):
            switch entry {
            case .startSecretChat(sectionId):
                return true
            default:
                return false
            }
        case let .sharedMedia(sectionId):
            switch entry {
            case .sharedMedia(sectionId):
                return true
            default:
                return false
            }
        case let .notifications(lhsSectionId, lhsSettings):
            switch entry {
            case let .notifications(rhsSectionId, rhsSettings):
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                    return lhsSettings.isEqual(to: rhsSettings)
                } else if (lhsSettings != nil) != (rhsSettings != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case let .block(sectionId, lhsPeer, isBlocked, isBot):
            switch entry {
            case .block(sectionId, let rhsPeer, isBlocked, isBot):
                return lhsPeer.isEqual(rhsPeer)
            default:
                return false
            }
        case let .groupInCommon(sectionId, count):
            switch entry {
            case .groupInCommon(sectionId, count):
                return true
            default:
                return false
            }
        case let .deleteChat(sectionId):
            switch entry {
            case .deleteChat(sectionId):
                return true
            default:
                return false
            }
        case let .deleteContact(sectionId):
            switch entry {
            case .deleteContact(sectionId):
                return true
            default:
                return false
            }
        case let .encryptionKey(sectionId):
            switch entry {
            case .encryptionKey(sectionId):
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
        case .scam:
            return 1
        case .about:
            return 2
        case .phoneNumber:
            return 3
        case .bio:
            return 4
        case .userName:
            return 5
        case .sendMessage:
            return 6
        case .botAddToGroup:
            return 7
        case .botShare:
            return 8
        case .botSettings:
            return 9
        case .botHelp:
            return 10
        case .botPrivacy:
            return 11
        case .shareContact:
            return 12
        case .shareMyInfo:
            return 13
        case .addContact:
            return 14
        case .startSecretChat:
            return 15
        case .sharedMedia:
            return 16
        case .notifications:
            return 17
        case .encryptionKey:
            return 18
        case .groupInCommon:
            return 19
        case .block:
            return 20
        case .deleteChat:
            return 21
        case .deleteContact:
            return 22
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    private var sortIndex:Int {
        switch self {
        case let .info(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .about(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .bio(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .phoneNumber(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .userName(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .scam(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .sendMessage(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .botAddToGroup(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .botShare(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botSettings(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .botPrivacy(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .botHelp(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .shareContact(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .shareMyInfo(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .addContact(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .startSecretChat(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .sharedMedia(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .groupInCommon(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .notifications(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .encryptionKey(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .block(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .deleteChat(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .deleteContact(sectionId):
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
        case let .info(_, peerView, editable):
            return PeerInfoHeaderItem(initialSize, stableId:stableId.hashValue, context: arguments.context, peerView:peerView, editable: editable, updatingPhotoState: nil, firstNameEditableText: state.editingState?.editingFirstName, lastNameEditableText: state.editingState?.editingLastName, textChangeHandler: { firstName, lastName in
                arguments.updateEditingNames(firstName: firstName, lastName: lastName)
            })
        case let .about(_, text):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoAbout, text:text, context: arguments.context, detectLinks:true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            }, hashtag: arguments.context.sharedContext.bindings.globalSearch)
        case let .bio(_, text):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoBio, text:text, context: arguments.context, detectLinks:false)
        case let .phoneNumber(_, _, value, canCopy):
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:value.label, text: value.number, context: arguments.context, canCopy: canCopy)
        case let .userName(_, value):
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoUsername, text:"@\(value)", context: arguments.context)
        case let .scam(_, text):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoScam, labelColor: theme.colors.redUI, text: text, context: arguments.context, detectLinks:false)
        case .sendMessage:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSendMessage, nameStyle: blueActionButton, type: .none, action: {
                arguments.peerChat(arguments.peerId)
            })
        case .botAddToGroup:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotAddToGroup, nameStyle: blueActionButton, type: .none, action: {
                arguments.botAddToGroup()
            })
        case .botShare(_, let name):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotShare, nameStyle: blueActionButton, type: .none, action: {
                arguments.botShare(name)
            })
        case .botSettings:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotSettings, nameStyle: blueActionButton, type: .none, action: {
                arguments.botSettings()
            })
        case .botHelp:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotHelp, nameStyle: blueActionButton, type: .none, action: {
                arguments.botHelp()
            })
        case .botPrivacy:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoBotPrivacy, nameStyle: blueActionButton, type: .none, action: {
                arguments.botPrivacy()
            })
        case .shareContact:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoShareContact, nameStyle: blueActionButton, type: .none, action: {
                arguments.shareContact()
            })
        case .shareMyInfo:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoShareMyInfo, nameStyle: blueActionButton, type: .none, action: {
                arguments.shareMyInfo()
            })
        case .addContact:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAddContact, nameStyle: blueActionButton, type: .none, action: {
                arguments.addContact()
            })
        case .startSecretChat:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoStartSecretChat, nameStyle: blueActionButton, type: .none, action: {
                arguments.startSecretChat()
            })
        case .sharedMedia:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSharedMedia, type: .none, action: {
                arguments.sharedMedia()
            })
        case let .groupInCommon(sectionId: _, count: count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoGroupsInCommon, type: .context("\(count)"), action: {
                arguments.groupInCommon()
            })
            
        case let .notifications(_, settings):
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoNotifications, type: .switchable(!((settings as? TelegramPeerNotificationSettings)?.isMuted ?? true)), action: {
                arguments.toggleNotifications()
            })
        case .encryptionKey:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoEncryptionKey, type: .none, action: {
                arguments.encryptionKey()
            })
        case let .block(_, peer, isBlocked, isBot):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: isBot ? (!isBlocked ? L10n.peerInfoStopBot : L10n.peerInfoRestartBot) : (!isBlocked ? L10n.peerInfoBlockUser : L10n.peerInfoUnblockUser), nameStyle:redActionButton, type: .none, action: {
                arguments.updateBlocked(peer: peer, !isBlocked, isBot)
            })
        case .deleteChat:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoDeleteSecretChat, nameStyle: redActionButton, type: .none, action: {
                arguments.delete()
            })
        case .deleteContact:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoDeleteContact, nameStyle: redActionButton, type: .none, action: {
                arguments.deleteContact()
            })
        case .section(_):
            return GeneralRowItem(initialSize, height:20, stableId: stableId.hashValue)
        }
        
    }
    
}



func userInfoEntries(view: PeerView, arguments: PeerInfoArguments) -> [PeerInfoEntry] {
    
    let arguments = arguments as! UserInfoArguments
    let state = arguments.state as! UserInfoState
    
    var entries: [PeerInfoEntry] = []
    
    var sectionId:Int = 1
    
    
    entries.append(UserInfoEntry.info(sectionId: sectionId, view, editable: state.editingState != nil && (view.peers[view.peerId] as? TelegramUser)?.botInfo == nil && view.peerIsContact))
    
    if let peer = view.peers[view.peerId] {
        
        
        if let user = peerViewMainPeer(view) as? TelegramUser {
            if state.editingState == nil {
                
                if user.isScam {
                    entries.append(UserInfoEntry.scam(sectionId: sectionId, text: L10n.peerInfoScamWarning))
                }
                
                if let cachedUserData = view.cachedData as? CachedUserData {
                    if let about = cachedUserData.about, !about.isEmpty, !user.isScam {
                        if peer.isBot {
                            entries.append(UserInfoEntry.about(sectionId: sectionId, text: about))
                        } else {
                            entries.append(UserInfoEntry.bio(sectionId: sectionId, text: about))
                        }
                    }
                }
                
                if let phoneNumber = user.phone, !phoneNumber.isEmpty {
                    entries.append(UserInfoEntry.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: L10n.peerInfoPhone, number: formatPhoneNumber(phoneNumber)), canCopy: true))
                } else if view.peerIsContact {
                    entries.append(UserInfoEntry.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: L10n.peerInfoPhone, number: L10n.newContactPhoneHidden), canCopy: false))
                }
                if let username = user.username, !username.isEmpty {
                    entries.append(UserInfoEntry.userName(sectionId: sectionId, value: username))
                }
                
                
                entries.append(UserInfoEntry.section(sectionId: sectionId))
                sectionId += 1
                
               
                if !(peer is TelegramSecretChat) {
                    entries.append(UserInfoEntry.sendMessage(sectionId: sectionId))
                    if !user.isBot {
                        if !view.peerIsContact {
                            entries.append(UserInfoEntry.addContact(sectionId: sectionId))
                        } else if let phone = user.phone, !phone.isEmpty {
                            entries.append(UserInfoEntry.shareContact(sectionId: sectionId))
                        }
                        if let cachedData = view.cachedData as? CachedUserData, let statusSettings = cachedData.peerStatusSettings {
                            if statusSettings.contains(.canShareContact) {
                                entries.append(UserInfoEntry.shareMyInfo(sectionId: sectionId))
                            }
                        }
                    } else if let botInfo = user.botInfo {
                        if botInfo.flags.contains(.worksWithGroups) {
                            entries.append(UserInfoEntry.botAddToGroup(sectionId: sectionId))
                        }
                        entries.append(UserInfoEntry.botShare(sectionId: sectionId, name: user.addressName ?? ""))
                        if let cachedData = view.cachedData as? CachedUserData, let botInfo = cachedData.botInfo {
                            for command in botInfo.commands {
                                if command.text == "settings" {
                                    entries.append(UserInfoEntry.botSettings(sectionId: sectionId))
                                }
                                if command.text == "help" {
                                    entries.append(UserInfoEntry.botHelp(sectionId: sectionId))
                                }
                                if command.text == "privacy" {
                                    entries.append(UserInfoEntry.botPrivacy(sectionId: sectionId))
                                }
                            }
                        }
                    }
                } else {
                    if !view.peerIsContact {
                        entries.append(UserInfoEntry.addContact(sectionId: sectionId))
                    } else if let phone = user.phone, !phone.isEmpty {
                        entries.append(UserInfoEntry.shareContact(sectionId: sectionId))
                    }
                }
                
                if arguments.context.account.peerId != arguments.peerId, !(peer is TelegramSecretChat), let peer = peer as? TelegramUser, peer.botInfo == nil {
                    entries.append(UserInfoEntry.startSecretChat(sectionId: sectionId))
                }
                entries.append(UserInfoEntry.section(sectionId: sectionId))
                sectionId += 1
                
                entries.append(UserInfoEntry.sharedMedia(sectionId: sectionId))
            }
            if arguments.context.account.peerId != arguments.peerId {
                entries.append(UserInfoEntry.notifications(sectionId: sectionId, settings: view.notificationSettings))
            }
            
            if (peer is TelegramSecretChat) {
                entries.append(UserInfoEntry.encryptionKey(sectionId: sectionId))
            }
            
            if let cachedData = view.cachedData as? CachedUserData, arguments.context.account.peerId != arguments.peerId {
                
                if state.editingState == nil {
                    if cachedData.commonGroupCount > 0 {
                        entries.append(UserInfoEntry.groupInCommon(sectionId: sectionId, count: Int(cachedData.commonGroupCount)))
                    }
                    if !(peer is TelegramSecretChat) {
                        entries.append(UserInfoEntry.section(sectionId: sectionId))
                        sectionId += 1
                        entries.append(UserInfoEntry.block(sectionId: sectionId, peer: peer, blocked: cachedData.isBlocked, isBot: peer.isBot))
                    }
                } else {
                    entries.append(UserInfoEntry.section(sectionId: sectionId))
                    sectionId += 1
                    entries.append(UserInfoEntry.deleteContact(sectionId: sectionId))
                }
                
                
            }
            if peer is TelegramSecretChat {
                entries.append(UserInfoEntry.section(sectionId: sectionId))
                sectionId += 1
                
                entries.append(UserInfoEntry.deleteChat(sectionId: sectionId))
            }
        }
    }
    
    return entries.sorted(by: { (p1, p2) -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
