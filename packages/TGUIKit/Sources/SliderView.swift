//
//  SliderView.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 02/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

public protocol SlideViewProtocol {
    func willAppear()
    func willDisappear()
}

public enum SliderTransitionStyle {
    case fade
    case pushVertical
    case pushHorizontalFromLeft
    case pushHorizontalFromRight
}

private let kDefaultScheduledTransitionTimeInterval: TimeInterval = 4.0
private let kDefaultTransitionAnimationDuration: TimeInterval = 0.6
public class SliderView: Control {
    
    public private(set) var indexOfDisplayedSlide: Int = 0
    public var displayedSlide: (NSView & SlideViewProtocol)?
    private var transitionTimer: SwiftSignalKit.Timer?
    private let contentView = View(frame: NSZeroRect)
    private let dotsControl = SliderDotsControl(frame: NSZeroRect)
    private var scrollDeltaX: CGFloat = 0
    private var scrollDeltaY: CGFloat = 0
    
    public var moveOnTime = true
    
    public var normalColor: NSColor? {
        didSet {
            dotsControl.normalColor = normalColor
        }
    }
    public var highlightColor: NSColor? {
        didSet {
            dotsControl.highlightColor = highlightColor
        }
    }
    
    
    private var slides: [NSView] = []
    private var scheduledTransitionInterval: TimeInterval = kDefaultScheduledTransitionTimeInterval {
        didSet {
            if self.scheduledTransition {
                _prepareTransitionTimer()
            }
        }
    }
    
    public var transitionAnimationDuration: TimeInterval = kDefaultTransitionAnimationDuration
    public var repeatingScheduledTransition: Bool = true
    
    public var transitionStyle: SliderTransitionStyle = .fade
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self._prepareView()
        scheduledTransition = true
        
        set(handler: { [weak self] control in
            
            let mousePoint = control.window?.mouseLocationOutsideOfEventStream ?? .zero
            
            let point = control.convert(mousePoint, from: nil)
            let slider = control as! SliderView
            if point.x < control.frame.width / 2 {
                self?.transitionStyle = .pushHorizontalFromLeft
                slider.displaySlide(at: (slider.indexOfDisplayedSlide - 1) % slider.slides.count)
            } else {
                self?.transitionStyle = .pushHorizontalFromRight
                slider.displaySlide(at: (slider.indexOfDisplayedSlide + 1) % slider.slides.count)
            }
        }, for: .Click)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setScheduledTransition(_ scheduledTransition: Bool) {
        if scheduledTransition {
            _prepareTransitionTimer()
        } else {
            transitionTimer?.invalidate()
            transitionTimer = nil
        }
    }
    
    var scheduledTransition: Bool {
        get {
            return transitionTimer != nil
        } set {
            if newValue {
                _prepareTransitionTimer()
            } else {
                transitionTimer?.invalidate()
                transitionTimer = nil
            }
        }
    }

    
    override public func layout() {
        super.layout()
        contentView.frame = bounds
        for subview in contentView.subviews {
            subview.frame = contentView.bounds
        }
        dotsControl.updateFrame()
    }
    
    @objc fileprivate func _prepareView() {
        acceptsTouchEvents = true
        addSubview(contentView)
        
        dotsControl.sliderView = self
        addSubview(dotsControl, positioned: .above, relativeTo: contentView)

    }
    @objc fileprivate func _prepareTransitionTimer() {
        transitionTimer?.invalidate()
        transitionTimer = Timer.init(timeout: scheduledTransitionInterval, repeat: true, completion: { [weak self] in
            self?._handleTimerTick()
        }, queue: .mainQueue())
    }

    @objc fileprivate func _prepareTransition(to index: Int) {
        let duration: CFTimeInterval = transitionAnimationDuration * 0.3
        let transition = CATransition()
        transition.duration = duration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        switch self.transitionStyle {
        case .fade:
            transition.type = .fade
        case .pushHorizontalFromLeft:
            transition.type = .push
            transition.subtype = .fromLeft
        case .pushHorizontalFromRight:
            transition.type = .push
            transition.subtype = .fromRight
        case .pushVertical:
            transition.type = .moveIn
            transition.subtype = .fromTop
        }
        contentView.animations = ["subviews" : transition]
    }
    @objc fileprivate func _handleTimerTick() {
        if self.moveOnTime {
            if slides.count > 0 && (repeatingScheduledTransition || indexOfDisplayedSlide + 1 < slides.count) {
                displaySlide(at: (indexOfDisplayedSlide + 1) % slides.count)
            }
        }
    }
    @objc fileprivate func _dotViewSelected(_ dotView: NSView) {
        if scheduledTransition {
            _prepareTransitionTimer()
        }
        if dotView.tag >= 0 && dotView.tag < slides.count {
            transitionStyle = dotView.tag > dotsControl.indexOfHighlightedDot ? .pushHorizontalFromRight : .pushHorizontalFromLeft
            displaySlide(at: dotView.tag)
        }
    }
    
    public func displaySlide(at aIndex: Int, animated: Bool = true) {
        
        if aIndex < 0 {
            return
        }
        
        dotsControl.indexOfHighlightedDot = aIndex
        
        let slideToDisplay = slides[aIndex] as! (NSView & SlideViewProtocol)
        if slideToDisplay === displayedSlide {
            return
        }
        slideToDisplay.willAppear()
        slideToDisplay.frame = bounds
        slideToDisplay.autoresizingMask = [.width, .height]
        
        if displayedSlide == nil {
            contentView.addSubview(slideToDisplay)
            displayedSlide = slideToDisplay
            indexOfDisplayedSlide = aIndex
            return
        }
        
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = animated ? 0.2 : 0
        NSAnimationContext.current.timingFunction = .init(name: .easeOut)
        _prepareTransition(to: aIndex)
        if let displayedSlide = displayedSlide {
            displayedSlide.willDisappear()
            contentView.animator().replaceSubview(displayedSlide, with: slideToDisplay)
        }
        NSAnimationContext.endGrouping()
        
        displayedSlide = slideToDisplay
        indexOfDisplayedSlide = aIndex
    }
    
    public func addSlide(_ aSlide: (NSView & SlideViewProtocol)?) {
        if let aSlide = aSlide {
            slides.append(aSlide)
        }
       
        dotsControl.dotsCount = slides.count
        
        if slides.count == 1 {
            displaySlide(at: 0)
        }
    }
    
    public func removeSlide(_ aSlide: NSView?) {
        slides.removeAll(where: { element in element == aSlide })
        if indexOfDisplayedSlide >= slides.count {
            indexOfDisplayedSlide = 0
        }
        dotsControl.dotsCount = slides.count
    }

    
    override public func scrollWheel(with theEvent: NSEvent) {
        
        
        if theEvent.phase == .began {
            scrollDeltaX = 0
            scrollDeltaY = 0
            if theEvent.scrollingDeltaY != 0 {
                super.scrollWheel(with: theEvent)
            }
        } else if theEvent.phase == .changed {
            scrollDeltaX += theEvent.scrollingDeltaX
            scrollDeltaY += theEvent.scrollingDeltaY
            if scrollDeltaX == 0 {
                super.scrollWheel(with: theEvent)
            }
        } else if theEvent.phase == .ended {
            
            if scrollDeltaX > 50 {
                transitionStyle = .pushHorizontalFromLeft
                displaySlide(at: (indexOfDisplayedSlide - 1) % slides.count)
                if scheduledTransition {
                    _prepareTransitionTimer()
                }
            } else if scrollDeltaX < -50 {
                transitionStyle = .pushHorizontalFromRight
                displaySlide(at: (indexOfDisplayedSlide + 1) % slides.count)
                if scheduledTransition {
                    _prepareTransitionTimer()
                }
            }
        } else if theEvent.phase == .cancelled {
            scrollDeltaX = 0
            scrollDeltaY = 0
        } else {
            super.scrollWheel(with: theEvent)
        }
    }
    

}

private func highlightedDotImage(_ color: NSColor? = nil) -> CGImage {
    return generateImage(dotSize, contextGenerator: { size, context in
        context.clear(size.bounds)
        if let color = color {
            context.setFillColor(color.cgColor)
        } else {
            context.setFillColor(.white)
        }
        context.fillEllipse(in: size.bounds)
    })!
}

private func normalDotImage(_ color: NSColor? = nil) -> CGImage {
    return generateImage(dotSize, contextGenerator: { size, context in
        context.clear(size.bounds)
        if let color = color {
            context.setFillColor(color.cgColor)
        } else {
            context.setFillColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        }
        context.fillEllipse(in: size.bounds)
    })!
}

private let kDotImageSize: CGFloat = 15.0
private let kSpaceBetweenDotCenters: CGFloat = 12
private let kDotContainerY: CGFloat = 8.0
private let dotSize = NSMakeSize(6, 6)

private final class SliderDotsControl : NSView {
    
    var normalColor: NSColor? {
        didSet {
            update()
        }
    }
    var highlightColor: NSColor? {
        didSet {
            update()
        }
    }
    
    func updateFrame() {
        if let sliderView = sliderView {
            self.frame = NSMakeRect((sliderView.bounds.size.width - (CGFloat(dotsCount) * kSpaceBetweenDotCenters + kDotImageSize) + kSpaceBetweenDotCenters) / 2, sliderView.frame.height - kDotContainerY - kDotImageSize, CGFloat(dotsCount) * kSpaceBetweenDotCenters + kDotImageSize, kDotImageSize);
        }
    }
    
    var dotsCount: Int = 0 {
        didSet {
            removeAllSubviews()
            
            for currentDotIndex in 0 ..< self.dotsCount {
                let dotView = NSButton(frame: NSMakeRect(CGFloat(currentDotIndex) * kSpaceBetweenDotCenters, 0.0, kDotImageSize, kDotImageSize))
                dotView.image = (indexOfHighlightedDot == currentDotIndex ? NSImage(cgImage: highlightedDotImage(highlightColor), size: dotSize) : NSImage(cgImage: normalDotImage(normalColor), size: dotSize))
                dotView.alternateImage = dotView.image
                dotView.setButtonType(.momentaryChange)
                dotView.isBordered = false
                dotView.tag = currentDotIndex
                dotView.target = sliderView
                dotView.action = #selector(SliderView._dotViewSelected(_:))
                
                addSubview(dotView)
            }
            updateFrame()
        }
    }
    
    var indexOfHighlightedDot: Int = 0 {
        didSet {
            update()
        }
    }
    private func update() {
        for subview in subviews {
            if let subview = subview as? NSButton {
                subview.image = (indexOfHighlightedDot == subview.tag ? NSImage(cgImage: highlightedDotImage(highlightColor), size: dotSize) : NSImage(cgImage: normalDotImage(normalColor), size: dotSize))
            }
        }
    }
    fileprivate weak var sliderView: SliderView?
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    
}
