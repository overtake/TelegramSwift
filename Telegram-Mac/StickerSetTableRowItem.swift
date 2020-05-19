//
//  StickerSetTableRowItem.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit


enum ItemListStickerPackItemControl: Equatable {
    case none
    case installation(installed: Bool)
    case remove
    case empty
    case selected
}

class StickerSetTableRowItem: GeneralRowItem {
    
    fileprivate let context: AccountContext
    fileprivate let info:StickerPackCollectionInfo
    fileprivate let topItem:StickerPackItem?
    fileprivate let unread: Bool
    fileprivate let editing: ItemListStickerPackItemEditing
    fileprivate let _stableId:AnyHashable
    fileprivate let itemCount:Int32
    fileprivate let control: ItemListStickerPackItemControl
    fileprivate let nameLayout:TextViewLayout
    fileprivate let countLayout:TextViewLayout
    
    let addPack: () -> Void
    let removePack: () -> Void
    
    init(_ initialSize: NSSize, context:AccountContext, stableId:AnyHashable, info:StickerPackCollectionInfo, topItem:StickerPackItem?, itemCount:Int32, unread: Bool, editing: ItemListStickerPackItemEditing, enabled: Bool, control: ItemListStickerPackItemControl, viewType: GeneralViewType = .legacy, action:@escaping()->Void, addPack:@escaping()->Void = {}, removePack:@escaping() -> Void = {}) {
        self.context = context
        self._stableId = stableId
        self.info = info
        self.topItem = topItem
        self.unread = unread
        self.editing = editing
        self.itemCount = itemCount
        self.control = control
        self.addPack = addPack
        self.removePack = removePack
        nameLayout = TextViewLayout(.initialize(string: info.title, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        countLayout = TextViewLayout(.initialize(string: L10n.stickersSetCount1Countable(Int(itemCount)), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 50, stableId: stableId, type: .none, viewType: viewType, action: action, inset: NSEdgeInsets(left: 30, right: 30), enabled: enabled)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }

    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        switch self.viewType {
        case .legacy:
            nameLayout.measure(width: width - 50 - inset.left - inset.right)
            countLayout.measure(width: width - 50 - inset.left - inset.right)
        case let .modern(_, insets):
            nameLayout.measure(width: self.blockWidth - 80 - insets.left - insets.right)
            countLayout.measure(width: self.blockWidth - 80 - insets.left - insets.right)
        }
        return success
    }
    
    override func viewClass() -> AnyClass {
        return StickerSetTableRowView.self
    }
}

class StickerSetTableRowView : TableRowView, ViewDisplayDelegate {
    
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    
    private let imageView:TransformImageView = TransformImageView()
    private let nameView:TextView = TextView()
    private let countView:TextView = TextView()
    private let installationControl:ImageView = ImageView()
    private let removeControl = ImageButton()
    private var animatedView: MediaAnimatedStickerView?
    private let loadedStickerPackDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(imageView)
        imageView.setFrameSize(NSMakeSize(35, 35))
        containerView.addSubview(nameView)
        containerView.addSubview(countView)
        countView.userInteractionEnabled = false
        nameView.userInteractionEnabled = false
        containerView.addSubview(installationControl)

        containerView.displayDelegate = self
        
        containerView.set(handler: { control in
            if let event = NSApp.currentEvent {
                control.superview?.mouseDown(with: event)
            }
        }, for: .Down)
        
        containerView.set(handler: { control in
            if let event = NSApp.currentEvent {
                control.superview?.mouseDragged(with: event)
            }
        }, for: .MouseDragging)
        
        containerView.set(handler: { control in
            if let event = NSApp.currentEvent {
                control.superview?.mouseUp(with: event)
            }
        }, for: .Up)
        
        containerView.set(handler: { [weak self] _ in
            if let `self` = self, let item = self.item as? StickerSetTableRowItem, let event = NSApp.currentEvent {
                let point = self.containerView.convert(event.locationInWindow, from: nil)
                if NSPointInRect(point, self.installationControl.frame) {
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
        }, for: .Click)
        
        removeControl.set(handler: { [weak self] _ in
            if let item = self?.item as? StickerSetTableRowItem {
                item.removePack()
            }
        }, for: .SingleClick)
        containerView.addSubview(removeControl)
        self.addSubview(containerView)
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item as? StickerSetTableRowItem, layer == containerView.layer {
            ctx.setFillColor(theme.colors.border.cgColor)
            switch item.viewType {
            case .legacy:
                ctx.fill(NSMakeRect(item.inset.left + 50, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right - 50, .borderSize))
            case let .modern(position, insets):
                switch position {
                case .first, .inner:
                    ctx.fill(NSMakeRect(insets.left + 50, containerView.frame.height - .borderSize, containerView.frame.width - insets.left - insets.right - 50, .borderSize))
                default:
                    break
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? StickerSetTableRowItem {
            switch item.viewType {
            case .legacy:
                self.containerView.frame = self.bounds
                self.containerView.setCorners([])
                imageView.centerY(x: item.inset.left)
                nameView.update(item.nameLayout, origin: NSMakePoint(item.inset.left + 50, 7))
                countView.update(item.countLayout, origin: NSMakePoint(item.inset.left + 50, containerView.frame.height - item.countLayout.layoutSize.height - 7))
                installationControl.centerY(x: containerView.frame.width - item.inset.left - installationControl.frame.width)
                removeControl.centerY(x: containerView.frame.width - item.inset.left - removeControl.frame.width)
                animatedView?.centerY(x: item.inset.left)
            case let .modern(position, innerInsets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
                self.containerView.setCorners(position.corners)
                imageView.centerY(x: innerInsets.left)
                nameView.update(item.nameLayout, origin: NSMakePoint(innerInsets.left + 50, 7))
                countView.update(item.countLayout, origin: NSMakePoint(innerInsets.left + 50, containerView.frame.height - item.countLayout.layoutSize.height - 7))
                installationControl.centerY(x: containerView.frame.width - innerInsets.right - installationControl.frame.width)
                removeControl.centerY(x: containerView.frame.width - innerInsets.right - removeControl.frame.width)
                animatedView?.centerY(x: innerInsets.left)
            }
            
        }
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        nameView.backgroundColor = backdorColor
        countView.backgroundColor = backdorColor
        containerView.background = backdorColor
        if let item = item as? GeneralRowItem {
            self.backgroundColor = item.viewType.rowBackground
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        self.updateMouse()
        if let item = item as? StickerSetTableRowItem {
            
            removeControl.set(image: theme.icons.stickerPackDelete, for: .Normal)
            _ = removeControl.sizeToFit()
            
            if item.info.flags.contains(.isAnimated) {
                
                if self.animatedView == nil {
                    self.animatedView = MediaAnimatedStickerView(frame: NSZeroRect)
                    containerView.addSubview(self.animatedView!)
                }
                self.imageView.isHidden = true
                
                var file: TelegramMediaFile?
                if let thumbnail = item.info.thumbnail {
                    file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.FileName(fileName: "sticker.tgs"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
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
                    let dimensions = topItem.file.dimensions?.size ?? NSMakeSize(35, 35)
                    thumbnailItem = TelegramMediaImageRepresentation(dimensions: PixelDimensions(dimensions), resource: topItem.file.resource)
                    resourceReference = MediaResourceReference.media(media: .stickerPack(stickerPack: StickerPackReference.id(id: item.info.id.id, accessHash: item.info.accessHash), media: topItem.file), resource: topItem.file.resource)
                }
                if let thumbnailItem = thumbnailItem {
                    imageView.setSignal(chatMessageStickerPackThumbnail(postbox: item.context.account.postbox, representation: thumbnailItem, scale: backingScaleFactor, synchronousLoad: false))
                }
                if let resourceReference = resourceReference {
                    _ = fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: resourceReference, statsCategory: .file).start()
                }
                imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: NSMakeSize(35, 35), boundingSize: NSMakeSize(35, 35), intrinsicInsets: NSEdgeInsets()))
            }
           
            nameView.update(item.nameLayout)
            countView.update(item.countLayout)
            switch item.control {
            case let .installation(installed: installed):
                installationControl.image = installed ? theme.icons.stickersAddedFeatured : theme.icons.stickersAddFeatured
                installationControl.sizeToFit()
            case .remove:
                installationControl.image = theme.icons.stickersRemove
                installationControl.sizeToFit()
            case .selected:
                installationControl.image = theme.icons.generalSelect
                installationControl.sizeToFit()
            default:
                break
            }
            
            switch item.control {
            case .installation:
                installationControl.isHidden = false//!containerView.mouseInside()
                removeControl.isHidden = true
            case .none:
                installationControl.isHidden = true
                removeControl.isHidden = false//!containerView.mouseInside()
            case .remove:
                removeControl.isHidden = true
                installationControl.isHidden = false//!containerView.mouseInside()
            case .empty:
                removeControl.isHidden = true
                installationControl.isHidden = true
            case .selected:
                removeControl.isHidden = true
                installationControl.isHidden = false//!containerView.mouseInside()
            }
            
        }
        needsLayout = true
    }
    
    deinit {
        loadedStickerPackDisposable.dispose()
    }
    
}
