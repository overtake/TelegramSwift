//
//  WPMediaContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore

class WPMediaContentView: WPContentView {
    
    private(set) var contentNode:ChatMediaContentView?
    
    
    override func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let contentNode = contentNode {
            if contentNode is ChatStickerContentView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, StickerPreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatGIFContentView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, GifPreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatInteractiveContentView {
                if let image = contentNode.media as? TelegramMediaImage {
                    let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                    return (.image(reference, ImagePreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatFileContentView {
                if let file = contentNode.media as? TelegramMediaFile, file.isGraphicFile, let mediaId = file.id, let dimension = file.dimensions {
                    var representations: [TelegramMediaImageRepresentation] = []
                    representations.append(contentsOf: file.previewRepresentations)
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimension, resource: file.resource))
                    let image = TelegramMediaImage(imageId: mediaId, representations: representations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: file.partialReference)
                    let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                    return (.image(reference, ImagePreviewModalView.self), contentNode)
                }
            }
        }
        
        return nil
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard  let window = self.kitWindow, let content = content as? WPArticleLayout, content.isFullImageSize, let table = content.table, let contentNode = contentNode, contentNode.mouseInside() else {return false}
        _ = startModalPreviewHandle(table, window: window, context: content.context)
        return true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        // Drawing code here.
    }
    
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }

    
    override func update(with layout: WPLayout) {
        super.update(with: layout)
        
        if let layout = layout as? WPMediaLayout {
            if contentNode == nil || !contentNode!.isKind(of: layout.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = layout.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            
            self.contentNode?.update(with: layout.media, size: layout.mediaSize, context: layout.context, parent:layout.parent, table:layout.table, parameters: layout.parameters, approximateSynchronousValue: layout.approximateSynchronousValue)
        }
    }
    
    override func updateMouse() {
        contentNode?.updateMouse()
    }
    
    override func layout() {
        super.layout()
        if let content = content as? WPMediaLayout {
            self.contentNode?.setFrameOrigin(NSMakePoint(0, containerView.frame.height - content.mediaSize.height))
        }
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return contentNode?.interactionContentView(for: innerId, animateIn: animateIn) ?? self
    }
    
}
