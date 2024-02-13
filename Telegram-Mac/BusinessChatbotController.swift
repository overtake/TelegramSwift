//
//  BusinessChatbotController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit

#if DEBUG

private final class Arguments {
    let context: AccountContext
    let toggleAccess:(State.Access)->Void
    let selectChats:()->Void
    let toggleReplyAccess:()->Void
    let removeIncluded:(PeerId)->Void
    init(context: AccountContext, toggleAccess:@escaping(State.Access)->Void, selectChats:@escaping()->Void, toggleReplyAccess:@escaping()->Void, removeIncluded:@escaping(PeerId)->Void) {
        self.context = context
        self.toggleAccess = toggleAccess
        self.selectChats = selectChats
        self.toggleReplyAccess = toggleReplyAccess
        self.removeIncluded = removeIncluded
    }
}

private struct State : Equatable {
    enum Access : Equatable {
        case all
        case selected
    }
    var username: String?
    var access: Access = .all
    
    var replyAccess: Bool = true

    
    var selectedIds: [PeerId] = []
    
    var selectedPeers: [EnginePeer] = []

}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_input = InputDataIdentifier("_id_username")
private let _id_attached_bot = InputDataIdentifier("_id_attached_bot")

private let _id_access_1x1 = InputDataIdentifier("_id_access_1x1")
private let _id_access_selected = InputDataIdentifier("_id_access_selected")

private let _id_include_chats = InputDataIdentifier("_id_include_chats")
private let _id_exclude_chats = InputDataIdentifier("_id_exclude_chats")

private let _id_reply_to_message = InputDataIdentifier("_id_reply_to_message")

private let _id_remove = InputDataIdentifier("_id_remove")


private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let hText = "Add a bot to your account to help you automatically process and respond to the messages you receive. [Learn More >](learnmore)."
    
    let attr = parseMarkdownIntoAttributedString(hText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
        return (NSAttributedString.Key.link.rawValue, contents)
    }))
    entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.fly_dollar, text: attr)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: 0, value: .string(state.username), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: .singleItem, defaultText: ""), placeholder: nil, inputPlaceholder: "Bot Username", filter: { $0 }, limit: 60))

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("CHATS ACCESSIBLE FOR THE BOT"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_access_1x1, data: .init(name: "All 1-to-1 Chats Except...", color: theme.colors.text, type: .selectable(state.access == .all), viewType: .firstItem, action: {
        arguments.toggleAccess(.all)
    })))
    
    entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_access_selected, data: .init(name: "Only Selected Chats", color: theme.colors.text, type: .selectable(state.access == .selected), viewType: .lastItem, action: {
        arguments.toggleAccess(.selected)
    })))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    switch state.access {
    case .all:
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("EXCLUDE CHATS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_exclude_chats, data: .init(name: "Exclude Chats...", color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.selectedPeers.isEmpty ? .singleItem : .firstItem, action: arguments.selectChats)))
        
    case .selected:
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("INCLUDE CHATS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_include_chats, data: .init(name: "Include Chats...", color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.selectedPeers.isEmpty ? .singleItem : .firstItem, action: arguments.selectChats)))
    }
    
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let viewType: GeneralViewType
        let status: String?
    }
    var tuples: [Tuple] = []

    var selectedPeers: [Peer] = []

    let categories = state.selectedIds.filter {
        $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
    }
    for category in categories {
        let cat = ChatListFilterPeerCategories(rawValue: Int32(category.id._internalGetInt64Value()))
        selectedPeers.append(TelegramFilterCategory(category: cat))
    }

    selectedPeers.append(contentsOf: state.selectedPeers.map { $0._asPeer() })


    for (i, peer) in selectedPeers.enumerated() {
        var viewType: GeneralViewType = bestGeneralViewType(selectedPeers, for: i)
        if i == 0 {
            if i < selectedPeers.count - 1 {
                viewType = .innerItem
            } else {
                viewType = .lastItem
            }
        }
        let status: String? = nil
        tuples.append(.init(peer: .init(peer), viewType: viewType, status: nil))
    }

    for tuple in tuples {
        entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_peer(tuple.peer.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), viewType: tuple.viewType, action: {
                //arguments.openInfo(peer.id)
            }, contextMenuItems: {
                return .single([ContextMenuItem("Remove", handler: {
                    arguments.removeIncluded(tuple.peer.id)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
            }, highlightVerified: true)
        }))
    }

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("BOT PERMISSIONS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_reply_to_message, data: .init(name: "Reply to Messages", color: theme.colors.text, type: .switchable(state.replyAccess), viewType: .singleItem, action: arguments.toggleReplyAccess)))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("The bot will be able to view all new incoming messages, but not the messages that had been sent before you added the bot."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
  
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_remove, data: .init(name: "Remove Bot", color: theme.colors.redUI, type: .none, viewType: .singleItem, action: {
       
    })))
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func BusinessChatbotController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let peers: Signal<[EnginePeer], NoError> = statePromise.get() |> map { $0.selectedIds } |> distinctUntilChanged |> mapToSignal { peerIds in
        return context.account.postbox.transaction { transaction -> [EnginePeer] in
            return peerIds.compactMap {
                transaction.getPeer($0)
            }.map {
                .init($0)
            }
        }
    } |> deliverOnMainQueue
    
    actionsDisposable.add(peers.start(next: { peers in
        updateState { current in
            var current = current
            current.selectedPeers = peers
            return current
        }
    }))


    let arguments = Arguments(context: context, toggleAccess: { value in
        updateState { current in
            var current = current
            current.access = value
            return current
        }
    }, selectChats: {
        
        var items: [ShareAdditionItem] = []
        
        items.append(.init(peer: TelegramFilterCategory(category: .contacts), status: ""))
        items.append(.init(peer: TelegramFilterCategory(category: .nonContacts), status: ""))
        
        let additionTopItems = ShareAdditionItems(items: items, topSeparator: "CHAT TYPES", bottomSeparator: "CHATS")

        
        showModal(with: ShareModalController(BusinessSelectChatsCallbackObject(context, defaultSelectedIds: Set(), additionTopItems: additionTopItems, limit: 100, limitReachedText: "Limit reached", callback: { peerIds in
            
//            let categories = peerIds.filter {
//                $0.namespace._internalGetInt32Value() == ChatListFilterPeerCategories.Namespace
//            }
//            let peerIds = Set(peerIds).subtracting(categories)

            updateState { current in
                var current = current
                current.selectedIds = Array(peerIds)
                return current
            }
            
            return .complete()
        }, excludePeerIds: Set([context.peerId]))), for: context.window)
    }, toggleReplyAccess: {
        updateState { current in
            var current = current
            current.replyAccess = !current.replyAccess
            return current
        }
    }, removeIncluded: { peerId in
        updateState { current in
            var current = current
            current.selectedIds.removeAll(where: { $0 == peerId })
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Chat Bot", removeAfterDisappear: false, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}

#endif
