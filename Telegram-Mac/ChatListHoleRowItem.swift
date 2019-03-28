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

    private var context: AccountContext
    private var hole:ChatListHole
    
    override var stableId: AnyHashable {
        return hole.hashValue
    }
    
    override var height: CGFloat {
        return 20
    }
    
    public init(_ initialSize:NSSize, _ context: AccountContext, _ object: ChatListHole) {
        self.hole = object
        self.context = context
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return ChatListHoleRowView.self
    }
}


class ChatListHoleRowView: TableRowView {
    
}
