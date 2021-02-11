//
//  AutoremoMessagesController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import SyncCore

private final class Arguments {
    let context: AccountContext
    let setTimeout:(Int32)->Void
    let clearHistory: ()->Void
    let toggleGlobal:()->Void
    init(context: AccountContext, setTimeout:@escaping(Int32)->Void, clearHistory: @escaping()->Void, toggleGlobal: @escaping()->Void) {
        self.context = context
        self.setTimeout = setTimeout
        self.clearHistory = clearHistory
        self.toggleGlobal = toggleGlobal
    }
}

private struct State : Equatable {
    var autoremoveTimeout: CachedPeerAutoremoveTimeout?
    var isGlobal: Bool
    var timeout: Int32
    let peer: PeerEquatable
}


private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_never = InputDataIdentifier("_id_never")
private let _id_day = InputDataIdentifier("_id_day")
private let _id_week = InputDataIdentifier("_id_week")
private let _id_clear = InputDataIdentifier("_id_clear")
private let _id_global = InputDataIdentifier("_id_global")
private let _id_clear_both = InputDataIdentifier("_id_clear_both")
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []

    var sectionId:Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    if state.peer.peer.canClearHistory {
//        var thridTitle: String? = nil
//        if state.peer.peer.id.namespace == Namespaces.Peer.CloudUser && state.peer.peer.id != arguments.context.account.peerId && !state.peer.peer.isBot {
//            if arguments.context.limitConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
//                thridTitle = L10n.chatMessageDeleteForMeAndPerson(state.peer.peer.displayTitle)
//            }
//        }
//
//        let peer = state.peer.peer
//        let context = arguments.context
//
//        let header = peer is TelegramUser ? peer.id == context.peerId ? L10n.peerInfoConfirmClearHistorySavedMesssages : thridTitle != nil || peer.id.namespace == Namespaces.Peer.SecretChat ? L10n.peerInfoConfirmClearHistoryUserBothSides : L10n.peerInfoConfirmClearHistoryUser : L10n.peerInfoConfirmClearHistoryGroup
//
//        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(header), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
//        index += 1


        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_clear, data: .init(name: L10n.chatContextClearHistory, color: theme.colors.redUI, icon: theme.icons.destruct_clear_history, type: .none, viewType: .singleItem, enabled: true, action: arguments.clearHistory)))
        index += 1

//
//        if let thridTitle = thridTitle {
//            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_clear_both, data: .init(name: thridTitle, color: theme.colors.text, type: .switchable(false), viewType: .lastItem, enabled: true, action: arguments.clearHistory)))
//            index += 1
//        }

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

    }


    if state.peer.peer.canManageDestructTimer {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoremoveMessagesHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: InputDataEquatable(state), item: { [weak arguments] initialSize, stableId in
            let values:[Int32] = [.secondsInDay, .secondsInWeek, 0]

            var dotted: [Int] = []
            if let autoremoveTimeout = state.autoremoveTimeout, let peerValue = autoremoveTimeout.timeout?.peerValue {
                switch peerValue {
                case .secondsInDay:
                    dotted = [1, 2]
                case .secondsInWeek:
                    dotted = [2]
                default:
                    break
                }
            }

            return SelectSizeRowItem(initialSize, stableId: stableId, current: state.timeout, sizes: values, hasMarkers: false, titles: [L10n.autoremoveMessagesDay, L10n.autoremoveMessagesWeek, L10n.autoremoveMessagesNever], dottedIndexes: dotted, viewType: .singleItem, selectAction: { index in
                arguments?.setTimeout(values[index])
            })
        }))
        index += 1

        if let peerValue = state.autoremoveTimeout?.timeout?.peerValue {

            let text: String
            switch peerValue {
            case .secondsInWeek:
                text = L10n.autoremoveMessagesGlobalWeek(state.peer.peer.displayTitle)
            case .secondsInDay:
                text = L10n.autoremoveMessagesGlobalDay(state.peer.peer.displayTitle)
            default:
                text = ""
            }

            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(text), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
        } else {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoremoveMessagesDesc), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
        }

        if state.peer.peer.isUser {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1


            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_global, data: .init(name: L10n.autoremoveMessagesAlsoFor(state.peer.peer.compactDisplayTitle), color: theme.colors.text, type: .switchable(state.isGlobal), viewType: .singleItem, enabled: true, action: arguments.toggleGlobal)))
            index += 1

        }

        
    }
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1


    return entries
}

/*

 */

func AutoremoveMessagesController(context: AccountContext, peer: Peer) -> InputDataModalController {


    let peerId = peer.id

    let actionsDisposable = DisposableSet()

    let initialState = State(autoremoveTimeout: nil, isGlobal: false, timeout: 0, peer: PeerEquatable(peer))

    var close:(()->Void)? = nil

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, setTimeout: { timeout in
        updateState { current in
            var current = current
            current.timeout = timeout
            return current
        }
    }, clearHistory: {
        var thridTitle: String? = nil
        var canRemoveGlobally: Bool = false
        if peerId.namespace == Namespaces.Peer.CloudUser && peerId != context.account.peerId && !peer.isBot {
            if context.limitConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                canRemoveGlobally = true
            }
        }
        if canRemoveGlobally {
            thridTitle = L10n.chatMessageDeleteForMeAndPerson(peer.displayTitle)
        }
        modernConfirm(for: context.window, account: context.account, peerId: peer.id, information: peer is TelegramUser ? peer.id == context.peerId ? L10n.peerInfoConfirmClearHistorySavedMesssages : canRemoveGlobally || peerId.namespace == Namespaces.Peer.SecretChat ? L10n.peerInfoConfirmClearHistoryUserBothSides : L10n.peerInfoConfirmClearHistoryUser : L10n.peerInfoConfirmClearHistoryGroup, okTitle: L10n.peerInfoConfirmClear, thridTitle: thridTitle, thridAutoOn: false, successHandler: { result in

            context.chatUndoManager.clearHistoryInteractively(postbox: context.account.postbox, peerId: peerId, type: result == .thrid ? .forEveryone : .forLocalPeer)
            close?()
        })
    }, toggleGlobal: {

        updateState { state in
            var state = state
            state.isGlobal.toggle()
            return state
        }
    })


    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: L10n.autoremoveMessagesTitle, hasDone: false)


    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    actionsDisposable.add(context.account.viewTracker.peerView(peer.id).start(next: { peerView in
        let autoremoveTimeout: CachedPeerAutoremoveTimeout?
        if let cachedData = peerView.cachedData as? CachedGroupData {
            autoremoveTimeout = cachedData.autoremoveTimeout
        } else if let cachedData = peerView.cachedData as? CachedChannelData {
            autoremoveTimeout = cachedData.autoremoveTimeout
        } else if let cachedData = peerView.cachedData as? CachedUserData {
            autoremoveTimeout = cachedData.autoremoveTimeout
        } else {
            autoremoveTimeout = nil
        }
        var isGlobal: Bool = false
        if let autoremoveTimeout = autoremoveTimeout {
            switch autoremoveTimeout {
            case let .known(timeout):
                if let timeout = timeout {
                    isGlobal = timeout.isGlobal
                }
            default:
                break
            }
        }
        updateState { current in
            var current = current
            current.autoremoveTimeout = autoremoveTimeout
            current.isGlobal = isGlobal
            current.timeout = autoremoveTimeout?.timeout?.myValue ?? 0
            return current
        }
    }))

    controller.validateData = { _ in
        return .fail(.doSomething(next: { f in

            let state = stateValue.with { $0 }

            if let timeout = state.autoremoveTimeout {
                if timeout.timeout?.myValue == state.timeout && timeout.timeout?.isGlobal == state.isGlobal {
                    close?()
                    return
                }
            }

            _ = showModalProgress(signal: setChatMessageAutoremoveTimeoutInteractively(account: context.account, peerId: peerId, timeout: state.timeout == 0 ? nil : state.timeout, isGlobal: state.isGlobal), for: context.window).start(completed: {
                f(.success(.custom({
                    _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                    close?()
                })))
            })
        }))
    }

    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)

    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)

    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })

    close = { [weak modalController] in
        modalController?.modal?.close()
    }


    return modalController

}

