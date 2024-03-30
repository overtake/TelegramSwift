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

    private var patternContentLayers: [SimpleLayer] = []
    private var patternTarget: InlineStickerItemLayer?

    
    private(set) var containerView:View = View()
    private(set) var content:WPLayout?
    private var action: TextButton? = nil
    
    
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
        
        if let pattern = layout.presentation.pattern {
            if patternTarget?.textColor != layout.presentation.activity.main {
                patternTarget = .init(account: layout.context.account, inlinePacksContext: layout.context.inlinePacksContext, emoji: .init(fileId: pattern, file: nil, emoji: ""), size: NSMakeSize(64, 64), playPolicy: .framesCount(1), textColor: layout.presentation.activity.main)
                patternTarget?.noDelayBeforeplay = true
                patternTarget?.isPlayable = true
                self.updatePatternLayerImages()
            }
            patternTarget?.contentDidUpdate = { [weak self] content in
                self?.updatePatternLayerImages()
            }
        } else {
            patternTarget = nil
            self.updatePatternLayerImages()
        }
        
        if layout.presentation.pattern != nil {
            var maxIndex = 0
            
            struct Placement {
                var position: CGPoint
                var size: CGFloat
                
                init(_ position: CGPoint, _ size: CGFloat) {
                    self.position = position
                    self.size = size
                }
            }
            
            let placements: [Placement] = [
                Placement(CGPoint(x: 176.0, y: 13.0), 38.0),
                Placement(CGPoint(x: 51.0, y: 45.0), 58.0),
                Placement(CGPoint(x: 349.0, y: 36.0), 58.0),
                Placement(CGPoint(x: 132.0, y: 64.0), 46.0),
                Placement(CGPoint(x: 241.0, y: 64.0), 54.0),
                Placement(CGPoint(x: 68.0, y: 121.0), 44.0),
                Placement(CGPoint(x: 178.0, y: 122.0), 47.0),
                Placement(CGPoint(x: 315.0, y: 122.0), 47.0),
            ]
            
            for placement in placements {
                let patternContentLayer: SimpleLayer
                if maxIndex < self.patternContentLayers.count {
                    patternContentLayer = self.patternContentLayers[maxIndex]
                } else {
                    patternContentLayer = SimpleLayer()
                    patternContentLayer.layerTintColor = layout.presentation.activity.main.cgColor
                    self.layer?.addSublayer(patternContentLayer)
                    self.patternContentLayers.append(patternContentLayer)
                }
               // patternContentLayer.contents = patternTarget?.contents // self.patternContentsTarget?.contents
                
                var start = NSMakePoint(layout.size.width, 0)
                
                if let article = layout as? WPArticleLayout {
                    if let arguments = article.imageArguments {
                        if !article.isFullImageSize {
                            start.x -= (arguments.boundingSize.width + 5)
                        }
                    }
                    
                }
                
                let itemSize = CGSize(width: placement.size / 3.0, height: placement.size / 3.0)
                patternContentLayer.frame = CGRect(origin: CGPoint(x: start.x - placement.position.x / 3.0 - itemSize.width * 0.5, y: start.y + placement.position.y / 3.0 - itemSize.height * 0.5), size: itemSize)
                
                var alphaFraction = abs(placement.position.x) / 400.0
                alphaFraction = min(1.0, max(0.0, alphaFraction))
                patternContentLayer.opacity = 0.3 * Float(1.0 - alphaFraction)
                
                maxIndex += 1
            }
            
            if maxIndex < self.patternContentLayers.count {
                for i in maxIndex ..< self.patternContentLayers.count {
                    self.patternContentLayers[i].removeFromSuperlayer()
                }
                self.patternContentLayers.removeSubrange(maxIndex ..< self.patternContentLayers.count)
            }
        } else {
            for patternContentLayer in self.patternContentLayers {
                patternContentLayer.removeFromSuperlayer()
            }
            self.patternContentLayers.removeAll()
        }
        
        self.backgroundColor = layout.presentation.activity.main.withAlphaComponent(0.1) //color
        self.needsLayout = true
        
        self.dashLayer.colors = layout.presentation.activity
        
        if let textLayout = layout.textLayout {
            updateInlineStickers(context: layout.context, view: self.textView, textLayout: textLayout)
        }
    }
    
    private func updatePatternLayerImages() {
        let image = self.patternTarget?.contents
        for patternContentLayer in self.patternContentLayers {
            patternContentLayer.contents = image
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
