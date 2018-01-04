//
//  SidebarCapViewController.swift
//  Telegram
//
//  Created by keepcoder on 28/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

class SidebarCapView : View {
    private let text:NSTextField = NSTextField()
    fileprivate let close:TitleButton = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        text.font = .normal(.header)
        text.drawsBackground = false
       // text.backgroundColor = .clear
        text.isSelectable = false
        text.isEditable = false
        text.isBordered = false
        text.focusRingType = .none
        text.isBezeled = false
        
        
        addSubview(text)
        
        close.set(font: .medium(.title), for: .Normal)
       
        
        addSubview(close)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        text.textColor = theme.colors.grayText
        text.stringValue = tr(L10n.sidebarAvalability);
        text.setFrameSize(text.sizeThatFits(NSMakeSize(300, 100)))
        self.background = theme.colors.background.withAlphaComponent(0.97)
        close.set(color: theme.colors.blueUI, for: .Normal)
        close.set(text: tr(L10n.navigationClose), for: .Normal)
        close.sizeToFit()
        needsLayout = true
    }
    
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func layout() {
        super.layout()
        text.center()
        close.centerX(y: text.frame.maxY + 10)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SidebarCapViewController: GenericViewController<SidebarCapView> {
    private let account:Account
    init(account:Account) {
        self.account = account
        super.init()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigation?.add(listener: WeakReference(value: self))
        genericView.close.set(handler: { [weak self] _ in
            self?.navigation?.closeSidebar()
            FastSettings.toggleSidebarShown(false)
            self?.account.context.entertainment.closedBySide()
        }, for: .Click)
    }
    
    deinit {
        navigation?.remove(listener: WeakReference(value: self))
    }
    
    var navigation:MajorNavigationController? {
        return self.account.context.mainNavigation as? MajorNavigationController
    }
    
    override func navigationWillChangeController() {
        self.view.setFrameSize(account.context.entertainment.frame.size)
        
        if navigation?.controller is ChatController {
            view.removeFromSuperview()
        } else {
            self.account.context.entertainment.addSubview(view)
        }
        
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: mainWindow)

    }
    
}
