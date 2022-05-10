//
//  PremiumBoardingController.swift
//  Telegram
//
//  Created by Mike Renoir on 10.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

enum PremiumValue : String {
    case limits
    case fileSize
    case downloadSpeed
    case noAds
    case uniqueReactions
    case premiumStickers
    case profileBadge
    case animatedProfilePicture
}

private struct State : Equatable {
        var values:[PremiumValue] = [.limits, .fileSize, .downloadSpeed, .noAds, .uniqueReactions, .premiumStickers, .profileBadge, .animatedProfilePicture]
}



private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    for value in state.values {
        //entries.append(<#T##newElement: InputDataEntry##InputDataEntry#>)
    }
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PremiumBoardingController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Telegram Premium")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalController = InputDataModalController(controller)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    return modalController
}





