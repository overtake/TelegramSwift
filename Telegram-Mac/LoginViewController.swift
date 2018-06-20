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
    init(sendCode:@escaping(String)->Void, resendCode:@escaping()->Void, editPhone:@escaping()->Void, checkCode:@escaping(String)->Void, checkPassword:@escaping(String)->Void) {
        self.sendCode = sendCode
        self.resendCode = resendCode
        self.editPhone = editPhone
        self.checkCode = checkCode
        self.checkPassword = checkPassword
    }
}

private class SignupView : View {
    let textView:TextView = TextView()
    let button:TitleButton = TitleButton()
    var arguments: LoginAuthViewArguments?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(button)
        
        button.set(font: .medium(.title), for: .Normal)
        button.set(color: .blueUI, for: .Normal)
        button.set(text: tr(L10n.alertOK), for: .Normal)
        
        _ = button.sizeToFit()
        
        button.set(handler: { [weak self] _ in
            self?.arguments?.editPhone()
        }, for: .Click)
        
        let layout = TextViewLayout(.initialize(string: tr(L10n.loginPhoneNumberNotRegistred), color: .text, font: .normal(.title)), alignment: .center)
        layout.measure(width: frameRect.width - 20)
        textView.update(layout)
    }
    
    override func layout() {
        super.layout()
        textView.layout?.measure(width: frame.width - 20)
        textView.update(textView.layout)
        textView.centerX(y: 30)
        button.centerX(y: textView.frame.maxY + 35)
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
        
        updateLocalizationAndTheme()
        
        addSubview(input)


        
        input.action = #selector(action)
        input.target = self
        
        addSubview(passwordLabel)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        let attr = NSMutableAttributedString()
        _ = attr.append(string: tr(L10n.loginPasswordPlaceholder), color: .grayText, font: .normal(.title))
        input.placeholderAttributedString = attr
        input.font = NSFont.normal(FontSize.text)
        input.textColor = .text
        input.sizeToFit()
        
        passwordLabel.attributedString = .initialize(string: tr(L10n.loginYourPasswordLabel), color: .grayText, font: .normal(FontSize.title))
        passwordLabel.sizeToFit()
    }
    
    @objc func action() {
        arguments?.checkPassword(self.input.stringValue)
    }
    
    
    

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(passwordLabel.frame.maxX + 20, frame.height - .borderSize, frame.width, .borderSize))
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
        editControl.set(color: .blueUI, for: .Normal)
        editControl.set(text: tr(L10n.navigationEdit), for: .Normal)
        _ = editControl.sizeToFit()
        
        editControl.set(handler: { [weak self] _ in
            self?.arguments?.editPhone()
        }, for: .Click)
        
        
        
        
        addSubview(yourPhoneLabel)
        addSubview(codeLabel)
        addSubview(editControl)
        
        
       
        
        
        codeText.textColor = .text
        codeText.font = NSFont.normal(.title)
        
        
        
        
        numberText.textColor = .grayText
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

    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        yourPhoneLabel.attributedString = .initialize(string: tr(L10n.loginYourPhoneLabel), color: .grayText, font: NSFont.normal(FontSize.title))
        yourPhoneLabel.sizeToFit()
        
        codeLabel.attributedString = .initialize(string: tr(L10n.loginYourCodeLabel), color: .grayText, font: NSFont.normal(FontSize.title))
        codeLabel.sizeToFit()
        numberText.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.loginPhoneFieldPlaceholder), color: .grayText, font: NSFont.normal(.header), coreText: false)
        
        codeText.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.loginCodePlaceholder), color: .grayText, font: NSFont.normal(.header), coreText: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let defaultInset:CGFloat = 30

    
    fileprivate override func layout() {
        super.layout()
        codeText.sizeToFit()
        numberText.sizeToFit()
        
        
        let maxInset = max(yourPhoneLabel.frame.width, codeLabel.frame.width)
        let contentInset = maxInset + 20 + 5 + defaultInset
        
        yourPhoneLabel.setFrameOrigin(maxInset - yourPhoneLabel.frame.width + defaultInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 25 - yourPhoneLabel.frame.height/2))
        codeLabel.setFrameOrigin(maxInset - codeLabel.frame.width + defaultInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 75 - codeLabel.frame.height/2))
        
        codeText.setFrameOrigin(contentInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 75 - codeText.frame.height/2))
        
        numberText.setFrameOrigin(contentInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 25 - yourPhoneLabel.frame.height/2))
        editControl.setFrameOrigin(frame.width - editControl.frame.width, floorToScreenPixels(scaleFactor: backingScaleFactor, 25 - yourPhoneLabel.frame.height/2))
        
        
        textView.centerX(y: codeText.frame.maxY + 60 + (passwordEnabled ? inputPassword.frame.height : 0))
        delayView.centerX(y: textView.frame.maxY + 20)
        errorLabel.centerX(y: codeText.frame.maxY + 30 + (passwordEnabled ? inputPassword.frame.height : 0))
        
        inputPassword.passwordLabel.centerY()
        inputPassword.passwordLabel.setFrameOrigin(contentInset - inputPassword.passwordLabel.frame.width - 25, inputPassword.passwordLabel.frame.minY)
        inputPassword.input.setFrameSize(inputPassword.frame.width - inputPassword.passwordLabel.frame.minX, inputPassword.input.frame.height)
        inputPassword.input.centerY(x:inputPassword.passwordLabel.frame.maxX + 25)

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
            basic = tr(L10n.loginEnterCodeFromApp)
            nextText = tr(L10n.loginSendSmsIfNotReceivedAppCode)
        case let .sms(length: length):
            codeLength = Int(length)
            basic = tr(L10n.loginJustSentSms)
        case let .call(length: length):
            codeLength = Int(length)
            basic = tr(L10n.loginPhoneCalledCode)
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
                        nextText = tr(L10n.loginWillCall(minutes, secValue))
                        break
                    case .sms:
                        nextText = tr(L10n.loginWillSendSms(minutes, secValue))
                        break
                    default:
                        break
                    }
                } else {
                    switch nextType {
                    case .call:
                        basic = tr(L10n.loginPhoneCalledCode)
                        nextText = tr(L10n.loginPhoneDialed)
                        break
                    default:
                        break
                    }
                }
                
            } else {
                nextText = tr(L10n.loginSendSmsIfNotReceivedAppCode)
            }
        }
        
        _ = attr.append(string: basic, color: .grayText, font: .normal(.title))
        let textLayout = TextViewLayout(attr, alignment: .center)
        textLayout.measure(width: 300)
        textView.update(textLayout)
        
        
        if !nextText.isEmpty {
            let attr = NSMutableAttributedString()
            
            if case .otherSession = type  {
                _ = attr.append(string: nextText, color: .link , font: .normal(.title))
                attr.add(link: inAppLink.callback("resend", { [weak self] link in
                    self?.arguments?.resendCode()
                }), for: attr.range)
                if  timeout == nil {
                    attr.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: attr.range)
                } else if let timeout = timeout {
                    attr.addAttribute(NSAttributedStringKey.foregroundColor, value: timeout <= 0 ? theme.colors.link : theme.colors.grayText, range: attr.range)
                }
            } else {
                _ = attr.append(string: nextText, color: .grayText, font: .normal(.title))
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
        self.numberText.stringValue = number
        self.codeText.textColor = .text
        self.codeText.stringValue = ""
        self.codeText.isEditable = true
        self.codeText.isSelectable = true
        inputPassword.isHidden = true
        self.update(with: type, nextType: nextType, timeout: timeout)
    }
    
    func setError(_ error: AuthorizationCodeVerificationError) {
        let textError:String
        switch error {
        case .limitExceeded:
            textError = tr(L10n.loginFloodWait)
        case .invalidCode:
            textError = tr(L10n.phoneCodeInvalid)
        case .generic:
            textError = tr(L10n.phoneCodeExpired)
        }
        errorLabel.state.set(.single(.error(textError)))
        codeText.shake()
    }
    
    func setPasswordError(_ error: AuthorizationPasswordVerificationError) {
        let text:String
        switch error {
        case .invalidPassword:
            text = tr(L10n.passwordHashInvalid)
        case .limitExceeded:
            text = tr(L10n.loginFloodWait)
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
            self.inputPassword.input.placeholderAttributedString = NSAttributedString.initialize(string: hint, color: .grayText, font: .normal(.title))
        } else {
            self.inputPassword.input.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.loginPasswordPlaceholder), color: .grayText, font: .normal(.title))
        }
        self.inputPassword.isHidden = false
        self.codeText.textColor = .grayText
        self.codeText.isEditable = false
        self.codeText.isSelectable = false
        
        let textLayout = TextViewLayout(.initialize(string: tr(L10n.loginEnterPasswordDescription), color: .grayText, font: .normal(.title)), alignment: .center)
        textLayout.measure(width: 300)
        textView.update(textLayout)
        
        disposable.set(nil)
        delayView.isHidden = true
        
        inputPassword.layer?.opacity = 0
        inputPassword.change(opacity: 1, animated: animated)
        
        textView.centerX()
        textView.change(pos: NSMakePoint(textView.frame.minX, textView.frame.minY + inputPassword.frame.height), animated: animated)
        
        needsLayout = true
    }
    
    override func controlTextDidChange(_ obj: Notification) {
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
        
        
        let maxInset = max(yourPhoneLabel.frame.width, codeLabel.frame.width) + 20
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(defaultInset + maxInset, 50, frame.width - maxInset, .borderSize))
        ctx.fill(NSMakeRect(defaultInset + maxInset, 100, frame.width - maxInset, .borderSize))
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
        
        
        countrySelector.style = ControlStyle(font: NSFont.medium(.title), foregroundColor: NSColor(0x007ee5), backgroundColor:.white)
        countrySelector.set(text: "France", for: .Normal)
        _ = countrySelector.sizeToFit()
        addSubview(countrySelector)
        
       
        
        
        addSubview(countryLabel)
        addSubview(numberLabel)
        
        countrySelector.set(handler: { [weak self] _ in
            self?.showCountrySelector()
        }, for: .Click)
        
        updateLocalizationAndTheme()
        
        codeText.stringValue = "+"
        
        codeText.textColor = .text
        codeText.font = NSFont.normal(.title)
        
        numberText.textColor = .text
        numberText.font = NSFont.normal(.title)
        
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
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        countryLabel.attributedString = .initialize(string: tr(L10n.loginCountryLabel), color: .grayText, font: NSFont.normal(FontSize.title))
        countryLabel.sizeToFit()
        
        numberLabel.attributedString = .initialize(string: tr(L10n.loginYourPhoneLabel), color: .grayText, font: NSFont.normal(FontSize.title))
        numberLabel.sizeToFit()
        
        numberText.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.loginPhoneFieldPlaceholder), color: .grayText, font: NSFont.normal(.header), coreText: false)
        
        needsLayout = true
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
        
        let maxInset = max(countryLabel.frame.width,numberLabel.frame.width)
        let contentInset = maxInset + 20 + 5
        countrySelector.setFrameOrigin(contentInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 25 - countrySelector.frame.height/2))
        
        countryLabel.setFrameOrigin(maxInset - countryLabel.frame.width, floorToScreenPixels(scaleFactor: backingScaleFactor, 25 - countryLabel.frame.height/2))
        numberLabel.setFrameOrigin(maxInset - numberLabel.frame.width, floorToScreenPixels(scaleFactor: backingScaleFactor, 75 - numberLabel.frame.height/2))
        
        codeText.setFrameOrigin(contentInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 75 - codeText.frame.height/2))
        numberText.setFrameOrigin(contentInset + separatorInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 75 - codeText.frame.height/2))
        errorLabel.centerX(y: 120)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        
        let maxInset = max(countryLabel.frame.width,numberLabel.frame.width) + 20
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(maxInset, 50, frame.width - maxInset, .borderSize))
        ctx.fill(NSMakeRect(maxInset, 100, frame.width - maxInset, .borderSize))
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
    
    override func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            hasChanges = true

            let code = codeText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let dec = code.prefix(4)
            
            if field == codeText {
                
                
                if code.length > 4 {
                    let list = Array(code.characters).map {String($0)}
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

class LoginAuthInfoView : View {

    fileprivate var state: UnauthorizedAccountStateContents = .empty
    
    private let phoneNumberContainer:PhoneNumberContainerView
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
        signupView = SignupView(frame: frameRect)
        super.init(frame:frameRect)
        
        addSubview(codeInputContainer)
        addSubview(phoneNumberContainer)
        addSubview(signupView)
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
        default:
            return nil
        }
    }
    
    func updateState(_ state:UnauthorizedAccountStateContents, animated: Bool) {
        self.state = state
        
        switch state {
        case let .phoneEntry(countryCode, phoneNumber):
            phoneNumberContainer.updateLocalizationAndTheme()
            phoneNumberContainer.errorLabel.state.set(.single(.normal))
            phoneNumberContainer.update(countryCode: countryCode, number: phoneNumber)
            phoneNumberContainer.isHidden = false
            
            phoneNumberContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.codeInputContainer.isHidden = true
                    self?.signupView.isHidden = true
                }
            })
            codeInputContainer.change(opacity: 0, animated: animated)
        case .empty:
            phoneNumberContainer.updateLocalizationAndTheme()
            phoneNumberContainer.isHidden = false
            phoneNumberContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.codeInputContainer.isHidden = true
                    self?.signupView.isHidden = true
                }
            })
        case let .confirmationCodeEntry(number, type, hash, timeout, nextType, terms):
            codeInputContainer.updateLocalizationAndTheme()
            codeInputContainer.isHidden = false
            codeInputContainer.undo = []
            codeInputContainer.update(number: number, type: type, hash: hash, timeout: timeout, nextType: nextType, animated: animated)
            phoneNumberContainer.change(opacity: 0, animated: animated)
            signupView.change(opacity: 0, animated: animated)
            
            if let terms = terms {
                terms
            }

            codeInputContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.phoneNumberContainer.isHidden = true
                    self?.signupView.isHidden = true
                }
            })
        case let .passwordEntry(hint, number, code):
            codeInputContainer.updateLocalizationAndTheme()
            codeInputContainer.isHidden = false
            codeInputContainer.showPasswordInput(hint, number ?? "", code ?? "", animated: animated)
            phoneNumberContainer.change(opacity: 0, animated: animated)
            signupView.change(opacity: 0, animated: animated)

            codeInputContainer.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.phoneNumberContainer.isHidden = true
                    self?.signupView.isHidden = true

                }
            })
        case .signUp:
            signupView.updateLocalizationAndTheme()
            signupView.isHidden = false
            phoneNumberContainer.change(opacity: 0, animated: animated)
            codeInputContainer.change(opacity: 0, animated: animated)
            
            signupView.change(opacity: 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.phoneNumberContainer.isHidden = true
                    self?.codeInputContainer.isHidden = true
                }
            })
        case .passwordRecovery(let hint, let number, let code, let emailPattern):
            //TODO
            break
        case .awaitingAccountReset(let protectedUntil, let number):
            //TODO
            break
        }
        window?.makeFirstResponder(firstResponder())
    }

    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        phoneNumberContainer.setFrameSize(newSize)
        codeInputContainer.setFrameSize(newSize)
        signupView.setFrameSize(newSize)
    }
    

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
}
