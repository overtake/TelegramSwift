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
                        let paslock:Signal<PostboxAccessChallengeData, Void> = !ignorepasslock ? account.postbox.transaction { transaction -> PostboxAccessChallengeData in
                            return transaction.getAccessChallengeData()
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
            }
    } |> switchToLatest
}


enum MigrationData {
    case auth(AccountResult?, ignorepasslock: Bool)
}


func migrationData(accountManager: AccountManager, appGroupPath:String, testingEnvironment: Bool) -> Signal<MigrationData, Void> {
    return currentAccount(networkArguments: NetworkInitializationArguments(apiId: API_ID, languagesCategory: languagesCategory), supplementary: false, manager: accountManager, rootPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> map { account in return .auth(account, ignorepasslock: false) }
}



enum ApplicationContext {
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
        
        rootController = PasscodeLockController(account, .login(hasTouchId: false), logoutImpl: {
            _ = (confirmSignal(for: window, information: tr(L10n.accountConfirmLogoutText)) |> filter {$0} |> mapToSignal {_ in return logoutFromAccount(id: account.id, accountManager: accountManager)}).start()
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


final class UnauthorizedApplicationContext {
    let account: UnauthorizedAccount
    let localizationDisposable:MetaDisposable = MetaDisposable()
    let rootController: MajorNavigationController
    let window:Window
    init(window:Window, account: UnauthorizedAccount, localization: LocalizationSettings?) {
        self.account = account
        self.window = window
        self.rootController = MajorNavigationController(AuthController.self, AuthController(account))
        rootController.alwaysAnimate = true
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
    private let requestAccessDisposable = MetaDisposable()
    private let alertsDisposable = MetaDisposable()
    private let audioDisposable = MetaDisposable()
    private let termDisposable = MetaDisposable()
    private let someActionsDisposable = DisposableSet()
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
        
       

        if let localization = localization {
            applyUILocalization(localization)
        }
        
        if let themeSettings = themeSettings {
            updateTheme(with: themeSettings, for: window)
        } else {
            setDefaultTheme(for: window)
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

        window.navigationController = rightController
        
        leftController = MainViewController(account, accountManager: accountManager);

        
        applicationContext = TelegramApplicationContext(rightController, EntertainmentViewController(size: NSMakeSize(350, window.frame.height), account: account), leftController, network: account.network, postbox: account.postbox)
        
       
        
        account.applicationContext = applicationContext
        
        
        
        leftController.navigationController = rightController
        
        
       
        
        super.init()
        
        termDisposable.set((account.stateManager.termsOfServiceUpdate |> deliverOnMainQueue).start(next: { terms in
            if let terms = terms {
                showModal(with: TermsModalController(account, terms: terms), for: mainWindow)
            } else {
                closeModal(TermsModalController.self)
            }
        }))
        
        applicationContext.switchSplitLayout = { [weak self] layout in
            self?.splitView.state = layout
        }
        
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
        
        let passlock = Signal<Void, Void>.single(Void()) |> delay(15, queue: Queue.concurrentDefaultQueue()) |> restart |> mapToSignal { () -> Signal<Int32?, Void> in
            return account.postbox.transaction { transaction -> Int32? in
                return transaction.getAccessChallengeData().timeout
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
                let controller = PasscodeLockController(account, .login(hasTouchId: false), logoutImpl: { [weak self] in
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
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(windiwDidChangeBackingProperties), name: NSWindow.didChangeBackingPropertiesNotification, object: window)

        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
                
       // NotificationCenter.default.addObserver(self, selector: #selector(windiwDidProfileChanged), name: Notification.Name.ns, object: window)

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveWakeNote(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
                
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsLocked), name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenIsUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)
        
        
        alertsDisposable.set((account.stateManager.displayAlerts |> deliverOnMainQueue).start(next: { alerts in
            for text in alerts {
                alert(for: window, info: text)
            }
        }))
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            
            if let strongSelf = self {
                if !strongSelf._lockedValue.passcodeLock {
                    self?._passlock.set(account.postbox.transaction { transaction -> Bool in
                        switch transaction.getAccessChallengeData() {
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
                strongSelf.applicationContext.mainNavigation?.push(ChatController(account: strongSelf.account, chatLocation: .peer(strongSelf.account.peerId)))
            }
            return .invoked
        }, with: self, for: .Zero, priority: .low, modifierFlags: [.command])
        
        

        
        
        suggestedLocalizationDisposable.set(( account.postbox.preferencesView(keys: [PreferencesKeys.suggestedLocalization]) |> mapToSignal { preferences -> Signal<SuggestedLocalizationInfo, Void> in
            
            let preferences = preferences.values[PreferencesKeys.suggestedLocalization] as? SuggestedLocalizationEntry
            if preferences == nil || !preferences!.isSeen, preferences?.languageCode != appCurrentLanguage.languageCode, preferences?.languageCode != "en" {
                let current = Locale.preferredLanguages[0]
                let split = current.split(separator: "-")
                let lan: String = !split.isEmpty ? String(split[0]) : "en"
                if lan != "en" {
                    return suggestedLocalizationInfo(network: account.network, languageCode: lan, extractKeys: ["Suggest.Localization.Header", "Suggest.Localization.Other"]) |> take(1)
                }
            }
            return .complete()
        } |> deliverOnMainQueue).start(next: { suggestionInfo in
            if suggestionInfo.availableLocalizations.count >= 2 {
                showModal(with: SuggestionLocalizationViewController(account, suggestionInfo: suggestionInfo), for: window)
            }
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
        
        
        audioDisposable.set(globalAudioPromise.get().start(next: { [weak self] controller in
            self?.prepareTouchBarAccessability(controller)
        }))
        
        someActionsDisposable.add(managedUpdatedRecentPeers(postbox: account.postbox, network: account.network).start())
        
    }
    
    
    private func prepareTouchBarAccessability(_ controller: APController?) {
        setTextViewEnableTouchBar(controller == nil)
        viewEnableTouchBar = controller == nil
        if #available(OSX 10.12.2, *) {
            NSApp.touchBar = nil
            window.touchBar = nil
            window.firstResponder?.touchBar = nil
            if !viewEnableTouchBar {
                //window.applyResponderIfNeeded()
            } 
        } else {
            // Fallback on earlier versions
        }
    }
    
   
    
    var isLocked: Bool {
        return _lockedValue.isLocked
    }
    
    
    func logout() {
        self.logoutDisposable.set((confirmSignal(for: window, information: tr(L10n.accountConfirmLogoutText)) |> filter {$0} |> mapToSignal { [weak self] _ -> Signal<Void, Void> in
            if let strongSelf = self {
                return logoutFromAccount(id: strongSelf.account.id, accountManager: strongSelf.accountManager)
            }
            return .complete()
        }).start())
    }
    
    @objc public func windiwDidProfileChanged() {
        var bp:Int = 0
        bp += 1
    }
    
    
    @objc public func windowDidBecomeKey() {
        self.resignTimestamp = nil
    }
    
    @objc public func windiwDidChangeBackingProperties() {
        _ = System.scaleFactor.swap(window.backingScaleFactor)
    }
    
    
    @objc public func windowDidResignKey() {
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
            _passlock.set(account.postbox.transaction { transaction -> Bool in
                switch transaction.getAccessChallengeData() {
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
        requestAccessDisposable.dispose()
        audioDisposable.dispose()
        alertsDisposable.dispose()
        termDisposable.dispose()
        viewer?.close()
        someActionsDisposable.dispose()
        
        for window in NSApp.windows {
            if window != self.window {
                window.orderOut(nil)
            }
        }
    }
    
    
    func startNotifyListener(with account: Account) {
        
        let lockedSreenSignal = lockedScreenPromise.get()
        
        self.nofityDisposable.set((account.stateManager.notificationMessages |> mapToSignal { messages -> Signal<([(Message, PeerGroupId?)], InAppNotificationSettings), Void> in
            return account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.inAppNotificationSettings]) |> mapToSignal { (settings) -> Signal<([(Message, PeerGroupId?)], InAppNotificationSettings), Void> in
                
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
            |> mapToSignal { messages, inAppSettings -> Signal<([(Message, PeerGroupId?)],[MessageId:NSImage], InAppNotificationSettings), Void> in
                
                var photos:[Signal<(MessageId, CGImage?),Void>] = []
                for message in messages {
                    var peer = message.0.author
                    if let mainPeer = messageMainPeer(message.0) {
                        if mainPeer is TelegramChannel || mainPeer is TelegramGroup {
                            peer = mainPeer
                        }
                    }
                    if let peer = peer {
                        photos.append(peerAvatarImage(account: account, photo: .peer(peer.id, peer.smallProfileImage, peer.displayLetters), genCap: false) |> map { data in return (message.0.id, data.0)})
                    }
                }
                
                return  combineLatest(photos) |> map { resources in
                    var images:[MessageId:NSImage] = [:]
                    for (messageId,image) in resources {
                        if let image = image {
                            images[messageId] = NSImage(cgImage: image, size: NSMakeSize(50,50))
                        }
                    }
                    return (messages, images, inAppSettings)
                }
            } |> mapToSignal { messages, images, inAppSettings -> Signal<([(Message, PeerGroupId?)],[MessageId:NSImage], InAppNotificationSettings, Bool), Void> in
                return lockedSreenSignal |> take(1)
                    |> map { data in return (messages, images, inAppSettings, data.isLocked)}
            }
            |> mapToSignal { values in
                return _callSession() |> map { s in
                    return (values.0, values.1, values.2, values.3, s != nil)
                }
            } |> deliverOnMainQueue).start(next: { messages, images, inAppSettings, screenIsLocked, inCall in
                for (message, groupId) in messages {
                    if message.author?.id != account.peerId {
                        var title:String = message.author?.displayTitle ?? ""
                        var hasReplyButton:Bool = !screenIsLocked
                        if let peer = message.peers[message.id.peerId] {
                            if peer.isSupergroup || peer.isGroup {
                                title = peer.displayTitle
                                hasReplyButton = peer.canSendMessage
                            } else if peer.isChannel {
                                hasReplyButton = false
                            }
                        }
                        if screenIsLocked {
                            title = appName
                        }
                        var text = chatListText(account: account, location: .peer(message.id.peerId), for: message).string.nsstring
                        var subText:String?
                        if text.contains("\n") {
                            let parts = text.components(separatedBy: "\n")
                            text = parts[1] as NSString
                            subText = parts[0]
                        }
                        
                        if !inAppSettings.displayPreviews || message.peers[message.id.peerId] is TelegramSecretChat || screenIsLocked {
                            text = tr(L10n.notificationLockedPreview).nsstring
                            subText = nil
                        }
                        
                        let notification = NSUserNotification()
                        notification.title = title
                        notification.informativeText = text as String
                        notification.subtitle = subText
                        notification.contentImage = screenIsLocked ? nil : images[message.id]
                        notification.hasReplyButton = hasReplyButton


                        var dict: [String : Any] = [:]

                        
                        if let row = message.replyMarkup?.rows.first, message.id.peerId.id == 777000, row.buttons.count == 2 && !screenIsLocked {
                            notification.hasReplyButton = false
                            notification.hasActionButton = true
                            notification.actionButtonTitle = row.buttons[0].title
                            notification.otherButtonTitle = row.buttons[1].title
                            if let _ = notification.value(forKey: "_showsButtons") {
                                notification.setValue(true, forKey: "_showsButtons")
                            }
                            
                            switch row.buttons[0].action {
                            case .callback(let data):
                                dict["inline.callbackDecline"] = data.makeData()
                            default:
                                break
                            }
                            
                            switch row.buttons[1].action {
                            case .callback(let data):
                                
                                dict["inline.callbackConfirm"] = data.makeData()
                            default:
                                break
                            }
                        }
                        
                        if localizedString(inAppSettings.tone) != tr(L10n.notificationSettingsToneNone) {
                            notification.soundName = inAppSettings.tone
                        } else {
                            notification.soundName = nil
                        }
                        
                        if message.muted || inCall {
                            notification.soundName = nil
                        }
                        
                        
                        
                        dict["message.id"] =  message.id.id
                        dict["message.namespace"] =  message.id.namespace
                        dict["peer.id"] =  message.id.peerId.id
                        dict["peer.namespace"] =  message.id.peerId.namespace
                        dict["groupId"] = groupId?.rawValue
                        
                        if screenIsLocked {
                            dict = [:]
                        }
                        
                        notification.userInfo = dict
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                }
            }))
    }
    
    
    
    @objc func receiveWakeNote(_ notificaiton:Notification) {
        account.shouldBeServiceTaskMaster.set(.single(.never) |> then(.single(.now)))
    }


     @objc private func userNotificationCenter(_ center: NSUserNotificationCenter, didDismissAlert notification: NSUserNotification) {
        if let userInfo = notification.userInfo, let msgId = userInfo["message.id"] as? Int32, let msgNamespace = userInfo["message.namespace"] as? Int32, let namespace = userInfo["peer.namespace"] as? Int32, let id = userInfo["peer.id"] as? Int32, let callbackData = userInfo["inline.callbackConfirm"] as? Data {
            let messageId = MessageId(peerId: PeerId(namespace: namespace, id: id), namespace: msgNamespace, id: msgId)
            
            requestAccessDisposable.set(requestMessageActionCallback(account: account, messageId: messageId, isGame: false, data: MemoryBuffer(data: callbackData)).start())
            _ = applyMaxReadIndexInteractively(postbox: self.account.postbox, stateManager: self.account.stateManager, index: MessageIndex.upperBound(peerId: messageId.peerId)).start()
        }
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        
        
        if let userInfo = notification.userInfo, let msgId = userInfo["message.id"] as? Int32, let msgNamespace = userInfo["message.namespace"] as? Int32, let namespace = userInfo["peer.namespace"] as? Int32, let id = userInfo["peer.id"] as? Int32 {
            
            let messageId = MessageId(peerId: PeerId(namespace: namespace, id: id), namespace: msgNamespace, id: msgId)
            
            if let callbackData = userInfo["inline.callbackDecline"] as? Data {
                requestAccessDisposable.set(requestMessageActionCallback(account: account, messageId: messageId, isGame: false, data: MemoryBuffer(data: callbackData)).start())
                _ = applyMaxReadIndexInteractively(postbox: self.account.postbox, stateManager: self.account.stateManager, index: MessageIndex.upperBound(peerId: messageId.peerId)).start()
                return
            }
            
            
            let location: ChatLocation
            if let groupId = notification.userInfo?["groupId"] as? Int32 {
                location = .group(PeerGroupId(rawValue: groupId))
            } else {
                location = .peer(messageId.peerId)
            }
            
            rightController.push(ChatController(account: account, chatLocation: location), false)
            
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
        
        
        let descLayout1 = TextViewLayout(NSAttributedString.initialize(string: tr(L10n.legacyIntroDescription1), color: .grayText, font: .normal(FontSize.text)), alignment: .center)
        descLayout1.measure(width: frameRect.width - 200)
        desc1.update(descLayout1)
        
        let descLayout2 = TextViewLayout(NSAttributedString.initialize(string: tr(L10n.legacyIntroDescription2), color: .grayText, font: NSFont.normal(FontSize.text)), alignment: .center)
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
        backgroundColor = .white
        
        doneButton.set(font: .medium(.header), for: .Normal)
        doneButton.set(text: tr(L10n.legacyIntroNext), for: .Normal)
        
        doneButton.set(color: .blueUI, for: .Normal)
        
        _ = doneButton.sizeToFit()
        addSubview(doneButton)
        
        addSubview(input)
        addSubview(logoutTextView)
        
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.alignment = .center
        input.delegate = self
        
        let attr = NSMutableAttributedString()//Passcode.EnterPasscodePlaceholder
        _ = attr.append(string: tr(L10n.passcodeEnterPasscodePlaceholder), color: .grayText, font: NSFont.normal(FontSize.text))
        attr.setAlignment(.center, range: attr.range)
        input.placeholderAttributedString = attr
        input.font = NSFont.normal(FontSize.text)
        input.textColor = .text
        input.sizeToFit()
        
        let logoutAttr = parseMarkdownIntoAttributedString(tr(L10n.passcodeLostDescription), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
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

