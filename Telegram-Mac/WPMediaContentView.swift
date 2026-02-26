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

private final class GiftView: View {
    
    private let emoji: PeerInfoSpawnEmojiView = .init(frame: NSMakeRect(0, 0, 180, 180))
    private let backgroundView: PeerInfoBackgroundView = .init(frame: NSMakeRect(0, 0, 180, 180))

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.backgroundView)
        addSubview(self.emoji)
        
        self.backgroundView.isEventLess = true
        self.emoji.isEventLess = true
        
        
        self.backgroundColor = .random
        
        layer?.cornerRadius = 10
    }
    
    func set(_ uniqueGift: StarGift.UniqueGift, context: AccountContext, animated: Bool) {
        var colors: [NSColor] = []

        for attribute in uniqueGift.attributes {
            switch attribute {
            case let .backdrop(_, _, innerColor, outerColor, _, _, _):
                colors = [NSColor(UInt32(innerColor)).withAlphaComponent(1), NSColor(UInt32(outerColor)).withAlphaComponent(1)]
            default:
                break
            }
        }
        backgroundView.gradient = colors
        
        
        var patternFile: TelegramMediaFile?
        var patternColor: NSColor?

        for attribute in uniqueGift.attributes {
            switch attribute {
            case .pattern(_, let file, _):
                patternFile = file
            case let .backdrop(_, _, _, _, color, _, _):
                patternColor = NSColor(UInt32(color)).withAlphaComponent(0.3)
            default:
                break
            }
        }
        if let patternFile, let patternColor {
            emoji.set(fileId: patternFile.fileId.id, color: patternColor, context: context, animated: animated)
        }
       
    }
    
    override func layout() {
        super.layout()
        self.backgroundView.frame = bounds
        self.emoji.frame = bounds.offsetBy(dx: 10, dy: 25)
    }
    
     required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class WPMediaContentView: WPContentView {
    
    private(set) var contentNode:ChatMediaContentView?
    private var giftView: GiftView?
    
    override func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let contentNode = contentNode {
            if contentNode is ChatStickerContentView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, StickerPreviewModalView.self), contentNode)
                }
            } else if contentNode is VideoStickerContentView {
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
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimension, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                    let image = TelegramMediaImage(imageId: mediaId, representations: representations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: file.partialReference, flags: [])
                    let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                    return (.image(reference, ImagePreviewModalView.self), contentNode)
                }
            }
        }
        
        return nil
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard  let window = self._window, let content = content as? WPArticleLayout, content.isFullImageSize, let table = content.table, let contentNode = contentNode, contentNode.mouseInside() else {return false}
        startModalPreviewHandle(table, window: window, context: content.context)
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

    
    override func update(with layout: WPLayout, animated: Bool) {
        super.update(with: layout, animated: animated)
        
        if let layout = layout as? WPMediaLayout {
            if contentNode == nil || !contentNode!.isKind(of: layout.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = layout.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            contentNode?.userInteractionEnabled = layout.isMediaClickable
            
            self.contentNode?.update(with: layout.media, size: layout.mediaSize, context: layout.context, parent:layout.parent, table:layout.table, parameters: layout.parameters, approximateSynchronousValue: layout.approximateSynchronousValue)
        }
        
        if let uniqueGift = layout.uniqueGift {
            let current: GiftView
            if let view = self.giftView {
                current = view
            } else {
                current = GiftView(frame: layout.contentRect)
                current.isEventLess = true
                self.containerView.addSubview(current, positioned: .below, relativeTo: self.contentNode)
                self.giftView = current
            }
            current.set(uniqueGift, context: layout.context, animated: animated)
            
        } else if let giftView {
            performSubviewRemoval(giftView, animated: animated)
            self.giftView = nil
        }
        self.contentNode?.userInteractionEnabled = self.giftView == nil
    }
    
    override func updateMouse() {
        contentNode?.updateMouse()
    }
    
    override func layout() {
        super.layout()
        if let contentNode = contentNode, let content = content as? WPMediaLayout {
            let y: CGFloat
            if !content.isLeadingMedia {
                y = containerView.frame.height - content.mediaSize.height - (content.action_text != nil ? 36 : 0)
            } else {
                y = content.insets.top
            }
            
            let rect = CGRect(origin: NSMakePoint(0, y), size: content.mediaSize)
            contentNode.frame = rect
            
            giftView?.frame = content.contentRect.insetBy(dx: 0, dy: 35).offsetBy(dx: -8, dy: -2)
            
            if let _ = giftView {
                contentNode.frame = contentNode.frame.offsetBy(dx: 0, dy: -28)
            }
        }
        
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return contentNode?.interactionContentView(for: innerId, animateIn: animateIn) ?? self
    }
    
    override var mediaContentView: NSView? {
        return contentNode
    }
    
}
