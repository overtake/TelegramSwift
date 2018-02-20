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



enum AvatarNodeState: Equatable {
    case Empty
    case PeerAvatar(PeerId, [String], TelegramMediaImageRepresentation?)
    case GroupAvatar([Peer])

}

func ==(lhs: AvatarNodeState, rhs: AvatarNodeState) -> Bool {
    switch (lhs, rhs) {
    case (.Empty, .Empty):
        return true
    case let (.PeerAvatar(lhsPeerId, lhsLetters, lhsPhotoRepresentations), .PeerAvatar(rhsPeerId, rhsLetters, rhsPhotoRepresentations)):
        return lhsPeerId == rhsPeerId && lhsLetters == rhsLetters && lhsPhotoRepresentations == rhsPhotoRepresentations
    case let (.GroupAvatar(lhsPeers), .GroupAvatar(rhsPeers)):
        if lhsPeers.count != rhsPeers.count {
            return false
        }
        for i in 0 ..< lhsPeers.count {
            if !lhsPeers[i].isEqual(rhsPeers[i]) {
                return false
            }
        }
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
        contentScale = 0
        self.state = state
        self.viewDidChangeBackingProperties()
    }
    
    public func setPeer(account: Account, peer: Peer?) {
        self.account = account
        let state: AvatarNodeState
        if let peer = peer {
            state = .PeerAvatar(peer.id, peer.displayLetters, peer.smallProfileImage)
        } else {
            state = .Empty
        }
        self.state = state
        contentScale = 0
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
        
        
        if let account = account {
            if contentScale != backingScaleFactor {
                contentScale = backingScaleFactor
                
                self.displaySuspended = true
                self.layer?.contents = nil
                let photo: PeerPhoto?
                switch state {
                case let .PeerAvatar(peerId, letters, representation):
                    photo = .peer(peerId, representation, letters)
                case let .GroupAvatar(peers):
                    let representations: [PeerId:TelegramMediaImageRepresentation] = peers.reduce([:], { current, peer  in
                        var current = current
                        if let smallProfileImage = peer.smallProfileImage {
                            current[peer.id] = smallProfileImage
                        }
                        return current
                    })
                    let letters: [PeerId:[String]] = peers.reduce([:], { current, peer  in
                        var current = current
                        current[peer.id] = peer.displayLetters
                        return current
                    })
                    photo = .group(peers.map{$0.id}, representations, letters)
                case .Empty:
                    photo = nil
                }
                if let photo = photo {
                    setSignal(peerAvatarImage(account: account, photo: photo, displayDimensions:frame.size, scale:backingScaleFactor, font: self.font))
                } else {
                    self.displaySuspended = false
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
