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
}

private final class Arguments {
    let context: AccountContext
    let toggleReveal:(MessageId)->Void
    init(context: AccountContext, toggleReveal: @escaping (MessageId) -> Void) {
        self.context = context
        self.toggleReveal = toggleReveal
    }
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
    let cancelButton = ImageButton()
    var hideSearch:(()->Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(searchView)
        addSubview(separator)
        cancelButton.autohighlight = false
        cancelButton.scaleOnClick = true
        cancelButton.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = cancelButton.sizeToFit()
        
        cancelButton.set(handler: { [weak self] _ in
            self?.hideSearch?()
            }, for: .Click)
        addSubview(cancelButton)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        separator.backgroundColor = theme.colors.border
        backgroundColor = theme.colors.background
        let theme = theme as! TelegramPresentationTheme
        cancelButton.set(image: theme.icons.dismissPinned, for: .Normal)
    }
    
    override func layout() {
        super.layout()
        searchView.frame = NSMakeRect(20, 10, frame.width - 55 - cancelButton.frame.width, 30)
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        cancelButton.centerY(x: frame.width - 15 - cancelButton.frame.width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class EmptyView : View {
    private let imageView = ImageView()
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        
        
    }
    
    func update(_ text: String) {
        
        self.imageView.image = NSImage(resource: .iconRecentLogs).precomposed(theme.colors.grayIcon)
        self.imageView.sizeToFit()
        
        let attributed = NSMutableAttributedString()
        _ = attributed.append(string: text, color: theme.colors.grayText, font: .normal(.title))
        attributed.detectBoldColorInString(with: .medium(.title))
        let emptyLayout = TextViewLayout(attributed, alignment: .center)
        emptyLayout.measure(width: 250)
        textView.update(emptyLayout)
                
        setFrameSize(NSMakeSize(250, imageView.frame.height + textView.frame.height + 15))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        imageView.centerX(y: 0)
        textView.centerX(y: imageView.frame.maxY + 15)
    }
}

class ChannelEventLogView : View {
    fileprivate let tableView:TableView = TableView(frame: NSZeroRect, isFlipped: false)
    fileprivate let settings: TextButton = TextButton()
    fileprivate let info: ImageButton = ImageButton()
    private let separator:View = View()
    private var emptyView:EmptyView = EmptyView(frame: .zero)
    private(set) var inSearch:Bool = false
    fileprivate var searchContainer:SearchContainerView?
    private var progress:ProgressIndicator = ProgressIndicator(frame:NSMakeRect(0, 0, 30, 30))
    
    fileprivate var searchInteractions: SearchInteractions?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(emptyView)
        addSubview(settings)
        settings.addSubview(info)
        addSubview(separator)
        addSubview(progress)
        
        
        info.autohighlight = false
        info.scaleOnClick = true
        
        separator.backgroundColor = .border
        settings.set(font: .medium(.title), for: .Normal)
        settings.set(text: strings().chanelEventFilterSettings, for: .Normal)
        
       
        setFrameSize(frameRect.size)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        self.backgroundColor = theme.colors.chatBackground
        settings.set(color: theme.colors.accent, for: .Normal)
        settings.set(background: theme.colors.grayTransparent, for: .Highlight)
        settings.set(background: theme.colors.background, for: .Normal)
        info.set(image: NSImage(resource: .iconChannelPromoInfo).precomposed(theme.colors.accent), for: .Normal)
        info.sizeToFit()
        separator.backgroundColor =  theme.colors.border
    }
    
    func updateState(_ state: ChannelEventLogState) {
        self.progress.animates = false
        switch state {
        case .history:
            self.progress.isHidden = true
            self.emptyView.isHidden = true
        case .loading:
            self.progress.isHidden = false
            self.progress.animates = true
            self.emptyView.isHidden = true
        case .empty(let text):
            self.progress.isHidden = true
            self.emptyView.isHidden = false
            self.emptyView.update(text)
        }
        needsLayout = true
    }
    
    fileprivate func toggleSearch() {
        if searchContainer != nil {
            self.hideSearch()
        } else {
            self.showSearch()
        }
       
    }
    
    fileprivate func showSearch() {
        inSearch = true
        
        let current: SearchContainerView
        if let view = self.searchContainer {
            current = view
        } else {
            current = SearchContainerView(frame: NSMakeRect(0, 0, frame.width, 50))
            current.layer?.animatePosition(from: NSMakePoint(0, -current.frame.height), to: .zero)
            self.searchContainer = current
            addSubview(current)
        }
        current.searchView.searchInteractions = searchInteractions
        current.searchView.setString("")
        current.searchView.change(state: .Focus, false)
        current.hideSearch = { [weak self] in
            self?.hideSearch()
        }
    }
    
    fileprivate func hideSearch() {
        inSearch = false
        if let searchContainer {
            searchContainer.searchView.setString("")
            performSubviewPosRemoval(searchContainer, pos: NSMakePoint(0, -searchContainer.frame.height), animated: true)
        }
        self.searchContainer = nil
        
    }
    
    
    override func layout() {
        super.layout()
        
        tableView.frame = NSMakeRect(0, 0, frame.width, frame.height - 50)
        settings.setFrameSize(frame.width, 50)
        separator.setFrameSize(frame.width, .borderSize)
        
        emptyView.center()
        settings.setFrameOrigin(NSMakePoint(0, frame.height - settings.frame.height))
        separator.setFrameOrigin(0, tableView.frame.maxY)
        progress.center()
        info.centerY(x: frame.width - info.frame.width - 20)
        
        if let searchContainer {
            searchContainer.setFrameSize(frame.width, searchContainer.frame.height)
        }
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

private struct State : Equatable {
    var revealed:Set<MessageId> = Set()
}

extension AdminLogEventsResult {
    var isGroup: Bool {
        if let peer = peers[peerId] {
            return peer.isSupergroup
        }
        return false
    }
}

private func eventLogItems(_ entries:[ChannelAdminEventLogEntry], state: State, isGroup: Bool, peerId: PeerId, initialSize: NSSize, chatInteraction: ChatInteraction, searchQuery: String) -> [TableRowItem] {
    var items:[TableRowItem] = []
    var index:Int = 0
    
    var groupped: [[ChannelAdminEventLogEntry]] = []
    
    var currentPeerId: PeerId?
    var entriesToProcess = [ChannelAdminEventLogEntry]()

    func processAndClearCurrentEntries() {
        if !entriesToProcess.isEmpty {
            groupped.append(entriesToProcess)
            entriesToProcess.removeAll()
        }
    }

    for entry in entries {
        switch entry.event.action {
        case .deleteMessage:
            if currentPeerId != entry.event.peerId {
                processAndClearCurrentEntries()
                currentPeerId = entry.event.peerId
            }
            entriesToProcess.append(entry)
        default:
            if currentPeerId != nil {
                processAndClearCurrentEntries()
            }
            currentPeerId = nil
            entriesToProcess.append(entry)
            processAndClearCurrentEntries()
        }
    }

    processAndClearCurrentEntries()
    
    let getGroupMessageId:([ChannelAdminEventLogEntry]) -> MessageId? = { group in
        let last = group[group.count - 1]
        switch last.event.action {
        case let .deleteMessage(message):
            return message.id
        default:
            return nil
        }
    }
    
    for group in groupped {
        for (i, entry) in group.enumerated() {
            switch entry.event.action {
            case let .editMessage(prev, new):
                let updatedMedia: TelegramMediaWebpage = .init(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(.init(url: "", displayUrl: "", hash: 0, type: "edited", websiteName: strings().channelEventLogOriginalMessage, title: nil, text: prev.text, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: true, imageIsVideoCover: false, image: prev.media.first as? TelegramMediaImage, file: prev.media.first as? TelegramMediaFile, story: nil, attributes: [], instantPage: nil)))
                
                let new = new.withUpdatedMedia([updatedMedia])
                
                let item = ChatRowItem.item(initialSize, from: .MessageEntry(new, MessageIndex(new), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(highlightFoundText: .init(query: searchQuery, isMessage: true), eventLog: entry.event), AutoplayMediaPreferences.defaultSettings)), interaction: chatInteraction, theme: theme) as? ChatRowItem
                
                if let item = item {
                    items.append(item)
                }
            case let .deleteMessage(message):
                var message = message
                    .withUpdatedTimestamp(entry.event.date)
                
                guard let groupId = getGroupMessageId(group) else {
                    return items
                }
                
                if i == group.count - 1, group.count > 1, !state.revealed.contains(groupId) {
                    let attribute = ReplyMarkupMessageAttribute(rows: [.init(buttons: [.init(title: strings().eventLogServiceShowMoreCountable(group.count - 1), titleWhenForwarded: nil, action: .text)])], flags: [.inline], placeholder: nil)
                    message = message.withUpdatedReplyMarkupAttribute(attribute)
                }
                if group.count == 1 || state.revealed.contains(groupId) || i == group.count - 1 {
                    items.append(ChatRowItem.item(initialSize, from: .MessageEntry(message.withUpdatedTimestamp(entry.event.date), MessageIndex(message), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(highlightFoundText: .init(query: searchQuery, isMessage: true), eventLog: entry.event), AutoplayMediaPreferences.defaultSettings)), interaction: chatInteraction, theme: theme))
                }
            case let .sendMessage(message):
                items.append(ChatRowItem.item(initialSize, from: .MessageEntry(message.withUpdatedTimestamp(entry.event.date), MessageIndex(message), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(highlightFoundText: .init(query: searchQuery, isMessage: true), eventLog: entry.event), AutoplayMediaPreferences.defaultSettings)), interaction: chatInteraction, theme: theme))
            case let .updatePinned(message):
                if let message = message {
                    items.append(ChatRowItem.item(initialSize, from: .MessageEntry(message.withUpdatedTimestamp(entry.event.date), MessageIndex(message), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(highlightFoundText: .init(query: searchQuery, isMessage: true), eventLog: entry.event), AutoplayMediaPreferences.defaultSettings)), interaction: chatInteraction, theme: theme))
                }
            default:
                break
            }
        }
        if let entry = group.first {
            let id = getGroupMessageId(group)
            let groupRevealed = id != nil ? state.revealed.contains(id!) : false
            items.append(ServiceEventLogItem(initialSize, entry: entry, isGroup: isGroup, chatInteraction: chatInteraction, group: group, groupRevealed: groupRevealed, toggleGroup: {
                if let id = id {
                    chatInteraction.executeReplymarkup(id)
                }
            }))
            index += 1
        }
    }
    
    
    items.insert(GeneralRowItem(.zero, height: 10, stableId: -1000), at: 0)
    items.append(GeneralRowItem(.zero, height: 10, stableId: 1000))
    
    for (i, item) in items.enumerated() {
        _ = item.makeSize(initialSize.width, oldWidth: initialSize.width)
        item._index = i
    }
    return items
}

class ChannelEventLogController: TelegramGenericViewController<ChannelEventLogView> {
    private let peerId:PeerId
    private let peer: EnginePeer
    private let chatInteraction:ChatInteraction
    private let disposable = MetaDisposable()
    private let searchState:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)
    private let filterDisposable = MetaDisposable()
    private let updateFilterDisposable = MetaDisposable()
    
    private var isGroup: Bool = true
    
    private let scrollDownOnNext: Atomic<Bool> = Atomic(value: false)
    
    private let filterStateValue:ValuePromise<ChannelEventFilterState> = ValuePromise(ChannelEventFilterState())
    private let filterState:Atomic<ChannelEventFilterState> = Atomic(value: ChannelEventFilterState())

    private func updateFilter(_ f:(ChannelEventFilterState)->ChannelEventFilterState) -> Void {
        self.filterStateValue.set(filterState.modify(f))
    }
        
    override var defaultBarStatus: String? {
        let state = self.filterState.with { $0 }
        
        if state.isFull {
            return strings().telegramChannelEventLogController
        } else {
            return strings().channelEventLogsTitleSelected
        }
        
    }
    
    override var defaultBarTitle: String {
        return self.peer._asPeer().displayTitle
    }
    
    override func viewClass() -> AnyClass {
        return ChannelEventLogView.self
    }
    

    private func showFilter() {
        let state = filterState.with { $0 }
        let context = self.context
        let peerId = self.peerId
        let isChannel = !self.isGroup
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
            showModal(with: ChannelEventFilterModalController(context: context, peerId: peerId, isChannel: isChannel, admins: admins, state: state, updated: { [weak self] updatedState in
                
                _ = self?.scrollDownOnNext.swap(true)
                self?.updateFilter { _ in
                    return updatedState
                }
                _ = self?.scrollDownOnNext.swap(true)
                self?.requestUpdateCenterBar()
        }), for: context.window)
            
        }))
    }
    
    init(_ context: AccountContext, peer: EnginePeer) {
        self.peerId = peer.id
        self.peer = peer
        chatInteraction = ChatInteraction(chatLocation: .peer(peerId), context: context, isLogInteraction: true)
        chatInteraction.update {
            $0.updatedPeer { _ in
                peer._asPeer()
            }
        }
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
            self?.genericView.toggleSearch()
        }, for: .Click)
        
        
        bar.button.scaleOnClick = true
        
        return bar
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let controller = context.sharedContext.getAudioPlayer(), let header = self.navigationController?.header, header.needShown {
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: genericView.tableView, supportTableView: nil)
            header.view.update(with: object)
        }
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
        
        let statePromise = ValuePromise(State(), ignoreRepeated: true)
        let stateValue = Atomic(value: State())
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let searchState = self.searchState
        let context = self.context
        let initialSize = self.atomicSize
        let chatInteraction = self.chatInteraction
        let peerId = self.peerId
        let eventLogContext = context.engine.peers.channelAdminEventLog(peerId: peerId)
        let scrollDownOnNext = self.scrollDownOnNext
        
        let searchQuery: Atomic<String> = Atomic(value: "")

        let arguments = Arguments(context: context, toggleReveal: { messageId in
            updateState { current in
                var current = current
                if current.revealed.contains(messageId) {
                    current.revealed.remove(messageId)
                } else {
                    current.revealed.insert(messageId)
                }
                return current
            }
        })
        
        chatInteraction.executeReplymarkup = { messageId in
            arguments.toggleReveal(messageId)
        }
        
        chatInteraction.focusMessageId = { [weak self] messageId, focusTarget, _ in
            self?.navigationController?.push(ChatAdditionController(context: context, chatLocation: .peer(peerId), focusTarget: focusTarget))
        }
        

        genericView.info.set(handler: { _ in
            alert(for: context.window, header: strings().channelEventLogAlertHeader, info: strings().channelEventLogAlertInfo)
        }, for: .Click)
        
        
        genericView.settings.set(handler: { [weak self] _ in
            self?.showFilter()
        }, for: .Click)
        
        genericView.searchInteractions = SearchInteractions({ state, _ in
            _ = searchQuery.swap(state.request)
            _ = scrollDownOnNext.swap(true)
            searchState.set(state)
            _ = scrollDownOnNext.swap(true)
        }, { state in
            _ = searchQuery.swap(state.request)
            _ = scrollDownOnNext.swap(true)
            searchState.set(state)
            _ = scrollDownOnNext.swap(true)
        })
        

        self.chatInteraction.openInfo = { [weak self] peerId, _, _, _ in
            if let navigation = self?.navigationController {
                PeerInfoController.push(navigation: navigation, context: context, peerId: peerId)
            }
        }
        
        self.chatInteraction.inlineAudioPlayer = { [weak self] controller in
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: self?.genericView.tableView, supportTableView: nil)
            context.sharedContext.showInlinePlayer(object)
        }
        
        let updateFilter = combineLatest(queue: .mainQueue(), searchState.get(), filterStateValue.get())
        
        updateFilterDisposable.set(updateFilter.start(next: { search, filter in
            eventLogContext.setFilter(.init(query: search.request, events: filter.selectedFlags, adminPeerIds: filter.selectedAdmins))
        }))

        let isGroup = !peer._asPeer().isChannel
        
        let signal: Signal<([TableRowItem], ([ChannelAdminEventLogEntry], Bool, ChannelAdminEventLogUpdateType, Bool), Bool), NoError> = combineLatest(eventLogContext.get(), statePromise.get()) |> map { result, state in
            let items = eventLogItems(result.0.reversed(), state: state, isGroup: isGroup, peerId: peerId, initialSize: initialSize.with { $0 }, chatInteraction: chatInteraction, searchQuery: searchQuery.with { $0 })
             return (items, result, isGroup)

        } |> deliverOnMainQueue
        
        
        
        disposable.set(signal.start(next: { [weak self] items, result, isGroup in
            guard let self else {
                return
            }
            
            let tableView = self.genericView.tableView

            let (deleteIndices, indicesAndItems, updatedAndItems) = mergeListsStableWithUpdates(leftList: tableView.allItems, rightList: items)
            
            let animated: Bool
            let scrollState: TableScrollState
            if scrollDownOnNext.swap(false) {
                scrollState = .down(false)
                animated = false
            } else {
                scrollState = .saveVisible(.upper, false)
                animated = false
            }
            
            let transition = TableUpdateTransition(deleted: deleteIndices, inserted: indicesAndItems.map { ($0.0, $0.1) }, updated: updatedAndItems.map { ($0.0, $0.1) }, animated: animated, state: scrollState, grouping: true)
            
            tableView.merge(with: transition)
            
           

            self.isGroup = isGroup
            
            switch result.2 {
            case .initial:
                self.genericView.updateState(.loading)
            case .load, .generic:
                if items.isEmpty {
                    self.genericView.updateState(.empty(!isGroup ? strings().channelEventLogEmptyText : strings().groupEventLogEmptyText))
                } else {
                    self.genericView.updateState(.history)
                }
            }
            self.readyOnce()
        }))
        
        genericView.tableView.setScrollHandler { scroll in
            switch scroll.direction {
            case .bottom:
                eventLogContext.loadMoreEntries()
            default:
                break
            }
        }
            

    }
    
    
}

