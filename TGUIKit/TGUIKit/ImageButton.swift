//
//  ImageButton.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class ImageButton: Button {

    var imageView:ImageView = ImageView()
    
    private var images:[ControlState:CGImage] = [:]
    private var backgroundImage:[ControlState:CGImage] = [:]
    
    
    public func removeImage(for state:ControlState) {
        images.removeValue(forKey: state)
        apply(state: self.controlState)
    }
    
    public func set(image:CGImage, for state:ControlState) -> Void {
        
        images[state] = image
        apply(state: self.controlState)
    }
    
    open override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
    }
    
    override func prepare() {
        super.prepare()
        imageView.animates = true
        self.addSubview(imageView)
    }
    
    override public func apply(state: ControlState) {
        let state:ControlState = self.isSelected ? .Highlight : state
        super.apply(state: state)

        if let image = images[state] {
            imageView.image = image
        } else if state == .Highlight && autohighlight, let image = images[.Normal] {
            imageView.image = style.highlight(image: image)
        } else if state == .Hover && highlightHovered, let image = images[.Normal] {
            imageView.image = style.highlight(image: image)
        } else {
            imageView.image = images[.Normal]
        }
        updateLayout()
    }
    
    public func disableActions() {
        animates = false
        self.layer?.disableActions()
        layer?.removeAllAnimations()
        imageView.animates = false
        imageView.layer?.disableActions()
    }
    
    
    override public func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) -> Bool {
        _ = super.sizeToFit(addition, maxSize, thatFit: thatFit)
        
        if let image = images[.Normal] {
            var size = image.backingSize
            
            if maxSize.width > 0 || maxSize.height > 0 {
                size = maxSize
            }
            
            size.width += addition.width
            size.height += addition.height
            self.setFrameSize(size)
        }
        return true
    }
    
    public override func updateLayout() {
        if let image = images[controlState] {
            imageView.setFrameSize(image.backingSize)
        }
        imageView.center()
    }
    
}
