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


private class TouchIdContainerView : View {
    fileprivate let button: TitleButton = TitleButton()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        
        button.autohighlight = false
        button.style = ControlStyle(font: .medium(.title), foregroundColor: .white, backgroundColor: theme.colors.accent, highlightColor: theme.colors.accent)
        button.set(font: .medium(.title), for: .Normal)
        button.set(color: .white, for: .Normal)

        button.set(text: L10n.passcodeUseTouchId, for: .Normal)
        button.set(image: theme.icons.passcodeTouchId, for: .Normal)
        button.layer?.cornerRadius = 18
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        _ = button.sizeToFit(NSMakeSize(16, 0), NSMakeSize(0, 36), thatFit: true)
        button.centerX(y: frame.height - button.frame.height)
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let (text, layout) = TextNode.layoutText(NSAttributedString.initialize(string: L10n.passcodeOr, color: theme.colors.grayText, font: .normal(.title)), theme.colors.background, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
        
        let f = focus(text.size)
        layout.draw(NSMakeRect(f.minX, 0, f.width, f.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, floorToScreenPixels(backingScaleFactor, f.height / 2), f.minX - 10, .borderSize))
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(f.maxX + 10, floorToScreenPixels(backingScaleFactor, f.height / 2), f.minX - 10, .borderSize))
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


private class PasscodeLockView : Control, NSTextFieldDelegate {
    fileprivate let nameView:TextView = TextView()
    fileprivate let input:PasscodeField
    private let nextButton:ImageButton = ImageButton()
    private var hasTouchId:Bool = false
    private let touchIdContainer:TouchIdContainerView = TouchIdContainerView(frame: NSMakeRect(0, 0, 240, 76))
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
        autoresizingMask = [.width, .height]
        self.backgroundColor = .white
        
        nextButton.set(background: theme.colors.blueIcon, for: .Normal)
        nextButton.set(image: theme.icons.passcodeLogin, for: .Normal)
        nextButton.setFrameSize(26, 26)
        nextButton.layer?.cornerRadius = nextButton.frame.height / 2
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        addSubview(nextButton)

        addSubview(nameView)
        addSubview(inputContainer)
        addSubview(logoutTextView)
        addSubview(touchIdContainer)
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
        //attr.setAlignment(.center, range: attr.range)
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
        
        touchIdContainer.button.set(handler: { [weak self] _ in
            self?.useTouchIdImpl()
        }, for: .SingleClick)
        
        updateLocalizationAndTheme(theme: theme)
        change(state: .None, animated: false)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        logoutTextView.backgroundColor = theme.colors.background
        input.backgroundColor = theme.colors.background
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
    
    func update(hasTouchId: Bool) {
        self.hasTouchId = hasTouchId
        
        let layout = TextViewLayout(.initialize(string: L10n.passlockEnterYourPasscode, color: theme.colors.text, font: .medium(17)))
        layout.measure(width: frame.width - 40)
        nameView.update(layout)

        let text = L10n.passcodeEnterPasscodePlaceholder
        if hasTouchId {
            showTouchIdUI()
        } else {
            hideTouchIdUI()
        }
        
        input.stringValue = ""
        let placeholder = NSMutableAttributedString()
        _ = placeholder.append(string: text, color: theme.colors.grayText, font: .normal(.title))
        input.placeholderAttributedString = placeholder
        
        needsLayout = true

    }
    
    private func showTouchIdUI() {
        touchIdContainer.isHidden = false
    }
    
    private func hideTouchIdUI() {
        touchIdContainer.isHidden = true
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
        
        touchIdContainer.centerX(y: inputContainer.frame.maxY + 20)
        nextButton.setFrameOrigin(inputContainer.frame.maxX + 10, inputContainer.frame.minY + (inputContainer.frame.height - nextButton.frame.height) / 2)
        
        change(state: fieldState, animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PasscodeLockController: ModalViewController {
    let accountManager: AccountManager
    private let useTouchId: Bool
    private let disposable:MetaDisposable = MetaDisposable()
    private let valueDisposable = MetaDisposable()
    private let logoutDisposable = MetaDisposable()
    private let _doneValue:Promise<Bool> = Promise()
    private let laContext = LAContext()
    var doneValue:Signal<Bool, NoError> {
        return _doneValue.get()
    }
    
    
    
    private let logoutImpl:() -> Signal<Never, NoError>
    init(_ accountManager: AccountManager, useTouchId: Bool, logoutImpl:@escaping()->Signal<Never, NoError> = { .complete() }) {
        self.accountManager = accountManager
        self.logoutImpl = logoutImpl
        self.useTouchId = useTouchId
        super.init(frame: NSMakeRect(0, 0, 340, 310))
        self.bar = .init(height: 0)
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
        
        genericView.useTouchIdImpl = { [weak self] in
            self?.callTouchId()
        }
        
        let accountManager = self.accountManager
        
        valueDisposable.set((genericView.value.get() |> mapToSignal { value in
            return accountManager.transaction { transaction -> (String, String?) in
                switch transaction.getAccessChallengeData() {
                case .none:
                    return (value, nil)
                case let .plaintextPassword(passcode, _, _), let .numericalPassword(passcode, _, _):
                    return (value, passcode)
                }
            }
        } |> deliverOnMainQueue).start(next: { [weak self] value, current in
            self?.checkNextValue(value, current)
        }))
        
        genericView.update(hasTouchId: useTouchId)
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
        disposable.dispose()
        logoutDisposable.dispose()
        valueDisposable.dispose()
        self.window?.removeAllHandlers(for: self)
    }
    
    override func viewClass() -> AnyClass {
        return PasscodeLockView.self
    }
    
}

