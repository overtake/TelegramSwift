//
//  AnimationStyle.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public struct AnimationStyle {

    public let duration:CFTimeInterval
    public let function:CAMediaTimingFunctionName
    public init(duration: CFTimeInterval, function: CAMediaTimingFunctionName) {
        self.duration = duration
        self.function = function
    }
}
