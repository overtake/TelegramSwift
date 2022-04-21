//
//  NSImageView+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/9/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore

extension NSImageView {
    func setImage(_ image: NSImage?, animated: Bool) {
        if self.image != image {
            if animated {
                let animation = CATransition()
                animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
                animation.type = .fade
                animation.duration = 0.2
                self.layer?.add(animation, forKey: "kCATransitionImageFade")
            }
            self.image = image
        }
    }

}

class TransparentImageView : NSImageView {
    
}

extension TransparentImageView {
    open override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
