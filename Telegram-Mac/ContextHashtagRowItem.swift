//
//  ContextHashtagRowItem.swift
//  Telegram
//
//  Created by keepcoder on 24/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class ContextHashtagRowItem: TableRowItem {

    let hashtag: String
    fileprivate let selectedTextLayout: TextViewLayout
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, hashtag:String) {
        self.hashtag = hashtag
        textLayout = TextViewLayout(.initialize(string: hashtag, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        selectedTextLayout = TextViewLayout(.initialize(string: hashtag, color: .white, font: .normal(.text)), maximumNumberOfLines: 1)
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override var stableId: AnyHashable {
        return "hashtag_\(hashtag)".hashValue
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout.measure(width: width - 40)
        selectedTextLayout.measure(width: width - 40)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return ContextHashtagRowView.self
    }
    
}


private class ContextHashtagRowView : TableRowView {
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        textView.centerY(x: 20)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = item, !item.isSelected, !item.isLast {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(20, frame.height - .borderSize, frame.width - 20, .borderSize))
        }
    }
    
    override var backdorColor: NSColor {
        if let item = item {
            return item.isSelected ? theme.colors.blueSelect : theme.colors.background
        } else {
            return theme.colors.background
        }
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ContextHashtagRowItem else {return}
        
        textView.update(item.isSelected ? item.selectedTextLayout : item.textLayout)
        needsLayout = true
    }
}
