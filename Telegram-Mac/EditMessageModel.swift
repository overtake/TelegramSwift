//
//  EditMessageModel.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
class EditMessageModel: ChatAccessoryModel {
    
    private var account:Account
    private(set) var editMessage:Message
    
    init(message:Message , account:Account) {
        self.account = account
        self.editMessage = message
        super.init()
        make(with :message)
    }

    
    func make(with message:Message) -> Void {
        self.headerAttr = .initialize(string: tr(L10n.chatInputAccessoryEditMessage), color: theme.colors.blueUI, font: .medium(.text))
        self.messageAttr = .initialize(string: pullText(from:message) as String, color: message.media.isEmpty ? theme.colors.text : theme.colors.grayText, font: .normal(.text))
        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
    
    
    
    
}
