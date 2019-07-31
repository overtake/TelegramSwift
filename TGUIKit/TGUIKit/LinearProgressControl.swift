//
//  LinearProgressControl.swift
//  TGUIKit
//
//  Created by keepcoder on 28/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum  LinearProgressAlignment {
    case bottom
    case center
    case top
}

public class LinearProgressControl: Control {
    
    public var hasMinumimVisibility: Bool = false
    
    private var progressView:View!
    private var fetchingView:View!

    private var fetchingViewRanges:[View] = []
    
    private var containerView:View!
    
    private var _progress:CGFloat = 0
    private var progress:CGFloat {
        get {
            return scrubblingTempState ?? _progress
        }
        set {
            _progress = newValue
        }
    }
    
    private var fetchingProgress: CGFloat = 0
    private var fetchingProgressRanges: [Range<CGFloat>] = []
    
    public var progressHeight:CGFloat
    public var onUserChanged:((Float)->Void)?
    
    public var onLiveScrobbling:((Float?)->Void)?

    
    public var insets: NSEdgeInsets = NSEdgeInsets() {
        didSet {
            needsLayout = true
        }
    }
    public var alignment: LinearProgressAlignment = .bottom
    public var liveScrobbling: Bool = true
    
    private var scrubber: ImageButton? = nil
    
    private(set) public var scrubblingTempState: CGFloat? {
        didSet {
            needsLayout = true
            self.progressView.layer?.removeAllAnimations()
            self.scrubber?.layer?.removeAllAnimations()
        }
    }
    
    public var scrubberImage: CGImage? {
        didSet {
            if let scrubberImage = scrubberImage {
                if scrubber == nil {
                    scrubber = ImageButton()
                    scrubber?.userInteractionEnabled = false
                    scrubber?.autohighlight = false
                    scrubber!.set(image: scrubberImage, for: .Normal)
                    _ = scrubber!.sizeToFit()
                    addSubview(scrubber!)
                } else {
                    scrubber!.set(image: scrubberImage, for: .Normal)
                    _ = scrubber!.sizeToFit()
                }
                needsLayout = true
            } else {
                scrubber?.removeFromSuperview()
                scrubber = nil
            }
        }
    }
    public var roundCorners: Bool = false {
        didSet {
            containerView.layer?.cornerRadius = roundCorners ? containerView.frame.height / 2 : 0
            progressView.layer?.cornerRadius = roundCorners ? progressView.frame.height / 2 : 0
            fetchingView.layer?.cornerRadius = roundCorners ? fetchingView.frame.height / 2 : 0
            
            for view in fetchingViewRanges {
                view.layer?.cornerRadius = roundCorners ? view.frame.height / 2 : 0
            }
        }
    }
    
    public var currentValue: CGFloat {
        return progress
    }
    
    
    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        if let onUserChanged = onUserChanged, isEnabled {
            let location = containerView.convert(event.locationInWindow, from: nil)
           // if location.x >= 0 && location.x <= frame.width {
            let progress = min(max(Float(max(location.x, 0) / containerView.frame.width), 0), 1)
            if liveScrobbling {
                onUserChanged(progress)
            } else {
                self.scrubblingTempState = CGFloat(progress)
                self.onLiveScrobbling?(progress)
            }
           // }
        }
    }
    
    
    public override func mouseDown(with event: NSEvent) {
        scrubblingTempState = nil
        if let _ = onUserChanged, !liveScrobbling, isEnabled {
            let location = containerView.convert(event.locationInWindow, from: nil)
            let progress = min(max(CGFloat(max(location.x, 0) / containerView.frame.width), 0), 1)
            self.scrubblingTempState = progress
            self.onLiveScrobbling?(nil)
            // }
        } else {
            super.mouseDown(with: event)
        }
    }
    
    public var hasTemporaryState: Bool {
        return scrubblingTempState != nil
    }

    public override func mouseUp(with event: NSEvent) {
        scrubblingTempState = nil
        if let onUserChanged = onUserChanged, isEnabled {
            let location = containerView.convert(event.locationInWindow, from: nil)
            let progress = min(max(Float(max(location.x, 0) / containerView.frame.width), 0), 1)
            onUserChanged(progress)
            self.onLiveScrobbling?(nil)
        } else {
            super.mouseUp(with: event)
        }
    }
    
    public var interactiveValue:Float {
        if let window = window {
            let location = containerView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            return Float(location.x / containerView.frame.width)
        }
        return 0
    }
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        trackingArea = nil
        
        if let _ = window {
            let options:NSTrackingArea.Options = [NSTrackingArea.Options.cursorUpdate, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.enabledDuringMouseDrag, NSTrackingArea.Options.activeInKeyWindow,NSTrackingArea.Options.inVisibleRect]
            self.trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            
            self.addTrackingArea(self.trackingArea!)
        }
    }
    
    deinit {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
    }
    
    public override var style: ControlStyle {
        set {
            self.progressView.layer?.backgroundColor = newValue.foregroundColor.cgColor
            super.style = newValue
        }
        get {
            return super.style
        }
    }
    
    public var containerBackground: NSColor = .clear {
        didSet {
            containerView.backgroundColor = containerBackground
        }
    }
    
    public var fetchingColor: NSColor = presentation.colors.grayTransparent {
        didSet {
            self.fetchingView.layer?.backgroundColor = fetchingColor.cgColor
            for fetchView in fetchingViewRanges {
                fetchView.backgroundColor = fetchingColor
            }
        }
    }
    
    
    private func preparedAnimation(keyPath: String, from: NSValue, to: NSValue, duration: Double, beginTime: Double?, offset: Double, speed: Float, repeatForever: Bool = false) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.fillMode = .both
        animation.speed = speed
        animation.timeOffset = offset
        animation.isAdditive = false
        if let beginTime = beginTime {
            animation.beginTime = beginTime
        }
        return animation
    }
    
    public func set(progress:CGFloat, animated:Bool, duration: Double, beginTime: Double?, offset: Double, speed: Float, repeatForever: Bool = false) {
        let progress:CGFloat = progress.isNaN ? 1 : progress
        self.progress = progress
        let size = NSMakeSize(floorToScreenPixels(scaleFactor: backingScaleFactor, max(containerView.frame.width * self.progress, hasMinumimVisibility ? progressHeight : 0)), progressHeight)
        
        
        progressView.centerY(x: 0)
        
        let fromBounds = NSMakeRect(0, progressView.frame.minY, 0, size.height)
        let toBounds = NSMakeRect(0, progressView.frame.minY, containerView.frame.width, size.height)
        
        if animated, scrubblingTempState == nil {
            progressView.layer?.add(preparedAnimation(keyPath: "bounds", from: NSValue(rect: fromBounds), to: NSValue(rect: toBounds), duration: duration, beginTime: beginTime, offset: offset, speed: speed), forKey: "bounds")
            if let scrubber = scrubber  {
                scrubber.layer?.add(preparedAnimation(keyPath: "position", from: NSValue(point: NSMakePoint(containerView.frame.minX - scrubber.frame.width / 2, scrubber.frame.minY)), to: NSValue(point: NSMakePoint(containerView.frame.maxX - scrubber.frame.width / 2, scrubber.frame.minY)), duration: duration, beginTime: beginTime, offset: offset, speed: speed), forKey: "position")
            }
        } else {
            progressView.layer?.removeAllAnimations()
            set(progress: progress)
        }
        
        updateFetchingRanges(animated)
    }
    
    public override var frame: NSRect {
        didSet {
            layout()
        }
    }
    public func set(progress:CGFloat, animated:Bool = false, duration: Double = 0.2) {
        let progress:CGFloat = progress.isNaN ? 1 : progress
        self.progress = progress
        let size = NSMakeSize(floorToScreenPixels(scaleFactor: backingScaleFactor, max(containerView.frame.width * self.progress, hasMinumimVisibility ? progressHeight : 0)), progressHeight)

        progressView.change(size: size, animated: animated, duration: duration, timingFunction: .linear)
        if let scrubber = scrubber {
            scrubber.change(pos: NSMakePoint(containerView.frame.minX + size.width - scrubber.frame.width / 2, scrubber.frame.minY), animated: animated)
        }
        progressView.centerY(x: 0)
        
        updateFetchingRanges(animated)
    }
    
    public func set(fetchingProgress: CGFloat, animated:Bool = false, duration: Double = 0.2) {
        let fetchingProgress:CGFloat = fetchingProgress.isNaN ? 1 : fetchingProgress
        self.fetchingProgress = fetchingProgress
        let size = NSMakeSize(floorToScreenPixels(scaleFactor: backingScaleFactor, containerView.frame.width * fetchingProgress), progressHeight)
        fetchingView.change(size: size, animated: animated, duration: duration, timingFunction: .linear)
        
        fetchingView.centerY(x: 0)
    }
    
    public func set(fetchingProgressRanges: [Range<CGFloat>], animated: Bool = true) {
        self.fetchingProgressRanges = fetchingProgressRanges
        updateFetchingRanges(animated)
    }
    
    private func updateFetchingRanges(_ animated: Bool) {
        let fetchingProgressRanges = self.fetchingProgressRanges.filter({$0.contains(self.currentValue)})
        
        if self.fetchingViewRanges.count == fetchingProgressRanges.count {
            
        } else if self.fetchingViewRanges.count > fetchingProgressRanges.count {
            while self.fetchingViewRanges.count != fetchingProgressRanges.count {
                self.fetchingViewRanges.removeLast().removeFromSuperview()
            }
        } else if self.fetchingViewRanges.count < fetchingProgressRanges.count {
            while self.fetchingViewRanges.count != fetchingProgressRanges.count {
                let view = View(frame: NSMakeRect(0, 0, 0, progressHeight))
                view.backgroundColor = fetchingColor
                self.fetchingViewRanges.append(view)
                containerView.addSubview(self.fetchingViewRanges.last!, positioned: .below, relativeTo: progressView)
            }
        }
        
        for i in 0 ..< fetchingProgressRanges.count {
            let range = fetchingProgressRanges[i]
            let view = self.fetchingViewRanges[i]
            let width = (range.upperBound - range.lowerBound) * containerView.frame.width
            view.change(size: NSMakeSize(width, progressHeight), animated: animated, duration: 0.2, timingFunction: .linear)
            view.setFrameOrigin(range.lowerBound * containerView.frame.width, floorToScreenPixels(scaleFactor: backingScaleFactor, (containerView.frame.height - progressHeight) / 2))
            view.layer?.cornerRadius = roundCorners ? view.frame.height / 2 : 0
        }
    }

    

    public init(progressHeight:CGFloat = 4) {
        self.progressHeight = progressHeight
        super.init(frame: NSMakeRect(0, 0, 0, progressHeight))
        
        initialize()
    }
    
    public override func layout() {
        super.layout()
        
        switch alignment {
        case .bottom:
            containerView.frame = NSMakeRect(insets.left, frame.height - progressHeight, frame.width - insets.left - insets.right, progressHeight)
        case .top:
            containerView.frame = NSMakeRect(insets.left, 0, frame.width - insets.left - insets.right, progressHeight)
        case .center:
            containerView.frame = NSMakeRect(insets.left, floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.height - progressHeight) / 2), frame.width - insets.left - insets.right, progressHeight)
        }
        
        let size = NSMakeSize(floorToScreenPixels(scaleFactor: backingScaleFactor, max(containerView.frame.width * self.progress, hasMinumimVisibility ? progressHeight : 0)), progressHeight)
        progressView.setFrameSize(size)
        
        
        if let scrubber = scrubber {
            scrubber.centerY(x: containerView.frame.minX + size.width - scrubber.frame.width / 2)
        }

    }
    

    private func initialize() {
        
        containerView = View(frame:NSMakeRect(0, 0, 0, progressHeight))
        addSubview(containerView)

        
        fetchingView = View(frame:NSMakeRect(0, 0, 0, progressHeight))
        fetchingView.backgroundColor = style.foregroundColor
        containerView.addSubview(fetchingView)
        
        progressView = View(frame:NSMakeRect(0, 0, 0, progressHeight))
        progressView.backgroundColor = style.foregroundColor
        containerView.addSubview(progressView)
        
        userInteractionEnabled = false
        
    }
    
    
    private func updateCursor() {
        if mouseInside() && onUserChanged != nil, style.highlightColor != .clear, isEnabled {
            set(background: style.highlightColor.withAlphaComponent(0.2), for: .Hover)
        } else {
            set(background: style.backgroundColor, for: .Hover)
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateCursor()
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateCursor()
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateCursor()
    }
    
    required public init(frame frameRect: NSRect) {
        self.progressHeight = frameRect.height
        super.init(frame:frameRect)
        initialize()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
