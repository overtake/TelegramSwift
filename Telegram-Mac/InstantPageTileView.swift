//
//  InstantPageTileView.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



final class InstantPageTileView: View {
    private let tile: InstantPageTile
    
    init(tile: InstantPageTile) {
        self.tile = tile
        super.init()
        super.backgroundColor = theme.colors.background
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
//    func checkCursor(_ event: NSEvent) {
//        let location = convert(event.locationInWindow, from: nil)
//        for item in tile.items {
//            if NSPointInRect(location, item.frame) {
//                if item is InstantPageTextItem {
//                    NSCursor.iBeam().set()
//                } else {
//                    NSCursor.arrow().set()
//                }
//                break
//            } else {
//                NSCursor.arrow().set()
//            }
//        }
//    }
//    
//    override func mouseDown(with event: NSEvent) {
//        super.mouseDown(with: event)
//        
//        
//        /*
//         if let layout = layout, let (_, _) = layout.link(at: location) {
//         NSCursor.pointingHand().set()
//         } else if isSelectable {
//         NSCursor.iBeam().set()
//         } else {
//         NSCursor.arrow().set()
//         }
// */
//        
//    }
//    
//    override func mouseEntered(with event: NSEvent) {
//        super.mouseEntered(with: event)
//        checkCursor(event)
//    }
//    override func mouseExited(with event: NSEvent) {
//        super.mouseExited(with: event)
//        checkCursor(event)
//    }
//    override func mouseMoved(with event: NSEvent) {
//        super.mouseMoved(with: event)
//        checkCursor(event)
//    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
//        ctx.setFillColor(NSColor.random.cgColor)
//        ctx.fill(bounds)
        tile.draw(context: ctx)
        
        
    }
    
}
