//
//  TextSizeSettingsRowItem.swift
//  Telegram
//
//  Created by keepcoder on 15/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



class TextSizeSettingsRowItem: GeneralRowItem {


    fileprivate let sizes: [Int32]
    fileprivate let current: Int32
    fileprivate let selectAction:(Int)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, current: Int32, sizes: [Int32], selectAction: @escaping(Int)->Void) {
        self.sizes = sizes
        self.current = current
        self.selectAction = selectAction
        super.init(initialSize, height: 50, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return TextSizeSettingsRowView.self
    }
    
    
}

private class TextSizeSettingsRowView : TableRowView {
    
    private var availableRects:[NSRect] = []
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard let item = item as? TextSizeSettingsRowItem, !item.sizes.isEmpty else {return}
        
        if item.sizes.count == availableRects.count {
            let point = convert(event.locationInWindow, from: nil)
            for i in 0 ..< availableRects.count {
                if NSPointInRect(point, availableRects[i]), item.current != i {
                    item.selectAction(i)
                }
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard let item = item as? TextSizeSettingsRowItem, !item.sizes.isEmpty else {return}
        
        if item.sizes.count == availableRects.count {
            let point = convert(event.locationInWindow, from: nil)
            for i in 0 ..< availableRects.count {
                if NSPointInRect(point, availableRects[i]), item.current != i {
                    item.selectAction(i)
                }
            }
        }
        
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? TextSizeSettingsRowItem, !item.sizes.isEmpty else {return}
        
        let minFontSize = CGFloat(item.sizes.first!)
        let maxFontSize = CGFloat(item.sizes.last!)
        
        let minNode = TextNode.layoutText(NSAttributedString.initialize(string: "A", color: theme.colors.text, font: .normal(minFontSize)), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
        
        let maxNode = TextNode.layoutText(NSAttributedString.initialize(string: "A", color: theme.colors.text, font: .normal(maxFontSize)), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)

        let minF = focus(minNode.0.size)
        let maxF = focus(maxNode.0.size)
        
        minNode.1.draw(NSMakeRect(item.inset.left, minF.minY, minF.width, minF.height), in: ctx, backingScaleFactor: backingScaleFactor)
        
        maxNode.1.draw(NSMakeRect(frame.width - item.inset.right - maxF.width, maxF.minY, maxF.width, maxF.height), in: ctx, backingScaleFactor: backingScaleFactor)
        
        let count = CGFloat(item.sizes.count)
        
        let insetBetweenFont: CGFloat = 20
        
        let width: CGFloat = frame.width - (item.inset.left + minF.width) - (item.inset.right + maxF.width) - insetBetweenFont * 2
        
        let per = floorToScreenPixels(width / (count - 1))
        
        ctx.setFillColor(theme.colors.blueFill.cgColor)
        let lineSize = NSMakeSize(width, 2)
        let lc = focus(lineSize)
        let minX = item.inset.left + minF.width + insetBetweenFont
        
        let interactionRect = NSMakeRect(minX, lc.minY, lc.width, lc.height)
        
        ctx.fill(interactionRect)
        
        let current = CGFloat(item.current)
        let selectSize = NSMakeSize(20, 20)
        
        let selectPoint = NSMakePoint(minX + floorToScreenPixels(interactionRect.width / CGFloat(item.sizes.count - 1)) * current - selectSize.width / 2, floorToScreenPixels((frame.height - selectSize.height) / 2))

        ctx.setFillColor(theme.colors.grayText.cgColor)
        let unMinX = selectPoint.x + selectSize.width / 2
        ctx.fill(NSMakeRect(unMinX, lc.minY, lc.maxX - unMinX, lc.height))
        
        
        for i in 0 ..< item.sizes.count {
            let perSize = NSMakeSize(10, 10)
            let perF = focus(perSize)
            let point = NSMakePoint(minX + per * CGFloat(i) - perSize.width / 2, perF.minY)
            ctx.setFillColor(theme.colors.background.cgColor)
            ctx.fill(NSMakeRect(point.x, point.y, perSize.width, perSize.height))
            
            ctx.setFillColor(i <= item.current ? theme.colors.blueFill.cgColor : theme.colors.grayText.cgColor)
            ctx.fillEllipse(in: NSMakeRect(point.x + perSize.width/2 - 2, point.y + 3, 4, 4))
        }
        
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fillEllipse(in: NSMakeRect(selectPoint.x, selectPoint.y, selectSize.width, selectSize.height))
        
        ctx.setFillColor(.white)
        ctx.fillEllipse(in: NSMakeRect(selectPoint.x + 1, selectPoint.y + 1, selectSize.width - 2, selectSize.height - 2))

        resetCursorRects()
        availableRects.removeAll()
        
        for i in 0 ..< item.sizes.count {
            let perF = focus(selectSize)
            let point = NSMakePoint(interactionRect.minX + floorToScreenPixels(interactionRect.width / (count - 1)) * CGFloat(i) - selectSize.width / 2, perF.minY)
            let rect = NSMakeRect(point.x, point.y, selectSize.width, selectSize.height)
            addCursorRect(rect, cursor: NSCursor.pointingHand)
            availableRects.append(rect)
        }
        
        layout()
        
    }
    
    
    override var firstResponder: NSResponder? {
        return self
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        
        
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
