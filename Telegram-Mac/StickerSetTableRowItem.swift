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



enum ItemListStickerPackItemControl: Equatable {
    case none
    case installation(installed: Bool)
    case remove
    case empty
    case selected
    static func ==(lhs: ItemListStickerPackItemControl, rhs: ItemListStickerPackItemControl) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case .remove:
            if case .remove = rhs {
                return true
            } else {
                return false
            }
        case .selected:
            if case .selected = rhs {
                return true
            } else {
                return false
            }
        case .empty:
            if case .empty = rhs {
                return true
            } else {
                return false
            }
        case let .installation(installed):
            if case .installation(installed) = rhs {
                return true
            } else {
                return false
            }
            
        }
    }
}

class StickerSetTableRowItem: TableRowItem {
    
    fileprivate let account:Account
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
    init(_ initialSize: NSSize, account:Account, stableId:AnyHashable, info:StickerPackCollectionInfo, topItem:StickerPackItem?, itemCount:Int32, unread: Bool, editing: ItemListStickerPackItemEditing, enabled: Bool, control: ItemListStickerPackItemControl, action:@escaping()->Void, addPack:@escaping()->Void = {}, removePack:@escaping() -> Void = {}) {
        self.account = account
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
        nameLayout.measure(width: width - 50 - insets.left - insets.right)
        countLayout.measure(width: width - 50 - insets.left - insets.right)
        return super.makeSize(width, oldWidth: oldWidth)
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

        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? StickerSetTableRowItem {
            if let topItem = item.topItem {
                nameView.backgroundColor = backdorColor
                countView.backgroundColor = backdorColor
                
                removeControl.set(image: theme.icons.stickerPackDelete, for: .Normal)
                removeControl.sizeToFit()
                imageView.setSignal( chatMessageSticker(account: item.account, file: topItem.file, type: .thumb, scale: backingScaleFactor))
                imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: NSMakeSize(35, 35), boundingSize: NSMakeSize(35, 35), intrinsicInsets: NSEdgeInsets()))
                _ = fileInteractiveFetched(account: item.account, file: topItem.file).start()
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
        }
        needsLayout = true
    }
    
    
}
