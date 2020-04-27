//
//  StickerPackItems.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09/07/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

class StickerPackRowItem: TableRowItem {
    
    override var height:CGFloat {
        return 40.0
    }
    
    override var width: CGFloat {
        return 40
    }
    
    let info:StickerPackCollectionInfo
    let topItem:StickerPackItem?
    let context: AccountContext
    
    let _stableId:StickerPackCollectionId
    override var stableId:AnyHashable {
        return _stableId
    }
    let packIndex: Int
    
    init(_ initialSize:NSSize, packIndex: Int, context:AccountContext, stableId: StickerPackCollectionId, info:StickerPackCollectionInfo, topItem:StickerPackItem?) {
        self.context = context
        self.packIndex = packIndex
        self._stableId = stableId
        self.info = info
        self.topItem = topItem
        super.init(initialSize)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items:[ContextMenuItem] = []
        let context = self.context
        
        switch _stableId {
        case let .pack(id):
            items.append(ContextMenuItem.init(L10n.stickersContextArchive, handler: {
                _ = removeStickerPackInteractively(postbox: context.account.postbox, id: id, option: RemoveStickerPackOption.archive).start()
            }))
            
            
            #if BETA || ALPHA || DEBUG
            if let resource = info.thumbnail?.resource {
                items.append(ContextMenuItem("Copy Pack Thumbnail (Dev.)", handler: {
                    let signal = context.account.postbox.mediaBox.resourceData(resource) |> take(1) |> deliverOnMainQueue
                    _ = signal.start(next: { data in
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            _ = getAnimatedStickerThumb(data: data, size: NSMakeSize(128, 128)).start(next: { path in
                                if let path = path {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.writeObjects([NSURL(fileURLWithPath: path)])
                                }
                            })
                        }
                    })
                }))
            }
            #endif
        default:
            break
        }
        return .single(items)
    }
    
    func contentNode()->ChatMediaContentView.Type {
        return MediaAnimatedStickerView.self
    }
    
    override func viewClass() -> AnyClass {
        if let file = topItem?.file, file.isAnimatedSticker {
            return AnimatedStickerPackRowView.self
        } else {
            return StickerPackRowView.self
        }
    }
}

class RecentPackRowItem: TableRowItem {
    
    override var height:CGFloat {
        return 40.0
    }
    override var width: CGFloat {
        return 40.0
    }
    
    let _stableId:StickerPackCollectionId
    override var stableId:AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, _ stableId:StickerPackCollectionId) {
        self._stableId = stableId
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return RecentPackRowView.self
    }
}


class StickerPackRowView: HorizontalRowView {
    
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    private var imageView:TransformImageView?
    
    private let overlay:ImageButton = ImageButton()
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        overlay.setFrameSize(35, 35)
        overlay.userInteractionEnabled = false
        overlay.autohighlight = false
        overlay.canHighlight = false
        addSubview(overlay)
        
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        
        self.imageView?.center()
        self.overlay.center()
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
        
        var mediaUpdated = true
        if let lhs = (self.item as? StickerPackRowItem)?.topItem, let rhs = (item as? StickerPackRowItem)?.topItem {
            mediaUpdated = !lhs.file.isEqual(to: rhs.file)
        }
        
        super.set(item: item, animated: animated)
        overlay.set(image: theme.icons.stickerPackSelection, for: .Normal)
        overlay.set(image: theme.icons.stickerPackSelectionActive, for: .Highlight)
        overlay.isSelected = item.isSelected
        
        if let item = item as? StickerPackRowItem {
            var thumbnailItem: TelegramMediaImageRepresentation?
            var resourceReference: MediaResourceReference?
            
            var file: TelegramMediaFile?

            
            if let thumbnail = item.info.thumbnail {
                thumbnailItem = thumbnail
                resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: item.info.id.id, accessHash: item.info.accessHash), resource: thumbnail.resource)
                file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], immediateThumbnailData: nil, mimeType: "image/webp", size: nil, attributes: [.FileName(fileName: "sticker.webp"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
            } else if let item = item.topItem, let dimensions = item.file.dimensions, let resource = chatMessageStickerResource(file: item.file, small: true) as? TelegramMediaResource {
                thumbnailItem = TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource)
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
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: NSMakeSize(30, 30), boundingSize: NSMakeSize(30, 30), intrinsicInsets: NSEdgeInsets())

            if let thumbnailItem = thumbnailItem {
                if let file = file {
                    imageView.setSignal(signal: cachedMedia(media: file , arguments: arguments, scale: backingScaleFactor))
                }
                if !imageView.isFullyLoaded {
                    imageView.setSignal( chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, representation: thumbnailItem, scale: backingScaleFactor, synchronousLoad: false), cacheImage: { result in
                        if let file = file {
                            cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
                        }
                    })
                }
            }
            imageView.set(arguments:arguments)
            imageView.setFrameSize(arguments.imageSize)
            if let resourceReference = resourceReference {
                stickerFetchedDisposable.set(fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: resourceReference, statsCategory: .file).start())
            }
            self.needsLayout = true
        }
        
        
    }
    
}

class RecentPackRowView: HorizontalRowView {
    
    var imageView:ImageView = ImageView()
    
    var overlay:ImageButton = ImageButton()
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        overlay.setFrameSize(35, 35)
        overlay.userInteractionEnabled = false
        overlay.autohighlight = false
        overlay.canHighlight = false
        imageView.setFrameSize(30, 30)

        addSubview(overlay)
        addSubview(imageView)
        
    }
    
    override func layout() {
        super.layout()
        imageView.center()
        overlay.center()
    }
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        super.set(item: item, animated: animated)
        overlay.set(image: theme.icons.stickerPackSelection, for: .Normal)
        overlay.set(image: theme.icons.stickerPackSelectionActive, for: .Highlight)
        
        overlay.isSelected = item.isSelected

        if let item = item as? RecentPackRowItem {
            self.needsLayout = true
            switch item._stableId {
            case .saved:
                imageView.image = theme.icons.stickersTabFave
            case .recent:
                imageView.image = theme.icons.stickersTabRecent
            case .featured:
                imageView.image = theme.icons.stickers_add_featured
            default:
                break
            }
            imageView.sizeToFit()
        }
        needsLayout = true
    }
    
}



class StickerSpecificPackItem: TableRowItem {
    override var height:CGFloat {
        return 40.0
    }
    override var width: CGFloat {
        return 40.0
    }
    fileprivate let specificPack: (StickerPackCollectionInfo, Peer)
    fileprivate let account: Account
    let _stableId:StickerPackCollectionId
    override var stableId:AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, stableId:StickerPackCollectionId, specificPack: (StickerPackCollectionInfo, Peer), account: Account) {
        self._stableId = stableId
        self.specificPack = specificPack
        self.account = account
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return StickerSpecificPackView.self
    }
}

class StickerSpecificPackView: HorizontalRowView {
    
    
    var imageView:AvatarControl = AvatarControl(font: .medium(.short))
    
    var overlay:ImageButton = ImageButton()
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        imageView.setFrameSize(30, 30)
        overlay.setFrameSize(35, 35)
        overlay.userInteractionEnabled = false
        overlay.autohighlight = false
        overlay.canHighlight = false
        imageView.userInteractionEnabled = false
        addSubview(overlay)
        addSubview(imageView)
    }
    
    override func layout() {
        super.layout()
        imageView.center()
        overlay.center()
    }
    
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        overlay.set(image: theme.icons.stickerPackSelection, for: .Normal)
        overlay.set(image: theme.icons.stickerPackSelectionActive, for: .Highlight)
        overlay.isSelected = item.isSelected
        if let item = item as? StickerSpecificPackItem {
            imageView.setPeer(account: item.account, peer: item.specificPack.1)
        }
    }
    
}

private final class AnimatedStickerPackRowView : HorizontalRowView {
    
    
    var overlay:ImageButton = ImageButton()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        overlay.setFrameSize(35, 35)
        overlay.autohighlight = false
        overlay.canHighlight = false
        overlay.userInteractionEnabled = false
        addSubview(overlay)
        
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
        if let item = item as? StickerPackRowItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            
            var file: TelegramMediaFile?
            if let thumbnail = item.info.thumbnail {
                file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.FileName(fileName: "sticker.tgs"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
            } else if let item = item.topItem {
                file = item.file
            }
            self.contentNode?.userInteractionEnabled = false
            self.contentNode?.isEventLess = true
            if let file = file {
                self.contentNode?.update(with: file, size: NSMakeSize(30, 30), context: item.context, parent: nil, table: item.table, parameters: nil, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
            }
            
        }
        
        overlay.set(image: theme.icons.stickerPackSelection, for: .Normal)
        overlay.set(image: theme.icons.stickerPackSelectionActive, for: .Highlight)
        
        overlay.isSelected = item.isSelected
        
        super.set(item: item, animated: animated)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        self.contentNode?.center()
        overlay.center()
    }
}
