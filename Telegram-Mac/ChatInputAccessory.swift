//
//  ChatInputAccessory.swift
//  Telegram-Mac
//
//  Created by keepcoder on 04/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac


class ChatInputAccessory: Node {

    var chatInteraction:ChatInteraction

    private var displayNode:ChatAccessoryModel?
    
    private let dismiss:ImageButton = ImageButton()
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
            self?.chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedReplyMessageId(nil)})})
        }
        dismissEdit = { [weak self] in
            self?.chatInteraction.update({$0.withoutEditMessage()})
        }
        dismissUrlPreview = { [weak self] in
            self?.chatInteraction.update({ state -> ChatPresentationInterfaceState in
                return state.updatedInterfaceState({$0.withUpdatedComposeDisableUrlPreview(state.urlPreview?.0)})
            })
        }

        dismiss.set(image: theme.icons.dismissAccessory, for: .Normal)
        dismiss.sizeToFit()
        
        view?.addSubview(dismiss)
        
        self.view = view
        
    }
    

    
    
    //edit
    //webpage
    //forward
    //reply
    
    func update(with state:ChatPresentationInterfaceState, account:Account, animated:Bool) -> Void {
        
        displayNode = nil
        dismiss.removeAllHandlers()
        if let urlPreview = state.urlPreview, state.interfaceState.composeDisableUrlPreview != urlPreview.0, let peer = state.peer, !peer.webUrlRestricted {
            displayNode = ChatUrlPreviewModel(account: account, webpage: urlPreview.1, url:urlPreview.0)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissUrlPreview()
                }, for: .Click)
            
        } else if let editState = state.editState {
            displayNode = EditMessageModel(message:editState.message, account:account)
            dismiss.set(handler: { [weak self] _ in
                self?.dismissEdit()
            }, for: .Click)
        } else if !state.interfaceState.forwardMessageIds.isEmpty {
            displayNode = ForwardPanelModel(forwardIds:state.interfaceState.forwardMessageIds,account:account)
            dismiss.set(handler: { [weak self] _ in
                self?.dismissForward()
            }, for: .Click)
        } else if let replyMessageId = state.interfaceState.replyMessageId {
            displayNode = ReplyModel(replyMessageId: replyMessageId, account:account)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissReply()
            }, for: .Click)
        }
        
        if let displayNode = displayNode {
            nodeReady.set(displayNode.nodeReady.get() |> map { _ in return animated})
        } else {
            nodeReady.set(.single(animated))
        }
        container.removeAllSubviews()
        displayNode?.view = container
    }
    
    
    override var frame: NSRect {
        get {
            
            return super.frame
        }
        set {
            super.frame = newValue
            self.container.frame = NSMakeRect(49, 0, newValue.width, size.height)
            dismiss.centerY(x: 0)
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
                    view.addSubview(container)
                }
                container.frame = view.bounds
                container.setNeedsDisplay()
            }
            
            super.view = newValue
            
            displayNode?.setNeedDisplay()
        }
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
