//
//  ContextClueRowItem.swift
//  Telegram
//
//  Created by keepcoder on 20/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class ContextClueRowItem: TableRowItem {

    private let _stableId:AnyHashable
    let clue:EmojiClue
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    fileprivate let clueLayout: TextViewLayout
    fileprivate let emojiLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId:AnyHashable, clue: EmojiClue) {
        self._stableId = stableId
        self.clue = clue
        clueLayout = TextViewLayout(.initialize(string: clue.label, color: theme.colors.text, font: .normal(.title)))
        emojiLayout = TextViewLayout(.initialize(string: clue.emoji, color: theme.colors.text, font: .normal(.title)))
        emojiLayout.measure(width: .greatestFiniteMagnitude)
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        clueLayout.measure(width: width - 50)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return ContextClueRowView.self
    }
    
}

private class ContextClueRowView : TableRowView {
    private let clueTextView:TextView = TextView()
    private let emojiTextView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clueTextView.userInteractionEnabled = false
        clueTextView.isSelectable = false
        emojiTextView.userInteractionEnabled = false
        emojiTextView.isSelectable = false
        addSubview(clueTextView)
        addSubview(emojiTextView)
    }
    
    override var backdorColor: NSColor {
        if let item = item {
            return item.isSelected ? theme.colors.blueSelect : theme.colors.background
        } else {
            return theme.colors.background
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item {
            if !item.isSelected {
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(40, frame.height - .borderSize, frame.width - 20, .borderSize))
            }
        }
    }
    
    override func layout() {
        super.layout()
        clueTextView.update(clueTextView.layout)
        clueTextView.centerY(x: 40)
        
        emojiTextView.update(emojiTextView.layout)
        emojiTextView.centerY(x: 10)
    }
    
    override func updateColors() {
        super.updateColors()
        self.emojiTextView.backgroundColor = backdorColor
        self.clueTextView.backgroundColor = backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        if let item = item as? ContextClueRowItem {
            clueTextView.update(item.clueLayout)
            emojiTextView.update(item.emojiLayout)
        }
        needsLayout = true
    }
}
