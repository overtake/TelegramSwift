//
//  ColdStartPasslockController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03.11.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private final class PasscodeField : NSSecureTextField {
    
    override func resignFirstResponder() -> Bool {
        (self.delegate as? PasscodeLockView)?.controlTextDidBeginEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        (self.delegate as? PasscodeLockView)?.controlTextDidEndEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.becomeFirstResponder()
    }
}


private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let nameView:TextView = TextView()
    fileprivate let input:PasscodeField
    private let nextButton:ImageButton = ImageButton()
    fileprivate let logoutTextView:TextView = TextView()
    fileprivate let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    fileprivate var logoutImpl:() -> Void = {}
    private let inputContainer: View = View()
    private var fieldState: SearchFieldState = .Focus
    
    required init(frame frameRect: NSRect) {
        input = PasscodeField(frame: NSZeroRect)
        input.stringValue = ""
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        self.backgroundColor = .clear
        
        nextButton.set(background: theme.colors.accentIcon, for: .Normal)
        nextButton.set(image: theme.icons.passcodeLogin, for: .Normal)
        nextButton.setFrameSize(26, 26)
        nextButton.layer?.cornerRadius = nextButton.frame.height / 2
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        addSubview(nextButton)
        
        addSubview(nameView)
        addSubview(inputContainer)
        addSubview(logoutTextView)
        input.isBordered = false
        input.usesSingleLineMode = true
        input.isBezeled = false
        input.focusRingType = .none
        input.delegate = self
        input.drawsBackground = false
        
        input.textView?.insertionPointColor = theme.colors.text
        
        inputContainer.backgroundColor = theme.colors.grayBackground
        inputContainer.layer?.cornerRadius = .cornerRadius
        inputContainer.addSubview(input)
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: L10n.passcodeEnterPasscodePlaceholder, color: theme.colors.grayText, font: .medium(17))
        input.placeholderAttributedString = attr
        input.cell?.usesSingleLineMode = true
        input.cell?.wraps = false
        input.cell?.isScrollable = true
        input.font = .normal(.title)
        input.textColor = theme.colors.text
        input.textView?.insertionPointColor = theme.colors.grayText
        
        input.sizeToFit()
        
        let logoutAttr = parseMarkdownIntoAttributedString(L10n.passcodeLostDescription, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  {_ in}))
        }))
        
        logoutTextView.isSelectable = false
        
        let logoutLayout = TextViewLayout(logoutAttr)
        logoutLayout.interactions = TextViewInteractions(processURL:{ [weak self] _ in
            self?.logoutImpl()
        })
        
        logoutTextView.set(layout: logoutLayout)
        
        input.target = self
        input.action = #selector(checkPasscode)
        
        nextButton.set(handler: { [weak self] _ in
            self?.checkPasscode()
        }, for: .SingleClick)
        
        
        updateLocalizationAndTheme(theme: theme)
        layout()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        logoutTextView.backgroundColor = theme.colors.background
        input.backgroundColor = theme.colors.background
        inputContainer.background = theme.colors.grayBackground
        nameView.backgroundColor = theme.colors.background
    }
    
    override func mouseMoved(with event: NSEvent) {
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        change(state: fieldState, animated: true)
    }
    
    
    
    func controlTextDidBeginEditing(_ obj: Notification) {
        change(state: .Focus, animated: true)
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        window?.makeFirstResponder(input)
    }
    
    private func change(state: SearchFieldState, animated: Bool) {
        self.fieldState = state
        switch state {
        case .Focus:
            input._change(size: NSMakeSize(inputContainer.frame.width - 20, input.frame.height), animated: animated)
            input._change(pos: NSMakePoint(10, input.frame.minY), animated: animated)
            nextButton.change(opacity: 1, animated: animated)
            nextButton._change(pos: NSMakePoint(inputContainer.frame.maxX + 10, nextButton.frame.minY), animated: animated)
        case .None:
            input.sizeToFit()
            let f = inputContainer.focus(input.frame.size)
            input._change(pos: NSMakePoint(f.minX, input.frame.minY), animated: animated)
            nextButton.change(opacity: 0, animated: animated)
            nextButton._change(pos: NSMakePoint(inputContainer.frame.maxX - nextButton.frame.width, nextButton.frame.minY), animated: animated)
        }
    }
    
    @objc func checkPasscode() {
        value.set(input.stringValue)
    }
    
    func update() {
        
        let layout = TextViewLayout(.initialize(string: L10n.passlockEnterYourPasscode, color: theme.colors.text, font: .medium(17)))
        layout.measure(width: frame.width - 40)
        nameView.update(layout)
        
        let text = L10n.passcodeEnterPasscodePlaceholder

        input.stringValue = ""
        let placeholder = NSMutableAttributedString()
        _ = placeholder.append(string: text, color: theme.colors.grayText, font: .normal(.title))
        input.placeholderAttributedString = placeholder
        
        needsLayout = true
        
    }
    
    override func layout() {
        super.layout()
        
        inputContainer.setFrameSize(200, 36)
        input.setFrameSize(inputContainer.frame.width - 20, input.frame.height)
        input.center()
        
        inputContainer.layer?.cornerRadius = inputContainer.frame.height / 2
        
        logoutTextView.layout?.measure(width: frame.width - 40)
        logoutTextView.update(logoutTextView.layout)
        
        nameView.center()
        nameView.centerX(y: nameView.frame.minY - floorToScreenPixels(backingScaleFactor, (20 + input.frame.height + 60)/2.0) - 20)
        logoutTextView.centerX(y:frame.height - logoutTextView.frame.height - 20)
        
        inputContainer.centerX(y: nameView.frame.maxY + 30)
        
        nextButton.setFrameOrigin(inputContainer.frame.maxX + 10, inputContainer.frame.minY + (inputContainer.frame.height - nextButton.frame.height) / 2)
        
        change(state: fieldState, animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ColdStartPasslockController: ModalViewController {
    private let valueDisposable = MetaDisposable()
    private let logoutDisposable = MetaDisposable()

    private let logoutImpl:() -> Signal<Never, NoError>
    private let checkNextValue: (String)->Bool
    init(checkNextValue:@escaping(String)->Bool, logoutImpl:@escaping()->Signal<Never, NoError>) {
        self.checkNextValue = checkNextValue
        self.logoutImpl = logoutImpl
        super.init(frame: NSMakeRect(0, 0, 350, 350))
        self.bar = .init(height: 0)
    }
    
    override var isVisualEffectBackground: Bool {
        return false
    }
    
    override var isFullScreen: Bool {
        return true
    }
    
    override var background: NSColor {
        return self.containerBackground
    }
    
    private var genericView:PasscodeLockView {
        return self.view as! PasscodeLockView
    }
    
   
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.logoutImpl = { [weak self] in
            guard let window = self?.window else { return }
            
            confirm(for: window, information: L10n.accountConfirmLogoutText, successHandler: { [weak self] _ in
                guard let `self` = self else { return }
                
                _ = showModalProgress(signal: self.logoutImpl(), for: window).start(completed: { [weak self] in
                    delay(0.2, closure: { [weak self] in
                        self?.close()
                    })
                })
            })
        }
        
        var locked = false
        
        valueDisposable.set((genericView.value.get() |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let `self` = self, !locked else {
                return
            }
            if !self.checkNextValue(value) {
                self.genericView.input.shake()
            } else {
                locked = true
            }
        }))
        
        genericView.update()
        readyOnce()
        
        
    }
    
    override var closable: Bool {
        return false
    }
    
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .invoked
    }
    
    override func firstResponder() -> NSResponder? {
        if !(window?.firstResponder is NSText) {
            return genericView.input
        }
        let editor = self.window?.fieldEditor(true, for: genericView.input)
        if window?.firstResponder != editor {
            return genericView.input
        }
        return editor
        
    }
    
    override var containerBackground: NSColor {
        return theme.colors.background.withAlphaComponent(1.0)
    }
    override var handleEvents: Bool {
        return true
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    
    override var responderPriority: HandlerPriority {
        return .supreme
    }
    
    deinit {
        logoutDisposable.dispose()
        valueDisposable.dispose()
        self.window?.removeAllHandlers(for: self)
    }
    
    override func viewClass() -> AnyClass {
        return PasscodeLockView.self
    }
    
}

