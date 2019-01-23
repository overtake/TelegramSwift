//
//  InstantPageArticleItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac


final class InstantPageArticleItem: InstantPageItem {
    
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    let hasLinks: Bool = false
    
    
    let isInteractive: Bool = false
    

    
    var frame: CGRect
    let wantsView: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []
    let webPage: TelegramMediaWebpage
    
    let contentItems: [InstantPageItem]
    let contentSize: CGSize
    let cover: TelegramMediaImage?
    let url: String
    let webpageId: MediaId
    let rtl: Bool
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, contentItems: [InstantPageItem], contentSize: CGSize, cover: TelegramMediaImage?, url: String, webpageId: MediaId, rtl: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.contentItems = contentItems
        self.contentSize = contentSize
        self.cover = cover
        self.url = url
        self.webpageId = webpageId
        self.rtl = rtl
    }
    
    func view(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> (InstantPageView & NSView)? {
        return InstantPageArticleView(account: arguments.account, item: self, webPage: self.webPage, contentItems: self.contentItems, contentSize: self.contentSize, cover: self.cover, url: self.url, webpageId: self.webpageId, rtl: self.rtl, openUrl: arguments.openUrl)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesView(_ view: InstantPageView) -> Bool {
        if let view = view as? InstantPageArticleView {
            return self === view.item
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 7
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
}

func layoutArticleItem(theme: InstantPageTheme, webPage: TelegramMediaWebpage, title: NSAttributedString, description: NSAttributedString, cover: TelegramMediaImage?, url: String, webpageId: MediaId, boundingWidth: CGFloat, rtl: Bool) -> InstantPageArticleItem {
    let inset: CGFloat = 17.0
    let imageSpacing: CGFloat = 10.0
    var sideInset = inset
    let imageSize = CGSize(width: 44.0, height: 44.0)
    if cover != nil {
        sideInset += imageSize.width + imageSpacing
    }
    
    var availableLines: Int = 3
    var contentHeight: CGFloat = 15.0 * 2.0
    
    var hasRTL = false
    var contentItems: [InstantPageItem] = []
    let (titleTextItem, titleItems, titleSize) = layoutTextItemWithString(title, boundingWidth: boundingWidth - inset - sideInset, offset: CGPoint(x: inset, y: 15.0), maxNumberOfLines: availableLines)
    contentItems.append(contentsOf: titleItems)
    contentHeight += titleSize.height
    
    if let textItem = titleTextItem {
        availableLines -= textItem.lines.count
        if textItem.containsRTL {
            hasRTL = true
        }
    }
    var descriptionInset = inset
    if hasRTL && cover != nil {
        descriptionInset += imageSize.width + imageSpacing
        for var item in titleItems {
            item.frame = item.frame.offsetBy(dx: imageSize.width + imageSpacing, dy: 0.0)
        }
    }
    
    if availableLines > 0 {
        let (descriptionTextItem, descriptionItems, descriptionSize) = layoutTextItemWithString(description, boundingWidth: boundingWidth - inset - sideInset, alignment: hasRTL ? .right : .natural, offset: CGPoint(x: descriptionInset, y: 15.0 + titleSize.height + 14.0), maxNumberOfLines: availableLines)
        contentItems.append(contentsOf: descriptionItems)
        
        if let textItem = descriptionTextItem {
            if textItem.containsRTL || hasRTL {
                hasRTL = true
            }
        }
        contentHeight += descriptionSize.height + 14.0
    }
    
    let contentSize = CGSize(width: boundingWidth, height: contentHeight)
    return InstantPageArticleItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height)), webPage: webPage, contentItems: contentItems, contentSize: contentSize, cover: cover, url: url, webpageId: webpageId, rtl: rtl || hasRTL)
}








final class InstantPageArticleView: Button, InstantPageView {
    let item: InstantPageArticleItem
    
    
    private let contentTile: InstantPageTile
    private let contentTileView: InstantPageTileView
    private var imageView: TransformImageView?
    
    let url: String
    let webpageId: MediaId
    let cover: TelegramMediaImage?
    let rtl: Bool
    
    private let openUrl: (InstantPageUrlItem) -> Void
    
    private var fetchedDisposable = MetaDisposable()
    
    init(account: Account, item: InstantPageArticleItem, webPage: TelegramMediaWebpage, contentItems: [InstantPageItem], contentSize: CGSize, cover: TelegramMediaImage?, url: String, webpageId: MediaId, rtl: Bool, openUrl: @escaping (InstantPageUrlItem) -> Void) {
        self.item = item
        self.url = url
        self.webpageId = webpageId
        self.cover = cover
        self.rtl = rtl
        self.openUrl = openUrl
        
        self.contentTile = InstantPageTile(frame: CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height))
        self.contentTile.items.append(contentsOf: contentItems)
        self.contentTileView = InstantPageTileView(tile: self.contentTile, backgroundColor: .clear)
        
        super.init()
        
        self.addSubview(self.contentTileView)
        
        if let image = cover {
            let imageView = TransformImageView()
            
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            imageView.setSignal(chatMessagePhoto(account: account, imageReference: imageReference, scale: backingScaleFactor))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, imageReference: imageReference).start())
            
            self.imageView = imageView
            self.addSubview(imageView)
        }

        set(handler: { [weak self] _ in
            self?.click()
        }, for: .Up)
        
        set(background: theme.colors.grayBackground, for: .Highlight)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    deinit {
        self.fetchedDisposable.dispose()
    }
    
    private func click() {
        self.openUrl(InstantPageUrlItem(url: self.url, webpageId: self.webpageId))
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset: CGFloat = 17.0
        let imageSize = CGSize(width: 44.0, height: 44.0)
        
        self.contentTileView.frame = self.bounds
        
        if let imageView = self.imageView, let image = self.cover, let largest = largestImageRepresentation(image.representations) {
            let size = largest.dimensions.aspectFilled(imageSize)
            let boundingSize = imageSize
            
            imageView.set(arguments: TransformImageArguments(corners: ImageCorners(radius: 5.0), imageSize: size, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))
        }
        
        if let imageView = self.imageView {
            if self.rtl {
                imageView.frame = CGRect(origin: CGPoint(x: inset, y: 11.0), size: imageSize)
            } else {
                imageView.frame = CGRect(origin: CGPoint(x: size.width - inset - imageSize.width, y: 11.0), size: imageSize)
            }
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    

    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
}
