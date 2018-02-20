//
//  MagnifyView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
open class MagnifyView : NSView {
    
    public private(set) var magnify:CGFloat = 1.0 {
        didSet {
            magnifyUpdater.set(magnify)
        }
    }
    public var maxMagnify:CGFloat = 8.0
    public var minMagnify:CGFloat = 1.0
    public let smartUpdater:Promise<NSSize> = Promise()
    public let magnifyUpdater:ValuePromise<CGFloat> = ValuePromise(ignoreRepeated: true)
    private var mov_start:NSPoint = NSZeroPoint
    private var mov_content_start:NSPoint = NSZeroPoint
    
    
    public private(set) var contentView:NSView
    let containerView:NSView = NSView()
    public var contentSize:NSSize = NSZeroSize {
        didSet {
            contentView.frame = focus(magnifiedSize)
        }
    }
    private var magnifiedSize:NSSize {
        return NSMakeSize(floorToScreenPixels(scaleFactor: backingScaleFactor, contentSize.width * magnify), floorToScreenPixels(scaleFactor: backingScaleFactor, contentSize.height * magnify))
    }
    
    public func swapView(_ newView: NSView) {
        self.contentView.removeFromSuperview()
        newView.removeFromSuperview()
        self.contentView = newView
        containerView.addSubview(newView)
        resetMagnify()
    }
    
    public init(_ contentView:NSView, contentSize:NSSize) {
        self.contentView = contentView
        contentView.setFrameSize(contentSize)
        self.contentSize = contentSize
        contentView.wantsLayer = true
        super.init(frame: NSZeroRect)
        wantsLayer = true
        containerView.wantsLayer = true
        addSubview(containerView)
        containerView.addSubview(contentView)
        contentView.background = .clear
        background = .clear
        smartUpdater.set(.single(contentSize))
    }
    
    public func resetMagnify() {
        magnify = 1.0
        contentView.setFrameSize(magnifiedSize)
        contentView.center()
    }
    
    public func zoomIn() {
        add(magnify: 0.5, for: NSMakePoint(containerView.frame.width/2, containerView.frame.height/2), animated: true)
    }
    
    public func zoomOut() {
        add(magnify: -0.5, for: NSMakePoint(containerView.frame.width/2, containerView.frame.height/2), animated: true)
    }
    
    open override func layout() {
        super.layout()
        containerView.setFrameSize(frame.size)
        contentView.center()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func magnify(with event: NSEvent) {
        super.magnify(with: event)
        
        add(magnify: event.magnification, for: containerView.convert(event.locationInWindow, from: nil))
        
        if event.phase == .ended {
            smartUpdater.set(.single(magnifiedSize) |> delay(0.3, queue: Queue.mainQueue()))
        } else if event.phase == .began {
            smartUpdater.set(smartUpdater.get())
        }
    }
    
    override open func smartMagnify(with event: NSEvent) {
        super.smartMagnify(with: event)
        addSmart(for: containerView.convert(event.locationInWindow, from: nil))
        smartUpdater.set(.single(magnifiedSize) |> delay(0.2, queue: Queue.mainQueue()))
    }
    
    func addSmart(for location:NSPoint) {
        var minFactor:CGFloat = min(max(frame.size.width / magnifiedSize.width,frame.size.height / magnifiedSize.height),2.0)
        if magnify > 1.0 {
            minFactor = 1 - magnify
        }
        add(magnify: minFactor, for: location, animated: true)
    }
    
    public func add(magnify:CGFloat, for location:NSPoint, animated:Bool = false) {
        self.magnify += magnify
        self.magnify = min(max(minMagnify,self.magnify),maxMagnify)
        let point = magnifyOrigin( for: location, from:contentView.frame, factor: magnify)
        
        //contentView.change(pos: point, animated: animated)
       // contentView.change(size: magnifiedSize, animated: animated)
        let content = animated ? contentView.animator() : contentView
        content.frame = NSMakeRect(point.x, point.y, magnifiedSize.width, magnifiedSize.height)
    }
    
    func magnifyOrigin(for location:NSPoint, from past:NSRect, factor:CGFloat) -> NSPoint {
        
        var point:NSPoint = past.origin
        let focused = focus(magnifiedSize).origin
        if NSPointInRect(location, contentView.frame) {
            if magnifiedSize.width < frame.width || magnifiedSize.height < frame.height {
                point = focused
            } else {
                point.x -= (magnifiedSize.width - past.width) * ((location.x - past.minX) / past.width)
                point.y -= (magnifiedSize.height - past.height) * ((location.y - past.minY) / past.height)
                
                point = adjust(with: point)
                
            }
        } else {
            point = focused
        }
        return point
    }
    
    override open func mouseDown(with theEvent: NSEvent) {
        self.mov_start = convert(theEvent.locationInWindow, from: nil)
        self.mov_content_start = contentView.frame.origin
    }
    
    override open func mouseUp(with theEvent: NSEvent) {
        self.mov_start = NSZeroPoint
        self.mov_content_start = NSZeroPoint
        super.mouseUp(with: theEvent)
    }
    
    override open func mouseDragged(with theEvent: NSEvent) {
        super.mouseDragged(with: theEvent)
        if (mov_start.x == 0 || mov_start.y == 0) || (frame.width > magnifiedSize.width && frame.height > magnifiedSize.height) {
            return
        }
        var current = convert(theEvent.locationInWindow, from: nil)
        current = NSMakePoint(current.x - mov_start.x, current.y - mov_start.y)
        
        let adjust = self.adjust(with: NSMakePoint(mov_content_start.x + current.x, mov_content_start.y + current.y))
        
        var point = contentView.frame.origin
        if magnifiedSize.width > frame.width {
            point.x = adjust.x
        }
        if magnifiedSize.height > frame.height {
            point.y = adjust.y
        }
        
        contentView.setFrameOrigin(point)
        
        
    }
    
    private func adjust(with point:NSPoint) -> NSPoint {
        var point = point
        point.x = floorToScreenPixels(scaleFactor: backingScaleFactor, max(min(0, point.x), point.x + (frame.width - (point.x + magnifiedSize.width))))
        point.y = floorToScreenPixels(scaleFactor: backingScaleFactor, max(min(0, point.y), point.y + (frame.height - (point.y + magnifiedSize.height))))
        return point
    }
    
    override open func scrollWheel(with event: NSEvent) {
        
        if magnify == minMagnify {
            super.scrollWheel(with: event)
            return
        }
        
        if event.type == .smartMagnify ||  event.type == .magnify || (event.scrollingDeltaY == 0 && event.scrollingDeltaX == 0)  {
            return
        }
        
        
        let content_f = contentView.frame.origin
        if (content_f.x == 0 && event.scrollingDeltaX > 0) || (content_f.x == (frame.width - magnifiedSize.width) && event.scrollingDeltaX < 0) {
           // super.scrollWheel(with: event)
            return
        }
        
        if (content_f.y == 0 && event.scrollingDeltaY < 0) || (content_f.y == (frame.height - magnifiedSize.height) && event.scrollingDeltaY > 0) {
           // super.scrollWheel(with: event)
            return
        }
        
        var point = content_f
        let adjust = self.adjust(with: NSMakePoint(content_f.x + event.scrollingDeltaX, content_f.y + -event.scrollingDeltaY))
        if event.scrollingDeltaX != 0 && magnifiedSize.width > frame.width {
            point.x = adjust.x
        }
        if event.scrollingDeltaY != 0 && magnifiedSize.height > frame.height {
            point.y = adjust.y
        }
        if point.equalTo(content_f) {
           // super.scrollWheel(with: event)
            return
        }
        
        contentView.setFrameOrigin(point)
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
    public var mouseInContent:Bool {
        if let window = window {
            let point = window.mouseLocationOutsideOfEventStream
            return NSPointInRect(convert(point, from: nil), contentView.frame)
        }
        return false
    }
    
    
}

