//
//  DatePicker.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 07/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

public final class DatePickerOption<T> : Equatable where T: Equatable {
    let name: String
    let value:T
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
        self.updateLocalizationAndTheme()
    }
    
    public override func layout() {
        super.layout()
        self.updateSelected(animated: false)
        self.borderView.frame = NSMakeRect(1, 1, bounds.width - 2, bounds.height - 2)
        self.activeBorderView.frame = bounds
        self.selectedText.center()
    }
    
    public override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.borderView.layer?.borderWidth = .borderSize
        self.borderView.layer?.borderColor = presentation.colors.border.cgColor
        self.borderView.layer?.cornerRadius = .cornerRadius
        
        self.activeBorderView.layer?.borderWidth = .borderSize
        self.activeBorderView.layer?.borderColor = presentation.colors.blueIcon.cgColor
        self.activeBorderView.layer?.cornerRadius = .cornerRadius
        self.updateSelected(animated: false)
    }
    
    
    public override func updateState() {
        super.updateState()
        self.updateSelected(animated: true)
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
        needsLayout = true
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
