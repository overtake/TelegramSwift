//
//  ChatInterfaceInteraction.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac
import MapKit


final class ReplyMarkupInteractions {
    let proccess:(ReplyMarkupButton, (Bool)->Void) -> Void
    
    init(proccess:@escaping (ReplyMarkupButton, (Bool)->Void)->Void) {
        self.proccess = proccess
    }
    
}


final class ChatInteraction : InterfaceObserver  {
    
    let chatLocation: ChatLocation
    
    var peerId : PeerId {
        switch chatLocation {
        case let .peer(peerId):
            return peerId
        case .group:
            return PeerId(0)
        }
    }
    
    var peer: Peer? {
        return presentation.peer
    }
    
    let account:Account
    let isLogInteraction:Bool
    let disableSelectAbility: Bool
    private let modifyDisposable:MetaDisposable = MetaDisposable()
    private let mediaDisposable:MetaDisposable = MetaDisposable()
    private let startBotDisposable:MetaDisposable = MetaDisposable()
    private let addContactDisposable:MetaDisposable = MetaDisposable()
    private let requestSessionId:MetaDisposable = MetaDisposable()
    private let disableProxyDisposable = MetaDisposable()
    private let enableProxyDisposable = MetaDisposable()
    init(chatLocation: ChatLocation, account:Account, isLogInteraction: Bool = false, disableSelectAbility: Bool = false) {
        self.chatLocation = chatLocation
        self.account = account
        self.disableSelectAbility = disableSelectAbility
        self.isLogInteraction = isLogInteraction
        self.presentation = ChatPresentationInterfaceState(chatLocation)
        super.init()
        
        let signal = mediaPromise.get() |> deliverOnMainQueue |> mapToQueue { [weak self] (media) -> Signal<Void, Void> in
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
    

    var setupReplyMessage: (MessageId?) -> Void = {_ in}
    var beginMessageSelection: (MessageId?) -> Void = {_ in}
    var deleteMessages: ([MessageId]) -> Void = {_ in }
    var forwardMessages: ([MessageId]) -> Void = {_ in}
    var sendMessage: () -> Void = {}
    var forceSendMessage: (ChatTextInputState) -> Void = {_ in}
    var sendPlainText: (String) -> Void = {_ in}

    //
    var focusMessageId: (MessageId?, MessageId, TableScrollState) -> Void = {_,_,_  in} // from, to, animated, position
    var sendMedia:([MediaSenderContainer]) -> Void = {_ in}
    var sendAppFile:(TelegramMediaFile) -> Void = {_ in}
    var sendMedias:([Media], ChatTextInputState, Bool) -> Void = {_,_,_ in}
    var focusInputField:()->Void = {}
    var openInfo:(PeerId, Bool, MessageId?, ChatInitialAction?) -> Void = {_,_,_,_  in} // peerId, isNeedOpenChat, postId, initialAction
    var beginEditingMessage:(Message?) -> Void = {_ in}
    var requestMessageActionCallback:(MessageId, Bool, MemoryBuffer?) -> Void = {_,_,_  in}
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
    var showPreviewSender:([URL], Bool)->Void = {_,_  in}
    var setSecretChatMessageAutoremoveTimeout:(Int32?)->Void = {_ in}
    var toggleNotifications:()->Void = {}
    var removeAndCloseChat:()->Void = {}
    var joinChannel:()->Void = {}
    var returnGroup:()->Void = {}
    var shareContact:(TelegramUser)->Void = {_ in}
    var unblock:()->Void = {}
    var updatePinned:(MessageId, Bool, Bool)->Void = {_,_,_ in}
    var reportSpamAndClose:()->Void = {}
    var dismissPeerReport:()->Void = {}
    var toggleSidebar:()->Void = {}
    var mentionPressed:()->Void = {}
    var jumpToDate:(Date)->Void = {_ in}
    var openFeedInfo: (PeerGroupId)->Void = {_ in}
    var showNextPost:()->Void = {}
    var startRecording:(Bool)->Void = {_ in}
    var openProxySettings: ()->Void = {}
    var sendLocation: (CLLocationCoordinate2D, MapVenue?) -> Void = {_, _ in}
    
    let loadingMessage: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    
    let mediaPromise:Promise<[MediaSenderContainer]> = Promise()
    
    func addContact() {
        addContactDisposable.set(addContactPeerInteractively(account: account, peerId: peerId, phone: (presentation.peer as? TelegramUser)?.phone).start())
    }
    
    func disableProxy() {
        let account = self.account
        disableProxyDisposable.set(updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current -> ProxySettings in
            return current.withUpdatedEnabled(false)
        }).start())
        
    }
    
    func applyProxy(_ server:ProxyServerSettings) -> Void {
        applyExternalProxy(server, postbox: account.postbox, network: account.network)
//        disableProxyDisposable.set(updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current -> ProxySettings in
//            return current.withAddedServer(server).withUpdatedActiveServer(server).withUpdatedEnabled(true)
//        }).start())
    }
    
    
    func call() {
        if let peer = presentation.peer {
            let peerId:PeerId
            if let peer = peer as? TelegramSecretChat {
                peerId = peer.regularPeerId
            } else {
                peerId = peer.id
            }
            requestSessionId.set((phoneCall(account, peerId: peerId) |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    applyUIPCallResult(strongSelf.account, result)
                }
            }))
        }
    }
    
    func startBot(_ payload:String? = nil) {
        startBotDisposable.set((requestStartBot(account: self.account, botPeerId: self.peerId, payload: payload) |> deliverOnMainQueue).start(completed: { [weak self] in
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
        let state = ChatTextInputState(inputText: text, selectionRange: text.length ..< text.length, attributes: [])
        self.update({$0.updatedInterfaceState({$0.withUpdatedInputState(state)})})
    }
    
    func appendText(_ text:String, selectedRange:Range<Int>? = nil) -> Range<Int> {
        var selectedRange = selectedRange ?? presentation.effectiveInput.selectionRange
        let inputText = presentation.effectiveInput.attributedString.mutableCopy() as! NSMutableAttributedString
        
        
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {
           // let minUtfIndex = inputText.utf16.index(inputText.utf16.startIndex, offsetBy: selectedRange.lowerBound)
           // let maxUtfIndex = inputText.utf16.index(minUtfIndex, offsetBy: selectedRange.upperBound - selectedRange.lowerBound)
            
            
            
           // inputText.removeSubrange(minUtfIndex.samePosition(in: inputText)! ..< maxUtfIndex.samePosition(in: inputText)!)
            inputText.replaceCharacters(in: NSMakeRange(selectedRange.lowerBound, selectedRange.upperBound - selectedRange.lowerBound), with: NSAttributedString(string: text))
            selectedRange = selectedRange.lowerBound ..< selectedRange.lowerBound
        } else {
            inputText.insert(NSAttributedString(string: text), at: selectedRange.lowerBound)
        }
        

        
//
//        var advance:Int = 0
//        for char in text.characters {
//            let index = inputText.utf16.index(inputText.utf16.startIndex, offsetBy: selectedRange.lowerBound + advance).samePosition(in: inputText)!
//            inputText.insert(char, at: index)
//            advance += 1
//        }
        let nRange:Range<Int> = selectedRange.lowerBound + text.length ..< selectedRange.lowerBound + text.length
        let state = ChatTextInputState(inputText: inputText.string, selectionRange: nRange, attributes: chatTextAttributes(from: inputText))
        self.update({$0.withUpdatedEffectiveInputState(state)})
        
        return selectedRange.lowerBound ..< selectedRange.lowerBound + text.length
    }
    
    func invokeInitialAction(includeAuto:Bool = false) {
        if let action = presentation.initialAction {
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
                    showPreviewSender( list.map { URL(fileURLWithPath: $0) }, true )
                }
            default:
                break
            }
        }
    }
    
    
    func processBotKeyboard(with keyboardMessage:Message) ->ReplyMarkupInteractions {
        if let attribute = keyboardMessage.replyMarkup, !isLogInteraction {
            
            return ReplyMarkupInteractions(proccess: { [weak self] (button, progress) in
                if let strongSelf = self {
                    switch button.action {
                    case let .url(url):
                        execute(inapp: inApp(for: url.nsstring, account: strongSelf.account, openInfo: strongSelf.openInfo, hashtag: strongSelf.modalSearch, command: strongSelf.sendPlainText, applyProxy: strongSelf.applyProxy))
                    case .text:
                        _ = (enqueueMessages(account: strongSelf.account, peerId: strongSelf.peerId, messages: [EnqueueMessage.message(text: button.title, attributes: [], media: nil, replyToMessageId: strongSelf.presentation.interfaceState.messageActionsState.processedSetupReplyMessageId, localGroupingKey: nil)]) |> deliverOnMainQueue).start(next: { [weak strongSelf] _ in
                            strongSelf?.scrollToLatest(true)
                        })
                    case .requestPhone:
                        strongSelf.shareSelfContact(nil)
                    case .openWebApp:
                        strongSelf.requestMessageActionCallback(keyboardMessage.id, true, nil)
                    case let .callback(data):
                        strongSelf.requestMessageActionCallback(keyboardMessage.id, false, data)
                    case let .switchInline(samePeer: same, query: query):
                        let text = "@\(keyboardMessage.inlinePeer?.username ?? keyboardMessage.author?.username ?? "") \(query)"
                        if same {
                            strongSelf.updateInput(with: text)
                        } else {
                            if let peer = keyboardMessage.inlinePeer {
                                strongSelf.account.context.mainNavigation?.set(modalAction: ShareInlineResultNavigationAction(payload: text, botName: peer.displayTitle), strongSelf.account.context.layout != .single)
                                if strongSelf.account.context.layout == .single {
                                    strongSelf.account.context.mainNavigation?.push(ForwardChatListController(strongSelf.account))
                                }
                            }
                            
                        }
                    case .payment:
                        alert(for: mainWindow, info: tr(L10n.paymentsUnsupported))
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
    
    public func saveState(_ force:Bool = true, scrollState: ChatInterfaceHistoryScrollState? = nil) {
        
        
        let timestamp = Int32(Date().timeIntervalSince1970)
        let interfaceState = presentation.interfaceState.withUpdatedTimestamp(timestamp).withUpdatedHistoryScrollState(scrollState)
        
        var s:Signal<Void,Void> = updatePeerChatInterfaceState(account: account, peerId: peerId, state: interfaceState)
        if !force {
            s = s |> delay(10, queue: Queue.mainQueue())
        }
        
        modifyDisposable.set(s.start())
    }
    
    

    deinit {
        addContactDisposable.dispose()
        mediaDisposable.dispose()
        startBotDisposable.dispose()
        requestSessionId.dispose()
        disableProxyDisposable.dispose()
        enableProxyDisposable.dispose()
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

