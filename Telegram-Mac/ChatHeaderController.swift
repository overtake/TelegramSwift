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
    case search(ChatSearchInteractions)
    case addContact
    case pinned(MessageId)
    case report
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
        case .pinned:
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
                newView.layer?.removeAllAnimations()
                if animated {
                    newView.layer?.animatePosition(from: NSMakePoint(0,-state.height), to: NSZeroPoint, duration: 0.2)
                }
            }
        }
    }
    
    private func viewIfNecessary(_ size:NSSize) -> View? {
        let view:View?
        switch _headerState {
        case .addContact:
            view = AddContactView(chatInteraction)
        case let .pinned(messageId):
            view = ChatPinnedView(messageId, chatInteraction: chatInteraction)
        case let .search(interactions):
            view = ChatSearchHeader(interactions, chatInteraction: chatInteraction)
        case .report:
            view = ChatReportView(chatInteraction)
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
    let searchRequest:(String, PeerId?) -> Signal<[Message],Void>
}

class ChatPinnedView : Control {
    private let node:ReplyModel
    private let chatInteraction:ChatInteraction
    private let readyDisposable = MetaDisposable()
    private let container:ChatAccessoryView = ChatAccessoryView()
    private let dismiss:ImageButton = ImageButton()
    private let loadMessageDisposable = MetaDisposable()
    init(_ messageId:MessageId, chatInteraction:ChatInteraction) {
        node = ReplyModel(replyMessageId: messageId, account: chatInteraction.account, isPinned: true)
        self.chatInteraction = chatInteraction
        super.init()
        
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        self.dismiss.sizeToFit()
        
        self.set(handler: { [weak self] _ in
            self?.chatInteraction.focusMessageId(nil, messageId, .center(id: 0, animated: true, focus: true, inset: 0))
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
                _ = requestUpdatePinnedMessage(account: chatInteraction.account, peerId: chatInteraction.peerId, update: .clear).start()
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
    
 
    override func layout() {
        node.measureSize(frame.width - 70)
        container.setFrameSize(frame.width - 70, node.size.height)
        container.centerY(x: 20)
        dismiss.centerY(x: frame.width - 21 - dismiss.frame.width)
        node.setNeedDisplay()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
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
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        
        report.set(text: tr(.chatHeaderReportSpam), for: .Normal)
        report.sizeToFit()
        
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        self.dismiss.sizeToFit()
        
        report.set(handler: { _ in
            chatInteraction.reportSpamAndClose()
        }, for: .SingleClick)
        
        dismiss.set(handler: { _ in
            chatInteraction.dismissPeerReport()
        }, for: .SingleClick)
        
        addSubview(dismiss)
        addSubview(report)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        report.set(text: tr(.chatHeaderReportSpam), for: .Normal)
        report.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.blueUI, backgroundColor: theme.colors.background, highlightColor: theme.colors.blueSelect)
        report.sizeToFit()
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

class AddContactView : Control {
    private let chatInteraction:ChatInteraction
    private let add:TitleButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()

    init(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init()
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        
        add.set(text: tr(.peerInfoAddContact), for: .Normal)
        add.sizeToFit()
        
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        dismiss.sizeToFit()

        add.set(handler: { _ in
            chatInteraction.addContact()
        }, for: .SingleClick)
        
        dismiss.set(handler: { _ in
            
        }, for: .SingleClick)
        
        addSubview(add)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        add.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.blueUI, backgroundColor: theme.colors.background, highlightColor: theme.colors.blueSelect)
        self.backgroundColor = theme.colors.background
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        add.center()
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
    init(inputQueryResult: ChatPresentationInputQueryResult? = nil, tokenState: TokenSearchState = .none, peerId: PeerId? = nil) {
        self.inputQueryResult = inputQueryResult
        self.tokenState = tokenState
        self.peerId = peerId
    }
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: f(self.inputQueryResult), tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedTokenState(_ token: TokenSearchState) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, tokenState: token, peerId: self.peerId)
    }
    func updatedPeerId(_ peerId: PeerId?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, tokenState: self.tokenState, peerId: peerId)
    }
}

private func ==(lhs: CSearchContextState, rhs: CSearchContextState) -> Bool {
    return lhs.inputQueryResult == rhs.inputQueryResult && lhs.tokenState == rhs.tokenState
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
}

class ChatSearchHeader : View, Notifable {
    
    private let searchView:ChatSearchView = ChatSearchView(frame: NSZeroRect)
    private let cancel:ImageButton = ImageButton()
    private let prev:ImageButton = ImageButton()
    private let next:ImageButton = ImageButton()
    private let from:ImageButton = ImageButton()
    private let calendar:ImageButton = ImageButton()
    
    private let separator:View = View()
    private let interactions:ChatSearchInteractions
    private let chatInteraction: ChatInteraction
    
    private let query:Promise<String?> = Promise()
    private let disposable:MetaDisposable = MetaDisposable()
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let inputInteraction: CSearchInteraction = CSearchInteraction()
    
    private var messages:[Message] = []
    private var currentIndex:Int = 0 {
        didSet {
            searchView.countValue = (current: currentIndex + 1, total: messages.count)
        }
    }
    init(_ interactions:ChatSearchInteractions, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = ChatInteraction(peerId: chatInteraction.peerId, account: chatInteraction.account)
        self.chatInteraction.update({$0.updatedPeer({_ in chatInteraction.presentation.peer})})
        self.inputContextHelper = InputContextHelper(account: chatInteraction.account, chatInteraction: self.chatInteraction)
        super.init()
        
        self.chatInteraction.movePeerToInput = { [weak self] peer in
            self?.searchView.completeToken(peer.compactDisplayTitle)
            self?.inputInteraction.update({$0.updatedPeerId(peer.id)})
        }
        
        initialize()
        inputInteraction.add(observer: self)
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        let account = chatInteraction.account
        if let value = value as? CSearchContextState, let oldValue = oldValue as? CSearchContextState, let view = superview {
            if let peer = chatInteraction.presentation.peer {
                if value.inputQueryResult != oldValue.inputQueryResult {
                    inputContextHelper.context(with: value.inputQueryResult, for: view, relativeView: self, position: .below, animated: animated)
                }
                switch value.tokenState {
                case .none:
                    messages = []
                    currentIndex = -1
                    from.isHidden = false
                    calendar.isHidden = false
                    needsLayout = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    inputInteraction.update(animated: animated, {
                        $0.updatedInputQueryResult { previousResult in
                            return .mentions([])
                        }.updatedPeerId(nil)
                    })
                case let .from(query, complete):
                    from.isHidden = true
                    calendar.isHidden = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    needsLayout = true
                    if complete {
                        inputInteraction.update(animated: animated, {
                            $0.updatedInputQueryResult { previousResult in
                                return .mentions([])
                            }
                        })
                    } else {
                        messages = []
                        currentIndex = -1
                        if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(peer: peer, .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, account: account) {
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
                                            }
                                        })
                                        
                                    }
                                }
                            }))
                            inScope = false
                            if let inScopeResult = inScopeResult {
                                inputInteraction.update(animated: animated, {
                                    $0.updatedInputQueryResult { previousResult in
                                        return inScopeResult(previousResult)
                                    }
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
        if let peer = chatInteraction.presentation.peer {
            self.from.isHidden = !peer.isSupergroup && !peer.isGroup
        } else {
            self.from.isHidden = true
        }
        
        _ = self.searchView.tokenPromise.get().start(next: { [weak self] state in
            self?.inputInteraction.update({$0.updatedTokenState(state)})
        })
        
     
        self.searchView.searchInteractions = SearchInteractions({ [weak self] state in
            if state.state == .None {
                self?.searchView.isLoading = false
            }
        }, { [weak self] state in
            if let strongSelf = self {
                strongSelf.messages = []
                strongSelf.currentIndex = -1
                strongSelf.updateSearchState()
                switch strongSelf.searchView.tokenState {
                case .none:
                    if state.request == tr(.chatSearchFrom), let peer = strongSelf.chatInteraction.presentation.peer, peer.isGroup || peer.isSupergroup  {
                        strongSelf.query.set(.single(""))
                        strongSelf.searchView.initToken()
                    } else {
                        strongSelf.searchView.isLoading = true
                        strongSelf.query.set(.single(state.request))
                    }
                    
                case .from(_, let complete):
                    if complete {
                        strongSelf.searchView.isLoading = true
                        strongSelf.query.set(.single(state.request))
                    }
                }
              
            }
            
        })
 
        
        let apply = query.get() |> mapToSignal { [weak self] query -> Signal<[Message], Void> in
            if let strongSelf = self, let query = query {
                return .single(Void()) |> delay(0.3, queue: Queue.mainQueue()) |> mapToSignal { [weak strongSelf] () -> Signal<[Message], Void> in
                    if let strongSelf = strongSelf {
                        return strongSelf.interactions.searchRequest(query, strongSelf.inputInteraction.state.peerId)
                    }
                    return .single([])
                }
            } else {
                return .single([])
            }
        } |> deliverOnMainQueue
        
        self.disposable.set(apply.start(next: { [weak self] messages in
            self?.messages = messages
            self?.currentIndex = -1
            self?.prevAction()
            self?.searchView.isLoading = false
            
        }, error: { [weak self] in
            self?.messages = []
            self?.currentIndex = -1
            self?.prevAction()
            self?.searchView.isLoading = false
        }))

        next.autohighlight = false
        prev.autohighlight = false

        calendar.sizeToFit()
        
        addSubview(next)
        addSubview(prev)
        addSubview(from)
        addSubview(calendar)
        
        cancel.sizeToFit()
        
        let interactions = self.interactions
        let searchView = self.searchView
        cancel.set(handler: { [weak self] _ in
            self?.inputInteraction.update {$0.updatedTokenState(.none)}
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
            if let strongSelf = self {
                showPopover(for: calendar, with: CalendarController(NSMakeRect(0,0,250,250), selectHandler: strongSelf.interactions.calendarAction), edge: .maxY, inset: NSMakePoint(-160, -40))
            }
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
        next.sizeToFit()
        
        prev.set(image: theme.icons.chatSearchUp, for: .Normal)
        prev.sizeToFit()

        calendar.set(image: theme.icons.chatSearchCalendar, for: .Normal)
        calendar.sizeToFit()
        
        cancel.set(image: theme.icons.chatSearchCancel, for: .Normal)
        cancel.sizeToFit()

        from.set(image: theme.icons.chatSearchFrom, for: .Normal)
        from.sizeToFit()
        
        separator.backgroundColor = theme.colors.border
        self.backgroundColor = theme.colors.background
        needsLayout = true
        updateSearchState()
    }
    
    func updateSearchState() {
        prev.isEnabled = !messages.isEmpty && currentIndex < messages.count - 1
        next.isEnabled = !messages.isEmpty && currentIndex > 0
        next.set(image: next.isEnabled ? theme.icons.chatSearchDown : theme.icons.chatSearchDownDisabled, for: .Normal)
        prev.set(image: prev.isEnabled ? theme.icons.chatSearchUp : theme.icons.chatSearchUpDisabled, for: .Normal)
    }
    
    func prevAction() {
        if !messages.isEmpty {
            currentIndex += 1
            currentIndex = min(messages.count - 1, currentIndex)
            perform()
        }
    }
    
    func perform() {
        interactions.jump(messages[min(max(0,currentIndex), messages.count - 1)])
        updateSearchState()
    }
    
    func nextAction() {
        if !messages.isEmpty {
            currentIndex -= 1
            currentIndex = max(0, currentIndex)
            perform()
        }
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
        searchView.centerY(x:80)
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        
        from.centerY(x: searchView.frame.maxX + 20)
        calendar.centerY(x: (from.isHidden ? searchView : from).frame.maxX + 20)

    }
    
    override func viewDidMoveToWindow() {
        if let _ = window {
            layout()
            self.searchView.change(state: .Focus, false)
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window = newWindow as? Window {
            window.set(handler: { [weak self] () -> KeyHandlerResult in
                self?.prevAction()
                return .invoked
            }, with: self, for: .UpArrow, priority: .medium)
            
            window.set(handler: { [weak self] () -> KeyHandlerResult in
                self?.nextAction()
                return .invoked
            }, with: self, for: .DownArrow, priority: .medium)
        } else {
            if let window = window as? Window {
                window.remove(object: self, for: .UpArrow)
                window.remove(object: self, for: .DownArrow)
                self.searchView.change(state: .None, false)
            }
            
        }
    }
    
    
    deinit {
        disposable.dispose()
        inputInteraction.remove(observer: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(frame frameRect: NSRect, interactions:ChatSearchInteractions, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction
        self.inputContextHelper = InputContextHelper(account: chatInteraction.account, chatInteraction: chatInteraction)
        super.init(frame: frameRect)
        initialize()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
