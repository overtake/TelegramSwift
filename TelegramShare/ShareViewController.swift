//
//  ShareViewController.swift
//  TelegramShare
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import ApiCredentials
import SwiftSignalKit
import ThemeSettings
import OpenSSLEncryption
import BuildConfig
import Localization
class ShareViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return "ShareViewController"
    }
    
    
    
    private var contextValue: AuthorizedApplicationContext?
    private let context = Promise<AuthorizedApplicationContext?>()
    private let contextDisposable = MetaDisposable()
    
    private var passlock: SEPasslockController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        

        guard let containerUrl = ApiEnvironment.containerURL else {
            return
        }
        initializeAccountManagement()

        
        
        let rootPath = containerUrl.path
        let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: containerUrl.path + "/accounts-metadata", isTemporary: false, isReadOnly: true, useCaches: true, removeDatabaseOnError: true)

        let logger = Logger(rootPath: containerUrl.path, basePath: containerUrl.path + "/logs")
        logger.logToConsole = false
        logger.logToFile = false
        Logger.setSharedLogger(logger)
        
        let themeSemaphore = DispatchSemaphore(value: 0)
        var themeSettings: ThemePaletteSettings = ThemePaletteSettings.defaultTheme
        _ = (themeSettingsView(accountManager: accountManager) |> take(1)).start(next: { settings in
            themeSettings = settings
            themeSemaphore.signal()
        })
        themeSemaphore.wait()
        
        var localization: LocalizationSettings? = nil
        let localizationSemaphore = DispatchSemaphore(value: 0)
        _ = (accountManager.transaction { transaction in
            localization = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self)
            localizationSemaphore.signal()
        }).start()
        localizationSemaphore.wait()
        
        if let localization = localization {
            applyShareUILocalization(localization)
        }
        
        telegramUpdateTheme(updateTheme(with: themeSettings), window: nil, animated: false)

        
        let appEncryption = AppEncryptionParameters(path: rootPath)
        
        if let deviceSpecificEncryptionParameters = appEncryption.decrypt() {
            let parameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
            launchExtension(accountManager: accountManager, encryptionParameters: parameters, appEncryption: appEncryption)
        } else {
            let extensionContext = self.extensionContext!
            
            self.passlock = SEPasslockController(checkNextValue: { passcode in
                appEncryption.applyPasscode(passcode)
                if let params = appEncryption.decrypt() {
                    let parameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: params.key)!, salt: ValueBoxEncryptionParameters.Salt(data: params.salt)!)
                    self.launchExtension(accountManager: accountManager, encryptionParameters: parameters, appEncryption: appEncryption)
                    return true
                } else {
                    return false
                }
            }, cancelImpl: {
                let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
                extensionContext.cancelRequest(withError: cancelError)
            })
            
            self.passlock!.view.frame = self.view.bounds
            self.view.addSubview(self.passlock!.view)
        }
    }

    
    private func launchExtension(accountManager: AccountManager<TelegramAccountManagerTypes>, encryptionParameters: ValueBoxEncryptionParameters, appEncryption: AppEncryptionParameters) {
        
        let extensionContext = self.extensionContext!

        let containerUrl = ApiEnvironment.containerURL!
        
        let rootPath = containerUrl.path

        let appData: Signal<Data?, NoError> = Signal { subscriber in
            subscriber.putNext(ApiEnvironment.appData)
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(.concurrentBackgroundQueue())
        
        let networkArguments = NetworkInitializationArguments(apiId: ApiEnvironment.apiId, apiHash: ApiEnvironment.apiHash, languagesCategory: ApiEnvironment.language, appVersion: ApiEnvironment.version, voipMaxLayer: 90, voipVersions: [], appData: appData, autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider(), resolvedDeviceName: ApiEnvironment.resolvedDeviceName)
        
        let sharedContext = SharedAccountContext(accountManager: accountManager, networkArguments: networkArguments, rootPath: rootPath, encryptionParameters: encryptionParameters, appEncryption: appEncryption, displayUpgradeProgress: { _ in })
        
      

        
        let rawAccounts = sharedContext.activeAccounts
            |> map { _, accounts, _ -> [Account] in
                return accounts.map({ $0.1 })
        }
        let _ = (sharedAccountInfos(accountManager: sharedContext.accountManager, accounts: rawAccounts)
            |> deliverOn(Queue())).start(next: { infos in
                storeAccountsData(rootPath: rootPath, accounts: infos)
            })
        
        
        
        let readyDisposable = MetaDisposable()
        _ = (self.context.get() |> mapToSignal { context -> Signal<AuthorizedApplicationContext?, NoError> in
            return .single(context)
            
            } |> deliverOnMainQueue).start(next: { context in
                assert(Queue.mainQueue().isCurrent())
                
                if let context = context {
                    context.rootController.view.frame = self.view.bounds
                    
                    readyDisposable.set((context.rootController.ready.get() |> take(1)).start(next: { [weak context] _ in
                        guard let context = context else { return }
                        if let contextValue = self.contextValue {
                            contextValue.rootController.view.removeFromSuperview()
                        }
                        self.contextValue = context
                        if let passlock = self.passlock, passlock.isLoaded() {
                            self.passlock?.view.removeFromSuperview()
                        }
                        self.view.addSubview(context.rootController.view, positioned: .below, relativeTo: self.view.subviews.first)
                        
                    }))
                }
            })
        
        
        self.context.set(sharedContext.activeAccounts
            |> map { primary, _, _ -> Account? in
                return primary
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs !== rhs {
                    return false
                }
                return true
            })
            |> map { account in
                if let account = account {
                    let context = AccountContext(sharedContext: sharedContext, window: Window(contentRect: NSZeroRect, styleMask: [], backing: NSWindow.BackingStoreType.buffered, defer: true), account: account)
                    return AuthorizedApplicationContext(context: context, shareContext: extensionContext)
                    
                } else {
                    return nil
                }
            })
    }

}

