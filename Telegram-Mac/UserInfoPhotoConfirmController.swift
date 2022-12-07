//
//  UserInfoPhotoConfirmController.swift
//  Telegram
//
//  Created by Mike Renoir on 07.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    static func == (lhs: State, rhs: State) -> Bool {
        if lhs.user != rhs.user {
            return false
        }
        if lhs.thumb != rhs.thumb {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        
        return true
    }
    
    var user: TelegramUser?
    var type: UserInfoArguments.SetPhotoType
    var thumb: URL?
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let user = state.user, let thumb = state.thumb {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return UserInfoSuggestPhotoItem(initialSize, context: arguments.context, stableId: stableId, user: user, thumb: thumb, type: state.type, viewType: .singleItem)
        }))
        index += 1
    }
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}



func UserInfoPhotoConfirmController(context: AccountContext, peerId: PeerId, thumb: Signal<URL, NoError>, type: UserInfoArguments.SetPhotoType, confirm:@escaping()->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    
    let initialState = State(type: type)
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil
    
    let dataSignal = combineLatest(getPeerView(peerId: peerId, postbox: context.account.postbox), thumb)
    
    actionsDisposable.add(dataSignal.start(next: { peer, thumb in
        updateState { current in
            var current = current
            current.user = peer as? TelegramUser
            current.thumb = thumb
            return current
        }
    }))

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let titleText: String
    switch type {
    case .suggest:
        titleText = strings().userInfoSuggestTitle
    case .set:
        titleText = strings().userInfoSetPhotoTitle
    }
    
    let controller = InputDataController(dataSignal: signal, title: titleText)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        confirm()
        close?()
        return .none
    }
    
    let okText: String
    switch type {
    case .suggest:
        okText = strings().userInfoSuggestConfirmOK
    case .set:
        okText = strings().userInfoSetPhotoConfirmOK
    }

    let modalInteractions = ModalInteractions(acceptTitle: okText, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}


