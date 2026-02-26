//
//  InteractiveTextView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore

final class InteractiveTextView : Control {
    let textView = TextView()
    private var context: AccountContext?
    
    var isLite: Bool = false
    private var decreaseAvatar: CGFloat = 0
    
    private var inlineStickerItemViews: [InlineStickerItemLayer.Key: SimpleLayer] = [:]
    
    private var visualEffect: VisualEffect? = nil    
    
    var hasBackground: Bool {
        return blurBackground != nil
    }
    
    public var blurBackground: NSColor? = nil {
        didSet {
            updateBackgroundBlur()
            if hasBackground {
                self.backgroundColor = .clear
            }
        }
    }
    
    convenience override init() {
        self.init(frame: .zero)
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        layer?.masksToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(text: TextViewLayout?, context: AccountContext?, insetEmoji: CGFloat = 0, decreaseAvatar: CGFloat = 0) {
        self.decreaseAvatar = decreaseAvatar
        self.textView.update(text)
        self.context = context
        if let text {
            self.setFrameSize(text.layoutSize)
        }
        if let context, let text {
            self.isLite = context.isLite(.emoji)
            self.updateInlineStickers(context: context, textLayout: text, itemViews: &inlineStickerItemViews, insetEmoji: insetEmoji)
        }
    }
    
    func resize(_ width: CGFloat) {
        self.textView.textLayout?.measure(width: width)
        self.set(text: self.textView.textLayout, context: self.context)
    }

    
    func updateInlineStickers(context: AccountContext, textLayout: TextViewLayout, itemViews: inout [InlineStickerItemLayer.Key: SimpleLayer], insetEmoji: CGFloat) {
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = self.textView.hashValue
        
        let textColor: NSColor
        if textLayout.attributedString.length > 0 {
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = textLayout.attributedString.attributes(at: max(0, textLayout.attributedString.length - 1), effectiveRange: &range)
            textColor = attrs[.foregroundColor] as? NSColor ?? theme.colors.text
        } else {
            textColor = theme.colors.text
        }

        for item in textLayout.embeddedItems {
            if let stickerItem = item.value as? InlineStickerItem, item.rect.width > 10 {
                if case let .attribute(emoji) = stickerItem.source {
                    
                    let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index, color: emoji.color ?? textColor)
                    validIds.append(id)
                    
                    let rect = item.rect.insetBy(dx: insetEmoji, dy: insetEmoji)
                    
                    let view: InlineStickerItemLayer
                    if let current = itemViews[id] as? InlineStickerItemLayer, current.frame.size == rect.size && current.textColor == id.color {
                        view = current
                    } else {
                        itemViews[id]?.removeFromSuperlayer()
                        view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, playPolicy: stickerItem.playPolicy ?? .loop, textColor: textColor)
                        itemViews[id] = view
                        view.superview = textView
                        textView.addEmbeddedLayer(view)
                    }
                    index += 1
                    
                    view.frame = rect
                } else if case let .avatar(peer) = stickerItem.source {
                    let id = InlineStickerItemLayer.Key(id: peer.id.toInt64(), index: index)
                    validIds.append(id)
                    let rect = NSMakeRect(item.rect.minX, item.rect.minY + 3, item.rect.width - 3 - decreaseAvatar, item.rect.width - 3 - decreaseAvatar)
                   
                    let view: InlineAvatarLayer
                    if let current = itemViews[id] as? InlineAvatarLayer {
                        view = current
                    } else {
                        itemViews[id]?.removeFromSuperlayer()
                        view = InlineAvatarLayer(context: context, frame: rect, peer: peer)
                        itemViews[id] = view
                        textView.addEmbeddedLayer(view)
                    }
                    index += 1
                    view.frame = rect
               }
                
            }
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in itemViews {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            itemViews.removeValue(forKey: key)
        }
        updateAnimatableContent()
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
    
    override func layout() {
        super.layout()
        self.textView.center()
        visualEffect?.frame = bounds
    }
    
    @objc func updateAnimatableContent() -> Void {
        for (_, value) in inlineStickerItemViews {
            if let value = value as? InlineStickerItemLayer {
                if let superview = value.superview {
                    value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow && !isLite
                }
            }
        }
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
    
    private func updateBackgroundBlur() {
        
        self.layer?.masksToBounds = blurBackground != nil
        if let blurBackground = blurBackground {
            if self.visualEffect == nil {
                self.visualEffect = VisualEffect(frame: self.bounds)
                addSubview(self.visualEffect!, positioned: .below, relativeTo: nil)
            }
            self.visualEffect?.bgColor = blurBackground
            
        }  else {
            self.visualEffect?.removeFromSuperview()
            self.visualEffect = nil
        }
        
        needsLayout = true
    }
    
}
