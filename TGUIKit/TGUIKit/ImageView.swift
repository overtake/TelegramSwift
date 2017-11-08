//
//  ImageView.swift
//  TGUIKit
//
//  Created by keepcoder on 22/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

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
    
    public func sizeToFit() {
        if let image = self.image {
            setFrameSize(image.backingSize)
        }
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
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
