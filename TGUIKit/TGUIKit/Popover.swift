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
    
    public weak var controller:ViewController?
    
    private weak var control:Control?
    
    public var isShown:Bool = false
    
    
    public var overlay:OverlayControl!
    private var background:PopoverBackground = PopoverBackground(frame: NSZeroRect)
    
    public var animationStyle:AnimationStyle = AnimationStyle(duration:0.2, function:kCAMediaTimingFunctionSpring)
    
    var readyDisposable:MetaDisposable = MetaDisposable()
    
    required public init(controller:ViewController) {
        self.controller = controller
        self.background.layer?.shadowOpacity = 0.35
        self.background.layer?.rasterizationScale = CGFloat(System.backingScale)
        self.background.layer?.shouldRasterize = true
        
        self.background.layer?.shadowOffset = NSMakeSize(0, -1)

       // self.background.wantsLayer = false
       
        super.init()
    }
    
 
    
    open func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint, contentRect:NSRect = NSZeroRect) -> Void {
        
        if let controller = controller, let parentView = control.window?.contentView {
            
            controller.loadViewIfNeeded()
            controller.viewWillAppear(animates)
            
            self.readyDisposable.set( (controller.ready.get() |> take(1)).start(next: {[weak self] (ready) in
                
                if let strongSelf = self {
                    strongSelf.control = control
                    
                    var point:NSPoint = control.convert(NSMakePoint(0, 0), to: parentView)
                    
                    if let edge = edge {
                        
                        switch edge {
                        case .maxX:
                            point.x -= controller.frame.width
                        case .maxY:
                            point.y -= controller.frame.height
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
                    
                    parentView.layer?.isOpaque = true
                    
                    //TGColor.borderSize * 2
                    strongSelf.background.frame = NSMakeRect(point.x, point.y, rect.width + 14, rect.height + 14)
                    strongSelf.background.backgroundColor = TGColor.clear
                    strongSelf.background.layer?.cornerRadius = TGColor.cornerRadius
                    
                    strongSelf.overlay = OverlayControl(frame: NSMakeRect(contentRect.minX, contentRect.minY, controller.frame.width , controller.frame.height ))
                    strongSelf.overlay.backgroundColor = TGColor.white
                    strongSelf.overlay.layer?.cornerRadius = TGColor.cornerRadius
                    
                    
                    strongSelf.background.addSubview(strongSelf.overlay)

                    
                    controller.view.layer?.cornerRadius = TGColor.cornerRadius
                    controller.view.setFrameOrigin(NSMakePoint(0, 0))
                    
                    
                    strongSelf.overlay.addSubview(controller.view)
                    
                    parentView.addSubview(strongSelf.background)
                    
                    strongSelf.overlay.center()
                    
                    controller.becomeFirstResponder()
                    
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
                                
                                if let strongSelf = self, control.controlState == .Normal {
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
        
       // return true
        
        if let window = control?.window, let content = window.contentView {
            let g:NSPoint = NSEvent.mouseLocation()
            let w:NSPoint = window.convertFromScreen(NSMakeRect(g.x, g.y, 1, 1)).origin
            //if w.x > background.frame.minX && background
            return NSPointInRect(w, background.frame)
        }
        return false
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
                        strongSelf.background.removeFromSuperview()
                    }
                })
                sub.layer?.opacity = 0.0

            }
            
            
            
        } else {
            self.background.removeFromSuperview()
            self.controller?.popover = nil

        }
    }
    
    
}
