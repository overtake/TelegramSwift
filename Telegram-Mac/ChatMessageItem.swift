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


class ChatMessageItem: ChatRowItem {
    public private(set) var messageText:NSAttributedString
    public private(set) var textLayout:TextViewLayout
    
    private let youtubeExternalLoader = MetaDisposable()
    
    override var selectableLayout:[TextViewLayout] {
        return [textLayout]
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
    
    var actionButtonText: String? {
        if let _ = message?.adAttribute, let author = message?.author {
            if author.isBot {
                return strings().chatMessageViewBot
            } else if author.isGroup || author.isSupergroup {
                return strings().chatMessageViewGroup
            } else {
                return strings().chatMessageViewChannel
            }
        }
        if let webpage = webpageLayout, !webpage.hasInstantPage {
            let link = inApp(for: webpage.content.url.nsstring, context: context, openInfo: chatInteraction.openInfo)
            switch link {
            case let .followResolvedName(_, _, postId, _, action, _):
                if let action = action {
                    inner: switch action {
                    case let .joinVoiceChat(hash):
                        if hash != nil {
                            return strings().chatMessageJoinVoiceChatAsSpeaker
                        } else {
                            return strings().chatMessageJoinVoiceChatAsListener
                        }
                    default:
                        break inner
                    }
                }
                if let postId = postId, postId > 0 {
                    return strings().chatMessageActionShowMessage
                }
            default:
                break
            }
            if webpage.wallpaper != nil {
                return strings().chatViewBackground
            }
            if webpage.isTheme {
                return strings().chatActionViewTheme
            }
        }
        
        if unsupported {
            return strings().chatUnsupportedUpdatedApp
        }
        
        return nil
    }
    
    override var isEditMarkVisible: Bool {
        if containsBigEmoji {
            return false
        } else {
            return super.isEditMarkVisible
        }
    }
    
    func invokeAction() {
        if let adAttribute = message?.adAttribute, let peer = peer {
            let link: inAppLink
            switch adAttribute.target {
            case let .peer(id, messageId, startParam):
                let action: ChatInitialAction?
                if let startParam = startParam {
                    action = .start(parameter: startParam, behavior: .none)
                } else {
                    action = nil
                }
                link = inAppLink.peerInfo(link: "", peerId: id, action: action, openChat: peer.isChannel, postId: messageId?.id, callback: chatInteraction.openInfo)
            case let .join(_, joinHash):
                link = .joinchat(link: "", joinHash, context: context, callback: chatInteraction.openInfo)
            }
            execute(inapp: link)
        } else if let webpage = webpageLayout {
            let link = inApp(for: webpage.content.url.nsstring, context: context, openInfo: chatInteraction.openInfo)
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
            
            let messageAttr:NSMutableAttributedString
            if message.inlinePeer == nil, message.text.isEmpty && (message.media.isEmpty || message.media.first is TelegramMediaUnsupported) {
                let attr = NSMutableAttributedString()
                _ = attr.append(string: strings().chatMessageUnsupportedNew, color: theme.chat.textColor(isIncoming, entry.renderType == .bubble), font: .code(theme.fontSize))
                messageAttr = attr
            } else {
                
                var mediaDuration: Double? = nil
                var mediaDurationMessage:Message?
                
                var canAssignToReply: Bool = true
                
                if let media = message.media.first as? TelegramMediaWebpage {
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
                    if let file = message.media.first as? TelegramMediaFile, file.isVideo && !file.isAnimated, let duration = file.duration {
                        mediaDuration = Double(duration)
                    } else if let media = message.media.first as? TelegramMediaWebpage {
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
                
                
                messageAttr = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text, message: message, context: context, fontSize: theme.fontSize, openInfo:openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.context.sharedContext.bindings.globalSearch, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, entry.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), mediaDuration: mediaDuration, timecode: { timecode in
                    openSpecificTimecodeFromReply?(timecode)
                }).mutableCopy() as! NSMutableAttributedString

                messageAttr.fixUndefinedEmojies()
                
                
                var formatting: Bool = messageAttr.length > 0 
                var index:Int = 0
                while formatting {
                    var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
                    if let _ = messageAttr.attribute(.preformattedPre, at: index, effectiveRange: &effectiveRange), effectiveRange.location != NSNotFound {
                        
                        let beforeAndAfter:(Int)->Bool = { index -> Bool in
                            let prefix:String = messageAttr.string.nsstring.substring(with: NSMakeRange(index, 1))
                            let whiteSpaceRange = prefix.rangeOfCharacter(from: NSCharacterSet.whitespaces)
                            var increment: Bool = false
                            if let _ = whiteSpaceRange {
                                messageAttr.replaceCharacters(in: NSMakeRange(index, 1), with: "\n")
                            } else if prefix != "\n" {
                                messageAttr.insert(.initialize(string: "\n"), at: index)
                                increment = true
                            }
                            return increment
                        }
                        
                        if effectiveRange.min > 0 {
                            let increment = beforeAndAfter(effectiveRange.min)
                            if increment {
                                effectiveRange = NSMakeRange(effectiveRange.location, effectiveRange.length + 1)
                            }
                        }
                        if effectiveRange.max < messageAttr.length - 1 {
                            let increment = beforeAndAfter(effectiveRange.max)
                            if increment {
                                effectiveRange = NSMakeRange(effectiveRange.location, effectiveRange.length + 1)
                            }
                        }
                    }
                    
                    if effectiveRange.location != NSNotFound {
                        index += effectiveRange.length
                    } else {
                        index += 1
                    }
                    
                    formatting = index < messageAttr.length
                }
                
//                if message.isScam {
//                    _ = messageAttr.append(string: "\n\n")
//                    _ = messageAttr.append(string: strings().chatScamWarning, color: theme.chat.textColor(isIncoming, entry.renderType == .bubble), font: .normal(theme.fontSize))
//                }
            }
            
            
            
            
            let copy = messageAttr.mutableCopy() as! NSMutableAttributedString
            
            if let peer = message.peers[message.id.peerId] {
                if peer is TelegramSecretChat {
                    copy.detectLinks(type: [.Links, .Mentions], context: context, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), openInfo: chatInteraction.openInfo)
                }
            }

            let containsBigEmoji: Bool
            if message.media.first == nil, bigEmojiMessage(context.sharedContext, message: message) {
                switch copy.string.glyphCount {
                case 1:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 5.8), range: copy.range)
                    containsBigEmoji = true
                case 2:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 4.8), range: copy.range)
                    containsBigEmoji = true
                case 3:
                    copy.addAttribute(.font, value: NSFont.normal(theme.fontSize * 3.8), range: copy.range)
                    containsBigEmoji = true
                default:
                    containsBigEmoji = false
                }
            } else {
                containsBigEmoji = false
            }
            
            self.containsBigEmoji = containsBigEmoji
            
            if message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
                copy.detectLinks(type: [.Links, .Mentions, .Hashtags, .Commands], context: context, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), openInfo: chatInteraction.openInfo, hashtag: { _ in }, command: { _ in }, applyProxy: chatInteraction.applyProxy)
            }
            if let text = message.restrictedText(context.contentSettings) {
                self.messageText = .initialize(string: text, color: theme.colors.grayText, font: .italic(theme.fontSize))
            } else {
                self.messageText = copy
            }
           
             var spoilers:[TextViewLayout.Spoiler] = []
             for attr in message.attributes {
                 if let attr = attr as? TextEntitiesMessageAttribute {
                     for entity in attr.entities {
                         switch entity.type {
                         case .Spoiler:
                             spoilers.append(.init(range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound), color: theme.colors.grayUI))
                         default:
                             break
                         }
                     }
                 }
             }
             
             
             textLayout = TextViewLayout(self.messageText, selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), strokeLinks: entry.renderType == .bubble && !containsBigEmoji, alwaysStaticItems: true, disableTooltips: false, mayItems: !message.isCopyProtected(), spoilers: spoilers)
            textLayout.mayBlocked = entry.renderType != .bubble
            
            if let highlightFoundText = entry.additionalData.highlightFoundText {
                if highlightFoundText.isMessage {
                    let range = copy.string.lowercased().nsstring.range(of: highlightFoundText.query.lowercased())
                    if range.location != NSNotFound {
                        textLayout.additionalSelections = [TextSelectedRange(range: range, color: theme.colors.accentIcon.withAlphaComponent(0.5), def: false)]
                    }
                } else {
                    var additionalSelections:[TextSelectedRange] = []
                    let string = copy.string.lowercased().nsstring
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
            
            if let range = selectManager.find(entry.stableId) {
                textLayout.selectedRange.range = range
            }
            
            
            var media = message.media.first
            if let game = media as? TelegramMediaGame {
                media = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: TelegramMediaWebpageContent.Loaded(TelegramMediaWebpageLoadedContent(url: "", displayUrl: "", hash: 0, type: "photo", websiteName: game.name, title: game.name, text: game.description, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, image: game.image, file: game.file, attributes: [], instantPage: nil)))
            }
            
            self.wpPresentation = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, entry.renderType == .bubble), activity: theme.chat.webPreviewActivity(isIncoming, entry.renderType == .bubble), link: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, entry.renderType == .bubble, presentation: theme), renderType: entry.renderType)

            
            if let webpage = media as? TelegramMediaWebpage {
                switch webpage.content {
                case let .Loaded(content):
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
                    if content.file == nil || forceArticle {
                        webpageLayout = WPArticleLayout(with: content, context: context, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: !message.isCopyProtected())
                    } else {
                        webpageLayout = WPMediaLayout(with: content, context: context, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: wpPresentation, approximateSynchronousValue: Thread.isMainThread, downloadSettings: downloadSettings, autoplayMedia: entry.autoplayMedia, theme: theme, mayCopyText: !message.isCopyProtected())
                    }
                default:
                    break
                }
            }
            
            super.init(initialSize, chatInteraction, context, entry, downloadSettings, theme: theme)
            
            
            (webpageLayout as? WPMediaLayout)?.parameters?.showMedia = { [weak self] message in
                if let webpage = message.media.first as? TelegramMediaWebpage {
                    switch webpage.content {
                    case let .Loaded(content):
                        if content.embedType == "iframe" && content.type != kBotInlineTypeGif {
                            showModal(with: WebpageModalController(content: content, context: context), for: mainWindow)
                            return
                        }
                    default:
                        break
                    }
                }
                showChatGallery(context: context, message: message, self?.table, (self?.webpageLayout as? WPMediaLayout)?.parameters, type: .alone)
            }
            
            openSpecificTimecodeFromReply = { [weak self] timecode in
                if let timecode = timecode {
                    var canAssignToReply: Bool = true
                    if let media = message.media.first as? TelegramMediaWebpage {
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
                                self?.youtubeExternalLoader.set((sharedVideoLoader.status(for: content) |> deliverOnMainQueue).start(next: { [weak item] status in
                                    if let item = item, let message = item.message {
                                        if let status = status {
                                            let content = content.withUpdatedYoutubeTimecode(timecode)
                                            if let media = message.media.first as? TelegramMediaWebpage {
                                                switch status {
                                                case .fail:
                                                    execute(inapp: .external(link: content.url, false))
                                                case .loaded:
                                                    let message = message.withUpdatedMedia([TelegramMediaWebpage(webpageId: media.webpageId, content: .Loaded(content))])
                                                    showChatGallery(context: item.context, message: message, item.table)
                                                default:
                                                    break
                                                }
                                            }
                                            
                                            
                                        }
                                    }
                                    
                                }))
                            }
                        }
                    }
                }
            }
            
            let interactions = globalLinkExecutor
            interactions.copy = {
                selectManager.copy(selectManager)
                return !selectManager.isEmpty
            }
            interactions.copyToClipboard = { text in
                copyToClipboard(text)
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
    
    override var identifier: String {
        if webpageLayout == nil {
            return super.identifier
        } else {
            return super.identifier + "\(stableId)"
        }
    }
    
    override var ignoreAtInitialization: Bool {
        return message?.adAttribute != nil
    }
    
    override var isForceRightLine: Bool {
         if let webpageLayout = webpageLayout {
             if let webpageLayout = webpageLayout as? WPArticleLayout {
                 if webpageLayout.hasInstantPage {
                     return true
                 }
                 if let _ = webpageLayout.imageSize {
                     return true
                 }
                 if actionButtonText != nil {
                     return true
                 }
                 if webpageLayout.groupLayout != nil {
                     return true
                 }
                 
             } else if webpageLayout is WPMediaLayout {
                 return true
             }
         }
        
        if self.webpageLayout?.content.type == "proxy" {
            return true
        } else {
            return super.isForceRightLine
        }
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        let size:NSSize = super.makeContentSize(width)
     
        webpageLayout?.measure(width: min(width, 380))
        
        let textBlockWidth: CGFloat = isBubbled ? max((webpageLayout?.size.width ?? width), min(240, width)) : width
        
        textLayout.measure(width: textBlockWidth, isBigEmoji: containsBigEmoji)

        
        var contentSize = NSMakeSize(max(webpageLayout?.contentRect.width ?? 0, textLayout.layoutSize.width), size.height + textLayout.layoutSize.height)
        
        if let webpageLayout = webpageLayout {
            contentSize.height += webpageLayout.size.height + defaultContentInnerInset
            contentSize.width = max(webpageLayout.size.width, contentSize.width)
            
        }
        if let _ = actionButtonText {
            contentSize.height += actionButtonHeight
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
    
    static func applyMessageEntities(with attributes:[MessageAttribute], for text:String, message: Message?, context: AccountContext, fontSize: CGFloat, openInfo:@escaping (PeerId, Bool, MessageId?, ChatInitialAction?)->Void, botCommand:@escaping (String)->Void = { _ in }, hashtag:@escaping (String)->Void = { _ in }, applyProxy:@escaping (ProxyServerSettings)->Void = { _ in }, textColor: NSColor = theme.colors.text, linkColor: NSColor = theme.colors.link, monospacedPre:NSColor = theme.colors.monospacedPre, monospacedCode: NSColor = theme.colors.monospacedCode, mediaDuration: Double? = nil, timecode: @escaping(Double?)->Void = { _ in }, openBank: @escaping(String)->Void = { _ in }) -> NSAttributedString {
        var entities: [MessageTextEntity] = []
        for attribute in attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                entities = attribute.entities
                break
            }
        }
        
        var fontAttributes: [NSRange: ChatTextFontAttributes] = [:]
        

        
        let string = NSMutableAttributedString(string: text, attributes: [NSAttributedString.Key.font: NSFont.normal(fontSize), NSAttributedString.Key.foregroundColor: textColor])
        
        let new = addLocallyGeneratedEntities(text, enabledTypes: [.timecode], entities: entities, mediaDuration: mediaDuration)
        var nsString: NSString?
        entities  = entities + (new ?? [])
        for entity in entities {
            let range = string.trimRange(NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
            
            switch entity.type {
            case .Url:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                let link = inApp(for:nsString!.substring(with: range) as NSString, context:context, openInfo:openInfo, applyProxy: applyProxy)
                string.addAttribute(NSAttributedString.Key.link, value: link, range: range)
            case .Email:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.external(link: "mailto:\(nsString!.substring(with: range))", false), range: range)
            case let .TextUrl(url):
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inApp(for: url as NSString, context: context, openInfo: openInfo, hashtag: hashtag, command: botCommand,  applyProxy: applyProxy, confirm: nsString?.substring(with: range).trimmed != url), range: range)
            case .Bold:
                if let fontAttribute = fontAttributes[range] {
                    fontAttributes[range] = fontAttribute.union(.bold)
                } else {
                    fontAttributes[range] = .bold
                }
            case .Italic:
                if let fontAttribute = fontAttributes[range] {
                    fontAttributes[range] = fontAttribute.union(.italic)
                } else {
                    fontAttributes[range] = .italic
                }
            case .Mention:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.followResolvedName(link: nsString!.substring(with: range), username: nsString!.substring(with: range), postId:nil, context:context, action:nil, callback: openInfo), range: range)
            case let .TextMention(peerId):
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.peerInfo(link: "", peerId: peerId, action:nil, openChat: false, postId: nil, callback: openInfo), range: range)
            case .BotCommand:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.botCommand(nsString!.substring(with: range), botCommand), range: range)
            case .Code:
                string.addAttribute(.preformattedCode, value: 4.0, range: range)
                if let fontAttribute = fontAttributes[range] {
                    fontAttributes[range] = fontAttribute.union(.monospace)
                } else {
                    fontAttributes[range] = .monospace
                }
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: monospacedCode, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.code(text.nsstring.substring(with: range), {  link in
                    copyToClipboard(link)
                    context.sharedContext.bindings.showControllerToaster(ControllerToaster(text: strings().shareLinkCopied), true)
                }), range: range)
            case  .Pre:
                string.addAttribute(.preformattedCode, value: 4.0, range: range)
                if let fontAttribute = fontAttributes[range] {
                    fontAttributes[range] = fontAttribute.union(.monospace)
                } else {
                    fontAttributes[range] = .monospace
                }
               // string.addAttribute(.preformattedPre, value: 4.0, range: range)
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: monospacedPre, range: range)
            case .Hashtag:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.hashtag(nsString!.substring(with: range), hashtag), range: range)
            case .Strikethrough:
                string.addAttribute(NSAttributedString.Key.strikethroughStyle, value: true, range: range)
            case .Underline:
                string.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: range)
            case .BankCard:
                if nsString == nil {
                    nsString = text as NSString
                }
                 string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                string.addAttribute(NSAttributedString.Key.link, value: inAppLink.callback(nsString!.substring(with: range), { bankCard in
                    openBank(bankCard)
                }), range: range)
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
        for (range, fontAttributes) in fontAttributes {
            var font: NSFont?
            if fontAttributes.contains(.blockQuote) {
                font = .code(fontSize)
            } else if fontAttributes == [.bold, .italic] {
                font = .boldItalic(fontSize)
            } else if fontAttributes == [.bold] {
                font = .bold(fontSize)
            } else if fontAttributes == [.italic] {
                font = .italic(fontSize)
            } else if fontAttributes == [.monospace] {
                font = .code(fontSize)
            }
            if let font = font {
                string.addAttribute(.font, value: font, range: range)
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
