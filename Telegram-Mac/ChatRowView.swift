//
//  ChatRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit



class ChatRowView: TableRowView, Notifable, MultipleSelectable, ViewDisplayDelegate, RevealTableView {
    
    
   
    
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
    private(set) var forwardName:TextView?
    private(set) var captionView:TextView?
    private var shareControl:ImageButton?
    private var nameView:TextView?
    private var adminBadge: TextView?
    let rightView:ChatRightView = ChatRightView(frame:NSZeroRect)
    private(set) var selectingView:SelectingControl?
    private var mouseDragged: Bool = false
    private var animatedView:RowAnimateView?
    
    private var forwardAccessory: ChatBubbleAccessoryForward? = nil
    private var viaAccessory: ChatBubbleViaAccessory? = nil
    
    let bubbleView = ChatMessageBubbleBackdrop()
    
    private var scamButton: ImageButton? = nil
    private var scamForwardButton: ImageButton? = nil

    let rowView: View

    required init(frame frameRect: NSRect) {
        rowView = View(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        
        super.addSubview(rowView)
        
        
        
        rowView.addSubview(bubbleView)
        rowView.addSubview(contentView)
        rowView.addSubview(rightView)
        
        rowView.displayDelegate = self
        
        super.addSubview(swipingRightView)
        
        
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        if !inLiveResize || !NSIsEmptyRect(visibleRect) {
            super.setFrameSize(newSize)
            rowView.setFrameSize(newSize)
        }
        
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        let oldOrigin = self.frame.origin
        super.setFrameOrigin(newOrigin)
        
        if oldOrigin != newOrigin, oldOrigin == .zero {
            updateBackground(animated: false)
        }
    }
    
    func updateBackground(animated: Bool, rotated: Bool = false) -> Void {
        
        guard let item = self.item as? ChatRowItem else {
            return
        }
        let gradientRect = item.chatInteraction.getGradientOffsetRect()
        let size = NSMakeSize(gradientRect.width, gradientRect.height + 30)
        
        let inset = size.height - gradientRect.minY + (frame.height - bubbleFrame.maxY) - 30
       // if visibleRect.height > 0 {
            bubbleView.update(rect: self.frame.offsetBy(dx: 0, dy: inset), within: size, animated: animated, rotated: rotated)
      //  }
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
                if rowView.frame.origin != rowPoint {
                    rowView.change(pos: rowPoint, animated: animated)
                }
            }
            
            
            updateMouse()
            
            if selectingMode {
                let force: Bool = selectingView == nil
                if selectingView == nil {
                    selectingView = SelectingControl(unselectedImage: item.presentation.icons.chatGroupToggleUnselected, selectedImage: item.presentation.icons.chatGroupToggleSelected, selected: item.isSelectedMessage)
                    selectingView?.setFrameOrigin(NSMakePoint(frame.width, selectingPoint.y))
                    selectingView?.layer?.opacity = 0
                    super.addSubview(selectingView!)
                }
                if selectingView!.isSelected != item.isSelectedMessage || force {
                    selectingView?.change(opacity: 1.0, animated: animated)
                    selectingView?.change(pos: selectingPoint, animated: animated)
                }
                
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
                renderLayoutType(item, animated: animated)
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
        if let item = item as? ChatRowItem {
            return isSelectedItem(item)
        }
        return false
    }
    
    private func isSelectedItem(_ item: ChatRowItem) -> Bool {
        if let message = item.message, let selectionState = item.chatInteraction.presentation.selectionState {
            return selectionState.selectedIds.contains(message.id)
        }
        return false
    }
    
    func isSelectInGroup(_ location: NSPoint) -> Bool {
        return isSelect
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? ChatRowItem else {return super.backdorColor}
        if let forceBackgroundColor = item.forceBackgroundColor {
            return forceBackgroundColor
        }
        return item.renderType == .bubble ? .clear : contextMenu != nil || isSelect ? item.presentation.colors.selectMessage : item.presentation.chatBackground
    }
    
    var contentColor: NSColor {
        guard let item = item as? ChatRowItem else {return backdorColor}
        
        if item.hasBubble {
            return .clear//isSelect || contextMenu != nil ? item.presentation.chat.backgoundSelectedColor(item.isIncoming, item.renderType == .bubble) : item.presentation.chat.backgroundColor(item.isIncoming, item.renderType == .bubble)
        } else {
            return .clear//backdorColor
        }
    }

    
    override func updateColors() -> Void {
        super.updateColors()
        
        guard let item = item as? ChatRowItem else {return}

        rowView.backgroundColor = backdorColor
        rightView.backgroundColor = item.isStateOverlayLayout ? .clear : contentColor
        contentView.backgroundColor = .clear
        item.replyModel?.backgroundColor = item.hasBubble ? contentColor : item.isBubbled ? item.presentation.colors.bubbleBackground_incoming : contentColor
        nameView?.backgroundColor = contentColor
        forwardName?.backgroundColor = contentColor
        captionView?.backgroundColor = contentColor
        replyMarkupView?.backgroundColor = backdorColor
        
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
                    if item.isFailed,  let messageId = item.message?.id {
                        
                       
                        
                        let signal = item.context.account.postbox.transaction { transaction -> [MessageId] in
                            return transaction.getMessageFailedGroup(messageId)?.compactMap({$0.id}) ?? []
                        } |> deliverOnMainQueue

                        
                        _ = signal.start(next: { ids in
                            let alert:NSAlert = NSAlert()
                            alert.window.appearance = theme.appearance
                            alert.alertStyle = .informational
                            alert.messageText = L10n.alertSendErrorHeader
                            alert.informativeText = L10n.alertSendErrorText
                            
                           
                            
                            alert.addButton(withTitle: L10n.alertSendErrorResend)
                            
                            if ids.count > 1 {
                                alert.addButton(withTitle: L10n.alertSendErrorResendItemsCountable(ids.count))
                            }
                            
                            alert.addButton(withTitle: L10n.alertSendErrorDelete)
                            
                           
                            
                            alert.addButton(withTitle: L10n.alertSendErrorIgnore)
                            
                            
                            alert.beginSheetModal(for: mainWindow, completionHandler: { [weak item] response in
                                switch response.rawValue {
                                case 1000:
                                    item?.resendMessage([messageId])
                                case 1001:
                                    if ids.count > 1 {
                                        item?.resendMessage(ids)
                                    } else {
                                        item?.deleteMessage()
                                    }
                                case 1002:
                                    if ids.count > 1 {
                                        item?.deleteMessage()
                                    }
                                default:
                                    break
                                }
                            })
                        })
                        
//                        item.account.postbox.transaction { transaction -> T in
//                            transaction
//                        }
//
                      
                        
                        
//                        confirm(for: mainWindow, header: L10n.alertSendErrorHeader, information: L10n.alertSendErrorText, okTitle: L10n.alertSendErrorResend, cancelTitle: L10n.alertSendErrorIgnore, thridTitle: L10n.alertSendErrorDelete, fourTitle: "Resend All", successHandler: { result in
//
//                            switch result {
//                            case .thrid:
//                                item.deleteMessage()
//                            default:
//                                item.resendMessage()
//                            }
//
//
//                        })
                    } else {
                        forceSelectItem(item, onRightClick: true)
                    }
                }
            }
        }
    }
    
    func forceSelectItem(_ item: ChatRowItem, onRightClick: Bool) {
        if let message = item.message {
            item.chatInteraction.withToggledSelectedMessage({$0.withToggledSelectedMessage(message.id)})
        }
    }
    
    override func onShowContextMenu() {
        guard let item = item as? ChatRowItem else {return}
        renderLayoutType(item, animated: true)

        updateColors()
        item.chatInteraction.focusInputField()
        super.onCloseContextMenu()
    }
    
    override func onCloseContextMenu() {
        guard let item = item as? ChatRowItem else {return}
        renderLayoutType(item, animated: true)
        self.rowView.change(pos: NSZeroPoint, animated: true)
        updateColors()
        super.onCloseContextMenu()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {

      //  super.draw(layer, in: ctx)

        if let item = self.item as? ChatRowItem {
            
            if let fwdHeader = item.forwardHeader, !item.isBubbled, layer == rowView.layer {
                let rect = NSMakeRect(item.defLeftInset, item.forwardHeaderInset.y, fwdHeader.0.size.width, fwdHeader.0.size.height)
                if backingScaleFactor == 1.0 {
                    ctx.setFillColor(contentColor.cgColor)
                    ctx.fill(rect)
                }
                fwdHeader.1.draw(rect, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            
            let radius:CGFloat = 1.0
          //  ctx.fill(NSMakeRect(0, radius, 2, layer.bounds.height - radius * 2))
      //     ctx.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius + radius, height: radius + radius)))
          //  ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: layer.bounds.height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
            
            //draw separator
            if let fwdType = item.forwardType, !item.isBubbled, layer == rowView.layer {
                ctx.setFillColor(item.presentation.colors.accent.cgColor)
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
                    item?.chatInteraction.focusMessageId(fromMessage.id, replyMessage.id, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0))
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
        let bubbleFrame = item.bubbleFrame
        return NSMakeRect(item.isIncoming ? item.bubbleFrame.minX : frame.width - bubbleFrame.width - item.leftInset, bubbleFrame.minY, bubbleFrame.width, bubbleFrame.height)
    }
    
    var rightFrame: NSRect {
        guard let item = item as? ChatRowItem else {return NSZeroRect}
        
        let rightSize = item.rightSize
        
        var rect = NSMakeRect(frame.width - rightSize.width - item.rightInset, item.defaultContentTopOffset, rightSize.width, rightSize.height)
        let bubbleFrame = self.bubbleFrame
        let hasBubble = item.hasBubble
        if item.isBubbled {
            rect.origin = NSMakePoint((hasBubble ? bubbleFrame.maxX : contentFrame.maxX) - rightSize.width - item.bubbleContentInset - (item.isIncoming ? 0 : item.additionBubbleInset), bubbleFrame.maxY - rightSize.height - 6 - (item.isStateOverlayLayout && !hasBubble ? 2 : 0))
            
            if item.isStateOverlayLayout {
                if item.isInstantVideo {
                    rect.origin.y = contentFrame.maxY - rect.height - 3
                } else {
                    rect.origin.x += 5
                    rect.origin.y -= 2
                    rect.origin.x = max(20, rect.origin.x)
                }
            }
            if item is ChatVideoMessageItem {
                rect.origin.x = item.isIncoming ? contentFrame.maxX - 40 : contentFrame.maxX - rightSize.width
                rect.origin.y += 3
            }
            if let item = item as? ChatMessageItem, item.containsBigEmoji {
                rect.origin.y = contentFrame.maxY + item.defaultContentTopOffset
            }
        }
        
        return rect
    }
    
    var avatarFrame: NSRect {
        guard let item = item as? ChatRowItem else {return NSZeroRect}

        var rect = NSMakeRect(item.leftInset, 6, 36, 36)

        if item.isBubbled {
            rect.origin.y = frame.height - 36
        }
        
        return rect
    }
    
    var captionFrame: NSRect {
        guard let item = item as? ChatRowItem, let captionLayout = item.captionLayout else {return NSZeroRect}
        
        return NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset, captionLayout.layoutSize.width, captionLayout.layoutSize.height)
    }
    
    var replyMarkupFrame: NSRect {
        guard let item = item as? ChatRowItem, let replyMarkup = item.replyMarkupModel else {return NSZeroRect}

        var frame = NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultReplyMarkupInset, replyMarkup.size.width, replyMarkup.size.height)
        
        if let captionLayout = item.captionLayout {
            frame.origin.y += captionLayout.layoutSize.height + item.defaultContentInnerInset
        }
        
        if item.hasBubble {
            frame.origin.y = bubbleFrame.maxY + item.defaultReplyMarkupInset
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
    
    var viaAccesoryPoint: NSPoint {
        guard let item = item as? ChatRowItem, let viaAccessory = viaAccessory else {return NSZeroPoint}
        
        if viaAccessory.superview == replyView {
            return NSMakePoint(5, 0)
        }
        
        var point: NSPoint = NSMakePoint(contentFrame.minX + item.elementsContentInset, item.defaultContentTopOffset)
        if item.isBubbled, !item.hasBubble {
            if item.isIncoming {
                point.x = contentFrame.maxX + 10
            } else {
                point.x = contentFrame.minX - viaAccessory.frame.width - 10
            }
        }
        return point
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
    
    var scamPoint: NSPoint {
        guard let item = item as? ChatRowItem, let authorText = item.authorText else {return NSZeroPoint}
        
        var point = self.namePoint
        point.x += authorText.layoutSize.width + 3
        point.y += 1
        return point
    }
    
    var scamForwardPoint: NSPoint {
        guard let item = item as? ChatRowItem, let forwardName = item.forwardNameLayout else {return NSZeroPoint}
        
        var point = self.forwardNamePoint
        point.x += forwardName.layoutSize.width + 3
        //point.y += 1
        return point
    }
    
    var adminBadgePoint: NSPoint {
        guard let item = item as? ChatRowItem, let adminBadge = item.adminBadge, let authorText = item.authorText else {return NSZeroPoint}
        
        var point = NSMakePoint( item.isBubbled ? bubbleFrame.maxX - item.bubbleContentInset - adminBadge.layoutSize.width : namePoint.x + authorText.layoutSize.width, item.defaultContentTopOffset + 1)
        if item.isBubbled {
            point.y -= item.topInset
        }
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
    
    var contentFrameModifier: NSRect {
        return self.contentFrame
    }
    
    var rowPoint: NSPoint {
        guard let item = item as? ChatRowItem else {return NSZeroPoint}
        
        if item.isBubbled {
            return NSMakePoint((item.chatInteraction.presentation.state == .selecting && !item.isIncoming ? -20 : 0), 0)
        } else {
            return NSMakePoint(0, 0)
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
    //    super.layout()
        if let item = item as? ChatRowItem {
            bubbleView.frame = bubbleFrame
            contentView.frame = contentFrameModifier
            

            
            rowView.setFrameOrigin(rowPoint)
            
            forwardName?.setFrameOrigin(forwardNamePoint)
            forwardAccessory?.setFrameOrigin(forwardNamePoint)

            rightView.frame = rightFrame

            nameView?.setFrameOrigin(namePoint)
            
            adminBadge?.setFrameOrigin(adminBadgePoint)
            
            viaAccessory?.setFrameOrigin(viaAccesoryPoint)
            item.replyModel?.frame = replyFrame

            
            scamButton?.setFrameOrigin(scamPoint)
            scamForwardButton?.setFrameOrigin(scamForwardPoint)
            avatar?.frame = avatarFrame
            captionView?.frame = captionFrame
            
            replyMarkupView?.frame = replyMarkupFrame
            item.replyMarkupModel?.layout()

            
            selectingView?.setFrameOrigin(selectingPoint)
            

            swipingRightView.frame = NSMakeRect(frame.width, 0, rightRevealWidth, frame.height)
            
            
            if let shareControl = shareControl {
                if item.isBubbled {
                    shareControl.setFrameOrigin(item.isIncoming ? max(bubbleFrame.maxX + 15, item.isStateOverlayLayout ? rightFrame.width + 15 : 0) : bubbleFrame.minX - shareControl.frame.width - 15, bubbleFrame.maxY - shareControl.frame.height - (item.isVideoOrBigEmoji ? rightFrame.height + 14 : 0))
                } else {
                    shareControl.setFrameOrigin(frame.width - 20.0 - shareControl.frame.width, rightView.frame.maxY )
                }
            }
        }
    }
    
    
    
    func fillForward(_ item:ChatRowItem) -> Void {
        if let forwardNameLayout = item.forwardNameLayout {
            if item.isBubbled && !item.hasBubble {
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
                item?.openInfo()
            }, for: .Click)
            avatar?.toolTip = item.nameHide
            self.avatar?.setPeer(account: item.context.account, peer: peer, message: item.message)
            
        } else {
            avatar?.removeFromSuperview()
            avatar = nil
        }
    }
    
    func fillScamButton(_ item: ChatRowItem) -> Void {
        if item.isScam, item.canFillAuthorName {
            if scamButton == nil {
                scamButton = ImageButton()
                scamButton?.autohighlight = false
                scamButton?.setFrameSize(theme.icons.scam.backingSize)
                rowView.addSubview(scamButton!)
                scamButton?.set(handler: { control in
                    tooltip(for: control, text: L10n.peerInfoScamWarning)
                }, for: .Click)
            }
            scamButton?.set(image: theme.icons.chatScam, for: .Normal)
            
        } else {
            scamButton?.removeFromSuperview()
            scamButton = nil
        }
    }
    
    func fillScamForwardButton(_ item: ChatRowItem) -> Void {
        if item.isForwardScam {
            if scamForwardButton == nil {
                scamForwardButton = ImageButton()
                scamForwardButton?.autohighlight = false
                scamForwardButton?.setFrameSize(theme.icons.scam.backingSize)
                rowView.addSubview(scamForwardButton!)
                scamForwardButton?.set(handler: { control in
                    tooltip(for: control, text: L10n.peerInfoScamWarning)
                }, for: .Click)
            }
            scamForwardButton?.set(image: theme.icons.chatScam, for: .Normal)
            
        } else {
            scamForwardButton?.removeFromSuperview()
            scamForwardButton = nil
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
            
            

            if item.isBubbled && item.presentation.backgroundMode.hasWallpapaer  {
                shareControl.set(image: item.isStorage ? item.presentation.icons.chatGotoMessageWallpaper : item.presentation.icons.chatShareWallpaper, for: .Normal)
                _ = shareControl.sizeToFit()
                shareControl.setFrameSize(NSMakeSize(shareControl.frame.width + 10, shareControl.frame.height + 10))
                shareControl.background = item.presentation.colors.background
                shareControl.layer?.cornerRadius = shareControl.frame.height / 2
            } else {
                shareControl.set(image: item.isStorage ? item.presentation.icons.chatGoMessage : item.presentation.icons.chatForwardMessagesActive, for: .Normal)
                _ = shareControl.sizeToFit()
                shareControl.background = .clear
            }
            
//
//            if item.isBubbled {
//                shareControl.setFrameSize(shareControl.frame.width + 5, shareControl.frame.height + 5)
//                shareControl.set(background: item.presentation.colors.grayForeground, for: .Normal)
//                shareControl.layer?.cornerRadius = shareControl.frame.height / 2
//            } else {
//                shareControl.sizeToFit()
//                shareControl.set(background: item.presentation.colors.background, for: .Normal)
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
            if item.isBubbled && !item.hasBubble {
                nameView?.removeFromSuperview()
                nameView = nil
                
                adminBadge?.removeFromSuperview()
                adminBadge = nil
                
                if viaAccessory == nil {
                    viaAccessory = ChatBubbleViaAccessory(frame: NSZeroRect)
                }
                
                guard let viaAccessory = viaAccessory else {return}
                
                viaAccessory.removeFromSuperview()
                if replyView != nil {
                    replyView?.addSubview(viaAccessory)
                } else {
                    rowView.addSubview(viaAccessory)
                }
                
                viaAccessory.updateText(layout: author)
                
                
            } else {
                
                viaAccessory?.removeFromSuperview()
                viaAccessory = nil
                
                if nameView == nil {
                    nameView = TextView()
                    nameView?.isSelectable = false
                    
                    rowView.addSubview(nameView!)
                }
                
                if let adminBadge = item.adminBadge {
                    if self.adminBadge == nil {
                        self.adminBadge = TextView()
                        self.adminBadge?.isSelectable = false
                        rowView.addSubview(self.adminBadge!)
                    }
                    self.adminBadge?.update(adminBadge, origin: adminBadgePoint)
                } else {
                    adminBadge?.removeFromSuperview()
                    adminBadge = nil
                }
                
                nameView?.update(author, origin: namePoint)
                nameView?.toolTip = item.nameHide
            }
            
        } else {
            
            viaAccessory?.removeFromSuperview()
            viaAccessory = nil
            
            nameView?.removeFromSuperview()
            nameView = nil
            
            adminBadge?.removeFromSuperview()
            adminBadge = nil
        }
    }
    
    override func focusAnimation(_ innerId: AnyHashable?) {
        
        if animatedView == nil {
            self.animatedView = RowAnimateView(frame:bounds)
            self.animatedView?.isEventLess = true
            rowView.addSubview(animatedView!)
            animatedView?.backgroundColor = theme.colors.focusAnimationColor
            animatedView?.layer?.opacity = 0
            
        }
        animatedView?.stableId = item?.stableId
        
        
        let animation: CABasicAnimation = makeSpringAnimation("opacity")
        
        animation.fromValue = animatedView?.layer?.presentation()?.opacity ?? 0
        animation.toValue = 0.5
        animation.autoreverses = true
        animation.isRemovedOnCompletion = true
        animation.fillMode = CAMediaTimingFillMode.forwards
        
        animation.delegate = CALayerAnimationDelegate(completion: { [weak self] completed in
            if completed {
                self?.animatedView?.removeFromSuperview()
                self?.animatedView = nil
            }
        })
        animation.isAdditive = false
        
        animatedView?.layer?.add(animation, forKey: "opacity")
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
            bubbleView.setType(image: item.bubbleImage, border: item.bubbleBorderImage, background: item.isIncoming ? item.presentation.icons.chatGradientBubble_incoming : item.presentation.icons.chatGradientBubble_outgoing)
            bubbleView.background = item.presentation.chat.bubbleBackgroundColor(item.isIncoming, item.hasBubble)
           // updateBackground(animated: animated, item: item)
        } else {
            bubbleView.setType(image: nil, border: nil, background: item.isIncoming ? item.presentation.icons.chatGradientBubble_incoming : item.presentation.icons.chatGradientBubble_outgoing)
        }
    }
    
    func animateInStateView() {
        rightView.layer?.animateAlpha(from: 0, to: 1.0, duration: 0.15)
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
            fillReplyIfNeeded(item.replyModel, item)
            fillName(item)
            fillForward(item)
            fillPhoto(item)
            fillCaption(item)
            fillReplyMarkup(item)
            fillShareControl(item)
            fillScamButton(item)
            fillScamForwardButton(item)
            item.chatInteraction.add(observer: self)
            
            updateSelectingState(selectingMode:item.chatInteraction.presentation.selectionState != nil, item: item, needUpdateColors: false)
        }
        super.set(item: item, animated: animated)
        rowView.needsDisplay = true
        needsLayout = true
    }

    open override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self.contentView
    }
    
    override func doubleClick(in location: NSPoint) {
        if let item = self.item as? ChatRowItem, item.chatInteraction.presentation.state == .normal {
            if self.hitTest(location) == nil || self.hitTest(location) == self || !clickInContent(point: location) || self.hitTest(location) == rowView || self.hitTest(location) == bubbleView || self.hitTest(location) == replyView {
                if let avatar = avatar {
                    if NSPointInRect(location, avatar.frame) {
                        return
                    }
                }
                if NSPointInRect(location, bubbleFrame), item.isBubbled {
                    return
                }
                if let message = item.message, canReplyMessage(message, peerId: item.chatInteraction.peerId) {
                    item.chatInteraction.setupReplyMessage(item.message?.id)
                }
            }
        }
    }
    
    func toggleSelected(_ select: Bool, in point: NSPoint) {
        guard let item = item as? ChatRowItem else { return }
        
        item.chatInteraction.withToggledSelectedMessage({ current in
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
        if hitTestView == nil || hitTestView == self || hitTestView == replyView || hitTestView?.isDescendant(of: contentView) == true || hitTestView == rowView || hitTestView == self.animatedView {
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
            case .previewMedia:
                result = false
            }
            if result {
                focusAnimation(nil)
            } else {
             //   NSSound.beep()
            }
        }
        
    }
    
    func previewMediaIfPossible() -> Bool {
        return false
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
    
    
    // swiping methods
    
    private var swipingRightView: View = View()

    private var animateOnceAfterDelta: Bool = true

    var additionalRevealDelta: CGFloat {
        return 0
    }
    
    var containerX: CGFloat {
        return rowView.frame.minX
    }
    var width: CGFloat {
        return rowView.frame.width
    }
    
    var rightRevealWidth: CGFloat {
        return 40
    }
    
    var leftRevealWidth: CGFloat {
        return 0
    }
    
    var endRevealState: SwipeDirection?
    
    func initRevealState() {
        swipingRightView.removeAllSubviews()
        swipingRightView.setFrameSize(rightRevealWidth, frame.height)

        
        guard let item = item as? ChatRowItem else {return}
        
        let control = ImageButton()
        control.disableActions()
        
        
        if item.isBubbled && item.presentation.backgroundMode.hasWallpapaer {
            control.set(image: item.presentation.icons.chatSwipeReplyWallpaper, for: .Normal)
            _ = control.sizeToFit()
            control.setFrameSize(NSMakeSize(control.frame.width + 10, control.frame.height + 10))
            control.background = item.presentation.colors.background
            control.layer?.cornerRadius = control.frame.height / 2
        } else {
            control.set(image: item.presentation.icons.chatSwipeReply, for: .Normal)
            _ = control.sizeToFit()
            control.background = .clear
        }
        swipingRightView.addSubview(control)
        
        control.centerY()
        
    }
    
    func moveReveal(delta: CGFloat) {
        if swipingRightView.subviews.isEmpty {
            initRevealState()
        }
        
        let delta = delta - additionalRevealDelta

        
        rowView.setFrameOrigin(NSMakePoint(delta, rowView.frame.minY))
        swipingRightView.change(pos: NSMakePoint(frame.width + delta, swipingRightView.frame.minY), animated: false)
        
        swipingRightView.change(size: NSMakeSize(max(rightRevealWidth, -delta), swipingRightView.frame.height), animated: false)

        
        
        let subviews = swipingRightView.subviews
        let action = subviews[0]
        action.centerY()
        
        if swipingRightView.frame.width > 100 {
            if animateOnceAfterDelta {
                animateOnceAfterDelta = false
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
                action.layer?.animatePosition(from: NSMakePoint((swipingRightView.frame.width - action.frame.width), 0), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
            }
            action.setFrameOrigin(NSMakePoint(0, action.frame.minY))
        } else {
            if !animateOnceAfterDelta {
                animateOnceAfterDelta = true
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
                action.layer?.animatePosition(from: NSMakePoint(-(swipingRightView.frame.width), 0), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
            }
            action.setFrameOrigin(NSMakePoint(max(swipingRightView.frame.width, 0), action.frame.minY))
        }
        
    }
    
    func completeReveal(direction: SwipeDirection) {
        
        if swipingRightView.subviews.isEmpty {
            initRevealState()
        }
        
        CATransaction.begin()
        
        let updateRightSubviews:(Bool) -> Void = { [weak self] animated in
            guard let `self` = self else {return}
            let subviews = self.swipingRightView.subviews
            subviews[0]._change(pos: NSMakePoint(0, subviews[0].frame.minY), animated: animated, completion: { [weak self] completed in
                self?.swipingRightView.removeAllSubviews()
            })
        }
        
        let failed:(@escaping(Bool)->Void)->Void = { [weak self] completion in
            guard let `self` = self else {return}
            self.rowView.change(pos: NSMakePoint(0, self.rowView.frame.minY), animated: true)
            self.swipingRightView.change(pos: NSMakePoint(self.frame.width, self.swipingRightView.frame.minY), animated: true, completion: completion)
            updateRightSubviews(true)
            self.endRevealState = nil
        }
        
        
        
        
        switch direction {
        case .left:
            failed({_ in})
        case .right:
            let invokeRightAction = swipingRightView.frame.width > 100
            if invokeRightAction {
                _ = (item as? ChatRowItem)?.replyAction()
            }
            failed({ completed in })
        default:
            self.endRevealState = nil
            failed({_ in})
        }
        
        CATransaction.commit()
    }
    
    
    override var interactableView: NSView {
        return self.rightView
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
    }
    
}
