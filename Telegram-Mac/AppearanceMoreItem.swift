//
//  AppearanceMoreItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


class AppearanceMoreItem: GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, text: String, font: NSFont, color: NSColor = theme.colors.text) {
        self.textLayout = TextViewLayout(.initialize(string: text, color: color, font: font), alwaysStaticItems: false)
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.textLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return AppearanceMoreView.self
    }
    
    override var height: CGFloat {
        var height: CGFloat = textLayout.layoutSize.height + viewType.innerInset.bottom + viewType.innerInset.top
    
        return height
    }
}


private final class AppearanceMoreView : GeneralContainableRowView {
    private let textView = TextView()
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(textView)
        self.addSubview(separator)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? AppearanceMoreItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        self.textView.backgroundColor = backdorColor
        self.separator.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? AppearanceMoreItem else {
            return
        }
        
        textView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        
        separator.frame = NSMakeRect(item.viewType.innerInset.left, containerView.frame.height - .borderSize, containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, .borderSize)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? AppearanceMoreItem else {
            return
        }
        
        textView.update(item.textLayout)
        self.separator.isHidden = !item.viewType.hasBorder
        needsLayout = true
    }
    
    override var firstResponder: NSResponder? {
        return nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
