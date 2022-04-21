//
//  SupportAccountContext.swift
//  Telegram
//
//  Created by Mike Renoir on 08.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit

final class SupportAccountContext {
    private let applicationContext: SharedApplicationContext
    
    private var contexts:[AuthorizedApplicationContext] = []
    private var windows: [Window] = []
    init(applicationContext: SharedApplicationContext) {
        self.applicationContext = applicationContext
    }
    
    func find(_ id: AccountRecordId) -> AccountContext? {
        if let value = self.contexts.first(where: { $0.context.account.id == id }) {
            return value.context
        }
        return nil
    }
    
    private let disposable: DisposableDict<AccountRecordId> = DisposableDict()
    
    func open(account: Account) {
        
        if let value = self.contexts.first(where: { $0.context.account.id == account.id }) {
            value.context.window.makeKeyAndOrderFront(nil)
            value.context.window.deminiaturize(nil)
            return
        }
        
        let sharedContext = applicationContext.sharedContext
        
        let window: Window
        if windows.isEmpty {
            window = Window(contentRect: NSMakeRect(0, 0, 400, 400), styleMask: [.closable, .miniaturizable, .resizable, .titled], backing: .buffered, defer: true)
            window.isReleasedWhenClosed = false
        } else {
            window = windows.removeFirst()
        }
        
        let context = AccountContext(sharedContext: sharedContext, window: window, account: account, isSupport: true)
        let applicationContext = AuthorizedApplicationContext(window: window, context: context, launchSettings: LaunchSettings.defaultSettings, callSession: sharedContext.getCrossAccountCallSession(), groupCallContext: sharedContext.getCrossAccountGroupCall())

        let out = account.loggedOut
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue
        
        disposable.set(out.start(next: { [weak self] value in
            self?.close(account: account)
        }), forKey: account.id)
        
        window.contentView?.addSubview(applicationContext.rootView, positioned: .below, relativeTo: window.contentView?.subviews.first)
        _ = applicationContext.ready.start(next: { [weak window] _ in
            window?.makeKeyAndOrderFront(self)
        })
        
        window.closeInterceptor = { [weak self] in
            self?.close(account: account)
            return true
        }

        telegramUpdateTheme(theme, window: window, animated: false)
        applicationContext.applyNewTheme()
        self.contexts.append(applicationContext)
    }
    func close(account: Account) {
        guard let index = self.contexts.firstIndex(where: { $0.context.account.id == account.id }) else {
            return
        }
        let value = self.contexts.remove(at: index)
        self.windows.append(value.context.window)
        value.context.window.orderOut(nil)
    }
    
    func enumerateAccountContext(_ f:(AccountContext)->Void) {
        for context in contexts {
            f(context.context)
        }
    }
    func enumerateApplicationContext(_ f:(AuthorizedApplicationContext)->Void) {
        for context in contexts {
            f(context)
        }
    }
    
    deinit {
        disposable.dispose()
    }
}
