//
//  MediaPreviewRowItem.swift
//  Telegram
//
//  Created by keepcoder on 19/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import TGUIKit
import SwiftSignalKit
import Postbox

class MediaPreviewRowItem: TableRowItem {
    
    


    let media: Media
    fileprivate let context: AccountContext
    private let _stableId = arc4random()
    fileprivate let parameters: ChatMediaLayoutParameters?
    fileprivate let chatInteraction: ChatInteraction
    fileprivate let edit:()->Void
    fileprivate let delete: (()->Void)?
    fileprivate let hasEditedData: Bool
    init(_ initialSize: NSSize, media: Media, context: AccountContext, hasEditedData: Bool = false, edit:@escaping()->Void = {}, delete: (()->Void)? = nil) {
        self.edit = edit
        self.delete = delete
        self.media = media
        self.context = context
        self.hasEditedData = hasEditedData
        self.chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context)
        if let media = media as? TelegramMediaFile {
            parameters = ChatMediaLayoutParameters.layout(for: media, isWebpage: false, chatInteraction: chatInteraction, presentation: .Empty, automaticDownload: true, isIncoming: false, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
        } else {
            parameters = nil
        }
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    
    private var overSize: CGFloat? = nil
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        parameters?.makeLabelsForWidth(width - (media.isInteractiveMedia ? 20 : 120))
        
        if let table = table, table.count == 1 {
            if contentSize.height > table.frame.height && table.frame.height > 0 {
                overSize = table.frame.height - 12
            } else {
                overSize = nil
            }
        }
        
        return result
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var identifier: String {
        return "\(ChatLayoutUtils.contentNode(for: media))"
    }
    
    override var height: CGFloat {
        return contentSize.height + 12
    }
    
    var contentSize: NSSize {
        let contentSize = layoutSize
        return NSMakeSize(width - (media.isInteractiveMedia ? 20 : 48), overSize ?? contentSize.height)
    }
    
    override var layoutSize: NSSize {
        return ChatLayoutUtils.contentSize(for: media, with: initialSize.width - (media.isInteractiveMedia ? 20 : 60))
    }
    
    public func contentNode() -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: media)
    }
    
    override func viewClass() -> AnyClass {
        return MediaPreviewRowView.self
    }
}

fileprivate class MediaPreviewRowView : TableRowView, ModalPreviewRowViewProtocol {
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let contentNode = contentNode {
            if contentNode is ChatGIFContentView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, GifPreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatInteractiveContentView {
                if let image = contentNode.media as? TelegramMediaImage {
                    let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                    return (.image(reference, ImagePreviewModalView.self), contentNode)
                }
            } else if contentNode is MediaAnimatedStickerView {
                if let file = contentNode.media as? TelegramMediaFile {
                    let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                    return (.file(reference, AnimatedStickerPreviewModalView.self), contentNode)
                }
            } else if contentNode is ChatFileContentView {
                if let file = contentNode.media as? TelegramMediaFile, file.isGraphicFile, let mediaId = file.id, let dimension = file.dimensions {
                    var representations: [TelegramMediaImageRepresentation] = []
                    representations.append(contentsOf: file.previewRepresentations)
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimension, resource: file.resource))
                    let image = TelegramMediaImage(imageId: mediaId, representations: representations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: file.partialReference, flags: [])
                    let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                    return (.image(reference, ImagePreviewModalView.self), contentNode)
                }
            }
        }
        
        return nil
    }
    
    var contentNode:ChatMediaContentView?
    let editControl: MediaPreviewEditControl = MediaPreviewEditControl()
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode?.needsDisplay = true
        }
    }
    
    override func forceClick(in location: NSPoint) {
        _ = contentNode?.previewMediaIfPossible()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func updateMouse() {
        guard let window = window, let table = item?.table else {
            editControl.isHidden = true
            return
        }
        
        let row = table.row(at: table.documentView!.convert(window.mouseLocationOutsideOfEventStream, from: nil))

        if row == item?.index {
            editControl.isHidden = false
        } else {
            editControl.isHidden = true
        }
    }
    
    override func shakeView() {
        contentNode?.shake()
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? MediaPreviewRowItem else { return }
        
        if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
            self.contentNode?.removeFromSuperview()
            let node = item.contentNode()
            self.contentNode = node.init(frame:NSZeroRect)
            self.addSubview(self.contentNode!)
            addSubview(editControl)
            updateMouse()
        }
        
        
        editControl.canEdit = (item.media is TelegramMediaImage)
        editControl.isInteractiveMedia = item.media.isInteractiveMedia
        editControl.canDelete = item.delete != nil
        editControl.set(edit: { [weak item] in
            item?.edit()
        }, delete: { [weak item] in
            item?.delete?()
        }, hasEditedData: item.hasEditedData)
        
        self.contentNode?.update(with: item.media, size: item.contentSize, context: item.context, parent: nil, table: item.table, parameters: item.parameters, animated: animated)
        
    }
    
    override func layout() {
        super.layout()
        guard let contentNode = contentNode else {return}
        contentNode.setFrameOrigin(12, 6)
        if editControl.isInteractiveMedia {
            editControl.setFrameOrigin(NSMakePoint(frame.width - editControl.frame.width - 20, frame.height - editControl.frame.height - 20))
        } else {
            editControl.centerY(x: frame.width - editControl.frame.width - 10)
        }
    }
    
    open override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        if let content = self.contentNode?.interactionContentView(for: innerId, animateIn: animateIn) {
            return content
        }
        return self
    }
    
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
    }
    
    override var backgroundColor: NSColor {
        didSet {
            contentNode?.backgroundColor = backdorColor
        }
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
}


