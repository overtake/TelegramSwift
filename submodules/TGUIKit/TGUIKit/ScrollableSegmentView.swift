//
//  ScrollableSegmentController.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 05.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa




public protocol _HasCustomUIEquatableRepresentation {
    func _toCustomUIEquatable() -> UIEquatable?
}

internal protocol _UIEquatableBox {
    var _typeID: ObjectIdentifier { get }
    func _unbox<T : Equatable>() -> T?
    
    func _isEqual(to: _UIEquatableBox) -> Bool?
    
    var _base: Any { get }
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool
}

internal struct _ConcreteEquatableBox<Base : Equatable> : _UIEquatableBox {
    internal var _baseEquatable: Base
    
    internal init(_ base: Base) {
        self._baseEquatable = base
    }
    
    
    internal var _typeID: ObjectIdentifier {
        return ObjectIdentifier(type(of: self))
    }
    
    internal func _unbox<T : Equatable>() -> T? {
        return (self as _UIEquatableBox as? _ConcreteEquatableBox<T>)?._baseEquatable
    }
    
    internal func _isEqual(to rhs: _UIEquatableBox) -> Bool? {
        if let rhs: Base = rhs._unbox() {
            return _baseEquatable == rhs
        }
        return nil
    }
    
    internal var _base: Any {
        return _baseEquatable
    }
    
    internal
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool {
        guard let value = _baseEquatable as? T else { return false }
        result.initialize(to: value)
        return true
    }
}


public struct UIEquatable {
    internal var _box: _UIEquatableBox
    internal var _usedCustomRepresentation: Bool
    
    
    public init<H : Equatable>(_ base: H) {
        if let customRepresentation =
            (base as? _HasCustomUIEquatableRepresentation)?._toCustomUIEquatable() {
            self = customRepresentation
            self._usedCustomRepresentation = true
            return
        }
        
        self._box = _ConcreteEquatableBox(base)
        self._usedCustomRepresentation = false
    }
    
    internal init<H : Equatable>(_usingDefaultRepresentationOf base: H) {
        self._box = _ConcreteEquatableBox(base)
        self._usedCustomRepresentation = false
    }
    
    public var base: Any {
        return _box._base
    }
    internal
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool {
        // Attempt the downcast.
        if _box._downCastConditional(into: result) { return true }
        
        
        
        return false
    }
}

extension UIEquatable : Equatable {
    public static func == (lhs: UIEquatable, rhs: UIEquatable) -> Bool {
        if let result = lhs._box._isEqual(to: rhs._box) { return result }
        
        return false
    }
}

extension UIEquatable : CustomStringConvertible {
    public var description: String {
        return String(describing: base)
    }
}

extension UIEquatable : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "UIEquatable(" + String(reflecting: base) + ")"
    }
}

extension UIEquatable : CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(
            self,
            children: ["value": base])
    }
}

public final class ScrollableSegmentItem : Equatable, Comparable, Identifiable {
    let title: String
    let selected: Bool
    let theme: ScrollableSegmentTheme
    let insets: NSEdgeInsets
    let icon: CGImage?
    let equatable: UIEquatable?
    public let index: Int
    public let uniqueId: Int32
    
    public init(title: String, index: Int, uniqueId: Int32, selected: Bool, insets: NSEdgeInsets, icon: CGImage?, theme: ScrollableSegmentTheme, equatable: UIEquatable?) {
        self.title = title
        self.index = index
        self.uniqueId = uniqueId
        self.selected = selected
        self.theme = theme
        self.insets = insets
        self.icon = icon
        self.equatable = equatable
    }
    
    public var stableId: Int32 {
        return uniqueId
    }
    public static func <(lhs: ScrollableSegmentItem, rhs: ScrollableSegmentItem) -> Bool {
        return lhs.index < rhs.index
    }
    public static func ==(lhs: ScrollableSegmentItem, rhs: ScrollableSegmentItem) -> Bool {
        return lhs.index == rhs.index && lhs.title == rhs.title && lhs.uniqueId == rhs.uniqueId && lhs.selected == rhs.selected && lhs.theme == rhs.theme && lhs.insets == rhs.insets && lhs.equatable == rhs.equatable
    }
    
    fileprivate var view:SegmentItemView?
}

private func buildText(for item: ScrollableSegmentItem) -> TextViewLayout {
    let layout = TextViewLayout.init(.initialize(string: item.title, color: item.selected ? item.theme.activeText : item.theme.inactiveText, font: item.theme.textFont))
    layout.measure(width: .greatestFiniteMagnitude)
    return layout
}

private final class SegmentItemView : Control {
    private(set) var item: ScrollableSegmentItem
    private var textLayout: TextViewLayout
    private var imageView: ImageView?
    private let textView = TextView()
    private let callback: (ScrollableSegmentItem)->Void
    private let menuItems:(ScrollableSegmentItem)->[ContextMenuItem]
    init(item: ScrollableSegmentItem, theme: ScrollableSegmentTheme, callback: @escaping(ScrollableSegmentItem)->Void, menuItems:@escaping(ScrollableSegmentItem)->[ContextMenuItem]) {
        self.item = item
        self.callback = callback
        self.menuItems = menuItems
        self.textLayout = buildText(for: item)
        super.init(frame: NSZeroRect)
        self.handleLongEvent = false
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        self.updateItem(item, theme: theme, animated: false)
        
        updateHandlers()
    }
    
    private func updateHandlers() {
        set(handler: { [weak self] _ in
            if self?.item.selected == false {
                self?.textView.change(opacity: 0.8, animated: true)
                self?.imageView?.change(opacity: 0.8, animated: true)
            }
            }, for: .Highlight)
        
        set(handler: { [weak self] _ in
            self?.textView.change(opacity: 1.0, animated: true)
            self?.imageView?.change(opacity: 1.0, animated: true)
            }, for: .Normal)
        
        set(handler: { [weak self] _ in
            self?.textView.change(opacity: 1.0, animated: true)
            self?.imageView?.change(opacity: 1.0, animated: true)
        }, for: .Hover)
        
        
        set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            self.callback(self.item)
        }, for: .Click)
        
        
        set(handler: { [weak self] control in
            guard let `self` = self else {
                return
            }
            if let event = NSApp.currentEvent {
                ContextMenu.show(items: self.menuItems(self.item), view: control, event: event)
            }
            
        }, for: .RightDown)
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
    }
    
    var size: NSSize {
        var width: CGFloat = self.textLayout.layoutSize.width + item.insets.left + item.insets.right
        if let imageView = imageView {
            width += 5 + imageView.frame.width
        }
        if self.textLayout.layoutSize.width == 0 {
            width -= (5 + (item.insets.left + item.insets.right) / 2)
        }
        return NSMakeSize(width, frame.height)
    }
    
    func updateItem(_ item: ScrollableSegmentItem, theme: ScrollableSegmentTheme, animated: Bool) {
        self.item = item
        self.textLayout = buildText(for: item)
        textView.update(self.textLayout)
        
        if let image = item.icon {
            if imageView == nil {
                imageView = ImageView()
                addSubview(imageView!)
                if animated {
                  //  imageView?.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                }
            }
            imageView?.image = image
            imageView?.sizeToFit()
        } else {
            if animated, let imageView = imageView {
                self.imageView = nil
                imageView.removeFromSuperview()

//                imageView.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak imageView] _ in
//                    imageView?.removeFromSuperview()
//                })
            } else {
                imageView?.removeFromSuperview()
                imageView = nil
            }
           
        }
        
        change(size: size, animated: animated, duration: duration)
        self.backgroundColor = presentation.colors.background
        textView.backgroundColor = presentation.colors.background
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if textView.frame.width > 0 {
            textView.centerY(x: item.insets.left)
            textView.setFrameOrigin(NSMakePoint(textView.frame.minX, textView.frame.minY - item.insets.bottom + item.insets.top))
        } else {
            textView.centerY(x: 0)
        }
        if let imageView = imageView {
            if textView.frame.width > 0 {
                imageView.centerY(x: textView.frame.maxX + 5)
            } else {
                imageView.center()
            }
            imageView.setFrameOrigin(NSMakePoint(imageView.frame.minX, imageView.frame.minY - (item.insets.bottom + item.insets.top) + 1))
        }
        
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(coder:) has not been implemented")
    }
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class SelectorView : View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .duringViewResize
    }
    var theme: ScrollableSegmentTheme? = nil {
        didSet {
            needsDisplay = true
        }
    }
    

    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.round(frame.size, 2.0)
        if let theme = self.theme {
            ctx.setFillColor(theme.selector.cgColor)
            ctx.fill(bounds)
        }
    }
}

public struct ScrollableSegmentTheme : Equatable {
    let border: NSColor
    let selector: NSColor
    let inactiveText: NSColor
    let activeText: NSColor
    let textFont: NSFont
    public init(border: NSColor, selector: NSColor, inactiveText: NSColor, activeText: NSColor, textFont: NSFont) {
        self.border = border
        self.selector = selector
        self.inactiveText = inactiveText
        self.activeText = activeText
        self.textFont = textFont
    }
}

private let duration: Double = 0.2


private class Scroll : ScrollView {
    override func scrollWheel(with event: NSEvent) {
        
        var scrollPoint = contentView.bounds.origin
        let isInverted: Bool = System.isScrollInverted
        if event.scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.x += -event.scrollingDeltaY
            } else {
                scrollPoint.x -= event.scrollingDeltaY
            }
        }
        if event.scrollingDeltaX != 0 {
            if !isInverted {
                scrollPoint.x += -event.scrollingDeltaX
            } else {
                scrollPoint.x -= event.scrollingDeltaX
            }
        }
        if documentView!.frame.width > frame.width {
            scrollPoint.x = min(max(0, scrollPoint.x), documentView!.frame.width - frame.width)
            clipView.scroll(to: scrollPoint)
        }
    }
}


public class ScrollableSegmentView: View {
    public let scrollView:ScrollView = Scroll()
    
    private let selectorView: SelectorView = SelectorView(frame: NSZeroRect)
    private let borderView = View()
    
    private let documentView = View()
    private var items: [ScrollableSegmentItem] = []
    private var selected:Int = 0
    
    public var menuItems:((ScrollableSegmentItem)->[ContextMenuItem])?

    
    public var didChangeSelectedItem:((ScrollableSegmentItem)->Void)?
    
    public var theme: ScrollableSegmentTheme = ScrollableSegmentTheme(border: presentation.colors.border, selector: presentation.colors.accent, inactiveText: presentation.colors.grayText, activeText: presentation.colors.accent, textFont: .medium(.title))
    {
        didSet {
            if theme != oldValue {
                redraw()
            }
        }
    }
    
    public override func scrollWheel(with event: NSEvent) {
        scrollView.scrollWheel(with: event)
    }
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        addSubview(borderView)
        addSubview(selectorView)
        scrollView.documentView = documentView
        
//        scrollView.backgroundColor = .clear
//        scrollView.background = .clear
//
//        documentView.backgroundColor = .clear
//
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.clipView, queue: OperationQueue.main, using: { [weak self] notification  in
            self?.needsLayout = true
        })
        layout()
        redraw()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override func updateLocalizationAndTheme(theme presentation: PresentationTheme) {
        self.theme = ScrollableSegmentTheme(border: presentation.colors.border, selector: presentation.colors.accent, inactiveText: presentation.colors.grayText, activeText: presentation.colors.accent, textFont: .normal(.title))
    }
    
    private var selectorFrame: CGRect {
        
        let selectedItem = self.items.first(where: { $0.selected })
        
        var x: CGFloat = 0
        var width: CGFloat = 20
        if let selectedItem = selectedItem, let view = selectedItem.view {
            let point: NSPoint
            if scrollView.clipView.isAnimateScrolling {
                point = NSMakePoint(min(max(view.frame.midX - frame.width / 2, 0), max(documentView.frame.width - frame.width, 0)), 0)
            } else {
                point = scrollView.documentOffset
            }
            
            
            x = view.frame.minX + selectedItem.insets.left - point.x
            width = view.size.width - selectedItem.insets.left - selectedItem.insets.right
        }
        
        return CGRect(origin: NSMakePoint(x, frame.height - 6 / 2), size: CGSize(width: width, height: 6))
    }

    
    private func moveSelector(_ animated: Bool = false) {
        self.selectorView.change(pos: selectorFrame.origin, animated: animated)
        self.selectorView.change(size: selectorFrame.size, animated: animated)
    }
    
    public override func layout() {
        super.layout()
        scrollView.frame = bounds
        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        selectorView.frame = selectorFrame
        for item in self.items {
            if let view = item.view {
                view.setFrameSize(NSMakeSize(view.size.width, frame.height))
            }
        }
        layoutItems(animated: false)
    }
    
    public func updateItems(_ items:[ScrollableSegmentItem], animated: Bool, autoscroll: Bool = true) -> Void {
        assertOnMainThread()
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: items)
        for rdx in deleteIndices.reversed() {
            self.removeItem(at: rdx, animated: animated)
        }
        for (idx, item, _) in indicesAndItems {
            self.insertItem(item, theme: self.theme, at: idx, animated: animated, callback: { [weak self] item in
                self?.didChangeSelectedItem?(item)
            }, menuItems: { [weak self] item in
                guard let menuItems = self?.menuItems else {
                    return []
                }
                return menuItems(item)
            })
        }
        for (idx, item, _) in updateIndices {
            self.updateItem(item, theme: self.theme, at: idx, animated: animated)
        }
        layoutItems(animated: animated)
       
        
        if let selectedItem = items.first(where: { $0.selected }), let selectedView = selectedItem.view {
            let point = NSMakePoint(min(max(selectedView.frame.midX - frame.width / 2, 0), max(documentView.frame.width - frame.width, 0)), 0)
            if point != scrollView.documentOffset, frame != .zero {
                scrollView.clipView.scroll(to: point, animated: animated)
            }
        }
        moveSelector(animated)
    }
    
    public func scrollToSelected(animated: Bool) {
        if let selectedItem = items.first(where: { $0.selected }), let selectedView = selectedItem.view {
            let point = NSMakePoint(min(max(selectedView.frame.midX - frame.width / 2, 0), max(documentView.frame.width - frame.width, 0)), 0)
            if point != scrollView.documentOffset, frame != .zero {
                scrollView.clipView.scroll(to: point, animated: true)
            }
        }
    }
    
    private func removeItem(at index: Int, animated: Bool) {
        let view = self.items[index].view
        self.items[index].view = nil
        if animated, let view = view {
            view.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak view] _ in
                view?.removeFromSuperview()
            })
        } else {
            view?.removeFromSuperview()
        }
        
        self.items.remove(at: index)
    }
    private func updateItem(_ item: ScrollableSegmentItem, theme: ScrollableSegmentTheme, at index: Int, animated: Bool) {
        item.view = self.items[index].view
        item.view?.updateItem(item, theme: theme, animated: animated)
        
        self.items[index] = item
    }
    private func insertItem(_ item: ScrollableSegmentItem, theme: ScrollableSegmentTheme, at index: Int, animated: Bool, callback: @escaping(ScrollableSegmentItem)->Void, menuItems: @escaping(ScrollableSegmentItem)->[ContextMenuItem]) {
        let view = SegmentItemView(item: item, theme: theme, callback: callback, menuItems: menuItems)
        view.setFrameSize(NSMakeSize(view.frame.width, frame.height))
        item.view = view
        
        var subviews = self.documentView.subviews
        
        subviews.insert(view, at: index)
        self.documentView.subviews = subviews
        self.items.insert(item, at: index)
        
        for (i, item) in self.items.enumerated() {
            if i == index - 1, let v = item.view {
                view.setFrameOrigin(NSMakePoint(v.frame.maxX, 0))
            }
        }
    }
    

    
    private func layoutItems(animated: Bool) {
        var x: CGFloat = 0
        for item in self.items {
            if let view = item.view {
                view._change(pos: NSMakePoint(x, 0), animated: animated)
                x += view.size.width
            }
        }
        documentView.change(size: NSMakeSize(x, frame.height), animated: animated)
    }
    
    private func redraw() {
        selectorView.theme = self.theme
        borderView.backgroundColor = self.theme.border
        backgroundColor = presentation.colors.background
        for item in self.items {
            item.view?.updateItem(item, theme: self.theme, animated: false)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
