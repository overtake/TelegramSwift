//
//  ChatPhotoItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import InAppSettings
import Postbox
import TGUIKit
import SwiftSignalKit

class ChatMediaLayoutParameters : Equatable {
    
    var showMedia:(Message)->Void = {_ in }
    var showMessage:(Message)->Void = {_ in }
    
    
    var chatLocationInput:()->ChatLocationInput = { fatalError() }
    var chatMode:ChatMode = .history
    
    var getUpdatingMediaProgress:(MessageId)->Signal<Float?, NoError> = { _ in return .single(nil) }
    var cancelOperation:(Message, Media)->Void = { _, _ in }
    
    let presentation: ChatMediaPresentation
    let media: Media
    
    
    var runEmojiScreenEffect:(String)->Void = { _ in }
    
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
    
    
    static func layout(for media:TelegramMediaFile, isWebpage: Bool, chatInteraction:ChatInteraction, presentation: ChatMediaPresentation, automaticDownload: Bool, isIncoming: Bool, isFile: Bool = false, autoplayMedia: AutoplayMediaPreferences, isChatRelated: Bool = false, isCopyProtected: Bool = false) -> ChatMediaLayoutParameters {
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
                case let .Audio(_, _duration, _, _, _data):
                    if let data = _data {
                        waveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                    }
                    duration = _duration
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
            return  ChatFileLayoutParameters(fileName: fileName, hasThumb: !media.previewRepresentations.isEmpty, presentation: presentation, media: media, automaticDownload: automaticDownload, isIncoming: isIncoming, autoplayMedia: autoplayMedia, isChatRelated: isChatRelated, isCopyProtected: isCopyProtected)
        }
    }
    
    @discardableResult func makeLabelsForWidth(_ width: CGFloat) -> CGFloat {
        return 0
    }
    
}

class ChatMediaGalleryParameters : ChatMediaLayoutParameters {
    let isWebpage: Bool

    init(showMedia:@escaping(Message)->Void = { _ in }, showMessage:@escaping(Message)->Void = { _ in }, isWebpage: Bool, presentation: ChatMediaPresentation = .Empty, media: Media, automaticDownload: Bool, autoplayMedia: AutoplayMediaPreferences = AutoplayMediaPreferences.defaultSettings) {
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

    
    var parameters:ChatMediaLayoutParameters? = nil {
        didSet {
            updateParameters()
        }
    }
    
    private func updateParameters() {
        parameters?.chatLocationInput = chatInteraction.chatLocationInput
        parameters?.chatMode = chatInteraction.mode
        
        parameters?.getUpdatingMediaProgress = { [weak self] messageId in
            if let media = self?.entry.additionalData.updatingMedia {
                switch media.media {
                case .update:
                    return .single(media.progress)
                default:
                    break
                }
            }
            return .single(nil)
        }
        
        
        
        parameters?.cancelOperation = { [unowned context, weak self] message, media in
            if self?.entry.additionalData.updatingMedia != nil {
                context.account.pendingUpdateMessageManager.cancel(messageId: message.id)
            } else if let media = media as? TelegramMediaFile {
                messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, fileReference: FileMediaReference.message(message: MessageReference(message), media: media))
                if let resource = media.resource as? LocalFileArchiveMediaResource {
                    archiver.remove(.resource(resource))
                }
            } else if let media = media as? TelegramMediaImage {
                chatMessagePhotoCancelInteractiveFetch(account: context.account, photo: media)
            }
        }
    }
    
    
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
        return super.defaultContentTopOffset
    }
    

    
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        
        if hasBubble, isBubbleFullFilled, (authorText == nil && replyModel == nil && forwardNameLayout == nil) {
            offset.y -= (defaultContentInnerInset + 1)
        } else if hasBubble, !isBubbleFullFilled, replyModel != nil || forwardNameLayout != nil {
            offset.y += defaultContentInnerInset
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

    
    override var instantlyResize: Bool {
        if !captionLayouts.isEmpty && media.isInteractiveMedia {
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
        
        
        let parameters = ChatMediaGalleryParameters(showMedia: { [weak self] message in
            guard let `self` = self else {return}
            
            var type:GalleryAppearType = .history
            if let parameters = self.parameters as? ChatMediaGalleryParameters, parameters.isWebpage {
                type = .alone
            } else if message.containsSecretMedia {
                type = .secret
            }
                        
            showChatGallery(context: context, message: message, self.table, self.parameters, type: type, chatMode: self.chatInteraction.mode, contextHolder: self.chatInteraction.contextHolder())
            
            }, showMessage: { [weak self] message in
                self?.chatInteraction.focusMessageId(nil, message.id, .CenterEmpty)
            }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: context.account, renderType: object.renderType, theme: theme), media: media, automaticDownload: downloadSettings.isDownloable(message), autoplayMedia: object.autoplayMedia)
        
        self.parameters = parameters
        
        self.updateParameters()
        
        if !message.text.isEmpty, canAddCaption {
            
            
            
            var caption:NSMutableAttributedString = NSMutableAttributedString()
            _ = caption.append(string: message.text, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(theme.fontSize))
            var types:ParsingType = [.Links, .Mentions, .Hashtags]
            
            if let peer = coreMessageMainPeer(message) as? TelegramUser {
                if peer.botInfo != nil {
                    types.insert(.Commands)
                }
            } else if let peer = coreMessageMainPeer(message) as? TelegramChannel {
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
            
            var spoilers:[TextViewLayout.Spoiler] = []
            for attr in message.attributes {
                if let attr = attr as? TextEntitiesMessageAttribute {
                    for entity in attr.entities {
                        switch entity.type {
                        case .Spoiler:
                            spoilers.append(.init(range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound), color: theme.chat.textColor(isIncoming, renderType == .bubble), isRevealed: chatInteraction.presentation.interfaceState.revealedSpoilers.contains(message.id)))
                        default:
                            break
                        }
                    }
                }
            }
            
            caption = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text, message: message, context: context, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.modalSearch, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, object.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, object.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), mediaDuration: mediaDuration, timecode: { [weak self] timecode in
                self?.parameters?.set_timeCodeInitializer(timecode)
                self?.parameters?.showMedia(message)
            }, openBank: chatInteraction.openBank).mutableCopy() as! NSMutableAttributedString
            
            
            if !hasEntities || message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
                caption.detectLinks(type: types, context: context, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble), openInfo:chatInteraction.openInfo, hashtag: context.sharedContext.bindings.globalSearch, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy)
            }
            if !(self is ChatVideoMessageItem) {
                captionLayouts = [.init(id: message.stableId, offset: CGPoint(x: 0, y: 0), layout: TextViewLayout(caption, alignment: .left, selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), strokeLinks: object.renderType == .bubble, alwaysStaticItems: true, disableTooltips: false, mayItems: !message.isCopyProtected(), spoilers: spoilers, onSpoilerReveal: { [weak chatInteraction] in
                    chatInteraction?.update({
                        $0.updatedInterfaceState({
                            $0.withRevealedSpoiler(message.id)
                        })
                    })
                }))]
            }
            
            let interactions = globalLinkExecutor
            
            interactions.copyToClipboard = { text in
                copyToClipboard(text)
                context.sharedContext.bindings.rootNavigation().controller.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
            }
            interactions.topWindow = { [weak self] in
                return self?.menuAdditionView
            }
            for textLayout in self.captionLayouts.map ({ $0.layout }) {
                textLayout.interactions = interactions
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
            if captionLayouts.isEmpty && commentsBubbleData == nil {
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
    
    func openMedia(_ timemark: Int32? = nil) {
        if let message = self.message {
            if let timemark = timemark {
                self.parameters?.set_timeCodeInitializer(Double(timemark))
            }
            self.parameters?.showMedia(message)
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        let size = ChatLayoutUtils.contentSize(for: media, with: width, hasText: message?.text.isEmpty == false || (isBubbled && (commentsBubbleData != nil || message?.isImported == true)))
        return size
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
       
        let caption = self.captionLayouts.first(where: { $0.id == self.firstMessage?.stableId })
        
        if let message = message {
            return chatMenuItems(for: message, entry: entry, textLayout: (caption?.layout, nil), chatInteraction: chatInteraction)
        }
        return super.menuItems(in: location)
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
    
    var isPinchable: Bool {
        return contentNode() == ChatInteractiveContentView.self || contentNode() == ChatGIFContentView.self
    }
}



class ChatMediaView: ChatRowView, ModalPreviewRowViewProtocol {
    
    private var pinchToZoom: PinchToZoom?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        pinchToZoom = PinchToZoom(parentView: contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
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
                } else if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, VideoPreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatFileContentView {
                if let file = contentNode.media as? TelegramMediaFile, file.isGraphicFile, let mediaId = file.id, let dimension = file.dimensions {
                    var representations: [TelegramMediaImageRepresentation] = []
                    representations.append(contentsOf: file.previewRepresentations)
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimension, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
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
    
    override func contentFrame(_ item: ChatRowItem) -> NSRect {
        var rect = super.contentFrame(item)
        guard let item = item as? ChatMediaItem else {
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
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        if let item:ChatMediaItem = item as? ChatMediaItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
                
            }
           
            self.contentNode?.update(with: item.media, size: item.contentSize, context: item.context, parent:item.message, table:item.table, parameters:item.parameters, animated: animated, positionFlags: item.positionFlags, approximateSynchronousValue: item.approximateSynchronousValue)
            
            if item.isPinchable {
                self.pinchToZoom?.add(to: contentNode!, size: item.contentSize)
            } else {
                self.pinchToZoom?.remove()
            }
        }
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
        rightView.blurBackground = self.rightView.blurBackground
        rightView.layer?.cornerRadius = self.rightView.layer!.cornerRadius
        var rect = self.rightView.convert(self.rightView.bounds, to: contentNode)
        
        if contentNode.visibleRect.minY < rect.midY && contentNode.visibleRect.minY + contentNode.visibleRect.height > rect.midY {
            rect.origin.y = contentNode.frame.height - rect.maxY
            rightView.frame = rect
            view.addSubview(rightView)
        }
        
        
        contentNode.addAccesoryOnCopiedView(view: view)
    }

}



