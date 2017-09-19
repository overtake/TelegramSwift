//
//  HorizontalRowView.swift
//  TGUIKit
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class HorizontalRowView: TableRowView {

    private var container:View = View()
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.delegate = nil
        container.layer?.delegate = self
        super.addSubview(container)

        container.frame = NSMakeRect(0, 0, frame.height, frame.width)
        container.frameCenterRotation = 90
    }
    
    
    
    open override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        container.backgroundColor = backdorColor
    }
    
    open override func draw(_ dirtyRect: NSRect) {
        
    }
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
//                ctx.translateBy(x: frame.width / 2.0, y: frame.height / 2.0)
//                ctx.scaleBy(x: -1.0, y: 1.0)
//                ctx.rotate(by: 90 * CGFloat(M_PI) / 180)
//                ctx.translateBy(x: -frame.width / 2.0, y: -frame.height / 2.0)
    }
    
    open override func addSubview(_ view: NSView) {
        container.addSubview(view)
    }
    
    deinit {
        container.removeAllSubviews()
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        container.setFrameSize(newSize)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
