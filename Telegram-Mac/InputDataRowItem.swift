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

    fileprivate let placeholderLayout: TextViewLayout?
    fileprivate let placeholder: InputDataInputPlaceholder?
    
    
    fileprivate let inputPlaceholder: NSAttributedString
    fileprivate let filter:(String)->String
    let limit:Int32
    private let updated:()->Void
    fileprivate(set) var currentText: String = "" {
        didSet {
            if currentText != oldValue {
                updated()
            }
        }
    }
    
    var currentAttributed: NSAttributedString {
        return .initialize(string: currentText, font: .normal(.text), coreText: false)
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
    init(_ initialSize: NSSize, stableId: AnyHashable, mode: InputDataInputMode, error: InputDataValueError?, currentText: String, placeholder: InputDataInputPlaceholder?, inputPlaceholder: String, filter:@escaping(String)->String, updated:@escaping()->Void, limit: Int32) {
        self.filter = filter
        self.limit = limit
        self.updated = updated
        self.placeholder = placeholder
        self.inputPlaceholder = .initialize(string: inputPlaceholder, color: theme.colors.grayText, font: .normal(.text))
        placeholderLayout = placeholder?.placeholder != nil ? TextViewLayout(.initialize(string: placeholder!.placeholder!, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1) : nil
    
        self.currentText = currentText
        self.mode = mode
        super.init(initialSize, stableId: stableId, error: error)
        
       
        //.initialize(string: currentText, font: .normal(.text), coreText: false)
        
       
        _ = makeSize(initialSize.width, oldWidth: oldWidth)
    }
    
    var textFieldLeftInset: CGFloat {
        if let placeholder = placeholder {
            if let _ = placeholder.placeholder {
                return 102
            } else {
                if let icon = placeholder.icon {
                    return icon.backingSize.width + 6
                } else {
                    return -2
                }
            }
        } else {
            return -2
        }
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let currentAttributed: NSMutableAttributedString = NSMutableAttributedString()
        _ = currentAttributed.append(string: currentText, font: .normal(.text))
        
        if mode == .secure {
            currentAttributed.setAttributedString(.init(string: String(currentText.map { _ in return "•" })))
            currentAttributed.addAttribute(.font, value: NSFont.normal(15.0 + 3.22), range: currentAttributed.range)
        }
        
        let textStorage = NSTextStorage(attributedString: currentAttributed)
        
        var additionalRightInset: CGFloat = 0
        if let image = placeholder?.rightResoringImage {
            additionalRightInset += image.backingSize.width + 6
        }
        
        let textContainer = NSTextContainer(size: NSMakeSize(initialSize.width - inset.left - inset.right - textFieldLeftInset - additionalRightInset, .greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        
        inputHeight = max(34, layoutManager.usedRect(for: textContainer).height + 6)
        
        let success = super.makeSize(width, oldWidth: oldWidth)
        placeholderLayout?.measure(width: 100)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return InputDataRowView.self
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


final class InputDataRowView : GeneralRowView, TGModernGrowingDelegate, NSTextFieldDelegate {
    private let placeholderTextView = TextView()
    private let resortingView: ImageButton = ImageButton()
    private var placeholderAction: ImageButton = ImageButton()
    private let textView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect, unscrollable: true)
    private let secureField: InputDataSecureField = InputDataSecureField(frame: NSMakeRect(0, 0, 100, 16))
    private let textLimitation: TextViewLabel = TextViewLabel(frame: NSMakeRect(0, 0, 16, 14))
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(placeholderAction)
        addSubview(placeholderTextView)
        addSubview(textView)
        addSubview(secureField)
        addSubview(separator)
        addSubview(resortingView)
        addSubview(textLimitation)
        placeholderAction.autohighlight = false
        resortingView.autohighlight = false
        
        
        
        textLimitation.alignment = .right
        
        resortingView.userInteractionEnabled = false
        
    //    textView.max_height = 34
      // .isSingleLine = true
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
            secureField.setSelectionRange(NSMakeRange(0, secureField.stringValue.length))
        }
        if !textView.isHidden {
            textView.shake()
            textView.setSelectedRange(NSMakeRange(0, textView.string().length))

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

    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataRowItem else {return}
        placeholderTextView.setFrameOrigin(item.inset.left, 14)
        placeholderAction.setFrameOrigin(item.inset.left, 12)
        
        
        var additionalRightInset: CGFloat = 0
        if let placeholder = item.placeholder {
            if placeholder.drawBorderAfterPlaceholder {
                separator.frame = NSMakeRect(item.inset.left + item.textFieldLeftInset + 4, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset, .borderSize)
            } else {
                separator.frame = NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize)
            }
            
            if let _ = placeholder.rightResoringImage {
                resortingView.setFrameOrigin(NSMakePoint(frame.width - resortingView.frame.width - item.inset.right + 4, 14))
                additionalRightInset += resortingView.frame.width + 6
            }
        } else {
            separator.frame = NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize)
        }


        secureField.setFrameSize(NSMakeSize(frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - additionalRightInset, item.inputHeight))
        secureField.setFrameOrigin(item.inset.left + item.textFieldLeftInset, 14)

        textView.setFrameSize(NSMakeSize(frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - additionalRightInset, item.inputHeight))
        textView.setFrameOrigin(item.inset.left + item.textFieldLeftInset - 3, 5)
        
        textLimitation.setFrameOrigin(NSMakePoint(frame.width - item.inset.right - textLimitation.frame.width + 4, frame.height - textLimitation.frame.height - 4))
        
    }
    
    public func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        if let item = item as? InputDataRowItem {
            return item.limit
        }
        return 100
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        NSSound.beep()
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        if let item = item as? InputDataRowItem, let table = item.table {
            item.inputHeight = height
            
            
            textLimitation.change(pos: NSMakePoint(frame.width - item.inset.right - textLimitation.frame.width + 4, item.height - textLimitation.frame.height), animated: animated)
            
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    separator.change(pos: NSMakePoint(item.inset.left + item.textFieldLeftInset + 4, frame.height - .borderSize), animated: animated)
                } else {
                    separator.change(pos: NSMakePoint(item.inset.left, frame.height - .borderSize), animated: animated)
                }
            } else {
                separator.change(pos: NSMakePoint(item.inset.left, frame.height - .borderSize), animated: animated)
            }
            
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
                
                textView.setString(updated, animated: true)
                NSSound.beep()
            } else {
                item.currentText = string
            }
        }
    }
    
    
    
    func controlTextDidChange(_ obj: Notification) {
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
        secureField.font = .normal(13)
        secureField.backgroundColor = theme.colors.background
        secureField.textColor = theme.colors.text
        separator.backgroundColor = theme.colors.border
    }
    
 
    override var mouseInsideField: Bool {
        return secureField._mouseInside() || textView._mouseInside()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
//        switch true {
//        case NSPointInRect(convert(point, from: superview), secureField.frame):
//            return secureField
//        case NSPointInRect(convert(point, from: superview), textView.frame):
//            return textView
//        default:
            return super.hitTest(point)
        //}
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
        
        guard let item = item as? InputDataRowItem else {return}
        
        placeholderTextView.isHidden = item.placeholderLayout == nil
        placeholderTextView.update(item.placeholderLayout)
        placeholderAction.isHidden = item.placeholder?.icon == nil
        
        
        
        resortingView.isHidden = item.placeholder?.rightResoringImage == nil
        
        if let placeholder = item.placeholder {
            if let icon = placeholder.icon {
                placeholderAction.set(image: icon, for: .Normal)
                _ = placeholderAction.sizeToFit()
                placeholderAction.removeAllHandlers()
                placeholderAction.set(handler: { _ in
                    placeholder.action?()
                }, for: .SingleClick)
            }
            if let resortingImage = placeholder.rightResoringImage {
                resortingView.set(image: resortingImage, for: .Normal)
                _ = resortingView.sizeToFit()
            }
            
            if placeholder.hasLimitationText {
                textLimitation.isHidden = item.currentText.length < item.limit / 3 * 2
                textLimitation.attributedString = .initialize(string: "\(item.limit - Int32(item.currentText.length))", color: theme.colors.grayText, font: .normal(.small))
                
                
            } else {
                textLimitation.isHidden = true
            }
        }
        
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
        }
        
        super.set(item: item, animated: animated)

        
        needsLayout = true
    }
}
