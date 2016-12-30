//
//  ImageBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 30/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class ImageBarView: BarView {
    public var button:ImageButton = ImageButton()
    
    
    public func set(image:CGImage, highlightImage:CGImage?) {
        button.set(image: image, for: .Normal)
        if let highlight = highlightImage {
            button.set(image: highlight, for: .Highlight)
        }
        button.sizeToFit()
        self.needsLayout = true
    }
    
    public override func layout() {
        super.layout()
        button.center()
    }
    
    override init() {
        super.init()
        addSubview(button)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
