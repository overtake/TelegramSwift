//
//  SavedPeersController.swift
//  Telegram
//
//  Created by Mike Renoir on 22.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore

private final class Arguments {
    let context: AccountContext
    let open:(Int64)->Void
    init(context: AccountContext, open:@escaping(Int64)->Void) {
        self.open = open
        self.context = context
    }
}

private struct State : Equatable {
    static func == (lhs: State, rhs: State) -> Bool {
        return lhs.isLoading == rhs.isLoading && lhs.view?.list.items == rhs.view?.list.items && lhs.search == rhs.search
    }
    
    var view: ChatListViewUpdate?
    var search: [EnginePeer]?
    var isLoading: Bool = false
}

private func _id_item(_ item: EngineChatList.Item) -> InputDataIdentifier {
    return .init("_id_\(item.id)")
//    if let peer = item.peer {
//        return .init("_id_peer_\(ite)")
//    } else {
//        return .init("anonymous")
//    }
}

private func _id_search(_ peerId: PeerId) -> InputDataIdentifier {
    return .init("_id_\(peerId.toInt64())")
//    if let peer = item.peer {
//        return .init("_id_peer_\(ite)")
//    } else {
//        return .init("anonymous")
//    }
}



private final class TableDelegate : TableViewDelegate {
    
    private let arguments: Arguments
    init(_ arguments: Arguments) {
        self.arguments = arguments
    }
    
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
       
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        
        
        if let item = item as? ChatListRowItem, let threadId = item.message?.threadId {
            arguments.open(threadId)
            return true
        }
        if let item = item as? ShortPeerRowItem {
            arguments.open(item.peerId.toInt64())
            return true
        }
        
        
        return false
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return item is ChatListRowItem || item is ShortPeerRowItem
    }
    
    
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
      
    struct Tuple : Equatable {
        let item: EngineChatList.Item
        let viewType: GeneralViewType
    }
    if let peers = state.search {
        if !peers.isEmpty {
            for peer in peers {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_search(peer.id), equatable: .init(peer), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: peer._asPeer(), account: arguments.context.account, context: arguments.context, height: 40, photoSize: NSMakeSize(30, 30), drawLastSeparator: true, viewType: .legacy, action: {
                        
                    }, highlightVerified: true)
                }))
            }
        } else {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("empty_search"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return SearchEmptyRowItem(initialSize, stableId: stableId)
            }))
        }
        
    } else  if let entry = state.view?.list {
        var items: [Tuple] = []
        for item in entry.items.reversed() {
            items.append(.init(item: item, viewType: .singleItem))
        }
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_item(item.item), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                let stableId: UIChatListEntryId = .savedMessageIndex(item.item.id)
                
                return ChatListRowItem(initialSize, context: arguments.context, stableId: stableId, mode: .savedMessages(item.item.renderedPeer.peerId.toInt64()), messages: item.item.messages.map { $0._asMessage() }, index: nil, readState: nil, draft: nil, pinnedType: item.item.chatListIndex.pinningIndex != nil ? .some : .none, renderedPeer: item.item.renderedPeer, peerPresence: nil, forumTopicData: nil, forumTopicItems: [], activities: [], highlightText: nil, associatedGroupId: .root, isMuted: item.item.isMuted, filter: .allChats, hideStatus: nil, titleMode: .normal, appearMode: .normal)
            }))
        }
    }
    
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    
    return entries
}

func SavedPeersController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let reorderDisposable = MetaDisposable()
    actionsDisposable.add(reorderDisposable)
    
    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let view = chatListViewForLocation(chatListLocation: .savedMessagesChats(peerId: context.peerId), location: .Initial(0, nil), filter: nil, account: context.account)
    
    actionsDisposable.add(view.start(next: { view in
        updateState { current in
            var current = current
            current.view = view
            return current
        }
    }))

    let arguments = Arguments(context: context, open: { threadId in
        let messageId = makeThreadIdMessageId(peerId: context.peerId, threadId: threadId)
        let threadMessage = ChatReplyThreadMessage(peerId: context.peerId, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: false, isMonoforumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false)
        
        let controller = ChatAdditionController(context: context, chatLocation: .thread(threadMessage), mode: .thread(mode: .savedMessages(origin: messageId)))
        context.bindings.rootNavigation().push(controller)
    })
    
    let delegate = TableDelegate(arguments)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    let search = InputDataMediaSearchContext()
    
    controller.contextObject = search
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    controller.didLoad = { controller, _ in
        controller.tableView.delegate = delegate
    }
    
    controller.didDisappear = { controller in
        controller.tableView.cancelSelection()
    }
    
    controller.afterTransaction = { controller in
        var pinnedCount: Int = 0
        controller.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem, item.isFixedItem else {return false}
            if item.canResortPinned {
                pinnedCount += 1
            }
            return item.isFixedItem
        }
        
        controller.tableView.resortController = TableResortController(resortRange: NSMakeRange(0, pinnedCount), start: { row in
            
        }, resort: { row in
            
        }, complete: { [weak controller] from, to in
            var items:[Int64] = []

            var offset: Int = 0
                       
            controller?.tableView.enumerateItems { item -> Bool in
                guard let item = item as? ChatListRowItem else {
                    offset += 1
                    return true
                }
                if item.isAd {
                    offset += 1
                }
                switch item.pinnedType {
                case .some, .last:
                    if let threadId = item.mode.threadId {
                        items.append(threadId)
                    }
                default:
                    break
                }
               
                return item.isFixedItem || item.groupId != .root
            }
            items.move(at: from - offset, to: to - offset)
            let signal = context.engine.peers.setForumChannelPinnedTopics(id: context.peerId, threadIds: items) |> deliverOnMainQueue
            reorderDisposable.set(signal.start())

        })}
    
    struct Tuple {
        let peers: [EnginePeer]?
        let searchState: SearchState
    }
    
    let searchResult:Signal<Tuple, NoError> = search.searchState.get() |> mapToSignal { state in
        if state.request.isEmpty {
            return .single(.init(peers: nil, searchState: state))
        } else {
            return context.engine.messages.searchLocalSavedMessagesPeers(query: state.request, indexNameMapping: [:])
            |> map(Optional.init)
            |> map { .init(peers: $0, searchState: state) }
        }
    } |> deliverOnMainQueue
    
    actionsDisposable.add(searchResult.startStrict(next: { result in
        updateState { current in
            var current = current
            current.search = result.peers
            return current
        }
        search.mediaSearchState.set(.init(state: result.searchState, animated: true, isLoading: false))
        search.inSearch = result.searchState.state == .Focus
    }))

    return controller
    
}

