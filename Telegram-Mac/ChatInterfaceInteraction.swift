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
import CodeSyntax
import TGUIKit
import SwiftSignalKit
import MapKit
import InputView
import CurrencyFormat

final class ReplyMarkupInteractions {
    let context: AccountContext
    let proccess:(ReplyMarkupButton, @escaping(Bool)->Void) -> Void
    
    init(context: AccountContext, proccess:@escaping (ReplyMarkupButton, @escaping(Bool)->Void)->Void) {
        self.context = context
        self.proccess = proccess
    }
    
}


final class ChatInteraction : InterfaceObserver  {
    
    var chatLocation: ChatLocation {
        return self.presentation.chatLocation
    }
    
    var isMonoforum: Bool {
        return presentation.isMonoforum
        //return chatLocation.threadMessage?.isMonoforumPost == true
    }
    
    func threadInfo(_ peerId: PeerId, holder: Atomic<ChatLocationContextHolder?>) -> ThreadInfo? {
        if (self.presentation.isTopicMode && peerId == self.peerId) || mode.isSavedMessagesThread || isMonoforum {
            switch chatLocation {
            case let .thread(data):
                return .init(message: data, isChannelPost: false, isMonoforumPost: chatLocation.threadMessage?.isMonoforumPost == true, isEmpty: false, contextHolder: holder)
            default:
                break
            }
        }
        return nil
    }
    
    var mode: ChatMode {
        return presentation.chatMode
    }
    var peerId : PeerId {
        return chatLocation.peerId
    }
    
    var activitySpace: PeerActivitySpace {
        return .init(peerId: peerId, category: mode.activityCategory(chatLocation.threadId))
    }
    
    var peer: Peer? {
        return presentation.peer
    }
    
    let context: AccountContext
    let isLogInteraction:Bool
    let disableSelectAbility: Bool
    let isGlobalSearchMessage: Bool
    let isPeerSavedMessages: Bool
    private let modifyDisposable:MetaDisposable = MetaDisposable()
    private let mediaDisposable:MetaDisposable = MetaDisposable()
    private let startBotDisposable:MetaDisposable = MetaDisposable()
    private let addContactDisposable:MetaDisposable = MetaDisposable()
    private let requestSessionId:MetaDisposable = MetaDisposable()
    let editDisposable = MetaDisposable()
    private let disableProxyDisposable = MetaDisposable()
    private let enableProxyDisposable = MetaDisposable()
    
    
    
    
    init(chatLocation: ChatLocation, context: AccountContext, mode: ChatMode = .history, isLogInteraction: Bool = false, disableSelectAbility: Bool = false, isGlobalSearchMessage: Bool = false, isPeerSavedMessages: Bool = false) {
        self.context = context
        self.disableSelectAbility = disableSelectAbility
        self.isLogInteraction = isLogInteraction
        self.isGlobalSearchMessage = isGlobalSearchMessage
        self.isPeerSavedMessages = isPeerSavedMessages
        self.presentation = ChatPresentationInterfaceState(chatLocation: chatLocation, chatMode: mode)
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
    
    enum AttachMediaType {
        case photo
        case video
    }
    
    var setupReplyMessage: (Message?, EngineMessageReplySubject?) -> Void = { _, _ in}
    var beginMessageSelection: (MessageId?) -> Void = {_ in}
    var deleteMessages: ([MessageId]) -> Void = {_ in }
    var forwardMessages: ([Message]) -> Void = {_ in}
    var reportMessages:(ReportReasonValue, [MessageId]) -> Void = { _, _ in }
    var sendMessage: (Bool, Date?, AvailableMessageEffects.MessageEffect?) -> Void = { _, _, _ in }
    var sendPlainText: (String) -> Void = {_ in}
    
    //
    var focusMessageId: (MessageId?, ChatFocusTarget, TableScrollState) -> Void = { _, _, _  in} // from, to, animated, position
    var focusPinnedMessageId: (MessageId) -> Void = { _ in} // from, to, animated, position
    var sendMedia:([MediaSenderContainer]) -> Void = {_ in}
    var sendAppFile:(TelegramMediaFile, Bool, String?, Bool, ItemCollectionId?) -> Void = { _,_, _, _, _ in}
    var sendMedias:([Media], ChatTextInputState, Bool, ChatTextInputState?, Bool, Date?, Bool, AvailableMessageEffects.MessageEffect?, Bool) -> Void = {_,_,_,_,_,_,_,_, _ in}
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
    var attachPhotoOrVideo:(AttachMediaType?)->Void = { _ in }
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
    var markAdAction:(Data, Bool)->Void = { _, _ in }
    var contextHolder:()->Atomic<ChatLocationContextHolder?> = { Atomic(value: nil) }
    
    var freezeAccountAlert:()->Void = { }
    
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
    var revealMedia:(Message)->Void = { _ in }
    var toggleTranslate:()->Void = { }
    var hideTranslation:()->Void = { }
    var openStories: (_ f:@escaping(PeerId, MessageId?, Int32?)-> NSView?, ((Signal<Never, NoError>)->Void)?)->Void = { _, _ in }
    var openChatPeerStories: (MessageId, PeerId, ((Signal<Never, NoError>)->Void)?)->Void = { _, _, _ in }
    var doNotTranslate:(String)->Void = { _ in }
    var translateTo:(String)->Void = { _ in }
    var enableTranslatePaywall:()->Void = { }
    var openPendingRequests:()->Void = { }
    var dismissPendingRequests:([PeerId])->Void = { _ in }
    var setupChatThemes:()->Void = { }
    var closeChatThemes:()->Void = { }
    var appendAttributedText:(NSAttributedString)->Void = { _ in }
    var setLocationTag:(HistoryViewInputTag?)->Void = { _ in }
    var revealFactCheck:(MessageId)->Void = { _ in }
    
    var hashtag:(String)->Void = { _ in }
    
    var sendMessageMenu:(Bool)->Signal<ContextMenu?, NoError> = { _ in .single(nil) }
    
    var removeAd:(Data)->Void = { _ in }
    
    var boostToUnrestrict:(BoostChannelSource)->Void = { _ in }
    
    var executeReplymarkup:(MessageId)->Void = { _ in }
    var toggleUnderMouseMessage:()->Void = { }
    
    var openStory:(MessageId, StoryId)->Void = { _, _ in }
    
    var sendMessageShortcut:(ShortcutMessageList.Item)->Void = { _ in }
    
    var replyToAnother:(EngineMessageReplySubject, Bool)->Void = { _, _ in }
    
    var enqueueCodeSyntax:(MessageId, NSRange, String, String, SyntaxterTheme)->Void = { _, _, _, _, _ in }
    
    var openPhoneNumberContextMenu: (String)->Void = { _ in }
    
    var toggleQuote: (QuoteMessageIndex)->Void = { _ in }
    
    var markAdAsSeen:(Data)->Void = { _ in }
    
    var openMonoforum:(PeerId)->Void = { peerId in }
    var toggleMonoforumState:()->Void = { }
    var monoforumMenuItems:(MonoforumItem) -> Signal<[ContextMenuItem], NoError> = { _ in return .single([]) }

    var sendGift:()->Void = { }
    var editPostSuggestion:(ChatInterfaceState.ChannelSuggestPost)->Void = { _ in }
    
    var updateChatLocationThread:(Int64?)->Void = { _ in }
    
    var appendTask:(Message)->Void = { _ in }
    
    
    func chatLocationInput(_ message: Message) -> ChatLocationInput {
        if mode.isThreadMode, chatLocation.threadMsgId == message.id {
            return context.chatLocationInput(for: .peer(message.id.peerId), contextHolder: contextHolder())
        } else {
            return context.chatLocationInput(for: self.chatLocation, contextHolder: contextHolder())
        }
    }
    
    func suggestPost() {
        self.update({
            $0.updatedInterfaceState {
                $0.withUpdatedSuggestPost(.init(amount: nil, date: nil, mode: .new))
            }
        })
        if let data = self.presentation.interfaceState.suggestPost {
            showModal(with: EditPostSuggestionController(chatInteraction: self, data: data), for: self.context.window)
        }
    }
    
    var updateFrame:(NSRect, ContainedViewLayoutTransition) -> Void = { _, _ in }
    
    var unarchive: ()->Void = { }
    
    var closeAfterPeek:(Int32)->Void = { _ in }
    
    var updateReactions: (MessageId, String, @escaping(Bool)->Void)->Void = { _, _, _ in }
    
    
    let loadingMessage: Promise<Bool> = Promise()
    let mediaPromise:Promise<[MediaSenderContainer]> = Promise()
    
    var hasSetDestructiveTimer: Bool {
        return presentation.hasSetDestructiveTimer
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
        
        
        guard !context.isFrozen else {
            context.freezeAlert()
            return
        }
        
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
            let messages = context.account.postbox.messagesAtIds(Array(ids)) |> deliverOnMainQueue
            _ = messages.start(next: { [weak self] messages in
                self?.forwardMessages(messages)
            })
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
    @discardableResult func appendText(_ text: NSAttributedString, selectedRange:Range<Int>? = nil) -> Range<Int> {
        
        let text = text.mutableCopy() as! NSMutableAttributedString
        
        var selectedRange = selectedRange ?? presentation.effectiveInput.selectionRange
        let inputText = presentation.effectiveInput.attributedString().mutableCopy() as! NSMutableAttributedString
        
        if self.presentation.state != .normal && presentation.state != .editing {
            return selectedRange.lowerBound ..< selectedRange.lowerBound
        }
        
        if selectedRange.lowerBound - 1 >= 0 {
            let attributes = inputText.attributes(at: selectedRange.lowerBound - 1, effectiveRange: nil)
                .filter { (key, value) in
                    if value is TextInputTextCustomEmojiAttribute {
                        return false
                    } else {
                        return true
                    }
                }
            text.addAttributes(attributes, range: text.range)
        }
        
//        if selectedRange.lowerBound == 0 {
//            let attributes = inputText.attributes(at: selectedRange.lowerBound, effectiveRange: nil).filter {
//                $0.key == TextInputAttributes.quote
//            }
//            text.addAttributes(attributes, range: text.range)
//        }
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {
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
                        verifyAlert_button(for: context.window, information: strings().chatEditCancelText, ok: strings().alertDiscard, cancel: strings().alertNO, successHandler: { [weak self] _ in
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
                        if let count = presentation.historyCount, count > 1 {
                            invoke = true
                        }
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
                    self.update({$0.updatedInterfaceState({$0.withUpdatedInputState(text)})})
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
                update(animated: animated, {
                    $0.updatedInterfaceState({
                        $0.withUpdatedForwardMessageIds(messageIds).withUpdatedInputState(inputState ?? $0.inputState)
                    }).withoutInitialAction()
                })
            case let .reply(subject, _):
                update(animated: animated, {
                    $0.updatedInterfaceState({
                        $0.withUpdatedReplyMessageId(subject)
                    }).withoutInitialAction()
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
            case let .attachBot(botname, payload, _):
                update({
                    $0.withoutInitialAction()
                })
                
                let context = self.context
                
                let installed: Signal<Peer?, NoError> = context.engine.messages.attachMenuBots() |> map { items in
                    for item in items {
                        if item.peer.addressName?.lowercased() == botname.lowercased() {
                            return item.peer._asPeer()
                        }
                    }
                    return nil
                } |> take(1) |> deliverOnMainQueue
                
                let replyId = presentation.interfaceState.replyMessageId?.messageId
                let peerId = self.peerId
                let threadId = presentation.chatLocation.threadId
                
                let openAttach:(Peer)->Void = { peer in
                    
                    let open:()->Void = {
                        let tab: BrowserTabData.Data = .webapp(bot: .init(peer), peerId: peerId, buttonText: "", url: nil, payload: payload, threadId: threadId, replyTo: replyId, fromMenu: false)
                        BrowserStateContext.get(context).open(tab: tab)
                    }
                    
                    let invoke:()->Void = {
                        _ = showModalProgress(signal: context.engine.messages.getAttachMenuBot(botId: peer.id, cached: true), for: context.window).start(next: { attach in
                            if attach.flags.contains(.showInSettingsDisclaimer) || attach.flags.contains(.notActivated) {
                                var options: [ModalAlertData.Option] = []
                                options.append(.init(string: strings().webBotAccountDisclaimerThird, isSelected: false, mandatory: true))
                                
                                var description: ModalAlertData.Description? = nil
                                let installBot = !attach.flags.contains(.notActivated) && attach.peer._asPeer().botInfo?.flags.contains(.canBeAddedToAttachMenu) == true && !attach.flags.contains(.showInAttachMenu)
                                if installBot {
                                    description = .init(string: strings().webBotAccountDesclaimerDesc(attach.shortName), onlyWhenEnabled: false)
                                }
                                
                                
                                let data = ModalAlertData(title: strings().webBotAccountDisclaimerTitle, info: strings().webBotAccountDisclaimerText, description: description, ok: strings().webBotAccountDisclaimerOK, options: options)
                                showModalAlert(for: context.window, data: data, completion: { result in
                                    _ = context.engine.messages.acceptAttachMenuBotDisclaimer(botId: peer.id).start()
                                    installAttachMenuBot(context: context, peer: peer, completion: { value in
                                        open()
                                        if value {
                                            showModalText(for: context.window, text: strings().webAppAttachSuccess(peer.displayTitle))
                                        }
                                    })
                                })
                            } else {
                                let botInfo = attach.peer._asPeer().botInfo
                                let installBot = botInfo?.flags.contains(.canBeAddedToAttachMenu) == true
                                if installBot {
                                    installAttachMenuBot(context: context, peer: peer, completion: { _ in
                                        open()
                                    })
                                } else {
                                    open()
                                }
                            }
                            
                        }, error: { _ in
                            open()
                        })
                    }
                    if peer.isVerified {
                        invoke()
                    } else if let _ = peer.botInfo {
                        invoke()
                    }
                }
                _ = installed.start(next: { peer in
                    if let peer = peer {
                        openAttach(peer)
                    } else {
                        _ = showModalProgress(signal: resolveUsername(username: botname, context: context), for: context.window).start(next: { peer in
                            if let peer = peer {
                                openAttach(peer)
                            } else {
                                alert(for: context.window, info: strings().webAppAttachDoenstExist("@\(botname)"))
                            }
                        })
                    }
                })
            case let .openWebview(botPeer, botApp, result):
                update(animated: animated, {
                    $0.withoutInitialAction()
                })
                BrowserStateContext.get(context).open(tab: .straight(bot: .init(botPeer.peer), peerId: peerId, title: botApp.title, result: result))
            case .makeWebview:
                update(animated: animated, {
                    $0.withoutInitialAction()
                })
            case let .joinVoiceChat(joinHash):
                update(animated: animated, {
                    $0.updatedGroupCall { $0?.withUpdatedJoinHash(joinHash) }.withoutInitialAction()
                })
                
                let peerId = self.peerId
                let context = self.context
                let isChannel = self.peer?.isChannel == true
                
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
                        return context.engine.calls.getCurrentGroupCall(reference: .id(id: call.id, accessHash: call.accessHash), peerId: peerId)
                    } else {
                        return .single(nil)
                    }
                } |> mapToSignal { data in
                    if let data = data {
                        return context.sharedContext.groupCallContext |> take(1) |> mapToSignalPromotingError { groupCallContext in
                            return .single(GroupCallPanelData(peerId: peerId, isChannel: isChannel, info: data.info, topParticipants: data.topParticipants, participantCount: data.info.participantCount, activeSpeakers: [], groupCall: groupCallContext))
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
            BrowserStateContext.get(context).open(tab: .webapp(bot: .init(bot), peerId: peerId, buttonText: buttonText, url: url, payload: nil, threadId: nil, replyTo: nil, fromMenu: true))
        }
    }
    
    func loadAndOpenInlineWebview(botId: PeerId, url: String) {
        let context = self.context
        
        let bot = context.account.postbox.loadedPeerWithId(botId) |> deliverOnMainQueue
        _ = bot.start(next: { [weak self] peer in
            self?.openWebview(bot: peer, title: nil, buttonText: "", url: url, simple: true, inline: true)
        })
        
    }
    
    func openEditReplies() {
        context.bindings.rootNavigation().push(BusinessQuickReplyController(context: context))
    }
    
    func openWebview(bot:Peer, title: String?, buttonText: String, url: String, simple: Bool, inline: Bool) {
        let replyTo = self.presentation.interfaceState.replyMessageId?.messageId
        let threadId = self.presentation.chatLocation.threadId
        let context = self.context
        let peerId = self.peerId
        
        let tab: BrowserTabData.Data
        if simple {
            tab = .simple(bot: .init(bot), url: url, buttonText: buttonText, source: inline ? .inline(startParam: nil) : .generic)
        } else {
            tab = .webapp(bot: .init(bot), peerId: peerId, buttonText: buttonText, url: url, payload: nil, threadId: threadId, replyTo: replyTo, fromMenu: false)
        }
        BrowserStateContext.get(context).open(tab: tab)
    }
    
    func processBotKeyboard(with keyboardMessage:Message) ->ReplyMarkupInteractions {
        if let attribute = keyboardMessage.replyMarkup, !isLogInteraction {
            
            let context = self.context
            let peerId = self.peerId
            let threadId = self.chatLocation.threadId
            
            return ReplyMarkupInteractions(context: context, proccess: { [weak self] (button, progress) in
                if let strongSelf = self {
                    switch button.action {
                    case let .url(url):
                        
                        execute(inapp: inApp(for: url.nsstring, context: strongSelf.context, openInfo: strongSelf.openInfo, hashtag: strongSelf.modalSearch, command: strongSelf.sendPlainText, applyProxy: strongSelf.applyProxy, confirm: true))
                       
                    case .text:
                        let replyId = strongSelf.presentation.interfaceState.messageActionsState.processedSetupReplyMessageId
                        _ = (enqueueMessages(account: strongSelf.context.account, peerId: strongSelf.peerId, messages: [EnqueueMessage.message(text: button.title, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: replyId.flatMap { .init(messageId: $0, quote: nil, todoItemId: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]) |> deliverOnMainQueue).start(next: { [weak strongSelf] _ in
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
                    case let .switchInline(samePeer: same, query: query, peerTypes):
                        let text = "@\(keyboardMessage.inlinePeer?.username ?? keyboardMessage.author?.username ?? "") \(query)"
                        if same {
                            strongSelf.updateInput(with: text)
                        } else {
                            
                            let object = ShareCallbackPeerTypesObject(context, peerTypes: peerTypes, callback: { peerIds in
                                if let peerId = peerIds.first {
                                    let controller = ChatAdditionController(context: context, chatLocation: .peer(peerId), initialAction: .inputText(text: .init(inputText: text), behavior: .automatic))
                                    context.bindings.rootNavigation().push(controller)
                                }
                                return .complete()
                            })
                            showModal(with: ShareModalController(object), for: context.window)
                            
                        }
                    case .payment:
                        if let invoice = keyboardMessage.anyMedia as? TelegramMediaInvoice {
                            let receiptMessageId = invoice.receiptMessageId
                            if let receiptMessageId = receiptMessageId {
                                showModal(with: PaymentsReceiptController(context: strongSelf.context, messageId: receiptMessageId, invoice: invoice), for: strongSelf.context.window)
                            } else {
                                if invoice.currency == XTR {
                                    showModal(with: Star_PurschaseInApp(context: context, invoice: invoice, source: .message(keyboardMessage.id)), for: context.window)
                                } else {
                                    showModal(with: PaymentsCheckoutController(context: strongSelf.context, source: .message(keyboardMessage.id), invoice: invoice), for: strongSelf.context.window)
                                }
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
                                var options: [ModalAlertData.Option] = []
                                options.append(.init(string: strings().botInlineAuthOptionLogin(requestURL, context.myPeer?.displayTitle ?? ""), isSelected: true, mandatory: false, uncheckEverything: true))
                                if writeAllowed {
                                    options.append(.init(string: strings().botInlineAuthOptionAllowSendMessages(peer.displayTitle), isSelected: true, mandatory: false))
                                }
                                
                                let data = ModalAlertData(title: strings().botInlineAuthHeader, info: strings().botInlineAuthTitle(requestURL), ok: strings().botInlineAuthOpen, options: options)
                                
                                showModalAlert(for: context.window, data: data, completion: { result in
                                    if result.selected.isEmpty {
                                        execute(inapp: .external(link: url, false))
                                    } else {
                                        let allowWriteAccess = result.selected[1] == true
                                        
                                        _ = showModalProgress(signal: context.engine.messages.acceptMessageActionUrlAuth(subject: .url(url), allowWriteAccess: allowWriteAccess), for: context.window).start(next: { result in
                                            switch result {
                                            case .default:
                                                execute(inapp: .external(link: url, true))
                                            case let .accepted(url):
                                                execute(inapp: .external(link: url, false))
                                            default:
                                                break
                                            }
                                        })
                                    }
                                })
                            }
                        })
                    case let .setupPoll(isQuiz):
                        showModal(with: NewPollController(chatInteraction: strongSelf, isQuiz: isQuiz), for: strongSelf.context.window)
                    case let .openUserProfile(peerId: peerId):
                        strongSelf.openInfo(peerId, false, nil, nil)
                    case let .openWebView(hashUrl, simple):
                        let bot = keyboardMessage.inlinePeer ?? keyboardMessage.author
                        if let bot = bot {
                            strongSelf.openWebview(bot: bot, title: bot.displayTitle, buttonText: button.title, url: hashUrl, simple: simple, inline: false)
                        }
                    case let .requestPeer(peerType, buttonId, maxQuantity):
                        selectSpecificPeer(context: context, peerType: peerType, messageId: keyboardMessage.id, buttonId: buttonId, maxQuantity: maxQuantity)
                    case let .copyText(payload):
                        copyToClipboard(payload)
                        showModalText(for: context.window, text: strings().shareLinkCopied)
                    default:
                        break
                    }
                    if attribute.flags.contains(.once) {
                        strongSelf.update({$0.updatedInterfaceState({$0.withUpdatedMessageActionsState({$0.withUpdatedClosedButtonKeyboardMessageId(keyboardMessage.id)})})})
                    }
                }
            })
        } else if let attribute = keyboardMessage.suggestPostAttribute, !isLogInteraction {
            
            let context = self.context
            let peer = presentation.peer
            let amount = attribute.amount
            
            return ReplyMarkupInteractions(context: context, proccess: { [weak self] button, progress in
                
                switch button.action {
                case let .url(url):
                    switch url {
                    case SuggestedPostMessageAttribute.commandApprove:
                        
                        if let peer, !peer.groupAccess.canPostMessages {
                            _ = context.engine.messages.monoforumPerformSuggestedPostAction(
                                id: keyboardMessage.id,
                                action: .approve(timestamp: nil)
                            ).start()
                        } else {
                            let comission = context.appConfiguration.getGeneralValue("ton_suggested_post_commission_permille", orElse: 850)
                            
                            let formatted: String
                            if let amount {
                                let totalAmount = "\(Double(formatCurrencyAmount(amount.amount.value, currency: TON))! * Double(comission.decemial / 100.0))".prettyCurrencyNumberUsd

                                switch amount.currency {
                                case .ton:
                                    formatted = "\(totalAmount) \(TON)"
                                case .stars:
                                    formatted = strings().starListItemCountCountable(Int(amount.amount.totalValue))
                                }
                            } else {
                                formatted = strings().chatServiceSuggestPostHeaderPriceFree
                            }
                            

                            if attribute.timestamp == nil {
                                let infoText = TextViewLayout(
                                    .initialize(
                                        string: amount != nil ? strings().chatSuggestPostPublishInfo(formatted, "\(comission.decemial.string)%") : strings().chatSuggestPostPublishInfoFree,
                                        color: theme.colors.text,
                                        font: .normal(.text)
                                    ),
                                    alignment: .center
                                )
                                infoText.measure(width: 260)

                                showModal(
                                    with: DateSelectorModalController(
                                        context: context,
                                        mode: .dateAction(
                                            title: strings().chatSuggestPostPublishAcceptTitle,
                                            done: { date in
                                                strings().chatSuggestPostPublishDateConfirm(stringForDate(timestamp: Int32(date.timeIntervalSince1970)))
                                            },
                                            action: .init(
                                                string: strings().chatSuggestPostPublishActionNow,
                                                callback: {
                                                    _ = context.engine.messages.monoforumPerformSuggestedPostAction(
                                                        id: keyboardMessage.id,
                                                        action: .approve(timestamp: nil)
                                                    ).start()
                                                }
                                            )
                                        ),
                                        selectedAt: { date in
                                            _ = context.engine.messages.monoforumPerformSuggestedPostAction(
                                                id: keyboardMessage.id,
                                                action: .approve(timestamp: Int32(date.timeIntervalSince1970))
                                            ).start()
                                        },
                                        infoText: infoText
                                    ),
                                    for: context.window
                                )
                            } else {
                                let author = keyboardMessage.author?.displayTitle ?? ""
                                let info: String
                                if let amount {
                                    info = strings().chatSuggestPostPublishConfirmInfo(author, formatted, "\(comission.decemial.string)%")
                                } else {
                                    info = strings().chatSuggestPostPublishConfirmInfoFree(author)
                                }
                                verifyAlert(
                                    for: context.window,
                                    header: strings().chatSuggestPostPublishConfirmHeader,
                                    information: info,
                                    ok: strings().chatSuggestPostPublishConfirmButton,
                                    successHandler: { _ in
                                        _ = context.engine.messages.monoforumPerformSuggestedPostAction(
                                            id: keyboardMessage.id,
                                            action: .approve(timestamp: nil)
                                        ).start()
                                    }
                                )
                            }
                        }
                        
                    case SuggestedPostMessageAttribute.commandDecline:
                        showModal(with: DeclineSuggestPostModalController(context: context, callback: { comment in
                            _ = context.engine.messages.monoforumPerformSuggestedPostAction(id: keyboardMessage.id, action: .reject(comment: comment.isEmpty ? nil : comment)).start()
                        }), for: context.window)
                        
                    case SuggestedPostMessageAttribute.commandChanges:
                        self?.beginEditingMessage(keyboardMessage)
                    default:
                        break
                    }
                default:
                    break
                }
            })
            
        }

        return ReplyMarkupInteractions(context: context, proccess: { [weak self] _,_ in
            self?.executeReplymarkup(keyboardMessage.id)
        })
    }
    
    
    
    public func saveState(_ force:Bool = true, scrollState: ChatInterfaceHistoryScrollState? = nil, sync: Bool = false) {
        
        if mode.customChatContents != nil || mode.customChatLink != nil {
            return
        }
        
        let peerId = self.peerId
        let context = self.context
        let timestamp = Int32(Date().timeIntervalSince1970)
        let interfaceState = presentation.interfaceState.withUpdatedTimestamp(timestamp).withUpdatedHistoryScrollState(scrollState)
        
        let updatedOpaqueData = try? EngineEncoder.encode(interfaceState)

        var s:Signal<Never, NoError> = context.engine.peers.setOpaqueChatInterfaceState(peerId: peerId, threadId: chatLocation.threadId, state: .init(opaqueData: updatedOpaqueData, historyScrollMessageIndex: interfaceState.historyScrollMessageIndex, mediaDraftState: nil, synchronizeableInputState: interfaceState.synchronizeableInputState))

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
    
    func getMessages(_ messageIds: [MessageId], _ album: Bool) -> Signal<[Message], NoError> {
        if let hashtags = self.mode.customChatContents {
            return hashtags.messagesAtIds(messageIds, album: album)
        } else {
            return context.account.postbox.transaction { transaction in
                var list:[Message] = []
                for messageId in messageIds {
                    if let messages = transaction.getMessageGroup(messageId), album {
                        list.append(contentsOf: messages)
                    } else if let message = transaction.getMessage(messageId) {
                        list.append(message)
                    }
                }
                return list
            }
        }
    }

    
}



