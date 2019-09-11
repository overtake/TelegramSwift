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
    private let updated:(String)->Void
    fileprivate(set) var currentText: String = "" {
        didSet {
            if currentText != oldValue {
                updated(currentText)
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
    fileprivate var realInputHeight: CGFloat = 21
    
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

    override var height: CGFloat {
        switch viewType {
        case .legacy:
            var height = inputHeight + 8
            if let errorLayout = errorLayout  {
                height += (height == 42 ? errorLayout.layoutSize.height : errorLayout.layoutSize.height / 2)
            }
            return height
        case let .modern(_, insets):
            var inputHeight = realInputHeight
            switch self.mode {
            case .plain:
                break
            case .secure:
                inputHeight -= 6
            }
            let height = inputHeight + insets.top + insets.bottom + inset.top + inset.bottom
//            if let errorLayout = errorLayout  {
//                height += errorLayout.layoutSize.height + 4
//            }
            return height
        }
       
    }
    fileprivate let mode: InputDataInputMode
    init(_ initialSize: NSSize, stableId: AnyHashable, mode: InputDataInputMode, error: InputDataValueError?, viewType: GeneralViewType = .legacy, currentText: String, placeholder: InputDataInputPlaceholder?, inputPlaceholder: String, filter:@escaping(String)->String, updated:@escaping(String)->Void, limit: Int32) {
        self.filter = filter
        self.limit = limit
        self.updated = updated
        self.placeholder = placeholder
        self.inputPlaceholder = .initialize(string: inputPlaceholder, color: theme.colors.grayText, font: .normal(.text))
        placeholderLayout = placeholder?.placeholder != nil ? TextViewLayout(.initialize(string: placeholder!.placeholder!, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1) : nil
    
        self.currentText = currentText
        self.mode = mode
    
        super.init(initialSize, stableId: stableId, viewType: viewType, error: error)
        
       
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
    
    func calculateHeight() {
        _ = self.makeSize(self.width, oldWidth: self.width)
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
        
        
        switch viewType {
        case .legacy:
            let textContainer = NSTextContainer(size: NSMakeSize(initialSize.width - inset.left - inset.right - textFieldLeftInset - additionalRightInset, .greatestFiniteMagnitude))
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            self.realInputHeight = max(34, layoutManager.usedRect(for: textContainer).height + 6)
            inputHeight = max(34, layoutManager.usedRect(for: textContainer).height + 6)
        case let .modern(_, insets):
            let textContainer = NSTextContainer(size: NSMakeSize(self.blockWidth - insets.left - insets.right - textFieldLeftInset - additionalRightInset, .greatestFiniteMagnitude))
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            switch self.mode {
            case .plain:
                self.realInputHeight = max(16, layoutManager.usedRect(for: textContainer).height)
            case .secure:
                self.realInputHeight = max(22, layoutManager.usedRect(for: textContainer).height)
            }
            inputHeight = max(34, layoutManager.usedRect(for: textContainer).height + 1)
        }
        
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


class InputDataRowView : GeneralRowView, TGModernGrowingDelegate, NSTextFieldDelegate {
    internal let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let placeholderTextView = TextView()
    private let resortingView: ImageButton = ImageButton()
    private var placeholderAction: ImageButton = ImageButton()
    internal let textView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect, unscrollable: true)
    private let secureField: InputDataSecureField = InputDataSecureField(frame: NSMakeRect(0, 0, 100, 16))
    private let textLimitation: TextViewLabel = TextViewLabel(frame: NSMakeRect(0, 0, 16, 14))
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(placeholderAction)
        containerView.addSubview(placeholderTextView)
        containerView.addSubview(textView)
        containerView.addSubview(secureField)
        containerView.addSubview(separator)
        containerView.addSubview(resortingView)
        containerView.addSubview(textLimitation)
        addSubview(containerView)
        placeholderAction.autohighlight = false
        resortingView.autohighlight = false
        
        containerView.userInteractionEnabled = false
        
        textLimitation.alignment = .right
        
        containerView.displayDelegate = self
        
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
        
        switch item.viewType {
        case .legacy:
            self.containerView.frame = bounds
            self.containerView.setCorners([])
            placeholderTextView.setFrameOrigin(item.inset.left, 14)
            placeholderAction.setFrameOrigin(item.inset.left, 12)
            
            
            var additionalRightInset: CGFloat = 0
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    separator.frame = NSMakeRect(item.inset.left + item.textFieldLeftInset + 4, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset, .borderSize)
                } else {
                    separator.frame = NSMakeRect(item.inset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right, .borderSize)
                }
                
                if let _ = placeholder.rightResoringImage {
                    resortingView.setFrameOrigin(NSMakePoint(self.containerView.frame.width - resortingView.frame.width - item.inset.right + 4, 14))
                    additionalRightInset += resortingView.frame.width + 6
                }
            } else {
                separator.frame = NSMakeRect(item.inset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right, .borderSize)
            }
            
            
            secureField.setFrameSize(NSMakeSize(self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - additionalRightInset, item.inputHeight))
            secureField.setFrameOrigin(item.inset.left + item.textFieldLeftInset, 14)
            
            textView.setFrameSize(NSMakeSize(self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - additionalRightInset, item.inputHeight))
            textView.setFrameOrigin(item.inset.left + item.textFieldLeftInset - 3, 6)
            
            textLimitation.setFrameOrigin(NSMakePoint(self.containerView.frame.width - item.inset.right - textLimitation.frame.width + 4, self.containerView.frame.height - textLimitation.frame.height - 4))
        case let .modern(position, innerInsets):
            self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            self.containerView.setCorners(position.corners)
         
            self.separator.isHidden = !position.border
            
            placeholderTextView.setFrameOrigin(innerInsets.left, innerInsets.top)
            placeholderAction.setFrameOrigin(innerInsets.left, innerInsets.top)
            
            var additionalRightInset: CGFloat = 0
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    separator.frame = NSMakeRect(innerInsets.left + item.textFieldLeftInset + 4, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInsets.left - innerInsets.right - item.textFieldLeftInset, .borderSize)
                } else {
                    separator.frame = NSMakeRect(innerInsets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - innerInsets.right, .borderSize)
                }
                
                if let _ = placeholder.rightResoringImage {
                    resortingView.setFrameOrigin(NSMakePoint(self.containerView.frame.width - resortingView.frame.width - innerInsets.right + 4, 14))
                    additionalRightInset += resortingView.frame.width + 6
                }
            } else {
                separator.frame = NSMakeRect(innerInsets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInsets.left - innerInsets.right, .borderSize)
            }
            
            
            secureField.setFrameSize(NSMakeSize(self.containerView.frame.width - innerInsets.left - innerInsets.right - item.textFieldLeftInset - additionalRightInset, item.inputHeight))
            secureField.setFrameOrigin(innerInsets.left + item.textFieldLeftInset, innerInsets.top)
            
            textView.setFrameSize(NSMakeSize(self.containerView.frame.width - innerInsets.left - innerInsets.right - item.textFieldLeftInset - additionalRightInset, item.inputHeight))
            if item.realInputHeight <= 16 {
                textView.setFrameOrigin(innerInsets.left + item.textFieldLeftInset - 3, innerInsets.top - 8)
            } else {
                textView.setFrameOrigin(innerInsets.left + item.textFieldLeftInset - 3, innerInsets.top )
            }
            
            textLimitation.setFrameOrigin(NSMakePoint(self.containerView.frame.width - innerInsets.right - textLimitation.frame.width + 4, self.containerView.frame.height - textLimitation.frame.height - 4))

            
        }
    }
    
    public func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        if let item = item as? InputDataRowItem {
            return item.limit
        }
        return 100000
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        NSSound.beep()
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        if let item = item as? InputDataRowItem, let table = item.table {
            item.inputHeight = height
            
            
            textLimitation.change(pos: NSMakePoint(containerView.frame.width - item.inset.right - textLimitation.frame.width + 4, item.height - textLimitation.frame.height), animated: animated)
            
            
            item.calculateHeight()
            
            change(size: NSMakeSize(item.width, item.height), animated: animated)

            switch item.viewType {
            case .legacy:
                break
            case .modern:
                self.containerView.change(size: NSMakeSize(item.blockWidth, item.height - item.inset.bottom - item.inset.top), animated: animated)
            }
            
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    separator.change(pos: NSMakePoint(separator.frame.minX, self.containerView.frame.height - .borderSize), animated: animated)
                } else {
                    separator.change(pos: NSMakePoint(separator.frame.minX, self.containerView.frame.height - .borderSize), animated: animated)
                }
            } else {
                separator.change(pos: NSMakePoint(separator.frame.minX, self.containerView.frame.height - .borderSize), animated: animated)
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
            let prevInputHeight = item.realInputHeight
            let prevHeight = item.inputHeight
            item.calculateHeight()
            if prevInputHeight != item.realInputHeight && prevHeight == item.inputHeight {
                textViewHeightChanged(item.inputHeight, animated: true)
            }
            self.needsLayout = true
            containerView.needsDisplay = true
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
            let prevInputHeight = item.realInputHeight
            item.calculateHeight()
            if prevInputHeight != item.realInputHeight {
                textViewHeightChanged(item.inputHeight, animated: true)
            }
            self.needsLayout = true
            containerView.needsDisplay = true
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
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        placeholderTextView.backgroundColor = backdorColor
        textView.cursorColor = theme.colors.indicatorColor
        textView.textFont = .normal(.text)
        textView.textColor = theme.colors.text
        textView.background = backdorColor
        secureField.font = .normal(13)
        secureField.backgroundColor = backdorColor
        secureField.textColor = theme.colors.text
        separator.backgroundColor = theme.colors.border
        containerView.backgroundColor = backdorColor
        guard let item = item as? InputDataRowItem else {
            return
        }
        self.background = item.viewType.rowBackground
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
        
        switch item.viewType {
        case .legacy:
            containerView.setCorners([], animated: animated)
        case let .modern(position, _):
            containerView.setCorners(position.corners, animated: animated)
        }
        
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
            textView.update(false)
            textView.needsDisplay = true
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

        containerView.needsDisplay = true
        self.layout()

    }
}
