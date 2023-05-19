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
import ColorPalette
import TGUIKit
import InAppSettings
import ThemeSettings
import Reactions
import FetchManager
import InAppPurchaseManager
import ApiCredentials



protocol ChatLocationContextHolder: AnyObject {
}



enum ChatLocation: Equatable {
    case peer(PeerId)
    case thread(ChatReplyThreadMessage)
}

extension ChatLocation {
    var unreadMessageCountsItem: UnreadMessageCountsItem {
        switch self {
        case let .peer(peerId):
            return .peer(id: peerId, handleThreads: false)
        case let .thread(data):
            return .peer(id: data.messageId.peerId, handleThreads: false)
        }
    }
    
    var postboxViewKey: PostboxViewKey {
        switch self {
        case let .peer(peerId):
            return .peer(peerId: peerId, components: [])
        case let .thread(data):
            return .peer(peerId: data.messageId.peerId, components: [])
        }
    }
    
    var pinnedItemId: PinnedItemId {
        switch self {
        case let .peer(peerId):
            return .peer(peerId)
        case let .thread(data):
            return .peer(data.messageId.peerId)
        }
    }
    
    var peerId: PeerId {
        switch self {
        case let .peer(peerId):
            return peerId
        case let .thread(data):
            return data.messageId.peerId
        }
    }
    var threadId: Int64? {
        switch self {
        case .peer:
            return nil
        case let .thread(replyThreadMessage):
            return makeMessageThreadId(replyThreadMessage.messageId) //Int64(replyThreadMessage.messageId.id)
        }
    }
    var threadMsgId: MessageId? {
        switch self {
        case .peer:
            return nil
        case let .thread(replyThreadMessage):
            return replyThreadMessage.messageId
        }
    }

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
    
    var bindings: AccountContextBindings = AccountContextBindings()


    #if !SHARE
    let fetchManager: FetchManager
    let diceCache: DiceCache
    let inlinePacksContext: InlineStickersContext
    let cachedGroupCallContexts: AccountGroupCallContextCacheImpl
    let networkStatusManager: NetworkStatusManager
    let inAppPurchaseManager: InAppPurchaseManager
    
    #endif
    private(set) var timeDifference:TimeInterval  = 0
    #if !SHARE
    
    var audioPlayer:APController?
    
    let peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager
    let blockedPeersContext: BlockedPeersContext
    let cacheCleaner: AccountClearCache
    let activeSessionsContext: ActiveSessionsContext
    let webSessions: WebSessionsContext
    let reactions: Reactions
    private(set) var reactionSettings: ReactionSettings = ReactionSettings.default
    private let reactionSettingsDisposable = MetaDisposable()
    private var chatInterfaceTempState:[PeerId : ChatInterfaceTempState] = [:]
    
    
    private let _chatThemes: Promise<[(String, TelegramPresentationTheme)]> = Promise([])
    var chatThemes: Signal<[(String, TelegramPresentationTheme)], NoError> {
        return _chatThemes.get() |> deliverOnMainQueue
    }
    
    
    
    private let _cloudThemes:Promise<CloudThemesCachedData> = Promise()
    var cloudThemes:Signal<CloudThemesCachedData, NoError> {
        return _cloudThemes.get() |> deliverOnMainQueue
    }
    #endif
    
    let cancelGlobalSearch:ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    
    private(set) var isSupport: Bool = false

    
    var isCurrent: Bool = false {
        didSet {
            if !self.isCurrent {
                //self.callManager = nil
            }
        }
    }
    
    
    private(set) var isPremium: Bool = false {
        didSet {
            #if !SHARE
            self.reactions.isPremium = isPremium
            #endif
        }
    }
    #if !SHARE
    var premiumIsBlocked: Bool {
        return self.premiumLimits.premium_purchase_blocked
    }
    #endif
    
    private let premiumDisposable = MetaDisposable()
    
    let globalPeerHandler:Promise<ChatLocation?> = Promise()
    
    func updateGlobalPeer() {
        globalPeerHandler.set(globalPeerHandler.get() |> take(1))
    }
    
    let hasPassportSettings: Promise<Bool> = Promise(false)

    private var _recentlyPeerUsed:[PeerId] = []
    private let _recentlyUserPeerIds = ValuePromise<[PeerId]>([])
    var recentlyUserPeerIds:Signal<[PeerId], NoError> {
        return _recentlyUserPeerIds.get()
    }
    
    private(set) var recentlyPeerUsed:[PeerId] {
        set {
            _recentlyPeerUsed = newValue
            _recentlyUserPeerIds.set(newValue)
        }
        get {
            return _recentlyPeerUsed
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
    
    private var _myPeer: Peer?
    
    var myPeer: Peer? {
        return _myPeer
    }

    
    
    private let isKeyWindowValue: ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    var isKeyWindow: Signal<Bool, NoError> {
        return isKeyWindowValue.get() |> deliverOnMainQueue
    }
    
    private let _autoplayMedia: Atomic<AutoplayMediaPreferences> = Atomic(value: AutoplayMediaPreferences.defaultSettings)
    
    var autoplayMedia: AutoplayMediaPreferences {
        return _autoplayMedia.with { $0 }
    }
    
    var layout:SplitViewState = .none {
        didSet {
            self.layoutHandler.set(self.layout)
        }
    }
    
    
    private let layoutHandler:ValuePromise<SplitViewState> = ValuePromise(ignoreRepeated:true)
    var layoutValue: Signal<SplitViewState, NoError> {
        return layoutHandler.get()
    }
    
    

    var isInGlobalSearch: Bool = false
    
    
    private let _contentSettings: Atomic<ContentSettings> = Atomic(value: ContentSettings.default)
    
    var contentSettings: ContentSettings {
        return _contentSettings.with { $0 }
    }
    
    
    public var closeFolderFirst: Bool = false
    
    private let preloadGifsDisposable = MetaDisposable()
    let engine: TelegramEngine
    
    private let giftStickersValues:Promise<[TelegramMediaFile]> = Promise([])
    var giftStickers: Signal<[TelegramMediaFile], NoError> {
        return giftStickersValues.get()
    }

    
    init(sharedContext: SharedAccountContext, window: Window, account: Account, isSupport: Bool = false) {
        self.sharedContext = sharedContext
        self.account = account
        self.window = window
        self.engine = TelegramEngine(account: account)
        self.isSupport = isSupport
        #if !SHARE
        self.inAppPurchaseManager = .init(premiumProductId: ApiEnvironment.premiumProductId)
        self.peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager(self.engine, account: account)
        self.diceCache = DiceCache(postbox: account.postbox, engine: self.engine)
        self.inlinePacksContext = .init(postbox: account.postbox, engine: self.engine)
        self.fetchManager = FetchManagerImpl(postbox: account.postbox, storeManager: DownloadedMediaStoreManagerImpl(postbox: account.postbox, accountManager: sharedContext.accountManager))
        self.blockedPeersContext = BlockedPeersContext(account: account)
        self.cacheCleaner = AccountClearCache(account: account)
        self.cachedGroupCallContexts = AccountGroupCallContextCacheImpl()
        self.activeSessionsContext = engine.privacy.activeSessions()
        self.webSessions = engine.privacy.webSessions()
        self.networkStatusManager = NetworkStatusManager(account: account, window: window, sharedContext: sharedContext)
        self.reactions = Reactions(engine)
        #endif
        
        
        giftStickersValues.set(engine.stickers.loadedStickerPack(reference: .premiumGifts, forceActualized: false)
        |> map { pack in
            switch pack {
            case let .result(_, items, _):
                return items.map { $0.file }
            default:
                return []
            }
        })
        
        let engine = self.engine
        
        repliesPeerId = account.testingEnvironment ? test_repliesPeerId : prod_repliesPeerId
        
        let limitConfiguration = _limitConfiguration
        prefDisposable.add(account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration]).start(next: { view in
            _ = limitConfiguration.swap(view.values[PreferencesKeys.limitsConfiguration]?.get(LimitsConfiguration.self) ?? LimitsConfiguration.defaultValue)
        }))
        let preloadGifsDisposable = self.preloadGifsDisposable
        let appConfiguration = _appConfiguration
        prefDisposable.add(account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]).start(next: { view in
            let configuration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
            _ = appConfiguration.swap(configuration)
        }))
        prefDisposable.add((account.postbox.peerView(id: account.peerId) |> deliverOnMainQueue).start(next: { [weak self] peerView in
            self?._myPeer = peerView.peers[peerView.peerId]
        }))
        
        
        #if !SHARE
        let signal:Signal<Void, NoError> = Signal { subscriber in
            
            let signal: Signal<Never, NoError> = account.postbox.transaction {
                return $0.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
            } |> mapToSignal { configuration in
                let value = GIFKeyboardConfiguration.with(appConfiguration: configuration)
                var signals = value.emojis.map {
                    engine.stickers.searchGifs(query: $0)
                }
                signals.insert(engine.stickers.searchGifs(query: ""), at: 0)
                return combineLatest(signals) |> ignoreValues
            }
            
            let disposable = signal.start(completed: {
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                disposable.dispose()
            }
        }
        
        let updated = (signal |> then(.complete() |> suspendAwareDelay(20.0 * 60.0, queue: .concurrentDefaultQueue()))) |> restart
        preloadGifsDisposable.set(updated.start())
        
       
        let chatThemes: Signal<[(String, TelegramPresentationTheme)], NoError> = combineLatest(appearanceSignal, engine.themes.getChatThemes(accountManager: sharedContext.accountManager)) |> mapToSignal { appearance, themes in
            var signals:[Signal<(String, TelegramPresentationTheme), NoError>] = []
            
            for theme in themes {
                let effective = theme.effectiveSettings(isDark: appearance.presentation.dark)
                if let settings = effective, let emoji = theme.emoticon?.fixed {
                    let newTheme = appearance.presentation.withUpdatedColors(settings.palette)
                    if let wallpaper = settings.wallpaper?.uiWallpaper {
                        signals.append(moveWallpaperToCache(postbox: account.postbox, wallpaper: wallpaper) |> map { wallpaper in
                            return (emoji, newTheme.withUpdatedWallpaper(.init(wallpaper: wallpaper, associated: nil)))
                        })
                    } else {
                        signals.append(.single((emoji, newTheme)))
                    }
                }
            }
            
            let first = Signal<[(String, TelegramPresentationTheme)], NoError>.single([])
            return first |> then(combineLatest(signals)) |> map { values in
                var dict: [(String, TelegramPresentationTheme)] = []
                for value in values {
                    dict.append((value.0, value.1))
                }
                return dict
            }
        }
        self._chatThemes.set((chatThemes |> then(.complete() |> suspendAwareDelay(20.0 * 60.0, queue: .concurrentDefaultQueue()))) |> restart)
        
        
        let cloudThemes: Signal<[TelegramTheme], NoError> = telegramThemes(postbox: account.postbox, network: account.network, accountManager: sharedContext.accountManager) |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs.count == rhs.count
        })
        
        let themesList: Signal<([TelegramTheme], [CloudThemesCachedData.Key : [SmartThemeCachedData]]), NoError> = cloudThemes |> mapToSignal { themes in
            var signals:[Signal<(CloudThemesCachedData.Key, Int64, TelegramPresentationTheme), NoError>] = []
            
            for key in CloudThemesCachedData.Key.all {
                for theme in themes {
                    let effective = theme.effectiveSettings(for: key.colors)
                    if let settings = effective, theme.isDefault, let _ = theme.emoticon {
                        let newTheme = appAppearance.presentation.withUpdatedColors(settings.palette)
                        if let wallpaper = settings.wallpaper?.uiWallpaper {
                            signals.append(moveWallpaperToCache(postbox: account.postbox, wallpaper: wallpaper) |> map { wallpaper in
                                return (key, theme.id, newTheme.withUpdatedWallpaper(.init(wallpaper: wallpaper, associated: nil)))
                            })
                        } else {
                            signals.append(.single((key, theme.id, newTheme)))
                        }
                    }
                }
            }
            
            return combineLatest(signals) |> mapToSignal { values in
                
                var signals: [Signal<(CloudThemesCachedData.Key, Int64, SmartThemeCachedData), NoError>] = []
                for value in values {
                    let bubbled = value.0.bubbled
                    let theme = value.2
                    let themeId = value.1
                    let key = value.0
                    if let telegramTheme = themes.first(where: { $0.id == value.1 }) {
                        signals.append(generateChatThemeThumb(palette: theme.colors, bubbled: bubbled, backgroundMode: bubbled ? theme.backgroundMode : .color(color: theme.colors.chatBackground)) |> map {
                            (key, themeId, SmartThemeCachedData(source: .cloud(telegramTheme), data: .init(appTheme: theme, previewIcon: $0, emoticon: telegramTheme.emoticon ?? telegramTheme.title)))
                        })
                    }
                }
                return combineLatest(signals) |> map { values in
                    var data:[CloudThemesCachedData.Key: [SmartThemeCachedData]] = [:]
                    for value in values {
                        var array:[SmartThemeCachedData] = data[value.0] ?? []
                        array.append(value.2)
                        data[value.0] = array
                    }
                    return (themes, data)

                }
            }
        }
        
        
        let defaultAndCustom: Signal<(SmartThemeCachedData, SmartThemeCachedData?), NoError> = combineLatest(appearanceSignal, themeSettingsView(accountManager: sharedContext.accountManager)) |> map { appearance, value -> (ThemePaletteSettings, TelegramPresentationTheme, ThemePaletteSettings?) in
            
            let `default` = value.withUpdatedToDefault(dark: appearance.presentation.dark)
                .withUpdatedCloudTheme(nil)
                .withUpdatedPalette(appearance.presentation.colors.parent.palette)
                .installDefaultWallpaper()
            
            
            let  customData = value.withUpdatedCloudTheme(appearance.presentation.cloudTheme)
                .withUpdatedPalette(appearance.presentation.colors)
                .installDefaultWallpaper()
            
            var custom: ThemePaletteSettings?
            if let cloud = customData.cloudTheme, cloud.settings == nil {
                custom = customData
            } else if let cloud = customData.cloudTheme {
                if let settings = cloud.effectiveSettings(for: value.palette.parent.palette) {
                    if customData.wallpaper.wallpaper != settings.wallpaper?.uiWallpaper {
                        custom = customData
                    }
                }
            }
            
            return (`default`, appearance.presentation, custom)
        } |> deliverOn(.concurrentBackgroundQueue()) |> mapToSignal { (value, theme, custom) in
            
            var signals:[Signal<SmartThemeCachedData, NoError>] = []
            
            let  values = [value, custom].compactMap { $0 }
            for (i, value) in values.enumerated() {
                let newTheme = theme.withUpdatedColors(value.palette).withUpdatedWallpaper(value.wallpaper)
                signals.append(moveWallpaperToCache(postbox: account.postbox, wallpaper: value.wallpaper.wallpaper) |> mapToSignal { _ in
                    return generateChatThemeThumb(palette: newTheme.colors, bubbled: value.bubbled, backgroundMode: value.bubbled ? newTheme.backgroundMode : .color(color: newTheme.colors.chatBackground))
                } |> map { previewIcon in
                    return SmartThemeCachedData(source: .local(value.palette), data: .init(appTheme: newTheme, previewIcon: previewIcon, emoticon: i == 0 ? "🏠" : "🎨"))
                })
            }
            
            return combineLatest(signals) |> map { ($0[0], $0.count == 2 ? $0[1] : nil) }
        }
        
        _cloudThemes.set(cloudThemes |> map { cloudThemes in
            return .init(themes: cloudThemes, list: [:], default: nil, custom: nil)
        })
//        _cloudThemes.set(.single(.init(themes: [], list: [:], default: nil, custom: nil)))

        let settings = account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
           |> map { preferencesView -> ReactionSettings in
               let reactionSettings: ReactionSettings
               if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                   reactionSettings = value
               } else {
                   reactionSettings = .default
               }
               return reactionSettings
           } |> deliverOnMainQueue
        
        reactionSettingsDisposable.set(settings.start(next: { [weak self] settings in
            self?.reactionSettings = settings
        }))
        
        #endif
        
        
        
        let autoplayMedia = _autoplayMedia
        prefDisposable.add(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.autoplayMedia]).start(next: { view in
            _ = autoplayMedia.swap(view.values[ApplicationSpecificPreferencesKeys.autoplayMedia]?.get(AutoplayMediaPreferences.self) ?? AutoplayMediaPreferences.defaultSettings)
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
        
        let passthrough: Atomic<Bool> = Atomic(value: false)
        let cloudSignal = appearanceSignal |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
            return lhs.presentation.cloudTheme == rhs.presentation.cloudTheme
        }) |> take(until: { _ in
            return .init(passthrough: passthrough.swap(true), complete: false)
        })
        |> map { value in
            return (value.presentation.cloudTheme, value.presentation.colors)
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
            
            subscriber.putNext(freeSystemGigabytes())
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
        
        account.callSessionManager.updateVersions(versions: OngoingCallContext.versions(includeExperimental: true, includeReference: true).map { version, supportsVideo -> CallSessionManagerImplementationVersion in
            CallSessionManagerImplementationVersion(version: version, supportsVideo: supportsVideo)
        })
        
//        reactions.needsPremium = { [weak self] in
//            if let strongSelf = self {
//                showModal(with: PremiumReactionsModal(context: strongSelf), for: strongSelf.window)
//            }
//        }
        
        #endif
        
        let isPremium: Signal<Bool, NoError> = account.postbox.peerView(id: account.peerId) |> map { view in
            return (view.peers[view.peerId] as? TelegramUser)?.flags.contains(.isPremium) ?? false
        } |> deliverOnMainQueue
        
        self.premiumDisposable.set(isPremium.start(next: { [weak self] value in
            self?.isPremium = value
        }))
        
    }
    
    @objc private func updateKeyWindow() {
        self.isKeyWindowValue.set(window.isKeyWindow)
    }
    
    func focus() {
        window.makeKeyAndOrderFront(nil)
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
    #if !SHARE
    func setChatInterfaceTempState(_ state: ChatInterfaceTempState, for peerId: PeerId) {
        self.chatInterfaceTempState[peerId] = state
    }
    func getChatInterfaceTempState(_ peerId: PeerId?) -> ChatInterfaceTempState? {
        if let peerId = peerId {
            return self.chatInterfaceTempState[peerId]
        } else {
            return nil
        }
    }
    var premiumLimits: PremiumLimitConfig {
        return PremiumLimitConfig(appConfiguration: appConfiguration)
    }
    var premiumOrder:PremiumPromoOrder {
        return PremiumPromoOrder(appConfiguration: appConfiguration)
    }
    var premiumBuyConfig: PremiumBuyConfig {
        return PremiumBuyConfig(appConfiguration: appConfiguration)
    }
    #endif
    
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
        premiumDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
        #if !SHARE
      //  self.walletPasscodeTimeoutContext.clear()
        self.networkStatusManager.cleanup()
        self.audioPlayer?.cleanup()
        self.audioPlayer = nil
        self.diceCache.cleanup()
        _chatThemes.set(.single([]))
        _cloudThemes.set(.single(.init(themes: [], list: [:], default: nil, custom: nil)))
        reactionSettingsDisposable.dispose()
        #endif
    }
   
    
    func checkFirstRecentlyForDuplicate(peerId:PeerId) {
        if let index = recentlyPeerUsed.firstIndex(of: peerId), index == 0 {
         //   recentlyPeerUsed.remove(at: index)
        }
    }
    
    func addRecentlyUsedPeer(peerId:PeerId) {
        if let index = recentlyPeerUsed.firstIndex(of: peerId) {
            recentlyPeerUsed.remove(at: index)
        }
        recentlyPeerUsed.insert(peerId, at: 0)
    }
    
    
    func chatLocationInput(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> ChatLocationInput {
        switch location {
        case let .peer(peerId):
            return .peer(peerId: peerId, threadId: nil)
        case let .thread(data):
            if data.isForumPost {
                return .peer(peerId: data.messageId.peerId, threadId: makeMessageThreadId(data.messageId))
            } else {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return .thread(peerId: data.messageId.peerId, threadId: makeMessageThreadId(data.messageId), data: context.state)
            }
        }
    }
    
    func chatLocationOutgoingReadState(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<MessageId?, NoError> {
        switch location {
        case .peer:
            return .single(nil)
        case let .thread(data):
            if data.isForumPost {
                let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: data.messageId.peerId, threadId: Int64(data.messageId.id))
                return self.account.postbox.combinedView(keys: [viewKey])
                |> map { views -> MessageId? in
                    if let threadInfo = views.views[viewKey] as? MessageHistoryThreadInfoView, let data = threadInfo.info?.data.get(MessageHistoryThreadData.self) {
                        return MessageId(peerId: location.peerId, namespace: Namespaces.Message.Cloud, id: data.maxOutgoingReadId)
                    } else {
                        return nil
                    }
                }
            } else {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return context.maxReadOutgoingMessageId
            }
        }
    }

    public func chatLocationUnreadCount(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<Int, NoError> {
        switch location {
        case let .peer(peerId):
            let unreadCountsKey: PostboxViewKey = .unreadCounts(items: [.peer(id: peerId, handleThreads: false), .total(nil)])
            return self.account.postbox.combinedView(keys: [unreadCountsKey])
            |> map { views in
                var unreadCount: Int32 = 0

                if let view = views.views[unreadCountsKey] as? UnreadMessageCountsView {
                    if let count = view.count(for: .peer(id: peerId, handleThreads: false)) {
                        unreadCount = count
                    }
                }

                return Int(unreadCount)
            }
        case let .thread(data):
            if data.isForumPost {
                let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: data.messageId.peerId, threadId: Int64(data.messageId.id))
                return self.account.postbox.combinedView(keys: [viewKey])
                |> map { views -> Int in
                    if let threadInfo = views.views[viewKey] as? MessageHistoryThreadInfoView, let data = threadInfo.info?.data.get(MessageHistoryThreadData.self) {
                        return Int(data.incomingUnreadCount)
                    } else {
                        return 0
                    }
                }
            } else {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return context.unreadCount
            }

        }
    }


    
    func applyMaxReadIndex(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>, messageIndex: MessageIndex) {
        switch location {
        case .peer:
            let _ = self.engine.messages.applyMaxReadIndexInteractively(index: messageIndex).start()
        case let .thread(data):
            let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
            context.applyMaxReadIndex(messageIndex: messageIndex)
        }
    }


   

    
    #if !SHARE
    
    func navigateToThread(_ threadId: MessageId, fromId: MessageId) {
        let signal:Signal<ThreadInfo, FetchChannelReplyThreadMessageError> = fetchAndPreloadReplyThreadInfo(context: self, subject: .channelPost(threadId))
        
        _ = showModalProgress(signal: signal |> take(1), for: self.window).start(next: { [weak self] result in
            guard let context = self else {
                return
            }
            let chatLocation: ChatLocation = .thread(result.message)
            
            let updatedMode: ReplyThreadMode
            if result.isChannelPost {
                updatedMode = .comments(origin: fromId)
            } else {
                updatedMode = .replies(origin: fromId)
            }
            let controller = ChatController(context: context, chatLocation: chatLocation, mode: .thread(data: result.message, mode: updatedMode), messageId: fromId, initialAction: nil, chatLocationContextHolder: result.contextHolder)
            
            context.bindings.rootNavigation().push(controller)
            
        }, error: { error in
            
        })
    }

    
    func composeCreateGroup(selectedPeers:Set<PeerId> = Set()) {
        createGroup(with: self, selectedPeers: selectedPeers)
    }
    func composeCreateChannel() {
        createChannel(with: self)
    }
    func composeCreateSecretChat() {
        let account = self.account
        let window = self.window
        let engine = self.engine
        let confirmationImpl:([PeerId])->Signal<Bool, NoError> = { peerIds in
            if let first = peerIds.first, peerIds.count == 1 {
                return account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                    return confirmSignal(for: window, information: strings().composeConfirmStartSecretChat(peer.displayTitle))
                }
            }
            return confirmSignal(for: window, information: strings().peerInfoConfirmAddMembers1Countable(peerIds.count))
        }
        let select = selectModalPeers(window: window, context: self, title: strings().composeSelectSecretChat, limit: 1, confirmation: confirmationImpl)
        
        let create = select |> map { $0.first! } |> mapToSignal { peerId in
            return engine.peers.createSecretChat(peerId: peerId) |> `catch` {_ in .complete()}
            } |> deliverOnMainQueue |> mapToSignal{ peerId -> Signal<PeerId, NoError> in
                return showModalProgress(signal: .single(peerId), for: window)
        }
        
        _ = create.start(next: { [weak self] peerId in
            guard let `self` = self else {return}
            self.bindings.rootNavigation().push(ChatController(context: self, chatLocation: .peer(peerId)))
        })
    }
    #endif
}


func downloadAndApplyCloudTheme(context: AccountContext, theme cloudTheme: TelegramTheme, palette: ColorPalette? = nil, install: Bool = false) -> Signal<Never, Void> {
    if let cloudSettings = cloudTheme.effectiveSettings(for: palette ?? theme.colors) {
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
                                    return DefaultCloudTheme(cloud: cloudTheme, palette: palette, wallpaper: AssociatedWallpaper(cloud: cloud, wallpaper: wallpaper))
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

