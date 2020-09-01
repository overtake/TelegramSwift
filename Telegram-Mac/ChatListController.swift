//
//  TGDialogsViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore



enum UIChatListEntryId : Hashable {
    case chatId(PeerId, Int32?)
    case groupId(PeerGroupId)
    case reveal
    case empty
    case loading
}

struct ChatListInputActivity : Equatable {
    let peer: PeerEquatable
    let activity: PeerInputActivity
    init(_ peer: Peer, _ activity: PeerInputActivity) {
        self.peer = PeerEquatable(peer)
        self.activity = activity
    }
}

struct ChatListPeerInputActivities : Equatable {
    let activities: [PeerId: [ChatListInputActivity]]
    
    init(activities: [PeerId: [ChatListInputActivity]]) {
        self.activities = activities
    }
    func withUpdatedActivities(_ activities: [PeerId: [ChatListInputActivity]]) -> ChatListPeerInputActivities {
        return ChatListPeerInputActivities(activities: activities)
    }
}

struct ChatListState: Equatable {
    let activities: ChatListPeerInputActivities
    
    func updateActivities(_ f:(ChatListPeerInputActivities)->ChatListPeerInputActivities) -> ChatListState {
        return ChatListState(activities: f(self.activities))
    }
}

struct UIChatAdditionalItem : Equatable {
    static func == (lhs: UIChatAdditionalItem, rhs: UIChatAdditionalItem) -> Bool {
        return lhs.item.isEqual(to: rhs.item) && lhs.index == rhs.index
    }
    
    let item: AdditionalChatListItem
    let index: Int
}


enum UIChatListEntry : Identifiable, Comparable {
    case chat(ChatListEntry, [ChatListInputActivity], UIChatAdditionalItem?, filter: ChatListFilter?)
    case group(Int, PeerGroupId, [ChatListGroupReferencePeer], Message?, PeerGroupUnreadCountersCombinedSummary, TotalUnreadCountDisplayCategory, Bool, HiddenArchiveStatus)
    case reveal([ChatListFilter], ChatListFilter?, ChatListFilterBadges)
    case empty(ChatListFilter?)
    case loading(ChatListFilter?)
    static func == (lhs: UIChatListEntry, rhs: UIChatListEntry) -> Bool {
        switch lhs {
        case let .chat(entry, activity, additionItem, filter):
            if case .chat(entry, activity, additionItem, filter) = rhs {
               return true
            } else {
                return false
            }
        case let .group(index, groupId, peers, lhsMessage, unreadState, unreadCountDisplayCategory, animated, isHidden):
            if case .group(index, groupId, peers, let rhsMessage, unreadState, unreadCountDisplayCategory, animated, isHidden) = rhs {
                if let lhsMessage = lhsMessage, let rhsMessage = rhsMessage {
                    return isEqualMessages(lhsMessage, rhsMessage)
                } else if (lhsMessage != nil) != (rhsMessage != nil) {
                    return false
                } else {
                    return true
                }
            } else {
                return false
            }
        case let .reveal(filters, current, counters):
            if case .reveal(filters, current, counters) = rhs {
                return true
            } else {
                return false
            }
        case let .empty(filter):
            if case .empty(filter) = rhs {
                return true
            } else {
                return false
            }
        case let .loading(filter):
            if case .loading(filter) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var index: ChatListIndex {
        switch self {
        case let .chat(entry, _, additionItem, _):
            if let additionItem = additionItem {
                var current = MessageIndex.absoluteUpperBound().predecessor()
                for _ in 0 ..< additionItem.index {
                    current = current.predecessor()
                }
                return ChatListIndex(pinningIndex: 0, messageIndex: current)
            }
            switch entry {
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            case let .MessageEntry(values):
               return values.0
            }
        case .reveal:
            return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound())
        case let .group(values):
            var index = MessageIndex.absoluteUpperBound().predecessor()
            for _ in 0 ..< values.0 {
                index = index.predecessor()
            }
            return ChatListIndex(pinningIndex: 0, messageIndex: index)
        case .empty:
            return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound().predecessor())
        case .loading:
            return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound().predecessor())
        }
    }
    
    static func < (lhs: UIChatListEntry, rhs: UIChatListEntry) -> Bool {
       return lhs.index < rhs.index
    }
    
    var stableId: UIChatListEntryId {
        switch self {
        case let .chat(entry, _, _, filterId):
            return .chatId(entry.index.messageIndex.id.peerId, filterId?.id)
        case let .group(_, groupId, _, _, _, _, _, _):
            return .groupId(groupId)
        case .reveal:
            return .reveal
        case .empty:
            return .empty
        case .loading:
            return .loading
        }
    }
    
}



fileprivate func prepareEntries(from:[AppearanceWrapperEntry<UIChatListEntry>]?, to:[AppearanceWrapperEntry<UIChatListEntry>], adIndex: UInt16?, context: AccountContext, initialSize:NSSize, animated:Bool, scrollState:TableScrollState? = nil, groupId: PeerGroupId, setupFilter: @escaping(ChatListFilter?)->Void, openFilterSettings: @escaping(ChatListFilter?)->Void, tabsMenuItems: @escaping(ChatListFilter?)->[ContextMenuItem]) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
        
        var cancelled: Bool = false
        
        func makeItem(_ entry: AppearanceWrapperEntry<UIChatListEntry>) -> TableRowItem {
            switch entry.entry {
            case let .chat(inner, activities, addition, filter):
                switch inner {
                case let .HoleEntry(hole):
                    return ChatListHoleRowItem(initialSize, context, hole)
                case let .MessageEntry(index, messages, readState, isMuted, embeddedState, renderedPeer, peerPresence, summaryInfo, hasFailed, isContact):
                    var pinnedType: ChatListPinnedType = .some
                    if let addition = addition {
                        pinnedType = .ad(addition.item)
                    } else if index.pinningIndex == nil {
                        pinnedType = .none
                    }
                    return ChatListRowItem(initialSize, context: context, messages: messages, index: inner.index, readState: readState, isMuted: isMuted, embeddedState: embeddedState, pinnedType: pinnedType, renderedPeer: renderedPeer, peerPresence: peerPresence, summaryInfo: summaryInfo, activities: activities, associatedGroupId: groupId, hasFailed: hasFailed, filter: filter)
                }
            case let .group(_, groupId, peers, message, unreadState, unreadCountDisplayCategory, animated, archiveStatus):
                return ChatListRowItem(initialSize, context: context, pinnedType: .none, groupId: groupId, peers: peers, messages: message != nil ? [message!] : [], unreadState: unreadState, unreadCountDisplayCategory: unreadCountDisplayCategory, animateGroup: animated, archiveStatus: archiveStatus)
            case let .reveal(tabs, selected, counters):
                return ChatListRevealItem(initialSize, context: context, tabs: tabs, selected: selected, counters: counters, action: setupFilter, openSettings: {
                    openFilterSettings(nil)
                }, menuItems: tabsMenuItems)
            case let .empty(filter):
                return ChatListEmptyRowItem(initialSize, stableId: entry.stableId, filter: filter, context: context, openFilterSettings: openFilterSettings)
            case let .loading(filter):
                return ChatListLoadingRowItem(initialSize, stableId: entry.stableId, filter: filter, context: context)
            }
        }
        
        
        
        let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
            return makeItem(entry)
        })
        
        let nState = scrollState ?? (animated ? .none(nil) : .saveVisible(.lower))
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated: animated, state: nState, animateVisibleOnly: false)
                
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return ActionDisposable {
           cancelled = true
        }
    }
}


enum HiddenArchiveStatus : Equatable {
    case normal
    case collapsed
    case hidden(Bool)
    
    var rawValue: Int {
        switch self {
        case .normal:
            return 0
        case .collapsed:
            return 1
        case .hidden:
            return 2
        }
    }
    var isHidden: Bool {
        switch self {
        case .hidden:
            return true
        default:
            return false
        }
    }
    
    init?(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .normal
        case 1:
            self = .collapsed
        case 2:
            self = .hidden(true)
        default:
            return nil
        }
    }
}

struct FilterData : Equatable {
    let filter: ChatListFilter?
    let tabs: [ChatListFilter]
    let sidebar: Bool
    init(filter: ChatListFilter?, tabs: [ChatListFilter], sidebar: Bool) {
        self.filter = filter
        self.tabs = tabs
        self.sidebar = sidebar
    }
    func withUpdatedFilter(_ filter: ChatListFilter?) -> FilterData {
        return FilterData(filter: filter, tabs: self.tabs, sidebar: self.sidebar)
    }
    func withUpdatedTabs(_ tabs:  [ChatListFilter]) -> FilterData {
        return FilterData(filter: self.filter, tabs: tabs, sidebar: self.sidebar)
    }
    func withUpdatedSidebar(_ sidebar: Bool) -> FilterData {
        return FilterData(filter: self.filter, tabs: self.tabs, sidebar: sidebar)
    }
}

private struct HiddenItems : Equatable {
    let archive: HiddenArchiveStatus
    let promo: Set<PeerId>
}

class ChatListController : PeersListController {
    
    private let filter = ValuePromise<FilterData>(ignoreRepeated: true)
    private let _filterValue = Atomic<FilterData>(value: FilterData(filter: nil, tabs: [], sidebar: false))
    private var filterValue: FilterData? {
        return _filterValue.with { $0 }
    }
    
    var filterSignal : Signal<FilterData, NoError> {
        return self.filter.get()
    }
    
    func updateFilter(_ f:(FilterData)->FilterData) {
        let previous = filterValue
        let current = _filterValue.modify(f)
        self.genericView.searchView.change(state: .None,  true)
        if previous?.filter?.id != current.filter?.id {
            scrollup(force: true)
            _  = first.swap(true)
            _  = animated.swap(false)
            self.request.set(.single(.Initial(max(Int(context.window.frame.height / 70) + 3, 12), nil)))
        }
        filter.set(current)
        setCenterTitle(self.defaultBarTitle)
    }
    
    private let request = Promise<ChatListIndexRequest>()
    private let previousChatList:Atomic<ChatListView?> = Atomic(value: nil)
    private let first = Atomic(value:true)
    private let animated = Atomic(value: false)
    private let removePeerIdGroupDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    private let scrollDisposable = MetaDisposable()
    private let reorderDisposable = MetaDisposable()
    private let globalPeerDisposable = MetaDisposable()
    private let archivationTooltipDisposable = MetaDisposable()
    private let undoTooltipControl: UndoTooltipControl
    private let animateGroupNextTransition:Atomic<PeerGroupId?> = Atomic(value: nil)
    private var activityStatusesDisposable:Disposable?
    
    private let suggestAutoarchiveDisposable = MetaDisposable()
    
    private var didSuggestAutoarchive: Bool = false
    
    private let hiddenItemsValue: Atomic<HiddenItems> = Atomic(value: HiddenItems(archive: FastSettings.archiveStatus, promo: Set()))
    private let hiddenItemsState: ValuePromise<HiddenItems> = ValuePromise(HiddenItems(archive: FastSettings.archiveStatus, promo: Set()), ignoreRepeated: true)
    
    private let filterDisposable = MetaDisposable()
    
    private func updateHiddenStateState(_ f:(HiddenItems)->HiddenItems) {
        let result = hiddenItemsValue.modify(f)
        FastSettings.archiveStatus = result.archive
        hiddenItemsState.set(result)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        let initialSize = self.atomicSize
        let context = self.context
        let previousChatList = self.previousChatList
        let first = Atomic<(ChatListIndex?, ChatListIndex?)>(value: (nil, nil))
        let scrollUp:Atomic<Bool> = self.first
        let groupId = self.mode.groupId
        let previousEntries:Atomic<[AppearanceWrapperEntry<UIChatListEntry>]?> = Atomic(value: nil)
        let animated: Atomic<Bool> = self.animated
        let animateGroupNextTransition = self.animateGroupNextTransition
        var scroll:TableScrollState? = nil

        let initialState = ChatListState(activities: ChatListPeerInputActivities(activities: [:]))
        let statePromise:ValuePromise<ChatListState> = ValuePromise(initialState)
        let stateValue: Atomic<ChatListState> = Atomic(value: initialState)
        
        let updateState:((ChatListState)->ChatListState)->Void = { f in
            statePromise.set(stateValue.modify(f))
        }
        
        
        let postbox = context.account.postbox
        let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
        let previousActivities = Atomic<ChatListPeerInputActivities?>(value: nil)
        self.activityStatusesDisposable = (context.account.allPeerInputActivities()
            |> mapToSignal { activitiesByPeerId -> Signal<[PeerId: [ChatListInputActivity]], NoError> in
                var foundAllPeers = true
                var cachedResult: [PeerId: [ChatListInputActivity]] = [:]
                previousPeerCache.with { dict -> Void in
                    for (chatPeerId, activities) in activitiesByPeerId {
                        var cachedChatResult: [ChatListInputActivity] = []
                        for (peerId, activity) in activities {
                            if let peer = dict[peerId] {
                                cachedChatResult.append(ChatListInputActivity(peer, activity))
                            } else {
                                foundAllPeers = false
                                break
                            }
                            cachedResult[chatPeerId] = cachedChatResult
                        }
                    }
                }
                if foundAllPeers {
                    return .single(cachedResult)
                } else {
                    return postbox.transaction { transaction -> [PeerId: [ChatListInputActivity]] in
                        var result: [PeerId: [ChatListInputActivity]] = [:]
                        var peerCache: [PeerId: Peer] = [:]
                        for (chatPeerId, activities) in activitiesByPeerId {
                            var chatResult: [ChatListInputActivity] = []
                            
                            for (peerId, activity) in activities {
                                if let peer = transaction.getPeer(peerId) {
                                    chatResult.append(ChatListInputActivity(peer, activity))
                                    peerCache[peerId] = peer
                                }
                            }
                            
                            result[chatPeerId] = chatResult
                        }
                        let _ = previousPeerCache.swap(peerCache)
                        return result
                    }
                }
            }
            |> map { activities -> ChatListPeerInputActivities? in
                return previousActivities.modify { current in
                    var updated = false
                    let currentList: [PeerId: [ChatListInputActivity]] = current?.activities ?? [:]
                    if currentList.count != activities.count {
                        updated = true
                    } else {
                        outer: for (peerId, currentValue) in currentList {
                            if let value = activities[peerId] {
                                if currentValue.count != value.count {
                                    updated = true
                                    break outer
                                } else {
                                    for i in 0 ..< currentValue.count {
                                        if currentValue[i] != value[i] {
                                            updated = true
                                            break outer
                                        }
                                    }
                                }
                            } else {
                                updated = true
                                break outer
                            }
                        }
                    }
                    if updated {
                        if activities.isEmpty {
                            return nil
                        } else {
                            return ChatListPeerInputActivities(activities: activities)
                        }
                    } else {
                        return current
                    }
                }
            }
            |> deliverOnMainQueue).start(next: { activities in
                updateState {
                    $0.updateActivities { _ in
                        activities ?? ChatListPeerInputActivities(activities: [:])
                    }
                }
            })
        
        let previousLocation: Atomic<ChatLocation?> = Atomic(value: nil)
        globalPeerDisposable.set(context.globalPeerHandler.get().start(next: { [weak self] location in
            if previousLocation.swap(location) != location {
                self?.removeRevealStateIfNeeded(nil)
            }
            
            self?.removeHighlightEvents()
            
            if let searchController = self?.searchController {
                searchController.updateHighlightEvents(location != nil)
            }
            if location == nil {
                self?.setHighlightEvents()
            }
        }))

        
        let foldersSignal = filter.get() |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs.filter == rhs.filter
        })
        
        let foldersTopBarUpdate = filter.get() |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.tabs != rhs.tabs {
                return false
            }
            if lhs.sidebar != rhs.sidebar {
                return false
            }
            if lhs.filter != rhs.filter {
                return false
            }
            return true
        })
        
        let signal = combineLatest(request.get() |> distinctUntilChanged, foldersSignal)
        
        let previousfilter = Atomic<FilterData?>(value: self.filterValue)
        
        let chatHistoryView: Signal<(ChatListView, ViewUpdateType, Bool, FilterData, Bool), NoError> = signal |> mapToSignal { location, data -> Signal<(ChatListView, ViewUpdateType, Bool, FilterData, Bool), NoError> in
            
            var signal:Signal<(ChatListView,ViewUpdateType), NoError>
            var removeNextAnimation: Bool = false
            switch location {
            case let .Initial(count, st):
                signal = context.account.viewTracker.tailChatListView(groupId: groupId, filterPredicate: chatListFilterPredicate(for: data.filter), count: count)
                scroll = st
            case let .Index(index, st):
                signal = context.account.viewTracker.aroundChatListView(groupId: groupId, filterPredicate: chatListFilterPredicate(for: data.filter), index: index, count: 100)
                scroll = st
                removeNextAnimation = st != nil
            }
            return signal |> map { ($0.0, $0.1, removeNextAnimation, data, previousfilter.swap(data)?.filter?.id != data.filter?.id)}
        }
        
        let setupFilter:(ChatListFilter?)->Void = { [weak self] filter in
            self?.updateFilter {
                $0.withUpdatedFilter(filter)
            }
            self?.scrollup(force: true)
        }
        let openFilterSettings:(ChatListFilter?)->Void = { filter in
            if let filter = filter {
                context.sharedContext.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
            } else {
                context.sharedContext.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
            }
        }
        

        let list:Signal<TableUpdateTransition,NoError> = combineLatest(queue: prepareQueue, chatHistoryView, appearanceSignal, statePromise.get(), context.chatUndoManager.allStatuses(), hiddenItemsState.get(), appNotificationSettings(accountManager: context.sharedContext.accountManager), chatListFilterItems(account: context.account, accountManager: context.sharedContext.accountManager), foldersTopBarUpdate) |> mapToQueue { value, appearance, state, undoStatuses, hiddenItems, inAppSettings, filtersCounter, filterData -> Signal<TableUpdateTransition, NoError> in
                    
            let removeNextAnimation = value.2
            
            let previous = first.swap((value.0.earlierIndex, value.0.laterIndex))
            
            let ignoreFlags = scrollUp.swap(false)
            
            if !ignoreFlags || (!ignoreFlags && (previous.0 != value.0.earlierIndex || previous.1 != value.0.laterIndex) && !removeNextAnimation) {
                scroll = nil
            }
            

            _ = previousChatList.swap(value.0)
            
            var prepare:[(ChatListEntry, UIChatAdditionalItem?)] = []
            for value in  value.0.entries {
                prepare.append((value, nil))
            }
            if value.0.laterIndex == nil, filterData.filter == nil {
                let items = value.0.additionalItemEntries.filter {
                    !hiddenItems.promo.contains($0.info.peerId)
                }
                for (i, current) in items.enumerated() {
                    prepare.append((current.entry, UIChatAdditionalItem(item: current.info, index: i + value.0.groupEntries.count)))
                }
            }
            var mapped: [UIChatListEntry] = prepare.map {
                return .chat($0, state.activities.activities[$0.index.messageIndex.id.peerId] ?? [], $1, filter: filterData.filter)
            }
            
            if filterData.filter != nil, mapped.isEmpty {} else {
                if value.0.laterIndex == nil {
                    for (i, group) in value.0.groupEntries.reversed().enumerated() {
                        mapped.append(.group(i, group.groupId, group.renderedPeers, group.message, group.unreadState, inAppSettings.totalUnreadCountDisplayCategory, animateGroupNextTransition.swap(nil) == group.groupId, hiddenItems.archive))
                    }
                }
            }
            
            
            if mapped.isEmpty {
                let hasHole = !value.0.entries.filter({ value in
                    switch value {
                    case .HoleEntry:
                        return true
                    default:
                        return false
                    }
                }).isEmpty
                if !hasHole {
                    mapped.append(.empty(filterData.filter))
                }
            } else {
                let isLoading = mapped.filter { value in
                    switch value {
                    case let .chat(entry, _, _, _):
                        if case .HoleEntry = entry {
                           return false
                        } else {
                            return true
                        }
                    default:
                        return true
                    }
                }.isEmpty
                if isLoading {
                    mapped.append(.loading(filterData.filter))
                    
                }
            }
            
            
            if !filterData.tabs.isEmpty && !filterData.sidebar {
                mapped.append(.reveal(filterData.tabs, filterData.filter, filtersCounter))
            }
            
            let entries = mapped.sorted().compactMap { entry -> AppearanceWrapperEntry<UIChatListEntry>? in
                switch entry {
                case let .chat(inner, activities, additionItem, filter):
                    switch inner {
                    case .HoleEntry:
                        return nil
                    case let .MessageEntry(values):
                        if undoStatuses.isActive(peerId: inner.index.messageIndex.id.peerId, types: [.deleteChat, .leftChat, .leftChannel, .deleteChannel]) {
                            return nil
                        } else if undoStatuses.isActive(peerId: inner.index.messageIndex.id.peerId, types: [.clearHistory]) {
                            let entry: ChatListEntry = ChatListEntry.MessageEntry(index: values.0, messages: [], readState: values.2, isRemovedFromTotalUnreadCount: values.3, embeddedInterfaceState: values.4, renderedPeer: values.5, presence: values.6, summaryInfo: values.7, hasFailed: values.8, isContact: values.9)
                            return AppearanceWrapperEntry(entry: .chat(entry, activities, additionItem, filter: filter), appearance: appearance)
                        } else if undoStatuses.isActive(peerId: inner.index.messageIndex.id.peerId, types: [.archiveChat]) {
                            if groupId == .root {
                                return nil
                            } else {
                                return AppearanceWrapperEntry(entry: entry, appearance: appearance)
                            }
                        } else {
                            return AppearanceWrapperEntry(entry: entry, appearance: appearance)
                        }
                    }
                case .group:
                    return AppearanceWrapperEntry(entry: entry, appearance: appearance)
                case .reveal:
                    return AppearanceWrapperEntry(entry: entry, appearance: appearance)
                case .empty:
                    return AppearanceWrapperEntry(entry: entry, appearance: appearance)
                case .loading:
                    return AppearanceWrapperEntry(entry: entry, appearance: appearance)
                }
            }
            
            let prev = previousEntries.swap(entries)
            
            
            var animated = animated.swap(true)
            
            if value.4 {
                animated = false
                scroll = .up(true)
            }
            
            return prepareEntries(from: prev, to: entries, adIndex: nil, context: context, initialSize: initialSize.with { $0 }, animated: animated, scrollState: scroll, groupId: groupId, setupFilter: setupFilter, openFilterSettings: openFilterSettings, tabsMenuItems: { filter in
                return filterContextMenuItems(filter, context: context)
            })
        }
        
        
        let appliedTransition = list |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            self?.enqueueTransition(transition)
            return .complete()
        }
        
        disposable.set(appliedTransition.start())
      
        
        request.set(.single(.Initial(max(Int(context.window.frame.height / 70) + 3, 13), nil)))
        
        var pinnedCount: Int = 0
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem, item.isFixedItem else {return false}
            pinnedCount += 1
            return item.isFixedItem
        }
        
        genericView.tableView.resortController = TableResortController(resortRange: NSMakeRange(0, pinnedCount), start: { row in
            
        }, resort: { row in
            
        }, complete: { [weak self] from, to in
            self?.resortPinned(from, to)
        })
        
        
        genericView.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] scroll in
            guard let `self` = self else {
                return
            }
            self.removeRevealStateIfNeeded(nil)
        }))
        
        genericView.tableView.set(stickClass: ChatListRevealItem.self, handler: { _ in
            
        })
        
        
        genericView.tableView.emptyChecker = { items in
            let filter = items.filter { !($0 is ChatListEmptyRowItem) }
            return filter.isEmpty
        }

        genericView.tableView.setScrollHandler({ [weak self] scroll in
            
            let view = previousChatList.modify({$0})
            
            if let strongSelf = self, let view = view {
                var messageIndex:ChatListIndex?
                
                switch scroll.direction {
                case .bottom:
                    messageIndex = view.earlierIndex
                case .top:
                    messageIndex = view.laterIndex
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    _ = animated.swap(false)
                    strongSelf.request.set(.single(.Index(messageIndex, nil)))
                }
            }
            
        })
        
        
        
 
        
        let filterView = chatListFilterPreferences(postbox: context.account.postbox) |> deliverOnMainQueue
        switch mode {
        case .folder:
            self.updateFilter( {
                $0.withUpdatedTabs([]).withUpdatedFilter(nil)
            } )
        case let .filter(filterId):
            filterDisposable.set(filterView.start(next: { [weak self] filters in
                var shouldBack: Bool = false
                self?.updateFilter { current in
                    var current = current
                    if let updated = filters.list.first(where: { $0.id == filterId }) {
                        current = current.withUpdatedFilter(updated)
                    } else {
                        shouldBack = true
                        current = current.withUpdatedFilter(nil)
                    }
                    current = current.withUpdatedTabs([])
                    return current
                }
                if shouldBack {
                    self?.navigationController?.back()
                }
            }))
        default:
            filterDisposable.set(filterView.start(next: { [weak self] filters in
                self?.updateFilter( { current in
                    var current = current
                    if let filter = current.filter {
                        if let updated = filters.list.first(where: { $0.id == filter.id }) {
                            current = current.withUpdatedFilter(updated)
                        } else {
                            current = current.withUpdatedFilter(nil)
                        }
                    }
                    
                    current = current.withUpdatedTabs(filters.list).withUpdatedSidebar(filters.sidebar)
                    return current
                } )
            }))
        }
    }
    
    func collapseOrExpandArchive() {
        updateHiddenStateState { current in
            switch current.archive {
            case .collapsed:
                return HiddenItems(archive: .normal, promo: current.promo)
            default:
                return HiddenItems(archive: .collapsed, promo: current.promo)
            }
        }
    }
    
    func hidePromoItem(_ peerId: PeerId) {
        updateHiddenStateState { current in
            var promo = current.promo
            promo.insert(peerId)
            return HiddenItems(archive: current.archive, promo: promo)
        }
        _ = hideAccountPromoInfoChat(account: self.context.account, peerId: peerId).start()
    }
    
    func toggleHideArchive() {
        updateHiddenStateState { current in
            switch current.archive {
            case .hidden:
                return HiddenItems(archive: .normal, promo: current.promo)
            default:
                return HiddenItems(archive: .hidden(true), promo: current.promo)
            }
        }
    }
    
    
    func setAnimateGroupNextTransition(_ groupId: PeerGroupId) {
        _ = self.animateGroupNextTransition.swap(groupId)
        
    }
    
    func addUndoAction(_ action:ChatUndoAction) {
        let context = self.context
        context.chatUndoManager.add(action: action)
        guard self.context.sharedContext.layout != .minimisize else { return }
        self.undoTooltipControl.add(controller: self)
    }
    
    private func enqueueTransition(_ transition: TableUpdateTransition) {
        self.genericView.tableView.merge(with: transition)
        readyOnce()
        switch self.mode {
        case .folder:
            if self.genericView.tableView.isEmpty {
                self.navigationController?.close()
            }
        default:
            break
        }
        
        var first: ChatListRowItem?
        self.genericView.tableView.enumerateItems { item -> Bool in
            if let item = item as? ChatListRowItem, item.archiveStatus != nil {
                first = item
            }
            
            return first == nil
        }
        
        if let first = first, let archiveStatus = first.archiveStatus {
            self.genericView.tableView.autohide = TableAutohide(item: first, hideUntilOverscroll: archiveStatus.isHidden, hideHandler: { [weak self] hidden in
                self?.updateHiddenStateState { current in
                    return HiddenItems(archive: .hidden(hidden), promo: current.promo)
                }
            })
        } else {
            self.genericView.tableView.autohide = nil
        }
        
        var pinnedRange: NSRange = NSMakeRange(NSNotFound, 0)
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem else {return true}
            switch item.pinnedType {
            case .some, .last:
                if pinnedRange.location == NSNotFound {
                    pinnedRange.location = item.index
                }
                pinnedRange.length += 1
            default:
                break
            }
            return item.isFixedItem || item.groupId != .root
        }
        
        self.searchController?.pinnedItems = self.collectPinnedItems
        self.genericView.tableView.resortController?.resortRange = pinnedRange
        
        
        let needPreload = previousChatList.with  { $0?.laterIndex == nil }
        if needPreload {
            var preloadItems:[ChatHistoryPreloadItem] = []
            self.genericView.tableView.enumerateItems(with: { item -> Bool in
                guard let item = item as? ChatListRowItem, let index = item.chatListIndex else {return true}
                preloadItems.append(.init(index: index, isMuted: item.isMuted, hasUnread: item.hasUnread))
                return preloadItems.count < 30
            })
            context.account.viewTracker.chatListPreloadItems.set(.single(preloadItems) |> delay(0.2, queue: prepareQueue))
        } else {
            context.account.viewTracker.chatListPreloadItems.set(.single([]))
        }
    }
    
    private func resortPinned(_ from: Int, _ to: Int) {
        
        var items:[PinnedItemId] = []

        var offset: Int = 0
        
        let groupId: PeerGroupId = self.mode.groupId

        let location: TogglePeerChatPinnedLocation
        
        if let filter = self.filterValue?.filter {
            location = .filter(filter.id)
        } else {
            location = .group(groupId)
        }
        
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem else {
                offset += 1
                return true
            }
            if item.groupId != .root || item.isAd {
                offset += 1
            }
            if let location = item.chatLocation {
                switch item.pinnedType {
                case .some, .last:
                    items.append(location.pinnedItemId)
                default:
                    break
                }
            }
           
            return item.isFixedItem || item.groupId != .root
        }
        
        
        
         items.move(at: from - offset, to: to - offset)
        
        reorderDisposable.set(context.account.postbox.transaction { transaction -> Void in
            _ = reorderPinnedItemIds(transaction: transaction, location: location, itemIds: items)
        }.start())
    }
    
    override var collectPinnedItems:[PinnedItemId] {
        var items:[PinnedItemId] = []
        
        
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem else {return false}
            if let location = item.chatLocation {
                switch item.pinnedType {
                case .some, .last:
                    items.append(location.pinnedItemId)
                default:
                    break
                }
            }
            return item.isFixedItem || item.groupId != .root
        }
        return items
    }

    private var lastScrolledIndex: ChatListIndex? = nil
    
    
    override func scrollup(force: Bool = false) {
        
        if force {
            self.genericView.tableView.scroll(to: .up(true), ignoreLayerAnimation: true)
            return
        }
        
        if searchController != nil {
            self.genericView.searchView.change(state: .None, true)
            return
        }
        
        let view = self.previousChatList.with { $0 }
        
        if self.genericView.tableView.contentOffset.y == 0, view?.laterIndex == nil {
            switch mode {
            case .folder:
                navigationController?.back()
                return
            case .filter:
                navigationController?.back()
                return
            case .plain:
                break
            }
            
        }
        
        
        let scrollToTop:()->Void = { [weak self] in
            guard let `self` = self else {return}

            let view = self.previousChatList.modify({$0})
            if view?.laterIndex != nil {
                _ = self.first.swap(true)
                self.request.set(.single(.Initial(50, .up(true))))
            } else {
                if self.genericView.tableView.documentOffset.y == 0 {
                    if self.filterValue?.filter != nil {
                        self.updateFilter {
                            $0.withUpdatedFilter(nil)
                        }
                    } else {
                        self.context.sharedContext.bindings.mainController().showFastChatSettings()
                    }
                } else {
                    self.genericView.tableView.scroll(to: .up(true), ignoreLayerAnimation: true)
                }
            }
        }
        scrollToTop()
    
        
    }
    
    var filterMenuItems: Signal<[SPopoverItem], NoError> {
        let context = self.context
       
        let isEnabled = context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
            |> map { view -> Bool in
                let configuration = ChatListFilteringConfiguration(appConfiguration: view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue)
                return configuration.isEnabled
        }
        
        return combineLatest(chatListFilterPreferences(postbox: context.account.postbox), isEnabled)
            |> take(1)
            |> deliverOnMainQueue
            |> map { [weak self] filters, isEnabled -> [SPopoverItem] in
                var items:[SPopoverItem] = []
                if isEnabled {
                    items.append(SPopoverItem(filters.list.isEmpty ? L10n.chatListFilterSetupEmpty : L10n.chatListFilterSetup, {
                        context.sharedContext.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
                    }, filters.list.isEmpty ? theme.icons.chat_filter_add : theme.icons.chat_filter_edit))
                    
                    if self?.filterValue?.filter != nil {
                        items.append(SPopoverItem(L10n.chatListFilterAll, {
                            self?.updateFilter {
                                $0.withUpdatedFilter(nil)
                            }
                        }))
                    }
                    
                    if !filters.list.isEmpty {
                        items.append(SPopoverItem(false))
                    }
                    for filter in filters.list {
                        let badge = GlobalBadgeNode(context.account, sharedContext: context.sharedContext, view: View(), layoutChanged: {
                            
                        }, getColor: { isSelected in
                            return isSelected ? .white : theme.colors.accent
                        }, filter: filter)
                        let additionView: SPopoverAdditionItemView = SPopoverAdditionItemView(context: badge, view: badge.view!, updateIsSelected: { [weak badge] isSelected in
                            badge?.isSelected = isSelected
                        })
                        
                        items.append(SPopoverItem(filter.title, { [weak self] in
                            guard let `self` = self, filter.id != self.filterValue?.filter?.id else {
                                return
                            }
                            self.updateFilter {
                                $0.withUpdatedFilter(filter)
                            }
                            self.scrollup(force: true)
                        }, filter.icon, additionView: additionView))
                    }
                }
                return items
        }
        
    }
    
    
    func globalSearch(_ query: String) {
        let invoke = { [weak self] in
            self?.genericView.searchView.change(state: .Focus, false)
            self?.genericView.searchView.setString(query)
        }
        
        switch context.sharedContext.layout {
        case .single:
            context.sharedContext.bindings.rootNavigation().back()
            Queue.mainQueue().justDispatch(invoke)
        case .minimisize:
            context.sharedContext.bindings.needFullsize()
            Queue.mainQueue().justDispatch(invoke)
        default:
            invoke()
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        let isLocked = (NSApp.delegate as? AppDelegate)?.passlock ?? .single(false)
        
        
        
        self.suggestAutoarchiveDisposable.set(combineLatest(queue: .mainQueue(), isLocked, context.isKeyWindow, getServerProvidedSuggestions(postbox: self.context.account.postbox)).start(next: { [weak self] locked, isKeyWindow, values in
                guard let strongSelf = self, let navigation = strongSelf.navigationController else {
                    return
                }
                if strongSelf.didSuggestAutoarchive {
                    return
                }
                if !values.contains(.autoarchivePopular) {
                    return
                }
                if !isKeyWindow {
                    return
                }
                if navigation.stackCount > 1 {
                    return
                }
                if locked {
                    return
                }
                strongSelf.didSuggestAutoarchive = true
                
                let context = strongSelf.context
            
                _ = dismissServerProvidedSuggestion(account: strongSelf.context.account, suggestion: .autoarchivePopular).start()
                
                confirm(for: context.window, header: L10n.alertHideNewChatsHeader, information: L10n.alertHideNewChatsText, okTitle: L10n.alertHideNewChatsOK, cancelTitle: L10n.alertHideNewChatsCancel, successHandler: { _ in
                    execute(inapp: .settings(link: "tg://settings/privacy", context: context, section: .privacy))
                })
                
            }))
    

        context.window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if event.modifierFlags.contains(.control) {
                if self.genericView.tableView._mouseInside() {
                    let row = self.genericView.tableView.row(at: self.genericView.tableView.clipView.convert(event.locationInWindow, from: nil))
                    if row >= 0 {
                        let view = self.genericView.hitTest(self.genericView.convert(event.locationInWindow, from: nil))
                        if view?.className.contains("Segment") == false {
                            self.genericView.tableView.item(at: row).view?.mouseDown(with: event)
                            return .invoked
                        } else {
                            return .rejected
                        }
                    }
                }
            }
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .high)
        
        
        context.window.add(swipe: { [weak self] direction, _ -> SwipeHandlerResult in
            guard let `self` = self, let window = self.window else {return .failed}
            let swipeState: SwipeState?
            
            var checkFolder: Bool = true
            let row = self.genericView.tableView.row(at: self.genericView.tableView.clipView.convert(window.mouseLocationOutsideOfEventStream, from: nil))
            if row != -1 {
                
                let hitTestView = self.genericView.hitTest(self.genericView.convert(window.mouseLocationOutsideOfEventStream, from: nil))
                if let view = hitTestView, view.isInSuperclassView(ChatListRevealView.self) {
                    return .failed
                }
                let item = self.genericView.tableView.item(at: row) as? ChatListRowItem
                if let item = item {
                    let view = item.view as? ChatListRowView
                    if view?.endRevealState != nil {
                        checkFolder = false
                    }
                    
                    if !item.hasRevealState {
                        return .failed
                    }
                } else {
                    return .failed
                }
                
            }

            
            switch direction {
            case let .left(_state):
                if !self.mode.isPlain && checkFolder {
                    swipeState = nil
                } else {
                    swipeState = _state
                }
                
            case let .right(_state):
                swipeState = _state
            case .none:
                swipeState = nil
            }
            
            
            guard let state = swipeState, self.context.sharedContext.layout != .minimisize else {return .failed}
            
            switch state {
            case .start:
                let row = self.genericView.tableView.row(at: self.genericView.tableView.clipView.convert(window.mouseLocationOutsideOfEventStream, from: nil))
                if row != -1 {
                    let item = self.genericView.tableView.item(at: row) as! ChatListRowItem
                    guard !item.isAd else {return .failed}
                    self.removeRevealStateIfNeeded(item.peerId)
                    (item.view as? RevealTableView)?.initRevealState()
                    return .success(RevealTableItemController(item: item))
                } else {
                    return .failed
                }
               
            case let .swiping(_delta, controller):
                let controller = controller as! RevealTableItemController

                guard let view = controller.item.view as? RevealTableView else {return .nothing}
                
                var delta:CGFloat
                switch direction {
                case .left:
                    delta = _delta//max(0, _delta)
                case .right:
                    delta = -_delta//min(-_delta, 0)
                default:
                    delta = _delta
                }
                
                
                delta -= view.additionalRevealDelta
                
                let newDelta = min(view.width * log2(abs(delta) + 1) * log2(delta < 0 ? view.width * 8 : view.width) / 100.0, abs(delta))

                if delta < 0 {
                    delta = -newDelta
                } else {
                    delta = newDelta
                }

                

                view.moveReveal(delta: delta)
            case let .success(_, controller), let .failed(_, controller):
                let controller = controller as! RevealTableItemController
                guard let view = (controller.item.view as? RevealTableView) else {return .nothing}
                
                var direction = direction
                
                switch direction {
                case let .left(state):
                  
                    if view.containerX < 0 && abs(view.containerX) > view.rightRevealWidth / 2 {
                        direction = .right(state.withAlwaysSuccess())
                    } else if abs(view.containerX) < view.rightRevealWidth / 2 && view.containerX < view.leftRevealWidth / 2 {
                       direction = .left(state.withAlwaysFailed())
                    } else {
                        direction = .left(state.withAlwaysSuccess())
                    }
                case .right:
                    if view.containerX > 0 && view.containerX > view.leftRevealWidth / 2 {
                        direction = .left(state.withAlwaysSuccess())
                    } else if abs(view.containerX) < view.rightRevealWidth / 2 && view.containerX < view.leftRevealWidth / 2 {
                        direction = .right(state.withAlwaysFailed())
                    } else {
                        direction = .right(state.withAlwaysSuccess())
                    }
                default:
                    break
                }
                
                view.completeReveal(direction: direction)
            }
            
          //  return .success()
            
            return .nothing
        }, with: self.genericView.tableView, identifier: "chat-list", priority: .high)
        
      
        
        if context.sharedContext.bindings.rootNavigation().stackCount == 1 {
            setHighlightEvents()
        }
    }
    
    private func setHighlightEvents() {
        
        removeHighlightEvents()
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let item = self?.genericView.tableView.highlightedItem(), item.index > 0 {
                self?.genericView.tableView.highlightPrev(turnDirection: false)
                while self?.genericView.tableView.highlightedItem() is PopularPeersRowItem || self?.genericView.tableView.highlightedItem() is SeparatorRowItem {
                    self?.genericView.tableView.highlightNext(turnDirection: false)
                }
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .low)
        
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.highlightNext(turnDirection: false)
            while self?.genericView.tableView.highlightedItem() is PopularPeersRowItem || self?.genericView.tableView.highlightedItem() is SeparatorRowItem {
                self?.genericView.tableView.highlightNext(turnDirection: false)
            }
            return .invoked
        }, with: self, for: .DownArrow, priority: .low)
        
    }
    
    private func removeHighlightEvents() {
        genericView.tableView.cancelHighlight()
        context.window.remove(object: self, for: .DownArrow, forceCheckFlags: true)
        context.window.remove(object: self, for: .UpArrow, forceCheckFlags: true)
    }
    
    private func removeRevealStateIfNeeded(_ ignoreId: PeerId?) {
        genericView.tableView.enumerateItems { item -> Bool in
            if let item = item as? ChatListRowItem, item.peerId != ignoreId {
                (item.view as? ChatListRowView)?.endRevealState = nil
            }
            return true
        }
    }
    
    private func _openChat(_ index: Int) {
        if !genericView.tableView.isEmpty {
            let archiveItem = genericView.tableView.item(at: 0) as? ChatListRowItem
            var index: Int = index
            if let item = archiveItem, item.isAutohidden || item.archiveStatus == .collapsed {
                index += 1
            }
            if archiveItem == nil {
                index += 1
                if genericView.tableView.count > 1 {
                    let archiveItem = genericView.tableView.item(at: 1) as? ChatListRowItem
                    if let item = archiveItem, item.isAutohidden || item.archiveStatus == .collapsed {
                        index += 1
                    }
                }
            }
            
            if genericView.tableView.count > index {
                _ = genericView.tableView.select(item: genericView.tableView.item(at: index), notify: true, byClick: true)
            }
        }
    }
    
    func openChat(_ index: Int, force: Bool = false) {
        if case .folder = self.mode {
            _openChat(index)
        } else if force  {
            _openChat(index)
        } else {
            let prefs = chatListFilterPreferences(postbox: context.account.postbox) |> deliverOnMainQueue |> take(1)
            
            _ = prefs.start(next: { [weak self] filters in
                if filters.list.isEmpty {
                    self?._openChat(index)
                } else if index == 0 {
                    self?.updateFilter {
                        $0.withUpdatedFilter(nil)
                    }
                    self?.scrollup(force: true)
                } else if filters.list.count >= index {
                    self?.updateFilter {
                        $0.withUpdatedFilter(filters.list[index - 1])
                    }
                    self?.scrollup(force: true)
                } else {
                    self?._openChat(index)
                }
            })
        }
    }
    
    override var removeAfterDisapper: Bool {
        switch self.mode {
        case .plain:
            return false
        default:
            return true
        }
    }
    

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        context.window.removeAllHandlers(for: self)
        context.window.removeAllHandlers(for: genericView.tableView)
        
        removeRevealStateIfNeeded(nil)
        
        suggestAutoarchiveDisposable.set(nil)
    }
    
//    override func getLeftBarViewOnce() -> BarView {
//        return MajorBackNavigationBar(self, context: context, excludePeerId: context.peerId)
//    }
    
    
    deinit {
        removePeerIdGroupDisposable.dispose()
        disposable.dispose()
        scrollDisposable.dispose()
        reorderDisposable.dispose()
        globalPeerDisposable.dispose()
        archivationTooltipDisposable.dispose()
        activityStatusesDisposable?.dispose()
        filterDisposable.dispose()
        suggestAutoarchiveDisposable.dispose()
    }
    
    
    override var enableBack: Bool {
        switch mode {
        case .folder, .filter:
            return true
        default:
            return false
        }
    }
    
    override var defaultBarTitle: String {
        switch mode {
        case .plain:
            return super.defaultBarTitle
        case .folder:
            return L10n.chatListArchivedChats
        case .filter:
            return _filterValue.with { $0.filter?.title ?? "Filter" }
        }
    }

    override func escapeKeyAction() -> KeyHandlerResult {
        if !mode.isPlain, let navigation = navigationController {
            navigation.back()
            return .invoked
        }
        if self.filterValue?.filter != nil {
            updateFilter {
                $0.withUpdatedFilter(nil)
            }
            return .invoked
        }
        return super.escapeKeyAction()
    }
    
    
    init(_ context: AccountContext, modal:Bool = false, groupId: PeerGroupId? = nil, filterId: Int32? = nil) {
        self.undoTooltipControl = UndoTooltipControl(context: context)
        
        let mode: PeerListMode
        if let filterId = filterId {
            mode = .filter(filterId)
        } else if let groupId = groupId {
            mode = .folder(groupId)
        } else {
            mode = .plain
        }
        
        super.init(context, followGlobal: !modal, mode: mode)
        
        if groupId != nil {
            context.closeFolderFirst = true
        }
    }

    override func selectionWillChange(row:Int, item:TableRowItem, byClick: Bool) -> Bool {
        if let item = item as? ChatListRowItem, let peer = item.peer, let modalAction = context.sharedContext.bindings.rootNavigation().modalAction {
            if !modalAction.isInvokable(for: peer) {
                modalAction.alertError(for: peer, with:mainWindow)
                return false
            }
            modalAction.afterInvoke()
            
            if let modalAction = modalAction as? FWDNavigationAction {
                if item.peerId == context.peerId {
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId).start()
                    _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                    navigationController?.removeModalAction()
                    return false
                }
            }
            
        }
        if let item = item as? ChatListRowItem {
            if item.groupId != .root {
                if byClick {
                    item.view?.focusAnimation(nil)
                    open(with: item.entryId, initialAction: nil, addition: false)
                }
                return false
            }
        }
        if item is ChatListRevealItem {
            return false
        }
        return true
    }
    
    override  func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        let navigation = context.sharedContext.bindings.rootNavigation()
        if let item = item as? ChatListRowItem {
            if !isNew, let controller = navigation.controller as? ChatController {
                switch controller.mode {
                case .history, .replyThread:
                    if let modalAction = navigation.modalAction {
                        navigation.controller.invokeNavigation(action: modalAction)
                    }
                    controller.clearReplyStack()
                    controller.scrollup(force: true)
                case .scheduled:
                    navigation.back()
                }
                
            } else {
                
                let context = self.context
                
                _ = (context.globalPeerHandler.get() |> take(1)).start(next: { location in
                    context.globalPeerHandler.set(.single(location))
                })
                
                let initialAction: ChatInitialAction?
                
                switch item.pinnedType {
                case let .ad(info):
                    if let info = info as? PromoChatListItem {
                        initialAction = .ad(info.kind)
                    } else {
                        initialAction = nil
                    }
                default:
                    initialAction = nil
                }
                
                open(with: item.entryId, initialAction: initialAction, addition: false)
            }
        }
    }
  
}

