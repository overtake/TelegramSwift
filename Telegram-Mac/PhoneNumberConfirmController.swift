//
//  PhoneNumberConfirmController.swift
//  Telegram
//
//  Created by keepcoder on 12/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit


final class PhoneNumberConfirmView : View {
    private let title = TextView()
    private let desc = TextView()
    fileprivate let input: Auth_PhoneInput = Auth_PhoneInput(frame: .zero)
    fileprivate let next = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(input)
        addSubview(desc)
        addSubview(next)
        
        next.autohighlight = false
        next.scaleOnClick = true
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        next.set(color: theme.colors.underSelectedColor, for: .Normal)
        next.set(background: theme.colors.accent, for: .Normal)
        next.set(font: .medium(.text), for: .Normal)
        next.set(text: strings().phoneNumberSendCode, for: .Normal)
        next.sizeToFit()
        next.layer?.cornerRadius = 10
        
        
        let infoLayout = TextViewLayout(.initialize(string: strings().phoneNumberInfo, color: theme.colors.grayText, font: .normal(12)))
        
        let titleLayout = TextViewLayout(.initialize(string: strings().phoneNumberTitle, color: theme.colors.grayText, font: .normal(12)))
        
        self.title.update(titleLayout)
        self.desc.update(infoLayout)

        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        title.resize(frame.width - 60 - 20)

        title.setFrameOrigin(NSMakePoint(30 + 10, 30))

        
        self.input.setFrameSize(NSMakeSize(frame.width - 60, 80))
        self.input.centerX(y: title.frame.maxY + 5)
        
        desc.resize(frame.width - 60 - 20)
        desc.setFrameOrigin(NSMakePoint(30 + 10, self.input.frame.maxY + 5))

        
        
        next.setFrameSize(NSMakeSize(frame.width - 60, 40))
        next.centerX(y: frame.height - next.frame.height - 50 - 30)
        
    }
    
    var phoneNumber: String {
        return input.readyValue
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PhoneNumberConfirmController : GenericViewController<PhoneNumberConfirmView> {

    private let context: AccountContext
    private let disposable = MetaDisposable()
    private var locked: Bool = false
    init(context: AccountContext) {
        self.context = context
        super.init(frame: .zero)
    }
    
    deinit {
        disposable.dispose()
    }
    
    private func sendCode(_ phoneNumber: String) {
        if locked {
            return
        }
        self.locked = true
        
        let context = self.context
        _ = showModalProgress(signal: context.engine.accountData.requestChangeAccountPhoneNumberVerification(phoneNumber: phoneNumber) |> deliverOnMainQueue, for: context.window).start(next: { [weak self] data in
            self?.navigationController?.push(PhoneNumberCodeConfirmController(context: context, data: data, phoneNumber: formatPhoneNumber(phoneNumber)))
            self?.locked = false
        }, error: { [weak self] error in
            let text: String
            switch error {
            case .limitExceeded:
                text = strings().changeNumberSendDataErrorLimitExceeded
            case .invalidPhoneNumber:
                text = strings().changeNumberSendDataErrorInvalidPhoneNumber
            case .phoneNumberOccupied:
                text = strings().changeNumberSendDataErrorPhoneNumberOccupied(phoneNumber)
            case .generic:
                text = strings().changeNumberSendDataErrorGeneric
            case .phoneBanned:
                text = strings().changeNumberSendDataErrorGeneric
            }
            self?.locked = false
            alert(for: context.window, info: text)
            self?.genericView.next.shake(beep: true)
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sharedContext = self.context.sharedContext
        let engine = context.engine
        
        let getCountries = appearanceSignal |> mapToSignal { appearance in
            engine.localization.getCountriesList(accountManager: sharedContext.accountManager, langCode: appearance.language.baseLanguageCode)
        } |> deliverOnMainQueue
        
        disposable.set(getCountries.start(next: { [weak self] countries in
            self?.genericView.input.manager = .init(countries)
            self?.readyOnce()
        }))
        
        genericView.next.set(handler: { [weak self] _ in
            guard let phoneNumber = self?.genericView.phoneNumber else {
                return
            }
            self?.sendCode(phoneNumber)
        }, for: .Click)
        
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.sendCode(self.genericView.phoneNumber)
        return .invoked
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.input.firstResponder
    }
    
    
    override var enableBack: Bool {
        return true
    }
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
}



