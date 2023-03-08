//
//  PhoneNumberConfirmCodeController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.03.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit


final class PhoneNumberCodeConfirmView : View {
    private let desc = TextView()
    fileprivate let input: Auth_CodeEntryContol = Auth_CodeEntryContol(frame: .zero)
    fileprivate let next = TitleButton()
    
    private var aboutString: String = strings().phoneNumberCodeInfo
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(input)
        addSubview(desc)
        addSubview(next)
        
        next.autohighlight = false
        next.scaleOnClick = true
        
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    func update(with count: Int, locked: Bool, aboutString: String, takeNext: @escaping(String)->Void, takeError: @escaping()->Void) {
        let size = self.input.update(count: count)
        self.aboutString = aboutString
        self.input.setFrameSize(size)
        self.input.takeNext = takeNext
        self.input.takeError = takeError
        self.input.set(locked: locked, animated: true)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        next.set(color: theme.colors.underSelectedColor, for: .Normal)
        next.set(background: theme.colors.accent, for: .Normal)
        next.set(font: .medium(.text), for: .Normal)
        next.set(text: strings().phoneNumberChangePhoneNumber, for: .Normal)
        next.sizeToFit()
        next.layer?.cornerRadius = 10
        
        
        let attr = parseMarkdownIntoAttributedString(aboutString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(12), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(12), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .bold(12), textColor: theme.colors.accent), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        }))
        let infoLayout = TextViewLayout(attr, alignment: .center)
        
        let interactions = TextViewInteractions()
        interactions.processURL = { value in
            if let value = value as? String {
                execute(inapp: .external(link: value, false))
            }
        }
        
        infoLayout.interactions = interactions
        
        self.desc.update(infoLayout)

        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
            
        self.input.centerX(y: 30)
        
        desc.resize(frame.width - 60 - 20)
        desc.centerX(y: self.input.frame.maxY + 5)

        next.setFrameSize(NSMakeSize(frame.width - 60, 40))
        next.centerX(y: frame.height - next.frame.height - 50 - 30)
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension SentAuthorizationCodeType {
    var lenght: Int32 {
        switch self {
        case let .call(length):
            return length
        case let .email(_, length, _, _, _, _):
            return length
        case let .otherSession(length):
            return length
        case let .sms(length):
            return length
        case let .fragment(_, length):
            return length
        default:
            return 5
        }
    }
    var aboutString: String {
        switch self {
        case let .fragment(url, length):
            return strings().phoneNumberCodeFragmentInfo(url)
        default:
            return strings().phoneNumberCodeInfo
        }
    }
}

final class PhoneNumberCodeConfirmController : GenericViewController<PhoneNumberCodeConfirmView> {

    private let context: AccountContext
    private let disposable = MetaDisposable()
    private let data: ChangeAccountPhoneNumberData
    private let phoneNumber: String
    private var locked: Bool = false
    init(context: AccountContext, data: ChangeAccountPhoneNumberData, phoneNumber: String) {
        self.context = context
        self.data = data
        self.phoneNumber = phoneNumber
        super.init(frame: .zero)
    }
    
    deinit {
        disposable.dispose()
    }
    
    private func checkCode() {
        if locked {
            return
        }
        self.locked = true
        let context = self.context
        
        let signal = context.engine.accountData.requestChangeAccountPhoneNumber(phoneNumber: phoneNumber, phoneCodeHash: data.hash, phoneCode: self.genericView.input.value)
        
        _ = showModalProgress(signal: signal, for: context.window).start(error: { [weak self] error in
            var alertText: String = ""
            switch error {
            case .generic:
                alertText = strings().changeNumberConfirmCodeErrorGeneric
            case .invalidCode:
                self?.genericView.input.shake()
                self?.genericView.input.moveToStart()
                self?.locked = false
                return
            case .codeExpired:
                alertText = strings().changeNumberConfirmCodeErrorCodeExpired
            case .limitExceeded:
                alertText = strings().changeNumberConfirmCodeErrorLimitExceeded
            }
            alert(for: context.window, info: alertText)
            self?.genericView.input.moveToStart()
            self?.locked = false
        }, completed: { [weak self] in
            guard let phoneNumber = self?.phoneNumber else {
                return
            }
            self?.locked = false
            closeAllModals(window: context.window)
            showModalText(for: context.window, text: strings().changeNumberConfirmCodeSuccess(phoneNumber))
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.genericView.update(with: Int(self.data.type.lenght), locked: false, aboutString: self.data.type.aboutString, takeNext: { [weak self] _ in
            self?.checkCode()
        }, takeError: {
            
        })
        
        
        self.readyOnce()
        
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.checkCode()
        return .invoked
    }
    
    override var defaultBarTitle: String {
        return strings().telegramPhoneNumberConfirmController
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.input.firstResponder()
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    func applyExternalLoginCode(_ code: String) {
        if !code.isEmpty {
            let chars = Array(code).map { String($0) }
            genericView.input.insertAll(chars.compactMap { Int($0) })
        }
    }
    
}



