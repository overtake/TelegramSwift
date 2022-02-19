//
//  Auth_CodeEntryContol.swift
//  Telegram
//
//  Created by Mike Renoir on 17.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import KeyboardKey

final class Auth_CodeEntryContol : View {
    
    class Auth_CodeElement : Control {
        private var textView: TextView? = nil
        private var current: UInt16? = nil
        
        
        
        var prev:((Control, Bool)->Void)?
        var next:((Control, Bool)->Void)?
        var invoke:(()->Void)?
        
        var locked: Bool = false

        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            layer?.cornerRadius = 10
            updateLocalizationAndTheme(theme: theme)
            self.set(handler: { control in
                control.window?.makeFirstResponder(control)
            }, for: .Click)
        }
        
        var value: String {
            if let current = current {
                return "\(current)"
            } else {
                return ""
            }
        }
        
        override func keyUp(with event: NSEvent) {
            super.keyUp(with: event)
        }
        
        override func keyDown(with event: NSEvent) {
            super.keyDown(with: event)
            
            guard !locked else {
                return
            }
            
            if let keyCode = KeyboardKey(rawValue: event.keyCode) {
                switch keyCode {
                case .Delete:
                    self.inputKey(nil, animated: true)
                    prev?(self, false)
                case .Tab:
                    next?(self, true)
                case .LeftArrow:
                    prev?(self, true)
                case .RightArrow:
                    next?(self, true)
                case .Return:
                    invoke?()
                default:
                    self.inputKey(event.keyCode, animated: true)
                }
            }
        }
        
        private func updateTextView() {
            if let textView = textView, let current = self.current {
                let layout = TextViewLayout(.initialize(string: "\(current)", color: locked ? theme.colors.grayText : theme.colors.text, font: .code(24)))
                layout.measure(width: .greatestFiniteMagnitude)
                textView.update(layout)
            }
        }
        
        func inputKey(_ keyCode: UInt16?, animated: Bool) {
            if let keyCode = keyCode {
                if let number = KeyboardKey(rawValue: keyCode)?.number {
                    if self.current != number {
                        if let view = textView {
                            performSubviewRemoval(view, animated: animated, duration: 0.2, scale: true)
                        }
                        let textView = TextView()
                        self.textView = textView
                        addSubview(textView)
                        let layout = TextViewLayout(.initialize(string: "\(number)", color: theme.colors.text, font: .code(24)))
                        layout.measure(width: .greatestFiniteMagnitude)
                        textView.update(layout)
                        textView.centerX(y: 7)
                        textView.userInteractionEnabled = false
                        textView.isSelectable = false
                        textView.isEventLess = true
                        if animated {
                            textView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                            textView.layer?.animatePosition(from: NSMakePoint(textView.frame.minX, textView.frame.minY + 5), to: textView.frame.origin)
                            textView.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                        }
                    }
                    self.current = number
                    self.next?(self, false)
                } else {
                    self.shake(beep: true)
                }
            } else {
                if let view = textView {
                    performSubviewRemoval(view, animated: animated, duration: 0.2, scale: true)
                }
                self.textView = nil
                self.current = nil
            }
        }
        
        override func layout() {
            super.layout()
            textView?.centerX(y: 7)
        }
        
        override func updateLocalizationAndTheme(theme: PresentationTheme) {
            super.updateLocalizationAndTheme(theme: theme)
            layer?.borderWidth = .borderSize
            background = theme.colors.grayBackground
        }
        
        var isFirstResponder: Bool {
            return window?.firstResponder == self
        }
        
        private func updateResponder(animated: Bool) {
            layer?.borderColor = isFirstResponder && !locked ? theme.colors.accent.cgColor : .clear
            if animated {
                layer?.animateBorder()
            }
        }
        
        override func resignFirstResponder() -> Bool {
            DispatchQueue.main.async {
                self.updateResponder(animated: true)
            }
            return true
        }
        
        override func becomeFirstResponder() -> Bool {
            DispatchQueue.main.async {
                self.updateResponder(animated: true)
            }
            return true
        }
        
        func set(locked: Bool, animated: Bool) {
            self.locked = locked
            updateResponder(animated: animated)
            updateTextView()
        }
        
        func clear() {
            inputKey(nil, animated: true)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    
    var takeNext:((String)->Void)?
    var takeError:(()->Void)?

    var locked: Bool = false
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    
    func moveToStart() {
        let subviews = self.subviews.compactMap { $0 as? Auth_CodeElement }
        for subview in subviews {
            subview.clear()
        }
        let subview = self.subviews.compactMap { $0 as? Auth_CodeElement }.first
        window?.makeFirstResponder(subview)
    }
    
    func set(locked: Bool, animated: Bool) {
        self.locked = locked
        let subviews = self.subviews.compactMap { $0 as? Auth_CodeElement }
        for subview in subviews {
            subview.set(locked: locked, animated: animated)
        }
    }
    
    func update(count: Int) -> NSSize {
        while subviews.count > count {
            subviews.removeLast()
        }
        while subviews.count < count {
            let Auth_CodeElement = Auth_CodeElement(frame: NSMakeRect(0, 0, 40, 40))
            
            Auth_CodeElement.next = { [weak self] control, flip in
                self?.next(control, flip)
            }
            Auth_CodeElement.prev = { [weak self] control, flip in
                self?.prev(control, flip)
            }
            Auth_CodeElement.invoke = { [weak self] in
                self?.invoke()
            }
            subviews.append(Auth_CodeElement)
        }
        needsLayout = true
        return NSMakeSize(subviewsSize.width + (CGFloat(subviews.count - 1) * 8) + 20, 40)
    }
    var value: String {
        let values = self.subviews.compactMap { $0 as? Auth_CodeElement }
        return values.reduce("", { current, value in
            return current + value.value
        })
    }
  
    override func layout() {
        super.layout()
        var x: CGFloat = 10
        for subview in subviews {
            subview.setFrameOrigin(NSMakePoint(x, 0))
            x += subview.frame.width + 8
        }
    }
    
    func firstResponder() -> NSResponder? {
        for subview in subviews {
            if window?.firstResponder == subview {
                return subview
            }
        }
        return subviews.first
    }
    func prev(_ current: Control, _ flip: Bool) {
        let subviews = self.subviews.compactMap { $0 as? Auth_CodeElement }
        if let index = subviews.firstIndex(where: { $0 == current }) {
            if index > 0 {
                let view = subviews[index - 1]
                window?.makeFirstResponder(view)
            } else if flip {
                let view = subviews[subviews.count - 1]
                window?.makeFirstResponder(view)
            }
        }
    }
    func next(_ current: Control, _ flip: Bool) {
        if !flip {
            takeError?()
        }
        let subviews = self.subviews.compactMap { $0 as? Auth_CodeElement }
        if let index = subviews.firstIndex(where: { $0 == current }) {
            if index < subviews.count - 1 {
                let view = subviews[index + 1]
                window?.makeFirstResponder(view)
            } else if flip {
                let view = subviews[0]
                window?.makeFirstResponder(view)
            } else if let index = subviews.firstIndex(where: { $0.value.isEmpty }) {
                let view = subviews[index]
                window?.makeFirstResponder(view)
            }
            if value.length == subviews.count, index == subviews.count - 1 {
                self.takeNext?(value)
            }
        }
    }
    func invoke() {
        guard !locked else {
            return
        }
        let subviews = self.subviews.compactMap { $0 as? Auth_CodeElement }
        if value.count == subviews.count {
            self.takeNext?(value)
        } else if let view = subviews.first(where: { $0.value.isEmpty }) {
            window?.makeFirstResponder(view)
            view.shake(beep: false)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
