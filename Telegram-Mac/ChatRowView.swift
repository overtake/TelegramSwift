//
//  ChatRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

private class ChatRowAnimateView: View {
    var stableId:AnyHashable?
}

class ChatRowView: TableRowView, Notifable, MultipleSelectable, ViewDisplayDelegate {
   
    
    var header: String? {
        if let item = item as? ChatRowItem, let message = item.message, let peer = messageMainPeer(message) {
            if !peer.isChannel, let date = item.fullDate, let name = item.authorText?.attributedString.string {
                return "\(name), [\(date)]:"
            }
        }
        return nil
    }


    private var avatar:AvatarControl?
    var contentView:View = View()
    private var replyView:ChatAccessoryView?
    private var replyMarkupView:View?
    private var forwardName:TextView?
    private(set) var captionView:TextView?
    private var shareControl:ImageButton?
    private var nameView:TextView?
    private var rightView:ChatRightView = ChatRightView(frame:NSZeroRect)
    private(set) var selectingView:SelectingControl?
    private var mouseDragged: Bool = false
    private var animatedView:ChatRowAnimateView?
    
    private var forwardAccessory: ChatBubbleAccessoryForward? = nil
    
    private var bubbleView: SImageView = SImageView()
    
    private let rowView: View
    
    required init(frame frameRect: NSRect) {
        rowView = View(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        
        super.addSubview(rowView)
        
        rowView.addSubview(bubbleView)
        rowView.addSubview(contentView)
        rowView.addSubview(rightView)
        
        rowView.displayDelegate = self
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        rowView.setFrameSize(newSize)
    }
    
    var selectableTextViews: [TextView] {
        if let captionView = captionView {
            return [captionView]
        }
        return []
    }
    
    func clickInContent(point: NSPoint) -> Bool {
        guard let item = item as? ChatRowItem, let layout = item.captionLayout, let captionView = captionView else {return true}
        let point = captionView.convert(point, from: self)
        let index = layout.findIndex(location: point)
        return point.x < layout.lines[index].frame.maxX
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ChatRowView {
            return self == other
        }
        return false
    }
    
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if (value.selectionState != oldValue.selectionState) {
                updateSelectingState(!NSIsEmptyRect(visibleRect), selectingMode:value.selectionState != nil, item: self.item as? ChatRowItem, needUpdateColors: true)
                updateColors()
                self.needsLayout = true
            } else if let item = item as? ChatRowItem, let message = item.message {
                if value.selectionState?.selectedIds.contains(message.id) != oldValue.selectionState?.selectedIds.contains(message.id) {
                    if let selectionState = value.selectionState {
                        selectingView?.set(selected: selectionState.selectedIds.contains(message.id), animated: !NSIsEmptyRect(visibleRect))
                        updateColors()
                        self.needsLayout = true
                    }
                }
            }
        }

    }
    
    
    func updateSelectingState(_ animated:Bool = false, selectingMode:Bool, item: ChatRowItem?, needUpdateColors: Bool) {
        if let item = item {
            let defRight = frame.width - item.rightSize.width - item.rightInset
            
            if !item.isBubbled {
                rightView.change(pos: NSMakePoint(defRight, rightView.frame.minY), animated: animated)
            } else {
                rowView.change(pos: rowPoint, animated: animated)
            }
            
            
            updateMouse()
            
            if selectingMode {
                if selectingView == nil {
                    selectingView = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
                    selectingView?.setFrameOrigin(NSMakePoint(frame.width, selectingPoint.y))
                    selectingView?.layer?.opacity = 0
                    super.addSubview(selectingView!)
                }
                selectingView?.change(opacity: 1.0, animated: animated)
               
                selectingView?.change(pos: selectingPoint, animated: animated)
            } else {
                if animated {
                    selectingView?.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion:false, completion:{ [weak self] (completed) in
                        //if completed {
                            self?.selectingView?.removeFromSuperview()
                            self?.selectingView = nil
                        //}
                    })
                } else {
                    self.selectingView?.removeFromSuperview()
                    self.selectingView = nil
                }
                selectingView?.change(pos: NSMakePoint(frame.width, selectingPoint.y), animated: animated)
            }
            
            updateSelectionViewAfterUpdateState(item: item, animated: animated)
            if needUpdateColors {
                updateColors()
            }
            if item.chatInteraction.presentation.state == .selecting {
                disableHierarchyInteraction()
            } else {
               restoreHierarchyInteraction()
            }

        }
    }
    
    func updateSelectionViewAfterUpdateState(item: ChatRowItem, animated: Bool) {
        
        if let selectionState = item.chatInteraction.presentation.selectionState, let message = item.message {
            selectingView?.set(selected: selectionState.selectedIds.contains(message.id), animated: animated)
        }
    }
    
    func canStartTextSelecting(_ event:NSEvent) -> Bool {
        return false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isSelect: Bool {
        if let item = item as? ChatRowItem, let message = item.message, let selectionState = item.chatInteraction.presentation.selectionState {
            return selectionState.selectedIds.contains(message.id)
        }
        return false
    }
    
    func isSelectInGroup(_ location: NSPoint) -> Bool {
        return isSelect
    }
    
    override var backdorColor: NSColor {
        return contextMenu != nil || isSelect ? theme.colors.selectMessage : theme.colors.background
    }
    
    var contentColor: NSColor {
        guard let item = item as? ChatRowItem else {return backdorColor}
        
        if item.hasBubble {
            return theme.chat.backgroundColor(item.isIncoming)
        } else {
            return backdorColor
        }
    }
    
    override func updateColors() -> Void {
        guard let item = item as? ChatRowItem else {return}

        rowView.backgroundColor = backdorColor
        rightView.backgroundColor = item.isStateOverlayLayout ? NSColor.black.withAlphaComponent(0.5) : contentColor
        contentView.backgroundColor = .clear
        item.replyModel?.backgroundColor = item.hasBubble ? theme.chat.backgroundColor(item.isIncoming) : item.isBubbled ? theme.colors.bubbleBackground_incoming : contentColor
        nameView?.backgroundColor = contentColor
        forwardName?.backgroundColor = contentColor
        captionView?.backgroundColor = contentColor
        replyMarkupView?.backgroundColor = backdorColor
        self.backgroundColor = backdorColor
        for view in contentView.subviews {
            if let view = view as? View {
                view.backgroundColor = contentColor
            }
        }
    }
    

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        mouseDragged = true
    }
    
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        mouseDragged = false
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        
        if let item = item as? ChatRowItem, !item.chatInteraction.isLogInteraction && !item.chatInteraction.disableSelectAbility, !item.sending, mouseInside(), !mouseDragged {
            
            if item.chatInteraction.presentation.state == .selecting {
                forceSelectItem(item, onRightClick: false)
            } else  {
                let location = self.convert(event.locationInWindow, from: nil)
                if NSPointInRect(location, rightView.frame) {
                    if item.isFailed {
                        confirm(for: mainWindow, header: tr(.alertSendErrorHeader), information: tr(.alertSendErrorText), okTitle: tr(.alertSendErrorResend), cancelTitle: tr(.alertSendErrorIgnore), thridTitle: tr(.alertSendErrorDelete), successHandler: { result in
                            
                            switch result {
                            case .thrid:
                                item.deleteMessage()
                            default:
                                item.resendMessage()
                            }
                            
                            
                        })
                    } else {
                        forceSelectItem(item, onRightClick: true)
                    }
                }
            }
        }
    }
    
    func forceSelectItem(_ item: ChatRowItem, onRightClick: Bool) {
        if let message = item.message {
            item.chatInteraction.update({$0.withToggledSelectedMessage(message.id)})
        }
    }
    
    override func onShowContextMenu() {
        updateColors()
        if let item = item as? ChatRowItem {
            item.chatInteraction.focusInputField()
        }
        super.onCloseContextMenu()
    }
    
    override func onCloseContextMenu() {
        updateColors()
        super.onCloseContextMenu()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {

        super.draw(layer, in: ctx)

        if let item = self.item as? ChatRowItem {
            
            if let fwdHeader = item.forwardHeader, !item.isBubbled {
                fwdHeader.1.draw(NSMakeRect(item.defLeftInset, item.forwardHeaderInset.y, fwdHeader.0.size.width, fwdHeader.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
            }
            
            let radius:CGFloat = 1.0
          //  ctx.fill(NSMakeRect(0, radius, 2, layer.bounds.height - radius * 2))
      //     ctx.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius + radius, height: radius + radius)))
          //  ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: layer.bounds.height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
            
            //draw separator
            if let fwdType = item.forwardType, !item.isBubbled {
                ctx.setFillColor(theme.colors.blueFill.cgColor)
                switch fwdType {
                case .ShortHeader:
                    let height = frame.height - item.forwardNameInset.y - item.defaultContentTopOffset
                    ctx.fill(NSMakeRect(item.defLeftInset, item.forwardNameInset.y + radius, 2, height - radius * 2))
                    ctx.fillEllipse(in: CGRect(origin: CGPoint(x: item.defLeftInset, y: item.forwardNameInset.y), size: CGSize(width: radius + radius, height: radius + radius)))
                    
                    ctx.fillEllipse(in: CGRect(origin: CGPoint(x: item.defLeftInset, y: item.forwardNameInset.y + height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
                    break
                case .FullHeader:
                    ctx.fill(NSMakeRect(item.defLeftInset, item.forwardNameInset.y + radius, 2, frame.height - item.forwardNameInset.y - radius))
                    ctx.fillEllipse(in: CGRect(origin: CGPoint(x: item.defLeftInset, y: item.forwardNameInset.y), size: CGSize(width: radius + radius, height: radius + radius)))
                    break
                case .Inside:
                     ctx.fill(NSMakeRect(item.defLeftInset, 0, 2, frame.height))
                    break
                case .Bottom:
                    ctx.fill(NSMakeRect(item.defLeftInset, 0, 2, frame.height - item.defaultContentTopOffset - radius))
                    ctx.fillEllipse(in: CGRect(origin: CGPoint(x: item.defLeftInset, y: frame.height - item.defaultContentTopOffset - radius), size: CGSize(width: radius + radius, height: radius + radius)))
                    break
                }
                
            }

        }
        
    }
    
    override func updateMouse() {
        if let shareControl = self.shareControl, let item = item as? ChatRowItem {
            shareControl.change(opacity: item.chatInteraction.presentation.state != .selecting && mouseInside() ? 1.0 : 0.0, animated: true)
        }
    }
    
    
    
    override func addSubview(_ view: NSView) {
        self.contentView.addSubview(view)
    }
    
    func fillReplyIfNeeded(_ reply:ReplyModel?, _ item:ChatRowItem) -> Void {
        
        if let reply = reply {
            
            if replyView == nil {
                replyView = ChatAccessoryView()
                replyView?.backgroundColor = backdorColor
                rowView.addSubview(replyView!)
            }
            
            if reply.isSideAccessory {
                replyView?.layer?.cornerRadius = .cornerRadius
            } else {
                replyView?.layer?.cornerRadius = 0
            }
            
            replyView?.removeAllHandlers()
            replyView?.set(handler: { [weak item, weak reply] _ in
                item?.chatInteraction.focusInputField()
                if let replyMessage = reply?.replyMessage, let fromMessage = item?.message {
                    item?.chatInteraction.focusMessageId(fromMessage.id, replyMessage.id, .center(id: 0, animated: true, focus: true, inset: 0))
                }
                
            }, for: .Click)
            
            reply.view = replyView
            //reply.view?.needsDisplay = true
        } else {
            replyView?.removeFromSuperview()
            replyView = nil
        }
        
    }
    
    var bubbleFrame: NSRect {
        guard let item = item as? ChatRowItem else {return NSZeroRect}
        return NSMakeRect(item.isIncoming ? item.bubbleFrame.minX : frame.width - item.bubbleFrame.width - item.leftInset, item.bubbleFrame.minY, item.bubbleFrame.width, item.bubbleFrame.height)
    }
    
    var rightFrame: NSRect {
        guard let item = item as? ChatRowItem else {return NSZeroRect}
        var rect = NSMakeRect(frame.width - item.rightSize.width - item.rightInset, item.defaultContentTopOffset, item.rightSize.width, item.rightSize.height)
        
        if item.isBubbled {
            rect.origin = NSMakePoint((item.hasBubble ? bubbleFrame.maxX : contentFrame.maxX) - item.rightSize.width - item.bubbleContentInset - (item.isIncoming ? 0 : item.additionBubbleInset), bubbleFrame.maxY - item.rightSize.height - 6 - (item.isStateOverlayLayout && !item.hasBubble ? 2 : 0))
            if item is ChatVideoMessageItem {
                rect.origin.x = item.isIncoming ? contentFrame.maxX - 50 : contentFrame.maxX - item.rightSize.width
            }
        }
        
        return rect
    }
    
    var avatarFrame: NSRect {
        guard let item = item as? ChatRowItem else {return NSZeroRect}

        var rect = NSMakeRect(item.leftInset, 6, 36, 36)

        if item.isBubbled {
            rect.origin.y = frame.height - item.additionBubbleInset - 36
        }
        
        return rect
    }
    
    var captionFrame: NSRect {
        guard let item = item as? ChatRowItem, let captionLayout = item.captionLayout else {return NSZeroRect}
        
        return NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset, captionLayout.layoutSize.width, captionLayout.layoutSize.height)
    }
    
    var replyMarkupFrame: NSRect {
        guard let item = item as? ChatRowItem, let replyMarkup = item.replyMarkupModel else {return NSZeroRect}

        var frame = NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset, replyMarkup.size.width, replyMarkup.size.height)
        
        if let captionLayout = item.captionLayout {
            frame.origin.y += captionLayout.layoutSize.height + item.defaultContentInnerInset
        }
        
        if item.hasBubble {
            frame.origin.y = bubbleFrame.maxY + item.defaultContentInnerInset
            frame.origin.x = bubbleFrame.minX + (item.isIncoming ? item.additionBubbleInset : 0)
        }
        
        return frame
    }
    
    var replyFrame: NSRect {
        guard let item = item as? ChatRowItem, let reply = item.replyModel else {return NSZeroRect}
        
        var frame: NSRect = NSMakeRect(contentFrame.minX + item.elementsContentInset, item.replyOffset, reply.size.width, reply.size.height)
        if item.isBubbled, !item.hasBubble {
            if item.isIncoming {
                frame.origin.x = contentFrame.maxX + 10
            } else {
                frame.origin.x = contentFrame.minX - reply.size.width - 10
            }
        }
        return frame
    }
    
    var namePoint: NSPoint {
        guard let item = item as? ChatRowItem else {return NSZeroPoint}
        
        var point = NSMakePoint(contentFrame.minX, item.defaultContentTopOffset)
        if item.isBubbled {
            point.y -= item.topInset
        } else {
            if item.forwardType != nil {
                point.x -= item.leftContentInset
            }
        }
        point.x += item.elementsContentInset
        return point
        
    }
    
    var selectingPoint: NSPoint {
        
        guard let item = item as? ChatRowItem else {return NSZeroPoint}
        
        var point = NSZeroPoint
        
        if let selectingView = selectingView {
            if item.isBubbled {
                let f = focus(selectingView.frame.size)
                point.y = f.minY
                point.x = frame.width - selectingView.frame.width - 15
            } else {
                point = NSMakePoint(rightFrame.maxX + 4, item.defaultContentTopOffset - 1)
            }
        }
        return point
    }
    
    var contentFrame:NSRect {
        guard let item = item as? ChatRowItem else {return NSZeroRect}
        var rect = NSMakeRect(item.contentOffset.x, item.contentOffset.y, item.contentSize.width, item.contentSize.height)
        if item.isBubbled {
            if !item.isIncoming {
                rect.origin.x = bubbleFrame.minX + item.bubbleContentInset
            } else {
                rect.origin.x = bubbleFrame.minX + item.bubbleContentInset + item.additionBubbleInset
            }
            
        }
        return rect
    }
    
    var rowPoint: NSPoint {
        guard let item = item as? ChatRowItem else {return NSZeroPoint}
        if item.isBubbled {
            return NSMakePoint(item.chatInteraction.presentation.state == .selecting && !item.isIncoming ? -20 : 0, 0)
        } else {
            return NSZeroPoint
        }
    }
    
    var forwardNamePoint: NSPoint {
        guard let item = item as? ChatRowItem else {return NSZeroPoint}

        var point = item.forwardNameInset
        
        if item.isBubbled && item.hasBubble {
            point.x = bubbleFrame.minX + (item.isIncoming ? item.bubbleContentInset + item.additionBubbleInset : item.bubbleContentInset)
        } else if item.isBubbled, let forwardAccessory = forwardAccessory {
            point.x = item.isIncoming ? contentFrame.maxX : contentFrame.minX - forwardAccessory.frame.width
        }
        
        return point
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ChatRowItem {
            bubbleView.frame = bubbleFrame
            contentView.frame = contentFrame
            
            rowView.setFrameOrigin(rowPoint)
            
            forwardName?.setFrameOrigin(forwardNamePoint)
            forwardAccessory?.setFrameOrigin(forwardNamePoint)

            rightView.frame = rightFrame
            nameView?.setFrameOrigin(namePoint)
            
            
            item.replyModel?.frame = replyFrame

            
            avatar?.frame = avatarFrame
            captionView?.frame = captionFrame
            
            replyMarkupView?.frame = replyMarkupFrame
            item.replyMarkupModel?.layout()

            
            selectingView?.setFrameOrigin(selectingPoint)
            
            
            if let shareControl = shareControl {
                if item.isBubbled {
                    shareControl.setFrameOrigin(item.isIncoming ? bubbleFrame.maxX + 15 : bubbleFrame.minX - shareControl.frame.width - 15, bubbleFrame.maxY - shareControl.frame.height - (item is ChatVideoMessageItem ? rightFrame.height + 14 : 0))
                } else {
                    shareControl.setFrameOrigin(frame.width - 20.0 - shareControl.frame.width, rightView.frame.maxY )
                }
            }
        }
    }
    
    
    
    func fillForward(_ item:ChatRowItem) -> Void {
        if let forwardNameLayout = item.forwardNameLayout {
            if item.isBubbled && item.isInstantVideo {
                forwardName?.removeFromSuperview()
                forwardName = nil
                
                if forwardAccessory == nil {
                    forwardAccessory = ChatBubbleAccessoryForward(frame: NSZeroRect)
                    rowView.addSubview(forwardAccessory!)
                }
                
                forwardAccessory?.updateText(layout: forwardNameLayout)
                
            } else {
                forwardAccessory?.removeFromSuperview()
                forwardAccessory = nil
                
                if forwardName == nil {
                    forwardName = TextView()
                    forwardName?.isSelectable = false
                    rowView.addSubview(forwardName!)
                }
                forwardName?.update(forwardNameLayout)
            }
            
        } else {
            forwardName?.removeFromSuperview()
            forwardName = nil
            forwardAccessory?.removeFromSuperview()
            forwardAccessory = nil
        }
    }
    
    func fillPhoto(_ item:ChatRowItem) -> Void {
        if item.hasPhoto, let peer = item.peer {
            
            if avatar == nil {
                avatar = AvatarControl(font: .avatar(.text))
                avatar?.setFrameSize(36,36)
               rowView.addSubview(avatar!)
            }
            avatar?.removeAllHandlers()
            avatar?.set(handler: { [weak item] control in
                item?.chatInteraction.openInfo(peer.id, false, nil, nil)
            }, for: .Click)
            
            self.avatar?.setPeer(account: item.account, peer: peer)
            
        } else {
            avatar?.removeFromSuperview()
            avatar = nil
        }
    }
    
    func fillCaption(_ item:ChatRowItem) -> Void {
        if let layout = item.captionLayout {
            if captionView == nil {
                captionView = TextView()
                rowView.addSubview(captionView!)
                rowView.addSubview(rightView)
            }
            //addSubview(captionView!, positioned: .below, relativeTo: rightView)
            captionView?.update(layout)
        } else {
            captionView?.removeFromSuperview()
            captionView = nil
        }
    }
    
    func fillShareControl(_ item:ChatRowItem) -> Void {
        if item.isSharable || item.isStorage {
            if shareControl == nil {
                shareControl = ImageButton()
                shareControl?.disableActions()
                shareControl?.change(opacity: 0, animated: false)
                rowView.addSubview(shareControl!)
            }
            
            guard let shareControl = shareControl else {return}
            
            shareControl.set(image: item.isStorage ? theme.icons.chatGoMessage : theme.icons.chatForwardMessagesActive, for: .Normal)
            shareControl.sizeToFit()

//
//            if item.isBubbled {
//                shareControl.setFrameSize(shareControl.frame.width + 5, shareControl.frame.height + 5)
//                shareControl.set(background: theme.colors.grayForeground, for: .Normal)
//                shareControl.layer?.cornerRadius = shareControl.frame.height / 2
//            } else {
//                shareControl.sizeToFit()
//                shareControl.set(background: theme.colors.background, for: .Normal)
//                shareControl.layer?.cornerRadius = 0
//            }
            
            shareControl.removeAllHandlers()
            shareControl.set(handler: { [ weak item] _ in
                if let item = item {
                    if item.isStorage {
                        item.gotoSourceMessage()
                    } else {
                        item.share()
                    }
                }
            }, for: .Click)
        } else {
            shareControl?.removeFromSuperview()
            shareControl = nil
        }
    }
    
    func fillReplyMarkup(_ item:ChatRowItem) -> Void {
        if let replyMarkup = item.replyMarkupModel {
            if replyMarkupView == nil {
                replyMarkupView = View()
                rowView.addSubview(replyMarkupView!)
            }
            
            replyMarkupView?.setFrameSize(replyMarkup.size.width, replyMarkup.size.height)
            replyMarkup.view = replyMarkupView
            replyMarkup.redraw()
        } else {
            replyMarkupView?.removeFromSuperview()
            replyMarkupView = nil
        }
    }
    
    func fillName(_ item:ChatRowItem) -> Void {
        if let author = item.authorText {
            if nameView == nil {
                nameView = TextView()
                nameView?.isSelectable = false
                rowView.addSubview(nameView!)
            }
            nameView?.update(author, origin: namePoint)
        } else {
            nameView?.removeFromSuperview()
            nameView = nil
        }
    }
    
    override func focusAnimation() {
        
        if animatedView == nil {
            self.animatedView = ChatRowAnimateView(frame:bounds)
            self.animatedView?.isEventLess = true
            rowView.addSubview(animatedView!)
            animatedView?.backgroundColor = NSColor(0x68A8E2)
            animatedView?.layer?.opacity = 0
            
        }
        animatedView?.stableId = item?.stableId
        animatedView?.change(opacity: 0.5, animated: true, false, removeOnCompletion: false, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
            //if completed {
                self?.animatedView?.change(opacity: 0, animated: true, false, removeOnCompletion: true, duration: 1.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
                    //if completed {
                        self?.animatedView?.removeFromSuperview()
                        self?.animatedView = nil
                  //  }
                })
          //  }
        })
     
        
    }
    
    func canDropSelection(in location: NSPoint) -> Bool {
        return true
    }

    override func rightMouseDown(with event: NSEvent) {
        if let item = self.item as? ChatRowItem {
            if item.chatInteraction.presentation.state == .selecting {
                return
            }
        }
        super.rightMouseDown(with: event)
    }
    
    
    private func renderLayoutType(_ item: ChatRowItem, animated: Bool) {
        if item.isBubbled, item.hasBubble {
            bubbleView.data = item.modernBubbleImage
            
        } else {
            bubbleView.data = nil
        }
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
                
        if let item = self.item as? ChatRowItem {
            item.chatInteraction.remove(observer: self)
        }
        if self.animatedView != nil && self.animatedView?.stableId != item.stableId {
            self.animatedView?.removeFromSuperview()
            self.animatedView = nil
        }
        
        if let item = item as? ChatRowItem {
            
            renderLayoutType(item, animated: animated)
            
            rightView.set(item:item, animated:animated)
            fillName(item)
            fillReplyIfNeeded(item.replyModel, item)
            fillForward(item)
            fillPhoto(item)
            fillCaption(item)
            fillReplyMarkup(item)
            fillShareControl(item)
            
            item.chatInteraction.add(observer: self)
            
            updateSelectingState(selectingMode:item.chatInteraction.presentation.selectionState != nil, item: item, needUpdateColors: false)
        }
        rowView.needsDisplay = true
        super.set(item: item, animated: animated)
        layout()
    }

    open override func interactionContentView(for innerId: AnyHashable ) -> NSView {
        return self.contentView
    }
    
    override func doubleClick(in location: NSPoint) {
        if let item = self.item as? ChatRowItem, item.chatInteraction.presentation.state == .normal {
            if self.hitTest(location) == nil || self.hitTest(location) == self || !clickInContent(point: location) || self.hitTest(location) == rowView || self.hitTest(location) == replyView {
                if let avatar = avatar {
                    if NSPointInRect(location, avatar.frame) {
                        return
                    }
                }
                item.chatInteraction.setupReplyMessage(item.message?.id)
            }
        }
    }
    
    func toggleSelected(_ select: Bool, in point: NSPoint) {
        guard let item = item as? ChatRowItem else { return }
        
        item.chatInteraction.update({ current in
            if let message = item.message {
                if (select && !current.isSelectedMessageId(message.id)) || (!select && current.isSelectedMessageId(message.id)) {
                    return current.withToggledSelectedMessage(message.id)
                }
            }
            return current
        })
    }
    
    override func forceClick(in location: NSPoint) {
        guard let item = item as? ChatRowItem else { return }
        
        let hitTestView = self.hitTest(location)
        if hitTestView == nil || hitTestView == self || hitTestView == replyView || hitTestView?.isDescendant(of: contentView) == true {
            if let avatar = avatar {
                if NSPointInRect(location, avatar.frame) {
                    return
                }
            }
            let result: Bool
            switch FastSettings.forceTouchAction {
            case .edit:
                result = item.editAction()
            case .reply:
                result = item.replyAction()
            case .forward:
                result = item.forwardAction()
            }
            if result {
                focusAnimation()
            }
        }
        
    }
    
    deinit {
        if let item = self.item as? ChatRowItem {
            item.chatInteraction.remove(observer: self)
        }
        contentView.removeAllSubviews()
    }
    
    override func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return contentView.convert(point, from: nil)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
         if let item = self.item as? ChatRowItem {
            if window == nil {
                item.chatInteraction.remove(observer: self)
            } else {
                item.chatInteraction.add(observer: self)
            }
        }
    }
    
}
