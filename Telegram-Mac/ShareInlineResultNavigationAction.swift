//
//  ShareInlineResultNavigationAction.swift
//  TelegramMac
//
//  Created by keepcoder on 13/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

class ShareInlineResultNavigationAction: NavigationModalAction {

    let payload:String
    init(payload:String, botName:String) {
        self.payload = payload
        super.init(reason: tr(L10n.inlineModalActionTitle), desc: tr(L10n.inlineModalActionDesc(botName)))
    }
    
    override func isInvokable(for value:Any) -> Bool {
        if let value = value as? Peer, value.canSendMessage {
            return true
        }
        return false
    }
    
    override func alertError(for value:Any, with window:Window) -> Void {
        if let _ = value as? Peer {
            alert(for: window, info: tr(L10n.alertForwardError))
        }
    }
}
