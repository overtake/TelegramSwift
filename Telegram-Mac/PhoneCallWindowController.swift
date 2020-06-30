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
    
    let overlay: Control = Control()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(overlay)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        overlay.frame = bounds
    }
    
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
    
    
}

private class PhoneCallWindowView : View {
    fileprivate let imageView:TransformImageView = TransformImageView()
    fileprivate let controls:View = View()
    fileprivate let backgroundView:View = View()
    let acceptControl:CallControl = CallControl(frame: .zero)
    let declineControl:CallControl = CallControl(frame: .zero)
    
    
    let b_Mute:CallControl = CallControl(frame: .zero)
    let b_VideoCamera:CallControl = CallControl(frame: .zero)

    let muteControl:ImageButton = ImageButton()
    private var textNameView: NSTextField = NSTextField()
    private var statusTextView:NSTextField = NSTextField()
    
    
    private let secureTextView:TextView = TextView()
    fileprivate let secureContainerView:NSView = NSView()
    
    private var incomingVideoView: NSView?
    private var outgoingVideoView: OutgoingVideoView = OutgoingVideoView(frame: NSMakeRect(0, 0, 150, 100))
    
    
    private var basicControls: View = View()
    
    private var state: CallSessionState?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(backgroundView)
        
        outgoingVideoView.layer?.cornerRadius = .cornerRadius
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 4
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSMakeSize(0, 0)
        outgoingVideoView.shadow = shadow
        
        addSubview(controls)
        controls.addSubview(basicControls)

        self.backgroundColor = NSColor(0x000000, 0.8)
        
        secureContainerView.wantsLayer = true
        secureTextView.backgroundColor = .clear

        secureContainerView.addSubview(secureTextView)
        
        
        addSubview(secureContainerView)

        
    
        backgroundView.backgroundColor = NSColor(0x000000, 0.2)
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
        
        layer?.cornerRadius = 10
        
        acceptControl.updateWithData(CallControlData(text: L10n.callAccept, isVisualEffect: false, icon: theme.icons.callWindowAccept, iconSize: NSMakeSize(60, 60), backgroundColor: .greenUI), animated: false)
        declineControl.updateWithData(CallControlData(text: L10n.callDecline, isVisualEffect: false, icon: theme.icons.callWindowDecline, iconSize: NSMakeSize(60, 60), backgroundColor: .redUI), animated: false)
        
        
        basicControls.addSubview(b_VideoCamera)
        basicControls.addSubview(b_Mute)
        
        
        var start: NSPoint? = nil
        
        outgoingVideoView.overlay.set(handler: { [weak self] control in
            guard let `self` = self, let window = self.window else {
                return
            }
            start = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        }, for: .Down)
        
        outgoingVideoView.overlay.set(handler: { [weak self] control in
            guard let `self` = self, let window = self.window, let startPoint = start else {
                return
            }
            let current = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            
            let difference = current - startPoint
            
            self.outgoingVideoView.setFrameOrigin(self.outgoingVideoView.frame.origin + difference)
            
            start = current
            
        }, for: .MouseDragging)
      
        outgoingVideoView.overlay.set(handler: { [weak self] control in
            guard let `self` = self, let _ = start else {
                return
            }
            
            var point = self.outgoingVideoView.frame.origin
            
            if self.outgoingVideoView.frame.maxX > self.frame.width {
                point.x = self.frame.width - self.outgoingVideoView.frame.width - 20
            } else if self.outgoingVideoView.frame.minX < 0 {
                point.x = 20
            }
            
            if self.outgoingVideoView.frame.maxY > self.frame.height {
                point.y = self.frame.height - self.outgoingVideoView.frame.height - 20
            } else if self.outgoingVideoView.frame.minY < 0 {
                point.y = 20
            }
            
            self.outgoingVideoView._change(pos: point, animated: true)
            
            start = nil
        }, for: .Up)
        
        outgoingVideoView.frame = NSMakeRect(frame.width - outgoingVideoView.frame.width - 20, frame.height - 140 - outgoingVideoView.frame.height, outgoingVideoView.frame.width, outgoingVideoView.frame.height)
        
    }
    
    private func mainControlY(_ control: NSView) -> CGFloat {
        return controls.frame.height - control.frame.height - 40
    }
    
    private func mainControlCenter(_ control: NSView) -> CGFloat {
        return floorToScreenPixels(backingScaleFactor, (controls.frame.width - control.frame.width) / 2)
    }
    
    
    override func layout() {
        super.layout()
        
        backgroundView.frame = bounds
        imageView.frame = bounds
        
        incomingVideoView?.frame = bounds
        
        
        textNameView.setFrameSize(NSMakeSize(controls.frame.width - 40, 36))
        textNameView.centerX(y: 50)
        statusTextView.setFrameSize(statusTextView.sizeThatFits(NSMakeSize(controls.frame.width - 40, 25)))
        statusTextView.centerX(y: textNameView.frame.maxY + 2)
        
        secureTextView.center()
        secureTextView.setFrameOrigin(secureTextView.frame.minX + 2, secureTextView.frame.minY)
        secureContainerView.centerX(y: statusTextView.frame.maxY + 5)
        
        
        let controlsSize = NSMakeSize(frame.width, 220)
        controls.frame = NSMakeRect(0, frame.height - controlsSize.height, controlsSize.width, controlsSize.height)
        
        basicControls.frame = controls.bounds
        
        let state = self.state ?? .ringing
        
        switch state {
        case .accepting, .active, .requesting:
            let activeViews = self.allActiveControlsViews
            let restWidth = self.allControlRestWidth
            var x: CGFloat = floor(restWidth / 2)
            for activeView in activeViews {
                activeView.setFrameOrigin(NSMakePoint(x, mainControlY(acceptControl)))
                x += activeView.size.width + 45
            }
        case .dropping:
            acceptControl.setFrameOrigin(frame.width - acceptControl.frame.width - 80,  mainControlY(acceptControl))
        case let .terminated(_, reason, _):
            if reason.recall {
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
            
        }
      
        
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
    
    func setDuration(_ duration:TimeInterval) {
        statusTextView.stringValue = String.durationTransformed(elapsed: Int(duration))
        needsLayout = true
    }
    
    func updateControlsVisibility() {
        if let state = state {
            switch state {
            case .active:
                self.backgroundView.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.controls.change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.textNameView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.secureContainerView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
                self.statusTextView._change(opacity: self.mouseInside() ? 1.0 : 0.0)
            default:
                self.backgroundView.change(opacity: 1.0)
                self.controls.change(opacity: 1.0)
                self.textNameView._change(opacity: 1.0)
                self.secureContainerView._change(opacity: 1.0)
                self.statusTextView._change(opacity: 1.0)
            }
        }

    }
    
    func updateState(_ state:CallSessionState, session:PCallSession, accountPeer: Peer?, animated: Bool) {
        
        self.state = state
        
        switch state {
        case .accepting:
            statusTextView.stringValue = L10n.callStatusConnecting
        case .active(_, _, let visual, _, _, _, _):
            let layout = TextViewLayout(.initialize(string: ObjcUtils.callEmojies(visual), color: .black, font: .normal(16.0)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            secureTextView.update(layout)
            secureContainerView.isHidden = false
            secureContainerView.setFrameSize(NSMakeSize(layout.layoutSize.width + 16, layout.layoutSize.height + 10))
            secureContainerView.layer?.cornerRadius = secureContainerView.frame.height / 2
            
            statusTextView.stringValue = L10n.callStatusConnecting
            
            if session.isVideo {
                session.makeIncomingVideoView { [weak self] view in
                    if let view = view, let `self` = self {
                        view.frame = self.imageView.frame
                        self.incomingVideoView = view
                        self.imageView.addSubview(view)
                        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        self.needsLayout = true
                    }
                }
                session.makeOutgoingVideoView { [weak self] view in
                    if let view = view, let `self` = self {
                        view.frame = self.outgoingVideoView.bounds
                        self.outgoingVideoView.addSubview(view, positioned: .below, relativeTo: self.outgoingVideoView.overlay)
                        self.addSubview(self.outgoingVideoView)
                        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        self.needsLayout = true
                    }
                }
            }
            
        case .ringing:
            if let accountPeer = accountPeer {
                statusTextView.stringValue = L10n.callStatusCallingAccount(accountPeer.addressName ?? accountPeer.compactDisplayTitle)
            } else {
                statusTextView.stringValue = L10n.callStatusCalling
            }
        case .terminated(_, let error, _):
            switch error {
            case .ended(let reason):
                
                switch reason {
                case .busy:
                    statusTextView.stringValue = L10n.callStatusBusy
                case .missed:
                    statusTextView.stringValue = L10n.callStatusEnded
                default:
                    statusTextView.stringValue = L10n.callStatusEnded
                }
                
            case .error:
                 statusTextView.stringValue = L10n.callStatusFailed
                 acceptControl.isEnabled = false
                 acceptControl.change(opacity: 0.8)
            }
            
            
        case .requesting(let ringing):
            statusTextView.stringValue = !ringing ? L10n.callStatusRequesting : L10n.callStatusRinging
        default:
            break
        }
        
        switch state {
        case .active, .accepting, .requesting:
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
            if reason.recall {
                self.acceptControl.isHidden = false
                
                let activeViews = self.activeControlsViews
                let restWidth = self.controlRestWidth
                var x: CGFloat = floor(restWidth / 2)
                for activeView in activeViews {
                    activeView._change(pos: NSMakePoint(x, 0), animated: animated, duration: 0.3, timingFunction: .spring)
                    x += activeView.size.width + 45
                }
                acceptControl.updateWithData(CallControlData(text: L10n.callRecall, isVisualEffect: false, icon: theme.icons.callWindowAccept, iconSize: NSMakeSize(60, 60), backgroundColor: .greenUI), animated: animated)
                
                declineControl.updateWithData(CallControlData(text: L10n.callClose, isVisualEffect: false, icon: theme.icons.callWindowClose, iconSize: NSMakeSize(60, 60), backgroundColor: .redUI), animated: animated)

                declineControl.change(pos: NSMakePoint(frame.width - acceptControl.frame.width - 80, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                acceptControl.change(pos: NSMakePoint(80, mainControlY(acceptControl)), animated: animated, duration: 0.3, timingFunction: .spring)
                
                outgoingVideoView.subviews.first?.removeFromSuperview()
                outgoingVideoView.removeFromSuperview()
                incomingVideoView?.removeFromSuperview()
                incomingVideoView = nil
                
            } else {
                _ = allActiveControlsViews.map {
                    $0.updateEnabled(false, animated: animated)
                }
            }
        case .dropping:
            break
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        view.secureContainerView.isHidden = true
        peerDisposable.set((session.account.viewTracker.peerView(session.peerId) |> deliverOnMainQueue).start(next: { [weak self] peerView in
            if let strongSelf = self {
                if let user = peerView.peers[peerView.peerId] as? TelegramUser {
                    strongSelf.updatePeerUI(user)
                }
            }
        }))
        
        let account = session.account
        
        let accountPeer: Signal<Peer?, NoError> =  session.sharedContext.activeAccounts |> mapToSignal { accounts in
            if accounts.accounts.count == 1 {
                return .single(nil)
            } else {
                return account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
            }
        }
        
        stateDisposable.set(combineLatest(queue: .mainQueue(), session.state.get(), accountPeer).start(next: { [weak self] state, accountPeer in
            if let strongSelf = self {
                strongSelf.applyState(state, session: strongSelf.session!, accountPeer: accountPeer, animated: !strongSelf.first)
                strongSelf.first = false
            }
        }))
        
        durationDisposable.set(session.durationPromise.get().start(next: { [weak self] duration in
            self?.view.setDuration(duration)
        }))
    }
    fileprivate let view:PhoneCallWindowView
    private var state:CallSessionState? = nil
    private let disposable:MetaDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private let durationDisposable = MetaDisposable()
    private let recallDisposable = MetaDisposable()
    private let peerDisposable = MetaDisposable()
    private let accessDataDisposable = MetaDisposable()
    private let keyStateDisposable = MetaDisposable()
    private let fetching = MetaDisposable()
    
    
    fileprivate var eventLocalMonitor: Any?
    fileprivate var eventGlobalMonitor: Any?

    
    init(_ session:PCallSession) {
        self.session = session
    
        
        let size = NSMakeSize(360, 500)
        if let screen = NSScreen.main {
            self.window = Window(contentRect: NSMakeRect(floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2), floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2), size.width, size.height), styleMask: [.fullSizeContentView, .borderless], backing: .buffered, defer: true, screen: screen)
            self.window.level = .modalPanel
            self.window.backgroundColor = .clear
        } else {
            fatalError("screen not found")
        }
        view = PhoneCallWindowView(frame: NSMakeRect(0, 0, size.width, size.height))
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        
        view.acceptControl.set(handler: { [weak self] _ in
            if let state = self?.state {
                switch state {
                case .ringing:
                    self?.session.acceptCallSession()
                case .terminated(_, let reason, _):
                    if reason.recall {
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
                session.toggleVideoEnabled()
            }
        }, for: .Click)
        
        self.view.b_Mute.set(handler: { [weak self] _ in
            if let session = self?.session {
                session.toggleMute()
            }
        }, for: .Click)
        
            
        let data = session.dataValue |> deliverOnMainQueue
        
        accessDataDisposable.set(data.start(next: { [weak self] data in
            guard let `self` = self else {
                return
            }
            self.view.b_VideoCamera.updateWithData(CallControlData(text: L10n.callCamera, isVisualEffect: !data.isVideoEnabled, icon: data.isVideoEnabled ? theme.icons.callWindowVideoActive : theme.icons.callWindowVideo, iconSize: NSMakeSize(50, 50), backgroundColor: .white), animated: false)
            
            self.view.b_Mute.updateWithData(CallControlData(text: L10n.callMute, isVisualEffect: !data.isMuted, icon: data.isMuted ? theme.icons.callWindowMuteActive : theme.icons.callWindowMute, iconSize: NSMakeSize(50, 50), backgroundColor: .white), animated: false)
            
        }))
        
        

        
        view.declineControl.set(handler: { [weak self] _ in
            if let state = self?.state {
                switch state {
                case .terminated:
                    closeCall()
                default:
                    self?.session.hangUpCurrentCall()
                }
            } else {
                closeCall()
            }
        }, for: .Click)
        
 
        self.window.contentView = view
        self.window.backgroundColor = .clear
        self.window.contentView?.layer?.cornerRadius = 10
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
        keyStateDisposable.set((session.state.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                if case .active = state, !strongSelf.session.isVideo, !strongSelf.window.isKeyWindow {
                    closeCall()
                }
                
            }
        }))
    }
    
    private func applyState(_ state:CallSessionState, session: PCallSession, accountPeer: Peer?, animated: Bool) {
        self.state = state
        view.updateState(state, session: session, accountPeer: accountPeer, animated: animated)
        switch state {
        case .ringing:
            break
        case .accepting:
            break
        case .requesting:
            break
        case .active:
            session.sharedContext.showCallHeader(with: session)
        case .dropping:
            break
        case .terminated(_, let error, _):
            switch error {
            case .ended(let reason):
                switch reason {
                case .hungUp, .missed:
                    closeCall(1.0)
                default:
                    break
                }
            case let .error(error):
                closeCall(1.0)
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
            }
            
            
            
        }
    }
    
    deinit {
        disposable.dispose()
        stateDisposable.dispose()
        durationDisposable.dispose()
        recallDisposable.dispose()
        peerDisposable.dispose()
        keyStateDisposable.dispose()
        fetching.dispose()
        accessDataDisposable.dispose()
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
        var first: Bool = true
        disposable.set((session.account.postbox.loadedPeerWithId(session.peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                strongSelf.updatePeerUI(peer as! TelegramUser)
                
                if first {
                    first = false
                    strongSelf.window.makeKeyAndOrderFront(self)
                    strongSelf.view.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.4)
                    strongSelf.view.layer?.animateAlpha(from: 0.2, to: 1.0, duration: 0.3)
                }
            }
        }))
        
    }
    
    private func updatePeerUI(_ user:TelegramUser) {
        
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: user.id.toInt64()), representations: user.profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        

        if let dimension = user.profileImageRepresentations.last?.dimensions.size {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: view.imageView.frame.size, intrinsicInsets: NSEdgeInsets())
            view.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: view.backingScaleFactor), clearInstantly: true)
            view.imageView.setSignal(chatMessagePhoto(account: session.account, imageReference: ImageMediaReference.standalone(media: media), peer: user, scale: view.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { result in
                 cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
            })
            view.imageView.set(arguments: arguments)

            if let reference = PeerReference(user) {
                fetching.set(fetchedMediaResource(mediaBox: session.account.postbox.mediaBox, reference: .avatar(peer: reference, resource: media.representations.last!.resource)).start())
            }
            
        } else {
            view.imageView.setSignal(signal: generateEmptyRoundAvatar(view.imageView.frame.size, font: .avatar(90.0), account: session.account, peer: user) |> map { TransformImageResult($0, true) })
        }
        
       
        view.updateName(user.displayTitle)
        
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

func closeCall(_ timeout:TimeInterval? = nil) {
    var signal = Signal<Void, NoError>.single(Void()) |> deliverOnMainQueue
    if let timeout = timeout {
        signal = signal |> delay(timeout, queue: Queue.mainQueue())
    }
    closeDisposable.set(signal.start(completed: {
        //controller?.window.styleMask = [.borderless]
        controller?.view.controls.removeFromSuperview()
        controller?.window.orderOut(nil)
        controller = nil
    }))
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
