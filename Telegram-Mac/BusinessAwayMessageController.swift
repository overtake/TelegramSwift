//
//  BusinessAwayMessageController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit

class BusinessSelectChatsCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    private let limitReachedText: String
    init(_ context: AccountContext, defaultSelectedIds: Set<PeerId>, additionTopItems: ShareAdditionItems?, limit: Int?, limitReachedText: String, callback:@escaping([PeerId])->Signal<Never, NoError>, excludePeerIds: Set<PeerId> = Set()) {
        self.callback = callback
        self.limitReachedText = limitReachedText
        super.init(context, excludePeerIds: excludePeerIds, defaultSelectedIds: defaultSelectedIds, additionTopItems: additionTopItems, limit: limit)
    }
    
    override var selectTopics: Bool {
        return false
    }
    
    override var hasFolders: Bool {
        return false
    }
    
    override var hasCaptionView: Bool {
        return false
    }
    override var blockCaptionView: Bool {
        return true
    }
    
    override func statusStyle(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> ControlStyle {
        return ControlStyle(font: .normal(.text), foregroundColor: theme.colors.grayText)
    }
    
//    override func statusString(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> String? {
//        <#code#>
//    }
    
    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        return callback(peerIds) |> castError(String.self)
    }
    override func limitReached() {
        alert(for: context.window, info: limitReachedText)
    }
    override var searchPlaceholderKey: String {
        return "ChatList.Add.Placeholder"
    }
    override var interactionOk: String {
        return strings().chatListFilterAddDone
    }
    override var alwaysEnableDone: Bool {
        return true
    }
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        if peer is TelegramSecretChat {
            return false
        }
        if excludePeerIds.contains(peer.id) {
            return false
        }
        return peer.isUser && !peer.isBot
    }
    
}


private final class Arguments {
    let context: AccountContext
    let toggleEnabled:()->Void
    let createMessage:()->Void
    let toggleSchedule:(State.Schedule)->Void
    let toggleRecepient:(State.Recepient)->Void
    let selectScheduleStart:(Date, Date)->Void
    let selectScheduleEnd:(Date, Date)->Void
    let selectChats:()->Void
    let removeIncluded:(PeerId)->Void
    init(context: AccountContext, toggleEnabled:@escaping()->Void, createMessage:@escaping()->Void, toggleSchedule:@escaping(State.Schedule)->Void, toggleRecepient:@escaping(State.Recepient)->Void, selectScheduleStart:@escaping(Date, Date)->Void, selectScheduleEnd:@escaping(Date, Date)->Void, selectChats:@escaping()->Void, removeIncluded:@escaping(PeerId)->Void) {
        self.context = context
        self.toggleEnabled = toggleEnabled
        self.createMessage = createMessage
        self.toggleSchedule = toggleSchedule
        self.toggleRecepient = toggleRecepient
        self.selectScheduleStart = selectScheduleStart
        self.selectScheduleEnd = selectScheduleEnd
        self.selectChats = selectChats
        self.removeIncluded = removeIncluded
    }
}

private struct State : Equatable {
    
    enum Recepient : Equatable {
        case all
        case selected
    }
    
    enum Schedule : Equatable {
        case alwaysSend
        case outsideWorking
        case custom(from: Date, to: Date)
        
        var isCustom: Bool {
            if case .custom = self {
                return true
            }
            return false
        }
    }
    
    var enabled: Bool = false
    
    var schedule: Schedule = .alwaysSend
    var recepient: Recepient = .all
    
    var selectedIds: [PeerId] = []
    
    var selectedPeers: [EnginePeer] = []
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_enabled = InputDataIdentifier("_id_enabled")

private let _id_create_message = InputDataIdentifier("_id_create_message")
private let _id_message = InputDataIdentifier("_id_message")

private let _id_schedule_always = InputDataIdentifier("_id_schedule_always")
private let _id_schedule_outside = InputDataIdentifier("_id_schedule_outside")
private let _id_schedule_custom = InputDataIdentifier("_id_schedule_custom")


private let _id_recepient_1x1 = InputDataIdentifier("_id_recepient_1x1")
private let _id_recepient_selected = InputDataIdentifier("_id_recepient_selected")

private let _id_start_time = InputDataIdentifier("_id_start_time")
private let _id_end_time = InputDataIdentifier("_id_end_time")


private let _id_include_chats = InputDataIdentifier("_id_include_chats")
private let _id_exclude_chats = InputDataIdentifier("_id_exclude_chats")

private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.fly_dollar, text: .initialize(string: "Automatically reply with a message when you are away.", color: theme.colors.listGrayText, font: .normal(.text)))
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: "Send Away Message", color: theme.colors.text, type: .switchable(state.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
  
    // entries
    
    if state.enabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("AWAY MESSAGE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_create_message, data: .init(name: "Create an Away Message", color: theme.colors.accent, icon: theme.icons.create_new_message_general, type: .next, viewType: .singleItem, action: arguments.createMessage)))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("SCHEDULE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule_always, data: .init(name: "Always Send", color: theme.colors.text, type: .selectable(state.schedule == .alwaysSend), viewType: .firstItem, action: {
            arguments.toggleSchedule(.alwaysSend)
        })))
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule_outside, data: .init(name: "Outside of Business Hours", color: theme.colors.text, type: .selectable(state.schedule == .outsideWorking), viewType: .innerItem, action: {
            arguments.toggleSchedule(.outsideWorking)
        })))

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule_custom, data: .init(name: "Custom Schedule", color: theme.colors.text, type: .selectable(state.schedule.isCustom), viewType: .lastItem, action: {
            arguments.toggleSchedule(.custom(from: Date(), to: Date(timeIntervalSinceNow: TimeInterval(Int32.secondsInWeek))))

        })))
        
        switch state.schedule {
        case let .custom(from, to):
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            let fromString = stringForMediumDate(timestamp: Int32(from.timeIntervalSince1970))
            let toString = stringForMediumDate(timestamp: Int32(to.timeIntervalSince1970))
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_start_time, data: .init(name: "Start Time", color: theme.colors.text, type: .nextContext(fromString), viewType: .firstItem, action: {
                arguments.selectScheduleStart(from, to)
            })))
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_end_time, data: .init(name: "End Time", color: theme.colors.text, type: .nextContext(toString), viewType: .lastItem, action: {
                arguments.selectScheduleEnd(from, to)
            })))
        default:
            break
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("RECIPIENTS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_recepient_1x1, data: .init(name: "All 1-to-1 Chats Except...", color: theme.colors.text, type: .selectable(state.recepient == .all), viewType: .firstItem, action: {
            arguments.toggleRecepient(.all)
        })))
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_recepient_selected, data: .init(name: "Only Selected Chats", color: theme.colors.text, type: .selectable(state.recepient == .selected), viewType: .lastItem, action: {
            arguments.toggleRecepient(.selected)
        })))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        switch state.recepient {
        case .all:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("EXCLUDE CHATS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_exclude_chats, data: .init(name: "Exclude Chats...", color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.selectedPeers.isEmpty ? .singleItem : .firstItem, action: arguments.selectChats)))
            
        case .selected:
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain("INCLUDE CHATS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_include_chats, data: .init(name: "Include Chats...", color: theme.colors.accent, icon: theme.icons.chat_filter_add, type: .none, viewType: state.selectedPeers.isEmpty ? .singleItem : .firstItem, action: arguments.selectChats)))
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
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(tuple.peer.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), viewType: tuple.viewType, action: {
                    //arguments.openInfo(peer.id)
                }, contextMenuItems: {
                    return .single([ContextMenuItem("Remove", handler: {
                        arguments.removeIncluded(tuple.peer.id)
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
                }, highlightVerified: true)
            }))
        }
    }
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func BusinessAwayMessageController(context: AccountContext, peerId: PeerId) -> InputDataController {

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

    let arguments = Arguments(context: context, toggleEnabled: {
        updateState { current in
            var current = current
            current.enabled = !current.enabled
            return current
        }
    }, createMessage: {
        
    }, toggleSchedule: { schedule in
        updateState { current in
            var current = current
            current.schedule = schedule
            return current
        }
    }, toggleRecepient: { recepient in
        updateState { current in
            var current = current
            current.recepient = recepient
            return current
        }
    }, selectScheduleStart: { from, to in
        showModal(with: DateSelectorModalController(context: context, defaultDate: from, mode: .date(title: "Schedule Start", doneTitle: strings().modalDone), selectedAt: { updated in
            updateState { current in
                var current = current
                current.schedule = .custom(from: updated, to: to)
                return current
            }
        }), for: context.window)
    }, selectScheduleEnd: { from, to in
        showModal(with: DateSelectorModalController(context: context, defaultDate: to, mode: .date(title: "Schedule End", doneTitle: strings().modalDone), selectedAt: { updated in
            updateState { current in
                var current = current
                current.schedule = .custom(from: from, to: updated)
                return current
            }
        }), for: context.window)
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
    }, removeIncluded: { peerId in
        updateState { current in
            var current = current
            current.selectedIds.removeAll(where: { $0 == peerId })
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), grouping: false)
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Away Message", removeAfterDisappear: false, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
