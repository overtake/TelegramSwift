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
import ColorPalette


struct WPLayoutPresentation {
    let text: NSColor
    let activity: PeerNameColors.Colors
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
    private let mayCopyText: Bool
    
    var insets: NSEdgeInsets = NSEdgeInsets(left: 8.0, right: 6, top: 3, bottom: 5)
    var imageInsets: NSEdgeInsets = NSEdgeInsets(left: 0, right: 0, top: 3, bottom: 0)
    
    var mediaCount: Int? {
        if let instantPage = content.instantPage, isGalleryAssemble, content.type == "telegram_album" {
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
        if let game = parent.anyMedia as? TelegramMediaGame {
            return TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: arc4random64()), content: .Loaded(TelegramMediaWebpageLoadedContent.init(url: "", displayUrl: "", hash: 0, type: "game", websiteName: game.title, title: nil, text: game.description, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, image: game.image, file: game.file, story: nil, attributes: [], instantPage: nil)))
        }
        return parent.anyMedia as! TelegramMediaWebpage
    }
    
    let presentation: WPLayoutPresentation
    let chatInteraction: ChatInteraction
    
    private var _approximateSynchronousValue: Bool = false
    var approximateSynchronousValue: Bool {
        get {
            let result = _approximateSynchronousValue
            _approximateSynchronousValue = false
            return result
        }
    }
    
    init(with content:TelegramMediaWebpageLoadedContent, context: AccountContext, chatInteraction:ChatInteraction, parent:Message, fontSize: CGFloat, presentation: WPLayoutPresentation, approximateSynchronousValue: Bool, mayCopyText: Bool) {
        self.content = content
        self.context = context
        self.presentation = presentation
        self.chatInteraction = chatInteraction
        self.mayCopyText = mayCopyText
        self.parent = parent
        self.fontSize = fontSize
        self._approximateSynchronousValue = approximateSynchronousValue
        
        if let websiteName = content.websiteName {
            let siteName: String
            switch content.type {
            case "telegram_background":
                siteName = strings().chatWPBackgroundTitle
            case "telegram_voicechat":
                siteName = strings().chatWPVoiceChatTitle
            default:
                siteName = websiteName
            }
            _siteNameAttr = .initialize(string: siteName, color: presentation.activity.main, font: .medium(.text))
        }
        
        
        let attributedText:NSMutableAttributedString = NSMutableAttributedString()
        
        
        if let siteName = _siteNameAttr {
            attributedText.append(siteName)
            attributedText.append(string: "\n", font: .normal(.text))
        }
        var text = content.type != "telegram_background" ? content.text?.trimmed : nil
        
        if text == nil, let story = content.story, let storedItem = parent.associatedStories[story.storyId]?.get(Stories.StoredItem.self) {
            switch storedItem {
            case let .item(item):
                text = item.text.prefixWithDots(100)
            default:
                break
            }
        }
        
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
            textLayout = TextViewLayout(attributedText, maximumNumberOfLines:10, truncationType: .end, cutout: nil, selectText: presentation.selectText, strokeLinks: presentation.renderType == .bubble, alwaysStaticItems: true, mayItems: mayCopyText)
            
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
//        attributedText.fixUndefinedEmojies()
        
    }
    
    var isStory: Bool {
        return content.story != nil
    }
    
    func openStory() {
        if let story = content.story {
            chatInteraction.openStory(parent.id, story.storyId)
        }
    }
    
    var isGalleryAssemble: Bool {
        if content.story != nil {
            return false
        }
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
        
    }
    
    func layout(with size:NSSize) -> Void {
        
        var buttonSize: CGFloat = 0
        if action_text != nil {
            buttonSize += 39
        }
        let size = NSMakeSize(max(size.width, hasInstantPage ? 160 : size.width), size.height + buttonSize)
        
        self.contentRect = NSMakeRect(insets.left, insets.top, size.width, size.height)
        self.size = NSMakeSize(size.width + insets.left + insets.right, size.height + insets.bottom + insets.top)
    }
    
    var action_text:String? {
        
        if let adAtribute = parent.adAttribute, let author = parent.author {
            if case .webPage = adAtribute.target {
                return strings().chatMessageOpenLink
            } else if author.isBot {
                return strings().chatMessageViewBot
            } else if author.isGroup || author.isSupergroup {
                return strings().chatMessageViewGroup
            } else {
                return strings().chatMessageViewChannel
            }
        }
        
        if self.isProxyConfig {
            return strings().chatApplyProxy
        } else if hasInstantPage {
            return strings().chatInstantView
        }
        if !self.hasInstantPage {
            let content = self.content
            let link = inApp(for: content.url.nsstring, context: context, messageId: parent.id, openInfo: chatInteraction.openInfo)
            switch link {
            case let .followResolvedName(_, _, postId, _, action, _):
                var actionIsSource: Bool = false
                if case .source = action {
                    actionIsSource = true
                }
                if let action = action, !actionIsSource {
                    inner: switch action {
                    case let .joinVoiceChat(hash):
                        if hash != nil {
                            return strings().chatMessageJoinVoiceChatAsSpeaker
                        } else {
                            return strings().chatMessageJoinVoiceChatAsListener
                        }
                    case .makeWebview:
                        return strings().chatMessageOpenApp
                    default:
                        break inner
                    }
                } else {
                    switch content.type {
                    case "telegram_channel":
                        return strings().chatMessageViewChannel
                    case "telegram_group":
                        return strings().chatMessageViewGroup
                    case "telegram_megagroup":
                        return strings().chatMessageViewGroup
                    case "telegram_gigagroup":
                        return strings().chatMessageViewGroup
                    case "telegram_user":
                        return strings().chatMessageSendMessage
                    default:
                        break
                    }
                }
                if let postId = postId, postId > 0 {
                    return strings().chatMessageActionShowMessage
                }
            case .folder:
                return strings().chatMessageViewChatList
            case .story:
                return strings().chatMessageOpenStory
            case .boost:
                return strings().chatMessageBoostChannel
            default:
                break
            }
            if self.wallpaper != nil {
                return strings().chatViewBackground
            }
            if self.isTheme {
                return strings().chatActionViewTheme
            }
        }
        return nil
    }
    
    func premiumBoarding() {
        showModal(with: PremiumBoardingController(context: context), for: context.window)
    }
    
    func invokeAction() {
        if self.hasInstantPage {
            showInstantPage(InstantPageViewController(context, webPage: parent.media[0] as! TelegramMediaWebpage, message: parent.text))
        } else if let proxyConfig = self.proxyConfig {
            applyExternalProxy(proxyConfig, accountManager: context.sharedContext.accountManager)
        } else if let adAttribute = parent.adAttribute {
            let link: inAppLink
            switch adAttribute.target {
            case let .peer(id, messageId, startParam):
                let action: ChatInitialAction?
                if let startParam = startParam {
                    action = .start(parameter: startParam, behavior: .none)
                } else {
                    action = nil
                }
                link = inAppLink.peerInfo(link: "", peerId: id, action: action, openChat: true, postId: messageId?.id, callback: chatInteraction.openInfo)
            case let .join(_, joinHash):
                link = .joinchat(link: "", joinHash, context: context, callback: chatInteraction.openInfo)
            case let .webPage(_, url: url):
                link = .external(link: url, false)
            }
            chatInteraction.markAdAction(adAttribute.opaqueId)
            execute(inapp: link)
        } else {
            let link = inApp(for: self.content.url.nsstring, context: context, messageId: parent.id, openInfo: chatInteraction.openInfo)
            execute(inapp: link)
        }
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
