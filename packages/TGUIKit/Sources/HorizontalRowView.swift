//
//  HorizontalRowView.swift
//  TGUIKit
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class HorizontalRowView: TableRowView {

    public let container: View = View()
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(container)

        container.frame = NSMakeRect(0, 0, frame.height, frame.width)
        container.frameCenterRotation = 90
    }
    
    
    
    open override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        container.backgroundColor = backdorColor
        
        let transiton: ContainedViewLayoutTransition
        if animated {
            transiton = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transiton = .immediate
        }
        transiton.updateFrame(view: container, frame: NSMakeRect(item.width, 0, item.height, item.width))
    }
    

    
    open override func addSubview(_ view: NSView) {
        container.addSubview(view)
    }
    
    deinit {
        container.removeAllSubviews()
    }
    
    open override func layout() {
        super.layout()
        container.frame = NSMakeRect(frame.size.width, 0, frame.size.height, frame.size.width)
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        guard let item = self.item else {
            super.setFrameSize(newSize)
            return
        }
        super.setFrameSize(NSMakeSize(item.width == 0 ? newSize.width : item.width, newSize.height))
       // container.setFrameSize(newSize)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
