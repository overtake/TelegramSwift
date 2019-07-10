//
//  StickerSetTableRowItem.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


enum ItemListStickerPackItemControl: Equatable {
    case none
    case installation(installed: Bool)
    case remove
    case empty
    case selected
}

class StickerSetTableRowItem: TableRowItem {
    
    fileprivate let context: AccountContext
    fileprivate let info:StickerPackCollectionInfo
    fileprivate let topItem:StickerPackItem?
    fileprivate let unread: Bool
    fileprivate let editing: ItemListStickerPackItemEditing
    fileprivate let enabled:Bool
    fileprivate let _stableId:AnyHashable
    fileprivate let itemCount:Int32
    fileprivate let control: ItemListStickerPackItemControl
    fileprivate let nameLayout:TextViewLayout
    fileprivate let countLayout:TextViewLayout
    
    let action:  () -> Void
    let addPack: () -> Void
    let removePack: () -> Void
    
    fileprivate let insets: NSEdgeInsets = NSEdgeInsets(left: 30, right: 30)
    
    override var stableId: AnyHashable {
        return _stableId
    }
    init(_ initialSize: NSSize, context:AccountContext, stableId:AnyHashable, info:StickerPackCollectionInfo, topItem:StickerPackItem?, itemCount:Int32, unread: Bool, editing: ItemListStickerPackItemEditing, enabled: Bool, control: ItemListStickerPackItemControl, action:@escaping()->Void, addPack:@escaping()->Void = {}, removePack:@escaping() -> Void = {}) {
        self.context = context
        self._stableId = stableId
        self.info = info
        self.topItem = topItem
        self.unread = unread
        self.editing = editing
        self.enabled = enabled
        self.itemCount = itemCount
        self.control = control
        self.action = action
        self.addPack = addPack
        self.removePack = removePack
        nameLayout = TextViewLayout(.initialize(string: info.title, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        countLayout = TextViewLayout(.initialize(string: tr(L10n.stickersSetCount1Countable(Int(itemCount))), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        nameLayout.measure(width: initialSize.width - 50 - insets.left - insets.right)
        countLayout.measure(width: initialSize.width - 50 - insets.left - insets.right)
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        return 50
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        nameLayout.measure(width: width - 50 - insets.left - insets.right)
        countLayout.measure(width: width - 50 - insets.left - insets.right)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return StickerSetTableRowView.self
    }
}

class StickerSetTableRowView : TableRowView {
    private let imageView:TransformImageView = TransformImageView()
    private let nameView:TextView = TextView()
    private let countView:TextView = TextView()
    private let installationControl:ImageView = ImageView()
    private let removeControl = ImageButton()
    private var animatedView: ChatMediaAnimatedStickerView?
    private let loadedStickerPackDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        imageView.setFrameSize(NSMakeSize(35, 35))
        addSubview(nameView)
        addSubview(countView)
        countView.userInteractionEnabled = false
        nameView.userInteractionEnabled = false
        addSubview(installationControl)

        removeControl.set(handler: { [weak self] _ in
            if let item = self?.item as? StickerSetTableRowItem {
                item.removePack()
            }
        }, for: .SingleClick)
        addSubview(removeControl)
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            if let item = item as? StickerSetTableRowItem {
                let point = convert(event.locationInWindow, from: nil)
                 if NSPointInRect(point, NSMakeRect(installationControl.frame.minX, 0, installationControl.frame.width, frame.height)) {
                    switch item.control {
                    case .installation:
                        item.addPack()
                    case .none:
                       break
                    case .remove:
                        item.removePack()
                    case .empty:
                        item.action()
                    case .selected:
                        break
                    }
                } else {
                    item.action()
                }
            }
        }

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = item as? StickerSetTableRowItem {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(item.insets.left + 50, frame.height - .borderSize, frame.width - item.insets.left - item.insets.right - 50, .borderSize))
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? StickerSetTableRowItem {
            imageView.centerY(x: item.insets.left)
            nameView.update(item.nameLayout, origin: NSMakePoint(item.insets.left + 50, 7))
            countView.update(item.countLayout, origin: NSMakePoint(item.insets.left + 50, frame.height - item.countLayout.layoutSize.height - 7))
            installationControl.centerY(x: frame.width - item.insets.left - installationControl.frame.width)
            removeControl.centerY(x: frame.width - item.insets.left - removeControl.frame.width)
            animatedView?.centerY(x: item.insets.left)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? StickerSetTableRowItem {
            nameView.backgroundColor = backdorColor
            countView.backgroundColor = backdorColor
            
            removeControl.set(image: theme.icons.stickerPackDelete, for: .Normal)
            _ = removeControl.sizeToFit()
            
            if item.info.flags.contains(.isAnimated) {
                
                if self.animatedView == nil {
                    self.animatedView = ChatMediaAnimatedStickerView(frame: NSZeroRect)
                    addSubview(self.animatedView!)
                }
                self.imageView.isHidden = true
                
                var file: TelegramMediaFile?
                if let thumbnail = item.info.thumbnail {
                    file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.FileName(fileName: "sticker.tgs"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
                } else if let item = item.topItem {
                    file = item.file
                }
                self.animatedView?.userInteractionEnabled = false
                if let file = file {
                    self.animatedView?.update(with: file, size: NSMakeSize(35, 35), context: item.context, parent: nil, table: item.table, parameters: nil, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
                }
            } else {
                
                self.animatedView?.removeFromSuperview()
                self.animatedView = nil
                
                 self.imageView.isHidden = false
                
                var thumbnailItem: TelegramMediaImageRepresentation?
                var resourceReference: MediaResourceReference?
                
                if let thumbnail = item.info.thumbnail {
                    thumbnailItem = thumbnail
                    resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: item.info.id.id, accessHash: item.info.accessHash), resource: thumbnail.resource)
                } else if let topItem = item.topItem {
                    let dimensions = topItem.file.dimensions ?? NSMakeSize(35, 35)
                    thumbnailItem = TelegramMediaImageRepresentation(dimensions: dimensions, resource: topItem.file.resource)
                    resourceReference = MediaResourceReference.media(media: .stickerPack(stickerPack: StickerPackReference.id(id: item.info.id.id, accessHash: item.info.accessHash), media: topItem.file), resource: topItem.file.resource)
                }
                if let thumbnailItem = thumbnailItem {
                    imageView.setSignal(chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, representation: thumbnailItem, scale: backingScaleFactor, synchronousLoad: false))
                }
                if let resourceReference = resourceReference {
                    _ = fetchedMediaResource(postbox: item.context.account.postbox, reference: resourceReference, statsCategory: .file).start()
                }
                imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: NSMakeSize(35, 35), boundingSize: NSMakeSize(35, 35), intrinsicInsets: NSEdgeInsets()))
            }
           
            nameView.update(item.nameLayout, origin: NSMakePoint(item.insets.left + 50, 7))
            countView.update(item.countLayout, origin: NSMakePoint(item.insets.left + 50, frame.height - item.countLayout.layoutSize.height - 7))
            switch item.control {
            case let .installation(installed: installed):
                installationControl.isHidden = false
                removeControl.isHidden = true
                installationControl.image = installed ? theme.icons.stickersAddedFeatured : theme.icons.stickersAddFeatured
                installationControl.sizeToFit()
                installationControl.centerY(x: frame.width - item.insets.left - installationControl.frame.width)
            case .none:
                installationControl.isHidden = true
                removeControl.isHidden = false
                removeControl.centerY(x: frame.width - item.insets.left - removeControl.frame.width)
            case .remove:
                removeControl.isHidden = true
                installationControl.isHidden = false
                installationControl.image = theme.icons.stickersRemove
                installationControl.sizeToFit()
                installationControl.centerY(x: frame.width - item.insets.left - installationControl.frame.width)
            case .empty:
                removeControl.isHidden = true
                installationControl.isHidden = true
            case .selected:
                removeControl.isHidden = true
                installationControl.isHidden = false
                installationControl.image = theme.icons.generalSelect
                installationControl.sizeToFit()
                installationControl.centerY(x: frame.width - item.insets.left - installationControl.frame.width)
            }
        }
        needsLayout = true
    }
    
    deinit {
        loadedStickerPackDisposable.dispose()
    }
    
}
