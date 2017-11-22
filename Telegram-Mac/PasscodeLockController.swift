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
import LocalAuthentication

enum PasscodeInnterState {
    case old
    case new
    case confirm
}

enum PasscodeViewState {
    case login
    case change(PasscodeInnterState)
    case enable(PasscodeInnterState)
    case disable(PasscodeInnterState)
}

private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let photoView:AvatarControl = AvatarControl(font: .avatar(.custom(23)))
    fileprivate let nameView:TextView = TextView()
    fileprivate let input:NSSecureTextField
    private let nextButton:TitleButton = TitleButton()
    private var state:PasscodeViewState?
    
    fileprivate let logoutTextView:TextView = TextView()
    fileprivate let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    fileprivate var logoutImpl:() -> Void = {}
    required init(frame frameRect: NSRect) {
        input = NSSecureTextField(frame: NSZeroRect)
        input.stringValue = ""
        super.init(frame: frameRect)
        photoView.setFrameSize(NSMakeSize(80, 80))
        self.backgroundColor = .white
        nextButton.set(color: theme.colors.blueUI, for: .Normal)
        nextButton.set(font: .medium(.title), for: .Normal)
        nextButton.set(text: tr(.passcodeNext), for: .Normal)
        nextButton.sizeToFit()
        
        
        addSubview(photoView)
        addSubview(nameView)
        addSubview(input)
        addSubview(logoutTextView)
        addSubview(nextButton)
        
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.alignment = .center
        input.delegate = self
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: tr(.passcodeEnterPasscodePlaceholder), color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
        attr.setAlignment(.center, range: attr.range)
        input.placeholderAttributedString = attr
        input.font = .normal(.text)
        input.textColor = theme.colors.text
        input.textView?.insertionPointColor = theme.colors.text
        input.sizeToFit()
        
        let logoutAttr = parseMarkdownIntoAttributedString(tr(.passcodeLostDescription), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedStringKey.link.rawValue, inAppLink.callback(contents,  {_ in}))
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
        
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        backgroundColor = theme.colors.background
        logoutTextView.backgroundColor = theme.colors.background
        input.backgroundColor = theme.colors.background
        nameView.backgroundColor = theme.colors.background
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

        switch state {
        case .login:
            self.logoutTextView.isHidden = false
        default:
            self.logoutTextView.isHidden = true
        }
        needsLayout = true
        changeInput(state)

    }
    
    fileprivate func changeInput(_ state:PasscodeViewState) {
        let placeholder = NSMutableAttributedString()
        let text:String
        
        switch state {
        case .login:
            text = tr(.passcodeEnterPasscodePlaceholder)
        case let .change(inner), let .enable(inner), let .disable(inner):
            switch inner {
            case .old:
                text = tr(.passcodeEnterCurrentPlaceholder)
            case .new:
                text = tr(.passcodeEnterNewPlaceholder)
            case .confirm:
                text = tr(.passcodeReEnterPlaceholder)
            }
        }
        input.stringValue = ""
        _ = placeholder.append(string: text, color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
        placeholder.setAlignment(.center, range: placeholder.range)
        input.placeholderAttributedString = placeholder
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(input.frame.minX, input.frame.maxY + 10, input.frame.width, .borderSize))
    }
    
    override func layout() {
        super.layout()
        
        
        logoutTextView.layout?.measure(width: frame.width - 40)
        logoutTextView.update(logoutTextView.layout)
        
        photoView.center()
        photoView.setFrameOrigin(photoView.frame.minX, photoView.frame.minY - floorToScreenPixels((20 + input.frame.height + 60)/2.0) - 20)
        input.setFrameSize(200, input.frame.height)
        nameView.centerX(y: photoView.frame.maxY + 20)
        input.centerX(y: nameView.frame.minY + 30 + 20)
        input.setFrameOrigin(input.frame.minX, input.frame.minY)
        logoutTextView.centerX(y:frame.height - logoutTextView.frame.height - 20)
        setNeedsDisplayLayer()
        
        nextButton.centerX(y: input.frame.maxY + 30)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PasscodeLockController: ModalViewController {
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
    
    private let logoutImpl:() -> Void
    init(_ account:Account, _ state: PasscodeViewState, logoutImpl:@escaping()->Void = {}) {
        self.account = account
        self.state = state
        self.logoutImpl = logoutImpl
        super.init(frame: NSMakeRect(0, 0, 340, 310))
        self.bar = .init(height: 0)
    }
    
    override var isFullScreen: Bool {
        switch state {
        case .login:
            return true
        default:
            return false
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
        case let .enable(inner):
            switch inner {
            case .new:
                passcodeValues.append(passcode)
                self.state = .enable(.confirm)
            case .confirm:
                if passcodeValues[0] == passcode {
                    _doneValue.set(account.postbox.modify { modifier -> Bool in
                        modifier.setAccessChallengeData(.plaintextPassword(value: passcode, timeout: 60*60, attempts: nil))
                        return true
                    })
                    close()
                } else {
                    genericView.input.shake()
                }
            default:
                break
            }
        case let .disable(inner):
            switch inner {
            case .old:
                if current == passcode {
                    _doneValue.set(account.postbox.modify { modifier -> Bool in
                        modifier.setAccessChallengeData(.none)
                        return true
                    })
                    close()
                } else {
                    genericView.input.shake()
                }
            default:
                break
            }
        case let .change(inner):
            switch inner {
            case .new:
                passcodeValues.append(passcode)
                self.state = .change(.confirm)
            case .confirm:
                if passcodeValues[0] == passcode {
                    _doneValue.set(account.postbox.modify { modifier -> Bool in
                        modifier.setAccessChallengeData(.plaintextPassword(value: passcode, timeout: modifier.getAccessChallengeData().timeout, attempts: nil))
                        return true
                    })
                    close()
                } else {
                    genericView.input.shake()
                }
            case .old:
                if current != passcode {
                    genericView.input.shake()
                } else {
                    self.state = .change(.new)
                }
            }
        }
    }
    
    func callTouchId() {
        let myContext = LAContext()
                
        if myContext.canUseBiometric {
            myContext.evaluatePolicy(.applicationPolicy, localizedReason: tr(.passcodeUnlockTouchIdReason)) { (success, evaluateError) in
                if (success) {
                    Queue.mainQueue().async {
                        self._doneValue.set(.single(true))
                        self.close()
                    }
                }
            }
        }
        

    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.logoutImpl = logoutImpl
        
        valueDisposable.set((genericView.value.get() |> mapToSignal { [weak self] value in
            if let strongSelf = self {
                return strongSelf.account.postbox.modify { modifier -> (String, String?) in
                    switch modifier.getAccessChallengeData() {
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
        
        disposable.set(combineLatest(account.postbox.loadedPeerWithId(account.peerId) |> deliverOnMainQueue, additionalSettings(postbox: account.postbox) |> take(1)).start(next: { [weak self] peer, additional in
            if let strongSelf = self {
                if additional.useTouchId {
                    switch strongSelf.state {
                    case .login:
                        strongSelf.callTouchId()
                    default:
                        break
                    }
                }
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

