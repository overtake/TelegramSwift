//
//  EmptyChatViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac

class EmptyChatView : View {
    private let containerView: View = View()
    private let label:TextView = TextView()
    private let imageView:ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(imageView)
        containerView.addSubview(label)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        containerView.backgroundColor = theme.colors.background
        self.background = theme.colors.background
        imageView.image = theme.icons.chatEmpty
        imageView.sizeToFit()
        label.backgroundColor = theme.colors.background
        label.update(TextViewLayout(.initialize(string: tr(L10n.emptyPeerDescription), color: theme.colors.grayText, font: .normal(.header)), maximumNumberOfLines: 1))
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        label.layout?.measure(width: frame.size.width - 20)
        label.update(label.layout)
        containerView.setFrameSize(frame.size.width - 20, imageView.frame.size.height + label.frame.size.height + 30)
        imageView.centerX()
        containerView.center()
        label.centerX(y: imageView.frame.maxY + 30)
    }
}

class EmptyChatViewController: TelegramGenericViewController<EmptyChatView> {
    
    override init(_ account: Account) {
        super.init(account)
        self.bar = NavigationBarStyle(height:0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (navigationController as? MajorNavigationController)?.closeSidebar()
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        globalPeerHandler.set(.single(nil))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.readyOnce()
    }
}
