//
//  Auth_PhoneNumber.swift
//  Telegram
//
//  Created by Mike Renoir on 14.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit
import TelegramCore
import SwiftSignalKit

private func formatNumber(_ number: String, country: Country) -> String {
    var formatted: String = ""
    
    guard let pattern = country.countryCodes.first?.patterns.first else {
        return number
    }
    let numberChars = Array(number)
    let patternChars = Array(pattern)
    
    var patternIndex: Int = 0
    for char in numberChars {
        if patternIndex < patternChars.count {
            let pattern = patternChars[patternIndex]
            if pattern == "X" {
                formatted.append(char)
            } else {
                formatted.append("\(pattern)")
                formatted.append(char)
                patternIndex += 1
            }
            patternIndex += 1
        } else {
            formatted.append(char)
        }
    }
    if patternIndex < patternChars.count, patternChars[patternIndex] == " " {
        formatted.append(" ")
    }
    return formatted
}

private func emojiFlagForISOCountryCode(_ countryCode: String) -> String {
    if countryCode.count != 2 {
        return ""
    }
    
    if countryCode == "XG" {
        return "🛰️"
    } else if countryCode == "XV" {
        return "🌍"
    }
    
    if ["YL"].contains(countryCode) {
        return "🌍"
    }
    
    let base : UInt32 = 127397
    var s = ""
    for v in countryCode.unicodeScalars {
        s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
    }
    return String(s)
}


private extension Country {
    var fullName: String {
        if let code = self.countryCodes.first {
            return "\(emojiFlagForISOCountryCode(self.id))" + " " + name + " +\(code.code)"
        } else {
            return self.name
        }
    }
    var emojiName: String {
        let emoji = emojiFlagForISOCountryCode(self.id)
        if emoji.isEmpty {
            return self.name
        } else {
            return emojiFlagForISOCountryCode(self.id) + " " + self.name
        }
    }
}

private final class Manager {
    let list: [Country]
    init(_ countries:[Country]) {
        self.list = countries
    }
    
    func item(byCodeNumber codeNumber: String, prefix: String?) -> Country? {
        let firstTrip = self.list.first(where: { value in
            for code in value.countryCodes {
                if code.code == codeNumber {
                    if let prefix = prefix {
                        return code.prefixes.contains(prefix)
                    }
                    return true
                }
            }
            return false
        })
        if firstTrip == nil {
            return self.list.first(where: { value in
                for code in value.countryCodes {
                    if code.code == codeNumber, code.prefixes.isEmpty {
                        return true
                    }
                }
                return false
            })
        }
        return firstTrip
    }
    func item(bySmallCountryName name: String) -> Country? {
        return self.list.first(where: { value in
            return value.id == name
        })
    }
}

final class Auth_LoginHeader : View {
    private let logo:LottiePlayerView = LottiePlayerView(frame: Auth_Insets.logoSize.bounds)
    private let header: TextView = TextView()
    private let desc: TextView = TextView()
    private var descAttr: NSAttributedString?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(logo)
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
        
        
        if let data = LocalAnimatedSticker.login_airplane.data {
            let colors:[LottieColor] = []
            self.logo.set(LottieAnimation(compressed: data, key: .init(key: .bundle("login_airplane"), size: Auth_Insets.logoSize, backingScale: Int(System.backingScale), fitzModifier: nil), playPolicy: .loop, colors: colors))
        }
        
        let layout = TextViewLayout(.initialize(string: appName, color: theme.colors.text, font: Auth_Insets.headerFont))
        layout.measure(width: frame.width)
        self.header.update(layout)
        
        let descAttr: NSAttributedString = .initialize(string: strings().loginNewPhoneNumber, color: theme.colors.grayText, font: Auth_Insets.infoFont)
        let descLayout = TextViewLayout(descAttr, alignment: .center)
        descLayout.measure(width: frame.width)
        self.desc.update(descLayout)
        
        self.layout()
    }
    
    func update(desc: NSAttributedString) {
        self.descAttr = desc
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func layout() {
        super.layout()
        self.logo.centerX(y: 0)
        self.header.centerX(y: self.logo.frame.maxY + 20)
        self.desc.centerX(y: self.header.frame.maxY + 10)

    }
    
    var height: CGFloat {
        return self.desc.frame.maxY
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class Auth_PhoneInput: View, NSTextFieldDelegate {
    private let separator = View()
    private let country: TitleButton = TitleButton()
    
    private let country_overlay: Control = Control()
    private let nextView = ImageView()
    
    private let codeText:NSTextField = NSTextField()
    private let numberText:NSTextField = NSTextField()

    
    fileprivate var manager: Manager = .init([]) {
        didSet {
            if !manager.list.isEmpty, selected == nil {
                let code = NSLocale.current.regionCode ?? "US"
                update(selected: manager.item(bySmallCountryName: code), update: true)
            }
        }
    }

    
    fileprivate var selected:Country? {
        didSet {
            updatePlaceholder()
        }
    }

    
    var next:((String)->Void)?
    var updatePhoneNumber:((String)->Void)?
    
    private let placeholder: TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(separator)
        layer?.cornerRadius = 10
        
        country.set(text: "-----", for: .Normal)
        country.disableActions()
        _ = country.sizeToFit()
        addSubview(country)
        addSubview(nextView)
        addSubview(country_overlay)
        
        codeText.stringValue = "+"
        codeText.font = .code(.title)
        numberText.font = .code(.title)
        
        numberText.isBordered = false
        numberText.isBezeled = false
        numberText.focusRingType = .none
        numberText.drawsBackground = false
        
        codeText.isBordered = false
        codeText.isBezeled = false
        codeText.focusRingType = .none
        codeText.drawsBackground = false
        
        codeText.delegate = self
        codeText.nextResponder = numberText
        codeText.nextKeyView = numberText
        
        numberText.delegate = self
        numberText.nextResponder = codeText
        numberText.nextKeyView = codeText
        
        addSubview(placeholder)
        addSubview(codeText)
        addSubview(numberText)
        
        updateLocalizationAndTheme(theme: theme)
        
        country_overlay.contextMenu = { [weak self] in
            guard let manager = self?.manager else {
                return nil
            }
            var items:[ContextMenuItem] = []
            for country in manager.list {
                let item = ContextMenuItem(country.fullName, handler: { [weak self] in
                    self?.update(selected: country, update: true)
                })
                items.append(item)
            }
            let menu = ContextMenu()
            for item in items {
                menu.addItem(item)
            }
            return menu
        }
    }
    
    private func updatePlaceholder() {
        let number = numberText.stringValue
        var text: String = number.isEmpty ? strings().loginPhoneFieldPlaceholder : ""
        if let item = selected {
            if let pattern = item.countryCodes.first?.patterns.first {
                text = String(pattern.replacingOccurrences(of: "X", with: "-"))
            }
        }
        let attr = NSMutableAttributedString()
        _ = attr.append(string: text, color: theme.colors.grayText, font: .code(.title))
        if !number.isEmpty {
            attr.addAttribute(.foregroundColor, value: NSColor.clear, range: NSMakeRange(0, min(number.length, text.length)))
        }
        let layout = TextViewLayout(attr)
        layout.measure(width: .greatestFiniteMagnitude)
        placeholder.update(layout)
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.grayBackground
        self.separator.background = theme.colors.border
        codeText.backgroundColor = .clear
        numberText.backgroundColor = .clear
        country.style = ControlStyle(font: .medium(.title), foregroundColor: theme.colors.text, backgroundColor: theme.colors.grayBackground)
        country.set(font: .normal(.header), for: .Normal)
        
        codeText.placeholderAttributedString = .initialize(string: strings().loginCodePlaceholder, color: theme.colors.grayText, font: .normal(.header), coreText: false)
        nextView.image = NSImage(named: "Icon_GeneralNext")?.precomposed(theme.colors.border)
        
        self.updatePlaceholder()
        
        nextView.sizeToFit()
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        codeText.sizeToFit()
        codeText.setFrameSize(codeText.frame.width, 18)
        numberText.setFrameSize(frame.width - (10 + codeText.frame.width + 10) - 10, 18)
        self.separator.frame = focus(NSMakeSize(frame.width - 20, .borderSize))
        codeText.setFrameOrigin(10, frame.height - floor(frame.height / 2 - codeText.frame.height/2))
        numberText.setFrameOrigin(10 + codeText.frame.width + 10, frame.height - floor(frame.height / 2 - numberText.frame.height/2))
        placeholder.setFrameOrigin(NSMakePoint(10 + codeText.frame.width + 10 + 2, frame.height - floor(frame.height / 2 - placeholder.frame.height/2) + 2))

        country.setFrameOrigin(NSMakePoint(10, 12))
        country_overlay.frame = NSMakeRect(0, 0, frame.width, frame.height / 2)
        nextView.setFrameOrigin(NSMakePoint(frame.width - 10 - nextView.frame.width, floor((frame.height / 2 - nextView.frame.height)/2)))
    }
    
    
    func update(selected:Country?, update:Bool, updateCode:Bool = true) -> Void {
        self.selected = selected
        if let selected = selected {
            country.set(text: selected.emojiName , for: .Normal)
        } else {
            country.set(text: strings().loginInvalidCountryCode, for: .Normal)
        }
        country.sizeToFit()
        if updateCode {
            codeText.stringValue = selected != nil ? "+\(selected!.countryCodes[0].code)" : "+"
        }
        needsLayout = true
    }
    
    func update(countryCode: Int32, number: String) {
        if !hasChanges {
            self.codeText.stringValue = "\(countryCode)"
            self.numberText.stringValue = formatPhoneNumber(number)

        }
    }
    
    private var hasChanges: Bool = false
    
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
                    })
                    
                    var found: Bool = false
                    for _code in reduced {
                        let rest = String(code[String(_code).endIndex...])
                        if let item = manager.item(byCodeNumber: _code, prefix: rest.prefix(1)) {
                            codeText.stringValue = "+" + String(_code)
                            update(selected: item, update: true, updateCode: false)
                            
                           
                            let text = rest + numberText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                            let formated = formatNumber(text, country: item).prefix(17)
                            numberText.stringValue = formated
                            window?.makeFirstResponder(numberText)
                            numberText.setCursorToEnd()
                            found = true
                            break
                        }
                    }
                    
                    if !found {
                        update(selected: nil, update: true, updateCode: false)
                    }
                } else {
                    codeText.stringValue = "+" + dec
                    let item:Country? = manager.item(byCodeNumber: dec, prefix: nil)
                    update(selected: item, update: true, updateCode:false)
                }
                
            } else if field == numberText, let item = self.selected {
                let current = numberText.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

                let updated:Country? = manager.item(byCodeNumber: dec, prefix: current.prefix(1))
                if item != updated {
                    self.update(selected: updated, update: true)
                }
                let formated = formatNumber(current, country: updated ?? item).prefix(17)
                numberText.stringValue = formated
                self.updatePhoneNumber?(formated)
            }
            
        }
        updatePlaceholder()
        needsLayout = true
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            if control == codeText {
                self.window?.makeFirstResponder(self.numberText)
                self.numberText.selectText(nil)
            } else if !numberText.stringValue.isEmpty {
                self.next?(codeText.stringValue + numberText.stringValue)
            }
            (control as? NSTextField)?.setCursorToEnd()
            return true
        } else if commandSelector == #selector(deleteBackward(_:)) {
            if control == numberText {
                if numberText.stringValue.isEmpty {
                    DispatchQueue.main.async {
                        self.window?.makeFirstResponder(self.codeText)
                        self.codeText.setCursorToEnd()
                    }
                } else {
                    if numberText.stringValue.last == " " {
                        numberText.stringValue = String(numberText.stringValue.prefix(max(0, numberText.stringValue.length - 1)))
                        return true
                    }
                }
            }
            return false
            
        }
        return false
    }

    
    var readyValue: String {
        return self.codeText.stringValue + numberText.stringValue
    }
    
    var firstResponder: NSResponder? {
        if window?.firstResponder != numberText.textView || window?.firstResponder != codeText.textView {
            if self.codeText.stringValue.isEmpty {
                return self.codeText
            }
            return self.numberText
        }
        return window?.firstResponder
    }
    
    func set(_ number: String) {
        if !hasChanges {
            self.codeText.stringValue = number
            self.numberText.stringValue = ""
            self.controlTextDidChange(Notification.init(name: NSControl.textDidChangeNotification, object: self.codeText, userInfo: nil))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class Auth_PhoneNumberView : View {
    private let header:Auth_LoginHeader
    private let container: View = View()
    private let input: Auth_PhoneInput = Auth_PhoneInput(frame: .zero)
    
    private let qrButton: TitleButton = TitleButton()
    private let nextView: Auth_NextView = Auth_NextView()
    
    private var qrEnabled: Bool = false
    private var isUserUpdated: Bool = false

    fileprivate let errorLabel:LoginErrorStateView = LoginErrorStateView()

    private var takeToken:(()->Void)?
    private var takeNext:((String)->Void)?

    
    
    required init(frame frameRect: NSRect) {
        header = Auth_LoginHeader(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        container.addSubview(header)
        container.addSubview(input)
        
        errorLabel.layer?.opacity = 0
        container.addSubview(errorLabel)
        
        container.addSubview(qrButton)
        container.addSubview(nextView)
        
        nextView.scaleOnClick = true
        qrButton.scaleOnClick = true
        
        nextView.set(handler: { [weak self] _ in
            self?.takeNext?(self?.input.readyValue ?? "")
        }, for: .Click)
        
        qrButton.set(handler: { [weak self] _ in
            self?.takeToken?()
        }, for: .Click)
        
        addSubview(container)

        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        self.header.setFrameSize(NSMakeSize(frame.width, self.header.height))
        
        qrButton.set(font: Auth_Insets.infoFontBold, for: .Normal)
        qrButton.style = ControlStyle(font: .medium(15.0), foregroundColor: theme.colors.accent, backgroundColor: .clear)
        qrButton.set(text: strings().loginQRLogin, for: .Normal)
        qrButton.sizeToFit(NSMakeSize(30, 0), NSMakeSize(0, Auth_Insets.nextHeight), thatFit: true)

        nextView.updateLocalizationAndTheme(theme: theme)
        
        needsLayout = true
    }

    override func layout() {
        super.layout()
        
        self.input.setFrameSize(NSMakeSize(280, 80))
        
        self.container.setFrameSize(NSMakeSize(frame.width, self.header.height + Auth_Insets.betweenHeader + input.frame.height + Auth_Insets.betweenNextView + Auth_Insets.nextHeight))
        
        self.header.centerX(y: 0)
        self.input.centerX(y: self.header.frame.maxY + Auth_Insets.betweenHeader)
        
        self.errorLabel.centerX(y: self.input.frame.maxY + Auth_Insets.betweenError)
        
        self.qrButton.centerX(y: self.input.frame.maxY + Auth_Insets.betweenNextView)
        self.nextView.centerX(y: self.input.frame.maxY + Auth_Insets.betweenNextView)

        self.container.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setPhoneError(_ error: AuthorizationCodeRequestError) {
        let text:String
        switch error {
        case .invalidPhoneNumber:
            text = strings().phoneNumberInvalid
        case .limitExceeded:
            text = strings().loginFloodWait
        case .generic:
            text = "undefined error"
        case .phoneLimitExceeded:
            text = "undefined error"
        case .phoneBanned:
            text = strings().loginNewPhoneBannedError
        case .timeout:
            text = "timeout"
        }
        errorLabel.state.set(.error(text))
    }
    
    func update(_ state: UnauthorizedAccountStateContents, countries: [Country], error: AuthorizationCodeRequestError?, qrEnabled: Bool, animated: Bool, takeToken:@escaping()->Void, takeNext: @escaping(String)->Void) {
        if let error = error {
            setPhoneError(error)
        } else {
            errorLabel.state.set(.normal)
        }
        switch state {
        case let .phoneEntry(countryCode, number):
            self.input.update(countryCode: countryCode, number: number)
        default:
            break
        }
        self.qrEnabled = qrEnabled
        
        self.takeNext = takeNext
        self.takeToken = takeToken
        
        if !qrEnabled {
            self.qrButton.isHidden = true
            self.nextView.isHidden = false
        } else {
            if !isUserUpdated {
                self.qrButton.isHidden = false
                self.nextView.isHidden = true
            } else {
                self.qrButton.isHidden = true
                self.nextView.isHidden = false
            }
        }
        
        input.updatePhoneNumber = { [weak self] value in
            self?.qrButton.isHidden = !value.isEmpty || !qrEnabled
            self?.nextView.isHidden = value.isEmpty && qrEnabled
            self?.isUserUpdated = !value.isEmpty
        }
        input.next = takeNext
        
        input.manager = .init(countries)
        
        needsLayout = true
    }
    
    func set(_ number: String) -> Void {
        self.input.set(number)
    }
    
    var firstResponder: NSResponder? {
        return input.firstResponder
    }
    
}

final class Auth_PhoneNumberController: GenericViewController<Auth_PhoneNumberView> {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    func update(_ state: UnauthorizedAccountStateContents, countries: [Country], error: AuthorizationCodeRequestError?, qrEnabled: Bool, takeToken:@escaping()->Void, takeNext: @escaping(String)->Void) {
        self.genericView.update(state, countries: countries, error: error, qrEnabled: qrEnabled, animated: true, takeToken: takeToken, takeNext: takeNext)
    }
    
    func set(number: String) {
        self.genericView.set(number)
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.firstResponder
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}
