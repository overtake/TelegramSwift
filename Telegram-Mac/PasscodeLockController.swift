//
//  PasscodeLockController.swift
//  TelegramMac
//
//  Created by keepcoder on 10/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit
import LocalAuthentication
import BuildConfig

private class TouchIdContainerView : View {
    fileprivate let button: TitleButton = TitleButton()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        
        button.scaleOnClick = true
        button.autohighlight = false
        button.style = ControlStyle(font: .medium(.title), foregroundColor: .white, backgroundColor: theme.colors.accent, highlightColor: theme.colors.accent)
        button.set(font: .medium(.title), for: .Normal)
        button.set(color: .white, for: .Normal)

        button.set(text: strings().passcodeUseTouchId, for: .Normal)
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
        
        let (text, layout) = TextNode.layoutText(NSAttributedString.initialize(string: strings().passcodeOr, color: theme.chatServiceItemTextColor, font: .normal(.title)), theme.colors.background, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
        
        let f = focus(text.size)
        layout.draw(NSMakeRect(f.minX, 0, f.width, f.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        
        ctx.setFillColor(theme.chatServiceItemTextColor.cgColor)
        ctx.fill(NSMakeRect(0, floorToScreenPixels(backingScaleFactor, f.height / 2), f.minX - 10, .borderSize))
        
        ctx.setFillColor(theme.chatServiceItemTextColor.cgColor)
        ctx.fill(NSMakeRect(f.maxX + 10, floorToScreenPixels(backingScaleFactor, f.height / 2), f.minX - 10, .borderSize))
    }
}

final class PasscodeField : NSSecureTextField {
    
    override func resignFirstResponder() -> Bool {
        (self.delegate as? PasscodeLockView)?.controlTextDidBeginEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        (self.delegate as? PasscodeLockView)?.controlTextDidEndEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.becomeFirstResponder()
    }
}


class PasscodeLockView : Control, NSTextFieldDelegate {
    private let backgroundView: BackgroundView = BackgroundView(frame: .zero)
    private let visualEffect: NSVisualEffectView = NSVisualEffectView(frame: .zero)

    
    fileprivate let nameView:TextView = TextView()
    let input:PasscodeField
    private let nextButton:ImageButton = ImageButton()
    private var hasTouchId:Bool = false
    private let touchIdContainer:TouchIdContainerView = TouchIdContainerView(frame: NSMakeRect(0, 0, 240, 76))
    fileprivate let logoutTextView:TextView = TextView()
    let value:ValuePromise<String> = ValuePromise(ignoreRepeated: false)
    var logoutImpl:() -> Void = {}
    fileprivate var useTouchIdImpl:() -> Void = {}
    private let inputContainer: View = View()
    private var fieldState: SearchFieldState = .Focus
    
    required init(frame frameRect: NSRect) {
        input = PasscodeField(frame: NSZeroRect)
        input.stringValue = ""
        backgroundView.useSharedAnimationPhase = false
        super.init(frame: frameRect)
        
        addSubview(backgroundView)
       // addSubview(visualEffect)
        
        visualEffect.state = .active
        visualEffect.blendingMode = .withinWindow
        
        autoresizingMask = [.width, .height]
        self.backgroundColor = .clear
        
        nextButton.autohighlight = false
        nextButton.set(background: theme.colors.accentIcon, for: .Normal)
        nextButton.set(image: theme.icons.passcodeLogin, for: .Normal)
        nextButton.setFrameSize(26, 26)
        nextButton.scaleOnClick = true
        nextButton.layer?.cornerRadius = nextButton.frame.height / 2
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        addSubview(nextButton)

//        addSubview(nameView)
        addSubview(inputContainer)
        addSubview(logoutTextView)
        addSubview(touchIdContainer)
        input.isBordered = false
        input.usesSingleLineMode = true
        input.isBezeled = false
        input.focusRingType = .none
        input.delegate = self
        input.drawsBackground = false
        
        nameView.disableBackgroundDrawing = true
        logoutTextView.disableBackgroundDrawing = true

            
        inputContainer.backgroundColor = theme.colors.grayBackground
        inputContainer.layer?.cornerRadius = .cornerRadius
        inputContainer.addSubview(input)
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().passcodeEnterPasscodePlaceholder, color: theme.colors.grayText, font: .medium(17))
        //attr.setAlignment(.center, range: attr.range)
        input.placeholderAttributedString = attr
        input.cell?.usesSingleLineMode = true
        input.cell?.wraps = false
        input.cell?.isScrollable = true
        input.font = .normal(.title)
        input.textView?.insertionPointColor = theme.colors.grayText
        
        input.sizeToFit()
        
       

        input.target = self
        input.action = #selector(checkPasscode)
        
        nextButton.set(handler: { [weak self] _ in
            self?.checkPasscode()
        }, for: .SingleClick)
        
        touchIdContainer.button.set(handler: { [weak self] _ in
            self?.useTouchIdImpl()
        }, for: .SingleClick)
        
        updateLocalizationAndTheme(theme: theme)
        layout()
    }
    
    var containerBgColor: NSColor {
        switch theme.controllerBackgroundMode {
        case .gradient:
            return theme.chatServiceItemColor
        case .background:
            return theme.chatServiceItemColor
        default:
            if theme.chatBackground == theme.chatServiceItemColor {
                return theme.colors.grayBackground
            }
        }
        return theme.chatServiceItemColor
    }
    
    var secondaryColor: NSColor {
        switch theme.controllerBackgroundMode {
        case .gradient:
            return theme.chatServiceItemTextColor
        case .background:
            return theme.chatServiceItemTextColor
        default:
            if theme.chatBackground == theme.chatServiceItemColor {
                return theme.colors.text
            }
        }
        return theme.chatServiceItemTextColor
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        backgroundColor = theme.colors.background
        input.backgroundColor = .clear
        input.textView?.insertionPointColor = secondaryColor;
        input.textColor = secondaryColor
        inputContainer.background = containerBgColor
        backgroundView.backgroundMode = theme.controllerBackgroundMode


        let placeholder = NSMutableAttributedString()
        _ = placeholder.append(string: strings().passcodeEnterPasscodePlaceholder, color: theme.chatServiceItemTextColor, font: .normal(.title))
        input.placeholderAttributedString = placeholder
        
        if #available(macOS 10.14, *) {
            visualEffect.material = .underWindowBackground
        } else {
            visualEffect.material = theme.colors.isDark ? .ultraDark : .light
        }
        
        let logoutAttr = parseMarkdownIntoAttributedString(strings().passcodeLostDescription, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.chatServiceItemTextColor), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.chatServiceItemTextColor), link: MarkdownAttributeSet(font: .bold(.text), textColor: secondaryColor == theme.chatServiceItemTextColor ? theme.chatServiceItemTextColor : theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  {_ in}))
        }))
        
        logoutTextView.isSelectable = false
        
        let logoutLayout = TextViewLayout(logoutAttr, alignment: .center)
        
        logoutLayout.interactions = TextViewInteractions(processURL:{ [weak self] _ in
            self?.logoutImpl()
        })
        logoutLayout.measure(width: frame.width - 40)
        if theme.bubbled {
            logoutLayout.generateAutoBlock(backgroundColor: theme.chatServiceItemColor)
        }
        logoutTextView.set(layout: logoutLayout)
        
        let layout = TextViewLayout(.initialize(string: strings().passlockEnterYourPasscode, color: theme.chatServiceItemTextColor, font: .medium(17)), alignment: .center)
        
        layout.measure(width: frame.width - 40)
        if theme.bubbled {
            layout.generateAutoBlock(backgroundColor: theme.chatServiceItemColor)
        }
        nameView.update(layout)
        
        
    }
    
    override func mouseMoved(with event: NSEvent) {
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        change(state: fieldState, animated: true)
        backgroundView.doAction()
    }
    

    
    func controlTextDidBeginEditing(_ obj: Notification) {
        change(state: .Focus, animated: true)
        input.textView?.insertionPointColor = secondaryColor
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        window?.makeFirstResponder(input)
        input.textView?.insertionPointColor = secondaryColor
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
        
        if hasTouchId {
            showTouchIdUI()
        } else {
            hideTouchIdUI()
        }
        
        input.stringValue = ""
       
        
        needsLayout = true

    }
    func updateAndSetValue() {
        self.value.set(self.input.stringValue)
        self.backgroundView.doAction()
    }
    
    private func showTouchIdUI() {
        touchIdContainer.isHidden = false
    }
    
    private func hideTouchIdUI() {
        touchIdContainer.isHidden = true
    }
    

    override func layout() {
        super.layout()
        
        backgroundView.frame = bounds
        backgroundView.updateLayout(size: frame.size, transition: .immediate)
        
        visualEffect.frame = bounds

        
        inputContainer.setFrameSize(200, 36)
        input.setFrameSize(inputContainer.frame.width - 20, input.frame.height)
        input.center()
        
        inputContainer.layer?.cornerRadius = inputContainer.frame.height / 2
        
        logoutTextView.resize(frame.width - 40, blockColor: theme.chatServiceItemColor)
        nameView.resize(frame.width - 40, blockColor: theme.chatServiceItemColor)
        
        
        inputContainer.center()
        inputContainer.setFrameOrigin(NSMakePoint(inputContainer.frame.minX - (nextButton.frame.width + 10) / 2, inputContainer.frame.minY))
        
        touchIdContainer.centerX(y: inputContainer.frame.maxY + 10)
        nextButton.setFrameOrigin(inputContainer.frame.maxX + 10, inputContainer.frame.minY + (inputContainer.frame.height - nextButton.frame.height) / 2)

        nameView.centerX(y: inputContainer.frame.minY - nameView.frame.height - 10)
        logoutTextView.centerX(y: frame.height - logoutTextView.frame.height - 10)
        
        
        change(state: fieldState, animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PasscodeLockController: ModalViewController {
    let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let useTouchId: Bool
    private let appearanceDisposable = MetaDisposable()
    private let disposable:MetaDisposable = MetaDisposable()
    private let valueDisposable = MetaDisposable()
    private let logoutDisposable = MetaDisposable()
    private let _doneValue:Promise<Bool> = Promise()
    private let laContext = LAContext()
    var doneValue:Signal<Bool, NoError> {
        return _doneValue.get()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
    private let updateCurrectController: ()->Void
    private let logoutImpl:() -> Signal<Never, NoError>
    init(_ accountManager: AccountManager<TelegramAccountManagerTypes>, useTouchId: Bool, logoutImpl:@escaping()->Signal<Never, NoError> = { .complete() }, updateCurrectController: @escaping()->Void) {
        self.accountManager = accountManager
        self.logoutImpl = logoutImpl
        self.useTouchId = useTouchId
        self.updateCurrectController = updateCurrectController
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
    
    private func checkNextValue(_ passcode: String) {
        let appEncryption = AppEncryptionParameters(path: accountManager.basePath.nsstring.deletingLastPathComponent)
        appEncryption.applyPasscode(passcode)
        if appEncryption.decrypt() != nil {
            self._doneValue.set(.single(true))
            self.close()
            
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
            laContext.evaluatePolicy(.applicationPolicy, localizedReason: strings().passcodeUnlockTouchIdReason) { (success, evaluateError) in
                if (success) {
                    Queue.mainQueue().async {
                        self._doneValue.set(.single(true))
                        self.close()
                    }
                }
            }
        }
    }
    
    override var cornerRadius: CGFloat {
        return 0
    }
    
    func invalidateTouchId() {
        laContext.invalidate()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.updateCurrectController()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        appearanceDisposable.set(appearanceSignal.start(next: { [weak self] appearance in
            self?.updateLocalizationAndTheme(theme: appearance.presentation)
        }))
        
        genericView.logoutImpl = { [weak self] in
            guard let window = self?.window else { return }
            
            confirm(for: window, information: strings().accountConfirmLogoutText, successHandler: { [weak self] _ in
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
                
        valueDisposable.set((genericView.value.get() |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.checkNextValue(value)
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
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.genericView.updateAndSetValue()
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
        disposable.dispose()
        logoutDisposable.dispose()
        valueDisposable.dispose()
        appearanceDisposable.dispose()
        self.window?.removeAllHandlers(for: self)
    }
    
    override func viewClass() -> AnyClass {
        return PasscodeLockView.self
    }
    
}

