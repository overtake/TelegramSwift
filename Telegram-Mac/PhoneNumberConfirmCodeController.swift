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
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(input)
        addSubview(desc)
        addSubview(next)
        
        next.autohighlight = false
        next.scaleOnClick = true
        
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    func update(with count: Int, locked: Bool, takeNext: @escaping(String)->Void, takeError: @escaping()->Void) {
        let size = self.input.update(count: count)
        self.input.setFrameSize(size)
        self.input.takeNext = takeNext
        self.input.takeError = takeError
        self.input.set(locked: locked, animated: true)
        
        needsLayout = true
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
        
        
        let infoLayout = TextViewLayout(.initialize(string: strings().phoneNumberCodeInfo, color: theme.colors.grayText, font: .normal(12)), alignment: .center)
        
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
        
        let sharedContext = self.context.sharedContext
        let engine = context.engine
        
        switch self.data.type {
        case let .sms(length):
            self.genericView.update(with: Int(length), locked: false, takeNext: { [weak self] _ in
                self?.checkCode()
            }, takeError: {
                
            })
        default:
            self.genericView.update(with: 6, locked: false, takeNext: { [weak self] _ in
                self?.checkCode()
            }, takeError: {
                
            })
        }
        
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
    
}



