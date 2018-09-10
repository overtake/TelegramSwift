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
    private let shareControl: ImageButton = ImageButton()
    private let moreControl: ImageButton = ImageButton()
    fileprivate var interactions: GalleryInteractions?
    fileprivate var thumbs: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let thumbs = thumbs {
                addSubview(thumbs)
                thumbs.center()
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
        photoView.setFrameSize(40, 40)
        addSubview(photoView)
        addSubview(shareControl)
        addSubview(moreControl)
        photoView.userInteractionEnabled = false
        shareControl.autohighlight = false
        moreControl.autohighlight = false
        
        let shareIcon = NSImage(cgImage: theme.icons.galleryShare, size: theme.icons.galleryShare.backingSize).precomposed(NSColor.white.withAlphaComponent(0.7))
        let moreIcon = NSImage(cgImage: theme.icons.galleryMore, size: theme.icons.galleryMore.backingSize).precomposed(NSColor.white.withAlphaComponent(0.7))

        shareControl.set(image: shareIcon, for: .Normal)
        moreControl.set(image: moreIcon, for: .Normal)
        
        shareControl.set(image: theme.icons.galleryShare, for: .Hover)
        moreControl.set(image: theme.icons.galleryMore, for: .Hover)
        shareControl.set(image: theme.icons.galleryShare, for: .Highlight)
        moreControl.set(image: theme.icons.galleryMore, for: .Highlight)
        
        _ = moreControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)
        _ = shareControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)
        
        shareControl.set(handler: { [weak self] control in
            _ = self?.interactions?.share(control)
        }, for: .Click)
        
        moreControl.set(handler: { [weak self] control in
            _ = self?.interactions?.showActions(control)
        }, for: .Click)
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        if let currentState = currentState {
            if NSPointInRect(point, photoView.frame) || NSPointInRect(point, nameRect), let peerId = currentState.peer?.id {
                interactions?.openInfo(peerId)
            } else if NSPointInRect(point, dateRect) {
                interactions?.openMessage()
            } else if let thumbs = thumbs, !NSPointInRect(point, thumbs.frame) {
                _ = interactions?.dismiss()
            }
        }
        
    }
    
    private var nameRect: NSRect {
        if let nameNode = nameNode {
            return NSMakeRect(photoView.frame.maxX + 10, photoView.frame.midY - nameNode.0.size.height - 2, nameNode.0.size.width, nameNode.0.size.height)
        }
        return NSZeroRect
    }
    private var dateRect: NSRect {
        if let dateNode = dateNode {
            return NSMakeRect(photoView.frame.maxX + 10, photoView.frame.midY + 2, dateNode.0.size.width, dateNode.0.size.height)
        }
        return NSZeroRect
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let nameNode = nameNode {
            nameNode.1.draw(NSMakeRect(photoView.frame.maxX + 10, photoView.frame.midY - nameNode.0.size.height - 2, nameNode.0.size.width, nameNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
        }
        if let dateNode = dateNode {
            dateNode.1.draw(NSMakeRect(photoView.frame.maxX + 10, photoView.frame.midY + 2, dateNode.0.size.width, dateNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
        }
    }
    
    func updatePeer(_ peer: Peer?, timestamp: TimeInterval, account: Account, canShare: Bool) {
        currentState = (peer, timestamp, account)
        shareControl.isHidden = !canShare
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
        guard let window = window else {return}
        
        let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if let currentState = currentState {
            photoView.setPeer(account: currentState.account, peer: currentState.peer)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
            formatter.timeZone = NSTimeZone.local
            nameNode = TextNode.layoutText(.initialize(string: currentState.peer?.displayTitle ?? L10n.peerDeletedUser, color: NSPointInRect(point, nameRect) ? .white : .grayText, font: .medium(14)), nil, 1, .end, NSMakeSize(frame.width, 20), nil, false, .left)
            dateNode = TextNode.layoutText(.initialize(string: currentState.timestamp == 0 ? "" : formatter.string(from: Date(timeIntervalSince1970: currentState.timestamp)), color: NSPointInRect(point, dateRect) ? .white : .grayText, font: .normal(13)), nil, 1, .end, NSMakeSize(frame.width, 20), nil, false, .left)
        }
        
        photoView._change(opacity: NSPointInRect(point, photoView.frame) ? 1 : 0.7, animated: false)

        needsDisplay = true
    }
    
    fileprivate var isInside: Bool = false {
        didSet {
            updateInterface()
        }
    }
    
    func updateVisibility() {
        isInside = mouseInside()
    }
    
    override func layout() {
        super.layout()
        photoView.centerY(x: 80)
        
        moreControl.centerY(x: frame.width - moreControl.frame.width - 80)
        shareControl.centerY(x: moreControl.frame.minX - shareControl.frame.width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


class GalleryModernControls: GenericViewController<GalleryModernControlsView> {
    private let account: Account
    private let interactions: GalleryInteractions
    private let thumbs: GalleryThumbsControl
    private let peerDisposable = MetaDisposable()
    init(_ account: Account, interactions: GalleryInteractions, frame: NSRect, thumbsControl: GalleryThumbsControl) {
        self.account = account
        self.interactions = interactions
        thumbs = thumbsControl
        super.init(frame: frame)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.thumbs = thumbs.view
        genericView.interactions = interactions
    }
    
    deinit {
        peerDisposable.dispose()
    }
    
    
    func update(_ entry: GalleryEntry?) {
        if let entry = entry {
            if let interfaceState = entry.interfaceState {
                peerDisposable.set((account.postbox.loadedPeerWithId(interfaceState.0) |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let `self` = self else {return}
                    self.genericView.updatePeer(peer, timestamp: interfaceState.1 == 0 ? 0 : interfaceState.1 - self.account.context.timeDifference, account: self.account, canShare: entry.canShare)
                }))
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
