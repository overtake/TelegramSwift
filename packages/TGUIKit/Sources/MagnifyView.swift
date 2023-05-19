//
//  MagnifyView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
open class MagnifyView : NSView {
    
    public private(set) var magnify:CGFloat = 1.0 {
        didSet {
        }
    }
    public var maxMagnify:CGFloat = 8.0
    public var minMagnify:CGFloat = 1.0
    
    private let smartUpdater:Promise<NSSize> = Promise()

    public var smartUpdaterValue: Signal<NSSize, NoError> {
        return smartUpdater.get() |> distinctUntilChanged
    }
    
    fileprivate let magnifyUpdater:Promise<CGFloat> = Promise(1)
    
    public var magnifyUpdaterValue:Signal<CGFloat, NoError> {
        return magnifyUpdater.get() |> distinctUntilChanged
    }
    
    private var mov_start:NSPoint = NSZeroPoint
    private var mov_content_start:NSPoint = NSZeroPoint
    
    
    public private(set) var contentView:NSView
    let containerView:NSView = NSView()
    open var contentSize:NSSize = NSZeroSize {
        didSet {
            if abs(oldValue.width - contentSize.width) > 1 || abs(oldValue.height - contentSize.height) > 1  {
                contentView.frame = focus(magnifiedSize)
            }
        }
    }

    
    public var contentFrame: NSRect {
        return contentView.frame.apply(multiplier: NSMakeSize(1 / magnify, 1 / magnify))
    }
    
    public var contentFrameMagnified: NSRect {
        return contentView.frame
    }
    
    private var magnifiedSize:NSSize {
        return NSMakeSize(floorToScreenPixels(backingScaleFactor, contentSize.width * magnify), floorToScreenPixels(backingScaleFactor, contentSize.height * magnify))
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
        containerView.autoresizesSubviews = false
        contentView.background = .clear
        background = .clear
        smartUpdater.set(.single(contentSize))
    }
    
    public func resetMagnify() {
        magnify = 1.0
        contentView.setFrameSize(magnifiedSize)
        contentView.center()
    }
    
    public func focusContentView() {
        contentView.center()
    }
    
    public func zoomIn() {
        add(magnify: 0.5, for: NSMakePoint(containerView.frame.width/2, containerView.frame.height/2), animated: true)
        magnifyUpdater.set(.single(magnify) |> delay(0.2, queue: .mainQueue()))
    }
    
    public func zoomOut() {
        add(magnify: -0.5, for: NSMakePoint(containerView.frame.width/2, containerView.frame.height/2), animated: true)
        magnifyUpdater.set(.single(magnify) |> delay(0.2, queue: .mainQueue()))
    }
    
    open override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    public func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: containerView, frame: bounds)
        transition.updateFrame(view: contentView, frame: contentView.centerFrame())
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func magnify(with event: NSEvent) {
       // super.magnify(with: event)
        
        add(magnify: event.magnification, for: containerView.convert(event.locationInWindow, from: nil))
        
        if event.phase == .ended {
            smartUpdater.set(.single(magnifiedSize) |> delay(0.3, queue: Queue.mainQueue()))
            magnifyUpdater.set(.single(magnify) |> delay(0.2, queue: .mainQueue()))
        } else if event.phase == .began {
            smartUpdater.set(smartUpdater.get())
        }
    }
    
    override open func smartMagnify(with event: NSEvent) {
      //  super.smartMagnify(with: event)
        addSmart(for: containerView.convert(event.locationInWindow, from: nil))
        smartUpdater.set(.single(magnifiedSize) |> delay(0.2, queue: Queue.mainQueue()))
        magnifyUpdater.set(.single(magnify) |> delay(0.2, queue: .mainQueue()))
    }
    
    func addSmart(for location:NSPoint) {
        var minFactor:CGFloat = min(max(floor(frame.size.width / magnifiedSize.width), floor(frame.size.height / magnifiedSize.height)),2.0)
        if magnify > 1.0 {
            minFactor = 1 - magnify
        }
        add(magnify: minFactor, for: location, animated: true)
    }
    
    open func add(magnify:CGFloat, for location:NSPoint, animated:Bool = false) {
        self.magnify += magnify
        self.magnify = min(max(minMagnify,self.magnify),maxMagnify)
        let point = magnifyOrigin( for: location, from:contentView.frame, factor: magnify)
        
        //contentView.change(pos: point, animated: animated)
       // contentView.change(size: magnifiedSize, animated: animated)
       // content.layer?.animateScaleCenter(from: <#T##CGFloat#>, to: <#T##CGFloat#>, duration: <#T##Double#>)
        //content.anch
        
        
        
         let content = animated ? contentView.animator() : contentView
        content.frame = NSMakeRect(point.x, point.y, magnifiedSize.width, magnifiedSize.height)
        
        
    }
    
    func magnifyOrigin(for location:NSPoint, from past:NSRect, factor:CGFloat) -> NSPoint {
        
        var point:NSPoint = past.origin
        let focused = focus(magnifiedSize).origin
        if NSPointInRect(location, contentView.frame) {
            if magnifiedSize.width < frame.width {
                point.x = focused.x
            } else {
                point.x -= (magnifiedSize.width - past.width) * ((location.x - past.minX) / past.width)
                point = adjust(with: point, adjustX: true, adjustY: false)
                
            }
            if magnifiedSize.height < frame.height {
                point.y = focused.y
            } else {
                point.y -= (magnifiedSize.height - past.height) * ((location.y - past.minY) / past.height)
                point = adjust(with: point, adjustX: false, adjustY: true)
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
    
    private func adjust(with point:NSPoint, adjustX: Bool = true, adjustY: Bool = true) -> NSPoint {
        var point = point
        if adjustX {
            point.x = floorToScreenPixels(backingScaleFactor, max(min(0, point.x), point.x + (frame.width - (point.x + magnifiedSize.width))))
        }
        if adjustY {
            point.y = floorToScreenPixels(backingScaleFactor, max(min(0, point.y), point.y + (frame.height - (point.y + magnifiedSize.height))))
        }
        return point
    }
    
    override open func scrollWheel(with event: NSEvent) {
        
        if magnify == minMagnify {
            super.scrollWheel(with: event)
            //return
        }
        
        if event.type == .smartMagnify ||  event.type == .magnify  {
            return
        }
        
        
        let content_f = contentView.frame.origin
        if (content_f.x == 0 && event.scrollingDeltaX > 0) || (content_f.x == (frame.width - magnifiedSize.width) && event.scrollingDeltaX < 0) {
           // super.scrollWheel(with: event)
         //  return
        }
        
        if (content_f.y == 0 && event.scrollingDeltaY < 0) || (content_f.y == (frame.height - magnifiedSize.height) && event.scrollingDeltaY > 0) {
           // super.scrollWheel(with: event)
          //  return
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
    
    
    open func mouseInside() -> Bool {
        return super._mouseInside()
    }
    
    
    public var mouseInContent:Bool {
        if let window = window {
            let point = window.mouseLocationOutsideOfEventStream
            return NSPointInRect(convert(point, from: nil), contentView.frame)
        }
        return false
    }
    
    
}

