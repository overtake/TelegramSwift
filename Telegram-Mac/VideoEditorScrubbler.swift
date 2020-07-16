//
//  VideoEditorScrubbler.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/07/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

private final class ScrubberMoveView: Control {
    private let view = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        view.isEventLess = true
        addSubview(view)
        view.layer?.cornerRadius = 2
        view.backgroundColor = .white
    }
    
    
    override func layout() {
        super.layout()
        view.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ScrubberLeftCrop: Control {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.round(bounds, flags: [.left, .top, .bottom])
        ctx.setFillColor(NSColor.grayText.cgColor)
        ctx.fill(bounds)
    }
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ScrubberRightCrop: Control {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.round(bounds, flags: [.right, .top, .bottom])
        ctx.setFillColor(NSColor.grayText.cgColor)
        ctx.fill(bounds)
    }
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct VideoScrubberValues : Equatable {
    let movePos: CGFloat
    let leftCrop: CGFloat
    let rightCrop: CGFloat
    let minDist: CGFloat
    let paused: Bool
    init(movePos: CGFloat, leftCrop: CGFloat, rightCrop: CGFloat, minDist: CGFloat, paused: Bool) {
        self.movePos = movePos
        self.leftCrop = leftCrop
        self.rightCrop = rightCrop
        self.minDist = minDist
        self.paused = paused
    }
    
    func withUpdatedMove(_ movePos: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: min(max(0, movePos), 1), leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, paused: paused)
    }
    func withUpdatedLeftCrop(_ leftCrop: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, leftCrop: min(max(0, leftCrop), 1), rightCrop: rightCrop, minDist: minDist, paused: paused)
    }
    func withUpdatedRightCrop(_ rightCrop: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, leftCrop: leftCrop, rightCrop: min(max(0, rightCrop), 1), minDist: minDist, paused: paused)
    }
    func withUpdatedMinDist(_ minDist: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, paused: paused)
    }
    func withUpdatedPaused(_ paused: Bool) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, paused: paused)
    }
}

class VideoEditorScrubblerControl : View, ViewDisplayDelegate {
    private let scrubber: ScrubberMoveView
    private var imageViewsContainer: View = View()
    private let overlay: View = View()
    private let distance = Control()
    private let leftCrop: ScrubberLeftCrop = ScrubberLeftCrop(frame: .zero)
    private let rightCrop: ScrubberRightCrop = ScrubberRightCrop(frame: .zero)

    private var values = VideoScrubberValues(movePos: 0, leftCrop: 0, rightCrop: 1.0, minDist: 0, paused: false)
    
    var updateValues:((VideoScrubberValues)->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        scrubber = ScrubberMoveView(frame: NSMakeRect(0, 0, 4, frameRect.height))
        super.init(frame: frameRect)
        addSubview(self.imageViewsContainer)
        addSubview(self.scrubber)
        imageViewsContainer.layer?.cornerRadius = .cornerRadius
        imageViewsContainer.backgroundColor = .blackTransparent
        
        overlay.isEventLess = true
        overlay.displayDelegate = self
        overlay.layer?.cornerRadius = .cornerRadius
        addSubview(overlay)
        
        addSubview(leftCrop)
        addSubview(rightCrop)
        
        addSubview(distance)
        
        
        func possibleDrag(_ value: CGFloat) -> Bool {
            return value >= 0 && value <= 1
        }
        
        var leftCropStart: NSPoint? = nil
        var rightCropStart: NSPoint? = nil
        var distanceStart: NSPoint? = nil


        leftCrop.set(handler: { control in
            leftCropStart = control.window?.mouseLocationOutsideOfEventStream ?? nil
        }, for: .Down)
        
        leftCrop.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            leftCropStart = nil
            self.updateValues?(self.values.withUpdatedPaused(false))
        }, for: .Up)
        
        
        leftCrop.set(handler: { [weak self] control in
            guard let `self` = self, let start = leftCropStart, let current = control.window?.mouseLocationOutsideOfEventStream else {
                return
            }
            
            let difference = start - current
            
            let width = self.frame.width - control.frame.width
            
            let newValue = control.frame.origin - difference
            
            let percent = newValue.x / width
            
            if (self.values.rightCrop - percent) > self.values.minDist {
                if possibleDrag(percent) {
                    leftCropStart = current
                    control.setFrameOrigin(newValue)
                }
                self.updateValues?(self.values.withUpdatedLeftCrop(percent).withUpdatedPaused(true))
            }
        }, for: .MouseDragging)
        
        
        rightCrop.set(handler: { control in
            rightCropStart = control.window?.mouseLocationOutsideOfEventStream ?? nil
        }, for: .Down)
        
        rightCrop.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            rightCropStart = nil
            self.updateValues?(self.values.withUpdatedPaused(false))
        }, for: .Up)
        
        
        rightCrop.set(handler: { [weak self] control in
            guard let `self` = self, let start = rightCropStart, let current = control.window?.mouseLocationOutsideOfEventStream else {
                return
            }
            let difference = start - current
            let width = self.frame.width - control.frame.width

            let newValue = control.frame.origin - difference
            let percent = newValue.x / width
            
            if (percent - self.values.leftCrop) > self.values.minDist {
                if possibleDrag(newValue.x / width) {
                    rightCropStart = current
                    control.setFrameOrigin(newValue)
                }
                self.updateValues?(self.values.withUpdatedRightCrop(percent).withUpdatedPaused(true))
            }
        }, for: .MouseDragging)
        
        
        distance.set(handler: { control in
            distanceStart = control.window?.mouseLocationOutsideOfEventStream ?? nil
        }, for: .Down)
        
        distance.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            distanceStart = nil
            self.updateValues?(self.values.withUpdatedPaused(false))
        }, for: .Up)
        
        
        distance.set(handler: { [weak self] control in
            guard let `self` = self, let start = distanceStart, let current = control.window?.mouseLocationOutsideOfEventStream else {
                return
            }
            let difference = start - current
            let value = difference.x / (self.frame.width - 8)
            
            let leftValue = self.values.leftCrop - value
            let rightValue = self.values.rightCrop - value
            if possibleDrag(leftValue) && possibleDrag(rightValue) {
                distanceStart = current
                let newValues = self.values.withUpdatedLeftCrop(leftValue).withUpdatedRightCrop(rightValue).withUpdatedPaused(true)
                self.updateValues?(newValues)
            }

        }, for: .MouseDragging)
        

        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        if layer == overlay.layer {
            //left
            ctx.setFillColor(NSColor.blackTransparent.cgColor)
            if values.leftCrop > 0 {
                ctx.fill(NSMakeRect(0, 0, leftCrop.frame.maxX, imageViewsContainer.frame.height))
            }
            if values.rightCrop < 1 {
                ctx.fill(NSMakeRect(rightCrop.frame.minX, 0, imageViewsContainer.frame.width - self.rightCrop.frame.minX, imageViewsContainer.frame.height))
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func render(_ images: [CGImage]) {
        
        while imageViewsContainer.subviews.count > images.count {
            imageViewsContainer.subviews.removeLast()
        }
        while imageViewsContainer.subviews.count < images.count {
            let view = ImageView()
            view.animates = true
            imageViewsContainer.addSubview(view)
        }
        
        for (i, image) in images.enumerated() {
            (imageViewsContainer.subviews[i] as? ImageView)?.image = image
            (imageViewsContainer.subviews[i] as? ImageView)?.setFrameSize(image.systemSize)
        }
        
        needsLayout = true
        overlay.needsDisplay = true
    }
    
    func apply(values: VideoScrubberValues) {
        let previousPaused = self.values.paused
        self.values = values
        if previousPaused != values.paused {
            self.scrubber.change(opacity: values.paused ? 0 : 1, animated: !values.paused)
        }
        needsLayout = true
        overlay.needsDisplay = true
    }
    
    override func layout() {
        super.layout()
        self.imageViewsContainer.setFrameSize(NSMakeSize(frame.width, frame.height - 4))
        self.imageViewsContainer.center()
        
        leftCrop.frame = NSMakeRect(values.leftCrop * (frame.width - 8), 2, 8, frame.height - 4)
        rightCrop.frame = NSMakeRect(values.rightCrop * (frame.width - 8), 2, 8, frame.height - 4)

        
        self.scrubber.frame = CGRect(origin: NSMakePoint(values.movePos * frame.width, 0), size: NSMakeSize(4, frame.height))
        
        self.distance.frame = NSMakeRect(leftCrop.frame.maxX, imageViewsContainer.frame.minY, imageViewsContainer.frame.width - leftCrop.frame.maxX - (imageViewsContainer.frame.width - rightCrop.frame.minX), imageViewsContainer.frame.height)
        
        var x: CGFloat = 0
        for view in imageViewsContainer.subviews {
            view.setFrameOrigin(NSMakePoint(x, 0))
            x += view.frame.width
        }
        
        overlay.frame = imageViewsContainer.frame
    }
}
