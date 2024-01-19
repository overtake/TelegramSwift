//
//  ChatInvoiceItem.swift
//  Telegram
//
//  Created by keepcoder on 19/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit
import CurrencyFormat
import AppKit

class ChatInvoiceItem: ChatRowItem {
    fileprivate let media:TelegramMediaInvoice
    fileprivate let textLayout:TextViewLayout
    fileprivate var arguments:TransformImageArguments?
    fileprivate let paymentText:String?
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        let message = object.message!
        
        let isIncoming: Bool = message.isIncoming(context.account, object.renderType == .bubble)
        let media = message.media[0] as! TelegramMediaInvoice
        self.media = media
        let attr = NSMutableAttributedString()
        
        var paymentText: String?
        outer: for attribute in message.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                for row in attribute.rows {
                    for button in row.buttons {
                        if case .payment = button.action {
                            paymentText = button.title
                            break outer
                        }
                    }
                }
                break
            }
        }
        self.paymentText = paymentText
        
        if let _ = media.extendedMedia {
            
        } else {
            _ = attr.append(string: media.title, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
            _ = attr.append(string: "\n")
            
            if media.receiptMessageId != nil {
                var title = strings().checkoutReceiptTitle.uppercased()
                if media.flags.contains(.isTest) {
                    title += " (Test)"
                }
                _ = attr.append(string: title, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
            } else {
                _ = attr.append(string: formatCurrencyAmount(media.totalAmount, currency: media.currency), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                
                _ = attr.append(string: " ")

                var title = strings().messageInvoiceLabel.uppercased()
                if media.flags.contains(.isTest) {
                    title += " (Test)"
                }
                _ = attr.append(string: title, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
            }
            
            _ = attr.append(string: "\n")
        }
        
        _ = attr.append(string: media.description, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text))
        attr.detectLinks(type: [.Links], context: chatInteraction.context, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble))
        
        textLayout = TextViewLayout(attr)
        textLayout.interactions = globalLinkExecutor
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        
    }
    
    func pay() {
        if let message = self.message {
            let keyboard = self.chatInteraction.processBotKeyboard(with: message)
            
            outer: for attribute in message.attributes {
                if let attribute = attribute as? ReplyMarkupMessageAttribute {
                    for row in attribute.rows {
                        for button in row.buttons {
                            if case .payment = button.action {
                                keyboard.proccess(button, { _ in
                                    
                                })
                                break outer
                            }
                        }
                    }
                    break
                }
            }
            
        }
    }
    
    override var isBubbleFullFilled: Bool {
        
        if let extended = media.extendedMedia {
            switch extended {
            case .preview:
                return true
            case .full:
                break
            }
        }
        
        if let _ = media.photo {
            return true
        } else {
            return super.isBubbleFullFilled
        }
    }
    
    var mediaBubbleCornerInset: CGFloat {
        return 1
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        //
        if hasBubble {
            if  forwardNameLayout != nil {
                offset.y += defaultContentInnerInset
            } else if !isBubbleFullFilled  {
                offset.y += (defaultContentInnerInset + 2)
            }
        }

        if hasBubble && authorText == nil && replyModel == nil && forwardNameLayout == nil {
            offset.y -= (defaultContentInnerInset + self.mediaBubbleCornerInset * 2 - (isBubbleFullFilled ? 1 : 0))
        }
        return offset
    }
    
    override var elementsContentInset: CGFloat {
        if hasBubble && isBubbleFullFilled {
            return bubbleContentInset
        }
        return super.elementsContentInset
    }
    
    override var realContentSize: NSSize {
        var size = super.realContentSize
        
        if isBubbleFullFilled {
            size.width -= bubbleContentInset * 2
        }
        return size
    }
    
    override var isForceRightLine: Bool {
        if let line = textLayout.lines.last, line.frame.width > realContentSize.width - (rightSize.width + insetBetweenContentAndDate ) {
            return true
        }
        return super.isForceRightLine
    }
    
    
    override var bubbleFrame: NSRect {
        var frame = super.bubbleFrame
        
        if isBubbleFullFilled {
            frame.size.width = contentSize.width + additionBubbleInset
            if hasBubble {
                frame.size.width += self.mediaBubbleCornerInset * 2
            }
        }
        
        return frame
    }
    
    override var defaultContentTopOffset: CGFloat {
        if isBubbled && !hasBubble {
            return 2
        }
        return isBubbled && !isBubbleFullFilled ? 14 :  super.defaultContentTopOffset
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {

        var contentSize = NSMakeSize(width, 0)
        var topLeftRadius: CGFloat = .cornerRadius
        let bottomLeftRadius: CGFloat = .cornerRadius
        var topRightRadius: CGFloat = .cornerRadius
        let bottomRightRadius: CGFloat = .cornerRadius
        if isBubbled {
            if !hasHeader {
                topLeftRadius = topLeftRadius * 3 + 2
                topRightRadius = topRightRadius * 3 + 2
            }
        }
        let corners = ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius))
        
        if let extended = media.extendedMedia {
            switch extended {
            case .preview(let dimensions, _, _):
                if let dimensions = dimensions {
                    contentSize = dimensions.size.aspectFitted(NSMakeSize(width, 300))
                    self.arguments = TransformImageArguments(corners: corners, imageSize: dimensions.size, boundingSize: contentSize, intrinsicInsets: NSEdgeInsets())
                }
            case .full:
                break
            }
        } else if let photo = media.photo {
            
            for attr in photo.attributes {
                switch attr {
                case let .ImageSize(size):
                    contentSize = size.size.aspectFitted(NSMakeSize(width, 200))
                    self.arguments = TransformImageArguments(corners: corners, imageSize: size.size, boundingSize: contentSize, intrinsicInsets: NSEdgeInsets())
                default:
                    break
                }
            }
        }
        
        var maxWidth: CGFloat = contentSize.width
        if hasBubble {
            maxWidth -= bubbleDefaultInnerInset
        }
        textLayout.measure(width: maxWidth)
        if arguments == nil {
            contentSize.width = textLayout.layoutSize.width
        } else {
            contentSize.height += defaultContentTopOffset
        }
        contentSize.height += textLayout.layoutSize.height
        
        return contentSize
    }
    
    override func viewClass() -> AnyClass {
        return ChatInvoiceView.self
    }
}


private class MediaDustView: View {
    private var currentParams: (size: CGSize, color: NSColor)?
    private var animColor: CGColor?
        
    private var emitter: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?
    private let maskLayer = SimpleShapeLayer()
        
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.initialize()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initialize() {
        
        let emitter = CAEmitterCell()
        emitter.color = NSColor(rgb: 0xffffff, alpha: 0.0).cgColor
        emitter.contents = NSImage(named: "textSpeckle_Normal")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        emitter.contentsScale = 1.8
        emitter.emissionRange = .pi * 2.0
        emitter.lifetime = 8.0
        emitter.scale = 0.5
        emitter.velocityRange = 0.0
        emitter.name = "dustCell"
        emitter.alphaRange = 1.0
        emitter.setValue("point", forKey: "particleType")
        emitter.setValue(1.0, forKey: "mass")
        emitter.setValue(0.01, forKey: "massRange")
        self.emitter = emitter
        
        let alphaBehavior = createEmitterBehavior(type: "valueOverLife")
        alphaBehavior.setValue("color.alpha", forKey: "keyPath")
        alphaBehavior.setValue([0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1, 0, 0, 1, 0, -1], forKey: "values")
        alphaBehavior.setValue(true, forKey: "additive")
        
        let scaleBehavior = createEmitterBehavior(type: "valueOverLife")
        scaleBehavior.setValue("scale", forKey: "keyPath")
        scaleBehavior.setValue([0.0, 0.5], forKey: "values")
        scaleBehavior.setValue([0.0, 0.05], forKey: "locations")
                
        let behaviors = [alphaBehavior, scaleBehavior]
    
        let emitterLayer = CAEmitterLayer()
        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [emitter]
        emitterLayer.seed = arc4random()
        emitterLayer.emitterShape = .rectangle
        emitterLayer.setValue(behaviors, forKey: "emitterBehaviors")
                
        self.emitterLayer = emitterLayer
        
        emitterLayer.mask = maskLayer
        maskLayer.fillRule = .evenOdd
        self.layer?.addSublayer(emitterLayer)
        
        self.updateEmitter()
    }
        
    private func updateEmitter() {
        guard let (size, _) = self.currentParams else {
            return
        }
        self.maskLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer?.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer?.emitterSize = size
        self.emitterLayer?.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        let square = Float(size.width * size.height)
        Queue.mainQueue().async {
            self.emitter?.birthRate = min(100000.0, square * 0.016)
        }
    }
    
    public func update(size: CGSize, color: NSColor, mask: CGPath) {
        self.currentParams = (size, color)
        self.updateEmitter()
        self.maskLayer.path = mask
    }
}


class ChatInvoiceView : ChatRowView {
    
    
    private class ExtendedMediaView: View {
        
        class Button : Control {
            private let textView = TextView()
            private let imageView = ImageView()
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(self.textView)
                addSubview(imageView)
                imageView.image = theme.icons.extend_content_lock
                imageView.sizeToFit()
                self.textView.userInteractionEnabled = false
                textView.isSelectable = false
                self.scaleOnClick = true
                self.backgroundColor = NSColor(rgb: 0x000000, alpha: 0.3)
                self.layer?.cornerRadius = frameRect.height / 2
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func layout() {
                super.layout()
                self.imageView.centerY(x: 10)
                self.textView.centerY(x: self.imageView.frame.maxX)
            }
            
            func update(_ text: String) -> NSSize {
                let layout = TextViewLayout(.initialize(string: text, color: .white, font: .medium(.text)))
                layout.measure(width: .greatestFiniteMagnitude)
                self.textView.update(layout)
                return NSMakeSize(layout.layoutSize.width + 20 + imageView.frame.width, frame.height)
            }
        }
        
        private let imageView = TransformImageView()
        private let dustView: MediaDustView
        private let maskLayer = SimpleShapeLayer()
        private let button = Button(frame: NSMakeRect(0, 0, 80, 32))
        
        var callback:(()->Void)? = nil
        
        required init(frame frameRect: NSRect) {
            self.dustView = MediaDustView(frame: frameRect.size.bounds)
            super.init(frame: frameRect)
            addSubview(imageView)
            addSubview(dustView)
            addSubview(button)
            
            button.set(handler: { [weak self] _ in
                self?.callback?()
            }, for: .Click)
        }
        
        override func layout() {
            super.layout()
            imageView.frame = bounds
            dustView.frame = bounds
            maskLayer.frame = bounds
            button.center()
        }
        
        private func buttonPath(_ basic: CGPath) -> CGPath {
            let buttonPath = CGMutablePath()

            buttonPath.addPath(basic)
            
                  
            buttonPath.addRoundedRect(in: self.button.frame, cornerWidth: button.frame.height / 2, cornerHeight: button.frame.height / 2)
                        
            return buttonPath
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ media: TelegramExtendedMedia, arguments: TransformImageArguments, item: ChatInvoiceItem) {
            
            switch media {
            case let .preview(_, immediateThumbnailData, _):
                let photo = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [], immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                self.imageView.setSignal(chatMessagePhoto(account: item.context.account, imageReference: .standalone(media: photo), scale: System.backingScale))
                self.imageView.set(arguments: arguments)
            case .full:
                break
            }
            
            let size = self.button.update(item.paymentText ?? "")
            self.button.setFrameSize(size)
            
            let path = CGMutablePath()
            
            let minx:CGFloat = 0, midx = arguments.boundingSize.width/2.0, maxx = arguments.boundingSize.width
            let miny:CGFloat = 0, midy = arguments.boundingSize.height/2.0, maxy = arguments.boundingSize.height
            
            path.move(to: NSMakePoint(minx, midy))
            
            let topLeftRadius: CGFloat = arguments.corners.bottomLeft.corner
            let bottomLeftRadius: CGFloat = arguments.corners.topLeft.corner
            let topRightRadius: CGFloat = arguments.corners.bottomRight.corner
            let bottomRightRadius: CGFloat = arguments.corners.topRight.corner
            
            path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
            path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
            path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
            path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
            
            maskLayer.frame = bounds
            maskLayer.path = path
            layer?.mask = maskLayer
            
            self.layout()
            self.dustView.update(size: frame.size, color: .white, mask: buttonPath(path))

        }
    }
    
    let textView:TextView = TextView()
    private var imageView:TransformImageView?
    private var extendedMedia: ExtendedMediaView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    override func contentFrame(_ item: ChatRowItem) -> NSRect {
        var rect = super.contentFrame(item)
        guard let item = item as? ChatInvoiceItem else {
            return rect
        }
        if item.isBubbled, item.isBubbleFullFilled {
            rect.origin.x -= item.bubbleContentInset
            if item.hasBubble {
                rect.origin.x += item.mediaBubbleCornerInset
            }
        }
        return rect
    }
    
    override var selectableTextViews: [TextView] {
        return [textView]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ChatInvoiceItem {
            let topView = self.extendedMedia ?? self.imageView
            if let topView = topView {
                self.textView.setFrameOrigin(NSMakePoint(item.elementsContentInset, topView.frame.maxY + item.defaultContentInnerInset))
            } else {
                self.textView.setFrameOrigin(NSMakePoint(item.elementsContentInset, 0))
            }
        }
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatInvoiceItem {
            
            self.textView.update(item.textLayout)
            
            if let media = item.media.extendedMedia, let arguments = item.arguments {
                let current: ExtendedMediaView
                if let view = self.extendedMedia {
                    current = view
                } else {
                    current = ExtendedMediaView(frame: arguments.boundingSize.bounds)
                    self.extendedMedia = current
                    addSubview(current)
                }
                current.callback = { [weak item] in
                    item?.pay()
                }
                current.setFrameSize(arguments.boundingSize)
                current.update(media, arguments: arguments, item: item)
            } else if let view = self.extendedMedia {
                performSubviewRemoval(view, animated: animated)
                self.extendedMedia = nil
            }
            
            if let photo = item.media.photo, item.media.extendedMedia == nil, let arguments = item.arguments, let message = item.message {
                let current: TransformImageView
                if let view = self.imageView {
                    current = view
                } else {
                    current = TransformImageView()
                    self.imageView = current
                    addSubview(current)
                }
                current.setSignal(chatMessageWebFilePhoto(account: item.context.account, photo: photo, scale: backingScaleFactor))
                current.set(arguments: arguments)
                current.setFrameSize(arguments.boundingSize)
                
                _ = fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, userLocation: .peer(message.id.peerId), userContentType: .image, reference: MediaResourceReference.media(media: AnyMediaReference.message(message: MessageReference(message), media: photo), resource: photo.resource)).start()
                
            } else if let view = self.imageView {
                performSubviewRemoval(view, animated: animated)
                self.imageView = nil
            }
        }
        needsLayout = true
    }
}

