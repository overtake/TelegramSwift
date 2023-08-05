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
import InAppSettings

private func readAllInFilter(_ filter: ChatListFilter?, context: AccountContext) {
    guard let filterPredicate = chatListFilterPredicate(for: filter) else {
        return
    }
    var markItems: [(groupId: EngineChatList.Group, filterPredicate: ChatListFilterPredicate?)] = []
    markItems.append((.root, filterPredicate))
    for additionalGroupId in filterPredicate.includeAdditionalPeerGroupIds {
        markItems.append((EngineChatList.Group(additionalGroupId), filterPredicate))
    }
    let _ = context.engine.messages.markAllChatsAsReadInteractively(items: markItems).start()
}

func filterContextMenuItems(_ filter: ChatListFilter, unreadCount: Int?, includeAllMuted: Bool? = nil, context: AccountContext) -> [ContextMenuItem] {
    var items:[ContextMenuItem] = []
    if var data = filter.data {
        items.append(.init(strings().chatListFilterEdit, handler: {
            context.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
        }, itemImage: MenuAnimation.menu_edit.value))
        
        items.append(.init(strings().chatListFilterAddChats, handler: {
            showModal(with: ShareModalController(SelectCallbackObject(context, defaultSelectedIds: Set(data.includePeers.peers), additionTopItems: nil, limit: 100, limitReachedText: strings().chatListFilterIncludeLimitReached, callback: { peerIds in
                return context.engine.peers.updateChatListFiltersInteractively({ filters in
                    var filters = filters
                    data.includePeers.setPeers(Array(peerIds.uniqueElements.prefix(100)))
                    let filter = filter.withUpdatedData(data)
                    if let index = filters.firstIndex(where: {$0.id == filter.id }) {
                        filters[index] = filter
                    }
                    return filters
                }) |> ignoreValues
                
            })), for: context.window)
        }, itemImage: MenuAnimation.menu_plus.value))
        
        if let unreadCount = unreadCount {
            if unreadCount > 0 {
                items.append(.init(strings().chatListFilterReadAll, handler: {
                    readAllInFilter(filter, context: context)
                }, itemImage: MenuAnimation.menu_folder_read.value))
            }
        }
        if data.categories.isEmpty && !data.excludeRead && !data.excludeMuted && !data.excludeArchived && data.excludePeers.isEmpty && !data.includePeers.peers.isEmpty {
            if let allMuted = includeAllMuted {
                items.append(.init(allMuted ? strings().chatListFilterUnmuteAll : strings().chatListFilterMuteAll, handler: {
                    let _ = context.engine.peers.updateMultiplePeerMuteSettings(peerIds: data.includePeers.peers, muted: !allMuted).start()
                }, itemImage: !allMuted ? MenuAnimation.menu_mute.value : MenuAnimation.menu_unmuted.value))
            }
        }
        
        if data.isShared {
            items.append(.init(strings().chatListFilterShare, handler: {
                shareSharedFolder(context: context, filter: filter)
            }, itemImage: MenuAnimation.menu_share.value))
        }
        
        items.append(ContextSeparatorItem())
        
        items.append(.init(strings().chatListFilterDelete, handler: {
            if filter.data?.isShared == true {
                deleteSharedFolder(context: context, filter: filter)
            } else {
                confirm(for: context.window, header: strings().chatListFilterConfirmRemoveHeader, information: strings().chatListFilterConfirmRemoveText, okTitle: strings().chatListFilterConfirmRemoveOK, successHandler: { _ in
                    _ = context.engine.peers.updateChatListFiltersInteractively({ filters in
                        var filters = filters
                        filters.removeAll(where: { $0.id == filter.id })
                        return filters
                    }).start()
                })
            }
        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
    } else {
        items.append(.init(strings().chatListFilterEditFilters, handler: {
            context.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
        }, itemImage: MenuAnimation.menu_edit.value))
    }
    
    return items
}

private final class LeftSidebarArguments {
    let context: AccountContext
    let callback:(ChatListFilter)->Void
    let menuItems:(ChatListFilter, Int?, Bool?)->[ContextMenuItem]
    init(context: AccountContext, callback: @escaping(ChatListFilter)->Void, menuItems: @escaping(ChatListFilter, Int?, Bool?)->[ContextMenuItem]) {
        self.context = context
        self.callback = callback
        self.menuItems = menuItems
    }
}


final class LeftSidebarView: Control {
    fileprivate let tableView = TableView()
    private let visualEffectView: NSVisualEffectView
    private let borderView = View()
    fileprivate var context: AccountContext?
    fileprivate let edit = ImageButton()
    required init(frame frameRect: NSRect) {
        self.visualEffectView = NSVisualEffectView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        
        addSubview(self.visualEffectView)
        addSubview(self.borderView)

        addSubview(self.tableView)
        addSubview(self.edit)
        tableView.getBackgroundColor = {
            return .clear
        }

        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .ultraDark
        visualEffectView.state = .active
        
        self.edit.autohighlight = false
        self.edit.scaleOnClick = false
       
        updateLocalizationAndTheme(theme: theme)
        
        contextMenu = { [weak self] in
            let menu = ContextMenu()
            menu.addItem(ContextMenuItem(strings().navigationEdit, handler: {
                if let context = self?.context {
                    context.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
                }
            }, itemImage: MenuAnimation.menu_edit.value))
            return menu
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        
        borderView.backgroundColor = theme.colors.border
        self.backgroundColor = theme.colors.listBackground
        self.borderView.isHidden = !theme.colors.isDark
        self.visualEffectView.isHidden = theme.colors.isDark
        self.edit.set(image: theme.icons.folders_sidebar_edit, for: .Normal)
        self.edit.set(image: theme.icons.folders_sidebar_edit_active, for: .Highlight)
        self.edit.borderColor = theme.colors.grayIcon.withAlphaComponent(0.1)
        needsLayout = true

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.visualEffectView.frame = bounds
        self.tableView.frame = NSMakeRect(0, 0, frame.width, frame.height - 50)
        self.borderView.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
        self.edit.frame = NSMakeRect(0, frame.height - 50, frame.width, 50)
        self.edit.border = tableView.frame.height < tableView.documentSize.height ? [.Top] : []
    }
}

private enum LeftSibarBarEntry : Comparable, Identifiable {
    static func < (lhs: LeftSibarBarEntry, rhs: LeftSibarBarEntry) -> Bool {
        return lhs.index < rhs.index
    }
    case topOffset
    case folder(index: Int, selected: Bool, filter: ChatListFilter, unreadCount: Int, hasUnmutedUnread: Bool)
    
    var stableId: Int32 {
        switch self {
        case .topOffset:
            return -2
        case let .folder(_, _, filter, _, _):
            return filter.id
        }
    }
    
    var index: Int {
        switch self {
        case .topOffset:
            return -1
        case let .folder(index, _, _, _, _):
            return index
        }
    }
    
    func item(_ arguments: LeftSidebarArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .folder(_, selected, filter, unreadCount, hasUnmutedUnread):
            return LeftSidebarFolderItem(initialSize, context: arguments.context, folder: filter, selected: selected, unreadCount: unreadCount, hasUnmutedUnread: hasUnmutedUnread, callback: arguments.callback, menuItems: arguments.menuItems)
        case .topOffset:
            return GeneralRowItem(initialSize, height: 24, stableId: stableId, backgroundColor: .clear)
        }
    }
}

private func leftSidebarEntries(_ filterData: FilterData, _ badges: ChatListFilterBadges) -> [LeftSibarBarEntry] {
    var index: Int = 1
    
    var entries:[LeftSibarBarEntry] = []
    entries.append(.topOffset)
    
    for filter in filterData.tabs {
        let badge = badges.count(for: filter)
        entries.append(.folder(index: index, selected: filter.id == filterData.filter.id, filter: filter, unreadCount: badge?.count ?? 0, hasUnmutedUnread: badge?.hasUnmutedUnread ?? false))
        index += 1
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<LeftSibarBarEntry>], right: [AppearanceWrapperEntry<LeftSibarBarEntry>], initialSize:NSSize, arguments:LeftSidebarArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
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
        
        genericView.context = context
        
        let arguments = LeftSidebarArguments(context: context, callback: { filter in
            navigateToChatListFilter(filter.id, context: context)

        }, menuItems: { filter, unreadCount, allMuted in
            return filterContextMenuItems(filter, unreadCount: unreadCount, includeAllMuted: allMuted, context: context)
        })
        let initialSize = self.atomicSize
        
        let previous: Atomic<[AppearanceWrapperEntry<LeftSibarBarEntry>]> = Atomic(value: [])
                
        genericView.edit.set(handler: { _ in
            if let controller = context.bindings.rootNavigation().controller as? InputDataController {
                if controller.identifier == "filters" {
                    return
                }
            }
            context.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
        }, for: .Click)

        
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, filterData, chatListFilterItems(engine: context.engine, accountManager: context.sharedContext.accountManager), appearanceSignal) |> map { filterData, badges, appearance in
            let entries = leftSidebarEntries(filterData, badges).map { AppearanceWrapperEntry.init(entry: $0, appearance: appearance) }
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.with { $0 }, arguments: arguments)
        } |> deliverOnMainQueue
        
        self.genericView.tableView.alwaysOpenRowsOnMouseUp = true
        
        disposable.set(signal.start(next: { [weak self] transition in
            
            guard let `self` = self else {
                return
            }
            self.genericView.tableView.merge(with: transition)
            self.genericView.updateLocalizationAndTheme(theme: theme)
            self.readyOnce()
            
            let range:NSRange
            if context.isPremium {
                range = NSMakeRange(1, self.genericView.tableView.count - 1)
            } else {
                range = NSMakeRange(2, self.genericView.tableView.count - 2)
            }
            self.genericView.tableView.resortController = TableResortController(resortRange: range, start: { _ in }, resort: { _ in }, complete: { from, to in
                _ = context.engine.peers.updateChatListFiltersInteractively({ filters in
                    var filters = filters
                    filters.move(at: from - 1, to: to - 1)
                    return filters
                }).start()
            })
        }))
    }
}


func navigateToChatListFilter(_ filter: Int32, context: AccountContext) {
    
    context.bindings.mainController().chatList.updateFilter { state in
        return state.withUpdatedFilterId(filter)
    }
    
    let rootNavigation = context.bindings.rootNavigation()
    
    let leftController = context.bindings.mainController()
    leftController.showChatList()
    
    leftController.navigation.close(animated: context.layout != .single || rootNavigation.stackCount == 1)
    
    if context.layout == .single {
        rootNavigation.close(animated: true)
    }
}
