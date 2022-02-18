//
//  Auth_PasswordEntry.swift
//  Telegram
//
//  Created by Mike Renoir on 15.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit
import TelegramCore

private final class Auth_PasswordEntryHeaderView : View {
    private let playerView:LottiePlayerView = LottiePlayerView()
    private let header: TextView = TextView()
    private let desc: TextView = TextView()
    private var descAttr: NSAttributedString?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(playerView)
        addSubview(header)
        addSubview(desc)
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        desc.userInteractionEnabled = false
        desc.isSelectable = false
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        if let data = LocalAnimatedSticker.keychain.data {
            self.playerView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("keychain"), size: Auth_Insets.logoSize, backingScale: Int(System.backingScale), fitzModifier: nil, colors: []), playPolicy: .onceEnd))
        }
        
        let layout = TextViewLayout(.initialize(string: strings().loginNewPasswordLabel, color: theme.colors.text, font: Auth_Insets.headerFont))
        layout.measure(width: frame.width)
        self.header.update(layout)
        
        let descAttr: NSAttributedString = .initialize(string: strings().loginNewPasswordInfo, color: theme.colors.grayText, font: Auth_Insets.infoFont)
        
        let descLayout = TextViewLayout(descAttr, alignment: .center)
        descLayout.measure(width: frame.width)
        self.desc.update(descLayout)
        
        self.layout()
    }
    
    override func layout() {
        super.layout()
        self.playerView.setFrameSize(Auth_Insets.logoSize)
        self.playerView.centerX(y: 0)
        self.header.centerX(y: self.playerView.frame.maxY + 20)
        self.desc.centerX(y: self.header.frame.maxY + 10)

    }
    
    var height: CGFloat {
        return self.desc.frame.maxY
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func playAnimation() {
        playerView.playAgain()
    }
}

private final class Auth_PasswordEntryInputView : View, NSTextFieldDelegate {
    private let secureField: NSSecureTextField = NSSecureTextField()
    private var hint: String?
    private var takeError: (()->Void)?
    private var invoke:(()->Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(secureField)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        background = theme.colors.grayBackground
        layer?.cornerRadius = 10
        
        secureField.font = .normal(.title)
        secureField.textColor = theme.colors.text
        secureField.drawsBackground = false
        secureField.backgroundColor = .clear
        secureField.focusRingType = .none
        secureField.isBordered = false
        secureField.usesSingleLineMode = true
        secureField.isBezeled = false
        secureField.delegate = self
        
        let hint = self.hint ?? ""
        
        secureField.placeholderAttributedString = .initialize(string: hint.isEmpty ? strings().loginNewPasswordPlaceholder : hint, color: theme.colors.grayText, font: .normal(.text))
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            self.invoke?()
            return true
        }
        return false
    }
    
    func controlTextDidChange(_ obj: Notification) {
        self.takeError?()
    }
    
    func update(locked: Bool, hint: String?, invoke: @escaping()->Void, takeError:@escaping()->Void) {
        self.hint = hint
        self.invoke = invoke
        self.takeError = takeError
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func layout() {
        super.layout()
        secureField.frame = NSMakeRect(10, 10, frame.width - 20, 18)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func firstResponder() -> NSResponder? {
        return secureField
    }
    var value: String {
        return self.secureField.stringValue
    }
}

final class Auth_PasswordEntryView: View {
    private let container: View = View()
    private let header:Auth_PasswordEntryHeaderView
    private let input:Auth_PasswordEntryInputView
    private let nextView = Auth_NextView()
    private let error: LoginErrorStateView = LoginErrorStateView()
    private let forgot: TextView = TextView()
    private var locked: Bool = false
    private var takeReset: Bool = false {
        didSet {
            updateLocalizationAndTheme(theme: theme)
        }
    }
    
    private var takeNext:((String)->Void)?
    private var takeForgot:((Bool, @escaping()->Void)->Void)?
    required init(frame frameRect: NSRect) {
        header = Auth_PasswordEntryHeaderView(frame: frameRect.size.bounds)
        input = Auth_PasswordEntryInputView(frame: NSMakeRect(0, 0, 280, 40))
        super.init(frame: frameRect)
        container.addSubview(header)
        container.addSubview(input)
        container.addSubview(nextView)
        container.addSubview(error)
        container.addSubview(forgot)

        forgot.isSelectable = false
        addSubview(container)
        nextView.set(handler: { [weak self] _ in
            self?.invoke()
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        nextView.updateLocalizationAndTheme(theme: theme)
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: takeReset ? strings().loginResetAccountText : strings().loginPasswordForgot, color: takeReset ? theme.colors.redUI : theme.colors.accent, font: .normal(.title))
        attr.addAttribute(.link, value: inAppLink.callback("", { [weak self] _ in
            guard let takeReset = self?.takeReset else {
                return
            }
            self?.takeForgot?(takeReset, { [weak self] in
                self?.takeReset = true
            })
        }), range: attr.range)
        let layout = TextViewLayout(attr)
        layout.measure(width: .greatestFiniteMagnitude)
        layout.interactions = globalLinkExecutor
        forgot.update(layout)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        container.setFrameSize(NSMakeSize(frame.width, header.height + Auth_Insets.betweenHeader + input.frame.height + Auth_Insets.betweenNextView + Auth_Insets.nextHeight + Auth_Insets.betweenHeader + forgot.frame.height))
        
        header.setFrameSize(NSMakeSize(frame.width, header.height))
        header.centerX(y: 0)
        input.centerX(y: header.frame.maxY + Auth_Insets.betweenHeader)
        error.centerX(y: input.frame.maxY + Auth_Insets.betweenError)
        nextView.centerX(y: input.frame.maxY + Auth_Insets.betweenNextView)
        forgot.centerX(y: nextView.frame.maxY + Auth_Insets.betweenHeader)
        container.center()
        
    }
    
    func invoke() {
        if !self.input.value.isEmpty, !locked {
            self.takeNext?(self.input.value)
        }
    }
    
    func firstResponder() -> NSResponder? {
        return input.firstResponder()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func update(locked: Bool, error: AuthorizationPasswordVerificationError?, hint: String?, takeNext: @escaping(String)->Void, takeError:@escaping()->Void, takeForgot:@escaping(Bool, @escaping()->Void)->Void) {
        self.input.update(locked: locked, hint: hint, invoke: { [weak self] in
            self?.invoke()
        }, takeError: takeError)
        self.takeNext = takeNext
        self.takeForgot = takeForgot
        self.locked = locked
        nextView.updateLocked(locked)
        if let error = error {
            let text:String
            switch error {
            case .invalidPassword:
                text = strings().passwordHashInvalid
            case .limitExceeded:
                text = strings().loginFloodWait
            case .generic:
                text = "undefined error"
            }
            self.error.state.set(.error(text))
            self.input.shake(beep: true)
        } else {
            self.error.state.set(.normal)
        }
        needsLayout = true
    }
    
    func playAnimation() {
        header.playAnimation()
    }
}

final class Auth_PasswordEntryController : GenericViewController<Auth_PasswordEntryView> {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    func update(locked: Bool, error: AuthorizationPasswordVerificationError?, hint: String?, takeNext: @escaping(String)->Void, takeError:@escaping()->Void, takeForgot:@escaping(Bool, @escaping()->Void)->Void) {
        self.genericView.update(locked: locked, error: error, hint: hint, takeNext: takeNext, takeError: takeError, takeForgot: takeForgot)
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.firstResponder()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if animated {
            genericView.playAnimation()
        }
    }
}
