//
//  ChannelEventLogController.swift
//  Telegram
//
//  Created by keepcoder on 08/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//




import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


class ChannelEventLogTitledView : TitledBarView {
    private var titleNode:TextNode = TextNode()
    var attributedText:NSAttributedString
    init(controller: ViewController, _ text:NSAttributedString) {
        self.attributedText = text
        super.init(controller: controller)
        self.containerView.isHidden = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.background.cgColor)
        ctx.fill(bounds)
        
       let (textLayout, textApply) = TextNode.layoutText(maybeNode: titleNode, attributedText, nil, 1, .end, NSMakeSize(bounds.width - 40, bounds.height), nil,false, .left)
        let textRect = focus(textLayout.size)
        textApply.draw(textRect, in: ctx, backingScaleFactor: backingScaleFactor)
        
        var iconRect = focus(theme.icons.eventLogTriangle.backingSize)
        iconRect.origin.x = textRect.maxX + 6
        iconRect.origin.y += 1
        ctx.draw(theme.icons.eventLogTriangle, in: iconRect)
      
        
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        backgroundColor = theme.colors.background
        needsDisplay = true
    }
    
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum ChannelEventLogState {
    case loading
    case empty(String)
    case history
}

private class SearchContainerView : View {
    let searchView: SearchView = SearchView(frame: NSZeroRect)
    let separator:View = View()
    let cancelButton = TitleButton()
    var hideSearch:(()->Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(searchView)
        addSubview(separator)
        cancelButton.set(font: .medium(.text), for: .Normal)
        cancelButton.set(text: tr(.chatCancel), for: .Normal)
        cancelButton.sizeToFit()
        
        cancelButton.set(handler: { [weak self] _ in
            self?.hideSearch?()
        }, for: .Click)
        addSubview(cancelButton)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        cancelButton.set(background: theme.colors.background, for: .Normal)
        cancelButton.set(color: theme.colors.blueUI, for: .Normal)
        separator.backgroundColor = theme.colors.border
        backgroundColor = theme.colors.background
        
    }
    
    override func layout() {
        super.layout()
        searchView.centerY(x: 20)
        separator.setFrameOrigin(0, frame.height - .borderSize)
        cancelButton.centerY(x: frame.width - 20 - cancelButton.frame.width)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        searchView.setFrameSize(newSize.width - 60 - cancelButton.frame.width, 30)
        separator.setFrameSize(newSize.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ChannelEventLogView : View {
    fileprivate let tableView:TableView = TableView(frame: NSZeroRect, isFlipped: false)
    private let whatButton: TitleButton = TitleButton()
    private let separator:View = View()
    private var emptyTextView:TextView = TextView()
    private(set) var inSearch:Bool = false
    fileprivate let searchContainer:SearchContainerView
    private var progress:ProgressIndicator = ProgressIndicator(frame:NSMakeRect(0, 0, 30, 30))
    required init(frame frameRect: NSRect) {
        searchContainer = SearchContainerView(frame: NSMakeRect(0, 0, frameRect.width, 40))
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(emptyTextView)
        addSubview(whatButton)
        addSubview(separator)
        addSubview(progress)
        
        searchContainer.hideSearch = { [weak self] in
            self?.hideSearch()
        }
        
        emptyTextView.isSelectable = false
        separator.backgroundColor = .border
        whatButton.set(font: .medium(.title), for: .Normal)
        whatButton.set(text: tr(.channelEventLogWhat), for: .Normal)
        
        whatButton.set(handler: { _ in
            alert(for: mainWindow, header: tr(.channelEventLogAlertHeader), info: tr(.channelEventLogAlertInfo))
        }, for: .Click)
        setFrameSize(frameRect.size)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        whatButton.set(color: theme.colors.blueUI, for: .Normal)
        whatButton.set(background: theme.colors.grayTransparent, for: .Highlight)
        whatButton.set(background: theme.colors.background, for: .Normal)
        emptyTextView.backgroundColor = theme.colors.background
        separator.backgroundColor =  theme.colors.border
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        emptyTextView.setFrameSize(NSMakeSize(newSize.width, newSize.height - 50))
        tableView.setFrameSize(NSMakeSize(newSize.width, newSize.height - 50))
        whatButton.setFrameSize(newSize.width, 50)
        separator.setFrameSize(newSize.width, .borderSize)
        searchContainer.setFrameSize(newSize.width, searchContainer.frame.height)
    }
    
    
    func updateState(_ state: ChannelEventLogState) {
        self.progress.animates = false
        switch state {
        case .history:
            self.progress.isHidden = true
            self.emptyTextView.isHidden = true
        case .loading:
            self.progress.isHidden = false
            self.progress.animates = true
            self.emptyTextView.isHidden = true
        case .empty(let text):
            self.progress.isHidden = true
            self.emptyTextView.isHidden = false
            let attributed = NSMutableAttributedString()
            _ = attributed.append(string: text, color: theme.colors.grayText, font: .normal(.title))
            attributed.detectBoldColorInString(with: .medium(.title))
            let emptyLayout = TextViewLayout(attributed, alignment: .center)
            self.emptyTextView.update(emptyLayout)
        }
        needsLayout = true
    }
    
    fileprivate func showSearch() {
        addSubview(searchContainer)
        inSearch = true
        searchContainer.setFrameOrigin(0, -searchContainer.frame.height)
        searchContainer.change(pos: NSMakePoint(0, 0), animated: true)
    }
    
    fileprivate func hideSearch() {
        inSearch = false
        self.searchContainer.searchView.setString("")
        searchContainer.change(pos: NSMakePoint(0, -searchContainer.frame.height), animated: true, removeOnCompletion: false, completion: { [weak self] completed in
            if completed {
                self?.searchContainer.removeFromSuperview()
            }
        })
    }
    
    
    override func layout() {
        super.layout()
        
        emptyTextView.layout?.measure(width: frame.width - 40)
        emptyTextView.update(emptyTextView.layout)
        emptyTextView.center()
        tableView.setFrameOrigin(NSZeroPoint)
        whatButton.setFrameOrigin(NSMakePoint(0, frame.height - whatButton.frame.height))
        separator.setFrameOrigin(0, tableView.frame.maxY)
        progress.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct EventLogTableTransition {
    let result: [TableRowItem]
    let addition:Bool
    let state:ChannelEventFilterState
    let maxId:AdminLogEventId
    let eventLog:AdminLogEventsResult
}

extension AdminLogEventsResult {
    var isGroup: Bool {
        if let peer = peers[peerId] {
            return peer.isSupergroup
        }
        return false
    }
    
    var banHelp:[TelegramChannelBannedRightsFlags] {
        var order:[TelegramChannelBannedRightsFlags] = []
        order.append(.banSendMessages)
        order.append(.banSendMedia)
        order.append(.banSendStickers)
        order.append(.banEmbedLinks)
        return order
    }
    
    var rightsHelp:(specific: TelegramChannelAdminRightsFlags, order: [TelegramChannelAdminRightsFlags]) {
        if let peer = peers[peerId] as? TelegramChannel {
            let maskRightsFlags: TelegramChannelAdminRightsFlags
            let rightsOrder: [TelegramChannelAdminRightsFlags]
            
            switch peer.info {
            case .broadcast:
                maskRightsFlags = .broadcastSpecific
                rightsOrder = [
                    .canChangeInfo,
                    .canPostMessages,
                    .canEditMessages,
                    .canDeleteMessages,
                    .canAddAdmins
                ]
            case .group:
                maskRightsFlags = .groupSpecific
                rightsOrder = [
                    .canChangeInfo,
                    .canDeleteMessages,
                    .canBanUsers,
                    .canInviteUsers,
                    .canChangeInviteLink,
                    .canPinMessages,
                    .canAddAdmins
                ]
                
            }
            return (specific: maskRightsFlags, order: rightsOrder)
        }
        return (specific: [], order: [])
    }
    
}

private func eventLogItems(_ result:AdminLogEventsResult, initialSize: NSSize, chatInteraction: ChatInteraction) -> [TableRowItem] {
    var items:[TableRowItem] = []
    var index:Int = 0
    let timeDifference = Int32(chatInteraction.account.context.timeDifference)
    for event in result.events {
        switch event.action {
        case let .editMessage(prev, new):
            let item = ChatRowItem.item(initialSize, from: .MessageEntry(new.withUpdatedStableId(arc4random()), true, .Full(isAdmin: false), nil, nil), with: chatInteraction.account, interaction: chatInteraction)
            items.append(ChannelEventLogEditedPanelItem(initialSize, previous: prev, item: item))
            items.append(item)
        case let .deleteMessage(message):
            items.append(ChatRowItem.item(initialSize, from: .MessageEntry(message.withUpdatedStableId(arc4random()), true, .Full(isAdmin: false), nil, nil), with: chatInteraction.account, interaction: chatInteraction))
        case let .updatePinned(message):
            if let message = message?.withUpdatedStableId(arc4random()) {
                items.append(ChatRowItem.item(initialSize, from: .MessageEntry(message, true, .Full(isAdmin: false), nil, nil), with: chatInteraction.account, interaction: chatInteraction))
            }
        default:
            break
        }
        items.append(ServiceEventLogItem(initialSize, event: event, result: result, chatInteraction: chatInteraction))
        
        
        let nextEvent = index == result.events.count - 1 ? nil : result.events[index + 1]
        
        if let nextEvent = nextEvent {
            let dateId = chatDateId(for: event.date - timeDifference)
            let nextDateId = chatDateId(for: nextEvent.date - timeDifference)
            if dateId != nextDateId {
                let messageIndex = MessageIndex(id: MessageId(peerId: result.peerId, namespace: 0, id: INT_MAX), timestamp: Int32(dateId))
                items.append(ChatDateStickItem(initialSize, .DateEntry(messageIndex), interaction: chatInteraction))
            }
        }
        
        index += 1

    }
    for item in items {
        _ = item.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    return items
}

class ChannelEventLogController: TelegramGenericViewController<ChannelEventLogView> {
    private let peerId:PeerId
    private let chatInteraction:ChatInteraction
    private let promise:Promise<EventLogTableTransition> = Promise()
    private let history:Promise<(AdminLogEventId, ChannelEventFilterState)> = Promise()
    private var state:Atomic<ChannelEventFilterState?> = Atomic(value: nil)
    private let disposable = MetaDisposable()
    private let openPeerDisposable = MetaDisposable()
    private let searchState:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)
    override func viewClass() -> AnyClass {
        return ChannelEventLogView.self
    }
    
    override func requestUpdateCenterBar() {
        super.requestUpdateCenterBar()
        (centerBarView as? ChannelEventLogTitledView)?.attributedText = .initialize(string: defaultBarTitle, color: theme.colors.text, font: .medium(.title))
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        let bar = ChannelEventLogTitledView(controller: self, .initialize(string: defaultBarTitle, color: theme.colors.text, font: .medium(.title)))
        
        bar.set(handler: { [weak self] _ in
            self?.showFilter()
        }, for: .Click)
        
        return bar
    }
    
    private func showFilter() {
        if let state = state.modify({$0}) {
            showModal(with: ChannelEventFilterModalController(account: account, peerId: peerId, state: state, updated: { [weak self] updatedState in
                self?.history.set(.single((0, updatedState)))
                _ = self?.state.swap(updatedState)
            }), for: mainWindow)
        }
    }
    
    init(_ account:Account, peerId:PeerId) {
        self.peerId = peerId
        chatInteraction = ChatInteraction(peerId: peerId, account: account, isLogInteraction: true)
        super.init(account)
    }
    
    override var enableBack: Bool {
        return true
    }
    
    deinit {
        disposable.dispose()
        openPeerDisposable.dispose()
    }
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        (self.rightBarView as? ImageBarView)?.set(image: theme.icons.chatSearch)
    }
    
    override func getRightBarViewOnce() -> BarView {
        let bar = ImageBarView(controller: self, theme.icons.chatSearch)
        bar.button.set(handler: { [weak self] _ in
            self?.genericView.showSearch()
        }, for: .Click)
        return bar
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.inSearch {
            genericView.hideSearch()
            return .invoked
        } 
        return super.escapeKeyAction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                if !strongSelf.genericView.inSearch {
                    strongSelf.genericView.showSearch()
                } else {
                    strongSelf.genericView.hideSearch()
                }
            }
            return .invoked
        }, with: self, for: .F, modifierFlags: [.command])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let searchState = self.searchState
        
        genericView.searchContainer.searchView.searchInteractions = SearchInteractions({ state in
            searchState.set(state)
        }, { state in
            searchState.set(state)
        })
        
        self.chatInteraction.openInfo = { [weak self] peerId, _, _, _ in
            if let strongSelf = self {
                strongSelf.openPeerDisposable.set((strongSelf.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { [weak strongSelf] peer in
                    if let strongSelf = strongSelf {
                        strongSelf.navigationController?.push(PeerInfoController(account: strongSelf.account, peer: peer))
                    }
                }))
            }
        }
        
        self.chatInteraction.inlineAudioPlayer = { [weak self] controller in
            if let navigation = self?.navigationController {
                if let header = navigation.header, let strongSelf = self {
                    header.show(true)
                    if let view = header.view as? InlineAudioPlayerView {
                        view.update(with: controller, tableView: strongSelf.genericView.tableView)
                    }
                }
            }
        }
        
        let currentMaxId:Atomic<AdminLogEventId> = Atomic(value: 0)
        
        let initialSize = self.atomicSize
        let chatInteraction = self.chatInteraction
        let account = self.account
        let peerId = self.peerId
        
        let previousState:Atomic<ChannelEventFilterState?> = Atomic(value: nil)
        let previousAppearance:Atomic<Appearance?> = Atomic(value: nil)
        let previousSearchState:Atomic<SearchState> = Atomic(value: SearchState(state: .None, request: nil))
        disposable.set((combineLatest(searchState.get() |> map {SearchState(state: .None, request: $0.request)} |> distinctUntilChanged, history.get() |> filter {$0.0 != -1}) |> mapToSignal { values -> Signal<EventLogTableTransition?, Void> in
            
            let state = values.1.1
            let searchState = values.0
            return .single(nil) |> then (combineLatest(channelAdminLogEvents(account, peerId: peerId, maxId: values.1.0, minId: -1, limit: 50, query: searchState.request, filter: state.selectedFlags, admins: state.selectedAdmins) |> mapError { _ in} |> deliverOnPrepareQueue, appearanceSignal) |> map { result, appearance in

                
                let maxId = result.events.min(by: { (lhs, rhs) -> Bool in
                    return lhs.id < rhs.id
                })?.id ?? -1
                
                let items = eventLogItems(result, initialSize: initialSize.modify({$0}), chatInteraction: chatInteraction)
                let _previousState = previousState.swap(state)
                let _previousAppearance = previousAppearance.swap(appearance)
                let _previousSearchState = previousSearchState.swap(searchState)
                return EventLogTableTransition(result: items, addition: _previousState == state && _previousSearchState == searchState && _previousAppearance == appearance, state: state, maxId: maxId, eventLog: result)

            }  |> map {Optional($0)})
            
        }
        |> deliverOnMainQueue).start(next: { [weak self] transition in
            if let tableView = self?.genericView.tableView {
                if let transition = transition, let peer = transition.eventLog.peers[transition.eventLog.peerId] {
                    if !transition.addition {
                        tableView.removeAll()
                        _ = tableView.addItem(item: GeneralRowItem(initialSize.modify{$0}, height: 20, stableId: arc4random()))
                    }
                    tableView.insert(items: transition.result, at: tableView.count)
                    self?.genericView.updateState(tableView.isEmpty ? (transition.state.isEmpty && previousSearchState.modify({$0}).request.isEmpty ? .empty(peer.isChannel ? tr(.channelEventLogEmptyText) : tr(.groupEventLogEmptyText)) : .empty(tr(.channelEventLogEmptySearch))) : .history)
                } else {
                    self?.genericView.updateState(.loading)
                    self?.genericView.tableView.removeAll()
                    _ = tableView.addItem(item: GeneralRowItem(initialSize.modify{$0}, height: 20, stableId: arc4random()))
                }
                
                tableView.resetScrollNotifies()
                _ = currentMaxId.swap(transition?.maxId ?? -1)
            }
        }))
        
        genericView.tableView.setScrollHandler { [weak self] scroll in
            if let strongSelf = self {
                switch scroll.direction {
                case .bottom:
                    strongSelf.history.set(strongSelf.history.get() |> take(1) |> map { (_, state) in
                        return (currentMaxId.modify({$0}), state)
                    })
                default:
                    break
                }
            }
        }
        
        readyOnce()
        history.set(.single((0, ChannelEventFilterState())))
        _ = state.swap(ChannelEventFilterState())
    }
    
    
}
