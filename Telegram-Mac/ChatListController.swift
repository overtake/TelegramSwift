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
import InAppSettings
import FetchManager

private final class Arguments {
    let context: AccountContext
    let setupFilter: (ChatListFilter)->Void
    let openFilterSettings: (ChatListFilter)->Void
    let tabsMenuItems: (ChatListFilter)->[ContextMenuItem]
    let createTopic: ()->Void
    let switchOffForum: ()->Void
    init(context: AccountContext, setupFilter: @escaping(ChatListFilter)->Void, openFilterSettings: @escaping(ChatListFilter)->Void, tabsMenuItems: @escaping(ChatListFilter)->[ContextMenuItem], createTopic: @escaping()->Void, switchOffForum: @escaping()->Void) {
        self.context = context
        self.setupFilter = setupFilter
        self.openFilterSettings = openFilterSettings
        self.tabsMenuItems = tabsMenuItems
        self.createTopic = createTopic
        self.switchOffForum = switchOffForum
    }
}

enum UIChatListEntryId : Hashable {
    case chatId(EngineChatList.Item.Id, PeerId, Int32)
    case groupId(EngineChatList.Group)
    case forum(PeerId)
    case reveal
    case empty
    case loading
}


struct UIChatAdditionalItem : Equatable {
    static func == (lhs: UIChatAdditionalItem, rhs: UIChatAdditionalItem) -> Bool {
        return lhs.item == rhs.item && lhs.index == rhs.index
    }
    
    let item: EngineChatList.AdditionalItem
    let index: Int
}


enum UIChatListEntry : Identifiable, Comparable {
    case chat(EngineChatList.Item, [PeerListState.InputActivities.Activity], UIChatAdditionalItem?, filter: ChatListFilter)
    case group(Int, EngineChatList.GroupItem, Bool, HiddenArchiveStatus)
    case reveal([ChatListFilter], ChatListFilter, ChatListFilterBadges)
    case empty(ChatListFilter, PeerListMode, SplitViewState, PeerEquatable?)
    case loading(ChatListFilter)
    static func == (lhs: UIChatListEntry, rhs: UIChatListEntry) -> Bool {
        switch lhs {
        case let .chat(entry, activity, additionItem, filter):
            if case .chat(entry, activity, additionItem, filter) = rhs {
               return true
            } else {
                return false
            }
        case let .group(index, item, animated, isHidden):
            if case .group(index, item, animated, isHidden) = rhs {
                return true
            } else {
                return false
            }
        case let .reveal(filters, current, counters):
            if case .reveal(filters, current, counters) = rhs {
                return true
            } else {
                return false
            }
        case let .empty(filter, mode, state, peer):
            if case .empty(filter, mode, state, peer) = rhs {
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
                var current = MessageIndex.absoluteUpperBound().globalPredecessor()
                for _ in 0 ..< additionItem.index {
                    current = current.globalPredecessor()
                }
                return ChatListIndex(pinningIndex: 0, messageIndex: current)
            }
            switch entry.index {
            case let .chatList(index):
                return index
            case let .forum(pinnedIndex, timestamp, _, namespace, id):
                let index: UInt16?
                switch pinnedIndex {
                case .none:
                    index = nil
                case let .index(value):
                    index = UInt16(value)
                }
                return ChatListIndex(pinningIndex: index, messageIndex: .init(id: MessageId(peerId: entry.renderedPeer.peerId, namespace: namespace, id: id), timestamp: timestamp))
            }
        case .reveal:
            return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound())
        case let .group(id, _, _, _):
            var index = MessageIndex.absoluteUpperBound().globalPredecessor()
            for _ in 0 ..< id {
                index = index.peerLocalPredecessor()
            }
            return ChatListIndex(pinningIndex: 0, messageIndex: index)
        case .empty:
            return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound().globalPredecessor())
        case .loading:
            return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound().globalPredecessor())
        }
    }
    
    static func < (lhs: UIChatListEntry, rhs: UIChatListEntry) -> Bool {
       return lhs.index < rhs.index
    }
    
    var stableId: UIChatListEntryId {
        switch self {
        case let .chat(entry, _, _, filterId):
            if entry.renderedPeer.peer?._asPeer().isForum == true, entry.threadData == nil {
                return .forum(entry.renderedPeer.peerId)
            } else {
                return .chatId(entry.id, entry.renderedPeer.peerId, filterId.id)
            }
        case let .group(_, group, _, _):
            return .groupId(group.id)
        case .reveal:
            return .reveal
        case .empty:
            return .empty
        case .loading:
            return .loading
        }
    }
    
}



fileprivate func prepareEntries(from:[AppearanceWrapperEntry<UIChatListEntry>]?, to:[AppearanceWrapperEntry<UIChatListEntry>], adIndex: UInt16?, arguments: Arguments, initialSize:NSSize, animated:Bool, scrollState:TableScrollState? = nil, groupId: EngineChatList.Group) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
                
        func makeItem(_ entry: AppearanceWrapperEntry<UIChatListEntry>) -> TableRowItem {
            switch entry.entry {
            case let .chat(item, activities, addition, filter):
                var pinnedType: ChatListPinnedType = .some
                if let addition = addition {
                    pinnedType = .ad(addition.item)
                } else if entry.entry.index.pinningIndex == nil {
                    pinnedType = .none
                }
                let messages = item.messages.map {
                    $0._asMessage()
                }
                let mode: ChatListRowItem.Mode
                if let data = item.threadData, case let .forum(id) = item.id {
                    mode = .topic(id, data)
                } else {
                    mode = .chat
                }
                return ChatListRowItem(initialSize, context: arguments.context, stableId: entry.entry.stableId, mode: mode, messages: messages, index: entry.entry.index, readState: item.readCounters, draft: item.draft, pinnedType: pinnedType, renderedPeer: item.renderedPeer, peerPresence: item.presence, forumTopicData: item.forumTopicData, activities: activities, associatedGroupId: groupId, isMuted: item.isMuted, hasFailed: item.hasFailed, hasUnreadMentions: item.hasUnseenMentions, hasUnreadReactions: item.hasUnseenReactions, filter: filter)

            case let .group(_, item, animated, archiveStatus):
                var messages:[Message] = []
                if let message = item.topMessage {
                    messages.append(message._asMessage())
                }
                return ChatListRowItem(initialSize, context: arguments.context, stableId: entry.entry.stableId, pinnedType: .none, groupId: item.id, groupItems: item.items, messages: messages, unreadCount: item.unreadCount, animateGroup: animated, archiveStatus: archiveStatus)
            case let .reveal(tabs, selected, counters):
                return ChatListRevealItem(initialSize, context: arguments.context, tabs: tabs, selected: selected, counters: counters, action: arguments.setupFilter, openSettings: {
                    arguments.openFilterSettings(.allChats)
                }, menuItems: arguments.tabsMenuItems)
            case let .empty(filter, mode, state, peer):
                return ChatListEmptyRowItem(initialSize, stableId: entry.stableId, filter: filter, mode: mode, peer: peer?.peer, layoutState: state, context: arguments.context, openFilterSettings: arguments.openFilterSettings, createTopic: arguments.createTopic, switchOffForum: arguments.switchOffForum)
            case let .loading(filter):
                return ChatListLoadingRowItem(initialSize, stableId: entry.stableId, filter: filter, context: arguments.context)
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
    let filter: ChatListFilter
    let tabs: [ChatListFilter]
    let sidebar: Bool
    let request: ChatListIndexRequest
    init(filter: ChatListFilter, tabs: [ChatListFilter], sidebar: Bool, request: ChatListIndexRequest) {
        self.filter = filter
        self.tabs = tabs
        self.sidebar = sidebar
        self.request = request
    }
    
    var isEmpty: Bool {
        return self.tabs.isEmpty || (self.tabs.count == 1 && self.tabs[0] == .allChats)
    }
    
    var isFirst: Bool {
        return self.tabs.firstIndex(of: filter) == 0
    }
    
    func withUpdatedFilter(_ filter: ChatListFilter?) -> FilterData {
        let filter = filter ?? self.tabs.first ?? .allChats
        return FilterData(filter: filter, tabs: self.tabs, sidebar: self.sidebar, request: self.request)
    }
    func withUpdatedTabs(_ tabs:  [ChatListFilter]) -> FilterData {
        return FilterData(filter: self.filter, tabs: tabs, sidebar: self.sidebar, request: self.request)
    }
    func withUpdatedSidebar(_ sidebar: Bool) -> FilterData {
        return FilterData(filter: self.filter, tabs: self.tabs, sidebar: sidebar, request: self.request)
    }
    func withUpdatedRequest(_ request: ChatListIndexRequest) -> FilterData {
        return FilterData(filter: self.filter, tabs: self.tabs, sidebar: sidebar, request: request)
    }
}

private struct HiddenItems : Equatable {
    let archive: HiddenArchiveStatus
    let promo: Set<PeerId>
}

class ChatListController : PeersListController {
    
    private let filter = ValuePromise<FilterData>(ignoreRepeated: true)
    private let _filterValue = Atomic<FilterData>(value: FilterData(filter: .allChats, tabs: [], sidebar: false, request: .Initial(50, nil)))
    private var filterValue: FilterData? {
        return _filterValue.with { $0 }
    }
    
    var filterSignal : Signal<FilterData, NoError> {
        return self.filter.get()
    }
    
    func updateFilter(_ f:(FilterData)->FilterData) {
        
        let data = f(_filterValue.with { $0 })
        
        if !context.isPremium {
            if let index = data.tabs.firstIndex(of: data.filter) {
                if index > context.premiumLimits.dialog_filters_limit_default {
                    showPremiumLimit(context: context, type: .folders)
                    return
                }
            }
        }
        
        var changedFolder = false
        filter.set(_filterValue.modify { previous in
            var current = f(previous)
            if previous.filter.id != current.filter.id {
                current = current.withUpdatedRequest(.Initial(max(Int(context.window.frame.height / 70) + 3, 12), nil))
                changedFolder = true
            }
            return current
        })
        if changedFolder {
            self.removeRevealStateIfNeeded(nil)
        }
        self.genericView.searchView.change(state: .None,  true)
        setCenterTitle(self.defaultBarTitle)
    }
    
    private let previousChatList:Atomic<EngineChatList?> = Atomic(value: nil)
    private let first = Atomic(value:true)
    private let animated = Atomic(value: false)
    private let removePeerIdGroupDisposable = MetaDisposable()
    private let downloadsDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    private let scrollDisposable = MetaDisposable()
    private let reorderDisposable = MetaDisposable()
    private let globalPeerDisposable = MetaDisposable()
    private let archivationTooltipDisposable = MetaDisposable()
    private let animateGroupNextTransition:Atomic<EngineChatList.Group?> = Atomic(value: nil)
    private var activityStatusesDisposable:Disposable?
    
    private let downloadsSummary: DownloadsSummary
    
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
        let first = Atomic<(hasEarlier: Bool, hasLater: Bool)>(value: (hasEarlier: false, hasLater: false))
        let scrollUp:Atomic<Bool> = self.first
        let groupId = self.mode.groupId
        let mode = self.mode
        let previousEntries:Atomic<[AppearanceWrapperEntry<UIChatListEntry>]?> = Atomic(value: nil)
        let animated: Atomic<Bool> = self.animated
        let animateGroupNextTransition = self.animateGroupNextTransition
        var scroll:TableScrollState? = nil


        let arguments = Arguments(context: context, setupFilter: { [weak self] filter in
            self?.updateFilter {
                $0.withUpdatedFilter(filter)
            }
            self?.scrollup(force: true)
        }, openFilterSettings: { filter in
            if case .filter = filter {
                context.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
            } else {
                context.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
            }
        }, tabsMenuItems: { filter in
            return filterContextMenuItems(filter, context: context)
        }, createTopic: {
            switch mode {
            case let .forum(peerId):
                ForumUI.createTopic(peerId, context: context)
            default:
                break
            }
        }, switchOffForum: {
            switch mode {
            case let .forum(peerId):
                _ = context.engine.peers.setChannelForumMode(id: peerId, isForum: false).start()
            default:
                break
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

        
        let signal = filter.get() 

        let previousfilter = Atomic<FilterData?>(value: self.filterValue)

        let chatHistoryView: Signal<(ChatListViewUpdate, FilterData, Bool), NoError> = signal |> mapToSignal { data -> Signal<(ChatListViewUpdate, FilterData, Bool), NoError> in
            
            return chatListViewForLocation(chatListLocation: mode.location, location: data.request, filter: data.filter, account: context.account) |> map {
                return ($0, data, previousfilter.swap(data)?.filter.id != data.filter.id)
            }
        }
        
        let previousLayout: Atomic<SplitViewState> = Atomic(value: context.layout)

        let list:Signal<TableUpdateTransition,NoError> = combineLatest(queue: prepareQueue, chatHistoryView, appearanceSignal, stateUpdater, hiddenItemsState.get(), appNotificationSettings(accountManager: context.sharedContext.accountManager), chatListFilterItems(engine: context.engine, accountManager: context.sharedContext.accountManager)) |> mapToQueue { value, appearance, state, hiddenItems, inAppSettings, filtersCounter -> Signal<TableUpdateTransition, NoError> in
                    
            let filterData = value.1
            let update = value.0
            let removeNextAnimation = update.removeNextAnimation
            let previous = first.swap((hasEarlier: update.list.hasEarlier,
                                       hasLater: update.list.hasLater))
            
            let ignoreFlags = scrollUp.swap(false)
            
            if !ignoreFlags || (!ignoreFlags && (previous.hasEarlier != update.list.hasEarlier || previous.hasLater != update.list.hasLater) && !removeNextAnimation) {
                scroll = nil
            }
            

            _ = previousChatList.swap(update.list)
            var prepare:[(EngineChatList.Item, UIChatAdditionalItem?)] = []
            for value in update.list.items {
                prepare.append((value, nil))
            }
            
            if !update.list.hasLater, case .allChats = filterData.filter {
                let items = update.list.additionalItems.filter {
                    !hiddenItems.promo.contains($0.item.renderedPeer.peerId)
                }
                for (i, current) in items.enumerated() {
                    prepare.append((current.item, UIChatAdditionalItem(item: current, index: i + update.list.groupItems.count)))
                }
            }
            var mapped: [UIChatListEntry] = prepare.map { item in
                let space: PeerActivitySpace
                switch item.0.id {
                case let .forum(threadId):
                    space = .init(peerId: item.0.renderedPeer.peerId, category: .thread(threadId))
                case let .chatList(peerId):
                    space = .init(peerId: peerId, category: .global)
                }
                return .chat(item.0, state?.activities.activities[space] ?? [], item.1, filter: filterData.filter)
            }
            
            if case .filter = filterData.filter, mapped.isEmpty {} else {
                if !update.list.hasLater {
                    for (i, group) in update.list.groupItems.reversed().enumerated() {
                        mapped.append(.group(i, group, animateGroupNextTransition.swap(nil) == group.id, hiddenItems.archive))
                    }
                }
            }
            
            if mapped.isEmpty {
                if !update.list.isLoading {
                    mapped.append(.empty(filterData.filter, mode, state?.splitState ?? .none, .init(state?.forumPeer?.peer)))
                } else {
                    mapped.append(.loading(filterData.filter))
                }
            } else {
                if update.list.isLoading {
                    mapped.append(.loading(filterData.filter))
                }
            }
            
            
            if !filterData.isEmpty && !filterData.sidebar {
                mapped.append(.reveal(filterData.tabs, filterData.filter, filtersCounter))
            }
            
            let entries = mapped.sorted().compactMap { entry -> AppearanceWrapperEntry<UIChatListEntry>? in
                return AppearanceWrapperEntry(entry: entry, appearance: appearance)
            }
            
            let prev = previousEntries.swap(entries)
            
            
            var animated = animated.swap(true)
            
            if value.2 {
                animated = false
                scroll = .up(true)
            }
            
            let layoutUpdated = previousLayout.swap(context.layout) != context.layout
                        
            if layoutUpdated {
                scroll = .up(false)
                animated = false
            }
            
            return prepareEntries(from: prev, to: entries, adIndex: nil, arguments: arguments, initialSize: initialSize.with { $0 }, animated: animated, scrollState: scroll, groupId: groupId)
        }
        
        
        let appliedTransition = list |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            self?.enqueueTransition(transition)
            return .complete()
        }
        
        disposable.set(appliedTransition.start())
      
        
        
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
            self?.removeRevealStateIfNeeded(nil)

            if let strongSelf = self, let view = view {
                var messageIndex:EngineChatList.Item.Index?
                
                switch scroll.direction {
                case .bottom:
                    if view.hasEarlier {
                        messageIndex = view.items.first?.index
                    }
                case .top:
                    if view.hasLater {
                        messageIndex = view.items.last?.index
                    }
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    _ = animated.swap(false)
                    strongSelf.updateFilter {
                        $0.withUpdatedRequest(.Index(messageIndex, nil))
                    }
                }
            }
            
        })
        
        let filterView = chatListFilterPreferences(engine: context.engine) |> deliverOnMainQueue
        switch mode {
        case .folder, .forum:
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
            var first: Bool = true
            filterDisposable.set(combineLatest(filterView, context.layoutValue).start(next: { [weak self] filters, layout in
                self?.updateFilter( { current in
                    var current = current
                    current = current.withUpdatedTabs(filters.list).withUpdatedSidebar(filters.sidebar || layout == .minimisize)
                    if !first, let updated = filters.list.first(where: { $0.id == current.filter.id }) {
                        current = current.withUpdatedFilter(updated)
                    } else {
                        current = current.withUpdatedFilter(nil)
                    }
                    return current
                } )
                first = false
            }))
        }
        
        let downloadArguments: DownloadsControlArguments = DownloadsControlArguments(open: { [weak self] in
            self?.showDownloads(animated: true)
        }, navigate: { [weak self] messageId in
            self?.open(with: .chatId(.chatList(messageId.peerId), messageId.peerId, -1), messageId: messageId, initialAction: nil, close: false, forceAnimated: true)
        })
        
        downloadsDisposable.set(self.downloadsSummary.state.start(next: { [weak self] state in
            self?.genericView.updateDownloads(state, context: context, arguments: downloadArguments, animated: true)
        }))
        
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
    
    
    func setAnimateGroupNextTransition(_ groupId: EngineChatList.Group) {
        _ = self.animateGroupNextTransition.swap(groupId)
        
    }
    
    
    private func enqueueTransition(_ transition: TableUpdateTransition) {
        self.genericView.tableView.merge(with: transition)
        self.readyOnce()
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
        
        
        let needPreload = previousChatList.with  { $0?.hasLater == false }
        if needPreload {
            var preloadItems:[ChatHistoryPreloadItem] = []
            self.genericView.tableView.enumerateItems(with: { item -> Bool in
                guard let item = item as? ChatListRowItem, let index = item.chatListIndex else {return true}
                preloadItems.append(.init(index: index, threadId: item.mode.threadId, isMuted: item.isMuted, hasUnread: item.hasUnread))
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
        
        let groupId: EngineChatList.Group = self.mode.groupId

        let location: TogglePeerChatPinnedLocation
        
        if let filter = self.filterValue?.filter {
            switch filter {
            case .allChats:
                location = .group(groupId._asGroup())
            case let .filter(id, _, _, _):
                location = .filter(id)
            }
        } else {
            location = .group(groupId._asGroup())
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
        reorderDisposable.set(context.engine.peers.reorderPinnedItemIds(location: location, itemIds: items).start())
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
        
        if self.genericView.tableView.contentOffset.y == 0, view?.hasLater == false {
            switch mode {
            case .folder:
                navigationController?.back()
                return
            case .filter:
                navigationController?.back()
                return
            case .plain:
                break
            case .forum:
                navigationController?.back()
                return
            }
        }
        
        
        let scrollToTop:()->Void = { [weak self] in
            guard let `self` = self else {return}

            let view = self.previousChatList.modify({$0})
            if view?.hasLater == true {
                _ = self.first.swap(true)
                self.updateFilter {
                    $0.withUpdatedRequest(.Initial(50, .up(true)))
                }
            } else {
                if self.genericView.tableView.documentOffset.y == 0 {
                    if self.filterValue?.filter == .allChats {
                        self.context.bindings.mainController().showFastChatSettings()
                    } else {
                        self.updateFilter {
                            $0.withUpdatedFilter(nil)
                        }
                    }
                } else {
                    self.genericView.tableView.scroll(to: .up(true), ignoreLayerAnimation: true)
                }
            }
        }
        scrollToTop()
    }
    
    
    func globalSearch(_ query: String) {
        let invoke = { [weak self] in
            self?.genericView.searchView.change(state: .Focus, false)
            self?.genericView.searchView.setString(query)
        }
        
        switch context.layout {
        case .single:
            context.bindings.rootNavigation().back()
            Queue.mainQueue().justDispatch(invoke)
        case .minimisize:
            context.bindings.needFullsize()
            Queue.mainQueue().justDispatch(invoke)
        default:
            invoke()
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        let isLocked = (NSApp.delegate as? AppDelegate)?.passlock ?? .single(false)
        
        
        
        self.suggestAutoarchiveDisposable.set(combineLatest(queue: .mainQueue(), isLocked, context.isKeyWindow, getServerProvidedSuggestions(account: self.context.account)).start(next: { [weak self] locked, isKeyWindow, values in
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
                
                confirm(for: context.window, header: strings().alertHideNewChatsHeader, information: strings().alertHideNewChatsText, okTitle: strings().alertHideNewChatsOK, cancelTitle: strings().alertHideNewChatsCancel, successHandler: { _ in
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
            
            
            guard let state = swipeState, self.context.layout != .minimisize else {return .failed}
            
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
        
      
        
        if context.bindings.rootNavigation().stackCount == 1 {
            setHighlightEvents()
        }
    }
    
    private func setHighlightEvents() {
        
        removeHighlightEvents()
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let item = self?.genericView.tableView.highlightedItem(), item.index > 0 {
                self?.genericView.tableView.highlightPrev(turnDirection: false)
                while self?.genericView.tableView.highlightedItem() is PopularPeersRowItem || self?.genericView.tableView.highlightedItem() is SeparatorRowItem {
                    self?.genericView.tableView.highlightNext(turnDirection: false)
                }
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .low)
        
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
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
        if case .forum = self.mode {
            _openChat(index)
        } else if case .folder = self.mode {
            _openChat(index)
        } else if force  {
            _openChat(index)
        } else {
            let prefs = chatListFilterPreferences(engine: context.engine) |> deliverOnMainQueue |> take(1)
            
            _ = prefs.start(next: { [weak self] filters in
                if filters.isEmpty {
                    self?._openChat(index)
                } else if filters.list.count > index {
                    self?.updateFilter {
                        $0.withUpdatedFilter(filters.list[index])
                    }
                    self?.scrollup(force: true)
                } else {
                    self?._openChat(index)
                }
            })
        }
    }
    
    override var removeAfterDisapper: Bool {
        return false
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
        downloadsDisposable.dispose()
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
        case .filter:
            return _filterValue.with { $0.filter.title }
        default:
            return super.defaultBarTitle
        }
    }

    override func escapeKeyAction() -> KeyHandlerResult {
        if !mode.isPlain, let navigation = navigationController {
            navigation.back()
            return .invoked
        }
        if let filter = self.filterValue, !filter.isFirst {
            updateFilter {
                $0.withUpdatedFilter(nil)
            }
            return .invoked
        }
        return super.escapeKeyAction()
    }
    
    
    init(_ context: AccountContext, modal:Bool = false, mode: PeerListMode = .plain) {
        

        self.downloadsSummary = DownloadsSummary(context.fetchManager as! FetchManagerImpl, context: context)
        
        let searchOptions:AppSearchOptions
        searchOptions = [.messages, .chats]
        super.init(context, followGlobal: !modal, mode: mode, searchOptions: searchOptions)
        
        if mode.filterId != nil {
            context.closeFolderFirst = true
        }
    }

    override func selectionWillChange(row:Int, item:TableRowItem, byClick: Bool) -> Bool {
        if let item = item as? ChatListRowItem, let peer = item.peer, let modalAction = context.bindings.rootNavigation().modalAction {
            if !modalAction.isInvokable(for: peer) {
                modalAction.alertError(for: peer, with: item.context.window)
                return false
            }
            modalAction.afterInvoke()
            
            if let modalAction = modalAction as? FWDNavigationAction {
                if item.peerId == context.peerId {
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId, replyId: nil).start()
                    _ = showModalSuccess(for: item.context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
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
            } else if item.isForum && !item.isTopic {
                item.view?.focusAnimation(nil)
            }
        }
        if item is ChatListRevealItem {
            return false
        }
        return true
    }
    
   
    
    override  func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        let navigation = context.bindings.rootNavigation()
        if let item = item as? ChatListRowItem {
            if !isNew, let controller = navigation.controller as? ChatController, !(item.isForum && !item.isTopic) {
                switch controller.mode {
                case .history, .thread:
                    if let modalAction = navigation.modalAction {
                        navigation.controller.invokeNavigation(action: modalAction)
                    }
                    controller.clearReplyStack()
                    controller.scrollUpOrToUnread()
                case .scheduled, .pinned:
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
                    initialAction = .ad(info.promoInfo.content)
                default:
                    initialAction = nil
                }
                
                open(with: item.entryId, initialAction: initialAction, addition: false)
                
            }
        }
    }
  
}

