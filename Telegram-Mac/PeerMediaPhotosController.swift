//
//  PeerMediaPhotosController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.10.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit
extension Message : Equatable {
    public static func ==(lhs: Message, rhs: Message) -> Bool {
        return isEqualMessages(lhs, rhs)
    }
}

private enum PeerMediaMonthEntry : TableItemListNodeEntry {
    case line(index: MessageIndex, stableId: MessageIndex, items: [Message], galleryType: GalleryAppearType, viewType: GeneralViewType)
    case date(index: MessageIndex)
    case section(index: MessageIndex)
        
    static func < (lhs: PeerMediaMonthEntry, rhs: PeerMediaMonthEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy";
        switch self {
        case let .line(index, _, _, _, _):
            let date = Date(timeIntervalSince1970: TimeInterval(index.timestamp))
            return "items: \(formatter.string(from: date))"
        case let .date(index):
            let date = Date(timeIntervalSince1970: TimeInterval(index.timestamp))
            return "date: \(formatter.string(from: date))"
        case let .section(index):
            let date = Date(timeIntervalSince1970: TimeInterval(index.timestamp))
            return "section: \(formatter.string(from: date))"
        }
    }
    
    func item(_ arguments: PeerMediaPhotosArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .line(_, stableId, items, galleryType, viewType):
            return PeerPhotosMonthItem(initialSize, stableId: stableId, viewType: viewType, context: arguments.context, chatInteraction: arguments.chatInteraction, gallerySupplyment: arguments.gallerySupplyment, items: items, galleryType: galleryType)
        case .date:
            return PeerMediaDateItem(initialSize, index: index, stableId: stableId)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
    }
    
    var stableId: MessageIndex {
        switch self {
        case let .line(_, stableId, _, _, _):
            return stableId
        default:
            return self.index
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .line(index, _, _, _, _):
            return index
        case let .date(index):
            return index
        case let .section(index):
            return index
        }
    }
}

private final class PeerMediaPhotosArguments {
    let context: AccountContext
    let chatInteraction: ChatInteraction
    let gallerySupplyment: InteractionContentViewProtocol
    init(context: AccountContext, chatInteraction: ChatInteraction, gallerySupplyment: InteractionContentViewProtocol) {
        self.context = context
        self.gallerySupplyment = gallerySupplyment
        self.chatInteraction = chatInteraction
    }
}



private struct PeerMediaPhotosState : Equatable {
    static func == (lhs: PeerMediaPhotosState, rhs: PeerMediaPhotosState) -> Bool {
        return lhs.isLoading == rhs.isLoading && lhs.messages == rhs.messages && lhs.searchState == rhs.searchState && lhs.contentSettings == rhs.contentSettings && lhs.scrollPosition == rhs.scrollPosition && lhs.updateType == rhs.updateType && lhs.side == rhs.side
    }
    
    var isLoading: Bool
    var messages:[Message]
    var searchState: SearchState
    var contentSettings: ContentSettings
    var scrollPosition: ChatHistoryViewScrollPosition?
    var updateType: ChatHistoryViewUpdateType?
    var side: TableSavingSide?
    var view: MessageHistoryView?
    init(isLoading: Bool, messages: [Message], searchState: SearchState, contentSettings: ContentSettings, scrollPosition: ChatHistoryViewScrollPosition?, updateType: ChatHistoryViewUpdateType?, side: TableSavingSide?) {
        self.isLoading = isLoading
        self.messages = messages.reversed().filter { $0.restrictedText(contentSettings) == nil }
        self.searchState = searchState
        self.contentSettings = contentSettings
        self.updateType = updateType
        self.scrollPosition = scrollPosition
        self.side = side
    }
}

private func mediaEntires(state: PeerMediaPhotosState, arguments: PeerMediaPhotosArguments, isExternalSearch: Bool) -> [PeerMediaMonthEntry] {
    var entries:[PeerMediaMonthEntry] = []
    
    let galleryType: GalleryAppearType
    if isExternalSearch {
        galleryType = .messages(state.messages)
    } else {
        galleryType = .history
    }

    let timeDifference = Int32(arguments.context.timeDifference)
    var temp:[Message] = []
    for i in 0 ..< state.messages.count {
        
        let message = state.messages[i]
    
        temp.append(message)
        let next = i < state.messages.count - 1 ? state.messages[i + 1] : nil
        if let nextMessage = next {
            let dateId = mediaDateId(for: message.timestamp - timeDifference)
            let nextDateId = mediaDateId(for: nextMessage.timestamp - timeDifference)
            if dateId != nextDateId {
                let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: 0), timestamp: Int32(dateId))
                var viewType: GeneralViewType = .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 1, 0))
                if !entries.isEmpty {
                    entries.append(.section(index: index.peerLocalSuccessor()))
                    entries.append(.date(index: index))
                } else {
                    if !isExternalSearch {
                        viewType = .modern(position: .last, insets: NSEdgeInsetsMake(0, 0, 1, 0))
                    }
                }
                entries.append(.line(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), items: temp, galleryType: galleryType, viewType: viewType))
                temp.removeAll()
            }
        } else {
            let dateId = mediaDateId(for: message.timestamp - timeDifference)
            let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: 0), timestamp: Int32(dateId))
            
            if !entries.isEmpty {
                switch entries[entries.count - 1] {
                case let .line(prevIndex, stableId, items, galleryType, viewType):
                    let prevDateId = mediaDateId(for: prevIndex.timestamp)
                    if prevDateId != dateId {
                        entries.append(.section(index: index.peerLocalSuccessor()))
                        entries.append(.date(index: index))
                        entries.append(.line(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), items: temp, galleryType: galleryType, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 1, 0))))
                    } else {
                        entries[entries.count - 1] = .line(index: prevIndex, stableId: stableId, items: items + temp, galleryType: galleryType, viewType: viewType)
                    }
                default:
                    assertionFailure()
                }
            } else {
                if isExternalSearch {
                    entries.append(.line(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), items: temp, galleryType: galleryType, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 1, 0))))
                } else {
                    entries.append(.line(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), items: temp, galleryType: galleryType, viewType: .modern(position: .last, insets: NSEdgeInsetsMake(0, 0, 1, 0))))
                }
            }
            
        }
    }
    if !state.messages.isEmpty {
        entries.append(.section(index: MessageIndex.absoluteLowerBound()))
    }
    
    var updated:[PeerMediaMonthEntry] = []
    
    
    
    for entry in entries {
        switch entry {
        case let .line(index, _, items, galleryType, _):
            let chunks = items.chunks(4)
            for (i, chunk) in chunks.enumerated() {
                let message = chunk[0]
                let stableId = MessageIndex(message)

                let viewType = bestGeneralViewType(chunks, for: i)
                let updatedViewType: GeneralViewType = .modern(position: viewType.position, insets: NSEdgeInsetsMake(0, 0, 1, 0))
                updated.append(.line(index: index, stableId: stableId, items: chunk, galleryType: galleryType, viewType: updatedViewType))
            }
        case .date:
            updated.append(entry)
        case .section:
            updated.append(entry)
        }
    }

    return updated
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PeerMediaMonthEntry>], right: [AppearanceWrapperEntry<PeerMediaMonthEntry>], animated: Bool, scrollPostion: ChatHistoryViewScrollPosition?, updateType: ChatHistoryViewUpdateType?, side: TableSavingSide?, initialSize:NSSize, arguments: PeerMediaPhotosArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    var scrollState: TableScrollState = .none(nil)
    if let scrollPostion = scrollPostion {
        switch scrollPostion {
        case .index(_, let position, _, _):
            scrollState = position
        default:
            break
        }
    } else {
        if let updateType = updateType {
            switch updateType {
            case .Initial:
                scrollState = .saveVisible(side ?? .upper)
            case .Generic(let type):
                switch type {
                case .Initial:
                    scrollState = .saveVisible(side ?? .upper)
                case .FillHole:
                    scrollState = .saveVisible(side ?? .upper)
                default:
                    break
                }
            }
        }
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated, state: scrollState)
}


private final class PeerMediaSupplyment : InteractionContentViewProtocol {
    private weak var tableView: TableView?
    init(tableView: TableView) {
        self.tableView = tableView
    }
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if let stableId = stableId.base as? ChatHistoryEntryId, let tableView = tableView {
            switch stableId {
            case let .message(message):
                var found: NSView? = nil
                tableView.enumerateItems { item -> Bool in
                    if let item = item as? PeerPhotosMonthItem {
                        if item.contains(message.id) {
                            found = item.view?.interactionContentView(for: message.id, animateIn: animateIn)
                        }
                    }
                    return found == nil
                }
                return found
            default:
                break
            }
        }
        return nil
    }
    func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable) {
        
    }
    func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView) {
        if let stableId = stableId.base as? ChatHistoryEntryId, let tableView = tableView {
            switch stableId {
            case let .message(message):
                tableView.enumerateItems { item -> Bool in
                    if let item = item as? PeerPhotosMonthItem {
                        if item.contains(message.id) {
                            item.view?.addAccesoryOnCopiedView(innerId: message.id, view: view)
                            return false
                        }
                    }
                    return true
                }
            default:
                break
            }
        }
    }
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        return nil
    }
    func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        
    }
}

class PeerMediaPhotosController: TableViewController, PeerMediaSearchable {
    private let peerId: PeerId
    private let disposable = MetaDisposable()
    private let historyDisposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    private let previous: Atomic<[AppearanceWrapperEntry<PeerMediaMonthEntry>]> = Atomic(value: [])
    private let tags: MessageTags
    private var isExternalSearch: Bool = false
    private let location: ValuePromise<ChatHistoryLocation> = ValuePromise(ignoreRepeated: false)
    private var locationValue: ChatHistoryLocation? = nil

    private func setLocation(_ location: ChatHistoryLocation) -> Void {
        self.location.set(location)
        self.locationValue = location
    }
    
    init(_ context: AccountContext, chatInteraction: ChatInteraction, peerId: PeerId, tags: MessageTags) {
        self.peerId = peerId
        self.chatInteraction = chatInteraction
        self.tags = tags
        super.init(context)
    }
    
    private func perPageCount() -> Int {
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = min(600, atomicSize.with { $0.width } - 60)
        while true {
            let maximum = blockWidth - 7 - 7 - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 90 {
                break
            } else {
                rowCount -= 1
            }
        }
        var pageCount = Int((atomicSize.with { $0.height } / perWidth) * CGFloat(rowCount) + CGFloat(rowCount)) * 3
        pageCount -= (pageCount % 4)
        return pageCount
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = self.peerId
        let initialSize = self.atomicSize
        let tags = self.tags
        let isExternalSearch = self.isExternalSearch
        let perPageCount = self.perPageCount

        self.genericView.set(stickClass: PeerMediaDateItem.self, handler: { item in
            
        })
        
        self.genericView.needUpdateVisibleAfterScroll = true
        self.searchState.set(.single(SearchState(state: .None, request: nil)))
        self.genericView.emptyItem = PeerMediaEmptyRowItem(NSZeroSize, tags: self.tags)
        

        let requestCount = perPageCount()
        
        setLocation(.Initial(count: requestCount))
        
        
        let initialState = PeerMediaPhotosState(isLoading: false, messages: [], searchState: SearchState(state: .None, request: nil), contentSettings: context.contentSettings, scrollPosition: nil, updateType: nil, side: nil)
        let state: ValuePromise<PeerMediaPhotosState> = ValuePromise()
        let stateValue: Atomic<PeerMediaPhotosState> = Atomic(value: initialState)
        let updateState:((PeerMediaPhotosState)->PeerMediaPhotosState) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        
        let supplyment = PeerMediaSupplyment(tableView: genericView)
        
        let arguments = PeerMediaPhotosArguments(context: context, chatInteraction: chatInteraction, gallerySupplyment: supplyment)
        let animated:Atomic<Bool> = Atomic(value:false)

        
        let applyHole:() -> Void = { [weak self] in
            guard let `self` = self, let value = self.locationValue else {
                return
            }
            self.setLocation(value)
        }
        
        struct SearchResult {
            let result: [Message]?
        }
        
        let history: Signal<(ChatHistoryViewUpdate?, SearchResult?, SearchState, TableSavingSide?), NoError> = combineLatest(searchState.get(), location.get(), externalSearch.get()) |> mapToSignal { search, location, externalSearch in
            if let externalSearch = externalSearch {
                return .single((nil, SearchResult(result: externalSearch.messages), search, nil))
            } else if !search.request.isEmpty {
                
                let req = context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: nil, tags: .photoOrVideo, topMsgId: nil, minDate: nil, maxDate: nil), query: search.request, state: nil)
                
                return .single((nil, SearchResult(result: nil), search, nil)) |> then(req |> delay(0.2, queue: .concurrentDefaultQueue()) |> map { (nil, SearchResult(result: $0.0.messages), search, nil) })
            } else {
                return chatHistoryViewForLocation(location, context: context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: tags) |> map { ($0, nil, search, location.side) }
            }
        }
        
        let historyView: Atomic<MessageHistoryView?> = Atomic(value: nil)
        
        historyDisposable.set(history.start(next: { update in
            
            var messages:[Message]? = nil
            var isLoading: Bool = false
            let view: MessageHistoryView?
            let updateType: ChatHistoryViewUpdateType?

            var scroll: ChatHistoryViewScrollPosition?
            if let update = update.0 {
                switch update {
                case let .Loading(_, ut):
                    view = nil
                    isLoading = true
                    updateType = ut
                case let .HistoryView(_view, _type, _scroll, _):
                    view = _view
                    scroll = _scroll
                    isLoading = _view.isLoading
                    updateType = _type
                }
                
                switch updateType {
                case let .Generic(type: type):
                    switch type {
                    case .FillHole:
                        DispatchQueue.main.async(execute: applyHole)
                    default:
                        break
                    }
                default:
                    break
                }
                messages = view?.entries.map { value in
                    return value.message
                } ?? []
            } else if let update = update.1 {
                if let search = update.result {
                    messages = search
                } else {
                    isLoading = true
                }
                view = nil
                updateType = nil
            } else {
                view = nil
                updateType = nil
            }
            
            
            updateState { state in
                var state = state
                state.isLoading = isLoading
                if let messages = messages {
                    if !isExternalSearch {
                        state.messages = messages.reversed()
                    } else {
                        state.messages = messages
                    }
                }
                state.searchState = update.2
                state.scrollPosition = scroll
                state.updateType = updateType
                state.side = update.3
                state.view = view
                return state
            }
        }))
        
        let previous = self.previous
        
        
        let animate = animated.swap(true)

        
        let transition: Signal<(TableUpdateTransition, PeerMediaPhotosState), NoError> = combineLatest(queue: prepareQueue, state.get(), appearanceSignal) |> map { state, appearance in
            let entries = mediaEntires(state: state, arguments: arguments, isExternalSearch: isExternalSearch).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return (prepareTransition(left: previous.swap(entries), right: entries, animated: animate, scrollPostion: state.scrollPosition, updateType: state.updateType, side: state.side, initialSize: initialSize.with { $0 }, arguments: arguments), state)
        } |> deliverOnMainQueue
        
        
        var previousSearch: SearchState = SearchState(state: .None, request: nil)
        
        disposable.set(transition.start(next: { [weak self] transition, state in
            guard let `self` = self else {
                return
            }
            
            if previousSearch != state.searchState {
                self.scrollup()
            }
            previousSearch = state.searchState
            
            self.genericView.merge(with: transition)
            let searchState = MediaSearchState(state: state.searchState, animated: transition.animated, isLoading: state.isLoading)
            self.mediaSearchState.set(searchState)
            self.readyOnce()
            
            _ = historyView.swap(state.view)
        }))
        
        genericView.setScrollHandler { [weak self] scroll in
            let view = historyView.with { $0 }
            if let view = view, let strongSelf = self {
                var messageIndex:MessageIndex?
                
                let visible = strongSelf.genericView.visibleRows()
                
                switch scroll.direction {
                case .top:
                    if view.laterId != nil {
                        for i in visible.min ..< visible.max {
                            if let item = self?.genericView.item(at: i) as? PeerPhotosMonthItem {
                                if let message = item.items.first {
                                    messageIndex = MessageIndex(message)
                                    break
                                }
                            }
                        }
                    } else if view.laterId == nil, !view.holeLater, let locationValue = strongSelf.locationValue, !locationValue.isAtUpperBound, view.anchorIndex != .upperBound {
                        messageIndex = .upperBound(peerId: strongSelf.chatInteraction.peerId)
                    }
                case .bottom:
                    if view.earlierId != nil {
                        for i in stride(from: visible.max - 1, to: -1, by: -1) {
                            if let item = strongSelf.genericView.item(at: i) as? PeerPhotosMonthItem {
                                if let message = item.items.last {
                                    messageIndex = MessageIndex(message)
                                    break
                                }
                            }
                        }
                    }
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    let location: ChatHistoryLocation = .Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: strongSelf.perPageCount(), side: scroll.direction == .bottom ? .upper : .lower)
                    guard location != strongSelf.locationValue else {
                        return
                    }
                    strongSelf.setLocation(location)
                }
            }
        }
        
        onDeinit = {
            _ = historyView.swap(nil)
        }
    }
    
    private let mediaSearchState:ValuePromise<MediaSearchState> = ValuePromise(ignoreRepeated: true)
    private let searchState:Promise<SearchState> = Promise()
    
    func setSearchValue(_ value: Signal<SearchState, NoError>) {
        searchState.set(value)
    }
    
    private let externalSearch:Promise<ExternalSearchMessages?> = Promise(nil)
    
    func setExternalSearch(_ value: Signal<ExternalSearchMessages?, NoError>, _ loadMore: @escaping () -> Void) {
        externalSearch.set(value)
        self.isExternalSearch = true
    }
    
    func jumpTo(_ toMessage: Message) -> Void {

        let historyView = chatHistoryViewForLocation(.InitialSearch(location: .id(toMessage.id), count: perPageCount()), context: context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: .photoOrVideo, additionalData: [])
        
        struct FindSearchMessage {
            let message:Message?
            let loaded:Bool
        }
        
        let signal = historyView
            |> mapToSignal { historyView -> Signal<(Message?, Bool), NoError> in
                switch historyView {
                case .Loading:
                    return .single((nil, true))
                case let .HistoryView(view, _, _, _):
                    for entry in view.entries {
                        if entry.message.id == toMessage.id {
                            return .single((entry.message, false))
                        }
                    }
                    return .single((nil, false))
                }
            } |> take(until: { index in
                return SignalTakeAction(passthrough: index.0 != nil, complete: !index.1)
            }) |> map { $0.0 }
        
        _ = showModalProgress(signal: signal, for: context.window).start(next: { [weak self] message in
            if let strongSelf = self, let message = message {
                let message = message
                let toIndex = MessageIndex(message)
                let requestCount = strongSelf.perPageCount()
                
                DispatchQueue.main.async { [weak strongSelf] in
                    strongSelf?.location.set(.Scroll(index: .message(toIndex), anchorIndex: .message(toIndex), sourceIndex: .message(toIndex), scrollPosition: .top(id: MessageIndex(message), innerId: nil, animated: true, focus: .init(focus: true), inset: 0), count: requestCount, animated: true))
                }
            }
        })
    }
    
    var mediaSearchValue:Signal<MediaSearchState, NoError> {
        return mediaSearchState.get()
    }
    private var isSearch: Bool = false {
        didSet {
            if isSearch {
                searchState.set(.single(.init(state: .Focus, request: nil)))
            } else {
                searchState.set(.single(.init(state: .None, request: nil)))
            }
        }
    }
    
    override func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        var updatedStableId: AnyHashable?
        if let stableId = stableId.base as? MessageIndex {
            self.genericView.enumerateItems(with: { item in
                if let item = item as? PeerPhotosMonthItem {
                    if item.items.contains(where: { $0.id == stableId.id }) {
                        updatedStableId = item.stableId
                        return false
                    }
                }
                return true
            })
        }
        return updatedStableId
    }
    
    func toggleSearch() {
        let old = self.isSearch
        self.isSearch = !old
    }
    
    deinit {
        disposable.dispose()
        historyDisposable.dispose()
        _ = previous.swap([])
    }
    
}
