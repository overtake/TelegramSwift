//
//  ChatListHoleItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
class ChatListHoleRowItem: TableRowItem {

    private var account:Account
    private var hole:ChatListHole
    
    override var stableId: AnyHashable {
        return hole.hashValue
    }
    
    override var height: CGFloat {
        return 20
    }
    
    public init(_ initialSize:NSSize, _ account:Account, _ object: ChatListHole) {
        self.hole = object
        self.account = account
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return ChatListHoleRowView.self
    }
    
    
    
}
