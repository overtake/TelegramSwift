import Foundation
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import MtProtoKitMac
import IOKit
func applicationContext(window: Window, shouldOnlineKeeper:Signal<Bool,Void>, accountManager: AccountManager, appGroupPath: String, testingEnvironment: Bool) -> Signal<ApplicationContext?, NoError> {
    
    return migrationData(accountManager: accountManager, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment)
        |> deliverOnMainQueue
        |> map { migration -> Signal<ApplicationContext?, Void> in
            
            switch migration {
            case let .auth(result, ignorepasslock):
                if let result = result {
                    switch result {
                    case let .unauthorized(account):
                        return account.postbox.preferencesView(keys: [PreferencesKeys.localizationSettings]) |> take(1) |> deliverOnMainQueue |> map { preferences in
                            return ApplicationContext.unauthorized(UnauthorizedApplicationContext(window: window, account: account, localization: preferences.values[PreferencesKeys.localizationSettings] as? LocalizationSettings))
                        }
                    case let .authorized(account):
                        let paslock:Signal<PostboxAccessChallengeData, Void> = !ignorepasslock ? account.postbox.modify { modifier -> PostboxAccessChallengeData in
                            return modifier.getAccessChallengeData()
                        } |> deliverOnMainQueue : .single(.none)
                            
                        return paslock |> mapToSignal { access -> Signal<ApplicationContext?, Void> in
                            let promise:Promise<Void> = Promise()
                            let auth: Signal<ApplicationContext?, Void> = combineLatest(promise.get(), account.postbox.preferencesView(keys: [PreferencesKeys.localizationSettings, ApplicationSpecificPreferencesKeys.themeSettings]) |> take(1)) |> deliverOnMainQueue |> map { _, preferences in
                                return .authorized(AuthorizedApplicationContext(window: window, shouldOnlineKeeper: shouldOnlineKeeper, account: account, accountManager: accountManager, localization: preferences.values[PreferencesKeys.localizationSettings] as? LocalizationSettings, themeSettings: preferences.values[ApplicationSpecificPreferencesKeys.themeSettings] as? ThemePaletteSettings))
                            }
                            switch access {
                            case .none:
                                promise.set(.single(Void()))
                                return auth
                            default:
                                return account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.themeSettings, PreferencesKeys.localizationSettings]) |> take(1) |> deliverOnMainQueue |> map { value in
                                    return ApplicationContext.postboxAccess(PasscodeAccessContext(window, promise: promise, account: account, accountManager: accountManager, localization: value.values[PreferencesKeys.localizationSettings] as? LocalizationSettings, themeSettings: value.values[ApplicationSpecificPreferencesKeys.themeSettings] as? ThemePaletteSettings))
                                } |> then(auth)
                            }
                        }
                    case .upgrading:
                        return .single(nil)
                    }
                } else {
                    return .single(nil)
                }
            case let .migrationIntro(promise, data):
                return .single(.legacyIntro(LegacyIntroContext(window, promise: promise, defaultLegacyData: data)))
            }
    } |> switchToLatest
}


enum MigrationData {
    case migrationIntro(Promise<AuthorizationLegacyData>, AuthorizationLegacyData)
    case auth(AccountResult?, ignorepasslock: Bool)
}


func migrationData(accountManager: AccountManager, appGroupPath:String, testingEnvironment: Bool) -> Signal<MigrationData, Void> {
       
    return accountManager.modify { modifier -> Signal<MigrationData, Void> in
        
        if modifier.getCurrentId() == nil {
            
            let auth = legacyAuthData(passcode: emptyPasscodeData())
            let promise:Promise<AuthorizationLegacyData> = Promise()
            
            switch auth {
            case .data:
                break
            case .passcodeRequired:
                break
            case .none:
                return currentAccount(networkArguments: NetworkInitializationArguments(apiId: API_ID, languagesCategory: languagesCategory), supplementary: false, manager: accountManager, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> map { account in return .auth(account, ignorepasslock: false) }
            }
            
            return .single(.migrationIntro(promise, auth)) |> then ( promise.get() |> take(1) |> mapToSignal { result in
                return accountManager.modify { modifier -> Signal<MigrationData, Void> in
                
                    switch result {
                    case let .data(migration):
                        let accountId = modifier.createRecord([])
                        
                        let provider = ImportAccountProvider(mtProtoKeychain: {
                            return .single(migration.groups)
                        }, accountState: {
                            return .single(AuthorizedAccountState(masterDatacenterId: migration.masterDatacenterId, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: migration.userId), state: nil))
                        }, peers:  {
                            return .single([])
                        })
                        //if !isDebug {
                            clearLegacyData()
                       // }
                        return accountWithId(networkArguments: NetworkInitializationArguments(apiId: API_ID, languagesCategory: languagesCategory), id: accountId, supplementary: false, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods, shouldKeepAutoConnection: false) |> mapToSignal { accountResult in
                            switch accountResult {
                            case .unauthorized(let left):
                                return importAccount(account: left, provider: provider) |> mapToSignal {
                                    return accountManager.modify { modifier -> Void in
                                        modifier.setCurrentId(accountId)
                                        } |> mapToSignal {
                                            return currentAccount(networkArguments: NetworkInitializationArguments(apiId: API_ID, languagesCategory: languagesCategory), supplementary: false, manager: accountManager, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> map { accountResult  -> Signal<MigrationData, Void> in
                                                
                                                if let accountResult = accountResult {
                                                    switch accountResult {
                                                    case .authorized(let account):
                                                        for (resource, data) in migration.resources {
                                                            account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                                                        }
                                                        return account.postbox.modify { modifier -> MigrationData in
                                                            
                                                            updatePeers(modifier: modifier, peers: migration.peers, update: { (_, updated) -> Peer? in
                                                                return updated
                                                            })
                                                            
                                                            for (peerId, state) in migration.secretState {
                                                                modifier.setPeerChatState(peerId, state: terminateLegacySecretChat(modifier: modifier, peerId: peerId, state: state))
                                                            }
                                                            
                                                            if let passcode = migration.passcode {
                                                                modifier.setAccessChallengeData(.plaintextPassword(value: passcode, timeout: 60 * 60, attempts: nil))
                                                            }
                                                            _ = modifier.addMessages(migration.secretMessages, location: .Random)
                                                            
                                                            for message in migration.secretMessages {
                                                                if let attribute = message.attributes.first as? AutoremoveTimeoutMessageAttribute {
                                                                    switch message.id {
                                                                    case let .Id(id):
                                                                        let begin:Int32 = attribute.countdownBeginTime ?? Int32(Date().timeIntervalSince1970)
                                                                        modifier.addTimestampBasedMessageAttribute(tag: 0, timestamp: begin + attribute.timeout, messageId: id)
                                                                    default:
                                                                        break
                                                                    }
                                                                }
                                                            }
                                                            
                                                            return .auth(accountResult, ignorepasslock: true)
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                                
                                                return .single(.auth(accountResult, ignorepasslock: false))
                                            } |> switchToLatest 
                                    }
                                }
                            default:
                                break
                            }
                            return currentAccount(networkArguments: NetworkInitializationArguments(apiId: 2834, languagesCategory: languagesCategory), supplementary: false, manager: accountManager, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> map { account in return .auth(account, ignorepasslock: false) }
                        }
                    case .none:
                        clearLegacyData()
                    default:
                        assertionFailure()
                    }
                    
                    return currentAccount(networkArguments: NetworkInitializationArguments(apiId: API_ID, languagesCategory: languagesCategory), supplementary: false, manager: accountManager, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> map { account in return .auth(account, ignorepasslock: false) }
                } |> switchToLatest
                
            })

        }
        return currentAccount(networkArguments: NetworkInitializationArguments(apiId: API_ID, languagesCategory: languagesCategory), supplementary: false, manager: accountManager, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> map { account in return .auth(account, ignorepasslock: false) }

    } |> switchToLatest
    
}



enum ApplicationContext {
    case unauthorized(UnauthorizedApplicationContext)
    case authorized(AuthorizedApplicationContext)
    case legacyIntro(LegacyIntroContext)
    case postboxAccess(PasscodeAccessContext)
    
    func showRoot(for window:Window) {
        if let content = window.contentView {
            switch self {
            case let .postboxAccess(context):
                showModal(with: context.rootController, for: window)
            default:
                content.addSubview(rootView)
                rootView.frame = content.bounds
                viewDidAppear()
            }
        }
    }
    
    var rootView: NSView {
        switch self {
        case let .unauthorized(context):
            return context.rootController.view
        case let .authorized(context):
            return context.splitView
        case let .legacyIntro(context):
            return context.rootController.view
        case let .postboxAccess(context):
            return context.rootController.view
        }
    }
    
    func viewDidAppear() {
        switch self {
        case let .unauthorized(context):
            context.rootController.viewDidAppear(false)
        default:
            break
        }
    }
}

final class PasscodeAccessContext {
    let rootController:PasscodeLockController
    private let logoutDisposable = MetaDisposable()
    init(_ window:Window, promise:Promise<Void>, account:Account, accountManager:AccountManager, localization: LocalizationSettings?, themeSettings: ThemePaletteSettings?) {
        
        dropLocalization()
        if let localization = localization {
            applyUILocalization(localization)
        }
        
        if let theme = themeSettings {
            updateTheme(with: theme, for: window)
        } else {
            setDefaultTheme(for: window)
        }
        
        rootController = PasscodeLockController(account, .login, logoutImpl: {
            _ = (confirmSignal(for: window, information: tr(.accountConfirmLogoutText)) |> filter {$0} |> mapToSignal {_ in return logoutFromAccount(id: account.id, accountManager: accountManager)}).start()
        })
        rootController._frameRect = NSMakeRect(0, 0, window.frame.width, window.frame.height)
        
        window.maxSize = NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        window.minSize = NSMakeSize(380, 440)
        
        promise.set(rootController.doneValue |> filter {$0} |> map {_ in})
    
        
    }
    
    deinit {
        logoutDisposable.dispose()
    }
}

final class LegacyIntroContext {
    let rootController:LegacyIntroController
    init(_ window:Window, promise:Promise<AuthorizationLegacyData>, defaultLegacyData: AuthorizationLegacyData) {
        rootController = LegacyIntroController(promise: promise, defaultLegacyData: defaultLegacyData)
        let authSize = NSMakeSize(650, 600)
        window.maxSize = authSize
        window.minSize = authSize
        window.setFrame(NSMakeRect(0, 0, authSize.width, authSize.height), display: true)
        window.center()
        rootController._frameRect = NSMakeRect(0, 0, authSize.width, authSize.height)
    }
}

final class UnauthorizedApplicationContext {
    let account: UnauthorizedAccount
    let localizationDisposable:MetaDisposable = MetaDisposable()
    let rootController: AuthController
    let window:Window
    init(window:Window, account: UnauthorizedAccount, localization: LocalizationSettings?) {
        self.account = account
        self.window = window
        self.rootController = AuthController(account)
        let authSize = NSMakeSize(650, 600)
        
        setDefaultTheme(for: window)
        
        account.shouldBeServiceTaskMaster.set(.single(.now))
        
        window.maxSize = authSize
        window.minSize = authSize
        window.setFrame(NSMakeRect(0, 0, authSize.width, authSize.height), display: true)
        window.center()
        window.initFromSaver = false
        rootController._frameRect = NSMakeRect(0, 0, authSize.width, authSize.height)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveWakeNote(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
        

        
        
        dropLocalization()
        if let localization = localization {
            applyUILocalization(localization)
        }
        
        localizationDisposable.set(account.postbox.preferencesView(keys: [PreferencesKeys.localizationSettings]).start(next: { view in
            if let settings = view.values[PreferencesKeys.localizationSettings] as? LocalizationSettings {
                applyUILocalization(settings)
            }
        }))
        
    }
    
    deinit {
        account.shouldBeServiceTaskMaster.set(.single(.never))
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc func receiveWakeNote(_ notificaiton:Notification) {
        account.shouldBeServiceTaskMaster.set(.single(.never) |> then(.single(.now)))
    }
    
}

private struct LockNotificationsData : Equatable {
    let screenLock:Bool
    let passcodeLock:Bool
    
    init() {
        self.screenLock = false
        self.passcodeLock = false
    }
    
    init(screenLock: Bool, passcodeLock: Bool) {
        self.screenLock = screenLock
        self.passcodeLock = passcodeLock
    }
    
    func withUpdatedScreenLock(_ lock: Bool) -> LockNotificationsData {
        return LockNotificationsData(screenLock: lock, passcodeLock: passcodeLock)
    }
    func withUpdatedPasscodeLock(_ lock: Bool) -> LockNotificationsData {
        return LockNotificationsData(screenLock: screenLock, passcodeLock: lock)
    }
    
    static func ==(lhs:LockNotificationsData, rhs: LockNotificationsData) -> Bool {
        return lhs.screenLock == rhs.screenLock && lhs.passcodeLock == rhs.screenLock
    }
    
    var isLocked: Bool {
        return screenLock || passcodeLock
    }
}

final class AuthorizedApplicationContext: NSObject, SplitViewDelegate, NSUserNotificationCenterDelegate {
    
    private let nofityDisposable:MetaDisposable = MetaDisposable()
    
    private var mediaKeyTap:SPMediaKeyTap?
    
    let applicationContext: TelegramApplicationContext
    let account: Account
    let accountManager: AccountManager
    let window:Window
    let splitView:SplitView
    let leftController:MainViewController
    let rightController:MajorNavigationController
    private let emptyController:EmptyChatViewController
    
    private let loggedOutDisposable = MetaDisposable()
    private let passlockDisposable = MetaDisposable()
    private let logoutDisposable = MetaDisposable()
    private let ringingStatesDisposable = MetaDisposable()
    private let lockedScreenPromise:Promise<LockNotificationsData> = Promise(LockNotificationsData())
    private var _lockedValue:LockNotificationsData = LockNotificationsData()
    private var resignTimestamp:Int32? = nil
    private let _passlock = Promise<Bool>()
    
    private let settingsDisposable = MetaDisposable()
    private let localizationDisposable = MetaDisposable()
    private let suggestedLocalizationDisposable = MetaDisposable()
    private let appearanceDisposable = MetaDisposable()
    private func updateLocked(_ f:(LockNotificationsData) -> LockNotificationsData) {
        _lockedValue = f(_lockedValue)
        lockedScreenPromise.set(.single(_lockedValue))
    }
    
    init(window: Window, shouldOnlineKeeper:Signal<Bool, Void>, account: Account, accountManager: AccountManager, localization:LocalizationSettings?, themeSettings: ThemePaletteSettings?) {
        emptyController = EmptyChatViewController(account)
        
        self.account = account
        self.window = window
        self.accountManager = accountManager
        window.maxSize = NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude)
        window.minSize = NSMakeSize(380, 440)
        
        if let themeSettings = themeSettings {
            updateTheme(with: themeSettings, for: window)
        } else {
            setDefaultTheme(for: window)
        }

        if let localization = localization {
            applyUILocalization(localization)
        }
        
        
        if !window.initFromSaver {
            window.setFrame(NSMakeRect(0, 0, 800, 650), display: true)
            window.center()
        }
        
        
        
        setupAccount(account, fetchCachedResourceRepresentation: fetchCachedResourceRepresentation, transformOutgoingMessageMedia: transformOutgoingMessageMedia)
        
        account.stateManager.reset()
        account.shouldBeServiceTaskMaster.set(.single(.now))
        account.shouldKeepOnlinePresence.set(.single(true))
        account.shouldKeepOnlinePresence.set(shouldOnlineKeeper)
        
        self.splitView = SplitView(frame:mainWindow.contentView!.bounds)
        

        
        splitView.setProportion(proportion: SplitProportion(min:380, max:300+350), state: .single);
        splitView.setProportion(proportion: SplitProportion(min:300+350, max:300+350+600), state: .dual)
        
        
        rightController = ExMajorNavigationController(account, ChatController.self, emptyController);
        rightController.set(header: NavigationHeader(44, initializer: { (header) -> NavigationHeaderView in
            let view = InlineAudioPlayerView(header)
            return view
        }))
        
        rightController.set(callHeader: CallNavigationHeader(35, initializer: { header -> NavigationHeaderView in
            let view = CallNavigationHeaderView(header)
            return view
        }))

        
        applicationContext = TelegramApplicationContext(rightController, EntertainmentViewController(size: NSMakeSize(350, window.frame.height), account: account), network: account.network)
        account.applicationContext = applicationContext
        
        
        leftController = MainViewController(account, accountManager: accountManager);
        
        leftController.navigationController = rightController
        
        
       
        
        super.init()
        startNotifyListener(with: account)
        NSUserNotificationCenter.default.delegate = self
     

        #if BETA || STABLE
            
            settingsDisposable.set((account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.baseAppSettings]) |> deliverOnMainQueue).start(next: { [weak self] settings in
                
                let baseSettings: BaseApplicationSettings
                if let settings = settings.values[ApplicationSpecificPreferencesKeys.baseAppSettings] as? BaseApplicationSettings {
                    baseSettings = settings
                } else {
                    baseSettings = BaseApplicationSettings.defaultSettings
                }
                
                if baseSettings.handleInAppKeys {
                    self?.applicationContext.initMediaKeyTap()
                } else {
                    self?.applicationContext.deinitMediaKeyTap()
                }
                
            }))
            
        #endif
      
        var forceNotice:Bool = false
        if FastSettings.isMinimisize {
            self.splitView.state = .minimisize
            forceNotice = true
        }
        
        splitView.delegate = self;
        splitView.update(forceNotice)
        
       
        
        let accountId = account.id
        self.loggedOutDisposable.set(account.loggedOut.start(next: { value in
            if value {
                let _ = logoutFromAccount(id: accountId, accountManager: accountManager).start()
            }
        }))
        
        let passlock = Signal<Void, Void>.single(Void()) |> delay(60, queue: Queue.concurrentDefaultQueue()) |> restart |> mapToSignal { () -> Signal<Int32?, Void> in
            return account.postbox.modify { modifier -> Int32? in
                return modifier.getAccessChallengeData().timeout
            }
        } |> map { [weak self] timeout -> Bool in
            if let timeout = timeout {
                if let resignTimestamp = self?.resignTimestamp  {
                    let current = Int32(Date().timeIntervalSince1970)
                    if current - resignTimestamp > timeout {
                        return true
                    }
                }
                return Int64(timeout) < SystemIdleTime()
            } else  {
                return false
            }
        }
        |> filter { [weak self] _ in
            if let strongSelf = self {
                return !strongSelf._lockedValue.passcodeLock
            }
            return false
        }
        |> deliverOnMainQueue
            
            
        let showPasslock = passlock
        
        
        _passlock.set(showPasslock)
        
        passlockDisposable.set((_passlock.get() |> deliverOnMainQueue |> mapToSignal { [weak self] show -> Signal<Bool, Void> in
            if show {
                let controller = PasscodeLockController(account, .login, logoutImpl: { [weak self] in
                    self?.logout()
                })
                closeAllModals()
                showModal(with: controller, for: window)
                return .single(show) |> then( controller.doneValue |> map {_ in return false} |> take(1) )
            }
            return .never()
        } |> deliverOnMainQueue).start(next: { [weak self] lock in
            
            window.contentView?.subviews.first?.isHidden = lock
            
            self?.updateLocked { previous -> LockNotificationsData in
                return previous.withUpdatedPasscodeLock(lock)
            }
        }))
        
        
        ringingStatesDisposable.set((account.callSessionManager.ringingStates() |> deliverOn(callQueue)).start(next: { states in
            pullCurrentSession( { session in
                if let state = states.first {
                    if session == nil {
                        showPhoneCallWindow(PCallSession(account: account, peerId: state.peerId, id: state.id))
                    } else {
                        account.callSessionManager.drop(internalId: state.id, reason: .busy)
                    }
                }
            } )
        }))
        
        
       // NotificationCenter.default.addObserver(self, selector: #selector(windiwDidChangeBackingProperties), name: NSNotification.Name.NSWindowDidChangeBackingProperties, object: window)

        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveWakeNote(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
                
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsLocked), name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)
        

        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            
            if let strongSelf = self {
                if !strongSelf._lockedValue.passcodeLock {
                    self?._passlock.set(account.postbox.modify { modifier -> Bool in
                        switch modifier.getAccessChallengeData() {
                        case .none:
                            return false
                        default:
                            return true
                        }
                    })
                }
            }
            
            return .invoked
        }, with: self, for: .L, priority: .low, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                strongSelf.applicationContext.mainNavigation?.push(ChatController(account: strongSelf.account, peerId: strongSelf.account.peerId))
            }
            return .invoked
        }, with: self, for: .Zero, priority: .low, modifierFlags: [.command])
        
        

        
        
        suggestedLocalizationDisposable.set(( account.postbox.preferencesView(keys: [PreferencesKeys.suggestedLocalization]) |> mapToSignal { preferences -> Signal<SuggestedLocalizationInfo, Void> in
            
            let preferences = preferences.values[PreferencesKeys.suggestedLocalization] as? SuggestedLocalizationEntry
            if preferences == nil || !preferences!.isSeen, preferences?.languageCode != appCurrentLanguage.languageCode, preferences?.languageCode != "en" {
                return suggestedLocalizationInfo(network: account.network, languageCode: Locale.current.languageCode ?? "en", extractKeys: ["Suggest.Localization.Header", "Suggest.Localization.Other"]) |> take(1)
            }
            return .complete()
        } |> deliverOnMainQueue).start(next: { suggestionInfo in
                showModal(with: SuggestionLocalizationViewController(account, suggestionInfo: suggestionInfo), for: window)
        }))

        
        
        localizationDisposable.set(account.postbox.preferencesView(keys: [PreferencesKeys.localizationSettings]).start(next: { view in
            if let settings = view.values[PreferencesKeys.localizationSettings] as? LocalizationSettings {
                applyUILocalization(settings)
            }
        }))
        
        rightController.backgroundColor = theme.colors.background
        splitView.backgroundColor = theme.colors.background
        let basic = Atomic<ThemePaletteSettings?>(value: themeSettings)
        appearanceDisposable.set((account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.themeSettings]) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let settings = view.values[ApplicationSpecificPreferencesKeys.themeSettings] as? ThemePaletteSettings {
                if basic.swap(settings) != settings {
                    updateTheme(with: settings, for: window, animated: true)
                    self?.rightController.backgroundColor = theme.colors.background
                    self?.splitView.backgroundColor = theme.colors.background
                }
            }
        }))
        
    }
    
    var isLocked: Bool {
        return _lockedValue.isLocked
    }
    
    
    func logout() {
        self.logoutDisposable.set((confirmSignal(for: window, information: tr(.accountConfirmLogoutText)) |> filter {$0} |> mapToSignal { [weak self] _ -> Signal<Void, Void> in
            if let strongSelf = self {
                return logoutFromAccount(id: strongSelf.account.id, accountManager: strongSelf.accountManager)
            }
            return .complete()
        }).start())
    }
    
    
    @objc open func windowDidBecomeKey() {
        self.resignTimestamp = nil
    }
    
    
    @objc open func windowDidResignKey() {
        self.resignTimestamp = Int32(Date().timeIntervalSince1970)
    }
    
    
    func splitViewDidNeedSwapToLayout(state: SplitViewState) {
        splitView.removeAllControllers();
        let w:CGFloat = 300;
        FastSettings.isMinimisize = false
        switch state {
        case .single:
            rightController.empty = leftController
            
            if rightController.modalAction != nil {
                if rightController.controller is ChatController {
                    rightController.push(ForwardChatListController(account), false)
                }
            }
            splitView.addController(controller: rightController, proportion: SplitProportion(min:380, max:CGFloat.greatestFiniteMagnitude))
        case .dual:
            rightController.empty = emptyController
            if rightController.controller is ForwardChatListController {
                rightController.back(animated:false)
            }
            splitView.addController(controller: leftController, proportion: SplitProportion(min:w, max:w))
            splitView.addController(controller: rightController, proportion: SplitProportion(min:380, max:CGFloat.greatestFiniteMagnitude))
        case .minimisize:
            FastSettings.isMinimisize = true
            splitView.addController(controller: leftController, proportion: SplitProportion(min:70, max:70))
            splitView.addController(controller: rightController, proportion: SplitProportion(min:380, max:CGFloat.greatestFiniteMagnitude))
        default:
            break;
        }

        
        account.context.layoutHandler.set(state)
        splitView.layout()
    }
    
    @objc func screenIsLocked() {
        
        if !_lockedValue.passcodeLock {
            _passlock.set(account.postbox.modify { modifier -> Bool in
                switch modifier.getAccessChallengeData() {
                case .none:
                    return false
                default:
                    return true
                }
            })
        }
        
        updateLocked { (previous) -> LockNotificationsData in
            return previous.withUpdatedScreenLock(true)
        }
    }
    
    @objc func screenIsUnlocked() {
        updateLocked { (previous) -> LockNotificationsData in
            return previous.withUpdatedScreenLock(false)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func splitViewDidNeedMinimisize(controller: ViewController) {
        
    }
    
    func splitViewDidNeedFullsize(controller: ViewController) {
        
    }
    
    func splitViewIsCanMinimisize() -> Bool {
        return self.leftController.isCanMinimisize();
    }
    
    func splitViewDrawBorder() -> Bool {
        return false
    }
    
    deinit {
        self.account.shouldKeepOnlinePresence.set(.single(false))
        self.account.shouldBeServiceTaskMaster.set(.single(.never))
        nofityDisposable.dispose()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        self.loggedOutDisposable.dispose()
        passlockDisposable.dispose()
        logoutDisposable.dispose()
        window.removeAllHandlers(for: self)
        settingsDisposable.dispose()
        ringingStatesDisposable.dispose()
        localizationDisposable.dispose()
        suggestedLocalizationDisposable.dispose()
        appearanceDisposable.dispose()
        //query.stop()
    }
    
    
    func startNotifyListener(with account: Account) {
        
        let lockedSreenSignal = lockedScreenPromise.get()
        
        self.nofityDisposable.set((account.stateManager.notificationMessages |> mapToSignal { messages -> Signal<([Message], InAppNotificationSettings), Void> in
            return account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.inAppNotificationSettings]) |> mapToSignal { (settings) -> Signal<([Message], InAppNotificationSettings), Void> in
                
                let inAppSettings: InAppNotificationSettings
                if let settings = settings.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                    inAppSettings = settings
                } else {
                    inAppSettings = InAppNotificationSettings.defaultSettings
                }
                if inAppSettings.enabled && inAppSettings.muteUntil < Int32(Date().timeIntervalSince1970) {
                    return .single((messages, inAppSettings))
                } else {
                    return .complete()
                }
                
            }
            }
            |> mapToSignal { messages, inAppSettings -> Signal<([Message],[MessageId:NSImage], InAppNotificationSettings), Void> in
                
                var photos:[Signal<(MessageId, CGImage?),Void>] = []
                for message in messages {
                    var peer = message.author
                    if let mainPeer = messageMainPeer(message) {
                        if mainPeer is TelegramChannel || mainPeer is TelegramGroup {
                            peer = mainPeer
                        }
                    }
                    if let peer = peer {
                        if let image = peerAvatarImage(account: account, peer: peer, genCap: false) {
                            photos.append(image |> map { data in return (message.id, data.0)})
                        }
                    }
                }
                
                return  combineLatest(photos) |> map { resources in
                    var images:[MessageId:NSImage] = [:]
                    for (messageId,image) in resources {
                        if let image = image {
                            images[messageId] = NSImage(cgImage: image, size: NSMakeSize(50,50))
                        }
                    }
                    return (messages,images, inAppSettings)
                }
            } |> mapToSignal { messages, images, inAppSettings -> Signal<([Message],[MessageId:NSImage], InAppNotificationSettings, Bool), Void> in
                return lockedSreenSignal |> take(1)
                    |> map { data in return (messages, images, inAppSettings, data.isLocked)}
            }
            |> mapToSignal { values in
                return _callSession() |> map { s in
                    return (values.0, values.1, values.2, values.3, s != nil)
                }
            } |> deliverOnMainQueue).start(next: { messages, images, inAppSettings, screenIsLocked, inCall in
                for message in messages {
                    if message.author?.id != account.peerId {
                        var title:String = message.author?.displayTitle ?? ""
                        var hasReplyButton:Bool = true
                        if let peer = message.peers[message.id.peerId], peer is TelegramChannel || peer is TelegramGroup {
                            title = peer.displayTitle
                            hasReplyButton = peer.canSendMessage
                        }
                        var text = chatListText(account: account, for: message).string.nsstring
                        var subText:String?
                        if text.contains("\n") {
                            let parts = text.components(separatedBy: "\n")
                            text = parts[1] as NSString
                            subText = parts[0]
                        }
                        
                        if !inAppSettings.displayPreviews || message.peers[message.id.peerId] is TelegramSecretChat || screenIsLocked {
                            text = tr(.notificationLockedPreview).nsstring
                            subText = nil
                        }
                        
                        let notification = NSUserNotification()
                        notification.title = title
                        notification.informativeText = text as String
                        notification.subtitle = subText
                        notification.contentImage = images[message.id]
                        notification.hasReplyButton = hasReplyButton
                        
                        if localizedString(inAppSettings.tone) != tr(.notificationSettingsToneNone) {
                            notification.soundName = inAppSettings.tone
                        } else {
                            notification.soundName = nil
                        }
                        
                        if message.muted || inCall {
                            notification.soundName = nil
                        }
                        
                        
                        var dict: [String : Any] = [:]
                        
                        dict["message.id"] =  message.id.id
                        dict["message.namespace"] =  message.id.namespace
                        dict["peer.id"] =  message.id.peerId.id
                        dict["peer.namespace"] =  message.id.peerId.namespace
                        
                        notification.userInfo = dict
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                }
            }))
    }
    
    
    
    @objc func receiveWakeNote(_ notificaiton:Notification) {
        account.shouldBeServiceTaskMaster.set(.single(.never) |> then(.single(.now)))
    }


    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        
        
        if let msgId = notification.userInfo?["message.id"] as? Int32, let msgNamespace = notification.userInfo?["message.namespace"] as? Int32, let namespace = notification.userInfo?["peer.namespace"] as? Int32, let id = notification.userInfo?["peer.id"] as? Int32 {
            
            let messageId = MessageId(peerId: PeerId(namespace: namespace, id: id), namespace: msgNamespace, id: msgId)
            
            rightController.push(ChatController(account: account, peerId: messageId.peerId), false)
            
            if notification.activationType == .replied, let text = notification.response?.string {
                var replyToMessageId:MessageId?
                if messageId.peerId.namespace != Namespaces.Peer.CloudUser {
                    replyToMessageId = messageId
                }
                _ = enqueueMessages(account: account, peerId: messageId.peerId, messages: [EnqueueMessage.message(text: text, attributes: [], media: nil, replyToMessageId: replyToMessageId, localGroupingKey: nil)]).start()
            } else {
                self.window.deminiaturize(self)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    
}









private class LegacyPasscodeHeaderView : View {
    
    private let logo:ImageView = ImageView()
    private let header:TextView = TextView()
    private let desc1:TextView = TextView()
    
    private let desc2:TextView = TextView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        let logoImage = #imageLiteral(resourceName: "Icon_LegacyIntro").precomposed()
        self.logo.image = logoImage
        self.logo.sizeToFit()
        let headerLayout = TextViewLayout(NSAttributedString.initialize(string: appName, color: NSColor.text, font: .normal(28.0)), maximumNumberOfLines: 1)
        headerLayout.measure(width: CGFloat.greatestFiniteMagnitude)
        header.update(headerLayout)
        
        
        let descLayout1 = TextViewLayout(NSAttributedString.initialize(string: tr(.legacyIntroDescription1), color: .grayText, font: .normal(FontSize.text)), alignment: .center)
        descLayout1.measure(width: frameRect.width - 200)
        desc1.update(descLayout1)
        
        let descLayout2 = TextViewLayout(NSAttributedString.initialize(string: tr(.legacyIntroDescription2), color: .grayText, font: NSFont.normal(FontSize.text)), alignment: .center)
        descLayout2.measure(width: frameRect.width - 200)
        desc2.update(descLayout2)
        
        addSubview(logo)
        addSubview(header)
        addSubview(desc1)
        addSubview(desc2)
        
        logo.centerX()
        header.centerX(y: logo.frame.maxY + 10)
        desc1.centerX(y: header.frame.maxY + 10)
        desc2.centerX(y: desc1.frame.maxY + 10)
        
        self.setFrameSize(frame.width, desc2.frame.maxY)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class LegacyIntroView : View, NSTextFieldDelegate {
    fileprivate let input:NSSecureTextField
    fileprivate let logoutTextView:TextView = TextView()
    fileprivate let doneButton:TitleButton = TitleButton()
    fileprivate let legacyIntro: LegacyPasscodeHeaderView
    fileprivate var layoutWithPasscode: Bool = false {
        didSet {
            
            self.input.isHidden = !layoutWithPasscode
            self.logoutTextView.isHidden = !layoutWithPasscode
            self.needsLayout = true
            self.needsDisplay = true
        }
    }
    required init(frame frameRect: NSRect) {
        input = NSSecureTextField(frame: NSZeroRect)
        input.stringValue = ""
        legacyIntro = LegacyPasscodeHeaderView(frame: NSMakeRect(0,0, frameRect.width, 300))
        super.init(frame: frameRect)
        
        
        doneButton.set(font: .medium(.header), for: .Normal)
        doneButton.set(text: tr(.legacyIntroNext), for: .Normal)
        
        doneButton.set(color: .blueUI, for: .Normal)
        
        doneButton.sizeToFit()
        addSubview(doneButton)
        
        addSubview(input)
        addSubview(logoutTextView)
        
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.alignment = .center
        input.delegate = self
        
        let attr = NSMutableAttributedString()//Passcode.EnterPasscodePlaceholder
        _ = attr.append(string: tr(.passcodeEnterPasscodePlaceholder), color: .grayText, font: NSFont.normal(FontSize.text))
        attr.setAlignment(.center, range: attr.range)
        input.placeholderAttributedString = attr
        input.font = NSFont.normal(FontSize.text)
        input.textColor = .text
        input.sizeToFit()
        
        let logoutAttr = parseMarkdownIntoAttributedString(tr(.passcodeLostDescription), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedStringKey.link.rawValue, inAppLink.callback(contents, {_ in}))
        }))
        
        logoutTextView.isSelectable = false
        
        logoutTextView.set(layout: TextViewLayout(logoutAttr))
        
        addSubview(legacyIntro)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if !input.isHidden {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(input.frame.minX, input.frame.maxY + 10, input.frame.width, .borderSize))
        }
    }
    
    override func layout() {
        super.layout()
        
        legacyIntro.centerX(y: 80)
        
        logoutTextView.layout?.measure(width: frame.width - 40)
        logoutTextView.update(logoutTextView.layout)
        
        input.setFrameSize(200, input.frame.height)
        input.centerX(y: legacyIntro.frame.maxY + 30)
        logoutTextView.centerX(y:frame.height - logoutTextView.frame.height - 20)
        
        doneButton.centerX(y : (input.isHidden ? legacyIntro.frame.maxY : input.frame.maxY) + 30)
        
        setNeedsDisplayLayer()
        
    }
    

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class LegacyIntroController: GenericViewController<LegacyIntroView> {
    private let disposable:MetaDisposable = MetaDisposable()
    private let promise:Promise<AuthorizationLegacyData>
    private let defaultData:AuthorizationLegacyData
    init(promise:Promise<AuthorizationLegacyData>, defaultLegacyData:AuthorizationLegacyData) {
        self.promise = promise
        self.defaultData = defaultLegacyData
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
        
        genericView.doneButton.set(handler: { [weak self] _ in
            self?.checkCodeAndAuth()
        }, for: .Click)
        
        genericView.input.target = self
        genericView.input.action = #selector(checkCodeAndAuth)
        
        switch defaultData {
        case .data, .none:
            genericView.layoutWithPasscode = false
        case .passcodeRequired:
            genericView.layoutWithPasscode = true
        }
        
        mainWindow.set(responder: { [weak self] () -> NSResponder? in
            return self?.firstResponder()
        }, with: self, priority: .low)
    }
    
    private func logout() {
        promise.set(.single(.none))
    }
    
    @objc private func checkCodeAndAuth() {
        
        switch defaultData {
        case .data:
            promise.set(.single(defaultData))
            break
        case .passcodeRequired:
            if let md5Hash = ObjcUtils.md5(genericView.input.stringValue).data(using: .utf8) {
                var part1: Data = md5Hash.subdata(in : 0 ..< 16)
                var part2: Data = md5Hash.subdata(in : 16 ..< 32)
                
                var zero:UInt8 = 0
                for _ in 0 ..< 16 {
                    part1.append(&zero, count: 1)
                    part2.append(&zero, count: 1)
                }
                
                part1.append(part2)
                
                let legacy = legacyAuthData(passcode: part1, textPasscode: genericView.input.stringValue)
                
                switch legacy {
                case .data:
                    promise.set(.single(legacy))
                case .passcodeRequired:
                    genericView.input.shake()
                case .none:
                    promise.set(.single(.none))
                }
                
            }
            
            
            
        default:
            break
        }
    }
    
    override func firstResponder() -> NSResponder? {
        if !(window?.firstResponder is NSText) {
            return genericView.input
        }
        let editor = self.window?.fieldEditor(true, for: genericView.input)
        if window?.firstResponder != editor {
            return genericView.input
        }
        return editor
        
    }
    
    deinit {
        disposable.dispose()
        mainWindow.removeObserver(for: self)
    }
    
    override func viewClass() -> AnyClass {
        return LegacyIntroView.self
    }
    
}

