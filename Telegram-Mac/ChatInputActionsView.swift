//
//  ChatInputActionsView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit


//
let iconsInset:CGFloat = 20.0

class ChatInputActionsView: View {
    
    let chatInteraction:ChatInteraction
    private let send:ImageButton = ImageButton()
    private let voice:ImageButton = ImageButton()
    private let muteChannelMessages:ImageButton = ImageButton()
    let entertaiments:ImageButton = ImageButton()
    private let slowModeTimeout:TitleButton = TitleButton()
    private let inlineCancel:ImageButton = ImageButton()
    private let keyboard:ImageButton = ImageButton()
    private var scheduled:ImageButton?

    private var secretTimer:ImageButton?
    private var inlineProgress: ProgressIndicator? = nil
    
    private var prevView: View
    
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        self.prevView = self.send
        super.init(frame: frameRect)
        
        keyboard.autohighlight = false
        
        addSubview(keyboard)
        addSubview(send)
        addSubview(voice)
        addSubview(inlineCancel)
        addSubview(muteChannelMessages)
        addSubview(slowModeTimeout)
        inlineCancel.isHidden = true
        send.isHidden = true
        voice.isHidden = true
        muteChannelMessages.isHidden = true
        slowModeTimeout.isHidden = true
        voice.autohighlight = false
        muteChannelMessages.autohighlight = false
        send.autohighlight = false
        
        voice.set(handler: { [weak self] _ in
            guard let `self` = self else { return }
            
            FastSettings.toggleRecordingState()
            
            self.voice.set(image: FastSettings.recordingState == .voice ? theme.icons.chatRecordVoice : theme.icons.chatRecordVideo, for: .Normal)
            
            getAppTooltip(for: FastSettings.recordingState == .voice ? .voiceRecording : .videoRecording, callback: { value in
                tooltip(for: self.voice, text: value)
            })
            
        }, for: .Click)
        
        
        voice.set(handler: { [weak self] control in
            self?.chatInteraction.startRecording(false, control)
        }, for: .LongMouseDown)

        
        muteChannelMessages.set(handler: { [weak self] _ in
            if let chatInteraction = self?.chatInteraction {
                FastSettings.toggleChannelMessagesMuted(chatInteraction.peerId)
                (self?.superview?.superview as? View)?.updateLocalizationAndTheme(theme: theme)
            }
        }, for: .Click)


        keyboard.set(handler: { [weak self] _ in
            self?.toggleKeyboard()
        }, for: .Up)
        
        inlineCancel.set(handler: { [weak self] _ in
            if let inputContext = self?.chatInteraction.presentation.inputContext, case let .contextRequest(_, query) = inputContext {
                if query.isEmpty {
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
        muteChannelMessages.hideAnimated = false
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        send.set(image: self.chatInteraction.presentation.state == .editing ? theme.icons.chatSaveEditedMessage : theme.icons.chatSendMessage, for: .Normal)
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
        
        
        if let timeout = chatInteraction.presentation.messageSecretTimeout?.timeout?.effectiveValue {
            secretTimer?.set(image: theme.chat.messageSecretTimer(shortTimeIntervalString(value: timeout)), for: .Normal)
        } else {
            secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)
        }
        
        
        scheduled?.set(image: theme.icons.chatInputScheduled, for: .Normal)

        
        slowModeTimeout.set(font: .normal(.text), for: .Normal)
        slowModeTimeout.set(color: theme.colors.grayIcon, for: .Normal)
        _ = self.slowModeTimeout.sizeToFit(NSZeroSize, NSMakeSize(38, 30), thatFit: true)

    }
    
    private func updateEntertainmentIcon() {
        entertaiments.set(image: chatInteraction.presentation.isEmojiSection || chatInteraction.presentation.state == .editing ? theme.icons.chatEntertainment : theme.icons.chatEntertainmentSticker, for: .Normal)
        entertaiments.setFrameSize(60, 40)
    }
    
    var entertaimentsPopover: ViewController {
        if chatInteraction.presentation.state == .editing {
            let emoji = EmojiesController(chatInteraction.context)
            if let interactions = chatInteraction.context.bindings.entertainment().interactions {
                emoji.update(with: interactions, chatInteraction: chatInteraction)
            }
            return emoji
        }
        return chatInteraction.context.bindings.entertainment()
    }
    
    private func addHoverObserver() {
        
        entertaiments.set(handler: { [weak self] (state) in
            guard let `self` = self else {return}
            let chatInteraction = self.chatInteraction
            
            let context = chatInteraction.context
            let navigation = context.bindings.rootNavigation()
            NSLog("\(navigation.frame.width), \(context.layout == .dual)")
            if (navigation.frame.width <= 730 && context.layout == .dual) || !FastSettings.sidebarEnabled {
                self.showEntertainment()
            }
        }, for: .Hover)
    }
    
    private func showEntertainment() {
        let rect = NSMakeRect(0, 0, 350, min(max(chatInteraction.context.window.frame.height - 250, 300), 550))
        entertaimentsPopover._frameRect = rect
        entertaimentsPopover.view.frame = rect
        showPopover(for: entertaiments, with: entertaimentsPopover, edge: .maxX, inset:NSMakePoint(frame.width - entertaiments.frame.maxX + 38, 10), delayBeforeShown: 0.1)
    }
    
    private func addClickObserver() {
        entertaiments.set(handler: { [weak self] (state) in
            if let strongSelf = self {
                let chatInteraction = strongSelf.chatInteraction
                let navigation = chatInteraction.context.bindings.rootNavigation()
                if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled, sidebarEnabled {
                    if navigation.frame.width > 730 && chatInteraction.context.layout == .dual {
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
        self.updateLayout(size: self.frame.size, transition: .immediate)
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
    
    var currentActionView: NSView {
        if !self.send.isHidden {
            return self.send
        } else if !self.voice.isHidden {
            return self.voice
        } else if !self.slowModeTimeout.isHidden {
            return self.slowModeTimeout
        } else {
            return self
        }
    }
    
    
    private var first:Bool = true
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value.interfaceState != oldValue.interfaceState || !animated || value.inputQueryResult != oldValue.inputQueryResult || value.inputContext != oldValue.inputContext || value.sidebarEnabled != oldValue.sidebarEnabled || value.sidebarShown != oldValue.sidebarShown || value.layout != oldValue.layout || value.isKeyboardActive != oldValue.isKeyboardActive || value.isKeyboardShown != oldValue.isKeyboardShown || value.slowMode != oldValue.slowMode || value.hasScheduled != oldValue.hasScheduled || value.messageSecretTimeout != oldValue.messageSecretTimeout {

                if chatInteraction.hasSetDestructiveTimer {
                    if secretTimer == nil {
                        secretTimer = ImageButton()
                        secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)
                        _ = secretTimer?.sizeToFit()
                        addSubview(secretTimer!)

                        if let peer = self.chatInteraction.peer {
                            if peer.isSecretChat {
                                secretTimer?.contextMenu = { [weak self] in
                                    let menu = ContextMenu()
                                    
                                    if let items = self?.secretTimerItems() {
                                        for item in items {
                                            menu.addItem(item)
                                        }
                                    }
                                    return menu
                                }
                            } else {
                                secretTimer?.set(handler: { [weak self] control in
                                    self?.chatInteraction.showDeleterSetup(control)
                                }, for: .Click)
                            }
                        }
                    }
                } else if let view = secretTimer {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    secretTimer = nil
                }


                send.animates = false
                send.set(image: value.state == .editing ? theme.icons.chatSaveEditedMessage : theme.icons.chatSendMessage, for: .Normal)
                send.animates = true
                
                if let timeout = value.messageSecretTimeout?.timeout?.effectiveValue {
                    secretTimer?.set(image: theme.chat.messageSecretTimer(shortTimeIntervalString(value: timeout)), for: .Normal)
                } else {
                    secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)
                }
              
                if let peer = value.peer {
                    muteChannelMessages.isHidden = !peer.isChannel || !peer.canSendMessage(value.chatMode.isThreadMode) || !value.effectiveInput.inputText.isEmpty || value.interfaceState.editState != nil
                }
                
                var newInlineRequest = value.inputQueryResult != oldValue.inputQueryResult
                var oldInlineRequest = newInlineRequest
                var newInlineLoading: Bool = false
                var oldInlineLoading: Bool = false
                
                if let query = value.inputQueryResult, case let .contextRequestResult(peer, data) = query {
                    if let address = peer.addressName, "@\(address)" != value.effectiveInput.inputText {
                        newInlineLoading = data == nil
                    } else {
                        newInlineLoading = false
                    }
                }
                
                
                if let query = value.inputQueryResult, case .contextRequestResult = query, newInlineRequest || first {
                    newInlineRequest = true
                } else {
                    newInlineRequest = false
                }
                

                
                if let query = oldValue.inputQueryResult, case let .contextRequestResult(peer, data) = query {
                    if let address = peer.addressName, "@\(address)" != oldValue.effectiveInput.inputText {
                        oldInlineLoading = data == nil
                    } else {
                        oldInlineLoading = false
                    }
                }
                
                let newSlowModeCounter: Bool = value.slowMode?.timeout != nil && value.interfaceState.editState == nil && !newInlineLoading && !newInlineRequest
                let oldSlowModeCounter: Bool = oldValue.slowMode?.timeout != nil && oldValue.interfaceState.editState == nil && !oldInlineLoading && !oldInlineRequest
                
                
                if let query = oldValue.inputQueryResult, case .contextRequestResult = query, oldInlineRequest || first {
                    oldInlineRequest = true
                } else {
                    oldInlineRequest = false
                }
                
                
                let sNew = !value.effectiveInput.inputText.isEmpty || !value.interfaceState.forwardMessageIds.isEmpty || value.state == .editing
                let sOld = !oldValue.effectiveInput.inputText.isEmpty || !oldValue.interfaceState.forwardMessageIds.isEmpty || oldValue.state == .editing
                
                if sNew != sOld || first || newInlineRequest != oldInlineRequest || oldInlineLoading != newInlineLoading || newSlowModeCounter != oldSlowModeCounter {
                    first = false
                    
                    let prevView:View = self.prevView
                    let newView:View
                    
                    if newSlowModeCounter {
                        newView = slowModeTimeout
                    } else if newInlineRequest {
                        newView = inlineCancel
                    } else if oldInlineRequest {
                        newView = sNew ? send : voice
                    } else {
                        newView = sNew ? send : voice
                    }

                    self.prevView = newView
                    
                    let anim = animated && prevView != newView
                    
                    newView.isHidden = false
                    newView.layer?.opacity = 1.0
                    prevView.layer?.opacity = 0.0
                    if anim {
                        newView.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        newView.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.6)
                        prevView.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion:{ [weak prevView] complete in
                            if complete {
                                prevView?.isHidden = true
                            }
                        })
                    } else if prevView != newView {
                        prevView.isHidden = true
                    } else {
                        prevView.isHidden = false
                        prevView.layer?.opacity = 1.0
                    }
                }
                
                inlineCancel.isHidden = inlineCancel.isHidden || newInlineLoading
               
                if newInlineLoading {
                    if inlineProgress == nil {
                        inlineProgress = ProgressIndicator(frame: NSMakeRect(0, 0, 22, 22))
                        inlineProgress?.progressColor = theme.colors.grayIcon
                        addSubview(inlineProgress!, positioned: .below, relativeTo: inlineCancel)
                        inlineProgress?.set(handler: { [weak self] _ in
                            if let inputContext = self?.chatInteraction.presentation.inputContext, case let .contextRequest(_, query) = inputContext {
                                if query.isEmpty {
                                    self?.chatInteraction.clearInput()
                                } else {
                                    self?.chatInteraction.clearContextQuery()
                                }
                            }
                        }, for: .Click)
                    }
                } else if let view = inlineProgress {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    inlineProgress = nil
                }
       
                entertaiments.apply(state: .Normal)
                entertaiments.isSelected = value.isShowSidebar 
                
                keyboard.isHidden = !value.isKeyboardActive
                
                if let keyboardMessage = value.keyboardButtonsMessage {
                    if let closedId = value.interfaceState.messageActionsState.closedButtonKeyboardMessageId, closedId == keyboardMessage.id {
                        self.keyboard.set(image: theme.icons.chatDisabledReplyMarkup, for: .Normal)
                    } else {
                        self.keyboard.set(image: theme.icons.chatActiveReplyMarkup, for: .Normal)
                    }

                }
                if let slowMode = value.slowMode, let timeout = slowMode.timeout, timeout >= 0 {
                    let minutes = timeout / 60
                    let seconds = timeout % 60
                    let string = String(format: "%@:%@", minutes < 10 ? "0\(minutes)" : "\(minutes)", seconds < 10 ? "0\(seconds)" : "\(seconds)")
                    self.slowModeTimeout.set(text: string, for: .Normal)
                }
                
                if value.hasScheduled && value.effectiveInput.inputText.isEmpty && value.interfaceState.editState == nil {
                    if scheduled == nil {
                        scheduled = ImageButton()
                        scheduled!.set(image: theme.icons.chatInputScheduled, for: .Normal)
                        _ = scheduled!.sizeToFit()
                        addSubview(scheduled!)
                        scheduled?.centerY(x: 0)
                    }
                    scheduled?.removeAllHandlers()
                    scheduled?.set(handler: { [weak self] _ in
                        self?.chatInteraction.openScheduledMessages()
                    }, for: .Click)
                } else if let view = scheduled {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    scheduled = nil
                }
                updateEntertainmentIcon()
                
                updateLayout(size: frame.size, transition: .immediate)
                
            } else if value.isEmojiSection != oldValue.isEmojiSection {
                updateEntertainmentIcon()
                updateLayout(size: frame.size, transition: .immediate)
            }
        }
    }
    
    func size(_ value: ChatPresentationInterfaceState) -> NSSize {
        
        
        var size:NSSize = NSMakeSize(send.frame.width + iconsInset + entertaiments.frame.width, frame.height)
        
        if chatInteraction.hasSetDestructiveTimer {
            size.width += theme.icons.chatSecretTimer.backingSize.width + iconsInset
        }
        if chatInteraction.presentation.keyboardButtonsMessage != nil {
            size.width += keyboard.frame.width + iconsInset
        }
        if let peer = chatInteraction.presentation.peer {
            let hasMute = !(!peer.isChannel || !peer.canSendMessage(value.chatMode.isThreadMode) || !value.effectiveInput.inputText.isEmpty || value.interfaceState.editState != nil)
            if hasMute {
                size.width += muteChannelMessages.frame.width
            }
        }
        if value.hasScheduled && value.effectiveInput.inputText.isEmpty && value.interfaceState.editState == nil {
            size.width += theme.icons.chatInputScheduled.backingSize.width + iconsInset + (muteChannelMessages.isHidden ? 0 : iconsInset)
        }
        return size
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: inlineCancel, frame: inlineCancel.centerFrameY(x: size.width - inlineCancel.frame.width - iconsInset - 6))
        
        if let view = inlineProgress {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: size.width - inlineCancel.frame.width - iconsInset - 10))
        }
        transition.updateFrame(view: voice, frame: voice.centerFrameY(x: size.width - voice.frame.width - iconsInset))
        transition.updateFrame(view: send, frame: send.centerFrameY(x: size.width - send.frame.width - iconsInset))
        transition.updateFrame(view: slowModeTimeout, frame: slowModeTimeout.centerFrameY(x: size.width - slowModeTimeout.frame.width - iconsInset))
        transition.updateFrame(view: entertaiments, frame: entertaiments.centerFrameY(x: voice.frame.minX - entertaiments.frame.width - 0))
        transition.updateFrame(view: keyboard, frame: keyboard.centerFrameY(x: entertaiments.frame.minX - keyboard.frame.width))
        transition.updateFrame(view: muteChannelMessages, frame: muteChannelMessages.centerFrameY(x: entertaiments.frame.minX - muteChannelMessages.frame.width))

        
        if let scheduled = scheduled {
            if muteChannelMessages.isHidden {
                transition.updateFrame(view: scheduled, frame: scheduled.centerFrameY(x: (keyboard.isHidden ? entertaiments.frame.minX : keyboard.frame.minX) - scheduled.frame.width))
            } else {
                transition.updateFrame(view: scheduled, frame: scheduled.centerFrameY(x: muteChannelMessages.frame.minX - scheduled.frame.width - iconsInset))
            }
        }
        
        let views = [inlineCancel,
         inlineProgress,
         voice,
         send,
         slowModeTimeout,
         entertaiments,
         keyboard,
         muteChannelMessages,
         scheduled].filter { $0 != nil && !$0!.isHidden }.map { $0! }
        
        let minView = views.min(by: { $0.frame.minX < $1.frame.minX })
        if let minView = minView, let secretTimer = secretTimer {
            if minView == entertaiments {
                transition.updateFrame(view: secretTimer, frame: secretTimer.centerFrameY(x: minView.frame.minX - secretTimer.frame.width))
            } else {
                transition.updateFrame(view: secretTimer, frame: secretTimer.centerFrameY(x: minView.frame.minX - secretTimer.frame.width - iconsInset))
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
        
    }
    
    func prepare(with chatInteraction:ChatInteraction) -> Void {
        

        
        send.contextMenu = { [weak chatInteraction] in
            
            
            if let chatInteraction = chatInteraction, let peer = chatInteraction.peer {
                let context = chatInteraction.context
                if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                    return nil
                }
                if chatInteraction.presentation.state != .normal {
                    return nil
                }
                var items:[ContextMenuItem] = []
                
                if peer.id != chatInteraction.context.account.peerId {
                    items.append(ContextMenuItem(strings().chatSendWithoutSound, handler: { [weak chatInteraction] in
                        chatInteraction?.sendMessage(true, nil)
                    }, itemImage: MenuAnimation.menu_mute.value))
                }
                switch chatInteraction.mode {
                case .history, .thread:
                    if !peer.isSecretChat {
                        let text = peer.id == chatInteraction.context.peerId ? strings().chatSendSetReminder : strings().chatSendScheduledMessage
                        items.append(ContextMenuItem(text, handler: {
                            showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak chatInteraction] date in
                                chatInteraction?.sendMessage(false, date)
                            }), for: context.window)
                        }, itemImage: MenuAnimation.menu_schedule_message.value))
                    }
                default:
                    break
                }
                if !items.isEmpty {
                    let menu = ContextMenu()
                    for item in items {
                        menu.addItem(item)
                    }
                    return menu
                }
            }
            return nil
        }
        
        send.set(handler: { [weak chatInteraction] control in
             chatInteraction?.sendMessage(false, nil)
        }, for: .Click)
        
        slowModeTimeout.set(handler: { [weak chatInteraction] control in
            if let slowMode = chatInteraction?.presentation.slowMode {
                showSlowModeTimeoutTooltip(slowMode, for: control)
            }
        }, for: .Click)
                

        
        notify(with: chatInteraction.presentation, oldValue: chatInteraction.presentation, animated: false)
    }
    
    func performSendMessage() {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func secretTimerItems() -> [ContextMenuItem] {
        
        var items:[ContextMenuItem] = []
        
        if chatInteraction.hasSetDestructiveTimer {
            if chatInteraction.presentation.messageSecretTimeout != nil {
                items.append(ContextMenuItem(strings().secretTimerOff, handler: { [weak self] in
                    self?.chatInteraction.setChatMessageAutoremoveTimeout(nil)
                }))
            }
        }
        if chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
            for i in 0 ..< 30 {
                items.append(ContextMenuItem(strings().timerSecondsCountable(i + 1), handler: { [weak self] in
                    self?.chatInteraction.setChatMessageAutoremoveTimeout(Int32(i + 1))
                }))
            }

            items.append(ContextMenuItem(strings().timerMinutesCountable(1), handler: { [weak self] in
                self?.chatInteraction.setChatMessageAutoremoveTimeout(60)
            }))

            items.append(ContextMenuItem(strings().timerHoursCountable(1), handler: { [weak self] in
                self?.chatInteraction.setChatMessageAutoremoveTimeout(60 * 60)
            }))

            items.append(ContextMenuItem(strings().timerDaysCountable(1), handler: { [weak self] in
                self?.chatInteraction.setChatMessageAutoremoveTimeout(60 * 60 * 24)
            }))

            items.append(ContextMenuItem(strings().timerWeeksCountable(1), handler: { [weak self] in
                self?.chatInteraction.setChatMessageAutoremoveTimeout(60 * 60 * 24 * 7)
            }))
        }

        
        return items
    }
    
    
}
