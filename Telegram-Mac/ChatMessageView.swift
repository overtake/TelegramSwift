//
//  ChatMessageView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

final class InlineStickerItemView : View {
    struct Key: Hashable {
        var id: Int64
        var index: Int
    }
    private let context: AccountContext
    private let emoji: ChatTextCustomEmojiAttribute
    private let view: StickerMediaContentView
    private var infoDisposable: Disposable?
    init(context: AccountContext, emoji: ChatTextCustomEmojiAttribute, size: NSSize) {
        self.context = context
        self.emoji = emoji
        self.view = StickerMediaContentView(frame: size.bounds)
        super.init(frame: size.bounds)
        addSubview(view)
            
        self.infoDisposable = (context.inlinePacksContext.stickerPack(reference: emoji.reference)
        |> deliverOnMainQueue).start(next: { [weak self] files in
            guard let strongSelf = self else {
                return
            }
            for file in files {
                if file.fileId.id == emoji.fileId {
                    strongSelf.view.update(with: file, size: size, context: context, parent: nil, table: nil)
                    break
                }
            }
        })
        
    }
    
    deinit {
        infoDisposable?.dispose()
    }
    
    override var isHidden: Bool {
        didSet {
            view.isHidden = isHidden
        }
    }
    
    override func layout() {
        super.layout()
        view.center()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class ChatMessageView: ChatRowView, ModalPreviewRowViewProtocol {
    
    private var inlineStickerItemViews: [InlineStickerItemView.Key: InlineStickerItemView] = [:]

    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let webpageContent = webpageContent {
            return webpageContent.fileAtPoint(convert(point, from: self))
        }
        
        return nil
    }
    
    override func forceClick(in location: NSPoint) {
        if previewMediaIfPossible() {
            
        } else {
            super.forceClick(in: location)
        }
    }
    
    override func previewMediaIfPossible() -> Bool {
        return webpageContent?.previewMediaIfPossible() ?? false
    }
    
    private let text:TextView = TextView()

    private(set) var webpageContent:WPContentView?
    private var actionButton: TitleButton?
    override func draw(_ dirtyRect: NSRect) {
        
        // Drawing code here.
    }
    
    required init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
       // self.layerContentsRedrawPolicy = .never
        self.addSubview(text)
    }
    
    override func layout() {
        super.layout()
       
    }
    
    func webpageFrame(_ item: ChatMessageItem) -> NSRect {
        guard let item = self.item as? ChatMessageItem else {
            return .zero
        }
        if let webpageLayout = item.webpageLayout {
            return CGRect(origin: NSMakePoint(0, text.frame.maxY + item.defaultContentInnerInset), size: webpageLayout.size)
        }
        return .zero
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        guard let item = self.item as? ChatMessageItem else {
            return
        }
        if let webpageContent = webpageContent {
            transition.updateFrame(view: webpageContent, frame: webpageFrame(item))
        }
        if let actionButton = actionButton {
            var add = item.additionalLineForDateInBubbleState ?? 0
            if !item.isBubbled {
                add = 0
            } else if webpageContent != nil {
                add = 0
            }
            let contentRect = self.contentFrame(item)
            transition.updateFrame(view: actionButton, frame: CGRect(origin: NSMakePoint(contentRect.minX, contentRect.maxY - actionButton.frame.height + add), size: actionButton.frame.size))
        }
    }

    override func canStartTextSelecting(_ event: NSEvent) -> Bool {
        if let superTextView = text.superview {
            if let webpageContent = webpageContent {
                return !NSPointInRect(superTextView.convert(event.locationInWindow, from: nil), webpageContent.frame)
            }
            return true
        }
        return false
    }
    
    override var selectableTextViews: [TextView] {
        var views:[TextView] = [text]
        if let webpage = webpageContent {
            views += webpage.selectableTextViews
        }
        return views
    }
    
    override func updateMouse() {
        super.updateMouse()
        webpageContent?.updateMouse()
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        let point = self.contentView.convert(location, from: nil)
        return true
    }
    
    


    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)

        if let item = item as? ChatMessageItem {
            self.text.update(item.textLayout)
            
            updateInlineStickers(context: item.context, view: self.text, textLayout: item.textLayout)
            
            if let webpageLayout = item.webpageLayout {
                let updated = webpageContent == nil || !webpageContent!.isKind(of: webpageLayout.viewClass())
                
                if updated {
                    webpageContent?.removeFromSuperview()
                    let vz = webpageLayout.viewClass() as! WPContentView.Type
                    webpageContent = vz.init()
                    webpageContent!.frame = webpageFrame(item)
                    addSubview(webpageContent!)
                }
                webpageContent?.update(with: webpageLayout)
            } else {
                if let view = webpageContent {
                    performSubviewRemoval(view, animated: animated)
                    webpageContent = nil
                }
            }
            if let text = item.actionButtonText {
                var isNew = false
                if actionButton == nil {
                    actionButton = TitleButton()
                    actionButton?.layer?.cornerRadius = .cornerRadius
                    actionButton?.layer?.borderWidth = 1
                    actionButton?.disableActions()
                    actionButton?.set(font: .normal(.text), for: .Normal)
                    self.rowView.addSubview(actionButton!)
                    isNew = true
                }
                actionButton?.scaleOnClick = true
                actionButton?.removeAllHandlers()
                actionButton?.set(handler: { [weak item] _ in
                    item?.invokeAction()
                }, for: .Click)
                actionButton?.set(text: text, for: .Normal)
                actionButton?.layer?.borderColor = item.wpPresentation.activity.cgColor
                actionButton?.set(color: item.wpPresentation.activity, for: .Normal)
                _ = actionButton?.sizeToFit(NSZeroSize, NSMakeSize(item.actionButtonWidth, 30), thatFit: true)
                if animated, isNew {
                    actionButton?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2, timingFunction: .easeOut)
                    actionButton?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            } else {
                if let view = actionButton {
                    performSubviewRemoval(view, animated: animated)
                    actionButton = nil
                }
            }

        }

    }
    
    override func clickInContent(point: NSPoint) -> Bool {
        guard let item = item as? ChatMessageItem else {return true}
        
        let point = text.convert(point, from: self)
        let layout = item.textLayout
        
        let index = layout.findIndex(location: point)
        return index >= 0 && point.x < layout.lines[index].frame.maxX
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        if let webpageContent = webpageContent {
            return webpageContent.interactionContentView(for: innerId, animateIn: animateIn)
        }
        return self
    }
    

    override func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        let main = super.convertWindowPointToContent(point)
        
        if let webpageContent = webpageContent, NSPointInRect(main, webpageContent.frame) {
            return webpageContent.convertWindowPointToContent(point)
        } else {
            return main
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
