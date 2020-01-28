//
//  ChatListRevealItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class ChatListRevealItem: TableStickItem {
    fileprivate let action:(()->Void)?
    init(_ initialSize: NSSize, action: (()->Void)? = nil) {
        self.action = action
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        self.action = nil
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return UIChatListEntryId.reveal
    }
    
    override func viewClass() -> AnyClass {
        return ChatListRevealView.self
    }
}


private final class ChatListRevealView : TableStickView {
    private let textView: TextView = TextView()
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(separator)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        border = [.Right]
        separator.change(opacity: 0, animated: false)
    }
    
    override func mouseUp(with event: NSEvent) {
       
    }
    override func mouseDown(with event: NSEvent) {
        if mouseInside() {
            if let item = item as? ChatListRevealItem {
                item.action?()
            }
        }
    }
    
    override func updateIsVisible(_ visible: Bool, animated: Bool) {
        super.updateIsVisible(visible, animated: animated)
        var visible = visible
        if let table = item?.table {
            visible = visible && table.documentOffset.y > 0
        }
        separator.change(opacity: visible ? 1 : 0, animated: false)
    }
    

    
    override func updateColors() {
        super.updateColors()
        separator.backgroundColor = theme.colors.border
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        let layout = TextViewLayout(.initialize(string: L10n.chatListCloseFilter, color: theme.colors.accent, font: .normal(.text)))
        textView.update(layout)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        let layout = textView.layout
        layout?.measure(width: frame.width - 40)
        textView.update(layout)
        
        textView.center()
        
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
