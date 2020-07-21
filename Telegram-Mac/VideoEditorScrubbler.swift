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
    let maxDist: CGFloat
    let paused: Bool
    let keyFrame: CGFloat?
    let suspended: Bool
    init(movePos: CGFloat, keyFrame: CGFloat?, leftCrop: CGFloat, rightCrop: CGFloat, minDist: CGFloat, maxDist: CGFloat, paused: Bool, suspended: Bool) {
        self.movePos = movePos
        self.keyFrame = keyFrame
        self.leftCrop = leftCrop
        self.rightCrop = rightCrop
        self.minDist = minDist
        self.paused = paused
        self.maxDist = maxDist
        self.suspended = suspended
    }
    
    func withUpdatedMove(_ movePos: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: min(max(0, movePos), 1), keyFrame: keyFrame, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedLeftCrop(_ leftCrop: CGFloat) -> VideoScrubberValues {
        var keyFrame = self.keyFrame
        if let frame = keyFrame, leftCrop > frame {
            keyFrame = nil
        }
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftCrop: min(max(0, leftCrop), 1), rightCrop: rightCrop, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedRightCrop(_ rightCrop: CGFloat) -> VideoScrubberValues {
        var keyFrame = self.keyFrame
        if let frame = keyFrame, rightCrop < frame {
            keyFrame = nil
        }
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftCrop: leftCrop, rightCrop: min(max(0, rightCrop), 1), minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedMinDist(_ minDist: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedMaxDist(_ maxDist: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedPaused(_ paused: Bool) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    
    func withUpdatedKeyFrame(_ keyFrame: CGFloat?) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedSuspended(_ suspended: Bool) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftCrop: leftCrop, rightCrop: rightCrop, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
}

class VideoEditorScrubblerControl : View, ViewDisplayDelegate {
    private let scrubber: ScrubberMoveView
    private var imageViewsContainer: View = View()
    private let overlay: View = View()
    private let distance = Control()
    private let leftCrop: ScrubberLeftCrop = ScrubberLeftCrop(frame: .zero)
    private let rightCrop: ScrubberRightCrop = ScrubberRightCrop(frame: .zero)
    
    private var values = VideoScrubberValues(movePos: 0, keyFrame: nil, leftCrop: 0, rightCrop: 1.0, minDist: 0, maxDist: 1, paused: false, suspended: false)
    
    var updateValues:((VideoScrubberValues)->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        scrubber = ScrubberMoveView(frame: NSMakeRect(0, 0, 4, frameRect.height))
        super.init(frame: frameRect)
        addSubview(self.imageViewsContainer)
        imageViewsContainer.layer?.cornerRadius = .cornerRadius
        imageViewsContainer.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        addSubview(self.scrubber)

        overlay.isEventLess = true
        overlay.displayDelegate = self
        overlay.layer?.cornerRadius = .cornerRadius
        addSubview(overlay)
        
        addSubview(leftCrop)
        addSubview(rightCrop)
        
        addSubview(distance)

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.scrubber.shadow = shadow
        
        
        func possibleDrag(_ value: CGFloat) -> Bool {
            return value >= 0 && value <= 1
        }
        func checkDist(_ leftValue: CGFloat, _ rightValue: CGFloat, _ min: CGFloat, _ max: CGFloat) -> Bool {
            return (leftValue - rightValue) >= min && (leftValue - rightValue) <= max
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
            
            if checkDist(self.values.rightCrop, percent, self.values.minDist, self.values.maxDist) {
                if possibleDrag(percent) {
                    leftCropStart = current
                    control.setFrameOrigin(newValue)
                }
                if percent != self.values.leftCrop {
                    self.updateValues?(self.values.withUpdatedLeftCrop(percent).withUpdatedPaused(true))
                }
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
            var percent = newValue.x / width
            
            if percent < 0 && self.values.rightCrop > 0 {
                percent = 0
            }
            if percent > 1 && self.values.rightCrop < 1 {
                percent = 1
            }
            
            if checkDist(percent, self.values.leftCrop, self.values.minDist, self.values.maxDist) {
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
        
        
        var chooseFrame: Bool = false
        
        distance.set(handler: { [weak self] control in
            guard let `self` = self else {
                return
            }
            if !self.values.paused {
                let point = self.imageViewsContainer.convert(control.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
                let keyFrame = min(1, max(0, (point.x - self.scrubber.frame.width / 2) / self.imageViewsContainer.frame.width))
                self.updateValues?(self.values.withUpdatedSuspended(true).withUpdatedPaused(true).withUpdatedMove(keyFrame))
                chooseFrame = true
            }
            
        }, for: .LongMouseDown)
        
        
        distance.set(handler: { [weak self] control in
            guard let `self` = self else {
                return
            }
            
            let point = self.imageViewsContainer.convert(control.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
            let keyFrame = min(1, max(0, (point.x - self.scrubber.frame.width / 2) / self.imageViewsContainer.frame.width))
            var values = self.values
            if !self.values.suspended {
                if !values.paused  {
                    let point = self.imageViewsContainer.convert(control.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
                    let keyFrame = min(1, max(0, (point.x - self.scrubber.frame.width / 2) / self.imageViewsContainer.frame.width))
                    if keyFrame != values.keyFrame {
                        values = values.withUpdatedKeyFrame(keyFrame).withUpdatedMove(keyFrame).withUpdatedPaused(true).withUpdatedSuspended(true)
                    }
                } else {
                    values = values.withUpdatedPaused(false)
                }
            } else if self.values.suspended && chooseFrame {
                if keyFrame != values.keyFrame {
                    values = values.withUpdatedKeyFrame(keyFrame).withUpdatedMove(keyFrame).withUpdatedPaused(true).withUpdatedSuspended(true)
                }
            }
            self.updateValues?(values)
            chooseFrame = false
            distanceStart = nil
        }, for: .Up)
        
        
        distance.set(handler: { [weak self] control in
            guard let `self` = self, let start = distanceStart, let current = control.window?.mouseLocationOutsideOfEventStream else {
                return
            }
            
            let difference = start - current
            let value = difference.x / (self.frame.width - self.leftCrop.frame.width)
            
            if chooseFrame {
                let updatedValue = self.values.movePos - value
                if updatedValue >= self.values.leftCrop && updatedValue <= self.values.rightCrop {
                    let newValues = self.values.withUpdatedMove(updatedValue)
                    self.updateValues?(newValues)
                    distanceStart = current
                }
            } else {
                var leftValue = self.values.leftCrop - value
                var rightValue = self.values.rightCrop - value
                if leftValue < 0 && self.values.leftCrop > 0 {
                    leftValue = 0
                }
                if leftValue > 1 && self.values.leftCrop < 1 {
                    leftValue = 1
                }
                if rightValue < 0 && self.values.rightCrop > 0 {
                    rightValue = 0
                }
                if rightValue > 1 && self.values.rightCrop < 1 {
                    rightValue = 1
                }
                if possibleDrag(leftValue) && possibleDrag(rightValue) && (leftValue != self.values.leftCrop || rightValue != self.values.rightCrop) {
                    distanceStart = current
                    let newValues = self.values.withUpdatedLeftCrop(leftValue).withUpdatedRightCrop(rightValue).withUpdatedPaused(true)
                    self.updateValues?(newValues)
                }
            }
            
           
            
            

        }, for: .MouseDragging)
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        if layer == overlay.layer {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
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
    
    func render(_ images: [CGImage], size: NSSize) {
        
//        while imageViewsContainer.subviews.count > images.count {
//            imageViewsContainer.subviews.removeLast()
//        }
        while imageViewsContainer.subviews.count < images.count {
            let view = ImageView()
            view.animates = true
            imageViewsContainer.addSubview(view)
        }
        
        for (i, image) in images.enumerated() {
            (imageViewsContainer.subviews[i] as? ImageView)?.image = image
            (imageViewsContainer.subviews[i] as? ImageView)?.setFrameSize(size)
        }
        
        needsLayout = true
        overlay.needsDisplay = true
    }
    
    func apply(values: VideoScrubberValues) {
        let previousPaused = self.values.paused
        let previousSuspdended = self.values.suspended
        self.values = values
        if previousPaused != values.paused || values.suspended != previousSuspdended {
            self.scrubber.change(opacity: values.paused && !values.suspended ? 0 : 1, animated: !values.paused)
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

        
        self.scrubber.frame = CGRect(origin: NSMakePoint(min(max(values.movePos * frame.width, leftCrop.frame.maxX), rightCrop.frame.minX - self.scrubber.frame.width), 0), size: NSMakeSize(4, frame.height))
        
        self.distance.frame = NSMakeRect(leftCrop.frame.maxX, imageViewsContainer.frame.minY, imageViewsContainer.frame.width - leftCrop.frame.maxX - (imageViewsContainer.frame.width - rightCrop.frame.minX), imageViewsContainer.frame.height)
        
        var x: CGFloat = 0
        for view in imageViewsContainer.subviews {
            view.setFrameOrigin(NSMakePoint(x, 0))
            x += view.frame.width
        }
        
        overlay.frame = imageViewsContainer.frame
    }
}
