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


class AccountViewController: NavigationViewController {
    private var layoutController:LayoutAccountController
    init(_ account:Account, accountManager: AccountManager) {
        self.layoutController = LayoutAccountController(account, accountManager: accountManager)
        super.init(layoutController)
        layoutController.navigationController = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layoutController.viewWillAppear(animated)
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



enum AccountInfoEntry : Comparable, Identifiable {
    case info(index:Int, AccountInfoItemState, TelegramUser, ConnectionStatus)
    case updatePhoto(index: Int)
    case general(index: Int)
    case stickers(index: Int)
    case notifications(index: Int)
    case username(index: Int, username: String)
    case bio(index: Int, about: String)
    case language(index: Int, current: String)
    case appearance(index: Int)
    case phone(index: Int, phone: String)
    case privacy(index: Int)
    case dataAndStorage(index: Int)
    case accounts(index: Int)
    case about(index: Int)
    case faq(index: Int)
    case ask(index: Int)
    case logout(index: Int)
    case whiteSpace(index:Int, height:CGFloat)
    
    var stableId: Int {
        switch self {
        case .info:
            return 0
        case .updatePhoto:
            return 1
        case .username:
            return 2
        case .bio:
            return 3
        case .phone:
            return 4
        case .general:
            return 5
        case .notifications:
            return 6
        case .dataAndStorage:
            return 7
        case .privacy:
            return 8
        case .language:
            return 9
        case .stickers:
            return 10
        case .appearance:
            return 11
        case .accounts:
            return 12
        case .about:
            return 13
        case .faq:
            return 14
        case .ask:
            return 15
        case .logout:
            return 16
        case let .whiteSpace(index, _):
            return 1000 + index
        }
    }
    
    var index:Int {
        switch self {
        case let .info(index, _, _, _):
            return index
        case let .updatePhoto(index):
            return index
        case let  .general(index):
            return index
        case let .stickers(index):
            return index
        case let .notifications(index):
            return index
        case let  .username(index, _):
            return index
        case let .bio(index, _):
            return index
        case let .language(index, _):
            return index
        case let .appearance(index):
            return index
        case let .phone(index, _):
            return index
        case let .privacy(index):
            return index
        case let .dataAndStorage(index):
            return index
        case let .accounts(index):
            return index
        case let .about(index):
            return index
        case let .faq(index):
            return index
        case let .ask(index):
            return index
        case let .logout(index):
            return index
        case let .whiteSpace(index, _):
            return index
        }
    }
    
    static func ==(lhs:AccountInfoEntry, rhs:AccountInfoEntry) -> Bool {
        switch lhs {
        case let .info(lhsIndex, lhsState, lhsPeer, lhsConnectionState):
            if case let .info(rhsIndex, rhsState, rhsPeer, rhsConnectionState) = rhs {
                return lhsIndex == rhsIndex && lhsState == rhsState && lhsIndex == rhsIndex && lhsConnectionState == rhsConnectionState && lhsPeer.isEqual(rhsPeer)
            } else {
                return false
            }
        case let .updatePhoto(lhsIndex):
            if case let .updatePhoto(rhsIndex) = rhs {
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
        case let .notifications(lhsIndex):
            if case let .notifications(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .username(lhsIndex, lhsUsername):
            if case let .username(rhsIndex, rhsUsername) = rhs {
                return lhsIndex == rhsIndex && lhsUsername == rhsUsername
            } else {
                return false
            }
        case let .bio(lhsIndex, lhsAbout):
            if case let .bio(rhsIndex, rhsAbout) = rhs {
                return lhsIndex == rhsIndex && lhsAbout == rhsAbout
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
        case let .phone(lhsIndex, lhsPhone):
            if case let .phone(rhsIndex, rhsPhone) = rhs {
                return lhsIndex == rhsIndex && lhsPhone == rhsPhone
            } else {
                return false
            }
        case let .privacy(lhsIndex):
            if case let .privacy(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .dataAndStorage(lhsIndex):
            if case let .dataAndStorage(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .accounts(lhsIndex):
            if case let .accounts(rhsIndex) = rhs {
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
        case let .logout(lhsIndex):
            if case let .logout(rhsIndex) = rhs {
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
    
}




class LayoutAccountController : EditableViewController<TableView>, TableViewDelegate {
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        
    }
    
    func selectionWillChange(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return row > 0
    }

    private let accountManager:AccountManager
    private let peer = Promise<TelegramUser?>()
    private let statePromise:ValuePromise<ViewControllerState> = ValuePromise(ignoreRepeated: true)
    private let connectionPromise = Promise<ConnectionStatus>(.online)
    private let entries:Atomic<[AppearanceWrapperEntry<AccountInfoEntry>]?> = Atomic(value: nil)
    private let disposable = MetaDisposable()
    private let updatePhotoDisposable = MetaDisposable()
    
    var navigation:NavigationViewController? {
        return super.navigationController?.navigationController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.border = [.Right]
        genericView.delegate = self
        self.rightBarView.border = [.Right]
        readyOnce()
        
    }
    
    private var editButton:ImageButton? = nil
    private var doneButton:TitleButton? = nil
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        editButton?.style = navigationButtonStyle
        editButton?.set(image: theme.icons.chatActions, for: .Normal)
        editButton?.set(image: theme.icons.chatActionsActive, for: .Highlight)
        
        editButton?.setFrameSize(68, 50)
        editButton?.center()
        doneButton?.set(color: theme.colors.blueUI, for: .Normal)
        doneButton?.style = navigationButtonStyle
    }
    
    override func getRightBarViewOnce() -> BarView {
        let back = BarView(70, controller: self)
        back.border = [.Right]
        let editButton = ImageButton()
        editButton.disableActions()
        back.addSubview(editButton)
        
        self.editButton = editButton
        let doneButton = TitleButton()
        doneButton.disableActions()
        doneButton.set(font: .medium(.text), for: .Normal)
        doneButton.set(text: tr(.navigationDone), for: .Normal)
        doneButton.sizeToFit()
        back.addSubview(doneButton)
        doneButton.center()
        
        self.doneButton = doneButton
        
        
        doneButton.isHidden = true
        
        
        editButton.set(handler: { [weak self] control in
            
            if !hasPopover(mainWindow), let strongSelf = self {
                var items: [SPopoverItem] = []
                items.append(SPopoverItem(tr(.accountSettingsAbout), {
                    showModal(with: AboutModalController(), for: mainWindow)
                }, theme.icons.settingsAbout))
                items.append(SPopoverItem(tr(.accountSettingsLogout), { [weak strongSelf] in
                    confirm(for: mainWindow, with: tr(.accountConfirmLogout), and: tr(.accountConfirmLogoutText), successHandler: {_ in 
                        if let strongSelf = strongSelf {
                            let _ = logoutFromAccount(id: strongSelf.account.id, accountManager: strongSelf.accountManager).start()
                        }
                    })
                    
                }, theme.icons.settingsLogout, theme.colors.redUI))
                showPopover(for: control, with: SPopoverViewController(items: items), edge: .maxY, inset: NSMakePoint(-60, -50))
            }
           

        }, for: .Hover)
        
        doneButton.set(handler: { [weak self] _ in
            self?.changeState()
        }, for: .Click)
        
        requestUpdateRightBar()
        return back
    }

    
    override func navigationWillChangeController() {
        if let navigation = navigation as? ExMajorNavigationController {
            if navigation.controller is StorageUsageController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.dataAndStorage(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is NotificationSettingsViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.notifications(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is PrivacyAndSecurityViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.privacy(index: 0).stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is LanguageViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.language(index: 0, current: "").stableId)) {
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
            } else if navigation.controller is UsernameSettingsViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.username(index: 0, username: "").stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if navigation.controller is BioViewController {
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.bio(index: 0, about: "").stableId)) {
                    _ = genericView.select(item: item)
                }
            } else if PhoneNumberIntroController.assciatedControllerTypes.contains(where: {navigation.controller.isKind(of: $0)}) {
                
                if let item = genericView.item(stableId: AnyHashable(AccountInfoEntry.phone(index: 0, phone: "").stableId)) {
                    _ = genericView.select(item: item)
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let apply = combineLatest(account.viewTracker.peerView( account.peerId), connectionPromise.get(), statePromise.get(), appearanceSignal) |> deliverOn(Queue.mainQueue()) |> map { [weak self] peerView, connection, state, appearance -> TableUpdateTransition in
            
            if let strongSelf = self {
                let entries = strongSelf.entries(for: state, account: strongSelf.account, connection: connection, peerView: peerView, language: appearance.language).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                let previous = strongSelf.entries.swap(entries)
                return strongSelf.prepareEntries(left: previous, right: entries, account: strongSelf.account, accountManager: strongSelf.accountManager, animated: true, atomicSize: strongSelf.atomicSize.modify({$0}))
            }
            return TableUpdateTransition(deleted: [], inserted: [], updated: [])
            
        }
        
        disposable.set(apply.start(next: { [weak self] transition in

            self?.genericView.merge(with: transition)
            self?.navigationWillChangeController()
        }))
        
        
        peer.set(account.viewTracker.peerView(account.peerId) |> map { peerView -> TelegramUser? in
            return peerView.peers[peerView.peerId] as? TelegramUser
        })
        
        connectionPromise.set(account.network.connectionStatus)
        statePromise.set(.Normal)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disposable.set(nil)
    }
    
    
    override func update(with state: ViewControllerState) {
        if state == .Normal {
            saveNamesIfNeeded(false)
        }
        super.update(with: state)
        statePromise.set(state)
        
        editButton?.isHidden = state == .Edit
        doneButton?.isHidden = state == .Normal
        
        switch state {
        case .Normal:
            window?.removeObserver(for: self)
        case .Edit:
            window?.set(responder: { [weak self] () -> NSResponder? in
                if let view = self?.genericView.viewNecessary(at: 0) as? AccountInfoView {
                    return view.firstResponder
                }
                return nil
            }, with: self, priority: .high)
        default:
            break
        }
    }
    
    override func getLeftBarViewOnce() -> BarView {
        return BarView(controller: self)
    }
    
    init(_ account:Account, accountManager:AccountManager) {
        self.accountManager = accountManager
        super.init(account)
    }
    
    func entries(for state:ViewControllerState, account:Account, connection:ConnectionStatus, peerView:PeerView, language: Language) -> [AccountInfoEntry] {
        var entries:[AccountInfoEntry] = []
        
        var index:Int = 0
        
        let user = peerViewMainPeer(peerView) as? TelegramUser
        
        if let peer = peerViewMainPeer(peerView) as? TelegramUser {
            entries.append(.info(index: index, state == .Edit ? .edit : .normal, peer, connection))
            index += 1
        }
        
        
        
        entries.append(.username(index: index, username: peerViewMainPeer(peerView)?.addressName ?? ""))
        index += 1
        
        let cachedData = peerView.cachedData as? CachedUserData
        entries.append(.bio(index: index, about: cachedData?.about ?? ""))
        index += 1
        
        entries.append(.phone(index: index, phone: user?.phone ?? ""))
        index += 1
        
        entries.append(.whiteSpace(index: index, height: 30))
        index += 1
        
        entries.append(.general(index: index))
        index += 1
        entries.append(.notifications(index: index))
        index += 1
        entries.append(.dataAndStorage(index: index))
        index += 1
        entries.append(.privacy(index: index))
        index += 1
        entries.append(.language(index: index, current: tr(.accountSettingsCurrentLanguage)))
        index += 1

        entries.append(.stickers(index: index))
        index += 1

      
        

//        entries.append(.accounts(index: index))
//        index += 1
        entries.append(.whiteSpace(index: index, height: 30))
        index += 1
      //  entries.append(.about(index: index))
      //  index += 1
        entries.append(.faq(index: index))
        index += 1
        entries.append(.ask(index: index))
        
        if state == .Edit {
            index += 1
            entries.append(.whiteSpace(index: index, height: 20))
            index += 1
            entries.append(.logout(index: index))
        }
        
        return entries
    }
    
    func saveNamesIfNeeded(_ cState:Bool = true) -> Void {
        if let item = genericView.item(at: 0) as? AccountInfoItem {
            if item.firstName != (item.peer.firstName ?? "") || item.lastName != (item.peer.lastName ?? "") {
                _ = showModalProgress(signal: updateAccountPeerName(account: account, firstName: item.firstName, lastName: item.lastName), for: mainWindow).start()
            }
            if cState {
                changeState()
            }
        }
    }
    
    fileprivate func prepareEntries(left:[AppearanceWrapperEntry<AccountInfoEntry>]?, right:[AppearanceWrapperEntry<AccountInfoEntry>], account:Account, accountManager: AccountManager, animated:Bool, atomicSize:NSSize) -> TableUpdateTransition {
        let atomicSize = NSMakeSize(max(280, atomicSize.width), atomicSize.height)
        let (deleted,inserted,updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
            switch entry.entry {
            case let .info(_, state, peer, connection):
                return AccountInfoItem(atomicSize, stableId: entry.stableId, account: account, peer: peer, state: state, connectionStatus: connection, saveCallback: { [weak self] in
                    self?.saveNamesIfNeeded()
                }, editCallback: { [weak self] in
                    self?.changeState()
                }, imageCallback: { [weak self] in
                    if let strongSelf = self {
                        pickImage(for: mainWindow, completion:{ [weak strongSelf] image in
                            if let image = image {
                                strongSelf?.startUpdatePhoto(image, account: account)
                            }
                        })
                    }
                    
                })
            case  .updatePhoto:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsSetProfilePhoto), nameStyle: blueActionButton, type: .none, action: {}, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case  .general:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsGeneral), icon: theme.icons.settingsGeneral, type: .none, action: {[weak self] in
                    if !(self?.navigation?.controller is GeneralSettingsViewController) {
                        self?.navigation?.push(GeneralSettingsViewController(account))
                    }
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .stickers:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsStickers), icon: theme.icons.settingsStickers, type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is InstalledStickerPacksController) {
                        self?.navigation?.push(InstalledStickerPacksController(account))
                    }
                }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .notifications:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsNotifications), icon: theme.icons.settingsNotifications, type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is NotificationSettingsViewController) {
                        self?.navigation?.push(NotificationSettingsViewController(account))
                    }
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case let .username(_, username):
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: username.isEmpty ? tr(.accountSettingsSetUsername) : username, icon: theme.icons.settingsUsername, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: username.isEmpty ? theme.colors.blueUI : theme.colors.text), type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is UsernameSettingsViewController) {
                        self?.navigation?.push(UsernameSettingsViewController(account))
                    }
                }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .bio(_, let about):
                
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: about.isEmpty ? tr(.accountSettingsSetBio) : about, icon: theme.icons.settingsBio, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: about.isEmpty ? theme.colors.blueUI : theme.colors.text), type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is BioViewController) {
                        self?.navigation?.push(BioViewController(account))
                    }
                }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case let  .phone(_, phone):
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: formatPhoneNumber(phone), icon: theme.icons.settingsPhoneNumber, type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is PhoneNumberIntroController) {
                        self?.navigation?.push(PhoneNumberIntroController(account))
                    }
                }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case let .language(_, current):
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsLanguage), icon: theme.icons.settingsLanguage, type: .context(stateback: {
                    return current
                }), action: { [weak self] in
                    if !(self?.navigation?.controller is LanguageViewController) {
                        self?.navigation?.push(LanguageViewController(account))
                    }
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .appearance:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsAppearance), type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is AppearanceViewController) {
                        self?.navigation?.push(AppearanceViewController(account))
                    }
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .privacy:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsPrivacyAndSecurity), icon: theme.icons.settingsSecurity, type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is PrivacyAndSecurityViewController) {
                        self?.navigation?.push(PrivacyAndSecurityViewController(account, initialSettings: .single(nil) |> then(requestAccountPrivacySettings(account: account) |> map { Optional($0) })))
                    }
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .dataAndStorage:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsStorage), icon: theme.icons.settingsStorage, type: .none, action: { [weak self] in
                    if !(self?.navigation?.controller is StorageUsageController) {
                        self?.navigation?.push(StorageUsageController(account))
                    }
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .accounts:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: "tr(.accountSettingsAccounts)", type: .none, action: { [weak self] in
                    self?.navigation?.push(AccountsListViewController(account, accountManager: accountManager))
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .about:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsAbout), icon: theme.icons.settingsFaq, type: .none, action: { [weak self] in
                    if let window = self?.window {
                        showModal(with: AboutModalController(), for: window)
                    }
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .faq:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsFAQ), icon: theme.icons.settingsFaq, type: .none, action: { [weak self] in
                    
                    self?.openFaq()
                    
                }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .ask:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsAskQuestion), icon: theme.icons.settingsAskQuestion, type: .none, action: { [weak self] in
                    
                    confirm(for: mainWindow, with: appName, and: tr(.accountConfirmAskQuestion), thridTitle: tr(.accountConfirmGoToFaq), successHandler: { [weak self] result in
                        switch result {
                        case .basic:
                            _ = showModalProgress(signal: supportPeerId(account: account), for: mainWindow).start(next: { [weak self] peerId in
                                if let peerId = peerId {
                                    self?.navigation?.push(ChatController(account: account, peerId: peerId))
                                }
                            })
                        case .thrid:
                            self?.openFaq()
                        }
                    })
                    
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case .logout:
                return GeneralInteractedRowItem(atomicSize, stableId: entry.stableId, name: tr(.accountSettingsLogout), nameStyle: redActionButton, type: .none, action: { [weak self] in
                    
                    confirm(for: mainWindow, with: tr(.accountConfirmLogout), and: tr(.accountConfirmLogoutText), successHandler: { [weak self] _ in
                        if let strongSelf = self {
                            let _ = logoutFromAccount(id: strongSelf.account.id, accountManager: strongSelf.accountManager).start()
                        }
                    })
                    
                    
                    
                    }, border:[BorderType.Right], inset:NSEdgeInsets(left:16))
            case let .whiteSpace(_, height):
                return GeneralRowItem(atomicSize, height: height, stableId: entry.stableId, border:[BorderType.Right])
            }
        })
        
        return TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated)
    }
    
    private func openFaq() {
        let account = self.account
        let language = appCurrentLanguage.languageCode[appCurrentLanguage.languageCode.index(appCurrentLanguage.languageCode.endIndex, offsetBy: -2) ..< appCurrentLanguage.languageCode.endIndex]
        
        _ = showModalProgress(signal: webpagePreview(account: account, url: "https://telegram.org/faq/" + language) |> deliverOnMainQueue, for: mainWindow).start(next: { webpage in
            if let webpage = webpage {
                showInstantPage(InstantPageViewController(account, webPage: webpage, message: nil))
            } else {
                execute(inapp: .external(link: "https://telegram.org/faq/" + language, true))
            }
        })
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        navigationController?.updateLocalizationAndTheme()
    }
    
    func startUpdatePhoto(_ image: NSImage, account:Account) {
        
        updatePhotoDisposable.set((putToTemp(image: image) |> mapToSignal { path -> Signal<Void, Void> in
            return updatePeerPhoto(account: account, peerId: account.peerId, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64()))
                |> mapError {_ in} |> map {_ in}
        }).start())
    }
    
    deinit {
        disposable.dispose()
        updatePhotoDisposable.dispose()
    }

}

