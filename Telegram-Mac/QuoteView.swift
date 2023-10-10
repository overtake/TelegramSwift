//
//  QuoteView.swift
//  Telegram
//
//  Created by Mike Renoir on 03.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TGModernGrowingTextView

class QuoteTextAttachment : TGTextAttachment {
    let input: ChatTextInputState
    var range: NSRange = NSMakeRange(NSNotFound, 0)
    
    let layout: TextViewLayout
    
    init(identifier: String, input: ChatTextInputState, initialSize: NSSize) {
        self.input = input
        
        let cutout = TextViewCutout(topRight: NSMakeSize(5, 5))
        let layout = TextViewLayout(input.attributedString(theme), cutout: cutout)
        self.layout = layout
        super.init(identifier: identifier, fileId: 0, file: nil, text: input.inputText, info: nil, from: .zero, type: TGTextAttachment.quote)
        self.bounds = CGRect.init(origin: .zero, size: self.measure(initialSize))
    }
    
    func measure(_ textSize: NSSize) -> NSSize {
        self.layout.measure(width: textSize.width - 41)
        return NSMakeSize(textSize.width, self.layout.layoutSize.height + 10 + 8)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func makeSize(for view: NSView, textViewSize textSize: NSSize, range: NSRange) -> NSSize {
        self.range = range
        let newSize = self.measure(textSize)
        self.bounds = newSize.bounds
        
        if let view = view as? InputQuoteView {
            let size = view.measure(textSize)
            return size
        } else {
            return .zero
        }
    }
    
    
}


class QuoteView : Control {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDragged(with event: NSEvent) {
        superview?.mouseDragged(with: event)
    }
}


class InputQuoteView : QuoteView, Notifable {
    
    private let imageView = ImageView()
    private let textView = TextView()
    private let container = View()
    private let line = View()
    
    private var attachment: QuoteTextAttachment?
    private var interaction: ChatInteraction?
    
    var isEditing: Bool {
        return _selected
    }
    
    private var _selected: Bool = false {
        didSet {
            if oldValue != _selected {
                self.updateColors()
            }
        }
    }
    
    private var _selectedRange: NSRange? = nil

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(line)
        container.addSubview(textView)
        container.addSubview(imageView)
        container.layer?.cornerRadius = .cornerRadius
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            self.selectAttachment()
        }, for: .Click)
        
        layer?.masksToBounds = false
    
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value.effectiveInput != oldValue.effectiveInput {
                self.inputDidUpdate(value.effectiveInput)
            }
        }
    }
    
    private func selectAttachment() {
        guard let interaction = self.interaction else {
            return
        }
        let input = interaction.presentation.effectiveInput
        
        guard let attachment = self.attachment else {
            return
        }
        self.interaction?.update({ value in
            var value = value
            let input = value.effectiveInput
            let updatedInput = ChatTextInputState(inputText: input.inputText, selectionRange: attachment.input.selectionRange, attributes: input.attributes)
            value = value.withUpdatedEffectiveInputState(updatedInput)
            return value
        })
    }
    
    
    private func inputDidUpdate(_ input: ChatTextInputState) -> Void {
        
        
        guard let attachment = self.attachment else {
            return
        }
        let selectedRange = NSMakeRange(input.selectionRange.lowerBound, input.selectionRange.upperBound - input.selectionRange.lowerBound)
        
        let attachRange = NSMakeRange(attachment.input.selectionRange.lowerBound, attachment.input.selectionRange.upperBound - attachment.input.selectionRange.lowerBound)
        
        let intersection = selectedRange.intersection(attachRange)
        _selected = intersection != nil && intersection!.length > 0
        
        _selectedRange = selectedRange
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? InputQuoteView {
            return other === self
        }
        return false
    }
    
    private func updateColors() {
        self.container.backgroundColor = theme.colors.accent.withAlphaComponent(isEditing ? 0.4 : 0.2)
        self.line.backgroundColor = theme.colors.accent
        self.imageView.image = theme.icons.message_quote_accent
        self.imageView.sizeToFit()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        updateColors()
    }
    
    func set(_ attachment: QuoteTextAttachment, interaction: ChatInteraction) {
        self.attachment = attachment
        self.updateLocalizationAndTheme(theme: theme)
        self.interaction = interaction
        
        interaction.add(observer: self)
        self.update(attachment)
    }
    
    func measure(_ textSize: NSSize) -> NSSize {
        self.textView.resize(textSize.width - 41)
        return NSMakeSize(textSize.width, self.textView.frame.height + 10 + 8)
    }
    
    func update(_ attachment: QuoteTextAttachment) {
        self.textView.update(attachment.layout)
        needsLayout = true
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        self.container.setFrameSize(NSMakeSize(frame.width - 6, self.textView.frame.height + 10))
        self.container.centerY(x: 6)
        self.textView.centerY(x: 15)
        self.imageView.setFrameOrigin(NSMakePoint(container.frame.width - imageView.frame.width - 5, 4))
        self.line.frame = NSMakeRect(0, 0, 4, container.frame.height)
    }
}
