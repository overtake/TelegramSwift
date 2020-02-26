//
//  View+Extensions.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/10/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore



extension NSView {
    static let oneDevicePixel: CGFloat = (1.0 / max(2, min(1, 2.0)))
}

// MARK: View+Animation
public extension NSView {
    func bringToFront() {
        if var subviews = superview?.subviews, let index = subviews.firstIndex(where: { $0 === self }) {
            subviews.append(subviews.remove(at: index))
            superview?.subviews = subviews
        }
    }
    
    func layoutIfNeeded(animated: Bool) {
        View.perform(animated: animated) {
            self.needsLayout = true
        }
    }
    
    func setVisible(_ visible: Bool, animated: Bool) {
        let updatedAlpha: CGFloat = visible ? 1 : 0
        if self.alphaValue != updatedAlpha {
            View.perform(animated: animated) {
                self.alphaValue = updatedAlpha
            }
        }
    }
    
    static func perform(animated: Bool, animations: @escaping () -> Void) {
        perform(animated: animated, animations: animations, completion: { _ in })
    }
    
    static func perform(animated: Bool, animations: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        if animated {
            NSAnimationContext.runAnimationGroup({ _ in
                animations()
            }, completionHandler: {
                completion(true)
            })
            //View.animate(withDuration: .defaultDuration, delay: 0, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }
    
    var isVisibleInWindow: Bool {
        return visibleRect.height > 0
    }
}
