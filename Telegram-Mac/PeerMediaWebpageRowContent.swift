//
//  MediaWebpageRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class PeerMediaWebpageRowItem: PeerMediaRowItem {
    
    var textLayout:TextViewLayout?
    var linkLayout:TextViewLayout?
    
    var iconText:NSAttributedString?
    var firstCharacter:String?
    var icon:TelegramMediaImage?
    var iconArguments:TransformImageArguments?
    var thumb:CGImage? = nil
    let readPercent: Int32?
    init(_ initialSize:NSSize, _ interface:ChatInteraction, _ account:Account, _ object: PeerMediaSharedEntry, saveToRecent: Bool = true, readPercent: Int32? = nil) {
        self.readPercent = readPercent
        super.init(initialSize,interface,account,object)
        iconSize = NSMakeSize(50, 50)
        self.contentInset = NSEdgeInsets(left: 70, right: 10, top: 5, bottom: 5)
        let isFullRead = readPercent == 100

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
                    icon = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], reference: nil, partialReference: nil)
                    
                    let imageCorners = ImageCorners(radius: iconSize.width/2)
                    iconArguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageRepresentation.dimensions.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
                }
                
               
                let attributedText = NSMutableAttributedString()

                let _ = attributedText.append(string: content.title ?? content.websiteName ?? hostName, color: isFullRead ? theme.colors.grayText : theme.colors.text, font: .medium(.text))
                
                if let text = content.text {
                    let _ = attributedText.append(string: "\n")
                    let _ = attributedText.append(string: text, color: isFullRead ? theme.colors.grayText : theme.colors.text, font: NSFont.normal(FontSize.text))
                    attributedText.detectLinks(type: [.Links], account: account, openInfo: interface.openInfo)
                }
                
                textLayout = TextViewLayout(attributedText, maximumNumberOfLines: 3, truncationType: .end)
                
                let linkAttributed:NSMutableAttributedString = NSMutableAttributedString()
                let _ = linkAttributed.append(string: content.displayUrl, color: theme.colors.link, font: NSFont.normal(FontSize.text))
                linkAttributed.detectLinks(type: [.Links], account: account, color: isFullRead ? theme.colors.link.withAlphaComponent(0.7) : theme.colors.link, openInfo: interface.openInfo)
                
                linkLayout = TextViewLayout(linkAttributed, maximumNumberOfLines: 1, truncationType: .end)
            }
        } else {
            
            var link:String = ""
            let links = ObjcUtils.textCheckingResults(forText: message.text, highlightMentionsAndTags: false, highlightCommands: false, dotInMention: false)
            if let links = links, !links.isEmpty {
                let range = (links[0] as! NSValue).rangeValue
                link = message.text.nsstring.substring(with: range)
                
                let attr = NSMutableAttributedString()
                _ = attr.append(string: link, color: theme.colors.link, font: .normal(.text))
                 attr.detectLinks(type: [.Links])
                
                linkLayout = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end)
            }
            
            var hostName: String = link
            if let url = URL(string: link), let host = url.host, !host.isEmpty {
                hostName = host
                firstCharacter = host.prefix(1)
            } else {
                firstCharacter = link.prefix(1)
            }
            
            let attributedText = NSMutableAttributedString()

            let _ = attributedText.append(string: hostName, color: theme.colors.text, font: .medium(.text))
            if !hostName.isEmpty {
                let _ = attributedText.append(string: "\n")
            }
            let _ = attributedText.append(string: message.text, color: theme.colors.text, font: NSFont.normal(.text))

            textLayout = TextViewLayout(attributedText, maximumNumberOfLines: 3, truncationType: .end)
           
        }
        
        if icon == nil {
            thumb = generateMediaEmptyLinkThumb(color: theme.colors.border, host: firstCharacter?.uppercased() ?? "H")
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
       
        
        linkLayout?.interactions = TextViewInteractions(processURL: { [weak self] url in
            if let webpage = self?.message.media.first as? TelegramMediaWebpage, let `self` = self {
                if self.hasInstantPage {
                    showInstantPage(InstantPageViewController(account, webPage: webpage, message: nil, saveToRecent: saveToRecent))
                    return
                }
            }
            globalLinkExecutor.processURL(url)
        }, copy: { [weak self] in
                guard let `self` = self else {return false}
                if let string = self.linkLayout?.attributedString.string {
                    copyToClipboard(string)
                }
                return true
        }, localizeLinkCopy: { link in
                return L10n.textContextCopyLink
        })
        
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
        textLayout?.measure(width: width - contentInset.left - contentInset.right)
        linkLayout?.measure(width: width - contentInset.left - contentInset.right - (hasInstantPage ? 10 : 0))
        
        var textSizes:CGFloat = 0
        if let tLayout = textLayout {
            textSizes += tLayout.layoutSize.height
        }
        if let lLayout = linkLayout {
            textSizes += lLayout.layoutSize.height
        }
        contentSize = NSMakeSize(width, max(textSizes + contentInset.top + contentInset.bottom + 2.0,60))
        
        return result
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaWebpageRowView.self
    }
}


class PeerMediaWebpageRowView : PeerMediaRowView {
    
    private var imageView:TransformImageView
    private var textView:TextView
    private var linkView:TextView
    private var ivImage: ImageView? = nil
    private var progressTextView: TextView?
    private var readProgressView: RadialProgressView?
    required init(frame frameRect: NSRect) {
        imageView = TransformImageView(frame:NSMakeRect(10, 5, 50.0, 50.0))
        textView = TextView()
        linkView = TextView()
        super.init(frame: frameRect)
        
        linkView.isSelectable = false
        
        addSubview(imageView)
        addSubview(textView)
        addSubview(linkView)
        
    }
    
   override func layout() {
        super.layout()
        if let item = item as? PeerMediaWebpageRowItem {
            textView.update(item.textLayout, origin: NSMakePoint(item.contentInset.left,item.contentInset.top))
            linkView.isHidden = item.linkLayout == nil
            linkView.update(item.linkLayout, origin: NSMakePoint(item.contentInset.left + (item.hasInstantPage ? 10 : 0),textView.frame.maxY + 2.0))
            ivImage?.setFrameOrigin(item.contentInset.left, textView.frame.maxY + 6.0)
            readProgressView?.center()
            progressTextView?.center()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let item = item as? PeerMediaWebpageRowItem, item.isArticle else {
            super.mouseUp(with: event)
            return
        }
        item.linkLayout?.interactions.processURL(event)
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        super.set(item: item,animated:animated)
        textView.backgroundColor = backdorColor
        linkView.backgroundColor = backdorColor
        if let item = item as? PeerMediaWebpageRowItem {
            
            textView.userInteractionEnabled = !item.isArticle
            

            
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
            
            let updateIconImageSignal:Signal<(TransformImageArguments) -> DrawingContext?,NoError>
            if let icon = item.icon {
                updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: icon), scale: backingScaleFactor, small:true)
            } else {
                updateIconImageSignal = .single({_ in return nil})
            }
            if let arguments = item.iconArguments {
                imageView.set(arguments: arguments)
                imageView.setSignal( updateIconImageSignal)
            }
            
            if item.icon == nil {
                imageView.layer?.contents = item.thumb
            }
            
            if let readProgress = item.readPercent {
                if readProgressView == nil {
                    readProgressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: theme.colors.blueUI, icon: nil, lineWidth: 3), twist: false, size: NSMakeSize(item.iconSize.width, item.iconSize.height))
                    imageView.addSubview(readProgressView!)
                    readProgressView?.isEventLess = true
                    readProgressView?.userInteractionEnabled = false
                }
                readProgressView?.state = .ImpossibleFetching(progress: readProgress == 100 ? 0 : Float(readProgress) / 100.0, force: true)
                
                
                if progressTextView == nil {
                    progressTextView = TextView()
                    imageView.addSubview(progressTextView!)
                }
                let layout = TextViewLayout(.initialize(string: readProgress == 100 ? L10n.articleRead : "\(readProgress)%", color: .white, font: .bold(11)))
                layout.measure(width: .greatestFiniteMagnitude)
                progressTextView?.backgroundColor = .clear
                progressTextView?.update(layout)
                progressTextView?.isEventLess = true
                progressTextView?.userInteractionEnabled = false
                
            } else {
                readProgressView?.removeFromSuperview()
                readProgressView = nil
                progressTextView?.removeFromSuperview()
                progressTextView = nil
            }
            
            needsLayout = true
        }
    }
    
    override func updateSelectingMode(with selectingMode:Bool, animated:Bool = false) {
        super.updateSelectingMode(with: selectingMode, animated: animated)
        self.textView.isSelectable = !selectingMode
        self.linkView.userInteractionEnabled = !selectingMode
        self.textView.userInteractionEnabled = !selectingMode
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
