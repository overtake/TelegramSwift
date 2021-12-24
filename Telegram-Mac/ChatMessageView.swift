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
class ChatMessageView: ChatRowView, ModalPreviewRowViewProtocol {
    
    
    
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
                if actionButton == nil {
                    actionButton = TitleButton()
                    actionButton?.layer?.cornerRadius = .cornerRadius
                    actionButton?.layer?.borderWidth = 1
                    actionButton?.disableActions()
                    actionButton?.set(font: .normal(.text), for: .Normal)
                    self.rowView.addSubview(actionButton!)
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
