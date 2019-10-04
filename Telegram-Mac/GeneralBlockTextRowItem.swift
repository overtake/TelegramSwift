//
//  GeneralBlockTextRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class GeneralBlockTextRowItem: GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, text: String, font: NSFont) {
        self.textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: font), alwaysStaticItems: false)
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        textLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return WalletAddressRowView.self
    }
    
    override var height: CGFloat {
        return viewType.innerInset.top + viewType.innerInset.bottom + textLayout.layoutSize.height
    }
}


private final class WalletAddressRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let textView = TextView()
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(textView)
        containerView.addSubview(separator)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? GeneralBlockTextRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        self.textView.backgroundColor = backdorColor
        self.separator.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralBlockTextRowItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        textView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        
        separator.frame = NSMakeRect(item.viewType.innerInset.left, containerView.frame.height - .borderSize, containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, .borderSize)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GeneralBlockTextRowItem else {
            return
        }
        textView.update(item.textLayout)
        self.separator.isHidden = !item.viewType.hasBorder
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
