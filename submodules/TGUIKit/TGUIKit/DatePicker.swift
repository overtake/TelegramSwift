//
//  DatePicker.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 07/08/2019.
//  Copyminutes © 2019 Telegram. All minutess reserved.
//

import Cocoa

public final class DatePickerOption<T> : Equatable where T: Equatable {
    public let name: String
    public let value:T
    public init(name: String, value: T) {
        self.name = name
        self.value = value
    }
    
    public static func ==(lhs: DatePickerOption<T>, rhs: DatePickerOption<T>) -> Bool {
        return lhs.name == rhs.name && rhs.value == rhs.value
    }
    
}

public final class DatePickerData {
    
}



public class DatePicker<T>: Control where T: Equatable {
    
    private let selectedText = TextView()
    private let borderView = View()
    private let activeBorderView = View()
    
    public var selected: DatePickerOption<T> {
        didSet {
            if oldValue != selected {
                self.updateSelected(animated: true)
            }
        }
    }
    
    public var font: NSFont = .normal(.text)
    
    public init(selected: DatePickerOption<T>) {
        self.selected = selected
        super.init(frame: NSZeroRect)
        self.selectedText.userInteractionEnabled = false
        self.selectedText.isEventLess = true
        self.selectedText.isSelectable = false
        
        self.addSubview(self.selectedText)
        self.addSubview(self.borderView)
        self.addSubview(self.activeBorderView)
        self.updateLocalizationAndTheme(theme: presentation)
    }
    
    public override func layout() {
        super.layout()
        self.updateSelected(animated: false)
        self.borderView.frame = bounds
        self.activeBorderView.frame = bounds
        self.selectedText.center()
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = presentation.colors.grayBackground
        self.layer?.cornerRadius = .cornerRadius
        
        self.borderView.layer?.borderWidth = .borderSize
        self.borderView.layer?.borderColor = presentation.colors.border.cgColor
        self.borderView.layer?.cornerRadius = .cornerRadius
        
        self.activeBorderView.layer?.borderWidth = .borderSize
        self.activeBorderView.layer?.borderColor = presentation.colors.accentIcon.cgColor
        self.activeBorderView.layer?.cornerRadius = .cornerRadius
        self.updateSelected(animated: false)
        needsLayout = true
    }
    
    
    public override func updateState() {
        super.updateState()
        self.updateSelected(animated: true)
        needsLayout = true
    }
    
    private func updateSelected(animated: Bool) {
        let layout = TextViewLayout(.initialize(string: self.selected.name, color: presentation.colors.text, font: self.font), maximumNumberOfLines: 1, alwaysStaticItems: true)
        layout.measure(width: frame.width - 8)
        self.selectedText.update(layout)
        if controlState == .Highlight || isSelected {
            self.borderView.change(opacity: 0, animated: animated)
            self.activeBorderView.change(opacity: 1, animated: animated)
        } else {
            self.borderView.change(opacity: 1, animated: animated)
            self.activeBorderView.change(opacity: 0, animated: animated)
        }
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}




public struct TimePickerOption : Equatable {
    public let hours: Int32
    public let minutes: Int32
    public let seconds: Int32
    public init(hours: Int32, minutes: Int32, seconds: Int32) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
}

private final class TimeOptionView: View {
    
    private var textNode:(TextNodeLayout, TextNode)?
    private var textNodeSelected:(TextNodeLayout, TextNode)?

    private var isFirst: Bool = false
    
    var keyDown:((Int32, Bool)->Void)? = nil
    var next:((Bool)->Void)? = nil
    
    private func updateLayout() {
        
        let value: String = self.value < 10 ? "0\(self.value)" : "\(self.value)"
        
        textNode = TextNode.layoutText(.initialize(string: value, color: presentation.colors.text, font: .normal(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
        textNodeSelected = TextNode.layoutText(.initialize(string: value, color: presentation.colors.underSelectedColor, font: .normal(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
        
        setFrameSize(NSMakeSize(textNode!.0.size.width + 6,  textNode!.0.size.height + 4))

        needsDisplay = true
    }
    
    var value: Int32 = 0 {
        didSet {
            updateLayout()
        }
    }
    init(value: Int32) {
        self.value = value
        super.init(frame: NSZeroRect)
        updateLayout()
    }
    
    override func keyDown(with event: NSEvent) {
        guard let keyCode = KeyboardKey(rawValue: event.keyCode) else {
            return
        }
        switch keyCode {
        case .Zero, .Keypad0:
            self.keyDown?(0, isFirst)
        case .One, .Keypad1:
            self.keyDown?(1, isFirst)
        case .Two, .Keypad2:
            self.keyDown?(2, isFirst)
        case .Three, .Keypad3:
            self.keyDown?(3, isFirst)
        case .Four, .Keypad4:
            self.keyDown?(4, isFirst)
        case .Five, .Keypad5:
            self.keyDown?(5, isFirst)
        case .Six, .Keypad6:
            self.keyDown?(6, isFirst)
        case .Seven, .Keypad7:
            self.keyDown?(7, isFirst)
        case .Eight, .Keypad8:
            self.keyDown?(8, isFirst)
        case .Nine, .Keypad9:
            self.keyDown?(9, isFirst)
        case .Tab, .RightArrow:
            self.next?(true)
        case .LeftArrow:
            self.next?(false)
        case .Escape:
            self.window?.makeFirstResponder(nil)
        default:
            break
        }
        isFirst = false
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.round(frame.size, 4)
        
        if window?.firstResponder == self {
            ctx.setFillColor(presentation.colors.accentSelect.cgColor)
            ctx.fill(bounds)
            if let textNode = textNodeSelected {
                textNode.1.draw(focus(textNode.0.size), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
            }
        } else {
            ctx.setFillColor(presentation.colors.grayBackground.cgColor)
            ctx.fill(bounds)
            if let textNode = textNodeSelected {
                textNode.1.draw(focus(textNode.0.size), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
            }
        }
        
    }
    
    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        isFirst = true
        return super.becomeFirstResponder()
    }
    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        isFirst = false
        return super.resignFirstResponder()
    }
}

public class TimePicker: Control {
    
    public var update:((TimePickerOption)->Bool)?
    
    private let hoursView:TimeOptionView
    private let minutesView:TimeOptionView
    private let secondsView:TimeOptionView
    private let separatorView1: TextView = TextView()
    private let separatorView2: TextView = TextView()
    private let borderView = View()
    
    public var selected: TimePickerOption {
        didSet {
            if oldValue != selected {
                self.hoursView.value = selected.hours
                self.minutesView.value = selected.minutes
                self.secondsView.value = selected.seconds
                needsLayout = true
                self.updateSelected(animated: true)
            }
        }
    }
    
    public var font: NSFont = .normal(.text)
    
    public init(selected: TimePickerOption) {
        self.selected = selected
        self.hoursView = TimeOptionView(value: selected.hours)
        self.minutesView = TimeOptionView(value: selected.minutes)
        self.secondsView = TimeOptionView(value: selected.seconds)
        super.init(frame: NSZeroRect)
        
        
        separatorView1.userInteractionEnabled = false
        separatorView1.isSelectable = false
        separatorView1.isEventLess = true
        
        separatorView2.userInteractionEnabled = false
        separatorView2.isSelectable = false
        separatorView2.isEventLess = true
        
        self.addSubview(self.separatorView1)
        self.addSubview(self.separatorView2)
        self.addSubview(self.borderView)
        self.addSubview(self.hoursView)
        self.addSubview(self.minutesView)
        self.addSubview(self.secondsView)
        self.updateLocalizationAndTheme(theme: presentation)
        
        hoursView.keyDown = { [weak self] value, isFirst in
            guard let selected = self?.selected else {
                return
            }
            var updatedValue = value
            if isFirst {
                updatedValue = value
            } else {
                if selected.hours > 0, selected.hours < 10 {
                    updatedValue = min(Int32("\(selected.hours)\(updatedValue)")!, 23)
                    self?.switchToRight()
                }
            }
            
            let new = TimePickerOption(hours: updatedValue, minutes: selected.minutes, seconds: selected.seconds)
            if let result = self?.update?(new), result {
                self?.selected = new
            } else {
                self?.shake()
            }
        }
        minutesView.keyDown = { [weak self] value, isFirst in
            guard let selected = self?.selected else {
                return
            }
            var updatedValue = value
            if isFirst {
                updatedValue = value
            } else {
                if selected.minutes > 0, selected.minutes < 10 {
                    updatedValue = min(Int32("\(selected.minutes)\(updatedValue)")!, 59)
                    self?.switchToRight()
                }
            }
            let new = TimePickerOption(hours: selected.hours, minutes: updatedValue, seconds: selected.seconds)
            self?.selected = new
            if let result = self?.update?(new), result {
                self?.selected = new
            } else {
                self?.shake()
            }
        }
        secondsView.keyDown = { [weak self] value, isFirst in
            guard let selected = self?.selected else {
                return
            }
            var updatedValue = value
            if isFirst {
                updatedValue = value
            } else {
                if selected.seconds > 0, selected.seconds < 10 {
                    updatedValue = min(Int32("\(selected.seconds)\(updatedValue)")!, 59)
                    self?.switchToRight()
                }
            }
            let new = TimePickerOption(hours: selected.hours, minutes: selected.minutes, seconds: updatedValue)
            self?.selected = new
            if let result = self?.update?(new), result {
                self?.selected = new
            } else {
                self?.shake()
            }
        }
        minutesView.next = { [weak self] toRight in
            if !toRight {
                self?.switchToLeft()
            } else {
                self?.switchToRight()
            }
        }
        hoursView.next = { [weak self] toRight in
            if !toRight {
                self?.switchToLeft()
            } else {
                self?.switchToRight()
            }
        }
        secondsView.next = { [weak self] toRight in
            if !toRight {
                self?.switchToLeft()
            } else {
                self?.switchToRight()
            }
        }
    }
    
    func switchToRight() {
        if self.window?.firstResponder == self.hoursView {
            self.window?.makeFirstResponder(self.minutesView)
        } else if self.window?.firstResponder == self.minutesView {
            self.window?.makeFirstResponder(self.secondsView)
        } else {
            self.window?.makeFirstResponder(self.hoursView)
        }
    }
    func switchToLeft() {
        if self.window?.firstResponder == self.secondsView {
            self.window?.makeFirstResponder(self.minutesView)
        } else if self.window?.firstResponder == self.minutesView {
            self.window?.makeFirstResponder(self.hoursView)
        } else {
            self.window?.makeFirstResponder(self.secondsView)
        }
    }
    
    public var firstResponder: NSResponder? {
        if self.window?.firstResponder == self.secondsView {
            return self.secondsView
        } else if self.window?.firstResponder == self.minutesView {
            return self.minutesView
        } else {
            return self.hoursView
        }
    }
    
    public override func layout() {
        super.layout()
        
        minutesView.center()
        separatorView1.centerY(x: minutesView.frame.minX - separatorView1.frame.width - 2)
        hoursView.centerY(x: minutesView.frame.minX - hoursView.frame.width - separatorView1.frame.width - 5)
        separatorView2.centerY(x: minutesView.frame.maxX + 3)
        secondsView.centerY(x: minutesView.frame.maxX + separatorView1.frame.width + 5)
        self.borderView.frame = bounds
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = presentation.colors.grayBackground
        self.layer?.cornerRadius = .cornerRadius
        
        self.borderView.layer?.borderWidth = .borderSize
        self.borderView.layer?.borderColor = presentation.colors.border.cgColor
        self.borderView.layer?.cornerRadius = .cornerRadius
        
        let layout = TextViewLayout(.initialize(string: ":", color: presentation.colors.grayText, font: .normal(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        separatorView1.update(layout)
        
        separatorView2.update(layout)
        
        needsLayout = true
    }
    
    
    public override func updateState() {
        super.updateState()
        self.updateSelected(animated: true)
        needsLayout = true
    }
    
    private func updateSelected(animated: Bool) {
       
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}
