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

class ChatRowView: TableRowView, Notifable, MultipleSelectable {
   
    
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
    private var captionView:TextView?
    private var shareControl:ImageButton?
    private var nameView:TextView?
    private var rightView:ChatRightView = ChatRightView(frame:NSZeroRect)
    private var selectingView:SelectingControl?
    
    private var animatedView:ChatRowAnimateView?
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        super.addSubview(rightView)
        super.addSubview(contentView)
        
  
    }
    
    var selectableTextViews: [TextView] {
        if let captionView = captionView {
            return [captionView]
        }
        return []
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ChatRowView {
            return self == other
        }
        return false
    }
    
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if (value.selectionState != nil && oldValue.selectionState == nil) || (value.selectionState == nil && oldValue.selectionState != nil) {
                updateSelectingState(!NSIsEmptyRect(visibleRect), selectingMode:value.selectionState != nil, item: self.item as? ChatRowItem)
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
    
    
    func updateSelectingState(_ animated:Bool = false, selectingMode:Bool, item: ChatRowItem?) {
        if let item = item {
            let defRight = frame.width - item.rightSize.width - item.rightInset
            rightView.change(pos: NSMakePoint(defRight, rightView.frame.minY), animated: animated)
            
            if selectingMode {
                if selectingView == nil {
                    selectingView = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
                    selectingView?.setFrameOrigin(NSMakePoint(frame.width, item.defaultContentTopOffset - 1))
                    super.addSubview(selectingView!)
                }
                if animated {
                    selectingView?.layer?.removeAnimation(forKey: "opacity")
                    selectingView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
               
                selectingView?.change(pos: NSMakePoint(rightView.frame.maxX + 4,item.defaultContentTopOffset - 1), animated: animated)
            } else {
                
                if animated {
                    selectingView?.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion:false, completion:{ [weak self] (completed) in
                        if completed {
                            self?.selectingView?.removeFromSuperview()
                            self?.selectingView = nil
                        }
                    })
                } else {
                    self.selectingView?.removeFromSuperview()
                    self.selectingView = nil
                }
                
                selectingView?.change(pos: NSMakePoint(frame.width,item.defaultContentTopOffset - 1), animated: animated)
            }
            if let selectionState = item.chatInteraction.presentation.selectionState, let message = item.message {
                selectingView?.set(selected: selectionState.selectedIds.contains(message.id), animated: animated)
                updateColors()
            }
            if item.chatInteraction.presentation.state == .selecting {
                disableHierarchyInteraction()
            } else {
               restoreHierarchyInteraction()
            }

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
    
    override var backdorColor: NSColor {
        return contextMenu != nil || isSelect ? theme.colors.selectMessage : theme.colors.background
    }
    
    override func updateColors() -> Void {
        
        rightView.backgroundColor = backdorColor
        contentView.backgroundColor = backdorColor
        replyView?.backgroundColor = backdorColor
        nameView?.backgroundColor = backdorColor
        forwardName?.backgroundColor = backdorColor
        captionView?.backgroundColor = backdorColor
        replyMarkupView?.backgroundColor = backdorColor
        self.backgroundColor = backdorColor
        for view in contentView.subviews {
            if let view = view as? View {
                view.backgroundColor = backdorColor
            }
        }
        if let item = item as? ChatRowItem {
            item.replyModel?.setNeedDisplay()
        }
    }
    

    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        
        if let item = item as? ChatRowItem, !item.chatInteraction.isLogInteraction, !item.sending {
            
            if item.chatInteraction.presentation.state == .selecting, let message = item.message {
                item.chatInteraction.update({$0.withToggledSelectedMessage(message.id)})
            } else if let message = item.message {
                let location = self.convert(event.locationInWindow, from: nil)
                if NSPointInRect(location, rightView.frame) {
                    if message.flags.contains(.Failed) {
                        confirm(for: mainWindow, with: tr(.alertSendErrorHeader), and: tr(.alertSendErrorText), okTitle: tr(.alertSendErrorResend), cancelTitle: tr(.alertSendErrorIgnore), thridTitle: tr(.alertSendErrorDelete), successHandler: { result in
                            
                            switch result {
                            case .thrid:
                                item.deleteMessage()
                            default:
                                item.resendMessage()
                            }
                            
                            
                        })
                    } else {
                        item.chatInteraction.update({$0.withToggledSelectedMessage(message.id)})
                    }
                }
            }
        }
    }
    
    override func onShowContextMenu() {
        updateColors()
        super.onCloseContextMenu()
    }
    
    override func onCloseContextMenu() {
        updateColors()
        super.onCloseContextMenu()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {

        super.draw(layer, in: ctx)

        if let item = self.item as? ChatRowItem {
            
            if let fwdHeader = item.forwardHeader {
                fwdHeader.1.draw(NSMakeRect(item.defLeftInset, item.forwardHeaderInset.y, fwdHeader.0.size.width, fwdHeader.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
            }
            
            let radius:CGFloat = 1.0
          //  ctx.fill(NSMakeRect(0, radius, 2, layer.bounds.height - radius * 2))
      //     ctx.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius + radius, height: radius + radius)))
          //  ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: layer.bounds.height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
            
            //draw separator
            if let fwdType = item.forwardType {
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
            
            if item.isGame {
                ctx.setFillColor(theme.colors.blueFill.cgColor)
                let height = frame.height - item.gameInset.y - item.defaultContentTopOffset
                ctx.fill(NSMakeRect(item.gameInset.x, item.gameInset.y + radius, 2, height - radius * 2))
                
                ctx.fillEllipse(in: CGRect(origin: CGPoint(x: item.gameInset.x, y: item.gameInset.y), size: CGSize(width: radius + radius, height: radius + radius)))
                ctx.fillEllipse(in: CGRect(origin: CGPoint(x: item.gameInset.x, y: item.gameInset.y + height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
            }
        }
        
    }
    
    override func updateMouse() {
        if let shareControl = self.shareControl, let item = item as? ChatRowItem {
            shareControl.change(opacity: item.chatInteraction.presentation.state != .selecting && mouseInside() ? 1.0 : 0.0, animated: true)
        }
    }
    
    var contentFrame:NSRect {
        return self.contentView.frame
    }
    
    override func addSubview(_ view: NSView) {
        self.contentView.addSubview(view)
    }
    
    func fillReplyIfNeeded(_ reply:ReplyModel?, _ item:ChatRowItem) -> Void {
        
        if let reply = reply {
            
            if replyView == nil {
                replyView = ChatAccessoryView()
                replyView?.backgroundColor = backdorColor
                super.addSubview(replyView!)
            }
            
            replyView?.removeAllHandlers()
            replyView?.set(handler: { [weak item, weak reply] _ in
                if let replyMessage = reply?.replyMessage, let fromMessage = item?.message {
                    item?.chatInteraction.focusMessageId(fromMessage.id, replyMessage.id, .center(id: 0, animated: true, focus: true, inset: 0))
                }
                
            }, for: .Click)
            
//            replyView?.set(handler: { [weak reply, weak item] control in
//                if let replyMessageId = reply?.replyMessage?.id, let item = item {
//                    showPopover(for: control, with: ChatReplyPreviewController(item.account, messageId: replyMessageId, width: min(item.width - 160, 500)), inset: NSMakePoint(-8, 1))
//                }
//            }, for: .LongOver)
            
            reply.view = replyView
            reply.view?.needsDisplay = true
        } else {
            replyView?.removeFromSuperview()
            replyView = nil
        }
        
    }
    
    
    
    override func layout() {
        super.layout()
        if let item = item as? ChatRowItem {
            forwardName?.setFrameOrigin(item.forwardNameInset.x, item.forwardNameInset.y)
            contentView.frame = NSMakeRect(item.contentOffset.x, item.contentOffset.y, item.contentSize.width, item.contentSize.height)
            rightView.frame = NSMakeRect(frame.width - item.rightSize.width - item.rightInset, item.defaultContentTopOffset, item.rightSize.width, item.rightSize.height)
            if let reply = item.replyModel {
                reply.frame = NSMakeRect(contentFrame.minX, item.replyOffset, reply.size.width,reply.size.height)
            }
            avatar?.frame = NSMakeRect(item.leftInset, item.defaultContentTopOffset, 36, 36)
            
            var additionInset:CGFloat = contentView.frame.maxY + item.defaultContentTopOffset
            if let captionLayout = item.captionLayout {
                captionView?.frame = NSMakeRect(contentView.frame.minX, additionInset, captionLayout.layoutSize.width, captionLayout.layoutSize.height)
                additionInset += captionLayout.layoutSize.height + item.defaultContentTopOffset
            }
            
            item.replyModel?.view?.needsDisplay = true
            
            if let replyMarkup = item.replyMarkupModel {
                replyMarkupView?.frame = NSMakeRect(contentView.frame.minX, additionInset, replyMarkup.size.width, replyMarkup.size.height)
                replyMarkup.layout()
            }
            
            selectingView?.setFrameOrigin(rightView.frame.maxX + 4,item.defaultContentTopOffset - 1)
            if let shareControl = shareControl {
                shareControl.setFrameOrigin(frame.width - 20.0 - shareControl.frame.width, rightView.frame.maxY + 5)
            }
        }
    }
    
    
    
    func fillForward(_ item:ChatRowItem) -> Void {
        if let forwardNameLayout = item.forwardNameLayout {
            if forwardName == nil {
                forwardName = TextView()
                forwardName?.isSelectable = false
                super.addSubview(forwardName!)
            }
            if !forwardName!.isEqual(to: forwardNameLayout) {
                forwardName?.update(forwardNameLayout)
            }
        } else {
            forwardName?.removeFromSuperview()
            forwardName = nil
        }
    }
    
    func fillPhoto(_ item:ChatRowItem) -> Void {
        if case .Full = item.itemType, item.peer != nil {
            
            if avatar == nil {
                avatar = AvatarControl(font: .avatar(.text))
                avatar?.setFrameSize(36,36)
               super.addSubview(avatar!)
            }
            avatar?.removeAllHandlers()
            avatar?.set(handler: { control in
                if let peerId = item.peer?.id {
                    item.chatInteraction.openInfo(peerId, false, nil, nil)
                }
            }, for: .Click)
            
            avatar?.set(handler: { control in
                if let peerId = item.peer?.id {
                    showDetailInfoPopover(forPeerId: peerId, account: item.account, fromView: control)
                }
            }, for: .LongOver)
            
            self.avatar?.setPeer(account: item.account, peer: item.peer!)
            
        } else {
            avatar?.removeFromSuperview()
            avatar = nil
        }
    }
    
    func fillCaption(_ item:ChatRowItem) -> Void {
        if let layout = item.captionLayout {
            if captionView == nil {
                captionView = TextView()
                super.addSubview(captionView!)
            }
            captionView?.update(layout)
        } else {
            captionView?.removeFromSuperview()
            captionView = nil
        }
    }
    
    func fillShareControl(_ item:ChatRowItem) -> Void {
        if item.isSharable {
            if shareControl == nil {
                shareControl = ImageButton()
                shareControl?.disableActions()
                shareControl?.change(opacity: 0, animated: false)
                super.addSubview(shareControl!)
            }
            shareControl?.set(image: theme.icons.chatShare, for: .Normal)
            shareControl?.sizeToFit()
            shareControl?.removeAllHandlers()
            shareControl?.set(handler: { [weak self] _ in
                if let window = self?.contentView.kitWindow, let message = item.message {
                    showModal(with: ShareModalController(ShareMessageObject(item.account, message)), for: window)
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
                super.addSubview(replyMarkupView!)
            }
            
            replyMarkupView?.setFrameSize(replyMarkup.size.width, replyMarkup.size.height)
            replyMarkup.view = replyMarkupView
            replyMarkup.view?.backgroundColor = theme.colors.background
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
                super.addSubview(nameView!)
            }
            nameView?.update(author, origin:NSMakePoint(item.defLeftInset, item.defaultContentTopOffset))
        } else {
            nameView?.removeFromSuperview()
            nameView = nil
        }
    }
    
    override func focusAnimation() {
        
        if animatedView == nil {
            self.animatedView = ChatRowAnimateView(frame:bounds)
            self.animatedView?.isEventLess = true
            super.addSubview(animatedView!)
            animatedView?.backgroundColor = NSColor(0x68A8E2)
            animatedView?.layer?.opacity = 0
            
        }
        animatedView?.stableId = item?.stableId
        animatedView?.change(opacity: 0.5, animated: true, false, removeOnCompletion: false, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
            if completed {
                self?.animatedView?.change(opacity: 0, animated: true, false, removeOnCompletion: true, duration: 1.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
                    if completed {
                        self?.animatedView?.removeFromSuperview()
                        self?.animatedView = nil
                    }
                })
            }
        })
     
        
    }

    override func rightMouseDown(with event: NSEvent) {
        if let item = self.item as? ChatRowItem {
            if item.chatInteraction.presentation.state == .selecting {
                return
            }
        }
        super.rightMouseDown(with: event)
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
            
            rightView.set(item:item, animated:animated)
            fillName(item)
            fillReplyIfNeeded(item.replyModel, item)
            fillForward(item)
            fillPhoto(item)
            fillCaption(item)
            fillReplyMarkup(item)
            fillShareControl(item)
            item.chatInteraction.add(observer: self)
            
            updateSelectingState(selectingMode:item.chatInteraction.presentation.selectionState != nil, item: item)
        }
        
        super.set(item: item, animated: animated)
        self.needsLayout = true
    }

    open override var interactionContentView:NSView {
        return self.contentView
    }
    
    override func doubleClick(in location: NSPoint) {
        if let item = self.item as? ChatRowItem, item.chatInteraction.presentation.state == .normal {
            if self.hitTest(location) == nil || self.hitTest(location) == self || self.hitTest(location) == replyView {
                if let avatar = avatar {
                    if NSPointInRect(location, avatar.frame) {
                        return
                    }
                }
                item.chatInteraction.setupReplyMessage(item.message?.id)
            }
        }
    }
    
    override func forceClick(in location: NSPoint) {
        guard let item = item as? ChatRowItem else { return }
        guard let message = item.message else { return }
        guard canEditMessage(message, account: item.account) else { return }
        
        let state = item.chatInteraction.presentation.state
        if state == .normal || state == .editing {
            let hitTestView = self.hitTest(location)
            if hitTestView == nil || hitTestView == self || hitTestView == replyView || hitTestView?.isDescendant(of: contentView) == true {
                if let avatar = avatar {
                    if NSPointInRect(location, avatar.frame) {
                        return
                    }
                }
                focusAnimation()
                item.chatInteraction.beginEditingMessage(item.message)
            }
        }
    }
    
    deinit {
        if let item = self.item as? ChatRowItem {
            item.chatInteraction.remove(observer: self)
        }
        contentView.removeAllSubviews()
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
