//
//  ContextStickerRowItem.swift
//  Telegram
//
//  Created by keepcoder on 02/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac
import TGUIKit


class ContextStickerRowItem: TableRowItem {
    let result:InputMediaStickersRow
    fileprivate let account:Account
    fileprivate let _stableId:Int64
    fileprivate let chatInteraction:ChatInteraction
    var selectedIndex:Int? = nil
    override var stableId: AnyHashable {
        return _stableId
    }
    init(_ initialSize:NSSize, _ account:Account, _ entry:InputMediaStickersRow, _ stableId:Int64, _ chatInteraction:ChatInteraction) {
        self.account = account
        self.result = entry
        self.chatInteraction = chatInteraction
        self._stableId = stableId
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return ContextStickerRowView.self
    }
    
    override var height: CGFloat {
        return result.sizes.first!.height
    }
    
}



class ContextStickerRowView : TableRowView, StickerPreviewRowViewProtocol {

    
    func fileAtPoint(_ point:NSPoint) -> TelegramMediaFile? {
        if let item = item as? ContextStickerRowItem {
            var i:Int = 0
            for subview in subviews {
                if point.x > subview.frame.minX && point.x < subview.frame.maxX {
                    return item.result.results[i].file
                }
                i += 1
            }
        }
        return nil
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        if let item = item as? ContextStickerRowItem {
            
            let file = fileAtPoint(convert(event.locationInWindow, from: nil))
            
            if let reference = file?.stickerReference {
                menu.addItem(ContextMenuItem(L10n.contextViewStickerSet, handler: {
                    showModal(with: StickersPackPreviewModalController.init(item.account, peerId: item.chatInteraction.peerId, reference: reference), for: mainWindow)
                }))
            }
        }
        return menu
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        removeAllSubviews()
        if let item = item as? ContextStickerRowItem {
            for i in 0 ..< item.result.entries.count {
                let container:Control = Control()
                
                
                container.set(background: theme.colors.grayBackground, for: .Highlight)
                
                if item.selectedIndex == i {
                    container.set(background: theme.colors.blueSelect, for: .Normal)
                    container.set(background: theme.colors.blueSelect, for: .Hover)
                    container.set(background: theme.colors.blueUI, for: .Highlight)

                    container.apply(state: .Normal)
                }
                
                container.layer?.cornerRadius = .cornerRadius
                switch item.result.entries[i] {
                case let .sticker(data):
                    
                    container.set(handler: { [weak item] (control) in
                        item?.chatInteraction.sendAppFile(data.file)
                        item?.chatInteraction.clearInput()
                    }, for: .Click)
                    
                    container.set(handler: { [weak self, weak item] (control) in
                        if let window = self?.window as? Window, let item = item, let table = item.table {
                            _ = startStickerPreviewHandle(table, window: window, account: item.account)
                        }
                    }, for: .LongMouseDown)
                    
                    let view = TransformImageView()
                    view.setSignal( chatMessageSticker(account: item.account, file: data.file, type: .small, scale: backingScaleFactor))
                    _ = fileInteractiveFetched(account: item.account, file: data.file).start()
                    
                    let imageSize = data.file.dimensions?.aspectFitted(NSMakeSize(item.result.sizes[i].width - 8, item.result.sizes[i].height - 8)) ?? item.result.sizes[i]
                    view.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets()))
                    
                    view.setFrameSize(imageSize)
                    container.addSubview(view)
                    container.setFrameSize(NSMakeSize(item.result.sizes[i].width - 4, item.result.sizes[i].height - 4))
                default:
                    fatalError("ContextStickerRowItem support only stickers")
                }
                
                addSubview(container)
                
            }
            
            needsLayout = true
        }
    }
    

    
    override func layout() {
        super.layout()
        
        if let item = item as? ContextStickerRowItem  {
            let defSize = NSMakeSize( item.result.sizes[0].width - 4,  item.result.sizes[0].height - 4)
            
            let defInset = floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.width - defSize.width * CGFloat(item.result.maxCount)) / CGFloat(item.result.maxCount + 1))
            var inset = defInset
            
            for i in 0 ..< item.result.entries.count {
                subviews[i].centerY(x: inset)
                subviews[i].subviews.first?.center()
                inset += (defInset + subviews[i].frame.width)
            }
        }
    }

}

