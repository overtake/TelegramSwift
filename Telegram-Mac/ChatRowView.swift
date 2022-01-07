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

import Postbox
import SwiftSignalKit



class ChatRowView: TableRowView, Notifable, MultipleSelectable, ViewDisplayDelegate, RevealTableView {
    
    struct CaptionView {
        let id: UInt32
        let view: TextView
    }
   
    
    var header: String? {
        if let item = item as? ChatRowItem, let message = item.message, let peer = coreMessageMainPeer(message) {
            if !peer.isChannel, let date = item.fullDate, let name = item.authorText?.attributedString.string {
                return "\(name), [\(date)]:"
            }
        }
        return nil
    }


    private var avatar:AvatarControl?
    private(set) var contentView:View = View()
    private var replyView:ChatAccessoryView?
    private var replyMarkupView:View?
    private(set) var forwardName:TextView?
    private(set) var captionViews: [CaptionView] = []
    private var shareView:ImageButton?
    private var reactionsView:ChatReactionsView?
    private var channelCommentsBubbleControl: ChannelCommentsBubbleControl?
    private var channelCommentsBubbleSmallControl: ChannelCommentsSmallControl?
    private var channelCommentsControl: ChannelCommentsControl?

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
    
    private var psaButton: ImageButton? = nil
    
    private var hasBeenLayout: Bool = false

    let rowView: View
    
    var photoView: NSView? {
        return self.avatar
    }

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
            updateBackground(animated: false, item: self.item)
        }
    }
    
    func updateBackground(animated: Bool, item: TableRowItem?, rotated: Bool = false, clean: Bool = false) -> Void {
        
        guard let item = item as? ChatRowItem else {
            return
        }
        
        let gradientRect = item.chatInteraction.getGradientOffsetRect()
        let size = NSMakeSize(gradientRect.width, gradientRect.height + 60)
        
        let inset = size.height - gradientRect.minY + (frame.height - self.bubbleView.frame.maxY) - 30
        let animated = animated && visibleRect.height > 0 && !clean && self.layer?.animation(forKey: "position") == nil
        let rect = self.frame
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        bubbleView.update(rect: rect.offsetBy(dx: self.bubbleView.frame.minX, dy: inset), within: size, transition: transition, rotated: rotated)
    }
      
    var selectableTextViews: [TextView] {
        return captionViews.map { $0.view }
    }
    
    func clickInContent(point: NSPoint) -> Bool {
        guard let item = item as? ChatRowItem, let layout = item.captionLayouts.first?.layout, let captionView = captionViews.first else {return true}
        let point = captionView.view.convert(point, from: self)
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
        
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if (value.selectionState != oldValue.selectionState) {
                updateSelectingState(!NSIsEmptyRect(visibleRect), selectingMode:value.selectionState != nil, item: self.item as? ChatRowItem, needUpdateColors: true)
                
                updateLayout(size: frame.size, transition: transition)
            } else if let item = item as? ChatRowItem, let message = item.message {
                if value.selectionState?.selectedIds.contains(message.id) != oldValue.selectionState?.selectedIds.contains(message.id) {
                    if let selectionState = value.selectionState {
                        selectingView?.set(selected: selectionState.selectedIds.contains(message.id), animated: !NSIsEmptyRect(visibleRect))
                        updateColors()
                        updateLayout(size: frame.size, transition: transition)
                    }
                }
            }
        }

    }
    
    
    func updateSelectingState(_ animated:Bool = false, selectingMode:Bool, item: ChatRowItem?, needUpdateColors: Bool) {
        
        let selectingMode = selectingMode && item?.chatInteraction.mode.threadId != item?.message?.id
        if let item = item {
            updateMouse()
            if selectingMode {
                if selectingView == nil {
                    selectingView = SelectingControl(unselectedImage: item.presentation.chat_toggle_unselected, selectedImage: item.presentation.chat_toggle_selected, selected: item.isSelectedMessage)
                    selectingView?.setFrameOrigin(NSMakePoint(frame.width, selectingPoint(item).y))
                    super.addSubview(selectingView!)
                    
                    if animated {
                        selectingView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
            } else {
                if let view = self.selectingView {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    view.layer?.animatePosition(from: view.frame.origin, to: view.frame.origin.offsetBy(dx: 20, dy: 0), removeOnCompletion: false)
                    self.selectingView = nil
                }
            }
            updateSelectionViewAfterUpdateState(item: item, animated: animated)
            if needUpdateColors {
                renderLayoutType(item, animated: animated)
                updateColors()
            }
            if item.chatInteraction.presentation.state == .selecting || item.disableInteractions {
                disableHierarchyInteraction()
            } else {
               restoreHierarchyInteraction()
            }
            self.channelCommentsControl?.isEnabled = !item.isFailed && !item.isUnsent && item.chatInteraction.presentation.state != .selecting
            self.channelCommentsBubbleSmallControl?.isEnabled = !item.isFailed && !item.isUnsent && item.chatInteraction.presentation.state != .selecting
            self.channelCommentsBubbleControl?.isEnabled = !item.isFailed && !item.isUnsent && item.chatInteraction.presentation.state != .selecting
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
            return item.presentation.chat.backgroundColor(item.isIncoming, item.renderType == .bubble)
        } else {
            return backdorColor//backdorColor
        }
    }

    
    override func updateColors() -> Void {
        super.updateColors()
        
        guard let item = item as? ChatRowItem else {return}

        rowView.backgroundColor = backdorColor
        
        if item.shouldBlurService {
            rightView.blurBackground = item.presentation.blurServiceColor
            rightView.layer?.cornerRadius = item.rightSize.height / 2
        } else {
            rightView.blurBackground = nil
            rightView.layer?.cornerRadius = item.rightSize.height / 2
            rightView.backgroundColor = item.isStateOverlayLayout ? item.presentation.chatServiceItemColor : contentColor
        }

        contentView.backgroundColor = .clear
        if let replyModel = item.replyModel {
            replyModel.backgroundColor = item.hasBubble ? contentColor : item.isBubbled ? item.presentation.colors.bubbleBackground_incoming : contentColor
        }
        nameView?.backgroundColor = contentColor
        forwardName?.backgroundColor = contentColor
        for captionView in captionViews {
            captionView.view.backgroundColor = contentColor
        }
        replyMarkupView?.backgroundColor = backdorColor
        bubbleView.background = item.presentation.chat.bubbleBackgroundColor(item.isIncoming, item.hasBubble)

        if let control = channelCommentsControl {
            control.set(background: contentColor, for: .Normal)
        }
        if let control = channelCommentsBubbleControl {
            control.set(background: .clear, for: .Normal)
            control.set(background: item.presentation.colors.accent.withAlphaComponent(0.08), for: .Hover)
            control.set(background: item.presentation.colors.accent.withAlphaComponent(0.16), for: .Highlight)
        }

        if let control = channelCommentsBubbleSmallControl {
            control.set(background: item.presentation.chatServiceItemColor, for: .Normal)
            if item.presentation.shouldBlurService {
                control.set(background: .clear, for: .Normal)
                control.blurBackground = item.presentation.blurServiceColor
            } else {
                control.set(background: item.presentation.chatServiceItemColor, for: .Normal)
                control.blurBackground = nil
            }
        }

        
        for view in contentView.subviews {
            if let view = view as? View, !view.isDynamicColorUpdateLocked {
                view.backgroundColor = contentColor
            }
        }
    }
    
    private var mouseDownPoint: NSPoint = .zero
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        let current = convert(event.locationInWindow, from: nil)
        mouseDragged = mouseDragged || abs(mouseDownPoint.x - current.x) > 5 || abs(mouseDownPoint.y - current.y) > 5
        
    }
    
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        mouseDragged = false
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if let item = item as? ChatRowItem, !item.chatInteraction.isLogInteraction && !item.chatInteraction.disableSelectAbility, !item.sending, mouseInside(), !mouseDragged {
            if item.chatInteraction.presentation.state != .selecting {
                let location = self.convert(event.locationInWindow, from: nil)
                if NSPointInRect(location, rightView.frame) {
                    if item.isFailed,  let messageId = item.message?.id {
                        item.resendFailed(messageId)
                    } else {
                        forceSelectItem(item, onRightClick: true)
                    }
                }
            }
        }
    }
    
    func forceSelectItem(_ item: ChatRowItem, onRightClick: Bool) {
        if let message = item.message, item.isSelectable {
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
        updateColors()
        super.onCloseContextMenu()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {

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
            
            //draw separator
            if let fwdType = item.forwardType, !item.isBubbled, layer == rowView.layer {
                
                let color: NSColor
                if item.isPsa {
                    color = item.presentation.colors.greenUI
                } else {
                    color = item.presentation.colors.link
                }
                ctx.setFillColor(color.cgColor)
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
        if let shareView = self.shareView, let item = item as? ChatRowItem {
            shareView.change(opacity: item.chatInteraction.presentation.state != .selecting && mouseInside() ? 1.0 : 0.0, animated: true)
        }
        if let commentsView = self.channelCommentsBubbleSmallControl, let item = item as? ChatRowItem {
            commentsView.change(opacity: item.chatInteraction.presentation.state != .selecting && mouseInside() ? 1.0 : 0.0, animated: true)
        }
    }
    
    
    
    override func addSubview(_ view: NSView) {
        self.contentView.addSubview(view)
    }
    
    func fillReply(_ item:ChatRowItem, animated: Bool) -> Void {
        
        if let reply = item.replyModel {
            if replyView == nil {
                replyView = ChatAccessoryView(frame: replyFrame(item))
                rowView.addSubview(replyView!)
            }
            if reply.isSideAccessory {
                replyView?.layer?.cornerRadius = .cornerRadius
            } else {
                replyView?.layer?.cornerRadius = 0
            }
            replyView?.removeAllHandlers()
            replyView?.set(handler: { [weak item] _ in
                item?.chatInteraction.focusInputField()
                item?.openReplyMessage()
            }, for: .Click)
            
            reply.view = replyView
        } else {
            if let view = replyView {
                performSubviewRemoval(view, animated: animated, scale: true)
                replyView = nil
            }
        }
        
    }
    
    func bubbleFrame(_ item: ChatRowItem) -> NSRect {
        var bubbleFrame = item.bubbleFrame
        bubbleFrame = NSMakeRect(item.isIncoming ? bubbleFrame.minX : frame.width - bubbleFrame.width - item.leftInset, bubbleFrame.minY, bubbleFrame.width, bubbleFrame.height)
        
        if item.chatInteraction.mode.isThreadMode, item.chatInteraction.mode.threadId == item.message?.id {
            bubbleFrame.origin.x = focus(NSMakeSize(bubbleFrame.size.width + 8, bubbleFrame.size.height)).minX
        }
        
        return bubbleFrame
    }
    
    func rightFrame(_ item: ChatRowItem) -> NSRect {
        
        let rightSize = item.rightSize
        let bubbleFrame = self.bubbleFrame(item)
        let contentFrame = self.contentFrame(item)
        var rect = NSMakeRect(frame.width - rightSize.width - item.rightInset, item.defaultContentTopOffset, rightSize.width, rightSize.height)
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
            if let item = item as? ChatMessageItem {
                if item.containsBigEmoji {
                    rect.origin.y = bubbleFrame.maxY - rightSize.height
                } else if item.actionButtonText != nil {
                    if item.webpageLayout == nil {
                        rect.origin.y = bubbleFrame.maxY - rightSize.height - item.actionButtonHeight - 6;
                    }
                }
            }
            
            if item.hasBubble, let _ = item.commentsBubbleData {
                rect.origin.y -= ChatRowItem.channelCommentsBubbleHeight
            }
            
        }
        
        return rect
    }
    
    func avatarFrame(_ item: ChatRowItem) -> NSRect {
        var rect = NSMakeRect(item.leftInset, 6, 36, 36)

        if item.isBubbled {
            rect.origin.y = frame.height - 36
        }
        
        return rect
    }
    
    func captionFrame(_ item: ChatRowItem, caption: ChatRowItem.RowCaption) -> NSRect {
        let contentFrame = self.contentFrame(item)
        return NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset + caption.offset.y, caption.layout.layoutSize.width, caption.layout.layoutSize.height)
    }
    
    func replyMarkupFrame(_ item: ChatRowItem) -> NSRect {
        guard let replyMarkup = item.replyMarkupModel else {return NSZeroRect}

        let contentFrame = self.contentFrame(item)
        
        var frame = NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultReplyMarkupInset, replyMarkup.size.width, replyMarkup.size.height)
        
        if let captionLayout = item.captionLayouts.first?.layout {
            frame.origin.y += captionLayout.layoutSize.height + item.defaultContentInnerInset
        }
        
        let bubbleFrame = self.bubbleFrame(item)
        
        if item.hasBubble {
            frame.origin.y = bubbleFrame.maxY + item.defaultReplyMarkupInset
            frame.origin.x = bubbleFrame.minX + (item.isIncoming ? item.additionBubbleInset : 0)
        } else if item.isBubbled {
            frame.origin.y = bubbleFrame.maxY
        }
        
        return frame
    }
    
    func replyFrame(_ item: ChatRowItem) -> NSRect {
        guard let reply = item.replyModel else {return NSZeroRect}
        
        let contentFrame = self.contentFrame(item)
        
        var frame: NSRect = NSMakeRect(contentFrame.minX + item.elementsContentInset, item.replyOffset, reply.size.width, reply.size.height)
        if item.isBubbled, !item.hasBubble {
            if item.isIncoming {
                frame.origin.x = contentFrame.maxX + 10
            } else {
                frame.origin.x = contentFrame.minX - reply.size.width - 10
            }
            if item.isSharable || item.hasSource || item.commentsBubbleDataOverlay != nil {
                if item.isIncoming {
                    frame.origin.x += 46
                } else {
                    frame.origin.x -= 46
                }
            }
        }
        return frame
    }
    
    func viaAccesoryPoint(_ item: ChatRowItem) -> NSPoint {
        guard let viaAccessory = viaAccessory else {return NSZeroPoint}
        
        if viaAccessory.superview == replyView {
            return NSMakePoint(5, 0)
        }
        
        let contentFrame = self.contentFrame(item)
        
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
    
    func namePoint(_ item: ChatRowItem) -> NSPoint {
    
        let contentFrame = self.contentFrame(item)
        
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
    
    func scamPoint(_ item: ChatRowItem) -> NSPoint {
        guard let authorText = item.authorText else {return NSZeroPoint}
        
        var point = self.namePoint(item)
        point.x += authorText.layoutSize.width + 3
        point.y += 1
        return point
    }
    
    func psaPoint(_ item: ChatRowItem) -> NSPoint {
        var point: NSPoint = .zero
        if item.isBubbled, let _ = item.forwardNameLayout {
            point.x = item.bubbleFrame.width - 20
            point.y = self.forwardNamePoint(item).y
        } else if item.entry.renderType == .list, let name = item.authorText {
            point = self.namePoint(item)
            point.x += name.layoutSize.width
            point.y -= 6
        }
       
       // point.y -= 7
        return point
    }
    
    func scamForwardPoint(_ item: ChatRowItem) -> NSPoint {
        guard let forwardName = item.forwardNameLayout else {return NSZeroPoint}
        
        var point = self.forwardNamePoint(item)
        point.x += forwardName.layoutSize.width + 3
        //point.y += 1
        return point
    }
    
    func adminBadgePoint(_ item: ChatRowItem) -> NSPoint {
        guard let adminBadge = item.adminBadge, let authorText = item.authorText else {return NSZeroPoint}
        let bubbleFrame = self.bubbleFrame(item)
        let namePoint = self.namePoint(item)
        var point = NSMakePoint( item.isBubbled ? bubbleFrame.maxX - item.bubbleContentInset - adminBadge.layoutSize.width : namePoint.x + authorText.layoutSize.width, item.defaultContentTopOffset + 1)
        if item.isBubbled {
            point.y -= item.topInset
        }
        return point
    }
    
    func selectingPoint(_ item: ChatRowItem) -> NSPoint {
        
        var point = NSZeroPoint
        
        
        let rightFrame = self.rightFrame(item)
        
        if let selectingView = selectingView {
            if item.isBubbled {
                let f = focus(selectingView.frame.size)
                point.y = f.minY
                point.x = frame.width - selectingView.frame.width - 15
            } else {
                point = NSMakePoint(rightFrame.maxX + 4, item.defaultContentTopOffset - 3)
            }
        }
        return point
    }
    
    func contentFrame(_ item: ChatRowItem) -> NSRect {
        var rect = NSMakeRect(item.contentOffset.x, item.contentOffset.y, item.contentSize.width, item.contentSize.height)
        if item.isBubbled {
            let bubbleFrame = self.bubbleFrame(item)
            if !item.isIncoming {
                rect.origin.x = bubbleFrame.minX + item.bubbleContentInset
            } else {
                rect.origin.x = bubbleFrame.minX + item.bubbleContentInset + item.additionBubbleInset
            }
            
        }
        return rect
    }
    
    func contentFrameModifier(_ item: ChatRowItem) -> NSRect {
        return self.contentFrame(item)
    }
    
    func rowPoint(_ item: ChatRowItem) -> NSPoint {
        
        if item.isBubbled {
            return NSMakePoint((self.selectingView != nil && !item.isIncoming ? -20 : 0), 0)
        } else {
            return NSMakePoint(0, 0)
        }
    }
    
    func forwardNamePoint(_ item: ChatRowItem) -> NSPoint {

        var point = item.forwardNameInset
        
        if item.isBubbled && item.hasBubble {
            let bubbleFrame = self.bubbleFrame(item)
            point.x = bubbleFrame.minX + (item.isIncoming ? item.bubbleContentInset + item.additionBubbleInset : item.bubbleContentInset)
        } else if item.isBubbled, let forwardAccessory = forwardAccessory {
            let contentFrame = self.contentFrame(item)
            point.x = item.isIncoming ? contentFrame.maxX : contentFrame.minX - forwardAccessory.frame.width
        }
        
        return point
    }
    
    override func layout() {
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func shareViewPoint(_ item: ChatRowItem) -> NSPoint {
        guard let shareView = self.shareView else {
            return .zero
        }
        var point: NSPoint
        if item.isBubbled {
            let bubbleFrame = self.bubbleFrame(item)
            let rightFrame = self.rightFrame(item)
            point = NSMakePoint(item.isIncoming ? max(bubbleFrame.maxX + 10, rightFrame.maxX + 10) : bubbleFrame.minX - shareView.frame.width - 10, bubbleFrame.maxY - (shareView.frame.height))
        } else {
            let rightFrame = self.rightFrame(item)
            point = NSMakePoint(frame.width - 20.0 - shareView.frame.width, rightFrame.maxY)
        }
        return point
    }
    

    
    
    
    func fillForward(_ item:ChatRowItem, animated: Bool) -> Void {
        if let forwardNameLayout = item.forwardNameLayout {
            if item.isBubbled && !item.hasBubble {
                if let view = forwardName {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    forwardName = nil
                }
                
                if forwardAccessory == nil {
                    forwardAccessory = ChatBubbleAccessoryForward(frame: CGRect(origin: forwardNamePoint(item), size: forwardNameLayout.layoutSize))
                    rowView.addSubview(forwardAccessory!)
                }
                forwardAccessory?.updateText(layout: forwardNameLayout)
                
            } else {
                if let view = forwardAccessory {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    forwardAccessory = nil
                }
                if forwardName == nil {
                    forwardName = TextView(frame: CGRect(origin: forwardNamePoint(item), size: forwardNameLayout.layoutSize))
                    forwardName?.isSelectable = false
                    rowView.addSubview(forwardName!)
                }
                forwardName?.update(forwardNameLayout)
            }
            
        } else {
            if let view = forwardName {
                performSubviewRemoval(view, animated: animated, scale: true)
                forwardName = nil
            }
            if let view = forwardAccessory {
                performSubviewRemoval(view, animated: animated, scale: true)
                forwardAccessory = nil
            }
        }
    }
    
    static func makePhotoView(_ item: ChatRowItem) -> NSView {
        let avatar = AvatarControl(font: .avatar(.text))
        avatar.setFrameSize(36,36)
        if let peer = item.peer {
            avatar.setPeer(account: item.context.account, peer: peer, message: item.message)
        }
        return avatar
    }
    
    func fillPhoto(_ item:ChatRowItem, animated: Bool) -> Void {
        if item.hasPhoto, let peer = item.peer, item.renderType != .bubble {
            
            if avatar == nil {
                avatar = AvatarControl(font: .avatar(.text))
                avatar?.frame = avatarFrame(item)
                rowView.addSubview(avatar!)
            }
            avatar?.removeAllHandlers()
            avatar?.set(handler: { [weak item] control in
                item?.openInfo()
            }, for: .Click)
            avatar?.toolTip = item.nameHide
            self.avatar?.setPeer(account: item.context.account, peer: peer, message: item.message)
            
        } else {
            if let view = avatar {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.avatar = nil
            }
        }
    }
    
    func fillPsaButton(_ item: ChatRowItem, animated: Bool) -> Void {
        if let text = item.psaButton, item.forwardNameLayout != nil || !item.isBubbled {
            
            let icon = item.presentation.chat.channelInfoPromo(item.isIncoming, item.isBubbled, icons: theme.icons)
            
            if psaButton == nil {
                psaButton = ImageButton(frame: CGRect(origin: psaPoint(item), size: icon.backingSize))
                psaButton?.autohighlight = false
                rowView.addSubview(psaButton!)
                psaButton?.set(handler: { control in
                    tooltip(for: control, text: "", attributedText: text, interactions: globalLinkExecutor)
                }, for: .Click)
            }
            psaButton?.set(image: icon, for: .Normal)
            
        } else {
            if let view = psaButton {
                performSubviewRemoval(view, animated: animated, scale: true)
                psaButton = nil
            }
        }
    }
    
    func fillScamButton(_ item: ChatRowItem, animated: Bool) -> Void {
        if item.isScam || item.isFake, item.canFillAuthorName {
            if scamButton == nil {
                let text: String = !item.isScam ? strings().peerInfoFakeWarning : strings().peerInfoScamWarning
                scamButton = ImageButton(frame: CGRect(origin: scamPoint(item), size: item.badIcon.backingSize))
                scamButton?.autohighlight = false
                rowView.addSubview(scamButton!)
                scamButton?.set(handler: { control in
                    tooltip(for: control, text: text)
                }, for: .Click)
            }
            scamButton?.set(image: item.badIcon, for: .Normal)
            
        } else {
            if let view = scamButton {
                performSubviewRemoval(view, animated: animated, scale: true)
                scamButton = nil
            }
        }
    }
    
    func fillScamForwardButton(_ item: ChatRowItem, animated: Bool) -> Void {
        if item.isForwardScam || item.isForwardFake {
            if scamForwardButton == nil {
                let text: String = !item.isForwardScam ? strings().peerInfoFakeWarning : strings().peerInfoScamWarning
                scamForwardButton = ImageButton(frame: CGRect(origin: scamForwardPoint(item), size: item.forwardBadIcon.backingSize))
                scamForwardButton?.autohighlight = false
                rowView.addSubview(scamForwardButton!)
                scamForwardButton?.set(handler: { control in
                    tooltip(for: control, text: text)
                }, for: .Click)
            }
            scamForwardButton?.set(image: item.forwardBadIcon, for: .Normal)
            
        } else {
            if let view = scamForwardButton {
                performSubviewRemoval(view, animated: animated, scale: true)
                scamForwardButton = nil
            }
        }
    }
    
    func fillCaption(_ item:ChatRowItem, animated: Bool) -> Void {
        
        var removeIndexes:[Int] = []
        for (i, view) in captionViews.enumerated() {
            if !item.captionLayouts.contains(where: { $0.id == view.id}) {
                let captionView = view.view
                if animated {
                    captionView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak captionView] _ in
                        captionView?.removeFromSuperview()
                    })
                } else {
                    captionView.removeFromSuperview()
                }
                removeIndexes.append(i)
            }
        }
        
        for index in removeIndexes.reversed() {
            captionViews.remove(at: index)
        }
        
        for (i, layout) in item.captionLayouts.enumerated() {
            var view = captionViews.first(where: { $0.id == layout.id })
            if view == nil {
                view = CaptionView(id: layout.id, view: TextView())
                rowView.addSubview(view!.view, positioned: .below, relativeTo: rightView)
                view?.view.frame = captionFrame(item, caption: layout)
                captionViews.append(view!)
            }
            if let index = captionViews.firstIndex(where: { $0.id == layout.id }), index != i {
                captionViews.move(at: index, to: i)
            }
            view?.view.update(layout.layout)
        }
    }
    
    func reactionsRect(_ item: ChatRowItem) -> CGRect {
        guard let reactionsLayout = item.reactionsLayout else {
            return .zero
        }
        let contentFrame = self.contentFrame(item)
        
        var frame = NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultReplyMarkupInset, reactionsLayout.size.width, reactionsLayout.size.height)
        
        if let captionLayout = item.captionLayouts.first?.layout {
            frame.origin.y += captionLayout.layoutSize.height + item.defaultContentInnerInset
        }
        
        let bubbleFrame = self.bubbleFrame(item)
        
        if item.hasBubble {
            if item.isBubbleFullFilled, item.captionLayouts.isEmpty {
                frame.origin.y = bubbleFrame.maxY + item.defaultReactionsInset
                frame.origin.x = bubbleFrame.minX + (item.isIncoming ? item.additionBubbleInset : 0)
            } else {
                if item.captionLayouts.isEmpty {
                    frame.origin.y = contentFrame.maxY + item.defaultReactionsInset
                } else if let last = item.captionLayouts.last {
                    frame.origin.y = max(contentFrame.maxY, captionFrame(item, caption: last).maxY) + item.defaultReactionsInset
                }
                if !item.isBubbleFullFilled {
                    frame.origin.x = contentFrame.minX
                } else {
                    frame.origin.x = contentFrame.minX + item.defaultReactionsInset + item.additionBubbleInset
                }
                
            }
           
        } else if item.isBubbled {
            if let item = item as? ChatMessageItem {
                if item.containsBigEmoji {
                    frame.origin.y += rightFrame(item).height
                } 
            }
        }
        if reactionsLayout.presentation.isOutOfBounds, !item.isIncoming {
            frame.origin.x = contentFrame.maxX - reactionsLayout.size.width
        }
        return frame
    }
    
    func channelCommentsBubbleFrame(_ item: ChatRowItem) -> CGRect {
        guard let _ = item.commentsBubbleData else {
            return .zero
        }
        return NSMakeRect(0, 0, item.bubbleFrame.width, ChatRowItem.channelCommentsBubbleHeight)
    }
    func channelCommentsOverlayFrame(_ item: ChatRowItem) -> CGRect {
        guard let commentsData = item.commentsBubbleDataOverlay else {
            return .zero
        }
        let size = commentsData.size(false, true)
        let rightFrame = self.rightFrame(item)
        var rect = NSMakeRect(rightFrame.maxX + 19, rightFrame.minY - size.height - 15, size.width, size.height)
        if item.isInstantVideo {
            rect = NSMakeRect(rightFrame.maxX + 12, rightFrame.minY - size.height - 23, size.width, size.height)
        } else if let item = item as? ChatMessageItem, item.containsBigEmoji {
            rect.origin.x -= 8
            rect.origin.y -= 8
        }
        return rect
    }
    func channelCommentsFrame(_ item: ChatRowItem) -> CGRect {
        guard let commentsData = item.commentsData else {
            return .zero
        }
        let size = commentsData.size(false)
        let rightFrame = self.rightFrame(item)
        return CGRect(origin: CGPoint(x: rightFrame.minX - size.width - 4, y: rightFrame.minY - 1), size: size)
    }
    
    func fillChannelComments(_ item: ChatRowItem, animated: Bool) {
        if let commentsBubbleData = item.commentsBubbleData {
            let current: ChannelCommentsBubbleControl
            if let channelCommentsBubbleControl = self.channelCommentsBubbleControl {
                current = channelCommentsBubbleControl
            } else {
                current = ChannelCommentsBubbleControl(frame: NSMakeRect(0, 0, item.bubbleFrame.width, ChatRowItem.channelCommentsBubbleHeight))
                
                current.set(background: .clear, for: .Normal)
                current.set(background: item.presentation.colors.accent.withAlphaComponent(0.08), for: .Hover)
                current.set(background: item.presentation.colors.accent.withAlphaComponent(0.16), for: .Highlight)
                
                self.channelCommentsBubbleControl = current
                bubbleView.addSubview(current)
            }
            current.update(data: commentsBubbleData, size: channelCommentsBubbleFrame(item).size, animated: animated)
        } else {
            if let channelCommentsBubbleControl = self.channelCommentsBubbleControl {
                self.channelCommentsBubbleControl = nil
                if animated {
                    channelCommentsBubbleControl.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak channelCommentsBubbleControl] _ in
                        channelCommentsBubbleControl?.removeFromSuperview()
                    })
                } else {
                    channelCommentsBubbleControl.removeFromSuperview()
                }
            }
        }
        if let data = item.commentsBubbleDataOverlay {
            let current: ChannelCommentsSmallControl
            if let channelCommentsBubbleSmallControl = self.channelCommentsBubbleSmallControl {
                current = channelCommentsBubbleSmallControl
            } else {
                current = ChannelCommentsSmallControl(frame: CGRect(origin: .zero, size: data.size(false, true)))
                current.set(background: item.presentation.chatServiceItemColor, for: .Normal)
                
                current.change(opacity: 0, animated: animated)
                self.channelCommentsBubbleSmallControl = current
                rowView.addSubview(current)
            }
            if item.presentation.shouldBlurService {
                current.set(background: .clear, for: .Normal)
                current.blurBackground = item.presentation.blurServiceColor
            } else {
                current.set(background: contentColor, for: .Normal)
                current.blurBackground = nil
            }
            current.scaleOnClick = true
            current.update(data: data, size: channelCommentsOverlayFrame(item).size, animated: animated)
            current.change(pos: channelCommentsOverlayFrame(item).origin, animated: animated)
        } else {
            if let channelCommentsBubbleSmallControl = self.channelCommentsBubbleSmallControl {
                self.channelCommentsBubbleSmallControl = nil
                if animated {
                    channelCommentsBubbleSmallControl.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak channelCommentsBubbleSmallControl] _ in
                        channelCommentsBubbleSmallControl?.removeFromSuperview()
                    })
                } else {
                    channelCommentsBubbleSmallControl.removeFromSuperview()
                }
            }
        }
        if let commentsData = item.commentsData {
            let current: ChannelCommentsControl
            if let channelCommentsControl = self.channelCommentsControl {
                current = channelCommentsControl
            } else {
                current = ChannelCommentsControl(frame: NSMakeRect(0, 0, commentsData.size(false).width, ChatRowItem.channelCommentsHeight))
                current.set(background: contentColor, for: .Normal)
                self.channelCommentsControl = current
                rowView.addSubview(current)
            }
            current.update(data: commentsData, size: channelCommentsFrame(item).size, animated: animated)
        } else {
            if let channelCommentsControl = self.channelCommentsControl {
                self.channelCommentsControl = nil
                if animated {
                    channelCommentsControl.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak channelCommentsControl] _ in
                        channelCommentsControl?.removeFromSuperview()
                    })
                } else {
                    channelCommentsControl.removeFromSuperview()
                }
            }
        }
        self.channelCommentsControl?.isEnabled = !item.isFailed && !item.isUnsent
        self.channelCommentsBubbleControl?.isEnabled = !item.isFailed && !item.isUnsent
        self.channelCommentsBubbleSmallControl?.isEnabled = !item.isFailed && !item.isUnsent

    }
    
    func fillShareView(_ item:ChatRowItem, animated: Bool) -> Void {
        if item.shareVisible || item.hasSource {
            if shareView == nil {
                shareView = ImageButton(frame: CGRect(origin: shareViewPoint(item), size: NSMakeSize(29, 29)))
                shareView?.disableActions()
                shareView?.scaleOnClick = true
                shareView?.change(opacity: 0, animated: false)
                rowView.addSubview(shareView!)
            }
            
            guard let control = shareView else {return}
            control.autohighlight = false
            
            if item.presentation.shouldBlurService  {
                
                control.set(image: item.hasSource ? item.presentation.chat.chat_goto_message_bubble(theme: item.presentation) : item.presentation.chat.chat_share_bubble(theme: item.presentation), for: .Normal)
                
                control.set(cornerRadius: .half, for: .Normal)
                
                control.blurBackground = item.presentation.blurServiceColor
                control.background = .clear
            } else {
                if item.presentation.backgroundMode.hasWallpaper {
                    control.set(image: item.hasSource ? item.presentation.chat.chat_goto_message_bubble(theme: item.presentation) : item.presentation.chat.chat_share_bubble(theme: item.presentation), for: .Normal)
                } else {
                    control.set(image: item.hasSource ? item.presentation.icons.chat_goto_message : item.presentation.icons.chat_share_message, for: .Normal)
                }
                control.backgroundColor = item.presentation.chatServiceItemColor

                control.blurBackground = nil
                

            }
            let size = NSMakeSize(29, 29)
            control.setFrameSize(NSMakeSize(floorToScreenPixels(backingScaleFactor, (size.width + 4) * 1.05), floorToScreenPixels(backingScaleFactor, (size.height + 4) * 1.05)))
            control.set(cornerRadius: .half, for: .Normal)

            control.removeAllHandlers()
            control.set(handler: { [ weak item] _ in
                if let item = item {
                    if item.hasSource {
                        item.gotoSourceMessage()
                    } else {
                        item.share()
                    }
                }
            }, for: .Click)
        } else {
            if let view = shareView {
                performSubviewRemoval(view, animated: animated, scale: true)
                shareView = nil
            }
        }
    }
    
    func fillReactions(_ item: ChatRowItem, animated: Bool) {
        if let reactionsLayout = item.reactionsLayout, reactionsLayout.mode == .full  {
            if reactionsView == nil {
                reactionsView = ChatReactionsView(frame: reactionsRect(item))
                rowView.addSubview(reactionsView!)
            }
            guard let reactionsView = reactionsView else {return}
            reactionsView.update(with: reactionsLayout, animated: animated)
        } else {
            if let view = self.reactionsView {
                self.reactionsView = nil
                performSubviewRemoval(view, animated: animated, scale: true)
            }
        }
    }
    
    func fillReplyMarkup(_ item:ChatRowItem, animated: Bool) -> Void {
        if let replyMarkup = item.replyMarkupModel {
            if replyMarkupView == nil {
                replyMarkupView = View(frame: replyMarkupFrame(item))
                rowView.addSubview(replyMarkupView!)
            }
            replyMarkup.view = replyMarkupView
            replyMarkup.redraw()
        } else {
            if let replyMarkupView = self.replyMarkupView, animated {
                self.replyMarkupView = nil
                replyMarkupView.layer?.animateScaleCenter(from: 1, to: 0.1, duration: 0.2, removeOnCompletion: false)
                replyMarkupView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak replyMarkupView] _ in
                    replyMarkupView?.removeFromSuperview()
                })
            } else {
                replyMarkupView?.removeFromSuperview()
                replyMarkupView = nil
            }
        }
    }
    
    
    
    func fillName(_ item:ChatRowItem, animated: Bool) -> Void {
        if let author = item.authorText {
            if item.isBubbled && !item.hasBubble {
                if let view = nameView {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    self.nameView = nil
                }
                if let view = adminBadge {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    self.adminBadge = nil
                }
                
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
                if let view = viaAccessory {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    self.viaAccessory = nil
                }
                
                if nameView == nil {
                    nameView = TextView(frame: CGRect(origin: namePoint(item), size: author.layoutSize))
                    nameView?.isSelectable = false
                    rowView.addSubview(nameView!)
                }
                if let adminBadge = item.adminBadge {
                    if self.adminBadge == nil {
                        self.adminBadge = TextView(frame: CGRect(origin: adminBadgePoint(item), size: adminBadge.layoutSize))
                        self.adminBadge?.isSelectable = false
                        rowView.addSubview(self.adminBadge!)
                    }
                    self.adminBadge?.update(adminBadge)
                } else {
                    if let view = adminBadge {
                        performSubviewRemoval(view, animated: animated, scale: true)
                        self.adminBadge = nil
                    }
                }
                nameView?.update(author)
                nameView?.toolTip = item.nameHide
            }
            
        } else {
            if let view = viaAccessory {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.viaAccessory = nil
            }
            if let view = nameView {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.nameView = nil
            }
            if let view = adminBadge {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.adminBadge = nil
            }
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
        } else {
            bubbleView.setType(image: nil, border: nil, background: item.isIncoming ? item.presentation.icons.chatGradientBubble_incoming : item.presentation.icons.chatGradientBubble_outgoing)
        }
    }
    
    func animateInStateView() {
        rightView.layer?.animateAlpha(from: 0, to: 1.0, duration: 0.15)
    }
    
    func shakeContentView() {
        
        guard let item = item as? ChatRowItem else { return }
        
        if bubbleView.layer?.animation(forKey: "shake") != nil {
            return
        }
        
        let translation = CAKeyframeAnimation(keyPath: "transform.translation.x");
        translation.timingFunction = CAMediaTimingFunction(name: .linear)
        translation.values = [-2, 2, -2, 2, -2, 2, -2, 2, 0]
        
        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [-0.5, -0.5, -0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 0].map {
            ( degrees: Double) -> Double in
            let radians: Double = (.pi * degrees) / 180.0
            return radians
        }
        
        let shakeGroup: CAAnimationGroup = CAAnimationGroup()
        shakeGroup.isRemovedOnCompletion = true
        shakeGroup.animations = [rotation]
        shakeGroup.timingFunction = .init(name: .easeInEaseOut)
        shakeGroup.duration = 0.5
        
        
        
        let frame = bubbleFrame(item)
        let contentFrame = self.contentFrameModifier(item)
        
        
        contentView.layer?.position = NSMakePoint(contentFrame.minX + contentFrame.width / 2, contentFrame.minY + contentFrame.height / 2)
        contentView.layer?.anchorPoint = NSMakePoint(0.5, 0.5);
        
        if item.hasBubble {
            
            struct ShakeItem {
                let view: NSView
                let rect: NSRect
                let tempRect: NSRect
            }
            var views:[NSView] = [self.rightView, self.nameView, self.scamButton, self.replyView, self.adminBadge, self.forwardName, self.scamForwardButton, self.viaAccessory].compactMap { $0 }
            views.append(contentsOf: self.captionViews.map { $0.view })
            let shakeItems = views.map { view -> ShakeItem in
                return ShakeItem(view: view, rect: view.frame, tempRect: self.bubbleView.convert(view.frame, from: view.superview))
            }
            
            for item in shakeItems {
                item.view.removeFromSuperview()
                item.view.frame = item.tempRect
                bubbleView.addSubview(item.view)
            }
            
            
            shakeGroup.delegate = CALayerAnimationDelegate(completion: { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                for item in shakeItems {
                    item.view.removeFromSuperview()
                    item.view.frame = item.rect
                    self.rowView.addSubview(item.view)
                }
            })
        }
        
        bubbleView.layer?.position = NSMakePoint(frame.minX + frame.width / 2, frame.minY + frame.height / 2)
        bubbleView.layer?.anchorPoint = NSMakePoint(0.5, 0.5);

        
        bubbleView.layer?.add(shakeGroup, forKey: "shake")
        contentView.layer?.add(shakeGroup, forKey: "shake")

        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        let previousItem = self.item as? ChatRowItem

        super.set(item: item, animated: animated)


        if let item = previousItem {
            item.chatInteraction.remove(observer: self)
        }
        guard let item = item as? ChatRowItem else {
            return
        }
        
        if self.animatedView != nil && self.animatedView?.stableId != item.stableId {
            self.animatedView?.removeFromSuperview()
            self.animatedView = nil
        }
        
        let animated = animated && item.presentation.bubbled == previousItem?.presentation.bubbled
        
        
        if previousItem?.message?.id != item.message?.id {
            updateBackground(animated: false, item: item, clean: true)
        }
        
        renderLayoutType(item, animated: animated)
        

        item.chatInteraction.add(observer: self)
        
        updateSelectingState(selectingMode:item.chatInteraction.presentation.selectionState != nil, item: item, needUpdateColors: false)
        
        rightView.set(item:item, animated:animated)
        fillReply(item, animated: animated)
        fillName(item, animated: animated)
        fillForward(item, animated: animated)
        fillPhoto(item, animated: animated)
        fillScamButton(item, animated: animated)
        fillScamForwardButton(item, animated: animated)
        fillPsaButton(item, animated: animated)
        fillShareView(item, animated: animated)
        fillReactions(item, animated: animated)
        fillReplyMarkup(item, animated: animated)
        fillCaption(item, animated: animated)
        fillChannelComments(item, animated: animated)
        
        
        self.needsDisplay = true
        self.rowView.needsDisplay = true
        self.needsLayout = true

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
                if let message = item.message, canReplyMessage(message, peerId: item.chatInteraction.peerId, mode: item.chatInteraction.mode) {
                    item.chatInteraction.setupReplyMessage(item.message?.id)
                }
            }
        }
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        guard let item = item as? ChatRowItem else {
            return
        }
        hasBeenLayout = true
                
        transition.updateFrame(view: bubbleView, frame: bubbleFrame(item))
        bubbleView.updateLayout(size: bubbleView.frame.size, transition: transition)
        transition.updateFrame(view: contentView, frame: contentFrameModifier(item))
                
        transition.updateFrame(view: rowView, frame: CGRect(origin: rowPoint(item), size: size))
        
        updateBackground(animated: transition.isAnimated, item: item)
        
        if let view = forwardName {
            transition.updateFrame(view: view, frame: CGRect(origin: forwardNamePoint(item), size: view.frame.size))
        }
        if let view = forwardAccessory {
            transition.updateFrame(view: view, frame: CGRect(origin: forwardNamePoint(item), size: view.frame.size))
        }

        transition.updateFrame(view: rightView, frame: rightFrame(item))
        rightView.updateLayout(size: rightView.frame.size, transition: transition)

        if let view = nameView {
            transition.updateFrame(view: view, frame: CGRect(origin: namePoint(item), size: view.frame.size))
        }
        
        if let view = adminBadge {
            transition.updateFrame(view: view, frame: CGRect(origin: adminBadgePoint(item), size: view.frame.size))
        }
        if let view = viaAccessory {
            transition.updateFrame(view: view, frame: CGRect(origin: viaAccesoryPoint(item), size: view.frame.size))
        }
        
        if let view = item.replyModel?.view {
            transition.updateFrame(view: view, frame: replyFrame(item))
            view.needsDisplay = true
        }
        if let view = scamButton {
            transition.updateFrame(view: view, frame: CGRect(origin: scamPoint(item), size: view.frame.size))
        }
        if let view = scamForwardButton {
            transition.updateFrame(view: view, frame: CGRect(origin: scamForwardPoint(item), size: view.frame.size))
        }
        
        if let view = psaButton {
            transition.updateFrame(view: view, frame: CGRect(origin: psaPoint(item), size: view.frame.size))
        }
        
        if let view = avatar {
            transition.updateFrame(view: view, frame: avatarFrame(item))
        }
        
        for captionView in captionViews {
            if let caption = item.captionLayouts.first(where: { $0.id == captionView.id }) {
                transition.updateFrame(view: captionView.view, frame: captionFrame(item, caption: caption))
            }
        }
        
        
        if let view = replyMarkupView {
            transition.updateFrame(view: view, frame: replyMarkupFrame(item))
            item.replyMarkupModel?.layout()
        }
        
        if let view = selectingView {
            transition.updateFrame(view: view, frame: CGRect(origin: selectingPoint(item), size: view.frame.size))
        }
        
        
        if let view = animatedView {
            transition.updateFrame(view: view, frame: size.bounds)
        }
        if let view = channelCommentsBubbleControl {
            transition.updateFrame(view: view, frame: channelCommentsBubbleFrame(item))
        }
        if let view = channelCommentsControl {
            transition.updateFrame(view: view, frame: channelCommentsFrame(item))
        }
        if let view = channelCommentsBubbleSmallControl {
            transition.updateFrame(view: view, frame: channelCommentsOverlayFrame(item))
        }

        transition.updateFrame(view: self.swipingRightView, frame: NSMakeRect(frame.width, 0, rightRevealWidth, frame.height))
        
        if let view = shareView {
            transition.updateFrame(view: view, frame: CGRect(origin: shareViewPoint(item), size: view.frame.size))
        }
        
        if let view = reactionsView {
            transition.updateFrame(view: view, frame: reactionsRect(item))
            view.updateLayout(size: view.frame.size, transition: transition)
        }

    }
    
    
    func toggleSelected(_ select: Bool, in point: NSPoint) {
        guard let item = item as? ChatRowItem else { return }
        
        if item.isSelectable {
            item.chatInteraction.withToggledSelectedMessage({ current in
                if let message = item.message {
                    if (select && !current.isSelectedMessageId(message.id)) || (!select && current.isSelectedMessageId(message.id)) {
                        return current.withToggledSelectedMessage(message.id)
                    }
                }
                return current
            })
        }        
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
        
        
        if item.presentation.shouldBlurService {
            control.set(image: item.presentation.chat.chat_reply_swipe_bubble(theme: item.presentation), for: .Normal)
            control.autohighlight = false
            _ = control.sizeToFit()
            control.setFrameSize(NSMakeSize(control.frame.width + 4, control.frame.height + 4))
            control.set(background: item.presentation.chatServiceItemColor, for: .Normal)
            control.set(background: item.presentation.chatServiceItemColor.withAlphaComponent(0.8), for: .Highlight)
            
            
            
            control.layer?.cornerRadius = control.frame.height / 2
        } else {
            control.set(image: item.presentation.icons.chat_swipe_reply, for: .Normal)
            _ = control.sizeToFit()
            control.background = .clear
        }
        swipingRightView.addSubview(control)
        
        control.centerY()
        
    }
    
    var hasRevealState: Bool {
        return !swipingRightView.subviews.isEmpty
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
    
    var rectForReaction: NSRect {
        guard let item = self.item as? ChatRowItem else {
            return .zero
        }
        
        
        if item.isBubbled {
            let bubbleFrame = self.bubbleView.frame
            var rect = NSMakeRect(bubbleFrame.maxX - 10 + self.rowView.frame.minX, bubbleFrame.maxY - 10, 20, 20)
            if item.isIncoming {
                rect.origin.x -= 5
                rect.origin.y -= 5
            } else {
                rect.origin.x = bubbleFrame.minX - 5 + self.rowView.frame.minX
                rect.origin.y -= 5
            }
            return rect
        } else {
            let contentFrame = self.contentView.frame
            let rect = NSMakeRect(contentFrame.minX - 20 - 10 + self.rowView.frame.minX, contentFrame.minY, 20, 20)
            return rect
        }
    }
    
}
