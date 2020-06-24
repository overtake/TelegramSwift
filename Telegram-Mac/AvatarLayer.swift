//
//  AvatarControl.swift
//  Telegram-Mac
//
//  Created by keepcoder on 15/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import TGUIKit
import SwiftSignalKit
import SyncCore

private class AvatarNodeParameters: NSObject {
    let account: Account
    let peerId: Peer
    let letters: [String]
    let font: NSFont
    init(account: Account, peerId: Peer, letters: [String], font: NSFont) {
        self.account = account
        self.peerId = peerId
        self.letters = letters
        self.font = font
        super.init()
    }
}



enum AvatarNodeState: Equatable {
    case Empty
    case PeerAvatar(Peer, [String], TelegramMediaImageRepresentation?, Message?)
    case ArchivedChats

}

func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
    case (.Empty, .Empty):
        return true
    case let (.PeerAvatar(lhsPeer, lhsLetters, lhsPhotoRepresentations, _), .PeerAvatar(rhsPeer, rhsLetters, rhsPhotoRepresentations, _)):
        return lhsPeer.isEqual(rhsPeer) && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations
    case (.ArchivedChats, .ArchivedChats):
        return true
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
                
                if !self.displaySuspended {
                    self.needsDisplay = true
                }
            }
        }
    }
    private let disposable = MetaDisposable()

    private var state: AvatarNodeState = .Empty
    private var account:Account?
    private var contentScale: CGFloat = 0
    
    public var animated: Bool = false
    private var _attemptLoadNextSynchronous: Bool = false
    public var attemptLoadNextSynchronous: Bool {
        get {
            let result = _attemptLoadNextSynchronous
            _attemptLoadNextSynchronous = false
            return result
        }
        set {
            _attemptLoadNextSynchronous = newValue
        }
    }
    
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
    
    public func setState(account: Account, state: AvatarNodeState) {
        self.account = account
        if state != self.state {
            contentScale = 0
            self.state = state
            self.viewDidChangeBackingProperties()
        }
    }
    
    public func setPeer(account: Account, peer: Peer?, message: Message? = nil) {
        self.account = account
        let state: AvatarNodeState
        if let peer = peer {
            state = .PeerAvatar(peer, peer.displayLetters, peer.smallProfileImage, message)
        } else {
            state = .Empty
        }
        if self.state != state {
            self.state = state
            contentScale = 0
            self.viewDidChangeBackingProperties()
        }
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
        
        
        if let account = account, self.state != .Empty {
            if contentScale != backingScaleFactor {
                contentScale = backingScaleFactor
                self.displaySuspended = true
                self.layer?.contents = nil
                let photo: PeerPhoto?
                switch state {
                case let .PeerAvatar(peer, letters, representation, message):
                    if let peer = peer as? TelegramUser, peer.firstName == nil && peer.lastName == nil {
                        photo = nil
                        self.setState(account: account, state: .Empty)
                        let icon = theme.icons.deletedAccount
                        self.setSignal(generateEmptyPhoto(frame.size, type: .icon(colors: theme.colors.peerColors(Int(peer.id.id % 7)), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(min(50, frame.size.width - 20), min(frame.size.height - 20, 50))), cornerRadius: nil)) |> map {($0, false)})
                        return
                    } else {
                        photo = .peer(peer, representation, letters, message)
                    }
                case .Empty:
                    photo = nil
                default:
                    photo = nil
                }
                if let photo = photo {
                    setSignal(peerAvatarImage(account: account, photo: photo, displayDimensions: frame.size, scale:backingScaleFactor, font: self.font, synchronousLoad: attemptLoadNextSynchronous), force: false)
                } else {
                    let content = self.layer?.contents
                    self.displaySuspended = false
                    self.layer?.contents = content
                }
                
            }
        } else {
            self.state = .Empty
        }
    }
    
    public func setSignal(_ signal: Signal<(CGImage?, Bool), NoError>, force: Bool = true) {
        if force {
            self.state = .Empty
        }
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
            let options:NSTrackingArea.Options = [.cursorUpdate, .mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
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
