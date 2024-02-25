//
//  SEPasslockController.swift
//  Telegram
//
//  Created by keepcoder on 29/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Localization
import Postbox
import SwiftSignalKit




private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let nameView:TextView = TextView()
    fileprivate let input:NSSecureTextField
    private let nextButton:TextButton = TextButton()
    
    fileprivate var cancel:ImageButton = ImageButton()
    
    fileprivate let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    required init(frame frameRect: NSRect) {
        input = NSSecureTextField(frame: NSZeroRect)
        input.stringValue = ""
        super.init(frame: frameRect)
        self.backgroundColor = theme.colors.background
        nextButton.set(color: theme.colors.accent, for: .Normal)
        nextButton.set(font: .normal(.title), for: .Normal)
        nextButton.set(text: L10n.shareExtensionPasscodeNext, for: .Normal)
        _ = nextButton.sizeToFit()
        
        cancel.set(image: theme.icons.chatInlineDismiss, for: .Normal)
        _ = cancel.sizeToFit()

        
        nameView.backgroundColor = theme.colors.background
        addSubview(nameView)
        addSubview(input)
        addSubview(nextButton)
        addSubview(cancel)
        
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.alignment = .center
        input.delegate = self
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: L10n.shareExtensionPasscodePlaceholder, color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
        attr.setAlignment(.center, range: attr.range)
        input.placeholderAttributedString = attr
        input.backgroundColor = theme.colors.background
        input.font = NSFont.normal(FontSize.text)
        input.textColor = theme.colors.text
        input.textView?.insertionPointColor = theme.colors.text
        input.sizeToFit()
        
        input.target = self
        input.action = #selector(checkPasscode)
        
        nextButton.set(handler: { [weak self] _ in
            self?.checkPasscode()
        }, for: .SingleClick)
    }
    
    override func mouseMoved(with event: NSEvent) {
        
    }
    
    
    
    @objc func checkPasscode() {
        value.set(input.stringValue)
    }
    
    func update() {
        let layout = TextViewLayout(.initialize(string: L10n.passlockEnterYourPasscode, color: theme.colors.text, font:.normal(.title)))
        layout.measure(width: frame.width - 40)
        nameView.update(layout)
        
        needsLayout = true
        
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(input.frame.minX, input.frame.maxY + 10, input.frame.width, .borderSize))
    }
    
    override func layout() {
        super.layout()
        
        nameView.center()
        nameView.centerX(y: nameView.frame.minY - floorToScreenPixels(backingScaleFactor, (20 + input.frame.height + 60)/2.0) - 20)
        input.setFrameSize(200, input.frame.height)
        input.centerX(y: nameView.frame.minY + 30 + 20)
        input.setFrameOrigin(input.frame.minX, input.frame.minY)
        setNeedsDisplayLayer()
        
        nextButton.centerX(y: input.frame.maxY + 30)
        
        cancel.setFrameOrigin(frame.width - cancel.frame.width - 15, 15)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SEPasslockController: ModalViewController {

    private let valueDisposable = MetaDisposable()
    private let cancelImpl:()->Void
    private let checkNextValue: (String)->Bool
    init(checkNextValue: @escaping(String)->Bool, cancelImpl:@escaping()->Void) {
        self.cancelImpl = cancelImpl
        self.checkNextValue = checkNextValue
        super.init(frame: NSMakeRect(0, 0, 340, 310))
    }
    
    override var isFullScreen: Bool {
        return true
    }
    
    private var genericView:PasscodeLockView {
        return self.view as! PasscodeLockView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.cancel.set(handler: { [weak self] _ in
            self?.cancelImpl()
        }, for: .Click)
        
        valueDisposable.set((genericView.value.get() |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let `self` = self else {
                return
            }
            if !self.checkNextValue(value) {
                self.genericView.input.shake()
            }
        }))
        
        genericView.update()
        readyOnce()
        
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
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    deinit {
        valueDisposable.dispose()
        self.window?.removeAllHandlers(for: self)
    }
    
    override func viewClass() -> AnyClass {
        return PasscodeLockView.self
    }
    
}

