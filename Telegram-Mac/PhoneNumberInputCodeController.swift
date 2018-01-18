//
//  PhoneNumberInputCodeController.swift
//  Telegram
//
//  Created by keepcoder on 13/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


private final class ConfirmCodeArguments {
    let confirm:(String)->Void
    init(confirm:@escaping(String)->Void) {
        self.confirm = confirm
    }
}


class PhoneNumberInputCodeView : View, NSTextFieldDelegate {
    
    fileprivate var arguments: ConfirmCodeArguments?
    fileprivate var codeLength: Int32 = 5
    fileprivate var undo:[String] = []

    let codeText: NSTextField = NSTextField()
    private let inputContainer: View = View()
    private let yourCodeField: TextView = TextView()
    private let sentCodeField: TextView = TextView()
    
    private let callField: TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(inputContainer)
        addSubview(yourCodeField)
        addSubview(sentCodeField)
        addSubview(callField)
        
        
        inputContainer.addSubview(codeText)
        inputContainer.border = [.Bottom, .Top]
        
        codeText.stringValue = "123456"
        codeText.alignment = .center
        codeText.textColor = theme.colors.text
        codeText.font = NSFont.normal(.title)
        codeText.sizeToFit()
        codeText.stringValue = ""
        
        codeText.drawsBackground = false
        codeText.isBordered = false
        codeText.isBezeled = false
        codeText.focusRingType = .none
        codeText.maximumNumberOfLines = 1
        
        codeText.delegate = self
        
        updateLocalizationAndTheme()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            return true
        }
        return false
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        let code = codeText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().prefix(Int(codeLength))
        codeText.stringValue = code
        codeText.sizeToFit()
        if code.length == codeLength, undo.index(of: code) == nil {
            undo.append(code)
            arguments?.confirm(code)
        }
        needsLayout = true
    }
    
    func updateCallField(_ timeout: Int32?, nextType: AuthorizationCodeNextType?) {
        if let timeout = timeout, let nextType = nextType {
            callField.isHidden = false
            let layout:TextViewLayout
            if timeout > 0 {
                let timeout = Int(timeout)
                let minutes = timeout / 60;
                let sec = timeout % 60;
                let secValue = sec > 9 ? "\(sec)" : "0\(sec)"
                var nextText: String = ""
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
                layout = TextViewLayout(.initialize(string: nextText, color: theme.colors.grayText, font: .normal(.text)))
            } else {
                layout = TextViewLayout(.initialize(string: tr(L10n.loginPhoneDialed), color: theme.colors.grayText, font: .normal(.text)))
            }
            layout.measure(width: frame.width - 60)
            callField.update(layout)
        } else {
            callField.isHidden = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        yourCodeField.backgroundColor = theme.colors.grayBackground
        sentCodeField.backgroundColor = theme.colors.grayBackground
        callField.backgroundColor = theme.colors.grayBackground
        let yourCodeLayout = TextViewLayout(.initialize(string: tr(L10n.loginYourCodeLabel).uppercased(), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        let sentCodeLayout = TextViewLayout(.initialize(string: tr(L10n.loginJustSentSms), color: theme.colors.grayText, font: .normal(.text)))
        
        yourCodeField.update(yourCodeLayout)
        sentCodeField.update(sentCodeLayout)

        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: tr(L10n.loginCodePlaceholder), color: theme.colors.grayText, font: .normal(.title))
        attr.setAlignment(.center, range: attr.range)
        codeText.placeholderAttributedString = attr
        backgroundColor = theme.colors.grayBackground
    }
    
    override func layout() {
        super.layout()
        inputContainer.frame = NSMakeRect(0, 50, frame.width, 32)
        codeText.center()
        
        yourCodeField.layout?.measure(width: frame.width - 60)
        yourCodeField.update(yourCodeField.layout)
        
        sentCodeField.layout?.measure(width: frame.width - 60)
        sentCodeField.update(sentCodeField.layout)
        
        yourCodeField.setFrameOrigin(30, inputContainer.frame.minY - yourCodeField.frame.height - 8)
        sentCodeField.setFrameOrigin(30, inputContainer.frame.maxY + 8)
        
        callField.setFrameOrigin(30, sentCodeField.frame.maxY + 8)
    }
    
}

class PhoneNumberInputCodeController: TelegramGenericViewController<PhoneNumberInputCodeView> {

    
    private let data: ChangeAccountPhoneNumberData
    private let countDownDisposable = MetaDisposable()
    private let changePhoneDisposable = MetaDisposable()
    private let formattedNumber: String
    private var arguments: ConfirmCodeArguments?
    init(_ account: Account, data: ChangeAccountPhoneNumberData, formattedNumber: String) {
        self.data = data
        self.formattedNumber = formattedNumber
        super.init(account)
    }
    
    override var defaultBarTitle: String {
        return formattedNumber
    }
    
    private func checkCode(_ code:String)->Void {
                
        changePhoneDisposable.set(showModalProgress(signal: requestChangeAccountPhoneNumber(account: account, phoneNumber: formattedNumber, phoneCodeHash: data.hash, phoneCode: code) |> deliverOnMainQueue, for: mainWindow).start(error: { [weak self] error in
            var alertText: String = ""
            switch error {
            case .generic:
                alertText = tr(L10n.changeNumberConfirmCodeErrorGeneric)
            case .invalidCode:
                self?.genericView.codeText.shake()
                self?.genericView.codeText.setSelectionRange(NSMakeRange(0, code.length)) 
                return
            case .codeExpired:
                alertText = tr(L10n.changeNumberConfirmCodeErrorCodeExpired)
            case .limitExceeded:
                alertText = tr(L10n.changeNumberConfirmCodeErrorLimitExceeded)
            }
            alert(for: mainWindow, info: alertText)
        }, completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.navigationController?.close(animated: true)
                alert(for: mainWindow, info: tr(L10n.changeNumberConfirmCodeSuccess(strongSelf.formattedNumber)))
            }
        }))
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch data.type {
        case let .sms(length), let .call(length):
             genericView.codeLength = length
        default:
            break
        }
       
        
        self.arguments = ConfirmCodeArguments(confirm: { [weak self] code in
            self?.checkCode(code)
        })
        
        genericView.arguments = arguments
        
        genericView.updateCallField(data.timeout, nextType: data.nextType)
        
        if let timeout = data.timeout {
            countDownDisposable.set(countdown(Double(timeout), delay: 1.0).start(next: { [weak self] timeout in
                self?.genericView.updateCallField(Int32(timeout), nextType: self?.data.nextType)
            }))
        }
        
        readyOnce()
        
        self.rightBarView.set(handler:{ [weak self] _ in
            self?.executeNext()
        }, for: .Click)
        
    }
    
    override var enableBack: Bool {
        return true
    }
    
    private func executeNext() {
        checkCode(genericView.codeText.stringValue)
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        if window?.firstResponder == nil ||
        window?.firstResponder != genericView.codeText.textView {
            return genericView.codeText
        }
        return window?.firstResponder
    }
    
    deinit {
        countDownDisposable.dispose()
        changePhoneDisposable.dispose()
    }
    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: tr(L10n.composeNext), style: navigationButtonStyle, alignment:.Right)
    }
}
