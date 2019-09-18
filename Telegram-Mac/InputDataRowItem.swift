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

enum InputDataRightItemAction : Equatable {
    case clearText
    case resort
    case none
}

enum InputDataRightItem : Equatable {
    case action(CGImage, InputDataRightItemAction)
    case loading
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
    fileprivate let defaultText: String?
    fileprivate let mode: InputDataInputMode
    fileprivate let rightItem: InputDataRightItem?
    fileprivate let pasteFilter:((String)->(Bool, String))?
    init(_ initialSize: NSSize, stableId: AnyHashable, mode: InputDataInputMode, error: InputDataValueError?, viewType: GeneralViewType = .legacy, currentText: String, placeholder: InputDataInputPlaceholder?, inputPlaceholder: String, defaultText: String? = nil, rightItem: InputDataRightItem? = nil, filter:@escaping(String)->String, updated:@escaping(String)->Void, pasteFilter:((String)->(Bool, String))? = nil, limit: Int32) {
        self.filter = filter
        self.limit = limit
        self.updated = updated
        self.placeholder = placeholder
        self.pasteFilter = pasteFilter
        self.defaultText = defaultText
        self.rightItem = rightItem
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
    
    private(set) fileprivate var additionRightInset: CGFloat = 0
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let currentAttributed: NSMutableAttributedString = NSMutableAttributedString()
        _ = currentAttributed.append(string: (defaultText ?? "") + currentText, font: .normal(.text))
        
        if mode == .secure {
            currentAttributed.setAttributedString(.init(string: String(currentText.map { _ in return "•" })))
            currentAttributed.addAttribute(.font, value: NSFont.normal(15.0 + 3.22), range: currentAttributed.range)
        }
        
        let textStorage = NSTextStorage(attributedString: currentAttributed)
        
        if let rightItem = self.rightItem {
            switch rightItem {
            case .loading:
                self.additionRightInset = 20
            case let .action(icon, _):
                self.additionRightInset = icon.backingSize.width + 2
            }
        } else {
            self.additionRightInset = 0
        }
        
        switch viewType {
        case .legacy:
            let textContainer = NSTextContainer(size: NSMakeSize(initialSize.width - inset.left - inset.right - textFieldLeftInset - additionRightInset, .greatestFiniteMagnitude))
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            self.realInputHeight = max(34, layoutManager.usedRect(for: textContainer).height + 6)
            inputHeight = max(34, layoutManager.usedRect(for: textContainer).height + 6)
        case let .modern(_, insets):
            let textContainer = NSTextContainer(size: NSMakeSize(self.blockWidth - insets.left - insets.right - textFieldLeftInset - additionRightInset, .greatestFiniteMagnitude))
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
    private let rightActionView: ImageButton = ImageButton()
    private var loadingView: ProgressIndicator? = nil
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
        containerView.addSubview(rightActionView)
        containerView.addSubview(textLimitation)
        addSubview(containerView)
        placeholderAction.autohighlight = false
        rightActionView.autohighlight = false
        
        containerView.userInteractionEnabled = false
        
        textLimitation.alignment = .right
        
        
        
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
        
        textView.max_height = 10000
        
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
            placeholderTextView.setFrameOrigin(item.inset.left, 14)
            placeholderAction.setFrameOrigin(item.inset.left, 12)
            
            
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    separator.frame = NSMakeRect(item.inset.left + item.textFieldLeftInset + 4, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset, .borderSize)
                } else {
                    separator.frame = NSMakeRect(item.inset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right, .borderSize)
                }
                if let rightItem = item.rightItem {
                    switch rightItem {
                    case .action:
                        rightActionView.setFrameOrigin(NSMakePoint(self.containerView.frame.width - rightActionView.frame.width - item.inset.right + 4, 14))
                    default:
                        break
                    }
                }
            } else {
                separator.frame = NSMakeRect(item.inset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right, .borderSize)
            }
            
            
            secureField.setFrameSize(NSMakeSize(self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - item.additionRightInset, item.inputHeight))
            secureField.setFrameOrigin(item.inset.left + item.textFieldLeftInset, 14)
            
            textView.setFrameSize(NSMakeSize(self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - item.additionRightInset, item.inputHeight))
            textView.setFrameOrigin(item.inset.left + item.textFieldLeftInset - 3, 6)
            
            textLimitation.setFrameOrigin(NSMakePoint(self.containerView.frame.width - item.inset.right - textLimitation.frame.width + 4, self.containerView.frame.height - textLimitation.frame.height - 4))
        case let .modern(position, innerInsets):
            self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
         
            self.separator.isHidden = !position.border
            
            placeholderTextView.setFrameOrigin(innerInsets.left, innerInsets.top)
            placeholderAction.setFrameOrigin(innerInsets.left, innerInsets.top)
            
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    separator.frame = NSMakeRect(innerInsets.left + item.textFieldLeftInset + 4, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInsets.left - innerInsets.right - item.textFieldLeftInset, .borderSize)
                } else {
                    separator.frame = NSMakeRect(innerInsets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - innerInsets.right, .borderSize)
                }
            } else {
                separator.frame = NSMakeRect(innerInsets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInsets.left - innerInsets.right, .borderSize)
            }
            
            if let rightItem = item.rightItem {
                switch rightItem {
                case .action:
                    if item.realInputHeight <= 16 {
                        rightActionView.centerY(x: self.containerView.frame.width - rightActionView.frame.width - innerInsets.right)
                    } else {
                        rightActionView.setFrameOrigin(NSMakePoint(self.containerView.frame.width - rightActionView.frame.width - innerInsets.right, innerInsets.top))
                    }
                case .loading:
                    if let loadingView = loadingView  {
                        if item.realInputHeight <= 16 {
                            loadingView.centerY(x: self.containerView.frame.width - loadingView.frame.width - innerInsets.right)
                        } else {
                            loadingView.setFrameOrigin(NSMakePoint(self.containerView.frame.width - loadingView.frame.width - innerInsets.right, innerInsets.top))
                        }
                    }
                }
            }
            
            
            secureField.setFrameSize(NSMakeSize(item.blockWidth - innerInsets.left - innerInsets.right - item.textFieldLeftInset - item.additionRightInset, item.inputHeight))
            secureField.setFrameOrigin(innerInsets.left + item.textFieldLeftInset, innerInsets.top)
            
            textView.setFrameSize(NSMakeSize(item.blockWidth - innerInsets.left - innerInsets.right - item.textFieldLeftInset - item.additionRightInset, item.inputHeight))
            
            if item.realInputHeight <= 16 {
                textView.setFrameOrigin(innerInsets.left + item.textFieldLeftInset - 3, innerInsets.top - 8)
            } else {
                textView.setFrameOrigin(innerInsets.left + item.textFieldLeftInset - 3, innerInsets.top )
            }
            
            textLimitation.setFrameOrigin(NSMakePoint(item.blockWidth - innerInsets.right - textLimitation.frame.width, self.containerView.frame.height - innerInsets.bottom - textLimitation.frame.height))

            
        }
    }
    
    public func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        if let item = item as? InputDataRowItem {
            return item.limit
        }
        return 100000
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        if let item = item as? InputDataRowItem {
            switch item.mode {
            case .plain:
                self.textView.shake()
            case .secure:
                self.secureField.shake()
            }
        }
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        if let item = item as? InputDataRowItem, let pasteFilter = item.pasteFilter {
            if let string = pasteboard.string(forType: .string) {
                let value = pasteFilter(string)
                let updatedText = item.filter(value.1)
                if value.0 {
                    switch item.mode {
                    case .plain:
                        textView.setString(updatedText)
                    case .secure:
                        secureField.stringValue = updatedText
                    }
                } else {
                    switch item.mode {
                    case .plain:
                        textView.appendText(updatedText)
                    case .secure:
                        secureField.stringValue = secureField.stringValue + updatedText
                    }
                }
                return true
            }
            
        }
        return false
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        if let item = item as? InputDataRowItem, let table = item.table {
            item.inputHeight = height
            
            
            switch item.viewType {
            case .legacy:
                textLimitation.change(pos: NSMakePoint(containerView.frame.width - item.inset.right - textLimitation.frame.width + 4, item.height - textLimitation.frame.height), animated: animated)
            case let .modern(_, insets):
                textLimitation.change(pos: NSMakePoint(item.blockWidth - insets.right - textLimitation.frame.width , item.height - textLimitation.frame.height - insets.bottom), animated: animated)
            }
            
            item.calculateHeight()
            
            change(size: NSMakeSize(item.width, item.height), animated: animated)

            let containerRect: NSRect
            switch item.viewType {
            case .legacy:
                containerRect = self.bounds
            case .modern:
                containerRect = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, item.height - item.inset.bottom - item.inset.top)
            }
            containerView.change(size: containerRect.size, animated: animated, corners: item.viewType.corners)
            containerView.change(pos: containerRect.origin, animated: animated)
            
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
            containerView.needsDisplay = true
        }
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
//    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
//        if let item = item as? InputDataRowItem, let string = pasteboard.string(forType: .string) {
//            let updated = item.filter(string)
//            if updated == string {
//                return false
//            } else {
//                NSSound.beep()
//                shakeView()
//            }
//        }
//        return true
//    }
    
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
        loadingView?.progressColor = theme.colors.grayText
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
        
        self.textView.animates = false
        super.set(item: item, animated: animated)
        self.textView.animates = true
        
        placeholderTextView.isHidden = item.placeholderLayout == nil
        placeholderTextView.update(item.placeholderLayout)
        placeholderAction.isHidden = item.placeholder?.icon == nil
        
        let containerRect: NSRect
        switch item.viewType {
        case .legacy:
            containerRect = self.bounds
        case .modern:
            containerRect = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, item.height - item.inset.bottom - item.inset.top)
        }
        containerView.change(size: containerRect.size, animated: animated, corners: item.viewType.corners)
        containerView.change(pos: containerRect.origin, animated: animated)

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
                        self?.secureField.stringValue = ""
                        self?.textView.setString("")
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
                placeholderAction.set(image: icon, for: .Normal)
                _ = placeholderAction.sizeToFit()
                placeholderAction.removeAllHandlers()
                placeholderAction.set(handler: { _ in
                    placeholder.action?()
                }, for: .SingleClick)
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
            if textView.defaultText != (item.defaultText ?? "") {
                textView.defaultText = item.defaultText ?? ""
                textView.setString(item.currentText, animated: false)
            } else if item.currentText != textView.string() {
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
        
        containerView.needsDisplay = true
        self.needsLayout = true

    }
}
