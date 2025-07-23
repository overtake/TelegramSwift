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
#if !SHARE
import InAppPurchaseManager
import CurrencyFormat
#endif
import ApiCredentials


#if !SHARE
struct PremiumGiftProduct: Equatable {
    let giftOption: PremiumGiftCodeOption
    let storeProduct: InAppPurchaseManager.Product?
    
    var id: String {
        return self.storeProduct?.id ?? ""
    }
    
    var months: Int32 {
        return self.giftOption.months
    }
    
    var price: String {
        if let storeProduct = storeProduct {
            return formatCurrencyAmount(storeProduct.priceCurrencyAndAmount.amount, currency: storeProduct.priceCurrencyAndAmount.currency)
        }
        return formatCurrencyAmount(giftOption.amount, currency: giftOption.currency)
    }
    
    var pricePerMonth: String {
        if let storeProduct = storeProduct {
            return storeProduct.pricePerMonth(Int(self.months))
        } else {
            return formatCurrencyAmount(giftOption.amount / Int64(giftOption.months), currency: giftOption.currency)
        }
    }
    var priceCurrencyAndAmount:(currency: String, amount: Int64) {
        if let storeProduct = storeProduct {
            return storeProduct.priceCurrencyAndAmount
        } else {
            return (currency: giftOption.currency, amount: giftOption.amount)
        }
    }
    
    func multipliedPrice(count: Int) -> String {
        if let storeProduct = storeProduct {
            return storeProduct.multipliedPrice(count: count)
        } else {
            return formatCurrencyAmount(giftOption.amount * Int64(count), currency: giftOption.currency)
        }
    }
}
#endif


let servicePeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
let verifyCodePeerId = PeerId.init(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(489000))


func bestWindow(_ accountContext: AccountContext, _ controller: ViewController?) -> Window {
    return controller?.window ?? accountContext.window
}

public struct PremiumConfiguration {
    public static var defaultValue: PremiumConfiguration {
        return PremiumConfiguration(
            isPremiumDisabled: false,
            showPremiumGiftInAttachMenu: false,
            showPremiumGiftInTextField: false,
            giveawayGiftsPurchaseAvailable: false,
            boostsPerGiftCount: 3,
            audioTransciptionTrialMaxDuration: 300,
            audioTransciptionTrialCount: 2,
            minChannelNameColorLevel: 1,
            minChannelNameIconLevel: 4,
            minChannelProfileColorLevel: 5,
            minChannelProfileIconLevel: 7,
            minChannelEmojiStatusLevel: 8,
            minChannelWallpaperLevel: 9,
            minChannelCustomWallpaperLevel: 10,
            minChannelRestrictAdsLevel: 50,
            minGroupProfileIconLevel: 7,
            minGroupEmojiStatusLevel: 8,
            minGroupWallpaperLevel: 9,
            minGroupCustomWallpaperLevel: 9,
            minGroupEmojiPackLevel: 9,
            minGroupAudioTranscriptionLevel: 9,
            minChannelWearGiftLevel: 8,
            minChannelAutotranslationLevel: 3
        )
    }
    
    public let isPremiumDisabled: Bool
    public let showPremiumGiftInAttachMenu: Bool
    public let showPremiumGiftInTextField: Bool
    public let giveawayGiftsPurchaseAvailable: Bool
    public let boostsPerGiftCount: Int32
    public let audioTransciptionTrialMaxDuration: Int32
    public let audioTransciptionTrialCount: Int32
    public let minChannelNameColorLevel: Int32
    public let minChannelNameIconLevel: Int32
    public let minChannelProfileColorLevel: Int32
    public let minChannelProfileIconLevel: Int32
    public let minChannelEmojiStatusLevel: Int32
    public let minChannelWallpaperLevel: Int32
    public let minChannelCustomWallpaperLevel: Int32
    public let minChannelRestrictAdsLevel: Int32
    public let minChannelWearGiftLevel: Int32

    
    public let minGroupProfileIconLevel: Int32
    public let minGroupEmojiStatusLevel: Int32
    public let minGroupWallpaperLevel: Int32
    public let minGroupCustomWallpaperLevel: Int32
    public let minGroupEmojiPackLevel: Int32
    public let minGroupAudioTranscriptionLevel: Int32
    public let minChannelAutotranslationLevel: Int32
    fileprivate init(
        isPremiumDisabled: Bool,
        showPremiumGiftInAttachMenu: Bool,
        showPremiumGiftInTextField: Bool,
        giveawayGiftsPurchaseAvailable: Bool,
        boostsPerGiftCount: Int32,
        audioTransciptionTrialMaxDuration: Int32,
        audioTransciptionTrialCount: Int32,
        minChannelNameColorLevel: Int32,
        minChannelNameIconLevel: Int32,
        minChannelProfileColorLevel: Int32,
        minChannelProfileIconLevel: Int32,
        minChannelEmojiStatusLevel: Int32,
        minChannelWallpaperLevel: Int32,
        minChannelCustomWallpaperLevel: Int32,
        minChannelRestrictAdsLevel: Int32,
        minGroupProfileIconLevel: Int32,
        minGroupEmojiStatusLevel: Int32,
        minGroupWallpaperLevel: Int32,
        minGroupCustomWallpaperLevel: Int32,
        minGroupEmojiPackLevel: Int32,
        minGroupAudioTranscriptionLevel: Int32,
        minChannelWearGiftLevel: Int32,
        minChannelAutotranslationLevel: Int32
    ) {
        self.isPremiumDisabled = isPremiumDisabled
        self.showPremiumGiftInAttachMenu = showPremiumGiftInAttachMenu
        self.showPremiumGiftInTextField = showPremiumGiftInTextField
        self.giveawayGiftsPurchaseAvailable = giveawayGiftsPurchaseAvailable
        self.boostsPerGiftCount = boostsPerGiftCount
        self.audioTransciptionTrialMaxDuration = audioTransciptionTrialMaxDuration
        self.audioTransciptionTrialCount = audioTransciptionTrialCount
        self.minChannelNameColorLevel = minChannelNameColorLevel
        self.minChannelNameIconLevel = minChannelNameIconLevel
        self.minChannelProfileColorLevel = minChannelProfileColorLevel
        self.minChannelProfileIconLevel = minChannelProfileIconLevel
        self.minChannelEmojiStatusLevel = minChannelEmojiStatusLevel
        self.minChannelWallpaperLevel = minChannelWallpaperLevel
        self.minChannelCustomWallpaperLevel = minChannelCustomWallpaperLevel
        self.minChannelRestrictAdsLevel = minChannelRestrictAdsLevel
        self.minGroupProfileIconLevel = minGroupProfileIconLevel
        self.minGroupEmojiStatusLevel = minGroupEmojiStatusLevel
        self.minGroupWallpaperLevel = minGroupWallpaperLevel
        self.minGroupCustomWallpaperLevel = minGroupCustomWallpaperLevel
        self.minGroupEmojiPackLevel = minGroupEmojiPackLevel
        self.minGroupAudioTranscriptionLevel = minGroupAudioTranscriptionLevel
        self.minChannelWearGiftLevel = minChannelWearGiftLevel
        self.minChannelAutotranslationLevel = minChannelAutotranslationLevel
    }
    
    public static func with(appConfiguration: AppConfiguration) -> PremiumConfiguration {
        let defaultValue = self.defaultValue
        if let data = appConfiguration.data {
            func get(_ value: Any?) -> Int32? {
                return (value as? Double).flatMap(Int32.init)
            }
            return PremiumConfiguration(
                isPremiumDisabled: data["premium_purchase_blocked"] as? Bool ?? defaultValue.isPremiumDisabled,
                showPremiumGiftInAttachMenu: data["premium_gift_attach_menu_icon"] as? Bool ?? defaultValue.showPremiumGiftInAttachMenu,
                showPremiumGiftInTextField: data["premium_gift_text_field_icon"] as? Bool ?? defaultValue.showPremiumGiftInTextField,
                giveawayGiftsPurchaseAvailable: data["giveaway_gifts_purchase_available"] as? Bool ?? defaultValue.giveawayGiftsPurchaseAvailable,
                boostsPerGiftCount: get(data["boosts_per_sent_gift"]) ?? defaultValue.boostsPerGiftCount,
                audioTransciptionTrialMaxDuration: get(data["transcribe_audio_trial_duration_max"]) ?? defaultValue.audioTransciptionTrialMaxDuration,
                audioTransciptionTrialCount: get(data["transcribe_audio_trial_weekly_number"]) ?? defaultValue.audioTransciptionTrialCount,
                minChannelNameColorLevel: get(data["channel_color_level_min"]) ?? defaultValue.minChannelNameColorLevel,
                minChannelNameIconLevel: get(data["channel_bg_icon_level_min"]) ?? defaultValue.minChannelNameIconLevel,
                minChannelProfileColorLevel: get(data["channel_profile_color_level_min"]) ?? defaultValue.minChannelProfileColorLevel,
                minChannelProfileIconLevel: get(data["channel_profile_bg_icon_level_min"]) ?? defaultValue.minChannelProfileIconLevel,
                minChannelEmojiStatusLevel: get(data["channel_emoji_status_level_min"]) ?? defaultValue.minChannelEmojiStatusLevel,
                minChannelWallpaperLevel: get(data["channel_wallpaper_level_min"]) ?? defaultValue.minChannelWallpaperLevel,
                minChannelCustomWallpaperLevel: get(data["channel_custom_wallpaper_level_min"]) ?? defaultValue.minChannelCustomWallpaperLevel,
                minChannelRestrictAdsLevel: get(data["channel_restrict_sponsored_level_min"]) ?? defaultValue.minChannelRestrictAdsLevel,
                minGroupProfileIconLevel: get(data["group_profile_bg_icon_level_min "]) ?? defaultValue.minGroupProfileIconLevel,
                minGroupEmojiStatusLevel: get(data["group_emoji_status_level_min"]) ?? defaultValue.minGroupEmojiStatusLevel,
                minGroupWallpaperLevel: get(data["group_wallpaper_level_min"]) ?? defaultValue.minGroupWallpaperLevel,
                minGroupCustomWallpaperLevel: get(data["group_custom_wallpaper_level_min"]) ?? defaultValue.minGroupCustomWallpaperLevel,
                minGroupEmojiPackLevel: get(data["group_emoji_stickers_level_min"]) ?? defaultValue.minGroupEmojiPackLevel,
                minGroupAudioTranscriptionLevel: get(data["group_transcribe_level_min"]) ?? defaultValue.minGroupAudioTranscriptionLevel,
                minChannelWearGiftLevel: get(data["channel_emoji_status_level_min"]) ?? defaultValue.minChannelWearGiftLevel,
                minChannelAutotranslationLevel: get(data["channel_autotranslation_level_min"]) ?? defaultValue.minChannelWearGiftLevel
            )
        } else {
            return defaultValue
        }
    }
}





extension AppConfiguration {
    func getGeneralValue(_ key: String, orElse defaultValue: Int32) -> Int32 {
        if let value = self.data?[key] as? Double {
            return Int32(value)
        } else {
            return defaultValue
        }
    }
    func getGeneralValue64(_ key: String, orElse defaultValue: Int64) -> Int64 {
        if let value = self.data?[key] as? Double {
            return Int64(value)
        } else {
            return defaultValue
        }
    }
    func getGeneralValueDouble(_ key: String, orElse defaultValue: Double) -> Double {
        if let value = self.data?[key] as? Double {
            return Double(value)
        } else {
            return defaultValue
        }
    }
    func getStringValue(_ key: String, orElse defaultValue: String) -> String {
        if let value = self.data?[key] as? String {
            return value
        } else {
            return defaultValue
        }
    }
    func getBoolValue(_ key: String, orElse defaultValue: Bool) -> Bool {
        if let value = self.data?[key] as? Bool {
            return value
        } else {
            return defaultValue
        }
    }
}

private let globalStoryDisposable = MetaDisposable()

func SetOpenStoryDisposable(_ disposable: Disposable?) {
    globalStoryDisposable.set(disposable)
}
func CancelOpenStory() {
    globalStoryDisposable.set(nil)
}





struct AntiSpamBotConfiguration {
    static var defaultValue: AntiSpamBotConfiguration {
        return AntiSpamBotConfiguration(antiSpamBotId: nil, group_size_min: 100)
    }
    
    let antiSpamBotId: EnginePeer.Id?
    let group_size_min: Int32
    fileprivate init(antiSpamBotId: EnginePeer.Id?, group_size_min: Int32) {
        self.antiSpamBotId = antiSpamBotId
        self.group_size_min = group_size_min
    }
    
    static func with(appConfiguration: AppConfiguration) -> AntiSpamBotConfiguration {
        if let data = appConfiguration.data, let string = data["telegram_antispam_user_id"] as? String, let value = Int64(string) {
            let group_size_min: Int32
            
            if let string = data["telegram_antispam_group_size_min"] as? String, let value = Int32(string) {
                group_size_min = value
            } else {
                group_size_min = 100
            }
            
            return AntiSpamBotConfiguration(antiSpamBotId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(value)), group_size_min: group_size_min)
        } else {
            return .defaultValue
        }
    }
}



protocol ChatLocationContextHolder: AnyObject {
}

extension ChatReplyThreadMessage {
    var effectiveTopId: MessageId {
        return self.channelMessageId ?? MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: self.threadId))
    }
}


enum ChatLocation: Equatable {
    case peer(PeerId)
    case thread(ChatReplyThreadMessage)
}

extension ChatLocation {
    
    static func makeSaved(_ accountPeerId: PeerId, peerId: PeerId, isMonoforum: Bool = false) -> ChatLocation {
        return .makeSaved(accountPeerId, threadId: peerId.toInt64(), isMonoforum: isMonoforum)
    }
    
    static func makeSaved(_ accountPeerId: PeerId, threadId: Int64, isMonoforum: Bool = false) -> ChatLocation {
        return .thread(.init(peerId: accountPeerId, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: false, isMonoforumPost: isMonoforum, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false))
    }
    
    var unreadMessageCountsItem: UnreadMessageCountsItem {
        switch self {
        case let .peer(peerId):
            return .peer(id: peerId, handleThreads: false)
        case let .thread(data):
            return .peer(id: data.peerId, handleThreads: false)
        }
    }
    
    var postboxViewKey: PostboxViewKey {
        switch self {
        case let .peer(peerId):
            return .peer(peerId: peerId, components: [])
        case let .thread(data):
            return .peer(peerId: data.peerId, components: [])
        }
    }
    
    var pinnedItemId: PinnedItemId {
        switch self {
        case let .peer(peerId):
            return .peer(peerId)
        case let .thread(data):
            return .peer(data.peerId)
        }
    }
    
    var peerId: PeerId {
        switch self {
        case let .peer(peerId):
            return peerId
        case let .thread(data):
            return data.peerId
        }
    }
    var threadId: Int64? {
        switch self {
        case .peer:
            return nil
        case let .thread(replyThreadMessage):
            return replyThreadMessage.threadId
        }
    }
    var threadMsgId: MessageId? {
        switch self {
        case .peer:
            return nil
        case let .thread(replyThreadMessage):
            return replyThreadMessage.effectiveTopId
        }
    }
    var threadMessage: ChatReplyThreadMessage? {
        switch self {
        case .peer:
            return nil
        case let .thread(replyThreadMessage):
            return replyThreadMessage
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

struct CachedSearchMessages : Equatable {
    var result: SearchMessagesResult
    var state: SearchMessagesState
}

final class AccountContextBindings {
    #if !SHARE
    let rootNavigation: () -> MajorNavigationController
    let mainController: () -> MainViewController
    let showControllerToaster: (ControllerToaster, Bool) -> Void
    let globalSearch:(String, PeerId?, CachedSearchMessages?)->Void
    let switchSplitLayout:(SplitViewState)->Void
    let entertainment:()->EntertainmentViewController
    let needFullsize:()->Void
    let displayUpgradeProgress:(CGFloat)->Void
    init(rootNavigation: @escaping() -> MajorNavigationController = { fatalError() }, mainController: @escaping() -> MainViewController = { fatalError() }, showControllerToaster: @escaping(ControllerToaster, Bool) -> Void = { _, _ in fatalError() }, globalSearch: @escaping(String, PeerId?, CachedSearchMessages?) -> Void = { _, _, _ in fatalError() }, entertainment: @escaping()->EntertainmentViewController = { fatalError() }, switchSplitLayout: @escaping(SplitViewState)->Void = { _ in fatalError() }, needFullsize: @escaping() -> Void = { fatalError() }, displayUpgradeProgress: @escaping(CGFloat)->Void = { _ in fatalError() }) {
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
    let starsContext: StarsContext
    let tonContext: StarsContext
    let starsSubscriptionsContext: StarsSubscriptionsContext
    let currentCountriesConfiguration: Atomic<CountriesConfiguration> = Atomic(value: CountriesConfiguration(countries: loadCountryCodes()))
    var contentConfig: ContentSettingsConfiguration = .default
    private let _countriesConfiguration = Promise<CountriesConfiguration>()
    var countriesConfiguration: Signal<CountriesConfiguration, NoError> {
        return self._countriesConfiguration.get()
    }
    
    func currencyContext(_ currency: CurrencyAmount.Currency) -> StarsContext {
        switch currency {
        case .stars:
            return starsContext
        case .ton:
            return tonContext
        }
    }

    #endif
    private(set) var timeDifference:TimeInterval  = 0
    #if !SHARE
        
    
    let peerChannelMemberCategoriesContextsManager: PeerChannelMemberCategoriesContextsManager
    let blockedPeersContext: BlockedPeersContext
    let storiesBlockedPeersContext: BlockedPeersContext
    let cacheCleaner: AccountClearCache
    let activeSessionsContext: ActiveSessionsContext
    let webSessions: WebSessionsContext
    let reactions: Reactions
    let dockControl: DockControl
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
    
    
    var privacy:Signal<AccountPrivacySettings?, NoError> {
        return bindings.mainController().settings.privacySettings
    }
    func updateMessagesPrivacy(noPaidMessages: SelectivePrivacySettings, globalSettings: GlobalPrivacySettings) {
        bindings.mainController().settings.updateMessagesPrivacy(noPaidMessages: noPaidMessages, globalSettings: globalSettings)
    }
    func updatePrivacy(_ updated: SelectivePrivacySettings, kind: SelectivePrivacySettingsKind) {
        bindings.mainController().settings.updatePrivacy(updated, kind: kind)
    }
    
    private(set) var premiumProductsAndPrice: ([PremiumGiftProduct], (Int64, NSDecimalNumber)) = ([], (0, 0))
    #endif

    
    private let _emoticonThemes = Atomic<[(String, TelegramPresentationTheme)]>(value: [])
    var emoticonThemes: [(String, TelegramPresentationTheme)] {
        return _emoticonThemes.with { $0 }
    }
    
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
    
    private let globalLocationDisposable = MetaDisposable()
    let globalPeerHandler:Promise<ChatLocation?> = Promise()
    
    private let _globalLocationId = Atomic<ChatLocation?>(value: nil)
    var globalLocationId: ChatLocation? {
        return _globalLocationId.with { $0 }
    }
    
    let globalForumId:ValuePromise<PeerId?> = ValuePromise(nil, ignoreRepeated: true)
    
    func updateGlobalPeer() {
        _ = (self.globalPeerHandler.get() |> take(1)).start(next: { [weak self] location in
            self?.globalPeerHandler.set(.single(location))
        })
    }
    
    private(set) var autologinToken: String?
    
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
    private let reindexCacheDisposable = MetaDisposable()
    private let shouldReindexCacheDisposable = MetaDisposable()
    private let checkSidebarShouldEnable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let _limitConfiguration: Atomic<LimitsConfiguration> = Atomic(value: LimitsConfiguration.defaultValue)
    
    
    private var _peerNameColors: PeerNameColors?
    
    var limitConfiguration: LimitsConfiguration {
        return _limitConfiguration.with { $0 }
    }
    
    private let _appConfiguration: Atomic<AppConfiguration> = Atomic(value: AppConfiguration.defaultValue)
    
    var appConfiguration: AppConfiguration {
        return _appConfiguration.with { $0 }
    }
    
    private var cached: PeerNameColors?
    
    var peerNameColors: PeerNameColors {
        if let _peerNameColors = _peerNameColors {
            return _peerNameColors
        }
        return .init(colors: [:], darkColors: [:], displayOrder: [], profileColors: [:], profileDarkColors: [:], profilePaletteColors: [:], profilePaletteDarkColors: [:], profileStoryColors: [:], profileStoryDarkColors: [:], profileDisplayOrder: [], nameColorsChannelMinRequiredBoostLevel: [:], nameColorsGroupMinRequiredBoostLevel: [:])
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
    
    private let _stickerSettings: Atomic<StickerSettings> = Atomic(value: StickerSettings.defaultSettings)
    
    var stickerSettings: StickerSettings {
        return _stickerSettings.with { $0 }
    }
    
    
    public var closeFolderFirst: Bool = false
    
    let engine: TelegramEngine
    
    private let giftStickersValues:Promise<[TelegramMediaFile]> = Promise([])
    var giftStickers: Signal<[TelegramMediaFile], NoError> {
        return giftStickersValues.get()
    }

    public private(set) var audioTranscriptionTrial: AudioTranscription.TrialState = .defaultValue


    
    init(sharedContext: SharedAccountContext, window: Window, account: Account, isSupport: Bool = false) {
        self.sharedContext = sharedContext
        self.account = account
        self.window = window
        self.engine = TelegramEngine(account: account)
        self.isSupport = isSupport
        #if !SHARE
        self.inAppPurchaseManager = .init(engine: engine)
        
        
        
        
        self.peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager(self.engine, account: account)
        self.diceCache = DiceCache(postbox: account.postbox, engine: self.engine)
        self.inlinePacksContext = .init(postbox: account.postbox, engine: self.engine)
        self.fetchManager = FetchManagerImpl(postbox: account.postbox, storeManager: DownloadedMediaStoreManagerImpl(postbox: account.postbox, accountManager: sharedContext.accountManager))
        self.blockedPeersContext = BlockedPeersContext(account: account, subject: .blocked)
        self.storiesBlockedPeersContext = BlockedPeersContext(account: account, subject: .stories)
        self.cacheCleaner = AccountClearCache(account: account)
        self.cachedGroupCallContexts = AccountGroupCallContextCacheImpl()
        self.activeSessionsContext = engine.privacy.activeSessions()
        self.webSessions = engine.privacy.webSessions()
        self.networkStatusManager = NetworkStatusManager(account: account, window: window, sharedContext: sharedContext)
        self.reactions = Reactions(engine)
        self.dockControl = DockControl(engine, accountManager: sharedContext.accountManager)
        self.starsContext = engine.payments.peerStarsContext()
        self.tonContext = engine.payments.peerTonContext()
        self.starsSubscriptionsContext = engine.payments.peerStarsSubscriptionsContext(starsContext: self.starsContext)
        
        _ = self.engine.payments.keepStarGiftsUpdated().start()
        
        let _ = self.engine.peers.requestGlobalRecommendedChannelsIfNeeded().startStandalone()
        let _ = self.engine.peers.requestRecommendedAppsIfNeeded().startStandalone()
        let _ = self.engine.peers.managedUpdatedRecentApps().startStandalone()
        
        self.reactions.checkStarsAmount = { [weak self] amount, peerId in
            if let self {
                let starsAllowed = self.engine.data.get(TelegramEngine.EngineData.Item.Peer.ReactionSettings(id: peerId)) |> map { $0.knownValue?.starsAllowed == true }
                
                return combineLatest(queue: .mainQueue(), self.starsContext.state
                                     |> filter { $0 != nil }
                                     |> map { $0! }
                                     |> take(1)
                                     |> map { state in
                                        return state.balance.value >= amount
                                     }, starsAllowed)
            } else {
                return .single((false, false))
            }
        }
        
        self.reactions.failStarsAmount = { [weak self] amount, messageId in
            if let self {
                let signal = self.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)) |> deliverOnMainQueue
                _ = signal.start(next: { [weak self] peer in
                    if let peer = peer, let self {
                        showModal(with: Star_ListScreen(context: self, source: .reactions(peer, Int64(amount))), for: self.window)
                    }
                })
            }
        }
        
        self.reactions.successStarsAmount = { [weak self] amount in
            self?.starsContext.add(balance: amount)
        }
        self.reactions.starsDisabled = { [weak self] in
            if let self {
                showModalText(for: self.window, text: strings().chatReactionStarsDisabled)
            }
        }
        
        let products: Signal<[InAppPurchaseManager.Product], NoError>
        #if APP_STORE
        products = inAppPurchaseManager.availableProducts |> map {
            $0
        }
        #else
        products = .single([])
        #endif
        
        let signal = combineLatest(
            engine.payments.premiumGiftCodeOptions(peerId: nil),
            products
        )
        |> map { options, products in
            var gifts: [PremiumGiftProduct] = []
            for option in options {
                let product = products.first(where: { $0.id == option.storeProductId })
                gifts.append(PremiumGiftProduct(giftOption: option, storeProduct: product))
            }
            let defaultPrice: (Int64, NSDecimalNumber)
            if let defaultProduct = products.first(where: { $0.id == "org.telegram.telegramPremium.monthly" }) {
                defaultPrice = (defaultProduct.priceCurrencyAndAmount.amount, defaultProduct.priceValue)
            } else if let defaultProduct = options.first(where: { $0.storeProductId == "org.telegram.telegramPremium.threeMonths.code_x1" }) {
                defaultPrice = (defaultProduct.amount / Int64(defaultProduct.months), NSDecimalNumber(value: 1))
            } else {
                defaultPrice = (1, NSDecimalNumber(value: 1))
            }
            return (gifts, defaultPrice)
        } |> deliverOnMainQueue
        
        actionsDisposable.add(signal.start(next: { [weak self] value in
            self?.premiumProductsAndPrice = value
        }))
        
        
    #endif
        
        
        giftStickersValues.set(engine.stickers.loadedStickerPack(reference: .premiumGifts, forceActualized: false)
        |> map { pack in
            switch pack {
            case let .result(_, items, _):
                return items.map { $0.file._parse() }
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
        let appConfiguration = _appConfiguration
        prefDisposable.add(account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration]).start(next: { view in
            let configuration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
            _ = appConfiguration.swap(configuration)
        }))
        prefDisposable.add((account.postbox.peerView(id: account.peerId) |> deliverOnMainQueue).start(next: { [weak self] peerView in
            self?._myPeer = peerView.peers[peerView.peerId]
        }))
        
        
       
        
        
        #if !SHARE
       
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
        let themes = (chatThemes |> then(.complete() |> suspendAwareDelay(20.0 * 60.0, queue: .concurrentDefaultQueue()))) |> restart
        
        actionsDisposable.add(themes.start(next: { [weak self] values in
            self?._emoticonThemes.swap(values)
            self?._chatThemes.set(.single(values))
        }))
        
        let currentCountriesConfiguration = currentCountriesConfiguration
        self.actionsDisposable.add((engine.localization.getCountriesList(accountManager: sharedContext.accountManager, langCode: nil)
        |> deliverOnMainQueue).start(next: { value in
            let _ = currentCountriesConfiguration.swap(CountriesConfiguration(countries: value))
        }))

        
        
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
        
        actionsDisposable.add((contentSettingsConfiguration(network: account.network) |> deliverOnMainQueue).startStandalone(next: { [weak self] settings in
            self?.contentConfig = settings
        }))
        
        #endif
        
        actionsDisposable.add(combineLatest(queue: .mainQueue(), engine.accountData.observeAvailableColorOptions(scope: .profile), engine.accountData.observeAvailableColorOptions(scope: .replies)).start(next: { [weak self] profile, replies in
            self?._peerNameColors = .with(availableReplyColors: replies, availableProfileColors: profile)
        }))
        
        actionsDisposable.add((self.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: account.peerId))
           |> mapToSignal { peer -> Signal<AudioTranscription.TrialState, NoError> in
               let isPremium = peer?.isPremium ?? false
               if isPremium {
                   return .single(AudioTranscription.TrialState(cooldownUntilTime: nil, remainingCount: 1))
               } else {
                   return self.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.AudioTranscriptionTrial())
               }
           }
           |> deliverOnMainQueue).startStrict(next: { [weak self] audioTranscriptionTrial in
               guard let `self` = self else {
                   return
               }
               self.audioTranscriptionTrial = audioTranscriptionTrial
           }))

        
        
        let autoplayMedia = _autoplayMedia
        prefDisposable.add(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.autoplayMedia]).start(next: { view in
            _ = autoplayMedia.swap(view.values[ApplicationSpecificPreferencesKeys.autoplayMedia]?.get(AutoplayMediaPreferences.self) ?? AutoplayMediaPreferences.defaultSettings)
        }))
        
        let contentSettings = _contentSettings
        prefDisposable.add(getContentSettings(postbox: account.postbox).start(next: { settings in
            _ = contentSettings.swap(settings)
        }))
        
        let st = _stickerSettings
        prefDisposable.add(InAppSettings.stickerSettings(postbox: account.postbox).start(next: { settings in
            _ = st.swap(settings)
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
        
        var previous: [ChatListFilter]?
        checkSidebarShouldEnable.set(engine.peers.updatedChatListFilters().start(next: { filters in
            if previous != filters, let previous = previous {
                let prevCount = previous.count
                let newCount = filters.count
                if newCount > prevCount, newCount > 3 {
                    _ = updateChatListFolderSettings(account.postbox, { current in
                        if !current.interacted {
                            return current.withUpdatedSidebar(true)
                        } else {
                            return current
                        }
                    }).start()
                }
            }
            previous = filters
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
        
        actionsDisposable.add(requestApplicationIcons(engine: engine).start())

//        let focusIntentStatus = someAccountSetings(postbox: account.postbox) 
//        |> distinctUntilChanged(isEqual: { 
//            $0.focusIntentStatusEnabled == $1.focusIntentStatusEnabled &&
//            $0.focusIntentStatusActive == $1.focusIntentStatusActive
//        })
//        |> deliverOnMainQueue
//        
//        actionsDisposable.add(focusIntentStatus.startStandalone(next: { [weak self] settings in
//            guard let self else {
//                return
//            }
//            let setStatus:(Int64?)->Void = { [weak self] fileId in
//                guard let self else {
//                    return
//                }
//                if let fileId {
//                    let file = self.inlinePacksContext.load(fileId: fileId) |> deliverOnMainQueue
//                    _ = file.startStandalone(next: { file in
//                        _ = engine.accountData.setEmojiStatus(file: file, expirationDate: nil).start()
//                    })
//                } else {
//                    _ = engine.accountData.setEmojiStatus(file: nil, expirationDate: nil).start()
//                }
//            }
//            if settings.focusIntentStatusEnabled {
//                if let fileId = settings.focusIntentStatusActive {
//                    setStatus(fileId)
//                } else {
//                     _ = (self.diceCache.top_emojies_status |> deliverOnMainQueue).startStandalone(next: { files in
//                         if let file = files.first(where: { $0.customEmojiText == focusIntentEmoji }) {
//                             setStatus(file.fileId.id)
//                         }
//                     })
//                }
//            } else if let fileId = settings.focusIntentStatusFallback {
//                setStatus(fileId)
//            } else {
//                setStatus(nil)
//            }
//        }))
        
        #endif
        
        let isPremium: Signal<Bool, NoError> = account.postbox.peerView(id: account.peerId) |> map { view in
            return (view.peers[view.peerId] as? TelegramUser)?.flags.contains(.isPremium) ?? false
        } |> deliverOnMainQueue
        
        self.premiumDisposable.set(isPremium.start(next: { [weak self] value in
            self?.isPremium = value
        }))
        
        self.globalLocationDisposable.set(globalPeerHandler.get().start(next: { [weak self] value in
            _ = self?._globalLocationId.swap(value)
        }))
        let autologinToken = engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.Links()) |> deliverOnMainQueue
        
        actionsDisposable.add(autologinToken.start(next: { [weak self] token in
            self?.autologinToken = token.autologinToken
        }))
    }
    
    @objc private func updateKeyWindow() {
        self.isKeyWindowValue.set(window.isKeyWindow)
    }
    
    func focus() {
        window.makeKeyAndOrderFront(nil)
    }
    
    func isLite(_ key: LiteModeKey = .any) -> Bool {
        #if !SHARE
        return sharedContext.isLite(key)
        #endif
        return false
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
        freeSpaceDisposable.dispose()
        premiumDisposable.dispose()
        globalLocationDisposable.dispose()
        reindexCacheDisposable.dispose()
        shouldReindexCacheDisposable.dispose()
        checkSidebarShouldEnable.dispose()
        actionsDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
        #if !SHARE
      //  self.walletPasscodeTimeoutContext.clear()
        self.networkStatusManager.cleanup()
        self.diceCache.cleanup()
        _chatThemes.set(.single([]))
        _cloudThemes.set(.single(.init(themes: [], list: [:], default: nil, custom: nil)))
        reactionSettingsDisposable.dispose()
        dockControl.clear()
        #endif
    }
    
    var isFrozen: Bool {
        return appConfiguration.getGeneralValue("freeze_since_date", orElse: 0) != 0
    }
   
    
#if !SHARE
    func freezeAlert() {
        showModal(with: FrozenAccountController(context: self), for: self.window)
    }
    #endif
    
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
            if data.isForumPost || data.peerId.namespace != Namespaces.Peer.CloudChannel || data.isMonoforumPost {
                return .peer(peerId: data.peerId, threadId: data.threadId)
            } else {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return .thread(peerId: data.peerId, threadId: data.threadId, data: context.state)
            }
        }
    }
    
    func chatLocationOutgoingReadState(for location: ChatLocation, contextHolder: Atomic<ChatLocationContextHolder?>) -> Signal<MessageId?, NoError> {
        switch location {
        case .peer:
            return .single(nil)
        case let .thread(data):
            if data.isForumPost {
                let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: data.peerId, threadId: data.threadId)
                return self.account.postbox.combinedView(keys: [viewKey])
                |> map { views -> MessageId? in
                    if let threadInfo = views.views[viewKey] as? MessageHistoryThreadInfoView, let data = threadInfo.info?.data.get(MessageHistoryThreadData.self) {
                        return MessageId(peerId: location.peerId, namespace: Namespaces.Message.Cloud, id: data.maxOutgoingReadId)
                    } else {
                        return nil
                    }
                }
            } else if data.peerId.namespace == Namespaces.Peer.CloudChannel {
                let context = chatLocationContext(holder: contextHolder, account: self.account, data: data)
                return context.maxReadOutgoingMessageId
            } else {
                return .single(nil)
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
                let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: data.peerId, threadId: data.threadId)
                return self.account.postbox.combinedView(keys: [viewKey])
                |> map { views -> Int in
                    if let threadInfo = views.views[viewKey] as? MessageHistoryThreadInfoView, let data = threadInfo.info?.data.get(MessageHistoryThreadData.self) {
                        return Int(data.incomingUnreadCount)
                    } else {
                        return 0
                    }
                }
            } else if data.peerId.namespace != Namespaces.Peer.CloudChannel {
                return .single(0)
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
            let controller = ChatController(context: context, chatLocation: chatLocation, mode: .thread(mode: updatedMode), focusTarget: .init(messageId: fromId), initialAction: nil, chatLocationContextHolder: result.contextHolder)
            
            context.bindings.rootNavigation().push(controller)
            
        }, error: { error in
            
        })
    }

    
    func composeCreateGroup(selectedPeers:Set<PeerId> = Set()) {
        if isFrozen {
            self.freezeAlert()
        } else {
            createGroup(with: self, selectedPeers: selectedPeers)
        }
    }
    func composeCreateChannel() {
        if isFrozen {
            self.freezeAlert()
        } else {
            createChannel(with: self)
        }
    }
    func composeCreateSecretChat() {
        if isFrozen {
            self.freezeAlert()
        } else {
            let account = self.account
            let window = self.window
            let engine = self.engine
            let confirmationImpl:([PeerId])->Signal<Bool, NoError> = { peerIds in
                if let first = peerIds.first, peerIds.count == 1 {
                    return account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                        return verifyAlertSignal(for: window, information: strings().composeConfirmStartSecretChat(peer.displayTitle)) |> map { $0 == .basic }
                    }
                }
                return verifyAlertSignal(for: window, information: strings().peerInfoConfirmAddMembers1Countable(peerIds.count)) |> map { $0 == .basic }
            }
            let select = selectModalPeers(window: window, context: self, title: strings().composeSelectSecretChat, limit: 1, confirmation: confirmationImpl)
            
            let create = select |> map { $0.first! } |> castError(CreateSecretChatError.self) |> mapToSignal { peerId in
                return engine.peers.createSecretChat(peerId: peerId)
            } |> deliverOnMainQueue
            
            _ = create.start(next: { [weak self] peerId in
                guard let `self` = self else {return}
                self.bindings.rootNavigation().push(ChatController(context: self, chatLocation: .peer(peerId)))
            }, error: { [weak self] error in
                guard let context = self else {
                    return
                }
                switch error {
                case .generic:
                    showModalText(for: context.window, text: strings().unknownError)
                case .limitExceeded:
                    showModalText(for: context.window, text: strings().loginFloodWait)
                case let .premiumRequired(peer):
                    showModalText(for: context.window, text: strings().chatSecretChatPremiumRequired(peer._asPeer().compactDisplayTitle), button: strings().alertLearnMore, callback: { _ in
                        prem(with: PremiumBoardingController(context: context), for: context.window)
                    })
                }
            })
        }
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
            let fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .file, reference: MediaResourceReference.standalone(resource: file.resource)).start()
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
        self.context = ReplyThreadHistoryContext(account: account, peerId: data.peerId, data: data)
    }
}

