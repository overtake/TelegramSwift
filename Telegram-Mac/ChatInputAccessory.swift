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
    private var progress: Control?
    let container:ChatAccessoryView = ChatAccessoryView()
    private let updateMediaDisposable = MetaDisposable()
    
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
            self?.chatInteraction.update({$0.withoutEditMessage()})
        }
        dismissUrlPreview = { [weak self] in
            self?.chatInteraction.update({ state -> ChatPresentationInterfaceState in
                return state.updatedInterfaceState({$0.withUpdatedComposeDisableUrlPreview(state.urlPreview?.0)})
            })
        }

        dismiss.set(image: theme.icons.dismissAccessory, for: .Normal)
        _ = dismiss.sizeToFit()
        
       
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
      
        displayNode = nil
        dismiss.removeAllHandlers()
        container.removeAllHandlers()
        if let urlPreview = state.urlPreview, state.interfaceState.composeDisableUrlPreview != urlPreview.0, let peer = state.peer, !peer.webUrlRestricted {
            displayNode = ChatUrlPreviewModel(account: account, webpage: urlPreview.1, url:urlPreview.0)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissUrlPreview()
            }, for: .Click)
        } else if let editState = state.interfaceState.editState {
            displayNode = EditMessageModel(state: editState, account:account)
            dismiss.isHidden = editState.loadingState != .none
            progress?.isHidden = editState.loadingState == .none
            updateProgress(editState.loadingState)
            dismiss.set(handler: { [weak self] _ in
                self?.dismissEdit()
            }, for: .Click)
            progress?.set(handler: { [weak self] _ in
                self?.dismiss.send(event: .Click)
            }, for: .Click)
            let updateMedia:([String]?, Bool)->Void = { [weak self] exts, asMedia in
                guard let `self` = self else {return}
                
                filePanel(with: exts, allowMultiple: false, for: mainWindow, completion: { [weak self] files in
                    guard let `self` = self else {return}
                    if let file = files?.first {
                        self.updateMediaDisposable.set((Sender.generateMedia(for: MediaSenderContainer(path: file, isFile: !asMedia), account: account) |> deliverOnMainQueue).start(next: { [weak self] media, _ in
                            self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                        }))
                    }
                })
            }
            
            if let media = editState.message.media.first, media is TelegramMediaFile || media is TelegramMediaImage {
                container.set(handler: { control in
                    
                    var items:[SPopoverItem] = []
                    items.append(SPopoverItem(L10n.inputAttachPopoverPhotoOrVideo, {
                        updateMedia(mediaExts, true)
                    }, theme.icons.chatAttachPhoto))
                    
                    if editState.message.groupingKey == nil {
                        items.append(SPopoverItem(L10n.inputAttachPopoverFile, {
                            updateMedia(nil, false)
                        }, theme.icons.chatAttachFile))
                    }
                    
                    showPopover(for: control, with: SPopoverViewController(items: items), edge: nil, inset: NSMakePoint(-10, 0))
                    
        
                }, for: .Click)
            }
            
            
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
            indicator.progressColor = theme.colors.blueUI
        case let .progress(progress):
            let radial: RadialProgressView
            if let _radial = self.progress as? RadialProgressView {
                radial = _radial
            } else {
                radial = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: theme.colors.blueUI), twist: true, size: NSMakeSize(20, 20))
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
            self.container.frame = NSMakeRect(49, 0, newValue.width, size.height)
            dismiss.centerY(x: 0)
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
                    view.addSubview(container)
                }
                container.frame = view.bounds
                container.setNeedsDisplay()
            }
            
            super.view = newValue
            
            displayNode?.setNeedDisplay()
        }
    }
    
    deinit {
        updateMediaDisposable.dispose()
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
