//
//  ImageView.swift
//  TGUIKit
//
//  Created by keepcoder on 22/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public enum ImageViewTransition {
    case `default`
    case modern
}

open class ImageView: NSView {

    
    public var isEventLess: Bool = false
    
    public var animationTransition: ImageViewTransition = .default
    open var animates:Bool = false
    
    open var image:CGImage? {
        didSet {
            let wasImage = self.layer?.contents != nil
            self.layer?.contents = image
            if animates {
                if !wasImage {
                    self.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                } else {
                    animate()
                }
            }
        }
    }

    open var contentGravity: CALayerContentsGravity = .center {
        didSet {
            layer?.contentsGravity = contentGravity
        }
    }
    
    open func sizeToFit() {
        if let image = self.image {
            setFrameSize(image.backingSize)
        }
    }
    
    open override func hitTest(_ point: NSPoint) -> NSView? {
        if isEventLess {
            let view = super.hitTest(point)
            if let view = view as? View {
                if view.isEventLess || view === self {
                    return nil
                }
            }
            if let view = view as? ImageView {
                if view.isEventLess || view === self {
                    return nil
                }
            }
            return view
        } else {
            return super.hitTest(point)
        }
    }

    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    open override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }
    
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        layerContentsRedrawPolicy = .never
    }
    init() {
        super.init(frame: .zero)
        self.wantsLayer = true
        layerContentsRedrawPolicy = .never
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func animate() -> Void {
        let  animation = CABasicAnimation(keyPath: "contents")
        animation.duration = 0.2
        self.layer?.add(animation, forKey: "contents")
    }

    override open func viewDidChangeBackingProperties() {
        if let window = self.window {
            self.layer?.contentsScale = window.backingScaleFactor
        }
    }
    
    open func change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) -> Void  {
        super._change(pos: position, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    open func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    open func change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        super._change(opacity: to, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }


    
}
