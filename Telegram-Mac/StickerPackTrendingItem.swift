//
//  StickerPackTrendingItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.08.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox

private final class FeaturedHorizontalItem : TableRowItem {
    
    fileprivate let item: FeaturedStickerPackItem
    fileprivate let context: AccountContext
    fileprivate let click:(FeaturedStickerPackItem)->Void
    init(_ initialSize: NSSize, context: AccountContext, item: FeaturedStickerPackItem, click:@escaping(FeaturedStickerPackItem)->Void) {
        self.item = item
        self.click = click
        self.context = context
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return item.topItems.first?.file.id?.id ?? arc4random64()
    }
    override var height: CGFloat {
        return 30
    }
    override var width: CGFloat {
        return 30
    }
    func contentNode()->ChatMediaContentView.Type {
        if let file = item.topItems.first?.file, file.isAnimatedSticker {
            return MediaAnimatedStickerView.self
        } else {
            return ChatStickerContentView.self
        }
    }
    
    override func viewClass() -> AnyClass {
        if let file = item.topItems.first?.file, file.isAnimatedSticker {
            return FeaturedAnimatedHorizontalView.self
        } else {
            return FeaturedHorizontalView.self
        }
    }
}

private final class FeaturedAnimatedHorizontalView : HorizontalRowView {
    
    private let unread: View = View(frame: NSMakeRect(0, 0, 6, 6))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(unread)
        unread.layer?.cornerRadius = 3
        
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let item = self.item as? FeaturedHorizontalItem {
            item.click(item.item)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate(set) var contentNode:ChatMediaContentView?
    
    
    override var backgroundColor: NSColor {
        didSet {
            contentNode?.backgroundColor = backdorColor
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func shakeView() {
        contentNode?.shake()
    }
    
    
    override func updateMouse() {
        super.updateMouse()
        self.contentNode?.updateMouse()
    }
    
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            contentNode?.removeFromSuperview()
            contentNode = nil
        } else if let item = item, contentNode == nil {
            self.set(item: item, animated: false)
        }
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        if let item = item as? FeaturedHorizontalItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            unread.isHidden = !item.item.unread
            unread.backgroundColor = theme.colors.accent
            
            var file: TelegramMediaFile?
            if let thumbnail = item.item.info.thumbnail {
                file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.FileName(fileName: "sticker.tgs"), .Sticker(displayText: "", packReference: .id(id: item.item.info.id.id, accessHash: item.item.info.accessHash), maskData: nil)])
            } else if let item = item.item.topItems.first {
                file = item.file
            }
            self.contentNode?.userInteractionEnabled = false
            self.contentNode?.isEventLess = true
            if let file = file {
                self.contentNode?.update(with: file, size: NSMakeSize(25, 25), context: item.context, parent: nil, table: item.table, parameters: nil, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
            }
            
        }
        
        
        super.set(item: item, animated: animated)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        self.contentNode?.center()
        unread.setFrameOrigin(NSMakePoint(frame.width - unread.frame.width, 0))
    }
}

private final class FeaturedHorizontalView : HorizontalRowView {

    private let stickerFetchedDisposable = MetaDisposable()
    private var imageView:TransformImageView?
    
    private let unread: View = View(frame: NSMakeRect(0, 0, 6, 6))

    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)

        addSubview(unread)
        unread.layer?.cornerRadius = 3

    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let item = self.item as? FeaturedHorizontalItem {
            item.click(item.item)
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        
        self.imageView?.center()
        unread.setFrameOrigin(NSMakePoint(frame.width - unread.frame.width, 0))
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            self.imageView?.removeFromSuperview()
            self.imageView = nil
        } else if let item = item, self.imageView == nil {
            self.set(item: item, animated: false)
        }
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        super.set(item: item, animated: animated)

        guard let context = (item as? FeaturedHorizontalItem)?.context else {
            return
        }
        
        guard let item = (item as? FeaturedHorizontalItem)?.item else {
            return
        }
        
        unread.isHidden = !item.unread
        unread.backgroundColor = theme.colors.accent

        
        var thumbnailItem: TelegramMediaImageRepresentation?
        var resourceReference: MediaResourceReference?
        
        var file: TelegramMediaFile?

        
        if let thumbnail = item.info.thumbnail {
            thumbnailItem = thumbnail
            resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: item.info.id.id, accessHash: item.info.accessHash), resource: thumbnail.resource)
            file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: nil, attributes: [.FileName(fileName: "sticker.webp"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
        } else if let item = item.topItems.first, let dimensions = item.file.dimensions, let resource = chatMessageStickerResource(file: item.file, small: true) as? TelegramMediaResource {
            thumbnailItem = TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil)
            resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: resource)
            file = item.file
        }
        
        if self.imageView == nil {
            self.imageView = TransformImageView()
            self.addSubview(self.imageView!)
        }
        guard let imageView = self.imageView else {
            return
        }
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: NSMakeSize(25, 25), boundingSize: NSMakeSize(25, 25), intrinsicInsets: NSEdgeInsets())

        if let thumbnailItem = thumbnailItem {
            if let file = file {
                imageView.setSignal(signal: cachedMedia(media: file , arguments: arguments, scale: backingScaleFactor))
            }
            if !imageView.isFullyLoaded {
                imageView.setSignal(chatMessageStickerPackThumbnail(postbox: context.account.postbox, representation: thumbnailItem, scale: backingScaleFactor, synchronousLoad: false), cacheImage: { result in
                    if let file = file {
                        cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
                    }
                })
            }
        }
        imageView.set(arguments:arguments)
        imageView.setFrameSize(arguments.imageSize)
        if let resourceReference = resourceReference {
            stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: resourceReference, statsCategory: .file).start())
        }
        self.needsLayout = true
        
    }
}

final class StickerPackTrendingItem : GeneralRowItem {
    fileprivate let collectionId: StickerPackCollectionId
    fileprivate let featured:[FeaturedStickerPackItem]
    fileprivate let items: [FeaturedHorizontalItem]
    fileprivate let close: (Int64)->Void
    init(_ initialSize: NSSize, context: AccountContext, featured: [FeaturedStickerPackItem], collectionId: StickerPackCollectionId, close: @escaping(Int64)->Void, click:@escaping(FeaturedStickerPackItem)->Void) {
        self.collectionId = collectionId
        self.featured = featured
        self.close = close
        var items:[FeaturedHorizontalItem] = []
        for featured in featured {
            items.append(.init(NSMakeSize(30, 30), context: context, item: featured, click: click))
        }
        self.items = items
        super.init(initialSize, height: 50, stableId: collectionId)
    }
    
    
    override func viewClass() -> AnyClass {
        return StickerPackTrendingView.self
    }
}

private final class HorizontalInsetItem : TableRowItem {
    override var width: CGFloat {
        return 8
    }
    override var height: CGFloat {
        return 8
    }
    override var stableId: AnyHashable {
        return arc4random()
    }
    override func viewClass() -> AnyClass {
        return HorizontalInsetView.self
    }
}
private final class HorizontalInsetView: HorizontalRowView {
    
}

private final class StickerPackTrendingView : TableRowView {
    private let tableView: HorizontalTableView = HorizontalTableView(frame: .zero, isFlipped: true, bottomInset: 0, drawBorder: false)
    private let textView = TextView()
    private let close: ImageButton = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(textView)
        addSubview(close)
//        close.autohighlight = false
//        close.scaleOnClick = true
        tableView.getBackgroundColor = {
            .clear
        }
        
        self.close.set(handler: { [weak self] _ in
            if let item = self?.item as? StickerPackTrendingItem {
                if let id = item.featured.first?.info.id.id {
                    item.close(id)
                }
            }
        }, for: .Click)
    }
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }
    
    override func updateColors() {
        super.updateColors()
    }
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StickerPackTrendingItem else {
            return
        }
        
        self.close.set(image: theme.icons.wallpaper_color_close, for: .Normal)
        _ = self.close.sizeToFit()
        
        
        let layout = TextViewLayout.init(.initialize(string: L10n.stickersTrending.uppercased(), color: theme.colors.grayText, font: .medium(.text)))
        layout.measure(width: frame.width - 30)
        textView.update(layout)
        
        tableView.beginTableUpdates()
        tableView.removeAll()
        _ = tableView.addItem(item: HorizontalInsetItem(.zero), animation: animated ? .effectFade : .none)
        for item in item.items {
            _ = tableView.addItem(item: item, animation: animated ? .effectFade : .none)
        }
        _ = tableView.addItem(item: HorizontalInsetItem(.zero), animation: animated ? .effectFade : .none)
        tableView.endTableUpdates()
        
    }
    
    override func layout() {
        super.layout()
        textView.setFrameOrigin(NSMakePoint(10, 0))
        close.setFrameOrigin(NSMakePoint(frame.width - close.frame.width, -8))
        tableView.frame = NSMakeRect(0, frame.height - 30, frame.width, 30)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
