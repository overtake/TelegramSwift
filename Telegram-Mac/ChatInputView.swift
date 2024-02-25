//
//  Updated_ChatInputView.swift
//  Telegram
//
//  Created by Mike Renoir on 11.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TGUIKit
import SwiftSignalKit
import TelegramCore
import InputView
import Postbox
import ColorPalette

protocol ChatInputDelegate : AnyObject {
    func inputChanged(height:CGFloat, animated:Bool);
}

class ChatInputView: View, Notifable {
    
    private var standart:CGFloat = 50.0
    private var bottomHeight:CGFloat = 0
    static let bottomPadding:CGFloat = 10

    
    private let sendActivityDisposable = MetaDisposable()
    public let ready = Promise<Bool>()
    weak var delegate:ChatInputDelegate?
    var chatInteraction:ChatInteraction
    let accessory:ChatInputAccessory
    private let _ts:View
    
    private let contentView:View
    private let bottomView:NSScrollView = NSScrollView()
    
    
    private var messageActionsPanelView:MessageActionsPanelView?
    private var recordingPanelView:ChatInputRecordingView?
    private var blockedActionView:TextButton?
    private var blockText: View?
    private var additionBlockedActionView: ImageButton?
    private var chatDiscussionView: ChannelDiscussionInputView?
    private var restrictedView:RestrictionWrappedView?
    private var disallowText:Control?
    
    private let actionsView:ChatInputActionsView

    
    let textView:UITextView!
    let attachView:ChatInputAttachView!
    
    private let rtfAttachmentsDisposable = MetaDisposable()
    private let slowModeUntilDisposable = MetaDisposable()
    private let accessoryDisposable:MetaDisposable = MetaDisposable()

    
    private var replyMarkupModel:ReplyMarkupNode?
    override var isFlipped: Bool {
        return false
    }
    
    static let maxBottomHeight = ReplyMarkupNode.rowHeight * 3 + ReplyMarkupNode.buttonHeight / 2
    
    
    
    private var botMenuView: ChatInputMenuView?
    private var sendAsView: ChatInputSendAsView?
    
    private let textInteractions: TextView_Interactions = .init()
    
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        self.accessory = ChatInputAccessory(chatInteraction:chatInteraction)
        self.contentView = View(frame: NSMakeRect(0, 0, NSWidth(frameRect), NSHeight(frameRect)))
        self._ts = View(frame: NSMakeRect(0, 0, NSWidth(frameRect), .borderSize))
        self.attachView = ChatInputAttachView(frame: NSMakeRect(0, 0, 60, contentView.frame.height), chatInteraction:chatInteraction)
        actionsView = ChatInputActionsView(frame: NSMakeRect(contentView.frame.width - 100, 0, 100, contentView.frame.height), chatInteraction:chatInteraction);
        self.textView = UITextView(frame: NSMakeRect(attachView.frame.width, 0, contentView.frame.width - actionsView.frame.width, contentView.frame.height), interactions: self.textInteractions)

        super.init(frame: frameRect)
        
        self.textView.context = chatInteraction.context
        
        self.animates = true
        
        _ts.backgroundColor = .border;
        
        contentView.flip = false

        contentView.addSubview(attachView)
        
        bottomView.scrollerStyle = .overlay
        
        contentView.addSubview(textView)
        contentView.addSubview(actionsView)
        
        self.addSubview(accessory)
        self.addSubview(contentView)
        self.addSubview(bottomView)
        self.addSubview(_ts)

        bottomView.documentView = View()
        
        self.background = theme.colors.background
        updateLocalizationAndTheme(theme: theme)
        
        
        textInteractions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
        
        textInteractions.processEnter = { [weak self] event in
            return self?.textViewEnterPressed(event) ?? true
        }
        textInteractions.processPaste = { [weak self] pasteboard in
            return self?.processPaste(pasteboard) ?? false
        }
        textInteractions.processAttriburedCopy = { attributedString in
            return globalLinkExecutor.copyAttributedString(attributedString)
        }
    }
    
    func set(_ state: Updated_ChatTextInputState) {
        self.chatInteraction.update({
            $0.withUpdatedEffectiveInputState(state.textInputState())
        })
    }
    
    private var markNextTextChangeToFalseActivity: Bool = false

    public func textViewEnterPressed(_ event: NSEvent) -> Bool {
        
        let interaction = self.chatInteraction
        let context = interaction.context
        
        if FastSettings.checkSendingAbility(for: event) {
            let text = textView.string().trimmed
            if text.length > interaction.maxInputCharacters {
                if context.isPremium || context.premiumIsBlocked {
                    alert(for: context.window, info: strings().chatInputErrorMessageTooLongCountable(text.length - Int(interaction.maxInputCharacters)))
                } else {
                    verifyAlert_button(for: context.window, information: strings().chatInputErrorMessageTooLongCountable(text.length - Int(interaction.maxInputCharacters)), ok: strings().alertOK, cancel: "", option: strings().premiumGetPremiumDouble, successHandler: { result in
                        switch result {
                        case .thrid:
                            showPremiumLimit(context: context, type: .caption(text.length))
                        default:
                            break
                        }

                    })
                }
                return true
            }
            if !text.isEmpty || !interaction.presentation.interfaceState.forwardMessageIds.isEmpty || interaction.presentation.state == .editing {
                interaction.sendMessage(false, nil)
                if interaction.peerIsAccountPeer {
                    interaction.context.account.updateLocalInputActivity(peerId: interaction.activitySpace, activity: .typingText, isPresent: false)
                }
                markNextTextChangeToFalseActivity = true
            } else if text.isEmpty {
                interaction.scrollToLatest(true)
            }
            return true
        }
        return false
    }
    
    func height(for width: CGFloat) -> CGFloat {
        let contentHeight:CGFloat = contentHeight(for: width)
        var sumHeight:CGFloat = contentHeight + (accessory.isVisibility() ? accessory.size.height + 5 : 0)
        if let markup = replyMarkupModel  {
            bottomHeight = min(
                ChatInputView.maxBottomHeight,
                markup.size.height + ChatInputView.bottomPadding
            )
        } else {
            bottomHeight = 0
        }
        if chatInteraction.presentation.isKeyboardShown {
            sumHeight += bottomHeight
        }
        return sumHeight
    }
    
    
    
    
    public override var responder:NSResponder? {
        return textView.inputView
    }
    
    func updateInterface(with interaction:ChatInteraction) -> Void {
        self.chatInteraction = interaction
        actionsView.prepare(with: chatInteraction)
        needUpdateChatState(with: chatState, false)
        needUpdateReplyMarkup(with: interaction.presentation, false)
        
        
        updateAdditions(interaction.presentation, false)
        
        chatInteraction.add(observer: self)
        ready.set(accessory.nodeReady.get() |> map {_ in return true} |> take(1) )
        
        updateLayout(size: frame.size, transition: .immediate)
        
        self.updateInput(interaction.presentation, prevState: ChatPresentationInterfaceState(chatLocation: interaction.chatLocation, chatMode: interaction.mode), animated: false, initial: true)

    }
    
    private var textPlaceholder: String {
        
        guard let peer = chatInteraction.presentation.peer else {
            return strings().messagesPlaceholderSentMessage
        }
        
        if let _ = permissionText(from: peer, for: .banSendText), chatInteraction.presentation.state == .normal {
            return strings().channelPersmissionMessageBlock
        }
        
       
        
        if case let .thread(_, mode) = chatInteraction.mode {
            switch mode {
            case .comments:
                return strings().messagesPlaceholderComment
            case .replies:
                return strings().messagesPlaceholderReply
            case .topic:
                return strings().messagesPlaceholderSentMessage
            case .savedMessages, .saved:
                return ""
            }
        }
        
        if let cachedData = chatInteraction.presentation.cachedData as? CachedChannelData {
            let viewForumAsMessages = cachedData.viewForumAsMessages.knownValue
            if peer.isForum, viewForumAsMessages == true {
                if let replyMessage = chatInteraction.presentation.interfaceState.replyMessage {
                    if let threadInfo = replyMessage.associatedThreadInfo {
                        return strings().messagePlaceholderReplyToTopic(threadInfo.title)
                    }
                } else {
                    return strings().messagePlaceholderMessageInGeneral
                }
            }
        }
        
        if chatInteraction.presentation.interfaceState.editState != nil {
            return strings().messagePlaceholderEdit
        }
        if chatInteraction.mode == .scheduled {
            return strings().messagesPlaceholderScheduled
        }
        if let replyMarkup = chatInteraction.presentation.keyboardButtonsMessage?.replyMarkup {
            if let placeholder = replyMarkup.placeholder {
                return placeholder
            }
        }
        if let peer = chatInteraction.presentation.peer {
            if let peer = peer as? TelegramChannel {
                if peer.hasPermission(.canBeAnonymous) {
                    return strings().messagesPlaceholderAnonymous
                }
            }
            if peer.isChannel {
                return FastSettings.isChannelMessagesMuted(peer.id) ? strings().messagesPlaceholderSilentBroadcast : strings().messagesPlaceholderBroadcast
            }
        }
        if !chatInteraction.peerIsAccountPeer {
            return strings().messagesPlaceholderAnonymous
        }
        return strings().messagesPlaceholderSentMessage
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        _ts.backgroundColor = theme.colors.border
        backgroundColor = theme.colors.background
        contentView.backgroundColor = theme.colors.background
        actionsView.backgroundColor = theme.colors.background
        chatDiscussionView?.updateLocalizationAndTheme(theme: theme)
        bottomView.backgroundColor = theme.colors.background
        bottomView.documentView?.background = theme.colors.background
        self.needUpdateReplyMarkup(with: chatInteraction.presentation, false)
    
        accessory.update(with: chatInteraction.presentation, context: chatInteraction.context, animated: false)
        accessory.backgroundColor = theme.colors.background
        accessory.container.backgroundColor = theme.colors.background
        
        blockText?.backgroundColor = theme.colors.background
        
        let myPeerColor = chatInteraction.context.myPeer?.nameColor
        let colors: PeerNameColors.Colors
        if let myPeerColor = myPeerColor {
            colors = chatInteraction.context.peerNameColors.get(myPeerColor)
        } else {
            colors = .init(main: theme.colors.accent)
        }
        textView.inputTheme = theme.inputTheme.withUpdatedQuote(colors)
    }
    
    func notify(with value: Any, oldValue:Any, animated:Bool) {
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
            
        
        updateLayout(size: frame.size, transition: transition)

        self.actionsView.notify(with: value, oldValue: oldValue, animated: animated)

        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            
            if value.effectiveInput != oldValue.effectiveInput || oldValue.state != value.state {
                updateInput(value, prevState: oldValue, animated: animated)
            }
            updateAttachments(value,animated)
            
            var urlPreviewChanged:Bool
            if value.urlPreview?.0 != oldValue.urlPreview?.0 {
                urlPreviewChanged = true
            } else if let valuePreview = value.urlPreview?.1, let oldValuePreview = oldValue.urlPreview?.1 {
                urlPreviewChanged = !valuePreview.isEqual(to: oldValuePreview)
            } else if (value.urlPreview?.1 == nil) != (oldValue.urlPreview?.1 == nil) {
                urlPreviewChanged = true
            } else {
                urlPreviewChanged = false
            }
            
            urlPreviewChanged = urlPreviewChanged || value.interfaceState.composeDisableUrlPreview != oldValue.interfaceState.composeDisableUrlPreview
            
            
            if !isEqualMessageList(lhs: value.interfaceState.forwardMessages, rhs: oldValue.interfaceState.forwardMessages) || value.interfaceState.forwardMessageIds != oldValue.interfaceState.forwardMessageIds || value.interfaceState.replyMessageId != oldValue.interfaceState.replyMessageId || value.interfaceState.editState != oldValue.interfaceState.editState || urlPreviewChanged || value.interfaceState.hideSendersName != oldValue.interfaceState.hideSendersName || value.interfaceState.hideCaptions != oldValue.interfaceState.hideCaptions || value.interfaceState.linkBelowMessage != oldValue.interfaceState.linkBelowMessage || value.interfaceState.largeMedia != oldValue.interfaceState.largeMedia {
                updateAdditions(value,animated)
            }
            
            if value.state != oldValue.state {
                needUpdateChatState(with:value.state, animated)
            }
            
            var updateReplyMarkup = false
            
            if let lhsMessage = value.keyboardButtonsMessage, let rhsMessage = oldValue.keyboardButtonsMessage {
                if lhsMessage.id != rhsMessage.id || lhsMessage.stableVersion != rhsMessage.stableVersion {
                    updateReplyMarkup = true
                }
            } else if (value.keyboardButtonsMessage == nil) != (oldValue.keyboardButtonsMessage == nil) {
                updateReplyMarkup = true
            }
            
            if !updateReplyMarkup {
                updateReplyMarkup = value.isKeyboardShown != oldValue.isKeyboardShown
            }
            
            if updateReplyMarkup {
                needUpdateReplyMarkup(with: value, animated)
                inputDidUpdateLayout(animated: animated)
            }
            
            self.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
    }
    
    
    func needUpdateReplyMarkup(with state:ChatPresentationInterfaceState, _ animated:Bool) {
        if let keyboardMessage = state.keyboardButtonsMessage, let attribute = keyboardMessage.replyMarkup, state.isKeyboardShown || attribute.flags.contains(.persistent) {
            replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: keyboardMessage), theme, bottomView.documentView as? View, true)
            replyMarkupModel?.measureSize(frame.width - 30)
            replyMarkupModel?.redraw()
            replyMarkupModel?.layout()
            bottomView.contentView.scroll(to: NSZeroPoint)
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ChatInputView {
            return other == self
        }
        return false
    }
    
    var chatState:ChatState {
        return chatInteraction.presentation.state
    }
    
    func contentHeight(for width: CGFloat) -> CGFloat {
        return chatState == .normal || chatState == .editing ? textViewSize(width).0.height : CGFloat(textView.min_height)
    }
    
    func needUpdateChatState(with state:ChatState, _ animated:Bool) -> Void {
        CATransaction.begin()
        if animated {
            inputDidUpdateLayout(animated: animated)
        }
        
        recordingPanelView?.removeFromSuperview()
        recordingPanelView = nil
        blockedActionView?.removeFromSuperview()
        blockedActionView = nil
        additionBlockedActionView?.removeFromSuperview()
        additionBlockedActionView = nil
        chatDiscussionView?.removeFromSuperview()
        chatDiscussionView = nil
        restrictedView?.removeFromSuperview()
        restrictedView = nil
        messageActionsPanelView?.removeFromSuperview()
        messageActionsPanelView = nil
        
        blockText?.removeFromSuperview()
        blockText = nil
        
        textView.isHidden = false
        
        let chatInteraction = self.chatInteraction
        switch state {
        case .normal, .editing:
            self.contentView.isHidden = false
            self.contentView.change(opacity: 1.0, animated: animated)
            self.accessory.change(opacity: 1.0, animated: animated)
            break
        case .selecting:
            self.messageActionsPanelView = MessageActionsPanelView(frame: bounds)
            self.messageActionsPanelView?.prepare(with: chatInteraction)
            if animated {
                self.messageActionsPanelView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            self.addSubview(self.messageActionsPanelView!, positioned: .below, relativeTo: _ts)
            self.contentView.isHidden = true
            self.contentView.change(opacity: 0.0, animated: animated)
            self.accessory.change(opacity: 0.0, animated: animated)
            break
        case let .block(string):
            if !string.isEmpty {
                let current = Control(frame: NSMakeRect(0, 0, frame.width, frame.height - 1))
                current.backgroundColor = theme.colors.background
                addSubview(current)
                self.blockText = current
                
                let context = chatInteraction.context
                
                let textView = TextView()
                textView.isSelectable = false
                
                let parsed = parseMarkdownIntoAttributedString(string, attributes: MarkdownAttributes.init(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.link), linkAttribute: { link in
                    return (NSAttributedString.Key.link.rawValue, inAppLink.callback(link, { value in
                        if value == "premium" {
                            showModal(with: PremiumBoardingController(context: context), for: context.window)
                        }
                    }))
                })).detectBold(with: .medium(.text))
                let layout = TextViewLayout(parsed, alignment: .center)
                layout.measure(width: frame.width - 40)
                layout.interactions = globalLinkExecutor
                textView.update(layout)
                
                current.addSubview(textView)
            } else if let view = blockText {
                performSubviewRemoval(view, animated: animated)
                blockText = nil
            }
        case let .action(text, action, addition):
            self.messageActionsPanelView?.removeFromSuperview()
            self.blockedActionView?.removeFromSuperview()
            
            let blockedActionView = TextButton(frame: bounds)
            blockedActionView.autoSizeToFit = false
            blockedActionView.set(color: theme.colors.accent, for: .Normal)
            blockedActionView.set(font: .normal(.title), for: .Normal)
            
            blockedActionView.set(text: text, for: .Normal)
            blockedActionView.set(background: theme.colors.grayBackground, for: .Highlight)
            blockedActionView.sizeToFit(.zero, bounds.size, thatFit: true)
            if animated {
                blockedActionView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            blockedActionView.set(handler: {_ in
                action(chatInteraction)
            }, for:.Click)

            self.addSubview(blockedActionView, positioned: .below, relativeTo: _ts)
            
            self.blockedActionView = blockedActionView

            if let addition = addition {
                additionBlockedActionView = ImageButton()
                additionBlockedActionView?.animates = false
                additionBlockedActionView?.set(image: addition.icon, for: .Normal)
                additionBlockedActionView?.sizeToFit()
                addSubview(additionBlockedActionView!, positioned: .above, relativeTo: self.blockedActionView)

                additionBlockedActionView?.set(handler: { control in
                    addition.action(control)
                }, for: .Click)
            } else {
                additionBlockedActionView?.removeFromSuperview()
                additionBlockedActionView = nil
            }

            self.contentView.isHidden = true
            self.contentView.change(opacity: 0.0, animated: animated)
            self.accessory.change(opacity: 0.0, animated: animated)
        case let .botStart(text, action):
            self.messageActionsPanelView?.removeFromSuperview()
            self.blockedActionView?.removeFromSuperview()
            
            self.blockedActionView = TextButton(frame: bounds.insetBy(dx: 5, dy: 5))
            self.blockedActionView?.autoSizeToFit = false
            self.blockedActionView?.style = ControlStyle(font: .normal(.title),foregroundColor: theme.colors.underSelectedColor)
            self.blockedActionView?.set(text: text, for: .Normal)
            self.blockedActionView?.scaleOnClick = true
            self.blockedActionView?.set(background: theme.colors.accent, for: .Normal)
            self.blockedActionView?.set(background: theme.colors.accent.withAlphaComponent(0.8), for: .Highlight)
            self.blockedActionView?.sizeToFit(.zero, bounds.insetBy(dx: 5, dy: 5).size, thatFit: true)

            
            let shimmer = ShimmerEffectView()
            shimmer.isStatic = true
            self.blockedActionView?.addSubview(shimmer)
            
            self.blockedActionView?.layer?.cornerRadius = 10
            if animated {
                self.blockedActionView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            self.blockedActionView?.set(handler: {_ in
                action(chatInteraction)
            }, for:.Click)



            self.addSubview(self.blockedActionView!, positioned: .below, relativeTo: _ts)

            self.contentView.isHidden = true
            self.contentView.change(opacity: 0.0, animated: animated)
            self.accessory.change(opacity: 0.0, animated: animated)
        case let .channelWithDiscussion(discussionGroupId, leftAction, rightAction):
            self.messageActionsPanelView?.removeFromSuperview()
            self.chatDiscussionView = ChannelDiscussionInputView(frame: bounds)
            self.chatDiscussionView?.update(with: chatInteraction, discussionGroupId: discussionGroupId, leftAction: leftAction, rightAction: rightAction)
            
            self.addSubview(self.chatDiscussionView!, positioned: .below, relativeTo: _ts)
            self.contentView.isHidden = true
            self.contentView.change(opacity: 0.0, animated: animated)
            self.accessory.change(opacity: 0.0, animated: animated)
        case let .recording(recorder):
            textView.isHidden = true
            recordingPanelView = ChatInputRecordingView(frame: NSMakeRect(0,0,frame.width,standart), chatInteraction:chatInteraction, recorder:recorder)
            addSubview(recordingPanelView!, positioned: .below, relativeTo: _ts)
            if animated {
                self.recordingPanelView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        case let.restricted( text):
            self.messageActionsPanelView?.removeFromSuperview()
            self.restrictedView = RestrictionWrappedView(text)
            if animated {
                self.restrictedView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            self.addSubview(self.restrictedView!, positioned: .below, relativeTo: _ts)
            self.contentView.isHidden = true
            self.contentView.change(opacity: 0.0, animated: animated)
            self.accessory.change(opacity: 0.0, animated: animated)
        }
        
        if let peer = chatInteraction.presentation.peer, let text = permissionText(from: peer, for: .banSendText), state == .normal {
            let context = chatInteraction.context
            let current: Control
            if let view = self.disallowText {
                current = view
            } else {
                current = Control(frame: textView.frame)
                self.contentView.addSubview(current)
                self.disallowText = current
            }
            current.removeAllHandlers()
            current.set(handler: { _ in
                showModalText(for: context.window, text: text)
            }, for: .Click)
            current.set(cursor: .arrow, for: .Normal)
            current.set(cursor: .arrow, for: .Highlight)
            current.set(cursor: .arrow, for: .Hover)

        } else if let view = self.disallowText {
            performSubviewRemoval(view, animated: animated)
            self.disallowText = nil
        }
        
        CATransaction.commit()
    }
    
    func updateInput(_ state:ChatPresentationInterfaceState, prevState: ChatPresentationInterfaceState, animated:Bool = true, initial: Bool = false) -> Void {
        
        if let peer = state.peer, let _ = permissionText(from: peer, for: .banSendText), state.state == .normal {
            textView.inputView.isEditable = false
            textView.isHidden = false
        } else {
            switch state.state {
            case .normal, .editing:
                textView.inputView.isEditable = true
                textView.isHidden = false
            case let .block(string):
                textView.isHidden = !string.isEmpty
            default:
                textView.inputView.isEditable = false
            }
        }
        
        let input = state.effectiveInput
        
        self.textView.interactions.inputIsEnabled = self.isEnabled()
        self.textView.set(input)
        self.textView.placeholder = textPlaceholder
        
        if prevState.effectiveInput.inputText.isEmpty {
            self.textView.scrollToCursor()
        }

        if state.effectiveInput != prevState.effectiveInput {
            if state.effectiveInput.inputText.count != prevState.effectiveInput.inputText.count {
                self.textView.scrollToCursor()
            }
        }
        
        if chatInteraction.context.peerId != chatInteraction.peerId, let peer = chatInteraction.presentation.peer, !peer.isChannel && !markNextTextChangeToFalseActivity {
            sendActivityDisposable.set((Signal<Bool, NoError>.single(!state.effectiveInput.inputText.isEmpty) |> then(Signal<Bool, NoError>.single(false) |> delay(4.0, queue: Queue.mainQueue()))).start(next: { [weak self] isPresent in
                if let chatInteraction = self?.chatInteraction, let peer = chatInteraction.presentation.peer, !peer.isChannel && chatInteraction.presentation.state != .editing {
                    if self?.chatInteraction.peerIsAccountPeer == true {
                        chatInteraction.context.account.updateLocalInputActivity(peerId: .init(peerId: peer.id, category: chatInteraction.mode.activityCategory), activity: .typingText, isPresent: isPresent)
                    }
                }
            }))
        }

        
    }
    private var updateFirstTime: Bool = true
    func updateAdditions(_ state:ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        accessory.update(with: state, context: chatInteraction.context, animated: animated)
        
        accessoryDisposable.set(accessory.nodeReady.get().start(next: { [weak self] animated in
            self?.updateAccesory(animated: animated)
        }))
        self.textView.placeholder = textPlaceholder
    }
    
    private func updateAccesory(animated: Bool) {
        self.accessory.measureSize(self.frame.width - 40.0)
        self.inputDidUpdateLayout(animated: animated)
        self.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        if self.updateFirstTime {
            self.updateFirstTime = false
            self.textView.scrollToCursor()
        }
    }
    
    
    func updateAttachments(_ inputState:ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        if let botMenu = inputState.botMenu, !botMenu.isEmpty, inputState.interfaceState.inputState.inputText.isEmpty {
            let current: ChatInputMenuView
            if let view = self.botMenuView {
                current = view
            } else {
                current = ChatInputMenuView(frame: NSMakeRect(0, 0, 60, 50))
                self.botMenuView = current
                contentView.addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2, bounce: false)
                }
            }
            current.chatInteraction = self.chatInteraction
            current.update(botMenu, animated: animated)
        } else {
            if let view = self.botMenuView {
                self.botMenuView = nil
                performSubviewRemoval(view, animated: animated, scale: true)
            }
        }
        var anim = animated
        if let sendAsPeers = inputState.sendAsPeers, !sendAsPeers.isEmpty && inputState.state == .normal {
            let current: ChatInputSendAsView
            if let view = self.sendAsView {
                current = view
            } else {
                current = ChatInputSendAsView(frame: NSMakeRect(0, 0, 50, 50))
                self.sendAsView = current
                contentView.addSubview(current)
                anim = false
            }
            current.update(sendAsPeers, currentPeerId: inputState.currentSendAsPeerId ?? self.chatInteraction.context.peerId, chatInteraction: self.chatInteraction, animated: animated)
        } else {
            if let view = self.sendAsView {
                self.sendAsView = nil
               performSubviewRemoval(view, animated: animated)
            }
        }
        updateLayout(size: frame.size, transition: anim ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        let bottomInset = chatInteraction.presentation.isKeyboardShown ? bottomHeight : 0
        let keyboardWidth = frame.width - 30
        var leftInset: CGFloat = 0
        let contentHeight:CGFloat = contentHeight(for: size.width)
        
        transition.updateFrame(view: contentView, frame: NSMakeRect(0, bottomInset, size.width, contentHeight))
        transition.updateFrame(view: bottomView, frame: NSMakeRect(20, chatInteraction.presentation.isKeyboardShown ? 0 : -bottomHeight, keyboardWidth, bottomHeight))
        
        let actionsSize = actionsView.size(chatInteraction.presentation)
        let immediate: ContainedViewLayoutTransition = .immediate
        immediate.updateFrame(view: actionsView, frame: CGRect(origin: CGPoint(x: size.width - actionsSize.width, y: 0), size: actionsSize))
        actionsView.updateLayout(size: actionsSize, transition: immediate)

        
        if let view = botMenuView {
            leftInset += view.frame.width
            transition.updateFrame(view: view, frame: NSMakeRect(0, 0, view.frame.width, view.frame.height))
        }
        if let view = sendAsView {
            leftInset += view.frame.width
            transition.updateFrame(view: view, frame: NSMakeRect(0, 0, view.frame.width, view.frame.height))
        }
        if let markup = replyMarkupModel, markup.hasButtons, let view = markup.view {
            markup.measureSize(keyboardWidth)
            transition.updateFrame(view: view, frame: NSMakeRect(0, 0, markup.size.width, markup.size.height))
            markup.layout(transition: transition)
        }
        
        if let current = self.blockText {
            transition.updateFrame(view: current, frame: CGRect(origin: .zero, size: NSMakeSize(size.width, size.height - 1)))
            if let subview = current.subviews.first {
                transition.updateFrame(view: subview, frame: subview.centerFrame())
            }
        }
        
        transition.updateFrame(view: attachView, frame: NSMakeRect(leftInset, 0, attachView.frame.width, attachView.frame.height))
        leftInset += attachView.frame.width
        
        
        let (textSize, textHeight) = self.textViewSize(size.width)
        
        let viewRect = NSMakeRect(leftInset, 0, textSize.width, textSize.height)
        transition.updateFrame(view: textView, frame: viewRect)
        textView.updateLayout(size: viewRect.size, textHeight: textHeight, transition: transition)
        
        if let view = disallowText {
            transition.updateFrame(view: view, frame: textView.frame)
        }
                
        if let view = additionBlockedActionView {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: size.width - view.frame.width - 22))
        }
        
        transition.updateFrame(view: _ts, frame: NSMakeRect(0, size.height - .borderSize, size.width, .borderSize))
            
        accessory.measureSize(size.width - 64)
        transition.updateFrame(view: accessory, frame: NSMakeRect(15, contentView.frame.maxY, size.width - 39, accessory.size.height))
        accessory.updateLayout(NSMakeSize(size.width - 39, accessory.size.height), transition: transition)
                
        if let view = messageActionsPanelView {
            transition.updateFrame(view: view, frame: size.bounds)
        }
        if let view = blockedActionView {
            if view.scaleOnClick {
                transition.updateFrame(view: view, frame: size.bounds.insetBy(dx: 5, dy: 5))
            } else {
                transition.updateFrame(view: view, frame: size.bounds)
            }
            for subview in view.subviews {
                if let shimmer = subview as? ShimmerEffectView {
                    transition.updateFrame(view: subview, frame: view.bounds)
                    shimmer.updateAbsoluteRect(view.bounds, within: view.frame.size)
                    shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: view.bounds, cornerRadius: view.frame.height / 2)], horizontal: true, size: view.frame.size)

                }
            }
        }
        if let view = chatDiscussionView {
            transition.updateFrame(view: view, frame: size.bounds)
        }
        if let view = restrictedView {
            transition.updateFrame(view: view, frame: size.bounds)
        }
        
        guard let superview = superview else { return }
        textInteractions.max_height = floorToScreenPixels(backingScaleFactor, superview.frame.height / 2) + 50.0

    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    var stringValue:String {
        return textView.string()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    func inputDidUpdateLayout(animated: Bool) {
        let contentHeight:CGFloat = contentHeight(for: self.frame.width)
        var sumHeight:CGFloat = contentHeight + (accessory.isVisibility() ? accessory.size.height + 5 : 0)
        if let markup = replyMarkupModel  {
            bottomHeight = min(
                ChatInputView.maxBottomHeight,
                markup.size.height + ChatInputView.bottomPadding
            )
        } else {
            bottomHeight = 0
        }
        if chatInteraction.presentation.isKeyboardShown {
            sumHeight += bottomHeight
        }
                
        delegate?.inputChanged(height: sumHeight, animated: animated)

    }
    
    var currentActionView: NSView {
        return self.actionsView.currentActionView
    }
    var emojiView: NSView {
        return self.actionsView.entertaiments
    }
    func makeSpoiler() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.spoiler))
    }
    func makeUnderline() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.underline))
    }
    func makeQuote() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.quote))
    }
    func makeStrikethrough() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.strikethrough))
    }
    func makeBold() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.bold))
    }
    func removeAllAttributes() {
        self.textView.inputApplyTransform(.clear)
    }
    func makeUrl() {
        self.textView.inputApplyTransform(.url)
    }
    func makeItalic() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.italic))
    }
    func makeMonospace() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.monospace))
    }
    
    override func becomeFirstResponder() -> Bool {
        return self.textView.inputView.becomeFirstResponder()
    }
    
    func makeFirstResponder()  {
        self.window?.makeFirstResponder(self.responder)
    }
    
    
    deinit {
        self.accessoryDisposable.dispose()
        self.rtfAttachmentsDisposable.dispose()
        self.slowModeUntilDisposable.dispose()
        self.chatInteraction.remove(observer: self)
    }
    
    func textViewSize(_ width: CGFloat) -> (NSSize, CGFloat) {
        var leftInset: CGFloat = attachView.frame.width
        if let botMenu = self.botMenuView {
            leftInset += botMenu.frame.width
        }
        if let sendAsView = self.sendAsView {
            leftInset += sendAsView.frame.width
        }
        let w = width - actionsView.size(chatInteraction.presentation).width - leftInset
        let height = self.textView.height(for: w)
        return (NSMakeSize(w, min(max(height, textView.min_height), textView.max_height)), height)
    }
    
    func isEnabled() -> Bool {
        if let editState = chatInteraction.presentation.interfaceState.editState {
            if editState.loadingState != .none {
                return false
            }
        }
        return self.chatState == .normal || self.chatState == .editing
    }
    
    
    func copyAttributedString(_ attributedString: NSAttributedString!) -> Bool {
        return globalLinkExecutor.copyAttributedString(attributedString)
    }
    
    func processPaste(_ pasteboard: NSPasteboard) -> Bool {
        
        let interaction = self.chatInteraction
        
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.textView.scrollToCursor()
            }
        }
        
        if let window = kitWindow, self.chatState == .normal || self.chatState == .editing {
            
            if let string = pasteboard.string(forType: .string) {
                interaction.update { current in
                    if let disabled = current.interfaceState.composeDisableUrlPreview, disabled.lowercased() == string.lowercased() {
                        return current.updatedInterfaceState {$0.withUpdatedComposeDisableUrlPreview(nil)}
                    }
                    return current
                }
            }
            
            let result = InputPasteboardParser.proccess(pasteboard: pasteboard, chatInteraction: interaction, window: window)
            if result {
                if let disallowText = disallowText {
                    disallowText.send(event: .Click)
                    textView.shake(beep: true)
                } else {
                    if let data = pasteboard.data(forType: .kInApp) {
                        let decoder = AdaptedPostboxDecoder()
                        if let decoded = try? decoder.decode(ChatTextInputState.self, from: data) {
                            let state = decoded.unique(isPremium: interaction.context.isPremium)
                            
                            interaction.appendText(state.attributedString())
                            
                            return true
                        }
                    } else if let data = pasteboard.data(forType: .rtf) {
                        if let attributed = (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)) ?? (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil))  {
                            
                            let (attributed, attachments) = attributed.applyRtf()
                            
                            if !attachments.isEmpty {
                                rtfAttachmentsDisposable.set((prepareTextAttachments(attachments) |> deliverOnMainQueue).start(next: { [weak self] urls in
                                    if !urls.isEmpty, let interaction = self?.chatInteraction {
                                        interaction.showPreviewSender(urls, true, attributed)
                                    }
                                }))
                            } else {
                                self.chatInteraction.appendText(attributed)
                            }
                            return true
                        }
                    }
                }
            }
            return !result
        }
        
        return self.chatState != .normal
    }
    
}
