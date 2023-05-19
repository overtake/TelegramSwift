//
//  ShareInlineResultNavigationAction.swift
//  TelegramMac
//
//  Created by keepcoder on 13/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit

class ShareInlineResultNavigationAction: NavigationModalAction {

    let payload:String
    init(payload:String, botName:String) {
        self.payload = payload
        super.init(reason: strings().inlineModalActionTitle, desc: strings().inlineModalActionDesc(botName))
    }
    
    override func isInvokable(for value:Any) -> Bool {
        if let value = value as? Peer, value.canSendMessage(false) {
            return true
        }
        return false
    }
    
    override func alertError(for value:Any, with window:Window) -> Void {
        if let _ = value as? Peer {
            alert(for: window, info: strings().alertForwardError)
        }
    }
}
