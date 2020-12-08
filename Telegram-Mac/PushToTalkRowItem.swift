//
//  PushToTalkRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/12/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class PushToTalkRowItem : GeneralRowItem {
    fileprivate var settings: PushToTalkValue?
    fileprivate let checkPermission:()->Void
    fileprivate let update:(PushToTalkValue?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, settings: PushToTalkValue?, update:@escaping(PushToTalkValue?)->Void, checkPermission: @escaping()->Void, viewType: GeneralViewType) {
        self.settings = settings
        self.update = update
        self.checkPermission = checkPermission
        super.init(initialSize, height: 50, stableId: stableId, type: .none, viewType: viewType, inset: NSEdgeInsets(top: 3, left: 30, bottom: 3, right: 30), error: nil)
    }
    
    deinit {
        
    }
    
    override func viewClass() -> AnyClass {
        return PushToTalkRowView.self
    }
}



private final class PushToTalkRowView: GeneralContainableRowView {
        
    private enum PTTMode {
        case normal
        case editing
    }
    
    private var textView: TextView?
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
        addSubview(shortcutView)
        button.layer?.cornerRadius = 8
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 3
        shadow.shadowColor = NSColor.redUI.withAlphaComponent(1)
        shadow.shadowOffset = NSMakeSize(0, 0)
        shimmerView.shadow = shadow
        
        shimmerView.background = .random
        
        
        button.set(handler: { [weak self] _ in
            self?.toggleMode(animated: true, mode: self?.mode == PTTMode.normal ? .editing : .normal)
        }, for: .Click)
        
        button.scaleOnClick = true
        
        shortcutView.userInteractionEnabled = false
        shortcutView.isSelectable = false
    }
    
    private var recorder:KeyboardGlobalHandler?
    
    private func toggleMode(animated: Bool, mode: PTTMode) {
        
        self.mode = mode
        
        guard let item = item as? PushToTalkRowItem else {
            return
        }
        
        switch mode {
        case .editing:
            let recorder = KeyboardGlobalHandler()
            self.recorder = recorder
            recorder.setKeyUpHandler(nil, success: { [weak item, weak self] result in
                guard let item = item else {
                    return
                }
                let settings = PushToTalkValue(keyCodes: result.keyCodes, modifierFlags: result.modifierFlags, string: result.string)
                item.update(settings)
                item.settings = settings
                self?.set(item: item, animated: true)
            })

            item.checkPermission()
            
        case .normal:
            recorder = nil
        }
        
        button.background = buttonColor
        
        if self.textView?.layout?.attributedString.string != buttonText.attributedString.string {
            let textView = TextView()
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            textView.update(buttonText)
            
            button.addSubview(textView)
            textView.center()
            
            button.change(size: NSMakeSize(textView.frame.width + 20, containerView.frame.height - 8), animated: animated)
            button.change(pos: NSMakePoint(containerView.frame.width - button.frame.width - 4, button.frame.minY), animated: animated)
            
            if animated {
                textView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            if let textView = self.textView {
                if animated {
                    textView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak textView] _ in
                        textView?.removeFromSuperview()
                    })
                } else {
                    textView.removeFromSuperview()
                }
                
            }
            self.textView = textView
        }
        
       
        
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
        let attr: NSAttributedString
        if let settings = item.settings {
            attr = .initialize(string: settings.string, color: .white, font: .medium(.header))
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
        
        guard let item = item as? PushToTalkRowItem else {
            return
        }
        if let textView = textView {
            button.setFrameSize(NSMakeSize(textView.frame.width + 20, containerView.frame.height - 8))
            button.centerY(x: containerView.frame.width - button.frame.width - 4)
            textView.center()
        }
        
        
        shortcutView.centerY(x: item.viewType.innerInset.left, addition: 1)
        
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
    
    private var effectivePtt: PushToTalkValue? {
        guard let item = item as? PushToTalkRowItem else {
            return nil
        }
        return item.settings
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
        self.toggleMode(animated: animated, mode: .normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
