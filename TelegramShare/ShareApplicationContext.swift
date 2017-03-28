//
//  ShareApplicationContext.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac



private let telegramAccountAuxiliaryMethods = AccountAuxiliaryMethods(updatePeerChatInputState: { interfaceState, inputState -> PeerChatInterfaceState? in
    return nil
}, fetchResource: { account, resource, range in
    return nil
})

func applicationContext(accountManager: AccountManager, appGroupPath: String, extensionContext: NSExtensionContext) -> Signal<ShareApplicationContext?, NoError> {
    
    return currentAccount(apiId: 2834, supplementary: true, manager: accountManager, appGroupPath: appGroupPath, testingEnvironment: true, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> mapToSignal { either -> Signal<ShareApplicationContext?, Void> in
        if let either = either {
            switch either {
            case let .left(account):
                return .single(.unauthorized(UnauthorizedApplicationContext(account: account)))
            case let .right(account):
                let paslock:Signal<PostboxAccessChallengeData, Void> = account.postbox.modify { modifier -> PostboxAccessChallengeData in
                    return modifier.getAccessChallengeData()
                } |> deliverOnMainQueue
                
                return paslock |> mapToSignal { access -> Signal<ShareApplicationContext?, Void> in
                    let promise:Promise<Void> = Promise()
                    let auth: Signal<ShareApplicationContext?, Void> = promise.get() |> map {
                        return .authorized(AuthorizedApplicationContext(account: account, context: extensionContext))
                    }
                    switch access {
                    case .none:
                        promise.set(.single())
                        return auth
                    default:
                        return .single(.postboxAccess(PasscodeAccessContext(promise: promise, account: account))) |> then(auth)
                    }
                }
            }

        }
        
        return .single(nil)
    }

}




final class UnauthorizedApplicationContext {
    let account: UnauthorizedAccount
    
    let rootController: ViewController
    init( account: UnauthorizedAccount) {
        self.account = account
        self.rootController = ViewController()
        
    }
    
}

class AuthorizedApplicationContext {
    let account: Account
    let rootController: SESelectController
    init(account: Account, context: NSExtensionContext) {
        self.account = account
        self.rootController = SESelectController(ShareObject(account, context))
    }
}

class PasscodeAccessContext {
    let account: Account
    let promise:Promise<Void>
    let rootController: ModalViewController
    init(promise:Promise<Void>, account: Account) {
        self.account = account
        self.promise = promise
        self.rootController = ModalViewController()
    }
}

enum ShareApplicationContext {
    case unauthorized(UnauthorizedApplicationContext)
    case authorized(AuthorizedApplicationContext)
    case postboxAccess(PasscodeAccessContext)
    
    func showRoot(for window:Window) {
        if let content = window.contentView {
            switch self {
            case let .postboxAccess(context):
                showModal(with: context.rootController, for: window)
            default:
                content.addSubview(rootView)
                rootView.frame = content.bounds
            }
        }
    }
    
    var rootView: NSView {
        switch self {
        case let .unauthorized(context):
            return context.rootController.view
        case let .authorized(context):
            return context.rootController.view
        case let .postboxAccess(context):
            return context.rootController.view
        }
    }
}
