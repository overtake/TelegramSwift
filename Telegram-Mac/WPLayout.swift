//
//  WPLayout.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore


struct WPLayoutPresentation {
    let text: NSColor
    let activity: NSColor
    let link: NSColor
    let selectText: NSColor
    let ivIcon: CGImage
    let renderType: ChatItemRenderType
}

class WPLayout: Equatable {
    let content:TelegramMediaWebpageLoadedContent
    let parent:Message
    let context: AccountContext
    let fontSize:CGFloat
    weak var table:TableView?
    
    private var _siteNameAttr:NSAttributedString?
    
    private(set) var size:NSSize = NSZeroSize
    private(set) var contentRect:NSRect = NSZeroRect
    
    private(set) var textLayout:TextViewLayout?
    
    private(set) var siteName:(TextNodeLayout, TextNode)?
    private var _nameNode:TextNode?
    
    var insets: NSEdgeInsets = NSEdgeInsets(left:8.0, top:0.0)
    
    
    var mediaCount: Int? {
        if let instantPage = content.instantPage, isGalleryAssemble {
            if let block = instantPage.blocks.filter({ value in
                if case .slideshow = value {
                    return true
                } else if case .collage = value {
                    return true
                } else {
                    return false
                }
            }).last {
                switch block {
                case let .slideshow(items, _), let .collage(items , _):
                    if items.count == 1 {
                        return nil
                    }
                    return items.count
                default:
                    break
                }
               
            }
        }
        return nil
    }
    
    var webPage: TelegramMediaWebpage {
        if let game = parent.media.first as? TelegramMediaGame {
            return TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent.init(url: "", displayUrl: "", hash: 0, type: "game", websiteName: game.title, title: nil, text: game.description, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, image: game.image, file: game.file, attributes: [], instantPage: nil)))
        }
        return parent.media.first as! TelegramMediaWebpage
    }
    
    let presentation: WPLayoutPresentation
    
    private var _approximateSynchronousValue: Bool = false
    var approximateSynchronousValue: Bool {
        get {
            let result = _approximateSynchronousValue
            _approximateSynchronousValue = false
            return result
        }
    }
    
    init(with content:TelegramMediaWebpageLoadedContent, context: AccountContext, chatInteraction:ChatInteraction, parent:Message, fontSize: CGFloat, presentation: WPLayoutPresentation, approximateSynchronousValue: Bool) {
        self.content = content
        self.context = context
        self.presentation = presentation
        self.parent = parent
        self.fontSize = fontSize
        self._approximateSynchronousValue = approximateSynchronousValue
        if let websiteName = content.websiteName {
            let websiteName = content.type == "telegram_background" ? L10n.chatWPBackgroundTitle : websiteName
            _siteNameAttr = .initialize(string: websiteName, color: presentation.activity, font: .medium(.text))
            _nameNode = TextNode()
        }
        
        
        let attributedText:NSMutableAttributedString = NSMutableAttributedString()
        
        let text = content.type != "telegram_background" ? content.text?.trimmed : nil
        if let title = content.title ?? content.author, content.type != "telegram_background" {
            _ = attributedText.append(string: title, color: presentation.text, font: .medium(fontSize))
            if text != nil {
                _ = attributedText.append(string: "\n")
            }
        }
        if let text = text {
            _ = attributedText.append(string: text, color: presentation.text, font: .normal(fontSize))
        }
        if attributedText.length > 0 {
            var p: ParsingType = [.Links]
            let wname = content.websiteName?.lowercased() ?? ""
            if wname == "instagram" || wname == "twitter" {
                p = [.Links, .Mentions, .Hashtags]
            }
            
            attributedText.detectLinks(type: p, color: presentation.link, dotInMention: wname == "instagram")
            textLayout = TextViewLayout(attributedText, maximumNumberOfLines:10, truncationType: .end, cutout: nil, selectText: presentation.selectText, strokeLinks: presentation.renderType == .bubble, alwaysStaticItems: true)
            
            let interactions = globalLinkExecutor
            interactions.resolveLink = { link in
                 if let link = link as? inAppLink {
                    if case .external(let url, _) = link {
                        switch wname {
                        case "instagram":
                            if url.hasPrefix("@") {
                                return "https://instagram.com/\(url.nsstring.substring(from: 1))"
                            }
                            if url.hasPrefix("#") {
                                return "https://instagram.com/explore/tags/\(url.nsstring.substring(from: 1))"
                            }
                        case "twitter":
                            if url.hasPrefix("@") {
                                return "https://twitter.com/\(url.nsstring.substring(from: 1))"
                            }
                            if url.hasPrefix("#") {
                                return "https://twitter.com/hashtag/\(url.nsstring.substring(from: 1))"
                            }
                        default:
                            break
                        }
                    }
                    return link.link
                }
                return nil
                
            }
            interactions.processURL = { link in
                if let link = link as? inAppLink {
                    var link = link
                    if case .external(let url, _) = link {
                        switch wname {
                        case "instagram":
                            if url.hasPrefix("@") {
                                link = .external(link: "https://instagram.com/\(url.nsstring.substring(from: 1))", false)
                            }
                            if url.hasPrefix("#") {
                                link = .external(link: "https://instagram.com/explore/tags/\(url.nsstring.substring(from: 1))", false)
                            }
                        case "twitter":
                            if url.hasPrefix("@") {
                                link = .external(link: "https://twitter.com/\(url.nsstring.substring(from: 1))", false)
                            }
                            if url.hasPrefix("#") {
                                link = .external(link: "https://twitter.com/hashtag/\(url.nsstring.substring(from: 1))", false)
                            }
                        default:
                            link = inApp(for: url.nsstring, context: context, peerId: nil, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
                            break
                        }
                    }
                    
                    execute(inapp: link)
                }
            }
            
            textLayout?.interactions = interactions
            
        }
        attributedText.fixUndefinedEmojies()
        
    }
    
    var isGalleryAssemble: Bool {
        // && content.instantPage != nil
        if (content.type == "video" && content.type == "video/mp4") || content.type == "photo" || ((content.websiteName?.lowercased() == "instagram" || content.websiteName?.lowercased() == "twitter" || content.websiteName?.lowercased() == "telegram")) || content.text == nil {
            return !content.url.isEmpty && content.type != "telegram_background" && content.type != "telegram_theme"
        }
        return content.type == "telegram_album" && content.type != "telegram_background" && content.type != "telegram_theme"
    }
    
    var wallpaper: inAppLink? {
        if content.type == "telegram_background" {
            return inApp(for: content.url as NSString, context: context)
        }
        return nil
    }
    var isPatternWallpaper: Bool {
        return content.file?.mimeType == "application/x-tgwallpattern"
    }
    
    var wallpaperReference: WallpaperReference? {
        if let wallpaper = wallpaper {
            switch wallpaper {
            case let .wallpaper(link, context, preview):
                inner: switch preview {
                case let .slug(slug, _):
                    return .slug(slug)
                default:
                    break inner
                }
            default:
                break
            }
        }
        return nil
    }
    
    var themeLink: inAppLink? {
        if content.type == "telegram_theme" {
            return inApp(for: content.url as NSString, context: context)
        }
        return nil
    }
    
    var isTheme: Bool {
        return content.type == "telegram_theme" && (content.file != nil || content.isCrossplatformTheme)
    }
    
    func viewClass() -> AnyClass {
        return WPArticleContentView.self
    }
    private(set) var oldWidth:CGFloat = 0
    
    func measure(width: CGFloat)  {
        if oldWidth != width {
            self.oldWidth = width
            siteName = TextNode.layoutText(maybeNode: _nameNode, _siteNameAttr, nil, 1, .end, NSMakeSize(width, 20), nil, false, .left)
        }
        
        if let siteName = siteName {
            insets.top = siteName.0.size.height + 2.0
        }
        
    }
    
    func layout(with size:NSSize) -> Void {
        let size = NSMakeSize(max(size.width, hasInstantPage ? 160 : size.width) , size.height + (hasInstantPage ? 30 + 6 : 0) + (isProxyConfig ? 30 + 6 : 0))
        self.contentRect = NSMakeRect(insets.left, insets.top, size.width, size.height)
        self.size = NSMakeSize(size.width + insets.left + insets.right, size.height + insets.top + insets.bottom)
    }
    
    var hasInstantPage: Bool {
        if let instantPage = content.instantPage {
            if content.websiteName?.lowercased() == "instagram" || content.websiteName?.lowercased() == "twitter" || content.type == "telegram_album" {
                return false
            }
            if instantPage.blocks.count == 3 {
                switch instantPage.blocks[2] {
                case let .collage(_, caption), let .slideshow(_, caption):
                    return !attributedStringForRichText(caption.text, styleStack: InstantPageTextStyleStack()).string.isEmpty
                default:
                    break
                }
            }
            
            return true
        }
        return  false
    }
    
    var isProxyConfig: Bool {
        return content.type == "proxy"
    }
    
    var proxyConfig: ProxyServerSettings? {
        return proxySettings(from: content.url).0
    }
    
}

func ==(lhs:WPLayout, rhs:WPLayout) -> Bool {
    return lhs.content == rhs.content
}
