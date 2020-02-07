//
//  GeneralBlockTextRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


final class WalletTransactionTextItem : GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    fileprivate let subTextLayout: TextViewLayout
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, value: String, subText: String, color: NSColor, viewType: GeneralViewType) {
        self.context = context
        let attributed: NSMutableAttributedString = NSMutableAttributedString()
        if let range = value.range(of: Formatter.withSeparator.decimalSeparator) {
            let integralPart = String(value[..<range.lowerBound])
            let fractionalPart = String(value[range.lowerBound...])
            _ = attributed.append(string: integralPart, color: color, font: .medium(40.0))
            _ = attributed.append(string: fractionalPart, color: color, font: .medium(22.0))
        } else {
            _ = attributed.append(string: value, color: color, font: .medium(22.0))
        }

        
        self.textLayout = TextViewLayout(attributed)
        self.subTextLayout = TextViewLayout(.initialize(string: subText, color: theme.colors.listGrayText, font: .normal(11.5)))
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        textLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        subTextLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        return true
    }
    
    override var height: CGFloat {
        return textLayout.layoutSize.height + subTextLayout.layoutSize.height + viewType.innerInset.top + viewType.innerInset.bottom
    }
    
    override func viewClass() -> AnyClass {
        return WalletTransactionTextView.self
    }
    
}


private final class WalletTransactionTextView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let crystalView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let textView = TextView()
    private let subTextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.containerView)
        self.containerView.addSubview(self.textView)
        self.containerView.addSubview(self.subTextView)
        self.containerView.addSubview(self.crystalView)
        subTextView.isSelectable = false
        subTextView.userInteractionEnabled = false
        
        self.textView.isSelectable = false
        self.textView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        guard let item = item as? WalletTransactionTextItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        self.textView.backgroundColor = backdorColor
        self.subTextView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WalletTransactionTextItem else {
            return
        }
            
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
                
        textView.centerX(y: item.viewType.innerInset.top)
        
        crystalView.setFrameOrigin(NSMakePoint(textView.frame.minX - crystalView.frame.width, textView.frame.minY + 1))
        
        subTextView.centerX(y: textView.frame.maxY - 8)
        
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? WalletTransactionTextItem else {
            return
        }
        self.textView.update(item.textLayout)
        self.subTextView.update(item.subTextLayout)
        
        crystalView.update(with: LocalAnimatedSticker.brilliant_static.file, size: NSMakeSize(40, 40), context: item.context, parent: nil, table: nil, parameters: LocalAnimatedSticker.brilliant_static.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: true)
        
        needsLayout = true
    }
}
