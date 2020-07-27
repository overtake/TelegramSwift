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

private final class ScrubberleftTrim: Control {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.round(bounds, flags: [.left, .top, .bottom])
        ctx.setFillColor(NSColor.accent.cgColor)
        ctx.fill(bounds)
    }
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ScrubberrightTrim: Control {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.round(bounds, flags: [.right, .top, .bottom])
        ctx.setFillColor(NSColor.accent.cgColor)
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
    let leftTrim: CGFloat
    let rightTrim: CGFloat
    let minDist: CGFloat
    let maxDist: CGFloat
    let paused: Bool
    let keyFrame: CGFloat?
    let suspended: Bool
    init(movePos: CGFloat, keyFrame: CGFloat?, leftTrim: CGFloat, rightTrim: CGFloat, minDist: CGFloat, maxDist: CGFloat, paused: Bool, suspended: Bool) {
        self.movePos = movePos
        self.keyFrame = keyFrame
        self.leftTrim = leftTrim
        self.rightTrim = rightTrim
        self.minDist = minDist
        self.paused = paused
        self.maxDist = maxDist
        self.suspended = suspended
    }
    
    func withUpdatedMove(_ movePos: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: min(max(0, movePos), 1), keyFrame: keyFrame, leftTrim: leftTrim, rightTrim: rightTrim, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedleftTrim(_ leftTrim: CGFloat) -> VideoScrubberValues {
        var keyFrame = self.keyFrame
        if let frame = keyFrame, leftTrim > frame {
            keyFrame = nil
        }
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftTrim: min(max(0, leftTrim), 1), rightTrim: rightTrim, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedrightTrim(_ rightTrim: CGFloat) -> VideoScrubberValues {
        var keyFrame = self.keyFrame
        if let frame = keyFrame, rightTrim < frame {
            keyFrame = nil
        }
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftTrim: leftTrim, rightTrim: min(max(0, rightTrim), 1), minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedMinDist(_ minDist: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftTrim: leftTrim, rightTrim: rightTrim, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedMaxDist(_ maxDist: CGFloat) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftTrim: leftTrim, rightTrim: rightTrim, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedPaused(_ paused: Bool) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftTrim: leftTrim, rightTrim: rightTrim, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    
    func withUpdatedKeyFrame(_ keyFrame: CGFloat?) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftTrim: leftTrim, rightTrim: rightTrim, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
    func withUpdatedSuspended(_ suspended: Bool) -> VideoScrubberValues {
        return VideoScrubberValues(movePos: movePos, keyFrame: keyFrame, leftTrim: leftTrim, rightTrim: rightTrim, minDist: minDist, maxDist: maxDist, paused: paused, suspended: suspended)
    }
}

class VideoEditorScrubblerControl : View, ViewDisplayDelegate {
    private let scrubber: ScrubberMoveView
    private var imageViewsContainer: View = View()
    private let overlay: View = View()
    private let distance = Control()
    private let leftTrim: ScrubberleftTrim = ScrubberleftTrim(frame: .zero)
    private let rightTrim: ScrubberrightTrim = ScrubberrightTrim(frame: .zero)
    
    private var values = VideoScrubberValues(movePos: 0, keyFrame: nil, leftTrim: 0, rightTrim: 1.0, minDist: 0, maxDist: 1, paused: false, suspended: false)
    
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
        
        addSubview(leftTrim)
        addSubview(rightTrim)
        
        addSubview(distance)

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.scrubber.shadow = shadow
        
        
        let shadow1 = NSShadow()
        shadow1.shadowBlurRadius = 5
        shadow1.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow1.shadowOffset = NSMakeSize(0, 2)
        self.shadow = shadow1
        
        
        func possibleDrag(_ value: CGFloat) -> Bool {
            return value >= 0 && value <= 1
        }
        func checkDist(_ leftValue: CGFloat, _ rightValue: CGFloat, _ min: CGFloat, _ max: CGFloat) -> Bool {
            return (leftValue - rightValue) >= min && (leftValue - rightValue) <= max
        }
        
        var leftTrimStart: NSPoint? = nil
        var rightTrimStart: NSPoint? = nil
        var distanceStart: NSPoint? = nil


        leftTrim.set(handler: { control in
            leftTrimStart = control.window?.mouseLocationOutsideOfEventStream ?? nil
        }, for: .Down)
        
        leftTrim.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            leftTrimStart = nil
            self.updateValues?(self.values.withUpdatedPaused(false))
        }, for: .Up)
        
        
        leftTrim.set(handler: { [weak self] control in
            guard let `self` = self, let start = leftTrimStart, let current = control.window?.mouseLocationOutsideOfEventStream else {
                return
            }
            
            let difference = start - current
            
            let width = self.frame.width - control.frame.width
            
            let newValue = control.frame.origin - difference
            
            let percent = newValue.x / width
            
            if checkDist(self.values.rightTrim, percent, self.values.minDist, self.values.maxDist) {
                if possibleDrag(percent) {
                    leftTrimStart = current
                    control.setFrameOrigin(newValue)
                }
                if percent != self.values.leftTrim {
                    self.updateValues?(self.values.withUpdatedleftTrim(percent).withUpdatedPaused(true))
                }
            }
        }, for: .MouseDragging)
        
        
        rightTrim.set(handler: { control in
            rightTrimStart = control.window?.mouseLocationOutsideOfEventStream ?? nil
        }, for: .Down)
        
        rightTrim.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            rightTrimStart = nil
            self.updateValues?(self.values.withUpdatedPaused(false))
        }, for: .Up)
        
        
        rightTrim.set(handler: { [weak self] control in
            guard let `self` = self, let start = rightTrimStart, let current = control.window?.mouseLocationOutsideOfEventStream else {
                return
            }
            let difference = start - current
            let width = self.frame.width - control.frame.width

            let newValue = control.frame.origin - difference
            var percent = newValue.x / width
            
            if percent < 0 && self.values.rightTrim > 0 {
                percent = 0
            }
            if percent > 1 && self.values.rightTrim < 1 {
                percent = 1
            }
            
            if checkDist(percent, self.values.leftTrim, self.values.minDist, self.values.maxDist) {
                if possibleDrag(newValue.x / width) {
                    rightTrimStart = current
                    control.setFrameOrigin(newValue)
                }
                self.updateValues?(self.values.withUpdatedrightTrim(percent).withUpdatedPaused(true))
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
            var values = self.values
            let point = self.imageViewsContainer.convert(control.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
            let keyFrame = min(values.rightTrim, max(values.leftTrim, (point.x - self.scrubber.frame.width / 2) / self.imageViewsContainer.frame.width))
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
                    values = values
                        .withUpdatedKeyFrame(keyFrame)
                        .withUpdatedMove(keyFrame)
                        .withUpdatedPaused(true)
                        .withUpdatedSuspended(true)
                } else {
                    values = values
                        .withUpdatedMove(keyFrame)
                        .withUpdatedPaused(false)
                        .withUpdatedSuspended(false)
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
            let value = difference.x / (self.frame.width - self.leftTrim.frame.width)
            
            if chooseFrame {
                let updatedValue = self.values.movePos - value
                if updatedValue >= self.values.leftTrim && updatedValue <= self.values.rightTrim {
                    let newValues = self.values.withUpdatedMove(updatedValue)
                    self.updateValues?(newValues)
                    distanceStart = current
                }
            } else {
                var leftValue = self.values.leftTrim - value
                var rightValue = self.values.rightTrim - value
                if leftValue < 0 && self.values.leftTrim > 0 {
                    leftValue = 0
                }
                if leftValue > 1 && self.values.leftTrim < 1 {
                    leftValue = 1
                }
                if rightValue < 0 && self.values.rightTrim > 0 {
                    rightValue = 0
                }
                if rightValue > 1 && self.values.rightTrim < 1 {
                    rightValue = 1
                }
                if possibleDrag(leftValue) && possibleDrag(rightValue) && (leftValue != self.values.leftTrim || rightValue != self.values.rightTrim) {
                    distanceStart = current
                    let newValues = self.values.withUpdatedleftTrim(leftValue).withUpdatedrightTrim(rightValue).withUpdatedPaused(true)
                    self.updateValues?(newValues)
                }
            }
            
           
            
            

        }, for: .MouseDragging)
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        if layer == overlay.layer {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
            if values.leftTrim > 0 {
                ctx.fill(NSMakeRect(0, 0, leftTrim.frame.maxX, imageViewsContainer.frame.height))
            }
            if values.rightTrim < 1 {
                ctx.fill(NSMakeRect(rightTrim.frame.minX, 0, imageViewsContainer.frame.width - self.rightTrim.frame.minX, imageViewsContainer.frame.height))
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func render(_ images: [CGImage], size: NSSize) {
        
        while imageViewsContainer.subviews.count > images.count {
            imageViewsContainer.subviews.removeLast()
        }
        while imageViewsContainer.subviews.count < images.count {
            let view = ImageView()
            view.contentGravity = .resizeAspectFill
            view.animates = true
            imageViewsContainer.addSubview(view)
        }
        
        var x: CGFloat = 0

        
        for (i, image) in images.enumerated() {
            (imageViewsContainer.subviews[i] as? ImageView)?.image = image
            (imageViewsContainer.subviews[i] as? ImageView)?.frame = NSMakeRect(x, 0, size.width, size.height)
            x += size.width
        }
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
        
        leftTrim.frame = NSMakeRect(values.leftTrim * (frame.width - 8), 2, 8, frame.height - 4)
        rightTrim.frame = NSMakeRect(values.rightTrim * (frame.width - 8), 2, 8, frame.height - 4)

        
        self.scrubber.frame = CGRect(origin: NSMakePoint(min(max(values.movePos * frame.width, leftTrim.frame.maxX), rightTrim.frame.minX - self.scrubber.frame.width), 0), size: NSMakeSize(4, frame.height))
        
        self.distance.frame = NSMakeRect(leftTrim.frame.maxX, imageViewsContainer.frame.minY, imageViewsContainer.frame.width - leftTrim.frame.maxX - (imageViewsContainer.frame.width - rightTrim.frame.minX), imageViewsContainer.frame.height)
        
        var x: CGFloat = 0
        for view in imageViewsContainer.subviews {
            view.setFrameOrigin(NSMakePoint(x, 0))
            x += view.frame.width
        }
        
        overlay.frame = imageViewsContainer.frame
    }
}
