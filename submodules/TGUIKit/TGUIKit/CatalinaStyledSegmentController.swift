//
//  CatalinaStyledSegmentController.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 18.10.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

//
//  SegmentController.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 21/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa

public class CatalinaSegmentedItem {
    let title:String
    let handler: ()->Void
    public init(title:String, handler:@escaping()->Void) {
        self.title = title
        self.handler = handler
    }
}


public struct CatalinaSegmentTheme {
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let activeTextColor: NSColor
    let inactiveTextColor: NSColor
    public init(backgroundColor: NSColor, foregroundColor: NSColor, activeTextColor: NSColor, inactiveTextColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.activeTextColor = activeTextColor
        self.inactiveTextColor = inactiveTextColor
    }
}

private final class CatalinaSegmentItemView : Control {
    let item: CatalinaSegmentedItem
    private let inactiveTextView: TextView = TextView()
    private let activeTextView: TextView = TextView()
    private let separatorView = View()
    init(item: CatalinaSegmentedItem, theme: CatalinaSegmentTheme, select:@escaping()->Void) {
        self.item = item
        self.theme = theme
        super.init(frame: NSZeroRect)
        addSubview(activeTextView)
        addSubview(inactiveTextView)
        addSubview(separatorView)
        activeTextView.userInteractionEnabled = false
        activeTextView.isSelectable = false
        
        inactiveTextView.userInteractionEnabled = false
        inactiveTextView.isSelectable = false
               
        
        set(handler: { _ in
            select()
        }, for: .SingleClick)
        
        set(handler: { [weak self] _ in
            self?.inactiveTextView.layer?.animateAlpha(from: 1, to: 0.8, duration: 0.2, removeOnCompletion: false)
        }, for: .Down)
        
        set(handler: { [weak self] _ in
            self?.inactiveTextView.layer?.animateAlpha(from: 0.8, to: 1.0, duration: 0.2, removeOnCompletion: true)
        }, for: .Up)
    }
    
    
    var theme: CatalinaSegmentTheme {
        didSet {
            update()
            needsLayout = true
        }
    }
    
    private func update() {
        
        activeTextView.disableBackgroundDrawing = true
        inactiveTextView.disableBackgroundDrawing = true
        
        let activeLayout = TextViewLayout(.initialize(string: item.title, color: theme.activeTextColor, font: .medium(.text)), maximumNumberOfLines: 1, alwaysStaticItems: true)
        activeLayout.measure(width: frame.width - 6)
        
        let inactiveLayout = TextViewLayout(.initialize(string: item.title, color: theme.inactiveTextColor, font: .normal(.text)), maximumNumberOfLines: 1, alwaysStaticItems: true)
        inactiveLayout.measure(width: frame.width - 6)
        
        activeTextView.update(activeLayout)
        inactiveTextView.update(inactiveLayout)
        
        separatorView.backgroundColor = theme.inactiveTextColor
        
    }
    
    func set(_ selected: Bool, hasSepator: Bool, animated: Bool) {
        separatorView.change(opacity: hasSepator ? 0.4 : 0, animated: animated)
        activeTextView.change(opacity: selected ? 1 : 0, animated: animated)
        inactiveTextView.change(opacity: !selected ? 1 : 0, animated: animated)
        
//        activeTextView.backgroundColor = !selected ? theme.backgroundColor : theme.foregroundColor
//        inactiveTextView.backgroundColor = !selected ? theme.backgroundColor : theme.foregroundColor

        userInteractionEnabled = !selected
        isSelected = selected
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        update()
        separatorView.frame = NSMakeRect(frame.width - .borderSize, 8, .borderSize, frame.height - 16)
        activeTextView.center()
        inactiveTextView.center()
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
}

private class CatalinaSegmentedControlView: View {
    private let button: Control = Control()
    private let itemsContainerView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = 10.0
        addSubview(button)
        addSubview(itemsContainerView)
        button.layer?.cornerRadius = 8
        
        button.set(handler: { [weak self] control in
            control.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)
            guard let `self` = self else {
                return
            }
            let itemView = self.itemsContainerView.subviews.compactMap { $0 as? CatalinaSegmentItemView }.first(where: { $0.isSelected })
            itemView?.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)

        }, for: .Down)
        
        button.set(handler: { [weak self] control in
            control.layer?.animateScaleCenter(from: 0.95, to: 1.0, duration: 0.2, removeOnCompletion: true)
            guard let `self` = self else {
               return
            }
            let itemView = self.itemsContainerView.subviews.compactMap { $0 as? CatalinaSegmentItemView }.first(where: { $0.isSelected })
            itemView?.layer?.animateScaleCenter(from: 0.95, to: 1.0, duration: 0.2, removeOnCompletion: true)
        }, for: .Up)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var theme: CatalinaSegmentTheme = CatalinaSegmentTheme(backgroundColor: presentation.colors.listBackground, foregroundColor: presentation.colors.background, activeTextColor: presentation.colors.text, inactiveTextColor: presentation.colors.listGrayText) {
        didSet {
            for subview in itemsContainerView.subviews.compactMap({ $0 as? CatalinaSegmentItemView}) {
                subview.theme = theme
            }
            update()
        }
    }
    
    private func update() {
        self.backgroundColor = theme.backgroundColor
        itemsContainerView.backgroundColor = .clear
        
        button.backgroundColor = theme.foregroundColor
        needsLayout = true
    }
    
    func update(items: [CatalinaSegmentedItem], selected: Int, animated: Bool, select: @escaping(Int, Bool)->Void) -> Void {
        itemsContainerView.removeAllSubviews()
        for i in 0 ..< items.count {
            let view = CatalinaSegmentItemView(item: items[i], theme: theme, select: { select(i, true) })
            var hasSeparator: Bool = false
            if i != (items.count - 1) && selected != i {
                hasSeparator = true
                if selected > 0 {
                    if i == selected - 1 {
                        hasSeparator = false
                    }
                }
            }
            view.set(selected == i, hasSepator: hasSeparator, animated: animated)
            itemsContainerView.addSubview(view)
        }
        
        needsLayout = true
    }
    
    func set(selected: Int, animated: Bool) {
        let items = self.itemsContainerView.subviews.compactMap { $0 as? CatalinaSegmentItemView }
        for (i, subview) in items.enumerated() {
            var hasSeparator: Bool = false
            if i != (items.count - 1) && selected != i {
                hasSeparator = true
                if selected > 0 {
                    if i == selected - 1 {
                        hasSeparator = false
                    }
                }
            }
            subview.set(selected == i, hasSepator: hasSeparator, animated: animated)
            if selected == i {
                button.change(pos: NSMakePoint(max(2, min(subview.frame.minX + 2, frame.width - subview.frame.width - 2)), 2), animated: animated)
            }
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        let items = self.itemsContainerView.subviews.compactMap { $0 as? CatalinaSegmentItemView }
        
        guard !items.isEmpty else {return}
        
        self.itemsContainerView.frame = bounds
        
        
        var x: CGFloat = 0
        let itemWidth = floor(frame.width / CGFloat(items.count))
        for view in items {
            view.frame = NSMakeRect(x, 0, itemWidth, frame.height)
            
            if view.isSelected {
                button.frame = NSMakeRect(max(2, min(x + 2, frame.width - itemWidth - 2)), 2, itemWidth, frame.height - 4)
            }
            
            x += itemWidth
        }
    }
    
}


public class CatalinaStyledSegmentController: ViewController {

    private var items: [CatalinaSegmentedItem] = []
    private var selected: Int = 0
    
    private var genericView: CatalinaSegmentedControlView {
        return self.view as! CatalinaSegmentedControlView
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bar = .init(height: 0)
    }
    
    public var theme: CatalinaSegmentTheme {
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
    
    private func select(_ index: Int, animated: Bool) {
        self.selected = index
        items[index].handler()
        genericView.set(selected: index, animated: animated)
    }
    
    public func add(segment: CatalinaSegmentedItem) -> Void {
        items.append(segment)
        genericView.update(items: items, selected: selected, animated: false, select: { [weak self] index, animated in
            self?.select(index, animated: animated)
        })
    }
    public func segment(at index:Int) -> CatalinaSegmentedItem {
        return items[index]
    }
    public func replace(segment: CatalinaSegmentedItem, at index:Int) -> Void {
       items[index] = segment
        genericView.update(items: items, selected: selected, animated: false, select: { [weak self] index, animated in
            self?.select(index, animated: animated)
        })
    }
    public func insert(segment: CatalinaSegmentedItem, at index: Int) -> Void {
        items.insert(segment, at: index)
        genericView.update(items: items, selected: selected, animated: false, select: { [weak self] index, animated in
            self?.select(index, animated: animated)
        })
    }
    public func remove(at index: Int) -> Void {
        items.remove(at: index)
        genericView.update(items: items, selected: selected, animated: false, select: { [weak self] index, animated in
            self?.select(index, animated: animated)
        })
    }
    
    public func set(selected index: Int, animated: Bool = false) -> Void {
        selected = index
        genericView.set(selected: index, animated: animated)
    }
    
    public func selectNext(animated: Bool) {
        var index = self.selected
        index += 1
        if index == self.items.count {
            index = 0
        }
        self.select(index, animated: animated)
    }
    
    public func removeAll() -> Void {
        selected = 0
        items.removeAll()
        genericView.update(items: items, selected: selected, animated: false, select: { [weak self] index, animated in
            self?.select(index, animated: animated)
        })
    }
    
    override public func viewClass() -> AnyClass {
        return CatalinaSegmentedControlView.self
    }
}
