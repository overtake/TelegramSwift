//
//  PTTRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/12/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import DDHotKey
import TGUIKit


final class PTTRowItem : GeneralRowItem {
    fileprivate let settings: PTTSettings?
    fileprivate let update:(PTTSettings?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, settings: PTTSettings?, update:@escaping(PTTSettings?)->Void, viewType: GeneralViewType) {
        self.settings = settings
        self.update = update
        super.init(initialSize, height: 50, stableId: stableId, type: .none, viewType: viewType, inset: NSEdgeInsets(top: 3, left: 30, bottom: 3, right: 30), error: nil)
        if let settings = settings {
            DDHotKeyCenter.shared()?.register(DDHotKey(keyCode: settings.keyCode, modifierFlags: settings.modifierFlags, task: { event in
                if let event = event {
                    NSLog("\(event.type == .keyUp)")
                    NSLog("\(event.type == .keyDown)")
                } else {
                    NSLog("No Event")
                }
            }))
        }
                
    }
    
    override func viewClass() -> AnyClass {
        return PTTRowView.self
    }
}



private final class PTTRowView: GeneralContainableRowView {
        
    private enum PTTMode {
        case normal
        case editing
    }
    
    private let textView: TextView = TextView()
    private let button: Control = Control()
    
    private var mode: PTTMode = .normal
    
    private let shimmerView = View()
    
    private let shortcutView = TextView()
    private var eventGlobalMonitor: Any?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.subviews = [shimmerView, containerView]
        
        shimmerView.isEventLess = true
        
        shimmerView.layer?.cornerRadius = 10
        
        addSubview(button)
        button.addSubview(textView)
        addSubview(shortcutView)
        button.layer?.cornerRadius = 8
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 3
        shadow.shadowColor = NSColor.redUI.withAlphaComponent(1)
        shadow.shadowOffset = NSMakeSize(0, 0)
        shimmerView.shadow = shadow
        
        shimmerView.background = .random
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        button.set(handler: { [weak self] _ in
            self?.toggleMode(animated: true, mode: self?.mode == PTTMode.normal ? .editing : .normal)
        }, for: .Click)
        
        button.scaleOnClick = true
    }
    
    private func toggleMode(animated: Bool, mode: PTTMode) {
        
        self.mode = mode
        recorded = nil

        guard let item = item as? PTTRowItem else {
            return
        }
        
        button.background = buttonColor
        textView.update(buttonText)
        
        button.change(size: NSMakeSize(textView.frame.width + 20, containerView.frame.height - 8), animated: animated)
        button.change(pos: NSMakePoint(containerView.frame.width - button.frame.width - 4, button.frame.minY), animated: animated)
        textView.change(pos: button.focus(textView.frame.size).origin, animated: animated)
        
        if animated {
            button.layer?.animateBackground()
        }
        switch mode {
        case .normal:
            shimmerView.change(opacity: 0, animated: animated)
        case .editing:
            shimmerView.layer?.opacity = 1.0
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.5
            animation.toValue = 1.0
            animation.duration = 0.8
            animation.timingFunction = .init(name: .easeInEaseOut)
            animation.repeatCount = .infinity
            animation.autoreverses = true
            shimmerView.layer?.add(animation, forKey: "opacity")
        }
        //DDStringFromKeyCode(event.keyCode, event.modifierFlags.rawValue))
        let attr: NSAttributedString
        if let settings = item.settings {
            let value = DDStringFromKeyCode(settings.keyCode, settings.modifierFlags).uppercased().reduce("", { current, value in
                var current = current
                if current.isEmpty {
                    current += String(value)
                } else {
                    current += " + "
                    current += String(value)
                }
                return current
            })
            attr = .initialize(string: value, color: .white, font: .medium(.header))
        } else {
            attr = .initialize(string: L10n.voiceChatSettingsPushToTalkUndefined, color: GroupCallTheme.grayStatusColor, font: .medium(.header))
        }
        let layout = TextViewLayout(attr)
        layout.measure(width: .greatestFiniteMagnitude)
        
        shortcutView.update(layout)
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PTTRowItem else {
            return
        }
        button.setFrameSize(NSMakeSize(textView.frame.width + 20, containerView.frame.height - 8))
        button.centerY(x: containerView.frame.width - button.frame.width - 4)
        
        textView.center()
        
        shortcutView.centerY(x: item.viewType.innerInset.left)
        
        shimmerView.frame = containerView.frame
    }
    
    var buttonColor: NSColor {
        switch mode {
        case .editing:
            return GroupCallTheme.speakLockedColor.withAlphaComponent(0.2)
        case .normal:
            return GroupCallTheme.speakInactiveColor.withAlphaComponent(0.2)
        }
    }
    
    var buttonText: TextViewLayout {
        let textLayout: TextViewLayout
        switch self.mode {
        case .normal:
            textLayout = TextViewLayout(.initialize(string: L10n.voiceChatSettingsPushToTalkEditKeybind, color: GroupCallTheme.speakInactiveColor, font: .medium(.text)))
        case .editing:
            textLayout = TextViewLayout(.initialize(string: L10n.voiceChatSettingsPushToTalkStopRecording, color: GroupCallTheme.speakLockedColor, font: .medium(.text)))
        }
        textLayout.measure(width: .greatestFiniteMagnitude)
        return textLayout
    }
    
    override func updateColors() {
        super.updateColors()
        shimmerView.backgroundColor = NSColor.redUI
    }
    
    override var backdorColor: NSColor {
        return GroupCallTheme.membersColor
    }
    
    private var effectivePtt: PTTSettings? {
        guard let item = item as? PTTRowItem else {
            return self.recorded
        }
        return self.recorded ?? item.settings
    }
    
    private var recorded: PTTSettings? = nil
    private func addRecordedEvent(_ event: NSEvent) {
        if recorded == nil {
            recorded = PTTSettings(keyCode: KeyboardKey.Undefined.rawValue, modifierFlags: 0)
        }
        if let keyCode = KeyboardKey(rawValue: event.keyCode) {
            if !keyCode.isFlagKey {
                recorded?.keyCode = keyCode.rawValue
                recorded?.modifierFlags = event.modifierFlags.rawValue
            }
        }
    }
    private func finishRecording() {
        guard let item = item as? PTTRowItem else {
            return
        }
        if recorded?.keyCode != KeyboardKey.Undefined.rawValue {
            item.update(recorded)
        } else {
            shake(beep: true)
            set(item: item, animated: true)
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        addRecordedEvent(event)
    }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        addRecordedEvent(event)
    }
    
    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        finishRecording()
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window = newWindow as? Window {
            
            window.set(responder: { [weak self] in
                return self
            }, with: self, priority: .supreme)
            

        } else if let window = self.window as? Window {
            window.removeAllHandlers(for: self)
        }
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? PTTRowItem else {
            return
        }
        self.toggleMode(animated: animated, mode: .normal)
                
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
