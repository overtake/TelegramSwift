//
//  FWDNavigationAction.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
class FWDNavigationAction: NavigationModalAction {
    
    let messages:[Message]
    
    var ids:[MessageId] {
        return messages.map{$0.id}
    }
    init(messages:[Message], displayName:String) {
        self.messages = messages
        
        super.init(reason: L10n.forwardModalActionTitleCountable(messages.count), desc: L10n.forwardModalActionDescriptionCountable(messages.count, displayName))
    }
    
    override func isInvokable(for value:Any) -> Bool {
        if let value = value as? Peer {
            return value.canSendMessage(false)
        }
        return true
    }
    
    override func alertError(for value:Any, with window:Window) -> Void {
        if let _ = value as? Peer {
            alert(for: window, info: tr(L10n.alertForwardError))
        }
    }
    
}
