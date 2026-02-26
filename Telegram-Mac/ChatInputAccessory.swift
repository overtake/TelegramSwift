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
    private let iconView = ImageButton()
    private var progress: Control?
    let container:ChatAccessoryView = ChatAccessoryView()
    
    private let disposable = MetaDisposable()
    
    var dismissForward:(()->Void)!
    var dismissReply:(()->Void)!
    var dismissEdit:(()->Void)!
    var dismissUrlPreview:(()->Void)!
    var dismissSuggestPost:(()->Void)!

    init(chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: .zero)
        self.addSubview(iconView)
        self.addSubview(container)
        self.addSubview(dismiss)
        
        iconView.autohighlight = false
        
        
        dismissForward = { [weak self] in
            self?.chatInteraction.update({$0.updatedInterfaceState({$0.withoutForwardMessages()})})
        }
        dismissReply = { [weak self] in
            self?.chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedReplyMessageId(nil).withUpdatedDismissedForceReplyId($0.replyMessageId?.messageId)})})
        }
        dismissEdit = { [weak self] in
            self?.chatInteraction.cancelEditing()
        }
        dismissUrlPreview = { [weak self] in
            self?.chatInteraction.update({ state -> ChatPresentationInterfaceState in
                return state.updatedInterfaceState({$0.withUpdatedComposeDisableUrlPreview(state.urlPreview?.0)})
            })
        }
        dismissSuggestPost = { [weak self] in
            self?.chatInteraction.update({ state -> ChatPresentationInterfaceState in
                return state.updatedInterfaceState({$0.withUpdatedSuggestPost(nil).withoutEditMessage()})
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

        
        if let data = state.interfaceState.suggestPost {
            iconView.set(image: NSImage(resource: .iconInputSuggestPost).precomposed(theme.colors.accent), for: .Normal)
            displayNode = SuggestPostPanelModel(data: data, context: context)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissSuggestPost()
            }, for: .Click)
            
            container.set(handler: { [weak self] _ in
                self?.chatInteraction.editPostSuggestion(data)
             }, for: .Click)

            container.contextMenu = {
                return nil
            }
            

        } else if let urlPreview = state.urlPreview, state.interfaceState.composeDisableUrlPreview != urlPreview.0, let peer = state.peer, !peer.webUrlRestricted {
            iconView.set(image: theme.icons.chat_action_url_preview, for: .Normal)
            displayNode = ChatUrlPreviewModel(context: context, webpage: urlPreview.1, url:urlPreview.0)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissUrlPreview()
            }, for: .Click)
            
            let toggleLinkPosition:(Bool)->Void = { [weak self] below in
                self?.chatInteraction.update {
                    $0.updatedInterfaceState {
                        $0.withUpdatedLinkBelowMessage(below)
                    }
                }
            }
            let toggleLinkSize:(Bool)->Void = { [weak self] big in
                self?.chatInteraction.update {
                    $0.updatedInterfaceState {
                        $0.withUpdatedLargeMedia(big)
                    }
                }
            }
            
            container.contextMenu = { [weak self] in
                let menu = ContextMenu()
                menu.addItem(ContextMenuItem(strings().chatInputEditLinkAboveTheMessage, handler: {
                    toggleLinkPosition(false)
                }, itemImage: state.interfaceState.linkBelowMessage ? nil : MenuAnimation.menu_check_selected.value))
                
                menu.addItem(ContextMenuItem(strings().chatInputEditLinkBelowTheMessage, handler: {
                    toggleLinkPosition(true)
                }, itemImage: !state.interfaceState.linkBelowMessage ? nil : MenuAnimation.menu_check_selected.value))
                
                if let presentation = self?.chatInteraction.presentation, let urlPreview = presentation.urlPreview {
                    switch urlPreview.1.content {
                    case let .Loaded(content):
                        if let defaultValue = content.isMediaLargeByDefault {
                            menu.addItem(ContextSeparatorItem())
                            
                            let value = state.interfaceState.largeMedia ?? defaultValue
                            
                            menu.addItem(ContextMenuItem(strings().chatInputEditLinkLargerMedia, handler: {
                                toggleLinkSize(true)
                            }, itemImage: value ? MenuAnimation.menu_check_selected.value : nil))
                            
                            menu.addItem(ContextMenuItem(strings().chatInputEditLinkSmallerMedia, handler: {
                                toggleLinkSize(false)
                            }, itemImage: !value ? MenuAnimation.menu_check_selected.value : nil))
                        }
                    default:
                        break
                    }
                }
                
                menu.addItem(ContextSeparatorItem())

                menu.addItem(ContextMenuItem(strings().chatInputEditLinkRemovePreview, handler: { [weak self] in
                    self?.dismissUrlPreview()
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                
                return menu
            }
            
        } else if let editState = state.interfaceState.editState {
            displayNode = EditMessageModel(state: editState, context: context)
            iconView.set(image: theme.icons.chat_action_edit_message, for: .Normal)
            iconView.isHidden = editState.loadingState != .none
            progress?.isHidden = editState.loadingState == .none
            updateProgress(editState.loadingState)
            dismiss.set(handler: { [weak self] _ in
                self?.dismissEdit()
            }, for: .Click)
            progress?.set(handler: { [weak self] _ in
                self?.dismiss.send(event: .Click)
            }, for: .Click)
            
            container.contextMenu = { [weak self] in
                let menu = ContextMenu()
                
                if !editState.message.media.isEmpty {
                    menu.addItem(ContextMenuItem(editState.invertMedia ? strings().previewSenderMoveTextDown : strings().previewSenderMoveTextUp, handler: {
                        self?.chatInteraction.update {
                            $0.updatedInterfaceState {
                                $0.updatedEditState {
                                    $0?.withUpdatedInvertMedia(!editState.invertMedia)
                                }
                            }
                        }
                    }, itemImage: editState.invertMedia ? MenuAnimation.menu_sort_down.value : MenuAnimation.menu_sort_up.value))
                }
                if !editState.message.media.isEmpty, editState.addedMedia {
                    menu.addItem(ContextMenuItem(strings().previewSenderRemoveMedia, handler: {
                        self?.chatInteraction.update {
                            $0.updatedInterfaceState {
                                $0.updatedEditState { value in
                                    if let value = value {
                                        return .init(message: value.message.withUpdatedMedia([]))
                                    } else {
                                        return nil
                                    }
                                }
                            }
                        }
                    }, itemImage: MenuAnimation.menu_clear_history.value))
                }
                
                return menu
            }
            
        } else if !state.interfaceState.forwardMessages.isEmpty && !state.interfaceState.forwardMessageIds.isEmpty {
            displayNode = ForwardPanelModel(forwardMessages:state.interfaceState.forwardMessages, hideNames: state.interfaceState.hideSendersName, context: context)
           
            iconView.set(image: theme.icons.chat_action_forward_message, for: .Normal)

            let anotherAction = { [weak self] in
                guard let context = self?.chatInteraction.context else {
                    return
                }
                let fwdMessages = state.interfaceState.forwardMessages
                showModal(with: ShareModalController(ForwardMessagesObject(context, messages: fwdMessages, emptyPerformOnClose: true)), for: context.window)
                delay(0.15, closure: {
                    self?.chatInteraction.update({$0.updatedInterfaceState({$0.withoutForwardMessages()})})
                })
            }
            let setHideAction:(Bool)->Void = { [weak self] hide in
                self?.chatInteraction.update {
                    $0.updatedInterfaceState {
                        $0.withUpdatedHideSendersName(hide, saveTempValue: true)
                    }
                }
            }
            let setHideCaption:(Bool)->Void = { [weak self] hide in
                self?.chatInteraction.update {
                    $0.updatedInterfaceState { current in
                        var current = current
                        current = current.withUpdatedHideCaption(hide)
                        if current.tempSenderName == nil {
                            current = current.withUpdatedHideSendersName(hide, saveTempValue: false)
                        }
                        return current
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
                    !$0.text.isEmpty && $0.anyMedia != nil
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
                if let peer = state.peer, !peer.isCopyProtected {
                    items.append(ContextMenuItem(strings().chatAlertForwardActionAnother, handler: anotherAction, itemImage: MenuAnimation.menu_replace.value))
                }
                
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
            displayNode = ReplyModel(message: nil, replyMessageId: replyMessageId.messageId, context: chatInteraction.context, replyMessage: state.interfaceState.replyMessage, quote: replyMessageId.quote, dismissReply: dismissReply, forceClassic: true)
            iconView.set(image: theme.icons.chat_action_reply_message, for: .Normal)
            dismiss.set(handler: { [weak self ] _ in
                self?.dismissReply()
            }, for: .Click)
            
            container.set(handler: { [weak self] _ in
                self?.chatInteraction.focusMessageId(nil, .init(messageId: replyMessageId.messageId, string: nil), .CenterEmpty)
             }, for: .Click)

            
            container.contextMenu = {
                let menu = ContextMenu()
                if let peer = state.peer, !peer.isCopyProtected {
                    menu.addItem(ContextMenuItem(strings().chatInputReplyReplyToAnother, handler: {
                        self.chatInteraction.replyToAnother(replyMessageId, true)
                    }, itemImage: MenuAnimation.menu_replace.value))
                }
                return menu
                
            }
        }
        
        if let displayNode = displayNode {
            nodeReady.set(displayNode.nodeReady.get() |> map { _ in return animated })
        } else {
            nodeReady.set(.single(animated))
        }
        iconView.contextMenu = container.contextMenu
        iconView.sizeToFit()
        disposable.set(nodeReady.get().startStandalone(next: { [weak self, container] value in
            self?.displayNode?.view = container
        }))
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
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: size.width - dismiss.frame.width + 3))
        if let view = progress {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: 5))
        }
        displayNode?.setNeedDisplay()
        
    }
    
    
    deinit {
        disposable.dispose()
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
        displayNode?.measureSize(width - 59 - (displayNode?.cutout?.topLeft?.width ?? 0))
        
        if let displayNode = displayNode {
            self.size = NSMakeSize(width, displayNode.size.height)
        }
    }
    
    
    
}
