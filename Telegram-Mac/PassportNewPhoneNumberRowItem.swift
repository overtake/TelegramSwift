//
//  SecureIdNewPhoneNumberRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

private let manager = CountryManager()


private final class PassportPhoneNumberArguments {
    let sendCode:(String)->Void
    init(sendCode:@escaping(String)->Void) {
        self.sendCode = sendCode
    }
}

private final class PassportPhoneTextField : NSTextField {
    
    override func resignFirstResponder() -> Bool {
        (self.delegate as? PassportPhoneContainerView)?.controlTextDidBeginEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        (self.delegate as? PassportPhoneContainerView)?.controlTextDidEndEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.becomeFirstResponder()
    }
    
    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }
}


private class PassportPhoneContainerView : View, NSTextFieldDelegate {
    
    var arguments:PassportPhoneNumberArguments?
    
    
    private let countrySelector:TitleButton = TitleButton()
    
    
    fileprivate let errorLabel:LoginErrorStateView = LoginErrorStateView()
    
    let codeText:PassportPhoneTextField = PassportPhoneTextField()
    let numberText:PassportPhoneTextField = PassportPhoneTextField()
    
    fileprivate var selectedItem:CountryItem?
    private let manager: CountryManager
    
    required init(frame frameRect: NSRect, manager: CountryManager) {
        self.manager = manager
        super.init(frame: frameRect)
        
        
        countrySelector.style = ControlStyle(font: NSFont.medium(.title), foregroundColor: theme.colors.blueUI, backgroundColor: theme.colors.background)
        countrySelector.set(text: "France", for: .Normal)
        _ = countrySelector.sizeToFit()
        addSubview(countrySelector)
        
        

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
        
        numberText.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.loginPhoneFieldPlaceholder), color: theme.colors.grayText, font: NSFont.normal(.header), coreText: false)
        codeText.textView?.insertionPointColor = theme.colors.indicatorColor
        numberText.textView?.insertionPointColor = theme.colors.indicatorColor

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
        
        let maxInset: CGFloat = 0
        let contentInset = maxInset
        countrySelector.setFrameOrigin(contentInset - 2, floorToScreenPixels(scaleFactor: backingScaleFactor, 25 - countrySelector.frame.height/2))

        codeText.setFrameOrigin(contentInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 75 - codeText.frame.height/2))
        numberText.setFrameOrigin(contentInset + separatorInset, floorToScreenPixels(scaleFactor: backingScaleFactor, 75 - codeText.frame.height/2))
        errorLabel.centerX(y: 120)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        
        let maxInset: CGFloat = 0
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
    
    override func controlTextDidBeginEditing(_ obj: Notification) {
        codeText.textView?.backgroundColor = theme.colors.background
        numberText.textView?.backgroundColor = theme.colors.background
        codeText.textView?.insertionPointColor = theme.colors.indicatorColor
        numberText.textView?.insertionPointColor = theme.colors.indicatorColor
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        
        
        if let field = obj.object as? NSTextField {
            
            field.textView?.backgroundColor = theme.colors.background
            
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
        
        arguments?.sendCode(number)
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



class PassportNewPhoneNumberRowItem: GeneralRowItem, InputDataRowDataValue {

    var value: InputDataValue {
        return _value
    }
    
    fileprivate var _value: InputDataValue = .string("")
    
    init(_ initialSize: NSSize, stableId: AnyHashable, action: @escaping()->Void) {
        super.init(initialSize, height: 110, stableId: stableId, action: action)
    }
    
    
    override func viewClass() -> AnyClass {
        return PassportNewPhoneNumberRowView.self
    }
}


private final class PassportNewPhoneNumberRowView : TableRowView {
    fileprivate let container: PassportPhoneContainerView = PassportPhoneContainerView(frame: NSMakeRect(0, 0, 300, 110), manager: manager)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
    }
    
//    override var firstResponder: NSResponder? {
//        if container.numberText._mouseInside() {
//            return container.numberText
//        } else if container.codeText._mouseInside() {
//            return container.codeText
//        }
//        return container.numberText
//    }
//
    override var mouseInsideField: Bool {
        return container.numberText._mouseInside() || container.codeText._mouseInside()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        switch true {
        case NSPointInRect(point, container.numberText.frame):
            return container.numberText
        case NSPointInRect(point, container.codeText.frame):
            return container.codeText
        default:
            return super.hitTest(point)
        }
    }
    
    override func hasFirstResponder() -> Bool {
        return true
    }
    
    override var firstResponder: NSResponder? {
        let isKeyDown = NSApp.currentEvent?.type == NSEvent.EventType.keyDown && NSApp.currentEvent?.keyCode == KeyboardKey.Tab.rawValue
        switch true {
        case container.codeText._mouseInside() && !isKeyDown:
            return container.codeText
        case container.numberText._mouseInside() && !isKeyDown:
            return container.numberText
        default:
            switch true {
            case container.codeText.textView == window?.firstResponder:
                return container.codeText.textView
            case container.numberText.textView == window?.firstResponder:
                return container.numberText.textView
            default:
                return container.numberText
            }
        }
    }
    
    
    override func nextResponder() -> NSResponder? {
        if window?.firstResponder == container.codeText.textView {
            return container.numberText
        }
        if window?.firstResponder == container.numberText.textView {
            return container.codeText
        }
        return nil
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        container.setFrameSize(frame.width - item.inset.left - item.inset.right, container.frame.height)
        container.center()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        container.arguments = PassportPhoneNumberArguments(sendCode: { [weak self] phone in
            guard let item = self?.item as? PassportNewPhoneNumberRowItem else {return}
            item._value = .string(phone)
        })
    }
    
    override func updateColors() {
        super.updateColors()
        container.updateLocalizationAndTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
