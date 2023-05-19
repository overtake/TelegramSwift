//
//  ShareApplicationContext.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit



let telegramAccountAuxiliaryMethods = AccountAuxiliaryMethods(fetchResource: { account, resource, range, _ in
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
}, prepareSecretThumbnailData: { _ in
    return nil
})



final class UnauthorizedApplicationContext {
    let account: UnauthorizedAccount
    
    let rootController: SEUnauthorizedViewController
    init( account: UnauthorizedAccount, context: NSExtensionContext) {
        self.account = account

        self.rootController = SEUnauthorizedViewController(cancelImpl: {
            let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
            context.cancelRequest(withError: cancelError)
        })
    }
    
}

class AuthorizedApplicationContext {
    let context: AccountContext
    let rootController: SESelectController
    init(context: AccountContext, shareContext: NSExtensionContext) {
        self.context = context
        
        self.rootController = SESelectController(ShareObject(context, shareContext))
        context.account.network.shouldKeepConnection.set(.single(true))
    }
}

