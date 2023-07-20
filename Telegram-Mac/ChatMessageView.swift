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
    
    private var text:TextView?

    private(set) var webpageContent:WPContentView?
    private var actionButton: TitleButton?
    
    private var shimmerEffect: ShimmerView?
    private var shimmerMask: SimpleLayer?

    override func draw(_ dirtyRect: NSRect) {
        
        // Drawing code here.
    }
    
    required init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
       // self.layerContentsRedrawPolicy = .never
    }
    
    
    override func layout() {
        super.layout()
       
    }
    
    func webpageFrame(_ item: ChatMessageItem) -> NSRect {
        guard let item = self.item as? ChatMessageItem else {
            return .zero
        }
        let maxY = text?.frame.maxY ?? 0
        if let webpageLayout = item.webpageLayout {
            var size = webpageLayout.size
            return CGRect(origin: NSMakePoint(0, maxY + item.defaultContentInnerInset), size: size)
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
        if let superTextView = text?.superview {
            if let webpageContent = webpageContent {
                return !NSPointInRect(superTextView.convert(event.locationInWindow, from: nil), webpageContent.frame)
            }
            return true
        }
        return false
    }
    
    override var selectableTextViews: [TextView] {
        var views:[TextView] = [text].compactMap { $0 }
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
        let previous = self.item as? ChatMessageItem
        super.set(item: item, animated: animated)

        if let item = item as? ChatMessageItem {
            
            let isEqual = previous?.textLayout.attributedString.string == item.textLayout.attributedString.string
            if isEqual, let view = self.text {
                view.update(item.textLayout)
            } else {
                if let view = self.text {
                    performSubviewRemoval(view, animated: animated)
                }
                let current: TextView = TextView()
                current.update(item.textLayout)
                self.text = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            if let view = self.text {
                updateInlineStickers(context: item.context, view: view, textLayout: item.textLayout)
            }
            
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
            
            if item.isTranslateLoading, let blockImage = item.block.1 {
                let size = blockImage.size
                let current: ShimmerView
                if let view = self.shimmerEffect {
                    current = view
                } else {
                    current = ShimmerView()
                    self.shimmerEffect = current
                    self.rowView.addSubview(current, positioned: .below, relativeTo: contentView)
                    
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                current.update(backgroundColor: .blackTransparent, data: nil, size: size, imageSize: size)
                current.updateAbsoluteRect(size.bounds, within: size)
                
                let frame = contentFrame(item)
                current.frame = blockImage.backingSize.bounds.offsetBy(dx: frame.minX - 5, dy: frame.minY - 1)
                
                if let blockImage = item.block.1 {
                    if shimmerMask == nil {
                        shimmerMask = SimpleLayer()
                    }
                    var fr = CATransform3DIdentity
                    fr = CATransform3DTranslate(fr, blockImage.backingSize.width / 2, 0, 0)
                    fr = CATransform3DScale(fr, 1, -1, 1)
                    fr = CATransform3DTranslate(fr, -(blockImage.backingSize.width / 2), 0, 0)
                    
                    shimmerMask?.transform = fr
                    shimmerMask?.contentsScale = 2.0
                    shimmerMask?.contents = blockImage
                    shimmerMask?.frame = CGRect(origin: .zero, size: blockImage.backingSize)
                    current.layer?.mask = shimmerMask
                } else {
                    self.shimmerMask = nil
                    current.layer?.mask = nil
                }
            } else {
                if let view = self.shimmerEffect {
                    let shimmerMask = self.shimmerMask
                    performSubviewRemoval(view, animated: animated, completed: { [weak shimmerMask] _ in
                        shimmerMask?.removeFromSuperlayer()
                    })
                    self.shimmerEffect = nil
                    self.shimmerMask = nil
                }
            }

        }

    }
    
    override func updateAnimatableContent() {
        super.updateAnimatableContent()
        
        if let current = shimmerEffect {
            current.reloadAnimation()
        }

    }
    
    override func clickInContent(point: NSPoint) -> Bool {
        guard let item = item as? ChatMessageItem else {return true}
        
        if let text = self.text {
            let point = text.convert(point, from: self)
            let layout = item.textLayout
            
            let index = layout.findIndex(location: point)
            return index >= 0 && point.x < layout.lines[index].frame.maxX
        } else {
            return false
        }
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
    
    override func storyControl(_ storyId: StoryId) -> NSView? {
        if let item = item as? ChatRowItem {
            if item.message?.storyAttribute?.storyId == storyId {
                return super.storyControl(storyId)
            } else {
                return self.webpageContent?.mediaContentView ?? super.storyControl(storyId)
            }
        }
        return nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
