//
//  ChatInterfaceInteraction.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore

import TGUIKit
import SwiftSignalKit
import MapKit


final class ReplyMarkupInteractions {
    let proccess:(ReplyMarkupButton, @escaping(Bool)->Void) -> Void
    
    init(proccess:@escaping (ReplyMarkupButton, @escaping(Bool)->Void)->Void) {
        self.proccess = proccess
    }
    
}


final class ChatInteraction : InterfaceObserver  {
    
    let chatLocation: ChatLocation
    let mode: ChatMode
    var peerId : PeerId {
        return chatLocation.peerId
    }
    
    var activitySpace: PeerActivitySpace {
        return .init(peerId: peerId, category: mode.activityCategory)
    }
    
    var peer: Peer? {
        return presentation.peer
    }
    
    let context: AccountContext
    let isLogInteraction:Bool
    let disableSelectAbility: Bool
    let isGlobalSearchMessage: Bool
    private let modifyDisposable:MetaDisposable = MetaDisposable()
    private let mediaDisposable:MetaDisposable = MetaDisposable()
    private let startBotDisposable:MetaDisposable = MetaDisposable()
    private let addContactDisposable:MetaDisposable = MetaDisposable()
    private let requestSessionId:MetaDisposable = MetaDisposable()
    let editDisposable = MetaDisposable()
    private let disableProxyDisposable = MetaDisposable()
    private let enableProxyDisposable = MetaDisposable()
    
    
   
    
    init(chatLocation: ChatLocation, context: AccountContext, mode: ChatMode = .history, isLogInteraction: Bool = false, disableSelectAbility: Bool = false, isGlobalSearchMessage: Bool = false) {
        self.chatLocation = chatLocation
        self.context = context
        self.disableSelectAbility = disableSelectAbility
        self.isLogInteraction = isLogInteraction
        self.isGlobalSearchMessage = isGlobalSearchMessage
        self.presentation = ChatPresentationInterfaceState(chatLocation: chatLocation, chatMode: mode)
        self.mode = mode
        super.init()
        
        let signal = mediaPromise.get() |> deliverOnMainQueue |> mapToQueue { [weak self] (media) -> Signal<Void, NoError> in
            self?.sendMedia(media)
            return .single(Void())
        }
        _ = signal.start()
    }
    
    private(set) var presentation:ChatPresentationInterfaceState
    
    func update(animated:Bool = true, _ f:(ChatPresentationInterfaceState)->ChatPresentationInterfaceState)->Void {
        let oldValue = self.presentation
        self.presentation = f(presentation)
        if oldValue != presentation {
            notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
        }
    }
    
    var withToggledSelectedMessage:((ChatPresentationInterfaceState)->ChatPresentationInterfaceState)->Void = { _ in }
    

    var setupReplyMessage: (MessageId?) -> Void = {_ in}
    var beginMessageSelection: (MessageId?) -> Void = {_ in}
    var deleteMessages: ([MessageId]) -> Void = {_ in }
    var forwardMessages: ([MessageId]) -> Void = {_ in}
    var reportMessages:(ReportReasonValue, [MessageId]) -> Void = { _, _ in }
    var sendMessage: (Bool, Date?) -> Void = { _, _ in }
    var sendPlainText: (String) -> Void = {_ in}

    //
    var focusMessageId: (MessageId?, MessageId, TableScrollState) -> Void = {_,_,_  in} // from, to, animated, position
    var focusPinnedMessageId: (MessageId) -> Void = { _ in} // from, to, animated, position
    var sendMedia:([MediaSenderContainer]) -> Void = {_ in}
    var sendAppFile:(TelegramMediaFile, Bool, String?, Bool, ItemCollectionId?) -> Void = { _,_, _, _, _ in}
    var sendMedias:([Media], ChatTextInputState, Bool, ChatTextInputState?, Bool, Date?) -> Void = {_,_,_,_,_,_ in}
    var focusInputField:()->Void = {}
    var openInfo:(PeerId, Bool, MessageId?, ChatInitialAction?) -> Void = {_,_,_,_  in} // peerId, isNeedOpenChat, postId, initialAction
    var beginEditingMessage:(Message?) -> Void = {_ in}
    var requestMessageActionCallback:(MessageId, Bool, (requiresPassword: Bool, data: MemoryBuffer)?) -> Void = {_,_,_  in}
    var inlineAudioPlayer:(APController) -> Void = {_ in} 
    var movePeerToInput:(Peer) -> Void = {_ in}
    var sendInlineResult:(ChatContextResultCollection,ChatContextResult) -> Void = {_,_  in}
    var scrollToLatest:(Bool)->Void = {_ in}
    var shareSelfContact:(MessageId?)->Void = {_ in} // with reply
    var shareLocation:()->Void = {}
    var modalSearch:(String)->Void = {_ in }
    var sendCommand:(PeerCommand)->Void = {_ in }
    var setNavigationAction:(NavigationModalAction)->Void = {_ in}
    var switchInlinePeer:(PeerId, ChatInitialAction)->Void = {_,_  in}
    var showPreviewSender:([URL], Bool, NSAttributedString?)->Void = {_,_,_  in}
    var setChatMessageAutoremoveTimeout:(Int32?)->Void = {_ in}
    var toggleNotifications:(Bool?)->Void = { _ in }
    var removeAndCloseChat:()->Void = {}
    var joinChannel:()->Void = {}
    var returnGroup:()->Void = {}
    var shareContact:(TelegramUser)->Void = {_ in}
    var unblock:()->Void = {}
    var updatePinned:(MessageId, Bool, Bool, Bool)->Void = {_,_,_,_ in}
    var reportSpamAndClose:()->Void = {}
    var dismissPeerStatusOptions:()->Void = {}
    var dismissRequestChat: ()->Void = {}
    var toggleSidebar:()->Void = {}
    var mentionPressed:()->Void = {}
    var jumpToDate:(Date)->Void = {_ in}
    var showNextPost:()->Void = {}
    var startRecording:(Bool, NSView?)->Void = {_,_ in}
    var openProxySettings: ()->Void = {}
    var sendLocation: (CLLocationCoordinate2D, MapVenue?) -> Void = {_, _ in}
    var clearMentions:()->Void = {}
    var reactionPressed:()->Void = {}
    var clearReactions:()->Void = {}
    var attachFile:(Bool)->Void = { _ in }
    var attachPhotoOrVideo:()->Void = {}
    var attachPicture:()->Void = {}
    var attachLocation:()->Void = {}
    var updateEditingMessageMedia:([String]?, Bool) -> Void = { _, _ in}
    var editEditingMessagePhoto:(TelegramMediaImage) -> Void = { _ in}
    var removeChatInteractively:()->Void = { }
    var updateSearchRequest: (SearchMessagesResultState)->Void = { _ in }
    var searchPeerMessages: (Peer) -> Void = { _ in }
    var vote:(MessageId, [Data], Bool) -> Void = { _, _, _ in }
    var closePoll:(MessageId) -> Void = { _ in }
    var openDiscussion:()->Void = { }
    var addContact:()->Void = {}
    var blockContact: ()->Void = {}
    var openScheduledMessages: ()->Void = {}
    var openBank: (String)->Void = { _ in }
    var afterSentTransition:()->Void = {}
    var getGradientOffsetRect:()->NSRect = {  return .zero }
    var contextHolder:()->Atomic<ChatLocationContextHolder?> = { Atomic(value: nil) }
    
    var openFocusedMedia:(Int32?)->Void = { _ in return }
    
    var push:(ViewController)->Void = { _ in }
    var back:()->Void = { }

    var openPinnedMessages: (MessageId)->Void = { _ in }
    var unpinAllMessages: ()->Void = {}
    var setLocation: (ChatHistoryLocation)->Void = { _ in }
    var scrollToTheFirst: () -> Void = {}
    var openReplyThread:(MessageId, Bool, Bool, ReplyThreadMode)->Void = {  _, _, _, _ in }
    
    var transcribeAudio:(Message)->Void = { _ in }
    
    var joinGroupCall:(CachedChannelData.ActiveCall, String?)->Void = { _, _ in }

    var runEmojiScreenEffect:(String, Message, Bool, Bool)->Void = { _, _, _, _ in }
    var runPremiumScreenEffect:(Message, Bool, Bool)->Void = { _, _, _ in }
    var runReactionEffect:(MessageReaction.Reaction, MessageId)->Void = { _, _ in }

    var toggleSendAs: (PeerId)->Void = { _ in }
    
    var showDeleterSetup:(Control)->Void = { _ in }
    
    var showEmojiUseTooltip:()->Void = { }
    var restartTopic: ()->Void = { }

    var openPendingRequests:()->Void = { }
    var dismissPendingRequests:([PeerId])->Void = { _ in }
    var setupChatThemes:()->Void = { }
    func chatLocationInput(_ message: Message) -> ChatLocationInput {
        if mode.isThreadMode, mode.threadId == message.id {
            return context.chatLocationInput(for: .peer(message.id.peerId), contextHolder: contextHolder())
        } else {
            return context.chatLocationInput(for: self.chatLocation, contextHolder: contextHolder())
        }
    }
    
    var updateFrame:(NSRect, ContainedViewLayoutTransition) -> Void = { _, _ in }
    
    var unarchive: ()->Void = { }

    var closeAfterPeek:(Int32)->Void = { _ in }
    
    var updateReactions: (MessageId, String, @escaping(Bool)->Void)->Void = { _, _, _ in }
    
    let loadingMessage: Promise<Bool> = Promise()
    let mediaPromise:Promise<[MediaSenderContainer]> = Promise()
    
    var hasSetDestructiveTimer: Bool {
        
        if mode != .history {
            return false
        }
        
        if !self.presentation.interfaceState.inputState.inputText.isEmpty {
            return false
        }
        if self.peerId.namespace == Namespaces.Peer.SecretChat {
            return true
        }
        if let value = self.presentation.messageSecretTimeout {
            switch value {
            case let .known(value):
                if value != nil {
                    return true
                }
            default:
                return false
            }
        }

        return false
    }
    
    var peerIsAccountPeer: Bool {
        return self.presentation.currentSendAsPeerId == nil || self.presentation.currentSendAsPeerId == self.context.peerId
    }
    
    static let maxInput:Int32 = 50000
    static let textLimit: Int32 = 4096
    var maxInputCharacters:Int32 {
        if presentation.state == .normal {
            return ChatInteraction.maxInput
        } else if let editState = presentation.interfaceState.editState {
            if editState.message.media.count == 0 {
                return ChatInteraction.textLimit
            } else {
                for media in editState.message.media {
                    if !(media is TelegramMediaWebpage) {
                        return Int32(context.isPremium ? context.premiumLimits.caption_length_limit_premium : context.premiumLimits.caption_length_limit_default)
                    }
                }
                return ChatInteraction.textLimit
            }
        }
        
        return ChatInteraction.maxInput
    }

    /*
     var hasSetDestructiveTimer: Bool {
         if self.peerId.namespace == Namespaces.Peer.SecretChat {
             return true
         }
         if let peer = presentation.peer {
             if let peer = peer as? TelegramChannel, peer.isSupergroup {
                 return peer.groupAccess.canEditGroupInfo
             }
             if let value = self.presentation.messageSecretTimeout {
                 switch value {
                 case let .known(value):
                     if value != nil {
                         return true
                     }
                 default:
                     return false
                 }
             }
             if let peer = peer as? TelegramGroup {
                 switch peer.role {
                 case .admin, .creator:
                     return true
                 default:
                     break
                 }
             }
         }

         return false
     }


     */
    
    
    func disableProxy() {
        disableProxyDisposable.set(updateProxySettingsInteractively(accountManager: context.sharedContext.accountManager, { current -> ProxySettings in
            return current.withUpdatedEnabled(false)
        }).start())
        
    }
    
    func applyProxy(_ server:ProxyServerSettings) -> Void {
        applyExternalProxy(server, accountManager: context.sharedContext.accountManager)
    }
    
    
    func call(isVideo: Bool = false) {
        if let peer = presentation.peer {
            let peerId:PeerId
            if let peer = peer as? TelegramSecretChat {
                peerId = peer.regularPeerId
            } else {
                peerId = peer.id
            }
            let context = self.context
            requestSessionId.set((phoneCall(context: context, peerId: peerId, isVideo: isVideo) |> deliverOnMainQueue).start(next: { result in
                applyUIPCallResult(context, result)
            }))
        }
    }
    
    func startBot(_ payload:String? = nil) {
        startBotDisposable.set((context.engine.messages.requestStartBot(botPeerId: self.peerId, payload: payload) |> deliverOnMainQueue).start(completed: { [weak self] in
            self?.update({$0.updatedInitialAction(nil)})
        }))
    }
    
    func clearInput() {
        self.update({$0.updatedInterfaceState({$0.withUpdatedInputState(ChatTextInputState())})})
    }
    func clearContextQuery() {
        if case let .contextRequest(query) = self.presentation.inputContext {
            let str = "@" + query.addressName + " "
            let state = ChatTextInputState(inputText: str, selectionRange: str.length ..< str.length, attributes: [])
            self.update({$0.updatedInterfaceState({$0.withUpdatedInputState(state)})})
        }
    }
    
    func forwardSelectedMessages() {
        if let ids = presentation.selectionState?.selectedIds {
            forwardMessages(Array(ids))
        }
    }
    
    func deleteSelectedMessages() {
        if let ids = presentation.selectionState?.selectedIds {
            deleteMessages(Array(ids))
        }
    }
    
    func updateInput(with text:String) {
        if self.presentation.state == .normal {
            let state = ChatTextInputState(inputText: text, selectionRange: text.length ..< text.length, attributes: [])
            self.update({$0.updatedInterfaceState({$0.withUpdatedInputState(state)})})
        }
    }
    func appendText(_ text: NSAttributedString, selectedRange:Range<Int>? = nil) -> Range<Int> {

        var selectedRange = selectedRange ?? presentation.effectiveInput.selectionRange
        let inputText = presentation.effectiveInput.attributedString.mutableCopy() as! NSMutableAttributedString
        
        if self.presentation.state != .normal && presentation.state != .editing {
            return selectedRange.lowerBound ..< selectedRange.lowerBound
        }
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {
           // let minUtfIndex = inputText.utf16.index(inputText.utf16.startIndex, offsetBy: selectedRange.lowerBound)
           // let maxUtfIndex = inputText.utf16.index(minUtfIndex, offsetBy: selectedRange.upperBound - selectedRange.lowerBound)
            
            
            
           // inputText.removeSubrange(minUtfIndex.samePosition(in: inputText)! ..< maxUtfIndex.samePosition(in: inputText)!)
            inputText.replaceCharacters(in: NSMakeRange(selectedRange.lowerBound, selectedRange.upperBound - selectedRange.lowerBound), with: text)
            selectedRange = selectedRange.lowerBound ..< selectedRange.lowerBound
        } else {
            inputText.insert(text, at: selectedRange.lowerBound)
        }
        
        let nRange:Range<Int> = selectedRange.lowerBound + text.length ..< selectedRange.lowerBound + text.length
        let state = ChatTextInputState(inputText: inputText.string, selectionRange: nRange, attributes: chatTextAttributes(from: inputText))
        self.update({$0.withUpdatedEffectiveInputState(state)})
        
        return selectedRange.lowerBound ..< selectedRange.lowerBound + text.length
    }
    
        
    func appendText(_ text:String, selectedRange:Range<Int>? = nil) -> Range<Int> {
        return self.appendText(NSAttributedString(string: text, font: .normal(theme.fontSize)), selectedRange: selectedRange)
    }
    
    func cancelEditing(_ force: Bool = false) {
        if let editState = self.presentation.interfaceState.editState {
            let oldState = ChatEditState(message: editState.message)
            if force {
                self.update({$0.withoutEditMessage().updatedUrlPreview(nil)})
            } else {
                switch editState.loadingState {
                case .loading, .progress:
                    editDisposable.set(nil)
                    self.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedLoadingState(.none)})})})
                    return
                default:
                    if oldState.inputState.inputText != editState.inputState.inputText, !editState.inputState.inputText.isEmpty {
                        confirm(for: context.window, information: strings().chatEditCancelText, okTitle: strings().alertDiscard, cancelTitle: strings().alertNO, successHandler: { [weak self] _ in
                            self?.update({$0.withoutEditMessage().updatedUrlPreview(nil)})
                        })
                    } else {
                        self.update({$0.withoutEditMessage().updatedUrlPreview(nil)})
                    }
                }
            }
        }
        
    }
    
    func invokeInitialAction(includeAuto:Bool = false, animated: Bool = true, action: ChatInitialAction? = nil) {
        if let action = action ?? presentation.initialAction {
            switch action {
            case let .start(parameter: parameter, behavior: behavior):
                var invoke:Bool = !includeAuto
                if includeAuto {
                    switch behavior {
                    case .automatic:
                        invoke = true
                    default:
                        break
                    }
                }
                if invoke {
                    startBot(parameter)
                    update({
                        $0.withoutInitialAction()
                    })
                }
            case let .inputText(text: text, behavior: behavior):
                var invoke:Bool = !includeAuto
                if includeAuto {
                    switch behavior {
                    case .automatic:
                        invoke = true
                    default:
                        break
                    }
                }
                if invoke {
                    updateInput(with: text)
                    update({
                        $0.withoutInitialAction()
                    })
                }
            case let .files(list: list, behavior: behavior):
                var invoke:Bool = !includeAuto
                if includeAuto {
                    switch behavior {
                    case .automatic:
                        invoke = true
                    default:
                        break
                    }
                }
                if invoke {
                    showPreviewSender( list.map { URL(fileURLWithPath: $0) }, true, nil )
                    update({
                        $0.withoutInitialAction()
                    })
                }
            case let .forward(messageIds, inputState, _):
                update(animated: animated, {$0.updatedInterfaceState({$0.withUpdatedForwardMessageIds(messageIds).withUpdatedInputState(inputState ?? $0.inputState)})})
                update({
                    $0.withoutInitialAction()
                })
            case .ad:
                break
            case .source:
                break
            case let .closeAfter(peek):
               break
            case let .openMedia(timemark):
                self.openFocusedMedia(timemark)
                update({
                    $0.withoutInitialAction()
                })
            case let .selectToReport(reason):
                update(animated: animated, {
                    $0.withSelectionState().withoutInitialAction().withUpdatedRepotMode(reason)
                })
            case let .attachBot(botname, payload, choose):
                update({
                    $0.withoutInitialAction()
                })
                
                let context = self.context
                
                let installed: Signal<Peer?, NoError> = context.engine.messages.attachMenuBots() |> map { items in
                    for item in items {
                        if item.peer.username?.lowercased() == botname.lowercased() {
                            return item.peer
                        }
                    }
                    return nil
                } |> take(1) |> deliverOnMainQueue
                
                let replyId = presentation.interfaceState.replyMessageId
                let peerId = self.peerId
                let threadId = presentation.chatLocation.threadId
                
                let openAttach:(Peer)->Void = { [weak self] peer in
                    
                    let invoke:()->Void = { [weak self] in
                        _ = showModalProgress(signal: context.engine.messages.getAttachMenuBot(botId: peer.id, cached: true), for: context.window).start(next: { attach in
                            
                            let thumbFile: TelegramMediaFile
                            if let file = attach.icons[.macOSAnimated] {
                                thumbFile = file
                            } else {
                                thumbFile = MenuAnimation.menu_folder_bot.file
                            }
                            showModal(with: WebpageModalController(context: context, url: "", title: peer.displayTitle, requestData: .normal(url: nil, peerId: peerId, threadId: threadId, bot: peer, replyTo: replyId, buttonText: "", payload: payload, fromMenu: false, hasSettings: attach.hasSettings, complete: self?.afterSentTransition), chatInteraction: self, thumbFile: thumbFile), for: context.window)
                            
                        }, error: { _ in
                            showModal(with: WebpageModalController(context: context, url: "", title: peer.displayTitle, requestData: .normal(url: nil, peerId: peerId, threadId: threadId, bot: peer, replyTo: replyId, buttonText: "", payload: payload, fromMenu: false, hasSettings: false, complete: self?.afterSentTransition), chatInteraction: self, thumbFile: MenuAnimation.menu_folder_bot.file), for: context.window)
                        })
                    }
                    if peer.isVerified {
                        invoke()
                    } else if let info = peer.botInfo {
                        if info.flags.contains(.canBeAddedToAttachMenu) {
                            invoke()
                        } else {
                            if FastSettings.shouldConfirmWebApp(peer.id) {
                                confirm(for: context.window, header: strings().webAppFirstOpenTitle, information: strings().webAppFirstOpenInfo(peer.displayTitle), successHandler: { _ in
                                    invoke()
                                    FastSettings.markWebAppAsConfirmed(peer.id)
                                })
                            } else {
                                invoke()
                            }
                        }
                    }
                }
                _ = installed.start(next: { peer in
                    if let peer = peer {
                        openAttach(peer)
                    } else {
                        _ = showModalProgress(signal: resolveUsername(username: botname, context: context), for: context.window).start(next: { peer in
                            if let peer = peer {
                                if let botInfo = peer.botInfo {
                                    if botInfo.flags.contains(.canBeAddedToAttachMenu) {
                                        installAttachMenuBot(context: context, peer: peer, completion: { value in
                                            if value {
                                                openAttach(peer)
                                            }
                                        })
                                    } else {
                                        openAttach(peer)
                                    }
                                }
                            } else {
                                alert(for: context.window, info: strings().webAppAttachDoenstExist("@\(botname)"))
                            }
                        })
                    }
                })
            case let .joinVoiceChat(joinHash):
                update(animated: animated, {
                    $0.updatedGroupCall { $0?.withUpdatedJoinHash(joinHash) }.withoutInitialAction()
                })
                
                let peerId = self.peerId
                let context = self.context
                
                let joinCall:(GroupCallPanelData)->Void = { [weak self] data in
                    if data.groupCall?.call.peerId != peerId, let peer = self?.peer {
                        showModal(with: JoinVoiceChatAlertController(context: context, groupCall: data, peer: peer, join: { [weak self] in
                            if let call = data.info {
                                self?.joinGroupCall(CachedChannelData.ActiveCall(id: call.id, accessHash: call.accessHash, title: call.title, scheduleTimestamp: call.scheduleTimestamp, subscribedToScheduled: call.subscribedToScheduled, isStream: call.isStream), joinHash)
                            }
                        }), for: context.window)
                    } else {
                        if let call = data.info {
                            self?.joinGroupCall(CachedChannelData.ActiveCall(id: call.id, accessHash: call.accessHash, title: call.title, scheduleTimestamp: call.scheduleTimestamp, subscribedToScheduled: call.subscribedToScheduled, isStream: call.isStream), joinHash)
                        }
                    }
                }
                let call: Signal<GroupCallPanelData?, GetCurrentGroupCallError> = context.engine.calls.updatedCurrentPeerGroupCall(peerId: peerId) |> mapToSignalPromotingError { call -> Signal<GroupCallSummary?, GetCurrentGroupCallError> in
                    if let call = call {
                        return context.engine.calls.getCurrentGroupCall(callId: call.id, accessHash: call.accessHash, peerId: peerId)
                    } else {
                        return .single(nil)
                    }
                } |> mapToSignal { data in
                    if let data = data {
                        return context.sharedContext.groupCallContext |> take(1) |> mapToSignalPromotingError { groupCallContext in
                            return .single(GroupCallPanelData(peerId: peerId, info: data.info, topParticipants: data.topParticipants, participantCount: data.info.participantCount, activeSpeakers: [], groupCall: groupCallContext))
                        }
                    } else {
                        return .single(nil)
                    }
                }
                _ = showModalProgress(signal: call, for: context.window).start(next: {  data in
                    if let data = data {
                        joinCall(data)
                    } else {
                        alert(for: context.window, info: strings().chatVoiceChatJoinLinkUnavailable)
                    }
                })
            }
           
        }
    }

    
    func openWebviewFromMenu(buttonText: String, url: String) {
        if let bot = peer {
            let replyTo = self.presentation.interfaceState.replyMessageId
            let threadId = self.presentation.chatLocation.threadId
            let context = self.context
            let peerId = self.peerId
            let invoke:()->Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                _ = showModalProgress(signal: context.engine.messages.getAttachMenuBot(botId: bot.id, cached: true), for: context.window).start(next: { [weak strongSelf] attach in
                    
                    let thumbFile: TelegramMediaFile
                    if let file = attach.icons[.macOSAnimated] {
                        thumbFile = file
                    } else {
                        thumbFile = MenuAnimation.menu_folder_bot.file
                    }
                    showModal(with: WebpageModalController(context: context, url: url, title: bot.displayTitle, requestData: .normal(url: url, peerId: peerId, threadId: threadId, bot: bot, replyTo: replyTo, buttonText: buttonText, payload: nil, fromMenu: true, hasSettings: attach.hasSettings, complete: strongSelf?.afterSentTransition), chatInteraction: strongSelf, thumbFile: thumbFile), for: context.window)

                }, error: { [weak strongSelf] _ in
                    showModal(with: WebpageModalController(context: context, url: url, title: bot.displayTitle, requestData: .normal(url: url, peerId: peerId, threadId: threadId, bot: bot, replyTo: replyTo, buttonText: buttonText, payload: nil, fromMenu: true, hasSettings: false, complete: strongSelf?.afterSentTransition), chatInteraction: strongSelf, thumbFile: MenuAnimation.menu_folder_bot.file), for: context.window)
                })
                
            }
            if FastSettings.shouldConfirmWebApp(bot.id) {
                confirm(for: context.window, header: strings().webAppFirstOpenTitle, information: strings().webAppFirstOpenInfo(bot.displayTitle), successHandler: { _ in
                    invoke()
                    FastSettings.markWebAppAsConfirmed(bot.id)
                })
            } else {
                invoke()
            }
            
        }
    }
    
    func processBotKeyboard(with keyboardMessage:Message) ->ReplyMarkupInteractions {
        if let attribute = keyboardMessage.replyMarkup, !isLogInteraction {
            
            let context = self.context
            let peerId = self.peerId
            
            return ReplyMarkupInteractions(proccess: { [weak self] (button, progress) in
                if let strongSelf = self {
                    switch button.action {
                    case let .url(url):
                        execute(inapp: inApp(for: url.nsstring, context: strongSelf.context, openInfo: strongSelf.openInfo, hashtag: strongSelf.modalSearch, command: strongSelf.sendPlainText, applyProxy: strongSelf.applyProxy, confirm: true))
                    case .text:
                        _ = (enqueueMessages(account: strongSelf.context.account, peerId: strongSelf.peerId, messages: [EnqueueMessage.message(text: button.title, attributes: [], inlineStickers: [:], mediaReference: nil, replyToMessageId: strongSelf.presentation.interfaceState.messageActionsState.processedSetupReplyMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]) |> deliverOnMainQueue).start(next: { [weak strongSelf] _ in
                            strongSelf?.scrollToLatest(true)
                        })
                    case .requestPhone:
                        FastSettings.requstPermission(with: .contact, for: keyboardMessage.id.peerId, success: { [weak strongSelf] in
                            strongSelf?.shareSelfContact(nil)
                            if attribute.flags.contains(.once) {
                                strongSelf?.update({$0.updatedInterfaceState({$0.withUpdatedMessageActionsState({$0.withUpdatedClosedButtonKeyboardMessageId(keyboardMessage.id)})})})
                            }
                        })
                        
                        return
                    case .openWebApp:
                        strongSelf.requestMessageActionCallback(keyboardMessage.id, true, nil)
                    case let .callback(data):
                        strongSelf.requestMessageActionCallback(keyboardMessage.id, false, data)
                    case let .switchInline(samePeer: same, query: query):
                        let text = "@\(keyboardMessage.inlinePeer?.username ?? keyboardMessage.author?.username ?? "") \(query)"
                        if same {
                            strongSelf.updateInput(with: text)
                        } else {
                            if let peer = keyboardMessage.inlinePeer ?? keyboardMessage.effectiveAuthor {
                                strongSelf.context.bindings.rootNavigation().set(modalAction: ShareInlineResultNavigationAction(payload: text, botName: peer.displayTitle), strongSelf.context.layout != .single)
                                if strongSelf.context.layout == .single {
                                    strongSelf.context.bindings.rootNavigation().push(ForwardChatListController(strongSelf.context))
                                }
                            }
                            
                        }
                    case .payment:
                        if let invoice = keyboardMessage.effectiveMedia as? TelegramMediaInvoice {
                            let receiptMessageId = invoice.receiptMessageId
                            if let receiptMessageId = receiptMessageId {
                                showModal(with: PaymentsReceiptController(context: strongSelf.context, messageId: receiptMessageId, invoice: invoice), for: strongSelf.context.window)
                            } else {
                                showModal(with: PaymentsCheckoutController(context: strongSelf.context, source: .message(keyboardMessage.id), invoice: invoice), for: strongSelf.context.window)
                            }
                        }
                    case let .urlAuth(url, buttonId):
                        let context = strongSelf.context
                        _ = showModalProgress(signal: context.engine.messages.requestMessageActionUrlAuth(subject: .message(id: keyboardMessage.id, buttonId: buttonId)), for: context.window).start(next: { result in
                            switch result {
                            case let .accepted(url):
                                execute(inapp: inApp(for: url.nsstring, context: strongSelf.context, openInfo: strongSelf.openInfo, hashtag: strongSelf.modalSearch, command: strongSelf.sendPlainText, applyProxy: strongSelf.applyProxy))
                            case .default:
                                execute(inapp: inApp(for: url.nsstring, context: strongSelf.context, openInfo: strongSelf.openInfo, hashtag: strongSelf.modalSearch, command: strongSelf.sendPlainText, applyProxy: strongSelf.applyProxy, confirm: true))
                            case let .request(requestURL, peer, writeAllowed):
                                showModal(with: InlineLoginController(context: context, url: requestURL, originalURL: url, writeAllowed: writeAllowed, botPeer: peer, authorize: { allowWriteAccess in
                                    _ = showModalProgress(signal: context.engine.messages.acceptMessageActionUrlAuth(subject: .message(id: keyboardMessage.id, buttonId: buttonId), allowWriteAccess: allowWriteAccess), for: context.window).start(next: { result in
                                        switch result {
                                        case .default:
                                            execute(inapp: inApp(for: url.nsstring, context: strongSelf.context, openInfo: strongSelf.openInfo, hashtag: strongSelf.modalSearch, command: strongSelf.sendPlainText, applyProxy: strongSelf.applyProxy, confirm: true))
                                        case let .accepted(url):
                                            execute(inapp: inApp(for: url.nsstring, context: strongSelf.context, openInfo: strongSelf.openInfo, hashtag: strongSelf.modalSearch, command: strongSelf.sendPlainText, applyProxy: strongSelf.applyProxy))
                                        default:
                                            break
                                        }
                                    })
                                }), for: context.window)
                            }
                        })
                    case let .setupPoll(isQuiz):
                        showModal(with: NewPollController(chatInteraction: strongSelf, isQuiz: isQuiz), for: strongSelf.context.window)
                    case let .openUserProfile(peerId: peerId):
                        strongSelf.openInfo(peerId, false, nil, nil)
                    case let .openWebView(hashUrl, simple):
                        let bot = keyboardMessage.inlinePeer ?? keyboardMessage.author
                        let replyTo = strongSelf.presentation.interfaceState.replyMessageId
                        let threadId = strongSelf.presentation.chatLocation.threadId
                        if let bot = bot {
                            let botId = bot.id
                            if simple {
                                let signal = context.engine.messages.requestSimpleWebView(botId: botId, url: hashUrl, themeParams: generateWebAppThemeParams(theme))
                                _ = showModalProgress(signal: signal, for: context.window).start(next: { url in
                                    showModal(with: WebpageModalController(context: context, url: url, title: bot.displayTitle, requestData: .simple(url: hashUrl, bot: bot, buttonText: button.title), chatInteraction: strongSelf, thumbFile: MenuAnimation.menu_folder_bot.file), for: context.window)
                                })
                            } else {
                                _ = showModalProgress(signal: context.engine.messages.getAttachMenuBot(botId: bot.id, cached: true), for: context.window).start(next: { [weak strongSelf] attach in
                                    
                                    let thumbFile: TelegramMediaFile
                                    if let file = attach.icons[.macOSAnimated] {
                                        thumbFile = file
                                    } else {
                                        thumbFile = MenuAnimation.menu_folder_bot.file
                                    }
                                    showModal(with: WebpageModalController(context: context, url: hashUrl, title: bot.displayTitle, requestData: .normal(url: hashUrl, peerId: peerId, threadId: threadId, bot: bot, replyTo: replyTo, buttonText: button.title, payload: nil, fromMenu: false, hasSettings: attach.hasSettings, complete: strongSelf?.afterSentTransition), chatInteraction: strongSelf, thumbFile: thumbFile), for: context.window)

                                }, error: { [weak strongSelf] _ in
                                    showModal(with: WebpageModalController(context: context, url: hashUrl, title: bot.displayTitle, requestData: .normal(url: hashUrl, peerId: peerId, threadId: threadId, bot: bot, replyTo: replyTo, buttonText: button.title, payload: nil, fromMenu: false, hasSettings: false, complete: strongSelf?.afterSentTransition), chatInteraction: strongSelf, thumbFile: MenuAnimation.menu_folder_bot.file), for: context.window)
                                })
                            }

                        }
                    default:
                        break
                    }
                    if attribute.flags.contains(.once) {
                        strongSelf.update({$0.updatedInterfaceState({$0.withUpdatedMessageActionsState({$0.withUpdatedClosedButtonKeyboardMessageId(keyboardMessage.id)})})})
                    }
                }
            })
        }
        return ReplyMarkupInteractions(proccess: {_,_  in})
    }
    
    
    
    public func saveState(_ force:Bool = true, scrollState: ChatInterfaceHistoryScrollState? = nil, sync: Bool = false) {
        
        let peerId = self.peerId
        let context = self.context
        let timestamp = Int32(Date().timeIntervalSince1970)
        let interfaceState = presentation.interfaceState.withUpdatedTimestamp(timestamp).withUpdatedHistoryScrollState(scrollState)
        
        let updatedOpaqueData = try? EngineEncoder.encode(interfaceState)

        var s:Signal<Never, NoError> = context.engine.peers.setOpaqueChatInterfaceState(peerId: peerId, threadId: mode.threadId64, state: .init(opaqueData: updatedOpaqueData, historyScrollMessageIndex: interfaceState.historyScrollMessageIndex, synchronizeableInputState: interfaceState.synchronizeableInputState))

        if !force && !interfaceState.inputState.inputText.isEmpty {
            s = s |> delay(10, queue: Queue.mainQueue())
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let disposable = s.start(completed: {
            context.setChatInterfaceTempState(ChatInterfaceTempState(editState: interfaceState.editState), for: peerId)
            if sync {
                semaphore.signal()
            }
        })
        modifyDisposable.set(disposable)

        if sync {
            semaphore.wait()
        }
    }
    
    

    deinit {
       clean()
    }
    
    func clean() {
        
        addContactDisposable.dispose()
        mediaDisposable.dispose()
        startBotDisposable.dispose()
        requestSessionId.dispose()
        disableProxyDisposable.dispose()
        enableProxyDisposable.dispose()
        editDisposable.dispose()
        update({ _ in
            return ChatPresentationInterfaceState(chatLocation: self.chatLocation, chatMode: self.mode)
        })
    }
    
    
    
    public func applyAction(action:NavigationModalAction) {
        if let action = action as? FWDNavigationAction {
            self.update({$0.updatedInterfaceState({$0.withUpdatedForwardMessageIds(action.ids)})})
            saveState(false)
        } else if let action = action as? ShareInlineResultNavigationAction {
            updateInput(with: action.payload)
        }
    }
    
}

