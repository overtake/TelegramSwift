//
//  PhoneNumberConfirmController.swift
//  Telegram
//
//  Created by keepcoder on 12/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac

private let manager = CountryManager()



class ChangePhoneNumberView : View {
    fileprivate let container: ChangePhoneNumberContainerView = ChangePhoneNumberContainerView(frame: NSMakeRect(0, 0, 300, 110), manager: manager)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        backgroundColor = theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        container.centerX(y: 20)
    }
}


class PhoneNumberConfirmController: TelegramGenericViewController<ChangePhoneNumberView> {

    private let actionDisposable = MetaDisposable()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        
        let arguments = ChangePhoneNumberArguments(sendCode: { [weak self] phoneNumber in
//            let data = ChangeAccountPhoneNumberData(type: SentAuthorizationCodeType.sms(length: 6), hash: "", timeout: 10, nextType: AuthorizationCodeNextType.call)
//

            guard let strongSelf = self else {return}
            
            strongSelf.actionDisposable.set(showModalProgress(signal: requestChangeAccountPhoneNumberVerification(account: account, phoneNumber: phoneNumber) |> deliverOnMainQueue, for: mainWindow).start(next: { [weak strongSelf] data in
                
                strongSelf?.navigationController?.push(PhoneNumberInputCodeController(account, data: data, formattedNumber: formatPhoneNumber(phoneNumber)))
                
            }, error: { error in

                let text: String
                switch error {
                case .limitExceeded:
                    text = tr(L10n.changeNumberSendDataErrorLimitExceeded)
                case .invalidPhoneNumber:
                    text = tr(L10n.changeNumberSendDataErrorInvalidPhoneNumber)
                case .phoneNumberOccupied:
                    text = tr(L10n.changeNumberSendDataErrorPhoneNumberOccupied(phoneNumber))
                case .generic:
                    text = tr(L10n.changeNumberSendDataErrorGeneric)
                }

                alert(for: mainWindow, info: text)

            }))
        })
        
        genericView.container.arguments = arguments
        
        self.rightBarView.set(handler:{ [weak self] _ in
            if let strongSelf = self {
                arguments.sendCode(strongSelf.genericView.container.number)
            }
        }, for: .Click)
        
        readyOnce()
    }
    
    override var enableBack: Bool {
        return true
    }
    
    
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        if window?.firstResponder != genericView.container.numberText.textView || window?.firstResponder != genericView.container.codeText.textView {
            if genericView.container.codeText.stringValue.isEmpty {
                return genericView.container.codeText
            }
            return genericView.container.numberText
        }
        return window?.firstResponder
    }
    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: tr(L10n.composeNext), style: navigationButtonStyle, alignment:.Right)
    }
    
}
