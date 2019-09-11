//
//  LoginViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 26/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
private let manager = CountryManager()

final class LoginAuthViewArguments {
    let sendCode:(String)->Void
    let resendCode:()->Void
    let editPhone:()->Void
    let checkCode:(String)->Void
    let checkPassword:(String)->Void
    let requestPasswordRecovery: (@escaping(PasswordRecoveryOption)-> Void)->Void
    let resetAccount: ()->Void
    let signUp:(String, String, URL?) -> Void
    init(sendCode:@escaping(String)->Void, resendCode:@escaping()->Void, editPhone:@escaping()->Void, checkCode:@escaping(String)->Void, checkPassword:@escaping(String)->Void, requestPasswordRecovery: @escaping(@escaping(PasswordRecoveryOption)-> Void)->Void, resetAccount: @escaping()->Void, signUp:@escaping(String, String, URL?) -> Void) {
        self.sendCode = sendCode
        self.resendCode = resendCode
        self.editPhone = editPhone
        self.checkCode = checkCode
        self.checkPassword = checkPassword
        self.requestPasswordRecovery = requestPasswordRecovery
        self.resetAccount = resetAccount
        self.signUp = signUp
    }
}

private class SignupView : View, NSTextFieldDelegate {
    
    let firstName:NSTextField = NSTextField()
    let lastName:NSTextField = NSTextField()
    
    private var photoUrl: URL?
    
    private let firstNameSeparator: View = View()
    private let lastNameSeparator: View = View()

    private let photoView = ImageView()
    private let descView: TextView = TextView()
    private let addPhotoView: TextView = TextView()
    var arguments: LoginAuthViewArguments?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(firstName)
        addSubview(lastName)
        addSubview(firstNameSeparator)
        addSubview(lastNameSeparator)
        addSubview(addPhotoView)
        addSubview(photoView)
        addSubview(descView)
        descView.userInteractionEnabled = false
        descView.isSelectable = false
        addPhotoView.userInteractionEnabled = false
        addPhotoView.isSelectable = false

        
        firstName.isBordered = false
        firstName.usesSingleLineMode = true
        firstName.isBezeled = false
        firstName.focusRingType = .none
        firstName.drawsBackground = false
        
        firstName.delegate = self
        lastName.delegate = self
        
        
        lastName.isBordered = false
        lastName.usesSingleLineMode = true
        lastName.isBezeled = false
        lastName.focusRingType = .none
        lastName.drawsBackground = false
        
        firstName.cell?.wraps = false
        firstName.cell?.isScrollable = true
        
        firstName.nextKeyView = lastName
        firstName.nextResponder = lastName.textView
       // lastName.nextKeyView = firstName
        
        lastName.cell?.wraps = false
        lastName.cell?.isScrollable = true
        
        lastName.font = .medium(14)
        firstName.font = .medium(14)
        
        photoView.layer?.cornerRadius = 50
        updateLocalizationAndTheme(theme: theme)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        
        if commandSelector == #selector(insertNewline(_:)) {
            trySignUp()
            return true
        }
        
        return false
    }
    
    func trySignUp() {
        if firstName.stringValue.isEmpty {
            firstName.shake()
            
            if firstName.textView != window?.firstResponder {
                window?.makeFirstResponder(firstName.textView)
            }
        } else {
            arguments?.signUp(firstName.stringValue, lastName.stringValue, self.photoUrl)
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        firstNameSeparator.backgroundColor = theme.colors.border
        lastNameSeparator.backgroundColor = theme.colors.border
        
        lastName.placeholderAttributedString = .initialize(string: L10n.loginRegisterLastNamePlaceholder, color: theme.colors.grayText, font: .medium(14))
        firstName.placeholderAttributedString = .initialize(string: L10n.loginRegisterFirstNamePlaceholder, color: theme.colors.grayText, font: .medium(14))

        lastName.textColor = theme.colors.text
        firstName.textColor = theme.colors.text

        let descLayout = TextViewLayout(.initialize(string: L10n.loginRegisterDesc, color: theme.colors.grayText, font: .normal(.text)))
        descLayout.measure(width: frame.width)
        descView.update(descLayout)
        
        let addPhotoLayout = TextViewLayout(.initialize(string: L10n.loginRegisterAddPhotoPlaceholder, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        addPhotoLayout.measure(width: 90)
        addPhotoView.update(addPhotoLayout)
        
        photoView.layer?.borderColor = theme.colors.border.cgColor
        photoView.layer?.borderWidth = 1.0

    
        needsLayout = true
    }
    
    override func mouseDown(with event: NSEvent) {
        if photoView._mouseInside() {
            
            let updatePhoto:(URL) -> Void = { [weak self] url in
                self?.photoView.image = NSImage.init(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                self?.photoUrl = url
            }
            
            filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: mainWindow, completion: { paths in
                if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                    _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                        let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                        showModal(with: controller, for: mainWindow)
                        _ = (controller.result |> deliverOnMainQueue).start(next: { url, _ in
                            updatePhoto(url)
                            //arguments.updatePhoto(url.path)
                        })
                        
                        controller.onClose = {
                            removeFile(at: path)
                        }
                    })
                }
            })
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func layout() {
        super.layout()
        
        photoView.frame = NSMakeRect(0, 0, 100, 100)
        
        addPhotoView.setFrameOrigin(NSMakePoint( floorToScreenPixels(backingScaleFactor, (photoView.frame.width - addPhotoView.frame.width) / 2), floorToScreenPixels(backingScaleFactor, (photoView.frame.height - addPhotoView.frame.height) / 2)))
        
        firstName.frame = NSMakeRect(photoView.frame.maxX + 10, 20, frame.width - (photoView.frame.maxX + 10), 20)
        lastName.frame = NSMakeRect(photoView.frame.maxX + 10, 70, frame.width - (photoView.frame.maxX + 10), 20)

        
        firstNameSeparator.frame = NSMakeRect(photoView.frame.maxX + 10, 50, frame.width, .borderSize)
        lastNameSeparator.frame = NSMakeRect(photoView.frame.maxX + 10, 100, frame.width, .borderSize)

        descView.centerX(y: photoView.frame.maxY + 50)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class InputPasswordContainerView : View {
    
    fileprivate var arguments: LoginAuthViewArguments?
    let input:NSSecureTextField = NSSecureTextField(frame: NSZeroRect)
    let passwordLabel:TextViewLabel = TextViewLabel()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        input.stringValue = ""
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        
        updateLocalizationAndTheme(theme: theme)
        
        addSubview(input)


        
        input.action = #selector(action)
        input.target = self
        
      //  addSubview(passwordLabel)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let attr = NSMutableAttributedString()
        _ = attr.append(string: L10n.loginPasswordPlaceholder, color: theme.colors.grayText, font: .normal(.title))
        input.backgroundColor = theme.colors.background
        input.placeholderAttributedString = attr
        input.font = .normal(.text)
        input.textColor = theme.colors.text
        input.sizeToFit()
        
        
        needsDisplay = true
        
        
    }
    
    @objc func action() {
        arguments?.checkPassword(self.input.stringValue)
    }
    
    
    

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

private class InputCodeContainerView : View, NSTextFieldDelegate {
    
    fileprivate var arguments:LoginAuthViewArguments?
    
    private let editControl:TitleButton = TitleButton()
    let yourPhoneLabel:TextViewLabel = TextViewLabel()
    let codeLabel:TextViewLabel = TextViewLabel()
    let errorLabel:LoginErrorStateView = LoginErrorStateView()
    
    let codeText:NSTextField = NSTextField()
    let numberText:NSTextField = NSTextField()
    
    let inputPassword:InputPasswordContainerView = InputPasswordContainerView(frame: NSZeroRect)
    
    let textView:TextView = TextView()
    let delayView:TextView = TextView()
    
    private let forgotPasswordView = TitleButton()
    private let resetAccountView = TitleButton()
    
    fileprivate var selectedItem:CountryItem?
    
    fileprivate var undo:[String] = []
    private let disposable = MetaDisposable()
    private let shakeDisposable = MetaDisposable()
    private var codeLength:Int = 5
    
    private var passwordEnabled: Bool = false

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        addSubview(inputPassword)
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        delayView.isSelectable = false
        
        editControl.set(font: .medium(.title), for: .Normal)
        editControl.set(color: theme.colors.accent, for: .Normal)
        editControl.set(text: tr(L10n.navigationEdit), for: .Normal)
        _ = editControl.sizeToFit()
        
        editControl.set(handler: { [weak self] _ in
            self?.arguments?.editPhone()
        }, for: .Click)
        
        
        
        
       // addSubview(yourPhoneLabel)
     //   addSubview(codeLabel)
        addSubview(editControl)
        
      
       

        
        
        codeText.font = NSFont.normal(.title)
        
        
        
        codeText.textColor = theme.colors.text
        numberText.textColor = theme.colors.grayText
        
        numberText.font = NSFont.normal(.title)
        numberText.isSelectable = false
        numberText.isEditable = false
        
        numberText.isBordered = false
        numberText.isBezeled = false
        numberText.focusRingType = .none
        
        
        codeText.isBordered = false
        codeText.isBezeled = false
        codeText.focusRingType = .none
        
        codeText.delegate = self
        codeText.nextResponder = numberText
        codeText.nextKeyView = numberText
        
        numberText.delegate = self
        numberText.nextResponder = codeText
        numberText.nextKeyView = codeText
        addSubview(codeText)
        addSubview(numberText)
        
        addSubview(textView)
        addSubview(delayView)
        addSubview(errorLabel)

        
        addSubview(forgotPasswordView)
        addSubview(resetAccountView)
        
        forgotPasswordView.isHidden = true
        resetAccountView.isHidden = true
        
        forgotPasswordView.set(font: .normal(.title), for: .Normal)
        resetAccountView.set(font: .normal(.title), for: .Normal)
        
       
        forgotPasswordView.set(handler: { [weak self]  _ in
            self?.arguments?.requestPasswordRecovery({ [weak self] option in
                switch option {
                case .email:
                    self?.resetAccountView.isHidden = false
                case .none:
                    alert(for: mainWindow, info: L10n.loginRecoveryMailFailed)
                    self?.resetAccountView.isHidden = false
                }
            })
        }, for: .Click)
        
        resetAccountView.set(handler: { [weak self] _ in
            self?.arguments?.resetAccount()
        }, for: .Click)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        editControl.set(color: theme.colors.accent, for: .Normal)
        
        
        codeText.textColor = theme.colors.text
        numberText.textColor = theme.colors.grayText
        
        yourPhoneLabel.backgroundColor = theme.colors.background
        numberText.backgroundColor = theme.colors.background
        codeText.backgroundColor = theme.colors.background
        
        
        errorLabel.backgroundColor = theme.colors.background
        delayView.backgroundColor = theme.colors.background
        textView.backgroundColor = theme.colors.background

        yourPhoneLabel.attributedString = .initialize(string: L10n.loginYourPhoneLabel, color: theme.colors.grayText, font: .normal(.title))
        yourPhoneLabel.sizeToFit()
        
        codeLabel.attributedString = .initialize(string: L10n.loginYourCodeLabel, color: theme.colors.grayText, font: .normal(.title))
        codeLabel.sizeToFit()
        
        numberText.placeholderAttributedString = .initialize(string: L10n.loginPhoneFieldPlaceholder, color: theme.colors.grayText, font: .normal(.header), coreText: false)
        codeText.placeholderAttributedString = .initialize(string: L10n.loginCodePlaceholder, color: theme.colors.grayText, font: .normal(.header), coreText: false)
        
        
        forgotPasswordView.set(color: theme.colors.accent, for: .Normal)
        resetAccountView.set(color: theme.colors.redUI, for: .Normal)
        
        forgotPasswordView.set(text: L10n.loginPasswordForgot, for: .Normal)
        resetAccountView.set(text: L10n.loginResetAccountText, for: .Normal)
        
        
        _ = forgotPasswordView.sizeToFit()
        _ = resetAccountView.sizeToFit()
        
       
        
        needsLayout = true
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    
    fileprivate override func layout() {
        super.layout()
        codeText.sizeToFit()
        numberText.sizeToFit()
        
        
        
        
        codeText.setFrameOrigin(0, floorToScreenPixels(backingScaleFactor, 75 - codeText.frame.height/2))
        
        numberText.setFrameOrigin(0, floorToScreenPixels(backingScaleFactor, 25 - yourPhoneLabel.frame.height/2))
        editControl.setFrameOrigin(frame.width - editControl.frame.width, floorToScreenPixels(backingScaleFactor, 25 - yourPhoneLabel.frame.height/2))
        
        
        textView.centerX(y: codeText.frame.maxY + 50 + (passwordEnabled ? inputPassword.frame.height : 0))
        delayView.centerX(y: textView.frame.maxY + 20)
        errorLabel.centerX(y: codeText.frame.maxY + 25 + (passwordEnabled ? inputPassword.frame.height : 0))
        
        forgotPasswordView.centerX(y: textView.frame.maxY + 10)
        resetAccountView.centerX(y: forgotPasswordView.frame.maxY + 5)
        
        inputPassword.input.setFrameSize(inputPassword.frame.width - inputPassword.passwordLabel.frame.minX, inputPassword.input.frame.height)
        inputPassword.input.centerY()

        inputPassword.setFrameOrigin(0, 101)
    }
    
    fileprivate func update(with type:SentAuthorizationCodeType, nextType:AuthorizationCodeNextType? = nil, timeout:Int32?) {
        
        if let nextType = nextType, let timeout = timeout {
            runNextTimer(type, nextType, timeout)
        }
        updateAfterTick(type, nextType, timeout)
        
    }
    
    func runNextTimer(_ type:SentAuthorizationCodeType, _ nextType:AuthorizationCodeNextType?, _ timeout:Int32) {
        disposable.set(countdown(Double(timeout), delay: 1).start(next: { [weak self] value in
            self?.updateAfterTick(type, nextType, Int32(value))
            }, completed: { [weak self] in
                self?.arguments?.resendCode()
        }))
        
    }
    
    func clean() {
        disposable.set(nil)
    }
    
    deinit {
        disposable.dispose()
        shakeDisposable.dispose()
    }
    
    func updateAfterTick(_ type:SentAuthorizationCodeType, _ nextType:AuthorizationCodeNextType?, _ timeout:Int32?) {
        
        let attr = NSMutableAttributedString()
        
        var basic:String = ""
        var nextText:String = ""
        
        
        switch type {
        case let .otherSession(length: length):
            codeLength = Int(length)
            basic = L10n.loginEnterCodeFromApp
            nextText = L10n.loginSendSmsIfNotReceivedAppCode
        case let .sms(length: length):
            codeLength = Int(length)
            basic = L10n.loginJustSentSms
        case let .call(length: length):
            codeLength = Int(length)
            basic = L10n.loginPhoneCalledCode
        default:
            break
        }
        
        
        
        if let nextType = nextType {
            if let timeout = timeout {
                let timeout = Int(timeout)
                let minutes = timeout / 60;
                let sec = timeout % 60;
                let secValue = sec > 9 ? "\(sec)" : "0\(sec)"
                if timeout > 0 {
                    switch nextType {
                    case .call:
                        nextText = L10n.loginWillCall(minutes, secValue)
                        break
                    case .sms:
                        nextText = L10n.loginWillSendSms(minutes, secValue)
                        break
                    default:
                        break
                    }
                } else {
                    switch nextType {
                    case .call:
                        basic = L10n.loginPhoneCalledCode
                        nextText = L10n.loginPhoneDialed
                        break
                    default:
                        break
                    }
                }
                
            } else {
                nextText = tr(L10n.loginSendSmsIfNotReceivedAppCode)
            }
        }
        
        _ = attr.append(string: basic, color: theme.colors.grayText, font: .normal(.title))
        let textLayout = TextViewLayout(attr, alignment: .center)
        textLayout.measure(width: 300)
        textView.update(textLayout)
        
        
        if !nextText.isEmpty {
            let attr = NSMutableAttributedString()
            
            if case .otherSession = type  {
                _ = attr.append(string: nextText, color: theme.colors.link , font: .normal(.title))
                attr.add(link: inAppLink.callback("resend", { [weak self] link in
                    self?.arguments?.resendCode()
                }), for: attr.range)
                if  timeout == nil {
                    attr.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.link, range: attr.range)
                } else if let timeout = timeout {
                    attr.addAttribute(NSAttributedString.Key.foregroundColor, value: timeout <= 0 ? theme.colors.link : theme.colors.grayText, range: attr.range)
                }
            } else {
                _ = attr.append(string: nextText, color: theme.colors.grayText, font: .normal(.title))
            }
            let layout = TextViewLayout(attr)
            layout.interactions = globalLinkExecutor
            layout.measure(width: frame.width - 40)
            delayView.update(layout)
        }
        delayView.isHidden = nextText.isEmpty
        
        needsLayout = true
    }

    func update(number: String, type: SentAuthorizationCodeType, hash: String, timeout: Int32?, nextType: AuthorizationCodeNextType?, animated: Bool) {
        self.passwordEnabled = false
        self.numberText.stringValue = formatPhoneNumber(number)
        self.codeText.stringValue = ""
        self.codeText.isEditable = true
        self.codeText.isSelectable = true
        inputPassword.isHidden = true
        forgotPasswordView.isHidden = true
        resetAccountView.isHidden = true
        clearError()
        self.update(with: type, nextType: nextType, timeout: timeout)
    }
    
    func setError(_ error: AuthorizationCodeVerificationError) {
        let textError:String
        switch error {
        case .limitExceeded:
            textError = L10n.loginFloodWait
        case .invalidCode:
            textError = L10n.phoneCodeInvalid
        case .generic:
            textError = L10n.phoneCodeExpired
        case .codeExpired:
            textError = L10n.phoneCodeExpired
        }
        errorLabel.state.set(.single(.error(textError)))
        codeText.shake()
    }
    
    func setPasswordError(_ error: AuthorizationPasswordVerificationError) {
        let text:String
        switch error {
        case .invalidPassword:
            text = L10n.passwordHashInvalid
        case .limitExceeded:
            text = L10n.loginFloodWait
        case .generic:
            text = "undefined error"
        }
        errorLabel.state.set(.single(.error(text)))
        inputPassword.input.shake()
    }
    
   
    
    func clearError() {
        errorLabel.state.set(.single(.normal))
    }
    
    func showPasswordInput(_ hint:String, _ number:String, _ code:String, animated: Bool) {
        errorLabel.state.set(.single(.normal))
        self.passwordEnabled = true
        self.numberText.stringValue = number
        self.codeText.stringValue = code
        if !hint.isEmpty {
            self.inputPassword.input.placeholderAttributedString = .initialize(string: hint, color: theme.colors.grayText, font: .normal(.title))
        } else {
            self.inputPassword.input.placeholderAttributedString = .initialize(string: L10n.loginPasswordPlaceholder, color: theme.colors.grayText, font: .normal(.title))
        }
        self.inputPassword.isHidden = false
        self.codeText.textColor = theme.colors.grayText
        self.codeText.isEditable = false
        self.codeText.isSelectable = false
        
        let textLayout = TextViewLayout(.initialize(string: L10n.loginEnterPasswordDescription, color: theme.colors.grayText, font: .normal(.title)), alignment: .center)
        textLayout.measure(width: 300)
        textView.update(textLayout)
        
        
        
        disposable.set(nil)
        delayView.isHidden = true
        
        inputPassword.layer?.opacity = 0
        inputPassword.change(opacity: 1, animated: animated)
        
        textView.centerX()
        textView.change(pos: NSMakePoint(textView.frame.minX, textView.frame.minY + inputPassword.frame.height), animated: animated)
        
        forgotPasswordView.isHidden = false
        
       
        
        needsLayout = true
    }
    
    func controlTextDidChange(_ obj: Notification) {
        let code = codeText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().prefix(codeLength)
        codeText.stringValue = code
        codeText.sizeToFit()
        if code.length == codeLength, undo.index(of: code) == nil {
            undo.append(code)
            arguments?.checkCode(code)
        }
        needsLayout = true
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(deleteBackward(_:)) {
            return false
        }
        return true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, 50, frame.width, .borderSize))
        ctx.fill(NSMakeRect(0, 100, frame.width, .borderSize))
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        inputPassword.setFrameSize(newSize.width, 50)
    }
    
    
}


private class PhoneNumberContainerView : View, NSTextFieldDelegate {
    
    fileprivate var arguments:LoginAuthViewArguments?

    
    private let countrySelector:TitleButton = TitleButton()
    
    let countryLabel:TextViewLabel = TextViewLabel()
    let numberLabel:TextViewLabel = TextViewLabel()
    
    fileprivate let errorLabel:LoginErrorStateView = LoginErrorStateView()
    
    let codeText:NSTextField = NSTextField()
    let numberText:NSTextField = NSTextField()
    
    fileprivate var selectedItem:CountryItem?

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        countrySelector.style = ControlStyle(font: .medium(.title), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background)
        countrySelector.set(text: "France", for: .Normal)
        _ = countrySelector.sizeToFit()
        addSubview(countrySelector)
        
       
        
       // addSubview(countryLabel)
       // addSubview(numberLabel)
        
        countrySelector.set(handler: { [weak self] _ in
            self?.showCountrySelector()
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
        
        codeText.stringValue = "+"
        
       
        
        codeText.font = .normal(.title)
        
        numberText.font = .normal(.title)
        
        numberText.isBordered = false
        numberText.isBezeled = false
        numberText.focusRingType = .none
        
        codeText.isBordered = false
        codeText.isBezeled = false
        codeText.focusRingType = .none
        
        codeText.delegate = self
        codeText.nextResponder = numberText
        codeText.nextKeyView = numberText
        
        numberText.delegate = self
        numberText.nextResponder = codeText
        numberText.nextKeyView = codeText
        addSubview(codeText)
        addSubview(numberText)
        
        errorLabel.layer?.opacity = 0
        addSubview(errorLabel)
        
        let code = NSLocale.current.regionCode ?? "US"
        update(selectedItem: manager.item(bySmallCountryName: code), update: true)
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        countrySelector.style = ControlStyle(font: .medium(.title), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background)
        
        
        codeText.backgroundColor = theme.colors.background
        numberText.backgroundColor = theme.colors.background
        
        countryLabel.attributedString = .initialize(string: L10n.loginCountryLabel, color: theme.colors.grayText, font: .normal(.title))
        countryLabel.sizeToFit()
        
        numberLabel.attributedString = .initialize(string: L10n.loginYourPhoneLabel, color: theme.colors.grayText, font: .normal(.title))
        numberLabel.sizeToFit()
        
        numberText.placeholderAttributedString = .initialize(string: L10n.loginPhoneFieldPlaceholder, color: theme.colors.grayText, font: .normal(.header), coreText: false)
        
        needsLayout = true
        needsDisplay = true
    }
    
    func setPhoneError(_ error: AuthorizationCodeRequestError) {
        let text:String
        switch error {
        case .invalidPhoneNumber:
            text = tr(L10n.phoneNumberInvalid)
        case .limitExceeded:
            text = tr(L10n.loginFloodWait)
        case .generic:
            text = "undefined error"
        case .phoneLimitExceeded:
            text = "undefined error"
        case .phoneBanned:
            text = "PHONE BANNED"
        case .timeout:
            text = "timeout"
        }
        errorLabel.state.set(.single(.error(text)))
    }
    
    func update(countryCode: Int32, number: String) {
        self.codeText.stringValue = "\(countryCode)"
        self.numberText.stringValue = formatPhoneNumber(number)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate override func layout() {
        super.layout()
        codeText.sizeToFit()
        numberText.sizeToFit()
        
      //  let maxInset: CGFloat = max(countryLabel.frame.width,numberLabel.frame.width)
      //  let contentInset = maxInset + 20 + 5
        countrySelector.setFrameOrigin(0, floorToScreenPixels(backingScaleFactor, 25 - countrySelector.frame.height/2))
        
     //  countryLabel.setFrameOrigin(maxInset - countryLabel.frame.width, floorToScreenPixels(backingScaleFactor, 25 - countryLabel.frame.height/2))
     //   numberLabel.setFrameOrigin(maxInset - numberLabel.frame.width, floorToScreenPixels(backingScaleFactor, 75 - numberLabel.frame.height/2))
        
        codeText.setFrameOrigin(0, floorToScreenPixels(backingScaleFactor, 75 - codeText.frame.height/2))
        numberText.setFrameOrigin(separatorInset, floorToScreenPixels(backingScaleFactor, 75 - codeText.frame.height/2))
        errorLabel.centerX(y: 110)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        
       // let maxInset = max(countryLabel.frame.width,numberLabel.frame.width) + 20
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, 50, frame.width, .borderSize))
        ctx.fill(NSMakeRect(0, 100, frame.width, .borderSize))
        //  ctx.fill(NSMakeRect(maxInset + separatorInset, 50, .borderSize, 50))
    }
    
    
    func showCountrySelector() {
        
        var items:[ContextMenuItem] = []
        for country in manager.countries {
            let item = ContextMenuItem(country.fullName, handler: { [weak self] in
                self?.update(selectedItem: country, update: true)
            })
            items.append(item)
        }
        if let currentEvent = NSApp.currentEvent {
            ContextMenu.show(items: items, view: countrySelector, event: currentEvent, onShow: {(menu) in
                
            }, onClose: {})
        }
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            hasChanges = true

            let code = codeText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let dec = code.prefix(4)
            
            if field == codeText {
                
                
                if code.length > 4 {
                    let list = code.map {String($0)}
                    let reduced = list.reduce([], { current, value -> [String] in
                        var current = current
                        current.append((current.last ?? "") + value)
                        return current
                    }).map({Int($0)}).filter({$0 != nil}).map({$0!})
                    
                    var found: Bool = false
                    for _code in reduced {
                        if let item = manager.item(byCodeNumber: _code) {
                            codeText.stringValue = "+" + String(_code)
                            update(selectedItem: item, update: true, updateCode: false)
                            
                            var formated = formatPhoneNumber(String(_code) + code.substring(from: String(_code).endIndex) + numberText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
                            
                            if formated.hasPrefix("+") {
                                formated = formated.fromSuffix(2)
                            }
                            formated = formated.substring(from: String(_code).endIndex).prefix(17)
                            numberText.stringValue = formated
                            window?.makeFirstResponder(numberText)
                            numberText.setCursorToEnd()
                            found = true
                            break
                        }
                    }
                    
                    if !found {
                        update(selectedItem: nil, update: true, updateCode: false)
                    }
                } else {
                    codeText.stringValue = "+" + dec
                    
                    var item:CountryItem? = nil
                    if let code = Int(dec) {
                        item = manager.item(byCodeNumber: code)
                    }
                    update(selectedItem: item, update: true, updateCode:false)
                }
                
                
                
            } else if field == numberText {
                var formated = formatPhoneNumber(dec + numberText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
                if formated.hasPrefix("+") {
                    formated = formated.fromSuffix(2)
                }
                formated = formated.substring(from: dec.endIndex).prefix(17)
                numberText.stringValue = formated
            }
            
        }
        needsLayout = true
        setNeedsDisplayLayer()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            if control == codeText {
                self.window?.makeFirstResponder(self.numberText)
                self.numberText.selectText(nil)
            } else if !numberText.stringValue.isEmpty {
                arguments?.sendCode(codeText.stringValue + numberText.stringValue)
            }
            //Queue.mainQueue().justDispatch {
            (control as? NSTextField)?.setCursorToEnd()
            //}
            return true
        } else if commandSelector == #selector(deleteBackward(_:)) {
            if control == numberText {
                if numberText.stringValue.isEmpty {
                    Queue.mainQueue().justDispatch {
                        self.window?.makeFirstResponder(self.codeText)
                        self.codeText.setCursorToEnd()
                    }
                }
            }
            return false
            
        }
        return false
    }
    
    fileprivate var hasChanges: Bool = false
    
    func update(selectedItem:CountryItem?, update:Bool, updateCode:Bool = true) -> Void {
        self.selectedItem = selectedItem
        if update {
            countrySelector.set(text: selectedItem?.shortName ?? tr(L10n.loginInvalidCountryCode), for: .Normal)
            countrySelector.sizeToFit()
            if updateCode {
                codeText.stringValue = selectedItem != nil ? "+\(selectedItem!.code)" : "+"
            }
            needsLayout = true
            setNeedsDisplayLayer()
            
        }
    }
    
  
    
    var separatorInset:CGFloat {
        return codeText.frame.width + 10
    }
    
}


private func timerValueString(days: Int32, hours: Int32, minutes: Int32) -> String {
    var string = NSMutableAttributedString()
    
    var daysString = ""
    if days > 0 {
        daysString = "**" + L10n.timerDaysCountable(Int(days)) + "** "
    }
    
    var hoursString = ""
    if hours > 0 || days > 0 {
        hoursString = "**" + L10n.timerHoursCountable(Int(hours)) + "** "
    }
    
    let minutesString = "**" + L10n.timerMinutesCountable(Int(minutes)) + "**"
    
    return daysString + hoursString + minutesString
}

private final class AwaitingResetConfirmationView : View {
    private let textView: TextView = TextView()
    private let reset: TitleButton = TitleButton()
    private var phoneNumber: String = ""
    private var protectedUntil: Int32 = 0
    private var timer: SwiftSignalKitMac.Timer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.isSelectable = false
        addSubview(textView)
        addSubview(reset)
        
        reset.set(font: .bold(.title), for: .Normal)
    }
    
    func update(with phoneNumber: String, until:Int32, reset: @escaping()-> Void) -> Void {
        self.phoneNumber = phoneNumber
        self.protectedUntil = until
        updateLocalizationAndTheme(theme: theme)
        
        self.reset.removeAllHandlers()
        self.reset.set(handler: { _ in
            reset()
        }, for: .Click)
        
        if self.timer == nil {
            let timer = SwiftSignalKitMac.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                self?.updateTimerValue()
                }, queue: Queue.mainQueue())
            self.timer = timer
            timer.start()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        reset.set(color: theme.colors.redUI, for: .Normal)
        reset.set(text: L10n.loginResetAccount, for: .Normal)
        _ = reset.sizeToFit()
        updateTimerValue()
    }
    
    private func updateTimerValue() {
        let timerSeconds = max(0, self.protectedUntil - Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970))
        
        let secondsInAMinute: Int32 = 60
        let secondsInAnHour: Int32 = 60 * secondsInAMinute
        let secondsInADay: Int32 = 24 * secondsInAnHour
        
        let days = timerSeconds / secondsInADay
        
        let hourSeconds = timerSeconds % secondsInADay
        let hours = hourSeconds / secondsInAnHour
        
        let minuteSeconds = hourSeconds % secondsInAnHour
        var minutes = minuteSeconds / secondsInAMinute
        
        if days == 0 && hours == 0 && minutes == 0 && timerSeconds > 0 {
            minutes = 1
        }
        
        
        let attr = NSMutableAttributedString()
        
        
        _ = attr.append(string: L10n.twoStepAuthResetDescription(self.phoneNumber, timerValueString(days: days, hours: hours, minutes: minutes)), color: theme.colors.grayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .bold(.text))
        
        let layout = TextViewLayout(attr, alignment: .left, alwaysStaticItems: true)
        layout.measure(width: frame.width)
        
        textView.update(layout)
        needsLayout = true
        
        self.reset.isEnabled = timerSeconds <= 0
        
        if timerSeconds <= 0 {
            timer?.invalidate()
            timer = nil
        }
        
    }
    
    override func layout() {
        super.layout()
        textView.centerX()
        reset.setFrameOrigin(0, textView.frame.maxY + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class LoginAuthInfoView : View {

    fileprivate var state: UnauthorizedAccountStateContents = .empty
    
    private let phoneNumberContainer:PhoneNumberContainerView
    private let resetAccountContainer:AwaitingResetConfirmationView

    private let codeInputContainer:InputCodeContainerView
    private let signupView:SignupView
    var arguments:LoginAuthViewArguments? {
        didSet {
            phoneNumberContainer.arguments = arguments
            codeInputContainer.arguments = arguments
            codeInputContainer.inputPassword.arguments = arguments
            signupView.arguments = arguments
        }
    }
    
    var phoneNumber:String {
        return phoneNumberContainer.codeText.stringValue + phoneNumberContainer.numberText.stringValue
    }
    func trySignUp() {
        signupView.trySignUp()
    }
   
    var code:String {
        return codeInputContainer.codeText.stringValue
    }
    
    var password:String {
        return codeInputContainer.inputPassword.input.stringValue
    }
    
    func updateCodeError(_ error:AuthorizationCodeVerificationError) {
        codeInputContainer.setError(error)
    }
    
    func updatePasswordError(_ error: AuthorizationPasswordVerificationError) {
        codeInputContainer.setPasswordError(error)
    }
    
    func updatePhoneError(_ error:AuthorizationCodeRequestError) {
        phoneNumberContainer.setPhoneError(error)
    }
    
    required init(frame frameRect: NSRect) {
        codeInputContainer = InputCodeContainerView(frame: frameRect)
        phoneNumberContainer = PhoneNumberContainerView(frame: frameRect)
        resetAccountContainer = AwaitingResetConfirmationView(frame: frameRect)
        signupView = SignupView(frame: frameRect)
        super.init(frame:frameRect)
        
        addSubview(codeInputContainer)
        addSubview(phoneNumberContainer)
        addSubview(signupView)
        addSubview(resetAccountContainer)
    }
    
    func updateCountryCode(_ code: String) {
        if !phoneNumberContainer.hasChanges {
            phoneNumberContainer.update(selectedItem: manager.item(bySmallCountryName: code), update: true)
        }
    }
    

    func firstResponder() -> NSResponder? {
        switch state {
        case .phoneEntry, .empty:
            if window?.firstResponder != phoneNumberContainer.numberText.textView || window?.firstResponder != phoneNumberContainer.codeText.textView {
                if phoneNumberContainer.codeText.stringValue.isEmpty {
                    return phoneNumberContainer.codeText
                }
                return phoneNumberContainer.numberText
            }
            return window?.firstResponder
        case .confirmationCodeEntry:
            return codeInputContainer.codeText
        case .passwordEntry:
            if window?.firstResponder != codeInputContainer.inputPassword.input.textView || window?.firstResponder != codeInputContainer.inputPassword.input.textView {
                
                return codeInputContainer.inputPassword.input
            }
            return window?.firstResponder
        case .signUp:
            if window?.firstResponder != signupView.firstName.textView || window?.firstResponder != signupView.lastName.textView {
                return signupView.firstName
            }
            return window?.firstResponder
        default:
            return nil
        }
    }
    
    func updateState(_ state:UnauthorizedAccountStateContents, animated: Bool) {
        self.state = state
        
        switch state {
        case let .phoneEntry(countryCode, phoneNumber):
            phoneNumberContainer.updateLocalizationAndTheme(theme: theme)
            phoneNumberContainer.errorLabel.state.set(.single(.normal))
            phoneNumberContainer.update(countryCode: countryCode, number: phoneNumber)
            phoneNumberContainer.isHidden = false
            
            phoneNumberContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.codeInputContainer.isHidden = true
                    self?.signupView.isHidden = true
                    self?.resetAccountContainer.isHidden = true
                }
            })
            codeInputContainer.change(opacity: 0, animated: animated)
            resetAccountContainer.change(opacity: 0, animated: animated)
            signupView.change(opacity: 0, animated: animated)
        case .empty:
            phoneNumberContainer.updateLocalizationAndTheme(theme: theme)
            phoneNumberContainer.isHidden = false
            phoneNumberContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.codeInputContainer.isHidden = true
                    self?.signupView.isHidden = true
                    self?.resetAccountContainer.isHidden = true
                }
            })
            codeInputContainer.change(opacity: 0, animated: animated)
            resetAccountContainer.change(opacity: 0, animated: animated)
            signupView.change(opacity: 0, animated: animated)

        case let .confirmationCodeEntry(number, type, hash, timeout, nextType, _):
            codeInputContainer.updateLocalizationAndTheme(theme: theme)
            codeInputContainer.isHidden = false
            codeInputContainer.undo = []
            codeInputContainer.update(number: number, type: type, hash: hash, timeout: timeout, nextType: nextType, animated: animated)
            phoneNumberContainer.change(opacity: 0, animated: animated)
            signupView.change(opacity: 0, animated: animated)
            resetAccountContainer.change(opacity: 0, animated: animated)



            codeInputContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.phoneNumberContainer.isHidden = true
                    self?.signupView.isHidden = true
                    self?.resetAccountContainer.isHidden = true
                }
            })
        case let .passwordEntry(hint, number, code, _, _):
            codeInputContainer.updateLocalizationAndTheme(theme: theme)
            codeInputContainer.isHidden = false
            codeInputContainer.showPasswordInput(hint, number ?? "", code ?? "", animated: animated)
            phoneNumberContainer.change(opacity: 0, animated: animated)
            signupView.change(opacity: 0, animated: animated)
            resetAccountContainer.change(opacity: 0, animated: animated)

            codeInputContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.phoneNumberContainer.isHidden = true
                    self?.signupView.isHidden = true
                    self?.resetAccountContainer.isHidden = true

                }
            })
        case .signUp:
            signupView.updateLocalizationAndTheme(theme: theme)
            signupView.isHidden = false
            phoneNumberContainer.change(opacity: 0, animated: animated)
            codeInputContainer.change(opacity: 0, animated: animated)
            resetAccountContainer.change(opacity: 0, animated: animated)

            signupView.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.phoneNumberContainer.isHidden = true
                    self?.codeInputContainer.isHidden = true
                    self?.resetAccountContainer.isHidden = true
                }
            })
        case .passwordRecovery:
            //TODO
            break
        case .awaitingAccountReset(let protectedUntil, let number, _):
            resetAccountContainer.isHidden = false
            
            resetAccountContainer.update(with: number ?? "", until: protectedUntil, reset: { [weak self] in
                self?.arguments?.resetAccount()
            })
            resetAccountContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.signupView.isHidden = true
                    self?.phoneNumberContainer.isHidden = true
                    self?.codeInputContainer.isHidden = true
                }
            })
            phoneNumberContainer.change(opacity: 0, animated: animated)
            codeInputContainer.change(opacity: 0, animated: animated)
            signupView.change(opacity: 0, animated: animated)
        }
        window?.makeFirstResponder(firstResponder())
    }

    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        phoneNumberContainer.setFrameSize(newSize)
        codeInputContainer.setFrameSize(newSize)
        signupView.setFrameSize(newSize)
        resetAccountContainer.setFrameSize(newSize)
        
        phoneNumberContainer.centerX()
        codeInputContainer.centerX()
        signupView.centerX()
        resetAccountContainer.centerX()
    }
    

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
}
