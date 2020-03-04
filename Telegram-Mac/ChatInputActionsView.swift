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
import SyncCore
import SwiftSignalKit


//
let iconsInset:CGFloat = 20.0

class ChatInputActionsView: View, Notifable {
    
    let chatInteraction:ChatInteraction
    private let send:ImageButton = ImageButton()
    private let voice:ImageButton = ImageButton()
    private let muteChannelMessages:ImageButton = ImageButton()
    private let entertaiments:ImageButton = ImageButton()
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
        secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)
        
        scheduled?.set(image: theme.icons.scheduledInputAction, for: .Normal)

        
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
            let emoji = EmojiViewController(chatInteraction.context, search: .single(SearchState(state: .None, request: nil)))
            if let interactions = chatInteraction.context.sharedContext.bindings.entertainment().interactions {
                emoji.update(with: interactions)
            }
            return emoji
        }
        return chatInteraction.context.sharedContext.bindings.entertainment()
    }
    
    private func addHoverObserver() {
        
        entertaiments.set(handler: { [weak self] (state) in
            guard let `self` = self else {return}
            let chatInteraction = self.chatInteraction
            var enabled = false
            
            if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled {
                enabled = sidebarEnabled
            }
            if !((mainWindow.frame.width >= 1100 && chatInteraction.context.sharedContext.layout == .dual) || (mainWindow.frame.width >= 880 && chatInteraction.context.sharedContext.layout == .minimisize)) || !enabled {
                self.showEntertainment()
            }
        }, for: .Hover)
    }
    
    private func showEntertainment() {
        let rect = NSMakeRect(0, 0, 350, max(mainWindow.frame.height - 400, 300))
        entertaimentsPopover._frameRect = rect
        entertaimentsPopover.view.frame = rect
        showPopover(for: entertaiments, with: entertaimentsPopover, edge: .maxX, inset:NSMakePoint(frame.width - entertaiments.frame.maxX + 15, 10), delayBeforeShown: 0.0)
    }
    
    private func addClickObserver() {
        entertaiments.set(handler: { [weak self] (state) in
            if let strongSelf = self {
                let chatInteraction = strongSelf.chatInteraction
                if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled, sidebarEnabled {
                    if mainWindow.frame.width >= 1100 && chatInteraction.context.sharedContext.layout == .dual || mainWindow.frame.width >= 880 && chatInteraction.context.sharedContext.layout == .minimisize {
                        
                        chatInteraction.toggleSidebar()
                    }
                }
            }
        }, for: .Click)
    }
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
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
        inlineCancel.centerY(x:frame.width - inlineCancel.frame.width - iconsInset - 6)
        inlineProgress?.centerY(x: frame.width - inlineCancel.frame.width - iconsInset - 10)
        voice.centerY(x:frame.width - voice.frame.width - iconsInset)
        send.centerY(x: frame.width - send.frame.width - iconsInset)
        slowModeTimeout.centerY(x: frame.width - slowModeTimeout.frame.width - iconsInset)
        entertaiments.centerY(x: voice.frame.minX - entertaiments.frame.width - 0)
        secretTimer?.centerY(x: entertaiments.frame.minX - keyboard.frame.width)
        keyboard.centerY(x: entertaiments.frame.minX - keyboard.frame.width)
        muteChannelMessages.centerY(x: entertaiments.frame.minX - muteChannelMessages.frame.width)
        
        if let scheduled = scheduled {
            if muteChannelMessages.isHidden {
                scheduled.centerY(x: (keyboard.isHidden ? entertaiments.frame.minX : keyboard.frame.minX) - scheduled.frame.width)
            } else {
                scheduled.centerY(x: muteChannelMessages.frame.minX - scheduled.frame.width - iconsInset)
            }
        }
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
            if value.interfaceState != oldValue.interfaceState || !animated || value.inputQueryResult != oldValue.inputQueryResult || value.inputContext != oldValue.inputContext || value.sidebarEnabled != oldValue.sidebarEnabled || value.sidebarShown != oldValue.sidebarShown || value.layout != oldValue.layout || value.isKeyboardActive != oldValue.isKeyboardActive || value.isKeyboardShown != oldValue.isKeyboardShown || value.slowMode != oldValue.slowMode || value.hasScheduled != oldValue.hasScheduled {
            
                var size:NSSize = NSMakeSize(send.frame.width + iconsInset + entertaiments.frame.width, frame.height)
                
                if chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
                    size.width += theme.icons.chatSecretTimer.backingSize.width + iconsInset
                }
                send.animates = false
                send.set(image: value.state == .editing ? theme.icons.chatSaveEditedMessage : theme.icons.chatSendMessage, for: .Normal)
                send.animates = true
              
                if let peer = value.peer {
                    muteChannelMessages.isHidden = !peer.isChannel || !peer.canSendMessage || !value.effectiveInput.inputText.isEmpty || value.interfaceState.editState != nil
                }
                
                if !muteChannelMessages.isHidden {
                    size.width += muteChannelMessages.frame.width
                }
                
                var newInlineRequest = value.inputQueryResult != oldValue.inputQueryResult
                var oldInlineRequest = newInlineRequest
                var newInlineLoading: Bool = false
                var oldInlineLoading: Bool = false
                
                if let query = value.inputQueryResult, case .contextRequestResult(_, let data) = query {
                    newInlineLoading = data == nil && !value.effectiveInput.inputText.isEmpty
                }
                
                
                if let query = value.inputQueryResult, case .contextRequestResult = query, newInlineRequest || first {
                    newInlineRequest = true
                } else {
                    newInlineRequest = false
                }
                

                
                if let query = oldValue.inputQueryResult, case .contextRequestResult(_, let data) = query {
                    oldInlineLoading = data == nil
                }
                
                let newSlowModeCounter: Bool = value.slowMode?.timeout != nil && value.interfaceState.editState == nil && !newInlineLoading && !newInlineRequest
                let oldSlowModeCounter: Bool = oldValue.slowMode?.timeout != nil && oldValue.interfaceState.editState == nil && !oldInlineLoading && !oldInlineRequest
                
                
                if let query = oldValue.inputQueryResult, case .contextRequestResult = query, oldInlineRequest || first {
                    oldInlineRequest = true
                } else {
                    oldInlineRequest = false
                }
                
//                newInlineLoading = newInlineLoading && newInlineRequest
//                oldInlineLoading = oldInlineLoading && oldInlineRequest

                
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
                        prevView.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion:{ complete in
                            if complete {
                                prevView.isHidden = true
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
                    if let inlineProgress = inlineProgress {
                        self.inlineProgress = nil
                        if animated {
                            inlineProgress.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak inlineProgress] _ in
                                inlineProgress?.removeFromSuperview()
                            })
                        } else {
                            inlineProgress.removeFromSuperview()
                        }
                    }
                }
       
                entertaiments.apply(state: .Normal)
                entertaiments.isSelected = value.isShowSidebar 
                
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
                if let slowMode = value.slowMode, let timeout = slowMode.timeout, timeout >= 0 {
                    let minutes = timeout / 60
                    let seconds = timeout % 60
                    let string = String(format: "%@:%@", minutes < 10 ? "0\(minutes)" : "\(minutes)", seconds < 10 ? "0\(seconds)" : "\(seconds)")
                    self.slowModeTimeout.set(text: string, for: .Normal)
                }
                
                if value.hasScheduled && value.effectiveInput.inputText.isEmpty && value.interfaceState.editState == nil {
                    if scheduled == nil {
                        scheduled = ImageButton()
                        addSubview(scheduled!)
                    }
                    scheduled?.removeAllHandlers()
                    scheduled?.set(handler: { [weak self] _ in
                        self?.chatInteraction.openScheduledMessages()
                    }, for: .Click)
                    scheduled!.set(image: theme.icons.chatInputScheduled, for: .Normal)
                    _ = scheduled!.sizeToFit()
                    size.width += scheduled!.frame.width + iconsInset + (muteChannelMessages.isHidden ? 0 : iconsInset)
                } else {
                    scheduled?.removeFromSuperview()
                    scheduled = nil
                }
                
                setFrameSize(size)
                updateEntertainmentIcon()
                needsLayout = true
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
        
        let handler:(Control)->Void = { [weak chatInteraction] control in
            if let chatInteraction = chatInteraction, let peer = chatInteraction.peer, !peer.isSecretChat {
                let context = chatInteraction.context
                if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                    return
                }
                if chatInteraction.presentation.state != .normal {
                    return
                }
                var items:[SPopoverItem] = []
                
                if peer.id != chatInteraction.context.account.peerId {
                    items.append(SPopoverItem(L10n.chatSendWithoutSound, { [weak chatInteraction] in
                        chatInteraction?.sendMessage(true, nil)
                    }))
                }
                switch chatInteraction.mode {
                case .history:
                    items.append(SPopoverItem(peer.id == chatInteraction.context.peerId ? L10n.chatSendSetReminder : L10n.chatSendScheduledMessage, {
                        showModal(with: ScheduledMessageModalController(context: context, peerId: peer.id, scheduleAt: { [weak chatInteraction] date in
                            chatInteraction?.sendMessage(false, date)
                        }), for: context.window)
                    }))
                case .scheduled:
                    break
                }
                
                if !items.isEmpty {
                    showPopover(for: control, with: SPopoverViewController(items: items))
                }
            }
        }
        
        send.set(handler: handler, for: .RightDown)
        send.set(handler: handler, for: .LongMouseDown)

        
        send.set(handler: { [weak chatInteraction] control in
             chatInteraction?.sendMessage(false, nil)
        }, for: .Click)
        
        slowModeTimeout.set(handler: { [weak chatInteraction] control in
            if let slowMode = chatInteraction?.presentation.slowMode {
                showSlowModeTimeoutTooltip(slowMode, for: control)
            }
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
