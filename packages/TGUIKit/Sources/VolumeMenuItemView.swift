//
//  VolumeMenuItemView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import AppKit

public final class VolumeMenuItemView : Control {
    
    public var didUpdateValue:((CGFloat, Bool)->Void)? = nil
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    public var stateImages:(on: CGImage, off: CGImage)? = nil
    
    
    private var lineRect: CGRect {
        if let _ = stateImages {
            return .init(origin: .init(x: 40, y: (frame.height - 2 ) / 2), size: .init(width: frame.width - 55, height: 2))
        } else {
            return focus(NSMakeSize(frame.width - 20, 2))
        }
    }
    
    private var blobSize: NSSize {
        return NSMakeSize(6, 10)
    }
    
    private func updateValue(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let percentValue = ((point.x - lineRect.minX + 6 / 2) / lineRect.width) * maxValue
        var currentValue = min(max(minValue, percentValue), maxValue)
        
        let mid = (maxValue - minValue) / 2
        let magnify: CGFloat = 0.08
        
        if currentValue > mid - magnify && currentValue < mid + magnify {
            currentValue = mid
        }
        if currentValue <= minValue + magnify {
            currentValue = minValue
        }
        if currentValue >= maxValue - magnify {
            currentValue = maxValue
        }
        self.value = currentValue
    }
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let oldValue = self.value
        updateValue(event)
        if oldValue != value {
            didUpdateValue?(value, true)
        }
        
    }
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        didUpdateValue?(value, true)
    }
    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let oldValue = self.value
        updateValue(event)
        if oldValue != value {
            didUpdateValue?(value, false)
        }
    }
    
    public var value: CGFloat = 1 {
        didSet {
            needsDisplay = true
        }
    }
    public var minValue: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }
    public var maxValue: CGFloat = 2 {
        didSet {
            needsDisplay = true
        }
    }
    
    public var lineColor: NSColor = presentation.colors.grayUI.lighter().withAlphaComponent(0.8)
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        
        if let stateImages = stateImages {
            var imageRect = focus(stateImages.on.backingSize)
            imageRect.origin.x = 10
            if value == 0 {
                ctx.draw(stateImages.off, in: imageRect)
            } else {
                ctx.draw(stateImages.on, in: imageRect)
            }
        }
        
        ctx.setFillColor(lineColor.cgColor)

        let linePath = CGMutablePath()
        linePath.addRoundedRect(in: lineRect, cornerWidth: 1, cornerHeight: 1)
        
        
        
        linePath.addRoundedRect(in: NSMakeRect(lineRect.minX - 1, (frame.height - 6) / 2, 2, 6), cornerWidth: 1, cornerHeight: 1)
        linePath.addRoundedRect(in: NSMakeRect(lineRect.maxX - 1, (frame.height - 6) / 2, 2, 6), cornerWidth: 1, cornerHeight: 1)
        linePath.addRoundedRect(in: NSMakeRect(lineRect.midX - 1, (frame.height - 6) / 2, 2, 6), cornerWidth: 1, cornerHeight: 1)

        
        ctx.addPath(linePath)
        ctx.fillPath()
        

        
        let blobRect = CGRect(origin: NSMakePoint(lineRect.minX + ((value * lineRect.width) / maxValue) - 5, (frame.height - blobSize.height) / 2), size: blobSize)
        
        let blobPath = CGMutablePath()
        blobPath.addRoundedRect(in: blobRect, cornerWidth: blobRect.width / 2, cornerHeight: blobRect.width / 2)
        
        ctx.setFillColor(.white)
        
        ctx.addPath(blobPath)
        ctx.fillPath()

        
    }
}
