//
//  TableRowView.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac


open class TableRowView: NSTableRowView, CALayerDelegate {
    
    open private(set) weak var item:TableRowItem?
    private let menuDisposable = MetaDisposable()
    // var selected:Bool?
    
    open var border:BorderType?
    public var animates:Bool = true
    
    public private(set) var contextMenu:ContextMenu?
    
    
    required public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // self.layer = (self.layerClass() as! CALayer.Type).init()
        self.wantsLayer = true
        
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        self.layer?.delegate = self
        self.layer?.drawsAsynchronously = System.drawAsync
        autoresizesSubviews = false
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryDeepClick)
    }
    
    
    open func updateColors() {
        
    }
    
    open func layerClass() ->AnyClass {
        return CALayer.self;
    }
    
    open var backdorColor: NSColor {
        return presentation.colors.background
    }
    
    open var isSelect: Bool {
        return item?.isSelected ?? false
    }
    
    open override func draw(_ dirtyRect: NSRect) {
        
    }
    
    open func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(backdorColor.cgColor)
        ctx.fill(layer.bounds)
        
        if let border = border {
            
            ctx.setFillColor(presentation.colors.border.cgColor)
            
            if border.contains(.Top) {
                ctx.fill(NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize))
            }
            if border.contains(.Bottom) {
                ctx.fill(NSMakeRect(0, 0, frame.width, .borderSize))
            }
            if border.contains(.Left) {
                ctx.fill(NSMakeRect(0, 0, .borderSize, frame.height))
            }
            if border.contains(.Right) {
                ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
            }
            
        }
        
    }
    
    open var interactionContentView:NSView {
        return self
    }
    
    open var firstResponder:NSResponder? {
        return self
    }
    
    open override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) && event.clickCount == 1 {
            showContextMenu(event)
        } else {
            if event.clickCount == 2 {
                doubleClick(in: convert(event.locationInWindow, from: nil))
                return
            }
            super.mouseDown(with: event)
        }
    }
    
    private var lastPressureEventStage = 0
    
    open override func pressureChange(with event: NSEvent) {
        super.pressureChange(with: event)
        if event.stage == 2 && lastPressureEventStage < 2 {
            forceClick(in: convert(event.locationInWindow, from: nil))
        }
        lastPressureEventStage = event.stage
    }
    
    open override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        showContextMenu(event)
    }
    
    open func doubleClick(in location:NSPoint) -> Void {
        
    }
    
    open func forceClick(in location: NSPoint) {
        
    }
    
    open func showContextMenu(_ event:NSEvent) -> Void {
        
        menuDisposable.set(nil)
        contextMenu = nil
        
        if let item = item {
            menuDisposable.set((item.menuItems() |> deliverOnMainQueue |> take(1)).start(next: { [weak self] items in
                if let strongSelf = self {
                    let menu = ContextMenu()
                    menu.onShow = { [weak strongSelf] menu in
                        strongSelf?.contextMenu = menu
                        strongSelf?.onShowContextMenu()
                    }
                    menu.delegate = menu
                    menu.onClose = { [weak strongSelf] in
                        strongSelf?.contextMenu = nil
                        strongSelf?.onCloseContextMenu()
                    }
                    for item in items {
                        menu.addItem(item)
                    }
                    
                    menu.delegate = menu
                    NSMenu.popUpContextMenu(menu, with: event, for: strongSelf)
                }
                
            }))
        }
        
        
    }
    
    open override func menu(for event: NSEvent) -> NSMenu? {
        return NSMenu()
    }
    
    
    
    
    open func onShowContextMenu() ->Void {
        self.layer?.setNeedsDisplay()
    }
    
    open func onCloseContextMenu() ->Void {
        self.layer?.setNeedsDisplay()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func updateMouse() {
        
    }
    
    public var isInsertionAnimated:Bool {
        if let layer = layer?.presentation(), layer.animation(forKey: "position") != nil {
            return true
        }
        return false
    }
    
    public var rect:NSRect {
        if let layer = layer?.presentation(), layer.animation(forKey: "position") != nil {
            let rect = NSMakeRect(layer.position.x, layer.position.y, frame.width, frame.height)
            return rect
        }
        return frame
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard #available(OSX 10.12, *) else {
            needsLayout = true
            return
        }
    }
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        guard #available(OSX 10.12, *) else {
            needsLayout = true
            return
        }
    }
    
    open override func viewDidMoveToSuperview() {
        if superview != nil {
            guard #available(OSX 10.12, *) else {
                needsLayout = true
                return
            }
        }
    }
    
    open override func layout() {
        super.layout()
    }
    
    public func notifySubviewsToLayout(_ subview:NSView) -> Void {
        for sub in subview.subviews {
            sub.needsLayout = true
        }
    }
    
    open override var needsLayout: Bool {
        set {
            super.needsLayout = newValue
            if newValue {
                guard #available(OSX 10.12, *) else {
                    layout()
                    notifySubviewsToLayout(self)
                    return
                }
            }
        }
        get {
            return super.needsLayout
        }
    }
    
    deinit {
        menuDisposable.dispose()
    }
    
    
    open override func copy() -> Any {
        let view:View = View(frame:bounds)
        view.backgroundColor = self.backdorColor
        return view
    }
    
    open func set(item:TableRowItem, animated:Bool = false) -> Void {
        self.item = item;
        updateColors()
    }
    
    open func focusAnimation() {
        
    }
    
    public func change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) -> Void  {
        super._change(pos: position, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    public func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    public func change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        super._change(opacity: to, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    open func mouseInside() -> Bool {
        return super._mouseInside()
    }
    
}
