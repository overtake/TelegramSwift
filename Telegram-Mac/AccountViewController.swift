//
//  AccountViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac



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
    
    override func scrollup() {
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
    case passport(index: Int, peer: Peer)
    case update(index: Int, state: Any)
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
        case .privacy:
            return .index(6)
        case .language:
            return .index(7)
        case .stickers:
            return .index(8)
        case .update:
            return .index(9)
        case .appearance:
            return .index(10)
        case .passport:
            return .index(11)
        case .readArticles:
            return .index(12)
        case .about:
            return .index(13)
        case .faq:
            return .index(14)
        case .ask:
            return .index(15)
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
        case let .about(index):
            return index
        case let .passport(index, _):
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
                return [ContextMenuItem(L10n.accountSettingsDeleteAccount, handler: {
                    confirm(for: arguments.context.window, information: L10n.accountConfirmLogoutText, successHandler: { _ in
                        _ = logoutFromAccount(id: info.account.id, accountManager: arguments.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                    })
                })]
            }, alwaysHighlight: true, badgeNode: GlobalBadgeNode(info.account, sharedContext: arguments.context.sharedContext, getColor: { _ in theme.colors.accent }), compactText: true)
        case .addAccount:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsAddAccount, icon: theme.icons.peerInfoAddMember, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.blueIcon), type: .none, action: {
                let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
                arguments.context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
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
                arguments.presentController(AppearanceViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .privacy(_,  privacySettings, webSessions):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsPrivacyAndSecurity, icon: theme.icons.settingsSecurity, activeIcon: theme.icons.settingsSecurityActive, type: .next, action: {
                 arguments.presentController(PrivacyAndSecurityViewController(arguments.context, initialSettings: (privacySettings, webSessions)), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .dataAndStorage:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsDataAndStorage, icon: theme.icons.settingsStorage, activeIcon: theme.icons.settingsStorageActive, type: .next, action: {
                arguments.presentController(DataAndStorageViewController(arguments.context), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .about:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsAbout, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, action: {
                showModal(with: AboutModalController(), for: mainWindow)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .passport(_, peer):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsPassport, icon: theme.icons.settingsPassport, activeIcon: theme.icons.settingsPassportActive, type: .next, action: {
                arguments.presentController(PassportController(arguments.context, peer, request: nil, nil), true)
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


private func accountInfoEntries(peerView:PeerView, accounts: [AccountWithInfo], language: TelegramLocalization, privacySettings: AccountPrivacySettings?, webSessions: ([WebAuthorization], [PeerId : Peer])?, proxySettings: (ProxySettings, ConnectionStatus), passportVisible: Bool, appUpdateState: Any?) -> [AccountInfoEntry] {
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
    entries.append(.appearance(index: index))
    index += 1
    entries.append(.language(index: index, current: language.localizedName))
    index += 1
    entries.append(.stickers(index: index))
    index += 1
    
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
    


    entries.append(.whiteSpace(index: index, height: 20))
    index += 1
    entries.append(.faq(index: index))
    index += 1
    entries.append(.ask(index: index))
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
    
    var navigation:NavigationViewController? {
        return context.sharedContext.bindings.rootNavigation()
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
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
    private weak var arguments: AccountInfoArguments?
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.border = [.Right]
        genericView.delegate = self
        self.rightBarView.border = [.Right]
        let context = self.context
        
        let previous:Atomic<[AppearanceWrapperEntry<AccountInfoEntry>]> = Atomic(value: [])
        
        
        let arguments = AccountInfoArguments(context: context, presentController: { [weak self] controller, main in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            guard let singleLayout = self?.context.sharedContext.layout else {return}
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
        
        
        let apply = combineLatest(queue: queue, context.account.viewTracker.peerView(context.account.peerId), context.sharedContext.activeAccountsWithInfo, appearanceSignal, settings.get(), appUpdateState) |> map { peerView, accounts, appearance, settings, appUpdateState -> TableUpdateTransition in
            let entries = accountInfoEntries(peerView: peerView, accounts: accounts.accounts, language: appearance.language, privacySettings: settings.0, webSessions: settings.1, proxySettings: settings.2, passportVisible: settings.3, appUpdateState: appUpdateState).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
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
            } else if navigation.controller is AppearanceViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(10))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PrivacyAndSecurityViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(6))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is LanguageViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(7))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is InstalledStickerPacksController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(8))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is GeneralSettingsViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(2))) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PassportController {
                if let item = genericView.item(stableId: AccountInfoEntryId.index(Int(11))) {
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
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(11))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "app_update":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(9))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "notification-settings":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntryId.index(4))) {
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
        
        passportPromise.set(twoStepAuthData(context.account.network) |> map { value in
            return value.hasSecretValues
        } |> `catch` { error -> Signal<Bool, NoError> in
                return .single(false)
        })
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.remove(object: self, for: .P)
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
        return BarView(68, controller: self)
    }
    
    override init(_ context: AccountContext) {
        super.init(context)
    }
    

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        navigationController?.updateLocalizationAndTheme(theme: theme)
    }

    
    override func scrollup() {
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

