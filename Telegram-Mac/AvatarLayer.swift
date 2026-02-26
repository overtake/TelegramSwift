//
//  AvatarControl.swift
//  Telegram-Mac
//
//  Created by keepcoder on 15/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
import TGUIKit
import SwiftSignalKit


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
    case PeerAvatar(Peer, [String], TelegramMediaImageRepresentation?, PeerNameColor?, Message?, NSSize?, Bool, CGFloat?)
    case ArchivedChats
}

func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
    case (.Empty, .Empty):
        return true
    case let (.PeerAvatar(lhsPeer, lhsLetters, lhsPhotoRepresentations, lhsPeerNameColor, _, lhsSize, lhsForum, lhsCornerRadius), .PeerAvatar(rhsPeer, rhsLetters, rhsPhotoRepresentations, rhsPeerNameColor, _, rhsSize, rhsForum, rhsCornerRadius)):
        return lhsPeer.isEqual(rhsPeer) && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations && lhsSize == rhsSize && lhsForum == rhsForum && lhsPeerNameColor == rhsPeerNameColor && lhsCornerRadius == rhsCornerRadius
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
    private var disableForum: Bool = false
    private var contentScale: CGFloat = 0
    
    var contentUpdated: ((Any?)->Void)?
    
    func callContentUpdater() {
        self.contentUpdated?(self.imageContents)
    }
    
    var imageContents: Any? {
        didSet {
            self.layer?.contents = imageContents
            self.contentUpdated?(imageContents)
        }
    }
    
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
    
    public func setPeer(account: Account, peer: Peer?, message: Message? = nil, size: NSSize? = nil, disableForum: Bool = false, cornerRadius: CGFloat? = nil, forceMonoforum: Bool = false) {
        self.account = account
        self.disableForum = disableForum
        let state: AvatarNodeState
        if let peer = peer {
            state = .PeerAvatar(peer, peer.displayLetters, peer.smallProfileImage, peer.nameColor, message, size, (peer.isForumOrMonoForum && !disableForum) || forceMonoforum, cornerRadius)
        } else {
            state = .Empty
        }
        if self.state != state || self.imageContents == nil {
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
        layer?.contentsGravity = .resizeAspectFill
        
        if let account = account, self.state != .Empty {
            if contentScale != backingScaleFactor {
                contentScale = backingScaleFactor
                self.displaySuspended = true
                self.imageContents = nil
                let photo: PeerPhoto?
                var updatedSize: NSSize = self.frame.size
                
                let _disableForum: Bool
                
                switch state {
                case let .PeerAvatar(peer, letters, representation, nameColor, message, size, isForum, cornerRadius):
                    _disableForum = !isForum
                    if let peer = peer as? TelegramUser, peer.firstName == nil && peer.lastName == nil {
                        photo = nil
                        self.setState(account: account, state: .Empty)
                        let icon = theme.icons.deletedAccount
                        self.setSignal(generateEmptyPhoto(updatedSize, type: .icon(colors: theme.colors.peerColors(Int(peer.id.id._internalGetInt64Value() % 7)), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(min(50, updatedSize.width - 20), min(updatedSize.height - 20, 50))), cornerRadius: nil), bubble: peer.isMonoForum) |> map {($0, false)})
                        return
                    } else {
                        photo = .peer(peer, representation, nameColor, letters, message, cornerRadius)
                    }
                    updatedSize = size ?? frame.size
                case .Empty:
                    photo = nil
                    _disableForum = disableForum
                default:
                    photo = nil
                    _disableForum = disableForum
                }
                if let photo = photo {
                    setSignal(peerAvatarImage(account: account, photo: photo, displayDimensions: updatedSize, scale:backingScaleFactor, font: self.font, synchronousLoad: attemptLoadNextSynchronous, disableForum: _disableForum), force: false)
                } else {
                    let content = self.imageContents
                    self.displaySuspended = false
                    self.imageContents = content
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
                strongSelf.imageContents = image
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
        view.layer?.contents = self.imageContents
        view.layer?.masksToBounds = true
        view.frame = self.visibleRect
        view.layer?.shouldRasterize = true
        view.layer?.rasterizationScale = backingScaleFactor
        return view
    }
}
