//
//  PollResultController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit


private struct PollResultState : Equatable {
    
}

func PollResultController(context: AccountContext) -> InputDataModalController {

    
    let initialState = PollResultState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((PollResultState) -> PollResultState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let controller = InputDataController(dataSignal: .complete(), title: "Poll Results")
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    let modalController = InputDataModalController(controller)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    

    
    return modalController
}
