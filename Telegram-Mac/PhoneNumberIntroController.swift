//
//  PhoneNumberIntro.swift
//  Telegram
//
//  Created by keepcoder on 12/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

class ChaneNumberIntroView : NSScrollView, AppearanceViewProtocol {
    let imageView:ImageView = ImageView()
    let textView:TextView = TextView()
    private let containerView:View = View()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        documentView = containerView
        wantsLayer = true
        documentView?.addSubview(imageView)
        documentView?.addSubview(textView)
        
        updateLocalizationAndTheme()
        
    }
    func updateLocalizationAndTheme() {
        
        imageView.image = theme.icons.changePhoneNumberIntro
        imageView.sizeToFit()
        
        backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        documentView?.background = theme.colors.background
        let attr = NSMutableAttributedString()
        _ = attr.append(string: tr(L10n.changePhoneNumberIntroDescription), color: theme.colors.grayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .bold(.text))
        textView.set(layout: TextViewLayout(attr, alignment:.center))
        
    }
    
    
    override func layout() {
        super.layout()
        containerView.setFrameSize(frame.width, 0)
        
        textView.layout?.measure(width: 380 - 60)
        textView.update(textView.layout)
        imageView.centerX(y:30)
        textView.centerX(y:imageView.frame.maxY + 30)
        containerView.setFrameSize(frame.width, textView.frame.maxY + 30)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PhoneNumberIntroController: EmptyComposeController<Void,Bool,ChaneNumberIntroView> {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ready.set(account.postbox.loadedPeerWithId(account.peerId) |> deliverOnMainQueue |> map { [weak self] peer -> Bool in
            if let phone = (peer as? TelegramUser)?.phone {
                self?.setCenterTitle(formatPhoneNumber("+" + phone))
            }
            return true
        })
        
        self.rightBarView.set(handler:{ [weak self] _ in
            self?.executeNext()
        }, for: .Click)
        
    }
    
    static var assciatedControllerTypes:[ViewController.Type] {
        return [PhoneNumberIntroController.self, PhoneNumberConfirmController.self, PhoneNumberInputCodeController.self]
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: tr(L10n.composeNext), style: navigationButtonStyle, alignment:.Right)
    }
    
    func executeNext() {
        confirm(for: mainWindow, information: tr(L10n.changePhoneNumberIntroAlert), successHandler: { [weak self] _ in
            if let account = self?.account {
                self?.navigationController?.push(PhoneNumberConfirmController(account))
            }
        })
    }
    
}
