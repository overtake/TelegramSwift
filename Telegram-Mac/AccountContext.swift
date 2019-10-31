//
//  AccountContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit

struct TemporaryPasswordContainer {
    let date: TimeInterval
    let password: String
    
    var isActive: Bool {
        return date + 15 * 60 > Date().timeIntervalSince1970
    }
}

private final class TonInstanceData {
    var config: String?
    var blockchainName: String?
    var instance: TonInstance?
}


public final class StoredTonContext {
    private let basePath: String
    private let postbox: Postbox
    private let network: Network
    public let keychain: TonKeychain
    private let currentInstance = Atomic<TonInstanceData>(value: TonInstanceData())
    
    public init(basePath: String, postbox: Postbox, network: Network, keychain: TonKeychain) {
        self.basePath = basePath
        self.postbox = postbox
        self.network = network
        self.keychain = keychain
    }
    
    public func context(config: String, blockchainName: String, enableProxy: Bool) -> TonContext {
        return self.currentInstance.with { data -> TonContext in
            if let instance = data.instance, data.config == config, data.blockchainName == blockchainName {
                return TonContext(instance: instance, keychain: self.keychain)
            } else {
                data.config = config
                let instance = TonInstance(basePath: self.basePath, config: config, blockchainName: blockchainName, network: enableProxy ? self.network : nil)
                data.instance = instance
                return TonContext(instance: instance, keychain: self.keychain)
            }
        }
    }
}

public struct TonContext {
    public let instance: TonInstance
    public let keychain: TonKeychain
    
    public init(instance: TonInstance, keychain: TonKeychain) {
        self.instance = instance
        self.keychain = keychain
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

final class AccountContext {
    let sharedContext: SharedAccountContext
    let account: Account
    let window: Window

    #if !SHARE
    let fetchManager: FetchManager
    #endif
    private(set) var timeDifference:TimeInterval  = 0
    #if !SHARE
    let peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager()
    let chatUndoManager = ChatUndoManager()
    let blockedPeersContext: BlockedPeersContext
    let walletPasscodeTimeoutContext: WalletPasscodeTimeoutContext
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
    private let limitsDisposable = MetaDisposable()
    private let _limitConfiguration: Atomic<LimitsConfiguration> = Atomic(value: LimitsConfiguration.defaultValue)
    
    var limitConfiguration: LimitsConfiguration {
        return _limitConfiguration.with { $0 }
    }
    
    public let tonContext: StoredTonContext!
    
    public var closeFolderFirst: Bool = false
    
    init(sharedContext: SharedAccountContext, window: Window, tonContext: StoredTonContext?, account: Account) {
        self.sharedContext = sharedContext
        self.account = account
        self.window = window
        self.tonContext = tonContext
        #if !SHARE
        self.fetchManager = FetchManager(postbox: account.postbox)
        self.blockedPeersContext = BlockedPeersContext(account: account)
        self.walletPasscodeTimeoutContext = WalletPasscodeTimeoutContext(postbox: account.postbox)
        #endif
        
        
        let limitConfiguration = _limitConfiguration
        
        limitsDisposable.set(account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration]).start(next: { view in
            _ = limitConfiguration.swap(view.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration ?? LimitsConfiguration.defaultValue)
        }))
        
        
        globalPeerHandler.set(.single(nil))
        
        if account.network.globalTime > 0 {
            timeDifference = account.network.globalTime - Date().timeIntervalSince1970
        }
        
        updateDifferenceDisposable.set((Signal<Void, NoError>.single(Void())
            |> delay(5, queue: Queue.mainQueue()) |> restart).start(next: { [weak self, weak account] in
                if let account = account, account.network.globalTime > 0 {
                    self?.timeDifference = account.network.globalTime - Date().timeIntervalSince1970
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
        limitsDisposable.dispose()
        actualizeCloudTheme.dispose()
        applyThemeDisposable.dispose()
        cloudThemeObserver.dispose()
        
        #if !SHARE
        self.walletPasscodeTimeoutContext.clear()
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
    if let file = cloudTheme.file {
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
                            wallpaper = .single(.color(Int32(color.rgb)))
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
                                                wallpaper = getWallpaper(account: context.account, slug: slug) |> map(Optional.init)
                                            }
                                        default:
                                            wallpaper = getWallpaper(account: context.account, slug: slug) |> map(Optional.init)
                                        }
                                    } else {
                                        wallpaper = getWallpaper(account: context.account, slug: slug) |> map(Optional.init)
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
                                        }
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
                                    })
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
            } |> runOn(.mainQueue()) |> deliverOnMainQueue
    } else {
        return .complete()
    }
}


