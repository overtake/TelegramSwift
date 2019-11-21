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
import SyncCore
import SwiftSignalKit
import SyncCore
import OpenSSLEncryption

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
        
        
        
        declareEncodable(ThemePaletteSettings.self, f: { ThemePaletteSettings(decoder: $0) })
        declareEncodable(InAppNotificationSettings.self, f: { InAppNotificationSettings(decoder: $0) })

        
        let appGroupName = "6N38VWS5BX.ru.keepcoder.Telegram"
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
            return
        }
        
        let rootPath = containerUrl.path
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: Bundle.main.bundleIdentifier!)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)

        
        
        
        let accountManager = AccountManager(basePath: containerUrl.path + "/accounts-metadata")
        let networkArguments = NetworkInitializationArguments(apiId: ApiEnvironment.apiId, languagesCategory: ApiEnvironment.language, appVersion: ApiEnvironment.version, voipMaxLayer: 90, appData: .single(nil), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider())
        
        let sharedContext = SharedAccountContext(accountManager: accountManager, networkArguments: networkArguments, rootPath: rootPath, encryptionParameters: encryptionParameters, displayUpgradeProgress: { _ in })
        
        let logger = Logger(basePath: containerUrl.path + "/sharelogs")
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
            localization = transaction.getSharedData(SharedDataKeys.localizationSettings) as? LocalizationSettings
            localizationSemaphore.signal()
        }).start()
        localizationSemaphore.wait()
        
        if let localization = localization {
            applyShareUILocalization(localization)
        }
        
        updateTheme(with: themeSettings)
        
        
        
        let extensionContext = self.extensionContext!
        

        initializeAccountManagement()
        
        let rawAccounts = sharedContext.activeAccounts
            |> map { _, accounts, _ -> [Account] in
                return accounts.map({ $0.1 })
        }
        let _ = (sharedAccountInfos(accountManager: sharedContext.accountManager, accounts: rawAccounts)
            |> deliverOn(Queue())).start(next: { infos in
                storeAccountsData(rootPath: rootPath, accounts: infos)
        })
        
        
        var access: PostboxAccessChallengeData = .none
        let accessSemaphore = DispatchSemaphore(value: 0)
        _ = (accountManager.transaction { transaction in
            access = transaction.getAccessChallengeData()
            accessSemaphore.signal()
        }).start()
        accessSemaphore.wait()
        
        switch access {
        case .numericalPassword, .plaintextPassword:
            let passlock = SEPasslockController(sharedContext, cancelImpl: {
                let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
                extensionContext.cancelRequest(withError: cancelError)
            })
            
            self.passlock = passlock
            
            let passlockView = passlock.view
            
            _ = (passlock.doneValue |> filter { $0 } |> take(1)).start(next: { [weak passlockView] _ in
                passlockView?._change(opacity: 0, animated: true, removeOnCompletion: false, duration: 0.2, timingFunction: .spring, completion: { _ in
                    passlockView?.removeFromSuperview()
                    self.passlock = nil
                })
            })
            
            passlock.view.frame = self.view.bounds
            self.view.addSubview(passlock.view)
        default:
            break
        }
        
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
                    let context = AccountContext(sharedContext: sharedContext, window: Window(contentRect: NSZeroRect, styleMask: [], backing: NSWindow.BackingStoreType.buffered, defer: true), tonContext: nil, account: account)
                    return AuthorizedApplicationContext(context: context, shareContext: extensionContext)
                    
                } else {
                    return nil
                }
            })
        

        
      
        
    }

}

