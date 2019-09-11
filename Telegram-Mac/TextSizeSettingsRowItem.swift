//
//  SelectSizeRowItem.swift
//  Telegram
//
//  Created by keepcoder on 15/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



class SelectSizeRowItem: GeneralRowItem {

    fileprivate let titles:[String]?
    fileprivate let sizes: [Int32]
    fileprivate var current: Int32
    fileprivate let initialCurrent: Int32
    fileprivate let selectAction:(Int)->Void
    fileprivate let hasMarkers: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, current: Int32, sizes: [Int32], hasMarkers: Bool, titles:[String]? = nil, viewType: GeneralViewType = .legacy, selectAction: @escaping(Int)->Void) {
        self.sizes = sizes
        self.titles = titles
        self.initialCurrent = current
        self.hasMarkers = hasMarkers
        self.current = current
        self.selectAction = selectAction
        super.init(initialSize, height: titles != nil ? 60 : 40, stableId: stableId, viewType: viewType, inset: NSEdgeInsets(left: 30, right: 30))
    }
    
    override func viewClass() -> AnyClass {
        return SelectSizeRowView.self
    }
    
    
}

private class SelectSizeRowView : TableRowView, ViewDisplayDelegate {
    
    private var availableRects:[NSRect] = []
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(containerView)
        containerView.displayDelegate = self
        containerView.userInteractionEnabled = false
        containerView.isEventLess = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    
    
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard let item = item as? SelectSizeRowItem, !item.sizes.isEmpty else {return}
        
        if item.sizes.count == availableRects.count {
            let point = containerView.convert(event.locationInWindow, from: nil)
            for i in 0 ..< availableRects.count {
                if NSPointInRect(point, availableRects[i]), item.current != i {
                    item.current = item.sizes[i]
                    self.needsDisplay = true
                }
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard let item = item as? SelectSizeRowItem, !item.sizes.isEmpty else {return}
        
        if item.sizes.count == availableRects.count {
            let point = containerView.convert(event.locationInWindow, from: nil)
            for i in 0 ..< availableRects.count {
                if NSPointInRect(point, availableRects[i]), item.current != i {
                    item.selectAction(i)
                    return
                }
            }
            if item.initialCurrent != item.current {
                item.selectAction(item.sizes.firstIndex(of: item.current)!)
            }
        }
        
    }
    
    func _focus(_ size: NSSize) -> NSRect {
        var focus = self.containerView.focus(size)
        if let item = item as? SelectSizeRowItem {
            switch item.viewType {
            case .legacy:
                if item.titles != nil {
                    focus.origin.y += 20
                }
            case let .modern(_, insets):
                if item.titles != nil {
                    focus.origin.y += (20 - insets.bottom)
                }
            }
            
        }
        return focus
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? SelectSizeRowItem, !item.sizes.isEmpty, containerView.layer == layer else {return}
        
        switch item.viewType {
        case .legacy:
            let minFontSize = CGFloat(item.sizes.first!)
            let maxFontSize = CGFloat(item.sizes.last!)
            
            let minNode = TextNode.layoutText(.initialize(string: "A", color: theme.colors.text, font: .normal(min(minFontSize, 11))), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
            
            let maxNode = TextNode.layoutText(.initialize(string: "A", color: theme.colors.text, font: .normal(min(maxFontSize, 15))), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
            
            let minF = _focus(item.hasMarkers ? minNode.0.size : NSZeroSize)
            let maxF = _focus(item.hasMarkers ? maxNode.0.size : NSZeroSize)
            
            if item.hasMarkers {
                minNode.1.draw(NSMakeRect(item.inset.left, minF.minY, minF.width, minF.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                maxNode.1.draw(NSMakeRect(containerView.frame.width - item.inset.right - maxF.width, maxF.minY, maxF.width, maxF.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            
            let count = CGFloat(item.sizes.count)
            
            let insetBetweenFont: CGFloat = item.hasMarkers ? 20 : 0
            
            let width: CGFloat = containerView.frame.width - (item.inset.left + minF.width) - (item.inset.right + maxF.width) - insetBetweenFont * 2
            
            let per = floorToScreenPixels(backingScaleFactor, width / (count - 1))
            
            ctx.setFillColor(theme.colors.blueFill.cgColor)
            let lineSize = NSMakeSize(width, 2)
            let lc = _focus(lineSize)
            let minX = item.inset.left + minF.width + insetBetweenFont
            
            let interactionRect = NSMakeRect(minX, lc.minY, lc.width, lc.height)
            
            ctx.fill(interactionRect)
            
            let current: CGFloat = CGFloat(item.sizes.firstIndex(of: item.current) ?? 0)
            
            let selectSize = NSMakeSize(20, 20)
            
            let selectPoint = NSMakePoint(minX + floorToScreenPixels(backingScaleFactor, interactionRect.width / CGFloat(item.sizes.count - 1)) * current - selectSize.width / 2, _focus(selectSize).minY)
            
            ctx.setFillColor(theme.colors.grayText.cgColor)
            let unMinX = selectPoint.x + selectSize.width / 2
            ctx.fill(NSMakeRect(unMinX, lc.minY, lc.maxX - unMinX, lc.height))
            
            
            for i in 0 ..< item.sizes.count {
                let perSize = NSMakeSize(10, 10)
                let perF = _focus(perSize)
                let point = NSMakePoint(minX + per * CGFloat(i) - (i > 0 ? perSize.width / 2 : 0), perF.minY)
                ctx.setFillColor(theme.colors.background.cgColor)
                ctx.fill(NSMakeRect(point.x, point.y, perSize.width, perSize.height))
                
                ctx.setFillColor(item.sizes[i] <= item.current ? theme.colors.blueFill.cgColor : theme.colors.grayText.cgColor)
                ctx.fillEllipse(in: NSMakeRect(point.x + perSize.width/2 - 2, point.y + 3, 4, 4))
                
                if let titles = item.titles, titles.count == item.sizes.count {
                    let title = titles[i]
                    let titleNode = TextNode.layoutText(.initialize(string: title, color: theme.colors.text, font: .normal(.text)), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
                    titleNode.1.draw(NSMakeRect(min(max(point.x - titleNode.0.size.width / 2 + 3, minX), frame.width - titleNode.0.size.width - minX), point.y - 15 - titleNode.0.size.height, titleNode.0.size.width, titleNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                }
            }
            
            if let titles = item.titles, titles.count == 1, let title = titles.first {
                let perSize = NSMakeSize(10, 10)
                let perF = _focus(perSize)
                let titleNode = TextNode.layoutText(.initialize(string: title, color: theme.colors.text, font: .normal(.text)), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
                titleNode.1.draw(NSMakeRect(_focus(titleNode.0.size).minX, perF.minY - 15 - titleNode.0.size.height, titleNode.0.size.width, titleNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            
            
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fillEllipse(in: NSMakeRect(selectPoint.x, selectPoint.y, selectSize.width, selectSize.height))
            
            ctx.setFillColor(.white)
            ctx.fillEllipse(in: NSMakeRect(selectPoint.x + 1, selectPoint.y + 1, selectSize.width - 2, selectSize.height - 2))
            
            resetCursorRects()
            availableRects.removeAll()
            
            for i in 0 ..< item.sizes.count {
                let perF = _focus(selectSize)
                let point = NSMakePoint(interactionRect.minX + floorToScreenPixels(backingScaleFactor, interactionRect.width / (count - 1)) * CGFloat(i) - selectSize.width / 2, perF.minY)
                let rect = NSMakeRect(point.x, point.y, selectSize.width, selectSize.height)
                addCursorRect(rect, cursor: NSCursor.pointingHand)
                availableRects.append(rect)
            }
        case let .modern(_, insets):
            let minFontSize = CGFloat(item.sizes.first!)
            let maxFontSize = CGFloat(item.sizes.last!)
            
            let minNode = TextNode.layoutText(.initialize(string: "A", color: theme.colors.text, font: .normal(min(minFontSize, 11))), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
            
            let maxNode = TextNode.layoutText(.initialize(string: "A", color: theme.colors.text, font: .normal(min(maxFontSize, 15))), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
            
            let minF = _focus(item.hasMarkers ? minNode.0.size : NSZeroSize)
            let maxF = _focus(item.hasMarkers ? maxNode.0.size : NSZeroSize)
            
            if item.hasMarkers {
                minNode.1.draw(NSMakeRect(insets.left, minF.minY, minF.width, minF.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                maxNode.1.draw(NSMakeRect(containerView.frame.width - insets.right - maxF.width, maxF.minY, maxF.width, maxF.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            
            let count = CGFloat(item.sizes.count)
            
            let insetBetweenFont: CGFloat = item.hasMarkers ? 20 : 0
            
            let width: CGFloat = containerView.frame.width - (insets.left + minF.width) - (insets.right + maxF.width) - insetBetweenFont * 2
            
            let per = floorToScreenPixels(backingScaleFactor, width / (count - 1))
            
            ctx.setFillColor(theme.colors.blueFill.cgColor)
            let lineSize = NSMakeSize(width, 2)
            let lc = _focus(lineSize)
            let minX = insets.left + minF.width + insetBetweenFont
            
            let interactionRect = NSMakeRect(minX, lc.minY, lc.width, lc.height)
            
            ctx.fill(interactionRect)
            
            let current: CGFloat = CGFloat(item.sizes.firstIndex(of: item.current) ?? 0)
            
            let selectSize = NSMakeSize(20, 20)
            
            let selectPoint = NSMakePoint(minX + floorToScreenPixels(backingScaleFactor, interactionRect.width / CGFloat(item.sizes.count - 1)) * current - selectSize.width / 2, _focus(selectSize).minY)
            
            ctx.setFillColor(theme.colors.grayText.cgColor)
            let unMinX = selectPoint.x + selectSize.width / 2
            ctx.fill(NSMakeRect(unMinX, lc.minY, lc.maxX - unMinX, lc.height))
            
            
            for i in 0 ..< item.sizes.count {
                let perSize = NSMakeSize(10, 10)
                let perF = _focus(perSize)
                let point = NSMakePoint(minX + per * CGFloat(i) - (i > 0 ? perSize.width / 2 : 0), perF.minY)
                ctx.setFillColor(theme.colors.background.cgColor)
                ctx.fill(NSMakeRect(point.x, point.y, perSize.width, perSize.height))
                
                ctx.setFillColor(item.sizes[i] <= item.current ? theme.colors.blueFill.cgColor : theme.colors.grayText.cgColor)
                ctx.fillEllipse(in: NSMakeRect(point.x + perSize.width/2 - 2, point.y + 3, 4, 4))
                
                if let titles = item.titles, titles.count == item.sizes.count {
                    let title = titles[i]
                    let titleNode = TextNode.layoutText(.initialize(string: title, color: theme.colors.text, font: .normal(.text)), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
                    titleNode.1.draw(NSMakeRect(min(max(point.x - titleNode.0.size.width / 2 + 3, minX), frame.width - titleNode.0.size.width - minX), point.y - 15 - titleNode.0.size.height, titleNode.0.size.width, titleNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                }
            }
            
            if let titles = item.titles, titles.count == 1, let title = titles.first {
                let titleNode = TextNode.layoutText(.initialize(string: title, color: theme.colors.text, font: .normal(.text)), backdorColor, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
                titleNode.1.draw(NSMakeRect(_focus(titleNode.0.size).minX, insets.top , titleNode.0.size.width, titleNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            
            
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fillEllipse(in: NSMakeRect(selectPoint.x, selectPoint.y, selectSize.width, selectSize.height))
            
            ctx.setFillColor(.white)
            ctx.fillEllipse(in: NSMakeRect(selectPoint.x + 1, selectPoint.y + 1, selectSize.width - 2, selectSize.height - 2))
            
            resetCursorRects()
            availableRects.removeAll()
            
            for i in 0 ..< item.sizes.count {
                let perF = _focus(selectSize)
                let point = NSMakePoint(interactionRect.minX + floorToScreenPixels(backingScaleFactor, interactionRect.width / (count - 1)) * CGFloat(i) - selectSize.width / 2, perF.minY)
                let rect = NSMakeRect(point.x, point.y, selectSize.width, selectSize.height)
                addCursorRect(rect, cursor: NSCursor.pointingHand)
                availableRects.append(rect)
            }
        }
        
        layout()
        
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? SelectSizeRowItem else {
            return
        }
        switch item.viewType {
        case .legacy:
            self.containerView.frame = bounds
        case let .modern(position, _):
            self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            self.containerView.setCorners(position.corners)
        }
    }
    
    
    override var firstResponder: NSResponder? {
        return self
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = item as? SelectSizeRowItem else {
            return
        }
        containerView.backgroundColor = backdorColor
        
        switch item.viewType {
        case .legacy:
            self.background = backdorColor
        case .modern:
            self.background = theme.colors.grayBackground
        }
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SelectSizeRowItem else {
            return
        }
        switch item.viewType {
        case .legacy:
            self.containerView.setCorners([])
        case let .modern(position, _):
            self.containerView.setCorners(position.corners)
        }
        
        containerView.needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}





struct SliderSelectorItem : Equatable {
    let value: Int32?
    let localizedText: String?
    init(value: Int32?, localizedText:String? = nil) {
        assert(value != nil  || localizedText != nil)
        self.value = value
        self.localizedText = localizedText
    }
}

