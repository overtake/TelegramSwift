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

private let defaultWindowSize = NSMakeSize(340, 480)

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
    
    static var defaultSize: NSSize = NSMakeSize(150, 100)
    
    enum ResizeDirection {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let overlay: Control = Control()
    
    
    private var disabledView: NSVisualEffectView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(overlay)
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
    }
    
    func setIsPaused(_ paused: Bool, animated: Bool) {
        if paused {
            if disabledView == nil {
                let current = NSVisualEffectView()
                current.material = .dark
                current.state = .active
                current.blendingMode = .withinWindow
                current.wantsLayer = true
                current.layer?.cornerRadius = 3

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
    
    func updateFrame(_ frame: NSRect, animated: Bool) {
        if self.frame != frame {
            self.change(size: frame.size, animated: animated)
            self.change(pos: frame.origin, animated: animated)
            subviews.first?.subviews.first?._change(size: frame.size, animated: animated)
            subviews.first?._change(size: frame.size, animated: animated)
            overlay._change(size: frame.size, animated: animated)
            disabledView?._change(size: frame.size, animated: animated)
        }
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
    
    private var disabledView: NSVisualEffectView?
    fileprivate var videoView: NSView? {
        didSet {
            if let videoView = oldValue {
                videoView.removeFromSuperview()
            } else if let videoView = videoView {
                addSubview(videoView, positioned: .below, relativeTo: self.subviews.first)
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
            self.disabledView?.removeAllSubviews()
            if let peer = peer {
                let textView = TextView()
                let layout = TextViewLayout(.initialize(string: L10n.callVideoPaused(peer.compactDisplayTitle), color: .white, font: .normal(.header)), maximumNumberOfLines: 1)
                textView.userInteractionEnabled = false
                textView.isSelectable = false
                textView.update(layout)
                self.disabledView?.addSubview(textView)
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
    fileprivate var outgoingVideoView: OutgoingVideoView = OutgoingVideoView(frame: NSMakeRect(0, 0, 150, 100))
    private var outgoingVideoViewRequested: Bool = false
    private var incomingVideoViewRequested: Bool = false

    
    private var basicControls: View = View()
    
    private var state: CallState?
    
    private let fetching = MetaDisposable()


    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        
        addSubview(backgroundView)
        addSubview(outgoingVideoView)

        //backgroundView.isEventLess = true
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
        
        addSubview(secureTextView)
    
        backgroundView.backgroundColor = NSColor(0x000000, 0)
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
                if size.width < OutgoingVideoView.defaultSize.width || size.height < OutgoingVideoView.defaultSize.height {
                    return
                }
                if point.x < 20 ||
                    point.y < 20 ||
                    (self.frame.width - (point.x + size.width)) < 20 ||
                    (self.frame.height - (point.y + size.height)) < 20 ||
                    size.width > (defaultWindowSize.width - 40) ||
                    size.height > (defaultWindowSize.height - 40) {
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
            if let event = NSApp.currentEvent, event.clickCount == 2 {
                
                let inside = self.outgoingVideoView.convert(event.locationInWindow, from: nil)
                
                if frame.width > OutgoingVideoView.defaultSize.width {
                    size = OutgoingVideoView.defaultSize
                    point.x += floor(inside.x / 2)
                    point.y += floor(inside.y / 2)
                } else {
                    size = NSMakeSize(defaultWindowSize.width - 40, (defaultWindowSize.width - 40) * (OutgoingVideoView.defaultSize.height / OutgoingVideoView.defaultSize.width))
                    point.x -= floor(inside.x / 2)
                    point.y -= floor(inside.y / 2)
                }
                
            }
            
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
        
        switch state.state {
        case .ringing, .requesting, .terminating, .terminated:
            let videoFrame = bounds
            outgoingVideoView.frame = videoFrame
        default:
            var point = outgoingVideoView.frame.origin

            
            let size = outgoingVideoView.frame.size

            if previousFrame.size != frame.size {
                
                point.x += (frame.width - point.x) - (previousFrame.width - point.x)
                point.y += (frame.height - point.y) - (previousFrame.height - point.y)
                
                point.x = max(min(frame.width - size.width - 20, point.x), 20)
                point.y = max(min(frame.height - size.height - 20, point.y), 20)
            }
            
            let videoFrame = NSMakeRect(point.x, point.y, size.width, size.height)
            outgoingVideoView.updateFrame(videoFrame, animated: false)
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
            default:
                self.backgroundView.change(opacity: 1.0)
                self.controls.change(opacity: 1.0)
                self.textNameView._change(opacity: 1.0)
                self.secureTextView._change(opacity: 1.0)
                self.statusTextView._change(opacity: 1.0)
            }
        }

    }
    
    func updateState(_ state:CallState, session:PCallSession, accountPeer: Peer?, peer: TelegramUser?, animated: Bool) {
        
        let inputCameraIsActive = (state.videoState == .active || state.videoState == .active) && state.isOutgoingVideoPaused
        
        self.b_VideoCamera.updateWithData(CallControlData(text: L10n.callCamera, isVisualEffect: !inputCameraIsActive, icon: inputCameraIsActive ? theme.icons.callWindowVideoActive : theme.icons.callWindowVideo, iconSize: NSMakeSize(50, 50), backgroundColor: .white), animated: false)
        
        self.b_Mute.updateWithData(CallControlData(text: L10n.callMute, isVisualEffect: !state.isMuted, icon: state.isMuted ? theme.icons.callWindowMuteActive : theme.icons.callWindowMute, iconSize: NSMakeSize(50, 50), backgroundColor: .white), animated: false)
        
        self.state = state
        self.status = state.state.statusText(accountPeer)
        
        switch state.state {
        case let .active(_, _, visual):
            let layout = TextViewLayout(.initialize(string: ObjcUtils.callEmojies(visual), color: .black, font: .normal(16.0)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            secureTextView.update(layout)
        default:
            break
        }
        
        
        switch state.videoState {
        case .active:
            if !self.incomingVideoViewRequested {
                self.incomingVideoViewRequested = true
                session.makeIncomingVideoView(completion: { [weak self] view in
                    if let view = view, let `self` = self {
                        if self.incomingVideoView == nil {
                            self.incomingVideoView = IncomingVideoView(frame: self.imageView.frame)
                            self.imageView.addSubview(self.incomingVideoView!)
                        }
                        self.incomingVideoView?.videoView = view
                        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        self.needsLayout = true
                    }
                })
            }
        default:
            break
        }
        
        
        switch state.videoState {
        case .active, .outgoingRequested:
            if !self.outgoingVideoViewRequested {
                self.outgoingVideoViewRequested = true
                session.makeOutgoingVideoView(completion: { [weak self] view in
                    if let view = view, let `self` = self {
                        view.frame = self.outgoingVideoView.bounds
                        self.outgoingVideoView.addSubview(view, positioned: .below, relativeTo: self.outgoingVideoView.overlay)
                        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        self.needsLayout = true
                    }
                })
            }
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

                declineControl.change(pos: NSMakePoint(frame.width - acceptControl.frame.width - 80, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                acceptControl.change(pos: NSMakePoint(80, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                
                incomingVideoView?.removeFromSuperview()
                incomingVideoView = nil
                
            } else {
                _ = allActiveControlsViews.map {
                    $0.updateEnabled(false, animated: animated)
                }
            }
        case .terminating:
            break
        case .waiting:
            break
        case .reconnecting(_, _, _):
            break
        }
        
        
        outgoingVideoView.setIsPaused(state.isOutgoingVideoPaused, animated: animated)
        
        incomingVideoView?.setIsPaused(state.remoteVideoState == .inactive, peer: peer, animated: animated)

        
        switch state.state {
        case .ringing, .requesting, .terminating, .terminated:
            let videoFrame = bounds
            outgoingVideoView.updateFrame(videoFrame, animated: animated)
            outgoingVideoView.isEventLess = true
        default:
            var point = outgoingVideoView.frame.origin
            if outgoingVideoView.isEventLess {
                point = NSMakePoint(frame.width - OutgoingVideoView.defaultSize.width - 20, frame.height - 140 - OutgoingVideoView.defaultSize.height)
            }
            let videoFrame = NSMakeRect(point.x, point.y, OutgoingVideoView.defaultSize.width, OutgoingVideoView.defaultSize.height)
            outgoingVideoView.updateFrame(videoFrame, animated: animated)
            outgoingVideoView.isEventLess = false
        }
        if let peer = peer {
            updatePeerUI(peer, session: session)
        }
        
        needsLayout = true
    }
    
    
    private func updatePeerUI(_ user:TelegramUser, session: PCallSession) {
        
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: user.id.toInt64()), representations: user.profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        
        if let dimension = user.profileImageRepresentations.last?.dimensions.size {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: self.imageView.frame.size, intrinsicInsets: NSEdgeInsets())
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: true)
            self.imageView.setSignal(chatMessagePhoto(account: session.account, imageReference: ImageMediaReference.standalone(media: media), peer: user, scale: self.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { result in
                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
            })
            self.imageView.set(arguments: arguments)
            
            if let reference = PeerReference(user) {
                fetching.set(fetchedMediaResource(mediaBox: session.account.postbox.mediaBox, reference: .avatar(peer: reference, resource: media.representations.last!.resource)).start())
            }
            
        } else {
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
    let updateLocalizationAndThemeDisposable = MetaDisposable()
    fileprivate var session:PCallSession! {
        didSet {
            sessionDidUpdated()
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
            }
        }))
        
    }
    fileprivate let view:PhoneCallWindowView
    private var state:CallState? = nil
    private let disposable:MetaDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private let durationDisposable = MetaDisposable()
    private let recallDisposable = MetaDisposable()
    private let keyStateDisposable = MetaDisposable()
    private let readyDisposable = MetaDisposable()
    
    private let closeDisposable = MetaDisposable()

    
    private let ready: ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    fileprivate var eventLocalMonitor: Any?
    fileprivate var eventGlobalMonitor: Any?

    
    init(_ session:PCallSession) {
        self.session = session
        
        let size = defaultWindowSize
        if let screen = NSScreen.main {
            self.window = Window(contentRect: NSMakeRect(floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2), floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2), size.width, size.height), styleMask: [.fullSizeContentView, .borderless, .resizable, .miniaturizable, .titled], backing: .buffered, defer: false, screen: screen)
            self.window.minSize = size
            self.window.level = .modalPanel
            self.window.isOpaque = false
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
        }, for: .Click)
        
        self.view.b_VideoCamera.isHidden = !session.isVideo

        
        self.view.b_VideoCamera.set(handler: { [weak self] _ in
            if let session = self?.session {
                session.toggleOutgoingVideo()
            }
        }, for: .Click)
        
        self.view.b_Mute.set(handler: { [weak self] _ in
            if let session = self?.session {
                session.toggleMute()
            }
        }, for: .Click)
        
        
        view.declineControl.set(handler: { [weak self] _ in
            if let state = self?.state {
                self?.session.hangUpCurrentCall()
            } else {
                closeCall()
            }
        }, for: .Click)
        
 
        self.window.contentView = view
        //self.window.backgroundColor = .clear
        //self.window.contentView?.layer?.cornerRadius = 10
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
        
        
        eventLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp], handler: { [weak self] event in
            guard let `self` = self else {return event}
            self.window.sendEvent(event)
            return event
        })
        
        eventGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp], handler: { [weak self] event in
            guard let `self` = self else {return}
            self.window.sendEvent(event)
        })
        
        self.view.backgroundView.set(handler: { [weak self] _ in
            self?.view.updateControlsVisibility()

        }, for: .Click)
        
        let signal = session.canBeRemoved |> deliverOnMainQueue
        
        closeDisposable.set(signal.start(next: { value in
            if value {
                closeCall()
            }
        }))
        
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
    
    
    @objc open func windowDidBecomeKey() {
        keyStateDisposable.set(nil)
    }
    
    @objc open func windowDidResignKey() {
        keyStateDisposable.set((session.state |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                if case .active = state.state, !strongSelf.session.isVideo, !strongSelf.window.isKeyWindow {
                    closeCall()
                }
                
            }
        }))
    }
    
    private func applyState(_ state:CallState, session: PCallSession, accountPeer: Peer?, peer: TelegramUser?, animated: Bool) {
        self.state = state
        view.updateState(state, session: session, accountPeer: accountPeer, peer: peer, animated: animated)
        switch state.state {
        case .ringing:
            break
        case .connecting:
            break
        case .requesting:
            break
        case .active:
            session.sharedContext.showCallHeader(with: session)
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
        disposable.dispose()
        stateDisposable.dispose()
        durationDisposable.dispose()
        recallDisposable.dispose()
        keyStateDisposable.dispose()
        closeDisposable.dispose()
        readyDisposable.dispose()
        updateLocalizationAndThemeDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
        self.window.removeAllHandlers(for: self.view)
        
        if let monitor = eventLocalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = eventGlobalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func show() {
        let ready = self.ready.get() |> filter { $0 } |> take(1)
        
        readyDisposable.set(ready.start(next: { [weak self] _ in
            self?.window.makeKeyAndOrderFront(self)
            self?.view.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.4)
            self?.view.layer?.animateAlpha(from: 0.2, to: 1.0, duration: 0.3)
        }))
    }
}

private var controller:PhoneCallWindowController?


func showPhoneCallWindow(_ session:PCallSession) {
    Queue.mainQueue().async {
        controller?.session.hangUpCurrentCall()
        if let controller = controller {
            controller.session = session
        } else {
            controller = PhoneCallWindowController(session)
            controller?.show()
        }
        
    }
}
private let closeDisposable = MetaDisposable()

func closeCall(minimisize: Bool = false) {
    controller?.window.orderOut(nil)
    if !minimisize {
        controller = nil
    }
}


func applyUIPCallResult(_ sharedContext: SharedAccountContext, _ result:PCallResult) {
    assertOnMainThread()
    switch result {
    case let .success(session):
        showPhoneCallWindow(session)
    case .fail:
        break
    case let .samePeer(session):
        if let header = sharedContext.bindings.rootNavigation().callHeader, header.needShown {
            (header.view as? CallNavigationHeaderView)?.hide()
            showPhoneCallWindow(session)
        } else {
            controller?.window.orderFront(nil)
        }
    }
}
