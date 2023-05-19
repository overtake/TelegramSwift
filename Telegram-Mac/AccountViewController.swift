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
import Localization
import Postbox
import SwiftSignalKit

let normalAccountsLimit: Int = 3


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
    let openPremium:()->Void
    let addAccount:([AccountWithInfo])->Void
    let setStatus:(Control, TelegramUser)->Void
    let runStatusPopover:()->Void
    init(context: AccountContext, presentController:@escaping(ViewController, Bool)->Void, openFaq: @escaping()->Void, ask:@escaping()->Void, openUpdateApp: @escaping() -> Void, openPremium:@escaping()->Void, addAccount:@escaping([AccountWithInfo])->Void, setStatus:@escaping(Control, TelegramUser)->Void, runStatusPopover:@escaping()->Void) {
        self.context = context
        self.presentController = presentController
        self.openFaq = openFaq
        self.ask = ask
        self.openUpdateApp = openUpdateApp
        self.openPremium = openPremium
        self.addAccount = addAccount
        self.setStatus = setStatus
        self.runStatusPopover = runStatusPopover
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
        layoutController._frameRect = size.bounds
        layoutController.frame = NSMakeRect(0, layoutController.bar.height, size.width, size.height - layoutController.bar.height)
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
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .index(value):
            hasher.combine(value)
        case let .account(info):
            hasher.combine(info.account.id.int64)
        }
    }
}

private final class AnyUpdateStateEquatable  : Equatable {
    let any: Any
    init(any: Any) {
        self.any = any
    }
    static func ==(lhs: AnyUpdateStateEquatable, rhs: AnyUpdateStateEquatable) -> Bool {
        return lhs === rhs
    }
}

private enum AccountInfoEntry : TableItemListNodeEntry {
    case info(index:Int, viewType: GeneralViewType, PeerEquatable)
    case setStatus(index:Int, viewType: GeneralViewType, PeerEquatable)
    case accountRecord(index: Int, viewType: GeneralViewType, info: AccountWithInfo)
    case addAccount(index: Int, [AccountWithInfo], viewType: GeneralViewType)
    case proxy(index: Int, viewType: GeneralViewType, status: String?)
    case general(index: Int, viewType: GeneralViewType)
    case stickers(index: Int, viewType: GeneralViewType)
    case notifications(index: Int, viewType: GeneralViewType, status: UNUserNotifications.AuthorizationStatus)
    case language(index: Int, viewType: GeneralViewType, current: String)
    case appearance(index: Int, viewType: GeneralViewType)
    case privacy(index: Int, viewType: GeneralViewType, AccountPrivacySettings?, WebSessionsContextState)
    case dataAndStorage(index: Int, viewType: GeneralViewType)
    case activeSessions(index: Int, viewType: GeneralViewType, activeSessions: Int)
    case passport(index: Int, viewType: GeneralViewType, peer: PeerEquatable)
    case update(index: Int, viewType: GeneralViewType, state: AnyUpdateStateEquatable)
    case filters(index: Int, viewType: GeneralViewType)
    case premium(index: Int, viewType: GeneralViewType)
    case about(index: Int, viewType: GeneralViewType)
    case faq(index: Int, viewType: GeneralViewType)
    case ask(index: Int, viewType: GeneralViewType)

    case whiteSpace(index:Int, height:CGFloat)
    
    var stableId: AccountInfoEntryId {
        switch self {
        case .info:
            return .index(0)
        case .setStatus:
            return .index(1)
        case let .accountRecord(_, _, info):
            return .account(info)
        case .addAccount:
            return .index(2)
        case .general:
            return .index(3)
        case .proxy:
            return .index(4)
        case .notifications:
            return .index(5)
        case .dataAndStorage:
            return .index(6)
        case .activeSessions:
            return .index(7)
        case .privacy:
            return .index(8)
        case .language:
            return .index(9)
        case .stickers:
            return .index(10)
        case .filters:
            return .index(11)
        case .update:
            return .index(12)
        case .appearance:
            return .index(13)
        case .passport:
            return .index(14)
        case .premium:
            return .index(15)
        case .faq:
            return .index(16)
        case .ask:
            return .index(17)
        case .about:
            return .index(18)
        case let .whiteSpace(index, _):
            return .index(1000 + index)
        }
    }
    
    var index:Int {
        switch self {
        case let .info(index, _, _):
            return index
        case let .setStatus(index, _, _):
            return index
        case let .accountRecord(index, _, _):
            return index
        case let .addAccount(index, _, _):
            return index
        case let  .general(index, _):
            return index
        case let  .proxy(index, _, _):
            return index
        case let .stickers(index, _):
            return index
        case let .notifications(index, _, _):
            return index
        case let .language(index, _, _):
            return index
        case let .appearance(index, _):
            return index
        case let .privacy(index, _, _, _):
            return index
        case let .dataAndStorage(index, _):
            return index
        case let .activeSessions(index, _, _):
            return index
        case let .about(index, _):
            return index
        case let .passport(index, _, _):
            return index
        case let .filters(index, _):
            return index
        case let .premium(index, _):
            return index
        case let .faq(index, _):
            return index
        case let .ask(index, _):
            return index
        case let .update(index, _, _):
            return index
        case let .whiteSpace(index, _):
            return index
        }
    }
    
    static func <(lhs:AccountInfoEntry, rhs:AccountInfoEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: AccountInfoArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .info(_, viewType, peer):
            return AccountInfoItem(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets(left: 12, right: 12), context: arguments.context, peer: peer.peer as! TelegramUser, action: {
                let first: Atomic<Bool> = Atomic(value: true)
                EditAccountInfoController(context: arguments.context, f: { controller in
                    arguments.presentController(controller, first.swap(false))
                })
            }, setStatus: arguments.setStatus)
        case let .setStatus(_, viewType, peer):
            let icon: CGImage = peer.peer.emojiStatus != nil ? theme.icons.account_change_status : theme.icons.account_set_status
            let text = peer.peer.emojiStatus != nil ? strings().accountSettingsChangeStatus : strings().accountSettingsUpdateStatus
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accentIcon), type: .none, viewType: viewType, action: arguments.runStatusPopover, thumb: GeneralThumbAdditional(thumb: icon, textInset: 35, thumbInset: 0), border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .accountRecord(_, viewType, info):
            return ShortPeerRowItem(initialSize, peer: info.peer, account: info.account, context: nil, height: 42, photoSize: NSMakeSize(28, 28), titleStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.text, highlightColor: theme.colors.underSelectedColor), borderType: [.Right], inset: NSEdgeInsets(left: 12, right: 12), viewType: viewType, action: {
                arguments.context.sharedContext.switchToAccount(id: info.account.id, action: nil)
            }, contextMenuItems: {
                
                var items:[ContextMenuItem] = []
                
                items.append(ContextMenuItem(strings().accountOpenInWindow, handler: {
                    arguments.context.sharedContext.openAccount(id: info.account.id)
                }, itemImage: MenuAnimation.menu_open_profile.value))
                
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().accountSettingsDeleteAccount, handler: {
                    confirm(for: arguments.context.window, information: strings().accountConfirmLogoutText, successHandler: { _ in
                        _ = logoutFromAccount(id: info.account.id, accountManager: arguments.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                    })
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                
                return .single(items)
            }, alwaysHighlight: true, badgeNode: GlobalBadgeNode(info.account, sharedContext: arguments.context.sharedContext, getColor: { _ in theme.colors.accent }, sync: true), compactText: true, highlightVerified: true)
        case let .addAccount(_, accounts, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsAddAccount, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accentIcon), type: .none, viewType: viewType, action: {
                arguments.addAccount(accounts)
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.account_add_account, textInset: 35, thumbInset: 0), border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .general(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsGeneral, icon: theme.icons.settingsGeneral, activeIcon: theme.icons.settingsGeneralActive, type: .next, viewType: viewType, action: {
                arguments.presentController(GeneralSettingsViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .proxy(_, viewType, status):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsProxy, icon: theme.icons.settingsProxy, activeIcon: theme.icons.settingsProxyActive, type: .nextContext(status ?? ""), viewType: viewType, action: {
                let controller = proxyListController(accountManager: arguments.context.sharedContext.accountManager, network: arguments.context.account.network, share: { servers in
                    var message: String = ""
                    for server in servers {
                        message += server.link + "\n\n"
                    }
                    message = message.trimmed
                    
                    showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: message)), for: arguments.context.window)
                }, pushController: { controller in
                     arguments.presentController(controller, false)
                })
                arguments.presentController(controller, true)

            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .stickers(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsStickersAndEmoji, icon: theme.icons.settingsStickers, activeIcon: theme.icons.settingsStickersActive, type: .next, viewType: viewType, action: {
                arguments.presentController(InstalledStickerPacksController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .notifications(_, viewType, status):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsNotifications, icon: theme.icons.settingsNotifications, activeIcon: theme.icons.settingsNotificationsActive, type: status == .denied ? .image(#imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed()) : .next, viewType: viewType, action: {
                arguments.presentController(NotificationPreferencesController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .language(_, viewType, current):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsLanguage, icon: theme.icons.settingsLanguage, activeIcon: theme.icons.settingsLanguageActive, type: .nextContext(current), viewType: viewType, action: {
                arguments.presentController(LanguageViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .appearance(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsTheme, icon: theme.icons.settingsAppearance, activeIcon: theme.icons.settingsAppearanceActive, type: .next, viewType: viewType, action: {
                arguments.presentController(AppAppearanceViewController(context: arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .privacy(_, viewType,  privacySettings, _):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsPrivacyAndSecurity, icon: theme.icons.settingsSecurity, activeIcon: theme.icons.settingsSecurityActive, type: .next, viewType: viewType, action: {
                 arguments.presentController(PrivacyAndSecurityViewController(arguments.context, initialSettings: privacySettings), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .dataAndStorage(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsDataAndStorage, icon: theme.icons.settingsStorage, activeIcon: theme.icons.settingsStorageActive, type: .next, viewType: viewType, action: {
                arguments.presentController(DataAndStorageViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .activeSessions(_, viewType, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsActiveSessions, icon: theme.icons.settingsSessions, activeIcon: theme.icons.settingsSessionsActive, type: .nextContext("\(count)"), viewType: viewType, action: {
                arguments.presentController(RecentSessionsController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case .about:
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .modern(position: .single, insets: .init()), text: APP_VERSION_STRING, font: .normal(.text), color: theme.colors.grayText)
        case let .passport(_, viewType, peer):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsPassport, icon: theme.icons.settingsPassport, activeIcon: theme.icons.settingsPassportActive, type: .next, viewType: viewType, action: {
                arguments.presentController(PassportController(arguments.context, peer.peer, request: nil, nil), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .premium(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsPremium, icon: theme.icons.settingsPremium, activeIcon: theme.icons.settingsPremium, type: .next, viewType: viewType, action: {
                arguments.openPremium()
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .faq(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsFAQ, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, viewType: viewType, action: arguments.openFaq, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .ask(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsAskQuestion, icon: theme.icons.settingsAskQuestion, activeIcon: theme.icons.settingsAskQuestionActive, type: .next, viewType: viewType, action: {
                confirm(for: arguments.context.window, information: strings().accountConfirmAskQuestion, thridTitle: strings().accountConfirmGoToFaq, successHandler: {  result in
                    switch result {
                    case .basic:
                        _ = showModalProgress(signal: arguments.context.engine.peers.supportPeerId(), for: arguments.context.window).start(next: {  peerId in
                            if let peerId = peerId {
                                arguments.presentController(ChatController(context: arguments.context, chatLocation: .peer(peerId)), true)
                            }
                        })
                    case .thrid:
                        arguments.openFaq()
                    }
                })
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .filters(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountSettingsFilters, icon: theme.icons.settingsFilters, activeIcon: theme.icons.settingsFiltersActive, type: .next, viewType: viewType, action: {
                arguments.presentController(ChatListFiltersListController(context: arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .update(_, viewType, state):
            
            var text: String = ""
            #if !APP_STORE
            if let state = state.any as? AppUpdateState {
                switch state.loadingState {
                case let .loading(_, current, total):
                    text = "\(Int(Float(current) / Float(total) * 100))%"
                case let .readyToInstall(item), let .unarchiving(item):
                    text = "\(item.displayVersionString!).\(item.versionString!)"
                case .uptodate:
                    text = "" //strings().accountViewControllerDescUpdated
                case .failed:
                    text = strings().accountViewControllerDescFailed
                default:
                    text = ""
                }
            }
            #endif
           
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().accountViewControllerUpdate, icon: theme.icons.settingsUpdate, activeIcon: theme.icons.settingsUpdateActive, type: .nextContext(text), viewType: viewType, action: {
                arguments.openUpdateApp()
            }, border:[BorderType.Right], inset:NSEdgeInsets(left: 12, right: 12))
        case let .whiteSpace(_, height):
            return GeneralRowItem(initialSize, height: height, stableId: stableId, border: [BorderType.Right], backgroundColor: .clear)
        }
    }
    
}


private func accountInfoEntries(peerView:PeerView, context: AccountContext, accounts: [AccountWithInfo], language: TelegramLocalization, privacySettings: AccountPrivacySettings?, webSessions: WebSessionsContextState, proxySettings: (ProxySettings, ConnectionStatus), passportVisible: Bool, appUpdateState: Any?, hasFilters: Bool, sessionsCount: Int, unAuthStatus: UNUserNotifications.AuthorizationStatus) -> [AccountInfoEntry] {
    var entries:[AccountInfoEntry] = []
    
    var index:Int = 0
        
    if let peer = peerViewMainPeer(peerView) as? TelegramUser {
        entries.append(.whiteSpace(index: index, height: 20))
        index += 1
        entries.append(.info(index: index, viewType: .singleItem, PeerEquatable(peer)))
        index += 1
        
//        entries.append(.whiteSpace(index: index, height: 20))
//        index += 1

       
    }
    
    if let peer = peerViewMainPeer(peerView), context.isPremium {
        entries.append(.setStatus(index: index, viewType: .singleItem, PeerEquatable(peer)))
        index += 1
    }
    
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
   
    
    if !context.isSupport {
        for account in accounts {
            if account.account.id != context.account.id {
                entries.append(.accountRecord(index: index, viewType: .singleItem, info: account))
                index += 1
            }
        }
    }
    
    let accountsLimit: Int = normalAccountsLimit
    let effectiveLimit: Int
    if context.premiumIsBlocked {
        effectiveLimit = accountsLimit
    } else {
        effectiveLimit = accountsLimit + 1
    }
//    let hasPremium = accounts.filter({ $0.peer.isPremium })
//    let normalCount = accounts.filter({ !$0.peer.isPremium }).count

    if accounts.count < effectiveLimit, !context.isSupport {
        entries.append(.addAccount(index: index, accounts, viewType: .singleItem))
        index += 1
    }
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    if !proxySettings.0.servers.isEmpty {
        let status: String
        switch proxySettings.1 {
        case .online:
            status = proxySettings.0.enabled ? strings().accountSettingsProxyConnected : strings().accountSettingsProxyDisabled
        default:
            status = proxySettings.0.enabled ? strings().accountSettingsProxyConnecting : strings().accountSettingsProxyDisabled
        }
        entries.append(.proxy(index: index, viewType: .singleItem, status: status))
        index += 1
        
        entries.append(.whiteSpace(index: index, height: 20))
        index += 1
    }
    
    entries.append(.general(index: index, viewType: .singleItem))
    index += 1
    entries.append(.notifications(index: index, viewType: .singleItem, status: unAuthStatus))
    index += 1
    entries.append(.privacy(index: index, viewType: .singleItem, privacySettings, webSessions))
    index += 1
    entries.append(.dataAndStorage(index: index, viewType: .singleItem))
    index += 1
    entries.append(.activeSessions(index: index, viewType: .singleItem, activeSessions: sessionsCount))
    index += 1
    entries.append(.appearance(index: index, viewType: .singleItem))
    index += 1
    entries.append(.language(index: index, viewType: .singleItem, current: language.localizedName))
    index += 1
    entries.append(.stickers(index: index, viewType: .singleItem))
    index += 1
    
    if hasFilters {
        entries.append(.filters(index: index, viewType: .singleItem))
        index += 1
    }
    
    if let state = appUpdateState, !context.isSupport {
        entries.append(.update(index: index, viewType: .singleItem, state: AnyUpdateStateEquatable(any: state)))
        index += 1
    }
   

    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    if let peer = peerViewMainPeer(peerView) as? TelegramUser, passportVisible {
        entries.append(.passport(index: index, viewType: .singleItem, peer: PeerEquatable(peer)))
        index += 1
        
        entries.append(.whiteSpace(index: index, height: 20))
        index += 1
    }
    
    if !context.premiumIsBlocked {
        entries.append(.premium(index: index, viewType: .singleItem))
        index += 1
        
        entries.append(.whiteSpace(index: index, height: 20))
        index += 1
    }
   

    entries.append(.faq(index: index, viewType: .singleItem))
    index += 1
    entries.append(.ask(index: index, viewType: .singleItem))
    index += 1
    
    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    
    entries.append(.about(index: index, viewType: .singleItem))
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
        return context.bindings.rootNavigation()
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
        guard context.layout != .minimisize else {
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
        let button = TextButtonBarView(controller: self, text: strings().navigationEdit, style: navigationButtonStyle, alignment:.Right)
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
        (rightBarView as? TextButtonBarView)?.set(text: strings().navigationEdit, for: .Normal)
        (rightBarView as? TextButtonBarView)?.set(color: theme.colors.accent, for: .Normal)
        (rightBarView as? TextButtonBarView)?.needsLayout = true
    }
    
    override func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return item is GeneralInteractedRowItem || item is AccountInfoItem || item is ShortPeerRowItem
    }
    
    override func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    private let settings: Promise<(AccountPrivacySettings?, WebSessionsContextState, (ProxySettings, ConnectionStatus), Bool)> = Promise()
    private let syncLocalizations = MetaDisposable()
    fileprivate let passportPromise: Promise<Bool> = Promise(false)
    fileprivate let hasFilters: Promise<Bool> = Promise(false)

    private weak var arguments: AccountInfoArguments?
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.border = [.Right]
        genericView.delegate = self
       // self.rightBarView.border = [.Right]
        let context = self.context
        //theme.colors.listBackground
        genericView.getBackgroundColor = {
            return .clear
        }
        
        let privacySettings = context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)
        
        settings.set(combineLatest(Signal<AccountPrivacySettings?, NoError>.single(nil) |> then(privacySettings), context.webSessions.state, proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { settings in
            return context.account.network.connectionStatus |> map {(settings, $0)}
        }, passportPromise.get()))
        
        
        syncLocalizations.set(context.engine.localization.synchronizedLocalizationListState().start())
        
        
        self.hasFilters.set(context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> map { view -> Bool in
            let configuration = ChatListFilteringConfiguration(appConfiguration: view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue)
            return configuration.isEnabled
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<AccountInfoEntry>]> = Atomic(value: [])
        
        
        let setStatus:(Control, TelegramUser)->Void = { control, peer in
            let callback:(TelegramMediaFile, Int32?, CGRect?)->Void = { file, timeout, fromRect in
                context.reactions.setStatus(file, peer: peer, timestamp: context.timestamp, timeout: timeout, fromRect: fromRect)
            }
            if control.popover == nil {
                showPopover(for: control, with: PremiumStatusController(context, callback: callback, peer: peer), edge: .maxY, inset: NSMakePoint(-80, -35), static: true, animationMode: .reveal)
            }
        }
        
        let arguments = AccountInfoArguments(context: context, presentController: { [weak self] controller, main in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            guard let singleLayout = self?.context.layout else {return}
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
        }, openPremium: {
            showModal(with: PremiumBoardingController(context: context), for: context.window)
        }, addAccount: { accounts in
            let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
            let hasPremium = accounts.contains(where: { $0.peer.isPremium })
            if accounts.count == normalAccountsLimit {
                if hasPremium {
                    context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
                } else {
                    showPremiumLimit(context: context, type: .accounts(accounts.count))
                }
            } else {
                context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
            }
        }, setStatus: { control, user in
            setStatus(control, user)
        }, runStatusPopover: { [weak self] in
            guard let item = self?.genericView.item(at: 1) as? AccountInfoItem else {
                return
            }
            if let control = item.statusControl {
                setStatus(control, item.peer)
            }
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

        
        let apply = combineLatest(queue: prepareQueue, context.account.viewTracker.peerView(context.account.peerId), context.sharedContext.activeAccountsWithInfo, appearanceSignal, settings.get(), appUpdateState, hasFilters.get(), sessionsCount, UNUserNotifications.recurrentAuthorizationStatus(context)) |> map { peerView, accounts, appearance, settings, appUpdateState, hasFilters, sessionsCount, unAuthStatus -> TableUpdateTransition in
            let entries = accountInfoEntries(peerView: peerView, context: context, accounts: accounts.accounts, language: appearance.language, privacySettings: settings.0, webSessions: settings.1, proxySettings: settings.2, passportVisible: settings.3, appUpdateState: appUpdateState, hasFilters: hasFilters, sessionsCount: sessionsCount, unAuthStatus: unAuthStatus).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
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
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(6))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PrivacyAndSecurityViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(8))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is LanguageViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(9))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is InstalledStickerPacksController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(10))) {
                    _ = genericView.select(item: item)
                }
                
            } else if navigation.controller is GeneralSettingsViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(3))) {
                    _ = genericView.select(item: item)
                }
            }  else if navigation.controller is RecentSessionsController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(7))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PassportController {
                if let item = genericView.item(stableId: AccountInfoEntryId.index(Int(14))) {
                    _ = genericView.select(item: item)
                }
            } else if let controller = navigation.controller as? InputDataController {
                switch true {
                case controller.identifier == "proxy":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(4))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "account":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(0))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "passport":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(14))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "app_update":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(12))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "filters":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(11))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "notification-settings":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(5))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "app_appearance":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(13))) {
                        _ = genericView.select(item: item)
                    }
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
        
        passportPromise.set(context.engine.auth.twoStepAuthData() |> map { value in
            return value.hasSecretValues
        } |> `catch` { error -> Signal<Bool, NoError> in
                return .single(false)
        })
        
        updateLocalizationAndTheme(theme: theme)
        
        
        context.window.set(handler: { [weak self] _ in
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
        
        
        let privacySettings = context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)

        settings.set(combineLatest(Signal<AccountPrivacySettings?, NoError>.single(nil) |> then(privacySettings), context.webSessions.state, proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { settings in
            return context.account.network.connectionStatus |> map {(settings, $0)}
        }, passportPromise.get()))
        

        syncLocalizations.set(context.engine.localization.synchronizedLocalizationListState().start())
        
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
        
        if let currentEvent = NSApp.currentEvent, currentEvent.clickCount == 5, !context.isSupport {
            context.bindings.rootNavigation().push(DeveloperViewController(context: context))
        }
        
        genericView.scroll(to: .up(true))
    }
    
    deinit {
        syncLocalizations.dispose()
        disposable.dispose()
    }

}

