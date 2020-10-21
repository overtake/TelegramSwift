//
//  VerticalParticleListControl.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 20/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa

private func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}
private func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

private func generateParticle(_ itemSize: NSSize, foregroundColor: NSColor) -> CGImage {
    return generateImage(itemSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        ctx.round(size, itemSize.width / 2)
        ctx.setFillColor(foregroundColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
    })!
}

private func generateList(_ count: Int, itemSize: NSSize, backgroundColor: NSColor, foregroundColor: NSColor, mask: Bool) -> CGImage {
    
    return generateImage(NSMakeSize(itemSize.width, (itemSize.height * CGFloat(count)) + (itemSize.width * CGFloat(count - 1))), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        var pos: CGPoint = .zero
        let image = generateParticle(itemSize, foregroundColor: foregroundColor)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        for _ in 0 ..< count {
            if (mask) {
                ctx.setBlendMode(.clear)
            }
            ctx.draw(image, in: CGRect(origin: pos, size: itemSize))
            pos.y += itemSize.height + itemSize.width
        }
    })!
}

public class VerticalParticleListControl: Control {
    
    private let unselected = ImageView()
    private let unselectedMask = ImageView()
    
    private let selected = ImageView()
    
    private var count: Int = 0
    private var selectedIndex: Int = -1
    private var itemSize: NSSize = .zero
    override init() {
        super.init(frame: .zero)
        setup()
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    
    
    private func setup() {
        flip = false
        unselected.isEventLess = true
        selected.isEventLess = true
        unselectedMask.isEventLess = true
        //        unselected.animates = true
        //        unselectedMask.animates = true
        //        selected.animates = true
        addSubview(unselected)
        addSubview(selected)
        addSubview(unselectedMask)
    }
    
    
    public func update(count: Int, selectedIndex: Int, animated: Bool) {
        var itemSize = NSMakeSize(frame.width, 12)
        if count <= 3 {
            itemSize.height = floor((frame.height - (CGFloat(count - 1) * frame.width)) / CGFloat(count))
        }
        
        
        if self.count != count {
            self.unselected.image = generateList(count, itemSize: itemSize, backgroundColor: presentation.colors.background, foregroundColor: presentation.colors.accentIcon.withAlphaComponent(0.2), mask: false)
            self.unselected.sizeToFit()
            
            self.unselectedMask.image = generateList(count, itemSize: itemSize, backgroundColor: presentation.colors.background, foregroundColor: presentation.colors.grayIcon.withAlphaComponent(0.2), mask: true)
            self.unselectedMask.sizeToFit()
            
        }
        if self.itemSize != itemSize {
            selected.image = generateParticle(itemSize, foregroundColor: presentation.colors.accentIcon)
            selected.sizeToFit()
        }
        
        
        var pos:NSPoint = .zero
        var selectedPoint:NSPoint = .zero
        let itemPos = NSMakePoint(0, floor((itemSize.height * CGFloat(selectedIndex)) + (CGFloat(selectedIndex) * itemSize.width)))
        let maxDifference = -(unselected.frame.height - frame.height)
        if count > 3 {
            let topDifference = itemPos.y + itemSize.height - frame.height
            pos = NSMakePoint(0, max(min(0, -topDifference - ((frame.height - itemSize.height) / 2)), maxDifference))
            
        }
        
        if pos.y == 0 {
            selectedPoint = itemPos
        } else if pos.y == maxDifference {
            selectedPoint = NSMakePoint(0, frame.height - itemSize.height)
        } else {
            selectedPoint = NSMakePoint(0, (frame.height - itemSize.height) / 2)
        }
        
        if animated {
            self.unselected.layer?.animatePosition(from: self.unselected.frame.origin - pos, to: .zero, duration: 0.4, timingFunction: .spring, additive: true)
            self.unselectedMask.layer?.animatePosition(from: self.unselectedMask.frame.origin - pos, to: .zero, duration: 0.4, timingFunction: .spring, additive: true)
            self.selected.layer?.animatePosition(from: self.selected.frame.origin - selectedPoint, to: .zero, duration: 0.4, timingFunction: .spring, additive: true)
        }
        self.unselected.setFrameOrigin(pos)
        self.unselectedMask.setFrameOrigin(pos)
        
        self.selected.setFrameOrigin(selectedPoint)
        
        self.count = count
        self.itemSize = itemSize
        self.selectedIndex = selectedIndex
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
