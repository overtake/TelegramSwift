//
//  InputTextDataRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit
import InputView


class InputTextDataRowItem: GeneralRowItem, InputDataRowDataValue {

    fileprivate let placeholderLayout: TextViewLayout?
    fileprivate let placeholder: InputDataInputPlaceholder?
    
    fileprivate let inputPlaceholder: NSAttributedString
    fileprivate let filter:(String)->String
    let limit:Int32
    
    fileprivate let state: Updated_ChatTextInputState
    fileprivate let updateState:(Updated_ChatTextInputState)->Void
    
    fileprivate let hasEmoji: Bool
    
    fileprivate let context: AccountContext

    var value: InputDataValue {
        return .attributedString(state.inputText)
    }
    
    var isTextLimitVisible: Bool {
        return !(self.state.inputText.string.length < self.limit / 3 * 2 || self.state.inputText.string.length == self.limit)
    }
        
    override var inset: NSEdgeInsets {
        var inset = super.inset
        switch viewType {
        case .legacy:
            break
        case .modern:
            if let errorLayout = errorLayout {
                inset.bottom += errorLayout.layoutSize.height + 4
            }
        }
        return inset
    }

    fileprivate let rightItem: InputDataRightItem?
    fileprivate let canMakeTransformations: Bool
    fileprivate let simpleTransform: Bool
    fileprivate let allowedLinkHosts: [String]
    fileprivate let playAnimation: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, state: Updated_ChatTextInputState, viewType: GeneralViewType, placeholder: InputDataInputPlaceholder?, inputPlaceholder: String, rightItem: InputDataRightItem? = nil, canMakeTransformations: Bool = false, simpleTransform: Bool = true, filter:@escaping(String)->String, updateState:@escaping(Updated_ChatTextInputState)->Void, limit: Int32, hasEmoji: Bool = false, allowedLinkHosts: [String] = [], playAnimation: Bool = true, enabled: Bool = true) {
        self.filter = filter
        self.limit = limit
        self.context = context
        self.placeholder = placeholder
        self.hasEmoji = hasEmoji
        self.allowedLinkHosts = allowedLinkHosts
        self.canMakeTransformations = canMakeTransformations
        self.simpleTransform = simpleTransform
        self.rightItem = rightItem
        self.updateState = updateState
        self.playAnimation = playAnimation
        self.state = state
        self.inputPlaceholder = .initialize(string: inputPlaceholder, color: theme.colors.grayText, font: .normal(.text))
        self.placeholderLayout = placeholder?.placeholder != nil ? TextViewLayout(.initialize(string: placeholder!.placeholder!, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1) : nil
        super.init(initialSize, stableId: stableId, viewType: viewType, enabled: enabled)
    }
    
    var textFieldLeftInset: CGFloat {
        if let placeholder = placeholder {
            if let placeholder = placeholder.placeholder {
                if placeholder.trimmingCharacters(in: CharacterSet(charactersIn: "0987654321")).isEmpty {
                    return 30
                } else {
                    return 102
                }
            } else {
                if let icon = placeholder.icon {
                    return icon.backingSize.width + 6 + placeholder.insets.left
                } else {
                    return -2
                }
            }
        } else {
            return -2
        }
    }
    
    var hasTextLimitation: Bool {
        if self.height == 16 + (viewType.innerInset.top + viewType.innerInset.bottom) {
            return false
        }
        if let placeholder = placeholder {
            return placeholder.hasLimitationText
        } else {
            return limit > 5
        }
    }
    
    var textWidth: CGFloat {
        var width = blockWidth - viewType.innerInset.left - viewType.innerInset.right - 4
        if hasEmoji {
            width -= 20
        }
        if let placeholder = placeholder, let icon = placeholder.icon {
            width -= (icon.backingSize.width + viewType.innerInset.left)
        }
        if let rightItem {
            switch rightItem {
            case .action(let cGImage, _):
                width -= (cGImage.backingSize.width + 5)
            case .loading:
                width -= 20
            }
        }
        return width
    }
    
    override var height: CGFloat {
        let attr = NSMutableAttributedString()
        attr.append(string: self.state.inputText.string)
                
        attr.addAttribute(.font, value: NSFont.normal(.text), range: attr.range)
        let height = InputTextView.rawTextHeight(for: attr, width: textWidth)
        
        return max(16, height) + (viewType.innerInset.top + viewType.innerInset.bottom)
    }
    
    private(set) fileprivate var additionRightInset: CGFloat = 0
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        placeholderLayout?.measure(width: 100)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return InputTextDataRowView.self
    }
    
}

private final class InputDataSecureField : NSSecureTextField {
    override func becomeFirstResponder() -> Bool {
        
        let success = super.becomeFirstResponder()
        if success {
            let tetView = self.currentEditor() as? NSTextView
            tetView?.insertionPointColor = theme.colors.indicatorColor
        }
        //NSTextView* textField = (NSTextView*) [self currentEditor];
        
        return success
    }
}


class InputTextDataRowView : GeneralContainableRowView {
    private let placeholderTextView = TextView()
    private let rightActionView: ImageButton = ImageButton()
    private var loadingView: ProgressIndicator? = nil
    private var placeholderAction: ImageButton?
    internal let textView: UITextView = UITextView(frame: NSZeroRect)
    private let textLimitation: TextViewLabel = TextViewLabel(frame: NSMakeRect(0, 0, 16, 14))
    
    private let inputSwapDisposable = MetaDisposable()
    
    private var emoji: ImageButton?
    private var textInputSuggestionsView: InputSwapSuggestionsPanel?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(placeholderTextView)
        self.addSubview(textView)
        self.addSubview(rightActionView)
        self.addSubview(textLimitation)
        rightActionView.autohighlight = false
        
        containerView.userInteractionEnabled = false
        
        textLimitation.alignment = .right
        
        
        placeholderTextView.userInteractionEnabled = false
        placeholderTextView.isSelectable = false
              
    }
    
    
    func updateTextInputSuggestions(_ files: [TelegramMediaFile], range: NSRange, animated: Bool) {
        
        guard let item = item as? InputTextDataRowItem, let content = item.table?.superview?.superview else {
            return
        }
        
        let context = item.context
        
        if !files.isEmpty {
            let current: InputSwapSuggestionsPanel
            let isNew: Bool
            if let view = self.textInputSuggestionsView {
                current = view
                isNew = false
            } else {
                current = InputSwapSuggestionsPanel(inputView: self.textView, textContent: self.textView.scrollView.contentView, relativeView: content, window: context.window, context: context, presentation: theme, highlightRect: { [weak self] range, whole in
                    return self?.textView.highlight(for: range, whole: whole) ?? .zero
                })
                self.textInputSuggestionsView = current
                isNew = true
            }
            current.apply(files, range: range, animated: animated, isNew: isNew)
        } else if let view = self.textInputSuggestionsView {
            view.close(animated: animated)
            self.textInputSuggestionsView = nil
        }
    }

    
    deinit {
        inputSwapDisposable.dispose()
    }
    
    override func shakeView() {
        if !textView.isHidden {
            textView.shake()
            textView.selectAll()
        }
    }
    
    override func hasFirstResponder() -> Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    func canTransformInputText() -> Bool {
        guard let item = item as? InputTextDataRowItem else { return false }
        return item.canMakeTransformations
    }
    
    func makeBold() {
        self.textView.inputApplyTransform(.attribute(TextInputAttributes.bold))
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
    
    override var additionBorderInset: CGFloat {
        if let item = self.item as? InputTextDataRowItem {
            var inset: CGFloat = 0
            if let placeholderAction {
                inset += placeholderAction.frame.width + item.viewType.innerInset.left
            }
            return inset
        }
        return super.additionBorderInset
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? InputTextDataRowItem else {return}
                     
        let innerInsets = item.viewType.innerInset
        
        transition.updateFrame(view: placeholderTextView, frame: CGRect(origin: NSMakePoint(innerInsets.left, innerInsets.top), size: placeholderTextView.frame.size))
        
        var textOffset: CGFloat = 0
        
        if let placeholderAction {
            transition.updateFrame(view: placeholderAction, frame: CGRect(origin: NSMakePoint(innerInsets.left, innerInsets.top - 1), size: placeholderAction.frame.size))
            textOffset += placeholderAction.frame.width + innerInsets.left
        }

        
        let (textSize, textHeight) = textViewSize()
                
        transition.updateFrame(view: textView, frame: CGRect(origin: CGPoint(x: item.viewType.innerInset.left + textOffset, y: item.viewType.innerInset.top - 5), size: textSize))
        textView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        
            
        var emojiOffset: CGFloat = 0
        
        if let rightItem = item.rightItem {
            switch rightItem {
            case .action:
                transition.updateFrame(view: rightActionView, frame: CGRect(origin: NSMakePoint(self.containerView.frame.width - rightActionView.frame.width - innerInsets.right, innerInsets.top - 5), size: rightActionView.frame.size))
                emojiOffset += rightActionView.frame.width
            case .loading:
                if let loadingView = loadingView  {
                    transition.updateFrame(view: loadingView, frame: CGRect(origin: NSMakePoint(self.containerView.frame.width - loadingView.frame.width - innerInsets.right, innerInsets.top), size: loadingView.frame.size))
                    emojiOffset += rightActionView.frame.width + 5
                }
            }
        }
        transition.updateFrame(view: textLimitation, frame: CGRect(origin: NSMakePoint(item.blockWidth - innerInsets.right - textLimitation.frame.width, self.containerView.frame.height - innerInsets.bottom - textLimitation.frame.height), size: textLimitation.frame.size))
        
        
        if let emoji {
            transition.updateFrame(view: emoji, frame: CGRect(origin: NSMakePoint(containerView.frame.width - emoji.frame.width - innerInsets.right - emojiOffset, innerInsets.top - 3), size: emoji.frame.size))
        }
        
        self.textInputSuggestionsView?.updateRect(transition: transition)

    }

    
    override var backdorColor: NSColor {
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.backgroundColor
        }
        return theme.colors.background
    }

    override func updateColors() {
        super.updateColors()
        
        placeholderTextView.backgroundColor = backdorColor
        
        var inputTheme = textView.inputTheme
        inputTheme = inputTheme.withUpdatedFontSize(.text)
        
        textView.inputTheme = inputTheme

        containerView.backgroundColor = backdorColor
        loadingView?.progressColor = theme.colors.grayText
        guard let item = item as? InputTextDataRowItem else {
            return
        }
        self.background = item.viewType.rowBackground
    }
    
 
    override var mouseInsideField: Bool {
        return textView._mouseInside()
    }
    
    
    override var firstResponder: NSResponder? {
        return textView.inputView
    }
    
    func showPlaceholderActionTooltip(_ text: String) -> Void {
        if let placeholderAction = placeholderAction {
            tooltip(for: placeholderAction, text: text)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? InputTextDataRowItem else {return}
        
        super.set(item: item, animated: animated)

        placeholderTextView.isHidden = item.placeholderLayout == nil
        placeholderTextView.update(item.placeholderLayout)
        

        
        if let rightItem = item.rightItem {
            switch rightItem {
            case let .action(image, action):
                rightActionView.set(image: image, for: .Normal)
                _ = rightActionView.sizeToFit()
                rightActionView.isHidden = false
                loadingView?.removeFromSuperview()
                loadingView = nil
                rightActionView.removeAllHandlers()
                switch action {
                case .none:
                    rightActionView.userInteractionEnabled = false
                    rightActionView.autohighlight = false
                case .resort:
                    rightActionView.userInteractionEnabled = false
                    rightActionView.autohighlight = false
                case .clearText:
                    rightActionView.userInteractionEnabled = true
                    rightActionView.autohighlight = true
                    rightActionView.set(handler: { [weak self] _ in
                        self?.textView.set(.init())
                    }, for: .Click)
                case let .custom(action):
                    rightActionView.userInteractionEnabled = true
                    rightActionView.autohighlight = true
                    rightActionView.set(handler: { control in
                        action(item, control)
                    }, for: .Click)
                }
            case .loading:
                if loadingView == nil {
                    loadingView = ProgressIndicator(frame: NSMakeRect(0, 0, 18, 18))
                    loadingView?.progressColor = theme.colors.grayText
                    containerView.addSubview(loadingView!)
                }
                rightActionView.isHidden = true
            }
        } else {
            rightActionView.isHidden = true
            loadingView?.removeFromSuperview()
            loadingView = nil
        }
        
        if let placeholder = item.placeholder {
            if let icon = placeholder.icon {
                if placeholderAction == nil {
                    self.placeholderAction = ImageButton()
                    containerView.addSubview(self.placeholderAction!)
                    if animated {
                        placeholderAction!.layer?.animateAlpha(from: 0, to: 2, duration: 0.2)
                    }
                }
                guard let placeholderAction = self.placeholderAction else {
                    return
                }
                placeholderAction.set(image: icon, for: .Normal)
                placeholderAction.set(image: icon, for: .Highlight)
                placeholderAction.set(image: icon, for: .Hover)
                _ = placeholderAction.sizeToFit()
                placeholderAction.removeAllHandlers()
                placeholderAction.set(handler: { _ in
                    placeholder.action?()
                }, for: .SingleClick)
            } else {
                if let placeholderAction {
                    performSubviewRemoval(placeholderAction, animated: animated)
                    self.placeholderAction = nil
                }
            }
            
            
        } else {
            if let placeholderAction {
                performSubviewRemoval(placeholderAction, animated: animated)
                self.placeholderAction = nil
            }
        }
        
        if item.hasTextLimitation {
            textLimitation.isHidden = item.state.inputText.string.length < item.limit / 3 * 2 || item.state.inputText.string.length == item.limit || !item.enabled
            let color: NSColor = item.state.inputText.string.length > item.limit ? theme.colors.redUI : theme.colors.grayText
            textLimitation.attributedString = .initialize(string: "\(item.limit - Int32(item.state.inputText.string.length))", color: color, font: .normal(.small))
            textLimitation.sizeToFit()
        } else {
            textLimitation.isHidden = true
        }
        
        
        if item.hasEmoji {
            let current: ImageButton
            if let view = self.emoji {
                current = view
            } else {
                current = ImageButton()
                current.autohighlight = false
                current.scaleOnClick = true
                addSubview(current)
                self.emoji = current
                
                current.set(handler: { [weak self] control in
                    if let item = self?.item as? InputTextDataRowItem {
                        let emojis = EmojiesController(item.context, ignorePremium: true)
                        emojis._frameRect = NSMakeRect(0, 0, 350, 300)
                        let interactions = EntertainmentInteractions(.emoji, peerId: item.context.peerId)
                        emojis.update(with: interactions, chatInteraction: .init(chatLocation: .peer(item.context.peerId), context: item.context))

                        interactions.sendAnimatedEmoji = { [weak self] sticker, _, _, _, _ in
                            if let item = self?.item as? InputTextDataRowItem, let textView = self?.textView {
                                self?.textView.makeFirstResponder()
                                let text = sticker.file._parse().customEmojiText ?? sticker.file._parse().stickerText ?? clown
                                let state = textView.interactions.insertText(.makeAnimated(sticker.file._parse(), text: text))
                                item.updateState(state)
                                self?.set(state)
                            }
                        }
                        interactions.sendEmoji = { [weak self] string, _ in
                            self?.textView.makeFirstResponder()
                            if let item = self?.item as? InputTextDataRowItem, let textView = self?.textView {
                                let state = textView.interactions.insertText(.initialize(string: string))
                                item.updateState(state)
                                self?.set(state)
                            }
                        }
                        
                        showPopover(for: control, with: emojis)
                    }
                }, for: .Click)
            }
            current.set(image: NSImage.init(resource: .iconCustomEmojiSmall).precomposed(theme.colors.grayIcon), for: .Normal)
            current.sizeToFit()
        } else if let view = self.emoji {
            performSubviewRemoval(view, animated: animated)
            self.emoji = view
        }
        
        
        textView.placeholderFontSize = 13
        textView.placeholder = item.inputPlaceholder.string
        
        textView.context = item.context
        textView.interactions.max_height = 500
        textView.interactions.min_height = 20
        textView.interactions.allowedLinkHosts = item.allowedLinkHosts
        textView.interactions.canTransform = item.canMakeTransformations
        textView.interactions.simpleTransform = item.simpleTransform
        textView.interactions.inputIsEnabled = item.enabled
        
        
        self.textView.change(opacity: item.enabled ? 1 : 0.5, animated: animated)
        self.rightActionView.isHidden = !item.enabled
        self.placeholderAction?.isHidden = !item.enabled
        self.emoji?.isHidden = !item.enabled

        let prevPolicy = textView.interactions.emojiPlayPolicy
            
        textView.interactions.emojiPlayPolicy = item.playAnimation ? .loop : .framesCount(1)

        if prevPolicy != textView.interactions.emojiPlayPolicy {
            textView.updatePlayPolicy(textView.interactions.emojiPlayPolicy)
        }
        
        
        textView.interactions.filterEvent = { event in
            if let chars = event.characters {
                return !item.filter(chars).isEmpty
            } else {
                return false
            }
        }
        
        textView.interactions.inputDidUpdate = { _ in }
        
        self.textView.set(item.state.textInputState())

        
        textView.interactions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
    }
    
    var textWidth: CGFloat {
        guard let item = item as? InputTextDataRowItem else {
            return frame.width
        }
        return item.textWidth
    }
    
    func textViewSize() -> (NSSize, CGFloat) {
        let w = textWidth
        let height = textView.height(for: w)
        return (NSMakeSize(w, min(max(height, textView.min_height), textView.max_height)), height)
    }
    
    private func inputDidUpdateLayout(animated: Bool) {
        updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    private func set(_ state: Updated_ChatTextInputState) {
        guard let item = item as? InputTextDataRowItem else {
            return
        }
        
        let context = item.context
        
        item.updateState(state)
        
        
        let input = state.textInputState()
        
        let textInputContextState = textInputStateContextQueryRangeAndType(input, includeContext: false)
        var cleanup = true
        if let textInputContextState = textInputContextState, item.hasEmoji {
            if textInputContextState.1.contains(.swapEmoji) {
                let stringRange = textInputContextState.0
                let range = NSRange(string: input.inputText, range: stringRange)
                if !input.isAnimatedEmoji(at: range) {
                    let query = String(input.inputText[stringRange])
                    let signal = InputSwapSuggestionsPanelItems(query, peerId: context.peerId, context: context, ignorePremium: item.hasEmoji)
                    |> deliverOnMainQueue
                    self.inputSwapDisposable.set(signal.start(next: { [weak self] files in
                        self?.updateTextInputSuggestions(files, range: range, animated: true)
                    }))
                    cleanup = false
                }
            }
        }
        
        if cleanup {
            self.updateTextInputSuggestions([], range: NSMakeRange(0, 0), animated: true)
            self.inputSwapDisposable.set(nil)
        }
        
    }
    
}
