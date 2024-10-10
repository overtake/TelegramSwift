//
//  ChatAccessoryModel.swift
//  Telegram
//
//  Created by keepcoder on 01/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import ColorPalette

class ChatAccessoryView : Button {
    var imageView: TransformImageView?
    let headerView = TextView()
    var textView: TextView?
    
    private var shimmerEffect: ShimmerView?
    private var shimmerMask: SimpleLayer?

    private var patternContentLayers: [SimpleLayer] = []
    private var patternTarget: InlineStickerItemLayer?
    
    private var text_inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]
    private var header_inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]

    
    private weak var model: ChatAccessoryModel?
    
    private let backgroundView = SimpleLayer()
    
    private var quoteView: ImageView?
    
    private let borderLayer = DashLayer()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initialize()
    }
    
    private func initialize() {
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        addSubview(headerView)
                
        self.layer?.addSublayer(backgroundView)
        self.layer?.addSublayer(borderLayer)
        
    }
    
    override init() {
        super.init(frame: .zero)
        initialize()
    }
    
    override func layout() {
        super.layout()
        if let model = model {
            updateModel(model, animated: false)
        }
    }
    
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        
        guard let model = model else {
            return
        }
        
        
        
        let x: CGFloat = model.leftInset// + (model.isSideAccessory ? 10 : 0)

        let headerRect = CGRect(origin: NSMakePoint(x + model.mediaInset,  model.topOffset + 2), size: headerView.frame.size)
        transition.updateFrame(view: headerView, frame: headerRect)
        
        if let textView = textView {
            let textRect = CGRect(origin: NSMakePoint(x, headerRect.height + model.topOffset + 2), size: textView.frame.size)
            transition.updateFrame(view: textView, frame: textRect)
            if let view = shimmerEffect {
                let rect = CGRect(origin: textRect.origin, size: view.frame.size)
                transition.updateFrame(view: view, frame: rect.offsetBy(dx: -5, dy: -1))
            }
        }
        
        if let quoteView = quoteView {
            transition.updateFrame(view: quoteView, frame: NSMakeRect(size.width - quoteView.frame.width - 2, 2, quoteView.frame.width, quoteView.frame.height))
        }
        transition.updateFrame(layer: backgroundView, frame: size.bounds)
                
    }
    
    func updateModel(_ model: ChatAccessoryModel, animated: Bool) {
        self.model = model
        
        var cornerRadius: CGFloat = 0
        if model.modelType == .modern {
            cornerRadius = .cornerRadius
        } else {
            if model.isSideAccessory {
                cornerRadius = .cornerRadius
            }
        }
        borderLayer.colors = model.presentation.colors

        borderLayer.opacity = model.drawLine ? 1 : 0
        self.layer?.cornerRadius = cornerRadius
       
        
        if model.drawLine {
            
            var x: CGFloat = 0
            var y: CGFloat = 0
            var width: CGFloat = 2
            var height: CGFloat = model.size.height
            var cornerRadius: CGFloat = 0
            switch model.modelType {
            case .modern:
                width = 3
                x = 0
                height = model.size.height
            case .classic:
                x = 0
                y = model.topOffset
                height = model.size.height - model.topOffset
                cornerRadius = width / 2
            }
            
            let borderRect = NSMakeRect(x, y, width, height)
            borderLayer.frame = borderRect
            borderLayer.cornerRadius = cornerRadius
        }
                
        headerView.update(model.header)
        
        if let view = self.textView {
            view.update(model.message)
        } else {
            if let view = self.textView {
                performSubviewRemoval(view, animated: animated)
            }
            let previous = self.textView != nil
            let current: TextView = TextView()
            current.update(model.message)
            current.userInteractionEnabled = false
            current.isSelectable = false
            addSubview(current)
            self.textView = current
            self.updateLayout(self.frame.size, transition: .immediate)
            if animated, previous {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        }
     
        if let message = model.message, let view = self.textView {
            updateInlineStickers(context: model.context, view: view, textLayout: message, itemViews: &text_inlineStickerItemViews)
        }
        
        if let textLayout = model.header {
            updateInlineStickers(context: model.context, view: self.headerView, textLayout: textLayout, itemViews: &header_inlineStickerItemViews)
        }
        
        if let blockImage = model.shimm.1 {
            let size = blockImage.size
            let current: ShimmerView
            if let view = self.shimmerEffect {
                current = view
            } else {
                current = ShimmerView()
                self.shimmerEffect = current
                self.addSubview(current, positioned: .above, relativeTo: textView)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(backgroundColor: .blackTransparent, data: nil, size: size, imageSize: size)
            current.updateAbsoluteRect(size.bounds, within: size)
            
            current.frame = blockImage.backingSize.bounds
            
            if shimmerMask == nil {
                shimmerMask = SimpleLayer()
            }
            var fr = CATransform3DIdentity
            fr = CATransform3DTranslate(fr, blockImage.backingSize.width / 2, 0, 0)
            fr = CATransform3DScale(fr, 1, -1, 1)
            fr = CATransform3DTranslate(fr, -(blockImage.backingSize.width / 2), 0, 0)
            
            shimmerMask?.transform = fr
            shimmerMask?.contentsScale = 2.0
            shimmerMask?.contents = blockImage
            shimmerMask?.frame = CGRect(origin: .zero, size: blockImage.backingSize)
            current.layer?.mask = shimmerMask
        } else {
            if let view = self.shimmerEffect {
                let shimmerMask = self.shimmerMask
                performSubviewRemoval(view, animated: animated, completed: { [weak shimmerMask] _ in
                    shimmerMask?.removeFromSuperlayer()
                })
                self.shimmerEffect = nil
                self.shimmerMask = nil
            }
        }
        
        if let quote = model.quoteIcon {
            let current: ImageView
            if let view = self.quoteView {
                current = view
            } else {
                current = ImageView()
                addSubview(current)
                self.quoteView = current
            }
            current.image = quote
            current.sizeToFit()
            
        } else if let view = self.quoteView {
            performSubviewRemoval(view, animated: animated)
            self.quoteView = nil
        }
        
        if let pattern = model.presentation.pattern {
            if patternTarget?.textColor != model.presentation.colors.main || patternTarget?.fileId != pattern {
                patternTarget = .init(account: model.context.account, inlinePacksContext: model.context.inlinePacksContext, emoji: .init(fileId: pattern, file: nil, emoji: ""), size: NSMakeSize(64, 64), playPolicy: .framesCount(1), textColor: model.presentation.colors.main)
                patternTarget?.noDelayBeforeplay = true
                patternTarget?.isPlayable = true
            }
            patternTarget?.contentDidUpdate = { [weak self] content in
                self?.updatePatternLayerImages()
            }
        } else {
            patternTarget = nil
            self.updatePatternLayerImages()
        }
        
        if model.presentation.pattern != nil {
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
                    self.layer?.addSublayer(patternContentLayer)
                    self.patternContentLayers.append(patternContentLayer)
                }
                patternContentLayer.layerTintColor = model.presentation.colors.main.cgColor
               // patternContentLayer.contents = patternTarget?.contents // self.patternContentsTarget?.contents
                
                let itemSize = CGSize(width: placement.size / 3.0, height: placement.size / 3.0)
                patternContentLayer.frame = CGRect(origin: CGPoint(x: model.size.width - placement.position.x / 3.0 - itemSize.width * 0.5, y: placement.position.y / 3.0 - itemSize.height * 0.5), size: itemSize)
                
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
        
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        updateLayout(frame.size, transition: transition)
        
        self.updateListeners()
        
        self.updateTheme()

    }
    
    private func updatePatternLayerImages() {
        let image = self.patternTarget?.contents
        if image == nil {
            var bp = 0
            bp += 1
        }
        for patternContentLayer in self.patternContentLayers {
            patternContentLayer.contents = image
        }
    }

    
    func updateTheme() {
        if let model = model {
            switch model.modelType {
            case .modern:
                self.backgroundView.backgroundColor = model.presentation.colors.main.withAlphaComponent(0.1).cgColor
            case .classic:
                self.backgroundView.backgroundColor = model.presentation.background.cgColor
            }
            if model.isSideAccessory {
                self.backgroundColor = model.presentation.background
            } else {
                self.backgroundColor = .clear
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
    
    
    
    @objc func updateAnimatableContent() -> Void {
        for (_, value) in text_inlineStickerItemViews {
            if let superview = value.superview {
                value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow && !isLite
            }
        }
        for (_, value) in header_inlineStickerItemViews {
            if let superview = value.superview {
                value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow && !isLite
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
    
    private var isLite: Bool = false
    
    func updateInlineStickers(context: AccountContext, view textView: TextView, textLayout: TextViewLayout, itemViews: inout [InlineStickerItemLayer.Key: InlineStickerItemLayer]) {
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = textView.hashValue
        self.isLite = context.isLite(.emoji)
        
        let textColor: NSColor
        if textLayout.attributedString.length > 0 {
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = textLayout.attributedString.attributes(at: max(0, textLayout.attributedString.length - 1), effectiveRange: &range)
            textColor = attrs[.foregroundColor] as? NSColor ?? theme.colors.text
        } else {
            textColor = theme.colors.text
        }

        for item in textLayout.embeddedItems {
            if let stickerItem = item.value as? InlineStickerItem, case let .attribute(emoji) = stickerItem.source {
                
                let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index, color: textColor)
                validIds.append(id)
                
                let rect = item.rect.insetBy(dx: 0, dy: 0)
                
                let view: InlineStickerItemLayer
                if let current = itemViews[id], current.frame.size == rect.size && current.textColor == id.color {
                    view = current
                } else {
                    itemViews[id]?.removeFromSuperlayer()
                    view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, textColor: textColor)
                    itemViews[id] = view
                    view.superview = textView
                    textView.addEmbeddedLayer(view)
                }
                index += 1
                
                view.frame = rect
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ChatAccessoryPresentation {
    let background: NSColor
    let colors: PeerNameColors.Colors
    let enabledText: NSColor
    let disabledText: NSColor
    let quoteIcon: CGImage
    let pattern: Int64?
    let app: TelegramPresentationTheme
    func withUpdatedBackground(_ backgroundColor: NSColor) -> ChatAccessoryPresentation {
        return ChatAccessoryPresentation(background: backgroundColor, colors: self.colors, enabledText: self.enabledText, disabledText: self.disabledText, quoteIcon: self.quoteIcon, pattern: self.pattern, app: self.app)
    }
}

class ChatAccessoryModel: NSObject {
    
    enum ModelType {
        case modern
        case classic
    }
    
    var modelType: ModelType {
        return .modern
    }
    
    var quoteIcon: CGImage? {
        return nil
    }
    
    
    public let nodeReady = Promise<Bool>()
    
    public var shimm: (NSPoint, CGImage?) {
        return (.zero, nil)
    }
    
    var updateImageSignal: Signal<ImageDataTransformation, NoError>?

    var updatedMedia: Media? {
        return nil
    }
    
    var cutout: TextViewCutout? {
        let cutoutSize: NSSize?
        if updatedMedia != nil {
            cutoutSize = .init(width: 36, height: 18)
        } else {
            cutoutSize = nil
        }
        return .init(topLeft: cutoutSize)
    }
    
    open var backgroundColor:NSColor {
        didSet {
            self.presentation = presentation.withUpdatedBackground(backgroundColor)
        }
    }
    
    var isSideAccessory: Bool = false
    
    private var _presentation: ChatAccessoryPresentation? = nil
    var presentation: ChatAccessoryPresentation {
        set {
            _presentation = newValue
            self.view?.updateTheme()
        }
        get {
            return _presentation ?? ChatAccessoryPresentation(background: theme.colors.background, colors: .init(main: theme.colors.accent), enabledText: theme.colors.text, disabledText: theme.colors.grayText, quoteIcon: theme.icons.message_quote_accent, pattern: nil, app: theme)
        }
    }
    
    private let _strongView:ChatAccessoryView?
    open weak var view:ChatAccessoryView? {
        didSet {
            if let view = view {
                view.imageView?.removeFromSuperview()
                view.imageView = nil
                view.updateModel(self, animated: self.animates)
            }
        }
    }
    
    var animates: Bool = false
    
    open var size:NSSize = NSZeroSize
    let drawLine: Bool
    var width: CGFloat = 0
    var sizeToFit: Bool = false
    open var frame:NSRect {
        get {
            return self.view?.frame ?? NSZeroRect
        }
        set {
            self.view?.frame = newValue
        }
    }
    
    deinit {
        if _strongView != nil {
            assertOnMainThread()
        }
    }
    
    let context: AccountContext
    
    public init(context: AccountContext, view:ChatAccessoryView? = nil, presentation: ChatAccessoryPresentation? = nil, drawLine: Bool = true) {
        _strongView = view
        self.context = context
        self.drawLine = drawLine
        _presentation = presentation
        if view != nil {
            assertOnMainThread()
        }
        backgroundColor = theme.colors.background
        super.init()
        self.view = view
        
    }
    
    
    open func setNeedDisplay() -> Void {
        if let view = view {
            view.updateModel(self, animated: false)
        }
    }
    
    public func removeFromSuperview() -> Void {
        self.view?.removeFromSuperview()
    }
    
    
    open var viewClass:AnyClass {
        return View.self
    }
    
    
    let yInset:CGFloat = 2
    var leftInset:CGFloat {
        return drawLine ? 8 : 8
    }
    
    var mediaInset: CGFloat {
        return 0
    }
    var mediaTopInset: CGFloat {
        return 4
    }
    
    var rightInset:CGFloat {
        return 6
    }
    
    var header:TextViewLayout?
    var message:TextViewLayout?
    
    var topOffset: CGFloat = 0
    
    
    func measureSize(_ width:CGFloat = 0, sizeToFit: Bool = false) -> Void {
        self.sizeToFit = sizeToFit
        
        header?.measure(width: width - leftInset - rightInset - (quoteIcon != nil ? 12 : 0) - mediaInset)
        
        var addition: CGFloat = 0
        if cutout != nil, !isSideAccessory {
            addition = mediaInset
        }
//        if addition != 0 {
//            addition -= 6
//        }
        message?.measure(width: width - leftInset - rightInset - addition)
        
        
        if let header = header, let message = message {
            var model_w = max(header.layoutSize.width + mediaInset, message.layoutSize.width) + leftInset + rightInset
            if quoteIcon != nil {
                model_w += 12
            }
            let width = sizeToFit ? model_w : width
            let height = max(38, header.layoutSize.height + message.layoutSize.height + yInset * 2)
            self.size = NSMakeSize(width, height)
            self.size.height += topOffset
        } else {
            self.size = NSMakeSize(width, 36)
        }
        self.width = width
    }
    

}
