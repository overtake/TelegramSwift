//
//  CallNavigationHeaderView.swift
//  Telegram
//
//  Created by keepcoder on 05/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

class CallNavigationHeaderView: NavigationHeaderView {
    private let backgroundView = NSView()
    private let callInfo:TitleButton = TitleButton()
    private let endCall:TitleButton = TitleButton()
    private let durationView:NSTextField = NSTextField()
    private let muteControl:ImageButton = ImageButton()
    private let dropCall:ImageButton = ImageButton()
    private let durationDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private var session:PCallSession? = nil {
        didSet {
            if let session = session {
                durationDisposable.set(session.durationPromise.get().start(next: { [weak self] duration in
                    self?.durationView.stringValue = String.durationTransformed(elapsed: Int(duration))
                    self?.durationView.sizeToFit()
                    self?.needsLayout = true
                }))
                
                stateDisposable.set((session.state.get() |> deliverOnMainQueue).start(next: { [weak self] state in
                    switch state {
                    case .terminated, .dropping:
                        self?.hide()
                    default:
                        break
                    }
                }))
            } else {
                durationDisposable.set(nil)
                stateDisposable.set(nil)
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let session = session {
            showPhoneCallWindow(session)
        }
    }
    
    func hide() {
        header?.hide(true)
        stateDisposable.set(nil)
        durationDisposable.set(nil)
    }
    
    func update(with session: PCallSession) {
        self.session = session
        
        let signal = session.account.viewTracker.peerView( session.peerId) |> deliverOnMainQueue |> beforeNext { [weak self] peerView in
            
            if let peer = peerViewMainPeer(peerView), let strongSelf = self {
                strongSelf.callInfo.set(text: peer.displayTitle, for: .Normal)
                strongSelf.needsLayout = true
            }
        } |> map {_ in return true}
        
        self.ready.set(signal)
        updateMutedBg(session, animated: false)
    }
    
    deinit {
        stateDisposable.dispose()
        durationDisposable.dispose()
    }
    
    override init(_ header: NavigationHeader) {
        super.init(header)
        
        backgroundView.frame = bounds
        backgroundView.wantsLayer = true
        addSubview(backgroundView)
        
        durationView.font = .normal(.text)
        durationView.drawsBackground = false
        durationView.backgroundColor = .clear
        durationView.isSelectable = false
        durationView.isEditable = false
        durationView.isBordered = false
        durationView.focusRingType = .none
        durationView.maximumNumberOfLines = 1

        addSubview(durationView)
        


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
                showPhoneCallWindow(session)
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
                self?.updateMutedBg(session, animated: true)
            }
        }, for: .Click)
        
        updateLocalizationAndTheme()
    }
    
    private var blueColor:NSColor {
        return theme.colors.blueSelect
    }
    private var grayColor:NSColor {
        return theme.colors.grayText
    }
    
    private func updateMutedBg(_ session:PCallSession, animated: Bool) {
        backgroundView.background = session.isMute ? grayColor : blueColor
        if animated {
            backgroundView.layer?.animateBackground()
        }
        muteControl.set(image: !session.isMute ? theme.icons.callInlineUnmuted : theme.icons.callInlineMuted, for: .Normal)
        muteControl.sizeToFit()
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        backgroundView.frame = bounds
        muteControl.centerY(x:20)
        durationView.centerY(x: muteControl.frame.maxX + 6)
        callInfo.center()
        dropCall.centerY(x: frame.width - dropCall.frame.width - 20)
        endCall.centerY(x: dropCall.frame.minX - 6 - endCall.frame.width)
        callInfo.sizeToFit(NSZeroSize, NSMakeSize(frame.width - durationView.frame.maxX - endCall.frame.width - 90, callInfo.frame.height), thatFit: true)
        callInfo.center()
    }
    
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        dropCall.set(image: theme.icons.callInlineDecline, for: .Normal)
        dropCall.sizeToFit()
        endCall.set(text: tr(L10n.callHeaderEndCall), for: .Normal)
        endCall.sizeToFit(NSZeroSize, NSMakeSize(80, 20), thatFit: true)
        durationView.textColor = .white
        callInfo.set(color: .white, for: .Normal)
        endCall.set(color: .white, for: .Normal)
        
        if let session = session {
            updateMutedBg(session, animated: false)
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
