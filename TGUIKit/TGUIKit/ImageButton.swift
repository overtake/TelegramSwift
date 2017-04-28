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
        
        if state == .Normal  {
            if autohighlight {
                set(image: style.highlight(image: image), for: .Highlight)
            }
            if highlightHovered {
                set(image: style.highlight(image: image), for: .Hover)
            }
            
        }
        apply(state: self.controlState)
    }
    
    open override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        if autohighlight, let _ = images[.Highlight], let image = images[.Normal] {
            set(image: style.highlight(image: image), for: .Highlight)
        }
    }
    
    override func prepare() {
        super.prepare()
        imageView.animates = true
        self.addSubview(imageView)
    }
    
    override public func apply(state: ControlState) {
        let state:ControlState = self.isSelected ? .Highlight : state
        super.apply(state: state)
        updateLayout()

        if let image = images[state] {
            imageView.image = image
        } else {
            imageView.image = images[.Normal]
        }
    }
    
    
    
    override public func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) {
        super.sizeToFit(addition)
        
        if let image = images[.Normal] {
            var size = image.backingSize
            
            if maxSize.width > 0 || maxSize.height > 0 {
                size = maxSize
            }
            
            size.width += addition.width
            size.height += addition.height
            self.setFrameSize(size)
        }
    }
    
    public override func updateLayout() {
        if let image = images[controlState] {
            imageView.setFrameSize(image.backingSize)
        }
        imageView.center()
    }
    
}
