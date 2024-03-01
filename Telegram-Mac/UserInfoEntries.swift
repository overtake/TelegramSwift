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
    let updatingPhotoState:PeerInfoUpdatingPhotoState?
    let suggestingPhotoState:PeerInfoUpdatingPhotoState?
    let businessHoursRevealed: Bool
    let businessHoursDisplayMyTimezone: Bool
    init(editingState: UserInfoEditingState?, savingData: Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?, suggestingPhotoState:PeerInfoUpdatingPhotoState?, businessHoursRevealed: Bool, businessHoursDisplayMyTimezone: Bool) {
        self.editingState = editingState
        self.savingData = savingData
        self.updatingPhotoState = updatingPhotoState
        self.suggestingPhotoState = suggestingPhotoState
        self.businessHoursRevealed = businessHoursRevealed
        self.businessHoursDisplayMyTimezone = businessHoursDisplayMyTimezone
    }
    
    override init() {
        self.editingState = nil
        self.savingData = false
        self.updatingPhotoState = nil
        self.suggestingPhotoState = nil
        self.businessHoursRevealed = false
        self.businessHoursDisplayMyTimezone = true
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
        if lhs.updatingPhotoState != rhs.updatingPhotoState {
            return false
        }
        if lhs.suggestingPhotoState != rhs.suggestingPhotoState {
            return false
        }
        if lhs.businessHoursRevealed != rhs.businessHoursRevealed {
            return false
        }
        if lhs.businessHoursDisplayMyTimezone != rhs.businessHoursDisplayMyTimezone {
            return false
        }
        return true
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: savingData, updatingPhotoState: self.updatingPhotoState, suggestingPhotoState: self.suggestingPhotoState, businessHoursRevealed: self.businessHoursRevealed, businessHoursDisplayMyTimezone: self.businessHoursDisplayMyTimezone)
    }
    
    func withUpdatedEditingState(_ editingState: UserInfoEditingState?) -> UserInfoState {
        return UserInfoState(editingState: editingState, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, suggestingPhotoState: self.suggestingPhotoState, businessHoursRevealed: self.businessHoursRevealed, businessHoursDisplayMyTimezone: self.businessHoursDisplayMyTimezone)
    }
    
    func withUpdatedUpdatingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: f(self.updatingPhotoState), suggestingPhotoState: self.suggestingPhotoState, businessHoursRevealed: self.businessHoursRevealed, businessHoursDisplayMyTimezone: self.businessHoursDisplayMyTimezone)
    }
    func withoutUpdatingPhotoState() -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: nil, suggestingPhotoState: self.suggestingPhotoState, businessHoursRevealed: self.businessHoursRevealed, businessHoursDisplayMyTimezone: self.businessHoursDisplayMyTimezone)
    }
    
    func withUpdatedSuggestingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, suggestingPhotoState: f(self.updatingPhotoState), businessHoursRevealed: self.businessHoursRevealed, businessHoursDisplayMyTimezone: self.businessHoursDisplayMyTimezone)
    }
    func withoutSuggestingPhotoState() -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, suggestingPhotoState: nil, businessHoursRevealed: self.businessHoursRevealed, businessHoursDisplayMyTimezone: self.businessHoursDisplayMyTimezone)
    }
    func withBusinessHoursRevealed(_ revealed: Bool) -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, suggestingPhotoState: self.suggestingPhotoState, businessHoursRevealed: revealed, businessHoursDisplayMyTimezone: self.businessHoursDisplayMyTimezone)
    }
    func withBusinessHoursTimeZoneUpdated(_ businessHoursDisplayMyTimezone: Bool) -> UserInfoState {
        return UserInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState, suggestingPhotoState: self.suggestingPhotoState, businessHoursRevealed: self.businessHoursRevealed, businessHoursDisplayMyTimezone: businessHoursDisplayMyTimezone)
    }
}

class UserInfoArguments : PeerInfoArguments {
    
    
    enum SetPhotoType: Int, Equatable {
        case suggest = 0
        case set = 1
    }
    

    private let shareDisposable = MetaDisposable()
    private let blockDisposable = MetaDisposable()
    private let startSecretChatDisposable = MetaDisposable()
    private let updatePeerNameDisposable = MetaDisposable()
    private let deletePeerContactDisposable = MetaDisposable()
    private let callDisposable = MetaDisposable()
    private let updatePhotoDisposable = MetaDisposable()

    
    func giftPremium(_ options: [CachedPremiumGiftOption]) {
        showModal(with: PremiumGiftController(context: context, peerId: self.effectivePeerId, options: options), for: context.window)
    }
    
    func editBot(_ payload: String?, action: Bool = true) -> Void {
        let context = self.context
        if let username = peer?.addressName {
            let botFather = showModalProgress(signal: resolveUsername(username: "botfather", context: context), for: context.window)
            _ = botFather.start(next: { [weak self] peer in
                if let peer = peer {
                    let payload = payload != nil ? "-\(payload!)" : ""
                    let initialAction: ChatInitialAction?
                    if action {
                        initialAction = .start(parameter: username + payload, behavior: .automatic)
                    } else {
                        initialAction = nil
                    }
                    self?.pullNavigation()?.push(ChatAdditionController(context: context, chatLocation: .peer(peer.id), initialAction: initialAction))
                }
            })
        }
    }
    
    func openBotfather() {
        self.editBot(nil, action: false)
    }
    func openEditBotUsername() {
        self.pullNavigation()?.push(EditBotUsernameController(context: context, peerId: peerId))
    }
    
    func shareContact() {
        let context = self.context
        
        let peer = getPeerView(peerId: effectivePeerId, postbox: context.account.postbox) |> take(1) |> deliverOnMainQueue
        shareDisposable.set(peer.start(next: { [weak self] peer in
            if let context = self?.context, let peer = peer as? TelegramUser {
                showModal(with: ShareModalController(ShareContactObject(context, user: peer)), for: context.window)
            }
        }))
    }
    
    override init(context: AccountContext, peerId: PeerId, state: PeerInfoState, isAd: Bool, pushViewController: @escaping (ViewController) -> Void, pullNavigation: @escaping () -> NavigationViewController?, mediaController: @escaping()->PeerMediaController?) {
        super.init(context: context, peerId: peerId, state: state, isAd: isAd, pushViewController: pushViewController, pullNavigation: pullNavigation, mediaController: mediaController)
    }
    
    func shareMyInfo() {
        
        
        let context = self.context
        let peerId = self.peerId
        
        
        let peer = context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        } |> deliverOnMainQueue
        
        _ = peer.start(next: { [weak self] peer in
            if let peer = peer {
                verifyAlert_button(for: context.window, information: strings().peerInfoConfirmShareInfo(peer.displayTitle), successHandler: { [weak self] _ in
                    let signal: Signal<Void, NoError> = context.account.postbox.loadedPeerWithId(context.peerId) |> map { $0 as! TelegramUser } |> mapToSignal { peer in
                        let signal = Sender.enqueue(message: EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil)), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []), context: context, peerId: peerId)
                        return signal  |> map { _ in}
                    }
                    self?.shareDisposable.set(showModalProgress(signal: signal, for: context.window).start())
                })
            }
        })
        
        
    }
    
    func addContact() {
        let context = self.context
        let peerView = getPeerView(peerId: peerId, postbox: context.account.postbox) |> take(1) |> deliverOnMainQueue
        _ = peerView.start(next: { peer in
            if let peer = peer {
                showModal(with: NewContactController(context: context, peerId: peer.id), for: context.window)
            }
        })
    }
    
    override func updateEditable(_ editable:Bool, peerView:PeerView, controller: PeerInfoController) -> Bool {
        
        let context = self.context
        let peerId = self.peerId
        let isEditableBot = self.peer?.botInfo?.flags.contains(.canEdit) == true
        let updateState:((UserInfoState)->UserInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let peer = self.peer as? TelegramUser
        
        let firstName: String = peerViewMainPeer(peerView)?.compactDisplayTitle ?? ""
        let lastName = isEditableBot ? (peerView.cachedData as? CachedUserData)?.about : peer?.lastName

        if editable {
            updateState { state -> UserInfoState in
                return state.withUpdatedEditingState(UserInfoEditingState(editingFirstName: firstName, editingLastName: lastName))
            }
        } else {
            var updateValues: (firstName: String?, lastName: String?) = (nil, nil)
            updateState { state in
                if let peer = peerViewMainPeer(peerView) as? TelegramUser {
                    if peer.firstName != state.editingState?.editingFirstName {
                        updateValues.firstName = state.editingState?.editingFirstName
                    }
                    if lastName != state.editingState?.editingLastName {
                        updateValues.lastName = state.editingState?.editingLastName
                    }
                    return state.withUpdatedSavingData(true)
                } else {
                    return state.withUpdatedEditingState(nil)
                }
            }
            
            if let firstName = updateValues.firstName, firstName.isEmpty {
                controller.genericView.tableView.item(stableId: IntPeerInfoEntryStableId(value: 101).hashValue)?.view?.shakeView()
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
            
            
            enum UpdateError {
                case generic
            }
            
            let updateNames: Signal<Never, UpdateError>
            //
            if updateValues.firstName != nil || updateValues.lastName != nil {
                if isEditableBot {
                    var signals:[Signal<Void, UpdateError>] = []
                    if let firstName = updateValues.firstName {
                        signals.append(context.engine.peers.updateBotName(peerId: peerId, name: firstName) |> mapError { _ in return UpdateError.generic })
                    }
                    
                    if let lastName = updateValues.lastName {
                        signals.append(context.engine.peers.updateBotAbout(peerId: peerId, about: lastName) |> mapError { _ in return UpdateError.generic })
                    }
                    
                    updateNames = combineLatest(signals) |> ignoreValues
                } else {
                    updateNames = showModalProgress(signal: context.engine.contacts.updateContactName(peerId: peerId, firstName: updateValues.firstName ?? peer?.firstName ?? "", lastName: updateValues.lastName ?? peer?.lastName ?? "") |> mapError { _ in return UpdateError.generic } |> ignoreValues |> deliverOnMainQueue, for: context.window)
                }
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
        self.peerChat(self.effectivePeerId)
    }
    
    
    func openLocation(_ peer: Peer, _ location: TelegramBusinessLocation) {
        if let coordinates = location.coordinates {
            showModal(with: LocationModalPreview(context, map: .init(latitude: coordinates.latitude, longitude: coordinates.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil), peer: peer, messageId: nil), for: context.window)
        }
    }
    func openHours(_ peer: Peer, _ businessHours: TelegramBusinessHours) {
        let updateState:((UserInfoState)->UserInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        updateState { state in
            return state.withBusinessHoursRevealed(!state.businessHoursRevealed)
        }
    }
    
    func toggleDisplayZoneTime() {
        let updateState:((UserInfoState)->UserInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        updateState { state in
            return state.withBusinessHoursTimeZoneUpdated(!state.businessHoursDisplayMyTimezone).withBusinessHoursRevealed(true)
        }
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
        let peer = getPeerView(peerId: effectivePeerId, postbox: context.account.postbox) |> take(1) |> map {
            return $0?.id
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
        
        let result = selectModalPeers(window: context.window, context: context, title: strings().selectPeersTitleSelectGroupOrChannel, behavior: SelectChatsBehavior(settings: [.groups, .channels], limit: 1), confirmation: { peerIds -> Signal<Bool, NoError> in
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
                verifyAlert_button(for: context.window, information: strings().confirmAddBotToGroup(values.dest.displayTitle), successHandler: { [weak self] _ in
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
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/settings"), context: context, peerId: peerId, replyId: nil, threadId: nil).start()
        pullNavigation()?.back()
    }
    func botHelp() {
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/help"), context: context, peerId: peerId, replyId: nil, threadId: nil).start()
        pullNavigation()?.back()
    }
    
    func botPrivacy() {
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/privacy"), context: context, peerId: peerId, replyId: nil, threadId: nil).start()
        pullNavigation()?.back()
    }
    
    func startSecretChat() {
        let context = self.context
        let peerId = self.peerId
        
        let peer = context.account.postbox.loadedPeerWithId(peerId)
        let premiumRequired = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.IsPremiumRequiredForMessaging(id: peerId))
        
        let signal = combineLatest(peer, premiumRequired) |> deliverOnMainQueue |> mapToSignal { peer, premiumRequired -> Signal<PeerId?, NoError> in
            if !context.isPremium && premiumRequired {
                return .single(nil)
            }
            let confirm = verifyAlertSignal(for: context.window, header: strings().peerInfoConfirmSecretChatHeader, information: strings().peerInfoConfirmStartSecretChat(peer.displayTitle), ok: strings().peerInfoConfirmSecretChatOK)
            return confirm |> filter { $0 == .basic } |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                return showModalProgress(signal: context.engine.peers.createSecretChat(peerId: peer.id) |> `catch` { _ in return .complete()}, for: context.window) |> map(Optional.init)
            }
        } |> deliverOnMainQueue
        
        
        
        startSecretChatDisposable.set(signal.start(next: { [weak self] peerId in
            if let strongSelf = self {
                if let peerId = peerId {
                    strongSelf.pushViewController(ChatController(context: strongSelf.context, chatLocation: .peer(peerId)))
                } else {
                    showModalText(for: context.window, text: strings().chatSecretChatPremiumRequired(strongSelf.peer?.compactDisplayTitle ?? ""), button: strings().alertLearnMore, callback: { _ in
                        showModal(with: PremiumBoardingController(context: context), for: context.window)
                    })
                }
            }
        }))
    }
    
    override func dismissEdition() {
        updateState { state in
            return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
        }
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
            verifyAlert_button(for: context.window, header: strings().peerInfoBlockHeader, information: strings().peerInfoBlockText(peer.displayTitle), ok: strings().peerInfoBlockOK, successHandler: { [weak self] _ in
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
        
        verifyAlert(for: context.window, information: strings().peerInfoConfirmDeleteContact, ok: strings().modalDelete, successHandler: { _ in
            _ = showModalProgress(signal: context.engine.contacts.deleteContactPeerInteractively(peerId: peerId) |> deliverOnMainQueue, for: context.window).start()
        })

    }
    
    func encryptionKey() {
        pushViewController(SecretChatKeyViewController(context, peerId: peerId))
    }
    
    private func makeUpdatePhotoItems(_ custom: NSImage?, type: SetPhotoType) -> [ContextMenuItem] {
        let context = self.context
        let peerId = self.peerId
        let isEditableBot = self.peer?.botInfo?.flags.contains(.canEdit) == true
        let info = strings().userInfoSetPhotoInfo(peer?.compactDisplayTitle ?? "")
        
        let updatePhoto:(Signal<NSImage, NoError>) -> Void = { [weak self] image in
            let signal = image |> mapToSignal { image in
                return putToTemp(image: image, compress: true)
            } |> deliverOnMainQueue
            _ = signal.start(next: { [weak self] path in
                let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square), confirm: { url, f in
                    if isEditableBot {
                        f()
                    } else {
                        showModal(with: UserInfoPhotoConfirmController(context: context, peerId: peerId, thumb: url, type: type, confirm: f), for: context.window)
                    }
                })
                showModal(with: controller, for: context.window, animationType: .scaleCenter)
                _ = controller.result.start(next: { [weak self] url, _ in
                    DispatchQueue.main.async {
                        self?.updatePhoto(url.path, type: type)
                    }
                })
            })
        }
        if let image = custom {
            updatePhoto(.single(image))
        } else {
            
            let context = self.context
            let updateVideo = self.updateVideo
            
            let makeVideo:(MediaObjectToAvatar)->Void = { object in
                
                switch object.object.foreground.type {
                case .emoji:
                    updatePhoto(object.start() |> mapToSignal { value in
                        if let result = value.result {
                            switch result {
                            case let .image(image):
                                return .single(image)
                            default:
                                return .never()
                            }
                        } else {
                            return .never()
                        }
                    })
                default:
                    let signal:Signal<VideoAvatarGeneratorState, NoError> = object.start() |> map { value in
                        if let result = value.result {
                            switch result {
                            case let .video(path, thumb):
                                return .complete(thumb: thumb, video: path, keyFrame: nil)
                            default:
                                return .error
                            }
                        } else if let status = value.status {
                            switch status {
                            case let .initializing(thumb):
                                return .start(thumb: thumb)
                            case let .converting(progress):
                                return .progress(progress)
                            default:
                                return .error
                            }
                        } else {
                            return .error
                        }
                    }
                    updateVideo(signal, type)
                }
            }
            
            
            var items:[ContextMenuItem] = []
            
            items.append(.init(strings().editAvatarPhotoOrVideo, handler: {
                filePanel(with: photoExts + videoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        updatePhoto(.single(image))
                    } else if let path = paths?.first {
                        selectVideoAvatar(context: context, path: path, localize: info, signal: { signal in
                            updateVideo(signal, type)
                        }, confirm: { url, f in
                            if isEditableBot {
                                f()
                            } else {
                                showModal(with: UserInfoPhotoConfirmController(context: context, peerId: peerId, thumb: url, type: type, confirm: f), for: context.window)
                            }
                        })
                    }
                })
            }, itemImage: MenuAnimation.menu_shared_media.value))
//            
//            items.append(.init(strings().editAvatarCustomize, handler: {
//                showModal(with: AvatarConstructorController(context, target: .avatar, videoSignal: makeVideo, confirm: { url, f in
//                    showModal(with: UserInfoPhotoConfirmController(context: context, peerId: peerId, thumb: url, type: type, confirm: f), for: context.window)
//                }), for: context.window)
//            }, itemImage: MenuAnimation.menu_view_sticker_set.value))
            
            return items
        }
        return []
    }
    
    func updateContactPhoto(_ custom: NSImage?, control: Control?, type: SetPhotoType) {
        let context = self.context
        let peerId = self.peerId
        let info = strings().userInfoSetPhotoInfo(peer?.compactDisplayTitle ?? "")
        let updateVideo = self.updateVideo
        let updatePhoto:(Signal<NSImage, NoError>) -> Void = { [weak self] image in
            let signal = image |> mapToSignal { image in
                return putToTemp(image: image, compress: true)
            } |> deliverOnMainQueue
            _ = signal.start(next: { [weak self] path in
                let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square), confirm: { url, f in
                    showModal(with: UserInfoPhotoConfirmController(context: context, peerId: peerId, thumb: url, type: type, confirm: f), for: context.window)
                })
                showModal(with: controller, for: context.window, animationType: .scaleCenter)
                _ = controller.result.start(next: { [weak self] url, _ in
                    DispatchQueue.main.async {
                        self?.updatePhoto(url.path, type: type)
                    }
                })
            })
        }
        let items = self.makeUpdatePhotoItems(custom, type: type)
        
        if let control = control, let event = NSApp.currentEvent, !items.isEmpty {
            let menu = ContextMenu()
            for item in items {
                menu.addItem(item)
            }
            let value = AppMenu(menu: menu)
            value.show(event: event, view: control)
        } else {
            filePanel(with: photoExts + videoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { paths in
                if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                    updatePhoto(.single(image))
                } else if let path = paths?.first {
                    selectVideoAvatar(context: context, path: path, localize: info, signal: { signal in
                        updateVideo(signal, type)
                    }, confirm: { url, f in
                        showModal(with: UserInfoPhotoConfirmController(context: context, peerId: peerId, thumb: url, type: type, confirm: f), for: context.window)
                    })
                }
            })
        }
            
    }
    
    func setPhotoItems(_ type: SetPhotoType) -> [ContextMenuItem] {
        return makeUpdatePhotoItems(nil, type: type)
    }

    
    func updatePhoto(_ path:String, type: SetPhotoType) -> Void {
        
        let updateState:((UserInfoState)->UserInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let cancel = { [weak self] in
            self?.updatePhotoDisposable.set(nil)
            updateState { state -> UserInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }
        
        let context = self.context
        let peerId = self.peerId
        let title = self.peer?.compactDisplayTitle ?? ""
        
        let isEditableBot = self.peer?.botInfo?.flags.contains(.canEdit) == true
        
        let suggestSignal = Signal<String, NoError>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
            } |> castError(UploadPeerPhotoError.self) |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mode: .suggest, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                })
        }
        
        let updateSignal = Signal<String, NoError>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
            } |> beforeNext { resource in
                updateState { state in
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return PeerInfoUpdatingPhotoState(progress: 0, image: NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil), cancel: cancel)
                    }
                }
            } |> castError(UploadPeerPhotoError.self) |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                })
        }
        
        switch type {
        case .suggest:
            self.updatePhotoDisposable.set((suggestSignal |> deliverOnMainQueue).start(next: { value in
                updateState { current in
                    return current.withUpdatedSuggestingPhotoState({ _ in
                        .init(progress: 0, cancel: {})
                    })
                }
            }, completed: { [weak self] in
                if !isEditableBot {
                    showModalText(for: context.window, text: strings().userInfoSuggestTooltip(title))
                }
                updateState { current in
                    return current.withoutSuggestingPhotoState()
                }
                self?.pullNavigation()?.back()
            }))
        case .set:
            self.updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
                updateState { state in
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
                updateState { state in
                    return state.withoutUpdatingPhotoState()
                }
            }, completed: {
                updateState { state in
                    return state.withoutUpdatingPhotoState()
                }
                resetPeerPhotos(peerId: peerId)
                if !isEditableBot {
                    showModalText(for: context.window, text: strings().userInfoSetPhotoTooltip(title))
                }
            }))
        }        
    }
    
    func updateVideo(_ signal:Signal<VideoAvatarGeneratorState, NoError>, type: SetPhotoType) -> Void {
        
        let updateState:((UserInfoState)->UserInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let cancel = { [weak self] in
            self?.updatePhotoDisposable.set(nil)
            updateState { state in
                return state.withoutUpdatingPhotoState()
            }
        }
        
        let context = self.context
        let peerId = self.peerId
        let title = self.peer?.compactDisplayTitle ?? ""
        
        let suggestSignal: Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> = signal
        |> castError(UploadPeerPhotoError.self)
        |> mapToSignal { state in
            switch state {
            case .error:
                return .fail(.generic)
            case .start:
                return .next(.progress(0))
            case let .progress(value):
                return .next(.progress(value * 0.2))
            case let .complete(thumb, video, keyFrame):
                
                let (thumbResource, videoResource) = (LocalFileReferenceMediaResource(localFilePath: thumb, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true),
                                                      LocalFileReferenceMediaResource(localFilePath: video, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true))

                
                return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: thumbResource, videoResource: videoResource, videoStartTimestamp: keyFrame, markup: nil, mode: .suggest, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                }) |> mapToSignal { result in
                    switch result {
                    case let .progress(current):
                        if current == 1.0 {
                            return .single(.complete([]))
                        } else {
                            return .next(.progress(0.2 + (current * 0.8)))
                        }
                    default:
                        return .complete()
                    }
                }
            }
        }
        
        
        let updateSignal: Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> = signal
            |> castError(UploadPeerPhotoError.self)
            |> mapToSignal { state in
                switch state {
                case .error:
                    return .fail(.generic)
                case let .start(path):
                    updateState { state in
                        return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                            return PeerInfoUpdatingPhotoState(progress: 0, image: NSImage(contentsOfFile: path)?._cgImage, cancel: cancel)
                        }
                    }
                    return .next(.progress(0))
                case let .progress(value):
                    return .next(.progress(value * 0.2))
                case let .complete(thumb, video, keyFrame):
                    
                    updateState { state in
                        return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                            return PeerInfoUpdatingPhotoState(progress: 0.2, image: NSImage(contentsOfFile: thumb)?._cgImage, cancel: cancel)
                        }
                    }
                    
                    let (thumbResource, videoResource) = (LocalFileReferenceMediaResource(localFilePath: thumb, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true),
                                                          LocalFileReferenceMediaResource(localFilePath: video, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true))
                                        
                    return context.engine.contacts.updateContactPhoto(peerId: peerId, resource: thumbResource, videoResource: videoResource, videoStartTimestamp: keyFrame, markup: nil, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                    }) |> mapToSignal { result in
                        switch result {
                        case let .progress(current):
                            if current == 1.0 {
                                return .single(.complete([]))
                            } else {
                                return .next(.progress(0.2 + (current * 0.8)))
                            }
                        default:
                            return .complete()
                        }
                    }
                }
        }
        
        switch type {
        case .suggest:
            self.updatePhotoDisposable.set((suggestSignal |> deliverOnMainQueue).start(next: { [weak self] value in
                if case .complete = value {
                    showModalText(for: context.window, text: strings().userInfoSuggestTooltip(title))
                    updateState { current in
                        return current.withoutSuggestingPhotoState()
                    }
                    self?.pullNavigation()?.back()
                } else {
                    updateState { current in
                        return current.withUpdatedSuggestingPhotoState({ _ in
                            .init(progress: 0, cancel: {})
                        })
                    }
                }
            }))
        case .set:
            self.updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
                updateState { state in
                    switch status {
                    case .complete:
                        return state.withoutUpdatingPhotoState()
                    case let .progress(progress):
                        return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                            return previous?.withUpdatedProgress(progress)
                        }
                    }
                }
            }, error: { error in
                updateState { state in
                    return state.withoutUpdatingPhotoState()
                }
            }, completed: {
                updateState { state in
                    return state.withoutUpdatingPhotoState()
                }
                resetPeerPhotos(peerId: peerId)
                showModalText(for: context.window, text: strings().userInfoSetPhotoTooltip(title))
            }))
        }
    }
    
    func resetPhoto() {
        let context = self.context
        let peerId = self.peerId
        verifyAlert_button(for: context.window, information: strings().userInfoResetPhotoConfirm(peer?.compactDisplayTitle ?? ""), ok: strings().userInfoResetPhotoConfirmOK, successHandler: { _ in
            let signal = context.engine.contacts.updateContactPhoto(peerId: peerId, resource: nil, videoResource: nil, videoStartTimestamp: nil, markup: nil, mode: .custom, mapResourceToAvatarSizes: { _,_  in
                return .complete()
            })
            _ = showModalProgress(signal: signal, for: context.window).start()
        })
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
        updatePhotoDisposable.dispose()
    }
    
}



enum UserInfoEntry: PeerInfoEntry {
    case info(sectionId:Int, peerView: PeerView, editable:Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?, stories: PeerExpiringStoryListContext.State?, viewType: GeneralViewType)
    case setFirstName(sectionId:Int, text: String, viewType: GeneralViewType)
    case setLastName(sectionId:Int, text: String, placeholder: String, viewType: GeneralViewType)
    case about(sectionId:Int, text: String, viewType: GeneralViewType)
    case botEditUsername(sectionId:Int, text: String, viewType: GeneralViewType)
    case botEditIntro(sectionId:Int, viewType: GeneralViewType)
    case botEditCommands(sectionId:Int, viewType: GeneralViewType)
    case botEditSettings(sectionId:Int, viewType: GeneralViewType)
    case botEditInfo(sectionId:Int, viewType: GeneralViewType)
    case bio(sectionId:Int, text: String, PeerEquatable, viewType: GeneralViewType)
    case scam(sectionId:Int, title: String, text: String, viewType: GeneralViewType)
    case phoneNumber(sectionId:Int, index: Int, value: PhoneNumberWithLabel, canCopy: Bool, viewType: GeneralViewType)
    case userName(sectionId:Int, value: [String], viewType: GeneralViewType)
    case businessLocation(sectionId:Int, peer: EnginePeer, businessLocation: TelegramBusinessLocation, viewType: GeneralViewType)
    case businessHours(sectionId:Int, peer: EnginePeer, businessHours: TelegramBusinessHours, revealed: Bool, displayMyZone: Bool, viewType: GeneralViewType)
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
    case setPhoto(sectionId:Int, string: String, type: UserInfoArguments.SetPhotoType, nextType: GeneralInteractedType, viewType: GeneralViewType)
    case resetPhoto(sectionId:Int, string: String, image: TelegramMediaImage, user: TelegramUser, viewType: GeneralViewType)
    case setPhotoInfo(sectionId:Int, string: String, viewType: GeneralViewType)
    case block(sectionId:Int, peer: Peer, blocked: Bool, isBot: Bool, viewType: GeneralViewType)
    case deleteChat(sectionId: Int, viewType: GeneralViewType)
    case deleteContact(sectionId: Int, viewType: GeneralViewType)
    case encryptionKey(sectionId: Int, viewType: GeneralViewType)
    case media(sectionId: Int, controller: PeerMediaController, isVisible: Bool, viewType: GeneralViewType)
    case section(sectionId:Int)
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> UserInfoEntry {
        switch self {
        case let .info(sectionId, peerView, editable, updatingPhotoState, stories, _): return .info(sectionId: sectionId, peerView: peerView, editable: editable, updatingPhotoState: updatingPhotoState, stories: stories, viewType: viewType)
        case let .setFirstName(sectionId, text, _): return .setFirstName(sectionId: sectionId, text: text, viewType: viewType)
        case let .setLastName(sectionId, text, placeholder, _): return .setLastName(sectionId: sectionId, text: text, placeholder: placeholder, viewType: viewType)
        case let .botEditUsername(sectionId, text, _): return .botEditUsername(sectionId: sectionId, text: text, viewType: viewType)
        case let .botEditIntro(sectionId, _): return .botEditIntro(sectionId: sectionId, viewType: viewType)
        case let .botEditCommands(sectionId, _): return .botEditCommands(sectionId: sectionId, viewType: viewType)
        case let .botEditSettings(sectionId, _): return .botEditSettings(sectionId: sectionId, viewType: viewType)
        case let .botEditInfo(sectionId, _): return .botEditInfo(sectionId: sectionId, viewType: viewType)
        case let .about(sectionId, text, _): return .about(sectionId: sectionId, text: text, viewType: viewType)
        case let .bio(sectionId, text, peer, _): return .bio(sectionId: sectionId, text: text, peer, viewType: viewType)
        case let .scam(sectionId, title, text, _): return .scam(sectionId: sectionId, title: title, text: text, viewType: viewType)
        case let .phoneNumber(sectionId, index, value, canCopy, _): return .phoneNumber(sectionId: sectionId, index: index, value: value, canCopy: canCopy, viewType: viewType)
        case let .userName(sectionId, value, _): return .userName(sectionId: sectionId, value: value, viewType: viewType)
        case let .businessLocation(sectionId, peer, location, _): return .businessLocation(sectionId: sectionId, peer: peer, businessLocation: location, viewType: viewType)
        case let .businessHours(sectionId, peer, businessHours, revealed, displayMyZone, _): return .businessHours(sectionId: sectionId, peer: peer, businessHours: businessHours, revealed: revealed, displayMyZone: displayMyZone, viewType: viewType)
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
        case let .setPhoto(sectionId, string, type, nextType, _): return .setPhoto(sectionId: sectionId, string: string, type: type, nextType: nextType, viewType: viewType)
        case let .resetPhoto(sectionId, string, image, user, _): return .resetPhoto(sectionId: sectionId, string: string, image: image, user: user, viewType: viewType)
        case let .setPhotoInfo(sectionId, string, viewType): return .setPhotoInfo(sectionId: sectionId, string: string, viewType: viewType)
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
        case let .info(lhsSectionId, lhsPeerView, lhsEditable, lhsUpdatingPhotoState, lhsStories, lhsViewType):
            switch entry {
            case let .info(rhsSectionId, rhsPeerView, rhsEditable, rhsUpdatingPhotoState, rhsStories, rhsViewType):
                
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if lhsViewType != rhsViewType {
                    return false
                }
                if lhsUpdatingPhotoState != rhsUpdatingPhotoState {
                    return false
                }
                if lhsEditable != rhsEditable {
                    return false
                }
                if lhsStories != rhsStories {
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
        case let .setLastName(sectionId, text, placeholder, viewType):
            switch entry {
            case .setLastName(sectionId, text, placeholder, viewType):
                return true
            default:
                return false
            }
        case let .botEditUsername(sectionId, text, viewType):
            switch entry {
            case .botEditUsername(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .botEditIntro(sectionId, viewType):
            switch entry {
            case .botEditIntro(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .botEditCommands(sectionId, viewType):
            switch entry {
            case .botEditCommands(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .botEditSettings(sectionId, viewType):
            switch entry {
            case .botEditSettings(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .botEditInfo(sectionId, viewType):
            switch entry {
            case .botEditInfo(sectionId, viewType):
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
        case let .businessLocation(sectionId, peer, location, viewType):
            switch entry {
            case .businessLocation(sectionId, peer: peer, businessLocation: location, viewType):
                return true
            default:
                return false
            }
        case let .businessHours(sectionId, peer, businessHours, revealed, displayMyZone, viewType):
            switch entry {
            case .businessHours(sectionId, peer, businessHours, revealed, displayMyZone, viewType):
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
        case let .setPhoto(sectionId, string, type, nextType, viewType):
            switch entry {
            case .setPhoto(sectionId, string, type, nextType, viewType):
                return true
            default:
                return false
            }
        case let .resetPhoto(sectionId, string, image, user, viewType):
            switch entry {
            case .resetPhoto(sectionId, string, image, user, viewType):
                return true
            default:
                return false
            }
        case let .setPhotoInfo(sectionId, string, viewType):
            switch entry {
            case .setPhotoInfo(sectionId, string, viewType):
                return true
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
        case .botEditUsername:
            return 103
        case .botEditIntro:
            return 104
        case .botEditCommands:
            return 105
        case .botEditSettings:
            return 106
        case .botEditInfo:
            return 107
        case .scam:
            return 108
        case .about:
            return 109
        case .bio:
            return 110
        case .phoneNumber:
            return 111
        case .userName:
            return 112
        case .businessHours:
            return 113
        case .businessLocation:
            return 114
        case .sendMessage:
            return 115
        case .botAddToGroup:
            return 116
        case .botAddToGroupInfo:
            return 117
        case .botShare:
            return 118
        case .botSettings:
            return 119
        case .botHelp:
            return 120
        case .botPrivacy:
            return 121
        case .shareContact:
            return 122
        case .shareMyInfo:
            return 123
        case .addContact:
            return 124
        case .startSecretChat:
            return 125
        case .sharedMedia:
            return 126
        case .notifications:
            return 127
        case .encryptionKey:
            return 128
        case .groupInCommon:
            return 129
        case let .setPhoto(_, _, type, _, _):
            return 130 + type.rawValue
        case .resetPhoto:
            return 134
        case .setPhotoInfo:
            return 135
        case .block:
            return 136
        case .reportReaction:
            return 137
        case .deleteChat:
            return 138
        case .deleteContact:
            return 139
        case .media:
            return 140
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    private var sortIndex:Int {
        switch self {
        case let .info(sectionId, _, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setFirstName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setLastName(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditUsername(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditIntro(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditCommands(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditSettings(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditInfo(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .about(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .bio(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .phoneNumber(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .userName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .businessHours(sectionId, _, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .businessLocation(sectionId, _, _, _):
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
        case let .setPhoto(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .resetPhoto(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setPhotoInfo(sectionId, _, _):
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
        case let .info(_, peerView, editable, updatingPhotoState, stories, viewType):
            return PeerInfoHeadItem(initialSize, stableId:stableId.hashValue, context: arguments.context, arguments: arguments, peerView: peerView, threadData: nil, threadId: nil, stories: stories, viewType: viewType, editing: editable, updatingPhotoState: updatingPhotoState, updatePhoto: { image, control in
                arguments.updateContactPhoto(image, control: control, type: .set)
            })
        case let .setFirstName(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: strings().peerInfoFirstNamePlaceholder, filter: { $0 }, updated: {
                arguments.updateEditingNames(firstName: $0, lastName: state.editingState?.editingLastName)
            }, limit: 255)
        case let .setLastName(_, text, placeholder, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: placeholder, filter: { $0 }, updated: {
                arguments.updateEditingNames(firstName: state.editingState?.editingFirstName, lastName: $0)
            }, limit: 255)
        case let .botEditUsername(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotEditUsername, type: .nextContext(text), viewType: viewType, action: arguments.openEditBotUsername)
        case let .botEditIntro(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotEditIntro, icon: NSImage(named: "Icon_PeerInfo_BotIntro")?.precomposed(theme.colors.accent, flipVertical: true), nameStyle: blueActionButton, viewType: viewType, action: {
                arguments.editBot("intro")
            })
        case let .botEditCommands(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotEditCommands, icon: NSImage(named: "Icon_PeerInfo_BotCommands")?.precomposed(theme.colors.accent, flipVertical: true), nameStyle: blueActionButton, viewType: viewType, action: {
                arguments.editBot("commands")
            })
        case let .botEditSettings(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotEditSettings, icon: NSImage(named: "Icon_PeerInfo_BotSettings")?.precomposed(theme.colors.accent, flipVertical: true), nameStyle: blueActionButton, viewType: viewType, action: {
                arguments.editBot(nil)
            })
        case let .botEditInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: .markdown(strings().peerInfoBotEditInfo, linkHandler: { _ in
                arguments.openBotfather()
            }), viewType: viewType)
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
            var items:[ContextMenuItem] = []
            if value.number.hasPrefix("888") {
                if canCopy {
                    items.append(ContextSeparatorItem())
                }
                items.append(ContextMenuItem(strings().peerInfoPhoneAnonymousInfo, handler: {
                    execute(inapp: .external(link: "https://fragment.com", false))
                }, itemImage: MenuAnimation.menu_show_info.value, removeTail: false, overrideWidth: 200))
            }
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:value.label, copyMenuText: strings().textCopyLabelPhoneNumber, text: formatPhoneNumber(value.number), context: arguments.context, viewType: viewType, canCopy: canCopy, _copyToClipboard: {
                arguments.copy("+\(value.number)")
            }, contextItems: items)
        case let .userName(_, value, viewType):
            
            let link = "@\(value[0])"
            
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
            
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: strings().peerInfoUsername, copyMenuText: strings().textCopyLabelUsername, labelColor: theme.colors.text, text: text, context: arguments.context, viewType: viewType, detectLinks: true, isTextSelectable: value.count > 1, _copyToClipboard: {
                arguments.copy(link)
            }, linkInteractions: interactions)
        case let .businessLocation(_, peer, location, viewType):
            return PeerInfoLocationRowItem(initialSize, stableId: stableId.hashValue, context: arguments.context, peer: peer._asPeer(), location: location, viewType: viewType, open: {
                arguments.openLocation(peer._asPeer(), location)
            })
        case let .businessHours(_, peer, businessHours, revealed, displayMyZone, viewType):
            return PeerInfoHoursRowItem(initialSize, stableId: stableId.hashValue, context: arguments.context, revealed: revealed, peer: peer._asPeer(), businessHours: businessHours, displayLocalTimezone: displayMyZone, viewType: viewType, open: {
                arguments.openHours(peer._asPeer(), businessHours)
            }, toggleDisplayZoneTime: arguments.toggleDisplayZoneTime)
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
        case let .setPhoto(_, string, type, nextType, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: string, icon: type == .set ? theme.icons.contact_set_photo : theme.icons.contact_suggest_photo, nameStyle: blueActionButton, type: nextType, viewType: viewType, action: {
                arguments.updateContactPhoto(nil, control: nil, type: type)
            })
        case let .resetPhoto(_, string, image, user, viewType):
            return UserInfoResetPhotoItem(initialSize, stableId: stableId.hashValue, context: arguments.context, string: string, user: user, image: image, viewType: viewType, action: arguments.resetPhoto)
        case let .setPhotoInfo(_, string, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: string, viewType: viewType)
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
            return GeneralRowItem(initialSize, height: 20, stableId: stableId.hashValue, viewType: .separator)
        }
        
    }
    
}



func userInfoEntries(view: PeerView, arguments: PeerInfoArguments, mediaTabsData: PeerMediaTabsData, source: PeerInfoController.Source, stories: PeerExpiringStoryListContext.State?) -> [PeerInfoEntry] {
    
    let arguments = arguments as! UserInfoArguments
    let state = arguments.state as! UserInfoState
    
    var entries: [PeerInfoEntry] = []
    
    var sectionId:Int = 0
    entries.append(UserInfoEntry.section(sectionId: sectionId))
    sectionId += 1
    
    let editing = state.editingState != nil

    entries.append(UserInfoEntry.info(sectionId: sectionId, peerView: view, editable: editing, updatingPhotoState: state.updatingPhotoState, stories: stories, viewType: .singleItem))

    
    func applyBlock(_ block:[UserInfoEntry]) {
        var block = block
        for (i, item) in block.enumerated() {
            block[i] = item.withUpdatedViewType(bestGeneralViewType(block, for: i))
        }
        entries.append(contentsOf: block)
    }
    
    var headerBlock: [UserInfoEntry] = []
    
        
    
    if editing {
        headerBlock.append(.setFirstName(sectionId: sectionId, text: state.editingState?.editingFirstName ?? "", viewType: .singleItem))
        headerBlock.append(.setLastName(sectionId: sectionId, text: state.editingState?.editingLastName ?? "", placeholder: peerViewMainPeer(view)?.isBot == true ? strings().peerInfoDescriptionPlaceholder : strings().peerInfoLastNamePlaceholder, viewType: .singleItem))
    }
    
    applyBlock(headerBlock)
    
    
    
    entries.append(UserInfoEntry.section(sectionId: sectionId))
    sectionId += 1
    

    
    if let peer = view.peers[view.peerId] {
        
        if let user = peerViewMainPeer(view) as? TelegramUser {
            
            var destructBlock:[UserInfoEntry] = []
            var photoBlock:[UserInfoEntry] = []
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
                    infoBlock.append(.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: phoneNumber.hasPrefix("888") ? strings().peerInfoAnonymousPhone : strings().peerInfoPhone, number: phoneNumber), canCopy: true, viewType: .singleItem))
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
                
                if let cachedUserData = view.cachedData as? CachedUserData {
                    if let hours = cachedUserData.businessHours {
                        infoBlock.append(.businessHours(sectionId: sectionId, peer: .init(peer), businessHours: hours, revealed: state.businessHoursRevealed, displayMyZone: state.businessHoursDisplayMyTimezone, viewType: .singleItem))
                    }
                    if let location = cachedUserData.businessLocation {
                        infoBlock.append(.businessLocation(sectionId: sectionId, peer: .init(peer), businessLocation: location, viewType: .singleItem))
                    }
                }
                
                if !user.isBot {
                    if !view.peerIsContact, user.id != arguments.context.peerId {
                        infoBlock.append(.addContact(sectionId: sectionId, viewType: .singleItem))
                    }
                }
                if (peer is TelegramSecretChat) {
                    infoBlock.append(.encryptionKey(sectionId: sectionId, viewType: .singleItem))
                }
                if !user.isBot {
                    if !view.peerIsContact, user.id != arguments.context.peerId {
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
            
            if let cachedData = view.cachedData as? CachedUserData, arguments.context.account.peerId != arguments.peerId {
                if let _ = state.editingState {
                    
                    if peer.botInfo?.flags.contains(.canEdit) == true {
                        
                        entries.append(UserInfoEntry.botEditUsername(sectionId: sectionId, text: peer.addressName ?? "", viewType: .singleItem))
                        
                        entries.append(UserInfoEntry.section(sectionId: sectionId))
                        sectionId += 1
                        
                        destructBlock.append(.botEditIntro(sectionId: sectionId, viewType: .singleItem))
                        destructBlock.append(.botEditCommands(sectionId: sectionId, viewType: .singleItem))
                        destructBlock.append(.botEditSettings(sectionId: sectionId, viewType: .singleItem))

                    } else if view.peerIsContact {
                        photoBlock.append(.setPhoto(sectionId: sectionId, string: strings().userInfoSuggestPhoto(user.compactDisplayTitle), type: .suggest, nextType: state.suggestingPhotoState != nil ? .loading : .none, viewType: .singleItem))
                        photoBlock.append(.setPhoto(sectionId: sectionId, string: strings().userInfoSetPhoto(user.compactDisplayTitle), type: .set, nextType: .none, viewType: .singleItem))

                        if user.photo.contains(where: { $0.isPersonal }), let image = cachedData.photo {
                            photoBlock.append(.resetPhoto(sectionId: sectionId, string: strings().userInfoResetPhoto, image: image, user: user, viewType: .lastItem))
                        }
                    }
                    if !photoBlock.isEmpty {
                        entries.append(UserInfoEntry.setPhotoInfo(sectionId: sectionId, string: strings().userInfoSetPhotoBlockInfo(user.compactDisplayTitle), viewType: .textBottomItem))
                    }
                    if !photoBlock.isEmpty, peer is TelegramSecretChat || view.peerIsContact {
                        entries.append(UserInfoEntry.section(sectionId: sectionId))
                        sectionId += 1
                    }

                    if peer is TelegramSecretChat || view.peerIsContact {
                        destructBlock.append(.deleteContact(sectionId: sectionId, viewType: .singleItem))
                    }
                }
               
            }
            applyBlock(photoBlock)
            
            
            
            
            applyBlock(destructBlock)
            
            if peer.botInfo?.flags.contains(.canEdit) == true, state.editingState != nil {
                entries.append(UserInfoEntry.botEditInfo(sectionId: sectionId, viewType: .textBottomItem))
            }
            
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
