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
    
}
