//
//  CallSettingsModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import SwiftSignalKit
import Postbox
import TGUIKit


func CallSettingsModalController(_ sharedContext: SharedAccountContext) -> InputDataModalController {
    
    var close: (()->Void)? = nil

    
    let controller = CallSettingsController(sharedContext: sharedContext)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })

    let modalController = InputDataModalController(controller)

    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
    
}
