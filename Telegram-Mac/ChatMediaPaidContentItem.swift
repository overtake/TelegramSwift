//
//  ChatMediaPaidContentItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit
import InAppSettings

private enum Item {
    struct Full {
        let arguments: TransformImageArguments
        let media: Media
        let viewType: ChatMediaContentView.Type
        let position: LayoutPositionFlags
        let rect: NSRect
    }
    struct Preview {
        let arguments: TransformImageArguments
        let image: TelegramMediaImage
        let rect: NSRect
    }
    case full(Full)
    case preview(Preview)
}

private struct PaidData {
    let items: [Item]
    let size: NSSize
}


private func makePreviewItem(media: TelegramExtendedMedia, rect: CGRect, position: LayoutPositionFlags) -> Item {
    
    var topLeftRadius: CGFloat = .cornerRadius
    var bottomLeftRadius: CGFloat = .cornerRadius
    var topRightRadius: CGFloat = .cornerRadius
    var bottomRightRadius: CGFloat = .cornerRadius
    
    
    if position.contains(.top) && position.contains(.left) {
        topLeftRadius = topLeftRadius * 3 + 2
    }
    if position.contains(.top) && position.contains(.right) {
        topRightRadius = topRightRadius * 3 + 2
    }
    if position.contains(.bottom) && position.contains(.left) {
        bottomLeftRadius = bottomLeftRadius * 3 + 2
    }
    if position.contains(.bottom) && position.contains(.right) {
        bottomRightRadius = bottomRightRadius * 3 + 2
    }
    
    let corners = ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius))

    switch media {
    case let .preview(dimensions, immediateThumbnailData, videoDuration):
        let arguments = TransformImageArguments(corners: corners, imageSize: dimensions?.size ?? rect.size, boundingSize: rect.size, intrinsicInsets: NSEdgeInsets())
        return .preview(Item.Preview(arguments: arguments, image: .init(imageId: .init(namespace: 0, id: 0), representations: [], immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: []), rect: rect))
    case let .full(media):
        
        var size: NSSize
        if let media = media as? TelegramMediaImage {
            size = media.representationForDisplayAtSize(.init(width: 1280, height: 1280))?.dimensions.size ?? rect.size
        } else if let file = media as? TelegramMediaFile {
            size = file.dimensions?.size ?? rect.size
        } else {
            size = rect.size
        }
        
        let arguments = TransformImageArguments(corners: corners, imageSize: size, boundingSize: rect.size, intrinsicInsets: NSEdgeInsets())

        return .full(Item.Full(arguments: arguments, media: media, viewType: ChatLayoutUtils.contentNode(for: media), position: position, rect: rect))
    }
    
}



final class ChatMediaPaidContentItem : ChatRowItem {
    fileprivate let media: TelegramMediaPaidContent
    fileprivate var data: PaidData!
    fileprivate let isPreview: Bool
    
    fileprivate let groupedLayout: GroupedLayout?
    
    fileprivate let unlockText: TextViewLayout?
    
    fileprivate var parameters:[ChatMediaLayoutParameters] = []
    fileprivate let badgeLayout: TextViewLayout?
    
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        let message = object.message!
        self.media = message.media[0] as! TelegramMediaPaidContent
        
        switch media.extendedMedia[0] {
        case .preview:
            self.isPreview = true
        case .full:
            self.isPreview = false
        }
        
        if !isPreview {
            let text = NSMutableAttributedString()
            if messageMainPeer(.init(message))?._asPeer().isAdmin == true {
                text.append(string: "\(clown) \(media.amount)", color: NSColor(0xffffff), font: .normal(.text))
                text.insertEmbedded(.embedded(name: XTR_ICON, color: NSColor(0xffffff), resize: false), for: clown)
            } else {
                text.append(string: strings().paidMediaStatusPurchased, color: NSColor(0xffffff), font: .normal(.text))
            }
            self.badgeLayout = .init(text)
            self.badgeLayout?.measure(width: .greatestFiniteMagnitude)
        } else {
            self.badgeLayout = nil
        }
        
        if isPreview {
            let attr = NSMutableAttributedString()
            attr.append(string: strings().paidMediaUnlockForCountable(Int(media.amount)), color: .white, font: .medium(.text))
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file), for: "#")
            
            let textLayout = TextViewLayout(attr)
            textLayout.measure(width: .greatestFiniteMagnitude)
            self.unlockText = textLayout
        } else {
            unlockText = nil
        }
        
        let maxSize = NSMakeSize(320, 320)

        if media.extendedMedia.count > 1 {
            let messages: [Message] = media.extendedMedia.enumerated().map { (i, value) in
                let media: Media
                switch value {
                case let .preview(dimensions, immediateThumbnailData, _):
                    media = TelegramMediaImage(dimension: dimensions ?? .init(maxSize), immediateThumbnailData: immediateThumbnailData) 
                case let .full(_media):
                    media = _media
                }
                return .init(media, stableId: 0, messageId: .init(peerId: context.peerId, namespace: 0, id: MessageId.Id(i)))
            }
            self.groupedLayout = GroupedLayout(messages, type: .photoOrVideo)
        } else {
            self.groupedLayout = nil
        }
        
        super.init(initialSize, chatInteraction, context, object, theme: theme)
        
        
        let isIncoming = self.isIncoming
        
        var text: String = message.text
        var entities: [MessageTextEntity] = message.textEntities?.entities ?? []
        var isLoading: Bool = false
        if let translate = object.additionalData.translate {
            switch translate {
            case .loading:
                isLoading = true
            case let .complete(toLang):
                if let attribute = message.translationAttribute(toLang: toLang) {
                    text = attribute.text
                    entities = attribute.entities
                }
            }
        }
       
        if !text.isEmpty {
            
            var caption:NSMutableAttributedString = NSMutableAttributedString()
            _ = caption.append(string: text, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(theme.fontSize))
                        
            caption = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities)], for: text, message: message, context: context, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.hashtag, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, object.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, object.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), openBank: chatInteraction.openBank, blockColor: theme.chat.blockColor(context.peerNameColors, message: message, isIncoming: message.isIncoming(context.account, entry.renderType == .bubble), bubbled: entry.renderType == .bubble), isDark: theme.colors.isDark, bubbled: entry.renderType == .bubble, codeSyntaxData: entry.additionalData.codeSyntaxData, loadCodeSyntax: chatInteraction.enqueueCodeSyntax, openPhoneNumber: chatInteraction.openPhoneNumberContextMenu).mutableCopy() as! NSMutableAttributedString
            
            caption.removeWhitespaceFromQuoteAttribute()
            
            
            InlineStickerItem.apply(to: caption, associatedMedia: message.associatedMedia, entities: entities, isPremium: context.isPremium)
            
            let spoilerColor: NSColor
            if entry.renderType == .bubble {
                spoilerColor = theme.chat.grayText(isIncoming, entry.renderType == .bubble)
            } else {
                spoilerColor = theme.chat.textColor(isIncoming, entry.renderType == .bubble)
            }
            let isSpoilerRevealed = chatInteraction.presentation.interfaceState.revealedSpoilers.contains(message.id)
            
            let textLayout = FoldingTextLayout.make(caption, context: context, revealed: object.additionalData.quoteRevealed, takeLayout: { string in
                let textLayout = TextViewLayout(string, alignment: .left, selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), strokeLinks: object.renderType == .bubble, alwaysStaticItems: true, disableTooltips: false, mayItems: !message.isCopyProtected(), spoilerColor: spoilerColor, isSpoilerRevealed: isSpoilerRevealed, onSpoilerReveal: { [weak chatInteraction] in
                    chatInteraction?.update({
                        $0.updatedInterfaceState({
                            $0.withRevealedSpoiler(message.id)
                        })
                    })
                })
                
                if let highlightFoundText = object.additionalData.highlightFoundText {
                   if let range = rangeOfSearch(highlightFoundText.query, in: caption.string) {
                       textLayout.additionalSelections = [TextSelectedRange(range: range, color: theme.colors.accentIcon.withAlphaComponent(0.5), def: false)]
                   }
                }
                return textLayout
            })
            
            captionLayouts.append(.init(message: message, id: message.stableId, offset: CGPoint(x: 0, y: 0), layout: textLayout, isLoading: isLoading, contentInset: ChatRowItem.defaultContentInnerInset))
            captionLayouts[0].layout.applyRanges(selectManager.findAll(entry.stableId))
            
            let interactions = globalLinkExecutor
            
            interactions.copyToClipboard = { text in
                copyToClipboard(text)
                showModalText(for: context.window, text: strings().shareLinkCopied)
            }
            interactions.topWindow = { [weak self] in
                return self?.menuAdditionView ?? .single(nil)
            }
            if let layout = self.captionLayouts.first {
                interactions.menuItems = { [weak self, weak layout] type in
                    if let interactions = self?.chatInteraction, let entry = self?.entry, let layout {
                        return chatMenuItems(for: layout.message, entry: entry, textLayout: (layout.layout.merged, type), chatInteraction: interactions)
                    }
                    return .complete()
                }
            }
            
            for textLayout in self.captionLayouts.map ({ $0.layout }) {
                textLayout.set(interactions)
            }
        }
        
        if !isPreview {
            
            let medias = media.extendedMedia.compactMap {
                switch $0 {
                case let .full(media):
                    return media
                default:
                    return nil
                }
            }
            
            for i in 0 ..< media.extendedMedia.count {
                let parameters = ChatMediaGalleryParameters(showMedia: { [weak self] message in
                    showPaidMedia(context: context, medias: medias, parent: message, firstIndex: i, firstStableId: ChatHistoryEntryId.mediaId(i, message), self?.table, self?.parameters[i])
                }, showMessage: { [weak self] message in
                    self?.chatInteraction.focusMessageId(nil, .init(messageId: message.id, string: nil), .CenterEmpty)
                }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: context.account, renderType: entry.renderType, theme: theme), media: message.anyMedia!, automaticDownload: downloadSettings.isDownloable(message), autoplayMedia: entry.autoplayMedia, isRevealed: entry.isRevealed)
                
                parameters.automaticDownloadFunc = { message in
                    return object.additionalData.automaticDownload.isDownloable(message, index: i)
                }
                parameters.isProtected = true
                parameters.revealMedia = { message in
                    chatInteraction.revealMedia(message)
                }
                parameters.cancelOperation = { message, media in
                    if let media = media as? TelegramMediaFile {
                        messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, file: media)
                    } else if let media = media as? TelegramMediaImage {
                        chatMessagePhotoCancelInteractiveFetch(account: context.account, photo: media)
                    }
                }
                parameters.chatLocationInput = chatInteraction.chatLocationInput
                parameters.chatMode = chatInteraction.mode
                
                self.parameters.append(parameters)
            }
            
        }
        
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
               
        let size = ChatLayoutUtils.contentSize(for: media, with: width, hasText: message?.text.isEmpty == false || (isBubbled && commentsBubbleData != nil), groupedLayout: groupedLayout, spacing: hasBubble ? 2 : 4)
        
        var position: LayoutPositionFlags = []
        if (captionLayouts.isEmpty && commentsBubbleData == nil) || (invertMedia && commentsBubbleData == nil), factCheckLayout == nil {
            position.insert(.bottom)
            position.insert(.left)
            position.insert(.right)
        }
        if !hasUpsideSomething && !invertMedia {
            position.insert(.top)
            position.insert(.left)
            position.insert(.right)
        }
        
        let data: PaidData
        if let groupedLayout {
            var items:[Item] = []
            for i in 0 ..< groupedLayout.count {
                var position = groupedLayout.position(at: i)
                if hasBubble  {
                    if !captionLayouts.isEmpty || commentsBubbleData != nil, !invertMedia {
                        position.remove(.bottom)
                    }
                    if hasUpsideSomething || invertMedia {
                        position.remove(.top)
                    }
                }
                items.append(makePreviewItem(media: media.extendedMedia[i], rect: groupedLayout.frame(at: i), position: position))
            }
            data = .init(items: items, size: size)
            
        } else {
            let item = makePreviewItem(media: media.extendedMedia[0], rect: size.bounds, position: position)
            data = .init(items: [item], size: size)
        }
        
        self.data = data
        
        return size
    }
    
    
    override var isBubbleFullFilled: Bool {
        return isBubbled
    }
    
    var mediaBubbleCornerInset: CGFloat {
        return 1
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
        return super.defaultContentTopOffset
    }
    
    var hasUpsideSomething: Bool {
        return authorText != nil || replyModel != nil || topicLinkLayout != nil || forwardNameLayout != nil
    }
    
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        
        if hasBubble, isBubbleFullFilled, !hasUpsideSomething {
            offset.y -= (defaultContentInnerInset )
        } else if hasBubble, !isBubbleFullFilled, hasUpsideSomething {
            offset.y += defaultContentInnerInset
        } else if hasBubble, isBubbleFullFilled, hasUpsideSomething {
            offset.y += topInset
        }
        return offset
    }
    
    
    override var elementsContentInset: CGFloat {
        if hasBubble && isBubbleFullFilled {
            return bubbleContentInset
        }
        return super.elementsContentInset
    }
    
    
    
    override var _defaultHeight: CGFloat {
        if hasBubble && isBubbleFullFilled && captionLayouts.isEmpty {
            return contentOffset.y + defaultContentInnerInset - mediaBubbleCornerInset * 2 - 2
        }
        
        return super._defaultHeight
    }
    
    override var realContentSize: NSSize {
        var size = super.realContentSize
        
        if isBubbleFullFilled {
            size.width -= bubbleContentInset * 2
        }
        return size
    }
    
    
    override func viewClass() -> AnyClass {
        return ChatPaidMediaView.self
    }
    
    func buyProduct(image: TelegramMediaImage) {
        guard let messageId = message?.id else {
            return
        }
        let context = self.context
        
        let videoCount = media.extendedMedia.filter {
            switch $0 {
            case let .full(media):
                return media is TelegramMediaFile
            case let .preview(_, _, videoDuration):
                return videoDuration != nil
            }
        }.count
        let photosCount = self.data.items.count - videoCount
        
        let count = StarPurchaseType.PaidMediaCount(photoCount: photosCount, videoCount: videoCount)

        
        let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: .message(messageId)), for: context.window)

        _ = signal.startStandalone(next: { invoice in
            showModal(with: Star_PurschaseInApp(context: context, invoice: invoice, source: .message(messageId), type: .paidMedia(image, count)), for: context.window)
        })
        
    }
}

private class PreviewMediaView: Control {
    
    private let imageView = TransformImageView()
    private let dustView: MediaDustView2
    private let maskLayer = SimpleShapeLayer()
        
    
    private weak var item: ChatMediaPaidContentItem?
    private var preview: Item.Preview?
    
    required init(frame frameRect: NSRect) {
        self.dustView = MediaDustView2(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(dustView)
        
        scaleOnClick = true
        
        set(handler: { [weak self] _ in
            if let preview = self?.preview {
                self?.item?.buyProduct(image: preview.image)
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        imageView.frame = bounds
        dustView.frame = bounds
        maskLayer.frame = bounds
    }
    
    private func buttonPath(_ basic: CGPath) -> CGPath {
        let buttonPath = CGMutablePath()

        buttonPath.addPath(basic)
        
        return buttonPath
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(preview: Item.Preview, item: ChatMediaPaidContentItem, context: AccountContext) {
        
        self.item = item
        self.preview = preview
        
        let arguments = preview.arguments
        
        self.imageView.setSignal(chatMessagePhoto(account: context.account, imageReference: .standalone(media: preview.image), scale: System.backingScale))
        self.imageView.set(arguments: arguments)
        
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

private final class Button: Control {
    private let textView = InteractiveTextView()
    private let control = Control()
    private let visualEffect = NSVisualEffectView()
    private weak var item: ChatMediaPaidContentItem?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        visualEffect.wantsLayer = true
        visualEffect.material = .ultraDark
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        addSubview(visualEffect)
        
        addSubview(textView)
        
        self.scaleOnClick = true
        
        self.isDynamicColorUpdateLocked = true
        
        self.textView.userInteractionEnabled = false
        self.textView.textView.isSelectable = false
        self.layer?.cornerRadius = 15
        
        self.set(handler: { [weak self] _ in
            if let preview = self?.item?.data.items.first {
                switch preview {
                case .full:
                    break
                case .preview(let preview):
                    self?.item?.buyProduct(image: preview.image)
                }
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(textLayout: TextViewLayout, item: ChatMediaPaidContentItem, context: AccountContext) {
        self.item = item
        self.textView.set(text: textLayout, context: context)
        self.setFrameSize(NSMakeSize(textView.frame.width + 20, 30))
    }
    
    override func layout() {
        super.layout()
        self.textView.centerY(x: 10)
        visualEffect.frame = bounds
    }
}

private final class BadgeView : VisualEffect {
    fileprivate let textView = InteractiveTextView()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        

        textView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(textLayout: TextViewLayout, context: AccountContext) {
        self.textView.set(text: textLayout, context: context)
        setFrameSize(NSMakeSize(textLayout.layoutSize.width + 12, textLayout.layoutSize.height + 4))
        self.layer?.cornerRadius = frame.height / 2
    }
    
    override func layout() {
        super.layout()
        self.textView.center()
    }
}

private final class ChatPaidMediaView: ChatRowView {
    
    private var previews: [PreviewMediaView] = []
    private var contents: [ChatMediaContentView] = []
    
    private var unlockView: Button?
    private var badgeView: BadgeView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previous = self.item as? ChatMediaPaidContentItem
        
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatMediaPaidContentItem else {
            return
        }
        
        if item.isPreview {
            while !contents.isEmpty {
                performSubviewRemoval(contents.removeFirst(), animated: animated)
            }
            while previews.count > item.data.items.count {
                performSubviewRemoval(previews.removeLast(), animated: animated)
            }
            while previews.count < item.data.items.count {
                let view = PreviewMediaView(frame: .zero)
                previews.append(view)
                addSubview(view)
            }
            for (i, preview) in item.data.items.enumerated() {
                let view = previews[i]
                switch preview {
                case let .preview(preview):
                    view.frame = preview.rect
                    view.update(preview: preview, item: item, context: item.context)
                default:
                    break
                }
            }
        } else {
            while !previews.isEmpty {
                performSubviewRemoval(previews.removeFirst(), animated: animated)
            }
            
            if contents.count > item.data.items.count {
                let contentCount = contents.count
                let layoutCount = item.data.items.count
                for i in layoutCount ..< contentCount {
                    contents[i].removeFromSuperview()
                }
                contents = contents.subarray(with: NSMakeRange(0, layoutCount))
            } else if contents.count < item.data.items.count {
                let contentCount = contents.count
                for i in contentCount ..< item.data.items.count {
                    switch item.data.items[i] {
                    case let .full(item):
                        let node = item.viewType
                        let view = node.init(frame: item.rect)
                        contents.append(view)
                        addSubview(view)
                    default:
                        break
                    }
                }
            }
            for i in 0 ..< contents.count {
                switch item.data.items[i] {
                case let .full(item):
                    if contents[i].className != item.viewType.className() {
                        let node = item.viewType
                        let view = node.init(frame: item.rect)
                        contents[i].removeFromSuperview()
                        contents[i] = view
                        addSubview(view)
                    }
                default:
                    break
                }
            }
        }
        let transition: ContainedViewLayoutTransition
        if animated && previous?.isPreview == item.isPreview {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }

        for i in 0 ..< contents.count {
            switch item.data.items[i] {
            case let .full(full):
                contents[i].update(with: full.media, size: full.rect.size, context: item.context, parent: item.message, table: item.table, parameters: item.parameters[i], animated: transition.isAnimated, positionFlags: full.position, approximateSynchronousValue: false)
                transition.updateFrame(view: contents[i], frame: full.rect)
                contents[i].updateLayout(size: full.rect.size, transition: transition)
            default:
                break
            }
        }
        
        if let textLayout = item.unlockText {
            let unlock: Button
            if let view = self.unlockView {
                unlock = view
            } else {
                unlock = Button(frame: contentView.focus(NSMakeSize(textLayout.layoutSize.width + 20, 30)))
                self.unlockView = unlock
            }
            self.addSubview(unlock)
            unlock.update(textLayout: textLayout, item: item, context: item.context)
        } else {
            if let view = self.unlockView {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.unlockView = nil
            }
        }
        
        if let layout = item.badgeLayout {
            let current: BadgeView
            if let view = self.badgeView {
                current = view
            } else {
                current = .init(frame: .zero)
                self.badgeView = current
            }
            current.update(textLayout: layout, context: item.context)
            current.setFrameOrigin(NSMakePoint(item.contentSize.width - current.frame.width - 5, 5))
            addSubview(current)
            
            current.bgColor = item.presentation.blurServiceColor


        } else if let view = self.badgeView {
            performSubviewRemoval(view, animated: animated)
            self.badgeView = nil
        }
    }
    
    override func contentFrame(_ item: ChatRowItem) -> NSRect {
        var rect = super.contentFrame(item)
        guard let item = item as? ChatMediaPaidContentItem else {
            return rect
        }
        if item.isBubbled, item.isBubbleFullFilled {
            rect.origin.x -= item.bubbleContentInset
            if item.hasBubble {
                rect.origin.x += item.mediaBubbleCornerInset
            }
        }
        if item.invertMedia {
            if let layout = item.captionLayouts.last {
                rect.origin.y += layout.invertedSize
            }
        }
        return rect
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        if let unlockView {
            transition.updateFrame(view: unlockView, frame: unlockView.centerFrame())
        }
    }
    
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        
        guard let stableId = innerId.base as? ChatHistoryEntryId else {
            return contentView
        }
        
        switch stableId {
        case let .mediaId(index, _):
            return contents[index.base as! Int]
        default:
            break
        }
        
        return contentView
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        
        
        guard let stableId = innerId.base as? ChatHistoryEntryId, let item = item as? ChatRowItem else {
            return
        }
        
        switch stableId {
        case let .mediaId(index, _):
            let contentNode = contents[index.base as! Int]
            
            let rightView = ChatRightView(frame: NSZeroRect)
            rightView.set(item: item, animated: false)
            rightView.blurBackground = self.rightView.blurBackground
            rightView.layer?.cornerRadius = self.rightView.layer!.cornerRadius
            var rect = self.rightView.convert(self.rightView.bounds, to: contentNode)
            
            if contentNode.effectiveVisibleRect.minY < rect.midY && contentNode.effectiveVisibleRect.minY + contentNode.effectiveVisibleRect.height > rect.midY {
                rect.origin.y = contentNode.frame.height - rect.maxY
                rightView.frame = rect
                view.addSubview(rightView)
            }
            
            if let badgeView, let textLayout = badgeView.textView.textView.textLayout {
                let newBadge = BadgeView(frame: NSZeroRect)
                newBadge.update(textLayout: textLayout, context: item.context)
                
                var rect = badgeView.convert(badgeView.bounds, to: contentNode)
                rect.origin.y = contentNode.frame.height - rect.maxY
                newBadge.frame = rect
                
                view.addSubview(newBadge)
            }
            
            contentNode.addAccesoryOnCopiedView(view: view)
        default:
            break
        }
        
        
    }
}

