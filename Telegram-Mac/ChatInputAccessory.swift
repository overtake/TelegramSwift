//
//  ChatInputAccessory.swift
//  Telegram-Mac
//
//  Created by keepcoder on 04/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore

import TGUIKit
import SwiftSignalKit


class ChatInputAccessory: Node {

    var chatInteraction:ChatInteraction

    private var displayNode:ChatAccessoryModel?
    
    private let dismiss:ImageButton = ImageButton()
    private let iconView = ImageView()
    private var progress: Control?
    let container:ChatAccessoryView = ChatAccessoryView()
    
    var dismissForward:(()->Void)!
    var dismissReply:(()->Void)!
    var dismissEdit:(()->Void)!
    var dismissUrlPreview:(()->Void)!
    init(_ view: View? = nil, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(view)
        
        dismissForward = { [weak self] in
            self?.chatInteraction.update({$0.updatedInterfaceState({$0.withoutForwardMessages()})})
        }
        dismissReply = { [weak self] in
            self?.chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedReplyMessageId(nil).withUpdatedDismissedForceReplyId($0.replyMessageId)})})
        }
        dismissEdit = { [weak self] in
            self?.chatInteraction.cancelEditing()
        }
        dismissUrlPreview = { [weak self] in
            self?.chatInteraction.update({ state -> ChatPresentationInterfaceState in
                return state.updatedInterfaceState({$0.withUpdatedComposeDisableUrlPreview(state.urlPreview?.0)})
            })
        }

        dismiss.set(image: theme.icons.dismissAccessory, for: .Normal)
        _ = dismiss.sizeToFit()
        
        view?.addSubview(iconView)
        view?.addSubview(dismiss)
        self.view = view
        
    }
    

    
    
    //edit
    //webpage
    //forward
    //reply
    
    func update(with state:ChatPresentationInterfaceState, account:Account, animated:Bool) -> Void {
        
        dismiss.isHidden = false
        progress?.isHidden = true
        iconView.isHidden = false
        
        displayNode = nil
        dismiss.removeAllHandlers()
        container.removeAllHandlers()
        container.removeAllStateHandlers()

        if let urlPreview = state.urlPreview, state.interfaceState.composeDisableUrlPreview != urlPreview.0, let peer = state.peer, !peer.webUrlRestricted {
            iconView.image = theme.icons.chat_action_url_preview
            displayNode = ChatUrlPreviewModel(account: account, webpage: urlPreview.1, url:urlPreview.0)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissUrlPreview()
            }, for: .Click)
        } else if let editState = state.interfaceState.editState {
            displayNode = EditMessageModel(state: editState, account:account)
            iconView.image = theme.icons.chat_action_edit_message
            iconView.isHidden = editState.loadingState != .none
            progress?.isHidden = editState.loadingState == .none
            updateProgress(editState.loadingState)
            dismiss.set(handler: { [weak self] _ in
                self?.dismissEdit()
            }, for: .Click)
            progress?.set(handler: { [weak self] _ in
                self?.dismiss.send(event: .Click)
            }, for: .Click)
            
        } else if !state.interfaceState.forwardMessages.isEmpty && !state.interfaceState.forwardMessageIds.isEmpty {
            displayNode = ForwardPanelModel(forwardMessages:state.interfaceState.forwardMessages, hideNames: state.interfaceState.hideSendersName, account:account)
           
            iconView.image = theme.icons.chat_action_forward_message

            let anotherAction = { [weak self] in
                guard let context = self?.chatInteraction.context else {
                    return
                }
                let fwdMessages = state.interfaceState.forwardMessageIds
                showModal(with: ShareModalController(ForwardMessagesObject(context, messageIds: fwdMessages, emptyPerformOnClose: true)), for: context.window)
                delay(0.15, closure: {
                    self?.chatInteraction.update({$0.updatedInterfaceState({$0.withoutForwardMessages()})})
                })
            }
            let setHideAction = { [weak self] hide in
                self?.chatInteraction.update {
                    $0.updatedInterfaceState {
                        $0.withUpdatedHideSendersName(hide)
                    }
                }
            }
            let setHideCaption = { [weak self] hide in
                self?.chatInteraction.update {
                    $0.updatedInterfaceState {
                        $0.withUpdatedHideCaption(hide)
                    }
                }
            }
            
            var items:[SPopoverItem] = []
            
            let authors = state.interfaceState.forwardMessages.compactMap { $0.author?.id }.uniqueElements.count

            let hideSendersName = (state.interfaceState.hideSendersName || state.interfaceState.hideCaptions)
            
            items.append(SPopoverItem(L10n.chatAlertForwardActionShow1Countable(authors), {
                setHideAction(false)
            }, !hideSendersName ? theme.icons.chat_action_menu_selected : nil))
            
            items.append(SPopoverItem(L10n.chatAlertForwardActionHide1Countable(authors), {
                setHideAction(true)
            }, hideSendersName ? theme.icons.chat_action_menu_selected : nil))
        
            items.append(SPopoverItem(true))
            
            let messagesWithCaption = state.interfaceState.forwardMessages.filter {
                !$0.text.isEmpty && $0.media.first != nil
            }.count
            
            if messagesWithCaption > 0 {
                
                items.append(SPopoverItem(L10n.chatAlertForwardActionShowCaptionCountable(messagesWithCaption), {
                    setHideCaption(false)
                }, !state.interfaceState.hideCaptions ? theme.icons.chat_action_menu_selected : nil))
                
                items.append(SPopoverItem(L10n.chatAlertForwardActionHideCaptionCountable(messagesWithCaption), {
                    setHideCaption(true)
                }, state.interfaceState.hideCaptions ? theme.icons.chat_action_menu_selected : nil))
                
                items.append(SPopoverItem(true))

            }
            
            items.append(SPopoverItem(L10n.chatAlertForwardActionAnother, anotherAction, theme.icons.chat_action_menu_update_chat))

        
            container.set(handler: { control in
                showPopover(for: control, with: SPopoverViewController(items: items, visibility: 10), inset: NSMakePoint(-5, 3))
            }, for: .Hover)
            
            dismiss.set(handler: { [weak self] _ in
                self?.dismissForward()
            }, for: .Click)
            
            
        } else if let replyMessageId = state.interfaceState.replyMessageId {
            displayNode = ReplyModel(replyMessageId: replyMessageId, context: chatInteraction.context, replyMessage: state.interfaceState.replyMessage)
            iconView.image = theme.icons.chat_action_reply_message
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissReply()
            }, for: .Click)
            
            container.set(handler: { [weak self] _ in
               self?.chatInteraction.focusMessageId(nil, replyMessageId, .CenterEmpty)
            }, for: .Click)
        }
        
        if let displayNode = displayNode {
            nodeReady.set(displayNode.nodeReady.get() |> map { _ in return animated})
        } else {
            nodeReady.set(.single(animated))
        }
        iconView.sizeToFit()
        container.removeAllSubviews()
        displayNode?.view = container
    }
    
    private func updateProgress(_ loadingState: EditStateLoading) {
        switch loadingState {
        case .none:
            progress?.removeFromSuperview()
            progress = nil
        case .loading:
            
            let indicator:ProgressIndicator
            if let _indicator = progress as? ProgressIndicator {
                indicator = _indicator
            } else {
                indicator = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
                progress = indicator
                view?.addSubview(indicator)
            }
            indicator.progressColor = theme.colors.text
        case let .progress(progress):
            let radial: RadialProgressView
            if let _radial = self.progress as? RadialProgressView {
                radial = _radial
            } else {
                radial = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: theme.colors.accent), twist: true, size: NSMakeSize(20, 20))
                self.progress = radial
                view?.addSubview(radial)
            }
            radial.state = .ImpossibleFetching(progress: progress, force: false)
        }
    }
    
    
    override var frame: NSRect {
        get {
            
            return super.frame
        }
        set {
            super.frame = newValue
            self.container.frame = NSMakeRect(49, 0, measuredWidth, size.height)
            iconView.centerY(x: 2)
            dismiss.centerY(x: newValue.width - dismiss.frame.width)
            progress?.centerY(x: 5)
            displayNode?.setNeedDisplay()
        }
    }
    
    override var view: View? {
        get {
            return super.view
        }
        set {
            
            if let view = newValue {
                if container.superview != newValue {
                    container.removeFromSuperview()
                    view.addSubview(container, positioned: .below, relativeTo: dismiss)
                }
                container.frame = view.bounds
                container.setNeedsDisplay()
            }
            
            super.view = newValue
            
            displayNode?.setNeedDisplay()
        }
    }
    
    deinit {
    }
    
    override func setNeedDisplay() {
        super.setNeedDisplay()
        displayNode?.setNeedDisplay()
    }
    
    override var size: NSSize {
        get {
            
            var s:NSSize = super.size
            if let size = displayNode?.size {
                s = size
            }
            
            if s.height > 0 {
                s.width = measuredWidth
            }
            return s
        }
        set {
            super.size = size
        }
    }
    
    func isVisibility() -> Bool {
        let isRecordingVoice:Bool
        if case .recording = chatInteraction.presentation.state {
            isRecordingVoice = true
        } else {
            isRecordingVoice = false
        }
        return (displayNode != nil) && (self.chatInteraction.presentation.state == .normal || self.chatInteraction.presentation.state == .editing || isRecordingVoice)
    }

    
    override func measureSize(_ width: CGFloat) {
        displayNode?.measureSize(width - 59)
        
        if let displayNode = displayNode {
            self.size = displayNode.size
        }
        super.measureSize(width)
    }
    
    
}
