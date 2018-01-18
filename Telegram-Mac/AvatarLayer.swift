//
//  AvatarControl.swift
//  Telegram-Mac
//
//  Created by keepcoder on 15/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit
import SwiftSignalKitMac
private class AvatarNodeParameters: NSObject {
    let account: Account
    let peerId: PeerId
    let letters: [String]
    let font: NSFont
    init(account: Account, peerId: PeerId, letters: [String], font: NSFont) {
        self.account = account
        self.peerId = peerId
        self.letters = letters
        self.font = font
        super.init()
    }
}



private enum AvatarNodeState: Equatable {
    case Empty
    case PeerAvatar(PeerId, [String], TelegramMediaImageRepresentation?, CGFloat)
}

private func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
    case (.Empty, .Empty):
        return true
    case let (.PeerAvatar(lhsPeerId, lhsLetters, lhsPhotoRepresentations, lhsScale), .PeerAvatar(rhsPeerId, rhsLetters, rhsPhotoRepresentations, rhsScale)):
        return lhsPeerId == rhsPeerId && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations && lhsScale == rhsScale
    default:
        return false
    }
}

class AvatarControl: NSView {
    private var trackingArea:NSTrackingArea?
    private var displaySuspended:Bool = false
    var userInteractionEnabled:Bool = true
    private let longOverHandleDisposable = MetaDisposable()

    private var handlers:[(ControlEvent,(AvatarControl) -> Void)] = []
    
    var font: NSFont {
        didSet {
            if oldValue !== font {
                if let parameters = self.parameters {
                    self.parameters = AvatarNodeParameters(account: parameters.account, peerId: parameters.peerId, letters: parameters.letters, font: self.font)
                }
                
                if !self.displaySuspended {
                    self.needsDisplay = true
                }
            }
        }
    }
    private var parameters: AvatarNodeParameters?
    private let disposable = MetaDisposable()

    private var state: AvatarNodeState = .Empty
    private var account:Account?
    private var peer:Peer?
    
    
    public var animated: Bool = false
    
    public init(font: NSFont) {
        self.font = font
        super.init(frame: NSZeroRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }
    

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required override init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override public var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let updateImage = !value.size.equalTo(super.frame.size)
            super.frame = value
            if updateImage && !self.displaySuspended {
                self.needsDisplay = true
            }
        }
    }
    
    public func setPeer(account: Account, peer: Peer?) {
        self.account = account
        self.peer = peer
        self.viewDidChangeBackingProperties()
    }
    
    func set(handler:@escaping (AvatarControl) -> Void, for event:ControlEvent) -> Void {
        handlers.append((event,handler))
    }
    
    override open func mouseEntered(with event: NSEvent) {
        if userInteractionEnabled {
            
            let disposable = (Signal<Void,Void>.single(Void()) |> delay(0.3, queue: Queue.mainQueue())).start(next: { [weak self] in
                if let strongSelf = self, strongSelf._mouseInside() {
                    strongSelf.send(event: .LongOver)
                }
            })
            longOverHandleDisposable.set(disposable)
            
        } else {
            super.mouseEntered(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if userInteractionEnabled {
            longOverHandleDisposable.set(nil)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override open func mouseUp(with event: NSEvent) {
                
        if userInteractionEnabled {
            
            if _mouseInside() {
                if event.clickCount == 1  {
                    send(event: .SingleClick)
                }
                send(event: .Click)
            }
            
        } else {
            super.mouseUp(with: event)
        }
    }
    
    func removeAllHandlers() ->Void {
        handlers.removeAll()
    }
    
    func send(event:ControlEvent) -> Void {
        for (e,handler) in handlers {
            if e == event {
                handler(self)
            }
        }
    }
    
    override func viewDidChangeBackingProperties() {
        
        layer?.contentsScale = backingScaleFactor
        
        let updatedState:AvatarNodeState
        if let peer = peer {
            updatedState = AvatarNodeState.PeerAvatar(peer.id, peer.displayLetters, peer.smallProfileImage, backingScaleFactor)
        } else {
            updatedState = .Empty
        }
        
        if let account = account, let peer = peer {
            if updatedState != self.state {
                self.state = updatedState
                
                let parameters = AvatarNodeParameters(account: account, peerId: peer.id, letters: peer.displayLetters, font: self.font)
                
                self.displaySuspended = true
                self.layer?.contents = nil
                
                if let signal = peerAvatarImage(account: account, peer: peer, displayDimensions:frame.size, scale:backingScaleFactor, font: self.font) {
                    setSignal(signal)
                    
                } else {
                    self.displaySuspended = false
                }
                if self.parameters == nil || self.parameters != parameters {
                    self.parameters = parameters
                    self.needsDisplay = true
                }
            }
        } else {
            self.state = .Empty
        }
    }
    
    public func setSignal(_ signal: Signal<(CGImage?, Bool), NoError>) {
        self.disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] image, animated in
            if let strongSelf = self {
                strongSelf.layer?.contents = image
                if animated {
                    strongSelf.layer?.animateContents()
                }
            }
        }))
    }
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        trackingArea = nil
        
        if let _ = window {
            let options:NSTrackingArea.Options = [.cursorUpdate, .mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect]
            self.trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            
            self.addTrackingArea(self.trackingArea!)
        }
    }
    
    open override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateTrackingAreas()
    }
    
    deinit {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        disposable.dispose()
        longOverHandleDisposable.dispose()
    }

    override func copy() -> Any {
        let view = NSView()
        view.wantsLayer = true
        view.background = .clear
        view.layer?.frame = NSMakeRect(0, visibleRect.minY == 0 ? 0 : visibleRect.height - frame.height, frame.width,  frame.height)
        view.layer?.contents = self.layer?.contents
        view.layer?.masksToBounds = true
        view.frame = self.visibleRect
        view.layer?.shouldRasterize = true
        view.layer?.rasterizationScale = backingScaleFactor
        return view
    }
}
