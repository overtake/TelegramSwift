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
import TelegramMedia


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
        case avatar(EnginePeer)
    }
    
    let source: Source
    let playPolicy: LottiePlayPolicy?
    init(source: Source, playPolicy: LottiePlayPolicy? = nil) {
        self.source = source
        self.playPolicy = playPolicy
    }
    
    func hash(into hasher: inout Hasher) {
        switch source {
        case let .attribute(emoji):
            hasher.combine(emoji.fileId)
        case let .reference(sticker):
            hasher.combine(sticker.file.fileId.id)
        case let .avatar(peer):
            hasher.combine(peer.id)
        }
    }
    
    
    static func ==(lhs: InlineStickerItem, rhs: InlineStickerItem) -> Bool {
        if lhs.source != rhs.source {
            return false
        }
        return true
    }
    
    static func apply(to attr: NSMutableAttributedString, associatedMedia: [MediaId : Media], entities: [MessageTextEntity], isPremium: Bool, ignoreSpoiler: Bool = false, offset: Int = 0, playPolicy: LottiePlayPolicy? = nil) {
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
                    updatedAttributes[TextInputAttributes.embedded] = InlineStickerItem(source: .attribute(.init(fileId: fileId, file: associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile, emoji: text)), playPolicy: playPolicy)
                    
                    let insertString = NSAttributedString(string: clown, attributes: updatedAttributes)
                    copy.replaceCharacters(in: range, with: insertString)

                }
            }
        }
    }
}



class ChatMessageItem: ChatRowItem {
    public private(set) var messageText:NSAttributedString
    public private(set) var textLayout: FoldingTextLayout
        
    
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
            let inapp = inApp(for: adAtribute.url.nsstring, context: context)
            switch inapp {
            case .external:
                return true
            default:
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
            execute(inapp: inAppLink.external(link: itunesAppLink, false))
            #else
            (NSApp.delegate as? AppDelegate)?.checkForUpdates("")
            #endif
        }
    }
    
    
    private(set) var webpageLayout:WPLayout?
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction,_ context: AccountContext, _ entry: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        
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
                    chatInteraction?.openInfo(peerId, toChat, postId, toChat ? (initialAction ?? .source(message.id, nil)) : nil)
                }
                
                messageAttr = ChatMessageItem.applyMessageEntities(with: attributes, for: text, message: message, context: context, fontSize: theme.fontSize, openInfo:openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.hashtag, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, entry.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), mediaDuration: mediaDuration, timecode: { timecode in
                    openSpecificTimecodeFromReply?(timecode)
                }, blockColor: theme.chat.blockColor(context.peerNameColors, message: message, isIncoming: isIncoming, bubbled: entry.renderType == .bubble), isDark: theme.colors.isDark, bubbled: entry.renderType == .bubble, codeSyntaxData: entry.additionalData.codeSyntaxData, loadCodeSyntax: chatInteraction.enqueueCodeSyntax, openPhoneNumber: chatInteraction.openPhoneNumberContextMenu, ignoreLinks: !entry.additionalData.canHighlightLinks && isIncoming).mutableCopy() as! NSMutableAttributedString
                
             }
             
            let copy = messageAttr.mutableCopy() as! NSMutableAttributedString
             

            if let peer = message.peers[message.id.peerId] {
                if peer is TelegramSecretChat {
                    copy.detectLinks(type: [.Links, .Mentions], context: context, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), openInfo: chatInteraction.openInfo)
                }
            }

            let containsBigEmoji: Bool
             if message.anyMedia == nil, bigEmojiMessage(context.sharedContext, message: message), entry.additionalData.eventLog == nil {
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
           
           
             
             InlineStickerItem.apply(to: copy, associatedMedia: message.associatedMedia, entities: attributes.compactMap{ $0 as? TextEntitiesMessageAttribute }.first?.entities ?? [], isPremium: context.isPremium)

//             copy.fixUndefinedEmojies()

             
             
             
             let spoilerColor: NSColor
             if entry.renderType == .bubble {
                 spoilerColor = theme.chat.grayText(isIncoming, entry.renderType == .bubble)
             } else {
                 spoilerColor = theme.chat.textColor(isIncoming, entry.renderType == .bubble)
             }
             let isSpoilerRevealed = chatInteraction.presentation.interfaceState.revealedSpoilers.contains(message.id)
             
             copy.removeWhitespaceFromQuoteAttribute()

             
             if let _ = message.adAttribute {
                 messageText = .init()
             } else  if let text = message.restrictedText(context.contentSettings) {
                 self.messageText = .initialize(string: text, color: theme.colors.grayText, font: .italic(theme.fontSize))
             } else {
                 self.messageText = copy
             }
             
             
             textLayout = FoldingTextLayout.make(self.messageText, context: context, revealed: entry.additionalData.quoteRevealed, takeLayout: { string in
                 let textLayout = TextViewLayout(string, selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), strokeLinks: entry.renderType == .bubble && !containsBigEmoji, alwaysStaticItems: true, disableTooltips: false, mayItems: !message.isCopyProtected(), spoilerColor: spoilerColor, isSpoilerRevealed: isSpoilerRevealed, onSpoilerReveal: { [weak chatInteraction] in
                     chatInteraction?.update({
                         $0.updatedInterfaceState({
                             $0.withRevealedSpoiler(message.id)
                         })
                     })
                 })
                 textLayout.mayBlocked = true
               
                 if let highlightFoundText = entry.additionalData.highlightFoundText {
                    if let range = rangeOfSearch(highlightFoundText.query, in: string.string) {
                        textLayout.additionalSelections = [TextSelectedRange(range: range, color: theme.colors.accentIcon.withAlphaComponent(0.5), def: false)]
                    }
                 }
                
                 return textLayout
             })
             
             textLayout.applyRanges(selectManager.findAll(entry.stableId))

            
            var media = message.anyMedia
            if let game = media as? TelegramMediaGame {
                media = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: TelegramMediaWebpageContent.Loaded(TelegramMediaWebpageLoadedContent(url: "", displayUrl: "", hash: 0, type: "photo", websiteName: game.name, title: game.name, text: game.description, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: game.image, file: game.file, story: nil, attributes: [], instantPage: nil)))
            }
                        
            
            super.init(initialSize, chatInteraction, context, entry, theme: theme)
            
             let ignoreWebpage = !entry.additionalData.canHighlightLinks && isIncoming
            
             if let webpage = media as? TelegramMediaWebpage, !ignoreWebpage {
                 switch webpage.content {
                 case let .Loaded(content):
                     var content = content
                     var forceArticle: Bool = false
                     if let instantPage = content.instantPage?._parse() {
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
                     var uniqueGift: StarGift.UniqueGift? = nil
                     for attribute in content.attributes {
                         switch attribute {
                         case let .starGift(gift):
                             switch gift.gift {
                             case let .unique(gift):
                                 uniqueGift = gift
                             default:
                                 break
                             }
                         default:
                             break
                         }
                     }
                     
                     if content.file == nil || forceArticle, content.story == nil, uniqueGift == nil {
                         webpageLayout = WPArticleLayout(with: content, context: context, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: !message.isCopyProtected())
                     } else if content.file != nil || content.image != nil || uniqueGift != nil {
                         webpageLayout = WPMediaLayout(with: content, context: context, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: !message.isCopyProtected(), uniqueGift: uniqueGift)
                     }
                 default:
                     break
                 }
             } else if let adAttribute = message.adAttribute {
                 
                 let content: TelegramMediaWebpageLoadedContent = .init(url: "", displayUrl: "", hash: 0, type: "telegram_ad", websiteName: adAttribute.messageType == .recommended ? strings().chatMessageRecommendedTitle : strings().chatMessageSponsoredTitle, title: message.author?.displayTitle ?? "", text: message.text, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: adAttribute.hasContentMedia, imageIsVideoCover: false, image: message.media.first as? TelegramMediaImage, file: message.media.first as? TelegramMediaFile, story: nil, attributes: [], instantPage: nil)
                 
                 if adAttribute.hasContentMedia {
                     self.webpageLayout = WPMediaLayout(with: content, context: context, chatInteraction: chatInteraction, parent: message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: true, entities: message.textEntities?.entities, adAttribute: adAttribute)
                 } else {
                     self.webpageLayout = WPArticleLayout(with: content, context: context, chatInteraction: chatInteraction, parent: message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: true, entities: message.textEntities?.entities, adAttribute: adAttribute)
                 }
                 
             }
             
            (webpageLayout as? WPMediaLayout)?.parameters?.showMedia = { [weak self] message in
                if let webpage = message.media.first as? TelegramMediaWebpage {
                    switch webpage.content {
                    case let .Loaded(content):
                        if content.embedType == "iframe" && content.type != kBotInlineTypeGif, let url = content.embedUrl {
                            WebappWindow.makeAndOrderFront(WebpageModalController(context: context, url: url, title: content.websiteName ?? content.title ?? strings().webAppTitle, effectiveSize: content.embedSize?.size))
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
                showChatGallery(context: context, message: message, self?.table, (self?.webpageLayout as? WPMediaLayout)?.parameters, type: .alone, chatMode: chatInteraction.mode, chatLocation: chatInteraction.chatLocation)
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
                    chatInteraction?.markAdAction(adAttribute.opaqueId, adAttribute.hasContentMedia)
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
                    return chatMenuItems(for: message, entry: strongSelf.entry, textLayout: (strongSelf.textLayout.merged, type), chatInteraction: strongSelf.chatInteraction)
                }
                return .complete()
            }
            
            interactions.hoverOnLink = { value in
                
            }
            
            textLayout.set(interactions)
            
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
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        let size:NSSize = super.makeContentSize(width)
     
        webpageLayout?.measure(width: width)
        
        
        var textBlockWidth: CGFloat = isBubbled ? min(webpageLayout?.size.width ?? width, width) : width
       
        textLayout.measure(width: textBlockWidth, isBigEmoji: containsBigEmoji)
        if isTranslateLoading {
            textLayout.makeImageBlock(backgroundColor: .blackTransparent)
        }
        
        var contentSize = NSMakeSize(max(webpageLayout?.size.width ?? 0, textLayout.size.width), size.height + textLayout.size.height)
        
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
        
        if replyMarkupModel != nil, webpageLayout == nil, textLayout.size.width < 200 {
            frame.size.width = max(blockWidth, frame.width)
        }
                
        return frame
    }
    
   
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if let message = message {
            return chatMenuItems(for: message, entry: entry, textLayout: (self.textLayout.merged, nil), chatInteraction: self.chatInteraction)
        }
        return super.menuItems(in: location)
        
    }
    
    deinit {
    }
    
    override func viewClass() -> AnyClass {
        return ChatMessageView.self
    }
    
    static func applyMessageEntities(with attributes:[MessageAttribute], for text:String, message: Message?, context: AccountContext, fontSize: CGFloat, openInfo:@escaping (PeerId, Bool, MessageId?, ChatInitialAction?)->Void, botCommand:@escaping (String)->Void = { _ in }, hashtag:@escaping (String)->Void = { _ in }, applyProxy:@escaping (ProxyServerSettings)->Void = { _ in }, textColor: NSColor = theme.colors.text, linkColor: NSColor = theme.colors.link, monospacedPre:NSColor = theme.colors.monospacedPre, monospacedCode: NSColor = theme.colors.monospacedCode, mediaDuration: Double? = nil, timecode: @escaping(Double?)->Void = { _ in }, openBank: @escaping(String)->Void = { _ in }, underlineLinks: Bool = false, blockColor: PeerNameColors.Colors = .init(main: theme.colors.accent), isDark: Bool, bubbled: Bool, codeSyntaxData: [CodeSyntaxKey : CodeSyntaxResult] = [:], loadCodeSyntax: @escaping(MessageId, NSRange, String, String, SyntaxterTheme)->Void = { _, _, _, _, _ in }, openPhoneNumber: ((String)->Void)? = nil, confirm: Bool = true, ignoreLinks: Bool = false) -> NSAttributedString {
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
        
        entities = concatMessageAttributes(entities).filter({ entity in
            if ignoreLinks {
                switch entity.type {
                case .Url, .TextUrl, .TextMention, .Email, .PhoneNumber, .BankCard, .BotCommand, .Mention:
                    return false
                default:
                    return true
                }
            } else {
                if let message, message.peers[message.id.peerId]?.isMonoForum == true {
                    switch entity.type {
                    case .BotCommand:
                        return false
                    default:
                        return true
                    }
                }
                return true
            }
        })
        
        
    
        
        for attr in attributes {
            if let attr = attr as? TextEntitiesMessageAttribute {
                for entity in attr.entities {
                    switch entity.type {
                    case .Spoiler:
                        let range = NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound)
                        if let range = string.range.intersection(range) {
                            string.addAttribute(TextInputAttributes.spoiler, value: true as NSNumber, range: range)
                        }
                    default:
                        break
                    }
                }
            }
        }
        
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
                string.addAttribute(NSAttributedString.Key.link, value: inApp(for: url as NSString, context: context, messageId: message?.id, openInfo: openInfo, hashtag: hashtag, command: botCommand,  applyProxy: applyProxy, confirm: confirm ? nsString?.substring(with: range).trimmed != url : false), range: range)
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
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.followResolvedName(link: nsString!.substring(with: range), username: nsString!.substring(with: range), postId:nil, forceProfile: false, context:context, action:nil, callback: openInfo), range: range)
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
                    copyToClipboard(link.trimmed)
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
                
                string.addAttribute(TextInputAttributes.quote, value: TextViewBlockQuoteData(id: Int(arc4random64()), colors: .init(main: color, secondary: nil, tertiary: theme.colors.isDark ? .black : color), isCode: true, space: 4, header: header), range: range)
                fontAttributes.append((range, .monospace))
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: monospacedPre, range: range)
                string.addAttribute(TextInputAttributes.monospace, value: true as NSNumber, range: range)
                
                
                if let language = language?.lowercased() {
                    
                    let themeKeys = generateSyntaxThemeParams(theme, bubbled: bubbled, isIncoming: isIncoming)
                    
                    let code = string.attributedSubstring(from: range).string
                    let theme = SyntaxterTheme(dark: isDark, textColor: textColor, textFont: .code(fontSize), italicFont: .italicMonospace(fontSize), mediumFont: .semiboldMonospace(fontSize), themeKeys: themeKeys)!
                    var cachedData: CodeSyntaxResult? = nil
                    
                    if let messageId = message?.id {
                        cachedData = codeSyntaxData[.init(messageId: messageId, range: range, language: language, theme: theme)]
                    } else {
                        cachedData = .init(resut: CodeSyntax.syntax(code: code, language: language, theme: theme))
                    }
                    
                    if let resut = cachedData?.resut {
                        CodeSyntax.apply(resut, to: string, offset: range.location)
                    } else if let messageId = message?.id {
                        DispatchQueue.main.async {
                            loadCodeSyntax(messageId, range, code, language, theme)
                        }
                    }
                }

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
            case .PhoneNumber:
                if nsString == nil {
                    nsString = text as NSString
                }
                 string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.callback(nsString!.substring(with: range), { phoneNumber in
                    openPhoneNumber?(phoneNumber)
                }), range: range)
            case let .BlockQuote(collapsable):
                string.addAttribute(TextInputAttributes.quote, value: TextViewBlockQuoteData(id: Int(arc4random64()), colors: blockColor, space: 4, collapsable: collapsable), range: range)
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
    
    override func inset(for text: String) -> CGFloat {
        if let rect = self.textLayout.rect(for: text) {
            return rect.maxY
        } else {
            return super.inset(for: text)
        }
    }

}

