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
        _ = acceptControl.sizeToFit()
        
        declineControl.autohighlight = false
        declineControl.set(image: theme.icons.callWindowDecline, for: .Normal)
        _ = declineControl.sizeToFit()
        
        muteControl.autohighlight = false
        muteControl.set(image: theme.icons.callWindowMute, for: .Normal)
        _ = muteControl.sizeToFit()
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
        muteControl.setFrameOrigin(frame.width - 60 - muteControl.frame.width, 30 + floorToScreenPixels(backingScaleFactor, (declineControl.frame.height - muteControl.frame.height)/2))
        
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
    
    func updateState(_ state:CallSessionState, accountPeer: Peer?, animated: Bool) {
        switch state {
        case .accepting:
            statusTextView.stringValue = L10n.callStatusConnecting
        case .active(_, _, let visual, _, _, _):
            let layout = TextViewLayout(.initialize(string: ObjcUtils.callEmojies(visual), color: .black, font: .normal(16.0)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            secureTextView.update(layout)
            secureContainerView.isHidden = false
            secureContainerView.setFrameSize(NSMakeSize(layout.layoutSize.width + 16, layout.layoutSize.height + 10))
            secureContainerView.layer?.cornerRadius = secureContainerView.frame.height / 2
            
            statusTextView.stringValue = L10n.callStatusConnecting
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
            
            declineControl.change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.declineControl.isHidden = true
                }
            })
            acceptControl.change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - acceptControl.frame.width) / 2), 30), animated: animated)
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
            
        case .terminated(_, let reason, _):
            
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
                strongSelf.applyState(state, accountPeer: accountPeer, animated: !strongSelf.first)
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
            self.window = Window(contentRect: NSMakeRect(floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2), floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2), size.width, size.height), styleMask: [.fullSizeContentView], backing: .buffered, defer: true, screen: screen)
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
        
 
        self.window.contentView = view
        self.window.backgroundColor = .clear
        self.window.contentView?.layer?.cornerRadius = 4
        self.window.titlebarAppearsTransparent = true
        self.window.isMovableByWindowBackground = true
 
        sessionDidUpdated()
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
                if case .active = state, !strongSelf.window.isKeyWindow {
                    closeCall()
                }
                
            }
        }))
    }
    
    private func applyState(_ state:CallSessionState, accountPeer: Peer?, animated: Bool) {
        self.state = state
        view.updateState(state, accountPeer: accountPeer, animated: animated)
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
        updateLocalizationAndThemeDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
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
        
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: user.id.toInt64()), representations: user.profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil)
        

        if let dimension = user.profileImageRepresentations.last?.dimensions {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: view.imageView.frame.size, intrinsicInsets: NSEdgeInsets())
            view.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: view.backingScaleFactor), clearInstantly: true)
            view.imageView.setSignal(chatMessagePhoto(account: session.account, imageReference: ImageMediaReference.standalone(media: media), scale: view.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { result in
                 cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
            })
            view.imageView.set(arguments: arguments)

        } else {
            view.imageView.setSignal(signal: generateEmptyRoundAvatar(view.imageView.frame.size, font: .avatar(90.0), account: session.account, peer: user) |> map { TransformImageResult($0, true) })
        }
        
        
       
        
        _ = chatMessagePhotoInteractiveFetched(account: session.account, imageReference: ImageMediaReference.standalone(media: media)).start()
        
        
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
