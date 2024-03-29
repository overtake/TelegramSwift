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
    
    class ActionButton: TextButton {
        
        var urlView: ImageView?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(isExternalUrl: Bool, color: NSColor) {
            if isExternalUrl {
                let current: ImageView
                if let view = self.urlView {
                    current = view
                } else {
                    current = ImageView()
                    addSubview(current)
                    self.urlView = current
                }
                current.image = NSImage.init(named: "Icon_InlineBotUrl")?.precomposed(color)
                current.sizeToFit()
            } else if let view = self.urlView {
                view.removeFromSuperview()
                self.urlView = nil
            }
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            if let view = urlView {
                view.setFrameOrigin(NSMakePoint(frame.width - view.frame.width - 5, 5))
            }
        }
    }
    
    class AdSettingsView : View {
        private let close: ImageButton = ImageButton()
        private var more: ImageButton?
        private let separator = View()
        
        private weak var item: ChatMessageItem?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            addSubview(close)
            addSubview(separator)
            
            close.scaleOnClick = true
            close.autohighlight = false
            
            close.set(handler: { [weak self] _ in
                if let item = self?.item {
                    item.webpageLayout?.premiumBoarding()
                }
            }, for: .Click)

        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            close.setFrameOrigin(.zero)
            separator.frame = NSMakeRect(6, close.frame.maxY + 3, frame.width - 12, .borderSize)
            more?.setFrameOrigin(NSMakePoint(0, close.frame.maxY + 6))

        }
        
        func update(_ item: ChatMessageItem, animated: Bool) {
            self.item = item
            backgroundColor = theme.colors.background
            
            separator.backgroundColor = theme.colors.grayIcon.withAlphaComponent(0.4)

            close.set(image: NSImage(resource: .iconAdHide).precomposed(theme.colors.grayIcon), for: .Normal)
            close.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
            separator.isHidden = !item.isFragmentAd
            
            
            if item.isFragmentAd {
                let current: ImageButton
                if let view = self.more {
                    current = view
                } else {
                    current = ImageButton(frame: NSMakeRect(0, 30, 30, 30))
                    current.scaleOnClick = true
                    current.autohighlight = false

                    self.more = current
                    addSubview(current)
                    
                   
                    
                }
                current.removeAllHandlers()
                current.set(handler: { [weak item] control in
                    if let item = item, let event = NSApp.currentEvent {
                        _ = item.menuItems(in: .zero).startStandalone(next: { [weak control] items in
                            if let control = control {
                                let menu = ContextMenu()
                                menu.items = items
                                AppMenu.show(menu: menu, event: event, for: control)
                            }
                        })
                    }
                }, for: .Down)
                current.set(image: NSImage(resource: .iconAdMore).precomposed(theme.colors.grayIcon), for: .Normal)
                current.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
            } else if let view = self.more {
                performSubviewRemoval(view, animated: animated)
                self.more = nil
            }
        }
    }
    
    
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
    private var actionButton: ActionButton?
    
    
    private var adSettingView: AdSettingsView?
    
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
        let maxY: CGFloat

        if item.webpageAboveContent {
            maxY = 1
        } else {
            maxY = textFrame(item).maxY + item.defaultContentInnerInset
        }
        if let webpageLayout = item.webpageLayout {
            let size = webpageLayout.size
            return CGRect(origin: NSMakePoint(0, maxY), size: size)
        }
        return .zero
    }
    
    func textFrame(_ item: ChatMessageItem) -> NSRect {
        guard let item = self.item as? ChatMessageItem else {
            return .zero
        }
        let maxY: CGFloat

        if item.webpageAboveContent, item.webpageLayout != nil {
            maxY = webpageFrame(item).maxY + item.defaultContentInnerInset - 2
        } else {
            maxY = 0
        }
        return CGRect(origin: NSMakePoint(0, maxY), size: item.textLayout.layoutSize)

    }
    
    func adSettingFrame(_ item: ChatMessageItem) -> NSRect {
        let webpage = webpageFrame(item)
        var rect = NSMakeRect(webpage.maxX + contentFrame(item).minX + 10, contentFrame(item).minY + webpage.minY, 30, item.isFragmentAd ? 69 : 30)
        if item.isBubbled {
            rect.origin.x += 10
            rect.origin.y = bubbleFrame(item).minY
        }
        return rect
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        guard let item = self.item as? ChatMessageItem else {
            return
        }
        if let webpageContent = webpageContent {
            transition.updateFrame(view: webpageContent, frame: webpageFrame(item))
        }
        
        if let text = self.text {
            transition.updateFrame(view: text, frame: textFrame(item))
        }
        
        if let actionButton = actionButton {
            var add = item.additionalLineForDateInBubbleState ?? 0
            if !item.isBubbled {
                add = 0
            }
            let contentRect = self.contentFrame(item)
            transition.updateFrame(view: actionButton, frame: CGRect(origin: NSMakePoint(contentRect.minX, contentRect.maxY - actionButton.frame.height + add), size: actionButton.frame.size))
        }
        
        if let adSettingView {
            transition.updateFrame(view: adSettingView, frame: adSettingFrame(item))
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
    
    override func updateMouse(animated: Bool) {
        super.updateMouse(animated: animated)
        webpageContent?.updateMouse()
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        let point = self.contentView.convert(location, from: nil)
        return true
    }
    
    override func focusAnimation(_ innerId: AnyHashable?, text: String?) {
        super.focusAnimation(innerId, text: text)
        
        guard let item = item as? ChatRowItem else {
            return
        }
        if let text = text, !text.isEmpty {
            self.text?.highlight(text: text, color: item.presentation.colors.focusAnimationColor)
        }
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
                let current: TextView = TextView(frame: textFrame(item))
                current.update(item.textLayout)
                self.text = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            if let view = self.text {
                updateInlineStickers(context: item.context, view: [view])
            }
            
            if let webpageLayout = item.webpageLayout {
                let updated = webpageContent == nil || !webpageContent!.isKind(of: webpageLayout.viewClass())
                let current: WPContentView
                if !updated, let view = self.webpageContent {
                    current = view
                } else {
                    if let view = self.webpageContent {
                        performSubviewRemoval(view, animated: animated)
                    }
                    let vz = webpageLayout.viewClass() as! WPContentView.Type
                    current = vz.init()
                    current.frame = webpageFrame(item)
                    self.webpageContent = current
                    addSubview(current)
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                
                current.update(with: webpageLayout, animated: animated)
            } else if let view = webpageContent {
                performSubviewRemoval(view, animated: animated)
                webpageContent = nil
            }
            if let text = item.actionButtonText {
                var isNew = false
                if actionButton == nil {
                    actionButton = ActionButton(frame: .zero)
                    actionButton?.layer?.cornerRadius = .cornerRadius
                    actionButton?.disableActions()
                    actionButton?.set(font: .normal(.text), for: .Normal)
                    self.rowView.addSubview(actionButton!)
                    isNew = true
                }
                actionButton?.set(isExternalUrl: item.hasExternalLink, color: item.wpPresentation.activity.main)
                actionButton?.scaleOnClick = true
                actionButton?.removeAllHandlers()
                actionButton?.set(handler: { [weak item] _ in
                    item?.invokeAction()
                }, for: .Click)
                actionButton?.set(text: text, for: .Normal)
                actionButton?.set(color: item.wpPresentation.activity.main, for: .Normal)
                actionButton?.set(background: item.wpPresentation.activity.main.withAlphaComponent(0.1), for: .Normal)
                _ = actionButton?.sizeToFit(NSZeroSize, NSMakeSize(item.actionButtonWidth, 36), thatFit: true)
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
            
            if let adAttribute = item.message?.adAttribute {
                let current: AdSettingsView
                if let view = self.adSettingView {
                    current = view
                } else {
                    current = AdSettingsView(frame: adSettingFrame(item))
                    self.adSettingView = current
                    self.rowView.addSubview(current)
                }
                current.update(item, animated: animated)
                current.layer?.cornerRadius = current.frame.width / 2
            } else if let view = self.adSettingView {
                performSubviewRemoval(view, animated: animated)
                self.adSettingView = nil
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
        
        if let text = self.text, !item.textLayout.lines.isEmpty {
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
