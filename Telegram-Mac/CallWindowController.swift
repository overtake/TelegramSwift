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


private let defaultWindowSize = NSMakeSize(385, 550)

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
   
    private var statusView: CallStatusView = CallStatusView(frame: .zero)
    
    private let secureTextView:TextView = TextView()
    
    fileprivate let incomingVideoView: IncomingVideoView
    fileprivate let outgoingVideoView: OutgoingVideoView
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
        incomingVideoView = IncomingVideoView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(imageView)
        
        imageView.layer?.contentsGravity = .resizeAspectFill
        imageView.addSubview(incomingVideoView)
        
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
        self.addSubview(statusView)

        
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
                if size.width < 50 || size.height < 50 {
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
            
            let size = frame.size
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
            let closest: CGFloat = 100
            rect.size = NSMakeSize(floor(closest * aspectRatio), closest)
            
            let dif = outgoingVideoView.frame.size - rect.size
            
            rect.origin = rect.origin.offsetBy(dx: dif.width / 2, dy: dif.height / 2)
            
            if !outgoingVideoView.isMoved {
                let addition = max(0, CGFloat(tooltips.count) * 40 - 5)
                rect.origin = NSMakePoint(frame.width - rect.width - 20, frame.height - 140 - rect.height - addition)
            }
            
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

        incomingVideoView.frame = bounds
        
        if self.outgoingVideoView.videoView == nil {
            self.outgoingVideoView.frame = bounds
        }
        
        
        textNameView.setFrameSize(NSMakeSize(controls.frame.width - 40, 45))
        textNameView.centerX(y: 50)
        statusView.setFrameSize(statusView.sizeThatFits(NSMakeSize(controls.frame.width - 40, 25)))
        statusView.centerX(y: textNameView.frame.maxY + 8)
        
        secureTextView.centerX(y: statusView.frame.maxY + 8)
        
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
    
    
    func updateControlsVisibility() {
        if let state = state {
            switch state.state {
            case .active:
                self.backgroundView.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.controls.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.textNameView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.secureTextView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.statusView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                
                for tooltip in tooltips {
                    tooltip.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                }
                
            default:
                self.backgroundView.change(opacity: 1.0)
                self.controls.change(opacity: 1.0)
                self.textNameView._change(opacity: 1.0)
                self.secureTextView._change(opacity: 1.0)
                self.statusView._change(opacity: 1.0)
                
                for tooltip in tooltips {
                    tooltip.change(opacity: 1.0)
                }
            }
        }

    }
    
    func updateState(_ state:CallState, session:PCallSession, outgoingCameraInitialized: CameraState, incomingCameraInitialized: CameraState, accountPeer: Peer?, peer: TelegramUser?, animated: Bool) {
        
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
        let cameraCompitableState = outgoingCameraInitialized == .notInited || outgoingCameraInitialized == .inited
        self.b_VideoCamera.updateEnabled(state.videoIsAvailable(session.isVideo), animated: animated)
        self.b_Mute.updateEnabled(state.muteIsAvailable, animated: animated)
        
        self.b_VideoCamera.updateLoading(outgoingCameraInitialized == .initializing, animated: animated)

        self.state = state
        self.statusView.status = state.state.statusText(accountPeer, state.videoState)
        
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
                self.incomingVideoView._cameraInitialized.set(.initializing)
                session.makeIncomingVideoView(completion: { [weak self] view in
                    if let view = view, let `self` = self {
                        self.incomingVideoView.videoView = view
                        self.incomingVideoView.updateAspectRatio = self.updateIncomingAspectRatio
                        self.incomingVideoView.firstFrameHandler = { [weak self] in
                            self?.incomingVideoView.unhideView(animated: animated)
                        }
                    }
                })
            }
        case .inactive, .paused:
            self.incomingVideoViewRequested = false
            self.incomingVideoView.hideView(animated: animated)
            self.incomingVideoView._cameraInitialized.set(.notInited)
            self.needsLayout = true
        }
        
        
        switch state.videoState {
        case let .active(possible):
            if !self.outgoingVideoViewRequested {
                self.outgoingVideoViewRequested = true
                self.outgoingVideoView._cameraInitialized.set(.initializing)
                if possible {
                    session.makeOutgoingVideoView(completion: { [weak self] view in
                        if let view = view, let `self` = self {
                            self.outgoingVideoView.videoView = (view, possible)
                            self.outgoingVideoView.firstFrameHandler = { [weak self] in
                                self?.outgoingVideoView.unhideView(animated: animated)
                            }
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
            self.outgoingVideoView._cameraInitialized.set(.notInited)
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
        
        incomingVideoView.setIsPaused(state.remoteVideoState == .paused, peer: peer, animated: animated)
        
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
            if state.remoteVideoState == .inactive || incomingCameraInitialized == .notInited || incomingCameraInitialized == .initializing {
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
                    size = NSMakeSize(100 * outgoingAspectRatio, 100)
                } else {
                    size = OutgoingVideoView.defaultSize
                }
                let addition = max(0, CGFloat(tooltips.count) * 40 - 5)
                size = NSMakeSize(floor(size.width), floor(size.height))
                point = NSMakePoint(frame.width - size.width - 20, frame.height - 140 - size.height - addition)
            }
        } else {
            self.outgoingVideoView.isMoved = false
            point = .zero
            size = frame.size
        }
        let videoFrame = CGRect(origin: point, size: size)
        if !outgoingVideoView.isViewHidden {
            outgoingVideoView.updateFrame(videoFrame, animated: animated)
        }
        
        if videoFrame == bounds {
            addSubview(backgroundView, positioned: .above, relativeTo: outgoingVideoView)
        } else {
            addSubview(backgroundView, positioned: .below, relativeTo: outgoingVideoView)
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
            switch state.state {
            case .active:
                self.displayToastsAfterTimestamp = CACurrentMediaTime() + 2.0
            default:
                break
            }
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
                    view.change(pos: NSMakePoint(x, y), animated: animated)
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
        
        let outgoingCameraInitialized: Signal<CameraState, NoError> = .single(.notInited) |> then(view.outgoingVideoView.cameraInitialized)
        let incomingCameraInitialized: Signal<CameraState, NoError> = .single(.notInited) |> then(view.incomingVideoView.cameraInitialized)

        stateDisposable.set(combineLatest(queue: .mainQueue(), session.state, accountPeer, peer, outgoingCameraInitialized, incomingCameraInitialized).start(next: { [weak self] state, accountPeer, peer, outgoingCameraInitialized, incomingCameraInitialized in
            if let strongSelf = self {
                strongSelf.applyState(state, session: strongSelf.session!, outgoingCameraInitialized: outgoingCameraInitialized, incomingCameraInitialized: incomingCameraInitialized, accountPeer: accountPeer, peer: peer, animated: !strongSelf.first)
                strongSelf.first = false
                
                strongSelf.updateOutgoingAspectRatio(state.remoteAspectRatio)
            }
        }))
        
        view.updateIncomingAspectRatio = { [weak self] aspectRatio in
            self?.updateIncomingAspectRatio(max(0.7, aspectRatio))
            self?.updateOutgoingAspectRatio(max(0.7, aspectRatio))
        }
    }
    private var state:CallState? = nil
    private let disposable:MetaDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private let durationDisposable = MetaDisposable()
    private let recallDisposable = MetaDisposable()
    private let keyStateDisposable = MetaDisposable()
    private let readyDisposable = MetaDisposable()
    private let fullReadyDisposable = MetaDisposable()
    
    private var cameraInitialized: Promise<Bool> = Promise()
    
    private let ready: Promise<Bool> = Promise()
    
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
        }, for: .Click)
        
        
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
        }, for: .Click)
        
        self.view.b_Mute.set(handler: { [weak self] _ in
            if let session = self?.session {
                session.toggleMute()
            }
        }, for: .Click)
        
        
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
        }, for: .Click)
        
 
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
                self?.view.incomingVideoView.videoView?.setVideoContentMode(.resizeAspect)
            } else {
                self?.view.incomingVideoView.videoView?.setVideoContentMode(.resizeAspectFill)
            }
        }
        
        
        self.view.backgroundView.set(handler: { [weak self] _ in
            self?.view.updateControlsVisibility()
        }, for: .Click)

        window.animationBehavior = .utilityWindow
        updateIncomingAspectRatio(0.7)
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
            
            closestSide = max(400, closestSide)
            
            var updatedSize = NSMakeSize(floor(closestSide * CGFloat(aspectRatio)), closestSide)
            
            if screen.frame.width <= updatedSize.width || screen.frame.height <= updatedSize.height {
                let closest = min(updatedSize.width, updatedSize.height)
                updatedSize = NSMakeSize(floor(closest * CGFloat(aspectRatio)), closest)
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
    
    private func applyState(_ state:CallState, session: PCallSession, outgoingCameraInitialized: CameraState, incomingCameraInitialized: CameraState, accountPeer: Peer?, peer: TelegramUser?, animated: Bool) {
        self.state = state
        view.updateState(state, session: session, outgoingCameraInitialized: outgoingCameraInitialized, incomingCameraInitialized: incomingCameraInitialized, accountPeer: accountPeer, peer: peer, animated: animated)
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
        self.ready.set(.single(true))

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
        fullReadyDisposable.dispose()
        updateLocalizationAndThemeDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
        self.window.removeAllHandlers(for: self.view)
        
        _ = self.view.allActiveControlsViews.map {
            $0.updateEnabled(false, animated: true)
        }
    }
    
    func show() {
        let ready = self.ready.get() |> filter { $0 } |> take(1)
        
        readyDisposable.set(ready.start(next: { [weak self] _ in
            if let `self` = self, self.window.isVisible == false {
                self.window.makeKeyAndOrderFront(self)
                self.window.orderFrontRegardless()
                self.window.alphaValue = 0
                
                let fullReady: Signal<Bool, NoError>
                if self.session.isVideo {
                    fullReady = self.view.outgoingVideoView.cameraInitialized
                        |> map { $0 == .inited }
                        |> filter { $0 }
                        |> take(1)
                } else {
                    fullReady = .single(true)
                }
                
                self.fullReadyDisposable.set(fullReady.start(next: { [weak self] _ in
                    self?.window.animator().alphaValue = 1
                    self?.window.orderFrontRegardless()
                    self?.view.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.4)
                    self?.view.layer?.animateAlpha(from: 0.2, to: 1.0, duration: 0.3)
                }))
            } else {
                self?.window.makeKeyAndOrderFront(self)
                self?.window.orderFrontRegardless()
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
                    NSAnimationContext.runAnimationGroup({ ctx in
                        controller.window.animator().alphaValue = 0
                    }, completionHandler: {
                        controller.window.orderOut(nil)
                    })
                })
            } else {
                NSAnimationContext.runAnimationGroup({ ctx in
                    controller.window.animator().alphaValue = 0
                }, completionHandler: {
                    controller.window.orderOut(nil)
                })
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
