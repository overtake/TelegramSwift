//
//  SelectionRectView.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 02/10/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac


public enum SelectionRectDimensions {
    case none
    case original
    case square
    case x2_3
    case x3_5
    case x3_4
    case x4_5
    case x5_7
    case x9_16
    case x16_9
    public var description: String {
        switch self {
        case .none:
            return localizedString("SelectAreaControl.Dimension.None")
        case .original:
            return localizedString("SelectAreaControl.Dimension.Original")
        case .square:
            return localizedString("SelectAreaControl.Dimension.Square")
        case .x2_3:
            return "2x3"
        case .x3_5:
            return "3x5"
        case .x3_4:
            return "3x4"
        case .x4_5:
            return "4x5"
        case .x5_7:
            return "5x7"
        case .x9_16:
            return "9x16"
        case .x16_9:
            return "16x9"
        }
    }
    
    func aspectRation(_ size: NSSize) -> CGFloat {
        switch self {
        case .none:
            return 0
        case .original:
            return size.height / size.width
        case .square:
            return 1
        case .x2_3:
            return 3 / 2
        case .x3_5:
            return 5 / 3
        case .x3_4:
            return 4 / 3
        case .x4_5:
            return 5 / 4
        case .x5_7:
            return 7 / 5
        case .x9_16:
            return 16 / 9
        case .x16_9:
            return 9 / 16
        }
    }
    
    fileprivate func applyRect(_ rect: NSRect, for corner: SelectingCorner?, areaSize: NSSize, force: Bool = false) -> NSRect {
        let aspectRatio = self.aspectRation(areaSize)
        var newCropRect = rect
        if aspectRatio > 0, corner != nil || force {
            newCropRect.size.height = rect.width * aspectRatio
        } else {
            return rect
        }
        
        let currentCenter = NSMakePoint(rect.midX, rect.midY)
        
        if (newCropRect.size.height > areaSize.height)
        {
            newCropRect.size.height = areaSize.height;
            newCropRect.size.width = newCropRect.height / aspectRatio;
        }
        
        if let corner = corner {
            switch corner {
            case .topLeft, .topRight:
                newCropRect.origin.y += (rect.height - newCropRect.height)
            default:
                break
            }
        } else {
            newCropRect.origin.x = currentCenter.x - newCropRect.width / 2;
            newCropRect.origin.y = currentCenter.y - newCropRect.height / 2;
        }
        
        
        
//        if newCropRect.maxY > areaSize.height {
//            newCropRect.origin.x = areaSize.width - newCropRect.width;
//        }
//
//        if (newCropRect.maxY > areaSize.height) {
//            newCropRect.origin.y = areaSize.height - newCropRect.size.height;
//        }
//
//
       
        return newCropRect
    }
    
    public static var all: [SelectionRectDimensions] {
        return [.original, .square, .x2_3, .x3_5, .x3_4, .x4_5, .x5_7, .x9_16, .x16_9]
    }
}

public enum SelectingCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

private func generateCorner(_ corner: SelectingCorner, _ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        
        ctx.setFillColor(color.cgColor)
        switch corner {
        case .bottomLeft:
            ctx.fill(NSMakeRect(0, 0, 2, size.height))
            ctx.fill(NSMakeRect(0, 0, size.width, 2))
        case .bottomRight:
            ctx.fill(NSMakeRect(size.width - 2, 0, 2, size.height))
            ctx.fill(NSMakeRect(0, 0, size.width, 2))
        case .topLeft:
            ctx.fill(NSMakeRect(0, 0, 2, size.height))
            ctx.fill(NSMakeRect(0, size.height - 2, size.width, 2))
        case .topRight:
            ctx.fill(NSMakeRect(size.width - 2, 0, 2, size.height))
            ctx.fill(NSMakeRect(0, size.height - 2, size.width, 2))

        }
    })!
}

public func generateSelectionAreaCorners(_ color: NSColor) -> (topLeft: CGImage, topRight: CGImage, bottomLeft: CGImage, bottomRight: CGImage) {
    return (topLeft: generateCorner(.topLeft, color), topRight: generateCorner(.topRight, color), bottomLeft: generateCorner(.bottomLeft, color), bottomRight: generateCorner(.bottomRight, color))
}

public class SelectionRectView: View {

    private let topLeftCorner: ImageButton = ImageButton()
    private let topRightCorner: ImageButton = ImageButton()
    private let bottomLeftCorner: ImageButton = ImageButton()
    private let bottomRightCorner: ImageButton = ImageButton()
    
    public var minimumSize: NSSize = NSMakeSize(40, 40)
    public var isCircleCap: Bool = false
    private var _updatedRect: ValuePromise<NSRect> = ValuePromise(ignoreRepeated: true)
    public var updatedRect: Signal<NSRect, NoError> {
        return _updatedRect.get()
    }
    
    public var dimensions: SelectionRectDimensions = .none {
        didSet {
            if oldValue != dimensions && selectedRect != NSZeroRect {
              //  applyRect(selectedRect, force: true)
            }
        }
    }
    
    private var startSelectedRect: NSPoint? = nil
    private var moveSelectedRect: NSPoint? = nil

    public private(set) var selectedRect: NSRect = NSZeroRect {
        didSet {
            updateRectLayout()
            _updatedRect.set(selectedRect)
        }
    }
    
    public var topLeftPosition: NSPoint {
        return topLeftCorner.frame.origin
    }
    public var topRightPosition: NSPoint {
        return topRightCorner.frame.origin
    }
    public var bottomLeftPosition: NSPoint {
        return bottomLeftCorner.frame.origin
    }
    public var bottomRightPosition: NSPoint {
        return bottomRightCorner.frame.origin
    }
    
    public var isWholeSelected: Bool {
        let rect = NSMakeRect(0, 0, frame.width, frame.height)
        return rect == selectedRect
    }
    
    private var highlighedRect: NSRect {
        return NSMakeRect(max(1, selectedRect.minX), max(1, selectedRect.minY), min(selectedRect.width, frame.width - 2), min(selectedRect.height, frame.height - 2))
    }
    
    private func updateRectLayout() {
        topLeftCorner.setFrameOrigin(highlighedRect.minX - 2, highlighedRect.minY - 2)
        topRightCorner.setFrameOrigin(highlighedRect.maxX - topRightCorner.frame.width + 2, highlighedRect.minY - 2)

        bottomLeftCorner.setFrameOrigin(highlighedRect.minX - 2, highlighedRect.maxY - bottomLeftCorner.frame.height + 2)
        bottomRightCorner.setFrameOrigin(highlighedRect.maxX - topRightCorner.frame.width + 2, highlighedRect.maxY - bottomRightCorner.frame.height + 2)
        needsDisplay = true
    }
    
    private var currentCorner: SelectingCorner? = nil
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        currentCorner = nil
        guard let window = window else {return}
        var point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        point = NSMakePoint(ceil(point.x), ceil(point.y))
        if NSPointInRect(point, topLeftCorner.frame) {
            currentCorner = .topLeft
        } else if NSPointInRect(point, topRightCorner.frame) {
            currentCorner = .topRight
        } else if NSPointInRect(point, bottomLeftCorner.frame) {
            currentCorner = .bottomLeft
        } else if NSPointInRect(point, bottomRightCorner.frame) {
            currentCorner = .bottomRight
        } else if NSPointInRect(point, selectedRect) {
            startSelectedRect = selectedRect.origin
            moveSelectedRect = point
        } else {
            moveSelectedRect = nil
            startSelectedRect = nil
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2, NSPointInRect(point, selectedRect) {
            applyRect(bounds)
        }
        moveSelectedRect = nil
        startSelectedRect = nil
        currentCorner = nil
    }
    
    
    public override func mouseDragged(with event: NSEvent) {
        guard let window = window else {return}
        let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if let currentCorner = currentCorner {
            applyDragging(currentCorner)
        } else {
            if let current = moveSelectedRect, let selectedOriginPoint = startSelectedRect {
                let new = NSMakePoint(current.x - ceil(point.x), current.y - ceil(point.y))
                applyRect(NSMakeRect(selectedOriginPoint.x - new.x, selectedOriginPoint.y - new.y, selectedRect.width, selectedRect.height))
            } else {
                super.mouseDragged(with: event)
            }
        }
    }
    
    
    public override func layout() {
        super.layout()
        needsDisplay = true
        updateRectLayout()
    }
    
    
    public var inDragging: Bool {
        return currentCorner != nil || moveSelectedRect != nil
    }
    
    public func applyRect(_ newRect: NSRect, force: Bool = false, dimensions: SelectionRectDimensions = .none) {
        self.dimensions = dimensions
        selectedRect = dimensions.applyRect(NSMakeRect(min(max(0, newRect.minX), frame.width - newRect.width), min(max(0, newRect.minY), frame.height - newRect.height), max(min(newRect.width, frame.width), minimumSize.width), max(min(newRect.height, frame.height), minimumSize.height)), for: self.currentCorner, areaSize: frame.size, force: force)
    }

    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(topLeftCorner)
        addSubview(topRightCorner)
        addSubview(bottomLeftCorner)
        addSubview(bottomRightCorner)

        
        topLeftCorner.autohighlight = false
        topRightCorner.autohighlight = false
        bottomLeftCorner.autohighlight = false
        bottomRightCorner.autohighlight = false
        
        topLeftCorner.set(image: generateCorner(.topLeft, .white), for: .Normal)
        topRightCorner.set(image: generateCorner(.topRight, .white), for: .Normal)
        bottomLeftCorner.set(image: generateCorner(.bottomLeft, .white), for: .Normal)
        bottomRightCorner.set(image: generateCorner(.bottomRight, .white), for: .Normal)
        
        topLeftCorner.setFrameSize(NSMakeSize(20, 20))
        topRightCorner.setFrameSize(NSMakeSize(20, 20))
        bottomLeftCorner.setFrameSize(NSMakeSize(20, 20))
        bottomRightCorner.setFrameSize(NSMakeSize(20, 20))
        
        topLeftCorner.userInteractionEnabled = false
        topRightCorner.userInteractionEnabled = false
        bottomLeftCorner.userInteractionEnabled = false
        bottomRightCorner.userInteractionEnabled = false
        
        
//        topLeftCorner.set(handler: { [weak self] control in
//            self?.applyDragging(.topLeft)
//        }, for: .MouseDragging)
//
//        topRightCorner.set(handler: { [weak self] control in
//            self?.applyDragging(.topRight)
//        }, for: .MouseDragging)
//
//        bottomLeftCorner.set(handler: { [weak self] control in
//            self?.applyDragging(.bottomLeft)
//        }, for: .MouseDragging)
//
//        bottomRightCorner.set(handler: { [weak self] control in
//             self?.applyDragging(.bottomRight)
//        }, for: .MouseDragging)
    }
    
    private func applyDragging(_ corner: SelectingCorner) {
        moveSelectedRect = nil
        startSelectedRect = nil
        
        guard let window = window else {return}
        var current = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        current = NSMakePoint(min(max(0, ceil(current.x)), frame.width), min(max(0, ceil(current.y)), frame.height))
        
        
//        guard NSPointInRect(current, frame) else {
//            return
//        }
        let newRect: NSRect
        switch corner {
        case .topLeft:
            newRect = NSMakeRect(current.x, current.y, (frame.width - current.x) - (frame.width - selectedRect.maxX), (frame.height - current.y) - (frame.height - selectedRect.maxY))
        case .topRight:
            newRect = NSMakeRect(selectedRect.minX, current.y, frame.width - selectedRect.minX - (frame.width - current.x), (frame.height - current.y) - (frame.height - selectedRect.maxY))
        case .bottomLeft:
            newRect = NSMakeRect(current.x, selectedRect.minY, (frame.width - current.x) - (frame.width - selectedRect.maxX), frame.height - selectedRect.minY - (frame.height - current.y))
        case .bottomRight:
            newRect = NSMakeRect(selectedRect.minX, selectedRect.minY, frame.width - selectedRect.minX - (frame.width - current.x), frame.height - selectedRect.minY - (frame.height - current.y))
        }

        applyRect(newRect)
        
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(NSColor.blackTransparent.cgColor)
        
        let rect = NSMakeRect(max(1, selectedRect.minX), max(1, selectedRect.minY), min(selectedRect.width, frame.width - 2), min(selectedRect.height, frame.height - 2))
        
        ctx.setBlendMode(.normal)
        ctx.fill(bounds)
        
        ctx.setBlendMode(.clear)
        if isCircleCap {
            ctx.fillEllipse(in: rect)
        } else {
            ctx.fill(rect)
            ctx.setBlendMode(.normal)
            ctx.setStrokeColor(.white)
            ctx.setLineWidth(1)
            ctx.stroke(rect)
        }
    }
    
}
