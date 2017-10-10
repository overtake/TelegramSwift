//
//  InstantPageShapeItem.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TelegramCoreMac

enum InstantPageShape {
    case rect
    case ellipse
    case roundLine
}

final class InstantPageShapeItem: InstantPageItem {
    var frame: CGRect
    let shapeFrame: CGRect
    let shape: InstantPageShape
    let color: NSColor
    
    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = false
    let hasLinks: Bool = false
    
    let isInteractive: Bool = false
    
    init(frame: CGRect, shapeFrame: CGRect, shape: InstantPageShape, color: NSColor) {
        self.frame = frame
        self.shapeFrame = shapeFrame
        self.shape = shape
        self.color = color
    }
    
    func drawInTile(context: CGContext) {
        context.setFillColor(self.color.cgColor)
        
        switch self.shape {
        case .rect:
            context.fill(self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY))
        case .ellipse:
            context.fillEllipse(in: self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY))
        case .roundLine:
            if self.shapeFrame.size.width < self.shapeFrame.size.height {
                let radius = self.shapeFrame.size.width / 2.0
                var shapeFrame = self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY)
                shapeFrame.origin.y += radius
                shapeFrame.size.height -= radius + radius
                context.fill(shapeFrame)
                context.fillEllipse(in: CGRect(x: shapeFrame.minX, y: shapeFrame.minY - radius, width: radius + radius, height: radius + radius))
                context.fillEllipse(in: CGRect(x: shapeFrame.minX, y: shapeFrame.maxY - radius, width: radius + radius, height: radius + radius))
            } else {
                context.fill(self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY))
            }
        }
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageView) -> Bool {
        return false
    }
    
    func node(account: Account) -> InstantPageView? {
        return nil
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}
