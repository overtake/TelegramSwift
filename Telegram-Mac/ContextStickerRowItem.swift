//
//  ContextStickerRowItem.swift
//  Telegram
//
//  Created by keepcoder on 02/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore

import Postbox
import TGUIKit


class ContextStickerRowItem: TableRowItem {
    let result:InputMediaStickersRow
    fileprivate let context:AccountContext
    fileprivate let _stableId:Int64
    fileprivate let chatInteraction:ChatInteraction
    var selectedIndex:Int? = nil
    override var stableId: AnyHashable {
        return _stableId
    }
    init(_ initialSize:NSSize, _ context: AccountContext, _ entry:InputMediaStickersRow, _ stableId:Int64, _ chatInteraction:ChatInteraction) {
        self.context = context
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



class ContextStickerRowView : TableRowView, ModalPreviewRowViewProtocol {

    
    func fileAtPoint(_ point:NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let item = item as? ContextStickerRowItem {
            var i:Int = 0
            for subview in subviews {
                if point.x > subview.frame.minX && point.x < subview.frame.maxX {
                    let file = item.result.results[i].file
                    let reference = file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file)
                    if file.isVideoSticker && !file.isWebm {
                        return (.file(reference, GifPreviewModalView.self), subview)
                    } else if file.isAnimatedSticker || file.isWebm {
                        return (.file(reference, AnimatedStickerPreviewModalView.self), subview)
                    } else {
                        return (.file(reference, StickerPreviewModalView.self), subview)
                    }
                }
                i += 1
            }
        }
        return nil
    }
    
    override func showContextMenu(_ event: NSEvent) {
        let menu = ContextMenu()
        if let item = item as? ContextStickerRowItem {
            
            let reference = fileAtPoint(convert(event.locationInWindow, from: nil))
            
            if let reference = reference?.0.fileReference?.media.stickerReference {
                menu.addItem(ContextMenuItem(strings().contextViewStickerSet, handler: {
                    showModal(with: StickerPackPreviewModalController(item.context, peerId: item.chatInteraction.peerId, reference: reference), for: mainWindow)
                }, itemImage: MenuAnimation.menu_view_sticker_set.value))
            }
            if let file = reference?.0.fileReference?.media {
                menu.addItem(ContextMenuItem(strings().chatSendWithoutSound, handler: { [weak item] in
                    item?.chatInteraction.sendAppFile(file, true, nil, false)
                    item?.chatInteraction.clearInput()
                }, itemImage: MenuAnimation.menu_mute.value))
            }
            if let file = reference?.0.fileReference?.media {
                menu.addItem(ContextMenuItem(strings().chatSendScheduledMessage, handler: { [weak item] in
                    item?.chatInteraction.sendAppFile(file, false, nil, true)
                    item?.chatInteraction.clearInput()
                }, itemImage: MenuAnimation.menu_schedule_message.value))
            }
        }
        AppMenu.show(menu: menu, event: event, for: self)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ContextStickerRowItem {
            

            
            while subviews.count > item.result.entries.count {
                subviews.last?.removeFromSuperview()
            }
            while subviews.count < item.result.entries.count {
                let control = Control()
                addSubview(control)
                let content = StickerMediaContentView(frame: .zero)
                content.userInteractionEnabled = false
                control.addSubview(content)
            }
            
            
            
            for i in 0 ..< item.result.entries.count {
                let container:Control = self.subviews[i] as! Control
                container.removeAllHandlers()

                

                if item.selectedIndex == i {
                    container.set(background: theme.colors.grayBackground, for: .Normal)
                    container.set(background: theme.colors.grayBackground, for: .Hover)
                    container.set(background: theme.colors.grayBackground, for: .Highlight)

                    container.apply(state: .Normal)
                } else {
                    container.set(background: theme.colors.background, for: .Normal)
                    container.set(background: theme.colors.background, for: .Hover)
                    container.set(background: theme.colors.background, for: .Highlight)
                    container.apply(state: .Normal)
                }
                
                
                container.layer?.cornerRadius = .cornerRadius
                switch item.result.entries[i] {
                case let .sticker(data):
                    
                    container.set(handler: { [weak item] control in
                        if let slowMode = item?.chatInteraction.presentation.slowMode, slowMode.hasLocked {
                            showSlowModeTimeoutTooltip(slowMode, for: control)
                        } else {
                            item?.chatInteraction.sendAppFile(data.file, false, nil, false)
                            item?.chatInteraction.clearInput()
                        }
                    }, for: .Click)
                    
                    container.set(handler: { [weak self, weak item] (control) in
                        if let window = self?.window as? Window, let item = item, let table = item.table {
                            startModalPreviewHandle(table, window: window, context: item.context)
                        }
                    }, for: .LongMouseDown)
                    
                   
                    let view: StickerMediaContentView = container.subviews[0] as! StickerMediaContentView
            
                    let size = NSMakeSize(round(item.result.sizes[i].width - 8), round(item.result.sizes[i].height - 8))
                    view.update(with: data.file, size: size, context: item.context, parent: nil, table: item.table, parameters: nil, animated: false, positionFlags: nil, approximateSynchronousValue: false)
                    
                    container.setFrameSize(NSMakeSize(item.result.sizes[i].width - 4, item.result.sizes[i].height - 4))
                default:
                    fatalError("ContextStickerRowItem support only stickers")
                }
                
            }
            
            needsLayout = true
        }
    }
    

    
    override func layout() {
        super.layout()
        
        if let item = item as? ContextStickerRowItem  {
            let defSize = NSMakeSize( item.result.sizes[0].width - 4,  item.result.sizes[0].height - 4)
            
            let defInset = floorToScreenPixels(backingScaleFactor, (frame.width - defSize.width * CGFloat(item.result.maxCount)) / CGFloat(item.result.maxCount + 1))
            var inset = defInset
            
            for i in 0 ..< item.result.entries.count {
                subviews[i].centerY(x: inset)
                subviews[i].subviews.first?.center()
                inset += (defInset + subviews[i].frame.width)
            }
        }
    }

}

