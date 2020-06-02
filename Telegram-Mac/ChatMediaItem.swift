//
//  ChatPhotoItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import TGUIKit
import SwiftSignalKit

class ChatMediaLayoutParameters : Equatable {
    
    var showMedia:(Message)->Void = {_ in }
    var showMessage:(Message)->Void = {_ in }
    
    let presentation: ChatMediaPresentation
    let media: Media
    
    
    private var _timeCodeInitializer: Double? = nil

    var timeCodeInitializer:Double? {
        let current = self._timeCodeInitializer
        self._timeCodeInitializer = nil
        return current
    }
    
    func remove_timeCodeInitializer() {
        self._timeCodeInitializer = nil
    }
    
    func set_timeCodeInitializer(_ timecode: Double?) {
        self._timeCodeInitializer = timecode
    }
    
    private var _automaticDownload: Bool
    
    var automaticDownload: Bool {
        get {
            let value = _automaticDownload
//            _automaticDownload = false
            return value
        }
    }
    
    let autoplayMedia: AutoplayMediaPreferences
    
    var autoplay: Bool
    var soundOnHover: Bool {
        return autoplayMedia.soundOnHover
    }
    var preload: Bool {
        return autoplayMedia.preloadVideos
    }
    
//    var autoplay: Bool {
//        get {
//            let value = _automaticDownload
//            return value
//        }
//    }
//
    
    var automaticDownloadFunc:(Message)->Bool
    
    
    init(presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool, autoplayMedia: AutoplayMediaPreferences) {
        self.automaticDownloadFunc = { _ in
            return automaticDownload
        }
        self.presentation = presentation
        self.media = media
        self.autoplayMedia = autoplayMedia
        self._automaticDownload = automaticDownload
        if let media = media as? TelegramMediaFile {
            if media.isVideo && media.isAnimated {
                self.autoplay = autoplayMedia.gifs
            } else {
                self.autoplay = autoplayMedia.videos
            }
        } else {
            self.autoplay = false
        }
    }
    
    
    static func layout(for media:TelegramMediaFile, isWebpage: Bool, chatInteraction:ChatInteraction, presentation: ChatMediaPresentation, automaticDownload: Bool, isIncoming: Bool, isFile: Bool = false, autoplayMedia: AutoplayMediaPreferences, isChatRelated: Bool = false) -> ChatMediaLayoutParameters {
        if media.isInstantVideo && !isFile {
            var duration:Int = 0
            for attr in media.attributes {
                switch attr {
                case let .Video(params):
                    duration = params.duration
                default:
                    break
                }
            }
            
            return ChatMediaVideoMessageLayoutParameters(showPlayer:chatInteraction.inlineAudioPlayer, duration: duration, isMarked: true, isWebpage: isWebpage || chatInteraction.isLogInteraction, resource: media.resource, presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: autoplayMedia)
        } else if media.isVoice && !isFile {
            var waveform:AudioWaveform? = nil
            var duration:Int = 0
            for attr in media.attributes {
                switch attr {
                case let .Audio(params):
                    if let data = params.waveform?.makeData() {
                        waveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                    }
                    duration = params.duration
                default:
                    break
                }
            }
            
            return ChatMediaVoiceLayoutParameters(showPlayer:chatInteraction.inlineAudioPlayer, waveform:waveform, duration:duration, isMarked: true, isWebpage: isWebpage || chatInteraction.isLogInteraction, resource: media.resource, presentation: presentation, media: media, automaticDownload: automaticDownload)
        } else if media.isMusic && !isFile {
            var audioTitle:String?
            var audioPerformer:String?
            
            var duration:Int = 0
            for attribute in media.attributes {
                if case let .Audio(_, d, title, performer, _) = attribute {
                    duration = d
                    audioTitle = title
                    audioPerformer = performer
                    break
                }
            }
            
            let attr = NSMutableAttributedString()
            
            
            if let _audioTitle = audioTitle, let audioPerformer = audioPerformer {
                if _audioTitle.isEmpty && audioPerformer.isEmpty {
                    _ = attr.append(string: media.fileName, color: presentation.text, font: NSFont.medium(.title))
                    audioTitle = media.fileName
                } else {
                    _ = attr.append(string: _audioTitle + " - " + audioPerformer, color: presentation.text, font: NSFont.medium(.title))
                }
            } else {
                _ = attr.append(string: media.fileName, color: presentation.text, font: NSFont.medium(.title))
                audioTitle = media.fileName
            }
            
            return ChatMediaMusicLayoutParameters(nameLayout: TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end), durationLayout: TextViewLayout(.initialize(string: String.durationTransformed(elapsed: duration), color: presentation.grayText, font: .normal(.title)), maximumNumberOfLines: 1, truncationType: .end), sizeLayout: TextViewLayout(.initialize(string: (media.size ?? 0).prettyNumber, color: presentation.grayText, font: .normal(.title)), maximumNumberOfLines: 1, truncationType: .middle), resource: media.resource, isWebpage: isWebpage, title: audioTitle, performer: audioPerformer, showPlayer:chatInteraction.inlineAudioPlayer, presentation: presentation, media: media, automaticDownload: automaticDownload)
        } else {
            var fileName:String = "Unknown.file"
            if let name = media.fileName {
                fileName = name
            }
            return  ChatFileLayoutParameters(fileName: fileName, hasThumb: !media.previewRepresentations.isEmpty, presentation: presentation, media: media, automaticDownload: automaticDownload, isIncoming: isIncoming, autoplayMedia: autoplayMedia, isChatRelated: isChatRelated)
        }
    }
    
    func makeLabelsForWidth(_ width: CGFloat) {
        
    }
    
}

class ChatMediaGalleryParameters : ChatMediaLayoutParameters {
    let isWebpage: Bool

    init(showMedia:@escaping(Message)->Void, showMessage:@escaping(Message)->Void, isWebpage: Bool, presentation: ChatMediaPresentation = .Empty, media: Media, automaticDownload: Bool, autoplayMedia: AutoplayMediaPreferences = AutoplayMediaPreferences.defaultSettings) {
       self.isWebpage = isWebpage
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: autoplayMedia)
        self.showMedia = showMedia
        self.showMessage = showMessage
    }
}

func ==(lhs:ChatMediaLayoutParameters, rhs:ChatMediaLayoutParameters) -> Bool {
    return false
}


class ChatMediaItem: ChatRowItem {

    let media:Media

    
    var parameters:ChatMediaLayoutParameters?
    
  
    
    
    override var topInset:CGFloat {
        return 4
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
        return isBubbled && !isBubbleFullFilled ? 14 :  super.defaultContentTopOffset
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
    
    
    
    override var _defaultHeight: CGFloat {
        if hasBubble && isBubbleFullFilled && captionLayout == nil {
            return contentOffset.y + defaultContentInnerInset - mediaBubbleCornerInset * 2 - 1
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
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if isForceRightLine {
            return rightSize.height
        }
        if let file = self.media as? TelegramMediaFile, file.isEmojiAnimatedSticker {
            return rightSize.height + 3
        }
        if let caption = captionLayout {
            if let line = caption.lines.last, line.frame.width > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
                return rightSize.height
            }
        }
        if postAuthor != nil {
            return isStateOverlayLayout ? nil : rightSize.height
        }
        return super.additionalLineForDateInBubbleState
    }
    
    override var isFixedRightPosition: Bool {
        if media is TelegramMediaImage {
            return true
        } else if let media = media as? TelegramMediaFile {
            
            if let captionLayout = captionLayout, let line = captionLayout.lines.last, line.frame.width < realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
                return true
            }
            
            return media.isVideo || media.isAnimated || media.isVoice || media.isMusic || media.isStaticSticker || media.isAnimatedSticker
        }
        return super.isFixedRightPosition
    }
    
    override var instantlyResize: Bool {
        if captionLayout != nil && media.isInteractiveMedia {
            return true
        } else {
            return super.instantlyResize
        }
    }
    

    override var isBubbleFullFilled: Bool {
        return (media.isInteractiveMedia || isSticker) && isBubbled 
    }
    
    var positionFlags: LayoutPositionFlags? = nil
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        let message = object.message!
        
        let isIncoming: Bool = message.isIncoming(context.account, object.renderType == .bubble)

        media = message.media[0]
        
        
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        
        var canAddCaption: Bool = true
        if let media = media as? TelegramMediaFile, media.isAnimatedSticker || media.isStaticSticker {
            canAddCaption = false
        }
        if media is TelegramMediaDice {
            canAddCaption = false
        }
        
        
        self.parameters = ChatMediaGalleryParameters(showMedia: { [weak self] message in
            guard let `self` = self else {return}
            
            var type:GalleryAppearType = .history
            if let parameters = self.parameters as? ChatMediaGalleryParameters, parameters.isWebpage {
                type = .alone
            } else if message.containsSecretMedia {
                type = .secret
            }
            showChatGallery(context: context, message: message, self.table, self.parameters as? ChatMediaGalleryParameters, type: type)
            
            }, showMessage: { [weak self] message in
                self?.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
            }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: context.account, renderType: object.renderType), media: media, automaticDownload: downloadSettings.isDownloable(message), autoplayMedia: object.autoplayMedia)
        
        
        if !message.text.isEmpty, canAddCaption {
            
            
            
            var caption:NSMutableAttributedString = NSMutableAttributedString()
            _ = caption.append(string: message.text, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(theme.fontSize))
            var types:ParsingType = [.Links, .Mentions, .Hashtags]
            
            if let peer = messageMainPeer(message) as? TelegramUser {
                if peer.botInfo != nil {
                    types.insert(.Commands)
                }
            } else if let peer = messageMainPeer(message) as? TelegramChannel {
                switch peer.info {
                case .group:
                    types.insert(.Commands)
                default:
                    break
                }
            } else {
                types.insert(.Commands)
            }
            
            var hasEntities: Bool = false
            for attr in message.attributes {
                if attr is TextEntitiesMessageAttribute {
                    hasEntities = true
                    break
                }
            }
            var mediaDuration: Double? = nil
            if let file = message.media.first as? TelegramMediaFile, file.isVideo && !file.isAnimated, let duration = file.duration {
                mediaDuration = Double(duration)
            }
            
            caption = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text.fixed, context: context, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.modalSearch, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, object.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, object.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), mediaDuration: mediaDuration, timecode: { [weak self] timecode in
                self?.parameters?.set_timeCodeInitializer(timecode)
                self?.parameters?.showMedia(message)
            }, openBank: chatInteraction.openBank).mutableCopy() as! NSMutableAttributedString
            
            
            if !hasEntities || message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
                caption.detectLinks(type: types, context: context, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble), openInfo:chatInteraction.openInfo, hashtag: context.sharedContext.bindings.globalSearch, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy)
            }
            captionLayout = TextViewLayout(caption, alignment: .left, selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), strokeLinks: object.renderType == .bubble, alwaysStaticItems: true, disableTooltips: false)
            
            let interactions = globalLinkExecutor
            
            interactions.copyToClipboard = { text in
                copyToClipboard(text)
                context.sharedContext.bindings.rootNavigation().controller.show(toaster: ControllerToaster(text: L10n.shareLinkCopied))
            }
            captionLayout?.interactions = interactions
            
            if let textLayout = self.captionLayout {
                if let highlightFoundText = entry.additionalData.highlightFoundText {
                    if highlightFoundText.isMessage {
                        if let range = rangeOfSearch(highlightFoundText.query, in: caption.string) {
                            textLayout.additionalSelections = [TextSelectedRange(range: range, color: theme.colors.accentIcon.withAlphaComponent(0.5), def: false)]
                        }
                    } else {
                        var additionalSelections:[TextSelectedRange] = []
                        let string = caption.string.lowercased().nsstring
                        var searchRange = NSMakeRange(0, string.length)
                        var foundRange:NSRange = NSMakeRange(NSNotFound, 0)
                        while (searchRange.location < string.length) {
                            searchRange.length = string.length - searchRange.location
                            foundRange = string.range(of: highlightFoundText.query.lowercased(), options: [], range: searchRange)
                            if (foundRange.location != NSNotFound) {
                                additionalSelections.append(TextSelectedRange(range: foundRange, color: theme.colors.grayIcon.withAlphaComponent(0.5), def: false))
                                searchRange.location = foundRange.location+foundRange.length;
                            } else {
                                break
                            }
                        }
                        textLayout.additionalSelections = additionalSelections
                    }
                }
            }
            

        }
        
        

        
        if isBubbleFullFilled  {
            var positionFlags: LayoutPositionFlags = []
            if captionLayout == nil {
                positionFlags.insert(.bottom)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            if authorText == nil && replyModel == nil && forwardNameLayout == nil {
                positionFlags.insert(.top)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            self.positionFlags = positionFlags
        }

    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        let size = ChatLayoutUtils.contentSize(for: media, with: width, hasText: message?.text.isEmpty == false)
        return size
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items:Signal<[ContextMenuItem], NoError> = .complete()
        if let message = message {
            items = chatMenuItems(for: message, chatInteraction: chatInteraction)
        }
        return items |> map { [weak self] items in
            var items = items
            if let captionLayout = self?.captionLayout {
                let text = captionLayout.attributedString.string
                items.insert(ContextMenuItem(L10n.textCopyText, handler: {
                    copyToClipboard(text)
                }), at: min(items.count, 1))
                
                if let view = self?.view as? ChatRowView, let textView = view.captionView, let window = textView.window {
                    let point = textView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                    if let layout = textView.layout {
                        if let (link, _, range, _) = layout.link(at: point) {
                            var text:String = layout.attributedString.string.nsstring.substring(with: range)
                            if let link = link as? inAppLink {
                                if case let .external(link, _) = link {
                                    text = link
                                }
                            }
                            
                            for i in 0 ..< items.count {
                                if items[i].title == tr(L10n.messageContextCopyMessageLink1) {
                                    items.remove(at: i)
                                    break
                                }
                            }
                            
                            items.insert(ContextMenuItem(tr(L10n.messageContextCopyMessageLink1), handler: {
                                copyToClipboard(text)
                            }), at: 1)
                        }
                    }
                }
            }
            
            return items
        }
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        if let view = view as? ChatMediaView, let content = view.contentNode {
            let point = view.contentView.convert(location, from: nil)
            return !NSPointInRect(point, content.frame)
        }
        return false
    }
    
    override var identifier: String {
        return super.identifier
    }
   
    public func contentNode() -> ChatMediaContentView.Type {
        if let file = media as? TelegramMediaFile, message?.id.peerId.namespace == Namespaces.Peer.SecretChat, file.isAnimatedSticker, file.stickerReference == nil {
            return ChatFileContentView.self
        }
        return ChatLayoutUtils.contentNode(for: media)
    }
    
    override func viewClass() -> AnyClass {
        return ChatMediaView.self
    }
    
}



class ChatMediaView: ChatRowView, ModalPreviewRowViewProtocol {
    
    
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let contentNode = contentNode {
            if contentNode is ChatStickerContentView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, StickerPreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatGIFContentView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, GifPreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatInteractiveContentView {
                if let image = contentNode.media as? TelegramMediaImage {
                    let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                    return (.image(reference, ImagePreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatFileContentView {
                if let file = contentNode.media as? TelegramMediaFile, file.isGraphicFile, let mediaId = file.id, let dimension = file.dimensions {
                    var representations: [TelegramMediaImageRepresentation] = []
                    representations.append(contentsOf: file.previewRepresentations)
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimension, resource: file.resource))
                    let image = TelegramMediaImage(imageId: mediaId, representations: representations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: file.partialReference, flags: [])
                    let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                    return (.image(reference, ImagePreviewModalView.self), contentNode)
                }
            } else if contentNode is MediaAnimatedStickerView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, AnimatedStickerPreviewModalView.self), contentNode)
                }
            }
        }
        
        return nil
    }
    
    override func previewMediaIfPossible() -> Bool {
        
        return contentNode?.previewMediaIfPossible() ?? false
    }
    
    override func forceClick(in location: NSPoint) {
        
        if contentNode?.mouseInside() == true {
            let result = previewMediaIfPossible()
            if !result {
                super.forceClick(in: location)
            }
        } else {
            super.forceClick(in: location)
        }
        
    }
    
    
    fileprivate(set) var contentNode:ChatMediaContentView?
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode?.needsDisplay = true
        }
    }
    
    override var backgroundColor: NSColor {
        didSet {
            
            contentNode?.backgroundColor = contentColor
        }
    }
    
    override func shakeView() {
        contentNode?.shake()
    }
    
    
    override func updateMouse() {
        super.updateMouse()
        self.contentNode?.updateMouse()
    }
    
    override var contentFrame: NSRect {
        var rect = super.contentFrame
        
        guard let item = item as? ChatMediaItem else { return rect }
        
        if item.isBubbled, item.isBubbleFullFilled {
            rect.origin.x -= item.bubbleContentInset
            if item.hasBubble {
                rect.origin.x += item.mediaBubbleCornerInset
            }
        }
        
        return rect
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        if let item:ChatMediaItem = item as? ChatMediaItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            
            self.contentNode?.update(with: item.media, size: item.contentSize, context: item.context, parent:item.message, table:item.table, parameters:item.parameters, animated: animated, positionFlags: item.positionFlags, approximateSynchronousValue: item.approximateSynchronousValue)
        }
        super.set(item: item, animated: animated)
    }
    
    open override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
         if let content = self.contentNode?.interactionContentView(for: innerId, animateIn: animateIn) {
            return content
        }
        return self
    }
    
    override func videoTimebase(for innerId: AnyHashable) -> CMTimebase? {
       return self.contentNode?.videoTimebase()
    }
    override func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        self.contentNode?.applyTimebase(timebase: timebase)
    }
    
    override func interactionControllerDidFinishAnimation(interactive: Bool, innerId: AnyHashable) {
       
        if interactive {
            self.contentNode?.interactionControllerDidFinishAnimation(interactive: interactive)
        }
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        guard let item = item as? ChatRowItem, let contentNode = contentNode else {return}

        
        
        
        let rightView = ChatRightView(frame: NSZeroRect)
        rightView.set(item: item, animated: false)
        var rect = self.rightView.convert(self.rightView.bounds, to: contentNode)
        
        if contentNode.visibleRect.minY < rect.midY && contentNode.visibleRect.minY + contentNode.visibleRect.height > rect.midY {
            rect.origin.y = contentNode.frame.height - rect.maxY
            rightView.frame = rect
            view.addSubview(rightView)
        }
        
        
        contentNode.addAccesoryOnCopiedView(view: view)
    }

}



