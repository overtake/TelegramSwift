//
//  WPLayout.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac

class WPLayout: Equatable {
    let content:TelegramMediaWebpageLoadedContent
    let parent:Message
    let account:Account
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
            return instantPage.media.count + 1
        }
        return nil
    }
    
    init(with content:TelegramMediaWebpageLoadedContent, account:Account, chatInteraction:ChatInteraction, parent:Message, fontSize: CGFloat) {
        self.content = content
        self.account = account
        self.parent = parent
        self.fontSize = fontSize
        if let websiteName = content.websiteName {
            _siteNameAttr = .initialize(string: websiteName, color: theme.colors.link, font: .medium(.text))
            _nameNode = TextNode()
        }
        
        
        let attributedText:NSMutableAttributedString = NSMutableAttributedString()
        
        if let title = content.title ?? content.author {
            _ = attributedText.append(string: title, color: theme.colors.text, font: NSFont.medium(.custom(fontSize)))
            if content.text != nil {
                _ = attributedText.append(string: "\n")
            }
        }
        if let text = content.text {
            _ = attributedText.append(string: text, color: theme.colors.text, font: NSFont.normal(.custom(fontSize)))
        }
        if attributedText.length > 0 {
            var p: ParsingType = [.Links]
            let wname = content.websiteName?.lowercased() ?? ""
            if wname == "instagram" || wname == "twitter" {
                p = [.Links, .Mentions, .Hashtags]
            }
            
            attributedText.detectLinks(type: p, dotInMention: wname == "instagram")
            textLayout = TextViewLayout(attributedText, maximumNumberOfLines:10, truncationType: .end, cutout: nil)
            textLayout?.interactions = TextViewInteractions(processURL: { link in
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
                            link = inApp(for: url.nsstring, account: account, peerId: nil, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
                            break
                        }
                    }
                    
                    execute(inapp: link)
                }
            })
            
        }
        attributedText.fixUndefinedEmojies()
        
    }
    
    var isGalleryAssemble: Bool {
        if (content.type == "video" && content.type == "video/mp4") || content.type == "photo" || ((content.websiteName?.lowercased() == "instagram" || content.websiteName?.lowercased() == "twitter") && content.instantPage != nil) || content.text == nil {
            return true
        }
        return false
    }
    
    func viewClass() -> AnyClass {
        return WPArticleContentView.self
    }
    
    func measure(width: CGFloat)  {
        siteName = TextNode.layoutText(maybeNode: _nameNode, _siteNameAttr, nil, 1, .end, NSMakeSize(width, 20), nil, false, .left)
        
        if let siteName = siteName {
            insets.top = siteName.0.size.height + 2.0
        }
        
    }
    
    func layout(with size:NSSize) -> Void {
        let size = NSMakeSize(max(size.width, hasInstantPage ? 160 : size.width) , size.height + (hasInstantPage ? 30 + 6 : 0))
        self.contentRect = NSMakeRect(insets.left, insets.top, size.width, size.height)
        self.size = NSMakeSize(size.width + insets.left + insets.right, size.height + insets.top + insets.bottom)
    }
    
    var hasInstantPage: Bool {
        if let _ = content.instantPage {
            if content.websiteName?.lowercased() == "instagram" || content.websiteName?.lowercased() == "twitter" {
                return false
            }
            return true
        }
        return  false
    }
    
}

func ==(lhs:WPLayout, rhs:WPLayout) -> Bool {
    return lhs.content == rhs.content
}
