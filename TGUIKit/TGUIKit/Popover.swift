//
//  Popover.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

class PopoverBackground: View {
    override var isFlipped: Bool {
        return false
    }
}

open class Popover: NSObject {
    
    private var disposable:MetaDisposable = MetaDisposable()
    
    public var animates:Bool = true

    private var window:NSWindow
    
    public weak var controller:ViewController?
    
    private weak var control:Control?
    
    public var isShown:Bool = false
    
    
    public var overlay:OverlayControl!
    private var background:PopoverBackground = PopoverBackground(frame: NSZeroRect)
    
    public var animationStyle:AnimationStyle = AnimationStyle(duration:0.2, function:kCAMediaTimingFunctionSpring)
    
    var readyDisposable:MetaDisposable = MetaDisposable()
    
    required public init(controller:ViewController) {
        self.controller = controller

        window = NSWindow.init(contentRect: NSZeroRect, styleMask: [], backing: .buffered, defer: true, screen: NSScreen.main())
        window.backgroundColor = NSColor.clear
        
        super.init()
    }
    
 
    
    open func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint, contentRect:NSRect = NSZeroRect) -> Void {
        
        if let controller = controller, let viewWindow = control.window {
            
            controller.loadViewIfNeeded()
            controller.viewWillAppear(animates)
            
            self.readyDisposable.set( (controller.ready.get() |> take(1)).start(next: {[weak self] (ready) in
                
                if let strongSelf = self {
                    strongSelf.control = control
                    
                    var point:NSPoint = control.convert(NSMakePoint(0, 0), to: nil)
                    point = viewWindow.convertToScreen(NSMakeRect(point.x, point.y, 0, 0)).origin
                    
                    if let edge = edge {
                        
                        switch edge {
                        case .maxX:
                            point.x -= controller.frame.width
                        default:
                            fatalError("Not Implemented")
                        }
                        
                        
                    }
                    
                    point.x += inset.x
                    point.y += inset.y
                    
                    controller.viewWillAppear(strongSelf.animates)
                    
                    var rect = controller.bounds
                    if !NSIsEmptyRect(contentRect) {
                        rect = contentRect
                    }
                    
                    
                    strongSelf.window.setFrame(NSMakeRect(point.x, point.y, rect.width + TGColor.borderSize * 2, rect.height + TGColor.borderSize * 2), display: false)
                    
                    strongSelf.background.frame = NSMakeRect(0, 0, strongSelf.window.frame.width, strongSelf.window.frame.height)
                    strongSelf.background.backgroundColor = TGColor.clear
                    strongSelf.background.layer?.cornerRadius = TGColor.cornerRadius
                    
                    strongSelf.overlay = OverlayControl(frame: NSMakeRect(contentRect.minX, contentRect.minY, controller.frame.width + TGColor.borderSize * 2, controller.frame.height + TGColor.borderSize * 2))
                    strongSelf.overlay.backgroundColor = TGColor.border
                    strongSelf.overlay.layer?.cornerRadius = TGColor.cornerRadius
                    
                    //  self.window.hasShadow = true
                    
                    strongSelf.background.addSubview(strongSelf.overlay)
                    
                    
                    strongSelf.window.contentView = strongSelf.background
                    strongSelf.window.contentView?.layer?.cornerRadius = TGColor.cornerRadius
                    
                    controller.view.layer?.cornerRadius = TGColor.cornerRadius
                    controller.view.setFrameOrigin(NSMakePoint(TGColor.borderSize, TGColor.borderSize))
                    
                    strongSelf.overlay.addSubview(controller.view)
                    
                    viewWindow.addChildWindow(strongSelf.window, ordered: .above)
                    
                    strongSelf.isShown = true
                    
                    if let overlay = strongSelf.overlay {
                        if strongSelf.animates {
                            
                            var once:Bool = false
                            
                            for sub in strongSelf.background.subviews {
                                sub.layer?.animate(from: (-strongSelf.background.frame.height) as NSNumber, to: (sub.frame.minY) as NSNumber, keyPath: "position.y", timingFunction: strongSelf.animationStyle.function, duration: strongSelf.animationStyle.duration, removeOnCompletion: true, additive: false, completion:{[weak self] (comple) in
                                    if let strongSelf = self, !once {
                                        once = true
                                        controller.viewDidAppear(strongSelf.animates)
                                    }
                                    
                                    })
                                
                                sub.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: strongSelf.animationStyle.function, duration: strongSelf.animationStyle.duration)
                            }
                            
                            
                            
                        }
                        
                        let nHandler:() -> Void = { [weak self] in
                            
                            let s = Signal<Void,NoError>({ (subscriber) -> Disposable in
                                
                                subscriber.putNext()
                                
                                return ActionDisposable(action: {
                                    
                                });
                                
                            }) |> delay(0.2, queue: Queue.mainQueue())
                            
                            self?.disposable.set(s.start(next: { () in
                                
                                if let strongSelf = self {
                                    if !strongSelf.inside() {
                                        strongSelf.hide()
                                    }
                                }
                                
                            }))
                            
                        }
                        
                        let hHandler:() -> Void = { [weak self] in
                            
                            self?.disposable.set(nil)
                            
                        }
                        
                        overlay.set(handler: nHandler, for: .Normal)
                        overlay.set(handler: hHandler, for: .Hover)
                        
                        
                        control.set(handler: nHandler, for: .Normal)
                        control.set(handler: hHandler, for: .Hover)
                        
                        
                    }
                }
                
                

            }))
            
        }

    }
    
    public func addSubview(_ subview: View) -> Void {
        self.background.addSubview(subview)
    }
    
    func inside() -> Bool {
        
        let g:NSPoint = NSEvent.mouseLocation()
        let w:NSPoint = self.window.convertFromScreen(NSMakeRect(g.x, g.y, 1, 1)).origin
        let v:NSPoint = self.window.contentView!.convert(w, from: nil)
        return NSPointInRect(v, self.window.contentView!.bounds)
    }
    

    deinit {
        self.disposable.dispose()
        self.readyDisposable.dispose()
    }
    
    public func hide() -> Void {
        
        isShown = false
        
        overlay?.removeLastStateHandler()
        overlay?.removeLastStateHandler()
        
        control?.removeLastStateHandler()
        control?.removeLastStateHandler()
        
        self.disposable.dispose()
        self.readyDisposable.dispose()
        
        if animates, let overlay = overlay {
            
            var once:Bool = false
            for sub in background.subviews {
                sub.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration, completion:{[weak self] (comple) in
                    if let strongSelf = self, !once {
                        once = true
                        strongSelf.controller?.popover = nil
                        strongSelf.window.parent?.removeChildWindow(strongSelf.window)
                    }
                })
                sub.layer?.opacity = 0.0

            }
            
            
            
        } else {
            self.window.parent?.removeChildWindow(self.window)
            self.controller?.popover = nil

        }
    }
    
    
}
