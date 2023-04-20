//
//  EBlockItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit
import InAppSettings

class EBlockItem: TableRowItem {

    private let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return (CGFloat(lineAttr.count) * 34.0)
    }
    
    let lineAttr:[[NSAttributedString]]
    
    let account: Account
    var selectHandler:(String, NSRect)->Void = { _, _ in}
    let segment: EmojiSegment
    
    public init(_ initialSize:NSSize, stableId: AnyHashable, attrLines:[[NSAttributedString]], segment: EmojiSegment, account: Account, selectHandler:@escaping(String, NSRect)->Void) {
        self.lineAttr = attrLines
        self._stableId = stableId
        self.account = account
        self.segment = segment
        self.selectHandler = selectHandler
        
        super.init(initialSize)
    }
    
    override open func viewClass() ->AnyClass {
        return EBlockRowView.self;
    }
    
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items: [ContextMenuItem] = []
        let postbox = self.account.postbox
        if let view = self.view as? EBlockRowView {
            if let emoji = view.emojiUnderMouse?.emojiUnmodified, emoji.canHaveSkinToneModifier {
                items.append(EmojiToleranceContextMenuItem(emoji: emoji, callback: { value in
                    _ = modifySkinEmoji(emoji, modifier: value, postbox: postbox).start()
                }))
            }
        }
        
       
        return .single(items)
    }
}
