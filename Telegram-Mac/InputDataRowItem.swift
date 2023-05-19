//
//  InputDataRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TGModernGrowingTextView

protocol InputDataRowDataValue {
    var value: InputDataValue { get }
}

enum InputDataRightItemAction : Equatable {
    static func == (lhs: InputDataRightItemAction, rhs: InputDataRightItemAction) -> Bool {
        switch lhs {
        case .clearText:
            if case .clearText = rhs {
                return true
            } else {
                return false
            }
        case .resort:
            if case .resort = rhs {
                return true
            } else {
                return false
            }
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case .custom:
            if case .custom = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    case clearText
    case resort
    case custom((TableRowItem, Control)->Void)
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
    private var updatedText: String?
    private var _currentText: NSAttributedString = NSAttributedString() {
        didSet {
            let newValue = currentText.string
            if updatedText != newValue {
                updated(newValue)
                updatedText = newValue
            }
        }
    }
    fileprivate(set) var currentText: NSAttributedString {
        set {
            let copy = newValue.mutableCopy() as! NSMutableAttributedString
            if let defaultText = self.defaultText {
                copy.replaceCharacters(in: NSMakeRange(0, min(defaultText.length, copy.length)), with: "")
            }
             _currentText = copy
            
            if copy != newValue {
                self.redraw()
            }
        }
        get {
            return _currentText
        }
    }
    

    
    var currentAttributed: NSAttributedString {
        let attr = NSMutableAttributedString()
        
        if let defaultText = self.defaultText {
            attr.append(.initialize(string: defaultText, color: theme.colors.text, font: .normal(.text)))
        }
        attr.append(currentText)
        return attr
    }
    
    var value: InputDataValue {
        if canMakeTransformations {
            return .attributedString(currentText)
        } else {
            return .string(currentText.string)
        }
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
    fileprivate let canMakeTransformations: Bool
    fileprivate let pasteFilter:((String)->(Bool, String))?
    private let maxBlockWidth: CGFloat?
    init(_ initialSize: NSSize, stableId: AnyHashable, mode: InputDataInputMode, error: InputDataValueError?, viewType: GeneralViewType = .legacy, currentText: String, currentAttributedText: NSAttributedString? = nil, placeholder: InputDataInputPlaceholder?, inputPlaceholder: String, defaultText: String? = nil, rightItem: InputDataRightItem? = nil, canMakeTransformations: Bool = false, insets: NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), maxBlockWidth: CGFloat? = nil, filter:@escaping(String)->String, updated:@escaping(String)->Void, pasteFilter:((String)->(Bool, String))? = nil, limit: Int32, customTheme: GeneralRowItem.Theme? = nil) {
        self.filter = filter
        self.limit = limit
        self.updated = updated
        self.placeholder = placeholder
        self.pasteFilter = pasteFilter
        self.defaultText = defaultText
        self.maxBlockWidth = maxBlockWidth
        self.canMakeTransformations = canMakeTransformations
        self.rightItem = rightItem
        let holder = NSMutableAttributedString()
        switch mode {
        case .secure:
            holder.append(.initialize(string: inputPlaceholder, color: customTheme?.grayTextColor ?? theme.colors.grayText, font: .light(.text)))
        case .plain:
            holder.append(.initialize(string: inputPlaceholder, color: customTheme?.grayTextColor ?? theme.colors.grayText, font: .normal(.text)))
        }
        self.inputPlaceholder = holder
        placeholderLayout = placeholder?.placeholder != nil ? TextViewLayout(.initialize(string: placeholder!.placeholder!, color: customTheme?.grayTextColor ?? theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1) : nil
    
        _currentText = currentAttributedText ?? NSAttributedString.initialize(string: currentText, color: theme.colors.text, font: .normal(.text), coreText: false)
        self.mode = mode
    
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: insets, error: error, customTheme: customTheme)
        
       
        _ = makeSize(initialSize.width, oldWidth: oldWidth)
    }
    
    override var blockWidth: CGFloat {
        if let maxBlockWidth = maxBlockWidth {
            return min(maxBlockWidth, super.blockWidth)
        } else {
            return super.blockWidth
        }
    }
    
    var textFieldLeftInset: CGFloat {
        if let placeholder = placeholder {
            if let _ = placeholder.placeholder {
                return 102
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
    
    override var instantlyResize: Bool {
        return true
    }
    
    func calculateHeight() {
        _ = self.makeSize(self.width, oldWidth: self.width)
    }
    
    var hasTextLimitation: Bool {
        if let placeholder = placeholder {
            return placeholder.hasLimitationText
        } else {
            return limit > 30 && defaultText == nil
        }
    }
    
    private(set) fileprivate var additionRightInset: CGFloat = 0
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let currentAttributed: NSMutableAttributedString = NSMutableAttributedString()
        _ = currentAttributed.append(string: (defaultText ?? ""), font: .normal(.text), coreText: false)
        currentAttributed.append(currentText)
                
        if mode == .secure {
            currentAttributed.setAttributedString(.init(string: String(currentText.string.map { _ in return "•" })))
            currentAttributed.addAttribute(.font, value: NSFont.normal(15.0 + 3.22), range: currentAttributed.range)
        }
                
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
        
        if hasTextLimitation {
            self.additionRightInset += 20
        }
        
        switch viewType {
        case .legacy:
            let height = currentAttributed.sizeFittingWidth(initialSize.width - inset.left - inset.right - textFieldLeftInset - additionRightInset).height
            self.realInputHeight = max(34, height + 6)
            inputHeight = max(34, height + 6)
        case let .modern(_, insets):
            let height = currentAttributed.sizeFittingWidth(self.blockWidth - insets.left - insets.right - textFieldLeftInset - additionRightInset).height
            
            switch self.mode {
            case .plain:
                self.realInputHeight = max(16, height)
            case .secure:
                self.realInputHeight = max(22, height)
            }
            inputHeight = max(34, height + 1)
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
    private var placeholderAction: ImageButton?
    internal let textView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect, unscrollable: true)
    private let secureField: InputDataSecureField = InputDataSecureField(frame: NSMakeRect(0, 0, 100, 16))
    private let textLimitation: TextViewLabel = TextViewLabel(frame: NSMakeRect(0, 0, 16, 14))
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(placeholderTextView)
        containerView.addSubview(textView)
        containerView.addSubview(secureField)
        containerView.addSubview(separator)
        containerView.addSubview(textLimitation)
        containerView.addSubview(rightActionView)
        addSubview(containerView)
        rightActionView.autohighlight = false
        
        containerView.userInteractionEnabled = false
        
        textLimitation.alignment = .right
        
        
        
    //    textView.max_height = 34
      // .isSingleLine = true
        placeholderTextView.userInteractionEnabled = false
        placeholderTextView.isSelectable = false
        
        secureField.isBordered = false
        secureField.isBezeled = false
        secureField.focusRingType = .none
        secureField.drawsBackground = true
        secureField.isEditable = true
        secureField.isSelectable = true
        
        textView.max_height = 10000
        
        secureField.font = .normal(.text)
        secureField.textView?.insertionPointColor = theme.colors.text
        secureField.sizeToFit()
                
    }
    
    deinit {
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
        self.separator.shake()
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
        guard let item = item as? InputDataRowItem else { return false }
        return item.canMakeTransformations
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

    func makeUrl(of range: NSRange) {
        guard range.min != range.max, let window = window as? Window else {
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
    
    
    private var separatorFrame: NSRect {
        
        guard let item = item as? InputDataRowItem else { return NSZeroRect }
        
        switch item.viewType {
        case .legacy:
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    return NSMakeRect(item.inset.left + item.textFieldLeftInset + 4, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - 4, .borderSize)
                } else {
                    return NSMakeRect(item.inset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right, .borderSize)
                }
            } else {
                return NSMakeRect(item.inset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.inset.left - item.inset.right, .borderSize)
            }
        case let .modern(_, innerInsets):
            if let placeholder = item.placeholder {
                if placeholder.drawBorderAfterPlaceholder {
                    return NSMakeRect(innerInsets.left + item.textFieldLeftInset + 4, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInsets.left - innerInsets.right - item.textFieldLeftInset - 4, .borderSize)
                } else {
                    return NSMakeRect(innerInsets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInsets.left - innerInsets.right, .borderSize)
                }
            } else {
                return NSMakeRect(innerInsets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInsets.left - innerInsets.right, .borderSize)
            }
        }
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataRowItem else {return}
        
        switch item.viewType {
        case .legacy:
            self.containerView.frame = bounds
            placeholderTextView.setFrameOrigin(item.inset.left, 14)
            placeholderAction?.setFrameOrigin(item.inset.left, 12)
            
            separator.frame = separatorFrame

            if let rightItem = item.rightItem {
                switch rightItem {
                case .action:
                    rightActionView.setFrameOrigin(NSMakePoint(self.containerView.frame.width - rightActionView.frame.width - item.inset.right + 4, 14))
                default:
                    break
                }
            }
            
            secureField.setFrameSize(NSMakeSize(self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - item.additionRightInset, item.inputHeight))
            secureField.setFrameOrigin(item.inset.left + item.textFieldLeftInset, 14)
            
            textView.setFrameSize(NSMakeSize(self.containerView.frame.width - item.inset.left - item.inset.right - item.textFieldLeftInset - item.additionRightInset, item.inputHeight))
            textView.setFrameOrigin(item.inset.left + item.textFieldLeftInset - 3, 6)
            
            textLimitation.setFrameOrigin(NSMakePoint(self.containerView.frame.width - item.inset.right - textLimitation.frame.width + 4, self.containerView.frame.height - textLimitation.frame.height - 4))
        case let .modern(position, innerInsets):
            self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
         
            self.separator.isHidden = !position.border
            
            let textX = innerInsets.left + item.textFieldLeftInset - 3
            
            placeholderTextView.setFrameOrigin(NSMakePoint(innerInsets.left, innerInsets.top))
            placeholderAction?.setFrameOrigin(NSMakePoint(innerInsets.left, innerInsets.top - 1))
            
            separator.frame = separatorFrame
        
            
            if let rightItem = item.rightItem {
                switch rightItem {
                case .action:
                    if item.realInputHeight <= 22 {
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
            secureField.setFrameOrigin(innerInsets.left + item.textFieldLeftInset + 1, innerInsets.top)
            
            textView.setFrameSize(NSMakeSize(item.blockWidth - innerInsets.left - innerInsets.right - item.textFieldLeftInset - item.additionRightInset, item.inputHeight))
            
            if item.realInputHeight <= 16 {
                textView.setFrameOrigin(textX, innerInsets.top - 8)
            } else {
                textView.setFrameOrigin(textX, innerInsets.top )
            }
            
            textLimitation.setFrameOrigin(NSMakePoint(item.blockWidth - innerInsets.right - textLimitation.frame.width, self.containerView.frame.height - innerInsets.bottom - textLimitation.frame.height))

            
        }
    }
    
    public func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        if let item = item as? InputDataRowItem {
            if item.hasTextLimitation {
                return 10000
            } else {
                return item.limit
            }
        }
        return 100000
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        if let item = item as? InputDataRowItem {
            switch item.mode {
            case .plain:
                if self.textView.selectedRange().max == self.textView.string().length {
                    self.textView.shake()
                }
            case .secure:
                self.secureField.shake()
            }
        }
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        if let item = item as? InputDataRowItem, let pasteFilter = item.pasteFilter {
            if let string = pasteboard.string(forType: .string)?.trimmed {
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
            
            
            item.calculateHeight()
            
            table.reloadData(row: item.index, animated: animated)
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
            } else {
                item.currentText = textView.attributedString()
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
                item.currentText = .initialize(string: updated, color: theme.colors.text, font: .normal(.text))
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
        if let item = item as? InputDataRowItem {
            if item.currentText != textView.attributedString(), !textView.inputView.hasMarkedText() {
                item.currentText = textView.attributedString()
            }
        }
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
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.backgroundColor
        }
        return theme.colors.background
    }
    
    var textColor: NSColor {
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.textColor
        }
        return theme.colors.text
    }
    var linkColor: NSColor {
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.accentColor
        }
        return theme.colors.accent
    }
    var grayText: NSColor {
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.grayTextColor
        }
        return theme.colors.grayText
    }
    var redColor: NSColor {
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.redColor
        }
        return theme.colors.redUI
    }
    var borderColor: NSColor {
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.borderColor
        }
        return theme.colors.border
    }
    
    var indicatorColor: NSColor {
        if let item = item as? GeneralRowItem, let customTheme = item.customTheme {
            return customTheme.indicatorColor
        }
        return theme.colors.indicatorColor
    }
    
    override func updateColors() {
        placeholderTextView.backgroundColor = backdorColor
        textView.cursorColor = theme.colors.indicatorColor
        textView.textFont = .normal(.text)
        textView.textColor = textColor
        textView.linkColor = linkColor

        textView.setBackgroundColor(backdorColor)
        secureField.font = .normal(13)
        secureField.backgroundColor = backdorColor
        secureField.textColor = textColor
        separator.backgroundColor = borderColor
        containerView.backgroundColor = backdorColor
        loadingView?.progressColor = grayText
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
    
    func showPlaceholderActionTooltip(_ text: String) -> Void {
        if let placeholderAction = placeholderAction {
            tooltip(for: placeholderAction, text: text)
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.secureField.delegate = self
        self.textView.delegate = self
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? InputDataRowItem else {return}
        
        self.textView.animates = false
        super.set(item: item, animated: animated)
        self.textView.animates = true

        
        placeholderTextView.isHidden = item.placeholderLayout == nil
        placeholderTextView.update(item.placeholderLayout)
        
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
                    loadingView?.progressColor = self.grayText
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
                        separator.change(size: separatorFrame.size, animated: animated)
                        separator.change(pos: separatorFrame.origin, animated: animated)
                    }
                    
                    switch item.viewType {
                    case .legacy:
                        textView._change(pos: NSMakePoint(item.inset.left + item.textFieldLeftInset - 3, 6), animated: animated)
                    case let .modern(_, innerInsets):
                        let textX = innerInsets.left + item.textFieldLeftInset - 3
                        if item.realInputHeight <= 16 {
                            textView._change(pos: NSMakePoint(textX, textView.frame.minY), animated: animated)
                        } else {
                            textView._change(pos: NSMakePoint(textX, textView.frame.minY), animated: animated)
                        }
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
                if animated {
                    if let placeholderAction = placeholderAction {
                        self.placeholderAction = nil
                        placeholderAction.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak placeholderAction] _ in
                            placeholderAction?.removeFromSuperview()
                        })
                        separator.change(size: separatorFrame.size, animated: animated)
                        separator.change(pos: separatorFrame.origin, animated: animated)
                    }
                } else {
                    placeholderAction?.removeFromSuperview()
                    placeholderAction = nil
                }
                
                switch item.viewType {
                case .legacy:
                    textView._change(pos: NSMakePoint(item.inset.left + item.textFieldLeftInset - 3, 6), animated: animated)
                case let .modern(_, innerInsets):
                    let textX = innerInsets.left + item.textFieldLeftInset - 3
                    if item.realInputHeight <= 16 {
                        textView._change(pos: NSMakePoint(textX, textView.frame.minY), animated: animated)
                    } else {
                        textView._change(pos: NSMakePoint(textX, textView.frame.minY), animated: animated)
                    }
                }
            }
            
            
        } else {
            if animated {
                if let placeholderAction = placeholderAction {
                    self.placeholderAction = nil
                    placeholderAction.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak placeholderAction] _ in
                        placeholderAction?.removeFromSuperview()
                    })
                    separator.change(size: separatorFrame.size, animated: animated)
                    separator.change(pos: separatorFrame.origin, animated: animated)
                }
            } else {
                placeholderAction?.removeFromSuperview()
                placeholderAction = nil
            }
            
           
            
            switch item.viewType {
            case .legacy:
                textView._change(pos: NSMakePoint(item.inset.left + item.textFieldLeftInset - 3, 6), animated: animated)
            case let .modern(_, innerInsets):
                let textX = innerInsets.left + item.textFieldLeftInset - 3
                if item.realInputHeight <= 16 {
                    textView._change(pos: NSMakePoint(textX, textView.frame.minY), animated: animated)
                } else {
                    textView._change(pos: NSMakePoint(textX, textView.frame.minY), animated: animated)
                }
            }
        }
        
        if item.hasTextLimitation {
            textLimitation.isHidden = item.currentText.length < item.limit / 3 * 2 || item.currentText.length == item.limit
            let color: NSColor = item.currentText.length > item.limit ? self.redColor : self.grayText
            textLimitation.attributedString = .initialize(string: "\(item.limit - Int32(item.currentText.length))", color: color, font: .normal(.small))
            textLimitation.sizeToFit()
        } else {
            textLimitation.isHidden = true
        }
        
        switch item.mode {
        case .plain:
            secureField.isHidden = true
            textView.isHidden = false
            textView.animates = false
            textView.setPlaceholderAttributedString(item.inputPlaceholder, update: false)
            if item.currentAttributed != textView.attributedString() {
                textView.setAttributedString(item.currentAttributed, animated: false)
            }
            textView.update(false)
            textView.needsDisplay = true
            textView.animates = true
        case .secure:
            secureField.placeholderAttributedString = item.inputPlaceholder
            secureField.isHidden = false
            
            textView.isHidden = true
            if item.currentText.string != secureField.stringValue {
                secureField.stringValue = item.currentText.string
            }
        }
        
        containerView.needsDisplay = true
        self.needsLayout = true

    }
}
