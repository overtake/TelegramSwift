 //
//  TouchBarMaker.swift
//  Muse
//
//  Created by Marco Albera on 18/07/2017.
//  Copyright © 2017 Edge Apps. All rights reserved.
//


import Cocoa
 import SwiftSignalKitMac
 
 @available(OSX 10.12.2, *)
 extension NSTouchBar.CustomizationIdentifier {
    static let windowBar  = NSTouchBar.CustomizationIdentifier("\(Bundle.main.bundleIdentifier!).windowBar")
    static let popoverBar = NSTouchBar.CustomizationIdentifier("\(Bundle.main.bundleIdentifier!).popoverBar")
 }
 
 @available(OSX 10.12.2, *)
 extension NSTouchBarItem.Identifier {
    // Main TouchBar identifiers
    static let songArtworkTitleButton     = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.songArtworkTitle")
    static let songProgressSlider         = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.songProgressSlider")
    static let controlsSegmentedView       = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.controlsSegmentedView")
    static let likeButton                 = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.likeButton")
    static let soundPopoverButton         = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.soundPopoverButton")
    
    
    static var controlStripButton: NSTouchBarItem.Identifier {
        return NSTouchBarItem.Identifier(
            rawValue: "\(Bundle.main.bundleIdentifier!).TouchBarItem.controlStripButton_\(arc4random())"
        )
    }
 }

 
 
 @available(OSX 10.12.2, *)
 class AudioTouchBarItemViews {
    
    var didPresentAsSystemModal: Bool = false
    var pausedOnSlide: Bool = false
    weak var songArtworkTitleButton: NSCustomizableButton?
    weak var songProgressSlider: Slider?
    weak var controlsSegmentedView: NSSegmentedControl?
    
    let controlStripItem = NSControlStripTouchBarItem(identifier: .controlStripButton)
    
    weak var controlStripButton: NSCustomizableButton? {
        set {
            controlStripItem.view = newValue!
        }
        get {
            return controlStripItem.view as? NSCustomizableButton
        }
    }
    
    func prepareButtons(_ controller: APController) {
        controlsSegmentedView?.target = controller
        controlsSegmentedView?.segmentCount = 3
        controlsSegmentedView?.segmentStyle = .separated
        controlsSegmentedView?.trackingMode = .momentary
        controlsSegmentedView?.action = #selector(APController.touchBarControlsViewClicked(_:))
        
        controlsSegmentedView?.setImage(.previous, forSegment: 0)
        controlsSegmentedView?.setImage(.play, forSegment: 1)
        controlsSegmentedView?.setImage(.next, forSegment: 2)
        
        (0..<(controlsSegmentedView?.segmentCount)!).forEach {
            controlsSegmentedView?.setWidth(45.0, forSegment: $0)
        }
    }
    
    func prepareSongProgressSlider(_ controller: APController) {
        songProgressSlider?.delegate = controller
        songProgressSlider?.minValue = 0.0
        songProgressSlider?.maxValue = 1.0
        
        if songProgressSlider?.doubleValue == 0.0 {
            updateSongProgressSlider(with: controller.currentTime, duration: controller.duration)
        }
    }

    
    func prepareSongArtworkTitleButton(_ controller: APController) {
     //   songArtworkTitleButton?.target        = self
        songArtworkTitleButton?.bezelStyle    = .rounded
        songArtworkTitleButton?.alignment     = .center
        songArtworkTitleButton?.fontSize      = 16.0
        songArtworkTitleButton?.imagePosition = .imageLeading
       // songArtworkTitleButton?.action        = #selector(songArtworkTitleButtonClicked(_:))
        
        songArtworkTitleButton?.hasRoundedLeadingImage = true
        
        songArtworkTitleButton?.addGestureRecognizer(songArtworkTitleButtonPanGestureRecognizer)
    }
    

    
    var songArtworkTitleButtonPanGestureRecognizer: NSGestureRecognizer {
        let recognizer = NSPanGestureRecognizer()
        
        recognizer.target = self
        recognizer.action = #selector(songArtworkTitleButtonPanGestureHandler(_:))
        
        recognizer.allowedTouchTypes = .direct
        
        return recognizer
    }
    
    @objc func songArtworkTitleButtonPanGestureHandler(_ recognizer: NSPanGestureRecognizer) {
        if case .began = recognizer.state {
            //songArtworkTitleButton?.title =
               // recognizer.translation(in: songArtworkTitleButton).x > 0 ?
               //     song.name.truncate(at: songTitleMaximumLength)           :
              //  song.artist.truncate(at: songTitleMaximumLength)
        }
    }

    
    func updateSongProgressSlider(with current: Double, duration: Double) {
        songProgressSlider?.doubleValue = current / duration
    }
    
    func prepareControlStripButton(_ controller: APController) {
        controlStripButton = NSCustomizableButton(
            title: "",
            target: controller,
            action: #selector(APController.presentModalTouchBar),
            hasRoundedLeadingImage: false
        )
        
        controlStripButton?.textColor = NSColor.white.withAlphaComponent(0.8)
        controlStripButton?.font = NSFont.monospacedDigitSystemFont(ofSize: 16.0,
                                                                             weight: NSFont.Weight.regular)
        controlStripButton?.imagePosition = .imageOverlaps
        controlStripButton?.isBordered = false
        controlStripButton?.title = ""
        controlStripButton?.image = #imageLiteral(resourceName: "Icon_TouchBarBackgroundIcon")
        controlStripButton?.imageScaling = .scaleNone
        
       // controlStripButton?.addGestureRecognizer(controlStripButtonPressureGestureRecognizer)
       // controlStripButton?.addGestureRecognizer(controlStripButtonPanGestureRecognizer)
    }
    
 }
 
 
 class ButtonCell: NSButtonCell {
    
    // MARK: Properties
    
    // Has custom image drawing
    var hasRoundedLeadingImage = false {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // Radius of the rounded NSImage
    var radius: CGFloat = 5.0 {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    var textColor = NSColor.alternateSelectedControlTextColor {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    let imageRectOriginDelta: CGFloat = -8.0
    
    var computeImageRectOriginDelta = false {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    var titleMarginWithRoundedLeadingImage: CGFloat = 2.0 {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // Amount by which the title label will be moved
    var xOriginShiftDelta: CGFloat {
        // Only reduce the margin if we have an image
        guard   let view = self.controlView,
            hasRoundedLeadingImage,
            self.image != nil else { return 0 }
        
        if !computeImageRectOriginDelta {
            return imageRectOriginDelta + titleMarginWithRoundedLeadingImage
        }
        
        // Compute the delta based on our rect vs super's
        return  imageRect(forBounds: view.bounds).origin.x       -
            super.imageRect(forBounds: view.bounds).origin.x +
        titleMarginWithRoundedLeadingImage
    }
    
    // MARK: Drawing functions
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        guard hasRoundedLeadingImage else { return super.drawingRect(forBounds: rect) }
        
        return super.drawingRect(forBounds: NSMakeRect(rect.origin.x,
                                                       rect.origin.y,
                                                       rect.size.width - xOriginShiftDelta,
                                                       rect.size.height))
    }
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        guard hasRoundedLeadingImage else { return super.drawingRect(forBounds: rect) }
        
        return super.titleRect(forBounds: rect.insetBy(dx: xOriginShiftDelta, dy: 0))
    }
    
    /**
     Creates the image at the very beginning of the button
     */
    override func imageRect(forBounds rect: NSRect) -> NSRect {
        return hasRoundedLeadingImage ? NSMakeRect(0, 0, rect.height, rect.height) :
            super.imageRect(forBounds: rect)
    }
    
    /**
     Draws the title at a new position to suit new image origin
     */
    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        var frame = frame
        
        // Shift the title leftwards
        if hasRoundedLeadingImage { frame.origin.x += xOriginShiftDelta }
        
        let string = NSMutableAttributedString(attributedString: title)
        string.addAttribute(NSAttributedStringKey.foregroundColor,
                            value: textColor,
                            range: NSMakeRange(0, string.length))
        
        return super.drawTitle(string, withFrame: frame, in: controlView)
    }
    
    /**
     Draws the requested NSImage in a rounded rect
     */
    override func drawImage(_ image: NSImage, withFrame frame: NSRect, in controlView: NSView) {
        guard hasRoundedLeadingImage else { return super.drawImage(image,
                                                                   withFrame: frame,
                                                                   in: controlView)}
        
        NSGraphicsContext.saveGraphicsState()
        
        let path = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        path.addClip()
        
        image.size = frame.size
        
        image.draw(in: frame, from: NSZeroRect, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
 }

 
 extension NSTrackingArea.Options {
    
    // An OptionSet with the needed mouse tracking flags
    static var defaultMouse: NSTrackingArea.Options {
        return [.mouseEnteredAndExited, .activeAlways]
    }
 }
 
 enum NSViewMouseHoverState {
    
    case entered
    case exited
 }
 
 enum NSScrollDirection {
    
    case left
    case right
    case up
    case down
    
    init?(_ event: NSEvent) {
        let deltaX = Int(event.scrollingDeltaX)
        let deltaY = Int(event.scrollingDeltaY)
        
        guard deltaX != 0 || deltaY != 0 else { return nil }
        
        // WARNING: presumes natural scrolling!
        // TODO:    implement classic scrolling
        if abs(deltaX) > abs(deltaY) {
            switch deltaX {
            case Int.min..<0:
                self = .right
            case 0..<Int.max:
                self = .left
            default:
                return nil
            }
        } else {
            switch deltaY {
            case Int.min..<0:
                self = .down
            case 0..<Int.max:
                self = .up
            default:
                return nil
            }
        }
    }
 }
 
 struct NSScrollEvent {
    
    var direction: NSScrollDirection?
    
    init(initialEvent: NSEvent) {
        direction = NSScrollDirection(initialEvent)
    }
 }
 
 protocol NSMouseHoverableView {
    
    var onMouseHoverStateChange: ((NSViewMouseHoverState) -> ())? { set get }
 }
 
 protocol NSMouseScrollableView {
    
    var onMouseScrollEvent: ((NSScrollEvent) -> ())? { set get }
 }
 
 class NSHoverableView: NSView, NSMouseHoverableView, NSMouseScrollableView {
    
    // MARK: Hovering
    
    private var mouseTrackingArea: NSTrackingArea!
    
    var onMouseHoverStateChange: ((NSViewMouseHoverState) -> ())?
    
    override func mouseEntered(with event: NSEvent) {
        onMouseHoverStateChange?(.entered)
    }
    
    override func mouseExited(with event: NSEvent) {
        onMouseHoverStateChange?(.exited)
    }
    
    override func updateTrackingAreas() {
        if let area = mouseTrackingArea {
            removeTrackingArea(area)
        }
        
        mouseTrackingArea = NSTrackingArea.init(rect: self.bounds,
                                                options: .defaultMouse,
                                                owner: self,
                                                userInfo: nil)
        
        self.addTrackingArea(mouseTrackingArea)
    }
    
    // MARK: Scrolling
    
    var onMouseScrollEvent: ((NSScrollEvent) -> ())?
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase.contains(.began) {
            onMouseScrollEvent?(NSScrollEvent(initialEvent: event))
        }
    }
 }
 
@available(OSX 10.12, *)
 class NSCustomizableButton: NSButton, NSMouseHoverableView {
    
    // MARK: Hovering
    
    private var mouseTrackingArea: NSTrackingArea!
    
    var onMouseHoverStateChange: ((NSViewMouseHoverState) -> ())?
    
    override func mouseEntered(with event: NSEvent) {
        onMouseHoverStateChange?(.entered)
    }
    
    override func mouseExited(with event: NSEvent) {
        onMouseHoverStateChange?(.exited)
    }
    
    override func updateTrackingAreas() {
        if let area = mouseTrackingArea {
            removeTrackingArea(area)
        }
        
        mouseTrackingArea = NSTrackingArea.init(rect: self.bounds,
                                                options: .defaultMouse,
                                                owner: self,
                                                userInfo: nil)
        
        self.addTrackingArea(mouseTrackingArea)
    }
    
    // MARK: Customization
    
    var customizableCell: ButtonCell? {
        return self.cell as? ButtonCell
    }
    
    var fontSize: CGFloat? {
        didSet {
            if let size = fontSize {
                self.font = NSFont.systemFont(ofSize: size)
            }
        }
    }
    
    var textColor: NSColor? {
        didSet {
            if let color = textColor {
                customizableCell?.textColor = color
            }
        }
    }
    
    var hasRoundedLeadingImage: Bool? {
        didSet {
            if let roundedLeadingImage = hasRoundedLeadingImage {
                customizableCell?.hasRoundedLeadingImage = roundedLeadingImage
            }
        }
    }
    
    convenience init(title: String,
                     target: Any?,
                     action: Selector?,
                     hasRoundedLeadingImage: Bool) {
        self.init(title: title,
                  target: target,
                  action: action)
        
        self.hasRoundedLeadingImage = hasRoundedLeadingImage
    }
    
    
    
    
    class func cellClass() -> AnyClass? {
        return ButtonCell.self
    }
    
 }
 

 @available(OSX 10.12.2, *)
 class Slider: NSSlider {
    
    weak var delegate: SliderDelegate?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func touchesBegan(with event: NSEvent) {
        super.touchesBegan(with: event)
        
        delegate?.didTouchesBegan()
    }
    
    override func touchesMoved(with event: NSEvent) {
        super.touchesMoved(with: event)
        
        delegate?.didTouchesMoved()
    }
    
    override func touchesEnded(with event: NSEvent) {
        super.touchesEnded(with: event)
        
        delegate?.didTouchesEnd()
    }
    
    override func touchesCancelled(with event: NSEvent) {
        super.touchesCancelled(with: event)
        
        delegate?.didTouchesCancel()
    }
    
    override var doubleValue: Double {
        didSet {
            
        }
    }
    
 }
 
 @available(OSX 10.12.2, *)
 protocol SliderDelegate: class {
    func didTouchesBegan()
    func didTouchesMoved()
    func didTouchesEnd()
    func didTouchesCancel()
 }
 
 
 class SliderCell: NSSliderCell {
    
    // MARK: Properties
    // These require resreshing after being set
    // through calling needsDisplay on the control view
    // aka 'NSSliderView'
    
    // The NSImage resource for the knob
    var knobImage: NSImage! {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // The color fill for the knob
    var knobColor: NSColor? {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // The knob's width
    var knobWidth: CGFloat? {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // The knob's visibility
    var knobVisible: Bool = true {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // The knob's left and right margin
    var knobMargin: CGFloat = 2.0 {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // Colors
    var backgroundColor = NSColor.lightGray.withAlphaComponent(0.5) {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    var highlightColor  = NSColor.darkGray {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // Roundness radius
    var radius: CGFloat = 1 {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // Height
    var height: CGFloat = 2.5 {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // Width
    var width: CGFloat? {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    // Bar fill margin fraction
    // min: 0 - max: 0.5
    // adds a fraction * height margin to left bar fill
    var fillMarginFraction: CGFloat = 0.0 {
        didSet {
            // Make sure we're not over max value
            if fillMarginFraction > 0.5 { fillMarginFraction = 0.5 }
            
            self.controlView?.needsDisplay = true
        }
    }
    
    // Time info switch
    var hasTimeInfo: Bool = false {
        didSet {
            // Without this there's graphic corruption
            // on the drawn string
            self.controlView?.needsDisplay = true
        }
    }
    
    // TouchBar mode switch
    var isTouchBar: Bool = false {
        didSet {
            if isTouchBar, #available(OSX 10.12.2, *) {
                knobImage = .playhead
                height = 22
                radius = 0
            } else if isTouchBar {
                isTouchBar = false
            }
        }
    }
    
    // Time info
    var timeInfo: String = "" {
        didSet {
            infoWidth = NSAttributedString(string: timeInfo, attributes: infoFontAttributes(for: NSZeroRect)).size().width
        }
    }
    
    // Info bar sizes
    let infoHeight: CGFloat = 22
    private(set) var infoWidth:  CGFloat = 70.0
    
    // Info bar font attributes
    let paraghraphStyle = NSMutableParagraphStyle()
    
    var infoFontLeftColor: NSColor = .white {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    var infoFontRightColor: NSColor = .white {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    var infoFontSize: CGFloat = 17.0 {
        didSet {
            self.controlView?.needsDisplay = true
        }
    }
    
    private let barStep:  CGFloat = 2
    private let barWidth: CGFloat = 1
    private let barFill           = NSColor.labelColor.withAlphaComponent(0.25)
    
    
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        var backgroundRect = rect
        var leftRect       = rect
        
        // Apply the desired height, with a padding around fill if requested
        backgroundRect.size.height = height
        leftRect.size.height       = height - ( fillMarginFraction * height )
        
        // Center the slider
        backgroundRect.origin.y = rect.midY - height / 2.0
        leftRect.origin.y       = rect.midY - leftRect.size.height / 2.0
        
        leftRect.size.width *= relativeKnobPosition()
        

        if isTouchBar {
            barFill.setFill()
            
            // Draw the vertical bars in the background rect
            ( 0 ..< Int( backgroundRect.width / barStep ) + 1 )
                .map { CGFloat($0) * barStep }
                .forEach { NSBezierPath(rect: NSRect(x: backgroundRect.origin.x + $0,
                                                     y: backgroundRect.origin.y,
                                                     width: barWidth,
                                                     height: backgroundRect.height)).fill() }
            
            return
        }
        
        // Fill the bars
        [ ( backgroundRect, backgroundColor ), ( leftRect, highlightColor ) ].forEach {
            $1.setFill()
            
            // Draw in the correct area with specified radius
            NSBezierPath(roundedRect: $0,
                         xRadius: radius,
                         yRadius: radius).fill()
        }
    }
    
    /**
     Draw the knob
     */
    override func drawKnob(_ knobRect: NSRect) {
        if hasTimeInfo { drawInfo(near: knobRect) }
        
        if let color = knobColor {
            color.drawSwatch(in: knobRect)
            return
        }
        
        if let image = knobImage {
            // Determine wheter the knob will be visible
            let fraction: CGFloat = knobVisible ? 1.0 : 0.0
            
            image.draw(in: knobRect,
                       from: NSZeroRect,
                       operation: .sourceOver,
                       fraction: fraction)
            return
        }
        
        super.drawKnob(knobRect)
    }
    
    /**
     Build the main cell rect with specified width
     */
    override func barRect(flipped: Bool) -> NSRect {
        if let width = width {
            var rect = super.barRect(flipped: flipped)
            
            // Center the rect
            rect.origin.x  -= ( width - rect.width ) / 2
            // Set new size
            rect.size.width = width
            
            return rect
        }
        
        return super.barRect(flipped: flipped)
    }
    
    /**
     Build the rect for our knob image
     */
    override func knobRect(flipped: Bool) -> NSRect {
        // Only run this if knob width or img is custom
        guard   var bounds = self.controlView?.bounds, (knobImage != nil || knobWidth != nil)
            else { return super.knobRect(flipped: flipped) }
        
        var rect = super.knobRect(flipped: flipped)
        
        if let image = knobImage {
            rect.size = image.size
        } else if let width = knobWidth {
            rect.size.width = width
        }
        
        bounds = NSInsetRect(bounds, rect.size.width + knobMargin, 0)
        
        let absKnobPosition = self.relativeKnobPosition() * NSWidth(bounds) + NSMinX(bounds);
        
        rect = NSOffsetRect(rect, absKnobPosition - NSMidX(rect), 0)
        
        return rect
    }
    
    /**
     Return current knob position %
     */
    func relativeKnobPosition() -> CGFloat {
        return CGFloat((self.doubleValue - self.minValue) / (self.maxValue - self.minValue))
    }
    
    /**
     Draws the specified 'timeInfo' text near the knob
     */
    func drawInfo(near knobRect: NSRect) {
        timeInfo.draw(in: infoRect(near: knobRect),
                      withAttributes: infoFontAttributes(for: knobRect))
    }
    
    /**
     Returns a rect near the knob for the info view
     */
    func infoRect(near knobRect: NSRect) -> NSRect {
        var rect = knobRect
        
        // Sets dimensions the rect
        // TODO: Adapt this to given text
        rect.size.width  = infoWidth + knobRect.width
        rect.size.height = height
        
        // Set correct position (left or right the knob, centered vertically)
        rect.origin.x += shouldInfoBeLeft(of: knobRect) ? -(infoWidth + 5) : 5
        rect.origin.y  = knobRect.midY - height / 2.0
        
        return rect
    }
    
    /**
     Determines whether info view should be drawn on lhs or rhs,
     based on space availability before the knob rect
     */
    func shouldInfoBeLeft(of knobRect: NSRect) -> Bool {
        return knobRect.origin.x > (infoWidth + 15)
    }
    
    /**
     Font attributes for the info text
     */
    func infoFontAttributes(for rect: NSRect) -> [NSAttributedStringKey: Any] {
        let isLeftOfKnob = shouldInfoBeLeft(of: rect)
        
        paraghraphStyle.alignment = isLeftOfKnob ? .left : .right
        
        return [NSAttributedStringKey.font: NSFont.systemFont(ofSize: infoFontSize),
                NSAttributedStringKey.foregroundColor: isLeftOfKnob ? infoFontLeftColor : infoFontRightColor,
                NSAttributedStringKey.paragraphStyle: paraghraphStyle]
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
 }



 @available(OSX 10.12.2, *)
 class NSMediaSliderTouchBarItem: NSSliderTouchBarItem {
    
    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        
        prepareSlider()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        prepareSlider()
    }
    
    func prepareSlider() {
        let slider      = Slider()
        let cell        = SliderCell()
        
        cell.isTouchBar               = true
        slider.cell                   = cell
        
        // TODO: find a way to remove this
        slider.wantsLayer             = true
        slider.layer?.backgroundColor = NSColor.black.cgColor
        
        self.slider = slider
    }
    
 }

 @available(OSX 10.12.2, *)
 extension APController : NSTouchBarDelegate, SliderDelegate {
    
    var shouldShowControlStripItem: Bool {
        set {
            Preference<Bool>(.controlStripItem).set(newValue)
            let window = mainWindow
            if !window.isKeyWindow {
                toggleControlStripButton(force: true, visible: newValue)
            }
        }
        
        get {
            return Preference<Bool>(.controlStripItem).value
        }
    }
    
    @objc func touchBarControlsViewClicked(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: 
            prev()
        case 1:
            playOrPause()
        case 2:
            next()
        default:
            return
        }
    }
    
    func updateTouchbarControls(_ state: APState) {
        
        touchBarViews.controlsSegmentedView?.setImage(isPlaying ? .pause : .play,
                                        forSegment: 1)
        
        touchBarViews.controlsSegmentedView?.setEnabled(prevEnabled, forSegment: 0)
        touchBarViews.controlsSegmentedView?.setEnabled(!isDownloading, forSegment: 1)
        touchBarViews.controlsSegmentedView?.setEnabled(nextEnabled, forSegment: 2)
        
        touchBarViews.updateSongProgressSlider(with: currentTime, duration: duration)
    }
    

    func toggleControlStripButton(force: Bool = false, visible: Bool = false) {
        
        let shouldShow = force ? visible : (visible && self.shouldShowControlStripItem)

        let invoke = { 
            self.touchBarViews.controlStripButton?.animator().isHidden  = !shouldShow
            self.touchBarViews.controlStripItem.isPresentInControlStrip = shouldShow
        }
        
        if shouldShow || force {
            invoke()
        } else {
            delay(0.2, closure: invoke)
        }
    }
    
    @objc func injectControlStripButton() {
        #if DEBUG || STABLE
            touchBarViews.prepareControlStripButton(self)
            
            DFRSystemModalShowsCloseBoxWhenFrontMost(true)
            
            if shouldShowControlStripItem {
                touchBarViews.controlStripItem.isPresentInControlStrip = !mainWindow.isKeyWindow
            }
        #endif
        
    }
    
    @objc func presentModalTouchBar() {
         #if DEBUG || STABLE
            touchBar?.presentAsSystemModal(for: touchBarViews.controlStripItem)
            touchBarViews.didPresentAsSystemModal = true
        #endif
    }
    
    func reloadTouchBarIfNeeded() {
        if touchBarViews.didPresentAsSystemModal {
            #if DEBUG || STABLE
                touchBar?.dismissSystemModal()
                touchBar = nil
            #endif
           
            mainWindow.makeFirstResponder(self)
            touchBarViews.didPresentAsSystemModal = false
        }
    }

    func didTouchesBegan() {
        touchBarViews.pausedOnSlide = pause()
        set(trackProgress: Float(touchBarViews.songProgressSlider?.doubleValue ?? 0))
        updateSongSlider(true)
    }
    
    private func updateSongSlider(_ interactive: Bool) {
        if let cell = touchBarViews.songProgressSlider?.cell as? SliderCell {
            cell.knobImage = interactive ? nil : .playhead
            cell.hasTimeInfo = interactive
            cell.timeInfo = String.durationTransformed(elapsed: Int(currentTime))
        }
    }
    

    func didTouchesMoved() {
        set(trackProgress: Float(touchBarViews.songProgressSlider?.doubleValue ?? 0))
        updateSongSlider(true)
    }

    func didTouchesEnd() {
        set(trackProgress: Float(touchBarViews.songProgressSlider?.doubleValue ?? 0))
        updateSongSlider(false)
        if touchBarViews.pausedOnSlide {
            touchBarViews.pausedOnSlide = !play()
        }
    }
    

    func didTouchesCancel() {
        didTouchesEnd()
    }
    
    
    override func makeTouchBar() -> NSTouchBar? {

        let touchBar = NSTouchBar()
        
        touchBar.delegate                = self
        touchBar.customizationIdentifier = .windowBar
        touchBar.defaultItemIdentifiers  = [.controlsSegmentedView, .songProgressSlider]
        
        // Allow customization of NSTouchBar items
        touchBar.customizationAllowedItemIdentifiers = touchBar.defaultItemIdentifiers
        
        return touchBar
    }
    

    
    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard let barIdentifier = touchBar.customizationIdentifier else { return nil }
        
        switch barIdentifier {
        case .windowBar:
            return touchBarItem(for: identifier)
        default:
            return nil
        }
    }
    
    
    func touchBarItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .songArtworkTitleButton:
            return createItem(identifier: identifier, view: touchBarViews.songArtworkTitleButton) { item in
                touchBarViews.songArtworkTitleButton = item.view as? NSCustomizableButton
                touchBarViews.prepareSongArtworkTitleButton(self)
            }
        case .songProgressSlider:
            return createItem(identifier: identifier, view: touchBarViews.songProgressSlider) { item in
                touchBarViews.songProgressSlider = (item as? NSMediaSliderTouchBarItem)?.slider as? Slider
                touchBarViews.prepareSongProgressSlider(self)
            }
        case .controlsSegmentedView:
            return createItem(identifier: identifier, view: touchBarViews.controlsSegmentedView) { item in
                touchBarViews.controlsSegmentedView = item.view as? NSSegmentedControl
                touchBarViews.prepareButtons(self)
            }
        default:
            return nil
        }
    }
    
    

    
    public func createItem(identifier: NSTouchBarItem.Identifier,
                           view: NSView? = nil,
                           creationHandler: (NSTouchBarItem) -> ()) -> NSTouchBarItem {
        var item: NSTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
        
        switch identifier {
        case .songProgressSlider:
            item = NSMediaSliderTouchBarItem(identifier: identifier)
        case .soundPopoverButton:
            item = NSPopoverTouchBarItem(identifier: identifier)
            (item.view as? NSButton)?.imagePosition = .imageOnly
            (item.view as? NSButton)?.addTouchBarButtonWidthConstraint()
        default:
            break
        }
        
        // Append customization labels
        switch identifier {
        case .songProgressSlider:
            (item as? NSMediaSliderTouchBarItem)?.customizationLabel = "Progress slider"
        case .soundPopoverButton:
            (item as? NSPopoverTouchBarItem)?.customizationLabel = "Sound and playback options"
        case .songArtworkTitleButton:
            (item as? NSCustomTouchBarItem)?.customizationLabel = "Song artwork and title"
        case .likeButton:
            (item as? NSCustomTouchBarItem)?.customizationLabel = "Like song"
        case .controlsSegmentedView:
            (item as? NSCustomTouchBarItem)?.customizationLabel = "Playback controls"
        default:
            break
        }
        
        if  identifier == .songProgressSlider {
            creationHandler(item)
            return item
        }
        
        guard let customItem = item as? NSCustomTouchBarItem else { return item }
        
        if let view = view {
            // touch bar is being reloaded
            // -> restore the archived NSView on the item and reset target
            // TODO: handle disapppearences after system modal bar usage
            if let control = view as? NSControl { control.target = self }
            customItem.view = view
        } else {
            // touch bar is being created for the first time
            switch identifier {
            case .songArtworkTitleButton:
                let button = NSCustomizableButton(title: "",
                                                  target: self,
                                                  action: nil,
                                                  hasRoundedLeadingImage: true)
                button.imagePosition = .imageLeading
                button.addTouchBarButtonWidthConstraint()
                customItem.view = button
            case .likeButton:
                let button = NSButton(title: "",
                                      target: self,
                                      action: nil)
                button.imagePosition = .imageOnly
                button.addTouchBarButtonWidthConstraint()
                customItem.view = button
            case .controlsSegmentedView:
                customItem.view = NSSegmentedControl()
            default:
                break
            }
            
            creationHandler(item)
        }
        
        return customItem
    }
 }
