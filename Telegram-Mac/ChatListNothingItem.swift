//
//  ChatListNothingItem.swift
//  TelegramMac
//
//  Created by keepcoder on 11/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
class ChatListNothingItem: TableRowItem {

    let stableIndex:ChatListIndex
    override var stableId: AnyHashable {
        return stableIndex.messageIndex
    }
    init(_ initialSize: NSSize, _ index:ChatListIndex) {
        self.stableIndex = index
        super.init(initialSize)
    }
    
}
