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
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
})

func applicationContext(accountManager: AccountManager, appGroupPath: String, extensionContext: NSExtensionContext) -> Signal<ShareApplicationContext?, NoError> {
    
    return currentAccount(networkArguments: NetworkInitializationArguments(apiId: 2834, languagesCategory: "macos"), supplementary: true, manager: accountManager, rootPath: appGroupPath, testingEnvironment: false, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> mapToSignal { result -> Signal<ShareApplicationContext?, Void> in
        if let result = result {
            switch result {
            case .unauthorized(let account):
                return account.postbox.preferencesView(keys: [PreferencesKeys.localizationSettings]) |> take(1) |> deliverOnMainQueue |> map { value in
                    return .unauthorized(UnauthorizedApplicationContext(account: account, context: extensionContext,  localization: value.values[PreferencesKeys.localizationSettings] as? LocalizationSettings, theme: value.values[ApplicationSpecificPreferencesKeys.themeSettings] as? ThemePaletteSettings))
                }
            case let .authorized(account):
                let paslock:Signal<PostboxAccessChallengeData, Void> = account.postbox.transaction { transaction -> PostboxAccessChallengeData in
                    return transaction.getAccessChallengeData()
                } |> deliverOnMainQueue
                
                return paslock |> mapToSignal { access -> Signal<ShareApplicationContext?, Void> in
                    let promise:Promise<Void> = Promise()
                    let auth: Signal<ShareApplicationContext?, Void> = combineLatest(promise.get(), account.postbox.preferencesView(keys: [PreferencesKeys.localizationSettings, ApplicationSpecificPreferencesKeys.themeSettings]) |> take(1)) |> deliverOnMainQueue |> map { _, value in
                        return .authorized(AuthorizedApplicationContext(account: account, context: extensionContext,  localization: value.values[PreferencesKeys.localizationSettings] as? LocalizationSettings, theme: value.values[ApplicationSpecificPreferencesKeys.themeSettings] as? ThemePaletteSettings))
                    }
                    switch access {
                    case .none:
                        promise.set(.single(Void()))
                        return auth
                    default:
                        return account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.themeSettings, PreferencesKeys.localizationSettings]) |> take(1) |> deliverOnMainQueue |> map { value in
                            return .postboxAccess(PasscodeAccessContext(promise: promise, account: account, context: extensionContext,  localization: value.values[PreferencesKeys.localizationSettings] as? LocalizationSettings, theme: value.values[ApplicationSpecificPreferencesKeys.themeSettings] as? ThemePaletteSettings))
                        } |> then(auth)
                        
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
    init( account: UnauthorizedAccount, context: NSExtensionContext, localization:LocalizationSettings?, theme:ThemePaletteSettings?) {
        self.account = account
        if let localization = localization {
            applyShareUILocalization(localization)
        }
        if let themeSettings = theme {
            updateTheme(with: themeSettings)
        } else {
            setDefaultTheme(for: nil)
        }
        
        self.rootController = SEUnauthorizedViewController(cancelImpl: {
            let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
            context.cancelRequest(withError: cancelError)
        })
    }
    
}

class AuthorizedApplicationContext {
    let account: Account
    let rootController: SESelectController
    init(account: Account, context: NSExtensionContext, localization:LocalizationSettings?, theme:ThemePaletteSettings?) {
        self.account = account
        
        if let localization = localization {
            applyShareUILocalization(localization)
        }
        
        if let themeSettings = theme {
            updateTheme(with: themeSettings)
        } else {
            setDefaultTheme()
        }
        
        self.rootController = SESelectController(ShareObject(account, context))
        account.network.shouldKeepConnection.set(.single(true))
    }
}

class PasscodeAccessContext {
    let account: Account
    let promise:Promise<Void>
    let rootController: SEPasslockController
    init(promise:Promise<Void>, account: Account, context:NSExtensionContext, localization:LocalizationSettings?, theme:ThemePaletteSettings?) {
        self.account = account
        self.promise = promise
        if let localization = localization {
            applyShareUILocalization(localization)
        }
        if let themeSettings = theme {
            updateTheme(with: themeSettings)
        } else {
            setDefaultTheme()
        }
        
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
