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
    
    var webpageLayout:WPLayout?
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction,_ account:Account, _ entry: ChatHistoryEntry) {
        
        if let message = entry.message {
           
            let messageAttr:NSMutableAttributedString
            if message.text.isEmpty && message.media.isEmpty {
                let attr = NSMutableAttributedString()
                _ = attr.append(string: tr(.chatMessageUnsupported), color: theme.colors.text, font: .code(.custom(theme.fontSize)))
                messageAttr = attr
            } else {
                messageAttr = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text, account:account, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.forceSendMessage, hashtag:account.context.globalSearch ?? {_ in }, applyProxy: chatInteraction.applyProxy).mutableCopy() as! NSMutableAttributedString
//
                if message.flags.contains(.Sending) {
                    messageAttr.detectLinks(type: [.Links, .Mentions, .Hashtags], account: account, openInfo:chatInteraction.openInfo, applyProxy: chatInteraction.applyProxy)
                }
                
                messageAttr.fixUndefinedEmojies()
                
                
                var formatting: Bool = true
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
                    copy.detectLinks(type: .Links, account: account)
                }
            }
            
            self.messageText = copy
           
            
            textLayout = TextViewLayout(self.messageText)

            if let range = selectManager.find(entry.stableId) {
                textLayout.selectedRange.range = range
            }
            
            
            
            if let webpage = message.media.first as? TelegramMediaWebpage {
                switch webpage.content {
                case let .Loaded(content):
                    if content.file == nil {
                        webpageLayout = WPArticleLayout(with: content, account:account, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize)
                    } else {
                        webpageLayout = WPMediaLayout(with: content, account:account, chatInteraction: chatInteraction, parent:message, fontSize: theme.fontSize)
                    }
                default:
                    break
                }
            }
            
            super.init(initialSize,chatInteraction,account,entry)
            
            textLayout.interactions = TextViewInteractions(processURL:{ link in
                if let link = link as? inAppLink {
                    execute(inapp:link)
                }
            }, copy: {
                selectManager.copy(selectManager)
                return !selectManager.isEmpty
            }, menuItems: { [weak self] in
                var items:[ContextMenuItem] = []
                if let strongSelf = self {
                    items.append(ContextMenuItem(tr(.textCopy), handler: { [weak strongSelf] in
                        let result = strongSelf?.textLayout.interactions.copy?()
                        if let result = result, let strongSelf = strongSelf, !result {
                            if strongSelf.textLayout.selectedRange.hasSelectText {
                                let pb = NSPasteboard.general
                                pb.declareTypes([.string], owner: strongSelf)
                                var effectiveRange = strongSelf.textLayout.selectedRange.range
                                
                                let attribute = strongSelf.textLayout.attributedString.attribute(NSAttributedStringKey.link, at: strongSelf.textLayout.selectedRange.range.location, effectiveRange: &effectiveRange)
                                
                                if let attribute = attribute as? inAppLink, case let .external(link, confirm) = attribute {
                                    if confirm {
                                        pb.setString(link, forType: .string)
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
                            items.append(ContextMenuItem(tr(.chatContextCopyBlock), handler: {
                                copyToClipboard(blockText)
                            }))
                        }
                    }
                    
                    
                    return strongSelf.menuItems(in: NSZeroPoint) |> map { basic in
                        var basic = basic
                        basic.remove(at: 1)
                        return items + basic
                    }
                }
                return .complete()
                
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
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        let size:NSSize = super.makeContentSize(width)
        textLayout.measure(width: width)
     
        webpageLayout?.measure(width: min(width, 400))
        
        
        
        var contentSize = NSMakeSize(max(webpageLayout?.contentRect.width ?? 0, textLayout.layoutSize.width), size.height + textLayout.layoutSize.height)
        
        if let webpageLayout = webpageLayout {
            contentSize.height += webpageLayout.size.height + defaultContentTopOffset
            contentSize.width = max(webpageLayout.size.width, contentSize.width)
        }
        
        
        return contentSize
    }
    
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        var items = super.menuItems(in: location)
        let text = messageText.string
        
        let account = self.account!
        
        if let file = webpageLayout?.content.file {
            items = items |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
                var items = items
                return account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue |> mapToSignal { data in
                    if data.complete {
                        items.append(ContextMenuItem(tr(.contextCopyMedia), handler: {
                            saveAs(file, account: account)
                        }))
                    }
                    
                    if file.isSticker, let fileId = file.id {
                        return account.postbox.modify { modifier -> [ContextMenuItem] in
                            let saved = getIsStickerSaved(modifier: modifier, fileId: fileId)
                            items.append(ContextMenuItem( !saved ? tr(.chatContextAddFavoriteSticker) : tr(.chatContextRemoveFavoriteSticker), handler: {
                                
                                if !saved {
                                    _ = addSavedSticker(postbox: account.postbox, network: account.network, file: file).start()
                                } else {
                                    _ = removeSavedSticker(postbox: account.postbox, mediaId: fileId).start()
                                }
                            }))
                            
                            return items
                        }
                    }
                    
                    return .single(items)
                }
            }
        } else if let image = webpageLayout?.content.image {
            items = items |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
                var items = items
                if let resource = image.representations.last?.resource {
                    return account.postbox.mediaBox.resourceData(resource) |> take(1) |> deliverOnMainQueue |> map { data in
                        if data.complete {
                            items.append(ContextMenuItem(tr(.galleryContextCopyToClipboard), handler: {
                                if let path = link(path: data.path, ext: "jpg") {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.writeObjects([NSURL(fileURLWithPath: path)])
                                }
                            }))
                            items.append(ContextMenuItem(tr(.contextCopyMedia), handler: {
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

        
        return items |> map { items in
            var items = items
            items.insert(ContextMenuItem(tr(.textCopy), handler: {
                copyToClipboard(text)
            }), at: 1)
            
            return items
        }
    }
    
    override func viewClass() -> AnyClass {
        return ChatMessageView.self
    }
    
    static func applyMessageEntities(with attributes:[MessageAttribute], for text:String, account:Account, fontSize: CGFloat, openInfo:@escaping (PeerId, Bool, MessageId?, ChatInitialAction?)->Void, botCommand:@escaping (String)->Void, hashtag:@escaping (String)->Void, applyProxy:@escaping (ProxySettings)->Void) -> NSAttributedString {
        var entities: TextEntitiesMessageAttribute?
        for attribute in attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                entities = attribute
                break
            }
        }
        
        
        let string = NSMutableAttributedString(string: text, attributes: [NSAttributedStringKey.font: NSFont.normal(.custom(fontSize)), NSAttributedStringKey.foregroundColor: theme.colors.text])
        if let entities = entities {
            var nsString: NSString?
            for entity in entities.entities {
                let range = string.trimRange(NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))

                switch entity.type {
                case .Url:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    let link = inApp(for:nsString!.substring(with: range) as NSString, account:account, openInfo:openInfo, applyProxy: applyProxy)
                    string.addAttribute(NSAttributedStringKey.link, value: link, range: range)
                case .Email:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.external(link: "mailto:\(nsString!.substring(with: range))", false), range: range)
                case let .TextUrl(url):
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    
                    string.addAttribute(NSAttributedStringKey.link, value: inApp(for: url as NSString, account: account, openInfo: openInfo, hashtag: hashtag, command: botCommand,  applyProxy: applyProxy, confirm: true), range: range)
                case .Bold:
                    string.addAttribute(NSAttributedStringKey.font, value: NSFont.bold(.custom(fontSize)), range: range)
                case .Italic:
                    string.addAttribute(NSAttributedStringKey.font, value: NSFontManager.shared.convert(.normal(.custom(fontSize)), toHaveTrait: .italicFontMask), range: range)
                case .Mention:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.followResolvedName(username:nsString!.substring(with: range), postId:nil, account:account, action:nil, callback: openInfo), range: range)
                case let .TextMention(peerId):
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: range)
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.peerInfo(peerId: peerId, action:nil, openChat: false, postId: nil, callback: openInfo), range: range)
                case .BotCommand:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: range)
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    string.addAttribute(NSAttributedStringKey.link, value: inAppLink.botCommand(nsString!.substring(with: range), botCommand), range: range)
                case .Code:
                    string.addAttribute(.preformattedCode, value: 4.0, range: range)
                    string.addAttribute(NSAttributedStringKey.font, value: NSFont.code(.custom(fontSize)), range: range)
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.redUI, range: range)
                case  .Pre:
                    string.addAttribute(.preformattedPre, value: 4.0, range: range)
                    string.addAttribute(NSAttributedStringKey.font, value: NSFont.code(.custom(fontSize)), range: range)
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.text, range: range)
                case .Hashtag:
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: range)
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
