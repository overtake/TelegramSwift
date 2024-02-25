//
//  ChatAdditionController.swift
//  Telegram
//
//  Created by keepcoder on 22/09/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore

class ChatAdditionController: ChatController {
    override init(context: AccountContext, chatLocation: ChatLocation, mode: ChatMode = .history, focusTarget: ChatFocusTarget? = nil, initialAction: ChatInitialAction? = nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>? = nil) {
        super.init(context: context, chatLocation: chatLocation, mode: mode, focusTarget: focusTarget, initialAction: initialAction, chatLocationContextHolder: chatLocationContextHolder)
    }
}
