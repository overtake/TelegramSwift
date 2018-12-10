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
    
    private let zoomInControl: ImageButton = ImageButton()
    private let zoomOutControl: ImageButton = ImageButton()
    private let rotateControl: ImageButton = ImageButton()
    private let fastSaveControl: ImageButton = ImageButton()
    
    fileprivate var interactions: GalleryInteractions?
    fileprivate var thumbs: GalleryThumbsControlView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let thumbs = thumbs {
                addSubview(thumbs)
                thumbs.setFrameOrigin(NSMakePoint((self.frame.width - thumbs.frame.width) / 2 + (thumbs.frame.width - thumbs.documentSize.width) / 2, (self.frame.height - thumbs.frame.height) / 2))
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
        let fastSaveIcon = NSImage(cgImage: theme.icons.galleryFastSave, size: theme.icons.galleryFastSave.backingSize).precomposed(NSColor.white.withAlphaComponent(0.7))

        
        shareControl.set(image: shareIcon, for: .Normal)
        moreControl.set(image: moreIcon, for: .Normal)
        fastSaveControl.set(image: fastSaveIcon, for: .Normal)

        
        shareControl.set(image: theme.icons.galleryShare, for: .Hover)
        moreControl.set(image: theme.icons.galleryMore, for: .Hover)
        shareControl.set(image: theme.icons.galleryShare, for: .Highlight)
        moreControl.set(image: theme.icons.galleryMore, for: .Highlight)
        fastSaveControl.set(image: theme.icons.galleryFastSave, for: .Highlight)
        
        _ = moreControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)
        _ = shareControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)
        
        addSubview(fastSaveControl)
        addSubview(zoomInControl)
        addSubview(zoomOutControl)
        addSubview(rotateControl)
        
        let zoomIn = NSImage(cgImage: theme.icons.galleryZoomIn, size: theme.icons.galleryZoomIn.backingSize).precomposed(NSColor.white.withAlphaComponent(0.7))
        let zoomOut = NSImage(cgImage: theme.icons.galleryZoomOut, size: theme.icons.galleryZoomOut.backingSize).precomposed(NSColor.white.withAlphaComponent(0.7))
        let rotate = NSImage(cgImage: theme.icons.galleryRotate, size: theme.icons.galleryRotate.backingSize).precomposed(NSColor.white.withAlphaComponent(0.7))

        
        zoomInControl.set(image: zoomIn, for: .Normal)
        zoomOutControl.set(image: zoomOut, for: .Normal)
        rotateControl.set(image: rotate, for: .Normal)
        
        zoomInControl.set(image: theme.icons.galleryZoomIn, for: .Hover)
        zoomOutControl.set(image: theme.icons.galleryZoomOut, for: .Hover)
        rotateControl.set(image: theme.icons.galleryRotate, for: .Hover)
        
        zoomInControl.set(image: theme.icons.galleryZoomIn, for: .Highlight)
        zoomOutControl.set(image: theme.icons.galleryZoomOut, for: .Highlight)
        rotateControl.set(image: theme.icons.galleryRotate, for: .Highlight)

        
        _ = zoomInControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)
        _ = zoomOutControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)
        _ = rotateControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)
        _ = fastSaveControl.sizeToFit(NSZeroSize, NSMakeSize(60, 60), thatFit: true)

        shareControl.set(handler: { [weak self] control in
            _ = self?.interactions?.share(control)
        }, for: .Click)
        
        moreControl.set(handler: { [weak self] control in
            _ = self?.interactions?.showActions(control)
        }, for: .Click)
        
        rotateControl.set(handler: { [weak self] _ in
            self?.interactions?.rotateLeft()
        }, for: .Click)
        
        zoomInControl.set(handler: { [weak self] _ in
            self?.interactions?.zoomIn()
        }, for: .Click)
        
        zoomOutControl.set(handler: { [weak self] _ in
            self?.interactions?.zoomOut()
        }, for: .Click)
        
        fastSaveControl.set(handler: { [weak self] _ in
            self?.interactions?.fastSave()
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
    
    func updateControlsVisible(_ entry: GalleryEntry) {
        switch entry {
       
        case let .instantMedia(media, _):
            if media.media is TelegramMediaImage {
                zoomInControl.isHidden = false
                zoomOutControl.isHidden = false
                rotateControl.isHidden = false
                fastSaveControl.isHidden = false
            } else if let file = media.media as? TelegramMediaFile {
                if file.isVideo {
                    zoomInControl.isHidden = true
                    zoomOutControl.isHidden = true
                    rotateControl.isHidden = true
                    fastSaveControl.isHidden = false
                }
            }
        case let .message(message):
            if message.message?.media.first is TelegramMediaImage {
                zoomInControl.isHidden = false
                zoomOutControl.isHidden = false
                rotateControl.isHidden = false
                fastSaveControl.isHidden = false
            } else if let file = message.message?.media.first as? TelegramMediaFile {
                if file.isVideo {
                    zoomInControl.isHidden = true
                    zoomOutControl.isHidden = true
                    rotateControl.isHidden = true
                    fastSaveControl.isHidden = false
                }
            } else if let webpage = message.message?.media.first as? TelegramMediaWebpage {
                if case let .Loaded(content) = webpage.content {
                    if ExternalVideoLoader.isPlayable(content) {
                        zoomInControl.isHidden = false
                        zoomOutControl.isHidden = false
                        rotateControl.isHidden = true
                        fastSaveControl.isHidden = true
                    }
                }
            } else {
                zoomInControl.isHidden = true
                zoomOutControl.isHidden = true
                rotateControl.isHidden = true
                fastSaveControl.isHidden = true
            }
        default:
            zoomInControl.isHidden = false
            zoomOutControl.isHidden = false
            rotateControl.isHidden = false
            fastSaveControl.isHidden = false
        }
    }
    
    func updatePeer(_ peer: Peer?, timestamp: TimeInterval, account: Account, canShare: Bool) {
        currentState = (peer, timestamp, account)
        shareControl.isHidden = !canShare
        needsLayout = true
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
        if frame.minY >= 0 {
            isInside = mouseInside()
        }
    }
    
    override func layout() {
        super.layout()
        photoView.centerY(x: 80)
        
        moreControl.centerY(x: frame.width - moreControl.frame.width - 80)
        shareControl.centerY(x: moreControl.frame.minX - shareControl.frame.width)
        
        let alignControl = shareControl.isHidden ? moreControl : shareControl
        fastSaveControl.centerY(x: alignControl.frame.minX - fastSaveControl.frame.width)
        rotateControl.centerY(x: (fastSaveControl.isHidden ? alignControl.frame.minX : fastSaveControl.frame.minX) - rotateControl.frame.width - 60)
        zoomInControl.centerY(x: (rotateControl.isHidden ? alignControl.frame.minX - 60 : rotateControl.frame.minX) - zoomInControl.frame.width)
        zoomOutControl.centerY(x: zoomInControl.frame.minX - zoomOutControl.frame.width)
        
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
        genericView.thumbs = thumbs.genericView
        genericView.interactions = interactions
        
        thumbs.afterLayoutTransition = { [weak self] animated in
            guard let `self` = self else { return }
            self.thumbs.genericView.change(pos: NSMakePoint((self.frame.width - self.thumbs.frame.width) / 2 + (self.thumbs.frame.width - self.thumbs.genericView.documentSize.width) / 2, (self.frame.height - self.thumbs.frame.height) / 2), animated: animated)
        }
    }
    
    deinit {
        peerDisposable.dispose()
    }
    
    
    func update(_ entry: GalleryEntry?) {
        if let entry = entry {
            if let interfaceState = entry.interfaceState {
                self.genericView.updateControlsVisible(entry)
                peerDisposable.set((account.postbox.loadedPeerWithId(interfaceState.0) |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let `self` = self else {return}
                    self.genericView.updatePeer(peer, timestamp: interfaceState.1 == 0 ? 0 : interfaceState.1 - self.account.context.timeDifference, account: self.account, canShare: entry.canShare)
                }))
            }
        }
    }
    
    
    
    
    func animateIn() {
        genericView.change(pos: NSMakePoint(0, 0), animated: true, timingFunction: CAMediaTimingFunctionName.spring)
    }
    
    func animateOut() {
        genericView.change(pos: NSMakePoint(0, -frame.height), animated: true, timingFunction: CAMediaTimingFunctionName.spring)
    }
}
