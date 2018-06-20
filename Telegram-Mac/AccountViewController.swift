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
    let account: Account
    let accountManager: AccountManager
    let presentController:(ViewController, Bool) -> Void
    let openFaq:()->Void
    let ask:()->Void
    init(account: Account, accountManager: AccountManager, presentController:@escaping(ViewController, Bool)->Void, openFaq: @escaping()->Void, ask:@escaping()->Void) {
        self.account = account
        self.accountManager = accountManager
        self.presentController = presentController
        self.openFaq = openFaq
        self.ask = ask
    }
}

class AccountViewController: NavigationViewController {
    private var layoutController:LayoutAccountController
    init(_ account:Account, accountManager: AccountManager) {
        self.layoutController = LayoutAccountController(account, accountManager: accountManager)
        super.init(layoutController)
        layoutController.navigationController = self
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        navigationBar.frame = NSMakeRect(0, 0, bounds.width, layoutController.bar.height)
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



private enum AccountInfoEntry : TableItemListNodeEntry {
    case info(index:Int, TelegramUser)
    case proxy(index: Int, status: String?)
    case general(index: Int)
    case stickers(index: Int)
    case notifications(index: Int)
    case language(index: Int, current: String, languages:[LocalizationInfo]?)
    case appearance(index: Int)
    case privacy(index: Int, AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?, [Peer]?)
    case dataAndStorage(index: Int)
    case passport(index: Int, peer: Peer)
    case about(index: Int)
    case faq(index: Int)
    case ask(index: Int)
    case whiteSpace(index:Int, height:CGFloat)
    
    var stableId: Int {
        switch self {
        case .info:
            return 0
        case .general:
            return 2
        case .proxy:
            return 3
        case .notifications:
            return 4
        case .dataAndStorage:
            return 5
        case .privacy:
            return 6
        case .language:
            return 7
        case .stickers:
            return 8
        case .appearance:
            return 9
        case .passport:
            return 10
        case .about:
            return 11
        case .faq:
            return 12
        case .ask:
            return 13
        case let .whiteSpace(index, _):
            return 1000 + index
        }
    }
    
    var index:Int {
        switch self {
        case let .info(index, _):
            return index
        case let  .general(index):
            return index
        case let  .proxy(index, _):
            return index
        case let .stickers(index):
            return index
        case let .notifications(index):
            return index
        case let .language(index, _, _):
            return index
        case let .appearance(index):
            return index
        case let .privacy(index, _, _, _):
            return index
        case let .dataAndStorage(index):
            return index
        case let .about(index):
            return index
        case let .passport(index, _):
            return index
        case let .faq(index):
            return index
        case let .ask(index):
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
        case let .language(index, current, languages):
            if case .language(index, current, languages) = rhs {
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
        case let .privacy(lhsIndex, lhsPrivacy, lhsWebSessions, lhsBlockedPeers):
            if case let .privacy(rhsIndex, rhsPrivacy, rhsWebSessions, rhsBlockedPeers) = rhs {
                if let lhsWebSessions = lhsWebSessions, let rhsWebSessions = rhsWebSessions {
                    if lhsWebSessions.0 != rhsWebSessions.0 {
                        return false
                    }
                } else if (lhsWebSessions != nil) != (rhsWebSessions != nil) {
                    return false
                }
                if let lhsBlockedPeers = lhsBlockedPeers, let rhsBlockedPeers = rhsBlockedPeers {
                    if lhsBlockedPeers.count != rhsBlockedPeers.count {
                        return false
                    }
                    for i in 0 ..< lhsBlockedPeers.count {
                        if !lhsBlockedPeers[i].isEqual(rhsBlockedPeers[i]) {
                            return false
                        }
                    }
                } else if (lhsBlockedPeers != nil) != (rhsBlockedPeers != nil) {
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
            return AccountInfoItem(initialSize, stableId: stableId, account: arguments.account, peer: peer, action: {
                let first: Atomic<Bool> = Atomic(value: true)
                editAccountInfoController(account: arguments.account, accountManager: arguments.accountManager, f: { controller in
                    arguments.presentController(controller, first.swap(false))
                })
            })
        case .general:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsGeneral, icon: theme.icons.settingsGeneral, activeIcon: theme.icons.settingsGeneralActive, type: .next, action: {
                arguments.presentController(GeneralSettingsViewController(arguments.account), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .proxy(_, let status):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsProxy, icon: theme.icons.settingsProxy, activeIcon: theme.icons.settingsProxyActive, type: .nextContext(status ?? ""), action: {
                let first: Atomic<Bool> = Atomic(value: true)
                proxyListController(postbox: arguments.account.postbox, network: arguments.account.network, share: { servers in
                    var message: String = ""
                    for server in servers {
                        message += server.link + "\n\n"
                    }
                    message = message.trimmed
                    
                    showModal(with: ShareModalController(ShareLinkObject(arguments.account, link: message)), for: mainWindow)
                })( { controller in
                    arguments.presentController(controller, first.swap(false))
                })
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .stickers:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsStickers, icon: theme.icons.settingsStickers, activeIcon: theme.icons.settingsStickersActive, type: .next, action: {
                arguments.presentController(InstalledStickerPacksController(arguments.account), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .notifications:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsNotifications, icon: theme.icons.settingsNotifications, activeIcon: theme.icons.settingsNotificationsActive, type: .next, action: {
                arguments.presentController(NotificationSettingsViewController(arguments.account), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .language(_, _, languages):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsLanguage, icon: theme.icons.settingsLanguage, activeIcon: theme.icons.settingsLanguageActive, type: .nextContext(""), action: {
                arguments.presentController(LanguageViewController(arguments.account, languages: languages), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .appearance:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsTheme, icon: theme.icons.settingsAppearance, activeIcon: theme.icons.settingsAppearanceActive, type: .next, action: {
                arguments.presentController(AppearanceViewController(arguments.account), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .privacy(_, let privacySettings, let webSessions, let blockedPeers):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsPrivacyAndSecurity, icon: theme.icons.settingsSecurity, activeIcon: theme.icons.settingsSecurityActive, type: .next, action: {
                 arguments.presentController(PrivacyAndSecurityViewController(arguments.account, initialSettings: .single((privacySettings, webSessions, blockedPeers))), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .dataAndStorage:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsDataAndStorage, icon: theme.icons.settingsStorage, activeIcon: theme.icons.settingsStorageActive, type: .next, action: {
                arguments.presentController(DataAndStorageViewController(arguments.account), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .about:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsAbout, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, action: {
                showModal(with: AboutModalController(), for: mainWindow)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .passport(_, peer):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsPassport, icon: theme.icons.settingsPassport, activeIcon: theme.icons.settingsPassportActive, type: .next, action: {
                arguments.presentController(PassportController(arguments.account, peer, request: nil, nil), true)
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .faq:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsFAQ, icon: theme.icons.settingsFaq, activeIcon: theme.icons.settingsFaqActive, type: .next, action: {
                
                arguments.openFaq()
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case .ask:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.accountSettingsAskQuestion, icon: theme.icons.settingsAskQuestion, activeIcon: theme.icons.settingsAskQuestionActive, type: .next, action: {
                confirm(for: mainWindow, information: L10n.accountConfirmAskQuestion, thridTitle: L10n.accountConfirmGoToFaq, successHandler: {  result in
                    switch result {
                    case .basic:
                        _ = showModalProgress(signal: supportPeerId(account: arguments.account), for: mainWindow).start(next: {  peerId in
                            if let peerId = peerId {
                                arguments.presentController(ChatController(account: arguments.account, chatLocation: .peer(peerId)), true)
                            }
                        })
                    case .thrid:
                        arguments.openFaq()
                    }
                })
                
            }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
        case let .whiteSpace(_, height):
            return GeneralRowItem(initialSize, height: height, stableId: stableId, border:[BorderType.Right])
        }
    }
    
}


private func accountInfoEntries(peerView:PeerView, language: Language, privacySettings: AccountPrivacySettings?, webSessions: ([WebAuthorization], [PeerId : Peer])?, blockedPeers:[Peer]?, proxySettings: (ProxySettings, ConnectionStatus), languages: [LocalizationInfo]?, passportVisible: Bool) -> [AccountInfoEntry] {
    var entries:[AccountInfoEntry] = []
    
    var index:Int = 0
        
    if let peer = peerViewMainPeer(peerView) as? TelegramUser {
        entries.append(.info(index: index, peer))
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
    entries.append(.privacy(index: index, privacySettings, webSessions, blockedPeers))
    index += 1
    entries.append(.dataAndStorage(index: index))
    index += 1
    entries.append(.language(index: index, current: L10n.accountSettingsCurrentLanguage, languages: languages))
    index += 1
    entries.append(.stickers(index: index))
    index += 1
    entries.append(.appearance(index: index))
    index += 1
    
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

    
    return entries
}

private func prepareEntries(left: [AppearanceWrapperEntry<AccountInfoEntry>], right: [AppearanceWrapperEntry<AccountInfoEntry>], arguments: AccountInfoArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated)  = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class LayoutAccountController : TableViewController {
    private let accountManager:AccountManager
    private let disposable = MetaDisposable()
    
    var navigation:NavigationViewController? {
        return super.navigationController?.navigationController
    }
    
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: L10n.navigationEdit, style: navigationButtonStyle, alignment:.Right)
        let account = self.account
        let accountManager = self.accountManager
        button.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            let first: Atomic<Bool> = Atomic(value: true)
            editAccountInfoController(account: account, accountManager: accountManager, f: { [weak self] controller in
                self?.arguments?.presentController(controller, first.swap(false))
            })
        }, for: .Click)
        return button
    }
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        (rightBarView as? TextButtonBarView)?.set(text: L10n.navigationEdit, for: .Normal)
        (rightBarView as? TextButtonBarView)?.set(color: theme.colors.blueUI, for: .Normal)
        (rightBarView as? TextButtonBarView)?.needsLayout = true
    }
    
    override func selectionWillChange(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    override func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    private let settings: Promise<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?, (ProxySettings, ConnectionStatus), Bool)> = Promise()
    private let languages: Promise<[LocalizationInfo]?> = Promise()
    private let blockedPeers: Promise<[Peer]?> = Promise()
    private let passportPromise: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    private weak var arguments: AccountInfoArguments?
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.border = [.Right]
        genericView.delegate = self
        self.rightBarView.border = [.Right]
        let account = self.account
        
        let previous:Atomic<[AppearanceWrapperEntry<AccountInfoEntry>]> = Atomic(value: [])
        
        
        let arguments = AccountInfoArguments(account: account, accountManager: accountManager, presentController: { [weak self] controller, main in
            guard let navigation = self?.navigation as? MajorNavigationController else {return}
            guard let singleLayout = self?.account.context.layout else {return}
            if main {
                navigation.removeExceptMajor()
            }
            navigation.push(controller, !main || singleLayout == .single)
        }, openFaq: {
            openFaq(account: account)
        }, ask: {
            
        })
        
        self.arguments = arguments
        
        let atomicSize = self.atomicSize
        

        
        let apply = combineLatest(account.viewTracker.peerView( account.peerId) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, settings.get() |> deliverOnPrepareQueue, languages.get() |> deliverOnPrepareQueue, blockedPeers.get() |> deliverOnPrepareQueue) |> map { peerView, appearance, settings, languages, blockedPeers -> TableUpdateTransition in
            let entries = accountInfoEntries(peerView: peerView, language: appearance.language, privacySettings: settings.0, webSessions: settings.1, blockedPeers: blockedPeers, proxySettings: settings.2, languages: languages, passportVisible: settings.3).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            var size = atomicSize.modify {$0}
            size.width = max(size.width, 280)
            return prepareEntries(left: previous.swap(entries), right: entries, arguments: arguments, initialSize: size)
        } |> deliverOnMainQueue
        
        disposable.set(apply.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.navigationWillChangeController()
            self?.readyOnce()
        }))
    }
    
    
    
    
    override func navigationWillChangeController() {
        if let navigation = navigation as? ExMajorNavigationController {
            if navigation.controller is DataAndStorageViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.dataAndStorage(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is AppearanceViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.appearance(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is NotificationSettingsViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.notifications(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PrivacyAndSecurityViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.privacy(index: 0, nil, nil, nil).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is LanguageViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.language(index: 0, current: "", languages: nil).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is InstalledStickerPacksController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.stickers(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is GeneralSettingsViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.general(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PassportController {
                if let item = genericView.item(stableId: AnyHashable(Int(10))) {
                    _ = genericView.select(item: item)
                }
            } else if let controller = navigation.controller as? InputDataController {
                switch true {
                case controller.identifier == "proxy":
                    if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.proxy(index: 0, status: nil).stableId)) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "account":
                    if let item = genericView.item(stableId: AnyHashable(Int(0))) {
                        _ = genericView.select(item: item)
                    }
                case controller.identifier == "passport":
                    if let item = genericView.item(stableId: AnyHashable(Int(10))) {
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
        updateLocalizationAndTheme()
        
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.passportPromise.set(true)
            return .invoked
        }, with: self, for: .P, modifierFlags: [.command])
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.remove(object: self, for: .P)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let account = self.account
        
        settings.set(combineLatest(Signal<AccountPrivacySettings?, Void>.single(nil) |> then(requestAccountPrivacySettings(account: account) |> map {Optional($0)}), Signal<([WebAuthorization], [PeerId : Peer])?, Void>.single(nil) |> then(webSessions(network: account.network) |> map {Optional($0)}), proxySettingsSignal(account.postbox) |> mapToSignal { settings in
            return account.network.connectionStatus |> map {(settings, $0)}
        }, passportPromise.get()))
        languages.set(Signal<[LocalizationInfo]?, Void>.single(nil) |> deliverOnPrepareQueue |> then(availableLocalizations(postbox: account.postbox, network: account.network, allowCached: true) |> map {Optional($0)} |> deliverOnPrepareQueue))
        blockedPeers.set(Signal<[Peer]?, Void>.single(nil) |> deliverOnPrepareQueue |> then(requestBlockedPeers(account: account) |> map {Optional($0)} |> deliverOnPrepareQueue))
    }
    
    override func getLeftBarViewOnce() -> BarView {
        return BarView(controller: self)
    }
    
    init(_ account:Account, accountManager:AccountManager) {
        self.accountManager = accountManager
        super.init(account)
    }
    

    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        navigationController?.updateLocalizationAndTheme()
    }

    
    override func scrollup() {
        if let currentEvent = NSApp.currentEvent, currentEvent.clickCount == 5 {
            account.context.mainNavigation?.push(DeveloperViewController(account, accountManager))
        }
        
        genericView.scroll(to: .up(true))
    }
    
    deinit {
        disposable.dispose()
    }

}

