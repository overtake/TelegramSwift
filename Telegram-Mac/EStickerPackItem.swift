//
//  StickerPackItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 25/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac



class EStickerPackRowItem: TableRowItem {
    
    override var height:CGFloat {
        return 40.0
    }
    
    override var width: CGFloat {
        return 40
    }

    var info:StickerPackCollectionInfo
    var topItem:StickerPackItem?
    var context: AccountContext
    var interaction:EStickersInteraction
    private var packIndex:Int
    
    let _stableId:ChatMediaGridCollectionStableId
    override var stableId:AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, _ context:AccountContext, _ index:Int, _ stableId:ChatMediaGridCollectionStableId, _ info:StickerPackCollectionInfo, _ topItem:StickerPackItem?, _ interaction:EStickersInteraction) {
        self.context = context
        self._stableId = stableId
        self.info = info
        self.topItem = topItem
        self.packIndex = index
        self.interaction = interaction
        super.init(initialSize)
    }
    
    func contentNode()->ChatMediaContentView.Type {
        return ChatMediaAnimatedStickerView.self
    }
    
    override func viewClass() -> AnyClass {
        if let file = topItem?.file, file.isAnimatedSticker {
            return EAnimatedStickerPackRowView.self
        } else {
            return EStickerPackRowView.self
        }
    }
}

class ERecentPackRowItem: TableRowItem {
    
    override var height:CGFloat {
        return 40.0
    }
    override var width: CGFloat {
        return 40
    }
    let interaction:EStickersInteraction
    
    let _stableId:ChatMediaGridCollectionStableId
    override var stableId:AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, _ stableId:ChatMediaGridCollectionStableId, _ interaction:EStickersInteraction) {
        self._stableId = stableId
        self.interaction = interaction
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return ERecentPackRowView.self
    }
}


class EStickerPackRowView: HorizontalRowView {
    
    private let boundingSize = CGSize(width: 40.0, height: 40.0)
    private let imageSize = CGSize(width: 26, height: 26)
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var imageView:TransformImageView = TransformImageView()
    
    var overlay:OverlayControl = OverlayControl()
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        overlay.frame = NSMakeRect(2.0, 2.0, bounds.width - 4.0, bounds.height - 4.0)
        overlay.layer?.cornerRadius = .cornerRadius
        addSubview(overlay)
        
        
        imageView.frame = self.bounds
        addSubview(imageView)
        
        overlay.set(handler: { [weak self] _ in
            
            if let item = self?.item as? EStickerPackRowItem {
                item.interaction.navigateToCollectionId(item._stableId)
            }
            
        }, for: .Down)
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        
        overlay.setFrameSize(30, 30)
        overlay.center()
    }

    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        var mediaUpdated = true
        if let lhs = (self.item as? EStickerPackRowItem)?.topItem, let rhs = (item as? EStickerPackRowItem)?.topItem {
            mediaUpdated = !lhs.file.isEqual(to: rhs.file)
        }
        
        super.set(item: item, animated: animated)
        overlay.set(background: theme.colors.grayBackground, for: .Highlight)
        overlay.set(background: theme.colors.background, for: .Normal)

        overlay.isSelected = item.isSelected

        if let item = item as? EStickerPackRowItem, mediaUpdated {
            var thumbnailItem: TelegramMediaImageRepresentation?
            var resourceReference: MediaResourceReference?
            if let thumbnail = item.info.thumbnail {
                thumbnailItem = thumbnail
                resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: item.info.id.id, accessHash: item.info.accessHash), resource: thumbnail.resource)
            } else if let item = item.topItem, let dimensions = item.file.dimensions, let resource = chatMessageStickerResource(file: item.file, small: true) as? TelegramMediaResource {
                thumbnailItem = TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource)
                resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: resource)
            }
            
            if let thumbnailItem = thumbnailItem {
                imageView.setSignal( chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, representation: thumbnailItem, scale: backingScaleFactor, synchronousLoad: false))
                
            }
            //   imageView.setSignal( chatMessageStickerPackThumbnail(account: item.account, fileReference: FileMediaReference.stickerPack(stickerPack: topItem.file.stickerReference!, media: topItem.file), type: .thumb, scale: backingScaleFactor))
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize:imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
            imageView.set(arguments:arguments)
            imageView.setFrameSize(arguments.imageSize)
            // _ = fileInteractiveFetched(account: item.account, fileReference: FileMediaReference.stickerPack(stickerPack: topItem.file.stickerReference!, media: topItem.file)).start()
            //   _ = fileInteractiveFetched(account: item.account, fileReference: resourceReference).start()
            if let resourceReference = resourceReference {
                _ = fetchedMediaResource(postbox: item.context.account.postbox, reference: resourceReference, statsCategory: .file).start()
            }
            self.needsLayout = true
        }
        
    }
    
}



class ERecentPackRowView: HorizontalRowView {
    
    private let boundingSize = CGSize(width: 40.0, height: 40.0)
    private let imageSize = CGSize(width: 26, height: 26)
    
    
    var imageView:ImageView = ImageView()
    
    var overlay:OverlayControl = OverlayControl()
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        overlay.frame = NSMakeRect(2.0, 2.0, bounds.width - 4.0, bounds.height - 4.0)
        overlay.layer?.cornerRadius = .cornerRadius
        
        addSubview(overlay)
        
        addSubview(imageView)
        
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? ERecentPackRowItem {
                item.interaction.navigateToCollectionId(item._stableId)
            }
        }, for: .Down)
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        
        overlay.setFrameSize(30, 30)
        overlay.center()
    }
    
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        super.set(item: item, animated: animated)
        overlay.isSelected = item.isSelected
        overlay.set(background: theme.colors.background, for: .Normal)
        overlay.set(background: theme.colors.grayForeground, for: .Highlight)

        if let item = item as? ERecentPackRowItem {
            self.needsLayout = true
            switch item._stableId {
            case .saved:
                imageView.image = theme.icons.stickersTabFave
            case .recent:
                imageView.image = theme.icons.stickersTabRecent
            default:
                break
            }
            imageView.sizeToFit()
            
        }
        
    }
    
}



class EStickerSpecificPackItem: TableRowItem {
    override var height:CGFloat {
        return 40.0
    }
    override var width: CGFloat {
        return 40
    }
    let interaction:EStickersInteraction
    fileprivate let specificPack: (StickerPackCollectionInfo, Peer)
    fileprivate let account: Account
    let _stableId:ChatMediaGridCollectionStableId
    override var stableId:AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, _ stableId:ChatMediaGridCollectionStableId, specificPack: (StickerPackCollectionInfo, Peer), account: Account, _ interaction:EStickersInteraction) {
        self._stableId = stableId
        self.interaction = interaction
        self.specificPack = specificPack
        self.account = account
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return EStickerSpecificPackView.self
    }
}

class EStickerSpecificPackView: HorizontalRowView {
    
    private let boundingSize = CGSize(width: 40.0, height: 40.0)
    private let imageSize = CGSize(width: 26, height: 26)
    
    
    var imageView:AvatarControl = AvatarControl(font: .medium(.short))
    
    var overlay:OverlayControl = OverlayControl()
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        overlay.frame = NSMakeRect(2.0, 2.0, bounds.width - 4.0, bounds.height - 4.0)
        overlay.layer?.cornerRadius = .cornerRadius
        
        addSubview(overlay)
        
        addSubview(imageView)
        imageView.setFrameSize(26, 26)
        imageView.set(handler: { [weak self] _ in
            if let item = self?.item as? EStickerSpecificPackItem {
                item.interaction.navigateToCollectionId(item._stableId)
            }
        }, for: .Down)
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        
        overlay.setFrameSize(30, 30)
        overlay.center()
    }
    
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        super.set(item: item, animated: animated)
        overlay.isSelected = item.isSelected
        overlay.set(background: theme.colors.background, for: .Normal)
        overlay.set(background: theme.colors.grayBackground, for: .Highlight)
        if let item = item as? EStickerSpecificPackItem {
            imageView.setPeer(account: item.account, peer: item.specificPack.1)
        }
        
    }
    
}

private final class EAnimatedStickerPackRowView : HorizontalRowView {

    
    var overlay:OverlayControl = OverlayControl()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        overlay.layer?.cornerRadius = .cornerRadius
        
        addSubview(overlay)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate(set) var contentNode:ChatMediaContentView?
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode?.needsDisplay = true
        }
    }
    
    override var backgroundColor: NSColor {
        didSet {
            
            contentNode?.backgroundColor = backdorColor
        }
    }
    
    override func shakeView() {
        contentNode?.shake()
    }
    
    
    override func updateMouse() {
        super.updateMouse()
        self.contentNode?.updateMouse()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        if let item = self.item as? EStickerPackRowItem {
            item.interaction.navigateToCollectionId(item._stableId)
        }
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        if let item = item as? EStickerPackRowItem {
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
            if let file = file {
                self.contentNode?.update(with: file, size: NSMakeSize(26, 26), context: item.context, parent: nil, table: item.table, parameters: nil, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
            }
            
        }
        
        overlay.isSelected = item.isSelected
        overlay.set(background: theme.colors.background, for: .Normal)
        overlay.set(background: theme.colors.grayBackground, for: .Highlight)
        
        super.set(item: item, animated: animated)
    }
    
    override func layout() {
        super.layout()
        
        self.contentNode?.center()

        overlay.setFrameSize(30, 30)
        overlay.center()
    }
}
