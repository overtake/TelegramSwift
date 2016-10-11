//
//  BarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class BarView: View {
    
    public var minWidth:CGFloat = 80

    override open func draw(_ layer: CALayer, in ctx: CGContext) {
        
        super.draw(layer, in: ctx)
        
    }
    
    override init() {
        super.init()
        self.border = [.Bottom]
        self.frame = NSMakeRect(0, 0, minWidth, 50)
    }
    
    override required public init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
