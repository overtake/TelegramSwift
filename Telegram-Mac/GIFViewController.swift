//
//  GIFViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit


private final class GifTabsArguments {
    let select:(GifTabEntryId)->Void
    let context: AccountContext
    init(context: AccountContext, select: @escaping(GifTabEntryId)->Void) {
        self.context = context
        self.select = select
    }
}

enum GifTabEntryId : Hashable {
    case recent
    case trending
    case recommended(String)
}

private enum GifTabEntry : TableItemListNodeEntry {
    typealias ItemGenerationArguments = GifTabsArguments
    
    case recent(selected: Bool)
    case trending(selected: Bool)
    case recommended(selected: Bool, index: Int, value: String)
    
    
    var index: Int {
        switch self {
        case .recent:
            return -2
        case .trending:
            return -1
        case let .recommended(_, index, _):
            return index
        }
    }
    
    var stableId: GifTabEntryId {
        switch self {
        case .recent:
            return .recent
        case .trending:
            return .trending
        case let .recommended(_, _, value):
            return .recommended(value)
        }
    }
    
    static func < (lhs: GifTabEntry, rhs: GifTabEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var selected: Bool {
        switch self {
        case let .recent(selected):
            return selected
        case let .trending(selected):
            return selected
        case let .recommended(selected, _, _):
            return selected
        }
    }
    
    func item(_ arguments: GifTabsArguments, initialSize: NSSize) -> TableRowItem {
        return GifPanelTabRowItem(initialSize, selected: self.selected, entry: stableId, select: arguments.select)
    }
}



struct GIFKeyboardConfiguration : Equatable {
    static var defaultValue: GIFKeyboardConfiguration {
        return GIFKeyboardConfiguration(emojis: [])
    }
    
    let emojis: [String]
    
    fileprivate init(emojis: [String]) {
        self.emojis = emojis.map { $0.fixed }
    }
    
    static func with(appConfiguration: AppConfiguration) -> GIFKeyboardConfiguration {
        if let data = appConfiguration.data, let value = data["gif_search_emojies"] as? [String] {
            return GIFKeyboardConfiguration(emojis: value.map { $0.fixed })
        } else {
            return .defaultValue
        }
    }
    
}

private func prepareEntries(left:[InputContextEntry], right:[InputContextEntry], context: AccountContext,  initialSize:NSSize, arguments: RecentGifsArguments?) -> TableUpdateTransition {
   let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        switch entry {
        case let .contextMediaResult(collection, row, index):
            return ContextMediaRowItem(initialSize, row, index, context, ContextMediaArguments(sendResult: { result, view in
                if let collection = collection {
                    arguments?.sendInlineResult(collection, result, view)
                } else {
                    switch result {
                    case let .internalReference(values):
                        if let file = values.file {
                            arguments?.sendAppFile(file, view, false)
                        }
                    default:
                        break
                    }
                }
            }, menuItems: { file, view in
                return context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                    var items: [ContextMenuItem] = []
                    if let mediaId = file.id {
                        let gifItems = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap {$0.contents as? RecentMediaItem}
                        if let _ = gifItems.firstIndex(where: {$0.media.id == mediaId}) {
                            items.append(ContextMenuItem(L10n.messageContextRemoveGif, handler: {
                                let _ = removeSavedGif(postbox: context.account.postbox, mediaId: mediaId).start()
                            }))
                        } else {
                            items.append(ContextMenuItem(L10n.messageContextSaveGif, handler: {
                                let _ = addSavedGif(postbox: context.account.postbox, fileReference: FileMediaReference.savedGif(media: file)).start()
                            }))
                        }
                        items.append(ContextMenuItem(L10n.chatSendWithoutSound, handler: {
                            arguments?.sendAppFile(file, view, true)
                        }))
                    }
                    return items
                }
            }))
        case let .separator(string, _, _):
            return SeparatorRowItem(initialSize, entry.stableId, string: string)
        case let .emoji(clues, selected, _, _):
            return ContextClueRowItem(initialSize, stableId: entry.stableId, context: context, clues: clues, selected: selected, canDisablePrediction: false, callback: { emoji in
                arguments?.searchBySuggestion(emoji)
            })
        default:
            fatalError()
        }
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private func prepareTabTransition(left:[GifTabEntry], right:[GifTabEntry], initialSize:NSSize, arguments: GifTabsArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        return entry.item(arguments, initialSize: initialSize)
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)

}

private func recentEntries(for view:OrderedItemListView?, initialSize:NSSize) -> [InputContextEntry] {
    if let view = view {
        
        let result: [ChatContextResult] = view.items.compactMap({($0.contents as? RecentMediaItem)?.media as? TelegramMediaFile}).map { file in
            let reference = ChatContextResult.InternalReference(queryId: 0, id: "gif-panel", type: "gif", title: nil, description: nil, image: nil, file: file, message: .auto(caption: "", entities: nil, replyMarkup: nil))
            return .internalReference(reference)
        }
        let values = makeMediaEnties(result, isSavedGifs: true, initialSize: NSMakeSize(initialSize.width, 100))
        var wrapped:[InputContextEntry] = []
        for value in values {
            wrapped.append(InputContextEntry.contextMediaResult(nil, value, Int64(arc4random()) | ((Int64(wrapped.count) << 40))))
        }
        
        return wrapped
    }
    return []
}

private func tabsEntries(_ emojis: [String], selected: GifTabEntryId) -> [GifTabEntry] {
    var entries:[GifTabEntry] = []
    
    entries.append(.recent(selected: selected == .recent))
    entries.append(.trending(selected: selected == .trending))

    for (i, emoji) in emojis.enumerated() {
        entries.append(.recommended(selected: selected == .recommended(emoji), index: i, value: emoji))
    }
    
    return entries
}

private func gifEntries(for collection: ChatContextResultCollection?, results: [ChatContextResult], initialSize: NSSize) -> [InputContextEntry] {
    var result: [InputContextEntry] = []
    if let collection = collection {
        result = makeMediaEnties(results, isSavedGifs: true, initialSize: NSMakeSize(initialSize.width, 100)).map({InputContextEntry.contextMediaResult(collection, $0, arc4random64())})
    }
    
    return result
}

final class RecentGifsArguments {
    var sendInlineResult:(ChatContextResultCollection,ChatContextResult, NSView) -> Void = { _,_,_  in}
    var sendAppFile:(TelegramMediaFile, NSView, Bool) -> Void = { _,_,_ in}
    var searchBySuggestion:(String)->Void = { _ in }
}

final class TableContainer : View {
    fileprivate var tableView: TableView?
    fileprivate var restrictedView:RestrictionWrappedView?
    fileprivate let progressView: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
    fileprivate let emptyResults: ImageView = ImageView()
    
    
    let searchView = SearchView(frame: .zero)
    private let searchContainer = View()
    fileprivate let packsView:HorizontalTableView = HorizontalTableView(frame: NSZeroRect)
    private let separator:View = View()
    fileprivate let tabsContainer: View = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        emptyResults.contentGravity = .center
        updateLocalizationAndTheme(theme: theme)
        
        
        searchContainer.addSubview(searchView)
        addSubview(searchContainer)
        
        tabsContainer.addSubview(packsView)
        tabsContainer.addSubview(separator)
        addSubview(tabsContainer)
        
        reinstall()
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer, let text = permissionText(from: peer, for: .banSendGifs) {
            restrictedView?.removeFromSuperview()
            restrictedView = RestrictionWrappedView(text)
            addSubview(restrictedView!)
        } else {
            restrictedView?.removeFromSuperview()
            restrictedView = nil
        }
        setFrameSize(frame.size)
        needsLayout = true
    }
    
    private var searchState: SearchState? = nil
    
    func updateSearchState(_ searchState: SearchState, animated: Bool) {
        self.searchState = searchState
        switch searchState.state {
        case .Focus:
            tabsContainer.change(pos: NSMakePoint(0, -tabsContainer.frame.height), animated: animated)
            searchContainer.change(pos: NSMakePoint(0, tabsContainer.frame.maxY), animated: animated)
        case .None:
            tabsContainer.change(pos: NSMakePoint(0, 0), animated: animated)
            searchContainer.change(pos: NSMakePoint(0, tabsContainer.frame.maxY), animated: animated)
        }
        if let tableView = tableView {
            tableView.change(size: NSMakeSize(frame.width, frame.height - searchContainer.frame.maxY), animated: animated)
            tableView.change(pos: NSMakePoint(0, searchContainer.frame.maxY), animated: animated)
        }
    }
    
    func reinstall() {
        self.packsView.removeAll()
        tableView?.removeFromSuperview()
        tableView = TableView(frame: bounds)
        var subviews:[NSView] = [tabsContainer, searchContainer,tableView!, emptyResults]
        
        restrictedView?.removeFromSuperview()
        if let restrictedView = restrictedView {
            subviews.append(restrictedView)
        }
        self.subviews = subviews
    }
    
    fileprivate func merge(with transition: TableUpdateTransition, tabTransition: TableUpdateTransition, animated: Bool) {
        self.tableView?.merge(with: transition)
        self.packsView.merge(with: tabTransition)
        if let tableView = tableView {
            let emptySearchHidden: Bool = !tableView.isEmpty
            
            if !emptySearchHidden {
                emptyResults.isHidden = false
            }
            emptyResults.change(opacity: emptySearchHidden ? 0 : 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.emptyResults.isHidden = emptySearchHidden
                }
            })
            
        } else {
            emptyResults.isHidden = true
        }
    }

    func deinstall() {
        tableView?.removeFromSuperview()
        tableView = nil
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.restrictedView?.updateLocalizationAndTheme(theme: theme)
        emptyResults.background = theme.colors.background
        emptyResults.image = theme.icons.stickersEmptySearch
        searchView.updateLocalizationAndTheme(theme: theme)
        separator.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        
        let initial: CGFloat = searchState?.state == .Focus ? -50 : 0
        
        tabsContainer.frame = NSMakeRect(0, initial, frame.width, 50)
        separator.frame = NSMakeRect(0, tabsContainer.frame.height - .borderSize, tabsContainer.frame.width, .borderSize)
        packsView.frame = tabsContainer.focus(NSMakeSize(frame.width, 40))
        
        
        searchContainer.frame = NSMakeRect(0, tabsContainer.frame.maxY, frame.width, 50)
        searchView.setFrameSize(NSMakeSize(frame.width - 20, 30))
        searchView.center()
        
        restrictedView?.setFrameSize(frame.size)

        if let tableView = tableView {
            tableView.frame = NSMakeRect(0, searchContainer.frame.maxY, frame.width, frame.height - searchContainer.frame.maxY)
            emptyResults.sizeToFit()
            emptyResults.center()
        }
        progressView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GIFViewController: TelegramGenericViewController<TableContainer>, Notifable {
    
    
    private var tabsState: ValuePromise<GifTabEntryId> = ValuePromise(.recent, ignoreRepeated: true)
    
    private let searchValue = ValuePromise<SearchState>(.init(state: .None, request: nil))
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            let value = searchState
            if value.request.isEmpty {
                self.searchValue.set(value)
            } else {
                self.searchValue.set(value)
            }
            
        }
    }
    
    private var interactions:EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    private let disposable = MetaDisposable()
    private let searchStateDisposable = MetaDisposable()
    private let preloadDisposable = MetaDisposable()
    var makeSearchCommand:((ESearchCommand)->Void)?

    override init(_ context: AccountContext) {
        super.init(context)
        bar = .init(height: 0)
    }
    
    private func updateSearchState(_ state: SearchState) {
        self.searchState = state
        if !state.request.isEmpty {
            self.makeSearchCommand?(.loading)
        }
        if self.isLoaded() == true {
            self.genericView.updateSearchState(state, animated: true)
            self.genericView.tableView?.scroll(to: .up(true))
        }
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction?.remove(observer: self)
        self.chatInteraction = chatInteraction
        chatInteraction.add(observer: self)
        if isLoaded() {
            genericView.updateRestricion(chatInteraction.presentation.peer)
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState, let peer = value.peer, let oldPeer = oldValue.peer {
            if permissionText(from: peer, for: .banSendGifs) != permissionText(from: oldPeer, for: .banSendGifs) {
                genericView.updateRestricion(peer)
            }
        }
    }
    
    
    
    func isEqual(to other: Notifable) -> Bool {
        return other === self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disposable.set(nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        genericView.tableView?.removeAll()
        genericView.tableView?.removeFromSuperview()
        genericView.tableView = nil
        ready.set(.single(false))
    }
    
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    override var canBecomeResponder: Bool {
        if let view = context.sharedContext.bindings.rootNavigation().view as? SplitView {
            return view.state == .single
        }
        return false
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        let value = GIFKeyboardConfiguration.with(appConfiguration: context.appConfiguration)
        
        genericView.reinstall()
        genericView.updateRestricion(chatInteraction?.presentation.peer)
        
        
        let searchInteractions = SearchInteractions({ [weak self] state, _ in
            self?.updateSearchState(state)
        }, { [weak self] state in
            self?.updateSearchState(state)
        })
        genericView.searchView.searchInteractions = searchInteractions
        
        _ = atomicSize.swap(_frameRect.size)
        let arguments = RecentGifsArguments()
        
        arguments.sendAppFile = { [weak self] file, view, silent in
            if let slowMode = self?.chatInteraction?.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else {
                self?.chatInteraction?.sendAppFile(file, silent)
                self?.makeSearchCommand?(.close)
                self?.context.sharedContext.bindings.entertainment().closePopover()
            }
        }
        
        arguments.sendInlineResult = { [weak self] results, result, view in
            if let slowMode = self?.chatInteraction?.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else {
                self?.chatInteraction?.sendInlineResult(results, result)
                self?.makeSearchCommand?(.close)
                self?.context.sharedContext.bindings.entertainment().closePopover()
            }
        }
        
        arguments.searchBySuggestion = { [weak self] value in
            self?.makeSearchCommand?(.apply(value))
        }
        
        let tabsArguments = GifTabsArguments(context: context, select: { [weak self] id in
            self?.makeSearchCommand?(.close)
            self?.tabsState.set(id)
        })
        
        let previous:Atomic<[InputContextEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let context = self.context
        
        struct SearchGifsState {
            var request: String
            var state: SearchFieldState
            var values:[ChatContextResult]
            var nextOffset: String
            var tab: GifTabEntryId
        }
        
        let loadNext: ValuePromise<Bool> = ValuePromise(true, ignoreRepeated: false)
        
        let searchState:Atomic<SearchGifsState> = Atomic(value: SearchGifsState(request: "", state: .None, values: [], nextOffset: "", tab: .recent))
        
        let signal = combineLatest(queue: prepareQueue, context.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]), self.searchValue.get(), tabsState.get(), loadNext.get()) |> mapToSignal { view, search, selectedTab, _ -> Signal<(TableUpdateTransition, GifTabEntryId), NoError> in
            
            _ = searchState.modify { current -> SearchGifsState in
                var current = current
                if current.request != search.request || current.state != search.state || current.tab != selectedTab {
                    current.values = []
                    current.nextOffset = ""
                }
                current.request = search.request
                current.state = search.state
                current.tab = selectedTab
                return current
            }
            
            switch search.state {
            case .Focus:
                let searchSignal = searchGifs(account: context.account, query: search.request, nextOffset: searchState.with { $0.nextOffset })
                return searchSignal |> map { result in
                    _ = searchState.modify { current -> SearchGifsState in
                        var current = current
                        current.values += (result?.results ?? [])
                        current.nextOffset = result?.nextOffset ?? ""
                        return current
                    }
                    let entries = gifEntries(for: result, results: searchState.with { $0.values }, initialSize: initialSize.with { $0 })
                    return (prepareEntries(left: previous.swap(entries), right: entries, context: context, initialSize: initialSize.with { $0 }, arguments: arguments), selectedTab)
                }
            default:
                var request: String? = nil
                
                switch selectedTab {
                case .recent:
                    break
                case .trending:
                    request = ""
                case let .recommended(value):
                    request = value
                }
                if let request = request {
                    let searchSignal = searchGifs(account: context.account, query: request, nextOffset: searchState.with { $0.nextOffset })
                    return searchSignal |> map { result in
                        _ = searchState.modify { current -> SearchGifsState in
                            var current = current
                            current.values += (result?.results ?? [])
                            current.nextOffset = result?.nextOffset ?? ""
                            return current
                        }
                        let entries = gifEntries(for: result, results: searchState.with { $0.values }, initialSize: initialSize.with { $0 })
                        return (prepareEntries(left: previous.swap(entries), right: entries, context: context, initialSize: initialSize.with { $0 }, arguments: arguments), selectedTab)
                    }
                } else {
                    let postboxView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] as! OrderedItemListView
                    let entries = recentEntries(for: postboxView, initialSize: initialSize.with { $0 }).sorted(by: <)
                    return .single((prepareEntries(left: previous.swap(entries), right: entries, context: context, initialSize: initialSize.with { $0 }, arguments: arguments), selectedTab))
                }
               
            }
        } |> deliverOnMainQueue
        
        var firstTime: Bool = true
        
        let previvousTabs: Atomic<[GifTabEntry]> = Atomic(value: [])
        
        let transitions: Signal<(TableUpdateTransition, TableUpdateTransition), NoError> = signal |> map { transition, id in
            let entries = tabsEntries(value.emojis, selected: id)
            return (transition, prepareTabTransition(left: previvousTabs.swap(entries), right: entries, initialSize: initialSize.with { $0 }, arguments: tabsArguments))
        } |> deliverOnMainQueue
        
        disposable.set(transitions.start(next: { [weak self] transition, tabTransition in
            self?.genericView.merge(with: transition, tabTransition: tabTransition, animated: !firstTime)
            self?.makeSearchCommand?(.normal)
            firstTime = false
            self?.ready.set(.single(true))
        }))
       
        
        genericView.tableView?.setScrollHandler { position in
            if !searchState.with({ $0.values.isEmpty && !$0.nextOffset.isEmpty }) {
                switch position.direction {
                case .bottom:
                    loadNext.set(true)
                default:
                    break
                }
            }
        }
    }
    
    
    override func scrollup(force: Bool = false) {
        self.genericView.tableView?.scroll(to: .up(true))
    }
    
    deinit {
        disposable.dispose()
        searchStateDisposable.dispose()
        chatInteraction?.remove(observer: self)
        preloadDisposable.dispose()
    }
    
}
