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
//import TelegramMedia



private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let input = NSSecureTextField(frame: NSZeroRect)
    fileprivate let inputContainer = View()
    private let nextButton = ImageButton()
    
    fileprivate var cancel:ImageButton = ImageButton()
    private let animationView: SE_LottiePlayerView = .init(frame: NSMakeRect(0, 0, 150, 150))
        
    fileprivate let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    required init(frame frameRect: NSRect) {
        input.stringValue = ""
        super.init(frame: frameRect)
        
        self.backgroundColor = theme.colors.background
        
        cancel.set(image: theme.icons.modalClose, for: .Normal)
        _ = cancel.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)

        
        inputContainer.addSubview(input)
        addSubview(animationView)
        addSubview(inputContainer)
        addSubview(nextButton)
        addSubview(cancel)
        
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.alignment = .left
        input.delegate = self
        
        let path = Bundle.main.path(forResource: "duck_passcode", ofType: "tgs")
        if let path = path {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            if let data = data {
                animationView.set(SE_LottieAnimation(compressed: data, key: .init(key: .bundle("duck_passcode"), size: NSMakeSize(150, 150)), playPolicy: .onceEnd))
            }
        }
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: L10n.shareExtensionPasscodePlaceholder, color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
        attr.setAlignment(.left, range: attr.range)
        input.placeholderAttributedString = attr
        input.backgroundColor = .clear
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
        inputContainer.backgroundColor = theme.colors.grayBackground
        
        
        nextButton.autohighlight = false
        nextButton.scaleOnClick = true
        nextButton.set(background: theme.colors.accentIcon, for: .Normal)
        nextButton.set(image: theme.icons.passcodeLogin, for: .Normal)
        nextButton.setFrameSize(26, 26)
        nextButton.scaleOnClick = true
        nextButton.layer?.cornerRadius = nextButton.frame.height / 2
        
        needsLayout = true
        
    }
    
    

    override func layout() {
        super.layout()
        
        animationView.centerX(y: 90)

        inputContainer.setFrameSize(NSMakeSize(frame.width - 80 - 30 - 10, 34))
        inputContainer.layer?.cornerRadius = inputContainer.frame.height / 2
        
        input.frame = inputContainer.focus(NSMakeSize(inputContainer.frame.width - 20, input.frame.height)).offsetBy(dx: 0, dy: -2)
        
        inputContainer.setFrameOrigin(NSMakePoint(40, animationView.frame.maxY + 20))
        
        
        nextButton.setFrameOrigin(NSMakePoint(inputContainer.frame.maxX + 10, inputContainer.frame.minY + 4))
        
        cancel.setFrameOrigin(10, 10)
        
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
                self.genericView.inputContainer.shake()
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

