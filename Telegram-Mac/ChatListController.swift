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

enum UIChatListEntry : Identifiable, Comparable {
    case chat(ChatListEntry, [ChatListInputActivity], isSponsored: Bool, filterId: Int32?)
    case group(Int, PeerGroupId, [ChatListGroupReferencePeer], Message?, PeerGroupUnreadCountersCombinedSummary, TotalUnreadCountDisplayCategory, Bool, HiddenArchiveStatus)
    case reveal([ChatListFilter], ChatListFilter?, [Int32: Int32])
    case empty(ChatListFilter?)
    static func == (lhs: UIChatListEntry, rhs: UIChatListEntry) -> Bool {
        switch lhs {
        case let .chat(entry, activity, isSponsored, filterId):
            if case .chat(entry, activity, isSponsored, filterId) = rhs {
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
        }
    }
    
    var index: ChatListIndex {
        switch self {
        case let .chat(entry, _, isSponsored, _):
            switch entry {
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            case let .MessageEntry(values):
                if isSponsored {
                    return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound().predecessor().predecessor())
                } else {
                    return values.0
                }
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
        }
    }
    
    static func < (lhs: UIChatListEntry, rhs: UIChatListEntry) -> Bool {
       return lhs.index < rhs.index
    }
    
    var stableId: UIChatListEntryId {
        switch self {
        case let .chat(entry, _, _, filterId):
            return .chatId(entry.index.messageIndex.id.peerId, filterId)
        case let .group(_, groupId, _, _, _, _, _, _):
            return .groupId(groupId)
        case .reveal:
            return .reveal
        case .empty:
            return .empty
        }
    }
    
}



fileprivate func prepareEntries(from:[AppearanceWrapperEntry<UIChatListEntry>]?, to:[AppearanceWrapperEntry<UIChatListEntry>], adIndex: UInt16?, context: AccountContext, initialSize:NSSize, animated:Bool, scrollState:TableScrollState? = nil, groupId: PeerGroupId, setupFilter: @escaping(ChatListFilter?)->Void, openFilterSettings: @escaping(ChatListFilter?)->Void, tabsMenuItems: @escaping(ChatListFilter?)->[ContextMenuItem]) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
        
        var cancelled: Bool = false
        
        func makeItem(_ entry: AppearanceWrapperEntry<UIChatListEntry>) -> TableRowItem {
            switch entry.entry {
            case let .chat(inner, activities, isSponsored, _):
                switch inner {
                case let .HoleEntry(hole):
                    return ChatListHoleRowItem(initialSize, context, hole)
                case let .MessageEntry(index, message, readState, notifySettings,embeddedState, renderedPeer, peerPresence, summaryInfo, hasFailed):
                    var pinnedType: ChatListPinnedType = .some
                    if isSponsored {
                        pinnedType = .ad
                    } else if index.pinningIndex == nil {
                        pinnedType = .none
                    }
                    return ChatListRowItem(initialSize, context: context, message: message, index: inner.index, readState:readState, notificationSettings: notifySettings, embeddedState: embeddedState, pinnedType: pinnedType, renderedPeer: renderedPeer, peerPresence: peerPresence, summaryInfo: summaryInfo, activities: activities, associatedGroupId: groupId, hasFailed: hasFailed)
                }
            case let .group(_, groupId, peers, message, unreadState, unreadCountDisplayCategory, animated, archiveStatus):
                return ChatListRowItem(initialSize, context: context, pinnedType: .none, groupId: groupId, peers: peers, message: message, unreadState: unreadState, unreadCountDisplayCategory: unreadCountDisplayCategory, animateGroup: animated, archiveStatus: archiveStatus)
            case let .reveal(tabs, selected, counters):
                return ChatListRevealItem(initialSize, context: context, tabs: tabs, selected: selected, counters: counters, action: setupFilter, openSettings: {
                    openFilterSettings(nil)
                }, menuItems: tabsMenuItems)
            case let .empty(filter):
                return ChatListEmptyRowItem(initialSize, stableId: entry.stableId, filter: filter, context: context, openFilterSettings: openFilterSettings)
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

private struct FilterData : Equatable {
    let filter: ChatListFilter?
    let tabs: [ChatListFilter]
    init(filter: ChatListFilter?, tabs: [ChatListFilter]) {
        self.filter = filter
        self.tabs = tabs
    }
    func withUpdatedFilter(_ filter: ChatListFilter?) -> FilterData {
        return FilterData(filter: filter, tabs: self.tabs)
    }
    func withUpdatedTabs(_ tabs:  [ChatListFilter]) -> FilterData {
        return FilterData(filter: self.filter, tabs: tabs)
    }
}

class ChatListController : PeersListController {
    
    private let filter = ValuePromise<FilterData>(ignoreRepeated: true)
    private let _filterValue = Atomic<FilterData>(value: FilterData(filter: nil, tabs: []))
    private var filterValue: FilterData? {
        return _filterValue.with { $0 }
    }
    private func updateFilter(_ f:(FilterData)->FilterData) {
        filter.set(_filterValue.modify(f))
        _  = first.swap(true)
        setCenterTitle(self.defaultBarTitle)
    }
    
    private let request = Promise<ChatListIndexRequest>()
    private let previousChatList:Atomic<ChatListView?> = Atomic(value: nil)
    private let first = Atomic(value:true)
    private let removePeerIdGroupDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    private let scrollDisposable = MetaDisposable()
    private let reorderDisposable = MetaDisposable()
    private let globalPeerDisposable = MetaDisposable()
    private let archivationTooltipDisposable = MetaDisposable()
    private let undoTooltipControl: UndoTooltipControl
    private let animateGroupNextTransition:Atomic<PeerGroupId?> = Atomic(value: nil)
    private var activityStatusesDisposable:Disposable?
    private let hiddenArchiveValue: Atomic<HiddenArchiveStatus> = Atomic(value: FastSettings.archiveStatus)
    private let hiddenArchiveState: ValuePromise<HiddenArchiveStatus> = ValuePromise(FastSettings.archiveStatus, ignoreRepeated: true)
    
    private let filterDisposable = MetaDisposable()
    
    private func updateHiddenStateState(_ f:(HiddenArchiveStatus)->HiddenArchiveStatus) {
        let result = hiddenArchiveValue.modify(f)
        FastSettings.archiveStatus = result
        hiddenArchiveState.set(result)
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
        let animated: Atomic<Bool> = Atomic(value: false)
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

        
        let signal = combineLatest(request.get() |> distinctUntilChanged, filter.get())
        
        let chatHistoryView: Signal<(ChatListView, ViewUpdateType, Bool, FilterData), NoError> = signal |> mapToSignal { location, data -> Signal<(ChatListView, ViewUpdateType, Bool, FilterData), NoError> in
            
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
            return signal |> map { ($0.0, $0.1, removeNextAnimation, data)}
        }
        
        let setupFilter:(ChatListFilter?)->Void = { [weak self] filter in
            self?.updateFilter {
                $0.withUpdatedFilter(filter)
            }
            self?.scrollup()
        }
        let openFilterSettings:(ChatListFilter?)->Void = { filter in
            if let filter = filter {
                context.sharedContext.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
            } else {
                context.sharedContext.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
            }
        }
        
        

        let list:Signal<TableUpdateTransition,NoError> = combineLatest(queue: prepareQueue, chatHistoryView, appearanceSignal, statePromise.get(), context.chatUndoManager.allStatuses(), hiddenArchiveState.get(), appNotificationSettings(accountManager: context.sharedContext.accountManager), filtersBadgeCounters(context: context)) |> mapToQueue { value, appearance, state, undoStatuses, archiveIsHidden, inAppSettings, filtersCounter -> Signal<TableUpdateTransition, NoError> in
                    
            var removeNextAnimation = value.2
            
            let previous = first.swap((value.0.earlierIndex, value.0.laterIndex))
            
            let ignoreFlags = scrollUp.swap(false)
            
            if !ignoreFlags || (!ignoreFlags && (previous.0 != value.0.earlierIndex || previous.1 != value.0.laterIndex) && !removeNextAnimation) {
                scroll = nil
            }
            
            if removeNextAnimation {
                removeNextAnimation = false
            }
            
            _ = previousChatList.swap(value.0)
            
                    
            var prepare:[(ChatListEntry, Bool)] = []
            for value in  value.0.entries {
                prepare.append((value, false))
            }
            if value.0.laterIndex == nil, value.3.filter == nil {
                if let value = value.0.additionalItemEntries.first {
                    prepare.append((value, true))
                }
            }
            var mapped: [UIChatListEntry] = prepare.map {
                return .chat($0, state.activities.activities[$0.index.messageIndex.id.peerId] ?? [], isSponsored: $1, filterId: value.3.filter?.id)
            }
            
            if value.3.filter != nil, mapped.isEmpty {} else {
                if value.0.laterIndex == nil {
                    for (i, group) in value.0.groupEntries.reversed().enumerated() {
                        mapped.append(.group(i, group.groupId, group.renderedPeers, group.message, group.unreadState, inAppSettings.totalUnreadCountDisplayCategory, animateGroupNextTransition.swap(nil) == group.groupId, archiveIsHidden))
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
                    mapped.append(.empty(value.3.filter))
                }
            }
            
            if !value.3.tabs.isEmpty {
                let dict:[Int32: Int32] = filtersCounter.reduce([:], { current, value in
                    var current = current
                    current[value.id] = value.count
                    return current
                })
                mapped.append(.reveal(value.3.tabs, value.3.filter, dict))
            }
            
            let entries = mapped.sorted().compactMap { entry -> AppearanceWrapperEntry<UIChatListEntry>? in
                switch entry {
                case let .chat(inner, activities, isSponsored, filterId):
                    switch inner {
                    case .HoleEntry:
                        return nil
                    case let .MessageEntry(values):
                        if undoStatuses.isActive(peerId: inner.index.messageIndex.id.peerId, types: [.deleteChat, .leftChat, .leftChannel, .deleteChannel]) {
                            return nil
                        } else if undoStatuses.isActive(peerId: inner.index.messageIndex.id.peerId, types: [.clearHistory]) {
                            let entry: ChatListEntry = ChatListEntry.MessageEntry(values.0, nil, values.2, values.3, values.4, values.5, values.6, values.7, values.8)
                            return AppearanceWrapperEntry(entry: .chat(entry, activities, isSponsored: isSponsored, filterId: filterId), appearance: appearance)
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
                }
            }
            
            let prev = previousEntries.swap(entries)
            
            var animated = animated.swap(true)
//            if value.3 != previousfilter.data.swap(value.3) {
//                animated = false
//            }
            return prepareEntries(from: prev, to: entries, adIndex: nil, context: context, initialSize: initialSize.with { $0 }, animated: animated, scrollState: scroll, groupId: groupId, setupFilter: setupFilter, openFilterSettings: openFilterSettings, tabsMenuItems: { filter in
                
                var items:[ContextMenuItem] = []
                if var filter = filter {
                    items.append(.init(L10n.chatListFilterEdit, handler: {
                        context.sharedContext.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
                    }))
                    items.append(.init(L10n.chatListFilterAddChats, handler: {
                        showModal(with: ShareModalController(SelectCallbackObject(context, excludePeerIds: Set(filter.data.includePeers), callback: { peerIds in
                            return combineLatest(updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { state in
                                var state = state
                                filter.data.includePeers = filter.data.includePeers + peerIds
                                state.withAddedFilter(filter, onlyReplace: true)
                                return state
                            }), replaceRemoteChatListFilters(account: context.account)) |> ignoreValues
                            
                        })), for: context.window)
                    }))
                    items.append(.init(L10n.chatListFilterDelete, handler: {
                        confirm(for: context.window, header: L10n.chatListFilterConfirmRemoveHeader, information: L10n.chatListFilterConfirmRemoveText, okTitle: L10n.chatListFilterConfirmRemoveOK, successHandler: { _ in
                            _ = combineLatest(updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { state in
                                var state = state
                                state.withRemovedFilter(filter)
                                return state
                            }), replaceRemoteChatListFilters(account: context.account)).start()
                        })
                        
                    }))
                } else {
                    items.append(.init(L10n.chatListFilterEditFilters, handler: {
                        context.sharedContext.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
                    }))
                }
                
                return items
            })
        }
        
        
        let appliedTransition = list |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            self?.enqueueTransition(transition)
            return .complete()
        }
        
        disposable.set(appliedTransition.start())
      
        
        request.set(.single(.Initial(max(Int(frame.height / 70) + 5, 10), nil)))
        
        var pinnedCount: Int = 0
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem, item.pinnedType != .none else {return false}
            pinnedCount += 1
            return item.pinnedType != .none
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
            #if !STABLE && !APP_STORE
            context.sharedContext.bindings.mainController().isUpChatList = self.genericView.tableView.documentOffset.y <= 0 && self.previousChatList.with { $0?.laterIndex == nil} && self.mode.groupId == .root
            #endif
//            if scroll.visibleRows.location == 0 && view.laterIndex != nil {
//                self.lastScrolledIndex = nil
//            }
//            self.account.context.mainViewController.isUpChatList = scroll.visibleRows.location > 0 || view.laterIndex != nil
//            #else
            //#endif
            self.removeRevealStateIfNeeded(nil)
        }))
        
        genericView.tableView.set(stickClass: ChatListRevealItem.self, handler: { _ in
            
        })
        

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
            filterDisposable.set(filterView.start(next: { [weak self] settings in
                var shouldBack: Bool = false
                self?.updateFilter { current in
                    var current = current
                    if let updated = settings.filters.first(where: { $0.id == filterId }) {
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
            filterDisposable.set(filterView.start(next: { [weak self] settings in
                self?.updateFilter( { current in
                    var current = current
                    if let filter = current.filter {
                        if let updated = settings.filters.first(where: { $0.id == filter.id }) {
                            current = current.withUpdatedFilter(updated)
                        } else {
                            current = current.withUpdatedFilter(nil)
                        }
                    }
                    
                    current = current.withUpdatedTabs(settings.filters)
                    return current
                } )
            }))
        }
    }
    
    func collapseOrExpandArchive() {
        updateHiddenStateState { current in
            switch current {
            case .collapsed:
                return .normal
            default:
                return .collapsed
            }
        }
    }
    
    func toggleHideArchive() {
        updateHiddenStateState { current in
            switch current {
            case .hidden:
                return .normal
            default:
                return .hidden(true)
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
                self?.updateHiddenStateState { _ in
                    return .hidden(hidden)
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
            return item.pinnedType != .none || item.groupId != .root
        }
        self.searchController?.pinnedItems = self.collectPinnedItems
        self.genericView.tableView.resortController?.resortRange = pinnedRange
    }
    
    private func resortPinned(_ from: Int, _ to: Int) {
        
        var items:[PinnedItemId] = []

        var offset: Int = 0
        
        let groupId: PeerGroupId = self.mode.groupId

        
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem else {
                offset += 1
                return true
            }
            if item.groupId != .root || item.pinnedType == .ad {
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
           
            return item.pinnedType != .none || item.groupId != .root
        }
        
        
        
         items.move(at: from - offset, to: to - offset)
        
        reorderDisposable.set(context.account.postbox.transaction { transaction -> Void in
            _ = reorderPinnedItemIds(transaction: transaction, groupId: groupId, itemIds: items)
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
            return item.pinnedType != .none || item.groupId != .root
        }
        return items
    }

    private var lastScrolledIndex: ChatListIndex? = nil
    
    
    override func scrollup() {
        
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
                    self.context.sharedContext.bindings.mainController().showFastChatSettings()
                } else {
                    self.genericView.tableView.scroll(to: .up(true), ignoreLayerAnimation: true)
                }
            }
        }
        
//        #if !STABLE && !APP_STORE
//        let view = self.previousChatList.modify({$0})
//
//
//        if lastScrolledIndex == nil, view?.laterIndex != nil || genericView.tableView.scrollPosition().current.visibleRows.location > 0  {
//            scrollToTop()
//            return
//        }
//        let postbox = account.postbox
//
//        let signal:Signal<ChatListIndex?, NoError> = account.context.badgefilter.data.get() |> mapToSignal { filter -> Signal<ChatListIndex?, NoError> in
//            return postbox.transaction { transaction -> ChatListIndex? in
//                return transaction.getEarliestUnreadChatListIndex(filtered: filter == .filtered, earlierThan: lastScrolledIndex)
//            }
//            } |> deliverOnMainQueue
//
//        scrollDisposable.set(signal.start(next: { [weak self] index in
//            guard let `self` = self else {return}
//            if let index = index {
//                self.lastScrolledIndex = index
//                self.request.set(.single(ChatListIndexRequest.Index(index, TableScrollState.center(id: ChatLocation.peer(index.messageIndex.id.peerId), innerId: nil, animated: true, focus: .init(focus: true), inset: 0))))
//            } else {
//                self.lastScrolledIndex = nil
//                scrollToTop()
//            }
//        }))
//
//        #else
            scrollToTop()
       // #endif
        
        
    }
    
    var filterMenuItems: Signal<[SPopoverItem], NoError> {
        let context = self.context
       
        return chatListFilterPreferences(postbox: context.account.postbox)
            |> take(1)
            |> deliverOnMainQueue
            |> map { [weak self] settings -> [SPopoverItem] in
                var items:[SPopoverItem] = []
                items.append(SPopoverItem(L10n.chatListFilterSetup, {
                    context.sharedContext.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
                }, theme.icons.chat_filter_add))
                
                if self?.filterValue?.filter != nil {
                    items.append(SPopoverItem(L10n.chatListFilterAll, {
                        self?.updateFilter {
                            $0.withUpdatedFilter(nil)
                        }
                    }))
                }
                
                if !settings.filters.isEmpty {
                    items.append(SPopoverItem(false))
                }
                for filter in settings.filters {
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
                        self.scrollup()
                    }, filter.icon, additionView: additionView))
                    
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
        context.window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if event.modifierFlags.contains(.control) {
                if self.genericView.tableView._mouseInside() {
                    let row = self.genericView.tableView.row(at: self.genericView.tableView.clipView.convert(event.locationInWindow, from: nil))
                    if row >= 0 {
                        self.genericView.tableView.item(at: row).view?.mouseDown(with: event)
                        return .invoked
                    }
                }
            }
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .high)
        
        
        context.window.add(swipe: { [weak self] direction -> SwipeHandlerResult in
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
                    guard item.pinnedType != .ad else {return .failed}
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
        
        if force {
            _openChat(index)
        } else {
            let prefs = chatListFilterPreferences(postbox: context.account.postbox) |> deliverOnMainQueue |> take(1)
            
            _ = prefs.start(next: { [weak self] settings in
                if index == 0 {
                    self?.updateFilter {
                        $0.withUpdatedFilter(nil)
                    }
                    self?.scrollup()
                } else if settings.filters.count >= index {
                    self?.updateFilter {
                        $0.withUpdatedFilter(settings.filters[index - 1])
                    }
                    self?.scrollup()
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
    
    override func backSettings() -> (String, CGImage?) {
        switch self.mode {
        case .plain:
            return super.backSettings()
        case .folder:
            return (L10n.chatListArchiveBack, super.backSettings().1)
        case .filter:
             return (L10n.chatListFilterBack, super.backSettings().1)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        context.window.removeAllHandlers(for: self)
        context.window.removeAllHandlers(for: genericView.tableView)
        
        removeRevealStateIfNeeded(nil)
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
                case .history:
                    if let modalAction = navigation.modalAction {
                        navigation.controller.invokeNavigation(action: modalAction)
                    }
                    controller.clearReplyStack()
                    controller.scrollup()
                case .scheduled:
                    navigation.back()
                }
                
            } else {
                
                let context = self.context
                
                _ = (context.globalPeerHandler.get() |> take(1)).start(next: { location in
                    context.globalPeerHandler.set(.single(location))
                })
                
                open(with: item.entryId, initialAction: item.pinnedType == .ad && FastSettings.showAdAlert ? .ad : nil, addition: false)
            }
        }
    }
  
}

