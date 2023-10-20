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

class ChatAccessoryView : Button {
    var imageView: TransformImageView?
    let headerView = TextView()
    var textView: TextView?
    
    private var shimmerEffect: ShimmerView?
    private var shimmerMask: SimpleLayer?

    
    private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]

    
    private weak var model: ChatAccessoryModel?
    
    private var quoteView: ImageView?
    
    private let borderLayer = SimpleShapeLayer()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initialize()
    }
    
    private func initialize() {
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        addSubview(headerView)
                
       
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
        
        
        
        let x: CGFloat = model.leftInset + (model.isSideAccessory ? 10 : 0)

        let headerRect = CGRect(origin: NSMakePoint(x + model.mediaInset, (model.isSideAccessory ? 5 : 0) + model.topOffset + 2), size: headerView.frame.size)
        transition.updateFrame(view: headerView, frame: headerRect)
        
        if let textView = textView {
            let textRect = CGRect(origin: NSMakePoint(x, headerRect.height + (model.isSideAccessory ? 5 : 0) + model.topOffset + 2), size: textView.frame.size)
            transition.updateFrame(view: textView, frame: textRect)
            if let view = shimmerEffect {
                let rect = CGRect(origin: textRect.origin, size: view.frame.size)
                transition.updateFrame(view: view, frame: rect.offsetBy(dx: -5, dy: -1))
            }
        }
        
        if let quoteView = quoteView {
            transition.updateFrame(view: quoteView, frame: NSMakeRect(size.width - quoteView.frame.width - 2, 2, quoteView.frame.width, quoteView.frame.height))
        }
                
    }
    
    func updateModel(_ model: ChatAccessoryModel, animated: Bool) {
        self.model = model
        self.backgroundColor = model.presentation.background
        
        var cornerRadius: CGFloat = 0
        if model.modelType == .modern {
            cornerRadius = 3
        } else {
            if model.isSideAccessory {
                cornerRadius = .cornerRadius
            }
        }
        borderLayer.backgroundColor = PeerNameColorCache.value.get(model.presentation.title).cgColor

        borderLayer.opacity = model.drawLine ? 1 : 0
        self.layer?.cornerRadius = cornerRadius
       
        
        if model.drawLine {
            
            var x: CGFloat = 0
            var y: CGFloat = 0
            var width: CGFloat = 2
            var height: CGFloat = model.size.height //
            var cornerRadius: CGFloat = 0
            switch model.modelType {
            case .modern:
                width = 6
                x = -(width / 2)
                height = model.size.height
            case .classic:
                x = model.isSideAccessory ? 10 : 0
                y = model.isSideAccessory ? 5 : 0 + model.topOffset
                height = model.size.height - model.topOffset - (model.isSideAccessory ? 10 : 0)
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
            updateInlineStickers(context: model.context, view: view, textLayout: message)
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
    
    func updateTheme() {
        if let model = model {
            switch model.modelType {
            case .modern:
                self.backgroundColor = model.presentation.title.0.withAlphaComponent(0.1)
            case .classic:
                self.backgroundColor = model.presentation.background
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
        for (_, value) in inlineStickerItemViews {
            if let superview = value.superview {
                value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow && !isLite
            }
        }
    }
    
    private var isLite: Bool = false
    
    func updateInlineStickers(context: AccountContext, view textView: TextView, textLayout: TextViewLayout) {
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = textView.hashValue
        self.isLite = context.isLite(.emoji)
        
        let textColor: NSColor
        if textLayout.attributedString.length > 0 {
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = textLayout.attributedString.attributes(at: 0, effectiveRange: &range)
            textColor = attrs[.foregroundColor] as? NSColor ?? theme.colors.text
        } else {
            textColor = theme.colors.text
        }

        for item in textLayout.embeddedItems {
            if let stickerItem = item.value as? InlineStickerItem, case let .attribute(emoji) = stickerItem.source {
                
                let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index)
                validIds.append(id)
                
                let rect = item.rect.insetBy(dx: -2, dy: -2)
                
                let view: InlineStickerItemLayer
                if let current = self.inlineStickerItemViews[id], current.frame.size == rect.size {
                    view = current
                } else {
                    self.inlineStickerItemViews[id]?.removeFromSuperlayer()
                    view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, textColor: textColor)
                    self.inlineStickerItemViews[id] = view
                    view.superview = textView
                    textView.addEmbeddedLayer(view)
                }
                index += 1
                
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ChatAccessoryPresentation {
    let background: NSColor
    let title: (NSColor, NSColor?)
    let enabledText: NSColor
    let disabledText: NSColor
    let quoteIcon: CGImage
    let app: TelegramPresentationTheme
    func withUpdatedBackground(_ backgroundColor: NSColor) -> ChatAccessoryPresentation {
        return ChatAccessoryPresentation(background: backgroundColor, title: self.title, enabledText: self.enabledText, disabledText: self.disabledText, quoteIcon: self.quoteIcon, app: self.app)
    }
}

class ChatAccessoryModel: NSObject {
    
    enum ModelType {
        case modern
        case classic
    }
    
    var modelType: ModelType {
        if isSideAccessory {
            return .classic
        }
        
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
            return _presentation ?? ChatAccessoryPresentation(background: theme.colors.background, title: (theme.colors.accent, nil), enabledText: theme.colors.text, disabledText: theme.colors.grayText, quoteIcon: theme.icons.message_quote_accent, app: theme)
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
        
        header?.measure(width: width - leftInset - rightInset - (quoteIcon != nil ? 12 : 0))
        message?.measure(width: width - leftInset - rightInset)
        
        if let header = header, let message = message {
            var model_w = max(header.layoutSize.width + mediaInset, message.layoutSize.width) + leftInset + rightInset
            if isSideAccessory {
                model_w += 20
            }
            if quoteIcon != nil {
                model_w += 12
            }
            let width = sizeToFit ? model_w : width
            let height = max(38, header.layoutSize.height + message.layoutSize.height + yInset * 2 + (isSideAccessory ? 10 : 0))
            self.size = NSMakeSize(width, height)
            self.size.height += topOffset
        } else {
            self.size = NSMakeSize(width, 36)
        }
        self.width = width
    }
    

}
