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
    let navigation = MajorNavigationController(ChatController.self, ChatController(context: context, chatLocation: location, mode: .preview), context.window)
    navigation.backgroundMode = theme.controllerBackgroundMode
    navigation._frameRect = NSMakeRect(0, 0, 350, context.window.frame.height - 60)
    navigation.canAddControllers = false
    return navigation
}


func ChatListModalPreviewController(context: AccountContext) -> NavigationViewController {
    let navigation = MajorNavigationController(ChatListController.self, ChatListController(context, modal: true, groupId: nil, filterId: nil), context.window)
    navigation._frameRect = NSMakeRect(0, 0, 350, context.window.frame.height - 60)
    navigation.canAddControllers = false
    return navigation
}
