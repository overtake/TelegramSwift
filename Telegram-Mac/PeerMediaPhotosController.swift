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
            return PeerPhotosMonthItem(initialSize, stableId: stableId, viewType: viewType, context: arguments.context, chatInteraction: arguments.chatInteraction, items: items, galleryType: galleryType, gallery: arguments.gallery)
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
    let gallery:(Message, GalleryAppearType)->Void
    init(context: AccountContext, chatInteraction: ChatInteraction, gallerySupplyment: InteractionContentViewProtocol, gallery:@escaping(Message, GalleryAppearType)->Void) {
        self.context = context
        self.gallerySupplyment = gallerySupplyment
        self.chatInteraction = chatInteraction
        self.gallery = gallery
    }
}



private struct PeerMediaPhotosState : Equatable {
    static func == (lhs: PeerMediaPhotosState, rhs: PeerMediaPhotosState) -> Bool {
        return lhs.isLoading == rhs.isLoading && lhs.messages == rhs.messages && lhs.searchState == rhs.searchState && lhs.contentSettings == rhs.contentSettings && lhs.scrollPosition == rhs.scrollPosition && lhs.updateType == rhs.updateType && lhs.side == rhs.side && lhs.perRowCount == rhs.perRowCount
    }
    
    var isLoading: Bool
    var messages:[Message]
    var searchState: SearchState
    var contentSettings: ContentSettings
    var scrollPosition: ChatHistoryViewScrollPosition?
    var updateType: ChatHistoryViewUpdateType?
    var side: TableSavingSide?
    var view: MessageHistoryView?
    var perRowCount: Int
    init(isLoading: Bool, messages: [Message], searchState: SearchState, contentSettings: ContentSettings, scrollPosition: ChatHistoryViewScrollPosition?, updateType: ChatHistoryViewUpdateType?, side: TableSavingSide?, perRowCount: Int) {
        self.isLoading = isLoading
        self.messages = messages.reversed().filter { $0.restrictedText(contentSettings) == nil }
        self.searchState = searchState
        self.contentSettings = contentSettings
        self.updateType = updateType
        self.scrollPosition = scrollPosition
        self.side = side
        self.perRowCount = perRowCount
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
                var viewType: GeneralViewType = .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                if !entries.isEmpty {
                    entries.append(.section(index: index.peerLocalSuccessor()))
                    entries.append(.date(index: index))
                } else {
                    if !isExternalSearch {
                        viewType = .modern(position: .last, insets: NSEdgeInsetsMake(0, 0, 0, 0))
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
                        entries.append(.line(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), items: temp, galleryType: galleryType, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))))
                    } else {
                        entries[entries.count - 1] = .line(index: prevIndex, stableId: stableId, items: items + temp, galleryType: galleryType, viewType: viewType)
                    }
                default:
                    assertionFailure()
                }
            } else {
                if isExternalSearch {
                    entries.append(.line(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), items: temp, galleryType: galleryType, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))))
                } else {
                    entries.append(.line(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), items: temp, galleryType: galleryType, viewType: .modern(position: .last, insets: NSEdgeInsetsMake(0, 0, 0, 0))))
                }
            }
            
        }
    }
    if !state.messages.isEmpty {
        entries.append(.section(index: MessageIndex.absoluteLowerBound()))
    }
    
    var updated:[PeerMediaMonthEntry] = []
    
    
    
    var j: Int = 0
    for entry in entries {
        switch entry {
        case let .line(index, _, items, galleryType, _):
            let chunks = items.chunks(state.perRowCount)
            for (i, chunk) in chunks.enumerated() {
                let message = chunk[0]
                let stableId = MessageIndex(message)

                var viewType: GeneralViewType = bestGeneralViewType(chunks, for: i)
                if i == 0 && j == 0 {
                    viewType = chunks.count > 1 ? .innerItem : .lastItem
                }
                let updatedViewType: GeneralViewType = .modern(position: viewType.position, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                updated.append(.line(index: index, stableId: stableId, items: chunk, galleryType: galleryType, viewType: updatedViewType))
            }
            j += 1
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
                scrollState = .none(nil)
            case .Generic(let type):
                switch type {
                case .Initial, .FillHole, .UpdateVisible:
                    scrollState = .saveVisible(side ?? .upper, false)
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
    private var isTopHistory: (()->Bool)? = nil
    private var updatePerRowCount:((Int) -> Void)? = nil
    private var threadInfo: ThreadInfo?
    private func setLocation(_ location: ChatHistoryLocation) -> Void {
        self.location.set(location)
        self.locationValue = location
    }
    
    init(_ context: AccountContext, chatInteraction: ChatInteraction, threadInfo: ThreadInfo?, peerId: PeerId, tags: MessageTags) {
        self.peerId = peerId
        self.threadInfo = threadInfo
        self.chatInteraction = chatInteraction
        self.tags = tags
        super.init(context)
    }
    
    private var perRowCount: Int {
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = min(600, atomicSize.with { $0.width })
        while true {
            let maximum = blockWidth - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 90 {
                break
            } else {
                rowCount -= 1
            }
        }
        return rowCount
    }
    
    private func perPageCount() -> Int {
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = min(600, atomicSize.with { $0.width })
        while true {
            let maximum = blockWidth - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 90 {
                break
            } else {
                rowCount -= 1
            }
        }
        let pageCount = Int((atomicSize.with { $0.height } / perWidth) * CGFloat(rowCount) + CGFloat(rowCount)) * 2
//        pageCount -= (pageCount % rowCount)
        return pageCount * 5
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        updatePerRowCount?(self.perRowCount)
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
        
        setLocation(.Initial(count: requestCount, scrollPosition: nil))
        
        
        let initialState = PeerMediaPhotosState(isLoading: false, messages: [], searchState: SearchState(state: .None, request: nil), contentSettings: context.contentSettings, scrollPosition: nil, updateType: nil, side: nil, perRowCount: self.perRowCount)
        let state: ValuePromise<PeerMediaPhotosState> = ValuePromise(ignoreRepeated: true)
        let stateValue: Atomic<PeerMediaPhotosState> = Atomic(value: initialState)
        let updateState:((PeerMediaPhotosState)->PeerMediaPhotosState) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        
        updatePerRowCount = { value in
            updateState { current in
                var current = current
                current.perRowCount = value
                return current
            }
        }
        
        let supplyment = PeerMediaSupplyment(tableView: genericView)
        
        let mode: ChatMode
        let chatLocation = chatInteraction.chatLocation
        
        let contextHolder: Atomic<ChatLocationContextHolder?>
        if let threadInfo = threadInfo {
            mode = .thread(mode: .topic(origin: threadInfo.message.effectiveTopId))
            contextHolder = threadInfo.contextHolder
        } else {
            mode = .history
            contextHolder = .init(value: nil)
        }
        
        let arguments = PeerMediaPhotosArguments(context: context, chatInteraction: chatInteraction, gallerySupplyment: supplyment, gallery: { [weak self] message, type in
            
            let accept:()->Void = {
                let parameters = ChatMediaGalleryParameters(showMedia: { _ in }, showMessage: { message in
                    self?.chatInteraction.focusMessageId(nil, .init(messageId: message.id, string: nil), .none(nil))
                }, isWebpage: false, media: message.anyMedia!, automaticDownload: true)
                
                showChatGallery(context: context, message: message, supplyment, parameters, type: type, reversed: true, chatMode: mode, chatLocation: chatLocation, contextHolder: contextHolder)
            }
            
            if message.isSensitiveContent(platform: "ios") {
                
                if !context.contentConfig.sensitiveContentEnabled, context.contentConfig.canAdjustSensitiveContent {
                    let need_verification = context.appConfiguration.getBoolValue("need_age_video_verification", orElse: false)
                    
                    if need_verification {
                        showModal(with: VerifyAgeAlertController(context: context), for: context.window)
                        return
                    }
                }
                if context.contentConfig.sensitiveContentEnabled {
                    accept()
                } else {
                    verifyAlert(for: context.window, header: strings().chatSensitiveContent, information: strings().chatSensitiveContentConfirm, ok: strings().chatSensitiveContentConfirmOk, option: context.contentConfig.canAdjustSensitiveContent ? strings().chatSensitiveContentConfirmThird : nil, optionIsSelected: false, successHandler: { result in
                        
                        if result == .thrid {
                            let _ = updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: true).start()
                        }
                        accept()
                    })
                }
            } else {
                accept()
            }
            
        })
        
        /*
         layoutItem.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))

         */
        
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
        
        let chatLocationInput: ChatLocationInput = self.chatLocationInput
        
        
        let history: Signal<(ChatHistoryViewUpdate?, SearchResult?, SearchState, TableSavingSide?), NoError> = combineLatest(searchState.get(), location.get(), externalSearch.get()) |> mapToSignal { search, location, externalSearch in
            if let externalSearch = externalSearch {
                return .single((nil, SearchResult(result: externalSearch.messages), search, nil))
            } else if !search.request.isEmpty {
                
                let req = context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: nil, tags: .photoOrVideo, reactions: [], threadId: nil, minDate: nil, maxDate: nil), query: search.request, state: nil)
                
                return .single((nil, SearchResult(result: nil), search, nil)) |> then(req |> delay(0.2, queue: .concurrentDefaultQueue()) |> map { (nil, SearchResult(result: $0.0.messages), search, nil) })
            } else {
                return chatHistoryViewForLocation(location, context: context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tag: .tag(tags), chatLocationInput: chatLocationInput) |> map { ($0, nil, search, location.side) }
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
        
        

        
        let transition: Signal<(TableUpdateTransition, PeerMediaPhotosState), NoError> = combineLatest(queue: prepareQueue, state.get(), appearanceSignal) |> map { state, appearance in
            let entries = mediaEntires(state: state, arguments: arguments, isExternalSearch: isExternalSearch).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return (prepareTransition(left: previous.swap(entries), right: entries, animated: animated.swap(true), scrollPostion: state.scrollPosition, updateType: state.updateType, side: state.side, initialSize: initialSize.with { $0 }, arguments: arguments), state)
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
        isTopHistory = {
            return historyView.with { $0?.laterId == nil }
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
    
    private var chatLocationInput: ChatLocationInput {
        let chatLocationInput: ChatLocationInput
        if let threadInfo = threadInfo {
            chatLocationInput = context.chatLocationInput(for: .thread(threadInfo.message), contextHolder: threadInfo.contextHolder)
        } else {
            chatLocationInput = .peer(peerId: peerId, threadId: nil)
        }
        return chatLocationInput
    }
    
    func jumpTo(_ toMessage: Message) -> Void {

        let historyView = chatHistoryViewForLocation(.InitialSearch(location: .id(toMessage.id, nil), count: perPageCount()), context: context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tag: .tag(.photoOrVideo), additionalData: [], chatLocationInput: self.chatLocationInput)
        
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
    
    var onTheTop: Bool {
        return self.isTopHistory?() ?? true
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
