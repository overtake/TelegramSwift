//
//  UILabel+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/9/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore

extension NSTextField {
    func setTextColor(_ color: NSColor, animated: Bool) {
        if self.textColor != color {
            if animated {
                let animation = CATransition()
                animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
                animation.type = .fade
                animation.duration = 0.2
                self.layer?.add(animation, forKey: "kCATransitionColorFade")
            }
            self.textColor = color
        }
    }
    
    func setText(_ title: String?, animated: Bool) {
        if self.stringValue != title {
            if animated {
                let animation = CATransition()
                animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
                animation.type = .fade
                animation.duration = 0.2
                self.layer?.add(animation, forKey: "kCATransitionTextFade")
            }
            self.stringValue = title ?? ""
        }
    }
}


class TransparentTextField : NSTextField {
    
}

extension TransparentTextField {
    open override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
