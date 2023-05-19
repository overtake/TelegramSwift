//
//  ChannelEventLogController.swift
//  Telegram
//
//  Created by keepcoder on 08/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//




import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit

extension ChannelAdminEventLogEntry : Identifiable {
    
    //private func eventLogItems(_ entries:[ChannelAdminEventLogEntry], isGroup: Bool, peerId: PeerId, initialSize: NSSize, chatInteraction: ChatInteraction) -> [TableRowItem] {

    
}

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
        layer.backgroundColor = theme.colors.background.cgColor
        
        let (textLayout, textApply) = TextNode.layoutText(maybeNode: titleNode, attributedText, nil, 1, .end, NSMakeSize(bounds.width - 40, bounds.height), nil,false, .left)
        let textRect = focus(textLayout.size)
        textApply.draw(textRect, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        
        var iconRect = focus(theme.icons.eventLogTriangle.backingSize)
        iconRect.origin.x = textRect.maxX + 6
        iconRect.origin.y += 1
        ctx.draw(theme.icons.eventLogTriangle, in: iconRect)
        
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
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
        cancelButton.set(text: strings().chatCancel, for: .Normal)
        _ = cancelButton.sizeToFit()
        
        cancelButton.set(handler: { [weak self] _ in
            self?.hideSearch?()
            }, for: .Click)
        addSubview(cancelButton)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        cancelButton.set(background: theme.colors.background, for: .Normal)
        cancelButton.set(color: theme.colors.accent, for: .Normal)
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
        whatButton.set(text: strings().channelEventLogWhat, for: .Normal)
        
        whatButton.set(handler: { _ in
            alert(for: mainWindow, header: strings().channelEventLogAlertHeader, info: strings().channelEventLogAlertInfo)
        }, for: .Click)
        setFrameSize(frameRect.size)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.chatBackground
        whatButton.set(color: theme.colors.accent, for: .Normal)
        whatButton.set(background: theme.colors.grayTransparent, for: .Highlight)
        whatButton.set(background: theme.colors.background, for: .Normal)
        emptyTextView.backgroundColor = theme.colors.chatBackground
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
        
        emptyTextView.textLayout?.measure(width: frame.width - 40)
        emptyTextView.update(emptyTextView.textLayout)
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
    let fullyLoaded: Bool
}

extension AdminLogEventsResult {
    var isGroup: Bool {
        if let peer = peers[peerId] {
            return peer.isSupergroup
        }
        return false
    }

}

private func eventLogItems(_ entries:[ChannelAdminEventLogEntry], isGroup: Bool, peerId: PeerId, initialSize: NSSize, chatInteraction: ChatInteraction) -> [TableRowItem] {
    var items:[TableRowItem] = []
    var index:Int = 0
    let timeDifference = Int32(chatInteraction.context.timeDifference)
    for entry in entries {
        switch entry.event.action {
        case let .editMessage(prev, new):
            let item = ChatRowItem.item(initialSize, from: .MessageEntry(new.withUpdatedStableId(arc4random()), MessageIndex(new), true, .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings)), interaction: chatInteraction, theme: theme) as? ChatRowItem
            if let item = item {
                if !(new.effectiveMedia is TelegramMediaAction) {
                    items.append(ChannelEventLogEditedPanelItem(initialSize, previous: prev, item: item))
                    items.append(item)
                }
            }
        case let .deleteMessage(message), let .sendMessage(message):
            items.append(ChatRowItem.item(initialSize, from: .MessageEntry(message.withUpdatedStableId(arc4random()).withUpdatedTimestamp(entry.event.date), MessageIndex(message), true, .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings)), interaction: chatInteraction, theme: theme))
        case let .updatePinned(message):
            if let message = message?.withUpdatedStableId(arc4random()) {
                items.append(ChatRowItem.item(initialSize, from: .MessageEntry(message, MessageIndex(message), true, .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings)), interaction: chatInteraction, theme: theme))
            }
        default:
            break
        }
        items.append(ServiceEventLogItem(initialSize, entry: entry, isGroup: isGroup, chatInteraction: chatInteraction))
        
        
        let nextEvent = index == entries.count - 1 ? nil : entries[index + 1].event
        
        if let nextEvent = nextEvent {
            let dateId = chatDateId(for: entry.event.date - timeDifference)
            let nextDateId = chatDateId(for: nextEvent.date - timeDifference)
            if dateId != nextDateId {
                let messageIndex = MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: INT_MAX), timestamp: Int32(dateId))
                items.append(ChatDateStickItem(initialSize, .DateEntry(messageIndex, .list, theme), interaction: chatInteraction, theme: theme))
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
    private let disposable = MetaDisposable()
    private let searchState:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)
    private let filterDisposable = MetaDisposable()
    private let updateFilterDisposable = MetaDisposable()
    
    private let filterStateValue:ValuePromise<ChannelEventFilterState> = ValuePromise(ChannelEventFilterState())
    private let filterState:Atomic<ChannelEventFilterState> = Atomic(value: ChannelEventFilterState())

    private func updateFilter(_ f:(ChannelEventFilterState)->ChannelEventFilterState) -> Void {
        self.filterStateValue.set(filterState.modify(f))
    }
    
    
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
        let state = filterState.with { $0 }
        let context = self.context
        let peerId = self.peerId
        let adminsPromise = ValuePromise<[RenderedChannelParticipant]?>(nil)
        _ = context.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { membersState in
            if case .loading = membersState.loadingState, membersState.list.isEmpty {
                adminsPromise.set(nil)
            } else {
                adminsPromise.set(membersState.list)
            }
        })
            
        let admins = adminsPromise.get() |> filter { $0 != nil } |> take(1) |> map { $0! }
        filterDisposable.set(showModalProgress(signal: admins, for: context.window).start(next: { [weak self] admins in
        showModal(with: ChannelEventFilterModalController(context: context, peerId: peerId, admins: admins, state: state, updated: { [weak self] updatedState in
            
            self?.updateFilter { _ in
                return updatedState
            }

        }), for: context.window)
            
        }))
    }
    
    init(_ context: AccountContext, peerId:PeerId) {
        self.peerId = peerId
        chatInteraction = ChatInteraction(chatLocation: .peer(peerId), context: context, isLogInteraction: true)
        
        super.init(context)
        
    }
    
    override var enableBack: Bool {
        return true
    }
    
    deinit {
        disposable.dispose()
        filterDisposable.dispose()
        updateFilterDisposable.dispose()
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
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
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
        
        genericView.tableView.getBackgroundColor = {
            return theme.colors.chatBackground
        }
        
        let searchState = self.searchState
        let context = self.context
        let initialSize = self.atomicSize
        let chatInteraction = self.chatInteraction
        let peerId = self.peerId
        let eventLogContext = context.engine.peers.channelAdminEventLog(peerId: peerId)

        
        genericView.searchContainer.searchView.searchInteractions = SearchInteractions({ state, _ in
            searchState.set(state)
        }, { state in
            searchState.set(state)
        })
        

        self.chatInteraction.openInfo = { [weak self] peerId, _, _, _ in
            if let strongSelf = self {
               strongSelf.navigationController?.push(PeerInfoController(context: context, peerId: peerId))
            }
        }
        
        self.chatInteraction.inlineAudioPlayer = { [weak self] controller in
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: self?.genericView.tableView, supportTableView: nil)
            self?.navigationController?.header?.show(true, contextObject: object)
        }
 

        
        let updateFilter = combineLatest(queue: .mainQueue(),searchState.get(), filterStateValue.get())
        
        updateFilterDisposable.set(updateFilter.start(next: { search, filter in
            eventLogContext.setFilter(.init(query: search.request, events: filter.selectedFlags, adminPeerIds: filter.selectedAdmins))
        }))

        let isGroup: Signal<Bool, NoError> = context.account.postbox.transaction {
            let peer = $0.getPeer(peerId)
            if let peer = peer {
                return peer.isGroup || peer.isSupergroup
            } else {
                return false
            }
        }
        

        
        let signal: Signal<([TableRowItem], ([ChannelAdminEventLogEntry], Bool, ChannelAdminEventLogUpdateType, Bool), Bool), NoError> = combineLatest(eventLogContext.get(), isGroup) |> map { result, isGroup in
            
            let items = eventLogItems(result.0.reversed(), isGroup: isGroup, peerId: peerId, initialSize: initialSize.with { $0 }, chatInteraction: chatInteraction)
            

            return (items, result, isGroup)

        } |> deliverOnMainQueue
        
        //                subscriber.putNext((strongSelf.entries.0, strongSelf.hasEarlier, .initial, strongSelf.hasEntries))

        
        disposable.set(signal.start(next: { [weak self] items, result, isGroup in
            self?.genericView.tableView.beginTableUpdates()
            self?.genericView.tableView.removeAll()
            self?.genericView.tableView.insert(items: items)
            self?.genericView.tableView.endTableUpdates()
            
            switch result.2 {
            case .initial:
                self?.genericView.updateState(.loading)
            case .load, .generic:
                if items.isEmpty {
                    self?.genericView.updateState(.empty(!isGroup ? strings().channelEventLogEmptyText : strings().groupEventLogEmptyText))
                } else {
                    self?.genericView.updateState(.history)
                }
            }

        }))
        
        
        genericView.tableView.setScrollHandler { scroll in
            switch scroll.direction {
            case .bottom:
                eventLogContext.loadMoreEntries()
            default:
                break
            }
        }
        
        
        self.genericView.tableView.removeAll()
        _ = self.genericView.tableView.addItem(item: GeneralRowItem(initialSize.modify{$0}, height: 20, stableId: arc4random(), backgroundColor: theme.colors.chatBackground))
        
        readyOnce()

    }
    
    
}

