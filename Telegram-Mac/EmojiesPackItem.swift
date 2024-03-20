//
//  EmojiesPackItem.swift
//  Telegram
//
//  Created by Mike Renoir on 01.07.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

class EmojiesPackItem: TableRowItem {
    
    override var height:CGFloat {
        return 40.0
    }
    
    override var width: CGFloat {
        return 40
    }
    
    let info:StickerPackCollectionInfo
    let topItem:StickerPackItem?
    let context: AccountContext
    
    let _stableId:AnyHashable
    override var stableId:AnyHashable {
        return _stableId
    }
    let focusHandler:(StickerPackCollectionInfo)->Void
    init(_ initialSize:NSSize, context:AccountContext, stableId: AnyHashable, info:StickerPackCollectionInfo, topItem:StickerPackItem?, focusHandler:@escaping(StickerPackCollectionInfo)->Void) {
        self.context = context
        self._stableId = stableId
        self.info = info
        self.topItem = topItem
        self.focusHandler = focusHandler
        super.init(initialSize)
    }
    
    func contentNode()->ChatMediaContentView.Type {
        return StickerMediaContentView.self
    }
    
    override func viewClass() -> AnyClass {
        return EmojiesPackView.self
    }
}


private final class EmojiesPackView : HorizontalRowView {
    
    
    var overlay:ImageButton = ImageButton()
    
    private let control = OverlayControl()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        overlay.setFrameSize(35, 35)
        control.setFrameSize(35, 35)
        
        
        overlay.autohighlight = false
        overlay.canHighlight = false
        overlay.userInteractionEnabled = false
        addSubview(overlay)
        
        
        
        control.set(handler: { [weak self] _ in
            if let item = self?.item as? EmojiesPackItem {
                item.focusHandler(item.info)
            }
        }, for: .Click)
        
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
    
    
    override func updateMouse(animated: Bool) {
        super.updateMouse(animated: animated)
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
        if let item = item as? EmojiesPackItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            
            var file: TelegramMediaFile?
            if let thumbnail = item.info.thumbnail {
                file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: item.info.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [thumbnail], videoThumbnails: [], immediateThumbnailData: item.info.immediateThumbnailData, mimeType: item.info.flags.contains(.isVideo) ? "video/webm" : "application/x-tgsticker", size: nil, attributes: [.FileName(fileName: item.info.flags.contains(.isVideo) ? "webm-preview" : "sticker.tgs"), .Sticker(displayText: "", packReference: .id(id: item.info.id.id, accessHash: item.info.accessHash), maskData: nil)])
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
        
        addSubview(control)

        
        super.set(item: item, animated: animated)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        self.contentNode?.center()
        overlay.center()
        control.center()
    }
}
