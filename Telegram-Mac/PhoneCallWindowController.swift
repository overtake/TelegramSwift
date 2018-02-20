//
//  PhoneCallWindow.swift
//  Telegram
//
//  Created by keepcoder on 24/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac

private class ShadowView : View {
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        ctx.clear(NSMakeRect(0, 0, frame.width, frame.height))
        
        var locations: [CGFloat] = [1.0, 0.2];
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [NSColor.black.withAlphaComponent(0.4).cgColor, NSColor.clear.cgColor]), locations: nil)!
        
        ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: frame.height), options: CGGradientDrawingOptions())
    }
    
}

private class PhoneCallWindowView : View {
    //private var avatar:AvatarControl = AvatarControl
    fileprivate let imageView:TransformImageView = TransformImageView()
    fileprivate let controls:NSVisualEffectView = NSVisualEffectView()
    fileprivate let backgroundView:View = View()
    let acceptControl:ImageButton = ImageButton()
    let declineControl:ImageButton = ImageButton()
    let muteControl:ImageButton = ImageButton()
    let closeMissedControl:ImageButton = ImageButton()
    private var textNameView: NSTextField = NSTextField()
    private var statusTextView:NSTextField = NSTextField()
    
    
    private let secureTextView:TextView = TextView()
    fileprivate let secureContainerView:NSView = NSView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(imageView)
        addSubview(controls)
        self.backgroundColor = NSColor(0x000000, 0.8)
        
       // shadowView.layer?.shadowColor = NSColor.blackTransparent.cgColor
              // controls.backgroundColor = NSColor(0x000000, 0.85)
        
        controls.material = .dark
        controls.blendingMode = .behindWindow
        
        secureContainerView.wantsLayer = true
        secureContainerView.background = NSColor(0x000000, 0.75)
        secureTextView.backgroundColor = .clear

        secureContainerView.addSubview(secureTextView)
        
        
        addSubview(secureContainerView)

        
    
        backgroundView.backgroundColor = .clear
        backgroundView.frame = NSMakeRect(0, 0, frameRect.width, frameRect.height)
        
        acceptControl.autohighlight = false
        acceptControl.set(image: theme.icons.callWindowAccept, for: .Normal)
        acceptControl.sizeToFit()
        
        declineControl.autohighlight = false
        declineControl.set(image: theme.icons.callWindowDecline, for: .Normal)
        declineControl.sizeToFit()
        
        muteControl.autohighlight = false
        muteControl.set(image: theme.icons.callWindowMute, for: .Normal)
        muteControl.sizeToFit()
        controls.addSubview(muteControl)
        
        closeMissedControl.autohighlight = false
        closeMissedControl.set(image: theme.icons.callWindowCancel, for: .Normal)
        closeMissedControl.setFrameSize(50,50)
        closeMissedControl.layer?.cornerRadius = 25
        closeMissedControl.layer?.borderWidth = 2
        closeMissedControl.layer?.borderColor = theme.colors.border.cgColor
        
        
        
        controls.addSubview(acceptControl)
        controls.addSubview(declineControl)
        controls.addSubview(textNameView)
        controls.addSubview(statusTextView)
        controls.addSubview(closeMissedControl)
        
        textNameView.font = .medium(18.0)
        textNameView.drawsBackground = false
        textNameView.backgroundColor = .clear
        textNameView.textColor = nightBluePalette.text
        textNameView.isSelectable = false
        textNameView.isEditable = false
        textNameView.isBordered = false
        textNameView.focusRingType = .none
        textNameView.maximumNumberOfLines = 1
        textNameView.alignment = .center
        textNameView.cell?.truncatesLastVisibleLine = true
        textNameView.lineBreakMode = .byTruncatingTail
        statusTextView.font = .normal(.header)
        statusTextView.drawsBackground = false
        statusTextView.backgroundColor = .clear
        statusTextView.textColor = nightBluePalette.text
        statusTextView.isSelectable = false
        statusTextView.isEditable = false
        statusTextView.isBordered = false
        statusTextView.focusRingType = .none
        
       // self.backgroundView.backgroundColor = .blackTransparent
        let controlsSize = NSMakeSize(frameRect.width, 160)
        controls.frame = NSMakeRect(0, frameRect.height - controlsSize.height, controlsSize.width, controlsSize.height)
       // controls.backgroundColor = .blackTransparent
      //  controls.flip = false
        //controls.material = .ultraDark
        //controls.blendingMode = .behindWindow
        //controls.state = .followsWindowActiveState
        imageView.setFrameSize(frameRect.size.width, frameRect.size.height - controlsSize.height)
        
        declineControl.setFrameOrigin(80, 30)
        acceptControl.setFrameOrigin(frame.width - acceptControl.frame.width - 80, 30)
        
        layer?.cornerRadius = 6
        
        closeMissedControl.isHidden = true
        closeMissedControl.layer?.opacity = 0
        

    }
    
    

    override func layout() {
        super.layout()
        
        textNameView.setFrameSize(NSMakeSize(controls.frame.width - 40, 24))
        textNameView.centerX(y: controls.frame.height - textNameView.frame.height - 20)
        statusTextView.setFrameSize(statusTextView.sizeThatFits(NSMakeSize(controls.frame.width - 40, 30)))
        statusTextView.centerX(y: controls.frame.height - textNameView.frame.height - 20 - 20)
        
        secureTextView.center()
        secureTextView.setFrameOrigin(secureTextView.frame.minX + 2, secureTextView.frame.minY)
        secureContainerView.centerX(y: frame.height - 170 - secureContainerView.frame.height)
        muteControl.setFrameOrigin(frame.width - 60 - muteControl.frame.width, 30 + floorToScreenPixels(scaleFactor: backingScaleFactor, (declineControl.frame.height - muteControl.frame.height)/2))
        
        closeMissedControl.setFrameOrigin(80, 30)

    }
    
    func updateName(_ name:String) {
        textNameView.stringValue = name
        needsLayout = true
    }
    
    func setDuration(_ duration:TimeInterval) {
        statusTextView.stringValue = String.durationTransformed(elapsed: Int(duration))
        needsLayout = true
    }
    
    func updateState(_ state:CallSessionState, animated: Bool) {
        switch state {
        case .accepting:
            statusTextView.stringValue = tr(L10n.callStatusConnecting)
        case .active(_, let visual, _, _):
            let layout = TextViewLayout(.initialize(string: ObjcUtils.callEmojies(visual), color: .black, font: .normal(16.0)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            secureTextView.update(layout)
            secureContainerView.isHidden = false
            secureContainerView.setFrameSize(NSMakeSize(layout.layoutSize.width + 16, layout.layoutSize.height + 10))
            secureContainerView.layer?.cornerRadius = secureContainerView.frame.height / 2
            
            statusTextView.stringValue = tr(L10n.callStatusConnecting)
        case .ringing:
            statusTextView.stringValue = tr(L10n.callStatusCalling)
        case .terminated(let error, _):
            switch error {
            case .ended(let reason):
                
                switch reason {
                case .busy:
                    statusTextView.stringValue = tr(L10n.callStatusBusy)
                case .missed:
                    statusTextView.stringValue = tr(L10n.callStatusEnded) 
                default:
                    statusTextView.stringValue = tr(L10n.callStatusEnded)
                }
                
            case .error:
                 statusTextView.stringValue = tr(L10n.callStatusFailed)
                 acceptControl.isEnabled = false
                 acceptControl.change(opacity: 0.8)
            }
            
            
        case .requesting(let ringing):
            statusTextView.stringValue = !ringing ? tr(L10n.callStatusRequesting) : tr(L10n.callStatusRinging)
        default:
            break
        }
        
        switch state {
        case .active, .accepting, .requesting:
            
            declineControl.change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.declineControl.isHidden = true
                }
            })
            acceptControl.change(pos: NSMakePoint(floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.width - acceptControl.frame.width) / 2), 30), animated: animated)
            acceptControl.set(image: theme.icons.callWindowDecline, for: .Normal)
            
            muteControl.isHidden = false
            muteControl.change(opacity: 1, animated: animated)
            
            closeMissedControl.change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.closeMissedControl.isHidden = true
                }
            })
            
        case .ringing:
            declineControl.isHidden = false
            muteControl.change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.muteControl.isHidden = true
                }
            })
            acceptControl.set(image: theme.icons.callWindowAccept, for: .Normal)
            acceptControl.change(pos: NSMakePoint(frame.width - acceptControl.frame.width - 80, 30), animated: animated)
            declineControl.change(opacity: 1, animated: animated)
            
            closeMissedControl.change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.closeMissedControl.isHidden = true
                }
            })
            
        case .terminated(let reason, _):
            
            let recall:Bool
            
            switch reason {
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
            
            if recall {
                closeMissedControl.isHidden = false
                closeMissedControl.change(opacity: 1, animated: animated)
                
                muteControl.change(opacity: 0, animated: animated, completion: { [weak self] completed in
                    if completed {
                        self?.muteControl.isHidden = true
                    }
                })
                
                acceptControl.set(image: theme.icons.callWindowAccept, for: .Normal)
                acceptControl.change(pos: NSMakePoint(frame.width - acceptControl.frame.width - 80, 30), animated: animated)
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
    let window:NSWindow
    let updateLocalizationAndThemeDisposable = MetaDisposable()
    fileprivate var session:PCallSession! {
        didSet {
            sessionDidUpdated()
        }
    }

    var first:Bool = true

    private func sessionDidUpdated() {
        view.secureContainerView.isHidden = true
        peerDisposable.set((session.account.viewTracker.peerView( session.peerId) |> deliverOnMainQueue).start(next: { [weak self] peerView in
            if let strongSelf = self {
                if let user = peerView.peers[peerView.peerId] as? TelegramUser {
                    strongSelf.updatePeerUI(user)
                }
            }
        }))
        
        stateDisposable.set((session.state.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.applyState(state, animated: !strongSelf.first)
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
    private let keyStateDisposable = MetaDisposable()
    init(_ session:PCallSession) {
        self.session = session
    
        
        let size = NSMakeSize(300, 460)
        if let screen = NSScreen.main {
            self.window = Window(contentRect: NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (screen.frame.width - size.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (screen.frame.height - size.height) / 2), size.width, size.height), styleMask: [.fullSizeContentView], backing: .buffered, defer: true, screen: screen)
            self.window.level = .screenSaver
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
                case .terminated(let reason, _):
                    
                    let recall:Bool
                    switch reason {
                    case .ended(let reason):
                        switch reason {
                        case .busy, .missed:
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
                    
                    if recall {
                        self?.recall()
                    } else {
                        self?.session.hangUpCurrentCall()
                    }
                default:
                    self?.session.hangUpCurrentCall()
                }

            } else {
                closeCall()
            }
        }, for: .Click)
        
        view.closeMissedControl.set(handler: { _ in
            closeCall()
        }, for: .Click)
        
        view.muteControl.set(handler: { [weak self] control in
            if let session = self?.session, let control = control as? ImageButton {
                session.toggleMute()
                control.set(image: session.isMute ? theme.icons.callWindowUnmute : theme.icons.callWindowMute, for: .Normal)
            }
        }, for: .Click)
        
        view.muteControl.set(image: session.isMute ? theme.icons.callWindowUnmute : theme.icons.callWindowMute, for: .Normal)

        
        view.declineControl.set(handler: { [weak self] _ in
            self?.session.hangUpCurrentCall()
        }, for: .Click)
        
        
        /*  view.deviceSettingsButton.set(handler: { [weak self] _ in
            
            if let session = self?.session, let strongSelf = self {
                _ = (combineLatest(session.inputDevices(), session.outputDevices(), session.currentInputDeviceId(), session.currentOutputDeviceId()) |> deliverOnMainQueue).start(next: { [weak strongSelf] input, output, currentInputId, currentOutputId in
                   
                    var settingsWindow:NSWindow!
                    
                    let deviceSettings = NativeCallSettingsViewController(inputDevices: input, outputDevices: output, currentInputDeviceId: currentInputId, currentOutputDeviceId: currentOutputId, onSave: { [weak strongSelf] (inputDevice, outputDevice) in
                        strongSelf?.session.setCurrentInputDevice(inputDevice)
                        strongSelf?.session.setCurrentOutputDevice(outputDevice)
                    }, onCancel: {
                    })
                    
                    settingsWindow = NSWindow(contentViewController: deviceSettings)
                    settingsWindow.styleMask = [.borderless]
                    //settingsWindow.appearance = mainWindow.appearance
                    settingsWindow.contentView?.wantsLayer = true
                    settingsWindow.contentView?.layer?.cornerRadius = 4
                    //settingsWindow.contentView?.background = theme.colors.background
                    //settingsWindow.backgroundColor = theme.colors.background
                    //settingsWindow.isOpaque = false
                    
                    strongSelf?.window.beginSheet(settingsWindow, completionHandler: { response in
                        
                    })
                })
                
              
            }
            
        }, for: .Click)
 */
        
        self.window.contentView = view
        self.window.backgroundColor = .clear
        self.window.contentView?.layer?.cornerRadius = 4
        self.window.titlebarAppearsTransparent = true
        self.window.isMovableByWindowBackground = true
 
        sessionDidUpdated()
    }
    
    private func recall() {
        let account = session.account
        let peerId = session.peerId
        
        recallDisposable.set((phoneCall(account, peerId: peerId, ignoreSame: true) |> deliverOnMainQueue).start(next: { [weak self] result in
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
                if case .active = state, !strongSelf.window.isKeyWindow {
                    closeCall()
                }
                
            }
        }))
    }
    
    private func applyState(_ state:CallSessionState, animated: Bool) {
        self.state = state
        view.updateState(state, animated: animated)
        switch state {
        case .ringing:
            break
        case .accepting:
            break
        case .requesting:
            break
        case .active:
            session.account.context.showCallHeader(with: session)
        case .dropping:
            break
        case .terminated(let error, _):
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
                disposable.set((session.account.viewTracker.peerView( session.peerId) |> deliverOnMainQueue).start(next: { peerView in
                    if let peer = peerViewMainPeer(peerView) {
                        switch error {
                        case .privacyRestricted:
                            alert(for: mainWindow, info: tr(L10n.callPrivacyErrorMessage(peer.compactDisplayTitle)))
                        case .notSupportedByPeer:
                            alert(for: mainWindow, info: tr(L10n.callParticipantVersionOutdatedError(peer.compactDisplayTitle)))
                        case .serverProvided(let serverError):
                            alert(for: mainWindow, info: serverError)
                        case .generic:
                            alert(for: mainWindow, info: tr(L10n.callUndefinedError))
                        default:
                            break
                        }
                        
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
        updateLocalizationAndThemeDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    func show() {
        var first: Bool = true
        disposable.set((session.account.viewTracker.peerView( session.peerId) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peerView in
            if let strongSelf = self {
                if let user = peerView.peers[peerView.peerId] as? TelegramUser {
                    strongSelf.updatePeerUI(user)
                }
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
        
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: user.profileImageRepresentations, reference: nil)
        

        
        if let dimension = user.profileImageRepresentations.last?.dimensions {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: view.imageView.frame.size, intrinsicInsets: NSEdgeInsets())
            view.imageView.setSignal(signal: cachedMedia(media: media, size: arguments.imageSize, scale: view.backingScaleFactor))
            view.imageView.setSignal(chatMessagePhoto(account: session.account, photo: media, scale: view.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { [weak self] image in
                if let strongSelf = self {
                    return cacheMedia(signal: image, media: media, size: arguments.imageSize, scale: strongSelf.view.backingScaleFactor)
                } else {
                    return .complete()
                }
            })
            view.imageView.set(arguments: arguments)

        } else {
            view.imageView.setSignal(signal: generateEmptyRoundAvatar(view.imageView.frame.size, font: .avatar(90.0), account: session.account, peer: user))
        }
        
        
       
        
        _ = chatMessagePhotoInteractiveFetched(account: session.account, photo: media).start()
        
        
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
    var signal = Signal<Void, Void>.single(Void()) |> deliverOnMainQueue
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


func applyUIPCallResult(_ account:Account, _ result:PCallResult) {
    assertOnMainThread()
    
    switch result {
    case let .success(session):
        showPhoneCallWindow(session)
    case .fail:
        break
    case let .samePeer(session):
        if let header = account.context.mainNavigation?.callHeader, header.needShown {
            (header.view as? CallNavigationHeaderView)?.hide()
            showPhoneCallWindow(session)
        } else {
            controller?.window.orderFront(nil)
        }
    }
}
