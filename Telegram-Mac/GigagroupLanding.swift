//
//  GigagroupLanding.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 15.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TGUIKit
import TelegramCore
import Postbox




private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {

}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []

    var sectionId:Int32 = 0
    var index: Int32 = 0


    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("sticker"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: .gigagroup, text: .init())
    }))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1


    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("features"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: strings().broadcastGroupsIntroText, font: .normal(.text))
    }))
    index += 1

    // entries

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

func GigagroupLandingController(context: AccountContext, peerId: PeerId) -> InputDataModalController {

    var close:(()->Void)? = nil

    let actionsDisposable = DisposableSet()

    let initialState = State()

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)

    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: strings().broadcastGroupsIntroTitle)

    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    controller.validateData = { _ in
        verifyAlert_button(for: context.window, header: strings().broadcastGroupsConfirmationAlertTitle, information: strings().broadcastGroupsConfirmationAlertText, ok: strings().broadcastGroupsConfirmationAlertConvert, successHandler: { _ in
            _ = showModalProgress(signal: convertGroupToGigagroup(account: context.account, peerId: peerId), for: context.window).start(error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: strings().unknownError)
                }
            }, completed: {
                showModalText(for: context.window, text: strings().broadcastGroupsSuccess)
                close?()
            })

        }, cancelHandler: {
            
        })
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().broadcastGroupsConvert, accept: { [weak controller] in
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
