//
//  InputDataDateRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import CalendarUtils
import TGModernGrowingTextView
import KeyboardKey

class InputDataDateRowItem: GeneralRowItem, InputDataRowDataValue {
    fileprivate let placeholderLayout: TextViewLayout
    fileprivate let dayHolderLayout: TextViewLayout
    fileprivate let monthHolderLayout: TextViewLayout
    fileprivate let yearHolderLayout: TextViewLayout

    private let updated:()->Void
    fileprivate var _value: InputDataValue {
        didSet {
            if _value != oldValue {
                updated()
            }
        }
    }
    
    var value: InputDataValue {
        return _value
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable, value: InputDataValue, error: InputDataValueError?, updated:@escaping()->Void, placeholder: String) {
        self._value = value
        self.updated = updated
        placeholderLayout = TextViewLayout(.initialize(string: placeholder, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        
        dayHolderLayout = TextViewLayout(.initialize(string: strings().inputDataDateDayPlaceholder1, color: theme.colors.text, font: .normal(.text)))
        monthHolderLayout = TextViewLayout(.initialize(string: strings().inputDataDateMonthPlaceholder1, color: theme.colors.text, font: .normal(.text)))
        yearHolderLayout = TextViewLayout(.initialize(string: strings().inputDataDateYearPlaceholder1, color: theme.colors.text, font: .normal(.text)))

        dayHolderLayout.measure(width: .greatestFiniteMagnitude)
        monthHolderLayout.measure(width: .greatestFiniteMagnitude)
        yearHolderLayout.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize, height: 44, stableId: stableId, error: error)
        _ = makeSize(initialSize.width, oldWidth: oldWidth)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        placeholderLayout.measure(width: 100)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return InputDataDateRowView.self
    }
    
}


final class InputDataDateRowView : GeneralRowView, TGModernGrowingDelegate {
    private let placeholderTextView = TextView()
    private let dayInput = TGModernGrowingTextView(frame: NSZeroRect)
    private let monthInput = TGModernGrowingTextView(frame: NSZeroRect)
    private let yearInput = TGModernGrowingTextView(frame: NSZeroRect)

    private let firstSeparator = TextViewLabel()
    private let secondSeparator = TextViewLabel()
    private var ignoreChanges: Bool = false
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(placeholderTextView)
        
        placeholderTextView.userInteractionEnabled = false
        placeholderTextView.isSelectable = false
        
        dayInput.delegate = self
        monthInput.delegate = self
        yearInput.delegate = self
        

        
        dayInput.textFont = .normal(.text)
        monthInput.textFont = .normal(.text)
        yearInput.textFont = .normal(.text)
        
        

        addSubview(dayInput)
        addSubview(monthInput)
        addSubview(yearInput)
        
        firstSeparator.autosize = true
        secondSeparator.autosize = true
        
        addSubview(firstSeparator)
        addSubview(secondSeparator)
        
    }
    
    public func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        switch true {
        case textView === dayInput:
            return 2
        case textView === monthInput:
            return 2
        case textView === yearInput:
            return 4
        default:
            return 0
        }
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        var bp:Int = 0
        bp += 1
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
        
        guard let item = item as? InputDataDateRowItem else {return}
        guard !ignoreChanges else {return}
        
        var day = String(dayInput.string().unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})
        var month = String(monthInput.string().unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})
        var year = String(yearInput.string().unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})
        
        var _month:String?
        var _year: String?
        var _day: String?
        if year.length == 4 {
            year = "\(Int(year)!)"
            _year = year
        }
        if month.length > 0 {
            let _m = min(Int(month)!, 12)
            if _m == 0 {
                month = "0"
            } else {
                month = "\(month.length == 2 && _m < 10 ? "0\(_m)" : "\(_m)")"
            }
            _month = month == "0" ? nil : month
        }
        
        if day.length > 0 {
           var _max:Int = 31
            if let year = _year, let month = _month {
                if let date = dateFormatter.date(from: "02.\(month).\(year)") {
                    _max = CalendarUtils.lastDay(ofTheMonth: date)
                }
            }
            let _d = min(Int(day)!, _max)
            if _d == 0 {
                day = "0"
            } else {
                day = "\(day.length == 2 && _d < 10 ? "0\(_d)" : "\(_d)")"
            }
            _day = day == "0" ? nil : day
        }
        
        item._value = .date(_day != nil ? Int32(_day!) : nil, _month != nil ? Int32(_month!) : nil, _year != nil ? Int32(_year!) : nil)
        
        dayInput.setString(day)
        monthInput.setString(month)
        yearInput.setString(year)
        
        if month.length == 2, month.prefix(1) == "0" {
            textViewDidReachedLimit(monthInput)
        }
        
        if day.length == 2, window?.firstResponder == dayInput.inputView {
            textViewDidReachedLimit(dayInput)
        }
        if month.length == 2, window?.firstResponder == monthInput.inputView {
            textViewDidReachedLimit(monthInput)
        }
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        if let responder = nextResponder() {
            window?.makeFirstResponder(responder)
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? InputDataDateRowItem else {return}
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
    }
    
    override var mouseInsideField: Bool {
        return yearInput._mouseInside() || dayInput._mouseInside() || monthInput._mouseInside()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        switch true {
        case NSPointInRect(point, yearInput.frame):
            return yearInput
        case NSPointInRect(point, dayInput.frame):
            return dayInput
        case NSPointInRect(point, monthInput.frame):
            return monthInput
        default:
            return super.hitTest(point)
        }
    }
    
    override func hasFirstResponder() -> Bool {
        return true
    }
    
    override var firstResponder: NSResponder? {
        let isKeyDown = NSApp.currentEvent?.type == NSEvent.EventType.keyDown && NSApp.currentEvent?.keyCode == KeyboardKey.Tab.rawValue
        switch true {
        case yearInput._mouseInside() && !isKeyDown:
            return yearInput.inputView
        case dayInput._mouseInside() && !isKeyDown:
            return dayInput.inputView
        case monthInput._mouseInside() && !isKeyDown:
            return monthInput.inputView
        default:
            switch true {
            case yearInput.inputView == window?.firstResponder:
                return yearInput.inputView
            case dayInput.inputView == window?.firstResponder:
                return dayInput.inputView
            case monthInput.inputView == window?.firstResponder:
                return monthInput.inputView
            default:
                return dayInput.inputView
            }
        }
    }
    
    override func nextResponder() -> NSResponder? {
        if window?.firstResponder == dayInput.inputView {
            return monthInput.inputView
        }
        if window?.firstResponder == monthInput.inputView {
            return yearInput.inputView
        }
        return nil
    }
    
    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataDateRowItem else {return}
        
        placeholderTextView.setFrameOrigin(item.inset.left, 14)
        
        let defaultLeftInset = item.inset.left + 100
        
        dayInput.setFrameOrigin(defaultLeftInset, 15)
        monthInput.setFrameOrigin(dayInput.frame.maxX + 8, 15)
        yearInput.setFrameOrigin(monthInput.frame.maxX + 8, 15)
        
        firstSeparator.setFrameOrigin(dayInput.frame.maxX - 7, 14)
        secondSeparator.setFrameOrigin(monthInput.frame.maxX - 7, 14)
        
        
//
//        dayPlaceholder.setFrameOrigin(defaultLeftInset, 14)
        
//
//        monthPlaceholder.setFrameOrigin(defaultLeftInset, dayPlaceholder.frame.maxY + 5)
//        monthSelector.setFrameOrigin(monthPlaceholder.frame.maxX + 3, monthPlaceholder.frame.minY - 3)
//
//        yearPlaceholder.setFrameOrigin(defaultLeftInset, monthPlaceholder.frame.maxY + 5)
//        yearSelector.setFrameOrigin(yearPlaceholder.frame.maxX + 3, yearPlaceholder.frame.minY - 3)
    }
    
    override func shakeView() {
        guard let item = item as? InputDataDateRowItem else {return}

        switch item.value {
        case let .date(day, month, year):
            if day == nil {
                dayInput.shake()
            }
            if month == nil {
                monthInput.shake()
            }
            if year == nil {
                yearInput.shake()
            }
            if year != nil && month != nil && day != nil {
                dayInput.shake()
                monthInput.shake()
                yearInput.shake()
            }
        default:
            break
        }
        
        
    }
    
    override func updateColors() {
        placeholderTextView.backgroundColor = theme.colors.background
        firstSeparator.backgroundColor = theme.colors.background
        secondSeparator.backgroundColor = theme.colors.background
        
        dayInput.textColor = theme.colors.text
        monthInput.textColor = theme.colors.text
        yearInput.textColor = theme.colors.text
        
        dayInput.setBackgroundColor(backdorColor)
        monthInput.setBackgroundColor(backdorColor)
        yearInput.setBackgroundColor(backdorColor)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        

        guard let item = item as? InputDataDateRowItem else {return}
        placeholderTextView.update(item.placeholderLayout)
        
        
        let dayLayout = TextViewLayout(.initialize(string: strings().inputDataDateDayPlaceholder1, color: theme.colors.grayText, font: .normal(.text)))
        dayLayout.measure(width: .greatestFiniteMagnitude)
        
        let monthLayout = TextViewLayout(.initialize(string: strings().inputDataDateMonthPlaceholder1, color: theme.colors.grayText, font: .normal(.text)))
        monthLayout.measure(width: .greatestFiniteMagnitude)
        
        let yearLayout = TextViewLayout(.initialize(string: strings().inputDataDateYearPlaceholder1, color: theme.colors.grayText, font: .normal(.text)))
        yearLayout.measure(width: .greatestFiniteMagnitude)
        

                
        dayInput.min_height = Int32(dayLayout.layoutSize.height)
        dayInput.max_height = Int32(dayLayout.layoutSize.height)
        dayInput.setFrameSize(NSMakeSize(dayLayout.layoutSize.width + 20, dayLayout.layoutSize.height))
        
        monthInput.min_height = Int32(monthLayout.layoutSize.height)
        monthInput.max_height = Int32(monthLayout.layoutSize.height)
        monthInput.setFrameSize(NSMakeSize(monthLayout.layoutSize.width + 20, monthLayout.layoutSize.height))

        yearInput.min_height = Int32(yearLayout.layoutSize.height)
        yearInput.max_height = Int32(yearLayout.layoutSize.height)
        yearInput.setFrameSize(NSMakeSize(yearLayout.layoutSize.width + 20, yearLayout.layoutSize.height))
        
        firstSeparator.attributedString = .initialize(string: "/", color: theme.colors.text, font: .medium(.text))
        secondSeparator.attributedString = .initialize(string: "/", color: theme.colors.text, font: .medium(.text))
        firstSeparator.sizeToFit()
        secondSeparator.sizeToFit()
        
        ignoreChanges = true
        
        switch item.value {
        case let .date(day, month, year):
            if let day = day {
                dayInput.setString("\( day < 10 && day > 0 ? "\(day)" : "\(day)")", animated: false)
            } else {
                dayInput.setString("", animated: false)
            }
            if let month = month {
                monthInput.setString("\( month < 10 && month > 0 ? "\(month)" : "\(month)")", animated: false)
            } else {
                monthInput.setString("", animated: false)
            }
            if let year = year {
                yearInput.setString("\(year)", animated: false)
            } else {
                yearInput.setString("", animated: false)
            }
        default:
            dayInput.setString("", animated: false)
            monthInput.setString("", animated: false)
            yearInput.setString("", animated: false)
        }
        ignoreChanges = false

        dayInput.placeholderAttributedString = dayLayout.attributedString
        monthInput.placeholderAttributedString = monthLayout.attributedString
        yearInput.placeholderAttributedString = yearLayout.attributedString
        

        super.set(item: item, animated: animated)

        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
