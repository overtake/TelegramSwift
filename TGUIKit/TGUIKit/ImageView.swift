//
//  ImageView.swift
//  TGUIKit
//
//  Created by keepcoder on 22/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum ImageContentGravity {
    case center
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case resize
    case resizeAspect
    case resizeAspectFill
    
    public var rawValue: String {
        switch self {
        case .center: return "center"
        case .top: return "top"
        case .bottom: return "bottom"
        case .left: return "left"
        case .right: return "right"
        case .topLeft: return "topLeft"
        case .topRight: return "topRight"
        case .bottomLeft: return "bottomLeft"
        case .bottomRight: return "bottomRight"
        case .resize: return "resize"
        case .resizeAspect: return "resizeAspect"
        case .resizeAspectFill: return "resizeAspectFill"
        }
    }
}

public class ImageView: NSView {

    public var animates:Bool = false
    
    public var image:CGImage? {
        didSet {
            self.layer?.contents = image
            if animates {
                animate()
            }
        }
    }

    public var contentGravity: ImageContentGravity = .resize {
        didSet {
            layer?.contentsGravity = contentGravity.rawValue
        }
    }
    
    public func sizeToFit() {
        if let image = self.image {
            setFrameSize(image.backingSize)
        }
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        layerContentsRedrawPolicy = .never
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func animate() -> Void {
        let  animation = CABasicAnimation(keyPath: "contents")
        animation.duration = 0.2
        self.layer?.add(animation, forKey: "contents")
    }

    override public func viewDidChangeBackingProperties() {
        if let window = self.window {
            self.layer?.contentsScale = window.backingScaleFactor/2.0;
        }
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
    
}
