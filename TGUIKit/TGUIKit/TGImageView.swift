//
//  TGImageView.swift
//  TGUIKit
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class TGImageView: View {
    private var _image:NSImage?
    public var image: NSImage? {
        set {
            _image = newValue
            self.update()
        }
        
        get {
            return _image
        }
    }
    
    private var imageLayer:CALayer

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    required public init(frame frameRect: NSRect) {
        self.imageLayer = CALayer.init()
        
        super.init(frame: frameRect)
        
        self.wantsLayer = true
        
        self.imageLayer.delegate = self
        self.imageLayer.disableActions()
        self.imageLayer.masksToBounds = true;
        self.layer?.addSublayer(self.imageLayer)
        self.imageLayer.anchorPoint = NSMakePoint(0.5, 0.5)
    }
    
    public override func layout() {
        super.layout()
        self.imageLayer.bounds = self.bounds;
        self.imageLayer.position = NSMakePoint(NSMidX(self.bounds), NSMidY(self.bounds));
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update() -> Void {
        self.imageLayer.contentsCenter = NSMakeRect(0.0, 0.0, 1.0, 1.0);
        self.imageLayer.contents = self.image;
        
        self.layout()
    }
    
    public func add(_ animation:CAAnimation, forKey:String) -> Void {
        self.imageLayer.add(animation, forKey: forKey)
    }
    
    public func removeAnimation(_ forKey:String) -> Void {
        self.imageLayer.removeAnimation(forKey: forKey)
    }
    
    public var currentLayer:CALayer {
        return self.imageLayer
    }
    
    public override func viewDidChangeBackingProperties() {
        if let w = self.window {
            self.layer?.contentsScale = w.backingScaleFactor;
            self.imageLayer.contentsScale = (self.layer?.contentsScale)!;
        }
    }
    
}
