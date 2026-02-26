//
//  UserInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import CurrencyFormat
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

    
    func giftPremium(_ isBirthday: Bool) {
        showModal(with: GiftingController(context: context, peerId: self.effectivePeerId, isBirthday: isBirthday, starGiftsContext: getStarGiftsContext?()), for: context.window)
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
    
    func openApp() {
        if let peer {
            BrowserStateContext.get(context).open(tab: .mainapp(bot: .init(peer), source: .generic))
        }
    }
    func openBotfather() {
        self.editBot(nil, action: false)
    }
    func openEditBotUsername() {
        self.pullNavigation()?.push(EditBotUsernameController(context: context, peerId: peerId))
    }
    
    func openAffiliate(starRefProgram: TelegramStarRefProgram?) {
        if let starRefProgram, let peer, peer.botInfo?.flags.contains(.canEdit) == false {
            showModal(with: Affiliate_ProgramPreview(context: context, peerId: context.peerId, program: AffiliateProgram.init(starRefProgram, peer: .init(peer)), joined: { _ in
                
            }), for: context.window)
        } else {
            self.pullNavigation()?.push(Affiliate_StartController(context: context, peerId: peerId, starRefProgram: starRefProgram))
        }
    }
    
    func openVerifyAccounts(_ verification: BotVerifierSettings) {
        let context = self.context
        let botId = self.peerId
        
        
        selectModalPeers(window: context.window, context: context, title: strings().peerInfoVerifyAccounts, limit: 1, behavior: SelectChatsBehavior(settings: [.bots, .channels, .groups, .remote], excludePeerIds: [self.peerId], limit: 1), confirmation: { peerIds in
            
            return Signal { subscriber in
                
                if let peerId = peerIds.first {
                    
                    
                    let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId), TelegramEngine.EngineData.Item.Peer.Verification(id: peerId)) |> deliverOnMainQueue
                    
                    _ = peer.startStandalone(next: { peer, currentVerification in
                        if let peer {
                            
                            let limit = context.appConfiguration.getGeneralValue("bot_verification_description_length_limit", orElse: 70)
                            
                            var text: String = ""
                            
                            let title: String
                            let info: String
                            let ok: String
                            let footer: ModalAlertData.Footer?
                            if currentVerification?.botId == botId {
                                title = strings().botVerificationRemoveTitle
                                if peer._asPeer().isBot {
                                    info = strings().botVerificationRemoveBotText
                                } else if peer._asPeer().isChannel {
                                    info = strings().botVerificationRemoveChannelText
                                } else if peer._asPeer().isSupergroup {
                                    info = strings().botVerificationRemoveGroupText
                                } else {
                                    info = strings().botVerificationRemoveUserText
                                }
                                ok = strings().botVerificationRemoveRemove
                                footer = nil
                            } else {
                                if peer._asPeer().isBot {
                                    title = strings().botVerificationVerifyBotTitle
                                } else if peer._asPeer().isChannel {
                                    title = strings().botVerificationVerifyChannelTitle
                                } else if peer._asPeer().isSupergroup {
                                    title = strings().botVerificationVerifyGroupTitle
                                } else {
                                    title = strings().botVerificationVerifyUserTitle
                                }
                                if peer._asPeer().isBot {
                                    info = strings().botVerificationVerifyBotText
                                } else if peer._asPeer().isChannel {
                                    info = strings().botVerificationVerifyChannelText
                                } else if peer._asPeer().isSupergroup {
                                    info = strings().botVerificationVerifyGroupText
                                } else {
                                    info = strings().botVerificationVerifyUserText
                                }
                                ok = strings().botVerificationVerifyVerify
                                footer = .init(value: { initialSize, stableId, presentation, updateData in
                                    return InputDataRowItem(initialSize, stableId: 0, mode: .plain, error: nil, viewType: .singleItem, currentText: "", placeholder: nil, inputPlaceholder: strings().botVerificationVerifyPlaceholder, filter: { $0 }, updated: { updated in
                                        text = updated
                                        DispatchQueue.main.async(execute: updateData)
                                    }, limit: limit)
                                })
                            }
                                                        
                            let data = ModalAlertData(title: title, info: info, description: nil, ok: ok, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), footer: .init(value: { initialSize, stableId, presentation, _ in
                                return Bot_VerifyAccountRowItem(initialSize, stableId: stableId, peer: peer, context: context, fileId: verification.iconFileId)
                            }), footer1: footer)
                            
                            showModalAlert(for: context.window, data: data, completion: { result in
                                
                                let update: UpdateCustomVerificationValue
                                if currentVerification?.botId == botId {
                                    update = .disabled
                                } else {
                                    update = .enabled(description: text.isEmpty ? nil : text)
                                }
                                
                                subscriber.putNext(true)
                                subscriber.putCompletion()
                                
                                _ = showModalProgress(signal: context.engine.peers.updateCustomVerification(botId: botId, peerId: peerId, value: update), for: context.window).start(error: { error in
                                    switch error {
                                    case .generic:
                                        showModalText(for: context.window, text: strings().unknownError)
                                    }
                                }, completed: {
                                    if currentVerification?.botId == botId {
                                        showModalText(for: context.window, text: strings().botVerificationRemoved(peer._asPeer().displayTitle))
                                    } else {
                                        showModalText(for: context.window, text: strings().botVerificationAdded(peer._asPeer().displayTitle))
                                    }
                                })
                            }, onDeinit: {
                                
                            })
                        }
                    })
                }
                
                return EmptyDisposable
            }
        }).start(next: { peerIds in
            
            
        })
    }
    
    func openStarsBalance() {
        if let revenueContext = getStarsContext?() {
            self.pullNavigation()?.push(FragmentStarMonetizationController(context: context, peerId: peerId, revenueContext: revenueContext))
        }
    }
    
    func openTonBalance() {
        if let revenueContext = getTonContext?() {
            self.pullNavigation()?.push(FragmentMonetizationController(context: context, peerId: peerId, onlyTonContext: revenueContext))
        }
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
    
    func togglePermissionsStatus() {
        _ = self.context.engine.peers.toggleBotEmojiStatusAccess(peerId: self.peerId, enabled: false).start()
    }
    func togglePermissionsGeo() {
        let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: peerId) { current in
            return WebAppPermissionsState(location: WebAppPermissionsState.Location(isRequested: true, isAllowed: !(current?.location?.isAllowed ?? false)), emojiStatus: nil)
        }.start()
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
            showModal(with: LocationModalPreview(context, map: .init(latitude: coordinates.latitude, longitude: coordinates.longitude, heading: nil, accuracyRadius: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil), peer: peer, messageId: nil), for: context.window)
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
    
    func openPersonalChannel(_ item: UserInfoPersonalChannel) {
        self.pullNavigation()?.push(ChatAdditionController(context: context, chatLocation: .peer(item.peer.id)))
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
    
    func giftBirthday() {
        let context = self.context
        
        let peerId = self.peerId
        
        multigift(context: context, selected: [peerId])
        
    }
    
    func botSettings() {
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/settings"), context: context, peerId: peerId, replyId: nil, threadId: nil).start()
        pullNavigation()?.back()
    }
    func botHelp() {
        _ = Sender.enqueue(input: ChatTextInputState(inputText: "/help"), context: context, peerId: peerId, replyId: nil, threadId: nil).start()
        pullNavigation()?.back()
    }
    
    func reportBot() {
        let peerId = self.peerId
        let context = self.context
        
        reportComplicated(context: context, subject: .peer(peerId), title: strings().reportComplicatedPeerTitle(self.peer?.displayTitle ?? ""))
        
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
        
        let signal = combineLatest(peer, premiumRequired) |> castError(CreateSecretChatError.self) |> deliverOnMainQueue |> mapToSignal { peer, premiumRequired -> Signal<PeerId?, CreateSecretChatError> in
            if !context.isPremium && premiumRequired {
                return .single(nil)
            }
            let confirm = verifyAlertSignal(for: context.window, header: strings().peerInfoConfirmSecretChatHeader, information: strings().peerInfoConfirmStartSecretChat(peer.displayTitle), ok: strings().peerInfoConfirmSecretChatOK) |> castError(CreateSecretChatError.self)
            return confirm |> filter { $0 == .basic } |> mapToSignal { _ -> Signal<PeerId?, CreateSecretChatError> in
                return showModalProgress(signal: context.engine.peers.createSecretChat(peerId: peer.id), for: context.window) |> map(Optional.init)
            }
        } |> deliverOnMainQueue
        
        
        
        startSecretChatDisposable.set(signal.start(next: { [weak self] peerId in
            if let strongSelf = self {
                if let peerId = peerId {
                    strongSelf.pushViewController(ChatController(context: strongSelf.context, chatLocation: .peer(peerId)))
                }
            }
        }, error: { error in
            switch error {
            case .generic:
                showModalText(for: context.window, text: strings().unknownError)
            case .limitExceeded:
                showModalText(for: context.window, text: strings().loginFloodWait)
            case let .premiumRequired(peer):
                showModalText(for: context.window, text: strings().chatSecretChatPremiumRequired(peer._asPeer().compactDisplayTitle), button: strings().alertLearnMore, callback: { _ in
                    prem(with: PremiumBoardingController(context: context), for: context.window)
                })
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
                let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square, circle: true), confirm: { url, f in
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
                let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square, circle: true), confirm: { url, f in
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

struct UserInfoAddress : Equatable {
    let username: String
    let collectable: Bool
}

enum UserInfoEntry: PeerInfoEntry {
    case info(sectionId:Int, peerView: PeerView, editable:Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?, stories: PeerExpiringStoryListContext.State?, viewType: GeneralViewType)
    case personalChannelInfo(sectionId:Int, left: String, right: String, viewType: GeneralViewType)
    case personalChannel(sectionId:Int, item: UserInfoPersonalChannel, viewType: GeneralViewType)
    case setFirstName(sectionId:Int, text: String, viewType: GeneralViewType)
    case setLastName(sectionId:Int, text: String, placeholder: String, viewType: GeneralViewType)
    case about(sectionId:Int, text: String, launchApp: Bool, viewType: GeneralViewType)
    case aboutInfo(sectionId:Int, text: String, viewType: GeneralViewType)
    case botStarsBalance(sectionId:Int, text: String, viewType: GeneralViewType)
    case botTonBalance(sectionId:Int, text: String, viewType: GeneralViewType)
    case botPermissionsHeader(sectionId:Int, text: String, viewType: GeneralViewType)
    case botPermissionsStatus(sectionId:Int, value: Bool, viewType: GeneralViewType)
    case botPermissionsGeo(sectionId:Int, value: Bool, viewType: GeneralViewType)
    case botEditUsername(sectionId:Int, text: String, viewType: GeneralViewType)
    case botAffiliate(sectionId:Int, text: String, starRefProgram: TelegramStarRefProgram?, viewType: GeneralViewType)
    case verifyAccounts(sectionId:Int, verification: BotVerifierSettings, viewType: GeneralViewType)
    case botEditIntro(sectionId:Int, viewType: GeneralViewType)
    case botEditCommands(sectionId:Int, viewType: GeneralViewType)
    case botEditSettings(sectionId:Int, viewType: GeneralViewType)
    case botEditInfo(sectionId:Int, viewType: GeneralViewType)
    case bio(sectionId:Int, text: String, PeerEquatable, viewType: GeneralViewType)
    case birthday(sectionId:Int, text: String, Bool, viewType: GeneralViewType)
    case scam(sectionId:Int, title: String, text: String, viewType: GeneralViewType)
    case phoneNumber(sectionId:Int, index: Int, value: PhoneNumberWithLabel, canCopy: Bool, viewType: GeneralViewType)
    case peerId(sectionId:Int, value: String, viewType: GeneralViewType)
    case userName(sectionId:Int, value: [UserInfoAddress], viewType: GeneralViewType)
    case verifiedInfo(sectionId: Int, value: PeerVerification?, viewType: GeneralViewType)
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
    
    var viewType: GeneralViewType {
        switch self {
        case .info(_, _, _, _, _, let viewType):
            return viewType
        case .personalChannelInfo(_, _, _, let viewType):
            return viewType
        case .personalChannel(_, _, let viewType):
            return viewType
        case .setFirstName(_, _, let viewType):
            return viewType
        case .setLastName(_, _, _, let viewType):
            return viewType
        case .about(_, _, _, let viewType):
            return viewType
        case .aboutInfo(_, _, let viewType):
            return viewType
        case .botStarsBalance(_, _, let viewType):
            return viewType
        case .botTonBalance(_, _, let viewType):
            return viewType
        case .botPermissionsHeader(_, _, let viewType):
            return viewType
        case .botPermissionsStatus(_, _, let viewType):
            return viewType
        case .botPermissionsGeo(_, _, let viewType):
            return viewType
        case .botEditUsername(_, _, let viewType):
            return viewType
        case .botAffiliate(_, _, _, let viewType):
            return viewType
        case .verifyAccounts(_, _, let viewType):
            return viewType
        case .botEditIntro(_, let viewType):
            return viewType
        case .botEditCommands(_, let viewType):
            return viewType
        case .botEditSettings(_, let viewType):
            return viewType
        case .botEditInfo(_, let viewType):
            return viewType
        case .bio(_, _, _, let viewType):
            return viewType
        case .birthday(_, _, _, let viewType):
            return viewType
        case .scam(_, _, _, let viewType):
            return viewType
        case .phoneNumber(_, _, _, _, let viewType):
            return viewType
        case .peerId(_, _, let viewType):
            return viewType
        case .userName(_, _, let viewType):
            return viewType
        case .verifiedInfo(_, _, let viewType):
            return viewType
        case .businessLocation(_, _, _, let viewType):
            return viewType
        case .businessHours(_, _, _, _, _, let viewType):
            return viewType
        case .reportReaction(_,_, let viewType):
            return viewType
        case .sendMessage(_, let viewType):
            return viewType
        case .shareContact(_, let viewType):
            return viewType
        case .shareMyInfo(_, let viewType):
            return viewType
        case .addContact(_, let viewType):
            return viewType
        case .botAddToGroup(_, let viewType):
            return viewType
        case .botAddToGroupInfo(_, let viewType):
            return viewType
        case .botShare(_, _, let viewType):
            return viewType
        case .botHelp(_, let viewType):
            return viewType
        case .botSettings(_, let viewType):
            return viewType
        case .botPrivacy(_, let viewType):
            return viewType
        case .startSecretChat(_, let viewType):
            return viewType
        case .sharedMedia(_, let viewType):
            return viewType
        case .notifications(_, _, let viewType):
            return viewType
        case .groupInCommon(_, _, _, let viewType):
            return viewType
        case .setPhoto(_, _, _, _, let viewType):
            return viewType
        case .resetPhoto(_, _, _, _, let viewType):
            return viewType
        case .setPhotoInfo(_, _, let viewType):
            return viewType
        case .block(_, _, _, _, let viewType):
            return viewType
        case .deleteChat(_, let viewType):
            return viewType
        case .deleteContact(_, let viewType):
            return viewType
        case .encryptionKey(_, let viewType):
            return viewType
        case .media(_, _, _, let viewType):
            return viewType
        case .section(_):
            return .legacy
        }
    }
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> UserInfoEntry {
        switch self {
        case let .info(sectionId, peerView, editable, updatingPhotoState, stories, _): return .info(sectionId: sectionId, peerView: peerView, editable: editable, updatingPhotoState: updatingPhotoState, stories: stories, viewType: viewType)
        case let .personalChannelInfo(sectionId, left, right, _): return .personalChannelInfo(sectionId: sectionId, left: left, right: right, viewType: viewType)
        case let .personalChannel(sectionId, item, _): return .personalChannel(sectionId: sectionId, item: item, viewType: viewType)
        case let .setFirstName(sectionId, text, _): return .setFirstName(sectionId: sectionId, text: text, viewType: viewType)
        case let .setLastName(sectionId, text, placeholder, _): return .setLastName(sectionId: sectionId, text: text, placeholder: placeholder, viewType: viewType)
        case let .botStarsBalance(sectionId, text, _): return .botStarsBalance(sectionId: sectionId, text: text, viewType: viewType)
        case let .botTonBalance(sectionId, text, _): return .botTonBalance(sectionId: sectionId, text: text, viewType: viewType)
        case let .botPermissionsHeader(sectionId, text, _): return .botPermissionsHeader(sectionId: sectionId, text: text, viewType: viewType)
        case let .botPermissionsStatus(sectionId, value, _): return .botPermissionsStatus(sectionId: sectionId, value: value, viewType: viewType)
        case let .botPermissionsGeo(sectionId, value, _): return .botPermissionsGeo(sectionId: sectionId, value: value, viewType: viewType)
        case let .botEditUsername(sectionId, text, _): return .botEditUsername(sectionId: sectionId, text: text, viewType: viewType)
        case let .botAffiliate(sectionId, text, starRefProgram, _): return .botAffiliate(sectionId: sectionId, text: text, starRefProgram: starRefProgram, viewType: viewType)
        case let .verifyAccounts(sectionId, verification, _): return .verifyAccounts(sectionId: sectionId, verification: verification, viewType: viewType)
        case let .botEditIntro(sectionId, _): return .botEditIntro(sectionId: sectionId, viewType: viewType)
        case let .botEditCommands(sectionId, _): return .botEditCommands(sectionId: sectionId, viewType: viewType)
        case let .botEditSettings(sectionId, _): return .botEditSettings(sectionId: sectionId, viewType: viewType)
        case let .botEditInfo(sectionId, _): return .botEditInfo(sectionId: sectionId, viewType: viewType)
        case let .about(sectionId, text, launchApp, _): return .about(sectionId: sectionId, text: text, launchApp: launchApp, viewType: viewType)
        case let .aboutInfo(sectionId, text, _): return .aboutInfo(sectionId: sectionId, text: text, viewType: viewType)
        case let .bio(sectionId, text, peer, _): return .bio(sectionId: sectionId, text: text, peer, viewType: viewType)
        case let .birthday(sectionId, text, peer, _): return .birthday(sectionId: sectionId, text: text, peer, viewType: viewType)
        case let .scam(sectionId, title, text, _): return .scam(sectionId: sectionId, title: title, text: text, viewType: viewType)
        case let .phoneNumber(sectionId, index, value, canCopy, _): return .phoneNumber(sectionId: sectionId, index: index, value: value, canCopy: canCopy, viewType: viewType)
        case let .userName(sectionId, value, _): return .userName(sectionId: sectionId, value: value, viewType: viewType)
        case let .verifiedInfo(sectionId, value, _): return .verifiedInfo(sectionId: sectionId, value: value, viewType: viewType)
        case let .peerId(sectionId, value, _): return .peerId(sectionId: sectionId, value: value, viewType: viewType)
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
        case let .personalChannelInfo(sectionId, left, right, viewType):
            if case .personalChannelInfo(sectionId, left, right, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .personalChannel(sectionId, item, viewType):
            if case .personalChannel(sectionId, item, viewType) = entry {
                return true
            } else {
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
        case let .botStarsBalance(sectionId, text, viewType):
            switch entry {
            case .botStarsBalance(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .botTonBalance(sectionId, text, viewType):
            switch entry {
            case .botTonBalance(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .botPermissionsHeader(sectionId, text, viewType):
            switch entry {
            case .botPermissionsHeader(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .botPermissionsStatus(sectionId, value, viewType):
            switch entry {
            case .botPermissionsStatus(sectionId, value, viewType):
                return true
            default:
                return false
            }
        case let .botPermissionsGeo(sectionId, value, viewType):
            switch entry {
            case .botPermissionsGeo(sectionId, value, viewType):
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
        case let .botAffiliate(sectionId, text, starRefProgram, viewType):
            switch entry {
            case .botAffiliate(sectionId, text, starRefProgram, viewType):
                return true
            default:
                return false
            }
        case let .verifyAccounts(sectionId, text, viewType):
            switch entry {
            case .verifyAccounts(sectionId, text, viewType):
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
        case let .about(sectionId, text, launchLink, viewType):
            switch entry {
            case .about(sectionId, text, launchLink, viewType):
                return true
            default:
                return false
            }
        case let .aboutInfo(sectionId, text, viewType):
            switch entry {
            case .aboutInfo(sectionId, text, viewType):
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
        case let .birthday(sectionId, text, peer, viewType):
            switch entry {
            case .birthday(sectionId, text, peer, viewType):
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
        case let .verifiedInfo(sectionId, value, viewType):
            switch entry {
            case .verifiedInfo(sectionId, value, viewType):
                return true
            default:
                return false
            }
        case let .peerId(sectionId, value, viewType):
            switch entry {
            case .peerId(sectionId, value, viewType):
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
        case .personalChannelInfo:
            return 101
        case .personalChannel:
            return 102
        case .setFirstName:
            return 103
        case .setLastName:
            return 104
        case .botEditUsername:
            return 105
        case .botAffiliate:
            return 106
        case .verifyAccounts:
            return 107
        case .botStarsBalance:
            return 108
        case .botTonBalance:
            return 109
        case .botPermissionsHeader:
            return 110
        case .botPermissionsStatus:
            return 111
        case .botPermissionsGeo:
            return 112
        case .botEditIntro:
            return 113
        case .botEditCommands:
            return 114
        case .botEditSettings:
            return 115
        case .botEditInfo:
            return 116
        case .userName:
            return 117
        case .scam:
            return 118
        case .about:
            return 119
        case .aboutInfo:
            return 120
        case .bio:
            return 121
        case .phoneNumber:
            return 122
        case .birthday:
            return 123
        case .peerId:
            return 124
        case .businessHours:
            return 125
        case .businessLocation:
            return 126
        case .sendMessage:
            return 127
        case .botAddToGroup:
            return 128
        case .botAddToGroupInfo:
            return 129
        case .botShare:
            return 130
        case .botSettings:
            return 131
        case .botHelp:
            return 132
        case .botPrivacy:
            return 133
        case .shareContact:
            return 134
        case .shareMyInfo:
            return 135
        case .addContact:
            return 136
        case .startSecretChat:
            return 137
        case .sharedMedia:
            return 138
        case .notifications:
            return 139
        case .encryptionKey:
            return 140
        case .groupInCommon:
            return 141
        case let .setPhoto(_, _, type, _, _):
            return 142 + type.rawValue
        case .resetPhoto:
            return 146
        case .setPhotoInfo:
            return 147
        case .block:
            return 148
        case .reportReaction:
            return 149
        case .deleteChat:
            return 150
        case .deleteContact:
            return 151
        case .verifiedInfo:
            return 152
        case .media:
            return 153
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    private var sortIndex:Int {
        switch self {
        case let .info(sectionId, _, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .personalChannelInfo(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .personalChannel(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setFirstName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setLastName(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditUsername(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botAffiliate(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .verifyAccounts(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botStarsBalance(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botTonBalance(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botPermissionsHeader(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botPermissionsStatus(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botPermissionsGeo(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditIntro(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditCommands(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditSettings(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .botEditInfo(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .about(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .aboutInfo(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .bio(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .birthday(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .phoneNumber(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .userName(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .verifiedInfo(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .peerId(sectionId, _, _):
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
            }, giftsContext: arguments.getStarGiftsContext?())
        case let .personalChannelInfo(_, left, right, viewType):
            return GeneralTextRowItem(initialSize, text: left, viewType: viewType, rightItem: .init(isLoading: false, text: .initialize(string: right, color: theme.colors.listGrayText, font: .normal(.small))))
        case let .personalChannel(_, item, viewType):
            return PersonalChannelRowItem(initialSize, stableId: stableId.hashValue, context: arguments.context, item: item, viewType: viewType, action: {
                arguments.openPersonalChannel(item)
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
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotEditUsername, icon: theme.icons.peerInfoBotUsername, type: .nextContext("@\(text)"), viewType: viewType, action: arguments.openEditBotUsername)
        case let .botAffiliate(_, text, starRefProgram, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotAffiliate, icon: NSImage(resource: .iconBotAffiliate).precomposed(flipVertical: true), type: .nextContext(text), viewType: viewType, action: {
                arguments.openAffiliate(starRefProgram: starRefProgram)
            })
        case let .verifyAccounts(_, verification, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoVerifyAccounts, icon: NSImage(resource: .iconPeerInfoVerifyAccounts).precomposed(theme.colors.accent, flipVertical: true), type: .nextContext(""), viewType: viewType, action: {
                arguments.openVerifyAccounts(verification)
            })
        case let .botStarsBalance(_, text, viewType):
            let icon = generateStarBalanceIcon(text)
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotEditStarsBalanceNew, icon: theme.icons.peerInfoStarsBalance, type: .nextImage(icon), viewType: viewType, action: arguments.openStarsBalance)
        case let .botTonBalance(_, text, viewType):
            let icon = generateTonBalanceIcon(text)
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotEditTonBalance, icon: theme.icons.peerInfoTonBalance, type: .nextImage(icon), viewType: viewType, action: arguments.openTonBalance)
        case let .botPermissionsHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: .plain(text), viewType: viewType)
        case let .botPermissionsStatus(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotPermissionsStatus, icon: NSImage(named: "Icon_PeerInfo_BotStatus")?.precomposed(flipVertical: true), type: .switchable(value), viewType: viewType, action: {
                arguments.togglePermissionsStatus()
                //arguments.editBot("intro")
            })
        case let .botPermissionsGeo(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: strings().peerInfoBotPermissionsGeo, icon: NSImage(named: "Icon_PeerInfo_BotLocation")?.precomposed(flipVertical: true), type: .switchable(value), viewType: viewType, action: {
                arguments.togglePermissionsGeo()
                //arguments.editBot("intro")
            })
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
        case let .about(_, text, launchApp, viewType):
            if text.isEmpty {
                return GeneralActionButtonRowItem.init(initialSize, stableId: stableId.hashValue, text: strings().botInfoOpenApp, viewType: viewType, action: arguments.openApp)
            } else {
                return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: strings().peerInfoAbout, copyMenuText: strings().textCopyLabelAbout, text:text, context: arguments.context, viewType: viewType, detectLinks: true, openInfo: { peerId, toChat, postId, _ in
                    if toChat {
                        arguments.peerChat(peerId, postId: postId)
                    } else {
                        arguments.peerInfo(peerId)
                    }
                }, hashtag: { hashtag in
                    arguments.context.bindings.globalSearch(hashtag, arguments.peerId, nil)
                }, launchApp: launchApp ? arguments.openApp : nil, canTranslate: true)
            }
        case let .aboutInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: .markdown(text, linkHandler: { link in
                execute(inapp: .external(link: link, false))
            }), viewType: viewType)
        case let .bio(_, text, peer, viewType):
            return TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: strings().peerInfoBio, copyMenuText: strings().textCopyLabelBio, text:text, context: arguments.context, viewType: viewType, detectLinks: true, onlyInApp: !peer.peer.isPremium, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            }, hashtag: { value in
                arguments.context.bindings.globalSearch(value, nil, nil)
            }, canTranslate: true)
        case let .verifiedInfo(_, value, viewType):
            let attr = NSMutableAttributedString()
            
            let text: String
            if let value {
                text = "\(clown) \(value.description)"
            } else {
                text = strings().peerInfoVerified(clown)
            }
            
            
            
            attr.append(string: text, color: theme.colors.listGrayText, font: .normal(.text))

            if let value {
                InlineStickerItem.apply(to: attr, associatedMedia: [:], entities: [.init(range: 0..<2, type: .CustomEmoji(stickerPack: nil, fileId: value.iconFileId))], isPremium: true)
            } else {
                attr.insertEmbedded(.embedded(name: "Icon_Verified_Telegram", color: theme.colors.grayIcon, resize: false), for: clown)
            }
            attr.detectLinks(type: [.Links], color: theme.colors.listGrayText)

            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: .attributed(attr), viewType: viewType, context: arguments.context)
        case let .birthday(_, text, canBirth, viewType):
            return  TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: strings().peerInfoBirthday, copyMenuText: strings().textCopyLabelBio, text:text, context: arguments.context, viewType: viewType, gift: canBirth ? arguments.giftBirthday : nil)
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
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:value.label, copyMenuText: strings().textCopyLabelPhoneNumber, text: formatPhoneNumber(context: arguments.context, number: value.number), context: arguments.context, viewType: viewType, canCopy: canCopy, _copyToClipboard: {
                
                if value.number.hasPrefix("888") {
                    arguments.openFragment(.phoneNumber(value.number))
                } else {
                    arguments.copy("+\(value.number)")
                }
            }, contextItems: items)
        case let .userName(_, value, viewType):
            
            let link = "@\(value[0].username)"
            
            let text: String
            if value.count > 1 {
                text = strings().peerInfoUsernamesList("@\(value[0].username)", value.suffix(value.count - 1).map { "@\($0.username)" }.joined(separator: ", "))
            } else {
                text = "@\(value[0].username)"
            }
            
            let interactions = TextViewInteractions()
            interactions.processURL = { link in
                if let link = link as? inAppLink {
                    let found = value.first(where: {  $0.username == link.link.replacingOccurrences(of: "@", with: "") })
                    if let found {
                        arguments.openFragment(.username(found.username))
                    } else {
                        arguments.copy(link.link)
                    }
                }
            }
            interactions.localizeLinkCopy = globalLinkExecutor.localizeLinkCopy
            
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: strings().peerInfoUsername, copyMenuText: strings().textCopyLabelUsername, labelColor: theme.colors.text, text: text, context: arguments.context, viewType: viewType, detectLinks: true, isTextSelectable: value.count > 1, _copyToClipboard: {
                arguments.copy(link)
            }, linkInteractions: interactions)
        case let .peerId(_, value, viewType):
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: "PEER ID", copyMenuText: strings().textCopyText, text: value, context: arguments.context, viewType: viewType, canCopy: true, _copyToClipboard: {
                arguments.copy(value)
            })
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



func userInfoEntries(view: PeerView, arguments: PeerInfoArguments, mediaTabsData: PeerMediaTabsData, source: PeerInfoController.Source, stories: PeerExpiringStoryListContext.State?, personalChannel: UserInfoPersonalChannel?, revenueState: StarsRevenueStatsContextState?, tonRevenueState: StarsRevenueStatsContextState?, webAppPermissionsState: WebAppPermissionsState?) -> [PeerInfoEntry] {
    
    let arguments = arguments as! UserInfoArguments
    let state = arguments.state as! UserInfoState
    
    var entries: [PeerInfoEntry] = []
    
    var sectionId:Int = 0
    entries.append(UserInfoEntry.section(sectionId: sectionId))
    sectionId += 1
    
    let editing = state.editingState != nil

    entries.append(UserInfoEntry.info(sectionId: sectionId, peerView: view, editable: editing, updatingPhotoState: state.updatingPhotoState, stories: stories, viewType: .singleItem))

    
    if let personalChannel, !editing {
        entries.append(UserInfoEntry.section(sectionId: sectionId))
        sectionId += 1
        
        let right: String
        if let subscribers = personalChannel.subscribers {
            let membersLocalized: String = strings().peerStatusSubscribersCountable(Int(subscribers))
            right = membersLocalized.replacingOccurrences(of: "\(subscribers)", with: subscribers.formattedWithSeparator).uppercased()
        } else {
            right = ""
        }
        
        entries.append(UserInfoEntry.personalChannelInfo(sectionId: sectionId, left: strings().peerInfoPersonalChannelTitle, right: right, viewType: .textTopItem))
        entries.append(UserInfoEntry.personalChannel(sectionId: sectionId, item: personalChannel, viewType: .singleItem))
    }
    
    func applyBlock(_ block:[UserInfoEntry]) {
        var block = block.sorted { (p1, p2) -> Bool in
            return p1.isOrderedBefore(p2)
        }
        
        var filtered = block.filter({
            return $0.viewType == .singleItem || $0.viewType == .firstItem || $0.viewType == .lastItem || $0.viewType == .innerItem
        })
        
        let restItems = block.filter({
            return $0.viewType != .singleItem && $0.viewType != .firstItem && $0.viewType != .lastItem && $0.viewType != .innerItem
        })
        
        for (i, item) in filtered.enumerated() {
            filtered[i] = item.withUpdatedViewType(bestGeneralViewType(filtered, for: i))
        }
        if filtered.count != block.count {
            filtered.append(contentsOf: restItems)
        }
        entries.append(contentsOf: filtered)
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
                
                if let phoneNumber = user.phone, !phoneNumber.isEmpty {
                    infoBlock.append(.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: phoneNumber.hasPrefix("888") ? strings().peerInfoAnonymousPhone : strings().peerInfoPhone, number: phoneNumber), canCopy: true, viewType: .singleItem))
                } else if view.peerIsContact {
                    infoBlock.append(.phoneNumber(sectionId: sectionId, index: 0, value: PhoneNumberWithLabel(label: strings().peerInfoPhone, number: strings().newContactPhoneHidden), canCopy: false, viewType: .singleItem))
                }
                
                if let cachedUserData = view.cachedData as? CachedUserData {
                    
                    if let about = cachedUserData.about, !about.isEmpty, !user.isScam && !user.isFake {
                        if let botInfo = peer.botInfo {
                            infoBlock.append(UserInfoEntry.about(sectionId: sectionId, text: about, launchApp: botInfo.flags.contains(.hasWebApp), viewType: .singleItem))
                            if botInfo.flags.contains(.canEdit) {
                                infoBlock.append(UserInfoEntry.aboutInfo(sectionId: sectionId, text: strings().botInfoLaunchInfo, viewType: .textBottomItem))
                            } else {
                                let privacyPolicyUrl = cachedUserData.botInfo?.privacyPolicyUrl ?? strings().botInfoLaunchInfoPrivacyUrl
                                infoBlock.append(UserInfoEntry.aboutInfo(sectionId: sectionId, text: strings().botInfoLaunchInfoUser(privacyPolicyUrl), viewType: .textBottomItem))
                                
                            }
                        } else {
                            infoBlock.append(UserInfoEntry.bio(sectionId: sectionId, text: about, PeerEquatable(peer), viewType: .singleItem))
                        }
                    } else if cachedUserData.about == nil, let botInfo = peer.botInfo, botInfo.flags.contains(.hasWebApp) {
                        infoBlock.append(UserInfoEntry.about(sectionId: sectionId, text: "", launchApp: botInfo.flags.contains(.hasWebApp), viewType: .singleItem))
                        if botInfo.flags.contains(.canEdit) {
                            infoBlock.append(UserInfoEntry.aboutInfo(sectionId: sectionId, text: strings().botInfoLaunchInfo, viewType: .textBottomItem))
                        } else {
                            let privacyPolicyUrl = cachedUserData.botInfo?.privacyPolicyUrl ?? strings().botInfoLaunchInfoPrivacyUrl
                            infoBlock.append(UserInfoEntry.aboutInfo(sectionId: sectionId, text: strings().botInfoLaunchInfoUser(privacyPolicyUrl), viewType: .textBottomItem))
                            
                        }
                    }
                    
                }
                

                
                var usernames:[UserInfoAddress] = user.usernames.filter { $0.isActive }.map {
                    .init(username: $0.username, collectable: $0.flags.contains(.isEditable))
                }
                if usernames.isEmpty, let address = user.addressName {
                    usernames.append(.init(username: address, collectable: false))
                }
                if !usernames.isEmpty {
                    infoBlock.append(.userName(sectionId: sectionId, value: usernames, viewType: .singleItem))
                }
                
          
                
                if let cachedUserData = view.cachedData as? CachedUserData {
                    if let birthday = cachedUserData.birthday {
                        infoBlock.append(.birthday(sectionId: sectionId, text: birthday.formattedYears, birthday.isEligble, viewType: .singleItem))
                    }
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
                }
               
                if user.isVerified || (view.cachedData as? CachedUserData)?.verification != nil {
                    infoBlock.append(UserInfoEntry.verifiedInfo(sectionId: sectionId, value: (view.cachedData as? CachedUserData)?.verification, viewType: .textBottomItem))
                }

                
                applyBlock(infoBlock)
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.worksWithGroups) {
                    entries.append(UserInfoEntry.section(sectionId: sectionId))
                    sectionId += 1
                    entries.append(UserInfoEntry.botAddToGroup(sectionId: sectionId, viewType: .singleItem))
                    entries.append(UserInfoEntry.botAddToGroupInfo(sectionId: sectionId, viewType: .textBottomItem))
                }
                
            }
            
            if let cachedData = view.cachedData as? CachedUserData, arguments.context.account.peerId != arguments.peerId {
                if let _ = state.editingState {
                    
                    if peer.botInfo?.flags.contains(.canEdit) == true {
                        let affiliateEnabled = arguments.context.appConfiguration.getBoolValue("starref_program_allowed", orElse: false)

                        entries.append(UserInfoEntry.botEditUsername(sectionId: sectionId, text: peer.addressName ?? "", viewType: affiliateEnabled ? .firstItem : .singleItem))
                        let text: String
                        if let program = cachedData.starRefProgram {
                            let localizedDuration: String
                            if let duration = program.durationMonths {
                                localizedDuration = duration < 12 ? strings().timerMonthsCountable(Int(duration)) : strings().timerYearsCountable(Int(duration / 12))
                            } else {
                                localizedDuration = strings().affiliateProgramDurationLifetime
                            }
                            text = "\(program.commissionPermille.decemial)%, \(localizedDuration)"
                        } else {
                            text = strings().affiliateProgramOff
                        }
                        if affiliateEnabled {
                            entries.append(UserInfoEntry.botAffiliate(sectionId: sectionId, text: text, starRefProgram: cachedData.starRefProgram, viewType: .lastItem))
                        }
                        entries.append(UserInfoEntry.section(sectionId: sectionId))
                        sectionId += 1
                        
                        if peer.isBot, let info = cachedData.botInfo, let settings = info.verifierSettings {
                            entries.append(UserInfoEntry.verifyAccounts(sectionId: sectionId, verification: settings, viewType: .singleItem))
                            entries.append(UserInfoEntry.section(sectionId: sectionId))
                            sectionId += 1
                        }

                        
                        destructBlock.append(.botEditIntro(sectionId: sectionId, viewType: .singleItem))
                        destructBlock.append(.botEditCommands(sectionId: sectionId, viewType: .singleItem))
                        destructBlock.append(.botEditSettings(sectionId: sectionId, viewType: .singleItem))

                    } else if view.peerIsContact, peer.sendPaidMessageStars == nil {
                        photoBlock.append(.setPhoto(sectionId: sectionId, string: strings().userInfoSuggestPhoto(user.compactDisplayTitle), type: .suggest, nextType: state.suggestingPhotoState != nil ? .loading : .none, viewType: .singleItem))
                        photoBlock.append(.setPhoto(sectionId: sectionId, string: strings().userInfoSetPhoto(user.compactDisplayTitle), type: .set, nextType: .none, viewType: .singleItem))

                        if user.photo.contains(where: { $0.isPersonal }), let image = cachedData.photo {
                            photoBlock.append(.resetPhoto(sectionId: sectionId, string: strings().userInfoResetPhoto, image: image, user: user, viewType: .lastItem))
                        }
                    }
                    
                    
                   
                    entries.append(UserInfoEntry.section(sectionId: sectionId))
                    sectionId += 1
                    
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
                } else {
                    if peer.botInfo?.flags.contains(.canEdit) == false, cachedData.starRefProgram != nil {
                        let affiliateEnabled = arguments.context.appConfiguration.getBoolValue("starref_connect_allowed", orElse: false)

                        let text: String
                        if let program = cachedData.starRefProgram {
                            let localizedDuration: String
                            if let duration = program.durationMonths {
                                localizedDuration = duration < 12 ? strings().timerMonthsCountable(Int(duration)) : strings().timerYearsCountable(Int(duration / 12))
                            } else {
                                localizedDuration = strings().affiliateProgramDurationLifetime
                            }
                            text = "\(program.commissionPermille.decemial)%, \(localizedDuration)"
                        } else {
                            text = strings().affiliateProgramOff
                        }
                        if affiliateEnabled {
                            entries.append(UserInfoEntry.botAffiliate(sectionId: sectionId, text: text, starRefProgram: cachedData.starRefProgram, viewType: .firstItem))
                        }
                    }
                }
               
            }
            applyBlock(photoBlock)
            
            
            
            
            applyBlock(destructBlock)
            
            if peer.botInfo?.flags.contains(.canEdit) == true, state.editingState != nil {
                entries.append(UserInfoEntry.botEditInfo(sectionId: sectionId, viewType: .textBottomItem))
            }
            
            
            if let cachedData = (view.cachedData as? CachedUserData) {
                
               
                
                let starBalance = (revenueState?.stats?.balances.currentBalance.amount.value ?? 0)
                let tonBalance = (tonRevenueState?.stats?.balances.currentBalance.amount.value ?? 0)

                let hasStars = (revenueState?.stats?.balances.overallRevenue.amount.value ?? 0) > 0
                let hasTon = (tonRevenueState?.stats?.balances.overallRevenue.amount.value ?? 0) > 0

                
                if hasStars || hasTon {
                    entries.append(UserInfoEntry.section(sectionId: sectionId))
                    sectionId += 1
                    

                    if hasStars {
                        entries.append(UserInfoEntry.botStarsBalance(sectionId: sectionId, text: starBalance == 0 ? "" : strings().peerInfoBotEditStarsCountCountable(Int(starBalance)).replacingOccurrences(of: "\(starBalance)", with: starBalance.formattedWithSeparator), viewType: hasTon ? .firstItem : .singleItem))
                    }
                    
                    if hasTon {
                        let balance = formatCurrencyAmount(tonBalance, currency: TON).prettyCurrencyNumberUsd
                        entries.append(UserInfoEntry.botTonBalance(sectionId: sectionId, text: "\(balance)", viewType: hasStars ? .lastItem : .singleItem))
                    }
                }
                
                var addHeader: Bool = true
                
                let addPermissionHeader:()->Void = {
                    entries.append(UserInfoEntry.section(sectionId: sectionId))
                    sectionId += 1
                    
                    entries.append(UserInfoEntry.botPermissionsHeader(sectionId: sectionId, text: strings().peerInfoBotPermissionsHeader, viewType: .textTopItem))
                }
                if cachedData.flags.contains(.botCanManageEmojiStatus) {
                    addPermissionHeader()
                    addHeader = false
                    entries.append(UserInfoEntry.botPermissionsStatus(sectionId: sectionId, value: cachedData.flags.contains(.botCanManageEmojiStatus), viewType: webAppPermissionsState?.location == nil ? .singleItem : .firstItem))
                }
                
                if let location = webAppPermissionsState?.location {
                    if addHeader {
                        addPermissionHeader()
                    }
                    entries.append(UserInfoEntry.botPermissionsGeo(sectionId: sectionId, value: location.isAllowed, viewType: addHeader ? .singleItem : .lastItem))
                }
                
            }
            
            if FastSettings.canViewPeerId {
                entries.append(UserInfoEntry.section(sectionId: sectionId))
                sectionId += 1
                entries.append(UserInfoEntry.peerId(sectionId: sectionId, value: "\(user.id.id._internalGetInt64Value())", viewType: .singleItem))
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
