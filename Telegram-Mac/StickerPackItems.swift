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

import Postbox
import SwiftSignalKit

class StickerPackRowItem: TableRowItem {
    
    override var height:CGFloat {
        return 36
    }
    
    override var width: CGFloat {
        return 36
    }
    
    let info:StickerPackCollectionInfo
    let topItem:StickerPackItem?
    let context: AccountContext
    
    let _stableId:AnyHashable
    override var stableId:AnyHashable {
        return _stableId
    }
    let packIndex: Int
    let isPremium: Bool
    let installed: Bool?
    
    init(_ initialSize:NSSize, stableId: AnyHashable, packIndex: Int, isPremium: Bool, installed: Bool? = nil, context:AccountContext, info:StickerPackCollectionInfo, topItem:StickerPackItem?) {
        self.context = context
        self.packIndex = packIndex
        self._stableId = stableId
        self.info = info
        self.topItem = topItem
        self.isPremium = isPremium
        self.installed = installed
        super.init(initialSize)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items:[ContextMenuItem] = []
        let context = self.context
        let info = info.id
        
        let id = ItemCollectionId(namespace: info.namespace, id: info.id)
        
        let text: String
        let option: RemoveStickerPackOption
        let animation: MenuAnimation
        if info.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
            text = strings().emojiContextRemove
            option = .delete
            animation = .menu_delete
        } else {
            text = strings().stickersContextArchive
            option = .archive
            animation = .menu_archive
        }
        
        items.append(ContextMenuItem(strings().emojiContextRemove, handler: {
            _ = context.engine.stickers.removeStickerPackInteractively(id: id, option: option).start()
        }, itemImage: animation.value))
        
        return .single(items)
    }
    
    func animateAppearance(delay: Double, duration: Double, ignoreCount: Int) {
        (self.view as? StickerPackRowView)?.animateAppearance(delay: delay, duration: duration, ignoreCount: ignoreCount)
    }
    
    override func viewClass() -> AnyClass {
        return StickerPackRowView.self
    }
}

class RecentPackRowItem: TableRowItem {
    
    override var height:CGFloat {
        return 36
    }
    override var width: CGFloat {
        return 36
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

class RecentPackRowView: HorizontalRowView {
    
    var imageView:ImageView = ImageView()
    
    
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        imageView.setFrameSize(30, 30)
        addSubview(imageView)
        
    }
    
    override func layout() {
        super.layout()
        imageView.center()
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        super.set(item: item, animated: animated)
        
        if let item = item as? RecentPackRowItem {
            self.needsLayout = true
            switch item._stableId {
            case .saved:
                imageView.image = item.isSelected ? theme.icons.stickers_favorite_active : theme.icons.stickers_favorite
            case .recent:
                imageView.image = item.isSelected ? theme.icons.emojiRecentTabActive : theme.icons.emojiRecentTab
            case .premium:
                imageView.image = theme.icons.premium_stickers
            case let .featured(hasUnred):
                if item.isSelected {
                    imageView.image = hasUnred ? theme.icons.stickers_add_featured_unread_active : theme.icons.stickers_add_featured_active
                } else {
                    imageView.image = hasUnred ? theme.icons.stickers_add_featured_unread : theme.icons.stickers_add_featured
                }
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
        return 36
    }
    override var width: CGFloat {
        return 36
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
        
    required init(frame frameRect:NSRect) {
        super.init(frame:frameRect)
        
        imageView.setFrameSize(30, 30)
        imageView.userInteractionEnabled = false
        addSubview(imageView)
    }
    
    override func layout() {
        super.layout()
        imageView.center()
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        if let item = item as? StickerSpecificPackItem {
            imageView.setPeer(account: item.account, peer: item.specificPack.1)
        }
    }
    
}

private final class StickerPackRowView : HorizontalRowView {
    
    private var inlineSticker: InlineStickerItemLayer?
    
    
    
    func animateAppearance(delay: Double, duration: Double, ignoreCount: Int) {
        self.inlineSticker?.animateScale(from: 0.1, to: 1, duration: duration, timingFunction: .spring, delay: delay)
        self.lockedView?.animateScale(from: 0.1, to: 1, duration: duration, timingFunction: .spring, delay: delay)
    }
    
    private var lockedView: InlineStickerLockLayer?

    
    private var isLocked: Bool = false
    func set(locked: Bool, unlock: Bool, animated: Bool) {
        self.isLocked = locked
        if isLocked {
            let current: InlineStickerLockLayer
            if let view = self.lockedView {
                current = view
            } else {
                current = InlineStickerLockLayer(frame: NSMakeRect(0, 0, 15, 15))
                self.lockedView = current
                if animated {
                    current.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.removeFromSuperlayer()
            self.container.layer?.addSublayer(current)

            current.updateImage(unlock ? theme.icons.premium_lock : theme.icons.premium_plus)
            if let layer = self.inlineSticker {
                current.tieToLayer(layer)
            }
        } else if let view = lockedView {
            performSublayerRemoval(view, animated: animated)
            self.lockedView = nil
        }
        needsLayout = true
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    private func updateListeners() {
        let center = NotificationCenter.default
        if let window = window {
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
        } else {
            center.removeObserver(self)
        }
    }

    @objc func updateAnimatableContent() -> Void {
        if let value = self.inlineSticker, let superview = value.superview {
            var isKeyWindow: Bool = false
            if let window = window {
                if !window.canBecomeKey {
                    isKeyWindow = true
                } else {
                    isKeyWindow = window.isKeyWindow
                }
            }
            value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && isKeyWindow
        }
    }

    
    override func layout() {
        super.layout()
        if let lockedView = lockedView {
            let point = NSMakePoint(frame.width - lockedView.frame.width - 4, frame.height - lockedView.frame.height - 4)
            lockedView.frame = CGRect.init(origin: point, size: lockedView.frame.size)
        }
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        super.set(item: item, animated: animated)

        
        if let item = item as? StickerPackRowItem {
            
            var file: TelegramMediaFile?
            if let thumbnail = item.info.thumbnail {
                file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], videoThumbnails: [], immediateThumbnailData: item.info.immediateThumbnailData, mimeType: item.info.flags.contains(.isVideo) ? "video/webm" : "application/x-tgsticker", size: nil, attributes: [.FileName(fileName: item.info.flags.contains(.isVideo) ? "webm-preview" : "sticker.tgs"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
            } else if let item = item.topItem {
                file = item.file
            }
            
            
            let current: InlineStickerItemLayer?
            if let view = self.inlineSticker, view.file?.fileId == file?.fileId {
                current = view
            } else {
                self.inlineSticker?.removeFromSuperlayer()
                self.inlineSticker = nil
                if let file = file {
                    current = InlineStickerItemLayer(account: item.context.account, file: file, size: NSMakeSize(26, 26))
                    self.container.layer?.addSublayer(current!)
                    self.inlineSticker = current
                } else {
                    current = nil
                }
            }
            current?.superview = self.container
            current?.frame = CGRect(origin: NSMakePoint(5, 5), size: NSMakeSize(26, 26))
            
            let unlock: Bool
            if !item.context.isPremium && item.isPremium {
                unlock = true
            } else if (item.installed != nil && !item.installed!) {
                unlock = false
            } else {
                unlock = true
            }
            
            self.set(locked: (!item.context.isPremium && item.isPremium) || (item.installed != nil && !item.installed!), unlock: unlock, animated: animated)

            self.updateAnimatableContent()
            self.updateListeners()
        }
        
        
        needsLayout = true
    }
    
}





class ETabRowItem: TableRowItem {
    
    let icon:CGImage
    let iconSelected: CGImage
        
    override func viewClass() -> AnyClass {
        return ETabRowView.self
    }
    
    let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return 36
    }
    
    override var width: CGFloat {
        return 36
    }
    
    init(_ initialSize:NSSize, stableId: AnyHashable, icon: CGImage, iconSelected: CGImage) {
        self.icon = icon
        self._stableId = stableId
        self.iconSelected = iconSelected
        super.init(initialSize)
    }
    
    func animateAppearance(delay: Double, duration: Double, ignoreCount: Int) {
        (self.view as? ETabRowView)?.animateAppearance(delay: delay, duration: duration, ignoreCount: ignoreCount)
    }
    
}



class ETabRowView: HorizontalRowView {
    
    private let image:ImageView = ImageView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    
        addSubview(image)

        image.isEventLess = true

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
    }
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        image.center()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated:animated)
        if let item = item as? ETabRowItem {
            image.image = item.isSelected ? item.iconSelected : item.icon
            image.sizeToFit()
        }
        needsLayout = true
    }
    
    func animateAppearance(delay: Double, duration: Double, ignoreCount: Int) {
        image.layer?.animateScaleSpring(from: 0.1, to: 1, duration: duration, delay: delay)
    }
}
