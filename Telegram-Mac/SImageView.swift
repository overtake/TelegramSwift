//
//  SImageView.swift
//  Telegram
//
//  Created by keepcoder on 04/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class SImageView: NSView {

    init() {
        super.init(frame: NSZeroRect)
        wantsLayer = true
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required override init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    var data: (CGImage, NSEdgeInsets)? {
        didSet {
            if let image = data {
                layer?.contentsScale = 2.0
                let imageSize = image.0.backingSize
                let insets = image.1
                let halfPixelFudge: CGFloat = 0.49
                let otherPixelFudge: CGFloat = 0.02
                var contentsCenter: CGRect  = NSMakeRect(0.0, 0.0, 1.0, 1.0);
                if (insets.left > 0 || insets.right > 0) {
                    contentsCenter.origin.x = ((insets.left + halfPixelFudge) / imageSize.width);
                    contentsCenter.size.width = (imageSize.width - (insets.left + insets.right + 1.0) + otherPixelFudge) / imageSize.width;
                }
                if (insets.top > 0 || insets.bottom > 0) {
                    contentsCenter.origin.y = ((insets.top + halfPixelFudge) / imageSize.height);
                    contentsCenter.size.height = (imageSize.height - (insets.top + insets.bottom + 1.0) + otherPixelFudge) / imageSize.height;
                }
                self.layer?.contentsGravity = kCAGravityResize;
                self.layer?.contentsCenter = contentsCenter;
                self.layer?.contents = image.0
            } else {
                self.layer?.contents = nil
            }
            
        }
    }
    
    
}
