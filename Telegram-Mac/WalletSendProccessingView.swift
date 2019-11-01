//
//  WalletSendProccessingController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore

final class WalletSendProccessingView : Control {
    private let titleView: TextView = TextView()
    private let textView: TextView = TextView()
    private let containerView = View()
    private let animationView = MediaAnimatedStickerView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(textView)
        containerView.addSubview(titleView)
        containerView.addSubview(animationView)
        addSubview(containerView)
        updateLocalizationAndTheme(theme: theme)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    func setup(context: AccountContext) {
        self.animationView.update(with: WalletAnimatedSticker.fly_dollar.file, size: NSMakeSize(200, 200), context: context, parent: nil, table: nil, parameters: WalletAnimatedSticker.fly_dollar.parameters, animated: false, positionFlags: nil, approximateSynchronousValue: true)
        
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.listBackground
        let titleLayout = TextViewLayout(.initialize(string: L10n.walletSendSendingTitle, color: theme.colors.text, font: .medium(22)), alignment: .center)
        titleLayout.measure(width: frame.width - 60)
        self.titleView.update(titleLayout)
        
        let textLayout = TextViewLayout(.initialize(string: L10n.walletSendSendingText, color: theme.colors.listGrayText, font: .normal(.text)), alignment: .center)
        textLayout.measure(width: frame.width - 60)
        self.textView.update(textLayout)

        self.titleView.backgroundColor = theme.colors.listBackground
        self.textView.backgroundColor = theme.colors.listBackground
    }
    
    override func layout() {
        super.layout()
        
        updateLocalizationAndTheme(theme: theme)
        
        containerView.frame = NSMakeRect(0, 0, frame.width - 60, animationView.frame.height + textView.frame.height + titleView.frame.height + 10)
        containerView.center()
        containerView.setFrameOrigin(NSMakePoint(containerView.frame.minX, containerView.frame.minY - 20))
        animationView.centerX(y: 0)
        titleView.centerX(y: animationView.frame.maxY)
        textView.centerX(y: titleView.frame.maxY + 10)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



final class WalletSentView : Control {
    private let titleView: TextView = TextView()
    private let textView: TextView = TextView()
    private let containerView = View()
    private let animationView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let walletButton = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(textView)
        containerView.addSubview(titleView)
        containerView.addSubview(animationView)
        
        addSubview(containerView)
        addSubview(walletButton)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        walletButton.layer?.cornerRadius = 10
    }
    
    private var amount: String = ""
    
    
    func setup(context: AccountContext, amount: String, callback: @escaping()->Void) {
        self.amount = amount
        self.animationView.update(with: WalletAnimatedSticker.success.file, size: NSMakeSize(150, 150), context: context, parent: nil, table: nil, parameters: WalletAnimatedSticker.success.parameters, animated: false, positionFlags: nil, approximateSynchronousValue: true)
        
        walletButton.removeAllHandlers()
        
        walletButton.set(handler: { _ in
            callback()
        }, for: .Click)
        
        self.updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.listBackground
        let titleLayout = TextViewLayout(.initialize(string: L10n.walletSendSentTitle, color: theme.colors.text, font: .medium(22)), alignment: .center)
        titleLayout.measure(width: frame.width - 60)
        self.titleView.update(titleLayout)
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: L10n.walletSendSentText(self.amount), color: theme.colors.listGrayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        let textLayout = TextViewLayout(attr, alignment: .center)
        textLayout.measure(width: frame.width - 60)
        self.textView.update(textLayout)
        
        self.titleView.backgroundColor = theme.colors.listBackground
        self.textView.backgroundColor = theme.colors.listBackground
        
        
        walletButton.set(background: theme.colors.accent, for: .Normal)
        walletButton.set(background: theme.colors.accent.withAlphaComponent(0.8), for: .Highlight)
        walletButton.set(text: L10n.walletSendSentViewMyWallet, for: .Normal)
        walletButton.set(color: theme.colors.underSelectedColor, for: .Normal)
        walletButton.set(font: .medium(.title), for: .Normal)
        
        
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        updateLocalizationAndTheme(theme: theme)
        
        containerView.frame = NSMakeRect(0, 0, frame.width - 60, animationView.frame.height + textView.frame.height + titleView.frame.height + 10)
        containerView.center()
        containerView.setFrameOrigin(NSMakePoint(containerView.frame.minX, containerView.frame.minY - 20))
        animationView.centerX(y: 0)
        animationView.setFrameOrigin(NSMakePoint(animationView.frame.minX + 12, 0))
        titleView.centerX(y: animationView.frame.maxY)
        textView.centerX(y: titleView.frame.maxY + 10)
        
        walletButton.setFrameSize(NSMakeSize(frame.width - 100, 40))
        walletButton.centerX(y: frame.height - 25 - 40)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



final class WalletPasscodeView : Control {
    private let titleView: TextView = TextView()
    private let textView: TextView = TextView()
    private let containerView = View()
    private let animationView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let inputView = InputDataRowView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(textView)
        containerView.addSubview(titleView)
        containerView.addSubview(animationView)
        addSubview(containerView)
        addSubview(inputView)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
    }
    
    func setup(context: AccountContext, decryptedKey: @escaping(Data)->Void) {
        self.animationView.update(with: WalletAnimatedSticker.keychain.file, size: NSMakeSize(150, 150), context: context, parent: nil, table: nil, parameters: WalletAnimatedSticker.success.parameters, animated: false, positionFlags: nil, approximateSynchronousValue: true)
        
        let inputItem = InputDataRowItem(NSMakeSize(350, 40), stableId: 0, mode: .secure, error: nil, viewType: .singleItem, currentText: "", placeholder: nil, inputPlaceholder: "Passcode", filter: { $0 }, updated: { updated in
            
        }, limit: 255)
        
        inputView.set(item: inputItem, animated: true)
        
        self.updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.listBackground
        let titleLayout = TextViewLayout(.initialize(string: "Passcode", color: theme.colors.text, font: .medium(22)), alignment: .center)
        titleLayout.measure(width: frame.width - 60)
        self.titleView.update(titleLayout)
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: "Please enter your passcode for transafer Grams.", color: theme.colors.listGrayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        let textLayout = TextViewLayout(attr, alignment: .center)
        textLayout.measure(width: frame.width - 60)
        self.textView.update(textLayout)
        
        self.titleView.backgroundColor = theme.colors.listBackground
        self.textView.backgroundColor = theme.colors.listBackground
        
        
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        updateLocalizationAndTheme(theme: theme)
        
        containerView.frame = NSMakeRect(0, 0, frame.width - 60, animationView.frame.height + textView.frame.height + titleView.frame.height + 10)
        containerView.center()
        containerView.setFrameOrigin(NSMakePoint(containerView.frame.minX, containerView.frame.minY - 20))
        animationView.centerX(y: 0)
        animationView.setFrameOrigin(NSMakePoint(animationView.frame.minX + 12, 0))
        titleView.centerX(y: animationView.frame.maxY)
        textView.centerX(y: titleView.frame.maxY + 10)
        
        inputView.setFrameSize(NSMakeSize(frame.width, 40))
        inputView.centerX(y: frame.height - 25 - 40)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


