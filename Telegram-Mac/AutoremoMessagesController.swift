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


private final class Arguments {
    let context: AccountContext
    let setTimeout:(Int32)->Void
    let clearHistory: ()->Void
    init(context: AccountContext, setTimeout:@escaping(Int32)->Void, clearHistory: @escaping()->Void) {
        self.context = context
        self.setTimeout = setTimeout
        self.clearHistory = clearHistory
    }
}

private struct State : Equatable {
    var autoremoveTimeout: CachedPeerAutoremoveTimeout?
    var timeout: Int32
    let peer: PeerEquatable
}

private let _id_sticker = InputDataIdentifier("_id_sticker")
private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_never = InputDataIdentifier("_id_never")
private let _id_day = InputDataIdentifier("_id_day")
private let _id_week = InputDataIdentifier("_id_week")
private let _id_clear = InputDataIdentifier("_id_clear")
private let _id_global = InputDataIdentifier("_id_global")
private let _id_clear_both = InputDataIdentifier("_id_clear_both")
private func entries(_ state: State, arguments: Arguments, onlyDelete: Bool) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []

    var sectionId:Int32 = 0
    var index: Int32 = 0

//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1

    if state.peer.peer.canClearHistory, !onlyDelete {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_clear, data: .init(name: strings().chatContextClearHistory, color: theme.colors.redUI, icon: theme.icons.destruct_clear_history, type: .none, viewType: .singleItem, enabled: true, action: arguments.clearHistory)))
        index += 1

    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_sticker, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.destructor, text: .init())
        }))
        index += 1

    }


    if state.peer.peer.canManageDestructTimer && state.peer.peer.id != arguments.context.peerId {
        
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().autoremoveMessagesHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: InputDataEquatable(state), comparable: nil, item: { [weak arguments] initialSize, stableId in
            var values:[Int32] = [0, .secondsInDay, .secondsInWeek, .secondsInMonth]

            if !values.contains(state.timeout) {
                values.append(state.timeout)
            }
            values.sort(by: <)
            
            let titles: [String] = values.map { value in
                if value == 0 {
                    return strings().autoremoveMessagesNever
                } else {
                    return autoremoveLocalized(Int(value))
                }
            }

            return SelectSizeRowItem(initialSize, stableId: stableId, current: state.timeout, sizes: values, hasMarkers: false, titles: titles, viewType: .singleItem, selectAction: { index in
                arguments?.setTimeout(values[index])
            })
        }))
        index += 1

        if let _ = state.autoremoveTimeout?.timeout?.peerValue {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().autoremoveMessagesDesc), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
        } else {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().autoremoveMessagesDesc), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
        }

    }
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1


    return entries
}


func AutoremoveMessagesController(context: AccountContext, peer: Peer, onlyDelete: Bool = false) -> InputDataModalController {


    let peerId = peer.id

    let actionsDisposable = DisposableSet()

    let initialState = State(autoremoveTimeout: nil, timeout: 0, peer: PeerEquatable(peer))

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
            thridTitle = strings().chatMessageDeleteForMeAndPerson(peer.displayTitle)
        }
        verifyAlert(for: context.window, information: peer is TelegramUser ? peer.id == context.peerId ? strings().peerInfoConfirmClearHistorySavedMesssages : canRemoveGlobally || peerId.namespace == Namespaces.Peer.SecretChat ? strings().peerInfoConfirmClearHistoryUserBothSides : strings().peerInfoConfirmClearHistoryUser : strings().peerInfoConfirmClearHistoryGroup, ok: strings().peerInfoConfirmClear, option: thridTitle, optionIsSelected: false, successHandler: { result in
            _ = context.engine.messages.clearHistoryInteractively(peerId: peerId, threadId: nil, type: result == .thrid ? .forEveryone : .forLocalPeer).start()
            close?()
        })
    })


    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments, onlyDelete: onlyDelete))
    }

    let controller = InputDataController(dataSignal: signal, title: onlyDelete ? strings().autoremoveMessagesTitleDeleteOnly : strings().autoremoveMessagesTitle, hasDone: false)


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
        updateState { current in
            var current = current
            current.autoremoveTimeout = autoremoveTimeout
            current.timeout = autoremoveTimeout?.timeout?.peerValue ?? 0
            return current
        }
    }))

    controller.validateData = { _ in
        return .fail(.doSomething(next: { f in

            let state = stateValue.with { $0 }

            if let timeout = state.autoremoveTimeout?.timeout?.peerValue {
                if timeout == state.timeout {
                    close?()
                    return
                }
            }

//            var text: String? = nil
//            if state.timeout != 0 {
//                switch state.timeout {
//                case .secondsInDay:
//                    text = strings().tipAutoDeleteTimerSetForDay
//                case .secondsInWeek:
//                    text = strings().tipAutoDeleteTimerSetForWeek
//                default:
//                    break
//                }
//            } else {
//                text = strings().tipAutoDeleteTimerSetOff
//            }
            
            _ = showModalProgress(signal: context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peerId, timeout: state.timeout == 0 ? nil : state.timeout), for: context.window).start(completed: {
                f(.success(.custom({
                   // if let text = text {
                     //   showModalText(for: context.window, text: text)
                   // }
                    close?()
                })))
            })
        }))
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)

    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)

    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })

    close = { [weak modalController] in
        modalController?.modal?.close()
    }


    return modalController

}

