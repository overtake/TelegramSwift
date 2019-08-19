import Cocoa

import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit
import Quartz
import MtProtoKitMac
import CoreServices
import LocalAuthentication

#if !APP_STORE
    import HockeySDK
#endif




private final class SharedApplicationContext {
    let sharedContext: SharedAccountContext
    let notificationManager: SharedNotificationManager
    let sharedWakeupManager: SharedWakeupManager
    init(sharedContext: SharedAccountContext, notificationManager: SharedNotificationManager, sharedWakeupManager: SharedWakeupManager) {
        self.sharedContext = sharedContext
        self.notificationManager = notificationManager
        self.sharedWakeupManager = sharedWakeupManager
    }
}

/*
 _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
 
 
 [_statusItem setTarget:self];
 [_statusItem setAction:@selector(didStatusItemClicked)];
 
 NSImage *menuIcon = [NSImage imageNamed:@"StatusIcon"];
 [menuIcon setTemplate:YES];
 
 NSMenu *statusMenu = [StandartViewController attachMenu];
 
 
 [statusMenu addItem:[NSMenuItem separatorItem]];
 
 [statusMenu addItem:[NSMenuItem menuItemWithTitle:NSLocalizedString(@"Quit", nil) withBlock:^(id sender) {
 
 [[NSApplication sharedApplication] terminate:self];
 
 }]];
 
 [_statusItem setMenu:statusMenu];
 
 [_statusItem setImage:menuIcon];
 */

#if !APP_STORE
extension AppDelegate : BITHockeyManagerDelegate {
    
}
#endif

@NSApplicationMain
class AppDelegate: NSResponder, NSApplicationDelegate, NSUserNotificationCenterDelegate, NSWindowDelegate {
   

    @IBOutlet weak var window: Window! {
        didSet {
            window.delegate = self
            window.isOpaque = true
            window.initSaver()
        }
    }
    
    override init() {
        super.init()
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_: with:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    let presentAccountStatus = Promise(false)
    fileprivate let nofityDisposable:MetaDisposable = MetaDisposable()
    var containerUrl:String!
    
    private let sharedContextPromise = Promise<SharedApplicationContext>()
    private var sharedContextOnce: Signal<SharedApplicationContext, NoError> {
        return sharedContextPromise.get() |> take(1) |> deliverOnMainQueue
    }

    
    private var contextValue: AuthorizedApplicationContext?
    private let context = Promise<AuthorizedApplicationContext?>()
    
    private var authContextValue: UnauthorizedApplicationContext?
    private let authContext = Promise<UnauthorizedApplicationContext?>()

    
    
    private let handleEventContextDisposable = MetaDisposable()
    private let proxyDisposable = MetaDisposable()
    private var activity:Any?
    private var executeUrlAfterLogin: String? = nil

    func applicationWillFinishLaunching(_ notification: Notification) {
       
    }
    
    var baseAppBundleId: String {
        return  Bundle.main.bundleIdentifier!
    }

   
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
//        final class Test {
//
//            init() {
//            }
//            deinit {
//                NSLog("dealloc test")
//                var bp:Int = 0
//                bp += 1
//            }
//        }
//
//
//        let signal = Signal<(Test?, Test?, Test?, Bool), NoError>.single((Test(), Test(), nil, false))
//        signal.start()

      
        initializeSelectManager()
        startLottieCacheCleaner()
        
        if #available(OSX 10.12.2, *) {
            NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }
        
        let appGroupName = "6N38VWS5BX.\(baseAppBundleId)"
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
            return
        }
        
        self.containerUrl = containerUrl.path

        
      
        
                
        let crashed = isCrashedLastTime(containerUrl.path)
        deinitCrashHandler(containerUrl.path)
        
        if crashed {
            let alert: NSAlert = NSAlert()
            alert.addButton(withTitle: L10n.crashOnLaunchOK)
            alert.addButton(withTitle: L10n.crashOnLaunchCancel)
            alert.messageText = L10n.crashOnLaunchMessage
            alert.informativeText = L10n.crashOnLaunchInformation
            alert.alertStyle = .critical
            if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
                try? FileManager.default.removeItem(atPath: self.containerUrl)
            }
        }
        
        saveIntermediateDate()

        uiLocalizationFunc = { key in
            return _NSLocalizedString(key)
        }
        
        DateUtils.setDateLocalizationFunc ({ key -> String in
            return _NSLocalizedString(key)
        })
        
        setInputLocalizationFunc { (key) -> String in
            return _NSLocalizedString(key)
        }
        
        var paths: [String?] = []
        paths.append(Bundle.main.path(forResource: "opening", ofType:"m4a"))
        paths.append(Bundle.main.path(forResource: "voip_busy", ofType:"caf"))
        paths.append(Bundle.main.path(forResource: "voip_ringback", ofType:"caf"))
        paths.append(Bundle.main.path(forResource: "voip_connecting", ofType:"mp3"))
        paths.append(Bundle.main.path(forResource: "voip_fail", ofType:"caf"))
        paths.append(Bundle.main.path(forResource: "voip_end", ofType:"caf"))
        paths.append(Bundle.main.path(forResource: "sent", ofType:"caf"))

        
        for path in paths {
            if let path = path {
                let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                player?.prepareToPlay()
            }
        }
        
        FFMpegGlobals.initializeGlobals()
        
        
       // applyMainMenuLocalization(window)
        
        mw = window
        
        #if !APP_STORE
          //  self.updater.automaticallyChecksForUpdates = true
           // self.updater.automaticallyDownloadsUpdates = false
           // self.updater.checkForUpdatesInBackground()
        #endif
        
        
      //  Timer.scheduledTimer(timeInterval: 60 * 60, target: self, selector: #selector(checkUpdates), userInfo: nil, repeats: true)
        
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(saveIntermediateDate), userInfo: nil, repeats: true)

                


        
        let hockeyAppId:String
        #if BETA
            hockeyAppId = "6ed2ac3049e1407387c2f1ffcb74e81f"
        #elseif ALPHA
            hockeyAppId = "f012091f35d947bbb3db9cbd3b0232d3"
        #endif
        
        #if BETA || ALPHA
            BITHockeyManager.shared().configure(withIdentifier: hockeyAppId)
            BITHockeyManager.shared().crashManager.isAutoSubmitCrashReport = true
            BITHockeyManager.shared().start()
            BITHockeyManager.shared()?.delegate = self
        #endif
//
//            #if STABLE     
//                let hockeyAppId:String = "d77af558b21e0878953100680b5ac66a"
//                BITHockeyManager.shared().configure(withIdentifier: hockeyAppId)
//                BITHockeyManager.shared().crashManager.isAutoSubmitCrashReport = false
//            #endif
            
     //   #endif
        

        telegramUIDeclareEncodables()
        
        MTLogSetEnabled(UserDefaults.standard.bool(forKey: "enablelogs"))

        let logger = Logger(basePath: containerUrl.path + "/logs")
        logger.logToConsole = TEST_SERVER
        logger.logToFile = UserDefaults.standard.bool(forKey: "enablelogs")
        
        #if DEBUG
            MTLogSetEnabled(true)
            logger.logToFile = true
        #endif
        
        initializeMimeStore()
        
//        #if APP_STORE || STABLE
//            logger.logToConsole = false
//            MTLogSetEnabled(false)
//        #endif
        
        Logger.setSharedLogger(logger)
        
                
        let bundleId = Bundle.main.bundleIdentifier
        if let bundleId = bundleId {
            LSSetDefaultHandlerForURLScheme("tg" as CFString, bundleId as CFString)
        }
        
        

        launchInterface()
        
    }
    
    
    private func launchInterface() {
        initializeAccountManagement()
        
        let rootPath = containerUrl!
        let window = self.window!
        
        
        window.minSize = NSMakeSize(380, 500)

        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        
                
        _ = System.scaleFactor.swap(window.backingScaleFactor)

        
        let networkDisposable = MetaDisposable()
        
        let accountManager = AccountManager(basePath: containerUrl + "/accounts-metadata")

        
        let displayUpgrade:(Float?) -> Void = { progress in
            if let progress = progress {
                let view = HackUtils.findElements(byClass: "Telegram.OpmizeDatabaseView", in: self.window.contentView!).first as? OpmizeDatabaseView ?? OpmizeDatabaseView(frame: self.window.bounds)
                view.setProgress(progress)
                self.window.contentView?.addSubview(view, positioned: .below, relativeTo: self.window.contentView?.subviews.first)
                self.window.makeKeyAndOrderFront(self)
            } else {
                (HackUtils.findElements(byClass: "Telegram.OpmizeDatabaseView", in: self.window.contentView!).first as? NSView)?.removeFromSuperview()
            }
        }
        
        
        let _ = (upgradedAccounts(accountManager: accountManager, rootPath: rootPath, encryptionParameters: encryptionParameters) |> deliverOnMainQueue).start(next: { value in
            if value > 0 {
                displayUpgrade(value)
            } else {
                displayUpgrade(nil)
            }
        }, completed: {
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
                applyUILocalization(localization)
            }
            
            updateTheme(with: themeSettings, for: window)
            
            
            
            
            
            let basicTheme = Atomic<ThemePaletteSettings?>(value: themeSettings)
            let viewDidChangedAppearance: ValuePromise<Bool> = ValuePromise(true)
            _ = (viewDidChangedAppearance.get() |> mapToSignal { _ in return themeSettingsView(accountManager: accountManager) } |> deliverOnMainQueue).start(next: { settings in
                if basicTheme.swap(settings) != settings {
                    updateTheme(with: settings, for: window, animated: window.isKeyWindow)
                    self.contextValue?.applyNewTheme()
                }
            })
            
            
            _ = combineLatest(autoNightSettings(accountManager: accountManager), Signal<Void, NoError>.single(Void()) |> then( Signal<Void, NoError>.single(Void()) |> delay(60, queue: Queue.mainQueue()) |> restart)).start(next: { preference, _ in
                if let schedule = preference.schedule {
                    
                    let isDarkTheme: Bool
                    
                    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    var now: time_t = time_t(nowTimestamp)
                    var timeinfoNow: tm = tm()
                    localtime_r(&now, &timeinfoNow)
                    let t = timeinfoNow.tm_hour * 60 * 60 + timeinfoNow.tm_min * 60 + timeinfoNow.tm_sec
                    
                    switch schedule {
                    case let .sunrise(coordinate):
                        if coordinate.latitude == 0 || coordinate.longitude == 0 {
                            isDarkTheme = theme.colors.isDark
                        } else {
                            if let sunrise = EDSunriseSet(date: Date(), timezone: NSTimeZone.local, latitude: coordinate.latitude, longitude: coordinate.longitude) {
                                let from = Int32(sunrise.sunset.timeIntervalSince1970 - sunrise.sunset.startOfDay.timeIntervalSince1970)
                                let to = Int32(sunrise.sunrise.timeIntervalSince1970 - sunrise.sunrise.startOfDay.timeIntervalSince1970)
                                isDarkTheme = to > from && t >= from && t <= to || to < from && (t >= from || t <= to)
                            } else {
                                isDarkTheme = false
                            }
                        }
                        
                        
                    case let .timeSensitive(from, to):
                        let from = from * 60 * 60
                        let to = to * 60 * 60
                        isDarkTheme = to > from && t >= from && t < to || to < from && (t >= from || t < to)
                    }
                    _ = updateThemeInteractivetly(accountManager: accountManager, f: { settings -> ThemePaletteSettings in
                        
                        let palette: ColorPalette
                        var palettes:[String : ColorPalette] = [:]
                        palettes[dayClassic.name] = dayClassic
                        palettes[whitePalette.name] = whitePalette
                        palettes[darkPalette.name] = darkPalette
                        palettes[nightBluePalette.name] = nightBluePalette
                        palettes[mojavePalette.name] = mojavePalette
                        
                        if isDarkTheme {
                            palette = palettes[preference.themeName] ?? nightBluePalette
                        } else {
                            palette = palettes[settings.defaultDayName] ?? dayClassic
                        }
                        if theme.colors.name != palette.name {
                            return settings.withUpdatedPalette(palette)
                        } else {
                            return settings
                        }
                        
                        
                    }).start()
                }
            })
            
            
            let basicLocalization = Atomic<LocalizationSettings?>(value: localization)
            _ = (accountManager.sharedData(keys: [SharedDataKeys.localizationSettings]) |> deliverOnMainQueue).start(next: { view in
                if let settings = view.entries[SharedDataKeys.localizationSettings] as? LocalizationSettings {
                    if basicLocalization.swap(settings) != settings {
                        applyUILocalization(settings)
                    }
                }
            })
            
            
            let networkArguments = NetworkInitializationArguments(apiId: API_ID, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: CallBridge.voipMaxLayer(), appData: .single(nil))
            
            let sharedContext = SharedAccountContext(accountManager: accountManager, networkArguments: networkArguments, rootPath: rootPath, encryptionParameters: encryptionParameters, displayUpgradeProgress: displayUpgrade)
            
            
            let rawAccounts = sharedContext.activeAccounts
                |> map { _, accounts, _ -> [Account] in
                    return accounts.map({ $0.1 })
            }
            let _ = (sharedAccountInfos(accountManager: sharedContext.accountManager, accounts: rawAccounts)
                |> deliverOn(Queue())).start(next: { infos in
                    storeAccountsData(rootPath: rootPath, accounts: infos)
                })
            
            
            let notificationsBindings = SharedNotificationBindings(navigateToChat: { account, peerId in
                
                if let contextValue = self.contextValue, contextValue.context.account.id == account.id {
                    contextValue.context.sharedContext.bindings.rootNavigation().push(ChatController(context: contextValue.context, chatLocation: .peer(peerId)))
                } else {
                    sharedContext.switchToAccount(id: account.id, action: .chat(peerId, necessary: true))
                }
                NSApp.activate(ignoringOtherApps: true)
                window.deminiaturize(nil)
            })
            
            let sharedNotificationManager = SharedNotificationManager(activeAccounts: sharedContext.activeAccounts |> map { ($0.0, $0.1.map { ($0.0, $0.1) }) }, accountManager: accountManager, window: window, bindings: notificationsBindings)
            let sharedWakeupManager = SharedWakeupManager(sharedContext: sharedContext, inForeground: self.presentAccountStatus.get())
            let sharedApplicationContext = SharedApplicationContext(sharedContext: sharedContext, notificationManager: sharedNotificationManager, sharedWakeupManager: sharedWakeupManager)
            
            
            
            self.sharedContextPromise.set(accountManager.transaction { transaction -> (SharedApplicationContext, LoggingSettings) in
                return (sharedApplicationContext, transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings ?? LoggingSettings.defaultSettings)
                }
                |> mapToSignal { sharedApplicationContext, loggingSettings -> Signal<SharedApplicationContext, NoError> in
                    Logger.shared.logToFile = loggingSettings.logToFile
                    Logger.shared.logToConsole = false//loggingSettings.logToConsole
                    Logger.shared.redactSensitiveData = true//loggingSettings.redactSensitiveData
                    return .single(sharedApplicationContext)
                })
            
            
            
            
            self.context.set(self.sharedContextPromise.get()
                |> deliverOnMainQueue
                |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext?, NoError> in
                    return sharedApplicationContext.sharedContext.activeAccounts
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
                                var settings: LaunchSettings?
                                if let action = sharedContext.getLaunchActionOnce(for: account.id) {
                                    settings = LaunchSettings(applyText: nil, previousText: nil, navigation: action, openAtLaunch: true)
                                } else {
                                    let semaphore = DispatchSemaphore(value: 0)
                                    _ = account.postbox.transaction { transaction in
                                        settings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings) as? LaunchSettings
                                        semaphore.signal()
                                        }.start()
                                    semaphore.wait()
                                }
                                
                                let context = AccountContext(sharedContext: sharedApplicationContext.sharedContext, window: window, account: account)
                                return AuthorizedApplicationContext(window: window, context: context, launchSettings: settings ?? LaunchSettings.defaultSettings)
                                
                            } else {
                                return nil
                            }
                    }
                })
            
            
            self.authContext.set(self.sharedContextPromise.get()
                |> deliverOnMainQueue
                |> mapToSignal { sharedApplicationContext -> Signal<UnauthorizedApplicationContext?, NoError> in
                    return sharedApplicationContext.sharedContext.activeAccounts
                        |> map { primary, accounts, auth -> (Account?, UnauthorizedAccount, [Account])? in
                            if let auth = auth {
                                return (primary, auth, Array(accounts.map({ $0.1 })))
                            } else {
                                return nil
                            }
                        }
                        |> distinctUntilChanged(isEqual: { lhs, rhs in
                            if lhs?.1 !== rhs?.1 {
                                return false
                            }
                            return true
                        })
                        |> mapToSignal { authAndAccounts -> Signal<(UnauthorizedAccount, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))?, NoError> in
                            if let (primary, auth, accounts) = authAndAccounts {
                                let phoneNumbers = combineLatest(accounts.map { account -> Signal<(AccountRecordId, String, Bool)?, NoError> in
                                    return account.postbox.transaction { transaction -> (AccountRecordId, String, Bool)? in
                                        if let phone = (transaction.getPeer(account.peerId) as? TelegramUser)?.phone {
                                            return (account.id, phone, account.testingEnvironment)
                                        } else {
                                            return nil
                                        }
                                    }
                                })
                                return phoneNumbers
                                    |> map { phoneNumbers -> (UnauthorizedAccount, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))? in
                                        var primaryNumber: (String, AccountRecordId, Bool)?
                                        if let primary = primary {
                                            for idAndNumber in phoneNumbers {
                                                if let (id, number, testingEnvironment) = idAndNumber, id == primary.id {
                                                    primaryNumber = (number, id, testingEnvironment)
                                                    break
                                                }
                                            }
                                        }
                                        return (auth, (primaryNumber, phoneNumbers.compactMap({ $0.flatMap({ ($0.1, $0.0, $0.2) }) })))
                                }
                            } else {
                                return .single(nil)
                            }
                        }
                        |> mapToSignal { accountAndOtherAccountPhoneNumbers -> Signal<(UnauthorizedAccount, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))?, NoError> in
                            if let (account, otherAccountPhoneNumbers) = accountAndOtherAccountPhoneNumbers {
                                return .single((account, otherAccountPhoneNumbers))
                            } else {
                                return .single(nil)
                            }
                        }
                        |> deliverOnMainQueue
                        |> mapToSignal { accountAndSettings -> Signal<UnauthorizedApplicationContext?, NoError> in
                            if let accountAndSettings = accountAndSettings {
                                return .single(UnauthorizedApplicationContext(window: window, sharedContext: sharedApplicationContext.sharedContext, account: accountAndSettings.0, otherAccountPhoneNumbers: accountAndSettings.1))
                            } else {
                                return .single(nil)
                            }
                    }
                })
            
            
            
            
            _ = (self.context.get() |> mapToSignal { context -> Signal<AuthorizedApplicationContext?, NoError> in
                if let context = context {
                    return context.ready |> map { [weak context] _ in
                        return context
                    }
                } else {
                    return .single(nil)
                }
                
                } |> deliverOnMainQueue).start(next: { context in
                    assert(Queue.mainQueue().isCurrent())
                    
                    if let contextValue = self.contextValue {
                        contextValue.context.isCurrent = false
                        contextValue.rootView.removeFromSuperview()
                    }
                    
                    (HackUtils.findElements(byClass: "Telegram.OpmizeDatabaseView", in: self.window.contentView!).first as? NSView)?.removeFromSuperview()
                    
                    
                    //closeAllModals()
                    closeAllPopovers(for: window)
                    
                    self.contextValue = context
                    
                    
                    if let context = context {
                        context.context.isCurrent = true
                        context.applyNewTheme()
                        self.window.contentView?.addSubview(context.rootView, positioned: .below, relativeTo: self.window.contentView?.subviews.first)
                        context.runLaunchAction()
                        if let executeUrlAfterLogin = self.executeUrlAfterLogin {
                            self.executeUrlAfterLogin = nil
                            execute(inapp: inApp(for: executeUrlAfterLogin.nsstring, context: context.context))
                        }
                        #if !APP_STORE
                        networkDisposable.set((context.context.account.postbox.preferencesView(keys: [PreferencesKeys.networkSettings]) |> delay(5.0, queue: Queue.mainQueue()) |> deliverOnMainQueue).start(next: { settings in
                            let settings = settings.values[PreferencesKeys.networkSettings] as? NetworkSettings
                            
                            let applicationUpdateUrlPrefix: String?
                            if let prefix = settings?.applicationUpdateUrlPrefix {
                                if prefix.range(of: "://") == nil {
                                    applicationUpdateUrlPrefix = "https://" + prefix
                                } else {
                                    applicationUpdateUrlPrefix = prefix
                                }
                            } else {
                                applicationUpdateUrlPrefix = nil
                            }
                            setAppUpdaterBaseDomain(applicationUpdateUrlPrefix)
                            updater_resetWithUpdaterSource(.external(account: context.context.account))
                            
                        }))
                        #endif
                        
                        if let url = AppDelegate.eventProcessed {
                            self.processURL(url)
                        }
                        
                        if !self.window.isKeyWindow {
                            self.window.makeKeyAndOrderFront(self)
                        }
                        self.window.deminiaturize(self)
                        NSApp.activate(ignoringOtherApps: true)
                        
                        
                    }
                })
            
            
            var presentAuthAnimated: Bool = false
            
            let authContextReadyDisposable = MetaDisposable()
            
            _ = (self.authContext.get()
                |> deliverOnMainQueue).start(next: { context in
                    
                    (HackUtils.findElements(byClass: "Telegram.OpmizeDatabaseView", in: self.window.contentView!).first as? NSView)?.removeFromSuperview()
                    
                    if let authContextValue = self.authContextValue {
                        authContextValue.account.shouldBeServiceTaskMaster.set(.single(.never))
                        authContextValue.modal.close()
                    }
                    self.authContextValue = context
                    if let context = context {
                        let isReady: Signal<Bool, NoError> = .single(true)
                        authContextReadyDisposable.set((isReady
                            |> filter { $0 }
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { _ in
                                
                                window.makeKeyAndOrderFront(nil)
                                showModal(with: context.modal, for: window, animated: presentAuthAnimated)
                                
                                #if !APP_STORE
                                networkDisposable.set((context.account.postbox.preferencesView(keys: [PreferencesKeys.networkSettings]) |> delay(5.0, queue: Queue.mainQueue()) |> deliverOnMainQueue).start(next: { settings in
                                    let settings = settings.values[PreferencesKeys.networkSettings] as? NetworkSettings
                                    
                                    let applicationUpdateUrlPrefix: String?
                                    if let prefix = settings?.applicationUpdateUrlPrefix {
                                        if prefix.range(of: "://") == nil {
                                            applicationUpdateUrlPrefix = "https://" + prefix
                                        } else {
                                            applicationUpdateUrlPrefix = prefix
                                        }
                                    } else {
                                        applicationUpdateUrlPrefix = nil
                                    }
                                    setAppUpdaterBaseDomain(applicationUpdateUrlPrefix)
                                    updater_resetWithUpdaterSource(.external(account: nil))

                                }))
                                #endif
                                
                                
                            }))
                    } else {
                        presentAuthAnimated = true
                        authContextReadyDisposable.set(nil)
                    }
                })
            
            
            
            
            
            //
            
            
            self.saveIntermediateDate()
            
            
            if #available(OSX 10.14, *) {
                DistributedNotificationCenter.default().addObserver(forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: nil, using: { _ in
                    delay(0.1, closure: {
                        forceUpdateStatusBarIconByDockTile(sharedContext: sharedContext)
                        viewDidChangedAppearance.set(true)
                    })
                })
            }
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.windiwDidChangeBackingProperties), name: NSWindow.didChangeBackingPropertiesNotification, object: window)
            
            
            
            let fontSizes:[Int32] = [11, 12, 13, 14, 15, 16, 17, 18]
            
            
            window.set(handler: { () -> KeyHandlerResult in
                _ = updateThemeInteractivetly(accountManager: accountManager, f: { current -> ThemePaletteSettings in
                    if let index = fontSizes.firstIndex(of: Int32(current.fontSize)) {
                        if index == fontSizes.count - 1 {
                            return current
                        } else {
                            return current.withUpdatedFontSize(CGFloat(fontSizes[index + 1]))
                        }
                    } else {
                        return current
                    }
                }).start()
                if let index = fontSizes.firstIndex(of: Int32(theme.fontSize)), index == fontSizes.count - 1 {
                    return .rejected
                }
                return .invoked
            }, with: self, for: .Equal, modifierFlags: [.command])
            
            window.set(handler: { () -> KeyHandlerResult in
                _ = updateThemeInteractivetly(accountManager: accountManager, f: { current -> ThemePaletteSettings in
                    if let index = fontSizes.firstIndex(of: Int32(current.fontSize)) {
                        if index == 0 {
                            return current
                        } else {
                            return current.withUpdatedFontSize(CGFloat(fontSizes[index - 1]))
                        }
                    } else {
                        return current
                    }
                }).start()
                if let index = fontSizes.firstIndex(of: Int32(theme.fontSize)), index == 0 {
                    return .rejected
                }
                return  .invoked
            }, with: self, for: .Minus, modifierFlags: [.command])
            
            self.window.contentView?.wantsLayer = true
        })
        
        
    }
    
    
    @objc public func windiwDidChangeBackingProperties() {
        _ = System.scaleFactor.swap(window.backingScaleFactor)
    }
    


    @IBAction func checkForUpdates(_ sender: Any) {
        #if !APP_STORE
        showModal(with: InputDataModalController(AppUpdateViewController()), for: window)
        updater_resetWithUpdaterSource(.external(account: self.contextValue?.context.account))
        #endif
    }
    
    override func awakeFromNib() {
        #if APP_STORE
        if let menu = NSApp.mainMenu?.item(at: 0)?.submenu, let sparkleItem = menu.item(withTag: 1000) {
            menu.removeItem(sparkleItem)
        }
        #endif
    }
    
    
    @objc func checkUpdates() {
        #if !APP_STORE
        showModal(with: InputDataModalController(AppUpdateViewController()), for: window)
        #endif
    }
    
    
    
    @objc func saveIntermediateDate() {
        crashIntermediateDate(containerUrl)
    }
    
    private static var eventProcessed: String? = nil
    
    @objc func handleURLEvent(_ event:NSAppleEventDescriptor, with replyEvent:NSAppleEventDescriptor) {
        let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue
        processURL(url)
    }
    
    private func processURL(_ url: String?) {
        AppDelegate.eventProcessed = url
        
        if let url = AppDelegate.eventProcessed {
            NSApp.activate(ignoringOtherApps: true)
            self.window.deminiaturize(self)
            if let context = self.contextValue?.context {
                AppDelegate.eventProcessed = nil
                
                let link = inApp(for: url as NSString, context: context, openInfo: { (peerId, isChat, postId, action) in
                    context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId), messageId:postId, initialAction:action), true)
                }, applyProxy: { proxy in
                    applyExternalProxy(proxy, accountManager: context.sharedContext.accountManager)
                })
                execute(inapp: link)
            } else if let authContext = self.authContextValue {
                let settings = proxySettings(from: url)
                if settings.1 {
                    AppDelegate.eventProcessed = nil
                    if let proxy = settings.0 {
                        applyExternalProxy(proxy, accountManager: authContext.sharedContext.accountManager)
                    } else {
                        _ = updateProxySettingsInteractively(accountManager: authContext.sharedContext.accountManager, { current -> ProxySettings in
                            return current.withUpdatedActiveServer(nil)
                        }).start()
                    }
                }
                
                if url.range(of: legacyPassportUsername) != nil || url.range(of: "tg://passport") != nil {
                    alert(for: mainWindow, info: L10n.secureIdLoginText)
                    self.executeUrlAfterLogin = url
                }
            }
        }
    }
    
    
    func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
        var rect = rect
        rect.origin.y -= 22
        return rect;
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        presentAccountStatus.set(.single(true) |> then(.single(true) |> delay(50, queue: Queue.concurrentBackgroundQueue())) |> restart)
    }
    

    
    func applicationDidHide(_ notification: Notification) {
        presentAccountStatus.set(.single(false))
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if viewer != nil {
            viewer?.windowDidResignKey()
        } else if let passport = passport {
            passport.window.makeKeyAndOrderFront(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
        
        return true
    }
    
    
    override func acceptsPreviewPanelControl(_ panel:QLPreviewPanel) ->Bool {
        return true
    }
    
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = QuickLookPreview.current
        panel.dataSource = QuickLookPreview.current
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = nil
        panel.dataSource = nil
        QuickLookPreview.current.hide()
    }
    
   

   
    @IBAction func paste(_ sender: Any) {
        if let window = NSApp.keyWindow as? Window {
            window.pasteToFirstResponder(sender)
        }
    }
    @IBAction func copy(_ sender: Any) {
        if let window = NSApp.keyWindow as? Window {
            window.copyFromFirstResponder(sender)
        }
    }
    
    func applicationWillUnhide(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationWillBecomeActive(_ notification: Notification) {
        if contextValue != nil {
            if viewer != nil {
                viewer?.windowDidResignKey()
            } else if let passport = passport {
                passport.window.makeKeyAndOrderFront(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            
            
        }
    }
    
    
    
    func applicationDidResignActive(_ notification: Notification) {
        presentAccountStatus.set(.single(false))
        if viewer != nil {
            viewer?.window.orderOut(nil)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        deinitCrashHandler(containerUrl)
        
        #if !APP_STORE
            updateAppIfNeeded()
        #endif
    }
    
    
    func windowDidDeminiaturize(_ notification: Notification) {
        window.orderOut(nil)
        window.makeKeyAndOrderFront(nil)
    }
    
    func windowDidMiniaturize(_ notification: Notification) {
        window.resignMain()
    }
    
    
    @IBAction func unhide(_ sender: Any) {
         window.makeKeyAndOrderFront(sender)
    }
    
    @IBAction func aboutAction(_ sender: Any) {
        showModal(with: AboutModalController(), for: window)
        window.makeKeyAndOrderFront(sender)
    }
    @IBAction func preferencesAction(_ sender: Any) {
        
        if let context = contextValue?.context {
            context.sharedContext.bindings.mainController().showPreferences()
        }
        window.makeKeyAndOrderFront(sender)

    }
    @IBAction func closeWindow(_ sender: Any) {
        NSApp.keyWindow?.close()
    }
    
    func getLogFilesContentWithMaxSize() -> String {
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: String = ""
        _ = Logger.shared.collectShortLog().start(next: { logs in
            for log in logs.suffix(500) {
                result += log.1 + "\n"
            }
            semaphore.signal()
        })
        semaphore.wait()
        
        return result
        
//        var description = ""
//        if let sortedLogFileInfos = fileLogger.logFileManager.sortedLogFileInfos {
//            for logFile in sortedLogFileInfos {
//                if let logData = FileManager.default.contents(atPath: logFile.filePath) {
//                    if logData.count > 0 {
//                        description.append(String(data: logData, encoding: String.Encoding.utf8)!)
//                    }
//                }
//            }
//        }
//        if (description.characters.count > maxSize) {
//            description = description.substring(from: description.index(description.startIndex, offsetBy: description.characters.count - maxSize - 1))
//        }
//        return description;
    }
    
    #if !APP_STORE
    func applicationLog(for crashManager: BITCrashManager!) -> String! {
        return getLogFilesContentWithMaxSize()
    }
    #endif
    @IBAction func showQuickSwitcher(_ sender: Any) {
        
        if let context = contextValue?.context, authContextValue == nil {
            _ = sharedContextOnce.start(next: { applicationContext in
                if !applicationContext.notificationManager.isLocked {
                    showModal(with: QuickSwitcherModalController(context), for: self.window)
                }
            })
        }
        window.makeKeyAndOrderFront(sender)
    }
}
