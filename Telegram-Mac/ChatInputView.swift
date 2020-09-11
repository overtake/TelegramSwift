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
import SyncCore
import Postbox




protocol ChatInputDelegate : class {
    func inputChanged(height:CGFloat, animated:Bool);
}

let yInset:CGFloat = 8;

class ChatInputView: View, TGModernGrowingDelegate, Notifable {
    
    private let sendActivityDisposable = MetaDisposable()
    
    public let ready = Promise<Bool>()
    
    weak var delegate:ChatInputDelegate?
    let accessoryDispose:MetaDisposable = MetaDisposable()
    
    
    var chatInteraction:ChatInteraction
    
    var accessory:ChatInputAccessory!
    
    private var _ts:View!
    
    
    //containers
    private var accessoryView:View!
    private var contentView:View!
    private var bottomView:NSScrollView = NSScrollView()
    
    private var messageActionsPanelView:MessageActionsPanelView?
    private var recordingPanelView:ChatInputRecordingView?
    private var blockedActionView:TitleButton?
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
    
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: frameRect)
        
        self.animates = true
        
        _ts = View(frame: NSMakeRect(0, 0, NSWidth(frameRect), .borderSize))
        _ts.backgroundColor = .border;
        
        
        accessoryView = View(frame: NSMakeRect(20.0, frameRect.height, 0, 0))
        contentView = View(frame: NSMakeRect(0, 0, NSWidth(frameRect), NSHeight(frameRect)))
        
        contentView.flip = false
        
        
        actionsView = ChatInputActionsView(frame: NSMakeRect(contentView.frame.width - 100, 0, 100, contentView.frame.height), chatInteraction:chatInteraction);
        
        attachView = ChatInputAttachView(frame: NSMakeRect(0, 0, 60, contentView.frame.height), chatInteraction:chatInteraction)
        contentView.addSubview(attachView)
        
        bottomView.scrollerStyle = .overlay
        
        textView = TGModernGrowingTextView(frame: NSMakeRect(attachView.frame.width, yInset, contentView.frame.width - actionsView.frame.width, contentView.frame.height - yInset * 2.0))
        textView.textFont = .normal(.text)
        
        
        contentView.addSubview(textView)
        contentView.addSubview(actionsView)
        self.background = theme.colors.background
        
        accessory = ChatInputAccessory(accessoryView, chatInteraction:chatInteraction)
        
        self.addSubview(accessoryView)
        
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
        
        setFrameSize(frame.size)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        textView.textFont = .normal(CGFloat(theme.fontSize))
        
        updateInput(interaction.presentation, prevState: ChatPresentationInterfaceState(chatLocation: interaction.chatLocation, chatMode: interaction.mode), false)
        textView.setPlaceholderAttributedString(.initialize(string: textPlaceholder, color: theme.colors.grayText, font: NSFont.normal(theme.fontSize), coreText: false), update: false)
        
        textView.delegate = self
        
        
        updateAdditions(interaction.presentation, false)
        
        chatInteraction.add(observer: self)
        ready.set(accessory.nodeReady.get() |> map {_ in return true} |> take(1) )
    }
    
    private var textPlaceholder: String {
        if case let .replyThread(_, mode) = chatInteraction.mode {
            switch mode {
            case .replies:
                return L10n.messagesPlaceholderReply
            case .comments:
                return L10n.messagesPlaceholderComment
            }
        }
        if let peer = chatInteraction.presentation.peer {
            if let peer = peer as? TelegramChannel {
                if peer.hasPermission(.canBeAnonymous) {
                    return L10n.messagesPlaceholderAnonymous
                }
            }
            if peer.isChannel {
                if textView.frame.width < 150 {
                    return L10n.messagesPlaceholderBroadcastSmall
                }
                return FastSettings.isChannelMessagesMuted(peer.id) ? L10n.messagesPlaceholderSilentBroadcast : L10n.messagesPlaceholderBroadcast
            }
        }
        if textView.frame.width < 150 {
            return L10n.messagesPlaceholderSentMessageSmall
        }
        return L10n.messagesPlaceholderSentMessage
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
        actionsView.backgroundColor = theme.colors.background
        blockedActionView?.disableActions()
        textView.textFont = .normal(theme.fontSize)
        chatDiscussionView?.updateLocalizationAndTheme(theme: theme)
        blockedActionView?.style = ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accent,backgroundColor: theme.colors.background, highlightColor: theme.colors.grayBackground)
        bottomView.backgroundColor = theme.colors.background
        bottomView.documentView?.background = theme.colors.background
        replyMarkupModel?.layout()
        accessory.update(with: chatInteraction.presentation, account: chatInteraction.context.account, animated: false)
        accessoryView.backgroundColor = theme.colors.background
        accessory.container.backgroundColor = theme.colors.background
        textView.setBackgroundColor(theme.colors.background)
        
    }
    
    func notify(with value: Any, oldValue:Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            
            if value.effectiveInput != oldValue.effectiveInput {
                updateInput(value, prevState: oldValue, animated)
            }
            updateAttachments(value.interfaceState,animated)
            
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
            
            
            if !isEqualMessageList(lhs: value.interfaceState.forwardMessages, rhs: oldValue.interfaceState.forwardMessages) || value.interfaceState.forwardMessageIds != oldValue.interfaceState.forwardMessageIds || value.interfaceState.replyMessageId != oldValue.interfaceState.replyMessageId || value.interfaceState.editState != oldValue.interfaceState.editState || urlPreviewChanged {
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
            
            update()
        }
    }
    
    
    func needUpdateReplyMarkup(with state:ChatPresentationInterfaceState, _ animated:Bool) {
        if let keyboardMessage = state.keyboardButtonsMessage, let attribute = keyboardMessage.replyMarkup, state.isKeyboardShown {
            replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: keyboardMessage), bottomView.documentView as? View, true)
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
            self.accessoryView.change(opacity: 1.0, animated: animated)
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
            self.accessoryView.change(opacity: 0.0, animated: animated)
            break
        case .block(_):
            break
        case let .action(text,action):
            self.messageActionsPanelView?.removeFromSuperview()
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
            self.contentView.isHidden = true
            self.contentView.change(opacity: 0.0, animated: animated)
            self.accessoryView.change(opacity: 0.0, animated: animated)
        case let .channelWithDiscussion(discussionGroupId, leftAction, rightAction):
            self.messageActionsPanelView?.removeFromSuperview()
            self.chatDiscussionView = ChannelDiscussionInputView(frame: bounds)
            self.chatDiscussionView?.update(with: chatInteraction, discussionGroupId: discussionGroupId, leftAction: leftAction, rightAction: rightAction)
            
            self.addSubview(self.chatDiscussionView!, positioned: .below, relativeTo: _ts)
            self.contentView.isHidden = true
            self.contentView.change(opacity: 0.0, animated: animated)
            self.accessoryView.change(opacity: 0.0, animated: animated)
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
            self.accessoryView.change(opacity: 0.0, animated: animated)
        }
        
        CATransaction.commit()
    }
    
    func updateInput(_ state:ChatPresentationInterfaceState, prevState: ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        if textView.string() != state.effectiveInput.inputText || state.effectiveInput.attributes != prevState.effectiveInput.attributes  {
            textView.setAttributedString(state.effectiveInput.attributedString, animated:animated)
        }
        let range = NSMakeRange(state.effectiveInput.selectionRange.lowerBound, state.effectiveInput.selectionRange.upperBound - state.effectiveInput.selectionRange.lowerBound)
        if textView.selectedRange().location != range.location || textView.selectedRange().length != range.length {
            textView.setSelectedRange(range)
        }
        if prevState.effectiveInput.inputText.isEmpty {
            self.textView.scrollToCursor()
        }

    }
    private var updateFirstTime: Bool = true
    func updateAdditions(_ state:ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        accessory.update(with: state, account: chatInteraction.context.account, animated: animated)
        
        accessoryDispose.set(accessory.nodeReady.get().start(next: { [weak self] (animated) in
            if let strongSelf = self {
                strongSelf.accessory.measureSize(strongSelf.frame.width - 40.0)
                strongSelf.textViewHeightChanged(strongSelf.defaultContentHeight, animated: animated)
                strongSelf.update()
                if strongSelf.updateFirstTime {
                    strongSelf.updateFirstTime = false
                    strongSelf.textView.scrollToCursor()
                }
            }
        }))
        
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        textView.setSelectedRange(NSMakeRange(textView.string().length, 0))
    }
    
    func update() {
        if #available(OSX 10.12, *) {
            needsLayout = true
            setFrameSize(frame.size)
        } else {
            needsLayout = true
        }
        
    }
    
    func updateAttachments(_ inputState:ChatInterfaceState, _ animated:Bool = true) -> Void {
        
    }
    
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        let keyboardWidth = frame.width - 40
        
        bottomView.setFrameSize( NSMakeSize(keyboardWidth, bottomHeight))
        if let markup = replyMarkupModel, markup.hasButtons {
            markup.measureSize(keyboardWidth)
            markup.view?.setFrameSize(NSMakeSize(markup.size.width, markup.size.height + 5))
            markup.layout()
        }
        contentView.setFrameSize(frame.width, contentView.frame.height)
        textView.setFrameSize(textViewSize(textView))
        actionsView.setFrameSize(NSWidth(actionsView.frame), NSHeight(actionsView.frame))
        attachView.setFrameSize(NSWidth(attachView.frame), NSHeight(attachView.frame))
        _ts.setFrameSize(frame.width, .borderSize)
        
        accessory.measureSize(frame.width - 40.0)
        accessory.frame = NSMakeRect(15, contentView.frame.maxY, accessory.measuredWidth, accessory.size.height)
        messageActionsPanelView?.setFrameSize(frame.size)
        blockedActionView?.setFrameSize(frame.size)
        chatDiscussionView?.setFrameSize(frame.size)
        restrictedView?.setFrameSize(frame.size)
        
        guard let superview = superview else {return}
        textView.max_height = Int32(superview.frame.height / 2 + 50)
        
        if textView.placeholderAttributedString?.string != self.textPlaceholder {
            textView.setPlaceholderAttributedString(.initialize(string: textPlaceholder, color: theme.colors.grayText, font: NSFont.normal(theme.fontSize), coreText: false), update: false)
        }


    }
    
    override func layout() {
        super.layout()
        let bottomInset = chatInteraction.presentation.isKeyboardShown ? bottomHeight : 0
        bottomView.setFrameOrigin(20, chatInteraction.presentation.isKeyboardShown ? 0 : -bottomHeight)
        textView.setFrameSize(NSMakeSize(frame.width - actionsView.frame.width - attachView.frame.width, textView.frame.height))
        contentView.setFrameOrigin(0, bottomInset)
        actionsView.setFrameOrigin(frame.width - actionsView.frame.width, 0)
        attachView.setFrameOrigin(0, 0)
        _ts.setFrameOrigin(0, frame.height - .borderSize)
        
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
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
            
            accessory.view?.change(opacity: accessory.isVisibility() ? 1.0 : 0.0, animated: animated)
            accessory.view?.change(pos: NSMakePoint(15, contentHeight + bottomHeight), animated: animated)
            
            
            change(size: NSMakeSize(NSWidth(frame), sumHeight), animated: animated)
            
            delegate?.inputChanged(height: sumHeight, animated: animated)
        }
        
    }
    
    public func textViewEnterPressed(_ event: NSEvent) -> Bool {
        
        if FastSettings.checkSendingAbility(for: event) {
            let text = textView.string().trimmed
            if text.length > chatInteraction.presentation.maxInputCharacters {
                alert(for: chatInteraction.context.window, info: L10n.chatInputErrorMessageTooLongCountable(text.length - Int(chatInteraction.presentation.maxInputCharacters)))
                return false
            }
            if !text.isEmpty || !chatInteraction.presentation.interfaceState.forwardMessageIds.isEmpty || chatInteraction.presentation.state == .editing {
                chatInteraction.sendMessage(false, nil)
                chatInteraction.context.account.updateLocalInputActivity(peerId: chatInteraction.peerId, activity: .typingText, isPresent: false)
                markNextTextChangeToFalseActivity = true
            }
            
            return true
        }
        return false
    }
    
    var currentActionView: NSView {
        return self.actionsView.currentActionView
    }
    
    
    
    func makeBold() {
        self.textView.boldWord()
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
        
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.min ..< range.max, attributes: chatTextAttributes(from: attributed))
        
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
                    chatInteraction.context.account.updateLocalInputActivity(peerId: chatInteraction.peerId, activity: .typingText, isPresent: isPresent)
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
        return NSMakeSize(NSWidth(contentView.frame) - NSWidth(actionsView.frame) - NSWidth(attachView.frame), NSHeight(textView.frame))
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
        return ChatPresentationInterfaceState.maxInput
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
                if let data = pasteboard.data(forType: .rtf) {
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
                        Queue.mainQueue().async { [weak self] in
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
