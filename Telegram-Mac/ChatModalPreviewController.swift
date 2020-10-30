//
//  ChatModalPreviewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


func ChatModalPreviewController(location: ChatLocation, context: AccountContext) -> NavigationViewController {
    
    let navigation = NavigationViewController(ChatController(context: context, chatLocation: location, mode: .preview), context.window)
    navigation._frameRect = NSMakeRect(0, 0, 350, context.window.frame.height - 60)
    navigation.canAddControllers = false
    return navigation
    
}
