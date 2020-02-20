//
//  DatePicker.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 07/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
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




public final class TimePickerOption : Equatable {
    public let left: Int32
    public let right: Int32
    public init(left: Int32, right: Int32) {
        self.left = left
        self.right = right
    }
    
    public static func ==(lhs: TimePickerOption, rhs: TimePickerOption) -> Bool {
        return lhs.left == rhs.left && lhs.right == rhs.right
    }
    
}

private final class TimeOptionView: View {
    
    private var textNode:(TextNodeLayout, TextNode)?
    private var textNodeSelected:(TextNodeLayout, TextNode)?

    private var isFirst: Bool = false
    
    var keyDown:((Int32, Bool)->Void)? = nil
    var next:(()->Void)? = nil
    
    private func updateLayout() {
        
        let value: String = self.value < 10 ? "0\(self.value)" : "\(self.value)"
        
        textNode = TextNode.layoutText(.initialize(string: value, color: presentation.colors.grayText, font: .normal(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
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
        case KeyboardKey.Zero, KeyboardKey.Keypad0:
            self.keyDown?(0, isFirst)
        case KeyboardKey.One, KeyboardKey.Keypad1:
            self.keyDown?(1, isFirst)
        case KeyboardKey.Two, KeyboardKey.Keypad2:
            self.keyDown?(2, isFirst)
        case KeyboardKey.Three, KeyboardKey.Keypad3:
            self.keyDown?(3, isFirst)
        case KeyboardKey.Four, KeyboardKey.Keypad4:
            self.keyDown?(4, isFirst)
        case KeyboardKey.Five, KeyboardKey.Keypad5:
            self.keyDown?(5, isFirst)
        case KeyboardKey.Six, KeyboardKey.Keypad6:
            self.keyDown?(6, isFirst)
        case KeyboardKey.Seven, KeyboardKey.Keypad7:
            self.keyDown?(7, isFirst)
        case KeyboardKey.Eight, KeyboardKey.Keypad8:
            self.keyDown?(8, isFirst)
        case KeyboardKey.Nine, KeyboardKey.Keypad9:
            self.keyDown?(9, isFirst)
        case KeyboardKey.Tab, .RightArrow, .LeftArrow:
            self.next?()
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
    
    private let leftView:TimeOptionView
    private let rightView:TimeOptionView
    private let separatorView: TextView = TextView()
    private let borderView = View()
    
    public var selected: TimePickerOption {
        didSet {
            if oldValue != selected {
                self.leftView.value = selected.left
                self.rightView.value = selected.right
                needsLayout = true
                self.updateSelected(animated: true)
            }
        }
    }
    
    public var font: NSFont = .normal(.text)
    
    public init(selected: TimePickerOption) {
        self.selected = selected
        self.leftView = TimeOptionView(value: selected.left)
        self.rightView = TimeOptionView(value: selected.right)
        super.init(frame: NSZeroRect)
        
        
        separatorView.userInteractionEnabled = false
        separatorView.isSelectable = false
        separatorView.isEventLess = true
        
        self.addSubview(self.separatorView)
        self.addSubview(self.borderView)
        self.addSubview(self.leftView)
        self.addSubview(self.rightView)
        self.updateLocalizationAndTheme(theme: presentation)
        
        leftView.keyDown = { [weak self] value, isFirst in
            guard let selected = self?.selected else {
                return
            }
            var updatedValue = value
            if isFirst {
                updatedValue = value
            } else {
                if selected.left > 0, selected.left < 10 {
                    updatedValue = min(Int32("\(selected.left)\(updatedValue)")!, 23)
                    self?.switchToRight()
                }
            }
            
            let new = TimePickerOption(left: updatedValue, right: selected.right)
            if let result = self?.update?(new), result {
                self?.selected = new
            } else {
                self?.shake()
            }
        }
        rightView.keyDown = { [weak self] value, isFirst in
            guard let selected = self?.selected else {
                return
            }
            var updatedValue = value
            if isFirst {
                updatedValue = value
            } else {
                if selected.right > 0, selected.right < 10 {
                    updatedValue = min(Int32("\(selected.right)\(updatedValue)")!, 59)
                    self?.switchToLeft()
                }
            }
            let new = TimePickerOption(left: selected.left, right: updatedValue)
            self?.selected = new
            if let result = self?.update?(new), result {
                self?.selected = new
            } else {
                self?.shake()
            }
        }
        rightView.next = { [weak self] in
            if self?.firstResponder == self?.rightView {
                self?.switchToLeft()
            } else {
                self?.switchToRight()
            }
        }
        leftView.next = { [weak self] in
            if self?.firstResponder == self?.rightView {
                self?.switchToLeft()
            } else {
                self?.switchToRight()
            }
        }
    }
    
    func switchToRight() {
        self.window?.makeFirstResponder(self.rightView)
    }
    func switchToLeft() {
        self.window?.makeFirstResponder(self.leftView)
    }
    
    public var firstResponder: NSResponder? {
        return self.rightView == self.window?.firstResponder ? self.rightView : self.leftView
    }
    
    public override func layout() {
        super.layout()
        
        leftView.centerY(x: bounds.midX - leftView.frame.width - 2)
        rightView.centerY(x: bounds.midX + 3)
        separatorView.center()
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
        separatorView.update(layout)
        
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
