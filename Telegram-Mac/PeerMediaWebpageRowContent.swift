//
//  MediaWebpageRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

class PeerMediaWebpageRowItem: PeerMediaRowItem {
    
    private(set) var textLayout:TextViewLayout?
    private(set) var linkLayouts:[TextViewLayout] = []
    
    private(set) var iconText:NSAttributedString?
    private(set) var firstCharacter:String?
    private(set) var icon:TelegramMediaImage?
    private(set) var iconArguments:TransformImageArguments?
    private(set) var thumb:CGImage? = nil
    override init(_ initialSize:NSSize, _ interface:ChatInteraction, _ object: PeerMediaSharedEntry, viewType: GeneralViewType = .legacy) {
        super.init(initialSize,interface,object, viewType: viewType)

        
        var linkLayouts:[TextViewLayout] = []
        
        var links:[NSAttributedString] = []

        for attr in message.attributes {
            if let attr = attr as? TextEntitiesMessageAttribute {
                for entity in attr.entities {
                    inner: switch entity.type {
                    case .Email:
                        let attributed = NSMutableAttributedString()
                        let link = message.text.nsstring.substring(with: NSMakeRange(min(entity.range.lowerBound, message.text.length), max(min(entity.range.upperBound - entity.range.lowerBound, message.text.length - entity.range.lowerBound), 0)))
                        let range = attributed.append(string: link, color: theme.colors.link, font: .normal(.text))
                        attributed.addAttribute(.link, value: inApp(for: link as NSString, context: interface.context, peerId: interface.peerId, openInfo: interface.openInfo, applyProxy: interface.applyProxy, confirm: false), range: range)
                        links.append(attributed)
                    case .Url:
                        let attributed = NSMutableAttributedString()
                        let link = message.text.nsstring.substring(with: NSMakeRange(min(entity.range.lowerBound, message.text.length), max(min(entity.range.upperBound - entity.range.lowerBound, message.text.length - entity.range.lowerBound), 0)))
                        let range = attributed.append(string: link, color: theme.colors.link, font: .normal(.text))
                        attributed.addAttribute(.link, value: inApp(for: link as NSString, context: interface.context, peerId: interface.peerId, openInfo: interface.openInfo, applyProxy: interface.applyProxy, confirm: false), range: range)
                        links.append(attributed)
                    case let .TextUrl(url):
                        let attributed = NSMutableAttributedString()
                        let range = attributed.append(string: url, color: theme.colors.link, font: .normal(.text))
                        attributed.addAttribute(.link, value: inApp(for: url as NSString, context: interface.context, peerId:
                            interface.peerId, openInfo: interface.openInfo, applyProxy: interface.applyProxy, confirm: false), range: range)
                        links.append(attributed)
                    default:
                        break inner
                    }
                }
                break
            }
        }
        
        for attributed in links {
            let linkLayout = TextViewLayout(attributed, maximumNumberOfLines: 1, truncationType: .middle)
            linkLayout.interactions = globalLinkExecutor
            linkLayouts.append(linkLayout)
        }
        
        
        if let webpage = message.media.first as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                
                var hostName: String = ""
                if let url = URL(string: content.url), let host = url.host, !host.isEmpty {
                    hostName = host
                    firstCharacter = host.prefix(1)
                } else {
                    firstCharacter = content.url.prefix(1)
                }
                
                var iconImageRepresentation:TelegramMediaImageRepresentation? = nil
                if let image = content.image {
                    iconImageRepresentation = largestImageRepresentation(image.representations)
                } else if let file = content.file {
                    iconImageRepresentation = largestImageRepresentation(file.previewRepresentations)
                }
                
                if let iconImageRepresentation = iconImageRepresentation {
                    icon = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    
                    let imageCorners = ImageCorners(radius: .cornerRadius)
                    iconArguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageRepresentation.dimensions.size.aspectFilled(PeerMediaIconSize), boundingSize: PeerMediaIconSize, intrinsicInsets: NSEdgeInsets())
                }
                
               
                let attributedText = NSMutableAttributedString()

                let _ = attributedText.append(string: content.title ?? content.websiteName ?? hostName, color: theme.colors.text, font: .medium(.text))
                
                if let text = content.text {
                    let _ = attributedText.append(string: "\n")
                    let _ = attributedText.append(string: text, color: theme.colors.text, font: .normal(.short))
                    attributedText.detectLinks(type: [.Links], context: interface.context, openInfo: interface.openInfo)
                }
                
                textLayout = TextViewLayout(attributedText, maximumNumberOfLines: 3, truncationType: .end)
            }
        } else if let linkLayout = linkLayouts.first {
            let attributed = linkLayout.attributedString
            var hostName: String = attributed.string
            if let url = URL(string: attributed.string), let host = url.host, !host.isEmpty {
                hostName = host
                firstCharacter = host.prefix(1)
            } else {
                firstCharacter = "L"
            }
            
            let attributedText = NSMutableAttributedString()

            let _ = attributedText.append(string: hostName, color: theme.colors.text, font: .medium(.text))
            if !hostName.isEmpty {
                let _ = attributedText.append(string: "\n")
            }
            if message.text != linkLayout.attributedString.string {
                let _ = attributedText.append(string: message.text, color: theme.colors.text, font: .normal(.short))
            }
            textLayout = TextViewLayout(attributedText, maximumNumberOfLines: 3, truncationType: .end)
           
        }
        
        if icon == nil {
            thumb = generateMediaEmptyLinkThumb(color: theme.colors.listBackground, textColor: theme.colors.listGrayText, host: firstCharacter?.uppercased() ?? "H")
        }
        
        textLayout?.interactions = globalLinkExecutor
        if message.stableId != UINT32_MAX {
            textLayout?.interactions.menuItems = { [weak self] inside in
                guard let `self` = self else {return .complete()}
                return self.menuItems(in: NSZeroPoint) |> map { items in
                    var items = items
                    if let layout = self.textLayout, layout.selectedRange.hasSelectText {
                        let text = layout.attributedString.attributedSubstring(from: layout.selectedRange.range)
                        items.insert(ContextMenuItem(L10n.textCopy, handler: {
                            copyToClipboard(text.string)
                        }), at: 0)
                        items.insert(ContextSeparatorItem(), at: 1)
                    }
                    return items
                }
            }
        }
        
        for linkLayout in linkLayouts {
            linkLayout.interactions = TextViewInteractions(processURL: { [weak self] url in
                if let webpage = self?.message.media.first as? TelegramMediaWebpage, let `self` = self {
                    if self.hasInstantPage {
                        showInstantPage(InstantPageViewController(self.interface.context, webPage: webpage, message: nil, saveToRecent: false))
                        return
                    }
                }
                globalLinkExecutor.processURL(url)
            }, copy: { [weak linkLayout] in
                guard let linkLayout = linkLayout else {return false}
                copyToClipboard(linkLayout.attributedString.string)
                return false
            }, localizeLinkCopy: { link in
                return L10n.textContextCopyLink
            })
        }
        
        self.linkLayouts = linkLayouts
        
        _ = makeSize(initialSize.width, oldWidth: 0)
        
    }
    
    var hasInstantPage: Bool {
        if let webpage = message.media.first as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                if let _ = content.instantPage {
                    if content.websiteName?.lowercased() == "instagram" || content.websiteName?.lowercased() == "twitter" || content.websiteName?.lowercased() == "telegram"  {
                        return false
                    }
                    return true
                }
            }
        }
        return false
    }
    
    var isArticle: Bool {
        return message.stableId == UINT32_MAX
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        
        let result = super.makeSize(width, oldWidth: oldWidth)
        textLayout?.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        
        for linkLayout in linkLayouts {
            linkLayout.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right - (hasInstantPage ? 10 : 0))
        }
        
        var textSizes:CGFloat = 0
        if let tLayout = textLayout {
            textSizes += tLayout.layoutSize.height
        }
        for linkLayout in linkLayouts {
            textSizes += linkLayout.layoutSize.height
        }
        
        contentSize = NSMakeSize(width, max(textSizes + contentInset.top + contentInset.bottom + 2.0, 40))
        
        return result
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaWebpageRowView.self
    }
}


class PeerMediaWebpageRowView : PeerMediaRowView {
    
    private var imageView:TransformImageView
    private var textView:TextView
    private var linkViews:[TextView] = []
    private var ivImage: ImageView? = nil
    required init(frame frameRect: NSRect) {
        imageView = TransformImageView(frame:NSMakeRect(0, 0, PeerMediaIconSize.width, PeerMediaIconSize.height))
        textView = TextView()
        super.init(frame: frameRect)
        
        
        addSubview(imageView)
        addSubview(textView)
    }
    
   override func layout() {
        super.layout()
        if let item = item as? PeerMediaWebpageRowItem {
            ivImage?.setFrameOrigin(item.contentInset.left, textView.frame.maxY + 6.0)
            textView.setFrameOrigin(NSMakePoint(item.contentInset.left,item.contentInset.top))
            
            var linkY: CGFloat = textView.frame.maxY + 2.0
            
            for linkView in self.linkViews {
                linkView.setFrameOrigin(NSMakePoint(item.contentInset.left + (item.hasInstantPage ? 10 : 0), linkY))
                linkY += linkView.frame.height
            }
            
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let item = item as? PeerMediaWebpageRowItem, item.isArticle else {
            super.mouseUp(with: event)
            return
        }
       // item.linkLayout?.interactions.processURL(event)
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        super.set(item: item,animated:animated)
        textView.backgroundColor = backdorColor
        if let item = item as? PeerMediaWebpageRowItem {
            
            textView.userInteractionEnabled = !item.isArticle
            
            textView.update(item.textLayout, origin: NSMakePoint(item.contentInset.left,item.contentInset.top))
            

            while self.linkViews.count > item.linkLayouts.count {
                let last = self.linkViews.removeLast()
                last.removeFromSuperview()
            }
            while self.linkViews.count < item.linkLayouts.count {
                let new = TextView()
                addSubview(new)
                self.linkViews.append(new)
            }
            
            var linkY: CGFloat = textView.frame.maxY + 2.0
            
            for (i, linkView) in self.linkViews.enumerated() {
                let linkLayout = item.linkLayouts[i]
                linkView.backgroundColor = backdorColor
                linkView.update(linkLayout, origin: NSMakePoint(item.contentInset.left + (item.hasInstantPage ? 10 : 0), linkY))
                linkY += linkLayout.layoutSize.height
            }
            
            if item.hasInstantPage {
                if ivImage == nil {
                    ivImage = ImageView()
                }
                ivImage!.image = theme.icons.chatInstantView
                ivImage!.sizeToFit()
                addSubview(ivImage!)
            } else {
                ivImage?.removeFromSuperview()
                ivImage = nil
            }
            
            let updateIconImageSignal:Signal<ImageDataTransformation,NoError>
            if let icon = item.icon {
                updateIconImageSignal = chatWebpageSnippetPhoto(account: item.interface.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: icon), scale: backingScaleFactor, small:true)
            } else {
                updateIconImageSignal = .single(ImageDataTransformation())
            }
            if let arguments = item.iconArguments {
                imageView.set(arguments: arguments)
                imageView.setSignal( updateIconImageSignal)
            }
            
            if item.icon == nil {
                imageView.layer?.contents = item.thumb
            }
            
            needsLayout = true
        }
    }
    
    override func updateSelectingMode(with selectingMode:Bool, animated:Bool = false) {
        super.updateSelectingMode(with: selectingMode, animated: animated)
        self.textView.isSelectable = !selectingMode
        for linkView in self.linkViews {
            linkView.userInteractionEnabled = !selectingMode
        }
        self.textView.userInteractionEnabled = !selectingMode
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
