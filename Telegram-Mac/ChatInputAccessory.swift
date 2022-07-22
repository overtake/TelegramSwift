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


class ChatInputAccessory: View {

    
    let nodeReady = Promise<Bool>()

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
    init(chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: .zero)
        self.addSubview(iconView)
        self.addSubview(container)
        self.addSubview(dismiss)
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
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    

    
    
    //edit
    //webpage
    //forward
    //reply
    
    func update(with state:ChatPresentationInterfaceState, context: AccountContext, animated:Bool) -> Void {
        
        dismiss.isHidden = false
        progress?.isHidden = true
        iconView.isHidden = false
        
        displayNode = nil
        dismiss.removeAllHandlers()
        container.removeAllHandlers()
        container.removeAllStateHandlers()

        if let urlPreview = state.urlPreview, state.interfaceState.composeDisableUrlPreview != urlPreview.0, let peer = state.peer, !peer.webUrlRestricted {
            iconView.image = theme.icons.chat_action_url_preview
            displayNode = ChatUrlPreviewModel(context: context, webpage: urlPreview.1, url:urlPreview.0)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissUrlPreview()
            }, for: .Click)
        } else if let editState = state.interfaceState.editState {
            displayNode = EditMessageModel(state: editState, context: context)
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
            displayNode = ForwardPanelModel(forwardMessages:state.interfaceState.forwardMessages, hideNames: state.interfaceState.hideSendersName, context: context)
           
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
            

            container.contextMenu = {
                var items:[ContextMenuItem] = []
                
                let authors = state.interfaceState.forwardMessages.compactMap { $0.author?.id }.uniqueElements.count

                let hideSendersName = state.interfaceState.hideSendersName
                
                items.append(ContextMenuItem(strings().chatAlertForwardActionShow1Countable(authors), handler: {
                    setHideAction(false)
                }, itemImage: !hideSendersName ? MenuAnimation.menu_check_selected.value : nil))
                
                items.append(ContextMenuItem(strings().chatAlertForwardActionHide1Countable(authors), handler: {
                    setHideAction(true)
                }, itemImage: hideSendersName ? MenuAnimation.menu_check_selected.value : nil))
            
                items.append(ContextSeparatorItem())
                
                let messagesWithCaption = state.interfaceState.forwardMessages.filter {
                    !$0.text.isEmpty && $0.media.first != nil
                }.count
                
                if messagesWithCaption > 0 {
                    
                    items.append(ContextMenuItem(strings().chatAlertForwardActionShowCaptionCountable(messagesWithCaption), handler: {
                        setHideCaption(false)
                    }, itemImage: !state.interfaceState.hideCaptions ? MenuAnimation.menu_check_selected.value : nil))
                    
                    items.append(ContextMenuItem(strings().chatAlertForwardActionHideCaptionCountable(messagesWithCaption), handler: {
                        setHideCaption(true)
                    }, itemImage: state.interfaceState.hideCaptions ? MenuAnimation.menu_check_selected.value : nil))
                    
                    items.append(ContextSeparatorItem())

                }
                
                items.append(ContextMenuItem(strings().chatAlertForwardActionAnother, handler: anotherAction, itemImage: MenuAnimation.menu_replace.value))
                
                let menu = ContextMenu()
                for item in items {
                    menu.addItem(item)
                }
                return menu

            }
            
            dismiss.set(handler: { [weak self] _ in
                self?.dismissForward()
            }, for: .Click)
            
            
        } else if let replyMessageId = state.interfaceState.replyMessageId {
            displayNode = ReplyModel(replyMessageId: replyMessageId, context: chatInteraction.context, replyMessage: state.interfaceState.replyMessage, dismissReply: dismissReply)
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
                self.addSubview(indicator)
            }
            indicator.progressColor = theme.colors.text
        case let .progress(progress):
            let radial: RadialProgressView
            if let _radial = self.progress as? RadialProgressView {
                radial = _radial
            } else {
                radial = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: theme.colors.accent), twist: true, size: NSMakeSize(20, 20))
                self.progress = radial
                self.addSubview(radial)
            }
            radial.state = .ImpossibleFetching(progress: progress, force: false)
        }
    }
    
    
    override func layout() {
        super.layout()
        updateLayout(frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: self.container, frame: NSMakeRect(49, 0, size.width, size.height))
        transition.updateFrame(view: iconView, frame: iconView.centerFrameY(x: 2))
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: size.width - dismiss.frame.width))
        if let view = progress {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: 5))
        }
        displayNode?.setNeedDisplay()
        
    }
    
    
    deinit {
    }
    
    var size: NSSize = .zero
    
    func isVisibility() -> Bool {
        let isRecordingVoice:Bool
        if case .recording = chatInteraction.presentation.state {
            isRecordingVoice = true
        } else {
            isRecordingVoice = false
        }
        return (displayNode != nil) && (self.chatInteraction.presentation.state == .normal || self.chatInteraction.presentation.state == .editing || isRecordingVoice)
    }

    
    func measureSize(_ width: CGFloat) {
        displayNode?.measureSize(width - 59)
        
        if let displayNode = displayNode {
            self.size = NSMakeSize(width, displayNode.size.height)
        }
    }
    
    
}
