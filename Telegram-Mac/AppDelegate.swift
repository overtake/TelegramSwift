import Cocoa
import FFMpegBinding
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TGUIKit
import Quartz
import MtProtoKit
import CoreServices
import LocalAuthentication
//import WalletCore
import OpenSSLEncryption
import CoreSpotlight

#if !APP_STORE
import AppCenter
import AppCenterCrashes
#endif



let enableBetaFeatures = true

private(set) var appDelegate: AppDelegate?

#if !SHARE
extension Account {
    var diceCache: DiceCache? {
        return appDelegate?.contextValue?.context.diceCache
    }
}
#endif



private struct AutologinToken : Equatable {


    private let token: String
    private let domains:[String]

    fileprivate init(token: String, domains: [String]) {
        self.token = token
        self.domains = domains
    }

    static func with(appConfiguration: AppConfiguration) -> AutologinToken? {
        if let data = appConfiguration.data, let value = data["autologin_token"] as? String {
            let dict:[String] = data["autologin_domains"] as? [String] ?? []
            return AutologinToken(token: value, domains: dict)
        } else {
            return nil
        }
    }

    func applyTo(_ link: String, isTestServer: Bool) -> String? {
        let url = URL(string: link)
        if let url = url, let host = url.host, domains.contains(host) {
            var queryItems = [URLQueryItem(name: "autologin_token", value: self.token)]
            if isTestServer {
                queryItems.append(URLQueryItem(name: "_test", value: "1"))
            }
            var urlComps = URLComponents(string: link)!
            urlComps.queryItems = (urlComps.queryItems ?? []) + queryItems
            return urlComps.url?.absoluteString
        }
        return nil
    }
}


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


@NSApplicationMain
class AppDelegate: NSResponder, NSApplicationDelegate, NSUserNotificationCenterDelegate, NSWindowDelegate {
   

    @IBOutlet weak var window: Window! {
        didSet {
            window.delegate = self
            window.isOpaque = true
            let notInitial = window.initSaver()
            
            if !notInitial {
                let size = NSMakeSize(700, 550)
                if let screen = NSScreen.main {
                    window.setFrame(NSMakeRect((screen.frame.width - size.width) / 2, (screen.frame.height - size.height) / 2, size.width, size.height), display: true)
                }
            }
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
    private var sharedApplicationContextValue: SharedApplicationContext?

    
    var passlock: Signal<Bool, NoError> {
        return sharedContextPromise.get() |> mapToSignal {
            return $0.notificationManager.passlocked
        }
    }
    
    fileprivate var contextValue: AuthorizedApplicationContext?
    private let context = Promise<AuthorizedApplicationContext?>()
    
    private var authContextValue: UnauthorizedApplicationContext?
    private let authContext = Promise<UnauthorizedApplicationContext?>()

    private var activeValue: ValuePromise<Bool> = ValuePromise(true, ignoreRepeated: true)

    var isActive: Signal<Bool, NoError> {
        return self.activeValue.get()
    }
    private let encryptionValue:Promise<ValueBoxEncryptionParameters> = Promise()
    
    private let handleEventContextDisposable = MetaDisposable()
    private let proxyDisposable = MetaDisposable()
    private var activity:Any?
    private var executeUrlAfterLogin: String? = nil
    
    private(set) var appEncryption: AppEncryptionParameters!

    func applicationWillFinishLaunching(_ notification: Notification) {
       
    }
    
    var baseAppBundleId: String {
        return  Bundle.main.bundleIdentifier!
    }

   
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        
        appDelegate = self
        ApiEnvironment.migrate()
        
        initializeSelectManager()
        startLottieCacheCleaner()
        
        if #available(OSX 10.12.2, *) {
            NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }
        
        
        guard let containerUrl = ApiEnvironment.containerURL else {
            return
        }
        
        
        
        self.containerUrl = containerUrl.path
        
        TempBox.initializeShared(basePath: self.containerUrl, processType: "app", launchSpecificId: arc4random64())
        

        let v = View()
        v.flip = false
        window.contentView = v
        window.contentView?.autoresizingMask = [.width, .height]
        window.contentView?.autoresizesSubviews = true
        
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
            return _NSLocalizedString(key!)
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
            if let secret = Bundle.main.infoDictionary?["APPCENTER_SECRET"] as? String {
                AppCenter.start(withAppSecret: secret, services: [Crashes.self])
            }
        #endif
        
        
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(saveIntermediateDate), userInfo: nil, repeats: true)

        telegramUIDeclareEncodables()
        
        MTLogSetEnabled(UserDefaults.standard.bool(forKey: "enablelogs"))

        let logger = Logger(rootPath: containerUrl.path, basePath: containerUrl.path + "/logs")
        logger.logToConsole = false
        logger.logToFile = UserDefaults.standard.bool(forKey: "enablelogs")
        
        #if DEBUG
            MTLogSetEnabled(true)
            logger.logToConsole = false
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
        _ = System.scaleFactor.swap(window.backingScaleFactor)
        window.minSize = NSMakeSize(380, 500)
        
        let appEncryption = AppEncryptionParameters(path: rootPath)

        let accountManager = AccountManager(basePath: containerUrl + "/accounts-metadata", isTemporary: false, isReadOnly: false)

        if let deviceSpecificEncryptionParameters = appEncryption.decrypt() {
            let parameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
            self.launchApp(accountManager: accountManager, encryptionParameters: parameters, appEncryption: appEncryption)
        } else {
            
            
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
            
            self.window.makeKeyAndOrderFront(self)
            
            showModal(with: ColdStartPasslockController(checkNextValue: { passcode in
                appEncryption.applyPasscode(passcode)
                if let params = appEncryption.decrypt() {
                    let parameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: params.key)!, salt: ValueBoxEncryptionParameters.Salt(data: params.salt)!)
                    self.launchApp(accountManager: accountManager, encryptionParameters: parameters, appEncryption: appEncryption)
                    return true
                } else {
                    return false
                }
            }, logoutImpl: {
                return Signal { subscriber in
                    try? FileManager.default.removeItem(atPath: rootPath)
                    subscriber.putCompletion()
                    DispatchQueue.main.async {
                        let appEncryption = AppEncryptionParameters(path: rootPath)
                        let accountManager = AccountManager(basePath: self.containerUrl + "/accounts-metadata", isTemporary: false, isReadOnly: false)
                        if let params = appEncryption.decrypt() {
                            let parameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: params.key)!, salt: ValueBoxEncryptionParameters.Salt(data: params.salt)!)
                            self.launchApp(accountManager: accountManager, encryptionParameters: parameters, appEncryption: appEncryption)
                        }
                    }
                    return EmptyDisposable
                } |> runOn(prepareQueue)
            }), for: window)
        }
    }
    
    private func launchApp(accountManager: AccountManager, encryptionParameters: ValueBoxEncryptionParameters, appEncryption: AppEncryptionParameters) {
        
        
        self.appEncryption = appEncryption
        
        let rootPath = containerUrl!
        let window = self.window!
        _ = System.scaleFactor.swap(window.backingScaleFactor)
        
        
        window.minSize = NSMakeSize(380, 500)
        
        let networkDisposable = MetaDisposable()
        
        
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
            
            let passcodeSemaphore = DispatchSemaphore(value: 0)
            
            _ = accountManager.transaction { modifier -> Void in
                let passcode = modifier.getAccessChallengeData()
                
                switch passcode {
                case let .numericalPassword(value), let .plaintextPassword(value):
                    if !value.isEmpty {
                        appEncryption.change(value)
                        modifier.setAccessChallengeData(.plaintextPassword(value: ""))
                    }
                default:
                    break
                }
                passcodeSemaphore.signal()
            }.start()
            passcodeSemaphore.wait()

           
            
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
            let backingProperties:ValuePromise<CGFloat> = ValuePromise(System.backingScale, ignoreRepeated: true)
            
            
            var previousBackingScale = System.backingScale
            _ = combineLatest(queue: .mainQueue(), themeSettingsView(accountManager: accountManager), backingProperties.get()).start(next: { settings, backingScale in
                let previous = basicTheme.swap(settings)
                if previous?.palette != settings.palette || previous?.bubbled != settings.bubbled || previous?.wallpaper != settings.wallpaper || previous?.fontSize != settings.fontSize || previousBackingScale != backingScale  {
                    updateTheme(with: settings, for: window, animated: window.isKeyWindow && ((previous?.fontSize == settings.fontSize && previous?.palette != settings.palette) || previous?.bubbled != settings.bubbled || previous?.cloudTheme?.id != settings.cloudTheme?.id || previous?.palette.isDark != settings.palette.isDark))
                    self.contextValue?.applyNewTheme()
                }
                previousBackingScale = backingScale
            })
            
            NotificationCenter.default.addObserver(forName: NSWindow.didChangeBackingPropertiesNotification, object: window, queue: nil, using: { notification in
                backingProperties.set(System.backingScale)
            })
            
            let autoNightSignal = viewDidChangedAppearance.get() |> mapToSignal { _ in
                return combineLatest(autoNightSettings(accountManager: accountManager), Signal<Void, NoError>.single(Void()) |> then( Signal<Void, NoError>.single(Void()) |> delay(60, queue: Queue.mainQueue()) |> restart))
                } |> deliverOnMainQueue
            
            
            _ = autoNightSignal.start(next: { preference, _ in
                
                var isEnabled: Bool
                var isDark: Bool = false

                if let schedule = preference.schedule {
                    
                    isEnabled = true
                    
                    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    var now: time_t = time_t(nowTimestamp)
                    var timeinfoNow: tm = tm()
                    localtime_r(&now, &timeinfoNow)
                    let t = timeinfoNow.tm_hour * 60 * 60 + timeinfoNow.tm_min * 60 + timeinfoNow.tm_sec
                    
                    switch schedule {
                    case let .sunrise(coordinate):
                        if coordinate.latitude == 0 || coordinate.longitude == 0 {
                            isEnabled = theme.colors.isDark
                        } else {
                            if let sunrise = EDSunriseSet(date: Date(), timezone: NSTimeZone.local, latitude: coordinate.latitude, longitude: coordinate.longitude) {
                                let from = Int32(sunrise.sunset.timeIntervalSince1970 - sunrise.sunset.startOfDay.timeIntervalSince1970)
                                let to = Int32(sunrise.sunrise.timeIntervalSince1970 - sunrise.sunrise.startOfDay.timeIntervalSince1970)
                                isDark = to > from && t >= from && t <= to || to < from && (t >= from || t <= to)
                            } else {
                                isDark = false
                            }
                        }
                    case let .timeSensitive(from, to):
                        let from = from * 60 * 60
                        let to = to * 60 * 60
                        isDark = to > from && t >= from && t < to || to < from && (t >= from || t < to)
                    }
                    
                } else if preference.systemBased {
                    isEnabled = true
                    if #available(OSX 10.14, *) {
                        switch systemAppearance.name {
                        case NSAppearance.Name.aqua:
                            isDark = false
                        case NSAppearance.Name.darkAqua:
                            isDark = true
                        default:
                            isDark = false
                        }
                    } else {
                        isDark = false
                    }
                } else {
                    isEnabled = false
                }
                
                _ = updateThemeInteractivetly(accountManager: accountManager, f: { settings -> ThemePaletteSettings in
                    var settings = settings
                    if isEnabled {
                        settings = settings.withUpdatedToDefault(dark: isDark)
                        if isDark {
                            if let theme = preference.theme.cloud {
                                settings = settings.withUpdatedCloudTheme(theme.cloud).withUpdatedPalette(theme.palette).updateWallpaper { current in
                                    return ThemeWallpaper(wallpaper: theme.wallpaper.wallpaper, associated: theme.wallpaper)
                                }
                            } else {
                                settings = settings.withUpdatedPalette(preference.theme.local.palette).withUpdatedCloudTheme(nil).installDefaultWallpaper().installDefaultAccent()
                            }
                        }
                    }
                    return settings
                }).start()
            })
            
            
            let basicLocalization = Atomic<LocalizationSettings?>(value: localization)
            _ = (accountManager.sharedData(keys: [SharedDataKeys.localizationSettings]) |> deliverOnMainQueue).start(next: { view in
                if let settings = view.entries[SharedDataKeys.localizationSettings] as? LocalizationSettings {
                    if basicLocalization.swap(settings) != settings {
                        applyUILocalization(settings)
                    }
                }
            })
            
            
            let voipVersions = OngoingCallContext.versions(includeExperimental: true, includeReference: false).map { version, supportsVideo -> CallSessionManagerImplementationVersion in
                CallSessionManagerImplementationVersion(version: version, supportsVideo: supportsVideo)
            }
            
            let networkArguments = NetworkInitializationArguments(apiId: ApiEnvironment.apiId, apiHash: ApiEnvironment.apiHash, languagesCategory: ApiEnvironment.language, appVersion: ApiEnvironment.version, voipMaxLayer: OngoingCallContext.maxLayer, voipVersions: voipVersions, appData: .single(ApiEnvironment.appData), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider())
            
            let sharedContext = SharedAccountContext(accountManager: accountManager, networkArguments: networkArguments, rootPath: rootPath, encryptionParameters: encryptionParameters, appEncryption: appEncryption, displayUpgradeProgress: displayUpgrade)
            
            self.hangKeybind(sharedContext)
            
            
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
                    let navigation = contextValue.context.sharedContext.bindings.rootNavigation()
                    
                    if let controller = navigation.controller as? ChatController {
                        if controller.chatInteraction.peerId == peerId {
                            controller.scrollup()
                        } else {
                            navigation.push(ChatAdditionController(context: contextValue.context, chatLocation: .peer(peerId)))
                        }
                    } else {
                        navigation.push(ChatController(context: contextValue.context, chatLocation: .peer(peerId)))
                    }
                    
                } else {
                    sharedContext.switchToAccount(id: account.id, action: .chat(peerId, necessary: true))
                }
                NSApp.activate(ignoringOtherApps: true)
                window.deminiaturize(nil)
            }, navigateToThread: { account, threadId, fromId in
                if let contextValue = self.contextValue, contextValue.context.account.id == account.id {
                    
                    let pushController: (ChatLocation, ChatMode, MessageId, Atomic<ChatLocationContextHolder?>, Bool) -> Void = { chatLocation, mode, messageId, contextHolder, addition in
                        let navigation = contextValue.context.sharedContext.bindings.rootNavigation()
                        let controller: ChatController
                        if addition {
                            controller = ChatAdditionController(context: contextValue.context, chatLocation: chatLocation, mode: mode, messageId: messageId, initialAction: nil, chatLocationContextHolder: contextHolder)
                        } else {
                            controller = ChatController(context: contextValue.context, chatLocation: chatLocation, mode: mode, messageId: messageId, initialAction: nil, chatLocationContextHolder: contextHolder)
                        }
                        navigation.push(controller)
                    }
                    
                    let navigation = contextValue.context.sharedContext.bindings.rootNavigation()
                    
                    let currentInChat = navigation.controller is ChatController
                    let controller = navigation.controller as? ChatController
                    
                    if controller?.chatInteraction.mode.threadId == threadId {
                        controller?.scrollup()
                    } else {
                        
                        let signal:Signal<ReplyThreadInfo, FetchChannelReplyThreadMessageError> = fetchAndPreloadReplyThreadInfo(context: contextValue.context, subject: .channelPost(threadId))
                        
                        _ = showModalProgress(signal: signal |> take(1), for: contextValue.context.window).start(next: { result in
                            let chatLocation: ChatLocation = .replyThread(result.message)
                            
                            let updatedMode: ReplyThreadMode
                            if result.isChannelPost {
                                updatedMode = .comments(origin: fromId)
                            } else {
                                updatedMode = .replies(origin: fromId)
                            }
                            pushController(chatLocation, .replyThread(data: result.message, mode: updatedMode), fromId, result.contextHolder, currentInChat)
                            
                        }, error: { error in
                            
                        })
                    }
                    
                } else {
                    sharedContext.switchToAccount(id: account.id, action: .thread(threadId, fromId, necessary: true))
                }
                NSApp.activate(ignoringOtherApps: true)
                window.deminiaturize(nil)
            }, updateCurrectController: {
                if let contextValue = self.contextValue {
                    contextValue.context.sharedContext.bindings.rootNavigation().controller.updateController()
                }
            }, applyMaxReadIndexInteractively: { index in
                if let context = self.contextValue?.context {
                    _ = context.engine.messages.applyMaxReadIndexInteractively(index: index).start()
                }

            })
            
            let sharedNotificationManager = SharedNotificationManager(activeAccounts: sharedContext.activeAccounts |> map { ($0.0, $0.1.map { ($0.0, $0.1) }) }, appEncryption: appEncryption, accountManager: accountManager, window: window, bindings: notificationsBindings)
            let sharedWakeupManager = SharedWakeupManager(sharedContext: sharedContext, inForeground: self.presentAccountStatus.get())
            let sharedApplicationContext = SharedApplicationContext(sharedContext: sharedContext, notificationManager: sharedNotificationManager, sharedWakeupManager: sharedWakeupManager)
            
            self.sharedApplicationContextValue = sharedApplicationContext
            
            self.sharedContextPromise.set(accountManager.transaction { transaction -> (SharedApplicationContext, LoggingSettings) in
                return (sharedApplicationContext, transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings ?? LoggingSettings.defaultSettings)
            }
            |> mapToSignal { sharedApplicationContext, loggingSettings -> Signal<SharedApplicationContext, NoError> in
                #if BETA || ALPHA
                Logger.shared.logToFile = true
                #else
                Logger.shared.logToFile = loggingSettings.logToFile
                #endif
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
                                //  let tonContext = StoredTonContext(basePath: account.basePath, postbox: account.postbox, network: account.network, keychain: tonKeychain)
                                
                                let context = AccountContext(sharedContext: sharedApplicationContext.sharedContext, window: window, account: account)
                                return AuthorizedApplicationContext(window: window, context: context, launchSettings: settings ?? LaunchSettings.defaultSettings, callSession: sharedContext.getCrossAccountCallSession(), groupCallContext: sharedContext.getCrossAccountGroupCall())
                                
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
                    } else if context == nil {
                        globalAudio?.stop()
                    }
                    
                    (HackUtils.findElements(byClass: "Telegram.OpmizeDatabaseView", in: self.window.contentView!).first as? NSView)?.removeFromSuperview()
                    
                    closeModal(ColdStartPasslockController.self)
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
                            #if STABLE
                            updater_resetWithUpdaterSource(.internal(context: context.context))
                            #else
                            updater_resetWithUpdaterSource(.external(context: context.context))
                            #endif
                            
                        }))
                        #endif
                        
                        if let url = AppDelegate.eventProcessed {
                            self.processURL(url)
                        }
                        if let action = AppDelegate.spotlightAction {
                            self.processSpotlightAction(action)
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
                                    #if STABLE
                                    if let context = self.contextValue?.context {
                                        updater_resetWithUpdaterSource(.internal(context: context))
                                    } else {
                                        updater_resetWithUpdaterSource(.external(context: nil))
                                    }
                                    #else
                                    updater_resetWithUpdaterSource(.external(context: self.contextValue?.context))
                                    #endif
                                    
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
                
                (window.contentView as? View)?.viewDidChangedEffectiveAppearance = {
                    viewDidChangedAppearance.set(true)
                }
            }
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.windiwDidChangeBackingProperties), name: NSWindow.didChangeBackingPropertiesNotification, object: window)
            
            self.window.contentView?.wantsLayer = true
            
            sharedWakeupManager.onSleepValueUpdated = { value in
                self.updatePeerPresence()
            }
            sharedNotificationManager.didUpdateLocked = { value in
                self.updatePeerPresence()
            }
        })
        
    }

    func navigateProfile(_ peerId: PeerId, account: Account) {
        if let context = self.contextValue?.context, context.peerId == account.peerId {
            context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
            context.window.makeKeyAndOrderFront(nil)
            context.window.orderFrontRegardless()
        } else {
            sharedApplicationContextValue?.sharedContext.switchToAccount(id: account.id, action: .profile(peerId, necessary: true))
        }
    }
    func navigateChat(_ peerId: PeerId, account: Account) {
        if let context = self.contextValue?.context, context.peerId == account.peerId {
            context.sharedContext.bindings.rootNavigation().push(ChatAdditionController.init(context: context, chatLocation: .peer(peerId)))
            context.window.makeKeyAndOrderFront(nil)
            context.window.orderFrontRegardless()
        } else {
            sharedApplicationContextValue?.sharedContext.switchToAccount(id: account.id, action: .chat(peerId, necessary: true))
        }
    }
    
    
    private func updatePeerPresence() {
        if let sharedApplicationContextValue = sharedApplicationContextValue {
            let isOnline = NSApp.isActive && NSApp.isRunning && !NSApp.isHidden && !sharedApplicationContextValue.sharedWakeupManager.isSleeping && !sharedApplicationContextValue.notificationManager._lockedValue.screenLock && !sharedApplicationContextValue.notificationManager._lockedValue.passcodeLock
            #if DEBUG
            NSLog("accountIsOnline: \(isOnline)")
            #endif
            presentAccountStatus.set(.single(isOnline) |> then(.single(isOnline) |> delay(50, queue: Queue.concurrentBackgroundQueue())) |> restart)
        }
    }
    
    @objc public func windiwDidChangeBackingProperties() {
        _ = System.scaleFactor.swap(window.backingScaleFactor)
    }
    


    @IBAction func checkForUpdates(_ sender: Any) {
        #if !APP_STORE
            showModal(with: InputDataModalController(AppUpdateViewController()), for: window)
            #if STABLE
                if let context = self.contextValue?.context {
                    updater_resetWithUpdaterSource(.internal(context: context))
                } else {
                    updater_resetWithUpdaterSource(.external(context: nil))
                }
            #else
                updater_resetWithUpdaterSource(.external(context: self.contextValue?.context))
            #endif
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
    private static var spotlightAction: SpotlightIdentifier? = nil

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
    
    private func hangKeybind(_ sharedContext: SharedAccountContext) {
        let signal = combineLatest(queue: .mainQueue(), voiceCallSettings(sharedContext.accountManager), sharedContext.groupCallContext)
        
        _ = signal.start(next: { settings, activeCall in
            if let pushToTalk = settings.pushToTalk, let _ = activeCall {
                self.window.isPushToTalkEquaivalent = { event in
                    if !pushToTalk.modifierFlags.isEmpty, pushToTalk.keyCodes.contains(event.keyCode) {
                        for modifier in pushToTalk.modifierFlags {
                            if modifier.flag == event.modifierFlags.rawValue {
                                return true
                            }
                        }
                    }
                    return false
                }
            } else {
                self.window.isPushToTalkEquaivalent = nil
            }
            
        })

        
        
    }
    
    
    func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
        var rect = rect
        rect.origin.y -= 22
        return rect;
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        updatePeerPresence()
    }
    
    func tryApplyAutologinToken(_ url: String) -> String? {
        if let config = contextValue?.context.appConfiguration {
            if let value = AutologinToken.with(appConfiguration: config) {
                return value.applyTo(url, isTestServer: contextValue?.context.account.testingEnvironment ?? false)
            }
        }
        return nil
    }
    
    func applicationDidHide(_ notification: Notification) {
        updatePeerPresence()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !self.window.isVisible {
            self.window.makeKeyAndOrderFront(self)
            self.window.orderFrontRegardless()
        }
        if viewer != nil {
            viewer?.windowDidResignKey()
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
            if !self.window.isVisible {
                self.window.makeKeyAndOrderFront(self)
                self.window.orderFrontRegardless()
            }
            if viewer != nil {
                viewer?.windowDidResignKey()
            }
            self.activeValue.set(true)
            
        }
    }
    
    
    
    
    func applicationDidResignActive(_ notification: Notification) {
        updatePeerPresence()
        if viewer != nil {
            viewer?.window.orderOut(nil)
        }
        self.activeValue.set(false)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        deinitCrashHandler(containerUrl)
        
        #if !APP_STORE
            updateAppIfNeeded()
        #endif
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        
        if let context = self.contextValue?.context {
            let navigation = context.sharedContext.bindings.rootNavigation()
        }
        
        return .terminateNow
    }
    
    
    func windowDidDeminiaturize(_ notification: Notification) {
        window.orderOut(nil)
        window.makeKeyAndOrderFront(nil)
    }
    
    func windowDidMiniaturize(_ notification: Notification) {
        window.resignMain()
    }
    
    
    var hasAuthorized: Bool {
        return contextValue?.context != nil
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
    @IBAction func globalSearch(_ sender: Any) {
        if let context = contextValue?.context {
            context.sharedContext.bindings.mainController().focusSearch(animated: true)
        }
    }
    @IBAction func closeWindow(_ sender: Any) {
        NSApp.keyWindow?.close()
    }
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType {
            if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                if let identifier = parseSpotlightIdentifier(uniqueIdentifier) {
                    self.processSpotlightAction(identifier)
                }
            }
        }
        
        return true
    }
        
    private func processSpotlightAction(_ identifier: SpotlightIdentifier) {
        if let context = contextValue?.context {
            AppDelegate.spotlightAction = nil
            if context.account.id == identifier.recordId {
                switch identifier.source {
                case let .peerId(peerId):
                    context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
                }
            } else {
                switch identifier.source {
                case let .peerId(peerId):
                    context.sharedContext.switchToAccount(id: identifier.recordId, action: .chat(peerId, necessary: true))
                }
            }
        } else {
            AppDelegate.spotlightAction = identifier
        }
        
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
    }
    
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
