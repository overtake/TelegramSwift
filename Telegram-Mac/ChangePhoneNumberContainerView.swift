//
//  ChangePhoneNumberContainerView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac


final class ChangePhoneNumberArguments {
    let sendCode:(String)->Void
    init(sendCode:@escaping(String)->Void) {
        self.sendCode = sendCode
    }
}

class ChangePhoneNumberContainerView : View, NSTextFieldDelegate {
    
    var arguments:ChangePhoneNumberArguments?
    
    
    private let countrySelector:TitleButton = TitleButton()
    
    let countryLabel:TextViewLabel = TextViewLabel()
    let numberLabel:TextViewLabel = TextViewLabel()
    
    fileprivate let errorLabel:LoginErrorStateView = LoginErrorStateView()
    
    let codeText:NSTextField = NSTextField()
    let numberText:NSTextField = NSTextField()
    
    fileprivate var selectedItem:CountryItem?
    private let manager: CountryManager
    
    required init(frame frameRect: NSRect, manager: CountryManager) {
        self.manager = manager
        super.init(frame: frameRect)
        
        
        countrySelector.style = ControlStyle(font: NSFont.medium(.title), foregroundColor: theme.colors.blueUI, backgroundColor: theme.colors.background)
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
        
        codeText.textColor = theme.colors.text
        codeText.font = NSFont.normal(.title)
        numberText.textColor = theme.colors.text
        numberText.font = NSFont.normal(.title)
        
        numberText.isBordered = false
        numberText.isBezeled = false
        numberText.drawsBackground = false
        numberText.focusRingType = .none
        
        codeText.drawsBackground = false
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
        backgroundColor = theme.colors.background
        countryLabel.attributedString = .initialize(string: tr(L10n.loginCountryLabel), color: theme.colors.grayText, font: NSFont.normal(FontSize.title))
        countryLabel.sizeToFit()
        
        numberLabel.attributedString = .initialize(string: tr(L10n.loginYourPhoneLabel), color: theme.colors.grayText, font: NSFont.normal(FontSize.title))
        numberLabel.sizeToFit()
        
        numberText.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.loginPhoneFieldPlaceholder), color: theme.colors.grayText, font: NSFont.normal(.header), coreText: false)
        
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
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
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
            let code = codeText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let dec = code.prefix(4)
            
            if field == codeText {
                
                
                if code.length > 4 {
                    let list = Array(code).map {String($0)}
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
                            
                            let codeString = String(_code)
                            var formated = formatPhoneNumber(codeString + String(code[codeString.endIndex..<code.endIndex]) + numberText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
                            
                            if formated.hasPrefix("+") {
                                formated = formated.fromSuffix(2)
                            }
                            formated = String(code[codeString.endIndex..<code.endIndex]).prefix(17)
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
                formated = String(formated[dec.endIndex..<formated.endIndex]).prefix(17)
                numberText.stringValue = formated
            }
            
        }
        needsLayout = true
        setNeedsDisplayLayer()
    }
    
    var number:String {
        return codeText.stringValue + numberText.stringValue
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            if control == codeText {
                self.window?.makeFirstResponder(self.numberText)
                self.numberText.selectText(nil)
            } else if !numberText.stringValue.isEmpty {
                arguments?.sendCode(number)
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
    
    func update(selectedItem:CountryItem?, update:Bool, updateCode:Bool = true) -> Void {
        self.selectedItem = selectedItem
        if update {
            countrySelector.set(text: selectedItem?.shortName ?? tr(L10n.loginInvalidCountryCode), for: .Normal)
            _ = countrySelector.sizeToFit()
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
