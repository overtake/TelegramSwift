//
//  SegmentController.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 21/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa

public class SegmentedItem {
    let title:String
    let handler: ()->Void
    public init(title:String, handler:@escaping()->Void) {
        self.title = title
        self.handler = handler
    }
}

private enum SegmentItemPosition {
    case left
    case right
    case inner
}

public struct SegmentTheme {
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let textColor: NSColor
    public init(backgroundColor: NSColor, foregroundColor: NSColor, textColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.textColor = textColor
    }
}

private final class SegmentItemView : Control {
    let item: SegmentedItem
    let position: SegmentItemPosition
    let selected: Bool
    init(item: SegmentedItem, selected: Bool, theme: SegmentTheme, position: SegmentItemPosition, select:@escaping()->Void) {
        self.item = item
        self.theme = theme
        self.position = position
        self.selected = selected
        super.init(frame: NSZeroRect)
        
        set(handler: { _ in
            select()
        }, for: .SingleClick)
    }
    
    var theme: SegmentTheme {
        didSet {
            needsDisplay = true
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        needsDisplay = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
       
        
        switch position {
        case .left:
           ctx.round(bounds, flags: [.bottom, .top, .left])
           ctx.setFillColor(theme.foregroundColor.cgColor)
           ctx.fill(bounds)
           
           ctx.round(NSMakeRect(.borderSize , .borderSize, bounds.width - (.borderSize / 2), bounds.height - .borderSize), flags: [.bottom, .top, .left])
           ctx.setFillColor(theme.backgroundColor.cgColor)
           ctx.fill(bounds)
        case .right:
            ctx.round(bounds, flags: [.bottom, .top, .right])
            ctx.setFillColor(theme.foregroundColor.cgColor)
            ctx.fill(bounds)
            
            ctx.round(NSMakeRect(.borderSize / 2, .borderSize, bounds.width - .borderSize , bounds.height - .borderSize ), flags: [.bottom, .top, .right])
            ctx.setFillColor(theme.backgroundColor.cgColor)
            ctx.fill(bounds)
        case .inner:
            ctx.setFillColor(theme.foregroundColor.cgColor)
            ctx.fill(NSMakeRect(0, 0, .borderSize / 2, frame.height))
            
            ctx.setFillColor(theme.foregroundColor.cgColor)
            ctx.fill(NSMakeRect(0, 0, frame.width, .borderSize))
            
            ctx.setFillColor(theme.foregroundColor.cgColor)
            ctx.fill(NSMakeRect(frame.width - .borderSize / 2, 0, .borderSize / 2, frame.height))
            
            ctx.setFillColor(theme.foregroundColor.cgColor)
            ctx.fill(NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize))
        }
        
        
        
        if selected {
            ctx.setFillColor(theme.foregroundColor.cgColor)
            ctx.fill(bounds)
        }
        
        let text = TextNode.layoutText(.initialize(string: item.title, color: selected ? theme.backgroundColor : theme.foregroundColor, font: .normal(12)), selected ? theme.foregroundColor : theme.backgroundColor, 1, .end, NSMakeSize(frame.width - 10, frame.height), nil, false, .center)
        
        let f = focus(text.0.size)
        text.1.draw(f, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: selected ? theme.foregroundColor : theme.backgroundColor)
    }
}

private class SegmentedControlView: View {
    
    public var theme: SegmentTheme = SegmentTheme(backgroundColor: presentation.colors.background, foregroundColor: presentation.colors.blueUI, textColor: presentation.colors.blueUI) {
        didSet {
            for subview in subviews.compactMap({ $0 as? SegmentItemView}) {
                subview.theme = theme
            }
        }
    }
    
    func update(items: [SegmentedItem], selected: Int, select: @escaping(Int)->Void) -> Void {
        self.removeAllSubviews()
        for i in 0 ..< items.count {
            let view = SegmentItemView(item: items[i], selected: selected == i, theme: theme, position: i == 0 ? .left : i == items.count - 1 ? .right : .inner, select: { select(i) })
            addSubview(view)
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard !subviews.isEmpty else {return}
        
        var x: CGFloat = 0
        let itemWidth = floor(frame.width / CGFloat(subviews.count))
        for view in subviews {
            view.frame = NSMakeRect(x, 0, itemWidth, frame.height)
            x += itemWidth
        }
    }
    
}


public class SegmentController: ViewController {

    private var items: [SegmentedItem] = []
    private var selected: Int = 0
    
    private var genericView: SegmentedControlView {
        return self.view as! SegmentedControlView
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bar = .init(height: 0)
    }
    
    public var theme: SegmentTheme {
        get {
            return genericView.theme
        }
        set {
            genericView.theme = newValue
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    private func select(_ index: Int) {
        self.selected = index
        items[index].handler()
        genericView.update(items: items, selected: selected, select: { [weak self] index in self?.select(index)})
    }
    
    public func add(segment: SegmentedItem) -> Void {
        items.append(segment)
        genericView.update(items: items, selected: selected, select: { [weak self] index in self?.select(index)})
    }
    public func segment(at index:Int) -> SegmentedItem {
        return items[index]
    }
    public func replace(segment: SegmentedItem, at index:Int) -> Void {
       items[index] = segment
        genericView.update(items: items, selected: selected, select: { [weak self] index in self?.select(index)})
    }
    public func insert(segment: SegmentedItem, at index: Int) -> Void {
        items.insert(segment, at: index)
        genericView.update(items: items, selected: selected, select: { [weak self] index in self?.select(index)})
    }
    public func remove(at index: Int) -> Void {
         items.remove(at: index)
        genericView.update(items: items, selected: selected, select: { [weak self] index in self?.select(index)})
    }
    
    public func set(selected index: Int) -> Void {
        selected = index
        genericView.update(items: items, selected: selected, select: { [weak self] index in self?.select(index)})
    }
    
    public func removeAll() -> Void {
        selected = 0
        items.removeAll()
        genericView.update(items: items, selected: selected, select: { [weak self] index in self?.select(index)})
    }
    
    override public func viewClass() -> AnyClass {
        return SegmentedControlView.self
    }
}
