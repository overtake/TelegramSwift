//
//  FoldersSidebarController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore

func filterContextMenuItems(_ filter: ChatListFilter?, context: AccountContext) -> [ContextMenuItem] {
    var items:[ContextMenuItem] = []
    if var filter = filter {
        items.append(.init(L10n.chatListFilterEdit, handler: {
            context.sharedContext.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
        }))
        items.append(.init(L10n.chatListFilterAddChats, handler: {
            showModal(with: ShareModalController(SelectCallbackObject(context, defaultSelectedIds: Set(filter.data.includePeers.peers), additionTopItems: nil, limit: 100, limitReachedText: L10n.chatListFilterIncludeLimitReached, callback: { peerIds in
                return updateChatListFiltersInteractively(postbox: context.account.postbox, { filters in
                    var filters = filters
                    filter.data.includePeers.setPeers(Array(peerIds.uniqueElements.prefix(100)))
                    if let index = filters.firstIndex(where: {$0.id == filter.id }) {
                        filters[index] = filter
                    }
                    return filters
                }) |> ignoreValues
                
            })), for: context.window)
        }))
        items.append(.init(L10n.chatListFilterDelete, handler: {
            confirm(for: context.window, header: L10n.chatListFilterConfirmRemoveHeader, information: L10n.chatListFilterConfirmRemoveText, okTitle: L10n.chatListFilterConfirmRemoveOK, successHandler: { _ in
                _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { filters in
                    var filters = filters
                    filters.removeAll(where: { $0.id == filter.id })
                    return filters
                }).start()
            })
            
        }))
    } else {
        items.append(.init(L10n.chatListFilterEditFilters, handler: {
            context.sharedContext.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
        }))
    }
    
    return items
}

private final class LeftSidebarArguments {
    let context: AccountContext
    let callback:(ChatListFilter?)->Void
    let menuItems:(ChatListFilter?)->[ContextMenuItem]
    init(context: AccountContext, callback: @escaping(ChatListFilter?)->Void, menuItems: @escaping(ChatListFilter?)->[ContextMenuItem]) {
        self.context = context
        self.callback = callback
        self.menuItems = menuItems
    }
}


final class LeftSidebarView: View {
    fileprivate let tableView = TableView()
    private let visualEffectView: NSVisualEffectView
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        self.visualEffectView = NSVisualEffectView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        
        addSubview(self.visualEffectView)
        addSubview(self.borderView)

        addSubview(self.tableView)
        tableView.getBackgroundColor = {
            return .clear
        }

        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .ultraDark
       
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.visualEffectView.frame = bounds
        self.tableView.frame = bounds
        self.borderView.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
    }
}

private enum LeftSibarBarEntry : Comparable, Identifiable {
    static func < (lhs: LeftSibarBarEntry, rhs: LeftSibarBarEntry) -> Bool {
        return lhs.index < rhs.index
    }
    case topOffset
    case allChats(selected: Bool, unreadCount: Int, hasUnmutedUnread: Bool)
    case folder(index: Int, selected: Bool, filter: ChatListFilter, unreadCount: Int, hasUnmutedUnread: Bool)
    
    var stableId: Int32 {
        switch self {
        case .topOffset:
            return -2
        case .allChats:
            return -1
        case let .folder(_, _, filter, _, _):
            return filter.id
        }
    }
    
    var index: Int {
        switch self {
        case .topOffset:
            return -1
        case .allChats:
            return 0
        case let .folder(index, _, _, _, _):
            return index
        }
    }
    
    func item(_ arguments: LeftSidebarArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .allChats(selected, unreadCount, hasUnmutedUnread):
            return LeftSidebarFolderItem(initialSize, folder: nil, selected: selected, unreadCount: unreadCount, hasUnmutedUnread: hasUnmutedUnread, callback: arguments.callback, menuItems: arguments.menuItems)
        case let .folder(_, selected, filter, unreadCount, hasUnmutedUnread):
            return LeftSidebarFolderItem(initialSize, folder: filter, selected: selected, unreadCount: unreadCount, hasUnmutedUnread: hasUnmutedUnread, callback: arguments.callback, menuItems: arguments.menuItems)
        case .topOffset:
            return GeneralRowItem(initialSize, height: 16, stableId: stableId, backgroundColor: .clear)
        }
    }
}

private func leftSidebarEntries(_ filterData: FilterData, _ badges: ChatListFilterBadges) -> [LeftSibarBarEntry] {
    var index: Int = 1
    
    var entries:[LeftSibarBarEntry] = []
    entries.append(.topOffset)

    entries.append(.allChats(selected: filterData.filter == nil, unreadCount: badges.total, hasUnmutedUnread: true))
    
    for filter in filterData.tabs {
        let badge = badges.count(for: filter)
        entries.append(.folder(index: index, selected: filter.id == filterData.filter?.id, filter: filter, unreadCount: badge?.count ?? 0, hasUnmutedUnread: badge?.hasUnmutedUnread ?? false))
        index += 1
    }
    
    return entries
}

fileprivate func prepareTransition(left:[LeftSibarBarEntry], right: [LeftSibarBarEntry], initialSize:NSSize, arguments:LeftSidebarArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class LeftSidebarController: TelegramGenericViewController<LeftSidebarView> {

    let filterData: Signal<FilterData, NoError>
    let updateFilter: (_ f:(FilterData)->FilterData)->Void
    
    private let disposable = MetaDisposable()
    
    init(_ context: AccountContext, filterData: Signal<FilterData, NoError>, updateFilter: @escaping(_ f:(FilterData)->FilterData)->Void) {
        self.filterData = filterData
        self.updateFilter = updateFilter
        super.init(context)
        self.bar = .init(height: 0)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        let arguments = LeftSidebarArguments(context: context, callback: { [weak self] filter in
            self?.updateFilter { state in
                return state.withUpdatedFilter(filter)
            }
            
            let rootNavigation = context.sharedContext.bindings.rootNavigation()
            
            let leftController = context.sharedContext.bindings.mainController()
            leftController.chatListNavigation.close(animated: context.sharedContext.layout != .single || rootNavigation.stackCount == 1)
            
            if context.sharedContext.layout == .single {
                rootNavigation.close(animated: true)
            }
            leftController.showChatList()
            
        }, menuItems: { filter in
            return filterContextMenuItems(filter, context: context)
        })
        let initialSize = self.atomicSize
        
        let previous: Atomic<[LeftSibarBarEntry]> = Atomic(value: [])
                
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, filterData, chatListFilterItems(account: context.account, accountManager: context.sharedContext.accountManager)) |> map { filterData, badges in
            let entries = leftSidebarEntries(filterData, badges)
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.with { $0 }, arguments: arguments)
        } |> deliverOnMainQueue
        
        self.genericView.tableView.alwaysOpenRowsOnMouseUp = true
        
        disposable.set(signal.start(next: { [weak self] transition in
            
            guard let `self` = self else {
                return
            }
            self.genericView.tableView.merge(with: transition)
            self.readyOnce()
            
            let range = NSMakeRange(2, self.genericView.tableView.count - 2)
            
            self.genericView.tableView.resortController = TableResortController(resortRange: range, start: { _ in }, resort: { _ in }, complete: { from, to in
                _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { filters in
                    var filters = filters
                    filters.move(at: from - range.location, to: to - range.location)
                    return filters
                }).start()
            })
        }))
    }
}
