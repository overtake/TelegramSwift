//
//  WPContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore



class WPContentView: Control, MultipleSelectable, ModalPreviewRowViewProtocol {
    
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        return nil
    }
    
    var header: String? {
        return nil
    }

    private let dashLayer = DashLayer()
    
    var textView:TextView = TextView()
    private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]

    
    private(set) var containerView:View = View()
    private(set) var content:WPLayout?
    private var action: TextButton? = nil
    
    private var closeAdView: ImageButton?

    
    var selectableTextViews: [TextView] {
        return []
    }
    
    func previewMediaIfPossible() -> Bool {
        return false
    }
    

    override func layout() {
        super.layout()
        if let content = self.content {
            containerView.frame = content.contentRect
            textView.update(content.textLayout)
            textView.isHidden = content.textLayout == nil
            if let action = action {
                _ = action.sizeToFit(NSZeroSize, NSMakeSize(content.contentRect.width, 36), thatFit: true)
                action.setFrameOrigin(0, content.contentRect.height - action.frame.height + content.imageInsets.top * 2)
            }
            if let closeAdView = closeAdView {
                closeAdView.setFrameOrigin(NSMakePoint(self.frame.width - closeAdView.frame.width - 0, 0))
            }
        }
        dashLayer.frame = NSMakeRect(0, 0, 3, frame.height)
        needsDisplay = true
    }
    
    func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return convert(point, from: nil)
    }
    
    required public override init() {
        super.init()
        
        self.isDynamicColorUpdateLocked = true
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        super.addSubview(containerView)
        self.layer?.addSublayer(dashLayer)
        addSubview(textView)
        
        
        self.scaleOnClick = true
        
        layer?.cornerRadius = .cornerRadius
        
        set(handler: { [weak self] _ in
            self?.content?.invokeAction()
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func addSubview(_ view: NSView) {
        containerView.addSubview(view)
    }
    
    deinit {
        containerView.removeAllSubviews()
    }
    
    func updateMouse() {
        
    }

    func update(with layout:WPLayout, animated: Bool) -> Void {
        self.content = layout
        
        if let text = layout.action_text {
            let current: TextButton
            if let view = self.action {
                current = view
            } else {
                current = TextButton()
                self.action = current
                current.disableActions()
                addSubview(current)
                current.userInteractionEnabled = false
                
            }

            current.border = [.Top]
            current.borderColor = layout.presentation.activity.main.withAlphaComponent(0.1)
            current.set(color: layout.presentation.activity.main, for: .Normal)
            current.set(font: .medium(.title), for: .Normal)
            current.set(background: .clear, for: .Normal)
            current.set(text: text, for: .Normal)
            _ = current.sizeToFit(NSZeroSize, NSMakeSize(layout.contentRect.width, 36), thatFit: false)
            
            current.set(color: layout.presentation.activity.main, for: .Normal)
            if layout.hasInstantPage {
                current.set(image: NSImage.init(named: "Icon_ChatIV")!.precomposed(layout.presentation.activity.main), for: .Normal)
            } else {
                current.removeImage(for: .Normal)
            }
        } else if let view = self.action {
            performSubviewRemoval(view, animated: animated)
            self.action = nil
        }
        
        if let _ = layout.parent.adAttribute {
            //
            let current: ImageButton
            if let view = self.closeAdView {
                current = view
            } else {
                current = ImageButton()
                current.autohighlight = false
                current.scaleOnClick = true
                self.closeAdView = current
                super.addSubview(current)
            }
            current.removeAllHandlers()
            current.set(handler: { [weak layout] _ in
                layout?.premiumBoarding()
            }, for: .Click)
            current.set(image: NSImage(named: "Icon_GradientClose")!.precomposed(layout.presentation.activity.main), for: .Normal)
            current.sizeToFit()
            
        } else if let view = self.closeAdView {
            performSubviewRemoval(view, animated: animated)
            self.closeAdView = nil
        }
        
        self.backgroundColor = layout.presentation.activity.main.withAlphaComponent(0.1) //color
        self.needsLayout = true
        
        self.dashLayer.colors = layout.presentation.activity
        
        if let textLayout = layout.textLayout {
            updateInlineStickers(context: layout.context, view: self.textView, textLayout: textLayout)
        }
    }
    
    func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self.containerView
    }
    
    var mediaContentView: NSView? {
        return containerView
    }
    
    @objc func updateAnimatableContent() -> Void {
        for (_, value) in inlineStickerItemViews {
            if let superview = value.superview {
                var isKeyWindow: Bool = false
                if let window = self.window {
                    if !window.canBecomeKey {
                        isKeyWindow = true
                    } else {
                        isKeyWindow = window.isKeyWindow
                    }
                }
                value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && isKeyWindow && !isEmojiLite
            }
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
    
    
    var isEmojiLite: Bool {
        if let layout = self.content {
            return layout.context.isLite(.emoji)
        }
        return false
    }
    
    func updateInlineStickers(context: AccountContext, view textView: TextView, textLayout: TextViewLayout) {
        
        guard let content = self.content else {
            return
        }
        
        let textColor = content.presentation.text
        
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = textView.hashValue
        
        for item in textLayout.embeddedItems {
            if let stickerItem = item.value as? InlineStickerItem, case let .attribute(emoji) = stickerItem.source {
                
                let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index, color: textColor)
                validIds.append(id)
                
                
                let rect: NSRect
                if textLayout.isBigEmoji {
                    rect = item.rect
                } else {
                    rect = item.rect.insetBy(dx: -2, dy: -2)
                }
                
                let view: InlineStickerItemLayer
                if let current = self.inlineStickerItemViews[id], current.frame.size == rect.size, textColor == current.textColor {
                    view = current
                } else {
                    self.inlineStickerItemViews[id]?.removeFromSuperlayer()
                    view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, textColor: textColor)
                    self.inlineStickerItemViews[id] = view
                    view.superview = textView
                    textView.addEmbeddedLayer(view)
                }
                index += 1
                var isKeyWindow: Bool = false
                if let window = window {
                    if !window.canBecomeKey {
                        isKeyWindow = true
                    } else {
                        isKeyWindow = window.isKeyWindow
                    }
                }
                view.isPlayable = NSIntersectsRect(rect, textView.visibleRect) && isKeyWindow
                view.frame = rect
            }
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in self.inlineStickerItemViews {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            self.inlineStickerItemViews.removeValue(forKey: key)
        }
        updateAnimatableContent()
    }


}
