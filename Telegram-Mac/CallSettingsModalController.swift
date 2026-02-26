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


func CallSettingsModalController(_ sharedContext: SharedAccountContext, presentation: TelegramPresentationTheme = theme) -> InputDataModalController {
    
    var close: (()->Void)? = nil

    
    let controller = CallSettingsController(sharedContext: sharedContext, presentation: presentation)
    
    controller.getBackgroundColor = {
        return presentation.colors.listBackground
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })

    let modalController = InputDataModalController(controller, presentation: presentation)

    modalController._hasBorder = false
    
    modalController.getModalTheme = {
        .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: .clear, border: .clear, accent: presentation.colors.accent, grayForeground: .clear, activeBackground: presentation.colors.background, activeBorder: presentation.colors.border, listBackground: .clear)
    }
    modalController.getHeaderBorderColor = {
        return presentation.colors.border
    }

    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
    
}
