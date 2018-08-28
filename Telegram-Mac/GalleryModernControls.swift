//
//  GalleryModernControls.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28/08/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class GalleryModernControlsView: View {
    
    fileprivate let photoView: AvatarControl = AvatarControl(font: .avatar(18))
    private var nameNode: (TextNodeLayout, TextNode)? = nil
    private var dateNode: (TextNodeLayout, TextNode)? = nil
    fileprivate var thumbs: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let thumbs = thumbs {
                addSubview(thumbs)
            }
            needsLayout = true
        }
    }
    private var currentState:(peer: Peer?, timestamp: TimeInterval, account: Account)? {
        didSet {
            updateInterface()
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
       // backgroundColor = .blackTransparent
        photoView.setFrameSize(60, 60)
        addSubview(photoView)
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        if NSPointInRect(point, photoView.frame) {
            // open peer
        } else if NSPointInRect(point, nameRect) {
            //open peer
        } else if NSPointInRect(point, dateRect) {
            // open message
        }
    }
    
    private var nameRect: NSRect {
        if let nameNode = nameNode {
            return NSMakeRect(photoView.frame.maxX + 20, photoView.frame.midY - nameNode.0.size.height - 2, nameNode.0.size.width, nameNode.0.size.height)
        }
        return NSZeroRect
    }
    private var dateRect: NSRect {
        if let dateNode = dateNode {
            return NSMakeRect(photoView.frame.maxX + 20, photoView.frame.midY, dateNode.0.size.width + 2, dateNode.0.size.height)
        }
        return NSZeroRect
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let nameNode = nameNode {
            nameNode.1.draw(NSMakeRect(photoView.frame.maxX + 20, photoView.frame.midY - nameNode.0.size.height - 2, nameNode.0.size.width, nameNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
        }
        if let dateNode = dateNode {
            dateNode.1.draw(NSMakeRect(photoView.frame.maxX + 20, photoView.frame.midY, dateNode.0.size.width + 2, dateNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
        }
    }
    
    func updatePeer(_ peer: Peer?, timestamp: TimeInterval, account: Account) {
        currentState = (peer, timestamp, account)
       
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        
        if let window = newWindow as? Window {
            window.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
                self?.updateVisibility()
                return .rejected
            }, with: self, for: .mouseMoved)
        } else {
            (self.window as? Window)?.remove(object: self, for: .mouseMoved)
        }
    }
    
    private func updateInterface() {
        if let currentState = currentState {
            photoView.setPeer(account: currentState.account, peer: currentState.peer)
            nameNode = TextNode.layoutText(.initialize(string: currentState.peer?.displayTitle ?? L10n.peerDeletedUser, color: isInside ? .white : .grayText, font: .medium(16)), nil, 1, .end, NSMakeSize(frame.width, 20), nil, false, .left)
            dateNode = TextNode.layoutText(.initialize(string: DateUtils.string(forLastSeen: Int32(currentState.timestamp)), color: isInside ? .white : .grayText, font: .medium(16)), nil, 1, .end, NSMakeSize(frame.width, 20), nil, false, .left)
        }
        photoView._change(opacity: self.isInside ? 1 : 0.7, animated: false)
        needsDisplay = true
    }
    
    fileprivate var isInside: Bool = false {
        didSet {
            if isInside != oldValue {
                updateInterface()
            }
        }
    }
    
    func updateVisibility() {
        isInside = mouseInside()
    }
    
    override func layout() {
        super.layout()
        photoView.centerY(x: 100)
        thumbs?.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


class GalleryModernControls: GenericViewController<GalleryModernControlsView> {
    private let account: Account
    private let interactions: GalleryInteractions
    private let thumbs: GalleryThumbsControl
    init(_ account: Account, interactions: GalleryInteractions, frame: NSRect, thumbsControl: GalleryThumbsControl) {
        self.account = account
        self.interactions = interactions
        thumbs = thumbsControl
        super.init(frame: frame)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.thumbs = thumbs.view
    }
    
    
    
    func update(_ entry: GalleryEntry?) {
        if let entry = entry {
            switch entry {
            case let .message(entry):
                genericView.updatePeer(entry.message!.chatPeer, timestamp: TimeInterval(entry.message!.timestamp) - account.context.timeDifference, account: self.account)
            default:
                break
            }
        }
    }
    
    
    
    
    func animateIn() {
        genericView.change(pos: NSMakePoint(0, 0), animated: true, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut() {
        genericView.change(pos: NSMakePoint(0, -frame.height), animated: true, timingFunction: kCAMediaTimingFunctionSpring)
    }
}
