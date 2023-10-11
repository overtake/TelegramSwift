//
//  UIInputView.swift
//  Telegram
//
//  Created by Mike Renoir on 11.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import InputView



final class TextView_Interactions : InterfaceObserver {
    var presentation: Updated_ChatTextInputState
    init(presentation: Updated_ChatTextInputState) {
        self.presentation = presentation
    }
    
    func update(animated:Bool = true, _ f:(Updated_ChatTextInputState)->Updated_ChatTextInputState)->Void {
        let oldValue = self.presentation
        self.presentation = f(presentation)
        if oldValue != presentation {
            self.notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
        }
    }
    
    func insertText(_ text: NSAttributedString, selectedRange:Range<Int>? = nil) -> Updated_ChatTextInputState {
        
        var selectedRange = selectedRange ?? presentation.selectionRange
        let inputText = presentation.inputText.mutableCopy() as! NSMutableAttributedString
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {
            inputText.replaceCharacters(in: NSMakeRange(selectedRange.lowerBound, selectedRange.upperBound - selectedRange.lowerBound), with: text)
            selectedRange = selectedRange.lowerBound ..< selectedRange.lowerBound
        } else {
            inputText.insert(text, at: selectedRange.lowerBound)
        }
        
        let nRange:Range<Int> = selectedRange.lowerBound + text.length ..< selectedRange.lowerBound + text.length
        return Updated_ChatTextInputState(inputText: inputText, selectionRange: nRange)
    }
    
    var inputDidUpdate:((Updated_ChatTextInputState)->Void)?
}




private final class UITextView : View, Notifable, ChatInputTextViewDelegate {
    func inputViewIsEnabled() -> Bool {
        return true
    }
    
    func inputViewProcessEnter(_ theEvent: NSEvent) -> Bool {
        return FastSettings.checkSendingAbility(for: theEvent)
    }
    
    func inputViewMaybeClosed() -> Bool {
        return false
    }
    
    func inputMaximumHeight() -> CGFloat {
        return 340
    }
    
    private var updatingInputState: Bool = false
    
    func chatInputTextViewDidUpdateText() {
        refreshChatTextInputAttributes(self.view.textView, theme: theme.textInput, spoilersRevealed: false, availableEmojis: Set())
        refreshChatTextInputTypingAttributes(self.view.textView, theme: theme.textInput)

        let inputTextState = self.inputTextState
     
        self.interactions.update { _ in
            return inputTextState
        }
    }
    
    var inputTextState: Updated_ChatTextInputState {
        let selectionRange: Range<Int> = view.selectedRange.location ..< (view.selectedRange.location + view.selectedRange.length)
        return Updated_ChatTextInputState(inputText: stateAttributedStringForText(view.attributedText.copy() as! NSAttributedString), selectionRange: selectionRange)
    }

    
    func chatInputTextViewDidChangeSelection(dueToEditing: Bool) {
        if !dueToEditing && !self.updatingInputState {
            let inputTextState = self.inputTextState
            interactions.update { _ in
                inputTextState
            }
        }

    }
    
    func chatInputTextViewDidBeginEditing() {
        
    }
    
    func chatInputTextViewDidFinishEditing() {
        
    }
    
    func chatInputTextViewMenu(forTextRange textRange: NSRange, suggestedActions: [NSMenuItem]) -> ContextMenu {
        return ContextMenu()
    }
    
    func chatInputTextView(shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }
    
    func chatInputTextViewShouldCopy() -> Bool {
        return true
    }
    
    func chatInputTextViewShouldPaste() -> Bool {
        return true
    }
    
    func inputTextCanTransform() -> Bool {
        return true
    }
    
    func inputApplyTransform(_ reason: InputViewTransformReason, textRange: NSRange) {
        switch reason {
        case let .attribute(attribute):
            self.interactions.update({ current in
                return chatTextInputAddFormattingAttribute(current, attribute: attribute)
            })
        case .url:
            guard textRange.min != textRange.max, let window = kitWindow else {
                return
            }
            
            let text = self.interactions.presentation.inputText.attributedSubstring(from: textRange)
            var link: String?
            text.enumerateAttributes(in: NSMakeRange(0, text.length)) { attributes, _, _ in
                if let linkAttribute = attributes[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                    link = linkAttribute.url
                }
            }
            
            showModal(with: InputURLFormatterModalController(string: text.string, defaultUrl: link, completion: { [weak self] text, url in
                self?.interactions.update { current in
                    var current = current
                    if let url = url {
                        current = chatTextInputAddLinkAttribute(current, selectionRange: textRange.min ..< textRange.max, url: url)
                    } else {
                        current = chatTextInputClearFormattingAttributes(current, targetKey: .link)
                    }
                    return current
                }
            }), for: window)
            
        case .clear:
            self.interactions.update({ current in
                return chatTextInputClearFormattingAttributes(current)
            })
        }
    }
    
    func insertText(_ string: NSAttributedString, range: Range<Int>? = nil) {
        let updatedText = self.interactions.insertText(string, selectedRange: range)
        self.interactions.update { _ in
            updatedText
        }
    }
    
    private let view: ChatInputTextView
    let interactions: TextView_Interactions
    
    required init(frame frameRect: NSRect, context: AccountContext, interactions: TextView_Interactions) {
        self.view = ChatInputTextView(frame: frameRect.size.bounds)
        self.interactions = interactions
        super.init(frame: frameRect)
        self.interactions.add(observer: self)
        addSubview(view)
        view.delegate = self
        
        self.view.emojiViewProvider = { attachment, size, theme in
            let rect = size.bounds.insetBy(dx: -1.5, dy: -1.5)
            let view = InputAnimatedEmojiAttach(frame: rect)
            view.set(attachment, size: rect.size, context: context, textColor: theme.textColor)
            return view
        }
        self.view.placeholderString = .initialize(string: "Write a message...", color: theme.colors.grayText, font: .normal(theme.fontSize))
    }
    
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? UITextView {
            return other === self
        }
        return false
    }
        
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? Updated_ChatTextInputState, let oldValue = oldValue as? Updated_ChatTextInputState {
            self.updateInput(current: value, previous: oldValue)
        }
    }
    
    private func updateInput(current: Updated_ChatTextInputState, previous: Updated_ChatTextInputState) {
        
        self.updatingInputState = true
        
        let attributedText = textAttributedStringForStateText(current.inputText, fontSize: theme.textInput.fontSize, textColor: theme.textInput.text, accentTextColor: theme.textInput.accent, writingDirection: nil, spoilersRevealed: false, availableEmojis: Set())
        
        
        let textViewAttributed = textAttributedStringForStateText(view.attributedText.copy() as! NSAttributedString, fontSize: theme.textInput.fontSize, textColor: theme.textInput.text, accentTextColor: theme.textInput.accent, writingDirection: nil, spoilersRevealed: false, availableEmojis: Set())

        
        let selectionRange = NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count)

        if attributedText != textViewAttributed {
            let undoItem = InputViewUndoItem(was: textViewAttributed, be: attributedText, wasRange: self.view.selectedRange, beRange: selectionRange)
            self.view.addUndoItem(undoItem)
        }
        
        refreshChatTextInputAttributes(view.textView, theme: theme.textInput, spoilersRevealed: false, availableEmojis: Set())
        
        self.updatingInputState = false
        self.interactions.inputDidUpdate?(current)

    }
    
    func updateLayout(size: NSSize, textHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.view, frame: size.bounds)
        self.view.updateLayout(size: size, textHeight: textHeight, transition: transition)
    }
    
    func height(for width: CGFloat) -> CGFloat {
        return self.view.textHeightForWidth(width)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.view.theme = theme.inputTheme
    }
}
