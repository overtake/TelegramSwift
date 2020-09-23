//
//  AccountContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TGUIKit
import SyncCore

protocol ChatLocationContextHolder: class {
}



enum ChatLocation: Equatable {
    case peer(PeerId)
    case replyThread(ChatReplyThreadMessage)
}



struct TemporaryPasswordContainer {
    let date: TimeInterval
    let password: String
    
    var isActive: Bool {
        return date + 15 * 60 > Date().timeIntervalSince1970
    }
}

enum ApplyThemeUpdate {
    case local(ColorPalette)
    case cloud(TelegramTheme)
}

final class AccountContextBindings {
    #if !SHARE
    let rootNavigation: () -> MajorNavigationController
    let mainController: () -> MainViewController
    let showControllerToaster: (ControllerToaster, Bool) -> Void
    let globalSearch:(String)->Void
    let switchSplitLayout:(SplitViewState)->Void
    let entertainment:()->EntertainmentViewController
    let needFullsize:()->Void
    let displayUpgradeProgress:(CGFloat)->Void
    init(rootNavigation: @escaping() -> MajorNavigationController = { fatalError() }, mainController: @escaping() -> MainViewController = { fatalError() }, showControllerToaster: @escaping(ControllerToaster, Bool) -> Void = { _, _ in fatalError() }, globalSearch: @escaping(String) -> Void = { _ in fatalError() }, entertainment: @escaping()->EntertainmentViewController = { fatalError() }, switchSplitLayout: @escaping(SplitViewState)->Void = { _ in fatalError() }, needFullsize: @escaping() -> Void = { fatalError() }, displayUpgradeProgress: @escaping(CGFloat)->Void = { _ in fatalError() }) {
        self.rootNavigation = rootNavigation
        self.mainController = mainController
        self.showControllerToaster = showControllerToaster
        self.globalSearch = globalSearch
        self.entertainment = entertainment
        self.switchSplitLayout = switchSplitLayout
        self.needFullsize = needFullsize
        self.displayUpgradeProgress = displayUpgradeProgress
    }
    #endif
}

private var lastTimeFreeSpaceNotified: TimeInterval?


final class AccountContext {
    let sharedContext: SharedAccountContext
    let account: Account
    let window: Window

    #if !SHARE
    let fetchManager: FetchManager
    let diceCache: DiceCache
    #endif
    private(set) var timeDifference:TimeInterval  = 0
    #if !SHARE
    let peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager()
    let chatUndoManager = ChatUndoManager()
    let blockedPeersContext: BlockedPeersContext
    let activeSessionsContext: ActiveSessionsContext
    let cacheCleaner: AccountClearCache

 //   let walletPasscodeTimeoutContext: WalletPasscodeTimeoutContext
    #endif
    
    let cancelGlobalSearch:ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    

    
    var isCurrent: Bool = false {
        didSet {
            if !self.isCurrent {
                //self.callManager = nil
            }
        }
    }
    
    
    let globalPeerHandler:Promise<ChatLocation?> = Promise()
    
    func updateGlobalPeer() {
        globalPeerHandler.set(globalPeerHandler.get() |> take(1))
    }
    
    let hasPassportSettings: Promise<Bool> = Promise(false)

    private var _recentlyPeerUsed:[PeerId] = []

    private(set) var recentlyPeerUsed:[PeerId] {
        set {
            _recentlyPeerUsed = newValue
        }
        get {
            if _recentlyPeerUsed.count > 2 {
                return Array(_recentlyPeerUsed.prefix(through: 2))
            } else {
                return _recentlyPeerUsed
            }
        }
    }
    
    var peerId: PeerId {
        return account.peerId
    }
    
    private let updateDifferenceDisposable = MetaDisposable()
    private let temporaryPwdDisposable = MetaDisposable()
    private let actualizeCloudTheme = MetaDisposable()
    private let applyThemeDisposable = MetaDisposable()
    private let cloudThemeObserver = MetaDisposable()
    private let freeSpaceDisposable = MetaDisposable()
    private let prefDisposable = DisposableSet()
    private let _limitConfiguration: Atomic<LimitsConfiguration> = Atomic(value: LimitsConfiguration.defaultValue)
    
    var limitConfiguration: LimitsConfiguration {
        return _limitConfiguration.with { $0 }
    }
    
    private let _appConfiguration: Atomic<AppConfiguration> = Atomic(value: AppConfiguration.defaultValue)
    
    var appConfiguration: AppConfiguration {
        return _appConfiguration.with { $0 }
    }
    
    
    private let isKeyWindowValue: ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    var isKeyWindow: Signal<Bool, NoError> {
        return isKeyWindowValue.get() |> deliverOnMainQueue
    }
    
    private let _autoplayMedia: Atomic<AutoplayMediaPreferences> = Atomic(value: AutoplayMediaPreferences.defaultSettings)
    
    var autoplayMedia: AutoplayMediaPreferences {
        return _autoplayMedia.with { $0 }
    }
    

    var isInGlobalSearch: Bool = false
    
    
    private let _contentSettings: Atomic<ContentSettings> = Atomic(value: ContentSettings.default)
    
    var contentSettings: ContentSettings {
        return _contentSettings.with { $0 }
    }
    
   // public let tonContext: StoredTonContext!
    
    public var closeFolderFirst: Bool = false
    
    private let preloadGifsDisposable = MetaDisposable()
    
    
    //, tonContext: StoredTonContext?
    init(sharedContext: SharedAccountContext, window: Window, account: Account) {
        self.sharedContext = sharedContext
        self.account = account
        self.window = window
       // self.tonContext = tonContext
        #if !SHARE
        self.diceCache = DiceCache(postbox: account.postbox, network: account.network)
        self.fetchManager = FetchManager(postbox: account.postbox)
        self.blockedPeersContext = BlockedPeersContext(account: account)
        self.activeSessionsContext = ActiveSessionsContext(account: account)
        self.cacheCleaner = AccountClearCache(account: account)
     //   self.walletPasscodeTimeoutContext = WalletPasscodeTimeoutContext(postbox: account.postbox)
        #endif
        
        
        repliesPeerId = account.testingEnvironment ? test_repliesPeerId : prod_repliesPeerId
        
        let limitConfiguration = _limitConfiguration
        prefDisposable.add(account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration]).start(next: { view in
            _ = limitConfiguration.swap(view.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration ?? LimitsConfiguration.defaultValue)
        }))
        let preloadGifsDisposable = self.preloadGifsDisposable
        let appConfiguration = _appConfiguration
        prefDisposable.add(account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]).start(next: { view in
            let configuration = view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? AppConfiguration.defaultValue
            _ = appConfiguration.swap(configuration)
            
            
        }))
        
        #if !SHARE
        let signal:Signal<Void, NoError> = Signal { subscriber in
            
            let signal: Signal<Never, NoError> = account.postbox.transaction {
                return $0.getPreferencesEntry(key: PreferencesKeys.appConfiguration) as? AppConfiguration ?? AppConfiguration.defaultValue
            } |> mapToSignal { configuration in
                let value = GIFKeyboardConfiguration.with(appConfiguration: configuration)
                var signals = value.emojis.map {
                    searchGifs(account: account, query: $0)
                }
                signals.insert(searchGifs(account: account, query: ""), at: 0)
                return combineLatest(signals) |> ignoreValues
            }
            
            let disposable = signal.start(completed: {
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                disposable.dispose()
            }
        }
        
        let updated = (signal |> then(.complete() |> suspendAwareDelay(20.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
        preloadGifsDisposable.set(updated.start())
        
        #endif
        
        let autoplayMedia = _autoplayMedia
        prefDisposable.add(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.autoplayMedia]).start(next: { view in
            _ = autoplayMedia.swap(view.values[ApplicationSpecificPreferencesKeys.autoplayMedia] as? AutoplayMediaPreferences ?? AutoplayMediaPreferences.defaultSettings)
        }))
        
        let contentSettings = _contentSettings
        prefDisposable.add(getContentSettings(postbox: account.postbox).start(next: { settings in
            _ = contentSettings.swap(settings)
        }))
        
        
        globalPeerHandler.set(.single(nil))
        
        if account.network.globalTime > 0 {
            timeDifference = floor(account.network.globalTime - Date().timeIntervalSince1970)
        }
        
        updateDifferenceDisposable.set((Signal<Void, NoError>.single(Void())
            |> delay(5, queue: Queue.mainQueue()) |> restart).start(next: { [weak self, weak account] in
                if let account = account, account.network.globalTime > 0 {
                    self?.timeDifference = floor(account.network.globalTime - Date().timeIntervalSince1970)
                }
        }))
        
        
        let cloudSignal = themeUnmodifiedSettings(accountManager: sharedContext.accountManager) |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
            return lhs.cloudTheme == rhs.cloudTheme
        })
        |> map { value in
            return (value.cloudTheme, value.palette)
        }
        |> deliverOnMainQueue
        
        cloudThemeObserver.set(cloudSignal.start(next: { [weak self] (cloud, palette) in
            let update: ApplyThemeUpdate
            if let cloud = cloud {
                update = .cloud(cloud)
            } else {
                update = .local(palette)
            }
            self?.updateTheme(update)
        }))
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateKeyWindow), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(updateKeyWindow), name: NSWindow.didResignKeyNotification, object: window)
        
        
        #if !SHARE
        var freeSpaceSignal:Signal<UInt64?, NoError> = Signal { subscriber in
            
            subscriber.putNext(freeSystemGygabytes())
            subscriber.putCompletion()
            
            return ActionDisposable {
                
        }
        } |> runOn(.concurrentDefaultQueue())
        
        freeSpaceSignal = (freeSpaceSignal |> then(.complete() |> suspendAwareDelay(60.0 * 30, queue: Queue.concurrentDefaultQueue()))) |> restart
        
        
        let isLocked = (NSApp.delegate as? AppDelegate)?.passlock ?? .single(false)
        
        
        freeSpaceDisposable.set(combineLatest(queue: .mainQueue(), freeSpaceSignal, isKeyWindow, isLocked).start(next: { [weak self] space, isKeyWindow, locked in
            
            
            let limit: UInt64 = 5
            
            guard let `self` = self, isKeyWindow, !locked, let space = space, space < limit else {
                return
            }
            if lastTimeFreeSpaceNotified == nil || (lastTimeFreeSpaceNotified! + 60.0 * 60.0 * 3 < Date().timeIntervalSince1970) {
                lastTimeFreeSpaceNotified = Date().timeIntervalSince1970
                showOutOfMemoryWarning(window, freeSpace: space, context: self)
            }
            
        }))
        
        account.callSessionManager.updateVersions(versions: OngoingCallContext.versions(includeExperimental: true, includeReference: false).map { version, supportsVideo -> CallSessionManagerImplementationVersion in
            CallSessionManagerImplementationVersion(version: version, supportsVideo: supportsVideo)
        })
        
        #endif
    }
    
    @objc private func updateKeyWindow() {
        self.isKeyWindowValue.set(window.isKeyWindow)
    }
    
    private func updateTheme(_ update: ApplyThemeUpdate) {
        switch update {
        case let .cloud(cloudTheme):
            _ = applyTheme(accountManager: self.sharedContext.accountManager, account: self.account, theme: cloudTheme).start()
            let signal = actualizedTheme(account: self.account, accountManager: self.sharedContext.accountManager, theme: cloudTheme) |> deliverOnMainQueue
            self.actualizeCloudTheme.set(signal.start(next: { [weak self] cloudTheme in
                if let `self` = self {
                    self.applyThemeDisposable.set(downloadAndApplyCloudTheme(context: self, theme: cloudTheme, install: theme.cloudTheme?.id != cloudTheme.id).start())
                }
            }))
        case let .local(palette):
            actualizeCloudTheme.set(applyTheme(accountManager: self.sharedContext.accountManager, account: self.account, theme: nil).start())
            applyThemeDisposable.set(updateThemeInteractivetly(accountManager: self.sharedContext.accountManager, f: {
                return $0.withUpdatedPalette(palette).withUpdatedCloudTheme(nil)
            }).start())
        }
    }
    
    var timestamp: Int32 {
        var time:TimeInterval = TimeInterval(Date().timeIntervalSince1970)
        time -= self.timeDifference
        return Int32(time)
    }
    

    private var _temporartPassword: String?
    var temporaryPassword: String? {
        return _temporartPassword
    }
    
    func resetTemporaryPwd() {
        _temporartPassword = nil
        temporaryPwdDisposable.set(nil)
    }
    
    func setTemporaryPwd(_ password: String) -> Void {
        _temporartPassword = password
        let signal = Signal<Void, NoError>.single(Void()) |> delay(30 * 60, queue: Queue.mainQueue())
        temporaryPwdDisposable.set(signal.start(next: { [weak self] in
            self?._temporartPassword = nil
        }))
    }
    
    deinit {
       cleanup()
    }
    
    
    func cleanup() {
        updateDifferenceDisposable.dispose()
        temporaryPwdDisposable.dispose()
        prefDisposable.dispose()
        actualizeCloudTheme.dispose()
        applyThemeDisposable.dispose()
        cloudThemeObserver.dispose()
        preloadGifsDisposable.dispose()
        freeSpaceDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
        #if !SHARE
      //  self.walletPasscodeTimeoutContext.clear()
        self.diceCache.cleanup()
        #endif
    }
   
    
    func checkFirstRecentlyForDuplicate(peerId:PeerId) {
        if let index = recentlyPeerUsed.firstIndex(of: peerId), index == 0 {
            recentlyPeerUsed.remove(at: index)
        }
    }
    
    func addRecentlyUsedPeer(peerId:PeerId) {
        if let index = recentlyPeerUsed.firstIndex(of: peerId) {
            recentlyPeerUsed.remove(at: index)
        }
        recentlyPeerUsed.insert(peerId, at: 0)
        if recentlyPeerUsed.count > 4 {
            recentlyPeerUsed = Array(recentlyPeerUsed.prefix(through: 4))
        }
    }
    
    
    func chatLocationInput(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> ChatLocationInput {
        switch location {
        case let .peer(peerId):
            return .peer(peerId)
        case let .replyThread(data):
            let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
            return .external(data.messageId.peerId, context.state)
        }
    }
    
    func chatLocationOutgoingReadState(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<MessageId?, NoError> {
        switch location {
        case .peer:
            return .single(nil)
        case let .replyThread(data):
            let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
            return context.maxReadOutgoingMessageId
        }
    }


    
    func applyMaxReadIndex(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>, messageIndex: MessageIndex) {
        switch location {
        case .peer:
            let _ = applyMaxReadIndexInteractively(postbox: self.account.postbox, stateManager: self.account.stateManager, index: messageIndex).start()
        case let .replyThread(data):
            let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
            context.applyMaxReadIndex(messageIndex: messageIndex)
        }
    }




    
    #if !SHARE
    func composeCreateGroup() {
        createGroup(with: self)
    }
    func composeCreateChannel() {
        createChannel(with: self)
    }
    func composeCreateSecretChat() {
        let account = self.account
        let confirmationImpl:([PeerId])->Signal<Bool, NoError> = { peerIds in
            if let first = peerIds.first, peerIds.count == 1 {
                return account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                    return confirmSignal(for: mainWindow, information: L10n.composeConfirmStartSecretChat(peer.displayTitle))
                }
            }
            return confirmSignal(for: mainWindow, information: L10n.peerInfoConfirmAddMembers1Countable(peerIds.count))
        }
        let select = selectModalPeers(context: self, title: L10n.composeSelectSecretChat, limit: 1, confirmation: confirmationImpl)
        
        let create = select |> map { $0.first! } |> mapToSignal { peerId in
            return createSecretChat(account: account, peerId: peerId) |> `catch` {_ in .complete()}
            } |> deliverOnMainQueue |> mapToSignal{ peerId -> Signal<PeerId, NoError> in
                return showModalProgress(signal: .single(peerId), for: mainWindow)
        }
        
        _ = create.start(next: { [weak self] peerId in
            guard let `self` = self else {return}
            self.sharedContext.bindings.rootNavigation().push(ChatController(context: self, chatLocation: .peer(peerId)))
        })
    }
    #endif
}


func downloadAndApplyCloudTheme(context: AccountContext, theme cloudTheme: TelegramTheme, install: Bool = false) -> Signal<Never, Void> {
    if let cloudSettings = cloudTheme.settings {
        return Signal { subscriber in
            #if !SHARE
            let wallpaperDisposable = DisposableSet()
            let palette = cloudSettings.palette
            var wallpaper: Signal<TelegramWallpaper?, GetWallpaperError>? = nil
            let associated = theme.wallpaper.associated?.wallpaper
            if let w = cloudSettings.wallpaper, theme.wallpaper.wallpaper == associated || install {
                wallpaper = .single(w)
            } else if install, let wrapper = palette.wallpaper.wallpaper.cloudWallpaper {
                wallpaper = .single(wrapper)
            }
            
            if let wallpaper = wallpaper {
                wallpaperDisposable.add(wallpaper.start(next: { cloud in
                    if let cloud = cloud {
                        let wp = Wallpaper(cloud)
                        wallpaperDisposable.add(moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wp).start(next: { wallpaper in
                            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                                var settings = settings.withUpdatedPalette(palette).withUpdatedCloudTheme(cloudTheme)
                                var updateDefault:DefaultTheme = palette.isDark ? settings.defaultDark : settings.defaultDay
                                updateDefault = updateDefault.updateCloud { _ in
                                    return DefaultCloudTheme(cloud: cloudTheme, palette: palette, wallpaper: AssociatedWallpaper(cloud: cloud, wallpaper: wp))
                                }
                                settings = palette.isDark ? settings.withUpdatedDefaultDark(updateDefault) : settings.withUpdatedDefaultDay(updateDefault)
                                settings = settings.withUpdatedDefaultIsDark(palette.isDark)
                                return settings.updateWallpaper { value in
                                    return value.withUpdatedWallpaper(wallpaper)
                                        .withUpdatedAssociated(AssociatedWallpaper(cloud: cloud, wallpaper: wallpaper))
                                }.saveDefaultWallpaper().withSavedAssociatedTheme().saveDefaultAccent(color: cloudSettings.accent)
                            }).start()
                            
                            subscriber.putCompletion()
                        }))
                    } else {
                        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                            var settings = settings
                            var updateDefault:DefaultTheme = palette.isDark ? settings.defaultDark : settings.defaultDay
                            updateDefault = updateDefault.updateCloud { _ in
                                return DefaultCloudTheme(cloud: cloudTheme, palette: palette, wallpaper: AssociatedWallpaper(cloud: cloud, wallpaper: .none))
                            }
                            settings = palette.isDark ? settings.withUpdatedDefaultDark(updateDefault) : settings.withUpdatedDefaultDay(updateDefault)
                            settings = settings.withUpdatedDefaultIsDark(palette.isDark)
                            
                            return settings.withUpdatedPalette(palette).withUpdatedCloudTheme(cloudTheme).updateWallpaper({ value in
                                return value.withUpdatedWallpaper(.none)
                                    .withUpdatedAssociated(AssociatedWallpaper(cloud: cloud, wallpaper: .none))
                            }).saveDefaultWallpaper().withSavedAssociatedTheme().saveDefaultAccent(color: cloudSettings.accent)
                        }).start()
                        subscriber.putCompletion()
                    }
                }, error: { _ in
                    subscriber.putCompletion()
                }))
            } else {
                _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                    var settings = settings.withUpdatedPalette(palette).withUpdatedCloudTheme(cloudTheme)
                    var updateDefault:DefaultTheme = palette.isDark ? settings.defaultDark : settings.defaultDay
                    updateDefault = updateDefault.updateCloud { current in
                        let associated = current?.wallpaper ?? AssociatedWallpaper(cloud: nil, wallpaper: palette.wallpaper.wallpaper)
                        return DefaultCloudTheme(cloud: cloudTheme, palette: palette, wallpaper: associated)
                    }
                    settings = palette.isDark ? settings.withUpdatedDefaultDark(updateDefault) : settings.withUpdatedDefaultDay(updateDefault)
                    return settings.withSavedAssociatedTheme().saveDefaultAccent(color: cloudSettings.accent)
                }).start()
                subscriber.putCompletion()
            }
            #endif
            return ActionDisposable {
                #if !SHARE
                wallpaperDisposable.dispose()
                #endif
            }
        }
        |> runOn(.mainQueue())
        |> deliverOnMainQueue
    } else if let file = cloudTheme.file {
        return Signal { subscriber in
            let fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: file.resource)).start()
            let wallpaperDisposable = DisposableSet()
            
            let resourceData = context.account.postbox.mediaBox.resourceData(file.resource) |> filter { $0.complete } |> take(1)

            let dataDisposable = resourceData.start(next: { data in
                
                if let palette = importPalette(data.path) {                    
                    var wallpaper: Signal<TelegramWallpaper?, GetWallpaperError>? = nil
                    var newSettings: WallpaperSettings = WallpaperSettings()
                    #if !SHARE
                    switch palette.wallpaper {
                    case .none:
                        if theme.wallpaper.wallpaper == theme.wallpaper.associated?.wallpaper || install {
                            wallpaper = .single(nil)
                        }
                    case .builtin:
                        if theme.wallpaper.wallpaper == theme.wallpaper.associated?.wallpaper || install {
                            wallpaper = .single(.builtin(WallpaperSettings()))
                        }
                    case let .color(color):
                        if theme.wallpaper.wallpaper == theme.wallpaper.associated?.wallpaper || install {
                            wallpaper = .single(.color(color.argb))
                        }
                    case let .url(string):
                        let link = inApp(for: string as NSString, context: context)
                        switch link {
                        case let .wallpaper(values):
                            switch values.preview {
                            case let .slug(slug, settings):
                                if theme.wallpaper.wallpaper == theme.wallpaper.associated?.wallpaper || install {
                                    if let associated = theme.wallpaper.associated, let cloud = associated.cloud {
                                        switch cloud {
                                        case let .file(values):
                                            if values.slug == values.slug && values.settings == settings {
                                                wallpaper = .single(cloud)
                                            } else {
                                                wallpaper = getWallpaper(network: context.account.network, slug: slug) |> map(Optional.init)
                                            }
                                        default:
                                            wallpaper = getWallpaper(network: context.account.network, slug: slug) |> map(Optional.init)
                                        }
                                    } else {
                                        wallpaper = getWallpaper(network: context.account.network, slug: slug) |> map(Optional.init)
                                    }
                                }
                                newSettings = settings
                            default:
                                break
                            }
                        default:
                            break
                        }
                    }
                   
                    #endif
                    
                    if let wallpaper = wallpaper {
                        #if !SHARE
                        wallpaperDisposable.add(wallpaper.start(next: { cloud in
                            if let cloud = cloud {
                                let wp = Wallpaper(cloud).withUpdatedSettings(newSettings)
                                wallpaperDisposable.add(moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wp).start(next: { wallpaper in
                                    _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                                        var settings = settings.withUpdatedPalette(palette).withUpdatedCloudTheme(cloudTheme)
                                        var updateDefault:DefaultTheme = palette.isDark ? settings.defaultDark : settings.defaultDay
                                        updateDefault = updateDefault.updateCloud { _ in
                                            return DefaultCloudTheme(cloud: cloudTheme, palette: palette, wallpaper: AssociatedWallpaper(cloud: cloud, wallpaper: wp))
                                        }
                                        settings = palette.isDark ? settings.withUpdatedDefaultDark(updateDefault) : settings.withUpdatedDefaultDay(updateDefault)
                                        settings = settings.withUpdatedDefaultIsDark(palette.isDark)
                                        return settings.updateWallpaper { value in
                                            return value.withUpdatedWallpaper(wallpaper)
                                                .withUpdatedAssociated(AssociatedWallpaper(cloud: cloud, wallpaper: wallpaper))
                                        }.saveDefaultWallpaper()
                                    }).start()
                                    
                                    subscriber.putCompletion()
                                }))
                            } else {
                                _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                                    var settings = settings
                                    var updateDefault:DefaultTheme = palette.isDark ? settings.defaultDark : settings.defaultDay
                                    updateDefault = updateDefault.updateCloud { _ in
                                        return DefaultCloudTheme(cloud: cloudTheme, palette: palette, wallpaper: AssociatedWallpaper(cloud: cloud, wallpaper: .none))
                                    }
                                    settings = palette.isDark ? settings.withUpdatedDefaultDark(updateDefault) : settings.withUpdatedDefaultDay(updateDefault)
                                    settings = settings.withUpdatedDefaultIsDark(palette.isDark)
                                    
                                    return settings.withUpdatedPalette(palette).withUpdatedCloudTheme(cloudTheme).updateWallpaper({ value in
                                        return value.withUpdatedWallpaper(.none)
                                            .withUpdatedAssociated(AssociatedWallpaper(cloud: cloud, wallpaper: .none))
                                    }).saveDefaultWallpaper()
                                }).start()
                                subscriber.putCompletion()
                            }
                        }, error: { _ in
                            subscriber.putCompletion()
                        }))
                        #endif
                    } else {
                        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                            var settings = settings.withUpdatedPalette(palette).withUpdatedCloudTheme(cloudTheme)
                            var updateDefault:DefaultTheme = palette.isDark ? settings.defaultDark : settings.defaultDay
                            updateDefault = updateDefault.updateCloud { current in
                                let associated = current?.wallpaper ?? AssociatedWallpaper(cloud: nil, wallpaper: palette.wallpaper.wallpaper)
                                return DefaultCloudTheme(cloud: cloudTheme, palette: palette, wallpaper: associated)
                            }
                            settings = palette.isDark ? settings.withUpdatedDefaultDark(updateDefault) : settings.withUpdatedDefaultDay(updateDefault)
                            return settings
                        }).start()
                        subscriber.putCompletion()
                    }
                }
            })
            
            return ActionDisposable {
                fetchDisposable.dispose()
                dataDisposable.dispose()
                wallpaperDisposable.dispose()
            }
        }
        |> runOn(.mainQueue())
        |> deliverOnMainQueue
    } else {
        return .complete()
    }
}



private func chatLocationContext(holder: Atomic<ChatLocationContextHolder?>, account: Account, data: ChatReplyThreadMessage) -> ReplyThreadHistoryContext {
    let holder = holder.modify { current in
        if let current = current as? ChatLocationContextHolderImpl {
            return current
        } else {
            return ChatLocationContextHolderImpl(account: account, data: data)
        }
        } as! ChatLocationContextHolderImpl
    return holder.context
}

private final class ChatLocationContextHolderImpl: ChatLocationContextHolder {
    let context: ReplyThreadHistoryContext
    
    init(account: Account, data: ChatReplyThreadMessage) {
        self.context = ReplyThreadHistoryContext(account: account, peerId: data.messageId.peerId, data: data)
    }
}
