//
//  PremiumStatusControl.swift
//  Telegram
//
//  Created by Mike Renoir on 09.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import QuartzCore

final class PremiumStatusControl : Control {
    private var imageLayer: SimpleLayer?
    private var animateLayer: InlineStickerItemLayer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func set(_ peer: Peer, account: Account, inlinePacksContext: InlineStickersContext?, isSelected: Bool, isBig: Bool, animated: Bool) {
        
        
        
        if let size = PremiumStatusControl.controlSize(peer, isBig) {
            setFrameSize(size)
        }

        if peer.isFake || peer.isScam || peer.isVerified || (peer.isPremium && peer.emojiStatus == nil)  {
            if let animateLayer = animateLayer {
                performSublayerRemoval(animateLayer, animated: animated)
                self.animateLayer = nil
            }
            let current: SimpleLayer
            if let layer = self.imageLayer {
                current = layer
            } else {
                current = SimpleLayer()
                self.imageLayer = current
                self.layer?.addSublayer(current)
            }
            let image: CGImage?
            if peer.isVerified {
                image = isSelected ? theme.icons.verifyDialogActive : theme.icons.verifyDialog
            } else if peer.isScam {
                image = isSelected ? theme.icons.scamActive : theme.icons.scam
            } else if peer.isFake {
                image = isSelected ? theme.icons.fakeActive : theme.icons.fake
            } else if peer.isPremium {
                if isBig {
                    image = isSelected ? theme.icons.premium_account_active : theme.icons.premium_account
                } else {
                    image = isSelected ? theme.icons.premium_account_small_active : theme.icons.premium_account_small
                }
            } else {
                image = nil
            }
            if let image = image {
                current.contents = image
                current.frame = focus(image.systemSize)
            } else {
                current.contents = nil
            }
        } else if let status = peer.emojiStatus {
            if let imageLayer = imageLayer {
                performSublayerRemoval(imageLayer, animated: animated, scale: true)
                self.imageLayer = nil
            }
            let fileId: Int64 = status.fileId
            let current: InlineStickerItemLayer
            if let layer = self.animateLayer, layer.file?.fileId.id == fileId {
                current = layer
            } else {
                if let animateLayer = animateLayer {
                    performSublayerRemoval(animateLayer, animated: animated, scale: true)
                    self.animateLayer = nil
                }
                current = InlineStickerItemLayer(account: account, inlinePacksContext: inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: frame.size)
                current.superview = self
                self.animateLayer = current
                self.layer?.addSublayer(current)
                
                if animated {
                    current.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.animateScale(from: 0.1, to: 1, duration: 0.2)
                }
            }
        }
        self.updateAnimatableContent()
        self.updateListeners()
    }
    
    
    @objc func updateAnimatableContent() -> Void {
        if let layer = self.animateLayer, let superview = layer.superview {
            var isKeyWindow: Bool = false
            if let window = window {
                if !window.canBecomeKey {
                    isKeyWindow = true
                } else {
                    isKeyWindow = window.isKeyWindow
                }
            }
            layer.isPlayable = NSIntersectsRect(layer.frame, superview.visibleRect) && isKeyWindow
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateListeners() {
        let center = NotificationCenter.default
        if let window = window {
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
        } else {
            center.removeObserver(self)
        }
    }
    
    static func control(_ peer: Peer, account: Account, inlinePacksContext: InlineStickersContext?, isSelected: Bool, isBig: Bool = false, cached: PremiumStatusControl?, animated: Bool, force: Bool = false) -> PremiumStatusControl? {
        var current: PremiumStatusControl? = nil
        if peer.id != account.peerId || (inlinePacksContext == nil || force) {
            if peer.isVerified || peer.isScam || peer.isFake || peer.isPremium {
                current = cached ?? PremiumStatusControl(frame: .zero)
            }
        }
        current?.set(peer, account: account, inlinePacksContext: inlinePacksContext, isSelected: isSelected, isBig: isBig, animated: animated)
        return current
    }
    
    static func hasControl(_ peer: Peer) -> Bool {
        return peer.isVerified || peer.isScam || peer.isFake || peer.isPremium
    }
    static func controlSize(_ peer: Peer, _ isBig: Bool) -> NSSize? {
        if hasControl(peer) {
            return isBig ? NSMakeSize(20, 20) : NSMakeSize(16, 16)
        } else {
            return nil
        }
    }
}
