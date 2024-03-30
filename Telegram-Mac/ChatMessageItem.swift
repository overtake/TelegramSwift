//
//  ChatMessageItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppVideoServices
import Postbox
import SwiftSignalKit
import InAppSettings
import TGModernGrowingTextView
import Strings
import InputView
import ColorPalette
import CodeSyntax


struct ChatTextCustomEmojiAttribute : Equatable {
  
    let fileId: Int64
    let file: TelegramMediaFile?
    let emoji: String
    let color: NSColor?
    init(fileId: Int64, file: TelegramMediaFile?, emoji: String, color: NSColor? = nil) {
        self.fileId = fileId
        self.emoji = emoji
        self.file = file
        self.color = color
    }
}


final class InlineStickerItem : Hashable {
    
    enum Source : Equatable {
        case attribute(ChatTextCustomEmojiAttribute)
        case reference(StickerPackItem)
    }
    
    let source: Source
    
    init(source: Source) {
        self.source = source
    }
    
    func hash(into hasher: inout Hasher) {
        switch source {
        case let .attribute(emoji):
            hasher.combine(emoji.fileId)
        case let .reference(sticker):
            hasher.combine(sticker.file.fileId.id)
        }
    }
    
    
    static func ==(lhs: InlineStickerItem, rhs: InlineStickerItem) -> Bool {
        if lhs.source != rhs.source {
            return false
        }
        return true
    }
    
    static func apply(to attr: NSMutableAttributedString, associatedMedia: [MediaId : Media], entities: [MessageTextEntity], isPremium: Bool, ignoreSpoiler: Bool = false, offset: Int = 0) {
        let copy = attr
    
        
        var ranges: [NSRange] = []
        if ignoreSpoiler {
            for entity in entities.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
                guard case .Spoiler = entity.type else {
                    continue
                }
                let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                ranges.append(range)
            }
        }
                
        
        for entity in entities.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            guard case let .CustomEmoji(_, fileId) = entity.type else {
                continue
            }
            
            let lower = entity.range.lowerBound + offset
            let upper = entity.range.upperBound + offset

            let range = NSRange(location: lower, length: upper - lower)
            
            
            let intersection = ranges.first(where: { r in
                return r.intersection(range) != nil
            })
            if intersection == nil {
                let textRange = NSMakeRange(0, copy.string.length)
                if let range = textRange.intersection(range) {
                    let currentDict = copy.attributes(at: range.lowerBound, effectiveRange: nil)
                    var updatedAttributes: [NSAttributedString.Key: Any] = currentDict
                    let text = copy.string.nsstring.substring(with: range).fixed
                    updatedAttributes[TextInputAttributes.embedded] = InlineStickerItem(source: .attribute(.init(fileId: fileId, file: associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile, emoji: text)))
                    
                    let insertString = NSAttributedString(string: clown, attributes: updatedAttributes)
                    copy.replaceCharacters(in: range, with: insertString)

                }
            }
        }
    }
}



class ChatMessageItem: ChatRowItem {
    public private(set) var messageText:NSAttributedString
    public private(set) var textLayout:TextViewLayout
    
    private let youtubeExternalLoader = MetaDisposable()
    
    override var selectableLayout:[TextViewLayout] {
        return [textLayout]
    }
    
    var isFragmentAd: Bool {
        if let adAttribute = message?.adAttribute {
            return adAttribute.canReport
        } else {
            return false
        }
    }
    
    var webpageAboveContent: Bool {
        if let attr = message?.webpagePreviewAttribute, self.webpageLayout != nil {
            if attr.leadingPreview {
                return true
            }
        }
        return false
    }
    
    override func tableViewDidUpdated() {
        webpageLayout?.table = self.table
    }
    
    override var isSharable: Bool {
        if let webpage = webpageLayout {
            if webpage.content.type == "proxy" {
                return true
            }
        }
        return super.isSharable
    }
    
    override var isBubbleFullFilled: Bool {
        return containsBigEmoji || super.isBubbleFullFilled
    }
    
    override var isStateOverlayLayout: Bool {
        return containsBigEmoji && renderType == .bubble || super.isStateOverlayLayout
    }
    
    override var bubbleContentInset: CGFloat {
        return containsBigEmoji && renderType == .bubble ? 0 : super.bubbleContentInset
    }
    
    override var defaultContentTopOffset: CGFloat {
        if isBubbled && !hasBubble {
            return 2
        }
        return super.defaultContentTopOffset
    }
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        if isBubbled, isAdRow {
            offset.y += 2
        }
        return offset
    }

    override var height: CGFloat {
        var height = super.height
        if isBubbled, isAdRow {
            height += 3
        }
        return height
    }
    
    override var hasBubble: Bool {
        get {
            if containsBigEmoji {
                return false
            } else {
                return super.hasBubble
            }
        }
        set {
            super.hasBubble = newValue
        }
    }
    
    let containsBigEmoji: Bool
    

    override var isBigEmoji: Bool {
        return containsBigEmoji
    }
    
    var actionButtonWidth: CGFloat {
        if let webpage = webpageLayout {
            if webpage.isTheme {
                return webpage.size.width
            }
        } else if message?.adAttribute != nil {
            if isBubbled {
                return bubbleFrame.width - bubbleDefaultInnerInset
            }
        }
        
        return self.contentSize.width
    }
    
    var hasExternalLink: Bool {
        if let adAtribute = message?.adAttribute {
            if case .webPage = adAtribute.target {
                return true
            } else {
                return false
            }
        }
        return false
    }
    
    var actionButtonText: String? {
        
        if unsupported {
            return strings().chatUnsupportedUpdatedApp
        }
        
        return nil
    }
    
    override var isEditMarkVisible: Bool {
        return super.isEditMarkVisible
    }
    
    func invokeAction() {
        if let webpage = webpageLayout {
            let link = inApp(for: webpage.content.url.nsstring, context: context, messageId: message?.id, openInfo: chatInteraction.openInfo)
            execute(inapp: link)
        } else if unsupported {
            #if APP_STORE
            execute(inapp: inAppLink.external(link: "https://apps.apple.com/us/app/telegram/id747648890", false))
            #else
            (NSApp.delegate as? AppDelegate)?.checkForUpdates("")
            #endif
        }
    }
    
    let wpPresentation: WPLayoutPresentation
    
    var webpageLayout:WPLayout?
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction,_ context: AccountContext, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
         if let message = entry.message {
             
            
            let isIncoming: Bool = message.isIncoming(context.account, entry.renderType == .bubble)

            var openSpecificTimecodeFromReply:((Double?)->Void)? = nil
            
             
             var text: String = message.text
             var attributes: [MessageAttribute] = message.attributes
             if let translate = entry.additionalData.translate {
                 switch translate {
                 case .loading:
                     self.isTranslateLoading = true
                 case let .complete(toLang: toLang):
                     if let attribute = message.translationAttribute(toLang: toLang) {
                         text = attribute.text
                         attributes = [TextEntitiesMessageAttribute(entities: attribute.entities)]
                     }
                 }
             }
             
            let messageAttr:NSMutableAttributedString
            if message.inlinePeer == nil, message.text.isEmpty && (message.media.isEmpty || message.anyMedia is TelegramMediaUnsupported) {
                let attr = NSMutableAttributedString()
                _ = attr.append(string: strings().chatMessageUnsupportedNew, color: theme.chat.textColor(isIncoming, entry.renderType == .bubble), font: .code(theme.fontSize))
                messageAttr = attr
            } else {
                
                var mediaDuration: Double? = nil
                var mediaDurationMessage:Message?
                
                var canAssignToReply: Bool = true
                
                if let media = message.anyMedia as? TelegramMediaWebpage {
                    switch media.content {
                    case let .Loaded(content):
                        canAssignToReply = !ExternalVideoLoader.isPlayable(content)
                    default:
                        break
                    }
                }
                
                if canAssignToReply, let reply = message.replyAttribute  {
                    mediaDurationMessage = message.associatedMessages[reply.messageId]
                } else {
                    mediaDurationMessage = message
                }
                if let message = mediaDurationMessage {
                    if let file = message.anyMedia as? TelegramMediaFile, file.isVideo && !file.isAnimated, let duration = file.duration {
                        mediaDuration = Double(duration)
                    } else if let media = message.anyMedia as? TelegramMediaWebpage {
                        switch media.content {
                        case let .Loaded(content):
                            if ExternalVideoLoader.isPlayable(content) {
                                mediaDuration = 10 * 60 * 60
                            }
                        default:
                            break
                        }
                    }
                }
                
                let openInfo:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void = { [weak chatInteraction] peerId, toChat, postId, initialAction in
                    chatInteraction?.openInfo(peerId, toChat, postId, initialAction ?? .source(message.id))
                }
                
                messageAttr = ChatMessageItem.applyMessageEntities(with: attributes, for: text, message: message, context: context, fontSize: theme.fontSize, openInfo:openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.context.bindings.globalSearch, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, entry.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), mediaDuration: mediaDuration, timecode: { timecode in
                    openSpecificTimecodeFromReply?(timecode)
                }, blockColor: theme.chat.blockColor(context.peerNameColors, message: message, isIncoming: message.isIncoming(context.account, entry.renderType == .bubble), bubbled: entry.renderType == .bubble), isDark: theme.colors.isDark, bubbled: entry.renderType == .bubble).mutableCopy() as! NSMutableAttributedString
                
             }
             
            let copy = messageAttr.mutableCopy() as! NSMutableAttributedString
             

            if let peer = message.peers[message.id.peerId] {
                if peer is TelegramSecretChat {
                    copy.detectLinks(type: [.Links, .Mentions], context: context, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), openInfo: chatInteraction.openInfo)
                }
            }

            let containsBigEmoji: Bool
            if message.anyMedia == nil, bigEmojiMessage(context.sharedContext, message: message) {
                containsBigEmoji = true
                switch copy.string.count {
                case 1:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 8), range: copy.range)
                case 2:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 7), range: copy.range)
                case 3:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 6), range: copy.range)
                case 4:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 5), range: copy.range)
                case 5:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 4), range: copy.range)
                case 6:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 3), range: copy.range)
                default:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 2), range: copy.range)
                }
            } else {
                containsBigEmoji = false
            }
            
            self.containsBigEmoji = containsBigEmoji
             
            
            if message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
                copy.detectLinks(type: [.Links, .Mentions, .Hashtags, .Commands], context: context, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), openInfo: chatInteraction.openInfo, hashtag: { _ in }, command: { _ in }, applyProxy: chatInteraction.applyProxy)
            }
           
           
             var spoilers:[TextViewLayout.Spoiler] = []
             for attr in attributes {
                 if let attr = attr as? TextEntitiesMessageAttribute {
                     for entity in attr.entities {
                         switch entity.type {
                         case .Spoiler:
                             let range = NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound)
                             if let range = copy.range.intersection(range) {
                                 copy.addAttribute(TextInputAttributes.spoiler, value: true as NSNumber, range: range)
                             }
                         default:
                             break
                         }
                     }
                 }
             }
             InlineStickerItem.apply(to: copy, associatedMedia: message.associatedMedia, entities: attributes.compactMap{ $0 as? TextEntitiesMessageAttribute }.first?.entities ?? [], isPremium: context.isPremium)

//             copy.fixUndefinedEmojies()

             
             
             

             copy.enumerateAttribute(TextInputAttributes.spoiler, in: copy.range, options: .init(), using: { value, range, stop in
                 if let _ = value {
                     let color: NSColor
                     if entry.renderType == .bubble {
                         color = theme.chat.grayText(isIncoming, entry.renderType == .bubble)
                     } else {
                         color = theme.chat.textColor(isIncoming, entry.renderType == .bubble)
                     }
                     spoilers.append(.init(range: range, color: color, isRevealed: chatInteraction.presentation.interfaceState.revealedSpoilers.contains(message.id)))
                 }
             })
             
             copy.removeWhitespaceFromQuoteAttribute()

             
             if let ad = message.adAttribute {
                 messageText = .init()
             } else  if let text = message.restrictedText(context.contentSettings) {
                 self.messageText = .initialize(string: text, color: theme.colors.grayText, font: .italic(theme.fontSize))
             } else {
                 self.messageText = copy
             }
             
             textLayout = TextViewLayout(self.messageText, selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), strokeLinks: entry.renderType == .bubble && !containsBigEmoji, alwaysStaticItems: true, disableTooltips: false, mayItems: !message.isCopyProtected(), spoilers: spoilers, onSpoilerReveal: { [weak chatInteraction] in
                 chatInteraction?.update({
                     $0.updatedInterfaceState({
                         $0.withRevealedSpoiler(message.id)
                     })
                 })
             })
            textLayout.mayBlocked = true//entry.renderType = .bubble
            
            if let highlightFoundText = entry.additionalData.highlightFoundText {
                let string = copy.string.lowercased()
                let subranges = findSubstringRanges(in: string, query: highlightFoundText.query.lowercased())
                
                for subrange in subranges.0 {
                    let range = NSRange(string: string, range: subrange)
                    textLayout.additionalSelections.append(TextSelectedRange(range: range, color: theme.colors.accentIcon.withAlphaComponent(0.5), def: false))
                }
                
            }
            if let range = selectManager.find(entry.stableId) {
                textLayout.selectedRange.range = range
            }
             
            
            
            var media = message.anyMedia
            if let game = media as? TelegramMediaGame {
                media = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: TelegramMediaWebpageContent.Loaded(TelegramMediaWebpageLoadedContent(url: "", displayUrl: "", hash: 0, type: "photo", websiteName: game.name, title: game.name, text: game.description, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, image: game.image, file: game.file, story: nil, attributes: [], instantPage: nil)))
            }
            
             self.wpPresentation = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, entry.renderType == .bubble), activity: theme.chat.webPreviewActivity(context.peerNameColors, message: message, account: context.account, bubbled: entry.renderType == .bubble), link: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, entry.renderType == .bubble, presentation: theme), renderType: entry.renderType, pattern: theme.chat.webPreviewPattern(entry.message))

            
            if let webpage = media as? TelegramMediaWebpage {
                switch webpage.content {
                case let .Loaded(content):
                    var content = content
                    var forceArticle: Bool = false
                    if let instantPage = content.instantPage {
                        if instantPage.blocks.count == 3 {
                            switch instantPage.blocks[2] {
                            case .collage, .slideshow:
                                forceArticle = true
                            default:
                                break
                            }
                        }
                    }
                    if content.type == "telegram_background" {
                        forceArticle = true
                    }
                    
                    if let story = content.story, let media = message.associatedStories[story.storyId]?.get(Stories.StoredItem.self) {
                        switch media {
                        case let .item(story):
                            if let image = story.media as? TelegramMediaImage {
                                content = content.withUpdatedImage(image)
                            } else if let file = story.media as? TelegramMediaFile {
                                content = content.withUpdatedFile(file)
                            }
                        default:
                            break
                        }
                    }
                    
                    if content.file == nil || forceArticle, content.story == nil {
                        webpageLayout = WPArticleLayout(with: content, context: context, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: !message.isCopyProtected())
                    } else if content.file != nil || content.image != nil {
                        webpageLayout = WPMediaLayout(with: content, context: context, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: !message.isCopyProtected())
                    }
                default:
                    break
                }
            } else if let adAttribute = message.adAttribute {
                self.webpageLayout = WPArticleLayout(with: .init(url: "", displayUrl: "", hash: 0, type: "telegram_ad", websiteName: adAttribute.messageType == .recommended ? strings().chatMessageRecommendedTitle : strings().chatMessageSponsoredTitle, title: message.author?.displayTitle ?? "", text: message.text, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, image: message.media.first as? TelegramMediaImage, file: message.media.first as? TelegramMediaFile, story: nil, attributes: [], instantPage: nil), context: context, chatInteraction: chatInteraction, parent: message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: true, entities: message.textEntities?.entities, adAttribute: adAttribute)
            }
            
            super.init(initialSize, chatInteraction, context, entry, downloadSettings, theme: theme)
            
            
            (webpageLayout as? WPMediaLayout)?.parameters?.showMedia = { [weak self] message in
                if let webpage = message.media.first as? TelegramMediaWebpage {
                    switch webpage.content {
                    case let .Loaded(content):
                        if content.embedType == "iframe" && content.type != kBotInlineTypeGif, let url = content.embedUrl {
                            showModal(with: WebpageModalController(context: context, url: url, title: content.websiteName ?? content.title ?? strings().webAppTitle, effectiveSize: content.embedSize?.size, chatInteraction: self?.chatInteraction), for: context.window)
                            return
                        }
                        if let story = content.story {
                            self?.chatInteraction.openStory(message.id, story.storyId)
                            return
                        }
                    default:
                        break
                    }
                } else if let keybaord = message.replyMarkup {
                    if let button = keybaord.rows.first?.buttons.first {
                        switch button.action {
                        case .openWebApp:
                            self?.chatInteraction.requestMessageActionCallback(message.id, true, nil)
                            return
                        default:
                            break
                        }
                    }
                }
                showChatGallery(context: context, message: message, self?.table, (self?.webpageLayout as? WPMediaLayout)?.parameters, type: .alone)
            }
            
            openSpecificTimecodeFromReply = { [weak self] timecode in
                if let timecode = timecode {
                    var canAssignToReply: Bool = true
                    if let media = message.anyMedia as? TelegramMediaWebpage {
                        switch media.content {
                        case let .Loaded(content):
                            canAssignToReply = !ExternalVideoLoader.isPlayable(content)
                        default:
                            break
                        }
                    }
                    var assignMessage: Message?
                     if canAssignToReply, let reply = message.replyAttribute  {
                        assignMessage = message.associatedMessages[reply.messageId]
                    } else {
                        assignMessage = message
                    }
                    if let message = assignMessage {
                        let id = ChatHistoryEntryId.message(message)
                        if let item = self?.table?.item(stableId: id) as? ChatMediaItem {
                            item.parameters?.set_timeCodeInitializer(timecode)
                            item.parameters?.showMedia(message)
                        } else if let groupInfo = message.groupInfo {
                            let id = ChatHistoryEntryId.groupedPhotos(groupInfo: groupInfo)
                            if let item = self?.table?.item(stableId: id) as? ChatGroupedItem {
                                item.parameters.first?.set_timeCodeInitializer(timecode)
                                item.parameters.first?.showMedia(message)
                            }
                        } else if let item = self?.table?.item(stableId: id) as? ChatMessageItem {
                            if let content = item.webpageLayout?.content {
                                let content = content.withUpdatedYoutubeTimecode(timecode)
                                execute(inapp: .external(link: content.url, false))
                            }
                        }
                    }
                }
            }
            
            let interactions: TextViewInteractions = globalLinkExecutor
            if let adAttribute = message.adAttribute {
                interactions.processURL = { [weak chatInteraction] link in
                    chatInteraction?.markAdAction(adAttribute.opaqueId)
                    globalLinkExecutor.processURL(link)
                }
            }
            interactions.copy = {
                selectManager.copy(selectManager)
                return !selectManager.isEmpty
            }
            interactions.copyToClipboard = { text in
                copyToClipboard(text)
            }
            interactions.topWindow = { [weak self] in
                if let strongSelf = self {
                    return strongSelf.menuAdditionView
                } else {
                    return .single(nil)
                }
            }
            interactions.menuItems = { [weak self] type in
                if let strongSelf = self, let message = strongSelf.message {
                    return chatMenuItems(for: message, entry: strongSelf.entry, textLayout: (strongSelf.textLayout, type), chatInteraction: strongSelf.chatInteraction)
                }
                return .complete()
            }
            
            interactions.hoverOnLink = { value in
                
            }
            
            textLayout.interactions = interactions
            
            return
        }
        
        fatalError("entry has not message")
    }

    
    override var ignoreAtInitialization: Bool {
        return message?.adAttribute != nil
    }
    
    override var isForceRightLine: Bool {
        if actionButtonText != nil  {
            return true
        }
        if textLayout.lastLineIsRtl {
            return true
        }
        if let _ = webpageLayout, !webpageAboveContent || messageText.string.isEmpty {
             return true
        }
        return super.isForceRightLine
    }
    
    
    override var min_block_width: CGFloat {
        if webpageLayout != nil {
            return 340
        } else {
            return super.min_block_width
        }
    }
    
    
    private(set) var isTranslateLoading: Bool = false
    private(set) var block: (NSPoint, CGImage?) = (.zero, nil)
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        let size:NSSize = super.makeContentSize(width)
     
        webpageLayout?.measure(width: width)
        
        
        
        var textBlockWidth: CGFloat = isBubbled ? min(webpageLayout?.size.width ?? width, width) : width
        if textLayout.hasBlockQuotes {
            textBlockWidth -= 40
        }
        textLayout.measure(width: textBlockWidth, isBigEmoji: containsBigEmoji)
        if isTranslateLoading {
            self.block = textLayout.generateBlock(backgroundColor: .blackTransparent)
        } else {
            self.block = (.zero, nil)
        }
        
        var contentSize = NSMakeSize(max(webpageLayout?.size.width ?? 0, textLayout.layoutSize.width), size.height + textLayout.layoutSize.height)
        
        if let webpageLayout = webpageLayout {
            contentSize.height += webpageLayout.size.height + defaultContentInnerInset
            contentSize.width = max(webpageLayout.size.width, contentSize.width)
            
        }
        if let _ = actionButtonText {
            contentSize.height += actionButtonHeight
            contentSize.width = max(contentSize.width, 200)
        }
        
        
        return contentSize
    }
    
    
    
    var actionButtonHeight: CGFloat {
        return 36
    }
    
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var bubbleFrame: NSRect {
        var frame = super.bubbleFrame
        
        
        
        if isBubbleFullFilled {
            frame.size.width = contentSize.width + additionBubbleInset
            return frame
        }
        
        if replyMarkupModel != nil, webpageLayout == nil, textLayout.layoutSize.width < 200 {
            frame.size.width = max(blockWidth, frame.width)
        }
                
        return frame
    }
    
   
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if let message = message {
            return chatMenuItems(for: message, entry: entry, textLayout: (self.textLayout, nil), chatInteraction: self.chatInteraction)
        }
        return super.menuItems(in: location)
        
    }
    
    deinit {
        youtubeExternalLoader.dispose()
    }
    
    override func viewClass() -> AnyClass {
        return ChatMessageView.self
    }
    
    static func applyMessageEntities(with attributes:[MessageAttribute], for text:String, message: Message?, context: AccountContext, fontSize: CGFloat, openInfo:@escaping (PeerId, Bool, MessageId?, ChatInitialAction?)->Void, botCommand:@escaping (String)->Void = { _ in }, hashtag:@escaping (String)->Void = { _ in }, applyProxy:@escaping (ProxyServerSettings)->Void = { _ in }, textColor: NSColor = theme.colors.text, linkColor: NSColor = theme.colors.link, monospacedPre:NSColor = theme.colors.monospacedPre, monospacedCode: NSColor = theme.colors.monospacedCode, mediaDuration: Double? = nil, timecode: @escaping(Double?)->Void = { _ in }, openBank: @escaping(String)->Void = { _ in }, underlineLinks: Bool = false, blockColor: PeerNameColors.Colors = .init(main: theme.colors.accent), isDark: Bool, bubbled: Bool) -> NSAttributedString {
        var entities: [MessageTextEntity] = []
        for attribute in attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                entities = attribute.entities
                break
            }
        }
        
        var fontAttributes: [(NSRange, ChatTextFontAttributes)] = []
        

        
        let string = NSMutableAttributedString(string: text, attributes: [NSAttributedString.Key.font: NSFont.normal(fontSize), NSAttributedString.Key.foregroundColor: textColor])
        
        let new = addLocallyGeneratedEntities(text, enabledTypes: [.timecode], entities: entities, mediaDuration: mediaDuration)
        var nsString: NSString?
        entities = entities + (new ?? [])
        
        entities = concatMessageAttributes(entities)
        
        for entity in entities {
            let r = string.trimRange(NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
            
            guard let range = string.range.intersection(r) else {
                continue
            }
            
            switch entity.type {
            case .Url:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                let link = inApp(for:nsString!.substring(with: range) as NSString, context:context, messageId: message?.id, openInfo:openInfo, applyProxy: applyProxy)
                string.addAttribute(NSAttributedString.Key.link, value: link, range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
                }
            case .Email:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.external(link: "mailto:\(nsString!.substring(with: range))", false), range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
                }
            case let .TextUrl(url):
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inApp(for: url as NSString, context: context, messageId: message?.id, openInfo: openInfo, hashtag: hashtag, command: botCommand,  applyProxy: applyProxy, confirm: nsString?.substring(with: range).trimmed != url), range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
                }
                string.addAttribute(TextInputAttributes.textUrl, value: TextInputTextUrlAttribute(url: url), range: range)
            case .Bold:
                fontAttributes.append((range, .bold))
                string.addAttribute(TextInputAttributes.bold, value: true as NSNumber, range: range)
            case .Italic:
                fontAttributes.append((range, .italic))
                string.addAttribute(TextInputAttributes.italic, value: true as NSNumber, range: range)
            case .Mention:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.followResolvedName(link: nsString!.substring(with: range), username: nsString!.substring(with: range), postId:nil, context:context, action:nil, callback: openInfo), range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
                }
            case let .TextMention(peerId):
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.peerInfo(link: "", peerId: peerId, action:nil, openChat: false, postId: nil, callback: openInfo), range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
                }
                string.addAttribute(TextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: peerId), range: range)

            case .BotCommand:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.botCommand(nsString!.substring(with: range), botCommand), range: range)
            case .Code:
//                string.addAttribute(.preformattedPre, value: 4.0, range: range)
                fontAttributes.append((range, .monospace))

                string.addAttribute(NSAttributedString.Key.foregroundColor, value: monospacedCode, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.code(text.nsstring.substring(with: range), {  link in
                    copyToClipboard(link)
                    context.bindings.showControllerToaster(ControllerToaster(text: strings().shareLinkCopied), true)
                }), range: range)
                string.addAttribute(TextInputAttributes.monospace, value: true as NSNumber, range: range)
            case let .Pre(language: language):
                
                var lg: String = language ?? ""
                
                if lg.isEmpty {
                    lg = strings().contextCopy.lowercased()
                }
                let isIncoming = message?.isIncoming(context.account, bubbled) ?? false
                let color = theme.chat.activityColor(isIncoming, bubbled)

                
                let header: (TextNodeLayout, TextNode)?
                header = TextNode.layoutText(.initialize(string: lg.prefixWithDots(15), color: color, font: .medium(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
                
                string.addAttribute(TextInputAttributes.quote, value: TextViewBlockQuoteData(id: Int(arc4random64()), colors: .init(main: color, secondary: nil, tertiary: color), isCode: true, space: 4, header: header), range: range)
                fontAttributes.append((range, .monospace))
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: monospacedPre, range: range)
                string.addAttribute(TextInputAttributes.monospace, value: true as NSNumber, range: range)
                
                
                if let language = language?.lowercased() {
                    let code = string.attributedSubstring(from: range).string
                    let syntaxed = CodeSyntax.syntax(code: code, language: language, theme: .init(dark: isDark, textColor: textColor, textFont: .code(fontSize), italicFont: .italicMonospace(fontSize), mediumFont: .semiboldMonospace(fontSize)))
                    CodeSyntax.apply(syntaxed, to: string, offset: range.location)
                }
                
//                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.code(text.nsstring.substring(with: range), { link in
//                    copyToClipboard(link)
//                    context.bindings.showControllerToaster(ControllerToaster(text: strings().shareLinkCopied), true)
//                }), range: range)
                
            case .Hashtag:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.hashtag(nsString!.substring(with: range), hashtag), range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
                }
            case .Strikethrough:
                string.addAttribute(NSAttributedString.Key.strikethroughStyle, value: true, range: range)
                string.addAttribute(TextInputAttributes.strikethrough, value: true as NSNumber, range: range)
            case .Underline:
                string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
                string.addAttribute(TextInputAttributes.underline, value: true as NSNumber, range: range)
            case .BankCard:
                if nsString == nil {
                    nsString = text as NSString
                }
                 string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.callback(nsString!.substring(with: range), { bankCard in
                    openBank(bankCard)
                }), range: range)
            case .BlockQuote:
                string.addAttribute(TextInputAttributes.quote, value: TextViewBlockQuoteData(id: Int(arc4random64()), colors: blockColor, space: 4), range: range)
            case let .CustomEmoji(_, fileId: fileId):
                string.addAttribute(TextInputAttributes.customEmoji, value: TextInputTextCustomEmojiAttribute(fileId: fileId, file: nil, emoji: string.attributedSubstring(from: range).string), range: range)
            case let .Custom(type):
                if type == ApplicationSpecificEntityType.Timecode {
                    string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    let code = parseTimecodeString(nsString!.substring(with: range))
                    
                    var link = ""
                    if let message = message {
                        var peer: Peer?
                        var messageId: MessageId?
                        if let info = message.forwardInfo {
                            peer = info.author
                            messageId = info.sourceMessageId
                        } else {
                            peer = message.effectiveAuthor
                            messageId = message.id
                        }
                        if let peer = peer, let messageId = messageId {
                            if let code = code, peer.isChannel || peer.isSupergroup {
                                let code = Int(round(code))
                                let address = peer.addressName ?? "\(messageId.peerId.id)"
                                link = "t.me/\(address)/\(messageId.id)?t=\(code)"
                            }
                        }
                    }
                    
                    string.addAttribute(NSAttributedString.Key.link, value: inAppLink.callback(link, { _ in
                        timecode(code)
                    }), range: range)

                }
            default:
                break
            }
        }
        for (i, (range, attr)) in fontAttributes.enumerated() {
            var font: NSFont?
            var intersects:[(NSRange, ChatTextFontAttributes)] = []
            
            for (j, value) in fontAttributes.enumerated() {
                if j != i {
                    if let intersection = value.0.intersection(range) {
                        intersects.append((intersection, value.1))
                    }
                }
            }
                        
            switch attr {
            case .monospace, .blockQuote:
                font = .code(fontSize)
            case .italic:
                font = .italic(fontSize)
            case .bold:
                font = .bold(fontSize)
            default:
                break
            }
            if let font = font {
                string.addAttribute(.font, value: font, range: range)
            }
            
             for intersect in intersects {
                 var font: NSFont? = nil
                 loop: switch intersect.1 {
                 case .italic:
                     switch attr {
                     case .bold:
                         font = .boldItalic(fontSize)
                     default:
                         break loop
                     }
                 case .bold:
                    switch attr {
                    case .bold:
                        font = .boldItalic(fontSize)
                    default:
                        break loop
                    }
                 default:
                     break loop
                     
                 }
                 if let font = font {
                     string.addAttribute(.font, value: font, range: range)
                 }
             }
        }
        return string.copy() as! NSAttributedString
    }
}


/*
 if let color = NSColor(hexString: nsString!.substring(with: range)) {
     
     struct RunStruct {
         let ascent: CGFloat
         let descent: CGFloat
         let width: CGFloat
     }
     
     let dimensions = NSMakeSize(theme.fontSize + 6, theme.fontSize + 6)
     let extentBuffer = UnsafeMutablePointer<RunStruct>.allocate(capacity: 1)
     extentBuffer.initialize(to: RunStruct(ascent: 0.0, descent: 0.0, width: dimensions.width))
     var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { (pointer) in
     }, getAscent: { (pointer) -> CGFloat in
         let d = pointer.assumingMemoryBound(to: RunStruct.self)
         return d.pointee.ascent
     }, getDescent: { (pointer) -> CGFloat in
         let d = pointer.assumingMemoryBound(to: RunStruct.self)
         return d.pointee.descent
     }, getWidth: { (pointer) -> CGFloat in
         let d = pointer.assumingMemoryBound(to: RunStruct.self)
         return d.pointee.width
     })
     let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)
     let key = kCTRunDelegateAttributeName as String
     let attrDictionaryDelegate:[NSAttributedString.Key : Any] = [NSAttributedString.Key(key): delegate as Any, .hexColorMark : color, .hexColorMarkDimensions: dimensions]
     
     string.addAttributes(attrDictionaryDelegate, range: NSMakeRange(range.upperBound - 1, 1))
 }
 */
