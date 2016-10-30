//
//  SelectingControl.swift
//  TGUIKit
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class SelectingControl: Control {
    
   
    private var imageView:ImageView = ImageView()
    
    private var unselectedImage:CGImage
    private var selectedImage:CGImage
    
    public init(unselectedImage:CGImage, selectedImage:CGImage) {
        self.unselectedImage = unselectedImage
        self.selectedImage = selectedImage
        imageView.image = unselectedImage
        super.init(frame:NSMakeRect(0, 0, max(unselectedImage.backingSize.width,selectedImage.backingSize.width), max(unselectedImage.backingSize.height,selectedImage.backingSize.height)))
        userInteractionEnabled = false

        addSubview(imageView)
        
    }
    
    public override func layout() {
        super.layout()
        imageView.setFrameSize(unselectedImage.backingSize)
        imageView.center()
    }
    
    public func set(selected:Bool, animated:Bool = false) {
        self.isSelected = selected
        imageView.animates = animated
        imageView.image = selected ? selectedImage : unselectedImage
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
