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

private extension ChatListFilter {
    var additionIncludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        
        if !self.data.categories.contains(.contacts) {
            items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
        }
        if !self.data.categories.contains(.nonContacts) {
            items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))
        }
        if !self.data.categories.contains(.smallGroups) {
            items.append(.init(peer: TelegramFilterCategory(category: .smallGroups), status: ""))
        }
        if !self.data.categories.contains(.largeGroups) {
            items.append(.init(peer: TelegramFilterCategory(category: .largeGroups), status: ""))
        }
        if !self.data.categories.contains(.channels) {
            items.append(.init(peer: TelegramFilterCategory(category: .channels), status: ""))
        }
        if !self.data.categories.contains(.bots) {
            items.append(.init(peer: TelegramFilterCategory(category: .bots), status: ""))
        }
        return items
    }
    var additionExcludeItems: [ShareAdditionItem] {
        var items:[ShareAdditionItem] = []
        
        if !self.data.excludeMuted {
            items.append(.init(peer: TelegramFilterCategory(category: .excludeMuted), status: ""))
        }
        if !self.data.excludeRead {
            items.append(.init(peer: TelegramFilterCategory(category: .excludeRead), status: ""))
        }
        if !self.data.excludeArchived {
            items.append(.init(peer: TelegramFilterCategory(category: .excludeArchived), status: ""))
        }
        return items
    }
}

extension ChatListFiltersState {
    mutating func withAddedFilter(_ filter: ChatListFilter, onlyReplace: Bool = false) {
        if let index = filters.firstIndex(where: {$0.id == filter.id}) {
            filters[index] = filter
        } else if !onlyReplace {
            filters.append(filter)
        }
    }
    
    mutating func withRemovedFilter(_ filter: ChatListFilter) {
        filters.removeAll(where: {$0.id == filter.id })
    }
    
    mutating func withMoveFilter(_ from: Int, _ to: Int)  {
        filters.insert(filters.remove(at: from), at: to)
    }
}

class SelectCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    init(_ context: AccountContext, excludePeerIds: Set<PeerId>, additionTopItems: ShareAdditionItems?, callback:@escaping([PeerId])->Signal<Never, NoError>) {
        self.callback = callback
        super.init(context, excludePeerIds: excludePeerIds, additionTopItems: additionTopItems)
    }
    
    override var interactionOk: String {
        return L10n.chatListAddSave
    }
    
    override var hasCaptionView: Bool {
        return false
    }
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) -> Signal<Never, String> {
        return callback(peerIds) |> mapError { _ in return String() }
    }
    override var searchPlaceholderKey: String {
        return "ChatList.Add.Placeholder"
    }
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        return !self.excludePeerIds.contains(peer.id)
    }
    
}

private struct ChatListFiltersListState: Equatable {
    var filter: ChatListFilter
    init(filter: ChatListFilter) {
        self.filter = filter
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
    init(context: AccountContext, toggleOption:@escaping(ChatListFilterPeerCategories)->Void, addInclude: @escaping()->Void, addExclude: @escaping()->Void, removeIncluded: @escaping(PeerId)->Void, removeExcluded: @escaping(PeerId)->Void, openInfo: @escaping(PeerId)->Void, toggleExcludeMuted:@escaping(Bool)->Void, toggleExcludeRead: @escaping(Bool)->Void) {
        self.context = context
        self.toggleOption = toggleOption
        self.toggleExcludeMuted = toggleExcludeMuted
        self.toggleExcludeRead = toggleExcludeRead
        self.addInclude = addInclude
        self.addExclude = addExclude
        self.removeIncluded = removeIncluded
        self.removeExcluded = removeExcluded
        self.openInfo = openInfo
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

private func _id_include(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_include_\(peerId)")
}
private func _id_exclude(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_exclude_\(peerId)")
}
private func chatListFilterEntries(state: ChatListFiltersListState, includePeers: [Peer], excludePeers: [Peer], arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var includePeers:[Peer] = includePeers
    
    if state.filter.data.categories.contains(.smallGroups) {
        includePeers.insert(TelegramFilterCategory(category: .smallGroups), at: 0)
    }
    if state.filter.data.categories.contains(.largeGroups) {
        includePeers.insert(TelegramFilterCategory(category: .largeGroups), at: 0)
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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterNameHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.filter.title), error: nil, identifier: _id_name_input, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: L10n.chatListFilterNamePlaceholder, filter: { $0 }, limit: 20))
    index += 1
   
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterIncludeHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_include, equatable: InputDataEquatable(state), item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chatListFilterIncludeAddChat, nameStyle: blueActionButton, type: .none, viewType: includePeers.isEmpty ? .singleItem : .firstItem, action: arguments.addInclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chat_filter_add, textInset: 46, thumbInset: 4))
    }))
    index += 1
    
    
    var fake:[Int] = []
    fake.append(0)
    for (i, _) in includePeers.enumerated() {
        fake.append(i + 1)
    }
    
    for (i, peer) in includePeers.enumerated() {
        
        struct E : Equatable {
            let viewType: GeneralViewType
            let peer: PeerEquatable
        }
        
        let viewType = bestGeneralViewType(fake, for: i + 1)
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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterIncludeDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterExcludeHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_exclude, equatable: InputDataEquatable(state), item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chatListFilterExcludeAddChat, nameStyle: blueActionButton, type: .none, viewType: excludePeers.isEmpty ? .singleItem : .firstItem, action: arguments.addExclude, thumb: GeneralThumbAdditional(thumb: theme.icons.chat_filter_add, textInset: 46, thumbInset: 2))
    }))
    index += 1
    
    
    fake = []
    fake.append(0)
    for (i, _) in excludePeers.enumerated() {
        fake.append(i + 1)
    }
    
    for (i, peer) in excludePeers.enumerated() {
        struct E : Equatable {
            let viewType: GeneralViewType
            let peer: PeerEquatable
        }
        
        let viewType = bestGeneralViewType(fake, for: i + 1)
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
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterExcludeDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChatListFilterController(context: AccountContext, filter: ChatListFilter) -> InputDataController {
    
    
    let initialState = ChatListFiltersListState(filter: filter)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChatListFiltersListState) -> ChatListFiltersListState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let updateDisposable = MetaDisposable()
    
    let save:(Bool)->Void = { replace in
        let filter = stateValue.with { $0.filter }
        
        _ = combineLatest(updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { state in
            var state = state
            state.withAddedFilter(stateValue.with { $0.filter }, onlyReplace: replace)
            return state
        }), replaceRemoteChatListFilters(account: context.account)).start()
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
        
        showModal(with: ShareModalController(SelectCallbackObject(context, excludePeerIds: Set(stateValue.with { $0.filter.data.includePeers }), additionTopItems: additionTopItems, callback: { peerIds in
            updateState { state in
                var state = state
                
                let categories = peerIds.filter {
                    $0.namespace == ChatListFilterPeerCategories.Namespace
                }
                let peerIds = Set(peerIds).subtracting(categories)
                
                state.withUpdatedFilter { filter in
                    var filter = filter
                    filter.data.includePeers = (filter.data.includePeers + peerIds).uniqueElements
                    filter.data.excludePeers.removeAll(where: { peerIds.contains($0) })
                    var updatedCats = filter.data.categories
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
        
        showModal(with: ShareModalController(SelectCallbackObject(context, excludePeerIds: Set(stateValue.with { $0.filter.data.includePeers }), additionTopItems: additionTopItems, callback: { peerIds in
            updateState { state in
                var state = state
                state.withUpdatedFilter { filter in
                    var filter = filter
                    
                    let categories = peerIds.filter {
                        $0.namespace == ChatListFilterPeerCategories.Namespace
                    }
                    let peerIds = Set(peerIds).subtracting(categories)
                    filter.data.excludePeers = (filter.data.excludePeers + peerIds).uniqueElements
                    filter.data.includePeers.removeAll(where: { peerIds.contains($0) })
                    for cat in categories {
                        if ChatListFilterPeerCategories(rawValue: cat.id) == .excludeMuted {
                            filter.data.excludeMuted = true
                        }
                        if ChatListFilterPeerCategories(rawValue: cat.id) == .excludeRead {
                            filter.data.excludeRead = true
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
    })
    
    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, statePromise.get()) |> mapToSignal { _, state -> Signal<(ChatListFiltersListState, [Peer]), NoError> in
        return context.account.postbox.transaction { transaction -> [Peer] in
            return state.filter.data.includePeers.compactMap { transaction.getPeer($0) }
        } |> map {
            (state, $0)
        }
    } |> map {
        return chatListFilterEntries(state: $0, includePeers: $1, excludePeers: $1, arguments: arguments)
    } |> map {
          return InputDataSignalValue(entries: $0)
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.chatListFilterTitle, removeAfterDisappear: false)
    
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
            confirm(for: context.window, header: "Discard Changes", information: "Are you sure you want to discard all changes?", okTitle: "Yes", cancelTitle: "Cancel", successHandler: { _ in
                f(true)
            })
        } else {
            f(true)
        }
        
    }
    
    controller.updateDoneValue = { data in
        return { f in
            if filter.title.isEmpty {
                f(.enabled(L10n.navigationAdd))
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
            
            if !filter.isFullfilled {
                _ = showModalProgress(signal: requestUpdateChatListFilter(account: context.account, id: filter.id, filter: filter), for: context.window).start(error: { error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: L10n.unknownError)
                    }
                }, completed: {
                    save(false)
                    f(.success(.navigationBack))
                })
            } else {
                alert(for: context.window, info: "You can't add filter which concur to all chats. Please try again.")
            }
            
            
        }))
        
       
    }
    
    return controller
    
}




/*
 
 
 
 //    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterCategoriesHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
 //    index += 1
 //
 //
 //
 //    entries.append(.sectionId(sectionId, type: .normal))
 //    sectionId += 1
 //
 
 //    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_exclude_muted, data: .init(name: L10n.chatListFilterExcludeMuted, color: theme.colors.text, type: .switchable(state.filter.data.excludeMuted), viewType: .firstItem, enabled: true, action: {
 //        arguments.toggleExcludeMuted(!state.filter.data.excludeMuted)
 //    })))
 //    index += 1
 //
 //    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_exclude_read, data: .init(name: L10n.chatListFilterExcludeRead, color: theme.colors.text, type: .switchable(state.filter.data.excludeRead), viewType: .lastItem, enabled: true, action: {
 //        arguments.toggleExcludeRead(!state.filter.data.excludeRead)
 //    })))
 //    index += 1
 
 entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_private_chats, data: .init(name: L10n.chatListFilterPrivateChats, color: theme.colors.text, type: .selectable(state.filter.data.categories.contains(.privateChats)), viewType: .firstItem, enabled: true, action: {
 arguments.toggleOption(.privateChats)
 })))
 index += 1
 entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_secret_chats, data: .init(name: L10n.chatListFilterSecretChat, color: theme.colors.text, type: .selectable(state.filter.data.categories.contains(.secretChats)), viewType: .innerItem, enabled: true, action: {
 arguments.toggleOption(.secretChats)
 })))
 index += 1
 entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_public_groups, data: .init(name: L10n.chatListFilterPublicGroups, color: theme.colors.text, type: .selectable(state.filter.data.categories.contains(.publicGroups)), viewType: .innerItem, enabled: true, action: {
 arguments.toggleOption(.publicGroups)
 })))
 index += 1
 entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_private_groups, data: .init(name: L10n.chatListFilterPrivateGroups, color: theme.colors.text, type: .selectable(state.filter.data.categories.contains(.privateGroups)), viewType: .innerItem, enabled: true, action: {
 arguments.toggleOption(.privateGroups)
 })))
 index += 1
 entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_channels, data: .init(name: L10n.chatListFilterChannels, color: theme.colors.text, type: .selectable(state.filter.data.categories.contains(.channels)), viewType: .innerItem, enabled: true, action: {
 arguments.toggleOption(.channels)
 })))
 index += 1
 entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_bots, data: .init(name: L10n.chatListFilterBots, color: theme.colors.text, type: .selectable(state.filter.data.categories.contains(.bots)), viewType: .lastItem, enabled: true, action: {
 arguments.toggleOption(.bots)
 })))
 index += 1
 
 
 */
