//
//  ChatListEmptyRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit
import Cocoa

class ChatListEmptyRowItem: TableRowItem {
    private let _stableId: UInt32 = arc4random()
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override init(_ initialSize: NSSize) {
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        if let table = table {
            return table.frame.height
        }
        return initialSize.height
    }
    
    override func viewClass() -> AnyClass {
        return ChatListEmptyRowView.self
    }
}


private class ChatListEmptyRowView : TableRowView {
    
    private let textView = TextView()
    private let separator = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        addSubview(separator)
    }
    
    
    
    override func layout() {
        super.layout()
        
        separator.background = theme.colors.border
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: L10n.chatListEmptyText, color: theme.colors.grayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        let layout = TextViewLayout(attr, alignment: .center)
        layout.measure(width: frame.width - 40)
        
        textView.update(layout)
        textView.center()
        
        textView.isHidden = frame.width <= 70
        
        separator.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
