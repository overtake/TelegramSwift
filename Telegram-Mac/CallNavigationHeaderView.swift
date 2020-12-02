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

class CallNavigationHeaderView: NavigationHeaderView {
    private let backgroundView = NSView()
    private let callInfo:TitleButton = TitleButton()
    private let endCall:TitleButton = TitleButton()
    private let statusTextView:NSTextField = NSTextField()
    private let muteControl:ImageButton = ImageButton()
    private let dropCall:ImageButton = ImageButton()

    private let disposable = MetaDisposable()
    private let hideDisposable = MetaDisposable()

    
    private(set) var session: PCallSession?
    private var state: CallState?
    private weak var accountPeer: Peer?
    
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
    
    private func updateStatus() {
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
        statusTextView.stringValue = statusText
        statusTextView.sizeToFit()
        needsLayout = true
    }

    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let session = session {
            showCallWindow(session)
        }
    }
    
    func hide() {
        header?.hide(true)
        disposable.set(nil)
    }
    
    func update(with session: PCallSession) {
        self.session = session
        
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
                self?.callInfo.set(text: peer.displayTitle, for: .Normal)
            }
            self?.updateState(state, accountPeer: accountPeer, animated: false)
            self?.needsLayout = true
            self?.ready.set(.single(true))
        }))
        
        hideDisposable.set((session.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.hide()
                self?.session = nil
            }
        }))
        
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
        
        statusTextView.font = .normal(.text)
        statusTextView.drawsBackground = false
        statusTextView.backgroundColor = .clear
        statusTextView.isSelectable = false
        statusTextView.isEditable = false
        statusTextView.isBordered = false
        statusTextView.focusRingType = .none
        statusTextView.maximumNumberOfLines = 1

        addSubview(statusTextView)
        
        callInfo.set(font: .medium(.text), for: .Normal)
        callInfo.disableActions()
        addSubview(callInfo)
        callInfo.userInteractionEnabled = false
        
        endCall.set(font: .medium(.text), for: .Normal)
        endCall.disableActions()
        addSubview(endCall)
        
        dropCall.autohighlight = false
    
        addSubview(dropCall)
        
        callInfo.set(handler: { [weak self] _ in
            if let session = self?.session {
                showCallWindow(session)
                self?.hide()
            }
        }, for: .Click)
        
        dropCall.set(handler: { [weak self] _ in
            self?.session?.hangUpCurrentCall()
        }, for: .Click)
        
        endCall.set(handler: { [weak self] _ in
            self?.session?.hangUpCurrentCall()
        }, for: .Click)
        
        
        muteControl.autohighlight = false
        addSubview(muteControl)
        
        muteControl.set(handler: { [weak self] control in
            if let session = self?.session {
                session.toggleMute()
            }
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    private var blueColor:NSColor {
        return theme.colors.accentSelect
    }
    private var grayColor:NSColor {
        return theme.colors.grayText
    }
    
    private func updateState(_ state:CallState, accountPeer: Peer?, animated: Bool) {
        self.state = state
        self.status = state.state.statusText(accountPeer, state.videoState)
        backgroundView.background = state.isMuted ? grayColor : blueColor
        if animated {
            backgroundView.layer?.animateBackground()
        }
        muteControl.set(image: !state.isMuted ? theme.icons.callInlineUnmuted : theme.icons.callInlineMuted, for: .Normal)
        _ = muteControl.sizeToFit()
        needsLayout = true
        
        switch state.state {
        case let .terminated(_, reason, _):
            if let reason = reason, reason.recall {
                
            } else {
                backgroundView.background = (state.isMuted ? grayColor : blueColor).withAlphaComponent(0.6)
                muteControl.removeAllHandlers()
                endCall.removeAllHandlers()
                callInfo.removeAllHandlers()
                dropCall.removeAllHandlers()
                muteControl.change(opacity: 0.8, animated: animated)
                endCall.change(opacity: 0.8, animated: animated)
                statusTextView._change(opacity: 0.8, animated: animated)
                callInfo._change(opacity: 0.8, animated: animated)
                dropCall._change(opacity: 0.8, animated: animated)
            }
        default:
            break
        }
    }
    
    override func layout() {
        super.layout()
        
        backgroundView.frame = bounds
        muteControl.centerY(x:23)
        statusTextView.centerY(x: muteControl.frame.maxX + 6)
        callInfo.center()
        dropCall.centerY(x: frame.width - dropCall.frame.width - 25)
        endCall.centerY(x: dropCall.frame.minX - 6 - endCall.frame.width)
        _ = callInfo.sizeToFit(NSZeroSize, NSMakeSize(frame.width - 30 - endCall.frame.width - 90, callInfo.frame.height), thatFit: true)
        callInfo.center()
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        dropCall.set(image: theme.icons.callInlineDecline, for: .Normal)
        _ = dropCall.sizeToFit()
        endCall.set(text: tr(L10n.callHeaderEndCall), for: .Normal)
        _ = endCall.sizeToFit(NSZeroSize, NSMakeSize(80, 20), thatFit: true)
        statusTextView.textColor = .white
        callInfo.set(color: .white, for: .Normal)
        endCall.set(color: .white, for: .Normal)
        
        if let state = state {
            self.updateState(state, accountPeer: accountPeer, animated: false)
        }
        
        needsLayout = true

    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}




class GroupCallNavigationHeaderView: NavigationHeaderView {
    private let backgroundView = NSView()
    private let callInfo:TitleButton = TitleButton()
    private let endCall:TitleButton = TitleButton()
    private let statusTextView:NSTextField = NSTextField()
    private let muteControl:ImageButton = ImageButton()
    private let dropCall:ImageButton = ImageButton()

    private let disposable = MetaDisposable()
    private let hideDisposable = MetaDisposable()

    
    private(set) var context: GroupCallContext?
    
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
    
    private func updateStatus() {
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
        statusTextView.stringValue = statusText
        statusTextView.sizeToFit()
        needsLayout = true
    }

    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        self.context?.present()
    }
    
    func hide() {
        header?.hide(true)
        disposable.set(nil)
    }
    
    func update(with context: GroupCallContext) {
        self.context = context
        
        let peerId = context.call.peerId
        
        let data = context.call.summaryState
        |> filter { $0 != nil }
        |> map { $0! }
        |> map { summary -> GroupCallPanelData in
            return GroupCallPanelData(
                peerId: peerId,
                info: summary.info,
                topParticipants: summary.topParticipants,
                participantCount: summary.participantCount,
                numberOfActiveSpeakers: summary.numberOfActiveSpeakers,
                groupCall: nil
            )
        }

        let account = context.call.account
        
        let signal = Signal<Peer?, NoError>.single(context.call.peer) |> then(context.call.account.postbox.loadedPeerWithId(context.call.peerId) |> map(Optional.init) |> deliverOnMainQueue)
        
        let accountPeer: Signal<Peer?, NoError> = context.call.sharedContext.activeAccounts |> mapToSignal { accounts in
            if accounts.accounts.count == 1 {
                return .single(nil)
            } else {
                return account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
            }
        }
        
        disposable.set(combineLatest(queue: .mainQueue(), context.call.state, data, signal, accountPeer, appearanceSignal).start(next: { [weak self] state, data, peer, accountPeer, _ in
            if let peer = peer {
                self?.callInfo.set(text: peer.displayTitle, for: .Normal)
            }
            self?.updateState(state, data: data, accountPeer: accountPeer, animated: false)
            self?.needsLayout = true
            self?.ready.set(.single(true))
        }))
        
        hideDisposable.set((context.call.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.context = nil
                self?.hide()
            }
        }))
        
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
        
        statusTextView.font = .normal(.text)
        statusTextView.drawsBackground = false
        statusTextView.backgroundColor = .clear
        statusTextView.isSelectable = false
        statusTextView.isEditable = false
        statusTextView.isBordered = false
        statusTextView.focusRingType = .none
        statusTextView.maximumNumberOfLines = 1

        addSubview(statusTextView)
        
        callInfo.set(font: .medium(.text), for: .Normal)
        callInfo.disableActions()
        addSubview(callInfo)
        callInfo.userInteractionEnabled = false
        
        endCall.set(font: .medium(.text), for: .Normal)
        endCall.disableActions()
        addSubview(endCall)
        
        dropCall.autohighlight = false
    
        addSubview(dropCall)
        
        callInfo.set(handler: { [weak self] _ in
            self?.context?.present()
        }, for: .Click)
        
        dropCall.set(handler: { [weak self] _ in
            self?.context?.leave()
        }, for: .Click)
        
        endCall.set(handler: { [weak self] _ in
            self?.context?.leave()
        }, for: .Click)
        
        muteControl.autohighlight = false
        addSubview(muteControl)
        
        muteControl.set(handler: { [weak self] control in
            if let context = self?.context {
                context.call.toggleIsMuted()
            }
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    private func updateState(_ state: PresentationGroupCallState, data: GroupCallPanelData, accountPeer: Peer?, animated: Bool) {
        switch state.networkState {
        case .connecting:
            backgroundView.background = theme.colors.grayIcon
            self.status = .text(L10n.voiceChatStatusConnecting, nil)
        case .connected:
            if let muteState = state.muteState {
                if muteState.canUnmute {
                    backgroundView.background = theme.colors.accent
                } else {
                    backgroundView.background = theme.colors.grayIcon
                }
            } else {
                backgroundView.background = theme.colors.greenUI
            }
            self.status = .text(L10n.voiceChatStatusMembersCountable(data.participantCount), nil)
        }
        if animated {
            backgroundView.layer?.animateBackground()
        }

        muteControl.set(image: state.muteState == nil ? theme.icons.callInlineUnmuted : theme.icons.callInlineMuted, for: .Normal)
        _ = muteControl.sizeToFit()
        needsLayout = true
        
    }
    
    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        muteControl.centerY(x:23)
        statusTextView.centerY(x: muteControl.frame.maxX + 6)
        callInfo.center()
        dropCall.centerY(x: frame.width - dropCall.frame.width - 25)
        endCall.centerY(x: dropCall.frame.minX - 6 - endCall.frame.width)
        _ = callInfo.sizeToFit(NSZeroSize, NSMakeSize(frame.width - 30 - endCall.frame.width - 90, callInfo.frame.height), thatFit: true)
        callInfo.center()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        dropCall.set(image: theme.icons.callInlineDecline, for: .Normal)
        _ = dropCall.sizeToFit()
        endCall.set(text: L10n.voiceChatLeaveCall, for: .Normal)
        _ = endCall.sizeToFit(NSZeroSize, .zero, thatFit: false)
        statusTextView.textColor = .white
        callInfo.set(color: .white, for: .Normal)
        endCall.set(color: .white, for: .Normal)
        needsLayout = true
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
