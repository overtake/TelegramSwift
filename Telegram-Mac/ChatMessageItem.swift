//
//  ChatMessageItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
class ChatMessageItem: ChatRowItem {
    public private(set) var messageText:NSAttributedString
    public private(set) var textLayout:TextViewLayout
    
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
    
    var actionButtonText: String? {
        if let webpage = webpageLayout, !webpage.hasInstantPage {
            let link = inApp(for: webpage.content.url.nsstring, account: account, openInfo: chatInteraction.openInfo)
            switch link {
            case let .followResolvedName(_, postId, _, _, _):
                if let _ = postId {
                    return L10n.chatMessageActionShowMessage
                }
            default:
                break
            }
        }
        
        return nil
    }
    
    func invokeAction() {
        if let webpage = webpageLayout {
            let link = inApp(for: webpage.content.url.nsstring, account: account, openInfo: chatInteraction.openInfo)
            execute(inapp: link)
        }
    }
    
    var webpageLayout:WPLayout?
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction,_ account:Account, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        
         if let message = entry.message {
            
            let isIncoming: Bool = message.isIncoming(account, entry.renderType == .bubble)

           
            let messageAttr:NSMutableAttributedString
            if message.text.isEmpty && message.media.isEmpty {
                let attr = NSMutableAttributedString()
                _ = attr.append(string: tr(L10n.chatMessageUnsupported), color: theme.chat.textColor(isIncoming, entry.renderType == .bubble), font: .code(theme.fontSize))
                messageAttr = attr
            } else {
                messageAttr = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text, account:account, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.sendPlainText, hashtag:account.context.globalSearch ?? {_ in }, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, entry.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble)).mutableCopy() as! NSMutableAttributedString

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
                            let increment = beforeAndAfter(effectiveRange.min - 1)
                            if increment {
                                effectiveRange = NSMakeRange(effectiveRange.location - 1, effectiveRange.length)
                            }
                        }
                        if effectiveRange.max < messageAttr.length - 1 {
                            let increment = beforeAndAfter(effectiveRange.max)
                            if increment {
                                effectiveRange = NSMakeRange(effectiveRange.location + 1, effectiveRange.length)
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
            }
            
            
            let copy = messageAttr.mutableCopy() as! NSMutableAttributedString
            
            if let peer = message.peers[message.id.peerId] {
                if peer is TelegramSecretChat {
                    copy.detectLinks(type: .Links, account: account, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble))
                }
            }
            
           
            self.messageText = copy
           
            
            textLayout = TextViewLayout(self.messageText, selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), strokeLinks: entry.renderType == .bubble, alwaysStaticItems: true)
            textLayout.mayBlocked = entry.renderType != .bubble
            if let range = selectManager.find(entry.stableId) {
                textLayout.selectedRange.range = range
            }
            
            
            var media = message.media.first
            if let game = media as? TelegramMediaGame {
                media = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: TelegramMediaWebpageContent.Loaded(TelegramMediaWebpageLoadedContent(url: "", displayUrl: "", hash: 0, type: "photo", websiteName: game.name, title: game.name, text: game.description, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, image: game.image, file: game.file, instantPage: nil)))
            }
            
            if let webpage = media as? TelegramMediaWebpage {
                let presentation = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, entry.renderType == .bubble), activity: theme.chat.webPreviewActivity(isIncoming, entry.renderType == .bubble), link: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, entry.renderType == .bubble), renderType: entry.renderType)
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
                    if content.file == nil || forceArticle {
                        webpageLayout = WPArticleLayout(with: content, account:account, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: presentation, downloadSettings: downloadSettings)
                    } else {
                        webpageLayout = WPMediaLayout(with: content, account:account, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize, presentation: presentation, downloadSettings: downloadSettings)
                    }
                default:
                    break
                }
            }
            
            super.init(initialSize, chatInteraction, account, entry, downloadSettings)
            
            
            (webpageLayout as? WPMediaLayout)?.parameters?.showMedia = { [weak self] message in
                if let webpage = message.media.first as? TelegramMediaWebpage {
                    switch webpage.content {
                    case let .Loaded(content):
                        if content.embedType == "iframe" && content.type != kBotInlineTypeGif {
                            showModal(with: WebpageModalController(content: content,account: account), for: mainWindow)
                            return
                        }
                    default:
                        break
                    }
                }
                showChatGallery(account: account, message: message, self?.table, (self?.webpageLayout as? WPMediaLayout)?.parameters, type: .alone)
            }

            textLayout.interactions = TextViewInteractions(processURL:{ link in
                if let link = link as? inAppLink {
                    execute(inapp:link)
                }
            }, copy: {
                selectManager.copy(selectManager)
                return !selectManager.isEmpty
            }, menuItems: { [weak self] type in
                var items:[ContextMenuItem] = []
                if let strongSelf = self, let layout = self?.textLayout {
                    
                    let text: String
                    if let type = type {
                        text = copyContextText(from: type)
                    } else {
                        text = layout.selectedRange.hasSelectText ? tr(L10n.chatCopySelectedText) : tr(L10n.textCopy)
                    }
                    
                    
                    items.append(ContextMenuItem(text, handler: { [weak strongSelf] in
                        let result = strongSelf?.textLayout.interactions.copy?()
                        if let result = result, let strongSelf = strongSelf, !result {
                            if strongSelf.textLayout.selectedRange.hasSelectText {
                                let pb = NSPasteboard.general
                                pb.declareTypes([.string], owner: strongSelf)
                                var effectiveRange = strongSelf.textLayout.selectedRange.range
                                
                                let attribute = strongSelf.textLayout.attributedString.attribute(NSAttributedStringKey.link, at: strongSelf.textLayout.selectedRange.range.location, effectiveRange: &effectiveRange)
                                let text = strongSelf.textLayout.attributedString.attributedSubstring(from: effectiveRange).string
    
                                
                                if let attribute = attribute as? inAppLink {
                                    if case let .external(link, confirm) = attribute {
                                        if confirm {
                                            pb.setString(link, forType: .string)
                                            return
                                        }
                                    } else if case let .followResolvedName(username, _, _, _, _) = attribute {
                                        if text.range(of: "t.me") != nil {
                                            pb.setString(text, forType: .string)
                                        } else {
                                            pb.setString(!username.hasPrefix("@") ? "@\(username)" : "\(username)", forType: .string)
                                            return
                                        }
                                    } else if case let .joinchat(hash, _, _) = attribute {
                                        pb.setString("https://t.me/joinchat/\(hash)", forType: .string)
                                        return
                                    }
                                }
                                
                                pb.setString(strongSelf.textLayout.attributedString.string.nsstring.substring(with: strongSelf.textLayout.selectedRange.range), forType: .string)
                            }
                            
                        }
                    }))
                    
                    if strongSelf.textLayout.selectedRange.hasSelectText {
                        var effectiveRange: NSRange = NSMakeRange(NSNotFound, 0)
                        if let _ = strongSelf.textLayout.attributedString.attribute(.preformattedPre, at: strongSelf.textLayout.selectedRange.range.location, effectiveRange: &effectiveRange) {
                            let blockText = strongSelf.textLayout.attributedString.attributedSubstring(from: effectiveRange).string
                            items.append(ContextMenuItem(tr(L10n.chatContextCopyBlock), handler: {
                                copyToClipboard(blockText)
                            }))
                        }
                    }
                    
                    
                    return strongSelf.menuItems(in: NSZeroPoint) |> map { basic in
                        var basic = basic
                        basic.remove(at: 1)
                        basic.insert(contentsOf: items, at: 1)
                        return basic
                    }
                }
                return .complete()
                
            }, isDomainLink: { value in
                if !value.hasPrefix("@") && !value.hasPrefix("#") && !value.hasPrefix("/") {
                    return true
                }
                return false
            }, makeLinkType: { link in
                return globalLinkExecutor.makeLinkType(link)
            })
            
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
    
    
    override var isFixedRightPosition: Bool {
        if let webpageLayout = webpageLayout {
            if let webpageLayout = webpageLayout as? WPArticleLayout, let textLayout = webpageLayout.textLayout {
                if textLayout.lines.count > 1, let line = textLayout.lines.last, line.frame.width < contentSize.width - (rightSize.width + insetBetweenContentAndDate) {
                    return true
                }
            }
            return super.isFixedRightPosition
        }
        
        if textLayout.lines.count > 1, let line = textLayout.lines.last, line.frame.width < contentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return true
        }
        return super.isForceRightLine
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if isForceRightLine {
            return rightSize.height
        }
        if let webpageLayout = webpageLayout {
            if let webpageLayout = webpageLayout as? WPArticleLayout {
                if let textLayout = webpageLayout.textLayout {
                    if webpageLayout.hasInstantPage {
                        return rightSize.height
                    }
                    if textLayout.lines.count > 1, let line = textLayout.lines.last, line.frame.width > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
                        return rightSize.height
                    }
                    if let _ = webpageLayout.imageSize, webpageLayout.isFullImageSize || textLayout.layoutSize.height - 10 <= webpageLayout.contrainedImageSize.height {
                        return rightSize.height
                    }
                    if actionButtonText != nil {
                        return rightSize.height
                    }
                    if webpageLayout.groupLayout != nil {
                        return rightSize.height
                    }
                } else {
                    return rightSize.height
                }
                
                
            } else if webpageLayout is WPMediaLayout {
                return rightSize.height
            }
            return nil
        }
        
        if textLayout.lines.count == 1 {
            if contentOffset.x + textLayout.layoutSize.width - (rightSize.width + insetBetweenContentAndDate) > width {
                return rightSize.height
            }
        } else if let line = textLayout.lines.last, line.frame.width > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return rightSize.height
        }
        return nil
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        let size:NSSize = super.makeContentSize(width)
     
        webpageLayout?.measure(width: min(width, 380))
        
        let textBlockWidth: CGFloat = isBubbled ? max((webpageLayout?.size.width ?? width), min(280, width)) : width
        
        textLayout.measure(width: textBlockWidth)

        
        var contentSize = NSMakeSize(max(webpageLayout?.contentRect.width ?? 0, textLayout.layoutSize.width), size.height + textLayout.layoutSize.height)
        
        if let webpageLayout = webpageLayout {
            contentSize.height += webpageLayout.size.height + defaultContentInnerInset
            contentSize.width = max(webpageLayout.size.width, contentSize.width)
            if let _ = actionButtonText {
                contentSize.height += 36
            }
        }
        
        return contentSize
    }

    
    override var bubbleFrame: NSRect {
        var frame = super.bubbleFrame
        
        
        if replyMarkupModel != nil, webpageLayout == nil, textLayout.layoutSize.width < 200 {
            frame.size.width = max(blockWidth, frame.width)
        }
        return frame
    }
    
   
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        var items = super.menuItems(in: location)
        let text = messageText.string
        
        let account = self.account!
        
        var media: Media? = webpageLayout?.content.file ?? webpageLayout?.content.image
        
        if let groupLayout = (webpageLayout as? WPArticleLayout)?.groupLayout {
            if let message = groupLayout.message(at: location) {
                media = message.media.first
            }
        }
        
        if let file = media as? TelegramMediaFile {
            items = items |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
                var items = items
                return account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue |> mapToSignal { data in
                    if data.complete {
                        items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                            saveAs(file, account: account)
                        }))
                    }
                    
                    if file.isSticker, let fileId = file.id {
                        return account.postbox.transaction { transaction -> [ContextMenuItem] in
                            let saved = getIsStickerSaved(transaction: transaction, fileId: fileId)
                            items.append(ContextMenuItem( !saved ? tr(L10n.chatContextAddFavoriteSticker) : tr(L10n.chatContextRemoveFavoriteSticker), handler: {
                                
                                if !saved {
                                    _ = addSavedSticker(postbox: account.postbox, network: account.network, file: file).start()
                                } else {
                                    _ = removeSavedSticker(postbox: account.postbox, mediaId: fileId).start()
                                }
                            }))
                            
                            return items
                        }
                    } else if file.isVideo && file.isAnimated {
                        items.append(ContextMenuItem(tr(L10n.messageContextSaveGif), handler: {
                            let _ = addSavedGif(postbox: account.postbox, file: file).start()
                        }))
                    }
                    
                    return .single(items)
                }
            }
        } else if let image = media as? TelegramMediaImage {
            items = items |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
                var items = items
                if let resource = image.representations.last?.resource {
                    return account.postbox.mediaBox.resourceData(resource) |> take(1) |> deliverOnMainQueue |> map { data in
                        if data.complete {
                            items.append(ContextMenuItem(tr(L10n.galleryContextCopyToClipboard), handler: {
                                if let path = link(path: data.path, ext: "jpg") {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.writeObjects([NSURL(fileURLWithPath: path)])
                                }
                            }))
                            items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                                savePanel(file: data.path, ext: "jpg", for: mainWindow)
                            }))
                        }
                        return items
                    }
                } else {
                    return .single(items)
                }
            }
        }

        
        return items |> deliverOnMainQueue |> map { [weak self] items in
            var items = items
            
            var needCopy: Bool = true
            for i in 0 ..< items.count {
                if items[i].title == tr(L10n.messageContextCopyMessageLink1) || items[i].title == tr(L10n.textCopy) {
                    needCopy = false
                }
            }
            if needCopy {

            }
            
            
            if let view = self?.view as? ChatRowView, let textView = view.selectableTextViews.first, let window = textView.window, needCopy {
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
                    } else {
                        if let content = self?.webpageLayout?.content, content.type == "proxy" {
                            items.insert(ContextMenuItem(L10n.chatCopyProxyConfiguration, handler: {
                                copyToClipboard(content.url)
                            }), at: items.isEmpty ? 0 : 1)
                        } else {
                            items.insert(ContextMenuItem(layout.selectedRange.hasSelectText ? tr(L10n.chatCopySelectedText) : tr(L10n.textCopy), handler: {
                                copyToClipboard(text)
                            }), at: items.isEmpty ? 0 : 1)
                        }
                    }
                }
            }
            
            return items
        }
    }
    
    override func viewClass() -> AnyClass {
        return ChatMessageView.self
    }
    
    static func applyMessageEntities(with attributes:[MessageAttribute], for text:String, account:Account, fontSize: CGFloat, openInfo:@escaping (PeerId, Bool, MessageId?, ChatInitialAction?)->Void, botCommand:@escaping (String)->Void, hashtag:@escaping (String)->Void, applyProxy:@escaping (ProxyServerSettings)->Void, textColor: NSColor = theme.colors.text, linkColor: NSColor = theme.colors.link, monospacedPre:NSColor = theme.colors.monospacedPre, monospacedCode: NSColor = theme.colors.monospacedCode ) -> NSAttributedString {
        var entities: TextEntitiesMessageAttribute?
        for attribute in attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                entities = attribute
                break
            }
        }
        
        
        let string = NSMutableAttributedString(string: text, attributes: [NSAttributedStringKey.font: NSFont.normal(fontSize), NSAttributedStringKey.foregroundColor: textColor])
        if let entities = entities {
            var nsString: NSString?
            for entity in entities.entities {
                let range = string.trimRange(NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))

                switch entity.type {
                case .Url:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    let link = inApp(for:nsString!.substring(with: range) as NSString, account:account, openInfo:openInfo, applyProxy: applyProxy)
                    string.addAttribute(NSAttributedStringKey.link, value: link, range: range)
                case .Email:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.external(link: "mailto:\(nsString!.substring(with: range))", false), range: range)
                case let .TextUrl(url):
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    
                    string.addAttribute(NSAttributedStringKey.link, value: inApp(for: url as NSString, account: account, openInfo: openInfo, hashtag: hashtag, command: botCommand,  applyProxy: applyProxy, confirm: true), range: range)
                case .Bold:
                    string.addAttribute(NSAttributedStringKey.font, value: NSFont.bold(fontSize), range: range)
                case .Italic:
                    string.addAttribute(NSAttributedStringKey.font, value: NSFontManager.shared.convert(.normal(fontSize), toHaveTrait: .italicFontMask), range: range)
                case .Mention:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.followResolvedName(username:nsString!.substring(with: range), postId:nil, account:account, action:nil, callback: openInfo), range: range)
                case let .TextMention(peerId):
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.peerInfo(peerId: peerId, action:nil, openChat: false, postId: nil, callback: openInfo), range: range)
                case .BotCommand:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.botCommand(nsString!.substring(with: range), botCommand), range: range)
                case .Code:
                    string.addAttribute(.preformattedCode, value: 4.0, range: range)
                    string.addAttribute(NSAttributedStringKey.font, value: NSFont.code(fontSize), range: range)
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: monospacedCode, range: range)
                case  .Pre:
                    string.addAttribute(.preformattedPre, value: 4.0, range: range)
                    string.addAttribute(NSAttributedStringKey.font, value: NSFont.code(fontSize), range: range)
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: monospacedPre, range: range)
                case .Hashtag:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.hashtag(nsString!.substring(with: range), hashtag), range: range)
                    break
                default:
                    break
                }
            }
            
        }
        return string.copy() as! NSAttributedString
    }
}
