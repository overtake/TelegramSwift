//
//  ReadArticleRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

class ReadArticleRowItem: GeneralRowItem {

    fileprivate let article: ReadArticle

    fileprivate var textLayout:TextViewLayout?
    fileprivate var linkLayout:TextViewLayout?
    
    fileprivate var iconText:NSAttributedString?
    fileprivate var firstCharacter:String?
    fileprivate var icon:TelegramMediaImage?
    fileprivate var iconArguments:TransformImageArguments?
    fileprivate var thumb:CGImage? = nil
    fileprivate var iconSize: NSSize = NSMakeSize(50, 50)
    fileprivate var contentInset:NSEdgeInsets = NSEdgeInsets(left: 60.0, right: 10, top: 5, bottom: 5)
    fileprivate var contentSize:NSSize = NSMakeSize(0, 50)
    fileprivate let account: Account
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, article: ReadArticle) {
        self.article = article
        self.account = account
        super.init(initialSize, height: 60, stableId: stableId)
        
        self.contentInset = NSEdgeInsets(left: 70, right: 10, top: 5, bottom: 5)
        if case let .Loaded(content) = article.webPage.content {
            
            var hostName: String = ""
            if let url = URL(string: content.url), let host = url.host, !host.isEmpty {
                hostName = host
                firstCharacter = host.prefix(1)
            } else {
                firstCharacter = content.url.prefix(1)
            }
            
            var iconImageRepresentation:TelegramMediaImageRepresentation? = nil
            if let image = content.image {
                iconImageRepresentation = smallestImageRepresentation(image.representations)
            } else if let file = content.file {
                iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations)
            }
            
            if let iconImageRepresentation = iconImageRepresentation {
                icon = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], reference: nil)
                
                let imageCorners = ImageCorners(radius: iconSize.width/2)
                iconArguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageRepresentation.dimensions.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
            }
            
            
            let attributedText = NSMutableAttributedString()
            
            let _ = attributedText.append(string: content.title ?? content.websiteName ?? hostName, color: theme.colors.text, font: .medium(.text))
            
            if let text = content.text {
                let _ = attributedText.append(string: "\n")
                let _ = attributedText.append(string: text, color: theme.colors.text, font: NSFont.normal(FontSize.text))
          //      attributedText.detectLinks(type: [.Links, .Mentions, .Hashtags], account: account, openInfo: interface.openInfo)
            }
            
            textLayout = TextViewLayout(attributedText, maximumNumberOfLines: 6, truncationType: .end)
            
            let linkAttributed:NSMutableAttributedString = NSMutableAttributedString()
            let _ = linkAttributed.append(string: content.displayUrl, color: theme.colors.link, font: NSFont.normal(FontSize.text))
        //    linkAttributed.detectLinks(type: [.Links, .Mentions, .Hashtags], account: account, openInfo: interface.openInfo)
            
            linkLayout = TextViewLayout(linkAttributed, maximumNumberOfLines: 1, truncationType: .end)
        }
        
        if icon == nil {
            thumb = generateMediaEmptyLinkThumb(color: theme.colors.border, host: firstCharacter?.uppercased() ?? "H")
        }
        
        textLayout?.interactions = globalLinkExecutor
        
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
        
//        linkLayout?.interactions = TextViewInteractions(processURL: { [weak self] url in
//            if let webpage = self?.message.media.first as? TelegramMediaWebpage {
//                if case let .Loaded(content) = webpage.content {
//                    if let _ = content.instantPage {
//                        showInstantPage(InstantPageViewController(account, webPage: webpage, message: nil))
//                        return
//                    }
//                }
//            }
//            globalLinkExecutor.processURL(url)
//            }, copy: { [weak self] in
//                guard let `self` = self else {return false}
//                if let string = self.linkLayout?.attributedString.string {
//                    copyToClipboard(string)
//                }
//                return true
//        })
    }

    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout?.measure(width: width - contentInset.left - contentInset.right)
        linkLayout?.measure(width: width - contentInset.left - contentInset.right)
        
        var textSizes:CGFloat = 0
        if let tLayout = textLayout {
            textSizes += tLayout.layoutSize.height
        }
        if let lLayout = linkLayout {
            textSizes += lLayout.layoutSize.height
        }
        contentSize = NSMakeSize(width, max(textSizes + contentInset.top + contentInset.bottom + 2.0, 60))
        
        return success
    }
    
    override func viewClass() -> AnyClass {
        return ReadArticleRowView.self
    }
}



private final class ReadArticleRowView : TableRowView {
    private var imageView:TransformImageView
    private var textView:TextView
    private var linkView:TextView
    
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
        if let item = item as? ReadArticleRowItem {
            textView.update(item.textLayout, origin: NSMakePoint(item.contentInset.left,item.contentInset.top))
            linkView.isHidden = item.linkLayout == nil
            linkView.update(item.linkLayout, origin: NSMakePoint(item.contentInset.left,textView.frame.maxY + 2.0))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        super.set(item: item,animated:animated)
        textView.backgroundColor = backdorColor
        linkView.backgroundColor = backdorColor
        if let item = item as? ReadArticleRowItem {
            let updateIconImageSignal:Signal<(TransformImageArguments) -> DrawingContext?,NoError>
            if let icon = item.icon {
                updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: icon, scale: backingScaleFactor, small:true)
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
            
            needsLayout = true
        }
    }
    
//    func updateSelectingMode(with selectingMode:Bool, animated:Bool = false) {
//        super.updateSelectingMode(with: selectingMode, animated: animated)
//        self.textView.isSelectable = !selectingMode
//        self.linkView.userInteractionEnabled = !selectingMode
//        self.textView.userInteractionEnabled = !selectingMode
//    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
