//
//  ChatHeaderController.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac



enum ChatHeaderState : Identifiable, Equatable {
    case none
    case search(ChatSearchInteractions, Peer?)
    case addContact(block: Bool)
    case shareInfo
    case pinned(MessageId)
    case report
    case sponsored
    var stableId:Int {
        switch self {
        case .none:
            return 0
        case .search:
            return 1
        case .report:
            return 2
        case .addContact:
            return 3
        case .pinned:
            return 4
        case .sponsored:
            return 5
        case .shareInfo:
            return 6
        }
    }
    
    var height:CGFloat {
        switch self {
        case .none:
            return 0
        case .search:
            return 44
        case .report:
            return 44
        case .addContact:
            return 44
        case .shareInfo:
            return 44
        case .pinned:
            return 44
        case .sponsored:
            return 44
        }
    }
    
    static func ==(lhs:ChatHeaderState, rhs: ChatHeaderState) -> Bool {
        switch lhs {
        case let .pinned(pinnedId):
            if case .pinned(pinnedId) = rhs {
                return true
            } else {
                return false
            }
        default:
            return lhs.stableId == rhs.stableId
        }
    }
}




class ChatHeaderController {
    
    
    private var _headerState:ChatHeaderState = .none
    private let chatInteraction:ChatInteraction
    
    private(set) var currentView:View?
    
    var state:ChatHeaderState {
        return _headerState
    }
    
    func updateState(_ state:ChatHeaderState, animated:Bool, for view:View) -> Void {
        if _headerState != state {
            let previousState = _headerState
            _headerState = state
            
            if let current = currentView {
                if animated {
                    currentView?.layer?.animatePosition(from: NSZeroPoint, to: NSMakePoint(0, -previousState.height), duration: 0.2, removeOnCompletion:false, completion: { [weak current] complete in
                        if complete {
                            current?.removeFromSuperview()
                        }
                        
                    })
                } else {
                    currentView?.removeFromSuperview()
                    currentView = nil
                }
            }
            
            currentView = viewIfNecessary(NSMakeSize(view.frame.width, state.height))
            
            if let newView = currentView {
                view.addSubview(newView)
                (newView as? ChatSearchHeader)?.applySearchResponder()
                newView.layer?.removeAllAnimations()
                if animated {
                    newView.layer?.animatePosition(from: NSMakePoint(0,-state.height), to: NSZeroPoint, duration: 0.2, completion: { [weak newView] _ in
                        
                    })
                }
            }
        }
    }
    
    private func viewIfNecessary(_ size:NSSize) -> View? {
        let view:View?
        switch _headerState {
        case let .addContact(block):
            view = AddContactView(chatInteraction, canBlock: block)
        case .shareInfo:
            view = ShareInfoView(chatInteraction)
        case let .pinned(messageId):
            view = ChatPinnedView(messageId, chatInteraction: chatInteraction)
        case let .search(interactions, initialPeer):
            view = ChatSearchHeader(interactions, chatInteraction: chatInteraction, initialPeer: initialPeer)
        case .report:
            view = ChatReportView(chatInteraction)
        case .sponsored:
            view = ChatSponsoredView(chatInteraction: chatInteraction)
        case .none:
            view = nil
        
        }
        view?.frame = NSMakeRect(0, 0, size.width, size.height)
        return view
    }
    
    init(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
    }
    
}

struct ChatSearchInteractions {
    let jump:(Message)->Void
    let results:(String)->Void
    let calendarAction:(Date)->Void
    let cancel:()->Void
    let searchRequest:(String, PeerId?, SearchMessagesState?) -> Signal<([Message], SearchMessagesState?), NoError>
}

private class ChatSponsoredModel: ChatAccessoryModel {
    

    init() {
        super.init()
        update()
    }
    
    func update() {
        self.headerAttr = .initialize(string: L10n.chatProxySponsoredCapTitle, color: theme.colors.link, font: .medium(.text))
        self.messageAttr = .initialize(string: L10n.chatProxySponsoredCapDesc, color: theme.colors.text, font: .normal(.text))
        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
}

private final class ChatSponsoredView : Control {
    private let chatInteraction:ChatInteraction
    private let container:ChatAccessoryView = ChatAccessoryView()
    private let dismiss:ImageButton = ImageButton()
    private let node: ChatSponsoredModel = ChatSponsoredModel()
    init(chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init()
        
        dismiss.disableActions()
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = self.dismiss.sizeToFit()
        
        self.set(handler: { _ in
            confirm(for: mainWindow, header: L10n.chatProxySponsoredAlertHeader, information: L10n.chatProxySponsoredAlertText, cancelTitle: "", thridTitle: L10n.chatProxySponsoredAlertSettings, successHandler: { result in
                switch result {
                case .thrid:
                    chatInteraction.openProxySettings()
                default:
                    break
                }
            })
        }, for: .Click)
        
        dismiss.set(handler: { _ in
            FastSettings.adAlertViewed()
            chatInteraction.update({$0.withoutInitialAction()})
        }, for: .SingleClick)
        
        node.view = container
        
        addSubview(dismiss)
        container.userInteractionEnabled = false
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        addSubview(container)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.backgroundColor = theme.colors.background
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        container.backgroundColor = theme.colors.background
    }
    
    override func layout() {
        node.update()
        node.measureSize(frame.width - 70)
        container.setFrameSize(frame.width - 70, node.size.height)
        container.centerY(x: 20)
        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        node.setNeedDisplay()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class ChatPinnedView : Control {
    private let node:ReplyModel
    private let chatInteraction:ChatInteraction
    private let readyDisposable = MetaDisposable()
    private let container:ChatAccessoryView = ChatAccessoryView()
    private let dismiss:ImageButton = ImageButton()
    private let loadMessageDisposable = MetaDisposable()
    init(_ messageId:MessageId, chatInteraction:ChatInteraction) {
        node = ReplyModel(replyMessageId: messageId, account: chatInteraction.context.account, replyMessage: chatInteraction.presentation.cachedPinnedMessage, isPinned: true)
        self.chatInteraction = chatInteraction
        super.init()
        
        dismiss.disableActions()
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = self.dismiss.sizeToFit()
        
        self.set(handler: { [weak self] _ in
            self?.chatInteraction.focusMessageId(nil, messageId, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
        }, for: .Click)
        
        dismiss.set(handler: { [weak self] _ in
            self?.chatInteraction.updatePinned(messageId, true, false)
        }, for: .SingleClick)
        
        addSubview(dismiss)
        container.userInteractionEnabled = false
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        addSubview(container)
        node.view = container
        readyDisposable.set(node.nodeReady.get().start(next: { [weak self] result in
            self?.needsLayout = true
            
            if !result, let chatInteraction = self?.chatInteraction {
                _ = requestUpdatePinnedMessage(account: chatInteraction.context.account, peerId: chatInteraction.peerId, update: .clear).start()
            }
        }))
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        node.update()
        self.backgroundColor = theme.colors.background
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        container.backgroundColor = theme.colors.background
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
 
    override func layout() {
        node.measureSize(frame.width - 70)
        container.setFrameSize(frame.width - 70, node.size.height)
        container.centerY(x: 20)
        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        node.setNeedDisplay()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    deinit {
        readyDisposable.dispose()
        loadMessageDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class ChatReportView : Control {
    private let chatInteraction:ChatInteraction
    private let report:TitleButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()

    init(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init()
        dismiss.disableActions()
        
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        
        report.set(text: L10n.chatHeaderReportSpam, for: .Normal)
        _ = report.sizeToFit()
        
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = self.dismiss.sizeToFit()
        
        report.set(handler: { _ in
            chatInteraction.reportSpamAndClose()
        }, for: .SingleClick)
        
        dismiss.set(handler: { _ in
            chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        
        addSubview(dismiss)
        addSubview(report)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        report.set(text: tr(L10n.chatHeaderReportSpam), for: .Normal)
        report.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.redUI, backgroundColor: theme.colors.background, highlightColor: theme.colors.blueSelect)
        _ = report.sizeToFit()
        self.backgroundColor = theme.colors.background
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        report.center()
        dismiss.centerY(x: frame.width - dismiss.frame.width - 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class ShareInfoView : Control {
    private let chatInteraction:ChatInteraction
    private let share:TitleButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()
    init(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init()
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        dismiss.disableActions()
        
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = dismiss.sizeToFit()
        
        share.set(handler: { _ in
            chatInteraction.shareSelfContact(nil)
            chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        
        dismiss.set(handler: { _ in
            chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        
        
        
        addSubview(share)
        addSubview(dismiss)
        updateLocalizationAndTheme()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if window == nil {
            var bp:Int = 0
            bp += 1
        }
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        share.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background, highlightColor: theme.colors.blueSelect)
        
        share.set(text: L10n.peerInfoShareMyInfo, for: .Normal)

        self.backgroundColor = theme.colors.background
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        super.layout()
        dismiss.centerY(x: frame.width - dismiss.frame.width - 20)
        share.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class AddContactView : Control {
    private let chatInteraction:ChatInteraction
    private let add:TitleButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()
    private let blockButton: TitleButton = TitleButton()
    private let buttonsContainer = View()
    init(_ chatInteraction:ChatInteraction, canBlock: Bool) {
        self.chatInteraction = chatInteraction
        super.init()
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        dismiss.disableActions()
        
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = dismiss.sizeToFit()

        add.set(handler: { _ in
            chatInteraction.addContact()
        }, for: .SingleClick)
        
        dismiss.set(handler: { _ in
            chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        
        blockButton.set(handler: { _ in
            chatInteraction.blockContact()
        }, for: .SingleClick)
        
        
       
        
        buttonsContainer.addSubview(add)
        if canBlock {
            buttonsContainer.addSubview(blockButton)
        }
        addSubview(buttonsContainer)
        addSubview(dismiss)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        add.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background, highlightColor: theme.colors.blueSelect)
        blockButton.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.redUI, backgroundColor: theme.colors.background, highlightColor: theme.colors.redUI)
        
        if blockButton.superview == nil, let peer = chatInteraction.peer {
            add.set(text: L10n.peerInfoAddUserToContact(peer.compactDisplayTitle), for: .Normal)
        } else {
            add.set(text: L10n.peerInfoAddContact, for: .Normal)
        }
        blockButton.set(text: L10n.peerInfoBlockUser, for: .Normal)

        
        self.backgroundColor = theme.colors.background
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        dismiss.centerY(x: frame.width - dismiss.frame.width - 20)
        if blockButton.superview == nil {
            buttonsContainer.frame = NSMakeRect(0, 0, frame.width, frame.height - .borderSize)
            add.setFrameSize(NSMakeSize(add.frame.width, buttonsContainer.frame.height))
            add.center()
        } else {
            buttonsContainer.frame = NSMakeRect(0, 0, frame.width - (frame.width - dismiss.frame.minX), frame.height - .borderSize)
            add.frame = NSMakeRect(buttonsContainer.frame.width / 2, 0, buttonsContainer.frame.width / 2, buttonsContainer.frame.height)
            blockButton.frame = NSMakeRect(0, 0, buttonsContainer.frame.width / 2, buttonsContainer.frame.height)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

private final class CSearchContextState : Equatable {
    let inputQueryResult: ChatPresentationInputQueryResult?
    let tokenState: TokenSearchState
    let peerId:PeerId?
    let messages: ([Message], SearchMessagesState?)
    let selectedIndex: Int
    let searchState: SearchState
    
    init(inputQueryResult: ChatPresentationInputQueryResult? = nil, messages: ([Message], SearchMessagesState?) = ([], nil), selectedIndex: Int = -1, searchState: SearchState = SearchState(state: .None, request: ""), tokenState: TokenSearchState = .none, peerId: PeerId? = nil) {
        self.inputQueryResult = inputQueryResult
        self.tokenState = tokenState
        self.peerId = peerId
        self.messages = messages
        self.selectedIndex = selectedIndex
        self.searchState = searchState
    }
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: f(self.inputQueryResult), messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedTokenState(_ token: TokenSearchState) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: token, peerId: self.peerId)
    }
    func updatedPeerId(_ peerId: PeerId?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: peerId)
    }
    func updatedMessages(_ messages: ([Message], SearchMessagesState?)) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedSelectedIndex(_ selectedIndex: Int) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedSearchState(_ searchState: SearchState) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
}

private func ==(lhs: CSearchContextState, rhs: CSearchContextState) -> Bool {
    if lhs.messages.0.count != rhs.messages.0.count {
        return false
    } else {
        for i in 0 ..< lhs.messages.0.count {
            if !isEqualMessages(lhs.messages.0[i], rhs.messages.0[i]) {
                return false
            }
        }
    }
    return lhs.inputQueryResult == rhs.inputQueryResult && lhs.tokenState == rhs.tokenState && lhs.selectedIndex == rhs.selectedIndex && lhs.searchState == rhs.searchState && lhs.messages.1 == rhs.messages.1
}

private final class CSearchInteraction : InterfaceObserver {
    private(set) var state: CSearchContextState = CSearchContextState()
    
    func update(animated:Bool = true, _ f:(CSearchContextState)->CSearchContextState) -> Void {
        let oldValue = self.state
        self.state = f(state)
        if oldValue != state {
            notifyObservers(value: state, oldValue:oldValue, animated: animated)
        }
    }
    
    var currentMessage: Message? {
        if state.messages.0.isEmpty {
            return nil
        } else if state.messages.0.count <= state.selectedIndex || state.selectedIndex < 0 {
            return nil
        }
        return state.messages.0[state.selectedIndex]
    }
}

struct SearchStateQuery : Equatable {
    let query: String?
    let state: SearchMessagesState?
    init(_ query: String?, _ state: SearchMessagesState?) {
        self.query = query
        self.state = state
    }
}

struct SearchMessagesResultState : Equatable {
    static func == (lhs: SearchMessagesResultState, rhs: SearchMessagesResultState) -> Bool {
        if lhs.query != rhs.query {
            return false
        }
        if lhs.messages.count != rhs.messages.count {
            return false
        } else {
            for i in 0 ..< lhs.messages.count {
                if !isEqualMessages(lhs.messages[i], rhs.messages[i]) {
                    return false
                }
            }
        }
        return true
    }
    
    let query: String
    let messages: [Message]
    init(_ query: String, _ messages: [Message]) {
        self.query = query
        self.messages = messages
    }
    
    func containsMessage(_ message: Message) -> Bool {
        return self.messages.contains(where: { $0.id == message.id })
    }
}

class ChatSearchHeader : View, Notifable {
    
    private let searchView:ChatSearchView = ChatSearchView(frame: NSZeroRect)
    private let cancel:ImageButton = ImageButton()
    private let from:ImageButton = ImageButton()
    private let calendar:ImageButton = ImageButton()
    
    private let prev:ImageButton = ImageButton()
    private let next:ImageButton = ImageButton()

    
    private let separator:View = View()
    private let interactions:ChatSearchInteractions
    private let chatInteraction: ChatInteraction
    
    private let query:ValuePromise<SearchStateQuery> = ValuePromise()

    private let disposable:MetaDisposable = MetaDisposable()
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let inputInteraction: CSearchInteraction = CSearchInteraction()
    private let parentInteractions: ChatInteraction
    private let loadingDisposable = MetaDisposable()
   
    private let calendarController: CalendarController
    init(_ interactions:ChatSearchInteractions, chatInteraction: ChatInteraction, initialPeer: Peer?) {
        self.interactions = interactions
        self.parentInteractions = chatInteraction
        self.calendarController = CalendarController(NSMakeRect(0, 0, 250, 250), chatInteraction.context.window, selectHandler: interactions.calendarAction)
        self.chatInteraction = ChatInteraction(chatLocation: chatInteraction.chatLocation, context: chatInteraction.context)
        self.chatInteraction.update({$0.updatedPeer({_ in chatInteraction.presentation.peer})})
        self.inputContextHelper = InputContextHelper(chatInteraction: self.chatInteraction, highlightInsteadOfSelect: true)
        
        super.init()
        
        self.chatInteraction.movePeerToInput = { [weak self] peer in
            self?.searchView.completeToken(peer.compactDisplayTitle)
            self?.inputInteraction.update({$0.updatedPeerId(peer.id)})
        }
        
        
        self.chatInteraction.focusMessageId = { [weak self] fromId, messageId, state in
            self?.parentInteractions.focusMessageId(fromId, messageId, state)
            self?.inputInteraction.update({$0.updatedSelectedIndex($0.messages.0.firstIndex(where: {$0.id == messageId}) ?? -1)})
            _ = self?.window?.makeFirstResponder(nil)
        }
        
     

        initialize()
        

        
        parentInteractions.loadingMessage.set(.single(false))
        
        inputInteraction.add(observer: self)
        self.loadingDisposable.set((parentInteractions.loadingMessage.get() |> deliverOnMainQueue).start(next: { [weak self] loading in
            self?.searchView.isLoading = loading
        }))
        if let initialPeer = initialPeer {
            self.chatInteraction.movePeerToInput(initialPeer)
            Queue.mainQueue().justDispatch {
                self.searchView.change(state: .Focus, false)
            }
        }
      
    }
    
    func applySearchResponder() {
       // _ = window?.makeFirstResponder(searchView.input)
        searchView.layout()
        if searchView.state == .Focus && window?.firstResponder != searchView.input {
            _ = window?.makeFirstResponder(searchView.input)
        }
        searchView.change(state: .Focus, false)
    }
    
    private var calendarAbility: Bool {
        return true
    }
    
    private var fromAbility: Bool {
        if let peer = chatInteraction.presentation.peer {
            return peer.isSupergroup || peer.isGroup
        } else {
            return false
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        let context = chatInteraction.context
        if let value = value as? CSearchContextState, let oldValue = oldValue as? CSearchContextState, let view = superview {
            
            let stateValue = self.query
            
            prev.isEnabled = !value.messages.0.isEmpty && value.selectedIndex < value.messages.0.count - 1
            next.isEnabled = !value.messages.0.isEmpty && value.selectedIndex > 0
            next.set(image: next.isEnabled ? theme.icons.chatSearchDown : theme.icons.chatSearchDownDisabled, for: .Normal)
            prev.set(image: prev.isEnabled ? theme.icons.chatSearchUp : theme.icons.chatSearchUpDisabled, for: .Normal)

            
            
            if let peer = chatInteraction.presentation.peer {
                if value.inputQueryResult != oldValue.inputQueryResult {
                    inputContextHelper.context(with: value.inputQueryResult, for: view, relativeView: self, position: .below, selectIndex: value.selectedIndex != -1 ? value.selectedIndex : nil, animated: animated)
                }
                switch value.tokenState {
                case .none:
                    from.isHidden = !fromAbility
                    calendar.isHidden = !calendarAbility
                    needsLayout = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    inputInteraction.update(animated: animated, { state in
                        return state.updatedInputQueryResult { previousResult in
                            
                            let result = state.searchState.responder ? state.messages : ([], nil)
                            return .searchMessages((result.0, result.1, { searchMessagesState in
                                stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                            }), state.searchState.request)
                        }.updatedPeerId(nil)
                    })
                case let .from(query, complete):
                    from.isHidden = true
                    calendar.isHidden = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    needsLayout = true
                    if complete {
                        inputInteraction.update(animated: animated, { state in
                            return state.updatedInputQueryResult { previousResult in
                                let result = state.searchState.responder ? state.messages : ([], nil)
                                return .searchMessages((result.0, result.1, { searchMessagesState in
                                    stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                                }), state.searchState.request)
                            }
                        })
                    } else {
                        if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(peer: peer, .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, context: context) {
                            self.contextQueryState?.1.dispose()
                            var inScope = true
                            var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                            self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                                if let strongSelf = self {
                                    if Thread.isMainThread && inScope {
                                        inScope = false
                                        inScopeResult = result
                                    } else {
                                        strongSelf.inputInteraction.update(animated: animated, {
                                            $0.updatedInputQueryResult { previousResult in
                                                return result(previousResult)
                                            }.updatedMessages(([], nil)).updatedSelectedIndex(-1)
                                        })
                                        
                                    }
                                }
                            }))
                            inScope = false
                            if let inScopeResult = inScopeResult {
                                inputInteraction.update(animated: animated, {
                                    $0.updatedInputQueryResult { previousResult in
                                        return inScopeResult(previousResult)
                                    }.updatedMessages(([], nil)).updatedSelectedIndex(-1)
                                })
                            }
                        }
                    }
                }
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let to = other as? ChatSearchView {
            return to === other
        } else {
            return false
        }
    }
    
    
    
    
    
    private func initialize() {
        self.from.isHidden = !fromAbility
        
        _ = self.searchView.tokenPromise.get().start(next: { [weak self] state in
            self?.inputInteraction.update({$0.updatedTokenState(state)})
        })
        
     
        self.searchView.searchInteractions = SearchInteractions({ [weak self] state, _ in
            if state.state == .None {
                self?.parentInteractions.loadingMessage.set(.single(false))
                self?.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                self?.inputInteraction.update({$0.updatedMessages(([], nil)).updatedSelectedIndex(-1).updatedSearchState(state)})
            }
        }, { [weak self] state in
            guard let `self` = self else {return}
            
            self.inputInteraction.update({$0.updatedMessages(([], nil)).updatedSelectedIndex(-1).updatedSearchState(state)})
            
            self.updateSearchState()
            switch self.searchView.tokenState {
            case .none:
                if state.request == L10n.chatSearchFrom, let peer = self.chatInteraction.presentation.peer, peer.isGroup || peer.isSupergroup  {
                    self.query.set(SearchStateQuery("", nil))
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
                    self.searchView.initToken()
                } else {
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                    self.parentInteractions.loadingMessage.set(.single(true))
                    self.query.set(SearchStateQuery(state.request, nil))
                }
                
            case .from(_, let complete):
                if complete {
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                    self.parentInteractions.loadingMessage.set(.single(true))
                    self.query.set(SearchStateQuery(state.request, nil))
                }
            }
            
        }, responderModified: { [weak self] state in
            self?.inputInteraction.update({$0.updatedSearchState(state)})
        })
 
        
        let apply = query.get() |> mapToSignal { [weak self] state -> Signal<([Message], SearchMessagesState?, String), NoError> in
            
            guard let `self` = self else { return .single(([], nil, "")) }
            if let query = state.query {
                
                let stateSignal: Signal<SearchMessagesState?, NoError>
                if state.state == nil {
                    stateSignal = .single(state.state) |> delay(0.3, queue: Queue.mainQueue())
                } else {
                    stateSignal = .single(state.state)
                }
                
                return stateSignal |> mapToSignal { [weak self] state in
                    
                    guard let `self` = self else { return .single(([], nil, "")) }
                    
                    let emptyRequest: Bool
                    if case .from = self.inputInteraction.state.tokenState {
                        emptyRequest = true
                    } else {
                        emptyRequest = !query.isEmpty
                    }
                    if emptyRequest {
                        return self.interactions.searchRequest(query, self.inputInteraction.state.peerId, state) |> map { ($0.0, $0.1, query) }
                    } else {
                        return .single(([], nil, ""))
                    }
                }
            } else {
                return .single(([], nil, ""))
            }
        } |> deliverOnMainQueue
        
        self.disposable.set(apply.start(next: { [weak self] messages in
            guard let `self` = self else {return}
            self.parentInteractions.updateSearchRequest(SearchMessagesResultState(messages.2, messages.0))
            self.inputInteraction.update({$0.updatedMessages((messages.0, messages.1)).updatedSelectedIndex(-1)})
            self.parentInteractions.loadingMessage.set(.single(false))
        }))
        
        next.autohighlight = false
        prev.autohighlight = false



        _ = calendar.sizeToFit()
        
        addSubview(next)
        addSubview(prev)

        
        addSubview(from)
        
        
        addSubview(calendar)
        
        calendar.isHidden = !calendarAbility
        
        _ = cancel.sizeToFit()
        
        let interactions = self.interactions
        let searchView = self.searchView
        cancel.set(handler: { [weak self] _ in
            self?.inputInteraction.update {$0.updatedTokenState(.none).updatedSelectedIndex(-1).updatedMessages(([], nil)).updatedSearchState(SearchState(state: .None, request: ""))}
            self?.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
            interactions.cancel()
        }, for: .Click)
        
        next.set(handler: { [weak self] _ in
            self?.nextAction()
            }, for: .Click)
        prev.set(handler: { [weak self] _ in
            self?.prevAction()
        }, for: .Click)

        

        from.set(handler: { [weak self] _ in
            self?.searchView.initToken()
        }, for: .Click)
        
        
        
        calendar.set(handler: { [weak self] calendar in
            guard let `self` = self else {return}
            showPopover(for: calendar, with: self.calendarController, edge: .maxY, inset: NSMakePoint(-160, -40))
        }, for: .Click)

        addSubview(searchView)
        addSubview(cancel)
        addSubview(separator)
        
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        backgroundColor = theme.colors.background
        
        next.set(image: theme.icons.chatSearchDown, for: .Normal)
        _ = next.sizeToFit()
        
        prev.set(image: theme.icons.chatSearchUp, for: .Normal)
        _ = prev.sizeToFit()


        calendar.set(image: theme.icons.chatSearchCalendar, for: .Normal)
        _ = calendar.sizeToFit()
        
        cancel.set(image: theme.icons.chatSearchCancel, for: .Normal)
        _ = cancel.sizeToFit()

        from.set(image: theme.icons.chatSearchFrom, for: .Normal)
        _ = from.sizeToFit()
        
        separator.backgroundColor = theme.colors.border
        self.backgroundColor = theme.colors.background
        needsLayout = true
        updateSearchState()
    }
    
    func updateSearchState() {
       
    }
    
    func prevAction() {
        inputInteraction.update({$0.updatedSelectedIndex(min($0.selectedIndex + 1, $0.messages.0.count - 1))})
        perform()
    }
    
    func perform() {
        _ = window?.makeFirstResponder(nil)
        if let currentMessage = inputInteraction.currentMessage {
            interactions.jump(currentMessage)
        }
    }
    
    func nextAction() {
        inputInteraction.update({$0.updatedSelectedIndex(max($0.selectedIndex - 1, 0))})
        perform()
    }
    
    private var searchWidth: CGFloat {
        return frame.width - cancel.frame.width - 20 - 20 - 80 - (calendar.isHidden ? 0 : calendar.frame.width + 20) - (from.isHidden ? 0 : from.frame.width + 20)
    }
    
    override func layout() {
        super.layout()
        
        
        prev.centerY(x:10)
        next.centerY(x:prev.frame.maxX)


        cancel.centerY(x:frame.width - cancel.frame.width - 20)

        searchView.setFrameSize(NSMakeSize(searchWidth, 30))
        inputContextHelper.controller.view.setFrameSize(frame.width, inputContextHelper.controller.frame.height)
        searchView.centerY(x: 80)
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        
        from.centerY(x: searchView.frame.maxX + 20)
        calendar.centerY(x: (from.isHidden ? searchView : from).frame.maxX + 20)

    }
    
    override func viewDidMoveToWindow() {
        if let _ = window {
            layout()
            //self.searchView.change(state: .Focus, false)
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
         //   self.searchView.change(state: .None, false)
        }
    }
    
    
    deinit {
        inputInteraction.update(animated: false, { state in
            return state.updatedInputQueryResult( { _ in return nil } )
        })
        parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
        disposable.dispose()
        inputInteraction.remove(observer: self)
        loadingDisposable.set(nil)
        if let window = window as? Window {
            window.removeAllHandlers(for: self)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(frame frameRect: NSRect, interactions:ChatSearchInteractions, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction
        self.parentInteractions = chatInteraction
        self.inputContextHelper = InputContextHelper(chatInteraction: chatInteraction, highlightInsteadOfSelect: true)
        self.calendarController = CalendarController(NSMakeRect(0,0,250,250), chatInteraction.context.window, selectHandler: interactions.calendarAction)
        super.init(frame: frameRect)
        initialize()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
