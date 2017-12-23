//
//  ShareViewController.swift
//  TelegramShare
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


class ShareViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "ShareViewController")
    }
    private let accountManagerPromise = Promise<AccountManager>()
    private var contextValue: ShareApplicationContext?
    private let context = Promise<ShareApplicationContext?>()
    private let contextDisposable = MetaDisposable()
    
    
    override func loadView() {
        super.loadView()
        
        declareEncodable(ThemePaletteSettings.self, f: { ThemePaletteSettings(decoder: $0) })
    
        let appGroupName = "6N38VWS5BX.ru.keepcoder.Telegram"
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
            return
        }
        
        let logger = Logger(basePath: containerUrl.path + "/sharelogs")
        logger.logToConsole = false
        logger.logToFile = false
        Logger.setSharedLogger(logger)
        
        let extensionContext = self.extensionContext!
        
        self.accountManagerPromise.set(accountManager(basePath: containerUrl.path + "/accounts-metadata"))
        self.context.set(self.accountManagerPromise.get() |> deliverOnMainQueue |> mapToSignal { accountManager -> Signal<ShareApplicationContext?, NoError> in
            return applicationContext(accountManager: accountManager, appGroupPath: containerUrl.path, extensionContext: extensionContext)
        })
        
        self.contextDisposable.set(self.context.get().start(next: { context in
            assert(Queue.mainQueue().isCurrent())
            self.contextValue = context
            self.view.removeAllSubviews()
            if let rootView = context?.rootView {
                rootView.frame = self.view.bounds
                self.view.addSubview(rootView)
            }
        }))
        
    }
}

