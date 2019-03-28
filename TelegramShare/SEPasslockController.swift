//
//  SEPasslockController.swift
//  Telegram
//
//  Created by keepcoder on 29/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

//
//  PasscodeLockController.swift
//  TelegramMac
//
//  Created by keepcoder on 10/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac




private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let nameView:TextView = TextView()
    fileprivate let input:NSSecureTextField
    private let nextButton:TitleButton = TitleButton()
    
    fileprivate var cancel:ImageButton = ImageButton()
    
    fileprivate let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    required init(frame frameRect: NSRect) {
        input = NSSecureTextField(frame: NSZeroRect)
        input.stringValue = ""
        super.init(frame: frameRect)
        self.backgroundColor = theme.colors.background
        nextButton.set(color: theme.colors.blueUI, for: .Normal)
        nextButton.set(font: .normal(.title), for: .Normal)
        nextButton.set(text: tr(L10n.shareExtensionPasscodeNext), for: .Normal)
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
        _ = attr.append(string: tr(L10n.shareExtensionPasscodePlaceholder), color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
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
        nameView.centerX(y: nameView.frame.minY - floorToScreenPixels(scaleFactor: backingScaleFactor, (20 + input.frame.height + 60)/2.0) - 20)
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
    private let context: SharedAccountContext

    private let disposable:MetaDisposable = MetaDisposable()
    private let valueDisposable = MetaDisposable()
    private let logoutDisposable = MetaDisposable()
    private var passcodeValues:[String] = []
    private let _doneValue:Promise<Bool> = Promise()
    
    var doneValue:Signal<Bool, NoError> {
        return _doneValue.get()
    }
    private let cancelImpl:()->Void
    init(_ context: SharedAccountContext, cancelImpl:@escaping()->Void) {
        self.context = context
        self.cancelImpl = cancelImpl
        super.init(frame: NSMakeRect(0, 0, 340, 310))
    }
    
    override var isFullScreen: Bool {
        return true
    }
    
    private var genericView:PasscodeLockView {
        return self.view as! PasscodeLockView
    }
    
    private func checkNextValue(_ passcode: String, _ current:String?) {
        if current == passcode {
            _doneValue.set(.single(true))
            close()
        } else {
            genericView.input.shake()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.cancel.set(handler: { [weak self] _ in
            self?.cancelImpl()
        }, for: .Click)
        
        valueDisposable.set((genericView.value.get() |> mapToSignal { [weak self] value in
            if let strongSelf = self {
                return strongSelf.context.accountManager.transaction { transaction -> (String, String?) in
                    switch transaction.getAccessChallengeData() {
                    case .none:
                        return (value, nil)
                    case let .plaintextPassword(passcode, _, _), let .numericalPassword(passcode, _, _):
                        return (value, passcode)
                    }
                }
            }
            return .single(("", nil))
            } |> deliverOnMainQueue).start(next: { [weak self] value, current in
                self?.checkNextValue(value, current)
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
        disposable.dispose()
        logoutDisposable.dispose()
        valueDisposable.dispose()
        self.window?.removeAllHandlers(for: self)
    }
    
    override func viewClass() -> AnyClass {
        return PasscodeLockView.self
    }
    
}

