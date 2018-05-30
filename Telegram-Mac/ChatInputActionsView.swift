//
//  ChatInputActionsView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac


//
let iconsInset:CGFloat = 20.0

class ChatInputActionsView: View, Notifable {
    
    let chatInteraction:ChatInteraction
    private let send:ImageButton = ImageButton()
    private let voice:ImageButton = ImageButton()
    private let muteChannelMessages:ImageButton = ImageButton()
    private let entertaiments:ImageButton = ImageButton()
    private let inlineCancel:ImageButton = ImageButton()
    private let keyboard:ImageButton = ImageButton()
    private var secretTimer:ImageButton?
    private var inlineProgress: ProgressIndicator? = nil
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
       
        super.init(frame: frameRect)
        
        addSubview(keyboard)
        addSubview(send)
        addSubview(voice)
        addSubview(inlineCancel)
        addSubview(muteChannelMessages)
        inlineCancel.isHidden = true
        send.isHidden = true
        voice.isHidden = true
        muteChannelMessages.isHidden = true
        
        voice.autohighlight = false
        muteChannelMessages.autohighlight = false
        
        voice.set(handler: { [weak self] _ in
            FastSettings.toggleRecordingState()
            self?.voice.set(image: FastSettings.recordingState == .voice ? theme.icons.chatRecordVoice : theme.icons.chatRecordVideo, for: .Normal)
        }, for: .Click)
        
        
        voice.set(handler: { [weak self] _ in
            self?.chatInteraction.startRecording(false)
        }, for: .LongMouseDown)

        
        muteChannelMessages.set(handler: { [weak self] _ in
            if let chatInteraction = self?.chatInteraction {
                FastSettings.toggleChannelMessagesMuted(chatInteraction.peerId)
                (self?.superview?.superview as? View)?.updateLocalizationAndTheme()
            }
        }, for: .Click)


        keyboard.set(handler: { [weak self] _ in
            self?.toggleKeyboard()
        }, for: .Up)
        
        inlineCancel.set(handler: { [weak self] _ in
            if let inputContext = self?.chatInteraction.presentation.inputContext, case let .contextRequest(request) = inputContext {
                if request.query.isEmpty {
                    self?.chatInteraction.clearInput()
                } else {
                    self?.chatInteraction.clearContextQuery()
                }
            }
        }, for: .Up)

        entertaiments.highlightHovered = true
        addSubview(entertaiments)
        
        addHoverObserver()
        addClickObserver()
        entertaiments.canHighlight = false
        
        
        
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        send.set(image: theme.icons.chatSendMessage, for: .Normal)
        _ = send.sizeToFit()
        voice.set(image: FastSettings.recordingState == .voice ? theme.icons.chatRecordVoice : theme.icons.chatRecordVideo, for: .Normal)
        _ = voice.sizeToFit()
        
        let muted = FastSettings.isChannelMessagesMuted(chatInteraction.peerId)
        muteChannelMessages.set(image: !muted ? theme.icons.inputChannelMute : theme.icons.inputChannelUnmute, for: .Normal)
        _ = muteChannelMessages.sizeToFit()
        
        
        updateEntertainmentIcon()
        
        keyboard.set(image: theme.icons.chatActiveReplyMarkup, for: .Normal)
        _ = keyboard.sizeToFit()
        inlineCancel.set(image: theme.icons.chatInlineDismiss, for: .Normal)
        _ = inlineCancel.sizeToFit()
        secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)

    }
    
    private func updateEntertainmentIcon() {
        entertaiments.set(image: chatInteraction.presentation.isEmojiSection || chatInteraction.presentation.state == .editing ? theme.icons.chatEntertainment : theme.icons.chatEntertainmentSticker, for: .Normal)
        _ = entertaiments.sizeToFit()
    }
    
    var entertaimentsPopover: ViewController {
        if chatInteraction.presentation.state == .editing {
            let emoji = EmojiViewController(chatInteraction.account)
            if let interactions = chatInteraction.account.context.entertainment.interactions {
                emoji.update(with: interactions)
            }
            return emoji
        }
        return chatInteraction.account.context.entertainment
    }
    
    private func addHoverObserver() {
        
        entertaiments.set(handler: { [weak self] (state) in
            guard let `self` = self else {return}
            let chatInteraction = self.chatInteraction
            var enabled = false
            
            if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled {
                enabled = sidebarEnabled
            }
            if !((mainWindow.frame.width >= 1100 && chatInteraction.account.context.layout == .dual) || (mainWindow.frame.width >= 880 && chatInteraction.account.context.layout == .minimisize)) || !enabled {
                if !hasPopover(mainWindow) {
                    self.showEntertainment()
                }
                
            }
        }, for: .Hover)
    }
    
    private func showEntertainment() {
        let rect = NSMakeRect(0, 0, 350, floor(mainWindow.frame.height - 150))
        entertaimentsPopover._frameRect = rect
        entertaimentsPopover.view.frame = rect
        showPopover(for: entertaiments, with: entertaimentsPopover, edge: .maxX, inset:NSMakePoint(frame.width - entertaiments.frame.maxX + 15, 10), delayBeforeShown: 0.0)
    }
    
    private func addClickObserver() {
        entertaiments.set(handler: { [weak self] (state) in
            if let strongSelf = self {
                let chatInteraction = strongSelf.chatInteraction
                if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled, sidebarEnabled {
                    if mainWindow.frame.width >= 1100 && chatInteraction.account.context.layout == .dual || mainWindow.frame.width >= 880 && chatInteraction.account.context.layout == .minimisize {
                        
                        chatInteraction.toggleSidebar()
                    }
                }
            }
        }, for: .Click)
    }
    
    
    func toggleKeyboard() {
        let keyboardId = chatInteraction.presentation.keyboardButtonsMessage?.id
        chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedMessageActionsState({ actions in
            let nid = actions.closedButtonKeyboardMessageId != nil ? nil : keyboardId
            return actions.withUpdatedClosedButtonKeyboardMessageId(nid)
        })})})
    }
    
    override func layout() {
        super.layout()
        inlineCancel.centerY(x:frame.width - inlineCancel.frame.width - iconsInset)
        inlineProgress?.centerY(x: frame.width - inlineCancel.frame.width - iconsInset - 4)
        voice.centerY(x:frame.width - voice.frame.width - iconsInset)
        send.centerY(x: frame.width - send.frame.width - iconsInset)
        entertaiments.centerY(x: voice.frame.minX - entertaiments.frame.width - iconsInset)
        secretTimer?.centerY(x: entertaiments.frame.minX - keyboard.frame.width - iconsInset)
        keyboard.centerY(x: entertaiments.frame.minX - keyboard.frame.width - iconsInset)
        muteChannelMessages.centerY(x: entertaiments.frame.minX - muteChannelMessages.frame.width - iconsInset)
        
    }
    
    func stop() {

        let chatInteraction = self.chatInteraction
        if let recorder = chatInteraction.presentation.recordingState {
            if canSend {
                recorder.stop()
                chatInteraction.mediaPromise.set(recorder.data)
            } else {
                recorder.dispose()
            }
            closeAllModals()
        }
         chatInteraction.update({$0.withoutRecordingState()})
       
    }
    
    var canSend:Bool {
        if let superview = superview, let window = window {
            let mouse = superview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let inside = NSPointInRect(mouse, superview.frame)
            return inside
        }
        return false
    }
    
    
    private var first:Bool = true
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value.interfaceState != oldValue.interfaceState || value.interfaceState.editState != oldValue.interfaceState.editState || !animated || value.inputQueryResult != oldValue.inputQueryResult || value.inputContext != oldValue.inputContext || value.sidebarEnabled != oldValue.sidebarEnabled || value.sidebarShown != oldValue.sidebarShown || value.layout != oldValue.layout {
            
                var size:NSSize = NSMakeSize(send.frame.width + iconsInset + entertaiments.frame.width + iconsInset * 2, frame.height)
                
                if chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
                    size.width += theme.icons.chatSecretTimer.backingSize.width + iconsInset
                }
              
                if let peer = value.peer {
                    muteChannelMessages.isHidden = !peer.isChannel || !peer.canSendMessage
                }
                
                if !muteChannelMessages.isHidden {
                    size.width += muteChannelMessages.frame.width + iconsInset
                }
                
                var newInlineRequest = value.inputQueryResult != oldValue.inputQueryResult
                var oldInlineRequest = newInlineRequest
                var newInlineLoading: Bool = false
                var oldInlineLoading: Bool = false
                
                if let query = value.inputQueryResult, case .contextRequestResult(_, let data) = query {
                    newInlineLoading = data == nil
                }
                
                if let query = value.inputQueryResult, case .contextRequestResult = query, newInlineRequest || first {
                    newInlineRequest = true
                } else {
                    newInlineRequest = false
                }
                
                
                
                
                if let query = oldValue.inputQueryResult, case .contextRequestResult(_, let data) = query {
                    oldInlineLoading = data == nil
                }
                
                
                if let query = oldValue.inputQueryResult, case .contextRequestResult = query, oldInlineRequest || first {
                    oldInlineRequest = true
                } else {
                    oldInlineRequest = false
                }
                
                let sNew = !value.effectiveInput.inputText.isEmpty || !value.interfaceState.forwardMessageIds.isEmpty || value.state == .editing
                let sOld = !oldValue.effectiveInput.inputText.isEmpty || !oldValue.interfaceState.forwardMessageIds.isEmpty || oldValue.state == .editing
                
                let anim = animated && (sNew != sOld || newInlineRequest != oldInlineRequest)
                if sNew != sOld || first || newInlineRequest != oldInlineRequest || oldInlineLoading != newInlineLoading {
                    first = false
                    
                    let prevView:View
                    let newView:View
                    
                    if newInlineRequest {
                        prevView = !sOld ? voice : send
                        newView = inlineCancel
                    } else if oldInlineRequest {
                        prevView = inlineCancel
                        newView = sNew ? send : voice
                    } else {
                        prevView = sNew ? voice : send
                        newView = sNew ? send : voice
                    }

                    
                    newView.isHidden = false
                    newView.layer?.opacity = 1.0
                    prevView.layer?.opacity = 0.0
                    if anim {
                        newView.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        newView.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.6)
                        prevView.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion:{ complete in
                            if complete {
                                prevView.isHidden = true
                            }
                        })
                    } else {
                        prevView.isHidden = true
                    }
                }
                
                inlineCancel.isHidden = inlineCancel.isHidden || newInlineLoading
               
                if newInlineLoading {
                    if inlineProgress == nil {
                        inlineProgress = ProgressIndicator(frame: NSMakeRect(0, 0, 25, 25))
                        inlineProgress?.progressColor = theme.colors.grayIcon
                        addSubview(inlineProgress!, positioned: .below, relativeTo: inlineCancel)
                        inlineProgress?.set(handler: { [weak self] _ in
                            if let inputContext = self?.chatInteraction.presentation.inputContext, case let .contextRequest(request) = inputContext {
                                if request.query.isEmpty {
                                    self?.chatInteraction.clearInput()
                                } else {
                                    self?.chatInteraction.clearContextQuery()
                                }
                            }
                        }, for: .Click)
                    }
                } else {
                    inlineProgress?.removeFromSuperview()
                    inlineProgress = nil
                }
       
                entertaiments.apply(state: .Normal)
                entertaiments.isSelected = value.isShowSidebar || (chatInteraction.account.context.entertainment.popover?.isShown ?? false)
                
                keyboard.isHidden = !value.isKeyboardActive
                
                if let keyboardMessage = value.keyboardButtonsMessage {
                   // if value.state == .normal && (value.effectiveInput.inputText.isEmpty || value.isKeyboardShown) {
                        size.width += keyboard.frame.width + iconsInset
                   // }
                    if let closedId = value.interfaceState.messageActionsState.closedButtonKeyboardMessageId, closedId == keyboardMessage.id {
                        self.keyboard.set(image: theme.icons.chatDisabledReplyMarkup, for: .Normal)
                    } else {
                        self.keyboard.set(image: theme.icons.chatActiveReplyMarkup, for: .Normal)
                    }

                }
                self.change(size: size, animated: false)
                
                updateEntertainmentIcon()
                
                self.needsLayout = true
            } else if value.isEmojiSection != oldValue.isEmojiSection {
                updateEntertainmentIcon()
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ChatInputActionsView {
            return self == other
        }
        return false
    }
    
    deinit {
        chatInteraction.remove(observer: self)
    }
    
    func prepare(with chatInteraction:ChatInteraction) -> Void {
        send.set(handler: { _ in
            chatInteraction.sendMessage()
        }, for: .Click)
        
        chatInteraction.add(observer: self)
        notify(with: chatInteraction.presentation, oldValue: chatInteraction.presentation, animated: false)
        
        if chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
            secretTimer = ImageButton()
            secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)
            _ = secretTimer?.sizeToFit()
            addSubview(secretTimer!)
            
            secretTimer?.set(handler: { [weak self] control in
                if let strongSelf = self {
                    showPopover(for: control, with: SPopoverViewController(items:strongSelf.secretTimerItems(), visibility: 6), edge: .maxX, inset:NSMakePoint(120, 10))
                }
            }, for: .Click)
        }
    }
    
    func performSendMessage() {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func secretTimerItems() -> [SPopoverItem] {
        
        var items:[SPopoverItem] = []
        
        if let peer = chatInteraction.presentation.peer as? TelegramSecretChat {
            if peer.messageAutoremoveTimeout != nil {
                
                items.append(SPopoverItem(tr(L10n.secretTimerOff), { [weak self] in
                    self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(nil)
                }))
            }
        }
        
        
        for i in 0 ..< 30 {
            
            items.append(SPopoverItem(tr(L10n.timerSecondsCountable(i + 1)), { [weak self] in
                self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(Int32(i + 1))
            }))
        }
        
        items.append(SPopoverItem(tr(L10n.timerMinutesCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60)
        }))
        
        items.append(SPopoverItem(tr(L10n.timerHoursCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60 * 60)
        }))
        
        items.append(SPopoverItem(tr(L10n.timerDaysCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60 * 60 * 24)
        }))
        
        items.append(SPopoverItem(tr(L10n.timerWeeksCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60 * 60 * 24 * 7)
        }))
        
        return items
    }
    
    
}
