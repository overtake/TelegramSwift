//
//  ChatMessageView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
class ChatMessageView: ChatRowView {
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
        if let item = self.item as? ChatMessageItem {
            
            if let webpageLayout = item.webpageLayout {
                webpageContent?.frame = NSMakeRect(0, text.frame.maxY + item.defaultContentInnerInset, webpageLayout.size.width, webpageLayout.size.height)
                
                if let webpageContent = webpageContent, let actionButton = actionButton {
                    actionButton.setFrameOrigin(0, webpageContent.frame.maxY + 6)
                }
            }
           
        }
    }
    
    override func canStartTextSelecting(_ event: NSEvent) -> Bool {
      //  return true
        if let superTextView = text.superview {
            if let webpageContent = webpageContent {
                return !NSPointInRect(superTextView.convert(event.locationInWindow, from: nil), webpageContent.frame)
            }
            return true
        }
        return false
    }
    
    override var selectableTextViews: [TextView] {
        let views:[TextView] = [text]
//        if let webpage = webpageContent {
//            views += webpage.selectableTextViews
//        }
        return views
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        let point = self.contentView.convert(location, from: nil)
        if let webpageContent = webpageContent {
            return !NSPointInRect(point, webpageContent.frame)
        }
        return true
    }

    override func set(item:TableRowItem, animated:Bool = false) {
        
        if let item = item as? ChatMessageItem {
            
            self.text.update(item.textLayout)

            
            if let webpageLayout = item.webpageLayout {
                let updated = webpageContent == nil || !webpageContent!.isKind(of: webpageLayout.viewClass())
                
                if updated {
                    webpageContent?.removeFromSuperview()
                    let vz = webpageLayout.viewClass() as! WPContentView.Type
                    webpageContent = vz.init()
                    addSubview(webpageContent!)
                }
                webpageContent?.update(with: webpageLayout)
                
                if let text = item.actionButtonText {
                    if actionButton == nil {
                        actionButton = TitleButton()
                        actionButton?.layer?.cornerRadius = .cornerRadius
                        actionButton?.layer?.borderWidth = 1
                        actionButton?.disableActions()
                        actionButton?.set(font: .normal(.text), for: .Normal)
                        addSubview(actionButton!)
                    }
                    actionButton?.removeAllHandlers()
                    actionButton?.set(handler: { [weak item] _ in
                        item?.invokeAction()
                    }, for: .Click)
                    actionButton?.set(text: text, for: .Normal)
                    actionButton?.layer?.borderColor = webpageLayout.presentation.activity.cgColor
                    actionButton?.set(color: webpageLayout.presentation.activity, for: .Normal)
                    _ = actionButton?.sizeToFit(NSZeroSize, NSMakeSize(webpageLayout.size.width, 30), thatFit: true)

                } else {
                    actionButton?.removeFromSuperview()
                    actionButton = nil
                }
                
            } else {
                webpageContent?.removeFromSuperview()
                webpageContent = nil
                actionButton?.removeFromSuperview()
                actionButton = nil
            }

        }
        super.set(item: item, animated: animated)

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
