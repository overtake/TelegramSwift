//
//  AddContactModalController.swift
//  Telegram
//
//  Created by keepcoder on 10/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

private class AddContactControllerView : View, NSTextFieldDelegate {
    private let headerView:TextView = TextView()
    fileprivate let firstName:NSTextField = NSTextField()
    fileprivate let lastName:NSTextField = NSTextField()
    fileprivate let phoneNumber:NSTextField = NSTextField()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let layout = TextViewLayout(.initialize(string: tr(L10n.contactsAddContact), color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        layout.measure(width: frameRect.width)
        headerView.update(layout)
        addSubview(headerView)
        addSubview(firstName)
        addSubview(lastName)
        addSubview(phoneNumber)
        
        firstName.nextResponder = lastName
        firstName.nextKeyView = lastName
        
        lastName.nextResponder = phoneNumber
        lastName.nextKeyView = phoneNumber
        
        //phoneNumber.nextResponder = firstName
        //phoneNumber.nextKeyView = firstName
        
        firstName.delegate = self
        lastName.delegate = self
        phoneNumber.delegate = self

        
        firstName.isBordered = false
        firstName.isBezeled = false
        firstName.focusRingType = .none
        
        lastName.isBordered = false
        lastName.isBezeled = false
        lastName.focusRingType = .none
        
        phoneNumber.isBordered = false
        phoneNumber.isBezeled = false
        phoneNumber.focusRingType = .none
        
        
        firstName.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.contactsFirstNamePlaceholder), color: theme.colors.grayText, font: .normal(13.5))
        lastName.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.contactsLastNamePlaceholder), color: theme.colors.grayText, font: .normal(13.5))
        phoneNumber.placeholderAttributedString = NSAttributedString.initialize(string: tr(L10n.contactsPhoneNumberPlaceholder), color: theme.colors.grayText, font: .normal(13.5))
        
        firstName.setFrameSize(NSMakeSize(frameRect.width - 40, 20))
        lastName.setFrameSize(NSMakeSize(frameRect.width - 40, 20))
        phoneNumber.setFrameSize(NSMakeSize(frameRect.width - 40, 20))
        
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        backgroundColor = theme.colors.background
        headerView.backgroundColor = theme.colors.background
        firstName.backgroundColor = theme.colors.background
        lastName.backgroundColor = theme.colors.background
        phoneNumber.backgroundColor = theme.colors.background
    }
    
    
    override func controlTextDidChange(_ obj: Notification) {
        firstName.stringValue = firstName.stringValue.nsstring.substring(with: NSMakeRange(0, min(firstName.stringValue.length, 20)))
        lastName.stringValue = lastName.stringValue.nsstring.substring(with: NSMakeRange(0, min(lastName.stringValue.length, 20)))
        phoneNumber.stringValue = formatPhoneNumber(phoneNumber.stringValue)
    }
    
    
    override func layout() {
        super.layout()
        headerView.centerX(y: floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - headerView.frame.height)/2))
        firstName.centerX(y: 50 + 35)
        lastName.centerX(y: firstName.frame.maxY + 30)
        phoneNumber.centerX(y: lastName.frame.maxY + 30)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, 50, frame.width, .borderSize))
        ctx.fill(NSMakeRect(firstName.frame.minX, firstName.frame.maxY + 2, firstName.frame.width, .borderSize))
        ctx.fill(NSMakeRect(lastName.frame.minX, lastName.frame.maxY + 2, lastName.frame.width, .borderSize))
        ctx.fill(NSMakeRect(phoneNumber.frame.minX, phoneNumber.frame.maxY + 2, phoneNumber.frame.width, .borderSize))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AddContactModalController: ModalViewController {

    private let account:Account
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    override func viewClass() -> AnyClass {
        return AddContactControllerView.self
    }
    

    
    override func firstResponder() -> NSResponder? {
        if genericView.window?.firstResponder == genericView.firstName.textView || genericView.window?.firstResponder == genericView.lastName.textView || genericView.window?.firstResponder == genericView.phoneNumber.textView {
            return genericView.window?.firstResponder
        }
        return genericView.firstName
    }
    
    private var genericView:AddContactControllerView {
        return self.view as! AddContactControllerView
    }
    
    init(account: Account) {
        self.account = account
        super.init(frame: NSMakeRect(0, 0, 300, 240))
        bar = .init(height: 0)
    }
    
    func importAndCloseIfPossible() {
        if genericView.firstName.stringValue.length == 0 {
            genericView.firstName.shake()
        } else if genericView.phoneNumber.stringValue.length == 0 {
            genericView.phoneNumber.shake()
        } else {
            close()
            _ = (showModalProgress(signal: importContact(account: account, firstName: genericView.firstName.stringValue , lastName: genericView.lastName.stringValue, phoneNumber: genericView.phoneNumber.stringValue), for: mainWindow) |> deliverOnMainQueue).start(next: { [weak self]  peerId in
                if let peerId = peerId, let account = self?.account {
                    account.context.mainNavigation?.push(ChatController(account: account, chatLocation: .peer(peerId)))
                } else {
                    alert(for: mainWindow, header: tr(L10n.contactsNotRegistredTitle), info: tr(L10n.contactsNotRegistredDescription))
                }
            })
        }
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.contactsAddContact), accept: { [weak self] in
            self?.importAndCloseIfPossible()
        }, cancelTitle: tr(L10n.modalCancel), drawBorder: false)
    }
    
}
