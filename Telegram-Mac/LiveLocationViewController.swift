//
//  LiveLocationViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import MapKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox


private struct LiveLocationState : Equatable {
    
}

func liveLocationPreview(_ context: AccountContext) -> InputDataModalController {
    
    let initialState = LiveLocationState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((LiveLocationState) -> LiveLocationState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: [])
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Live Location")
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: "Save", accept: {
        close?()
    }, height: 50, singleButton: true)
    
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        
        return .none
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(300, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
