//
//  ChatListFilterRecommendedItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit

class ChatListFilterRecommendedItem: GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, title: String, description: String, viewType: GeneralViewType, add: @escaping()->Void) {
        
        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: title, color: theme.colors.text, font: .normal(.title))
        _ = attr.append(string: "\n", color: theme.colors.text, font: .normal(.title))
        _ = attr.append(string: description, color: theme.colors.grayText, font: .normal(.text))
        self.textLayout = TextViewLayout(attr)
        super.init(initialSize, height: 40, stableId: stableId, viewType: viewType, action: add)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.textLayout.measure(width: self.blockWidth - viewType.innerInset.left - viewType.innerInset.right - 60)
        
        return true
    }
    
    override var instantlyResize: Bool {
        return false
    }
    
    override var height: CGFloat {
        return self.textLayout.layoutSize.height + viewType.innerInset.top + viewType.innerInset.bottom
    }
    
    override func viewClass() -> AnyClass {
        return ChatListFilterRecommendedView.self
    }
    
}

private final class ChatListFilterRecommendedView : GeneralContainableRowView {
    private let textView: TextView = TextView()
    private let button = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(button)
        button.autohighlight = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }
        textView.centerY(x: item.viewType.innerInset.left)
        button.centerY(x: item.blockWidth - button.frame.width - item.viewType.innerInset.right)
    }
    
    override func updateColors() {
        super.updateColors()
        
        textView.backgroundColor = backdorColor
        button.set(background: theme.colors.accent, for: .Normal)
        button.set(background: theme.colors.accent.withAlphaComponent(0.85), for: .Highlight)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListFilterRecommendedItem else {
            return
        }
        textView.update(item.textLayout)
        
        button.set(font: .medium(.text), for: .Normal)
        button.set(color: theme.colors.underSelectedColor, for: .Normal)
        button.set(text: L10n.chatListFilterRecommendedAdd, for: .Normal)
        _ = button.sizeToFit(NSMakeSize(8, 8))
        button.layer?.cornerRadius = button.frame.height / 2
        
        
        button.removeAllHandlers()
        button.set(handler: { [weak item] _ in
            item?.action()
        }, for: .Click)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
