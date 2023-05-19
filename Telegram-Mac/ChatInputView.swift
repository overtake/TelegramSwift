//
//  ChatInputView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import TGModernGrowingTextView
import Postbox




protocol ChatInputDelegate : AnyObject {
    func inputChanged(height:CGFloat, animated:Bool);
}


let yInset:CGFloat = 8;

class ChatInputView: View, TGModernGrowingDelegate, Notifable {
    
    private let emojiHolderAnimator = EmojiHolderAnimator()
    
    private let sendActivityDisposable = MetaDisposable()
    
    public let ready = Promise<Bool>()
    
    weak var delegate:ChatInputDelegate?
    let accessoryDispose:MetaDisposable = MetaDisposable()
    
    
    var chatInteraction:ChatInteraction
    
    let accessory:ChatInputAccessory
    
    private var _ts:View!
    
    
    //containers
    private var contentView:View!
    private var bottomView:NSScrollView = NSScrollView()
    
    private var messageActionsPanelView:MessageActionsPanelView?
    private var recordingPanelView:ChatInputRecordingView?
    private var blockedActionView:TitleButton?
    private var additionBlockedActionView: ImageButton?
    private var chatDiscussionView: ChannelDiscussionInputView?
    private var restrictedView:RestrictionWrappedView?
    
    
    //views
    private(set) var textView:TGModernGrowingTextView!
    private var actionsView:ChatInputActionsView!
    private(set) var attachView:ChatInputAttachView!
    

    
    
    private let slowModeUntilDisposable = MetaDisposable()
    
    private var replyMarkupModel:ReplyMarkupNode?
    override var isFlipped: Bool {
        return false
    }
    
    private var standart:CGFloat = 50.0
    private var bottomHeight:CGFloat = 0
    
    static let bottomPadding:CGFloat = 10
    static let maxBottomHeight = ReplyMarkupNode.rowHeight * 3 + ReplyMarkupNode.buttonHeight / 2
    
    
    private let rtfAttachmentsDisposable = MetaDisposable()
    
    private var botMenuView: ChatInputMenuView?
    private var sendAsView: ChatInputSendAsView?
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        self.accessory = ChatInputAccessory(chatInteraction:chatInteraction)
        super.init(frame: frameRect)
        
        self.animates = true
        
        _ts = View(frame: NSMakeRect(0, 0, NSWidth(frameRect), .borderSize))
        _ts.backgroundColor = .border;
        
        
        contentView = View(frame: NSMakeRect(0, 0, NSWidth(frameRect), NSHeight(frameRect)))
        
        contentView.flip = false
        
        
        actionsView = ChatInputActionsView(frame: NSMakeRect(contentView.frame.width - 100, 0, 100, contentView.frame.height), chatInteraction:chatInteraction);
        
        attachView = ChatInputAttachView(frame: NSMakeRect(0, 0, 60, contentView.frame.height), chatInteraction:chatInteraction)
        contentView.addSubview(attachView)
        
        bottomView.scrollerStyle = .overlay
        
        textView = TGModernGrowingTextView(frame: NSMakeRect(attachView.frame.width, yInset, contentView.frame.width - actionsView.frame.width, contentView.frame.height - yInset * 2.0))
        textView.textFont = .normal(.text)
        
        let context = self.chatInteraction.context
                
        textView.installGetAttach({ attachment, size in
            let rect = size.bounds.insetBy(dx: -1.5, dy: -1.5)
            let view = ChatInputAnimatedEmojiAttach(frame: rect)
            view.set(attachment, size: rect.size, context: context)
            return view
        })
        
        contentView.addSubview(textView)
        contentView.addSubview(actionsView)
        self.background = theme.colors.background
        
        
        self.addSubview(accessory)

        
        self.addSubview(contentView)
        self.addSubview(bottomView)
        
        bottomView.documentView = View()
        
        self.addSubview(_ts)
        updateLocalizationAndTheme(theme: theme)
    }
    
    public override var responder:NSResponder? {
        return textView.inputView
    }
    
    func updateInterface(with interaction:ChatInteraction) -> Void {
        self.chatInteraction = interaction
        actionsView.prepare(with: chatInteraction)
        needUpdateChatState(with: chatState, false)
        needUpdateReplyMarkup(with: interaction.presentation, false)
        
        
        textView.textColor = theme.colors.text
        textView.selectedTextColor = theme.colors.selectText
        textView.linkColor = theme.colors.link
        textView.textFont = .normal(CGFloat(theme.fontSize))
        
        textView.setPlaceholderAttributedString(.initialize(string: textPlaceholder, color: theme.colors.grayText, font: NSFont.normal(theme.fontSize), coreText: false), update: false)
        textView.delegate = self
        
        self.updateInput(interaction.presentation, prevState: ChatPresentationInterfaceState(chatLocation: interaction.chatLocation, chatMode: interaction.mode), animated: false, initial: true)

        
        updateAdditions(interaction.presentation, false)
        
        chatInteraction.add(observer: self)
        ready.set(accessory.nodeReady.get() |> map {_ in return true} |> take(1) )
        
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    private var textPlaceholder: String {
        
        if case let .thread(_, mode) = chatInteraction.mode {
            switch mode {
            case .comments:
                return strings().messagesPlaceholderComment
            case .replies:
                return strings().messagesPlaceholderReply
            case .topic:
                return strings().messagesPlaceholderSentMessage
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
        textView.setPlaceholderAttributedString(.initialize(string: textPlaceholder, color: theme.colors.grayText, font: NSFont.normal(theme.fontSize), coreText: false), update: false)
        _ts.backgroundColor = theme.colors.border
        backgroundColor = theme.colors.background
        contentView.backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        textView.textColor = theme.colors.text
        textView.selectedTextColor = theme.colors.selectText
        actionsView.backgroundColor = theme.colors.background
        blockedActionView?.disableActions()
        textView.textFont = .normal(theme.fontSize)
        chatDiscussionView?.updateLocalizationAndTheme(theme: theme)
        blockedActionView?.style = ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accent,backgroundColor: theme.colors.background, highlightColor: theme.colors.grayBackground)
        bottomView.backgroundColor = theme.colors.background
        bottomView.documentView?.background = theme.colors.background
        self.needUpdateReplyMarkup(with: chatInteraction.presentation, false)
    
        accessory.update(with: chatInteraction.presentation, context: chatInteraction.context, animated: false)
        accessory.backgroundColor = theme.colors.background
        accessory.container.backgroundColor = theme.colors.background
        textView.setBackgroundColor(theme.colors.background)
                
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
            
            if value.effectiveInput != oldValue.effectiveInput {
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
            
            
            if !isEqualMessageList(lhs: value.interfaceState.forwardMessages, rhs: oldValue.interfaceState.forwardMessages) || value.interfaceState.forwardMessageIds != oldValue.interfaceState.forwardMessageIds || value.interfaceState.replyMessageId != oldValue.interfaceState.replyMessageId || value.interfaceState.editState != oldValue.interfaceState.editState || urlPreviewChanged || value.interfaceState.hideSendersName != oldValue.interfaceState.hideSendersName || value.interfaceState.hideCaptions != oldValue.interfaceState.hideCaptions {
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
                textViewHeightChanged(defaultContentHeight, animated: animated)
            }
            
            self.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
    }
    
    
    func needUpdateReplyMarkup(with state:ChatPresentationInterfaceState, _ animated:Bool) {
        if let keyboardMessage = state.keyboardButtonsMessage, let attribute = keyboardMessage.replyMarkup, state.isKeyboardShown {
            replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: keyboardMessage), theme, bottomView.documentView as? View, true)
            replyMarkupModel?.measureSize(frame.width - 40)
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
    
    var defaultContentHeight:CGFloat {
        return chatState == .normal || chatState == .editing ? textView.frame.height : CGFloat(textView.min_height)
    }
    
    func needUpdateChatState(with state:ChatState, _ animated:Bool) -> Void {
        CATransaction.begin()
        if animated {
            textViewHeightChanged(defaultContentHeight, animated: animated)
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
        case .block(_):
            break
        case let .action(text, action, addition):
            self.messageActionsPanelView?.removeFromSuperview()
            self.blockedActionView?.removeFromSuperview()
            self.blockedActionView = TitleButton(frame: bounds)
            self.blockedActionView?.style = ControlStyle(font: .normal(.title),foregroundColor: theme.colors.accent)
            self.blockedActionView?.set(text: text, for: .Normal)
            self.blockedActionView?.set(background: theme.colors.grayBackground, for: .Highlight)
            if animated {
                self.blockedActionView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            self.blockedActionView?.set(handler: {_ in
                action(chatInteraction)
            }, for:.Click)



            self.addSubview(self.blockedActionView!, positioned: .below, relativeTo: _ts)

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
        
        CATransaction.commit()
    }
    
    func updateInput(_ state:ChatPresentationInterfaceState, prevState: ChatPresentationInterfaceState, animated:Bool = true, initial: Bool = false) -> Void {
        if textView.string() != state.effectiveInput.inputText || state.effectiveInput.attributes != prevState.effectiveInput.attributes {
            let range = NSMakeRange(state.effectiveInput.selectionRange.lowerBound, state.effectiveInput.selectionRange.upperBound - state.effectiveInput.selectionRange.lowerBound)

            if !state.effectiveInput.attributes.isEmpty {
                var bp = 0
                bp += 1
            }
            
            let current = textView.attributedString().copy() as! NSAttributedString
            let currentRange = textView.selectedRange()

            let item = SimpleUndoItem(attributedString: current, be: state.effectiveInput.attributedString, wasRange: currentRange, be: range)
            if !initial {
                self.textView.addSimpleItem(item)
            } else {
                self.textView.setAttributedString(state.effectiveInput.attributedString, animated:animated)
                if textView.selectedRange().location != range.location || textView.selectedRange().length != range.length {
                    textView.setSelectedRange(range)
                }
            }

        }

        if prevState.effectiveInput.inputText.isEmpty {
            self.textView.scrollToCursor()
        }
        if initial {
            self.textView.update(true)
            self.textViewHeightChanged(self.textView.frame.height, animated: animated)
        }
        if state.effectiveInput != prevState.effectiveInput {
            self.emojiHolderAnimator.apply(self.textView, chatInteraction: self.chatInteraction, current: state.effectiveInput)
            if state.effectiveInput.inputText.count != prevState.effectiveInput.inputText.count {
                self.textView.scrollToCursor()
            }
        }
    }
    private var updateFirstTime: Bool = true
    func updateAdditions(_ state:ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        accessory.update(with: state, context: chatInteraction.context, animated: animated)
        
        accessoryDispose.set(accessory.nodeReady.get().start(next: { [weak self] animated in
            self?.updateAccesory(animated: animated)
        }))
    }
    
    private func updateAccesory(animated: Bool) {
        self.accessory.measureSize(self.frame.width - 40.0)
        self.textViewHeightChanged(self.defaultContentHeight, animated: animated)
        self.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        if self.updateFirstTime {
            self.updateFirstTime = false
            self.textView.scrollToCursor()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        textView.setSelectedRange(NSMakeRange(textView.string().length, 0))
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
        let keyboardWidth = frame.width - 40
        var leftInset: CGFloat = 0


        transition.updateFrame(view: contentView, frame: NSMakeRect(0, bottomInset, frame.width, contentView.frame.height))
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
        
        transition.updateFrame(view: attachView, frame: NSMakeRect(leftInset, 0, attachView.frame.width, attachView.frame.height))
        leftInset += attachView.frame.width
        
        let textSize = textViewSize(textView)
        transition.updateFrame(view: textView, frame: NSMakeRect(leftInset, yInset, textSize.width, textSize.height))
                
        if let view = additionBlockedActionView {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: size.width - view.frame.width - 22))
        }
        
        transition.updateFrame(view: _ts, frame: NSMakeRect(0, size.height - .borderSize, size.width, .borderSize))
            
        accessory.measureSize(size.width - 64)
        transition.updateFrame(view: accessory, frame: NSMakeRect(15, contentView.frame.maxY, size.width - 39, accessory.size.height))
        accessory.updateLayout(NSMakeSize(size.width - 39, accessory.size.height), transition: transition)
                
        if let view = messageActionsPanelView {
            transition.updateFrame(view: view, frame: bounds)
        }
        if let view = blockedActionView {
            transition.updateFrame(view: view, frame: bounds)
        }
        if let view = chatDiscussionView {
            transition.updateFrame(view: view, frame: bounds)
        }
        if let view = restrictedView {
            transition.updateFrame(view: view, frame: bounds)
        }
        
        guard let superview = superview else {return}
        textView.max_height = Int32(superview.frame.height / 2 + 50)

    }
    
    /*
     
     if textView.placeholderAttributedString?.string != self.textPlaceholder {
         textView.setPlaceholderAttributedString(.initialize(string: textPlaceholder, color: theme.colors.grayText, font: NSFont.normal(theme.fontSize), coreText: false), update: false)
     }
     
     */
    
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
    
    private var previousHeight:CGFloat = 0
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        let contentHeight:CGFloat = defaultContentHeight + yInset * 2.0
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
                
        if previousHeight != sumHeight {
            previousHeight = sumHeight
            let bottomInset = chatInteraction.presentation.isKeyboardShown ? bottomHeight : 0
            
            _ts.change(pos: NSMakePoint(0, sumHeight - .borderSize), animated: animated)
            
            contentView.change(size: NSMakeSize(NSWidth(frame), contentHeight), animated: animated)
            contentView.change(pos: NSMakePoint(0, bottomInset), animated: animated)
            
            bottomView._change(size: NSMakeSize(frame.width - 40, bottomHeight), animated: animated)
            bottomView._change(pos: NSMakePoint(20, chatInteraction.presentation.isKeyboardShown ? 0 : -bottomHeight), animated: animated)
            
            accessory.change(opacity: accessory.isVisibility() ? 1.0 : 0.0, animated: animated)
            accessory.change(pos: NSMakePoint(15, contentHeight + bottomHeight), animated: animated)
            
            
            change(size: NSMakeSize(NSWidth(frame), sumHeight), animated: animated)
            
            delegate?.inputChanged(height: sumHeight, animated: animated)
            
        }
        
    }
    
    public func textViewEnterPressed(_ event: NSEvent) -> Bool {
        
        if FastSettings.checkSendingAbility(for: event) {
            let text = textView.string().trimmed
            let context = chatInteraction.context
            if text.length > chatInteraction.maxInputCharacters {
                if context.isPremium || context.premiumIsBlocked {
                    alert(for: context.window, info: strings().chatInputErrorMessageTooLongCountable(text.length - Int(chatInteraction.maxInputCharacters)))
                } else {
                    confirm(for: context.window, information: strings().chatInputErrorMessageTooLongCountable(text.length - Int(chatInteraction.maxInputCharacters)), okTitle: strings().alertOK, cancelTitle: "", thridTitle: strings().premiumGetPremiumDouble, successHandler: { result in
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
            if !text.isEmpty || !chatInteraction.presentation.interfaceState.forwardMessageIds.isEmpty || chatInteraction.presentation.state == .editing {
                chatInteraction.sendMessage(false, nil)
                if self.chatInteraction.peerIsAccountPeer {
                    chatInteraction.context.account.updateLocalInputActivity(peerId: chatInteraction.activitySpace, activity: .typingText, isPresent: false)
                }
                markNextTextChangeToFalseActivity = true
            } else if text.isEmpty {
                chatInteraction.scrollToLatest(true)
            }
            
            return true
        }
        return false
    }
    
    
    var currentActionView: NSView {
        return self.actionsView.currentActionView
    }
    var emojiView: NSView {
        return self.actionsView.entertaiments
    }
    
    func makeSpoiler() {
        self.textView.spoilerWord()
    }
    func makeUnderline() {
        self.textView.underlineWord()
    }
    func makeStrikethrough() {
        self.textView.strikethroughWord()
    }
    
    func makeBold() {
        self.textView.boldWord()
    }
    func removeAllAttributes() {
        self.textView.removeAllAttributes()
    }
    func makeUrl() {
        self.makeUrl(of: textView.selectedRange())
    }
    func makeItalic() {
        self.textView.italicWord()
    }
    func makeMonospace() {
        self.textView.codeWord()
    }
    
    override func becomeFirstResponder() -> Bool {
        return self.textView.becomeFirstResponder()
    }
    
    func makeFirstResponder()  {
        self.window?.makeFirstResponder(self.textView.inputView)
    }
    private var previousString: String = ""
    func textViewTextDidChange(_ string: String) {

        
        let attributed = self.textView.attributedString()
        let range = self.textView.selectedRange()
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
        chatInteraction.update({$0.withUpdatedEffectiveInputState(state)})
        
    }
    
    func canTransformInputText() -> Bool {
        return true
    }
    
    private var markNextTextChangeToFalseActivity: Bool = false
    
    public func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        let attributed = self.textView.attributedString()
        
        let attrs = chatTextAttributes(from: attributed)
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.min ..< range.max, attributes: attrs)
        
        chatInteraction.update({ current in
            var current = current
            current = current.withUpdatedEffectiveInputState(state)
            if let disabledPreview = current.interfaceState.composeDisableUrlPreview {
                if !current.effectiveInput.inputText.contains(disabledPreview) {

                    var detectedUrl: String?
                    current.effectiveInput.attributedString.enumerateAttribute(NSAttributedString.Key(rawValue: TGCustomLinkAttributeName), in: current.effectiveInput.attributedString.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                        if let tag = value as? TGInputTextTag, let url = tag.attachment as? String {
                            detectedUrl = url
                        }
                        let s: ObjCBool = (detectedUrl != nil) ? true : false
                        stop.pointee = s
                    })
                    if detectedUrl == nil {
                        current = current.updatedUrlPreview(nil).updatedInterfaceState {$0.withUpdatedComposeDisableUrlPreview(nil)}
                    }
                }
            }
            return current
        })
        
        if chatInteraction.context.peerId != chatInteraction.peerId, let peer = chatInteraction.presentation.peer, !peer.isChannel && !markNextTextChangeToFalseActivity {
            
            sendActivityDisposable.set((Signal<Bool, NoError>.single(!state.inputText.isEmpty) |> then(Signal<Bool, NoError>.single(false) |> delay(4.0, queue: Queue.mainQueue()))).start(next: { [weak self] isPresent in
                if let chatInteraction = self?.chatInteraction, let peer = chatInteraction.presentation.peer, !peer.isChannel && chatInteraction.presentation.state != .editing {
                    if self?.chatInteraction.peerIsAccountPeer == true {
                        chatInteraction.context.account.updateLocalInputActivity(peerId: .init(peerId: peer.id, category: chatInteraction.mode.activityCategory), activity: .typingText, isPresent: isPresent)
                    }
                }
            }))
        }
        
        markNextTextChangeToFalseActivity = false
    }
    
    
    deinit {
        chatInteraction.remove(observer: self)
        self.accessoryDispose.dispose()
        rtfAttachmentsDisposable.dispose()
        slowModeUntilDisposable.dispose()
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        var leftInset: CGFloat = attachView.frame.width
        if let botMenu = self.botMenuView {
            leftInset += botMenu.frame.width
        }
        if let sendAsView = self.sendAsView {
            leftInset += sendAsView.frame.width
        }
        let size = NSMakeSize(contentView.frame.width - actionsView.size(chatInteraction.presentation).width - leftInset, textView.frame.height)
        return size
    }
    
    func textViewIsTypingEnabled() -> Bool {
        if let editState = chatInteraction.presentation.interfaceState.editState {
            if editState.loadingState != .none {
                return false
            }
        }
        return self.chatState == .normal || self.chatState == .editing
    }
    
    func makeUrl(of range: NSRange) {
        guard range.min != range.max, let window = kitWindow else {
            return
        }
        var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
        let defaultTag: TGInputTextTag? = self.textView.attributedString().attribute(NSAttributedString.Key(rawValue: TGCustomLinkAttributeName), at: range.location, effectiveRange: &effectiveRange) as? TGInputTextTag
        
        
        let defaultUrl = defaultTag?.attachment as? String
        
        if effectiveRange.location == NSNotFound || defaultTag == nil {
            effectiveRange = range
        }
        
        showModal(with: InputURLFormatterModalController(string: self.textView.string().nsstring.substring(with: effectiveRange), defaultUrl: defaultUrl, completion: { [weak self] url in
            self?.textView.addLink(url, range: effectiveRange)
        }), for: window)
        
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return ChatInteraction.maxInput
    }
    
    @available(OSX 10.12.2, *)
    func textView(_ textView: NSTextView!, shouldUpdateTouchBarItemIdentifiers identifiers: [NSTouchBarItem.Identifier]!) -> [NSTouchBarItem.Identifier]! {
        return inputChatTouchBarItems(presentation: chatInteraction.presentation)
    }
    
    func supportContinuityCamera() -> Bool {
        return true
    }
    
    func copyText(withRTF rtf: NSAttributedString!) -> Bool {
        return globalLinkExecutor.copyAttributedString(rtf)
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        
        if let window = kitWindow, self.chatState == .normal || self.chatState == .editing {
            
            if let string = pasteboard.string(forType: .string) {
                chatInteraction.update { current in
                    if let disabled = current.interfaceState.composeDisableUrlPreview, disabled.lowercased() == string.lowercased() {
                        return current.updatedInterfaceState {$0.withUpdatedComposeDisableUrlPreview(nil)}
                    }
                    return current
                }
            }
            
            let result = InputPasteboardParser.proccess(pasteboard: pasteboard, chatInteraction:self.chatInteraction, window: window)
            if result {
                
                if let data = pasteboard.data(forType: .kInApp) {
                    let decoder = AdaptedPostboxDecoder()
                    if let decoded = try? decoder.decode(ChatTextInputState.self, from: data) {
                        let attributed = decoded.unique(isPremium: chatInteraction.context.isPremium).attributedString
                        let current = textView.attributedString().copy() as! NSAttributedString
                        let currentRange = textView.selectedRange()
                        let (attributedString, range) = current.appendAttributedString(attributed, selectedRange: currentRange)
                        let item = SimpleUndoItem(attributedString: current, be: attributedString, wasRange: currentRange, be: range)
                        self.textView.addSimpleItem(item)
                        DispatchQueue.main.async { [weak self] in
                            self?.textView.scrollToCursor()
                        }
                        
                        return true
                    }
                } else if let data = pasteboard.data(forType: .rtf) {
                    if let attributed = (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)) ?? (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil))  {
                        
                        let (attributed, attachments) = attributed.applyRtf()
                        
                        if !attachments.isEmpty {
                            rtfAttachmentsDisposable.set((prepareTextAttachments(attachments) |> deliverOnMainQueue).start(next: { [weak self] urls in
                                if !urls.isEmpty, let chatInteraction = self?.chatInteraction {
                                    chatInteraction.showPreviewSender(urls, true, attributed)
                                }
                            }))
                        } else {
                            let current = textView.attributedString().copy() as! NSAttributedString
                            let currentRange = textView.selectedRange()
                            let (attributedString, range) = current.appendAttributedString(attributed, selectedRange: currentRange)
                            let item = SimpleUndoItem(attributedString: current, be: attributedString, wasRange: currentRange, be: range)
                            self.textView.addSimpleItem(item)
                        }
                        DispatchQueue.main.async { [weak self] in
                            self?.textView.scrollToCursor()
                        }
                        return true
                    }
                }
            }
            
            
            return !result
        }
        
        
        return self.chatState != .normal
    }
    
}
