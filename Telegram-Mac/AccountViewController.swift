//
//  AccountViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit


private final class AccountSearchBarView: TitledBarView {
    fileprivate let searchView = SearchView(frame: NSMakeRect(0, 0, 100, 30))
    init(controller: ViewController) {
        super.init(controller: controller)
        addSubview(searchView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        searchView.updateLocalizationAndTheme(theme: theme)
    }
    
    override func layout() {
        super.layout()
        searchView.setFrameSize(NSMakeSize(frame.width, 30))
        searchView.center()
    }
    
}


fileprivate final class AccountInfoArguments {
    let context: AccountContext
    let presentController:(ViewController, Bool) -> Void
    let openFaq:()->Void
    let ask:()->Void
    let openUpdateApp:() -> Void
    init(context: AccountContext, presentController:@escaping(ViewController, Bool)->Void, openFaq: @escaping()->Void, ask:@escaping()->Void, openUpdateApp: @escaping() -> Void) {
        self.context = context
        self.presentController = presentController
        self.openFaq = openFaq
        self.ask = ask
        self.openUpdateApp = openUpdateApp
    }
}

class AccountViewController: NavigationViewController {
    private var layoutController:LayoutAccountController
    private let disposable = MetaDisposable()
    init(_ context: AccountContext) {
        self.layoutController = LayoutAccountController(context)
        super.init(layoutController, context.window)
        self.ready.set(layoutController.ready.get())
        disposable.set(context.hasPassportSettings.get().start(next: { [weak self] value in
            self?.layoutController.passportPromise.set(.single(value))
        }))
        self.applyAppearOnLoad = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (self.view as? View)?.border = [.Right]
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        layoutController._frameRect = bounds
        layoutController.frame = NSMakeRect(0, layoutController.bar.height, bounds.width, bounds.height - layoutController.bar.height)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layoutController.viewWillAppear(animated)
    }
    
    override func scrollup(force: Bool = false) {
        layoutController.scrollup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutController.viewDidAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        layoutController.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        layoutController.viewDidDisappear(animated)
    }
}

private enum AccountInfoEntryId : Hashable {
    case index(Int)
    case account(AccountWithInfo)
    
    var hashValue: Int {
        return 0
    }
}

private enum AccountInfoEntry : TableItemListNodeEntry {
    case info(index:Int, TelegramUser)
    case accountRecord(index: Int, info: AccountWithInfo)
    case addAccount(index: Int)
    case proxy(index: Int, status: String?)
    case general(index: Int)
    case stickers(index: Int)
    case notifications(index: Int)
    case language(index: Int, current: String)
    case appearance(index: Int)
    case privacy(index: Int, AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?)
    case dataAndStorage(index: Int)
    case activeSessions(index: Int, activeSessions: Int)
    case passport(index: Int, peer: Peer)
    case wallet(index: Int)
    case update(index: Int, state: Any)
    case filters(index: Int)
    case readArticles(index: Int)
    case about(index: Int)
    case faq(index: Int)
    case ask(index: Int)
    case whiteSpace(index:Int, height:CGFloat)
    
    var stableId: AccountInfoEntryId {
        switch self {
        case .info:
            return .index(0)
        case let .accountRecord(_, info):
            return .account(info)
        case .addAccount:
            return .index(1)
        case .general:
            return .index(2)
        case .proxy:
            return .index(3)
        case .notifications:
            return .index(4)
        case .dataAndStorage:
            return .index(5)
        case .activeSessions:
            return .index(6)
        case .privacy:
            return .index(7)
        case .language:
            return .index(8)
        case .stickers:
            return .index(9)
        case .filters:
            return .index(10)
        case .update:
            return .index(11)
        case .appearance:
            return .index(12)
        case .passport:
            return .index(13)
        case .wallet:
            return .index(14)
        case .readArticles:
            return .index(15)
        case .about:
            return .index(16)
        case .faq:
            return .index(17)
        case .ask:
            return .index(18)
        case let .whiteSpace(index, _):
            return .index(1000 + index)
        }
    }
    
    var index:Int {
        switch self {
        case let .info(index, _):
            return index
        case let .accountRecord(index, _):
            return index
        case let .addAccount(index):
            return index
        case let  .general(index):
            return index
        case let  .proxy(index, _):
            return index
        case let .stickers(index):
            return index
        case let .notifications(index):
            return index
        case let .language(index, _):
            return index
        case let .appearance(index):
            return index
        case let .privacy(index, _, _):
            return index
        case let .dataAndStorage(index):
            return index
        case let .activeSessions(index, _):
            return index
        case let .about(index):
            return index
        case let .passport(index, _):
            return index
        case let .filters(index):
            return index
        case let .wallet(index):
            return index
        case let .readArticles(index):
            return index
        case let .faq(index):
            return index
        case let .ask(index):
            return index
        case let .update(index, _):
            return index
        case let .whiteSpace(index, _):
            return index
        }
    }
    
    static func ==(lhs:AccountInfoEntry, rhs:AccountInfoEntry) -> Bool {
        switch lhs {
        case let .info(lhsIndex, lhsPeer):
            if case let .info(rhsIndex, rhsPeer) = rhs {
                return lhsIndex == rhsIndex && lhsPeer.isEqual(rhsPeer)
            } else {
                return false
            }
        case let .accountRecord(lhsIndex, lhsInfo):
            if case let .accountRecord(rhsIndex, rhsInfo) = rhs {
                return lhsIndex == rhsIndex && lhsInfo == rhsInfo
            } else {
                return false
            }
        case let .addAccount(lhsIndex):
            if case let .addAccount(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .stickers(lhsIndex):
            if case let .stickers(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .general(lhsIndex):
            if case let .general(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .proxy(lhsIndex, lhsStatus):
            if case let .proxy(rhsIndex, rhsStatus) = rhs {
                return lhsIndex == rhsIndex && lhsStatus == rhsStatus
            } else {
                return false
            }
        case let .notifications(lhsIndex):
            if case let .notifications(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .language(index, current):
            if case .language(index, current) = rhs {
                return true
            } else {
                return false
            }
        case let .appearance(lhsIndex):
            if case let .appearance(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .privacy(lhsIndex, lhsPrivacy, lhsWebSessions):
            if case let .privacy(rhsIndex, rhsPrivacy, rhsWebSessions) = rhs {
                if let lhsWebSessions = lhsWebSessions, let rhsWebSessions = rhsWebSessions {
                    if lhsWebSessions.0 != rhsWebSessions.0 {
                        return false
                    }
                } else if (lhsWebSessions != nil) != (rhsWebSessions != nil) {
                    return false
                }
                return lhsIndex == rhsIndex && lhsPrivacy == rhsPrivacy
            } else {
                return false
            }
        case let .dataAndStorage(lhsIndex):
            if case let .dataAndStorage(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .activeSessions(index, activeSessions):
            if case .activeSessions(index, activeSessions) = rhs {
                return true
            } else {
                return false
            }
        case let .about(lhsIndex):
            if case let .about(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .passport(lhsIndex, lhsPeer):
            if case let .passport(rhsIndex, rhsPeer) = rhs {
                return lhsIndex == rhsIndex && lhsPeer.isEqual(rhsPeer)
            } else {
                return false
            }
        case let .wallet(index):
            if case .wallet(index) = rhs {
                return true
            } else {
                return false
            }
        case let .readArticles(lhsIndex):
            if case let .readArticles(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .faq(lhsIndex):
            if case let .faq(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .ask(lhsIndex):
            if case let .ask(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .filters(lhsIndex):
            if case let .filters(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .update(lhsIndex, lhsState):
            if case let .update(rhsIndex, rhsState) = rhs {
                #if !APP_STORE
                    let lhsState = lhsState as? AppUpdateState
                    let rhsState = rhsState as? AppUpdateState
                    if lhsState != rhsState {
                        return false
                    }
                #endif
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .whiteSpace(lhsIndex, lhsHeight):
            if case let .whiteSpace(rhsIndex, rhsHeight) = rhs {
                return lhsIndex == rhsIndex && lhsHeight == rhsHeight
            } else {
                return false
            }
        }
    }
    
    static func <(lhs:AccountInfoEntry, rhs:AccountInfoEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: AccountInfoArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .info(_, peer):
            return AccountInfoItem(initialSize, stableId: stableId, context: arguments.context, peer: peer, action: {
                let first: Atomic<Bool> = Atomic(value: true)
                EditAccountInfoController(context: arguments.context, f: { controller in
                    arguments.presentController(controller, first.swap(false))
                })
            })
        case let .accountRecord(_, info):
            return ShortPeerRowItem(initialSize, peer: info.peer, account: info.account, height: 42, photoSize: NSMakeSize(28, 28), titleStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.text, highlightColor: theme.colors.underSelectedColor), borderType: [.Right], inset: NSEdgeInsets(left:16), action: {
                arguments.context.sharedContext.switchToAccount(id: info.account.id, action: .settings)
            }, contextMenuItems: {
                return .single([ContextMenuItem(L10n.accountSettingsDeleteAccount, handler: {
                    confirm(for: arguments.context.window, information: L10n.accountConfirmLogoutText, successHandler: { _ in
                        _ = logoutFromAccount(id: info.account.id, accountManager: arguments.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                    })
                })])
            }, alwaysHighlight: true, badgeNode: GlobalBadgeNode(info.account, sharedContext: arguments.context.sharedContext, getColor: { _ in theme.colors.accent }), compactText: true)
        case .addAccount:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsAddAccount, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accentIcon), type: .none, action: {
                let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
                arguments.context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
                
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 35, thumbInset: 0), border:[BorderType.Right], inset:NSEdgeInsets(left:15))
        case .general:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsGeneral, icon: theme.icons.settingsGeneral, activeIcon: theme.icons.settingsGeneralActive, type: .next, action: {
                arguments.presentController(GeneralSettingsViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .proxy(_, let status):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsProxy, icon: theme.icons.settingsProxy, activeIcon: theme.icons.settingsProxyActive, type: .nextContext(status ?? ""), action: {
                let controller = proxyListController(accountManager: arguments.context.sharedContext.accountManager, network: arguments.context.account.network, share: { servers in
                    var message: String = ""
                    for server in servers {
                        message += server.link + "\n\n"
                    }
                    message = message.trimmed
                    
                    showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: message)), for: mainWindow)
                }, pushController: { controller in
                     arguments.presentController(controller, false)
                })
                arguments.presentController(controller, true)

            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .stickers:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsStickers, icon: theme.icons.settingsStickers, activeIcon: theme.icons.settingsStickersActive, type: .next, action: {
                arguments.presentController(InstalledStickerPacksController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .notifications:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsNotifications, icon: theme.icons.settingsNotifications, activeIcon: theme.icons.settingsNotificationsActive, type: .next, action: {
                arguments.presentController(NotificationPreferencesController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .language(_, current):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsLanguage, icon: theme.icons.settingsLanguage, activeIcon: theme.icons.settingsLanguageActive, type: .nextContext(current), action: {
                arguments.presentController(LanguageViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .appearance:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsTheme, icon: theme.icons.settingsAppearance, activeIcon: theme.icons.settingsAppearanceActive, type: .next, action: {
                arguments.presentController(AppAppearanceViewController(context: arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .privacy(_,  privacySettings, webSessions):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsPrivacyAndSecurity, icon: theme.icons.settingsSecurity, activeIcon: theme.icons.settingsSecurityActive, type: .next, action: {
                 arguments.presentController(PrivacyAndSecurityViewController(arguments.context, initialSettings: (privacySettings, webSessions)), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .dataAndStorage:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsDataAndStorage, icon: theme.icons.settingsStorage, activeIcon: theme.icons.settingsStorageActive, type: .next, action: {
                arguments.presentController(DataAndStorageViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .activeSessions(_, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsActiveSessions, icon: theme.icons.settingsSessions, activeIcon: theme.icons.settingsSessionsActive, type: .nextContext("\(count)"), action: {
                arguments.presentController(RecentSessionsController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .about:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsAbout, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, action: {
                showModal(with: AboutModalController(), for: mainWindow)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .passport(_, peer):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsPassport, icon: theme.icons.settingsPassport, activeIcon: theme.icons.settingsPassportActive, type: .next, action: {
                arguments.presentController(PassportController(arguments.context, peer, request: nil, nil), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .wallet:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsWallet, icon: theme.icons.settingsWallet, activeIcon: theme.icons.settingsWalletActive, type: .next, action: {
                let context = arguments.context
//                if #available(OSX 10.12, *) {
//
//                    let _ = combineLatest(queue: .mainQueue(), walletConfiguration(postbox: context.account.postbox), TONKeychain.hasKeys(for: context.account)).start(next: { configuration, hasKeys in
//                        if let config = configuration.config, let blockchainName = configuration.blockchainName {
//                            let tonContext = context.tonContext.context(config: config, blockchainName: blockchainName, enableProxy: !configuration.disableProxy)
//                            if hasKeys {
//                                let signal = tonContext.storage.getWalletRecords() |> deliverOnMainQueue
//                                _ = signal.start(next: { wallets in
//                                    if wallets.isEmpty {
//                                        arguments.presentController(WalletSplashController(context: context, tonContext: tonContext, mode: .intro), true)
//                                    } else {
//                                        arguments.presentController(WalletInfoController(context: context, tonContext: tonContext, walletInfo: wallets[0].info), true)
//                                    }
//                                })
//                            } else {
//                                arguments.presentController(WalletSplashController(context: context, tonContext: tonContext, mode: .unavailable), true)
//                            }
//                        }
//                    })
//                }
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .faq:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsFAQ, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, action: {
                
                arguments.openFaq()
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .readArticles:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsReadArticles, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, action: {
                
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .ask:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsAskQuestion, icon: theme.icons.settingsAskQuestion, activeIcon: theme.icons.settingsAskQuestionActive, type: .next, action: {
                confirm(for: mainWindow, information: L10n.accountConfirmAskQuestion, thridTitle: L10n.accountConfirmGoToFaq, successHandler: {  result in
                    switch result {
                    case .basic:
                        _ = showModalProgress(signal: supportPeerId(account: arguments.context.account), for: mainWindow).start(next: {  peerId in
                            if let peerId = peerId {
                                arguments.presentController(ChatController(context: arguments.context, chatLocation: .peer(peerId)), true)
                            }
                        })
                    case .thrid:
                        arguments.openFaq()
                    }
                })
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .filters:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsFilters, icon: theme.icons.settingsFilters, activeIcon: theme.icons.settingsFiltersActive, type: .next, action: {
                arguments.presentController(ChatListFiltersListController(context: arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .update(_, let state):
            
            var text: String = ""
            #if !APP_STORE
            if let state = state as? AppUpdateState {
                switch state.loadingState {
                case let .loading(_, current, total):
                    text = "\(Int(Float(current) / Float(total) * 100))%"
                case let .readyToInstall(item), let .unarchiving(item):
                    text = "\(item.displayVersionString!).\(item.versionString!)"
                case .uptodate:
                    text = "" //L10n.accountViewControllerDescUpdated
                case .failed:
                    text = L10n.accountViewControllerDescFailed
                default:
                    text = ""
                }
            }
            #endif
           
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountViewControllerUpdate, icon: theme.icons.settingsUpdate, activeIcon: theme.icons.settingsUpdateActive, type: .nextContext(text), action: {
                arguments.openUpdateApp()
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .whiteSpace(_, height):
            return GeneralRowItem(initialSize, height: height, stableId: stableId, border:[BorderType.Right])
        }
    }
    
}


private func accountInfoEntries(peerView:PeerView, accounts: [AccountWithInfo], language: TelegramLocalization, privacySettings: AccountPrivacySettings?, webSessions: ([WebAuthorization], [PeerId : Peer])?, proxySettings: (ProxySettings, ConnectionStatus), passportVisible: Bool, appUpdateState: Any?, hasWallet: Bool, hasFilters: Bool, sessionsCount: Int) -> [AccountInfoEntry] {
    var entries:[AccountInfoEntry] = []
    
    var index:Int = 0
        
    if let peer = peerViewMainPeer(peerView) as? TelegramUser {
        entries.append(.info(index: index, peer))
        index += 1
    }
    
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    for account in accounts {
        if account.peer.id != peerView.peerId {
            entries.append(.accountRecord(index: index, info: account))
            index += 1
        }
    }
    if accounts.count < 3 {
        entries.append(.addAccount(index: index))
        index += 1
    }
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    if !proxySettings.0.servers.isEmpty {
        let status: String
        switch proxySettings.1 {
        case .online:
            status = proxySettings.0.enabled ? L10n.accountSettingsProxyConnected : L10n.accountSettingsProxyDisabled
        default:
            status = proxySettings.0.enabled ? L10n.accountSettingsProxyConnecting : L10n.accountSettingsProxyDisabled
        }
        entries.append(.proxy(index: index, status: status))
        index += 1
        
        entries.append(.whiteSpace(index: index, height: 20))
        index += 1
    }
    
    entries.append(.general(index: index))
    index += 1
    entries.append(.notifications(index: index))
    index += 1
    entries.append(.privacy(index: index, privacySettings, webSessions))
    index += 1
    entries.append(.dataAndStorage(index: index))
    index += 1
    entries.append(.activeSessions(index: index, activeSessions: sessionsCount))
    index += 1
    entries.append(.appearance(index: index))
    index += 1
    entries.append(.language(index: index, current: language.localizedName))
    index += 1
    entries.append(.stickers(index: index))
    index += 1
    
    if hasFilters {
        entries.append(.filters(index: index))
        index += 1
    }
    
    if let state = appUpdateState {
        entries.append(.update(index: index, state: state))
        index += 1
    }
   

    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    if let peer = peerViewMainPeer(peerView) as? TelegramUser, passportVisible {
        entries.append(.passport(index: index, peer: peer))
        index += 1
    }
//    if hasWallet {
//        entries.append(.wallet(index: index))
//        index += 1
//    }
    


    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    entries.append(.faq(index: index))
    index += 1
    entries.append(.ask(index: index))
    index += 1
    
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    return entries
}

private func prepareEntries(left: [AppearanceWrapperEntry<AccountInfoEntry>], right: [AppearanceWrapperEntry<AccountInfoEntry>], arguments: AccountInfoArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated)  = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class LayoutAccountController : TableViewController {
    private let disposable = MetaDisposable()
    
    private var searchController: InputDataController?
    private let searchState: ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    var navigation:NavigationViewController? {
        return context.sharedContext.bindings.rootNavigation()
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        self.searchController?.view.frame = bounds
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        let searchBar = AccountSearchBarView(controller: self)
        
        searchBar.searchView.searchInteractions = SearchInteractions({ [weak self] state, animated in
            guard let `self` = self else {return}
            self.searchState.set(state)
            switch state.state {
            case .Focus:
                self.showSearchController(animated: animated)
            case .None:
                self.hideSearchController(animated: animated)
            }
            
        }, { [weak self] state in
            self?.searchState.set(state)
        })
        
        return searchBar
    }
    
    private func showSearchController(animated: Bool) {
        if searchController == nil {
            let rect = genericView.bounds
            let searchController = SearchSettingsController(context: context, searchQuery: self.searchState.get(), archivedStickerPacks: .single(nil), privacySettings: self.settings.get() |> map { $0.0 })
            searchController.bar = .init(height: 0)
            searchController._frameRect = rect
            searchController.tableView.border = [.Right]
            self.searchController = searchController
            searchController.navigationController = self.navigationController
            searchController.viewWillAppear(true)
            if animated {
                searchController.view.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion:{ [weak self] complete in
                    if complete {
                        self?.searchController?.viewDidAppear(animated)
                    }
                })
            } else {
                searchController.viewDidAppear(animated)
            }
            
            self.addSubview(searchController.view)
        }
    }
    
    
    
    private func hideSearchController(animated: Bool) {
        if let searchController = self.searchController {
            searchController.viewWillDisappear(animated)
            searchController.view.layer?.opacity = animated ? 1.0 : 0.0
            searchController.viewDidDisappear(true)
            self.searchController = nil
            let view = searchController.view
            
            searchController.view._change(opacity: 0, animated: animated, duration: 0.25, timingFunction: CAMediaTimingFunctionName.spring, completion: { [weak view] completed in
                view?.removeFromSuperview()
            })
        }
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        guard context.sharedContext.layout != .minimisize else {
            return .invoked
        }
        let searchView = (self.centerBarView as? AccountSearchBarView)?.searchView
        if let searchView = searchView {
            if searchView.state == .None {
                return searchView.changeResponder() ? .invoked : .rejected
            } else if searchView.state == .Focus && searchView.query.length > 0 {
                searchView.change(state: .None,  true)
                return .invoked
            }
        }
        return .rejected
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: L10n.navigationEdit, style: navigationButtonStyle, alignment:.Right)
        let context = self.context
        button.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            let first: Atomic<Bool> = Atomic(value: true)
            EditAccountInfoController(context: context, f: { [weak self] controller in
                self?.arguments?.presentController(controller, first.swap(false))
            })
        }, for: .Click)
        return button
    }
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        (rightBarView as? TextButtonBarView)?.set(text: L10n.navigationEdit, for: .Normal)
        (rightBarView as? TextButtonBarView)?.set(color: theme.colors.accent, for: .Normal)
        (rightBarView as? TextButtonBarView)?.needsLayout = true
    }
    
    override func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return item is GeneralInteractedRowItem || item is AccountInfoItem || item is ShortPeerRowItem
    }
    
    override func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    private let settings: Promise<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?, (ProxySettings, ConnectionStatus), Bool)> = Promise()
    private let syncLocalizations = MetaDisposable()
    fileprivate let passportPromise: Promise<Bool> = Promise(false)
    fileprivate let hasWallet: Promise<Bool> = Promise(false)
    fileprivate let hasFilters: Promise<Bool> = Promise(false)

    private weak var arguments: AccountInfoArguments?
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.border = [.Right]
        genericView.delegate = self
       // self.rightBarView.border = [.Right]
        let context = self.context
        genericView.getBackgroundColor = {
            return .clear
        }
        
        settings.set(combineLatest(Signal<AccountPrivacySettings?, NoError>.single(nil) |> then(requestAccountPrivacySettings(account: context.account) |> map {Optional($0)}), Signal<([WebAuthorization], [PeerId : Peer])?, NoError>.single(nil) |> then(webSessions(network: context.account.network) |> map {Optional($0)}), proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { settings in
            return context.account.network.connectionStatus |> map {(settings, $0)}
        }, passportPromise.get()))
        
        
        syncLocalizations.set(synchronizedLocalizationListState(postbox: context.account.postbox, network: context.account.network).start())
        
        self.hasWallet.set(context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> map { view -> Bool in
            let appConfiguration = view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
            let configuration = WalletConfiguration.with(appConfiguration: appConfiguration)
            if #available(OSX 10.12, *) {
                return configuration.config != nil
            } else {
                return false
            }
        })
        
        self.hasFilters.set(context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> map { view -> Bool in
            let configuration = ChatListFilteringConfiguration(appConfiguration: view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue)
            return configuration.isEnabled
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<AccountInfoEntry>]> = Atomic(value: [])
        
        
        let arguments = AccountInfoArguments(context: context, presentController: { [weak self] controller, main in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            guard let singleLayout = self?.context.sharedContext.layout else {return}
             var main = main
            if let controller = navigation.controller as? InputDataController, controller.identifier == "wallet-create" {
                main = false
            }
            if main {
                navigation.removeExceptMajor()
            }
            navigation.push(controller, !main || singleLayout == .single)
        }, openFaq: {
            openFaq(context: context)
        }, ask: {
            
        }, openUpdateApp: { [weak self] in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            #if !APP_STORE
            navigation.push(AppUpdateViewController(), false)
            #endif
        })
        
        self.arguments = arguments
        
        let atomicSize = self.atomicSize
        

        let appUpdateState: Signal<Any?, NoError>
        #if APP_STORE
            appUpdateState = .single(nil)
        #else
        appUpdateState = appUpdateStateSignal |> map(Optional.init)
        #endif
        
        
        let sessionsCount = context.activeSessionsContext.state |> map {
            $0.sessions.count
        }
        
        let apply = combineLatest(queue: prepareQueue, context.account.viewTracker.peerView(context.account.peerId), context.sharedContext.activeAccountsWithInfo, appearanceSignal, settings.get(), appUpdateState, hasWallet.get(), hasFilters.get(), sessionsCount) |> map { peerView, accounts, appearance, settings, appUpdateState, hasWallet, hasFilters, sessionsCount -> TableUpdateTransition in
            let entries = accountInfoEntries(peerView: peerView, accounts: accounts.accounts, language: appearance.language, privacySettings: settings.0, webSessions: settings.1, proxySettings: settings.2, passportVisible: settings.3, appUpdateState: appUpdateState, hasWallet: hasWallet, hasFilters: hasFilters, sessionsCount: sessionsCount).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            var size = atomicSize.modify {$0}
            size.width = max(size.width, 280)
            return prepareEntries(left: previous.swap(entries), right: entries, arguments: arguments, initialSize: size)
        } |> deliverOnMainQueue
        
        disposable.set(apply.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
    }
    
    
    
    
    override func navigationWillChangeController() {
        if let navigation = navigation as? ExMajorNavigationController {
            if navigation.controller is DataAndStorageViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(5))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PrivacyAndSecurityViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(7))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is LanguageViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(8))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is InstalledStickerPacksController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(9))) {
                    _ = genericView.select(item: item)
                }
                
            } else if navigation.controller is GeneralSettingsViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(2))) {
                    _ = genericView.select(item: item)
                }
            }  else if navigation.controller is RecentSessionsController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(6))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PassportController {
                if let item = genericView.item(stableId: AccountInfoEntryId.index(Int(13))) {
                    _ = genericView.select(item: item)
                }
            } else if let controller = navigation.controller as? InputDataController {
                switch true {
                case controller.identifier == "proxy":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(3))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "account":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(0))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "passport":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(13))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "app_update":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(11))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "filters":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(10))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "notification-settings":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(4))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "app_appearance":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(12))) {
                        _ = genericView.select(item: item)
                    }
//                case controller.identifier == "wallet-info" || controller.identifier == "wallet-create" || controller.identifier == "wallet-splash":
//                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(12))) {
//                        _ = genericView.select(item: item)
//                    }
                default:
                    genericView.cancelSelection()
                }
               
            } else {
                genericView.cancelSelection()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (navigation as? MajorNavigationController)?.add(listener: WeakReference(value: self))
        
        passportPromise.set(twoStepAuthData(context.account.network) |> map { value in
            return value.hasSecretValues
        } |> `catch` { error -> Signal<Bool, NoError> in
                return .single(false)
        })
        
        updateLocalizationAndTheme(theme: theme)
        
        
        context.window.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.escapeKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Escape, priority:.low)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let context = self.context
        
        
        
        
        settings.set(combineLatest(Signal<AccountPrivacySettings?, NoError>.single(nil) |> then(requestAccountPrivacySettings(account: context.account) |> map {Optional($0)}), Signal<([WebAuthorization], [PeerId : Peer])?, NoError>.single(nil) |> then(webSessions(network: context.account.network) |> map {Optional($0)}), proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { settings in
            return context.account.network.connectionStatus |> map {(settings, $0)}
        }, passportPromise.get()))
        

        syncLocalizations.set(synchronizedLocalizationListState(postbox: context.account.postbox, network: context.account.network).start())
        
    }
    
    override func getLeftBarViewOnce() -> BarView {
        return BarView(10, controller: self)
    }
    
    override init(_ context: AccountContext) {
        super.init(context)
    }
    

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        navigationController?.updateLocalizationAndTheme(theme: theme)
    }
    
    override func firstResponder() -> NSResponder? {
        return nil
    }

    
    override func scrollup(force: Bool = false) {
        
        if searchController != nil {
            let searchView = (self.centerBarView as? AccountSearchBarView)?.searchView
            searchView?.cancel(true)
            return
        }
        
        if let currentEvent = NSApp.currentEvent, currentEvent.clickCount == 5 {
            context.sharedContext.bindings.rootNavigation().push(DeveloperViewController(context: context))
        }
        
        genericView.scroll(to: .up(true))
    }
    
    deinit {
        syncLocalizations.dispose()
        disposable.dispose()
    }

}

