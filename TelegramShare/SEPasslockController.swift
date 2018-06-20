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


enum PasscodeViewState {
    case login
}

private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let photoView:AvatarControl = AvatarControl(font: .avatar(23.0))
    fileprivate let nameView:TextView = TextView()
    fileprivate let input:NSSecureTextField
    private let nextButton:TitleButton = TitleButton()
    private var state:PasscodeViewState?
    
    fileprivate var cancel:ImageButton = ImageButton()
    
    fileprivate let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    required init(frame frameRect: NSRect) {
        input = NSSecureTextField(frame: NSZeroRect)
        input.stringValue = ""
        super.init(frame: frameRect)
        photoView.setFrameSize(NSMakeSize(80, 80))
        self.backgroundColor = theme.colors.background
        nextButton.set(color: theme.colors.blueUI, for: .Normal)
        nextButton.set(font: .normal(.title), for: .Normal)
        nextButton.set(text: tr(L10n.shareExtensionPasscodeNext), for: .Normal)
        nextButton.sizeToFit()
        
        cancel.set(image: theme.icons.chatInlineDismiss, for: .Normal)
        cancel.sizeToFit()

        
        nameView.backgroundColor = theme.colors.background
        addSubview(photoView)
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
    
    func update(with state:PasscodeViewState, account:Account, peer:Peer) {
        self.state = state
        
        photoView.setPeer(account: account, peer: peer)
        let layout = TextViewLayout(.initialize(string:peer.displayTitle, color: theme.colors.text, font:.normal(.title)))
        layout.measure(width: frame.width - 40)
        nameView.update(layout)
        
        needsLayout = true
        changeInput(state)
        
    }
    
    fileprivate func changeInput(_ state:PasscodeViewState) {
       
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(input.frame.minX, input.frame.maxY + 10, input.frame.width, .borderSize))
    }
    
    override func layout() {
        super.layout()
        
        photoView.center()
        photoView.setFrameOrigin(photoView.frame.minX, photoView.frame.minY - floorToScreenPixels(scaleFactor: backingScaleFactor, (20 + input.frame.height + 60)/2.0) - 20)
        input.setFrameSize(200, input.frame.height)
        nameView.centerX(y: photoView.frame.maxY + 20)
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
    private let account:Account
    private var state: PasscodeViewState {
        didSet {
            self.genericView.changeInput(state)
        }
    }
    private let disposable:MetaDisposable = MetaDisposable()
    private let valueDisposable = MetaDisposable()
    private let logoutDisposable = MetaDisposable()
    private var passcodeValues:[String] = []
    private let _doneValue:Promise<Bool> = Promise()
    
    var doneValue:Signal<Bool, Void> {
        return _doneValue.get()
    }
    private let cancelImpl:()->Void
    init(_ account:Account, _ state: PasscodeViewState, cancelImpl:@escaping()->Void) {
        self.account = account
        self.state = state
        self.cancelImpl = cancelImpl
        super.init(frame: NSMakeRect(0, 0, 340, 310))
    }
    
    override var isFullScreen: Bool {
        switch state {
        case .login:
            return true
        }
    }
    
    private var genericView:PasscodeLockView {
        return self.view as! PasscodeLockView
    }
    
    private func checkNextValue(_ passcode: String, _ current:String?) {
        switch state {
        case .login:
            if current == passcode {
                _doneValue.set(.single(true))
                close()
            } else {
                genericView.input.shake()
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.cancel.set(handler: { [weak self] _ in
            self?.cancelImpl()
        }, for: .Click)
        valueDisposable.set((genericView.value.get() |> mapToSignal { [weak self] value in
            if let strongSelf = self {
                return strongSelf.account.postbox.transaction { transaction -> (String, String?) in
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
        
        disposable.set((account.postbox.loadedPeerWithId(account.peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                strongSelf.genericView.update(with: strongSelf.state, account: strongSelf.account, peer: peer)
                strongSelf.readyOnce()
            }
        }))
        
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

