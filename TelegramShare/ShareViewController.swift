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
    
    override var nibName: String? {
        return "ShareViewController"
    }
    
    
    fileprivate let authorization:Promise<Either<UnauthorizedAccount, Account>> = Promise()
    fileprivate let disposable = MetaDisposable()
    fileprivate let readyDisposable = MetaDisposable()
    fileprivate let ready:Promise<Bool> = Promise()
    override func loadView() {
        super.loadView()
    
        let appGroupName = "6N38VWS5BX.ru.keepcoder.Telegram"
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
            return
        }
        
        authorization.set(accountWithId(currentAccountId(appGroupPath: containerUrl.path, testingEnvironment:false), appGroupPath: containerUrl.path, testingEnvironment: false))
        
        disposable.set((authorization.get() |> deliverOnMainQueue).start(next: { (auth) in
            switch auth {
            case .left(_):
                assertionFailure()
            case let .right(account):
                setupAccount(account)
                account.shouldBeServiceTaskMaster.set(.single(.now))
                account.stateManager.reset()
                self.start(with: account)
            }
        }))
    }
    
    func start(with account:Account) {
        let share = SESelectController(ShareObject(account, extensionContext!))
        share.loadViewIfNeeded()
        readyDisposable.set((share.ready.get() |> deliverOnMainQueue).start(next: { (loaded) in
            self.view.addSubview(share.view)
        }))
    }
    
    deinit {
        disposable.dispose()
        readyDisposable.dispose()
    }

}

