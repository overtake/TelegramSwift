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


final class StarsSendActionView : Control {
    let text: TextView = TextView()
    let image: ImageView = ImageView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(text)
        addSubview(image)
        
        text.userInteractionEnabled = false
        text.isSelectable = false
        
        image.isEventLess = true
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(price: Int64, context: AccountContext, animated: Bool) {
        self.backgroundColor = theme.colors.accent
        
        self.scaleOnClick = true
        
        let layout = TextViewLayout(.initialize(string: price.prettyNumber, color: theme.colors.underSelectedColor, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        
        text.update(layout)
        
        image.image = NSImage(resource: .starSmall).precomposed(theme.colors.underSelectedColor)
        image.sizeToFit()
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        setFrameSize(NSMakeSize(text.frame.width + 12 + image.frame.width, 24))
        
        layer?.cornerRadius = frame.height / 2
    }
    
    override func layout() {
        super.layout()
        image.centerY(x: 5)
        
        text.centerY(x: image.frame.maxX + 2)
    }
}

//
let iconsInset:CGFloat = 20

class ChatInputActionsView: View {
    
    let chatInteraction:ChatInteraction
    private let send:ImageButton = ImageButton()
    private let voice:ImageButton = ImageButton()
    private let muteChannelMessages:ImageButton = ImageButton()
    let entertaiments:ImageButton = ImageButton()
    private let slowModeTimeout:TextButton = TextButton()
    private let inlineCancel:ImageButton = ImageButton()
    private let keyboard:ImageButton = ImageButton()
    private let gift:ImageButton = ImageButton()
    private let suggestPost:ImageButton = ImageButton()

    private var scheduled:ImageButton?
    
    private var sendPaidMessages: StarsSendActionView?

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
        
        addSubview(gift)
        addSubview(suggestPost)

        
        inlineCancel.isHidden = true
        send.isHidden = true
        voice.isHidden = true
        suggestPost.isHidden = true
        muteChannelMessages.isHidden = true
        slowModeTimeout.isHidden = true
        
        voice.autohighlight = false
        muteChannelMessages.autohighlight = false
        send.autohighlight = false
        gift.autohighlight = false
        suggestPost.autohighlight = false

        send.scaleOnClick = true
        muteChannelMessages.scaleOnClick = true
        slowModeTimeout.scaleOnClick = true
        inlineCancel.scaleOnClick = true
        gift.scaleOnClick = true
        suggestPost.scaleOnClick = true
        
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

        
        muteChannelMessages.set(handler: { [weak self] control in
            if let chatInteraction = self?.chatInteraction {
                FastSettings.toggleChannelMessagesMuted(chatInteraction.peerId)
                let isMuted = FastSettings.isChannelMessagesMuted(chatInteraction.peerId)
                (self?.superview?.superview as? ChatInputView)?.updatePlaceholder()
                tooltip(for: control, text: isMuted ? strings().messagesSilentTooltipSilent : strings().messagesSilentTooltip)
            }
        }, for: .Click)


        keyboard.set(handler: { [weak self] _ in
            self?.toggleKeyboard()
        }, for: .Up)
        
        gift.set(handler: { [weak self] _ in
            self?.chatInteraction.sendGift()
        }, for: .Up)
        
        suggestPost.set(handler: { [weak self] _ in
            self?.chatInteraction.suggestPost()
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
        
        gift.set(image: theme.icons.chat_input_send_gift, for: .Normal)
        _ = gift.sizeToFit()
        
        suggestPost.set(image: theme.icons.chat_input_suggest_post, for: .Normal)
        _ = suggestPost.sizeToFit()

        
        inlineCancel.set(image: theme.icons.chatInlineDismiss, for: .Normal)
        _ = inlineCancel.sizeToFit()
        
        
        if let timeout = chatInteraction.presentation.messageSecretTimeout?.timeout?.effectiveValue {
            secretTimer?.set(image: theme.chat.messageSecretTimer(shortTimeIntervalString(value: timeout)), for: .Normal)
        } else {
            secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)
        }
        
        
        scheduled?.set(image: theme.icons.chatInputScheduled, for: .Normal)

        
    }
    
    private func updateEntertainmentIcon() {
        entertaiments.set(image: chatInteraction.presentation.isEmojiSection || chatInteraction.presentation.state == .editing ? theme.icons.chatEntertainment : theme.icons.chatEntertainmentSticker, for: .Normal)
        entertaiments.setFrameSize(60, 40)
    }
    
    var entertaimentsPopover: ViewController {
        if chatInteraction.presentation.state == .editing || chatInteraction.mode.customChatLink != nil {
            let emoji = EmojiesController(chatInteraction.context)
            if let interactions = chatInteraction.context.bindings.entertainment().interactions {
                emoji.update(with: interactions, chatInteraction: chatInteraction)
            }
            return emoji
        }
        let controller = chatInteraction.context.bindings.entertainment()
        controller.update(with: chatInteraction)
        return controller
    }
    
    private func addHoverObserver() {
        
        entertaiments.set(handler: { [weak self] (state) in
            guard let `self` = self else {return}
            let chatInteraction = self.chatInteraction
            
            let context = chatInteraction.context
            let navigation = context.bindings.rootNavigation()
            if (navigation.frame.width <= 730) || !FastSettings.sidebarEnabled {
                self.showEntertainment()
            }
        }, for: .Hover)
    }
    
    private func showEntertainment() {
        let rect = NSMakeRect(0, 0, 350, min(max(chatInteraction.context.window.frame.height - 250, 300), 550))
        entertaimentsPopover._frameRect = rect
        entertaimentsPopover.view.frame = rect
        showPopover(for: entertaiments, with: entertaimentsPopover, edge: .maxX, inset:NSMakePoint(frame.width - entertaiments.frame.maxX + 38, 10), delayBeforeShown: 0.0)
    }
    
    private func addClickObserver() {
        entertaiments.set(handler: { [weak self] (state) in
            if let strongSelf = self {
                let chatInteraction = strongSelf.chatInteraction
                let navigation = chatInteraction.context.bindings.rootNavigation()
                if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled, sidebarEnabled {
                    if navigation.frame.width > 730 {
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
        if let sendPaidMessages {
            return sendPaidMessages
        } else if !self.send.isHidden {
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
            if value.interfaceState != oldValue.interfaceState || !animated || value.inputQueryResult != oldValue.inputQueryResult || value.inputContext != oldValue.inputContext || value.sidebarEnabled != oldValue.sidebarEnabled || value.sidebarShown != oldValue.sidebarShown || value.layout != oldValue.layout || value.isKeyboardActive != oldValue.isKeyboardActive || value.isKeyboardShown != oldValue.isKeyboardShown || value.slowMode != oldValue.slowMode || value.hasScheduled != oldValue.hasScheduled || value.messageSecretTimeout != oldValue.messageSecretTimeout || value.boostNeed != oldValue.boostNeed || value.restrictedByBoosts != oldValue.restrictedByBoosts || value.interfaceState.messageEffect != oldValue.interfaceState.messageEffect || value.sendPaidMessageStars != oldValue.sendPaidMessageStars || value.hasGift != oldValue.hasGift || value.allowPostSuggestion != oldValue.allowPostSuggestion || value.interfaceState.suggestPost != oldValue.interfaceState.suggestPost {

                if chatInteraction.hasSetDestructiveTimer, value.interfaceState.messageEffect == nil {
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
                
                let newSlowModeCounter: Bool = ((value.slowMode?.timeout != nil && !value.restrictedByBoosts) || value.boostNeed > 0) && value.interfaceState.editState == nil && !newInlineLoading && !newInlineRequest
                let oldSlowModeCounter: Bool = ((oldValue.slowMode?.timeout != nil && !oldValue.restrictedByBoosts ) || oldValue.boostNeed > 0) && oldValue.interfaceState.editState == nil && !oldInlineLoading && !oldInlineRequest
                
                
                if let query = oldValue.inputQueryResult, case .contextRequestResult = query, oldInlineRequest || first {
                    oldInlineRequest = true
                } else {
                    oldInlineRequest = false
                }
                
                
                let sNew = !value.effectiveInput.inputText.isEmpty || !value.interfaceState.forwardMessageIds.isEmpty || value.state == .editing || value.chatMode.customChatLink != nil
                let sOld = !oldValue.effectiveInput.inputText.isEmpty || !oldValue.interfaceState.forwardMessageIds.isEmpty || oldValue.state == .editing || value.chatMode.customChatLink != nil
                
                if value.chatMode.customChatLink != nil {
                    send.isEnabled = !value.effectiveInput.inputText.isEmpty
                } else {
                    send.isEnabled = true
                }
                
                if let sendPaidMessages = value.sendPaidMessageStars, sNew, !newSlowModeCounter {
                    let messagesCount = (value.interfaceState.inputState.inputText.isEmpty ? 0 : 1) + value.interfaceState.forwardMessages.count
                    let current: StarsSendActionView
                    if let view = self.sendPaidMessages {
                        current = view
                    } else {
                        current = StarsSendActionView(frame: .zero)
                        addSubview(current)
                        self.sendPaidMessages = current
                    }
                    current.update(price: sendPaidMessages.value * Int64(messagesCount), context: chatInteraction.context, animated: animated)
                    
                    current.setSingle(handler: { [weak self] _ in
                        self?.send.send(event: .Click)
                    }, for: .Click)
                    send.isHidden = true
                } else if let view = sendPaidMessages {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    self.sendPaidMessages = nil
                }

                
                if sNew != sOld || first || newInlineRequest != oldInlineRequest || oldInlineLoading != newInlineLoading || newSlowModeCounter != oldSlowModeCounter {
                    first = false
                    
                    let prevView:View = self.prevView
                    let newView:View
                    
                    if newSlowModeCounter {
                        newView = slowModeTimeout
                    } else if newInlineRequest {
                        newView = inlineCancel
                    } else if oldInlineRequest {
                        newView = sNew ? sendPaidMessages ?? send : voice
                    } else {
                        newView = sNew ? sendPaidMessages ?? send : voice
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
                gift.isHidden = !value.hasGift
                suggestPost.isHidden = !value.allowPostSuggestion || value.interfaceState.suggestPost != nil
                
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
                
                self.slowModeTimeout.set(font: .normal(.text), for: .Normal)
                self.slowModeTimeout.autoSizeToFit = false
                self.slowModeTimeout.sizeToFit(NSZeroSize, NSMakeSize(44, 25), thatFit: true)
                self.slowModeTimeout.layer?.cornerRadius = self.slowModeTimeout.frame.height / 2
                
                if value.boostNeed > 0 {
                    self.slowModeTimeout.set(background: premiumGradient[1], for: .Normal)
                    self.slowModeTimeout.set(color: .white, for: .Normal)
                } else {
                    slowModeTimeout.set(color: theme.colors.grayIcon, for: .Normal)
                    self.slowModeTimeout.set(background: .clear, for: .Normal)
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
        
        let sendValue = self.sendPaidMessages ?? send
        
        var size:NSSize = NSMakeSize(sendValue.frame.width + iconsInset + entertaiments.frame.width, frame.height)
        
        if value.hasSetDestructiveTimer, value.interfaceState.messageEffect == nil {
            size.width += theme.icons.chatSecretTimer.backingSize.width + iconsInset
        }
        if value.keyboardButtonsMessage != nil {
            size.width += keyboard.frame.width + iconsInset
        }
        
        if value.hasGift {
            size.width += gift.frame.width + iconsInset
        }
        
        if value.allowPostSuggestion {
            size.width += suggestPost.frame.width + iconsInset
        }
        
        if let peer = value.peer {
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
        
        let sendValue = sendPaidMessages ?? send
        
        transition.updateFrame(view: inlineCancel, frame: inlineCancel.centerFrameY(x: size.width - inlineCancel.frame.width - iconsInset - 6))
        
        if let view = inlineProgress {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: size.width - inlineCancel.frame.width - iconsInset - 10))
        }
        transition.updateFrame(view: voice, frame: voice.centerFrameY(x: size.width - voice.frame.width - iconsInset))
        transition.updateFrame(view: sendValue, frame: sendValue.centerFrameY(x: size.width - sendValue.frame.width - iconsInset))
        
        
        transition.updateFrame(view: slowModeTimeout, frame: slowModeTimeout.centerFrameY(x: size.width - slowModeTimeout.frame.width - iconsInset))
        transition.updateFrame(view: entertaiments, frame: entertaiments.centerFrameY(x: sendValue.frame.minX - entertaiments.frame.width))
        transition.updateFrame(view: keyboard, frame: keyboard.centerFrameY(x: entertaiments.frame.minX - keyboard.frame.width))
        transition.updateFrame(view: muteChannelMessages, frame: muteChannelMessages.centerFrameY(x: entertaiments.frame.minX - muteChannelMessages.frame.width))

        
        if let scheduled = scheduled {
            if muteChannelMessages.isHidden {
                transition.updateFrame(view: scheduled, frame: scheduled.centerFrameY(x: (keyboard.isHidden ? entertaiments.frame.minX : keyboard.frame.minX) - scheduled.frame.width))
            } else {
                transition.updateFrame(view: scheduled, frame: scheduled.centerFrameY(x: muteChannelMessages.frame.minX - scheduled.frame.width - iconsInset))
            }
        }
        
        if let scheduled {
            transition.updateFrame(view: gift, frame: gift.centerFrameY(x: scheduled.frame.minX - gift.frame.width - iconsInset))
        } else {
            transition.updateFrame(view: gift, frame: gift.centerFrameY(x: (scheduled ?? entertaiments).frame.minX - gift.frame.width))
        }
        
        transition.updateFrame(view: suggestPost, frame: suggestPost.centerFrameY(x: entertaiments.frame.minX - suggestPost.frame.width))

        
        let views = [inlineCancel,
         inlineProgress,
         voice,
         send,
         sendPaidMessages,
         slowModeTimeout,
         entertaiments,
         keyboard,
         gift,
         muteChannelMessages,
         scheduled, suggestPost].filter { $0 != nil && !$0!.isHidden }.map { $0! }
        
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
        
        
        let showMenu:(Control)->Void = { control in
            if let event = NSApp.currentEvent {
                let sendMenu = chatInteraction.sendMessageMenu(false) |> deliverOnMainQueue
                _ = sendMenu.startStandalone(next: { menu in
                    if let menu {
                        AppMenu.show(menu: menu, event: event, for: control)
                    }
                })
            }
        }

        send.set(handler: { control in
            showMenu(control)
        }, for: .RightDown)
        
        send.set(handler: { control in
            showMenu(control)
        }, for: .LongMouseDown)
                
        send.set(handler: { [weak chatInteraction] control in
            chatInteraction?.sendMessage(false, nil, chatInteraction?.presentation.messageEffect)
        }, for: .Click)
        
        slowModeTimeout.set(handler: { [weak chatInteraction] control in
            if let chatInteraction = chatInteraction {
                if let totalBoostNeed = chatInteraction.presentation.totalBoostNeed {
                    chatInteraction.boostToUnrestrict(.unblockSlowmode(totalBoostNeed))
                } else {
                    if let slowMode = chatInteraction.presentation.slowMode {
                        showSlowModeTimeoutTooltip(slowMode, for: control)
                    }
                }
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
