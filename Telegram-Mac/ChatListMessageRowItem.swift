//
//  ChatListMessageRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class ChatListMessageRowItem: ChatListRowItem {

    override var stableId: AnyHashable {
        return message!.id
    }
    
    
}
