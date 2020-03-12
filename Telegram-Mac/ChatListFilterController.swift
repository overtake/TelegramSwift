//
//  ChatListPresetController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/01/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TGUIKit

private let maximumPeers: Int = 100

private extension ChatListFilter {
    var additionIncludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        
        items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .groups), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .channels), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .bots), status: ""))
        return items
    }
    var selectedIncludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        
        if self.data.categories.contains(.contacts) {
            items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
        }
        if self.data.categories.contains(.nonContacts) {
            items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))
        }
        if self.data.categories.contains(.groups) {
            items.append(.init(peer: TelegramFilterCategory(category: .groups), status: ""))
        }
        if self.data.categories.contains(.channels) {
            items.append(.init(peer: TelegramFilterCategory(category: .channels), status: ""))
        }
        if self.data.categories.contains(.bots) {
            items.append(.init(peer: TelegramFilterCategory(category: .bots), status: ""))
        }
        return items
    }
    var additionExcludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        items.append(.init(peer: TelegramFilterCategory(category: .excludeMuted), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .excludeRead), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .excludeArchived), status: ""))
        return items
    }
    var selectedExcludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        
        if self.data.excludeMuted {
            items.append(.init(peer: TelegramFilterCategory(category: .excludeMuted), status: ""))
        }
        if self.data.excludeRead {
            items.append(.init(peer: TelegramFilterCategory(category: .excludeRead), status: ""))
        }
        if self.data.excludeArchived {
            items.append(.init(peer: TelegramFilterCategory(category: .excludeArchived), status: ""))
        }
        return items
    }
}

//extension ChatListFiltersState {
//    mutating func withAddedFilter(_ filter: ChatListFilter, onlyReplace: Bool = false) {
//        if let index = filters.firstIndex(where: {$0.id == filter.id}) {
//            filters[index] = filter
//        } else if !onlyReplace {
//            filters.append(filter)
//        }
//    }
//
//    mutating func withRemovedFilter(_ filter: ChatListFilter) {
//        filters.removeAll(where: {$0.id == filter.id })
//    }
//
//    mutating func withMoveFilter(_ from: Int, _ to: Int)  {
//        filters.insert(filters.remove(at: from), at: to)
//    }
//}

class SelectCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    private let limitReachedText: String
    init(_ context: AccountContext, defaultSelectedIds: Set<PeerId>, additionTopItems: ShareAdditionItems?, limit: Int?, limitReachedText: String, callback:@escaping([PeerId])->Signal<Never, NoError>) {
        self.callback = callback
        self.limitReachedText = limitReachedText
        super.init(context, defaultSelectedIds: defaultSelectedIds, additionTopItems: additionTopItems, limit: limit)
    }
    
    override var hasCaptionView: Bool {
        return false
    }
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) -> Signal<Never, String> {
        return callback(peerIds) |> mapError { _ in return String() }
    }
    override func limitReached() {
        alert(for: context.window, info: limitReachedText)
    }
    override var searchPlaceholderKey: String {
        return "ChatList.Add.Placeholder"
    }
    override var interactionOk: String {
        return L10n.chatListFilterAddDone
    }
    override var alwaysEnableDone: Bool {
        return true
    }
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        return true
    }
    
}

private struct ChatListFiltersListState: Equatable {
    var filter: ChatListFilter
    var showAllInclude: Bool
    var showAllExclude: Bool
    let isNew: Bool
    init(filter: ChatListFilter, isNew: Bool, showAllInclude: Bool, showAllExclude: Bool) {
        self.filter = filter
        self.isNew = isNew
        self.showAllInclude = showAllInclude
        self.showAllExclude = showAllExclude
    }
    
    
    
    mutating func withUpdatedFilter(_ f:(ChatListFilter)->ChatListFilter) {
        self.filter = f(self.filter)
    }
}

private final class ChatListPresetArguments {
    let context: AccountContext
    let toggleOption:(ChatListFilterPeerCategories)->Void
    let toggleExcludeMuted:(Bool)->Void
    let toggleExcludeRead:(Bool)->Void
    let addInclude:()->Void
    let addExclude:()->Void
    let removeIncluded:(PeerId)->Void
    let removeExcluded:(PeerId)->Void
    let openInfo:(PeerId)->Void
    let showAllInclude: ()->Void
    let showAllExclude: ()->Void
    init(context: AccountContext, toggleOption:@escaping(ChatListFilterPeerCategories)->Void, addInclude: @escaping()->Void, addExclude: @escaping()->Void, removeIncluded: @escaping(PeerId)->Void, removeExcluded: @escaping(PeerId)->Void, openInfo: @escaping(PeerId)->Void, toggleExcludeMuted:@escaping(Bool)->Void, toggleExcludeRead: @escaping(Bool)->Void, showAllInclude:@escaping()->Void, showAllExclude:@escaping()->Void) {
        self.context = context
        self.toggleOption = toggleOption
        self.toggleExcludeMuted = toggleExcludeMuted
        self.toggleExcludeRead = toggleExcludeRead
        self.addInclude = addInclude
        self.addExclude = addExclude
        self.removeIncluded = removeIncluded
        self.removeExcluded = removeExcluded
        self.openInfo = openInfo
        self.showAllInclude = showAllInclude
        self.showAllExclude = showAllExclude
    }
}

private let _id_name_input = InputDataIdentifier("_id_name_input")
private let _id_private_chats = InputDataIdentifier("_id_private_chats")

private let _id_public_groups = InputDataIdentifier("_id_public_groups")
private let _id_private_groups = InputDataIdentifier("_id_private_groups")
private let _id_secret_chats = InputDataIdentifier("_id_secret_chats")


private let _id_channels = InputDataIdentifier("_id_channels")
private let _id_bots = InputDataIdentifier("_id_bots")
private let _id_exclude_muted = InputDataIdentifier("_id_exclude_muted")
private let _id_exclude_read = InputDataIdentifier("_id_exclude_read")

private let _id_add_include = InputDataIdentifier("_id_add_include")
private let _id_add_exclude = InputDataIdentifier("_id_add_exclude")

private let _id_show_all_include = InputDataIdentifier("_id_show_all_include")
private let _id_show_all_exclude = InputDataIdentifier("_id_show_all_exclude")
private let _id_header = InputDataIdentifier("_id_header")
private func _id_include(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_include_\(peerId)")
}
private func _id_exclude(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_exclude_\(peerId)")
}
private func chatListFilterEntries(state: ChatListFiltersListState, includePeers: [Peer], excludePeers: [Peer], arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var includePeers:[Peer] = includePeers
    
    if state.filter.data.categories.contains(.groups) {
        includePeers.insert(TelegramFilterCategory(category: .groups), at: 0)
    }
    if state.filter.data.categories.contains(.channels) {
        includePeers.insert(TelegramFilterCategory(category: .channels), at: 0)
    }
    if state.filter.data.categories.contains(.contacts) {
        includePeers.insert(TelegramFilterCategory(category: .contacts), at: 0)
    }
    if state.filter.data.categories.contains(.nonContacts) {
        includePeers.insert(TelegramFilterCategory(category: .nonContacts), at: 0)
    }
    if state.filter.data.categories.contains(.bots) {
        includePeers.insert(TelegramFilterCategory(category: .bots), at: 0)
    }
    
    
    var excludePeers:[Peer] = excludePeers
    
    if state.filter.data.excludeMuted {
        excludePeers.insert(TelegramFilterCategory(category: .excludeMuted), at: 0)
    }
    if state.filter.data.excludeRead {
        excludePeers.insert(TelegramFilterCategory(category: .excludeRead), at: 0)
    }
    if state.filter.data.excludeArchived {
        excludePeers.insert(TelegramFilterCategory(category: .excludeArchived), at: 0)
    }

    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    if state.isNew {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, item: { initialSize, stableId in
            let attributedString = NSMutableAttributedString()
            return ChatListFiltersHeaderItem(initialSize, context: arguments.context, stableId: stableId, sticker: LocalAnimatedSticker.new_folder, text: attributedString)
        }))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterNameHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.filter.title), error: nil, identifier: _id_name_input, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: L10n.chatListFilterNamePlaceholder, filter: { $0 }, limit: 20))
    index += 1
   
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterIncludeHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    let hasAddInclude = state.filter.data.includePeers.count < maximumPeers || state.filter.data.categories != .all
    
    if hasAddInclude  {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_include, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chatListFilterIncludeAddChat, nameStyle: blueActionButton, type: .none, viewType: includePeers.isEmpty ? .singleItem : .firstItem, action: arguments.addInclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chat_filter_add, textInset: 46, thumbInset: 4))
        }))
        index += 1
    }
   
    
    
    var fake:[Int] = []
    fake.append(0)
    for (i, _) in includePeers.enumerated() {
        if hasAddInclude {
            fake.append(i + 1)
        } else {
            fake.append(i)
        }
    }
    
    for (i, peer) in includePeers.enumerated() {
        
        struct E : Equatable {
            let viewType: GeneralViewType
            let peer: PeerEquatable
        }
        
        if i > 10, !state.showAllInclude {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_show_all_include, equatable: InputDataEquatable(includePeers.count), item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chatListFilterShowMoreCountable(includePeers.count - i), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: arguments.showAllInclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
            }))
            index += 1
            break
        } else {
            let viewType = bestGeneralViewType(fake, for: hasAddInclude ? i + 1 : i)
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_include(peer.id), equatable: InputDataEquatable(E(viewType: viewType, peer: PeerEquatable(peer))), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), inset: NSEdgeInsets(left: 30, right: 30), viewType: viewType, action: {
                    arguments.openInfo(peer.id)
                }, contextMenuItems: {
                    return [ContextMenuItem(L10n.chatListFilterIncludeRemoveChat, handler: {
                        arguments.removeIncluded(peer.id)
                    })]
                })
            }))
            index += 1
        }
        
        
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterIncludeDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterExcludeHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    let hasAddExclude = state.filter.data.excludePeers.count < maximumPeers || !state.filter.data.excludeRead || !state.filter.data.excludeMuted || !state.filter.data.excludeArchived

    
    if hasAddExclude {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_exclude, equatable: InputDataEquatable(state), item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chatListFilterExcludeAddChat, nameStyle: blueActionButton, type: .none, viewType: excludePeers.isEmpty ? .singleItem : .firstItem, action: arguments.addExclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chat_filter_add, textInset: 46, thumbInset: 2))
        }))
        index += 1
    }
   
    
    
    fake = []
    fake.append(0)
    for (i, _) in excludePeers.enumerated() {
        if hasAddExclude {
            fake.append(i + 1)
        } else {
            fake.append(i)
        }
    }
    
    for (i, peer) in excludePeers.enumerated() {
        struct E : Equatable {
            let viewType: GeneralViewType
            let peer: PeerEquatable
        }
        if i > 10, !state.showAllInclude {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_show_all_exclude, equatable: InputDataEquatable(excludePeers.count), item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chatListFilterShowMoreCountable(includePeers.count - i), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: arguments.showAllInclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
            }))
            index += 1
            break
        } else {
            let viewType = bestGeneralViewType(fake, for: hasAddExclude ? i + 1 : i)
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_exclude(peer.id), equatable: InputDataEquatable(E(viewType: viewType, peer: PeerEquatable(peer))), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), inset: NSEdgeInsets(left: 30, right: 30), viewType: viewType, action: {
                    arguments.openInfo(peer.id)
                }, contextMenuItems: {
                    return [ContextMenuItem.init(L10n.chatListFilterExcludeRemoveChat, handler: {
                        arguments.removeExcluded(peer.id)
                    })]
                })
            }))
            index += 1
        }
        
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterExcludeDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChatListFilterController(context: AccountContext, filter: ChatListFilter, isNew: Bool = false) -> InputDataController {
    
    
    let initialState = ChatListFiltersListState(filter: filter, isNew: isNew, showAllInclude: false, showAllExclude: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChatListFiltersListState) -> ChatListFiltersListState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let updateDisposable = MetaDisposable()
    
    let save:(Bool)->Void = { replace in
        _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { filters in
            let filter = stateValue.with { $0.filter }
            var filters = filters
            if let index = filters.firstIndex(where: {$0.id == filter.id}) {
                filters[index] = filter
            } else if !replace {
                filters.append(filter)
            }
            return filters
        }).start()
    }
    
    
    let arguments = ChatListPresetArguments(context: context, toggleOption: { option in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                if filter.data.categories.contains(option) {
                    filter.data.categories.remove(option)
                } else {
                    filter.data.categories.insert(option)
                }
                return filter
            }
            return state
        }
       // save(true)
        
    }, addInclude: {
        
        let items = stateValue.with { $0.filter.additionIncludeItems }
        
        let additionTopItems = items.isEmpty ? nil : ShareAdditionItems(items: items, topSeparator: L10n.chatListAddTopSeparator, bottomSeparator: L10n.chatListAddBottomSeparator)
        
        showModal(with: ShareModalController(SelectCallbackObject(context, defaultSelectedIds: Set(stateValue.with { $0.filter.data.includePeers + $0.filter.selectedIncludeItems.map { $0.peer.id } }), additionTopItems: additionTopItems, limit: stateValue.with { maximumPeers - $0.filter.data.includePeers.count }, limitReachedText: L10n.chatListFilterIncludeLimitReached, callback: { peerIds in
            updateState { state in
                var state = state
                
                let categories = peerIds.filter {
                    $0.namespace == ChatListFilterPeerCategories.Namespace
                }
                let peerIds = Set(peerIds).subtracting(categories)
                
                state.withUpdatedFilter { filter in
                    var filter = filter
                    
                    filter.data.includePeers = Array(peerIds.uniqueElements.prefix(maximumPeers))
                    var updatedCats: ChatListFilterPeerCategories = []
                    let cats = categories.map { ChatListFilterPeerCategories(rawValue: $0.id) }
                    for cat in cats {
                        updatedCats.insert(cat)
                    }
                    filter.data.categories = updatedCats
                    return filter
                }
                return state
            }
         //   save(true)
            return .complete()
        })), for: context.window)
    }, addExclude: {
        
        let items = stateValue.with { $0.filter.additionExcludeItems }
        let additionTopItems = items.isEmpty ? nil : ShareAdditionItems(items: items, topSeparator: L10n.chatListAddTopSeparator, bottomSeparator: L10n.chatListAddBottomSeparator)
        
        showModal(with: ShareModalController(SelectCallbackObject(context, defaultSelectedIds: Set(stateValue.with { $0.filter.data.excludePeers + $0.filter.selectedExcludeItems.map { $0.peer.id } }), additionTopItems: additionTopItems, limit: stateValue.with { maximumPeers - $0.filter.data.excludePeers.count }, limitReachedText: L10n.chatListFilterExcludeLimitReached, callback: { peerIds in
            updateState { state in
                var state = state
                state.withUpdatedFilter { filter in
                    var filter = filter
                    
                    let categories = peerIds.filter {
                        $0.namespace == ChatListFilterPeerCategories.Namespace
                    }
                    let peerIds = Set(peerIds).subtracting(categories)
                    filter.data.excludePeers = Array(peerIds.uniqueElements.prefix(maximumPeers))
                    for cat in categories {
                        if ChatListFilterPeerCategories(rawValue: cat.id) == .excludeMuted {
                            filter.data.excludeMuted = true
                        }
                        if ChatListFilterPeerCategories(rawValue: cat.id) == .excludeRead {
                            filter.data.excludeRead = true
                        }
                        if ChatListFilterPeerCategories(rawValue: cat.id) == .excludeArchived {
                            filter.data.excludeArchived = true
                        }
                    }
                    
                    return filter
                }
                return state
            }
            //   save(true)
            return .complete()
        })), for: context.window)
    }, removeIncluded: { peerId in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                filter.data.includePeers.removeAll(where: { $0 == peerId })
                if peerId.namespace == ChatListFilterPeerCategories.Namespace  {
                    filter.data.categories.remove(ChatListFilterPeerCategories(rawValue: peerId.id))
                }
                return filter
            }
            return state
        }
        //save(true)
    }, removeExcluded: { peerId in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                filter.data.includePeers.removeAll(where: { $0 == peerId })
                if peerId.namespace == ChatListFilterPeerCategories.Namespace  {
                    if ChatListFilterPeerCategories(rawValue: peerId.id) == .excludeMuted {
                        filter.data.excludeMuted = false
                    }
                    if ChatListFilterPeerCategories(rawValue: peerId.id) == .excludeRead {
                        filter.data.excludeRead = false
                    }
                    if ChatListFilterPeerCategories(rawValue: peerId.id) == .excludeArchived {
                        filter.data.excludeArchived = false
                    }
                }
                return filter
            }
            return state
        }
        //save(true)
    }, openInfo: { peerId in
        context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
    }, toggleExcludeMuted: { updated in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                filter.data.excludeMuted = updated
                return filter
            }
            return state
        }
       // save(true)
    }, toggleExcludeRead: { updated in
        updateState { state in
            var state = state
            state.withUpdatedFilter { filter in
                var filter = filter
                filter.data.excludeRead = updated
                return filter
            }
            return state
        }
        //save(true)
    }, showAllInclude: {
        updateState { state in
            var state = state
            state.showAllInclude = true
            return state
        }
    }, showAllExclude: {
        updateState { state in
            var state = state
            state.showAllExclude = true
            return state
        }
    })
    
    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, statePromise.get()) |> mapToSignal { _, state -> Signal<(ChatListFiltersListState, ([Peer], [Peer])), NoError> in
        return context.account.postbox.transaction { transaction -> ([Peer], [Peer]) in
            return (state.filter.data.includePeers.compactMap { transaction.getPeer($0) }, state.filter.data.excludePeers.compactMap { transaction.getPeer($0) })
        } |> map {
            (state, $0)
        }
    } |> map {
        return chatListFilterEntries(state: $0, includePeers: $1.0, excludePeers: $1.1, arguments: arguments)
    } |> map {
          return InputDataSignalValue(entries: $0)
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: isNew ? L10n.chatListFilterNewTitle : L10n.chatListFilterTitle, removeAfterDisappear: false)
    
    controller.updateDatas = { data in
        
        if let name = data[_id_name_input]?.stringValue {
            updateState { state in
                var state = state
                state.withUpdatedFilter { filter in
                    var filter = filter
                    filter.title = name
                    return filter
                }
                return state
            }
        }
        
        return .none
    }
    
    controller.backInvocation = { data, f in
        if stateValue.with({ $0.filter != filter }) {
            confirm(for: context.window, header: L10n.chatListFilterDiscardHeader, information: L10n.chatListFilterDiscardText, okTitle: L10n.chatListFilterDiscardOK, cancelTitle: L10n.chatListFilterDiscardCancel, successHandler: { _ in
                f(true)
            })
        } else {
            f(true)
        }
        
    }
    
    controller.updateDoneValue = { data in
        return { f in
            if isNew {
                f(.enabled(L10n.chatListFilterDone))
            } else {
                f(.enabled(L10n.navigationDone))
            }
        }
    }
    
    controller.onDeinit = {
        updateDisposable.dispose()
    }
    
    
    controller.validateData = { data in
        
        return .fail(.doSomething(next: { f in
            let emptyTitle = stateValue.with { $0.filter.title.isEmpty }
            if emptyTitle {
                f(.fail(.fields([_id_name_input : .shake])))
                return
            }
            
            let filter = stateValue.with { $0.filter }
            
            if filter.isFullfilled {
                alert(for: context.window, info: L10n.chatListFilterErrorLikeChats)
            } else if filter.isEmpty {
                alert(for: context.window, info: L10n.chatListFilterErrorEmpty)
                f(.fail(.fields([_id_add_include : .shake])))
            } else {
                _ = showModalProgress(signal: requestUpdateChatListFilter(postbox: context.account.postbox, network: context.account.network, id: filter.id, filter: filter), for: context.window).start(error: { error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: L10n.unknownError)
                    }
                }, completed: {
                    save(false)
                    f(.success(.navigationBack))
                })
            }
            
            
        }))
        
       
    }
    
    return controller
    
}



