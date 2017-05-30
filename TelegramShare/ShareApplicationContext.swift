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
}, fetchResource: { account, resource, range, _ in
    return nil
})

func applicationContext(accountManager: AccountManager, appGroupPath: String, extensionContext: NSExtensionContext) -> Signal<ShareApplicationContext?, NoError> {
    
    return currentAccount(networkArguments: NetworkInitializationArguments(networkArguments: NetworkInitializationArguments(apiId: 2834, languagesCategory: "macos"), languagesCategory: "macos"), supplementary: true, manager: accountManager, appGroupPath: appGroupPath, testingEnvironment: true, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> mapToSignal { result -> Signal<ShareApplicationContext?, Void> in
        if let result = result {
            switch result {
            case .unauthorized(let account):
                return .single(.unauthorized(UnauthorizedApplicationContext(account: account, context: extensionContext)))
            case let .authorized(account):
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
                        return .single(.postboxAccess(PasscodeAccessContext(promise: promise, account: account, context: extensionContext))) |> then(auth)
                    }
                }
            default:
                return .complete()
            }

        }
        
        return .single(nil)
    } |> deliverOnMainQueue

}




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
    let account: Account
    let rootController: SESelectController
    init(account: Account, context: NSExtensionContext) {
        self.account = account
        self.rootController = SESelectController(ShareObject(account, context))
        account.network.shouldKeepConnection.set(.single(true))
    }
}

class PasscodeAccessContext {
    let account: Account
    let promise:Promise<Void>
    let rootController: SEPasslockController
    init(promise:Promise<Void>, account: Account, context:NSExtensionContext) {
        self.account = account
        self.promise = promise
        self.rootController = SEPasslockController(account, .login, cancelImpl: {
            let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
            context.cancelRequest(withError: cancelError)
        })
        promise.set(rootController.doneValue |> filter {$0} |> map {_ in})
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
