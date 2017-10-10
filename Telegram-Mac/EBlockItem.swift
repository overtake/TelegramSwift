//
//  EBlockItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
class EBlockItem: TableRowItem {

    var _stableId:Int64 = Int64(arc4random())
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return (CGFloat(lineAttr.count) * 34.0)
    }
    
    let lineAttr:[[NSAttributedString]]
    
    let account: Account
    var selectHandler:(String)->Void = {_ in}
    let segment: EmojiSegment
    
    public init(_ initialSize:NSSize, attrLines:[[NSAttributedString]], segment: EmojiSegment, account: Account, selectHandler:@escaping(String)->Void) {
        self.lineAttr = attrLines
        self.account = account
        self.segment = segment
        self.selectHandler = selectHandler
        
        super.init(initialSize)
    }
    
    override open func viewClass() ->AnyClass {
        return EBlockRowView.self;
    }
    
}
