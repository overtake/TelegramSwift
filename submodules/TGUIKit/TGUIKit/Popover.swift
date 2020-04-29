//
//  Popover.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//
import Cocoa
import SwiftSignalKit

class PopoverBackground: Control {

}

private struct PopoverFrameValue {
    let inset: NSPoint
    let edge: NSRectEdge?
    let contentRect: NSRect
    weak var control: Control?
    
}

open class Popover: NSObject {
    
    private weak var window:Window?
    
    private var disposable:MetaDisposable = MetaDisposable()
    
    public var animates:Bool = true
    
    public var controller:ViewController?
    
    private weak var control:Control?
    
    public var isShown:Bool = false
    
    public var overlay:OverlayControl!
    private var background:PopoverBackground = PopoverBackground(frame: NSZeroRect)
    
    public var animationStyle:AnimationStyle = AnimationStyle(duration:0.2, function:CAMediaTimingFunctionName.spring)
    
    var readyDisposable:MetaDisposable = MetaDisposable()
    private let `static`: Bool
    required public init(controller:ViewController, static: Bool) {
        self.controller = controller
//        self.background.layer?.shadowOpacity = 0.4
        self.background.layer?.rasterizationScale = CGFloat(System.backingScale)
        self.background.layer?.shouldRasterize = true
        self.background.layer?.isOpaque = false
        self.background.layer?.cornerRadius = 10
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 4
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSMakeSize(0, 0)
        self.background.shadow = shadow
        
        self.static = `static`
        super.init()
        
        background.popover = self
    }
    
    @objc func windowDidResized(_ notification: NSNotification) {
        hide()
    }
    
    private var frameValue: PopoverFrameValue!
    private func updatePopoverFrame() {
        if let parentView = window?.contentView, let control = frameValue.control, let controller = controller {
            var point:NSPoint = control.convert(NSMakePoint(0, 0), to: parentView)

            
            if let edge = frameValue.edge {
                
                switch edge {
                case .maxX:
                    point.x -= controller.frame.width
                case .maxY:
                    point.y -= controller.frame.height
                    background.flip = true
                case .minX:
                    point.x -= (controller.frame.width - control.frame.width)
                    point.y -= controller.frame.height
                    background.flip = true
                default:
                    fatalError("Not Implemented")
                }
                
                
            }
            
            if frameValue.inset.x != 0 {
                point.x += (frameValue.inset.x)
                
            }
            if frameValue.inset.y != 0 {
                point.y += frameValue.inset.y
            }
            
            
            var rect = controller.bounds
            if !NSIsEmptyRect(frameValue.contentRect) {
                rect = frameValue.contentRect
            }
            
            
            point.x = min(max(5, point.x), (parentView.frame.width - rect.width - 12) - 5)
            point.y = min(max(5, point.y), (parentView.frame.height - rect.height - 12) - 5)
                        
            background.frame = NSMakeRect(round(point.x), round(point.y), rect.width + 14, rect.height + 14)
        }
    }
    
    
    open func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint, contentRect:NSRect = NSMakeRect(7, 7, 0, 0), delayBeforeShown: Double = 0.2) -> Void {
        
        control.popover = self
        
        if let controller = controller, let parentView = control.window?.contentView {
            
            frameValue = PopoverFrameValue(inset: inset, edge: edge, contentRect: contentRect, control: control)
            
            controller.loadViewIfNeeded()
            controller.viewWillAppear(animates)
            
            self.window = control.kitWindow
            
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidResized(_:)), name: NSWindow.didResizeNotification, object: window)

            var signal = controller.ready.get() |> filter {$0} |> take(1)
            if control.controlState == .Hover && delayBeforeShown > 0.0 {
                signal = signal |> delay(delayBeforeShown, queue: Queue.mainQueue())
            }
            self.readyDisposable.set(signal.start(next: { [weak self, weak controller, weak parentView] ready in
                if let parentView = parentView {
                    for subview in parentView.subviews {
                        if let view = subview  as? PopoverBackground, view.popover?.isShown == true, view.popover?.controller?.isAutoclosePopover == true {
                            view.popover?.hide(false)
                        }
                    }
                }
                
                if let strongSelf = self, let controller = controller, let parentView = parentView, (strongSelf.inside() || (control.controlState == .Hover || control.controlState == .Highlight || strongSelf.static) || !control.userInteractionEnabled), control.window != nil, control.visibleRect != NSZeroRect {
                    
                    control.isSelected = true
                    
                    strongSelf.window?.set(escape: { [weak strongSelf] () -> KeyHandlerResult in
                        strongSelf?.hide()
                        return .invoked
                        }, with: strongSelf, priority: .modal)
                    
                    strongSelf.window?.set(handler: { () -> KeyHandlerResult in
                        return .invokeNext
                    }, with: strongSelf, for: .All)
                    
                    strongSelf.window?.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
                        if let strongSelf = self, !strongSelf.inside() && !control.mouseInside() {
                            strongSelf.hide()
                        }
                        return .invokeNext
                    },  with: strongSelf, for: .leftMouseUp, priority: .high)
                    
                    
                    strongSelf.window?.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
                        if let strongSelf = self, !strongSelf.inside() && !control.mouseInside() {
                            strongSelf.hide()
                        }
                        return .invokeNext
                    },  with: strongSelf, for: .scrollWheel, priority: .high)
                    
                    strongSelf.control = control
                    strongSelf.background.flip = false
                    
                    strongSelf.updatePopoverFrame()
                    strongSelf.background.backgroundColor = .clear
                    strongSelf.background.layer?.cornerRadius = 10
                    
                    strongSelf.overlay = OverlayControl(frame: NSMakeRect(contentRect.minX, contentRect.minY, controller.frame.width , controller.frame.height ))
                    strongSelf.overlay.backgroundColor = presentation.colors.background
                    strongSelf.overlay.layer?.cornerRadius = 10
                    strongSelf.overlay.layer?.opacity = 0.99
                    
                    
                    let bg = View(frame: NSMakeRect(strongSelf.overlay.frame.minX + 2, strongSelf.overlay.frame.minY + 2, strongSelf.overlay.frame.width - 4, strongSelf.overlay.frame.height - 4))
                    bg.layer?.cornerRadius = 10
                    bg.backgroundColor = presentation.colors.background
                    
                    strongSelf.background.addSubview(bg)
                    
                    strongSelf.background.addSubview(strongSelf.overlay)
                    
                    controller.view.setFrameOrigin(NSMakePoint(0, 0))
                    
                    
                    strongSelf.overlay.addSubview(controller.view)
                    
                    parentView.addSubview(strongSelf.background)
                    
                    
                    let result = controller.becomeFirstResponder()
                    
                    strongSelf.isShown = true
                    
                    if let _ = strongSelf.overlay {
                        if strongSelf.animates {
                            
                            var once:Bool = false
                            
                            strongSelf.background.layer?.animateAlpha(from: 0, to: 1, duration: 0.1, completion: { [weak controller] (comple) in
                                if let strongSelf = self, !once {
                                    once = true
                                    controller?.viewDidAppear(strongSelf.animates)
                                    if result == true {
                                        _ = strongSelf.window?.makeFirstResponder(controller?.firstResponder())
                                    } else if result == false {
                                        _ = strongSelf.window?.makeFirstResponder(nil)
                                    }
                                }
                                
                            })
                            
                        } else {
                            controller.viewDidAppear(strongSelf.animates)
                        }
                        
                        let nHandler:(Control) -> Void = { [weak strongSelf] control in
                            if let strongSelf = strongSelf {
                                let s = Signal<Void,NoError>.single(Void()) |> delay(0.2, queue: Queue.mainQueue()) |> then(Signal<Void,NoError>.single(Void()) |> delay(0.2, queue: Queue.mainQueue()) |> restart)
                                
                                strongSelf.disposable.set(s.start(next: { [weak strongSelf] () in
                                    if let strongSelf = strongSelf {
                                        if !strongSelf.inside() && !control.mouseInside() {
                                            if (NSEvent.pressedMouseButtons & (1 << 0)) == 0 {
                                                strongSelf.hide()
                                            }
                                        }
                                    }
                                    
                                }))
                            }
                            
                            
                        }
                        
                        var first: Bool = true
                        
                        strongSelf.window?.set(mouseHandler: { [weak strongSelf, weak control] _ -> KeyHandlerResult in
                            if let strongSelf = strongSelf, first, let control = control, !strongSelf.static {
                                if !strongSelf.inside() && !control.mouseInside() {
                                    first = false
                                    nHandler(control)
                                }
                            }
                            return .invokeNext
                        },  with: strongSelf, for: .mouseMoved, priority: .high)
                        
                        strongSelf.window?.set(mouseHandler: { [weak strongSelf] event -> KeyHandlerResult in
                            if let strongSelf = strongSelf, !strongSelf.inside() && (!control.mouseInside() || control.continuesAction) {
                                strongSelf.hide()
                                return .invokeNext
                            } else {
                                return .rejected
                            }
                        }, with: strongSelf, for: .leftMouseDown, priority: .high)
                        
                        strongSelf.window?.set(responder: { [weak controller] () -> NSResponder? in
                            return controller?.firstResponder()
                        }, with: self, priority: .high, ignoreKeys: [.Return])
                        
                        let hHandler:(Control) -> Void = { [weak strongSelf] _ in
                            
                            strongSelf?.disposable.set(nil)
                            
                        }
                        
                        strongSelf.background.set(handler: nHandler, for: .Normal)
                        strongSelf.background.set(handler: hHandler, for: .Hover)
                        
                        
                        control.set(handler: nHandler, for: .Normal)
                        control.set(handler: hHandler, for: .Hover)
                        
                        
                    }
                } else if let strongSelf = self {
                    controller?.viewWillDisappear(false)
                    controller?.viewDidDisappear(false)
                    controller?.didRemovedFromStack()
                    controller?.popover = nil
                    strongSelf.controller = nil
                    strongSelf.window?.removeAllHandlers(for: strongSelf)
                    strongSelf.window?.remove(object: strongSelf, for: .All)
                }
                
            }))
            
        }
        
    }
    
    
    public func addSubview(_ subview: View) -> Void {
        self.background.addSubview(subview)
    }
    
    func inside() -> Bool {
        
        // return true
        
        if let window = control?.window {
            let g:NSPoint = NSEvent.mouseLocation
            let w:NSPoint = window.contentView!.convert(window.convertFromScreen(NSMakeRect(g.x, g.y, 1, 1)).origin, from: nil)
            //if w.x > background.frame.minX && background
            return NSPointInRect(w, background.frame)
        }
        return false
    }
    
    
    deinit {
        self.disposable.dispose()
        self.readyDisposable.dispose()
        window?.remove(object: self, for: .All)
        background.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
    }
    
    public func hide(_ removeHandlers:Bool = true) -> Void {
        
        self.disposable.set(nil)
        self.readyDisposable.set(nil)

        
        if !isShown {
            return
        }
        
        isShown = false
        control?.isSelected = false
        window?.removeAllHandlers(for: self)
        window?.remove(object: self, for: .All)
        
        overlay?.removeLastStateHandler()
        overlay?.removeLastStateHandler()
        
        if removeHandlers {
            control?.removeLastStateHandler()
            control?.removeLastStateHandler()
        }
        
        controller?.viewWillDisappear(true)
        if animates {
            background.change(opacity: 0, animated: animates, duration: 0.15, completion: { [weak self] complete in
                guard let `self` = self else {return}
                if self === self.controller?.popover {
                    self.controller?.viewDidDisappear(true)
                    self.controller?.didRemovedFromStack()
                    self.controller?.popover = nil
                }
                self.controller = nil
                self.background.removeFromSuperview()
            })
//            for sub in background.subviews {
//
//                sub._change(opacity: 0, animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self] complete in
//                    if let strongSelf = self, !once {
//                        once = true
//
//                    }
//                })
//
//            }
        } else {
            controller?.viewDidDisappear(false)
            controller?.didRemovedFromStack()
            controller?.popover = nil
            controller = nil
            background.removeFromSuperview()
        }
    }
    
}

public func hasPopover(_ window:Window) -> Bool {
    if !window.sheets.isEmpty {
        return true
    }
    for subview in window.contentView!.subviews {
        if let subview = subview as? PopoverBackground, let popover = subview.popover {
            return popover.isShown
        }
    }
    return false
}

public func closeAllPopovers(for window: Window) {
    
    while hasPopover(window) {
        
        while !window.sheets.isEmpty {
            window.sheets.last?.orderOut(nil)
        }
        
        for subview in window.contentView!.subviews {
            if let subview = subview as? PopoverBackground, let popover = subview.popover {
                popover.hide()
            }
        }
    }
   
}

public func showPopover(for control:Control, with controller:ViewController, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint, delayBeforeShown: Double = 0.015, static: Bool = false ) -> Void {
    if let _ = control.window as? Window {
        if let popover = controller.popover {
            if popover.isShown {
                return
            }
        }
        
      //  if let event = NSApp.currentEvent, event.type == .gesture {
        
      //  }
                
        controller.popover = (controller.popoverClass as! Popover.Type).init(controller: controller, static: `static`)
        
        if let popover = controller.popover {
            popover.show(for: control, edge: edge, inset: inset, delayBeforeShown: delayBeforeShown)
        }
    }
}




