//
//  InputDataRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

protocol InputDataRowDataValue {
    var value: InputDataValue { get }
}

class InputDataRowItem: GeneralRowItem, InputDataRowDataValue {

    fileprivate let placeholderLayout: TextViewLayout
    fileprivate let inputPlaceholder: NSAttributedString
    fileprivate let filter:(String)->String
    fileprivate let limit:Int32
    private let updated:()->Void
    fileprivate(set) var currentText: String = "" {
        didSet {
            if currentText != oldValue {
                updated()
            }
        }
    }
    
    var value: InputDataValue {
        return .string(currentText)
    }
    
    fileprivate var inputHeight: CGFloat = 21
    override var height: CGFloat {
        var height = inputHeight + 8
        if let errorLayout = errorLayout  {
            height += (height == 42 ? errorLayout.layoutSize.height : errorLayout.layoutSize.height / 2)
        }
        return height
    }
    fileprivate let mode: InputDataInputMode
    init(_ initialSize: NSSize, stableId: AnyHashable, mode: InputDataInputMode, error: InputDataValueError?, currentText: String, placeholder: String, inputPlaceholder: String, filter:@escaping(String)->String, updated:@escaping()->Void, limit: Int32) {
        self.filter = filter
        self.limit = limit
        self.updated = updated
        self.inputPlaceholder = .initialize(string: inputPlaceholder, color: theme.colors.grayText, font: .normal(.text))
        placeholderLayout = TextViewLayout(.initialize(string: placeholder, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
    
        self.currentText = currentText
        self.mode = mode
        super.init(initialSize, stableId: stableId, error: error)
        
        let textStorage = NSTextStorage(attributedString: .initialize(string: currentText, font: .normal(.text), coreText: false))
        let textContainer = NSTextContainer(size: NSMakeSize(initialSize.width - inset.left - inset.right - textFieldLeftInset, .greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        
        inputHeight = max(34, layoutManager.usedRect(for: textContainer).height + 6)
        
        _ = makeSize(initialSize.width, oldWidth: oldWidth)
    }
    
    var textFieldLeftInset: CGFloat {
        return 100
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        placeholderLayout.measure(width: 100)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return InputDataRowView.self
    }
    
}


final class InputDataRowView : GeneralRowView, TGModernGrowingDelegate, NSTextFieldDelegate {
    private let placeholderTextView = TextView()
    private let textView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let secureField: NSSecureTextField = NSSecureTextField(frame: NSMakeRect(0, 0, 100, 16))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(placeholderTextView)
        addSubview(textView)
        addSubview(secureField)
    //    textView.max_height = 34
        textView.isSingleLine = true
        textView.delegate = self
        placeholderTextView.userInteractionEnabled = false
        placeholderTextView.isSelectable = false
        
        secureField.isBordered = false
        secureField.isBezeled = false
        secureField.focusRingType = .none
        secureField.delegate = self
        secureField.drawsBackground = true
        secureField.isEditable = true
        secureField.isSelectable = true
        
        
        secureField.font = .normal(.text)
        secureField.textView?.insertionPointColor = theme.colors.text
        secureField.sizeToFit()
        
    }
    
    override func shakeView() {
        if !secureField.isHidden {
            secureField.shake()
        }
        if !textView.isHidden {
            textView.shake()
        }
    }
    
    override func hasFirstResponder() -> Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? InputDataRowItem else {return}
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataRowItem else {return}
        placeholderTextView.setFrameOrigin(item.inset.left, 14)
        
        secureField.setFrameSize(NSMakeSize(frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset, secureField.frame.height))
        secureField.setFrameOrigin(item.inset.left + item.textFieldLeftInset, 14)

        textView.setFrameSize(NSMakeSize(frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset, textView.frame.height))
        textView.setFrameOrigin(item.inset.left + item.textFieldLeftInset - 2, 5)
        

    }
    
    public func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        if let item = item as? InputDataRowItem {
            return item.limit
        }
        return 100
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        if let item = item as? InputDataRowItem, let table = item.table {
            item.inputHeight = height
            
            table.noteHeightOfRow(item.index, animated)

        }
        
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return textView.frame.size
    }
    
    func textViewEnterPressed(_ event:NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func textViewNeedClose(_ textView: Any) {
        
    }
    
    func textViewTextDidChange(_ string: String) {
        if let item = item as? InputDataRowItem {
            let updated = item.filter(string)
            if updated != string {
                textView.setString(updated)
            } else {
                item.currentText = string
            }
        }
    }
    
    
    
    override func controlTextDidChange(_ obj: Notification) {
        if let item = item as? InputDataRowItem {
            let string = secureField.stringValue
            let updated = item.filter(string)
            if updated != string {
                secureField.stringValue = updated
            } else {
                item.currentText = string
            }
        }
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        if let item = item as? InputDataRowItem, let string = pasteboard.string(forType: .string) {
            let updated = item.filter(string)
            if updated == string {
                return false
            } else {
                NSSound.beep()
                shakeView()
            }
        }
        return true
    }
    
    override func updateColors() {
        placeholderTextView.backgroundColor = theme.colors.background
        textView.cursorColor = theme.colors.indicatorColor
        textView.textFont = .normal(.text)
        textView.textColor = theme.colors.text
        secureField.font = .normal(.text)
        secureField.backgroundColor = theme.colors.background
        
        secureField.textColor = theme.colors.text
    }
    
 
    override var mouseInsideField: Bool {
        return secureField._mouseInside() || textView._mouseInside()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        switch true {
        case NSPointInRect(point, secureField.frame):
            return secureField
        case NSPointInRect(point, textView.frame):
            return textView
        default:
            return super.hitTest(point)
        }
    }
    
    override var firstResponder: NSResponder? {
        if let item = item as? InputDataRowItem {
            switch item.mode {
            case .plain:
                return textView.inputView
            case .secure:
                return secureField
            }
        }
        return super.firstResponder
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InputDataRowItem else {return}
        placeholderTextView.update(item.placeholderLayout)
        

        
        switch item.mode {
        case .plain:
            secureField.isHidden = true
            textView.isHidden = false
            textView.animates = false
            textView.setPlaceholderAttributedString(item.inputPlaceholder, update: false)
            if item.currentText != textView.string() {
                textView.setString(item.currentText, animated: false)
            }
            textView.animates = true
        case .secure:
            secureField.placeholderAttributedString = item.inputPlaceholder
            secureField.isHidden = false
            textView.isHidden = true
            if item.currentText != secureField.stringValue {
                secureField.stringValue = item.currentText
            }
            secureField.sizeToFit()
        }
        
        
        
        needsLayout = true
        needsDisplay = true
    }
}
