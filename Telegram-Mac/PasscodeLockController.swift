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

enum PasscodeInnerState {
    case old
    case new
    case confirm
}

private class TouchIdContainerView : View {
    fileprivate let button: TitleButton = TitleButton()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        
        button.autohighlight = false
        button.style = ControlStyle(font: .medium(.title), foregroundColor: .white, backgroundColor: theme.colors.blueUI, highlightColor: theme.colors.blueUI)
        button.set(font: .medium(.title), for: .Normal)
        button.set(color: .white, for: .Normal)

        button.set(text: L10n.passcodeUseTouchId, for: .Normal)
        button.set(image: theme.icons.passcodeTouchId, for: .Normal)
        button.layer?.cornerRadius = .cornerRadius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        _ = button.sizeToFit(NSMakeSize(0, 0), NSMakeSize(frame.width, 36), thatFit: true)
        button.centerX(y: frame.height - button.frame.height)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let (text, layout) = TextNode.layoutText(NSAttributedString.initialize(string: L10n.passcodeOr, color: theme.colors.grayText, font: .normal(.title)), theme.colors.background, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
        
        let f = focus(text.size)
        layout.draw(NSMakeRect(f.minX, 0, f.width, f.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, floorToScreenPixels(scaleFactor: backingScaleFactor, f.height / 2), f.minX - 10, .borderSize))
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(f.maxX + 10, floorToScreenPixels(scaleFactor: backingScaleFactor, f.height / 2), f.minX - 10, .borderSize))
    }
}

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

enum PasscodeViewState {
    case login(hasTouchId: Bool)
    case change(PasscodeInnerState)
    case enable(PasscodeInnerState)
    case disable(PasscodeInnerState)
}

private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let photoView:AvatarControl = AvatarControl(font: .avatar(23.0))
    fileprivate let nameView:TextView = TextView()
    fileprivate let input:PasscodeField
    private let nextButton:ImageButton = ImageButton()
    private var state:PasscodeViewState?
    private let touchIdContainer:TouchIdContainerView = TouchIdContainerView(frame: NSMakeRect(0, 0, 200, 76))
    fileprivate let logoutTextView:TextView = TextView()
    fileprivate let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    fileprivate var logoutImpl:() -> Void = {}
    fileprivate var useTouchIdImpl:() -> Void = {}
    private let inputContainer: View = View()
    private var fieldState: SearchFieldState = .None
    
    required init(frame frameRect: NSRect) {
        input = PasscodeField(frame: NSZeroRect)
        input.stringValue = ""
        super.init(frame: frameRect)
        photoView.setFrameSize(NSMakeSize(80, 80))
        self.backgroundColor = .white
        
        nextButton.set(background: theme.colors.blueIcon, for: .Normal)
        nextButton.set(image: theme.icons.passcodeLogin, for: .Normal)
        nextButton.setFrameSize(26, 26)
        nextButton.layer?.cornerRadius = nextButton.frame.height / 2
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        addSubview(nextButton)

        addSubview(photoView)
        addSubview(nameView)
        addSubview(inputContainer)
        addSubview(logoutTextView)
        addSubview(touchIdContainer)
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.delegate = self
        input.drawsBackground = false
        input.textView?.insertionPointColor = theme.colors.text
        
        inputContainer.backgroundColor = theme.colors.grayBackground
        inputContainer.layer?.cornerRadius = .cornerRadius
        inputContainer.addSubview(input)
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: tr(L10n.passcodeEnterPasscodePlaceholder), color: theme.colors.grayText, font: .normal(.title))
        //attr.setAlignment(.center, range: attr.range)
        input.placeholderAttributedString = attr
        input.font = .normal(.title)
        input.textColor = theme.colors.text
        input.textView?.insertionPointColor = theme.colors.grayText
        input.sizeToFit()
        
        let logoutAttr = parseMarkdownIntoAttributedString(tr(L10n.passcodeLostDescription), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
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
        
        touchIdContainer.button.set(handler: { [weak self] _ in
            self?.useTouchIdImpl()
        }, for: .SingleClick)
        
        updateLocalizationAndTheme()
        change(state: .None, animated: false)
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
    
    override func controlTextDidChange(_ obj: Notification) {
        change(state: fieldState, animated: true)
    }
    

    
    override func controlTextDidBeginEditing(_ obj: Notification) {
        change(state: .Focus, animated: true)
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        window?.makeFirstResponder(input)
    }
    
    private func change(state: SearchFieldState, animated: Bool) {
        self.fieldState = state
        switch state {
        case .Focus:
            input._change(size: NSMakeSize(inputContainer.frame.width - 10, input.frame.height), animated: animated)
            input._change(pos: NSMakePoint(5, input.frame.minY), animated: animated)
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
            hideTouchIdUI()
            self.logoutTextView.isHidden = true
        }
        needsLayout = true
        changeInput(state)

    }
    
    fileprivate func changeInput(_ state:PasscodeViewState) {
        let placeholder = NSMutableAttributedString()
        let text:String
        
        switch state {
        case let .login(hasTouchId):
            text = tr(L10n.passcodeEnterPasscodePlaceholder)
            if hasTouchId {
                showTouchIdUI()
            } else {
                hideTouchIdUI()
            }
        case let .change(inner), let .enable(inner), let .disable(inner):
            switch inner {
            case .old:
                text = tr(L10n.passcodeEnterCurrentPlaceholder)
            case .new:
                text = tr(L10n.passcodeEnterNewPlaceholder)
            case .confirm:
                text = tr(L10n.passcodeReEnterPlaceholder)
            }
        }
        input.stringValue = ""
        _ = placeholder.append(string: text, color: theme.colors.grayText, font: .normal(.title))
        input.placeholderAttributedString = placeholder
    }
    
    private func showTouchIdUI() {
        touchIdContainer.isHidden = false
    }
    
    private func hideTouchIdUI() {
        touchIdContainer.isHidden = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    override func layout() {
        super.layout()
        
        inputContainer.setFrameSize(200, 36)
        input.setFrameSize(input.frame.width, input.frame.height)
        input.center()
        
        
        logoutTextView.layout?.measure(width: frame.width - 40)
        logoutTextView.update(logoutTextView.layout)
        
        photoView.center()
        photoView.setFrameOrigin(photoView.frame.minX, photoView.frame.minY - floorToScreenPixels(scaleFactor: backingScaleFactor, (20 + input.frame.height + 60)/2.0) - 20)
        nameView.centerX(y: photoView.frame.maxY + 20)
        logoutTextView.centerX(y:frame.height - logoutTextView.frame.height - 20)
        setNeedsDisplayLayer()
        
        inputContainer.centerX(y: nameView.frame.maxY + 30)
        
        touchIdContainer.centerX(y: inputContainer.frame.maxY + 20)
        nextButton.setFrameOrigin(inputContainer.frame.maxX + 10, inputContainer.frame.minY + (inputContainer.frame.height - nextButton.frame.height) / 2)
        
        change(state: fieldState, animated: false)
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
    private let laContext = LAContext()
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
                    _doneValue.set(account.postbox.transaction { transaction -> Bool in
                        transaction.setAccessChallengeData(.plaintextPassword(value: passcode, timeout: 60*60, attempts: nil))
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
                    _doneValue.set(account.postbox.transaction { transaction -> Bool in
                        transaction.setAccessChallengeData(.none)
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
                    _doneValue.set(account.postbox.transaction { transaction -> Bool in
                        transaction.setAccessChallengeData(.plaintextPassword(value: passcode, timeout: transaction.getAccessChallengeData().timeout, attempts: nil))
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
    
    override func windowDidBecomeKey() {
        super.windowDidBecomeKey()

        if NSApp.isActive {
          //  callTouchId()
        }
    }
    
    override func windowDidResignKey() {
        super.windowDidResignKey()
        if !NSApp.isActive {
           // invalidateTouchId()
        }
    }
    
    func callTouchId() {
        if laContext.canUseBiometric {
            laContext.evaluatePolicy(.applicationPolicy, localizedReason: tr(L10n.passcodeUnlockTouchIdReason)) { (success, evaluateError) in
                if (success) {
                    Queue.mainQueue().async {
                        self._doneValue.set(.single(true))
                        self.close()
                    }
                }
            }
        }
    }
    
    func invalidateTouchId() {
        laContext.invalidate()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        genericView.logoutImpl = logoutImpl
        
        genericView.useTouchIdImpl = { [weak self] in
            self?.callTouchId()
        }
        
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
        
        disposable.set(combineLatest(account.postbox.loadedPeerWithId(account.peerId) |> deliverOnMainQueue, additionalSettings(postbox: account.postbox) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peer, additional in
            if let strongSelf = self {
                var state = strongSelf.state
                if additional.useTouchId {
                    switch strongSelf.state {
                    case .login:
                        state = .login(hasTouchId: true)
                    default:
                        break
                    }
                }
                strongSelf.genericView.update(with: state, account: strongSelf.account, peer: peer)
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

