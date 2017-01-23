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
    
    required public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.delegate = nil
        container.layer?.delegate = self
        super.addSubview(container)

        container.frame = NSMakeRect(0, 0, frame.height, frame.width)
        container.backgroundColor = .random
        if let layer = container.layer {
            layer.transform = CATransform3DTranslate(layer.transform, floorToScreenPixels(frame.height/2), floorToScreenPixels(frame.width/2.0), 1.0)
          //  layer.transform = CATransform3DScale(layer.transform, -1, 1, 1)
            layer.transform = CATransform3DRotate(layer.transform, 90 * CGFloat(M_PI) / 180, 0, 0, 1.0)
            layer.transform = CATransform3DTranslate(layer.transform, -floorToScreenPixels(frame.height/2), -floorToScreenPixels(frame.width/2.0), 1.0)
        }
    }
    
    
    
    open override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
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
