//
//  ChatInputView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac




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
    var account:Account!
    
    private var _ts:View!
    
    
    //containers
    private var accessoryView:View!
    private var contentView:View!
    private var bottomView:NSScrollView = NSScrollView()
    
    private var messageActionsPanelView:MessageActionsPanelView?
    private var recordingPanelView:ChatInputRecordingView?
    private var blockedActionView:TitleButton?
    private var restrictedView:RestrictionWrappedView?
    
    
    //views
    private(set) var textView:TGModernGrowingTextView!
    private var actionsView:ChatInputActionsView!
    private var attachView:ChatInputAttachView!
    
    
    private let emojiReplacementDisposable:MetaDisposable = MetaDisposable()

    private var formatterPopover: InputFormatterPopover?
    
    private var replyMarkupModel:ReplyMarkupNode?
    override var isFlipped: Bool {
        return false
    }
    
    private var standart:CGFloat = 50.0
    private var bottomHeight:CGFloat = 0

    static let bottomPadding:CGFloat = 10
    static let maxBottomHeight = ReplyMarkupNode.rowHeight * 3 + ReplyMarkupNode.buttonHeight / 2
    
    
    private let formatterDisposable = MetaDisposable()
    
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
        contentView.addSubview(actionsView)
        
        attachView = ChatInputAttachView(frame: NSMakeRect(0, 0, 60, contentView.frame.height), chatInteraction:chatInteraction)
        contentView.addSubview(attachView)
        
        bottomView.scrollerStyle = .overlay
        
        textView = TGModernGrowingTextView(frame: NSMakeRect(attachView.frame.width, yInset, contentView.frame.width - actionsView.frame.width, contentView.frame.height - yInset * 2.0))
        textView.textFont = .normal(.text)
        
        contentView.addSubview(textView)
        self.background = theme.colors.background
        
        accessory = ChatInputAccessory(accessoryView, chatInteraction:chatInteraction)
        
        self.addSubview(accessoryView)

        self.addSubview(contentView)
        self.addSubview(bottomView)

        bottomView.documentView = View()
       
        self.addSubview(_ts)
        updateLocalizationAndTheme()
    }
    
    public override var responder:NSResponder? {
        return textView
    }
    
    func updateInterface(with interaction:ChatInteraction, account:Account) -> Void {
        self.chatInteraction = interaction
        self.account = account
        actionsView.prepare(with: chatInteraction)
        needUpdateChatState(with: chatState, false)
        needUpdateReplyMarkup(with: interaction.presentation, false)

        setFrameSize(frame.size)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        textView.textFont = .normal(CGFloat(theme.fontSize))
        
        updateInput(interaction.presentation, prevState: ChatPresentationInterfaceState(interaction.chatLocation), false)
        textView.setPlaceholderAttributedString(.initialize(string: textPlaceholder, color: theme.colors.grayText, font: NSFont.normal(theme.fontSize), coreText: false), update: false)
        
        textView.delegate = self
     
        
        updateAdditions(interaction.presentation, false)

        chatInteraction.add(observer: self)
        ready.set(accessory.nodeReady.get() |> map {_ in return true} |> take(1) )
    }
    
    private var textPlaceholder: String {
        if let peer = chatInteraction.presentation.peer {
            if peer.isChannel {
                return FastSettings.isChannelMessagesMuted(peer.id) ? tr(L10n.messagesPlaceholderSilentBroadcast) : tr(L10n.messagesPlaceholderBroadcast)
            }
        }
        return tr(L10n.messagesPlaceholderSentMessage)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        textView.setPlaceholderAttributedString(.initialize(string: textPlaceholder, color: theme.colors.grayText, font: NSFont.normal(theme.fontSize), coreText: false), update: false)
        _ts.backgroundColor = theme.colors.border
        backgroundColor = theme.colors.background
        contentView.backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        textView.textColor = theme.colors.text
        actionsView.backgroundColor = theme.colors.background
        blockedActionView?.disableActions()
        textView.textFont = .normal(theme.fontSize)

        blockedActionView?.style = ControlStyle(font: .normal(.title), foregroundColor: theme.colors.blueUI,backgroundColor: theme.colors.background, highlightColor: theme.colors.grayBackground)
        bottomView.backgroundColor = theme.colors.background
        bottomView.documentView?.background = theme.colors.background
        replyMarkupModel?.layout()
        accessoryView.backgroundColor = theme.colors.background
        accessory.container.backgroundColor = theme.colors.background
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
                urlPreviewChanged = !valuePreview.isEqual(oldValuePreview)
            } else if (value.urlPreview?.1 == nil) != (oldValue.urlPreview?.1 == nil) {
                urlPreviewChanged = true
            } else {
                urlPreviewChanged = false
            }
            
            urlPreviewChanged = urlPreviewChanged || value.interfaceState.composeDisableUrlPreview != oldValue.interfaceState.composeDisableUrlPreview
            
            
            if value.interfaceState.forwardMessageIds != oldValue.interfaceState.forwardMessageIds || value.interfaceState.replyMessageId != oldValue.interfaceState.replyMessageId || value.interfaceState.editState != oldValue.interfaceState.editState || urlPreviewChanged {
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
            replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: keyboardMessage), bottomView.documentView as? View)
            replyMarkupModel?.measureSize(frame.width - 40)
            replyMarkupModel?.redraw()
            replyMarkupModel?.layout()
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
            self.blockedActionView?.style = ControlStyle(font: .normal(.title),foregroundColor: theme.colors.blueUI)
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
            break
        case let .recording(recorder):
            textView.isHidden = true
            recordingPanelView = ChatInputRecordingView(frame: NSMakeRect(0,0,frame.width,standart), chatInteraction:chatInteraction, recorder:recorder)
            addSubview(recordingPanelView!, positioned: .below, relativeTo: _ts)
            if animated {
                self.recordingPanelView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            break
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
    }
    private var updateFirstTime: Bool = true
    func updateAdditions(_ state:ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        accessory.update(with: state, account: account, animated: animated)
        
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
        restrictedView?.setFrameSize(frame.size)
    }
    
    override func layout() {
        super.layout()
        
        let bottomInset = chatInteraction.presentation.isKeyboardShown ? bottomHeight : 0
        bottomView.setFrameOrigin(20, chatInteraction.presentation.isKeyboardShown ? 0 : -bottomHeight)
        
       contentView.setFrameOrigin(0, bottomInset)
        actionsView.setFrameOrigin(NSMaxX(textView.frame), 0)
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
            accessory.view?.change(pos: NSMakePoint(15, contentHeight), animated: animated)
            
            
            change(size: NSMakeSize(NSWidth(frame), sumHeight), animated: animated)
            
            delegate?.inputChanged(height: sumHeight, animated: animated)
        }

    }
    
    public func textViewEnterPressed(_ event: NSEvent) -> Bool {
        
        if FastSettings.checkSendingAbility(for: event) {
            if FastSettings.isPossibleReplaceEmojies {
                let text = textView.string().stringEmojiReplacements
                if textView.string() != text {
                    self.textView.setString(text)
                    let attributed = self.textView.attributedString()
                    let range = self.textView.selectedRange()
                    let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
                    chatInteraction.update({$0.withUpdatedEffectiveInputState(state)})
                }
            }
            
            if !textView.string().trimmed.isEmpty || !chatInteraction.presentation.interfaceState.forwardMessageIds.isEmpty || chatInteraction.presentation.state == .editing {
                chatInteraction.sendMessage()
                chatInteraction.account.updateLocalInputActivity(peerId: chatInteraction.peerId, activity: .typingText, isPresent: false)
                markNextTextChangeToFalseActivity = true
            }
            
            return true
        }
        return false
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
        if FastSettings.isPossibleReplaceEmojies {
            
            if previousString != string {
                let difference = string.replacingOccurrences(of: previousString, with: "")
                if difference.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    let replacedEmojies = string.stringEmojiReplacements
                    if string != replacedEmojies {
                        self.textView.setString(replacedEmojies)
                    }
                }
            }
           
            previousString = string
        }
        
        let attributed = self.textView.attributedString()
        let range = self.textView.selectedRange()
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
        chatInteraction.update({$0.withUpdatedEffectiveInputState(state)})

    }
    
    func canTransformInputText() -> Bool {
        if let editState = chatInteraction.presentation.interfaceState.editState {
            return editState.message.media.isEmpty
        }
        return true
    }
    
    private var markNextTextChangeToFalseActivity: Bool = false
    
    public func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        let attributed = self.textView.attributedString()
        
        formatterPopover?.close()
        formatterPopover = nil

        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
        chatInteraction.update({$0.withUpdatedEffectiveInputState(state)})
        
        if chatInteraction.account.peerId != chatInteraction.peerId, let peer = chatInteraction.presentation.peer, !peer.isChannel && !markNextTextChangeToFalseActivity {
            
            sendActivityDisposable.set((Signal<Bool, NoError>.single(true) |> then(Signal<Bool, NoError>.single(false) |> delay(4.0, queue: Queue.mainQueue()))).start(next: { [weak self] isPresent in
                if let chatInteraction = self?.chatInteraction, let peer = chatInteraction.presentation.peer, !peer.isChannel {
                    chatInteraction.account.updateLocalInputActivity(peerId: chatInteraction.peerId, activity: .typingText, isPresent: isPresent)
                }
            }))
        }
        
        markNextTextChangeToFalseActivity = false
    }

    
    deinit {
        chatInteraction.remove(observer: self)
        self.accessoryDispose.dispose()
        emojiReplacementDisposable.dispose()
        formatterDisposable.dispose()
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
        guard range.min != range.max else {
            return
        }
        
        let close:()->Void = { [weak self] in
            if let strongSelf = self {
                strongSelf.formatterPopover?.close()
                strongSelf.textView.setSelectedRange(NSMakeRange(strongSelf.textView.selectedRange().max, 0))
                strongSelf.formatterPopover = nil
            }
        }
        
        if formatterPopover == nil {
            self.formatterPopover = InputFormatterPopover(InputFormatterArguments(bold: { [weak self] in
                self?.textView.boldWord()
                close()
                }, italic: {  [weak self] in
                    self?.textView.italicWord()
                    close()
                }, code: {  [weak self] in
                    self?.textView.codeWord()
                    close()
                }, link: { [weak self] url in
                    self?.textView.addLink(url)
                    close()
            }), window: mainWindow)
        }
        
        formatterPopover?.show(relativeTo: textView.inputView.selectedRangeRect, of: textView, preferredEdge: .maxY)
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return chatInteraction.presentation.maxInputCharacters
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        
        if let window = kitWindow, self.chatState == .normal {
            return !InputPasteboardParser.proccess(pasteboard: pasteboard, account: self.account, chatInteraction:self.chatInteraction, window: window)
        }
        
        return self.chatState == .normal
    }

}
