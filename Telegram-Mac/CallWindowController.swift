//
//  PhoneCallWindow.swift
//  Telegram
//
//  Created by keepcoder on 24/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TgVoipWebrtc

private enum CallTooltipType : Int32 {
    case cameraOff
    case microOff
    case batteryLow
    
    var icon: CGImage {
        switch self {
        case .cameraOff:
            return theme.icons.call_tooltip_camera_off
        case .microOff:
            return theme.icons.call_tooltip_micro_off
        case .batteryLow:
            return theme.icons.call_tooltip_battery_low
        }
    }
    func text(_ title: String) -> String {
        switch self {
        case .cameraOff:
            return L10n.callToastCameraOff(title)
        case .microOff:
            return L10n.callToastMicroOff(title)
        case .batteryLow:
            return L10n.callToastLowBattery(title)
        }
    }
}


private final class CallTooltipView : Control {
    private let textView: TextView = TextView()
    private let icon: ImageView = ImageView()
    
    fileprivate var type: CallTooltipType? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(icon)
        
        textView.disableBackgroundDrawing = true
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        backgroundColor = NSColor.grayText.withAlphaComponent(0.7)
        
//        wantsLayer = true
//        self.material = .light
//        self.state = .active
    }
    
    func update(type: CallTooltipType, icon: CGImage, text: String, maxWidth: CGFloat) {
        
        self.type = type
        
        self.icon.image = icon
        self.icon.sizeToFit()
        
        let attr: NSAttributedString = .initialize(string: text, color: .white, font: .medium(.title))
        
        let layout = TextViewLayout(attr, maximumNumberOfLines: 1)
        layout.measure(width: maxWidth - 30 - icon.backingSize.width)
        textView.update(layout)
        
        setFrameSize(NSMakeSize(30 + self.icon.frame.width + self.textView.frame.width, 26))
        layer?.cornerRadius = frame.height / 2

        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        icon.centerY(x: 10)
        textView.centerY(x: icon.frame.maxX + 10)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



private let defaultWindowSize = NSMakeSize(375, 500)

extension CallState {
    func videoIsAvailable(_ isVideo: Bool) -> Bool {
        switch state {
        case .active:
            switch videoState {
            case .notAvailable:
                return false
            default:
                return true
            }
        case .ringing, .requesting, .connecting:
            switch videoState {
            case .notAvailable:
                return false
            default:
                if isVideo {
                    return true
                } else {
                    return false
                }
            }
            
        case .terminating, .terminated:
            return false
        default:
            return true
        }
    }
    
    var muteIsAvailable: Bool {
        switch state {
        case .active:
            return true
        case .ringing, .requesting, .connecting:
            return true
        case .terminating, .terminated:
            return false
        default:
            return true
        }
    }
}

extension CallSessionTerminationReason {
    var recall: Bool {
        let recall:Bool
        switch self {
        case .ended(let reason):
            switch reason {
            case .busy:
                recall = true
            default:
                recall = false
            }
        case .error(let reason):
            switch reason {
            case .disconnected:
                recall = true
            default:
                recall = false
            }
        }
        return recall
    }
}


private struct CallControlData {
    let text: String
    let isVisualEffect: Bool
    let icon: CGImage
    let iconSize: NSSize
    let backgroundColor: NSColor
}

private final class CallControl : Control {
    private let imageView: ImageView = ImageView()
    private var imageBackgroundView:NSView? = nil
    private let textView: TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
    override func stateDidUpdated( _ state: ControlState) {
        
        switch controlState {
        case .Highlight:
            imageBackgroundView?._change(opacity: 0.9)
            textView.change(opacity: 0.9)
        default:
            imageBackgroundView?._change(opacity: 1.0)
            textView.change(opacity: 1.0)
        }
    }
    
    func updateEnabled(_ enabled: Bool, animated: Bool) {
        self.isEnabled = enabled
        
        change(opacity: enabled ? 1 : 0.7, animated: animated)
    }
    
    var size: NSSize {
        return imageBackgroundView?.frame.size ?? frame.size
    }
    
    func updateWithData(_ data: CallControlData, animated: Bool) {
        let layout = TextViewLayout(.initialize(string: data.text, color: .white, font: .normal(12)), maximumNumberOfLines: 1)
        layout.measure(width: max(data.iconSize.width, 100))
        
        textView.update(layout)
        
        if data.isVisualEffect {
            if !(self.imageBackgroundView is NSVisualEffectView) || self.imageBackgroundView == nil {
                self.imageBackgroundView?.removeFromSuperview()
                self.imageBackgroundView = NSVisualEffectView(frame: NSMakeRect(0, 0, data.iconSize.width, data.iconSize.height))
                self.imageBackgroundView?.wantsLayer = true
                self.addSubview(self.imageBackgroundView!)
            }
            let view = self.imageBackgroundView as! NSVisualEffectView
            
            view.material = .light
            view.state = .active
            view.blendingMode = .withinWindow
        } else {
            if self.imageBackgroundView is NSVisualEffectView || self.imageBackgroundView == nil {
                self.imageBackgroundView?.removeFromSuperview()
                self.imageBackgroundView = View(frame: NSMakeRect(0, 0, data.iconSize.width, data.iconSize.height))
                self.addSubview(self.imageBackgroundView!)
            }
            self.imageBackgroundView?.background = data.backgroundColor
        }
        imageView.removeFromSuperview()
        self.imageBackgroundView?.addSubview(imageView)

        imageBackgroundView!._change(size: data.iconSize, animated: animated)
        imageBackgroundView!.layer?.cornerRadius = data.iconSize.height / 2

        imageView.animates = animated
        imageView.image = data.icon
        imageView.sizeToFit()
        
        change(size: NSMakeSize(max(data.iconSize.width, textView.frame.width), data.iconSize.height + 5 + layout.layoutSize.height), animated: animated)
        
        if animated {
            imageView._change(pos: imageBackgroundView!.focus(imageView.frame.size).origin, animated: animated)
            textView._change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - textView.frame.width) / 2), imageBackgroundView!.frame.height + 5), animated: animated)
            imageBackgroundView!._change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - imageBackgroundView!.frame.width) / 2), 0), animated: animated)
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        if let imageBackgroundView = imageBackgroundView {
            imageBackgroundView.centerX(y: 0)
            textView.centerX(y: imageBackgroundView.frame.height + 5)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class OutgoingVideoView : Control {
    
    private var progressIndicator: ProgressIndicator? = nil
    
    var isMoved: Bool = false
    
    var updateAspectRatio:((Float)->Void)? = nil

    
    fileprivate var videoView: (OngoingCallContextVideoView?, Bool)? {
        didSet {
            if let videoView = oldValue?.0 {
                progressIndicator?.removeFromSuperview()
                progressIndicator = nil
            }
            
            if videoView?.1 == false {
                self.backgroundColor = .black
                if notAvailableView == nil {
                    let current = TextView()
                    self.notAvailableView = current
                    let text = L10n.callCameraUnavailable
                    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(13), textColor: .white), bold: MarkdownAttributeSet(font: .bold(13), textColor: .white), link: MarkdownAttributeSet(font: .normal(13), textColor: .link), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { _ in
                            openSystemSettings(.camera)
                        }))
                    })).mutableCopy() as! NSMutableAttributedString
                    
                    let layout = TextViewLayout(attributedText, maximumNumberOfLines: 2, alignment: .center)
                    layout.interactions = globalLinkExecutor
                    current.isSelectable = false
                    current.update(layout)
                    
                    self.notAvailableView = current
                    addSubview(current, positioned: .below, relativeTo: overlay)
                }
            } else {
                if let videoView = videoView?.0 {
                    addSubview(videoView.view, positioned: .below, relativeTo: self.overlay)
                    videoView.view.frame = self.bounds
                    videoView.view.layer?.cornerRadius = .cornerRadius
                    if self.videoView?.1 == true {
                        videoView.view.background = .blackTransparent
                        if self.progressIndicator == nil {
                            self.progressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))
                            self.progressIndicator?.progressColor = .white
                            addSubview(self.progressIndicator!)
                            self.progressIndicator!.center()
                        }
                    } else {
                        videoView.view.background = .clear
                        if let notAvailableView = self.notAvailableView {
                            self.notAvailableView = nil
                            notAvailableView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak notAvailableView] _ in
                                notAvailableView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    let view = oldValue?.0?.view
                    
                    videoView.setOnFirstFrameReceived({ [weak self, weak view] aspectRatio in
                        DispatchQueue.main.async {
                            self?.backgroundColor = .clear
                            self?.videoView?.0?.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                            view?.removeFromSuperview()
                            if let progressIndicator = self?.progressIndicator {
                                self?.progressIndicator = nil
                                progressIndicator.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak progressIndicator] _ in
                                    progressIndicator?.removeFromSuperview()
                                })
                            }
                        }
                        self?.updateAspectRatio?(aspectRatio)
                    })
                }
            }
            
            
            needsLayout = true
        }
    }
    
    private var _hidden: Bool = false
    
    var isViewHidden: Bool {
        return _hidden
    }
    
    func unhideView(animated: Bool) {
        if let view = videoView?.0?.view, _hidden {
            addSubview(view, positioned: .below, relativeTo: self.subviews.first)
        }
        _hidden = false
    }
    
    func hideView(animated: Bool) {
        if let view = self.videoView?.0?.view, !_hidden {
            view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] completed in
                if completed {
                    view?.removeFromSuperview()
                    view?.layer?.removeAllAnimations()
                }
            })
            view.layer?.animateScaleCenter(from: 1, to: 0.2, duration: 0.2)
        }
        _hidden = true
    }
    
    override var isEventLess: Bool {
        didSet {
            overlay.isEventLess = isEventLess
        }
    }
    
    static var defaultSize: NSSize = NSMakeSize(100 * System.cameraAspectRatio, 100)
    
    enum ResizeDirection {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let overlay: Control = Control()
    
    
    private var disabledView: NSVisualEffectView?
    private var notAvailableView: TextView?
    
    
    private let maskLayer = CAShapeLayer()
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(overlay)
        self.layer?.cornerRadius = .cornerRadius
        self.layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.overlay.frame = bounds
        self.videoView?.0?.view.frame = bounds
        self.videoView?.0?.view.subviews.first?.frame = bounds
        self.progressIndicator?.center()
        self.disabledView?.frame = bounds
        
        if let textView = notAvailableView {
            let layout = textView.layout
            layout?.measure(width: frame.width - 40)
            textView.update(layout)
            textView.center()
        }
    }
    
    func setIsPaused(_ paused: Bool, animated: Bool) {
        if paused {
            if disabledView == nil {
                let current = NSVisualEffectView()
                current.material = .dark
                current.state = .active
                current.blendingMode = .withinWindow
                current.wantsLayer = true
                current.layer?.cornerRadius = .cornerRadius
                current.frame = bounds
                self.disabledView = current
                addSubview(current, positioned: .below, relativeTo: overlay)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            } else {
                self.disabledView?.frame = bounds
            }
        } else {
            if let disabledView = self.disabledView {
                self.disabledView = nil
                if animated {
                    disabledView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak disabledView] _ in
                        disabledView?.removeFromSuperview()
                    })
                } else {
                    disabledView.removeFromSuperview()
                }
            }
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    func updateFrame(_ frame: NSRect, animated: Bool) {
        if self.frame != frame {
            let duration: Double = 0.18
            
            self.videoView?.0?.view.subviews.first?._change(size: frame.size, animated: animated, duration: duration)
            self.videoView?.0?.view._change(size: frame.size, animated: animated, duration: duration)
            self.overlay._change(size: frame.size, animated: animated, duration: duration)
            self.progressIndicator?.change(pos: frame.focus(NSMakeSize(40, 40)).origin, animated: animated, duration: duration)
            
            self.disabledView?._change(size: frame.size, animated: animated, duration: duration)
            
            if let textView = notAvailableView, let layout = textView.layout {
                layout.measure(width: frame.width - 40)
                textView.update(layout)
                textView.change(pos: frame.focus(layout.layoutSize).origin, animated: animated, duration: duration)
            }
            self.change(size: frame.size, animated: animated)
            self.change(pos: frame.origin, animated: animated, duration: duration)
        }
        self.frame = frame
        updateCursorRects()
    }
    
    private func updateCursorRects() {
        resetCursorRects()
        if let cursor = NSCursor.set_windowResizeNorthEastSouthWestCursor {
            addCursorRect(NSMakeRect(0, frame.height - 10, 10, 10), cursor: cursor)
            addCursorRect(NSMakeRect(frame.width - 10, 0, 10, 10), cursor: cursor)
        }
        if let cursor = NSCursor.set_windowResizeNorthWestSouthEastCursor {
            addCursorRect(NSMakeRect(0, 0, 10, 10), cursor: cursor)
            addCursorRect(NSMakeRect(frame.width - 10, frame.height - 10, 10, 10), cursor: cursor)
        }
    }
    
    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        updateCursorRects()
    }
    
    func runResizer(at point: NSPoint) -> ResizeDirection? {
        let rects: [(NSRect, ResizeDirection)] = [(NSMakeRect(0, frame.height - 10, 10, 10), .bottomLeft),
                               (NSMakeRect(frame.width - 10, 0, 10, 10), .topRight),
                               (NSMakeRect(0, 0, 10, 10), .topLeft),
                               (NSMakeRect(frame.width - 10, frame.height - 10, 10, 10), .bottomRight)]
        for rect in rects {
            if NSPointInRect(point, rect.0) {
                return rect.1
            }
        }
        return nil
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return isEventLess
    }
}

private final class IncomingVideoView : Control {
    
    var updateAspectRatio:((Float)->Void)? = nil
    
    private var disabledView: NSVisualEffectView?
    fileprivate var videoView: OngoingCallContextVideoView? {
        didSet {
            if let videoView = oldValue {
                videoView.view.removeFromSuperview()
            }
            if let videoView = videoView {
                let isFullScreen = self.kitWindow?.isFullScreen ?? false
                videoView.setVideoContentMode(isFullScreen ? .resizeAspect : .resizeAspectFill)
                
                addSubview(videoView.view, positioned: .below, relativeTo: self.subviews.first)
                videoView.view.background = .clear
                
                videoView.setOnFirstFrameReceived({ [weak self] aspectRatio in
                    DispatchQueue.main.async {
                        self?.videoView?.view.background = .black
                        self?.videoView?.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        self?.updateAspectRatio?(aspectRatio)
                    }
                })
            }
            needsLayout = true
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.cornerRadius = .cornerRadius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        for subview in subviews {
            subview.frame = bounds
        }
        
        if let textView = disabledView?.subviews.first as? TextView {
            let layout = textView.layout
            layout?.measure(width: frame.width - 40)
            textView.update(layout)
            textView.center()
        }
    }
    
    func setIsPaused(_ paused: Bool, peer: TelegramUser?, animated: Bool) {
        if paused {
            if disabledView == nil {
                let current = NSVisualEffectView()
                current.material = .dark
                current.state = .active
                current.blendingMode = .withinWindow
                current.wantsLayer = true
                current.frame = bounds
                
                self.disabledView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            } else {
                self.disabledView?.frame = bounds
            }
        } else {
            if let disabledView = self.disabledView {
                self.disabledView = nil
                if animated {
                    disabledView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak disabledView] _ in
                        disabledView?.removeFromSuperview()
                    })
                } else {
                    disabledView.removeFromSuperview()
                }
            }
        }
        needsLayout = true
    }
    
    private var _hidden: Bool = false
    
    var isViewHidden: Bool {
        return _hidden
    }
    
    func unhideView(animated: Bool) {
        if let view = videoView?.view, _hidden {
            addSubview(view, positioned: .below, relativeTo: self.subviews.first)
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            view.layer?.animateScaleCenter(from: 0.2, to: 1.0, duration: 0.2)
        }
        _hidden = false
    }
    
    func hideView(animated: Bool) {
        if let view = self.videoView?.view, !_hidden {
            view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] completed in
                if completed {
                    view?.removeFromSuperview()
                    view?.layer?.removeAllAnimations()
                }
            })
            view.layer?.animateScaleCenter(from: 1, to: 0.2, duration: 0.2)
        }
        _hidden = true
    }
    
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}

private class PhoneCallWindowView : View {
    fileprivate let imageView:TransformImageView = TransformImageView()
    fileprivate let controls:View = View()
    fileprivate let backgroundView:Control = Control()
    let acceptControl:CallControl = CallControl(frame: .zero)
    let declineControl:CallControl = CallControl(frame: .zero)
    
    private var tooltips: [CallTooltipView] = []
    private var displayToastsAfterTimestamp: Double?
    

    
    let b_Mute:CallControl = CallControl(frame: .zero)
    let b_VideoCamera:CallControl = CallControl(frame: .zero)

    let muteControl:ImageButton = ImageButton()
    private var textNameView: NSTextField = NSTextField()
    
    private var statusTimer: SwiftSignalKit.Timer?
    
    var status: CallControllerStatusValue = .text("") {
        didSet {
            if self.status != oldValue {
                self.statusTimer?.invalidate()
                if case .timer = self.status {
                    self.statusTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        self?.updateStatus()
                    }, queue: Queue.mainQueue())
                    self.statusTimer?.start()
                    self.updateStatus()
                } else {
                    self.updateStatus()
                }
            }
        }
    }

    
    private var statusTextView:NSTextField = NSTextField()
    
    private let secureTextView:TextView = TextView()
    
    fileprivate var incomingVideoView: IncomingVideoView?
    fileprivate var outgoingVideoView: OutgoingVideoView
    private var outgoingVideoViewRequested: Bool = false
    private var incomingVideoViewRequested: Bool = false

    private var imageDimension: NSSize? = nil
    
    private var basicControls: View = View()
    
    private var state: CallState?
    
    private let fetching = MetaDisposable()

    var updateIncomingAspectRatio:((Float)->Void)? = nil

    
    private var outgoingAspectRatio: CGFloat = 0

    required init(frame frameRect: NSRect) {
        outgoingVideoView = OutgoingVideoView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(imageView)
        
        imageView.layer?.contentsGravity = .resizeAspectFill
        
        addSubview(backgroundView)
        addSubview(outgoingVideoView)

        controls.isEventLess = true
        basicControls.isEventLess = true

        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 4
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
        shadow.shadowOffset = NSMakeSize(0, 0)
        outgoingVideoView.shadow = shadow
        
        addSubview(controls)
        controls.addSubview(basicControls)

        self.backgroundColor = NSColor(0x000000, 0.8)
        
        secureTextView.backgroundColor = .clear
        secureTextView.isSelectable = false
        secureTextView.userInteractionEnabled = false
        addSubview(secureTextView)
    
        backgroundView.backgroundColor = NSColor(0x000000, 0.4)
        backgroundView.frame = NSMakeRect(0, 0, frameRect.width, frameRect.height)
        

        self.addSubview(textNameView)
        self.addSubview(statusTextView)

        
        controls.addSubview(acceptControl)
        controls.addSubview(declineControl)
        
        textNameView.font = .medium(36)
        textNameView.drawsBackground = false
        textNameView.backgroundColor = .clear
        textNameView.textColor = nightAccentPalette.text
        textNameView.isSelectable = false
        textNameView.isEditable = false
        textNameView.isBordered = false
        textNameView.focusRingType = .none
        textNameView.maximumNumberOfLines = 1
        textNameView.alignment = .center
        textNameView.cell?.truncatesLastVisibleLine = true
        textNameView.lineBreakMode = .byTruncatingTail
        statusTextView.font = .normal(18)
        statusTextView.drawsBackground = false
        statusTextView.backgroundColor = .clear
        statusTextView.textColor = nightAccentPalette.text
        statusTextView.isSelectable = false
        statusTextView.isEditable = false
        statusTextView.isBordered = false
        statusTextView.focusRingType = .none

        imageView.setFrameSize(frameRect.size.width, frameRect.size.height)
        
        
        acceptControl.updateWithData(CallControlData(text: L10n.callAccept, isVisualEffect: false, icon: theme.icons.callWindowAccept, iconSize: NSMakeSize(60, 60), backgroundColor: .greenUI), animated: false)
        declineControl.updateWithData(CallControlData(text: L10n.callDecline, isVisualEffect: false, icon: theme.icons.callWindowDecline, iconSize: NSMakeSize(60, 60), backgroundColor: .redUI), animated: false)
        
        
        basicControls.addSubview(b_VideoCamera)
        basicControls.addSubview(b_Mute)
        
        
        var start: NSPoint? = nil
        var resizeOutgoingVideoDirection: OutgoingVideoView.ResizeDirection? = nil
        outgoingVideoView.overlay.set(handler: { [weak self] control in
            guard let `self` = self, let window = self.window, self.outgoingVideoView.frame != self.bounds else {
                start = nil
                return
            }
            start = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            resizeOutgoingVideoDirection = self.outgoingVideoView.runResizer(at: self.outgoingVideoView.convert(window.mouseLocationOutsideOfEventStream, from: nil))
            
            
        }, for: .Down)
        
        outgoingVideoView.overlay.set(handler: { [weak self] control in
            guard let `self` = self, let window = self.window, let startPoint = start else {
                return
            }
            
            self.outgoingVideoView.isMoved = true
            
            let current = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let difference = current - startPoint

            if let resizeDirection = resizeOutgoingVideoDirection {
                let frame = self.outgoingVideoView.frame
                let size: NSSize
                let point: NSPoint
                let value_w = difference.x
                let value_h = difference.x * (frame.height / frame.width)

                switch resizeDirection {
                case .topLeft:
                    size = NSMakeSize(frame.width - value_w, frame.height - value_h)
                    point = NSMakePoint(frame.minX + value_w, frame.minY + value_h)
                case .topRight:
                    size = NSMakeSize(frame.width + value_w, frame.height + value_h)
                    point = NSMakePoint(frame.minX, frame.minY - value_h)
                case .bottomLeft:
                    size = NSMakeSize(frame.width - value_w, frame.height - value_h)
                    point = NSMakePoint(frame.minX + value_w, frame.minY)
                case .bottomRight:
                    size = NSMakeSize(frame.width + value_w, frame.height + value_h)
                    point = NSMakePoint(frame.minX, frame.minY)
                }
               
                if point.x < 20 ||
                    point.y < 20 ||
                    (self.frame.width - (point.x + size.width)) < 20 ||
                    (self.frame.height - (point.y + size.height)) < 20 ||
                    size.width > (window.frame.width - 40) ||
                    size.height > (window.frame.height - 40) {
                    return
                }
                self.outgoingVideoView.updateFrame(CGRect(origin: point, size: size), animated: false)

            } else {
                self.outgoingVideoView.setFrameOrigin(self.outgoingVideoView.frame.origin + difference)
            }
            start = current
            
        }, for: .MouseDragging)
      
        outgoingVideoView.overlay.set(handler: { [weak self] control in
            guard let `self` = self, let _ = start else {
                return
            }
            
            
            let frame = self.outgoingVideoView.frame
            var point = self.outgoingVideoView.frame.origin
            
            var size = frame.size
            if (size.width + point.x) > self.frame.width - 20 {
                point.x = self.frame.width - size.width - 20
            } else if point.x - 20 < 0 {
                point.x = 20
            }
            
            if (size.height + point.y) > self.frame.height - 20 {
                point.y = self.frame.height - size.height - 20
            } else if point.y - 20 < 0 {
                point.y = 20
            }
            
            let updatedRect = CGRect(origin: point, size: size)
            self.outgoingVideoView.updateFrame(updatedRect, animated: true)
            
            start = nil
            resizeOutgoingVideoDirection = nil
        }, for: .Up)

        
        outgoingVideoView.frame = NSMakeRect(frame.width - outgoingVideoView.frame.width - 20, frame.height - 140 - outgoingVideoView.frame.height, outgoingVideoView.frame.width, outgoingVideoView.frame.height)
        
    }
    
    func updateOutgoingAspectRatio(_ aspectRatio: CGFloat, animated: Bool) {
        if aspectRatio > 0, !outgoingVideoView.isEventLess, self.outgoingAspectRatio != aspectRatio {
            var rect = outgoingVideoView.frame
            let closest = max(rect.width, rect.height)
            rect.size = NSMakeSize(closest * aspectRatio, closest)
            
            let dif = outgoingVideoView.frame.size - rect.size
            
            rect.origin = rect.origin.offsetBy(dx: dif.width / 2, dy: dif.height / 2)
            
            outgoingVideoView.updateFrame(rect, animated: animated)
        }
        self.outgoingAspectRatio = aspectRatio
    }
    
    
    private func mainControlY(_ control: NSView) -> CGFloat {
        return controls.frame.height - control.frame.height - 40
    }
    
    private func mainControlCenter(_ control: NSView) -> CGFloat {
        return floorToScreenPixels(backingScaleFactor, (controls.frame.width - control.frame.width) / 2)
    }
    
    private var previousFrame: NSRect = .zero
    
    override func layout() {
        super.layout()
        
        backgroundView.frame = bounds
        imageView.frame = bounds

        incomingVideoView?.frame = bounds
        
        if self.outgoingVideoView.videoView == nil {
            self.outgoingVideoView.frame = bounds
        }
        
        
        textNameView.setFrameSize(NSMakeSize(controls.frame.width - 40, 36))
        textNameView.centerX(y: 50)
        statusTextView.setFrameSize(statusTextView.sizeThatFits(NSMakeSize(controls.frame.width - 40, 25)))
        statusTextView.centerX(y: textNameView.frame.maxY + 4)
        
        secureTextView.centerX(y: statusTextView.frame.maxY + 4)
        
        let controlsSize = NSMakeSize(frame.width, 220)
        controls.frame = NSMakeRect(0, frame.height - controlsSize.height, controlsSize.width, controlsSize.height)
        
        basicControls.frame = controls.bounds
        
        guard let state = self.state else {
            return
        }
        
        if !outgoingVideoView.isViewHidden {
            if outgoingVideoView.isEventLess {
                let videoFrame = bounds
                outgoingVideoView.updateFrame(videoFrame, animated: false)
            } else {
                var point = outgoingVideoView.frame.origin
                var size = outgoingVideoView.frame.size
                
                var updatedXY: Bool = true
                
                if previousFrame.size != frame.size, updatedXY {
                    point.x += (frame.width - point.x) - (previousFrame.width - point.x)
                    point.y += (frame.height - point.y) - (previousFrame.height - point.y)
                    
                    point.x = max(min(frame.width - size.width - 20, point.x), 20)
                    point.y = max(min(frame.height - size.height - 20, point.y), 20)
                }
                
                let videoFrame = NSMakeRect(point.x, point.y, size.width, size.height)
                outgoingVideoView.updateFrame(videoFrame, animated: false)
            }
        }
        
        
        switch state.state {
        case .connecting, .active, .requesting:
            let activeViews = self.allActiveControlsViews
            let restWidth = self.allControlRestWidth
            var x: CGFloat = floor(restWidth / 2)
            for activeView in activeViews {
                activeView.setFrameOrigin(NSMakePoint(x, mainControlY(acceptControl)))
                x += activeView.size.width + 45
            }
        case .terminating:
            acceptControl.setFrameOrigin(frame.width - acceptControl.frame.width - 80,  mainControlY(acceptControl))
        case let .terminated(_, reason, _):
            if let reason = reason, reason.recall {
                
                let activeViews = self.activeControlsViews
                let restWidth = self.controlRestWidth
                var x: CGFloat = floor(restWidth / 2)
                for activeView in activeViews {
                    activeView.setFrameOrigin(NSMakePoint(x, 0))
                    x += activeView.size.width + 45
                }
                acceptControl.setFrameOrigin(frame.width - acceptControl.frame.width - 80,  mainControlY(acceptControl))
                declineControl.setFrameOrigin(80,  mainControlY(acceptControl))
            } else {
                let activeViews = self.allActiveControlsViews
                let restWidth = self.allControlRestWidth
                var x: CGFloat = floor(restWidth / 2)
                for activeView in activeViews {
                    activeView.setFrameOrigin(NSMakePoint(x, mainControlY(acceptControl)))
                    x += activeView.size.width + 45
                }
            }
        case .ringing:
            declineControl.setFrameOrigin(80, mainControlY(declineControl))
            acceptControl.setFrameOrigin(frame.width - acceptControl.frame.width - 80,  mainControlY(acceptControl))
            
            let activeViews = self.activeControlsViews
            
            let restWidth = self.controlRestWidth
            var x: CGFloat = floor(restWidth / 2)
            for activeView in activeViews {
                activeView.setFrameOrigin(NSMakePoint(x, 0))
                x += activeView.size.width + 45
            }
            
        case .waiting:
            break
        case .reconnecting(_, _, _):
            break
        }
      
        if let dimension = imageDimension {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: self.imageView.frame.size, intrinsicInsets: NSEdgeInsets())
            self.imageView.set(arguments: arguments)
        }
        
        
        var y: CGFloat = self.controls.frame.minY - 40 + (self.allActiveControlsViews.first?.frame.minY ?? 0)
        
        for view in tooltips {
            let x = focus(view.frame.size).minX
            view.setFrameOrigin(NSMakePoint(x, y))
            y -= (view.frame.height + 10)
        }
        
        
        previousFrame = self.frame
    }
    
    var activeControlsViews:[CallControl] {
        return basicControls.subviews.filter {
            !$0.isHidden
        }.compactMap { $0 as? CallControl }
    }
    
    var allActiveControlsViews: [CallControl] {
        let values = basicControls.subviews.filter {
            !$0.isHidden
        }.compactMap { $0 as? CallControl }
        return values + controls.subviews.filter {
            $0 is CallControl && !$0.isHidden
        }.compactMap { $0 as? CallControl }
    }
    
    var controlRestWidth: CGFloat {
        return controls.frame.width - CGFloat(activeControlsViews.count - 1) * 45 - CGFloat(activeControlsViews.count) * 50
    }
    var allControlRestWidth: CGFloat {
        return controls.frame.width - CGFloat(allActiveControlsViews.count - 1) * 45 - CGFloat(allActiveControlsViews.count) * 50
    }
    
    
    func updateName(_ name:String) {
        textNameView.stringValue = name
        needsLayout = true
    }
    
    func updateStatus() {
        var statusText: String = ""
        switch self.status {
        case let .text(text):
            statusText = text
        case let .timer(referenceTime):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
            }
            statusText = durationString
        }
        statusTextView.stringValue = statusText
        statusTextView.alignment = .center
        needsLayout = true
    }
    
    func updateControlsVisibility() {
        if let state = state {
            switch state.state {
            case .active:
                self.backgroundView.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.controls.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.textNameView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.secureTextView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.statusTextView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                
                for tooltip in tooltips {
                    tooltip.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                }
                
            default:
                self.backgroundView.change(opacity: 1.0)
                self.controls.change(opacity: 1.0)
                self.textNameView._change(opacity: 1.0)
                self.secureTextView._change(opacity: 1.0)
                self.statusTextView._change(opacity: 1.0)
                
                for tooltip in tooltips {
                    tooltip.change(opacity: 1.0)
                }
            }
        }

    }
    
    func updateState(_ state:CallState, session:PCallSession, accountPeer: Peer?, peer: TelegramUser?, animated: Bool) {
        
        let inputCameraIsActive: Bool
        switch state.videoState {
        case .active:
            inputCameraIsActive = !state.isOutgoingVideoPaused
        default:
            inputCameraIsActive = false
        }
        self.b_VideoCamera.updateWithData(CallControlData(text: L10n.callCamera, isVisualEffect: !inputCameraIsActive, icon: inputCameraIsActive ? theme.icons.callWindowVideoActive : theme.icons.callWindowVideo, iconSize: NSMakeSize(50, 50), backgroundColor: .white), animated: false)
        
        self.b_Mute.updateWithData(CallControlData(text: L10n.callMute, isVisualEffect: !state.isMuted, icon: state.isMuted ? theme.icons.callWindowMuteActive : theme.icons.callWindowMute, iconSize: NSMakeSize(50, 50), backgroundColor: .white), animated: false)
        
        self.b_VideoCamera.isHidden = !session.isVideoPossible || !session.isVideoAvailable
        self.b_VideoCamera.updateEnabled(state.videoIsAvailable(session.isVideo), animated: animated)
        self.b_Mute.updateEnabled(state.muteIsAvailable, animated: animated)

        self.state = state
        self.status = state.state.statusText(accountPeer, state.videoState)
        
        switch state.state {
        case let .active(_, _, visual):
            let layout = TextViewLayout(.initialize(string: ObjcUtils.callEmojies(visual), color: .black, font: .normal(16.0)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            let wasEmpty = secureTextView.layout == nil
            secureTextView.update(layout)
            if wasEmpty {
                secureTextView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                secureTextView.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.4)
            }
        default:
            break
        }
        
        
        switch state.remoteVideoState {
        case .active:
            if !self.incomingVideoViewRequested {
                self.incomingVideoViewRequested = true
                session.makeIncomingVideoView(completion: { [weak self] view in
                    if let view = view, let `self` = self {
                        if self.incomingVideoView == nil {
                            self.incomingVideoView = IncomingVideoView(frame: self.imageView.frame)
                            self.imageView.addSubview(self.incomingVideoView!)
                        }
                        self.incomingVideoView?.updateAspectRatio = self.updateIncomingAspectRatio
                        self.incomingVideoView?.videoView = view
                        self.needsLayout = true
                    }
                })
            } else {
                self.incomingVideoView?.unhideView(animated: animated)
            }
        case .inactive, .paused:
            self.incomingVideoView?.hideView(animated: animated)
            self.needsLayout = true
        }
        
        
        switch state.videoState {
        case let .active(possible):
            if !self.outgoingVideoViewRequested {
                
                self.outgoingVideoView.unhideView(animated: animated)
                
                self.outgoingVideoViewRequested = true
                if possible {
                    session.makeOutgoingVideoView(completion: { [weak self] view in
                        if let view = view, let `self` = self {
                            self.outgoingVideoView.videoView = (view, possible)
                            self.needsLayout = true
                        }
                    })
                } else {
                    self.outgoingVideoView.videoView = (nil, possible)
                    self.needsLayout = true
                }
            }
        case .inactive, .paused:
            self.outgoingVideoViewRequested = false
            self.outgoingVideoView.hideView(animated: animated)
        default:
            break
        }
        
        switch state.state {
        case .active, .connecting, .requesting:
            self.acceptControl.isHidden = true
            let activeViews = self.allActiveControlsViews
            let restWidth = self.allControlRestWidth
            var x: CGFloat = floor(restWidth / 2)
            for activeView in activeViews {
                activeView._change(pos: NSMakePoint(x, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                x += activeView.size.width + 45
            }
            declineControl.updateWithData(CallControlData(text: L10n.callDecline, isVisualEffect: false, icon: theme.icons.callWindowDeclineSmall, iconSize: NSMakeSize(50, 50), backgroundColor: .redUI), animated: animated)
            
        case .ringing:
            break
        case .terminated(_, let reason, _):
            if let reason = reason, reason.recall {
                self.acceptControl.isHidden = false
                
                let activeViews = self.activeControlsViews
                let restWidth = self.controlRestWidth
                var x: CGFloat = floor(restWidth / 2)
                for activeView in activeViews {
                    activeView._change(pos: NSMakePoint(x, 0), animated: animated, duration: 0.3, timingFunction: .spring)
                    x += activeView.size.width + 45
                }
                acceptControl.updateWithData(CallControlData(text: L10n.callRecall, isVisualEffect: false, icon: theme.icons.callWindowAccept, iconSize: NSMakeSize(60, 60), backgroundColor: .greenUI), animated: animated)
                
                declineControl.updateWithData(CallControlData(text: L10n.callClose, isVisualEffect: false, icon: theme.icons.callWindowCancel, iconSize: NSMakeSize(60, 60), backgroundColor: .redUI), animated: animated)


                acceptControl.change(pos: NSMakePoint(frame.width - acceptControl.frame.width - 80, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                declineControl.change(pos: NSMakePoint(80, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                
                incomingVideoView?.removeFromSuperview()
                incomingVideoView = nil
                
                _ = activeControlsViews.map {
                    $0.updateEnabled(false, animated: animated)
                }
                
            } else {
                self.acceptControl.isHidden = true
                
                declineControl.updateWithData(CallControlData(text: L10n.callDecline, isVisualEffect: false, icon: theme.icons.callWindowDeclineSmall, iconSize: NSMakeSize(50, 50), backgroundColor: .redUI), animated: false)

                let activeViews = self.allActiveControlsViews
                let restWidth = self.allControlRestWidth
                var x: CGFloat = floor(restWidth / 2)
                for activeView in activeViews {
                    activeView._change(pos: NSMakePoint(x, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                    x += activeView.size.width + 45
                }
                
                _ = allActiveControlsViews.map {
                    $0.updateEnabled(false, animated: animated)
                }
            }
        case .terminating:
            _ = allActiveControlsViews.map {
                $0.updateEnabled(false, animated: animated)
            }
        case .waiting:
            break
        case .reconnecting(_, _, _):
            break
        }
        
        
        incomingVideoView?.setIsPaused(state.remoteVideoState == .paused, peer: peer, animated: animated)
        
        let wasEventLess = outgoingVideoView.isEventLess
       
        
        switch state.state {
        case .ringing, .requesting, .terminating, .terminated:
            outgoingVideoView.isEventLess = true
        default:
            switch state.videoState {
            case .active:
                outgoingVideoView.isEventLess = false
            default:
                outgoingVideoView.isEventLess = true
            }
            if state.remoteVideoState == .inactive {
                outgoingVideoView.isEventLess = true
            }
        }
        
        if let peer = peer {
            updatePeerUI(peer, session: session)
            self.updateTooltips(state, session: session, peer: peer, animated: animated, updateOutgoingVideo: !wasEventLess && !outgoingVideoView.isEventLess)
        }
        
        var point = outgoingVideoView.frame.origin
        var size = outgoingVideoView.frame.size
        
        if !outgoingVideoView.isEventLess {
            if !self.outgoingVideoView.isMoved {
                if outgoingAspectRatio > 0 {
                    size = NSMakeSize(OutgoingVideoView.defaultSize.width * outgoingAspectRatio, OutgoingVideoView.defaultSize.width)
                } else {
                    size = OutgoingVideoView.defaultSize
                }
                let addition = max(0, CGFloat(tooltips.count) * 40 - 5)
                
                point = NSMakePoint(frame.width - size.width - 20, frame.height - 140 - size.height - addition)
            }
        } else {
            self.outgoingVideoView.isMoved = false
            point = .zero
            size = frame.size
        }
        if !outgoingVideoView.isViewHidden {
            let videoFrame = CGRect(origin: point, size: size)
            outgoingVideoView.updateFrame(videoFrame, animated: animated)
        }
        
        
        needsLayout = true
    }
    
    private func updateTooltips(_ state:CallState, session:PCallSession, peer: TelegramUser, animated: Bool, updateOutgoingVideo: Bool) {
        var tooltips: [CallTooltipType] = []
        
        let maxWidth = defaultWindowSize.width - 40
        
        if let displayToastsAfterTimestamp = self.displayToastsAfterTimestamp {
            if CACurrentMediaTime() > displayToastsAfterTimestamp {
                switch state.state {
                case .active:
                    if state.remoteVideoState == .inactive {
                        switch state.videoState {
                        case .active:
                            tooltips.append(.cameraOff)
                        default:
                            break
                        }
                    }
                    if state.remoteAudioState == .muted {
                        tooltips.append(.microOff)
                    }
                    if state.remoteBatteryLevel == .low {
                        tooltips.append(.batteryLow)
                    }
                default:
                    break
                }
            }
        } else {
            self.displayToastsAfterTimestamp = CACurrentMediaTime() + 1.5
        }
        
       
        let updated = self.tooltips
        
        let removeTips = updated.filter { value in
            if let type = value.type {
                return !tooltips.contains(type)
            }
            return true
        }
        
        let updateTips = updated.filter { value in
            if let type = value.type {
                return tooltips.contains(type)
            }
            return false
        }
        
        let newTips: [CallTooltipView] = tooltips.filter { tip -> Bool in
            for view in updated {
                if view.type == tip {
                    return false
                }
            }
            return true
        }.map { tip in
            let view = CallTooltipView(frame: .zero)
            view.update(type: tip, icon: tip.icon, text: tip.text(peer.compactDisplayTitle), maxWidth: maxWidth)
            return view
        }
        
        for updated in updateTips {
            if let tip = updated.type {
                updated.update(type: tip, icon: tip.icon, text: tip.text(peer.compactDisplayTitle), maxWidth: maxWidth)
            }
        }
        
        for view in removeTips {
            if animated {
                view.layer?.animateScaleCenter(from: 1, to: 0.3, duration: 0.2)
                view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, timingFunction: .spring, removeOnCompletion: false, completion: { [weak view] _ in
                    view?.removeFromSuperview()
                })
            } else {
                view.removeFromSuperview()
            }
        }
        
        var y: CGFloat = self.controls.frame.minY - 40 + (self.allActiveControlsViews.first?.frame.minY ?? 0)
        
        let sorted = (updateTips + newTips).sorted(by: { lhs, rhs in
            return lhs.type!.rawValue < rhs.type!.rawValue
        })
        
        
        for view in sorted {
            let x = focus(view.frame.size).minX
            if view.superview == nil {
                addSubview(view)
                view.layer?.animateScaleSpring(from: 0.3, to: 1.0, duration: 0.2)
                view.layer?.animateAlpha(from: 0, to: 1, duration: 0.4, timingFunction: .spring)
            } else {
                if animated {
                    view.layer?.animatePosition(from: NSMakePoint(0, y - view.frame.minY), to: .zero, timingFunction: .spring, additive: true)
                }
            }
            view.setFrameOrigin(NSMakePoint(x, y))
            
            y -= (view.frame.height + 10)
        }
        
        self.tooltips = sorted
        
        if !outgoingVideoView.isMoved && outgoingVideoView.frame != bounds {
            let addition = max(0, CGFloat(tooltips.count) * 40 - 5)
            let size = self.outgoingVideoView.frame.size
            let point = NSMakePoint(frame.width - size.width - 20, frame.height - 140 - size.height - addition)
            self.outgoingVideoView.updateFrame(CGRect(origin: point, size: size), animated: animated)
        }
    }
    
    
    private func updatePeerUI(_ user:TelegramUser, session: PCallSession) {
        
        let id = user.profileImageRepresentations.first?.resource.id.hashValue ?? Int(user.id.toInt64())
        
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: MediaId.Id(id)), representations: user.profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        
        if let dimension = user.profileImageRepresentations.last?.dimensions.size {
            
            self.imageDimension = dimension
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: defaultWindowSize, intrinsicInsets: NSEdgeInsets())
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: false)
            self.imageView.setSignal(chatMessagePhoto(account: session.account, imageReference: ImageMediaReference.standalone(media: media), peer: user, scale: self.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { result in
                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
            })
            self.imageView.set(arguments: arguments)
            
            if let reference = PeerReference(user) {
                fetching.set(fetchedMediaResource(mediaBox: session.account.postbox.mediaBox, reference: .avatar(peer: reference, resource: media.representations.last!.resource)).start())
            }
            
        } else {
            self.imageDimension = nil
            self.imageView.setSignal(signal: generateEmptyRoundAvatar(self.imageView.frame.size, font: .avatar(90.0), account: session.account, peer: user) |> map { TransformImageResult($0, true) })
        }
        self.updateName(user.displayTitle)
        
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        fetching.dispose()
        statusTimer?.invalidate()
    }
}

class PhoneCallWindowController {
    let window:Window
    fileprivate var view:PhoneCallWindowView

    let updateLocalizationAndThemeDisposable = MetaDisposable()
    fileprivate var session:PCallSession! {
        didSet {
            first = false
            sessionDidUpdated()
            
            if let monitor = eventLocalMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = eventGlobalMonitor {
                NSEvent.removeMonitor(monitor)
            }
            
            eventLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp], handler: { [weak self] event in
                self?.view.updateControlsVisibility()
                return event
            })
            //
            eventGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp], handler: { [weak self] event in
                self?.view.updateControlsVisibility()
            })

        }
    }

    var first:Bool = true

    private func sessionDidUpdated() {

        
        let account = session.account
        
        let accountPeer: Signal<Peer?, NoError> =  session.sharedContext.activeAccounts |> mapToSignal { accounts in
            if accounts.accounts.count == 1 {
                return .single(nil)
            } else {
                return account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
            }
        }
        
        let peer = session.account.viewTracker.peerView(session.peerId) |> map {
            return $0.peers[$0.peerId] as? TelegramUser
        }
        
        stateDisposable.set(combineLatest(queue: .mainQueue(), session.state, accountPeer, peer).start(next: { [weak self] state, accountPeer, peer in
            if let strongSelf = self {
                strongSelf.applyState(state, session: strongSelf.session!, accountPeer: accountPeer, peer: peer, animated: !strongSelf.first)
                strongSelf.first = false
                
                strongSelf.updateOutgoingAspectRatio(state.remoteAspectRatio)
            }
        }))
        
        view.updateIncomingAspectRatio = { [weak self] aspectRatio in
            self?.updateIncomingAspectRatio(max(0.75, aspectRatio))
        }
    }
    private var state:CallState? = nil
    private let disposable:MetaDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private let durationDisposable = MetaDisposable()
    private let recallDisposable = MetaDisposable()
    private let keyStateDisposable = MetaDisposable()
    private let readyDisposable = MetaDisposable()
    
    
    private let ready: ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    fileprivate var eventLocalMonitor: Any?
    fileprivate var eventGlobalMonitor: Any?

    
    init(_ session:PCallSession) {
        self.session = session
        
        let size = defaultWindowSize
        if let screen = NSScreen.main {
            self.window = Window(contentRect: NSMakeRect(floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2), floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2), size.width, size.height), styleMask: [.fullSizeContentView, .borderless, .resizable, .miniaturizable, .titled], backing: .buffered, defer: true, screen: screen)
            self.window.minSize = size
            self.window.isOpaque = true
            self.window.backgroundColor = .black
        } else {
            fatalError("screen not found")
        }
        view = PhoneCallWindowView(frame: NSMakeRect(0, 0, size.width, size.height))
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        
        view.acceptControl.set(handler: { [weak self] _ in
            if let state = self?.state {
                switch state.state {
                case .ringing:
                    self?.session.acceptCallSession()
                case .terminated(_, let reason, _):
                    if let reason = reason, reason.recall {
                        self?.recall()
                    }
                default:
                    break
                }
            }
        }, for: .SingleClick)
        
        
        self.view.b_VideoCamera.set(handler: { [weak self] _ in
            if let `self` = self, let callState = self.state {
                switch callState.videoState {
                case .active, .paused:
                    self.session.disableVideo()
                case .inactive:
                    self.session.requestVideo()
                case .notAvailable:
                    break
                }
            }
        }, for: .SingleClick)
        
        self.view.b_Mute.set(handler: { [weak self] _ in
            if let session = self?.session {
                session.toggleMute()
            }
        }, for: .SingleClick)
        
        
        view.declineControl.set(handler: { [weak self] _ in
            if let state = self?.state {
                switch state.state {
                case let .terminated(_, reason, _):
                    if let reason = reason, reason.recall {
                        closeCall()
                    }
                default:
                    self?.session.hangUpCurrentCall()
                }
            } else {
                closeCall()
            }
        }, for: .SingleClick)
        
 
        self.window.contentView = view
        self.window.titlebarAppearsTransparent = true
        self.window.isMovableByWindowBackground = true
 
        sessionDidUpdated()
        
        
        window.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.view.updateControlsVisibility()
            return .rejected
        }, with: self.view, for: .mouseMoved)
        
        window.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.view.updateControlsVisibility()
            return .rejected
        }, with: self.view, for: .mouseEntered)
        
        window.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.view.updateControlsVisibility()
            return .rejected
        }, with: self.view, for: .mouseExited)
        
        
        window.onToggleFullScreen = { [weak self] value in
            if value {
                self?.view.incomingVideoView?.videoView?.setVideoContentMode(.resizeAspect)
            } else {
                self?.view.incomingVideoView?.videoView?.setVideoContentMode(.resizeAspectFill)
            }
        }
        
        
        self.view.backgroundView.set(handler: { [weak self] _ in
            self?.view.updateControlsVisibility()

        }, for: .SingleClick)

        window.animationBehavior = .utilityWindow
    }
    
    private func recall() {
        recallDisposable.set((phoneCall(account: session.account, sharedContext: session.sharedContext, peerId: session.peerId, ignoreSame: true) |> deliverOnMainQueue).start(next: { [weak self] result in
            switch result {
            case let .success(session):
                self?.session = session
            case .fail:
                break
            case .samePeer:
                break
            }
        }))
    }
    
    private var incomingAspectRatio: Float = 0
    private func updateIncomingAspectRatio(_ aspectRatio: Float) {
        if aspectRatio > 0 && self.incomingAspectRatio != aspectRatio, let screen = window.screen {
            var closestSide: CGFloat
            if aspectRatio > 1 {
                closestSide = min(window.frame.width, window.frame.height)
            } else {
                closestSide = max(window.frame.width, window.frame.height)
            }
            
            var updatedSize = NSMakeSize(closestSide * CGFloat(aspectRatio), closestSide)
            
            if screen.frame.width <= updatedSize.width || screen.frame.height <= updatedSize.height {
                let closest = min(updatedSize.width, updatedSize.height)
                updatedSize = NSMakeSize(closest * CGFloat(aspectRatio), closest)
            }
            
            window.setFrame(CGRect(origin: window.frame.origin.offsetBy(dx: (window.frame.width - updatedSize.width) / 2, dy: (window.frame.height - updatedSize.height) / 2), size: updatedSize), display: true, animate: true)
            window.aspectRatio = updatedSize
            self.incomingAspectRatio = aspectRatio
        }
    }
    
    private var outgoingAspectRatio: Float = 0
    private func updateOutgoingAspectRatio(_ aspectRatio: Float) {
        if aspectRatio > 0 && self.outgoingAspectRatio != aspectRatio {
            self.outgoingAspectRatio = aspectRatio
            self.view.updateOutgoingAspectRatio(CGFloat(aspectRatio), animated: true)
        }
    }
    
    
    @objc open func windowDidBecomeKey() {
        keyStateDisposable.set(nil)
    }
    
    @objc open func windowDidResignKey() {
        keyStateDisposable.set((session.state |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                if case .active = state.state, !strongSelf.session.isVideo, !strongSelf.window.isKeyWindow {
                    switch state.videoState {
                    case .active, .paused:
                        break
                    default:
                        closeCall()
                    }
                }
            }
        }))
    }
    
    private func applyState(_ state:CallState, session: PCallSession, accountPeer: Peer?, peer: TelegramUser?, animated: Bool) {
        self.state = state
        view.updateState(state, session: session, accountPeer: accountPeer, peer: peer, animated: animated)
        session.sharedContext.showCallHeader(with: session)
        switch state.state {
        case .ringing:
            break
        case .connecting:
            break
        case .requesting:
            break
        case .active:
            break
        case .terminating:
            break
        case .terminated(_, let error, _):
            switch error {
            case .ended(let reason)?:
                break
            case let .error(error)?:
                disposable.set((session.account.postbox.loadedPeerWithId(session.peerId) |> deliverOnMainQueue).start(next: { peer in
                    switch error {
                    case .privacyRestricted:
                        alert(for: mainWindow, info: L10n.callPrivacyErrorMessage(peer.compactDisplayTitle))
                    case .notSupportedByPeer:
                        alert(for: mainWindow, info: L10n.callParticipantVersionOutdatedError(peer.compactDisplayTitle))
                    case .serverProvided(let serverError):
                        alert(for: mainWindow, info: serverError)
                    case .generic:
                        alert(for: mainWindow, info: L10n.callUndefinedError)
                    default:
                        break
                    }
                })) 
            case .none:
                break
            }
        case .waiting:
            break
        case .reconnecting:
            break
        }
        self.ready.set(true)
    }
    
    deinit {
        cleanup()
    }
    
    fileprivate func cleanup() {
        disposable.dispose()
        stateDisposable.dispose()
        durationDisposable.dispose()
        recallDisposable.dispose()
        keyStateDisposable.dispose()
        readyDisposable.dispose()
        updateLocalizationAndThemeDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
        self.window.removeAllHandlers(for: self.view)
    }
    
    func show() {
        let ready = self.ready.get() |> filter { $0 } |> take(1)
        
        readyDisposable.set(ready.start(next: { [weak self] _ in
            if self?.window.isVisible == false {
                self?.window.makeKeyAndOrderFront(self)
                self?.window.orderFrontRegardless()
                self?.view.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.4)
                self?.view.layer?.animateAlpha(from: 0.2, to: 1.0, duration: 0.3)
            }
        }))
    }
}

private let controller:Atomic<PhoneCallWindowController?> = Atomic(value: nil)
private let closeDisposable = MetaDisposable()

func makeKeyAndOrderFrontCallWindow() -> Bool {
    return controller.with { value in
        if let value = value {
            value.window.makeKeyAndOrderFront(nil)
            value.window.orderFrontRegardless()
            return true
        } else {
            return  false
        }
    }
}

func showCallWindow(_ session:PCallSession) {
    _ = controller.modify { controller in
        if session.peerId != controller?.session.peerId {
            controller?.session.hangUpCurrentCall()
            if let controller = controller {
                controller.session = session
                return controller
            } else {
                return PhoneCallWindowController(session)
            }
        }
        return controller
    }
    controller.with { $0?.show() }
    
    let signal = session.canBeRemoved |> deliverOnMainQueue
    closeDisposable.set(signal.start(next: { value in
        if value {
            closeCall()
        }
    }))
}

func closeCall(minimisize: Bool = false) {
    _ = controller.modify { controller in
        if let controller = controller {
            controller.cleanup()
            if controller.window.isFullScreen {
                controller.window.toggleFullScreen(nil)
                delay(0.8, closure: {
                    controller.window.orderOut(nil)
                })
            } else {
                controller.window.orderOut(nil)
            }
        }
        return nil
    }
}


func applyUIPCallResult(_ sharedContext: SharedAccountContext, _ result:PCallResult) {
    assertOnMainThread()
    switch result {
    case let .success(session):
        showCallWindow(session)
    case .fail:
        break
    case let .samePeer(session):
        if let header = sharedContext.bindings.rootNavigation().callHeader, header.needShown {
            (header.view as? CallNavigationHeaderView)?.hide()
            showCallWindow(session)
        } else {
            controller.with { $0?.window.orderFront(nil) }
        }
    }
}
