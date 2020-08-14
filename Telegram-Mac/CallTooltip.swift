//
//  CallTooltip.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
imp

private enum CallTooltipType : Int32 {
    case cameraOff
    case microOff
    case batteryLow
    
    var icon: CGImage {
        switch self {
        case .cameraOff:
            return theme.icons.call_tooltip_camera_off
        case .microOff:
            return theme.icons.call_tooltip_micro_off
        case .batteryLow:
            return theme.icons.call_tooltip_battery_low
        }
    }
    func text(_ title: String) -> String {
        switch self {
        case .cameraOff:
            return L10n.callToastCameraOff(title)
        case .microOff:
            return L10n.callToastMicroOff(title)
        case .batteryLow:
            return L10n.callToastLowBattery(title)
        }
    }
}


private final class CallTooltipView : Control {
    private let textView: TextView = TextView()
    private let icon: ImageView = ImageView()
    
    fileprivate var type: CallTooltipType? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(icon)
        
        textView.disableBackgroundDrawing = true
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        backgroundColor = NSColor.grayText.withAlphaComponent(0.7)
        
    }
    
    func update(type: CallTooltipType, icon: CGImage, text: String, maxWidth: CGFloat) {
        
        self.type = type
        
        self.icon.image = icon
        self.icon.sizeToFit()
        
        let attr: NSAttributedString = .initialize(string: text, color: .white, font: .medium(.title))
        
        let layout = TextViewLayout(attr, maximumNumberOfLines: 1)
        layout.measure(width: maxWidth - 30 - icon.backingSize.width)
        textView.update(layout)
        
        setFrameSize(NSMakeSize(30 + self.icon.frame.width + self.textView.frame.width, 26))
        layer?.cornerRadius = frame.height / 2
        
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        icon.centerY(x: 10)
        textView.centerY(x: icon.frame.maxX + 10)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

