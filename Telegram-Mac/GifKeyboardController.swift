//
//  GifKeyboardController.swift
//  Telegram
//
//  Created by Mike Renoir on 29.07.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Cocoa



enum GifTabEntryId : Hashable {
    case recent
    case trending
    case recommended(String)
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

private struct State : Equatable {

    
    struct Entry : Equatable {
        let collection: ChatContextResultCollection?
        let row: ChatContextResult
        
    }
    
    enum TabEntryId : Equatable {
        case recent
        case trending
        case recommended(TelegramMediaFile)
        
        var stableId: AnyHashable {
            switch self {
            case .recent:
                return 0
            case .trending:
                return 1
            case let .recommended(file):
                return file.fileId.id
            }
        }
        
        var search: String? {
            switch self {
            case .recent:
                return nil
            case .trending:
                return ""
            case let .recommended(file):
                return file.stickerText
            }
        }
    }
    
    struct Search : Equatable {
        static let stableId: AnyHashable = AnyHashable(-1)
        var request: String
        var nextOffset: String?
        var items: [Entry]
    }
    
    var tabs:[TabEntryId] = []
    
    var search: Search?
     
    var tab: TabEntryId = .recent
    
    struct Entries : Equatable {
        var items: [Entry]
        var nextOffset: String?
    }
    
    var entries:[AnyHashable : Entries] = [:]
}

private final class Arguments {
    let context: AccountContext
    let selectTab:(State.TabEntryId)->Void
    let sendInlineResult:(ChatContextResultCollection,ChatContextResult, NSView) -> Void
    let sendAppFile:(TelegramMediaFile, NSView, Bool, Bool) -> Void

    init(context: AccountContext, selectTab:@escaping(State.TabEntryId)->Void, sendInlineResult:@escaping(ChatContextResultCollection,ChatContextResult, NSView)->Void, sendAppFile:@escaping(TelegramMediaFile, NSView, Bool, Bool) -> Void) {
        self.context = context
        self.selectTab = selectTab
        self.sendInlineResult = sendInlineResult
        self.sendAppFile = sendAppFile
    }
}

private func _id_gif(_ entry: InputMediaContextRow) -> InputDataIdentifier {
    return .init("_id_gif_\(entry.hashValue)")
}
private func _id_tab(_ stableId: AnyHashable) -> InputDataIdentifier {
    return .init("_id_tab_\(stableId)")
}


private func packEntries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    var sectionId:Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("left"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 6, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    
    for tab in state.tabs {
        
        struct Tuple: Equatable {
            let tab: State.TabEntryId
            let selected: Bool
        }
        let tuple = Tuple(tab: tab, selected: tab == state.tab)
        
        let source: GifKeyboardTabRowItem.Source
        switch tab {
        case .recent:
            source = .icon(tuple.selected ? theme.icons.gif_recent_active : theme.icons.gif_recent)
        case .trending:
            source = .icon(tuple.selected ? theme.icons.gif_trending_active : theme.icons.gif_trending)
        case let .recommended(file):
            source = .file(file)
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_tab(tuple.tab.stableId), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return GifKeyboardTabRowItem(initialSize, stableId: stableId, selected: tuple.selected, context: arguments.context, source: source, select: {
                arguments.selectTab(tab)
            })
        }))
    }
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("right"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 6, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    return entries
}

private func entries(_ state: State, arguments: Arguments, mediaArguments: ContextMediaArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
        
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 46, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    let value: [State.Entry]?
    if let search = state.search {
        value = search.items
    } else if let current = state.entries[state.tab.stableId] {
        value = current.items
    } else {
        value = nil
    }
    
    if let value = value {
        
        let values = value.map { $0.row }
        let collections = value.map { $0.collection }
        
        let items = makeMediaEnties(values, isSavedGifs: true, initialSize: NSMakeSize(350, 100))
        
        for (i, entry) in items.enumerated() {
            struct Tuple : Equatable {
                let row: InputMediaContextRow
                let collection: ChatContextResultCollection?
            }
            let tuple: Tuple = Tuple(row: entry, collection: collections[i])
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_gif(entry), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return ContextMediaRowItem(initialSize, tuple.row, 0, arguments.context, mediaArguments, collection: tuple.collection, stableId: stableId)
            }))
            index += 1
            
            if i != items.count - 1 {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_\(index)"), equatable: nil, comparable: nil, item: { initailSize, stableId in
                    return GeneralRowItem(initailSize, height: 1, stableId: stableId, backgroundColor: .clear)
                }))
            }
        }
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("bottom"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 46, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    return entries
}


final class GifKeyboardView : View {
    let tableView = TableView()
    let packsView = HorizontalTableView(frame: NSZeroRect)
    private let borderView = View()
    private let tabs = View()
    private let selectionView: View = View(frame: NSMakeRect(0, 0, 36, 36))
    
    let searchView = SearchView(frame: .zero)
    private let searchContainer = View()
    private let searchBorder = View()

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.packsView.getBackgroundColor = {
            .clear
        }
        addSubview(self.tableView)

        searchContainer.addSubview(searchView)
        searchContainer.addSubview(searchBorder)
        addSubview(searchContainer)
        
        tabs.addSubview(selectionView)
        tabs.addSubview(self.packsView)
        addSubview(self.borderView)
        addSubview(tabs)
        
        
        
        self.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateScrollerSearch()
        }))
        
        tableView.scrollerInsets = .init(left: 0, right: 0, top: 46, bottom: 50)
        
        self.layout()
    }
 
    
    override func layout() {
        super.layout()
        self.updateLayout(self.frame.size, transition: .immediate)
    }
    
    private func updateScrollerSearch() {
        self.updateLayout(self.frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        
        let initial: CGFloat = searchState?.state == .Focus ? -46 : 0

        transition.updateFrame(view: tabs, frame: NSMakeRect(0, initial, size.width, 46))
        transition.updateFrame(view: packsView, frame: tabs.focus(NSMakeSize(size.width, 36)))
        transition.updateFrame(view: borderView, frame: NSMakeRect(0, tabs.frame.maxY, size.width, .borderSize))

        
        let searchDest = (tableView.firstItem?.frame.minY ?? 0) + (tableView.clipView.destination?.y ?? tableView.documentOffset.y)
                
        transition.updateFrame(view: searchContainer, frame: NSMakeRect(0, min(max(tabs.frame.maxY - searchDest, 0), tabs.frame.maxY), size.width, 46))
        transition.updateFrame(view: searchView, frame: searchContainer.focus(NSMakeSize(size.width - 16, 30)))
        transition.updateFrame(view: searchBorder, frame: NSMakeRect(0, searchContainer.frame.height - .borderSize, size.width, .borderSize))
        
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, tabs.frame.maxY, size.width, size.height))


        let alpha: CGFloat = searchState?.state == .Focus && tableView.documentOffset.y > 0 ? 1 : 0
        transition.updateAlpha(view: searchBorder, alpha: alpha)
                
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        borderView.backgroundColor = theme.colors.border
        tabs.backgroundColor = theme.colors.background
        searchContainer.backgroundColor = theme.colors.background
        searchBorder.backgroundColor = theme.colors.border
        self.searchView.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private var searchState: SearchState? = nil

    func updateSearchState(_ searchState: SearchState, animated: Bool) {
        self.searchState = searchState

        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        self.updateLayout(self.frame.size, transition: transition)
    }
    
    func update(sections: TableUpdateTransition, packs: TableUpdateTransition) {
        self.tableView.merge(with: sections)
        self.packsView.merge(with: packs)
    }
}

final class GifKeyboardController : TelegramGenericViewController<GifKeyboardView> {
    
    private let disposable = MetaDisposable()
    
    private var interactions: EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    
    private var updateState: (((State) -> State) -> Void)? = nil
    
    var makeSearchCommand:((ESearchCommand)->Void)?
    
    var mode: EntertainmentViewController.Mode = .common
   
    private let searchValue = ValuePromise<SearchState>(.init(state: .None, request: nil))
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            self.searchValue.set(searchState)
        }
    }
    
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
        }
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let emojies = GIFKeyboardConfiguration.with(appConfiguration: context.appConfiguration)
                
       
        
        let context = self.context
        let mode = self.mode
        let actionsDisposable = DisposableSet()
        let disposableDict = DisposableDict<AnyHashable>()
        actionsDisposable.add(disposableDict)
        let initialSize = self.atomicSize

        
        
       
        
        let initialState = State()
        
        let statePromise = ValuePromise<State>(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let updateSearchCommand:()->Void = { [weak self] in
            self?.makeSearchCommand?(.normal)
        }
        let makeSearch:(State.TabEntryId?, String, String)->Void = { tab, query, nextOffset in
            let searchSignal = context.engine.stickers.searchGifs(query: query, nextOffset: nextOffset)
            
            let stableId: AnyHashable = tab?.stableId ?? State.Search.stableId

            disposableDict.set(searchSignal.start(next: { result in
                
                let values = result?.results ?? []
                var entries:[State.Entry] = []
                for value in values {
                    entries.append(.init(collection: nil, row: value))
                }
                updateState { current in
                    var current = current
                    if tab == nil {
                        let items = current.search?.items ?? []
                        current.search?.items = items + entries
                        current.search?.nextOffset = nextOffset
                    } else {
                        var state = current.entries[stableId] ?? .init(items: [], nextOffset: nil)
                        state.items = state.items + entries
                        state.nextOffset = result?.nextOffset
                        current.entries[stableId] = state
                    }
                    return current
                }
                DispatchQueue.main.async {
                    updateSearchCommand()
                }
            }), forKey: stableId)
        }
        
        let updateSearchState:(SearchState)->Void = { searchState in
            switch searchState.state {
            case .Focus:
                updateState { current in
                    var current = current
                    if !searchState.request.isEmpty {
                        current.search = .init(request: searchState.request, nextOffset: "", items: [])
                    } else {
                        current.search = nil
                    }
                    return current
                }
                makeSearch(nil, searchState.request, "")
            case .None:
                updateState { current in
                    var current = current
                    current.search = nil
                    return current
                }
            }
        }
        
        let searchInteractions = SearchInteractions({ [weak self] state, _ in
            self?.updateSearchState(state)
            updateSearchState(state)
        }, { [weak self] state in
            self?.updateSearchState(state)
            updateSearchState(state)
        })
        
        genericView.searchView.searchInteractions = searchInteractions
        
        
        let arguments = Arguments(context: context, selectTab: { [weak self] tab in
            updateState { current in
                var current = current
                current.tab = tab
                return current
            }
            
            let cached = stateValue.with { $0.entries[tab.stableId] }
            
            if let search = tab.search, cached == nil {
                makeSearch(tab, search, "")
            }
            self?.genericView.tableView.scroll(to: .up(true))
            self?.genericView.packsView.scroll(to: .center(id: InputDataEntryId.custom(_id_tab(tab.stableId)), innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
        }, sendInlineResult: { [weak self] results, result, view in
            if let slowMode = self?.chatInteraction?.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else {
                self?.chatInteraction?.sendInlineResult(results, result)
                self?.makeSearchCommand?(.close)
                self?.interactions?.close()
            }
        }, sendAppFile: { [weak self] file, view, silent, schedule in
            if let slowMode = self?.chatInteraction?.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else {
                self?.interactions?.sendGIF(file, silent, schedule)
                self?.makeSearchCommand?(.close)
                self?.interactions?.close()
            }
        })
        
        let mediaArguments: ContextMediaArguments = .init(sendResult: { collection, result, view in
            switch result {
            case let .internalReference(values):
                if let collection = collection {
                    arguments.sendInlineResult(collection, result, view)
                }else if let file = values.file {
                    arguments.sendAppFile(file, view, false, false)
                }
            default:
                break
            }
        }, menuItems: { file, view in
            if mode == .common {
                return context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                    var items: [ContextMenuItem] = []
                    if let mediaId = file.id {
                        let gifItems = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap { $0.contents.get(RecentMediaItem.self) }
                        if let _ = gifItems.firstIndex(where: {$0.media.id == mediaId}) {
                            items.append(ContextMenuItem(strings().messageContextRemoveGif, handler: {
                                let _ = removeSavedGif(postbox: context.account.postbox, mediaId: mediaId).start()
                                showModalText(for: context.window, text: strings().chatContextGifRemoved)
                            }, itemImage: MenuAnimation.menu_remove_gif.value))
                        } else {
                            items.append(ContextMenuItem(strings().messageContextSaveGif, handler: {
                                let limit = context.isPremium ? context.premiumLimits.saved_gifs_limit_premium : context.premiumLimits.saved_gifs_limit_default
                                if limit >= gifItems.count, !context.isPremium {
                                    showModalText(for: context.window, text: strings().chatContextFavoriteGifsLimitInfo("\(context.premiumLimits.saved_gifs_limit_premium)"), title: strings().chatContextFavoriteGifsLimitTitle, callback: { value in
                                        showPremiumLimit(context: context, type: .savedGifs)
                                    })
                                } else {
                                    showModalText(for: context.window, text: strings().chatContextGifAdded)
                                }
                                let _ = addSavedGif(postbox: context.account.postbox, fileReference: FileMediaReference.savedGif(media: file)).start()
                            }, itemImage: MenuAnimation.menu_add_gif.value))
                        }
                        items.append(ContextMenuItem(strings().chatSendWithoutSound, handler: {
                            arguments.sendAppFile(file, view, true, false)
                        }, itemImage: MenuAnimation.menu_mute.value))
                        items.append(ContextMenuItem(strings().chatSendScheduledMessage, handler: {
                            arguments.sendAppFile(file, view, false, true)
                        }, itemImage: MenuAnimation.menu_schedule_message.value))
                    }
                    return items
                }
            } else {
                return .single([])
            }
        }, openMessage: { message in
            
        }, messageMenuItems: { message, view in
            return .single([])
        })

        self.updateState = { f in
            updateState(f)
        }
        
        let signal:Signal<(sections: InputDataSignalValue, packs: InputDataSignalValue, state: State), NoError> = statePromise.get()
        |> deliverOnPrepareQueue
        |> map { state in
            let sections = InputDataSignalValue(entries: entries(state, arguments: arguments, mediaArguments: mediaArguments))
            let packs = InputDataSignalValue(entries: packEntries(state, arguments: arguments))
            return (sections: sections, packs: packs, state: state)
        }
        
        
        let previousSections: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let previousPacks: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])

        
        let onMainQueue: Atomic<Bool> = Atomic(value: false)
        
        let inputArguments = InputDataArguments(select: { _, _ in
            
        }, dataUpdated: {
            
        })
        
        let transition: Signal<(sections: TableUpdateTransition, packs: TableUpdateTransition, state: State), NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, signal) |> mapToQueue { appearance, state in
            let sectionEntries = state.sections.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let packEntries = state.packs.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})

            let onMain = onMainQueue.swap(false)
                        
            let sectionsTransition = prepareInputDataTransition(left: previousSections.swap(sectionEntries), right: sectionEntries, animated: state.sections.animated, searchState: state.sections.searchState, initialSize: initialSize.with{$0}, arguments: inputArguments, onMainQueue: onMain)
            
            
            let packsTransition = prepareInputDataTransition(left: previousPacks.swap(packEntries), right: packEntries, animated: state.packs.animated, searchState: state.packs.searchState, initialSize: initialSize.with{$0}, arguments: inputArguments, onMainQueue: onMain)

            return combineLatest(sectionsTransition, packsTransition) |> map { values in
                return (sections: values.0, packs: values.1, state: state.state)
            }
            
        } |> deliverOnMainQueue
        
        
        self.disposable.set(transition.start(next: { [weak self] sections, packs, state in
            self?.genericView.update(sections: sections, packs: packs)
            self?.readyOnce()
        }))
        
        let recent: Signal<[State.Entry], NoError> = context.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]) |> map { view in
            
            let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]! as! OrderedItemListView
            
            let result: [ChatContextResult] = view.items.compactMap({ $0.contents.get(RecentMediaItem.self)?.media }).map { file in
                let reference = ChatContextResult.InternalReference(queryId: 0, id: "gif-panel", type: "gif", title: nil, description: nil, image: nil, file: file, message: .auto(caption: "", entities: nil, replyMarkup: nil))
                return .internalReference(reference)
            }
            
            var entries:[State.Entry] = []
            for value in result {
                entries.append(.init(collection: nil, row: value))
            }
            return entries
        }
        
        let tabs: Signal<[TelegramMediaFile], NoError> = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false) |> map { info in
            switch info {
            case let .result(_, items, _):
                return emojies.emojis.compactMap { emoji in
                    if let first = items.first(where: { $0.file.stickerText == emoji }) {
                        return first.file
                    }
                    return nil
                }
            default:
                return []
            }
        }
        
        actionsDisposable.add(combineLatest(recent, tabs).start(next: { recent, tabs in
            updateState { current in
                var current = current
                current.entries[State.TabEntryId.recent.stableId] = State.Entries(items: recent, nextOffset: nil)
                
                var tabsEntries: [State.TabEntryId] = []
                if !recent.isEmpty {
                    tabsEntries.append(.recent)
                }
                tabsEntries.append(.trending)
                for tab in tabs {
                    tabsEntries.append(.recommended(tab))
                }
                if recent.isEmpty && current.tab == .recent {
                    current.tab = .trending
                }
                current.tabs = tabsEntries
                return current
            }
        }))
        
        self.onDeinit = {
            actionsDisposable.dispose()
            _ = previousSections.swap([])
            _ = previousPacks.swap([])
        }
        
        genericView.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                let state = stateValue.with { $0 }
                if let search = state.search, let nextOffset = search.nextOffset {
                    makeSearch(nil, search.request, nextOffset)
                } else {
                    if let value = state.entries[state.tab.stableId], let nextOffset = value.nextOffset {
                        if let search = state.tab.search {
                            makeSearch(state.tab, search, nextOffset)
                        }
                    }
                }
            default:
                break
            }
        }
        
        makeSearch(.trending, "", "")
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.updateState? { current in
            var current = current
            current.entries = current.entries.filter({ $0.key == current.tab.stableId || $0.key == State.TabEntryId.recent.stableId })
            return current
        }
    }
}
