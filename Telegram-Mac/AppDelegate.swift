import Cocoa
import FFMpegBinding
import SwiftSignalKit
import Postbox
import TelegramCore
import DateUtils
import TGUIKit
import Quartz
import MtProtoKit
import CoreServices
import LocalAuthentication
import OpenSSLEncryption
import CoreSpotlight
import BuildConfig
import Localization
import ApiCredentials
import EDSunriseSet
import ObjcUtils
import HackUtils
import TGModernGrowingTextView
import CrashHandler
import InAppSettings
import ThemeSettings
import ColorPalette
import WebKit
import TelegramSystem
import CodeSyntax
import MetalEngine
import TelegramMedia
import RLottie
import KeyboardKey

#if BETA || DEBUG
import Firebase
import FirebaseCrashlytics
#endif


//
//@available(macOS 13, *)
//class AppIntentObserver : NSObject {
//    
//    private let defaults = UserDefaults(suiteName: ApiEnvironment.intentsBundleId)!
//    
//    private var current: AppIntentDataModel?
//    
//    override init() {
//        super.init()
//        let modelData = defaults.value(forKey: AppIntentDataModel.keyInternal) as? Data
//        if let modelData, let model = AppIntentDataModel.decoded(modelData) {
//            self.current = model
//        }
//        defaults.addObserver(self, forKeyPath: AppIntentDataModel.key, options: .new, context: nil)
//    }
//    
//    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        if keyPath == AppIntentDataModel.key {
//            update()
//        }
//    }
//    
//    deinit {
//        defaults.removeObserver(self, forKeyPath: AppIntentDataModel.key)
//    }
//    
//    var onUpdate:((AppIntentDataModel?)->Void)?
//    
//    func update() {
//        let modelData = defaults.value(forKey: AppIntentDataModel.key) as? Data
//        let model: AppIntentDataModel?
//        if let modelData, let value = AppIntentDataModel.decoded(modelData) {
//            model = value
//        } else {
//            model = nil
//        }
//        if let model = model {
//            defaults.setValue(model.encoded(), forKey: AppIntentDataModel.keyInternal)
//        }
//        if model != self.current {
//            self.onUpdate?(model)
//        }
//        self.current = model
//    }
//    
//    public static let shared: AppIntentObserver = AppIntentObserver()
//}

final class CodeSyntax {
    private let syntaxer: Syntaxer
    private init() {
        let pathFile = Bundle.main.path(forResource: "grammars", ofType: "dat")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: pathFile))
        self.syntaxer = Syntaxer(data)!
    }
    private static let standart: CodeSyntax = .init()
    
    fileprivate static func initialize() {
        _ = CodeSyntax.standart
    }
    
    
    static func syntax(code: String, language: String, theme: SyntaxterTheme) -> NSAttributedString {
        return standart.syntaxer.syntax(code, language: language, theme: theme)
    }
    static func apply(_ code: NSAttributedString, to: NSMutableAttributedString, offset: Int) {
        code.enumerateAttributes(in: code.range, using: { value, innerRange, _ in
            if let font = value[.foregroundColor] as? NSColor {
                to.addAttribute(.foregroundColor, value: font, range: NSMakeRange(offset + innerRange.location, innerRange.length))
            } else if let font = value[.font] as? NSFont {
                to.addAttribute(.font, value: font, range: NSMakeRange(offset + innerRange.location, innerRange.length))
            }
        })
    }
}

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

    static func with(appConfiguration: AppConfiguration, autologinToken: String?) -> AutologinToken? {
        if let data = appConfiguration.data, let value = autologinToken {
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


final class SharedApplicationContext {
    let sharedContext: SharedAccountContext
    let notificationManager: SharedNotificationManager
    let sharedWakeupManager: SharedWakeupManager
    init(sharedContext: SharedAccountContext, notificationManager: SharedNotificationManager, sharedWakeupManager: SharedWakeupManager) {
        self.sharedContext = sharedContext
        self.notificationManager = notificationManager
        self.sharedWakeupManager = sharedWakeupManager
    }
}

private final class CtxInstallLayer : SimpleLayer {
    private var timer: SwiftSignalKit.Timer?
    override init() {
        super.init()
        self.contentsScale = 1
        self.frame = NSMakeRect(-1, -1, 1, 1)
        self.isOpaque = false
        self.timer = SwiftSignalKit.Timer(timeout: 10, repeat: true, completion: { [weak self] in
            self?.setNeedsDisplay()
        }, queue: .mainQueue())
        
        self.timer?.start()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(in ctx: CGContext) {
//        if FastSettings.useNativeGraphicContext {
//        #if !APP_STORE
//            DeviceGraphicsContextSettings.install(ctx)
//        #endif
//        } else {
//            DeviceGraphicsContextSettings.install(nil)
//        }
    }
}

extension RLottieBridge : R_LottieBridge {
   
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
    private(set) var sharedApplicationContextValue: SharedApplicationContext?
    private(set) var supportAccountContextValue: SupportAccountContext? {
        didSet {
            supportAccountContextValue?.didUpdate = { _ in
                self.updateActiveContexts()
            }
        }
    }
    
    var passlock: Signal<Bool, NoError> {
        return sharedContextPromise.get() |> mapToSignal {
            return $0.notificationManager.passlocked
        }
    }
    
    fileprivate var contextValue: AuthorizedApplicationContext? {
        didSet {
            updateActiveContexts()
        }
    }
    private let context = Promise<AuthorizedApplicationContext?>()
    
    private var authContextValue: UnauthorizedApplicationContext?
    private let authContext = Promise<UnauthorizedApplicationContext?>()
    
    private func effectiveContext(_ account: Account) -> AccountContext? {
        var current: AccountContext?
        enumerateAccountContexts({ context in
            if context.account.id == account.id {
                current = context
            }
        })
        return current
    }

    private var activeValue: ValuePromise<Bool> = ValuePromise(true, ignoreRepeated: true)

    var isActive: Signal<Bool, NoError> {
        return self.activeValue.get()
    }
    private let encryptionValue:Promise<ValueBoxEncryptionParameters> = Promise()
    
    private let handleEventContextDisposable = MetaDisposable()
    private let proxyDisposable = MetaDisposable()
    private var activity:Any?
    private var executeUrlAfterLogin: String? = nil
    private var timer: SwiftSignalKit.Timer?
    
    private(set) var appEncryption: AppEncryptionParameters!

    func applicationWillFinishLaunching(_ notification: Notification) {
        CodeSyntax.initialize()
        
        
        
        
       // UserDefaults.standard.set(true, forKey: "NSTableViewCanEstimateRowHeights")
     //   UserDefaults.standard.removeObject(forKey: "NSTableViewCanEstimateRowHeights")
    }
    
    var allowedDomains: [String] {
        if let context = contextValue?.context {
            let value = context.appConfiguration.data?["whitelisted_domains"] as? [String]
            return value ?? []
        }
        return []
    }
    
    var baseAppBundleId: String {
        return  Bundle.main.bundleIdentifier!
    }

    var currentContext:AccountContext? {
        var context: AccountContext?
        self.enumerateAccountContexts({ ctx in
            if ctx.isCurrent {
                context = ctx
            }
        })
        return context
    }
    
    private var ctxLayer: CtxInstallLayer?
    
    func updateGraphicContext() {
        ctxLayer?.display()
    }
    
    

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            return BrowserStateContext.checkKey(event)
        })
        
        UserDefaults.standard.set(true, forKey: "NSApplicationCrashOnExceptions")
        
        
       // NSApplication.shared.applicationIconImage = NSImage(named: "PremiumBlack")
      
//        window.styleMask.insert(.fullSizeContentView)
//        window.styleMask.insert(.unifiedTitleAndToolbar)
        //window.styleMask.insert(.borderless)
//        let customToolbar = NSToolbar(identifier: "main")
//        customToolbar.showsBaselineSeparator = false
////        window.titlebarAppearsTransparent = true
////        window.titleVisibility = .hidden
//        window.toolbar = customToolbar
        
        
        
//        titleBarAccessoryViewController.view = View()
//        titleBarAccessoryViewController.view.background = .random
//
//        titleBarAccessoryViewController.view.frame = NSMakeRect(0, 0, 0, 100) // Width not used.
//        window.addTitlebarAccessoryViewController(titleBarAccessoryViewController)
        
        appDelegate = self
        ApiEnvironment.migrate()
        
        initializeSelectManager()
        startLottieCacheCleaner()
        
        makeRLottie = { json, key in
            return RLottieBridge(json: json, key: key)
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
        

//        delay(2.0, closure: {
        #if arch(arm64)
            v.layer?.addSublayer(MetalEngine.shared.rootLayer)
        #endif
//        })
        
//        let ctxLayer = CtxInstallLayer()
//        self.ctxLayer = ctxLayer
//        window.contentView?.layer?.addSublayer(ctxLayer)
        
//        ctxLayer.setNeedsDisplay()
//        ctxLayer.display()
                
        let crashed = isCrashedLastTime(containerUrl.path)
        deinitCrashHandler(containerUrl.path)
        
        if crashed {
            let alert: NSAlert = NSAlert()
            alert.addButton(withTitle: strings().crashOnLaunchOK)
            alert.addButton(withTitle: strings().crashOnLaunchCancel)
            alert.messageText = strings().crashOnLaunchMessage
            alert.informativeText = strings().crashOnLaunchInformation
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
        
        
        TextView.context_copy_animation = MenuAnimation.menu_copy.value
        
       // applyMainMenuLocalization(window)
        
        mw = window
        
        
        #if BETA || DEBUG
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().sendUnsentReports()
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
        
        System.updateScaleFactor(window.backingScaleFactor)
        window.minSize = NSMakeSize(380, 500)
        
        let appEncryption = AppEncryptionParameters(path: rootPath)

        let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: containerUrl + "/accounts-metadata", isTemporary: false, isReadOnly: false, useCaches: true, removeDatabaseOnError: true)

        if let deviceSpecificEncryptionParameters = appEncryption.decrypt() {
            let parameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
            self.launchApp(accountManager: accountManager, encryptionParameters: parameters, appEncryption: appEncryption)
        } else {
            
            
            let data = combineLatest(themeSettingsView(accountManager: accountManager) |> take(1), accountManager.transaction { transaction in
                 transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self)
            }) |> deliverOnMainQueue
            
            _ = data.startStandalone(next: { themeSettings, localization in
                System.legacyMenu = themeSettings.legacyMenu

                if let localization = localization {
                    applyUILocalization(localization, window: self.window)
                    UNUserNotifications.current?.registerCategories()
                }
                
                telegramUpdateTheme(updateTheme(with: themeSettings), window: window, animated: false)

                self.window.makeKeyAndOrderFront(self)
                NSApp.activate(ignoringOtherApps: true)

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
                            let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: self.containerUrl + "/accounts-metadata", isTemporary: false, isReadOnly: false, useCaches: true, removeDatabaseOnError: true)
                            if let params = appEncryption.decrypt() {
                                let parameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: params.key)!, salt: ValueBoxEncryptionParameters.Salt(data: params.salt)!)
                                self.launchApp(accountManager: accountManager, encryptionParameters: parameters, appEncryption: appEncryption)
                            }
                        }
                        return EmptyDisposable
                    } |> runOn(prepareQueue)
                }), for: window)
            })
        }
    }
    
    func activeContext(for id: AccountRecordId?) -> AccountContext? {
        if let id = id {
            if let value = supportAccountContextValue?.find(id) {
                return value
            }
        }
        return contextValue?.context
    }
    
    func enumerateAccountContexts(_ f: (AccountContext)->Void) {
        if let contextValue = contextValue {
            f(contextValue.context)
        }
        self.supportAccountContextValue?.enumerateAccountContext(f)
    }
    
    func enumerateApplicationContexts(_ f: (AuthorizedApplicationContext)->Void) {
        if let contextValue = contextValue {
            f(contextValue)
        }
        self.supportAccountContextValue?.enumerateApplicationContext(f)
    }
    
    private var terminated = false
    
    private func launchApp(accountManager: AccountManager<TelegramAccountManagerTypes>, encryptionParameters: ValueBoxEncryptionParameters, appEncryption: AppEncryptionParameters) {
        
        FontCacheKey.initializeCache()
        
        clearUserDefaultsObject(forKeyPrefix: "dice_")
        
        self.appEncryption = appEncryption
        
        let rootPath = containerUrl!
        let window = self.window!
        System.updateScaleFactor(window.backingScaleFactor)
                
        window.minSize = NSMakeSize(380, 500)
        
        let networkDisposable = MetaDisposable()
        
        
       
//
//        self.window.closeInterceptor = {
//            if !self.terminated {
//                self.currentContext?.bindings.rootNavigation().gotoEmpty(false)
//            }
//            return false
//        }
        
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
            
            
            let data = combineLatest(accountManager.transaction {
                $0.getAccessChallengeData()
            }, themeSettingsView(accountManager: accountManager) |> take(1), accountManager.transaction { transaction in
                return transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self)
            }) |> deliverOnMainQueue
            
            _ = data.start(next: { passcode, themeSettings, localization in
                switch passcode {
                case let .numericalPassword(value), let .plaintextPassword(value):
                    if !value.isEmpty {
                        appEncryption.change(value)
                        _ = accountManager.transaction {
                            $0.setAccessChallengeData(.plaintextPassword(value: ""))
                        }.start()
                    }
                default:
                    break
                }
                
                if let localization = localization {
                    applyUILocalization(localization, window: self.window)
                    UNUserNotifications.current?.registerCategories()
                }
                            
                telegramUpdateTheme(updateTheme(with: themeSettings), window: window, animated: false)

                
                let basicTheme = Atomic<ThemePaletteSettings?>(value: themeSettings)
                let viewDidChangedAppearance: ValuePromise<Bool> = ValuePromise(true)
                let backingProperties:ValuePromise<CGFloat> = ValuePromise(System.backingScale, ignoreRepeated: true)
                
                
                let previousBackingScale: Atomic<CGFloat> = Atomic(value: System.backingScale)
                let signal: Signal<TelegramPresentationTheme?, NoError> = combineLatest(queue: resourcesQueue, themeSettingsView(accountManager: accountManager), backingProperties.get()) |> map { settings, backingScale in
                    let previous = basicTheme.swap(settings)
                    let previousScale = previousBackingScale.swap(backingScale)
                    System.legacyMenu = settings.legacyMenu
                    if previous?.palette != settings.palette || previous?.bubbled != settings.bubbled || previous?.wallpaper.wallpaper != settings.wallpaper.wallpaper || previous?.fontSize != settings.fontSize || previousScale != backingScale  {
                        return updateTheme(with: settings, animated: ((previous?.fontSize == settings.fontSize && previous?.palette != settings.palette) || previous?.bubbled != settings.bubbled || previous?.cloudTheme?.id != settings.cloudTheme?.id || previous?.palette.isDark != settings.palette.isDark))
                    } else {
                        return nil
                    }
                } |> deliverOnMainQueue
                
                _ = signal.start(next: { updatedTheme in
                    if let theme = updatedTheme {
                        if self.contextValue == nil {
                            telegramUpdateTheme(theme, window: window, animated: true)
                        } else {
                            self.enumerateApplicationContexts({ context in
                                telegramUpdateTheme(theme, window: context.context.window, animated: true)
                                context.applyNewTheme()
                            })
                        }
                    }
                })
                

                
                //
                
                NotificationCenter.default.addObserver(forName: NSWindow.didChangeBackingPropertiesNotification, object: window, queue: nil, using: { notification in
                    System.updateScaleFactor(window.backingScaleFactor)
                    backingProperties.set(window.backingScaleFactor)
                })
                
                let autoNightSignal = viewDidChangedAppearance.get() |> mapToSignal { _ in
                    return combineLatest(autoNightSettings(accountManager: accountManager), Signal<Void, NoError>.single(Void()) |> then( Signal<Void, NoError>.single(Void()) |> delay(60, queue: Queue.mainQueue()) |> restart))
                    } |> deliverOnMainQueue
                
                
                _ = combineLatest(autoNightSignal, additionalSettings(accountManager: accountManager)).start(next: { value1, value2 in
                    
                    let preference = value1.0
                    let alwaysDarkMode = value2.alwaysDarkMode
                    
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
                    if let settings = view.entries[SharedDataKeys.localizationSettings]?.get(LocalizationSettings.self) {
                        if basicLocalization.swap(settings) != settings {
                            applyUILocalization(settings, window: self.window)
                            UNUserNotifications.current?.registerCategories()
                        }
                    }
                })
                
                
                let voipVersions = OngoingCallContext.versions(includeExperimental: true, includeReference: false).map { version, supportsVideo -> CallSessionManagerImplementationVersion in
                    CallSessionManagerImplementationVersion(version: version, supportsVideo: supportsVideo)
                }
            
                let value = Configuration.value(for: .source)
                
                
               
                
                let appData: Signal<Data?, NoError> = Signal { subscriber in
                    subscriber.putNext(ApiEnvironment.appData)
                    subscriber.putCompletion()
                    return EmptyDisposable
                } |> runOn(.concurrentBackgroundQueue())
                
                
                var useBetaFeatures: Bool = false
                #if BETA || DEBUG
                useBetaFeatures = false
                #endif
                
                let networkArguments = NetworkInitializationArguments(apiId: ApiEnvironment.apiId, apiHash: ApiEnvironment.apiHash, languagesCategory: ApiEnvironment.language, appVersion: ApiEnvironment.version, voipMaxLayer: OngoingCallContext.maxLayer, voipVersions: voipVersions, appData: appData, externalRequestVerificationStream: .single([:]), externalRecaptchaRequestVerification: { _, _ in return .complete() }, autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider(), deviceModelName: deviceModelPretty(), useBetaFeatures: useBetaFeatures, isICloudEnabled: false)
                
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
                    if let contextValue =  self.effectiveContext(account) {
                        let navigation = contextValue.bindings.rootNavigation()
                        
                        if let controller = navigation.controller as? ChatController {
                            if controller.chatInteraction.peerId == peerId {
                                controller.scrollup()
                            } else {
                                navigation.push(ChatAdditionController(context: contextValue, chatLocation: .peer(peerId)))
                            }
                        } else {
                            navigation.push(ChatController(context: contextValue, chatLocation: .peer(peerId)))
                        }
                        NSApp.activate(ignoringOtherApps: true)
                        contextValue.window.deminiaturize(nil)
                    } else {
                        sharedContext.switchToAccount(id: account.id, action: .chat(peerId, necessary: true))
                        NSApp.activate(ignoringOtherApps: true)
                        window.deminiaturize(nil)
                    }
                }, navigateToThread: { account, threadId, fromId, threadData in
                    if let contextValue =  self.effectiveContext(account) {
                        let pushController: (ChatLocation, ChatMode, MessageId?, Atomic<ChatLocationContextHolder?>, Bool) -> Void = { chatLocation, mode, messageId, contextHolder, addition in
                            let navigation = contextValue.bindings.rootNavigation()
                            let controller: ChatController
                            if addition {
                                controller = ChatAdditionController(context: contextValue, chatLocation: chatLocation, mode: mode, focusTarget: .init(messageId: messageId), initialAction: nil, chatLocationContextHolder: contextHolder)
                            } else {
                                controller = ChatController(context: contextValue, chatLocation: chatLocation, mode: mode, focusTarget: .init(messageId: messageId), initialAction: nil, chatLocationContextHolder: contextHolder)
                            }
                            navigation.push(controller)
                        }
                        
                        let navigation = contextValue.bindings.rootNavigation()
                        
                        let currentInChat = navigation.controller is ChatController
                        let controller = navigation.controller as? ChatController
                        
                        if controller?.chatLocation.peerId == threadId.peerId,  controller?.chatLocation.threadMsgId == threadId {
                            controller?.scrollup()
                        } else {
                            
                            if let _ = threadData {
                                
                                _ = ForumUI.openTopic(Int64(threadId.id), peerId: threadId.peerId, context: contextValue).start()
                            } else if let fromId = fromId {
                                let signal:Signal<ThreadInfo, FetchChannelReplyThreadMessageError> = fetchAndPreloadReplyThreadInfo(context: contextValue, subject: .channelPost(threadId))
                                
                                _ = showModalProgress(signal: signal |> take(1), for: contextValue.window).start(next: { result in
                                    let chatLocation: ChatLocation = .thread(result.message)
                                    
                                    let updatedMode: ReplyThreadMode
                                    if result.isChannelPost {
                                        updatedMode = .comments(origin: fromId)
                                    } else {
                                        updatedMode = .replies(origin: fromId)
                                    }
                                    pushController(chatLocation, .thread(mode: updatedMode), fromId, result.contextHolder, currentInChat)
                                    
                                }, error: { error in
                                    
                                })
                            }
                        }
                        NSApp.activate(ignoringOtherApps: true)
                        contextValue.window.deminiaturize(nil)
                    } else {
                        sharedContext.switchToAccount(id: account.id, action: .thread(threadId, fromId, threadData, necessary: true))
                        NSApp.activate(ignoringOtherApps: true)
                        window.deminiaturize(nil)
                    }
                }, updateCurrectController: {
                    if let contextValue = self.contextValue {
                        contextValue.context.bindings.rootNavigation().controller.updateController()
                    }
                }, applyMaxReadIndexInteractively: { index in
                    if let context = self.contextValue?.context {
                        _ = context.engine.messages.applyMaxReadIndexInteractively(index: index).start()
                    }

                })
                
                let sharedNotificationManager = SharedNotificationManager(activeAccounts: sharedContext.activeAccounts |> map { ($0.0, $0.1.map { ($0.0, $0.1) }) }, appEncryption: appEncryption, accountManager: accountManager, bindings: notificationsBindings)
                let sharedWakeupManager = SharedWakeupManager(sharedContext: sharedContext, inForeground: self.presentAccountStatus.get())
                let sharedApplicationContext = SharedApplicationContext(sharedContext: sharedContext, notificationManager: sharedNotificationManager, sharedWakeupManager: sharedWakeupManager)
                
                self.sharedApplicationContextValue = sharedApplicationContext
                
                self.supportAccountContextValue = .init(applicationContext: sharedApplicationContext)
                
                
                self.sharedContextPromise.set(accountManager.transaction { transaction -> (SharedApplicationContext, LoggingSettings) in
                    return (sharedApplicationContext, transaction.getSharedData(SharedDataKeys.loggingSettings)?.get(LoggingSettings.self) ?? LoggingSettings.defaultSettings)
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
                            |> mapToSignal { primary, _, _ -> Signal<(Account?, LaunchSettings?), NoError> in
                                return .single((primary, nil))
                            }
                            |> distinctUntilChanged(isEqual: { lhs, rhs in
                                if lhs.0 !== rhs.0 {
                                    return false
                                }
                                return true
                            })
                            |> mapToSignal { (account, _) -> Signal<(Account?, LaunchSettings?), NoError> in
                                if let account = account {
                                    if let action = sharedContext.getLaunchActionOnce(for: account.id) {
                                        return .single((account, LaunchSettings(applyText: nil, previousText: nil, navigation: action)))
                                    } else {
                                        return account.postbox.transaction { transaction in
                                            return transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.launchSettings)?.get(LaunchSettings.self)
                                        } |> map {
                                            return (account, $0)
                                        }
                                    }
                                } else {
                                    return .single((nil, nil))
                                }
                            } |> mapToSignal { (account, settings) -> Signal<(Account?, LaunchSettings?, ChatListFolders?), NoError> in
                                if let account = account {
                                    return chatListFilterPreferences(engine: TelegramEngine(account: account)) |> take(1) |> map {
                                        (account, settings, $0)
                                    }
                                } else {
                                    return .single((account, settings, nil))
                                }
                                
                            } |> deliverOnMainQueue
                            |> map { account, settings, folders in
                                if let account = account {
                                                                    
                                    let context = AccountContext(sharedContext: sharedApplicationContext.sharedContext, window: window, account: account)
                                    return AuthorizedApplicationContext(window: window, context: context, launchSettings: settings ?? LaunchSettings.defaultSettings, callSession: sharedContext.getCrossAccountCallSession(), groupCallContext: sharedContext.getCrossAccountGroupCall(), inlinePlayerContext: sharedContext.getCrossInlinePlayer(), folders: folders)
                                    
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
                                let settings = settings.values[PreferencesKeys.networkSettings]?.get(NetworkSettings.self)
                                
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
                                #if STABLE || BETA || DEBUG
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
                                        let settings = settings.values[PreferencesKeys.networkSettings]?.get(NetworkSettings.self)
                                        
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
                
                self.timer = SwiftSignalKit.Timer(timeout: 5, repeat: true, completion: {
                    self.updatePeerPresence()
                }, queue: .mainQueue())
                self.timer?.start()
                
            })
        })
        
    }

    func navigateProfile(_ peerId: PeerId, account: Account) {
        if let context = self.contextValue?.context, context.peerId == account.peerId {
            PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
            context.window.makeKeyAndOrderFront(nil)
            context.window.orderFrontRegardless()
        } else {
            let signal = account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue
            _ = signal.start(next: { peer in
                self.sharedApplicationContextValue?.sharedContext.switchToAccount(id: account.id, action: .profile(EnginePeer(peer), necessary: true))
            })
        }
    }
    func navigateChat(_ peerId: PeerId, account: Account) {
        if let context = self.contextValue?.context, context.peerId == account.peerId {
            context.bindings.rootNavigation().push(ChatAdditionController.init(context: context, chatLocation: .peer(peerId)))
            context.window.makeKeyAndOrderFront(nil)
            context.window.orderFrontRegardless()
        } else {
            sharedApplicationContextValue?.sharedContext.switchToAccount(id: account.id, action: .chat(peerId, necessary: true))
        }
    }
    
    func openAccountInNewWindow(_ account: Account) {
        supportAccountContextValue?.open(account: account)
    }
    
    
    private func updatePeerPresence() {
        if let sharedApplicationContextValue = sharedApplicationContextValue {
            let isOnline = NSApp.isActive && NSApp.isRunning && !NSApp.isHidden && !sharedApplicationContextValue.sharedWakeupManager.isSleeping && !sharedApplicationContextValue.notificationManager._lockedValue.screenLock && !sharedApplicationContextValue.notificationManager._lockedValue.passcodeLock && SystemIdleTime() < 30
            
            
            presentAccountStatus.set(.single(isOnline) |> then(.single(isOnline) |> delay(50, queue: Queue.concurrentBackgroundQueue())) |> restart)
        }
    }
    
    @objc public func windiwDidChangeBackingProperties() {
        System.updateScaleFactor(window.backingScaleFactor)
    }
    
    func playSound(_ path: String) {
        if let context = self.contextValue?.context {
            SoundEffectPlay.play(postbox: context.account.postbox, path: path, volume: 0.7)
        }
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
                    context.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: postId), initialAction:action), true)
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
                    alert(for: mainWindow, info: strings().secureIdLoginText)
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
        var result: String?
        self.enumerateAccountContexts { context in
            if context.window == NSApp.keyWindow {
                let config = context.appConfiguration
                if let value = AutologinToken.with(appConfiguration: config, autologinToken: context.autologinToken) {
                    result = value.applyTo(url, isTestServer: contextValue?.context.account.testingEnvironment ?? false)
                }
            }
        }
        return result
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
        if contextValue != nil, !self.window.isMiniaturized {
            if !self.window.isVisible {
                self.window.makeKeyAndOrderFront(self)
                self.window.orderFrontRegardless()
            }
            if let viewer = viewer {
                viewer.windowDidResignKey()
            }
            self.activeValue.set(true)
            
        }
    }
    
    func updateActiveContexts() {
        let records = [self.contextValue?.context.account.id].compactMap { $0 } + (supportAccountContextValue?.accountIds ?? [])
        BrowserStateContext.focus(records)
    }
    
    
    func applicationDidResignActive(_ notification: Notification) {
        updatePeerPresence()
        if viewer != nil, NSScreen.main == viewer?.window.screen {
            viewer?.window.orderOut(nil)
        }
        self.activeValue.set(false)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        self.terminated = true
        deinitCrashHandler(containerUrl)
        
        #if !APP_STORE
            updateAppIfNeeded()
        #endif
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        
        if let context = self.contextValue?.context {
            let navigation = context.bindings.rootNavigation()
            (navigation.controller as? ChatController)?.chatInteraction.saveState(sync: true)
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
            context.bindings.mainController().showPreferences()
        }
        window.makeKeyAndOrderFront(sender)

    }
    @IBAction func globalSearch(_ sender: Any) {
        if let context = contextValue?.context {
            context.bindings.mainController().focusSearch(animated: true)
        }
    }
    @IBAction func closeWindow(_ sender: Any) {
        NSApp.keyWindow?.close()
    }
    
    func isLocked() -> Signal<Bool, NoError> {
        if let context = sharedApplicationContextValue {
            return context.notificationManager.isLockedValue
        }
        return .single(false)
    }
    func isLockedValue() -> Bool {
        if let context = sharedApplicationContextValue {
            return context.notificationManager.isLocked
        }
        return false
    }
    
    func showSavedPathSuccess(_ path: String) {
        if let context = contextValue?.context {
            
            let text: String = strings().savedAsModalOk
            
            let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .bold(15), textColor: .white), bold: MarkdownAttributeSet(font: .bold(15), textColor: .white), link: MarkdownAttributeSet(font: .bold(15), textColor: .link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { _ in }))
            })).mutableCopy() as! NSMutableAttributedString
            
            let layout = TextViewLayout(attributedText, alignment: .center, lineSpacing: 5.0, alwaysStaticItems: true)
            layout.interactions = TextViewInteractions(processURL: { _ in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            })
            layout.measure(width: 160)
            
            _ = showSaveModal(for: window, context: context, animation: LocalAnimatedSticker.success_saved, text: layout, delay: 3.0).start()
        }
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
                    navigateToChat(navigation: context.bindings.rootNavigation(), context: context, chatLocation: .peer(peerId))
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
        if authContextValue == nil {
            _ = sharedContextOnce.start(next: { applicationContext in
                if !applicationContext.notificationManager.isLocked {
                    self.enumerateApplicationContexts { applicationContext in
                        if applicationContext.context.window.isKeyWindow {
                            if !hasModals(applicationContext.context.window) {
                                showModal(with: QuickSwitcherModalController(applicationContext.context), for: applicationContext.context.window)
                                applicationContext.context.window.makeKeyAndOrderFront(sender)
                            }
                        }
                    }
                }
            })
        }
        
    }
    
    func applyExternalLoginCode(_ code: String) {
        if let modal = findModal(ModalController.self) {
            let controller = modal.controller.controller as? PhoneNumberCodeConfirmController
            if let controller = controller {
                controller.applyExternalLoginCode(code)
                return
            }
        }
        self.authContextValue?.applyExternalLoginCode(code)
    }
}
