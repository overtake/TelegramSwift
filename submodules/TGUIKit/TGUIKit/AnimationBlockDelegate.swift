//
//  AnimationBlockDelegate.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class AnimationBlockDelegate: NSObject, CAAnimationDelegate {

    let completion:(_ complete:Bool)->Void
    
    public init(_ completion:@escaping (_ complete:Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        completion(flag)
    }
    
}
