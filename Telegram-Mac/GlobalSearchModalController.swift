//
//  GlobalSearchModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox

private final class GlobalSearchArguments {
    let context: AccountContext
    let openInfo: (Peer, MessageId?) -> Void
    init(context: AccountContext, openInfo: @escaping(Peer, MessageId?) -> Void) {
        self.context = context
        self.openInfo = openInfo
    }
}

private struct GlobalSearchState : Equatable {
    static func == (lhs: GlobalSearchState, rhs: GlobalSearchState) -> Bool {
        if let lhsSearchResult = lhs.searchResult, let rhsSearchResult = rhs.searchResult {
            if lhsSearchResult.messages.count != rhsSearchResult.messages.count {
                return false
            } else {
                for (i, lhsMessage) in rhsSearchResult.messages.enumerated() {
                    if !isEqualMessages(lhsMessage, rhsSearchResult.messages[i]) {
                        return false
                    }
                }
                if lhsSearchResult.completed != rhsSearchResult.completed {
                    return false
                }
                if lhsSearchResult.readStates != rhsSearchResult.readStates {
                    return false
                }
            }
        } else if (lhs.searchResult != nil) != (rhs.searchResult != nil) {
            return false
        }
        
        return lhs.isLoading == rhs.isLoading && lhs.searchState == rhs.searchState
    }
    
    var isLoading: Bool = false
    var searchState: SearchMessagesState?
    var searchResult: SearchMessagesResult?
    var query: String = ""
}

private func _id_message(_ id: MessageIndex) -> InputDataIdentifier {
    return InputDataIdentifier("_id_message_\(id)")
}

private func globalSearchEntries(state: GlobalSearchState, arguments: GlobalSearchArguments) -> [InputDataEntry] {
    
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(50)))
    sectionId += 1
    
    if let result = state.searchResult {
        if !result.messages.isEmpty {
            
            let mapped = result.messages.map { message -> MessageHistoryEntry in
                let randomId = arc4random()
                return MessageHistoryEntry(message: message.withUpdatedStableId(randomId), isRead: result.readStates[message.id.peerId]?.isOutgoingMessageIndexRead(MessageIndex(message)) ?? false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false))
            }
            let _messageEntries = messageEntries(mapped, dayGrouping: true, renderType: theme.bubbled ? .bubble : .list, searchState: SearchMessagesResultState(state.query, result.messages))
            
            let interactions = ChatInteraction(chatLocation: .peer(PeerId(0)), context: arguments.context, mode: .history, isLogInteraction: true, disableSelectAbility: true, isGlobalSearchMessage: true)
            
            
            interactions.openInfo = { peerId, _, postId, _ in
                let message = mapped.first(where: { $0.message.id == postId})
                if let peer = message?.message.peers[peerId] {
                    arguments.openInfo(peer, postId)
                }
            }
            
            for entry in _messageEntries {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_message(entry.index), equatable: nil, item: { initialSize, stableId in
                    let item:TableRowItem
                    switch entry {
                    case .DateEntry:
                        item = ChatDateStickItem(initialSize, entry, interaction: interactions, theme: theme)
                    default:
                        item = ChatRowItem.item(initialSize, from: entry, interaction: interactions, theme: theme)
                    }
                    _ = item.makeSize(initialSize.width, oldWidth: 0)
                    return item
                }))
                index += 1
            }
        }
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

func GlobalSearchModalController(context: AccountContext) -> ViewController {
    
    var close: (()->Void)? = nil

    
    let arguments = GlobalSearchArguments(context: context, openInfo: { peer, messageId in
        close?()
        let signal = context.account.postbox.transaction { transaction -> Void in
            updatePeers(transaction: transaction, peers: [peer], update: { _, _ in
                return peer
            })
        } |> deliverOnMainQueue
        _ = signal.start(completed: {
            context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peer.id), messageId: messageId))
        })
    })
    
    let initialState = GlobalSearchState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((GlobalSearchState) -> GlobalSearchState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let searchDisposable = MetaDisposable()
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: globalSearchEntries(state: state, arguments: arguments), searchState: .visible(.init(cancelImage: nil, cancel: {
            
        }, updateState: { searchState in
            switch searchState.state {
            case .None:
               break
            case .Focus:
                break
            }
            if !searchState.request.isEmpty {
                updateState { state in
                    var state = state
                    state.isLoading = true
                    state.query = searchState.request
                    state.searchState = nil
                    return state
                }
                let signal = searchMessages(account: context.account, location: .general(tags: nil, minDate: nil, maxDate: nil), query: "#g c:ru minviews:100 \(searchState.request)", state: stateValue.with { $0.searchState }, limit: 100) |> deliverOnMainQueue
                
                searchDisposable.set(signal.start(next: { searchResult, searchState in
                    updateState { state in
                        var state = state
                        state.searchState = searchState
                        state.searchResult = searchResult
                        state.isLoading = false
                        return state
                    }
                }))
            } else {
                updateState { state in
                    var state = state
                    state.isLoading = false
                    state.query = searchState.request
                    return state
                }
                searchDisposable.set(nil)
            }

        })))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Global Search", hasDone: false)
    
    controller.onDeinit = {
        searchDisposable.dispose()
    }
    
    
    controller.getBackgroundColor = {
        return .clear
    }
    
    controller.didLoaded = { controller, _ in
        controller.genericView.backgroundMode = theme.backgroundMode
        controller.genericView.tableView.setIsFlipped(true)
    }
    
    controller.updateDatas = { data in
        updateState { state in
            return state
        }
        return .none
    }
    
    return controller
}
