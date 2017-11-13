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

    var info:StickerPackCollectionInfo
    var topItem:StickerPackItem?
    var account:Account
    var interaction:EStickersInteraction
    private var packIndex:Int
    
    let _stableId:ChatMediaGridCollectionStableId
    override var stableId:AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, _ account:Account, _ index:Int, _ stableId:ChatMediaGridCollectionStableId, _ info:StickerPackCollectionInfo, _ topItem:StickerPackItem?, _ interaction:EStickersInteraction) {
        self.account = account
        self._stableId = stableId
        self.info = info
        self.topItem = topItem
        self.packIndex = index
        self.interaction = interaction
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return EStickerPackRowView.self
    }
}

class ERecentPackRowItem: TableRowItem {
    
    override var height:CGFloat {
        return 40.0
    }
        var interaction:EStickersInteraction
    
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
    private let imageSize = CGSize(width: 30.0, height: 30.0)
    
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
            
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        
        overlay.setFrameSize(38, 38)
        overlay.layer?.cornerRadius = .cornerRadius
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
            mediaUpdated = !lhs.file.isEqual(rhs.file)
        }
        
        super.set(item: item, animated: animated)
        overlay.set(background: theme.colors.grayBackground, for: .Highlight)
        overlay.set(background: theme.colors.background, for: .Normal)

        overlay.isSelected = item.isSelected

        if let item = item as? EStickerPackRowItem, mediaUpdated {
            if let topItem = item.topItem, let dimensions = topItem.file.dimensions {
                imageView.setSignal( chatMessageSticker(account: item.account, file: topItem.file, type: .thumb, scale: backingScaleFactor))
                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize:dimensions.aspectFitted(imageSize), boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
                imageView.set(arguments:arguments)
                imageView.setFrameSize(arguments.imageSize)
                _ = fileInteractiveFetched(account: item.account, file: topItem.file).start()
            }
            self.needsLayout = true
        }
        
    }
    
}



class ERecentPackRowView: HorizontalRowView {
    
    private let boundingSize = CGSize(width: 40.0, height: 40.0)
    private let imageSize = CGSize(width: 30.0, height: 30.0)
    
    
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
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        
        overlay.setFrameSize(38, 38)
        overlay.layer?.cornerRadius = .cornerRadius
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
    private let imageSize = CGSize(width: 30.0, height: 30.0)
    
    
    var imageView:AvatarControl = AvatarControl(font: .medium(.short))
    
    var overlay:OverlayControl = OverlayControl()
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        overlay.frame = NSMakeRect(2.0, 2.0, bounds.width - 4.0, bounds.height - 4.0)
        overlay.layer?.cornerRadius = .cornerRadius
        
        addSubview(overlay)
        
        addSubview(imageView)
        imageView.setFrameSize(30, 30)
        imageView.set(handler: { [weak self] _ in
            if let item = self?.item as? EStickerSpecificPackItem {
                item.interaction.navigateToCollectionId(item._stableId)
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        
        overlay.setFrameSize(38, 38)
        overlay.layer?.cornerRadius = .cornerRadius
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

