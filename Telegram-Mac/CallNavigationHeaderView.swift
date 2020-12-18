//
//  CallNavigationHeaderView.swift
//  Telegram
//
//  Created by keepcoder on 05/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox


class CallHeaderBasicView : NavigationHeaderView {

    private var _backgroundView: NSView?
    var backgroundView: NSView {
        if _backgroundView == nil {
            _backgroundView = NSView()
        }
        return _backgroundView!
    }
    fileprivate let callInfo:TitleButton = TitleButton()
    fileprivate let endCall:ImageButton = ImageButton()
    fileprivate let statusTextView:DynamicCounterTextView = DynamicCounterTextView()
    fileprivate let muteControl:ImageButton = ImageButton()

    let disposable = MetaDisposable()
    let hideDisposable = MetaDisposable()


    override func hide(_ animated: Bool) {
        super.hide(true)
        disposable.set(nil)
        hideDisposable.set(nil)
    }
    
    private var statusTimer: SwiftSignalKit.Timer?

    
    var status: CallControllerStatusValue = .text("", nil) {
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
    
    private func updateStatus(animated: Bool = true) {
        var statusText: String = ""
        switch self.status {
        case let .text(text, _):
            statusText = text
        case let .timer(referenceTime, _):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
            }
            statusText = durationString
        }
        let dynamicResult = DynamicCounterTextView.make(for: statusText, count: statusText.trimmingCharacters(in: CharacterSet.decimalDigits.inverted), font: .normal(.text), textColor: .white, width: frame.width - 140)
        self.statusTextView.update(dynamicResult.values, animated: animated)
        self.statusTextView.change(size: dynamicResult.size, animated: animated)

        needsLayout = true
    }
    
    deinit {
        disposable.dispose()
        hideDisposable.dispose()
    }
    
    override init(_ header: NavigationHeader) {
        super.init(header)
        
        backgroundView.frame = bounds
        backgroundView.wantsLayer = true
        addSubview(backgroundView)
        
        statusTextView.backgroundColor = .clear


        callInfo.set(font: .medium(.text), for: .Normal)
        callInfo.disableActions()
        backgroundView.addSubview(callInfo)
        callInfo.userInteractionEnabled = false
        
        endCall.disableActions()
        backgroundView.addSubview(endCall)
        
        endCall.scaleOnClick = true
        muteControl.scaleOnClick = true

        backgroundView.addSubview(statusTextView)

        callInfo.set(handler: { [weak self] _ in
            self?.showInfoWindow()
        }, for: .Click)
        
    
        endCall.set(handler: { [weak self] _ in
            self?.hangUp()
        }, for: .Click)
        
        
        muteControl.autohighlight = false
        backgroundView.addSubview(muteControl)
        
        muteControl.set(handler: { [weak self] _ in
            self?.toggleMute()
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    func toggleMute() {
        
    }
    func showInfoWindow() {
        
    }
    func hangUp() {
        
    }

    func setInfo(_ text: String) {
        self.callInfo.set(text: text, for: .Normal)
    }
    func setMicroIcon(_ image: CGImage) {
        muteControl.set(image: image, for: .Normal)
        _ = muteControl.sizeToFit()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let point = self.convert(event.locationInWindow, from: nil)
        if let header = header, point.y <= header.height {
            showInfoWindow()
        }
    }
    
    var blueColor:NSColor {
        return theme.colors.accentSelect
    }
    var grayColor:NSColor {
        return theme.colors.grayText
    }

    func getEndText() -> String {
        return L10n.callHeaderEndCall
    }
    
    override func layout() {
        super.layout()
        
        backgroundView.frame = NSMakeRect(0, 0, frame.width, height)
        muteControl.centerY(x:18)
        statusTextView.centerY(x: muteControl.frame.maxX + 6)
        endCall.centerY(x: frame.width - endCall.frame.width - 20)
        _ = callInfo.sizeToFit(NSZeroSize, NSMakeSize(frame.width - 100 - 30 - endCall.frame.width - 100, callInfo.frame.height), thatFit: true)
        callInfo.center()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        endCall.set(image: theme.icons.callInlineDecline, for: .Normal)
        endCall.set(image: theme.icons.callInlineDecline, for: .Highlight)
        _ = endCall.sizeToFit(NSMakeSize(10, 10), thatFit: false)
        callInfo.set(color: .white, for: .Normal)

        needsLayout = true

    }
    
}

class CallNavigationHeaderView: CallHeaderBasicView {
    
    var session: PCallSession? {
        get {
            self.header?.contextObject as? PCallSession
        }
    }

    fileprivate weak var accountPeer: Peer?
    fileprivate var state: CallState?

    override func showInfoWindow() {
        if let session = self.session {
            showCallWindow(session)
        }
    }
    override func hangUp() {
        self.session?.hangUpCurrentCall()
    }
    
    override func toggleMute() {
        session?.toggleMute()
    }
    
    override func update(with contextObject: Any) {
        super.update(with: contextObject)
        let session = contextObject as! PCallSession
        let account = session.account
        let signal = Signal<Peer?, NoError>.single(session.peer) |> then(session.account.postbox.loadedPeerWithId(session.peerId) |> map(Optional.init) |> deliverOnMainQueue)

        let accountPeer: Signal<Peer?, NoError> =  session.sharedContext.activeAccounts |> mapToSignal { accounts in
            if accounts.accounts.count == 1 {
                return .single(nil)
            } else {
                return account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
            }
        }

        disposable.set(combineLatest(queue: .mainQueue(), session.state, signal, accountPeer).start(next: { [weak self] state, peer, accountPeer in
            if let peer = peer {
                self?.setInfo(peer.displayTitle)
            }
            self?.updateState(state, accountPeer: accountPeer, animated: false)
            self?.needsLayout = true
            self?.ready.set(.single(true))
        }))

        hideDisposable.set((session.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.hide(true)
            }
        }))
    }
    
    private func updateState(_ state:CallState, accountPeer: Peer?, animated: Bool) {
        self.state = state
        self.status = state.state.statusText(accountPeer, state.videoState)
        backgroundView.background = state.isMuted ? grayColor : blueColor
        if animated {
            backgroundView.layer?.animateBackground()
        }
        setMicroIcon(!state.isMuted ? theme.icons.callInlineUnmuted : theme.icons.callInlineMuted)
        needsLayout = true
        
        switch state.state {
        case let .terminated(_, reason, _):
            if let reason = reason, reason.recall {
                
            } else {
                backgroundView.background = (state.isMuted ? grayColor : blueColor).withAlphaComponent(0.6)
                muteControl.removeAllHandlers()
                endCall.removeAllHandlers()
                callInfo.removeAllHandlers()
                muteControl.change(opacity: 0.8, animated: animated)
                endCall.change(opacity: 0.8, animated: animated)
                statusTextView._change(opacity: 0.8, animated: animated)
                callInfo._change(opacity: 0.8, animated: animated)
            }
        default:
            break
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        if let state = state {
            self.updateState(state, accountPeer: accountPeer, animated: false)
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(_ header: NavigationHeader) {
        super.init(header)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}

