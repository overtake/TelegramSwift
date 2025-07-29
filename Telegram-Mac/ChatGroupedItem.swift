//
//  ChatGroupedItem.swift
//  Telegram
//
//  Created by keepcoder on 31/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit
import TGModernGrowingTextView
import InputView
class ChatGroupedItem: ChatRowItem {

    fileprivate(set) var parameters: [ChatMediaLayoutParameters] = []
    fileprivate let layout: GroupedLayout
    
    override var messages: [Message] {
        return layout.messages
    }
    
    var layoutType: GroupedMediaType {
        return layout.type
    }
   
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ entry: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        
        var captionLayouts: [ChatRowItem.RowCaption] = []
        
        if case let .groupedPhotos(messages, _) = entry {
            
            let messages = messages.map{$0.message!}.filter({!$0.media.isEmpty})
            let prettyCount = messages.filter { $0.anyMedia!.isInteractiveMedia }.count
            self.layout = GroupedLayout(messages, type: prettyCount != messages.count ? .files : .photoOrVideo)
            
            var captionMessages: [Message] = []
            switch layout.type {
            case .photoOrVideo:
                for message in messages {
                    if !captionMessages.isEmpty, !message.text.isEmpty {
                        captionMessages.removeAll()
                        break
                    }
                    if !message.text.isEmpty {
                        captionMessages.append(message)
                        break
                    }
                }
            case .files:
                captionMessages = messages.filter { !$0.text.isEmpty }
            }
            
            
            for message in captionMessages {
                
                let isIncoming: Bool = message.isIncoming(context.account, entry.renderType == .bubble)

                var text: String = message.text
                var attributes: [MessageAttribute] = message.attributes
                var isLoading: Bool = false
                if let translate = entry.additionalData(message.id).translate {
                    switch translate {
                    case .loading:
                        isLoading = true
                    case let .complete(toLang):
                        if let attribute = message.translationAttribute(toLang: toLang) {
                            text = attribute.text
                            attributes = [TextEntitiesMessageAttribute(entities: attribute.entities)]
                        }
                    }
                }
                var caption:NSMutableAttributedString = NSMutableAttributedString()
                NSAttributedString.initialize()
                _ = caption.append(string: text, color: theme.chat.textColor(isIncoming, entry.renderType == .bubble), font: NSFont.normal(theme.fontSize))
                
                var hasEntities: Bool = false
                for attr in attributes {
                    if attr is TextEntitiesMessageAttribute {
                        hasEntities = true
                        break
                    }
                }
                if hasEntities {
                    
                    caption = ChatMessageItem.applyMessageEntities(with: attributes, for: text, message: message, context: context, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.hashtag, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, entry.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), openBank: chatInteraction.openBank, blockColor: theme.chat.blockColor(context.peerNameColors, message: message, isIncoming: message.isIncoming(context.account, entry.renderType == .bubble), bubbled: entry.renderType == .bubble), isDark: theme.colors.isDark, bubbled: entry.renderType == .bubble, codeSyntaxData: entry.additionalData.codeSyntaxData, loadCodeSyntax: chatInteraction.enqueueCodeSyntax, openPhoneNumber: chatInteraction.openPhoneNumberContextMenu, ignoreLinks: !entry.additionalData.canHighlightLinks && isIncoming).mutableCopy() as! NSMutableAttributedString
                    caption.removeWhitespaceFromQuoteAttribute()

                }
                
                var stableId = message.stableId
                switch layout.type {
                case .files:
                    stableId = captionMessages.count == 1 ? messages.last!.stableId : message.stableId
                default:
                    break
                }
                InlineStickerItem.apply(to: caption, associatedMedia: message.associatedMedia, entities: attributes.compactMap{ $0 as? TextEntitiesMessageAttribute }.first?.entities ?? [], isPremium: context.isPremium)

                let spoilerColor: NSColor
                if entry.renderType == .bubble {
                    spoilerColor = theme.chat.grayText(isIncoming, entry.renderType == .bubble)
                } else {
                    spoilerColor = theme.chat.textColor(isIncoming, entry.renderType == .bubble)
                }
                let isSpoilerRevealed = chatInteraction.presentation.interfaceState.revealedSpoilers.contains(message.id)
                
                
                let textLayout = FoldingTextLayout.make(caption, context: context, revealed: entry.additionalData.quoteRevealed, takeLayout: { string in
                    let textLayout = TextViewLayout(string, alignment: .left, selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), strokeLinks: entry.renderType == .bubble, alwaysStaticItems: true, mayItems: !message.isCopyProtected(), spoilerColor: spoilerColor, isSpoilerRevealed: isSpoilerRevealed, onSpoilerReveal: { [weak chatInteraction] in
                        chatInteraction?.update({
                            $0.updatedInterfaceState({
                                $0.withRevealedSpoiler(message.id)
                            })
                        })
                    })
                    return textLayout
                })
                
                let layout: ChatRowItem.RowCaption = .init(message: message, id: stableId, offset: .zero, layout: textLayout, isLoading: isLoading, contentInset: ChatRowItem.defaultContentInnerInset)
                captionLayouts.append(layout)
                layout.layout.applyRanges(selectManager.findAll(stableId))

            }
            
        } else {
            fatalError("")
        }
        
        super.init(initialSize, chatInteraction, context, entry, theme: theme)
        
         self.captionLayouts = captionLayouts
        
        
        for layout in captionLayouts {
            
            let interactions = globalLinkExecutor

            interactions.topWindow = { [weak self] in
                if let strongSelf = self {
                    return strongSelf.menuAdditionView
                } else {
                    return .single(nil)
                }
            }
            interactions.menuItems = { [weak self, weak layout] type in
                if let interactions = self?.chatInteraction, let entry = self?.entry, let layout {
                    return chatMenuItems(for: layout.message, entry: entry, textLayout: (layout.layout.merged, type), chatInteraction: interactions)
                }
                return .complete()
            }
            layout.layout.set(interactions)
        }
                
        for (i, message) in layout.messages.enumerated() {
            
            switch layout.type {
            case .files:
                
                let parameters = ChatMediaLayoutParameters.layout(for: (message.anyMedia as! TelegramMediaFile), isWebpage: chatInteraction.isLogInteraction, chatInteraction: chatInteraction, presentation: .make(for: message, account: context.account, renderType: entry.renderType, theme: theme), automaticDownload: downloadSettings.isDownloable(message), isIncoming: message.isIncoming(context.account, entry.renderType == .bubble), autoplayMedia: entry.autoplayMedia, isRevealed: entry.additionalData.isRevealed)
                
                parameters.showMedia = { [weak self] message in
                    guard let `self` = self else {return}
                    
                    var type:GalleryAppearType = .history
                    let parameters = self.parameters[i] as? ChatMediaGalleryParameters
                    if let parameters = parameters, parameters.isWebpage {
                        type = .alone
                    } else if message.containsSecretMedia {
                        type = .secret
                    }
                                
                    showChatGallery(context: context, message: message, self.table, parameters, type: type, chatMode: self.chatInteraction.mode, chatLocation: self.chatInteraction.chatLocation, contextHolder: self.chatInteraction.contextHolder())
                }
                
                self.parameters.append(parameters)
            case .photoOrVideo:
                self.parameters.append(ChatMediaGalleryParameters(showMedia: { [weak self] message in
                    guard let `self` = self else {return}
                    
                    var type:GalleryAppearType = .history
                    if let parameters = self.parameters[i] as? ChatMediaGalleryParameters, parameters.isWebpage {
                        type = .alone
                    } else if message.containsSecretMedia {
                        type = .secret
                    }
                    if self.chatInteraction.mode.isThreadMode, self.chatInteraction.chatLocation.threadMsgId?.peerId == message.id.peerId {
                        type = .messages(self.messages)
                    }
                    showChatGallery(context: context, message: message, self.table, self.parameters[i], type: type, chatMode: self.chatInteraction.mode, chatLocation: self.chatInteraction.chatLocation, contextHolder: self.chatInteraction.contextHolder())
                    
                    }, showMessage: { [weak self] message in
                        self?.chatInteraction.focusMessageId(nil, .init(messageId: message.id, string: nil), .CenterEmpty)
                    }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: context.account, renderType: entry.renderType, theme: theme), media: message.anyMedia!, automaticDownload: downloadSettings.isDownloable(message), autoplayMedia: entry.autoplayMedia, isRevealed: entry.isRevealed))
            }
            self.parameters[i].automaticDownloadFunc = { message in
                return entry.additionalData.automaticDownload.isDownloable(message)
            }
            self.parameters[i].revealMedia = { message in
                chatInteraction.revealMedia(message)
            }
            self.parameters[i].chatLocationInput = chatInteraction.chatLocationInput
            self.parameters[i].chatMode = chatInteraction.mode
            self.parameters[i].getUpdatingMediaProgress = { messageId in
                switch entry {
                case let .groupedPhotos(entries, _):
                    let media = entries.first(where: { $0.message?.id == messageId})?.additionalData.updatingMedia
                    if let media = media {
                        switch media.media {
                        case .update:
                            return .single(media.progress)
                        default:
                            break
                        }
                    }
                default:
                    break
                }
                return .single(nil)
            }
            self.parameters[i].cancelOperation = { [unowned context] message, media in
                switch entry {
                case let .groupedPhotos(entries, _):
                    if let entry = entries.first(where: { $0.message?.id == message.id }) {
                        if entry.additionalData.updatingMedia != nil {
                            context.account.pendingUpdateMessageManager.cancel(messageId: message.id)
                        } else if let media = media as? TelegramMediaFile {
                            messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, file: media)
                            if let resource = media.resource as? LocalFileArchiveMediaResource {
                                archiver.remove(.resource(resource))
                            }
                        } else if let media = media as? TelegramMediaImage {
                            chatMessagePhotoCancelInteractiveFetch(account: context.account, photo: media)
                        }
                    }
                default:
                    break
                }
            }
            self.parameters[i].isProtected = message.containsSecretMedia || message.isCopyProtected()
        }
        
        if isBubbleFullFilled, layout.messages.count == 1  {
            var positionFlags: LayoutPositionFlags = []
            if captionLayouts.isEmpty {
                positionFlags.insert(.bottom)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            if !hasUpsideSomething {
                positionFlags.insert(.top)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            self.positionFlags = positionFlags
        }
        
        switch self.layout.type {
        case .files:
            var positionFlags: LayoutPositionFlags = []
            positionFlags.insert(.bottom)
            positionFlags.insert(.top)
            positionFlags.insert(.left)
            positionFlags.insert(.right)
            self.positionFlags = positionFlags
        default:
            break
        }
    }
    
    var hasUpsideSomething: Bool {
        return authorText != nil || replyModel != nil || topicLinkLayout != nil || forwardNameLayout != nil
    }
    
    override func share() {
        if let message = message {
            showModal(with: ShareModalController(ShareMessageObject(context, message, layout.messages)), for: context.window)
        }

    }
    
    override var lastLineContentWidth: ChatRowItem.LastLineData? {
        if let lastLineContentWidth = super.lastLineContentWidth {
            return lastLineContentWidth
        }
        switch self.layoutType {
        case .files:
            if let file = self.layout.messages.last?.anyMedia as? TelegramMediaFile, file.previewRepresentations.isEmpty {
                if let parameters = self.parameters[layout.messages.count - 1] as? ChatFileLayoutParameters {
                    let progressMaxWidth = max(parameters.uploadingLayout.layoutSize.width, parameters.downloadingLayout.layoutSize.width)
                    let width = max(parameters.finderLayout.layoutSize.width, parameters.downloadLayout.layoutSize.width, progressMaxWidth) + 50
                    return ChatRowItem.LastLineData(width: width, single: true)
                } else {
                    return nil
                }
            }
        default:
            return nil
        }
        return nil
    }
    
    override var hasBubble: Bool {
        get {
            if isBubbled, self.layout.type == .files {
                return true
            }
            return isBubbled && (!captionLayouts.isEmpty || message?.replyAttribute != nil || forwardNameLayout != nil || layout.messages.count == 1 || commentsBubbleData != nil)
        }
        set {
            super.hasBubble = newValue
        }
    }
    
    override var isBubbleFullFilled: Bool {
        return isBubbled && self.layout.type != .files
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
    
    fileprivate var positionFlags: LayoutPositionFlags?
    
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
    
    
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        var _width: CGFloat = 0
        switch layout.type {
        case .files:
            for parameter in parameters {
                let value = parameter.makeLabelsForWidth(min(width, 360))
                _width = max(_width, value)
            }
        case .photoOrVideo:
            _width = min(width, 360)
        }
       
        layout.measure(NSMakeSize(_width, min(_width, 320)), spacing: hasBubble ? 2 : 4)
        
        
        var maxContentWidth = layout.dimensions.width
        if hasBubble {
            maxContentWidth -= bubbleDefaultInnerInset
        }
        for layout in captionLayouts {
            layout.layout.measure(width: maxContentWidth)
        }
        self.captionLayouts = layout.applyCaptions(captionLayouts)
        return layout.dimensions
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        return result
    }
    
//    override var topInset:CGFloat {
//        return 2
//    }

    
    func contentNode(for index: Int) -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: layout.messages[index].media[0])
    }

    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var _message: Message? = nil
        
        var useGroupIfNeeded = true
        for i in 0 ..< layout.count {
            if NSPointInRect(location, layout.frame(at: i).insetBy(dx: -20, dy: 0)) {
                _message = layout.messages[i]
                useGroupIfNeeded = false
                break
            }
        }
        if _message == nil {
            let withText = layout.messages.filter { !$0.text.isEmpty }
            if withText.count == 1 {
                _message = withText[0]
            }
        }
        
        
        let msg = _message ?? self.message
        
        let caption = self.captionLayouts.first(where: { $0.id == msg?.stableId })?.layout


        if let message = msg {
            return chatMenuItems(for: message, entry: entry, textLayout: (caption?.merged, nil), chatInteraction: self.chatInteraction, useGroupIfNeeded: _message == nil || useGroupIfNeeded)
        }
        return super.menuItems(in: location)
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChatGroupedView.self
    }
    
}

class ChatGroupedView : ChatRowView , ModalPreviewRowViewProtocol {
    
    private(set) var contents: [ChatMediaContentView] = []
    private var selectionBackground: CornerView?
    
    
    private var forceClearContentBackground: Bool = false
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var contentColor: NSColor {
        if forceClearContentBackground {
            return .clear
        } else {
            return super.contentColor
        }
    }
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        guard let item = item as? ChatGroupedItem, let window = window as? Window else { return nil }
        
        let location = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(location, item.layout.frame(at: i).insetBy(dx: -20, dy: 0)) {
                let contentNode = contents[i]
                if contentNode is VideoStickerContentView {
                    if let file = contentNode.media as? TelegramMediaFile {
                        let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                        return (.file(reference, GifPreviewModalView.self), contentNode)
                    }
                } else if contentNode is ChatInteractiveContentView {
                    if let image = contentNode.media as? TelegramMediaImage {
                        let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                        return (.image(reference, ImagePreviewModalView.self), contentNode)
                    }
                }
            }
        }
        
        return nil
    }
    
    override func forceClick(in location: NSPoint) {
        if previewMediaIfPossible() {
            
        } else {
            super.forceClick(in: location)
        }
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard let item = item as? ChatGroupedItem, let window = window as? Window else { return false }
        
        let location = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        if contentView.mouseInside() {
            for i in 0 ..< item.layout.count {
                if NSPointInRect(location, item.layout.frame(at: i).insetBy(dx: -20, dy: 0)) {
                    let result = contents[i].previewMediaIfPossible()
                    return result
                }
            }
        }
        return false
    }

    override func updateColors() {
        super.updateColors()
    }
    
    override func notify(with value: Any, oldValue: Any, animated: Bool) {
        super.notify(with: value, oldValue: oldValue, animated: animated)
    }
    
    override func canDropSelection(in location: NSPoint) -> Bool {
        let point = self.convert(location, from: nil)
        return true//!NSPointInRect(point, contentView.frame)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func updateMouse(animated: Bool) {
        super.updateMouse(animated: animated)
        for content in contents {
            content.updateMouse()
        }
    }
    
    
    private func selectedIcon(_ item: ChatGroupedItem) -> CGImage {
        return item.presentation.icons.chatGroupToggleSelected
    }
    
    private func unselectedIcon(_ item: ChatGroupedItem) -> CGImage {
        switch item.layout.type {
        case .files:
            return item.isBubbled ? (item.isIncoming ? item.presentation.icons.group_selection_foreground_bubble_incoming : item.presentation.icons.group_selection_foreground_bubble_outgoing) : item.presentation.icons.group_selection_foreground
        case .photoOrVideo:
            return item.presentation.icons.chatGroupToggleUnselected
        }
    }
    
    override func updateSelectingState(_ animated: Bool, selectingMode: Bool, item: ChatRowItem?, needUpdateColors: Bool) {
        
        
        if let item = item as? ChatGroupedItem {
            
            if selectingMode {
                if contents.count > 1 {
                    for content in contents {
                        let subviews = content.subviews
                        var selectingControl: SelectingControl?
                        for subview in subviews {
                            if subview is SelectingControl {
                                selectingControl = subview as? SelectingControl
                                break
                            }
                        }
                        if selectingControl == nil {
                            selectingControl = SelectingControl(unselectedImage: unselectedIcon(item), selectedImage: selectedIcon(item))
                            content.addSubview(selectingControl!)
                            if animated {
                                selectingControl?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                                selectingControl?.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.2)
                            }
                        }
                        if let selectingControl = selectingControl {
                            selectingControl.setFrameOrigin(selectionOrigin(content))
                        }
                    }
                }
            } else {
                for content in contents {
                    let subviews = content.subviews
                    for subview in subviews {
                        if subview is SelectingControl {
                            if animated {
                                subview.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
                                subview.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.2, removeOnCompletion: false, completion: { [weak subview] completed in
                                    subview?.removeFromSuperview()
                                })
                            } else {
                                subview.removeFromSuperview()
                            }
                        }
                    }
                }
            }
            if let selectionState = item.chatInteraction.presentation.selectionState {
                for i in 0 ..< contents.count {
                    loop: for subview in contents[i].subviews {
                        if let select = subview as? SelectingControl {
                            select.set(selected: selectionState.selectedIds.contains(item.layout.messages[i].id), animated: animated)
                            break loop
                        }
                    }
                }
            }
        }
        super.updateSelectingState(animated, selectingMode: selectingMode, item: item, needUpdateColors: needUpdateColors)
    }
    
    override func updateSelectionViewAfterUpdateState(item: ChatRowItem, animated: Bool) {
        guard let item = item as? ChatGroupedItem else {return}
        guard let selectingView = selectingView  else {return}

        

        var selected: Bool = true
        for message in item.layout.messages {
            if !item.chatInteraction.presentation.isSelectedMessageId(message.id) {
                selected = false
                break
            }
        }
        selectingView.set(selected: selected, animated: animated)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? ChatGroupedItem else {return}
        

        
        if contents.count > item.layout.count {
            let contentCount = contents.count
            let layoutCount = item.layout.count
            
            for i in layoutCount ..< contentCount {
                contents[i].removeFromSuperview()
            }
            contents = contents.subarray(with: NSMakeRange(0, layoutCount))
        } else if contents.count < item.layout.count {
            let contentCount = contents.count
            for i in contentCount ..< item.layout.count {
                let node = item.contentNode(for: i)
                let view = node.init(frame:NSZeroRect)
                contents.append(view)
                addSubview(view)
            }
        }
        
        for i in 0 ..< contents.count {
            if contents[i].className != item.contentNode(for: i).className()  {
                let node = item.contentNode(for: i)
                let view = node.init(frame:NSZeroRect)
                contents[i].removeFromSuperview()
                contents[i] = view
                addSubview(view)
            }
        }
        
        //self.contentView.removeAllSubviews()
        
//        for content in contents {
//            addSubview(content)
//        }
        
        super.set(item: item, animated: animated)

        assert(contents.count == item.layout.count)
        
        let approximateSynchronousValue = item.approximateSynchronousValue
        
        contentView.frame = self.contentFrame(item)
                
        for i in 0 ..< item.layout.count {
            contents[i].change(size: item.layout.frame(at: i).size, animated: animated)
            var positionFlags: LayoutPositionFlags = item.isBubbled ? item.positionFlags ?? item.layout.position(at: i) : []

            if item.hasBubble  {
                if !item.captionLayouts.isEmpty || item.commentsBubbleData != nil, !item.invertMedia {
                    positionFlags.remove(.bottom)
                }
                if item.hasUpsideSomething || item.invertMedia {
                    positionFlags.remove(.top)
                }
            }

            
            contents[i].update(with: item.layout.messages[i].media[0], size: item.layout.frame(at: i).size, context: item.context, parent: item.layout.messages[i], table: item.table, parameters: item.parameters[i], animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
            
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.2, curve: .easeOut)
            } else {
                transition = .immediate
            }
            transition.updateFrame(view: contents[i], frame: item.layout.frame(at: i))
            contents[i].updateLayout(size: item.layout.frame(at: i).size, transition: transition)
            
        }

        needsLayout = true
    }

    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = newValue
            for content in contents {
                content.needsDisplay = newValue
            }
        }
    }
    override var backgroundColor: NSColor {
        didSet {
            for content in contents {
                content.backgroundColor = backdorColor
            }
        }
    }
    
    
    override func toggleSelected(_ select: Bool, in point: NSPoint) {
        guard let item = item as? ChatGroupedItem else { return }
        
        let location = contentView.convert(point, from: nil)
        var applied: Bool = contentView.mouseInside()
        if applied {
            for i in 0 ..< item.layout.count {
                if NSPointInRect(location, item.layout.frame(at: i).insetBy(dx: -20, dy: 0)) {
                    let id = item.layout.messages[i].id
                    item.chatInteraction.withToggledSelectedMessage({ current in
                        if (select && !current.isSelectedMessageId(id)) || (!select && current.isSelectedMessageId(id)) {
                            return current.withToggledSelectedMessage(id)
                        }
                        return current
                    })
                    applied = true
                    break
                }
            }
        }
        
        if !applied {
            item.chatInteraction.withToggledSelectedMessage({ current in
                return item.layout.messages.reduce(current, { current, message -> ChatPresentationInterfaceState in
                    if (select && !current.isSelectedMessageId(message.id)) || (!select && current.isSelectedMessageId(message.id)) {
                        return current.withToggledSelectedMessage(message.id)
                    }
                    return current
                })
            })
        }
        
    }
    
    
    
    override func forceSelectItem(_ item: ChatRowItem, onRightClick: Bool) {
        
        guard let item = item as? ChatGroupedItem else {return}
        guard let window = window as? Window else {return}

        if onRightClick {
            item.chatInteraction.withToggledSelectedMessage({ current in
                var current: ChatPresentationInterfaceState = current
                for message in item.layout.messages {
                    current = current.withToggledSelectedMessage(message.id)
                }
                return current
            })
            return
        }
        
        guard item.chatInteraction.presentation.state == .selecting else {return}
        
        let location = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        var selected: Bool = contentView.mouseInside()
        if contentView.mouseInside() {
            for i in 0 ..< item.layout.count {
                if NSPointInRect(location, item.layout.frame(at: i).insetBy(dx: -20, dy: 0)) {
                    item.chatInteraction.withToggledSelectedMessage({
                        $0.withToggledSelectedMessage(item.layout.messages[i].id)
                    })
                    selected = true
                    break
                }
            }
        }
        

        if !selected {
            let select = !isHasSelectedItem
            item.chatInteraction.withToggledSelectedMessage({ current in
                return item.layout.messages.reduce(current, { current, message -> ChatPresentationInterfaceState in
                    if (select && !current.isSelectedMessageId(message.id)) || (!select && current.isSelectedMessageId(message.id)) {
                        return current.withToggledSelectedMessage(message.id)
                    }
                    return current
                })
            })
        }
        
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            for content in contents {
                content.willRemove()
            }
        }
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        
        if let innerId = innerId.base as? ChatHistoryEntryId {
            switch innerId {
            case .message(let message):
                for content in contents {
                    if content.parent?.id == message.id {
                        return content.interactionContentView(for: innerId, animateIn: animateIn)
                    }
                }
            default:
                break
            }
        }
        
        return super.interactionContentView(for: innerId, animateIn: animateIn)
    }
    
    override func interactionControllerDidFinishAnimation(interactive: Bool, innerId: AnyHashable) {

    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        
        guard let item = item as? ChatRowItem else {return}
        if let innerId = innerId.base as? ChatHistoryEntryId {
            switch innerId {
            case .message(let message):
                for content in contents {
                    if content.parent?.id == message.id {
                        let rect = rightView.convert(rightView.bounds, to: content.superview)
                        if NSIntersectsRect(rect, content.frame), item.isStateOverlayLayout {
                            let rightView = ChatRightView(frame: NSZeroRect)
                            rightView.set(item: item, animated: false)
                            var rect = self.rightView.convert(self.rightView.bounds, to: content)
                            
                            if content.visibleRect.minY < rect.midY && content.visibleRect.minY + content.visibleRect.height > rect.midY {
                                rect.origin.y = content.frame.height - rect.maxY
                                rightView.frame = rect
                                view.addSubview(rightView)
                            }
                           
                        }
                        content.addAccesoryOnCopiedView(view: view)

                    }
                }
            default:
                break
            }
        }
        
        
    }
    
    
    override func isSelectInGroup(_ location: NSPoint) -> Bool {
        guard let item = item as? ChatGroupedItem else {return false}
        
        guard item.chatInteraction.presentation.state == .selecting else {return false}
        
        let location = contentView.convert(location, from: nil)
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(location, item.layout.frame(at: i)) {
                return item.chatInteraction.presentation.isSelectedMessageId(item.layout.messages[i].id)
            }
        }
        let selected = item.layout.messages.filter {
            item.chatInteraction.presentation.isSelectedMessageId($0.id)
        }
        return selected.count == item.layout.messages.count
    }
    
    private var isHasSelectedItem: Bool {
        guard let item = item as? ChatGroupedItem else {
            return false
        }
        for message in item.layout.messages {
            if item.chatInteraction.presentation.isSelectedMessageId(message.id) {
                return true
            }
        }
        return false
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? ChatGroupedItem, !item.isBubbled else {
            return super.backdorColor
        }
        
        
        if let _ = contextMenu {
            return item.presentation.colors.selectMessage
        }

        
        for message in item.layout.messages {
            if item.chatInteraction.presentation.isSelectedMessageId(message.id) {
                return item.presentation.colors.selectMessage
            }
        }
        
        return super.backdorColor
    }
    
    
    private func highlightFrameAndColor(_ item: ChatGroupedItem, at index: Int) -> (color: NSColor, frame: NSRect, flags: LayoutPositionFlags, superview: NSView) {
        switch item.layout.type {
        case .photoOrVideo:
            return (color: NSColor.black.withAlphaComponent(0.4), frame: item.layout.frame(at: index), flags: item.isBubbled ? item.positionFlags ?? item.layout.position(at: index) : [], superview: self.contentView)
        case .files:
            var frame = item.layout.frame(at: index)
            let contentFrame = self.contentFrame(item)
            let bubbleFrame = self.bubbleFrame(item)
            if item.hasBubble {
                
                frame.origin.x = 0
                frame.size.width = bubbleFrame.width
                
                var caption: CGFloat = 0
                
                if let layout = item.captionLayouts.first(where: { $0.id == item.layout.messages[index].stableId })  {
                    caption = layout.layout.size.height + 6
                }
                
                
                frame.size.height += 8
                if index == 0 {
                    frame.size.height += contentFrame.minY
                } else if index == item.layout.count - 1 {
                    frame.origin.y += contentFrame.minY
                    if item.reactionsLayout == nil {
                        frame.size.height += contentFrame.minY
                    }
                } else {
                    frame.origin.y += contentFrame.minY
                }
                
                frame.size.height += caption

                
                frame.origin.y = bubbleFrame.height - frame.maxY + 6
                
                return (item.isIncoming ? item.presentation.colors.bubbleBackground_incoming.darker().withAlphaComponent(0.5) : item.presentation.colors.blendedOutgoingColors.darker().withAlphaComponent(0.5)
                    , frame: frame, flags: [], superview: self.bubbleView)
            } else {
                
                frame.origin.x = 0
                frame.size.width = self.frame.width
                frame.size.height += 8
                
                var caption: CGFloat = 0
                
                if let layout = item.captionLayouts.first(where: { $0.id == item.layout.messages[index].stableId })  {
                    caption = layout.layout.size.height + 6
                }
                
                if index == 0 {
                    frame.size.height += contentFrame.minY
                } else if index == item.layout.count - 1 {
                    frame.origin.y += contentFrame.minY
                    frame.size.height += contentFrame.minY
                } else {
                    frame.origin.y += contentFrame.minY
                }
                
                frame.size.height += caption
                
                frame.origin.y -= 4
                
                return (color: item.presentation.colors.accentIcon.withAlphaComponent(0.15), frame: frame, flags: [], superview: self.rowView)
            }
        }
    }
    
    override func focusAnimation(_ innerId: AnyHashable?, text: String?) {
        if let innerId = innerId {
            guard let item = item as? ChatGroupedItem else {return}
            
            

            for i in 0 ..< item.layout.count {
                if AnyHashable(ChatHistoryEntryId.message(item.layout.messages[i])) == innerId {
                    
                    let data = highlightFrameAndColor(item, at: i)
                    
                    let selectionBackground = CornerView()
                    selectionBackground.isDynamicColorUpdateLocked = true
                    selectionBackground.didChangeSuperview = { [weak selectionBackground, weak self] in
                        self?.forceClearContentBackground = selectionBackground?.superview != nil
                        self?.updateColors()
                    }
                    
                    if let caption = captionViews.first(where: { $0.id == item.layout.messages[i].stableId }) {
                        if let text = text, !text.isEmpty {
                            caption.view.highlight(text: text, color: item.presentation.colors.focusAnimationColor)
                        }
                    }
                                        
                    
                    selectionBackground.frame = data.frame
                    selectionBackground.backgroundColor = data.color
                    
                    var positionFlags: LayoutPositionFlags = data.flags
                    
                    if item.hasBubble  {
                        if item.captionLayouts.first(where: { $0.id == item.firstMessage?.stableId }) == nil {
                            positionFlags.remove(.bottom)
                        }
                        if item.hasUpsideSomething {
                            positionFlags.remove(.top)
                        }
                    }

                    selectionBackground.positionFlags = positionFlags
                    data.superview.addSubview(selectionBackground)
                                        
                    let animation: CABasicAnimation = makeSpringAnimation("opacity")
                    
                    animation.fromValue = 0
                    animation.toValue = 1
                    animation.duration = 0.5
                    animation.isRemovedOnCompletion = false
                    animation.delegate = CALayerAnimationDelegate(completion: { [weak selectionBackground] completed in
                        if let selectionBackground = selectionBackground {
                            performSubviewRemoval(selectionBackground, animated: true, duration: 0.35, timingFunction: .spring)
                        }
                    })
                    
                    selectionBackground.layer?.add(animation, forKey: "opacity")
                    break
                }
            }
        } else {
            super.focusAnimation(innerId, text: text)
        }
    }
    
    
    override func onShowContextMenu() {
        guard let window = window as? Window else {return}
        guard let item = item as? ChatGroupedItem else {return}
        
        let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        var selected: Bool = false
        
        if let selectionBackground = selectionBackground {
            performSubviewRemoval(selectionBackground, animated: true)
            self.selectionBackground = nil
        }
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(point, item.layout.frame(at: i).insetBy(dx: -20, dy: 0)) {
                
                let data = highlightFrameAndColor(item, at: i)
                let selectionBackground = CornerView()
                selectionBackground.isDynamicColorUpdateLocked = true
                selectionBackground.didChangeSuperview = { [weak self, weak selectionBackground] in
                    self?.forceClearContentBackground = selectionBackground?.superview != nil
                    self?.updateColors()
                }
                selectionBackground.frame = data.frame
                selectionBackground.backgroundColor = data.color
                var positionFlags: LayoutPositionFlags = data.flags
                
                if item.hasBubble  {
                    if item.captionLayouts.first(where: { $0.id == item.firstMessage?.stableId }) != nil {
                        positionFlags.remove(.bottom)
                    }
                    if item.hasUpsideSomething{
                        positionFlags.remove(.top)
                    }
                }
                
                selectionBackground.positionFlags = positionFlags
                data.superview.addSubview(selectionBackground)
                
                self.selectionBackground = selectionBackground
                selectionBackground.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                
                selected = true
                break
            }
        }
        
        if !selected {
            super.onShowContextMenu()
        }
    }
    
    override func onCloseContextMenu() {
        super.onCloseContextMenu()
        
        if let selectionBackground = selectionBackground {
            performSubviewRemoval(selectionBackground, animated: true)
            self.selectionBackground = nil
        }
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        let point = contentView.convert(location, from: nil)
        for content in contents {
            if NSPointInRect(point, content.frame) {
                return false
            }
        }
        return true
    }
    
    override func contentFrame(_ item: ChatRowItem) -> NSRect {
        var rect = super.contentFrame(item)
        guard let item = item as? ChatGroupedItem else {
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
    
    func selectionOrigin(_ content: ChatMediaContentView) -> CGPoint {
        guard let item = item as? ChatGroupedItem else {return .zero}

        switch item.layout.type {
        case .files:
            let subviews = content.subviews
            for subview in subviews {
                if subview is SelectingControl {
                    if content is ChatAudioContentView {
                        return NSMakePoint(26, 18)
                    } else if let content = content as? ChatFileContentView {
                        if content.isHasThumb {
                            return NSMakePoint(40, 6)
                        } else {
                            return NSMakePoint(26, 18)
                        }
                    }
                }
            }
        case .photoOrVideo:
            let subviews = content.subviews
            for subview in subviews {
                if subview is SelectingControl {
                    return NSMakePoint(content.frame.width - subview.frame.width - 5, 5)
                }
            }
        }
        return .zero
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? ChatGroupedItem else {return}

        assert(contents.count == item.layout.count)

        for i in 0 ..< item.layout.count {
            transition.updateFrame(view: contents[i], frame: item.layout.frame(at: i))
            contents[i].updateLayout(size: item.layout.frame(at: i).size, transition: transition)
        }
        
        for content in contents {
            let subviews = content.subviews
            for subview in subviews {
                if subview is SelectingControl {
                    transition.updateFrame(view: subview, frame: CGRect(origin: selectionOrigin(content), size: subview.frame.size))
                }
            }
        }
    }
    
    override func layout() {
        super.layout()

        
        
        
    }
    
}
