//
//  SharedAccountContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

private struct AccountAttributes: Equatable {
    let sortIndex: Int32
    let isTestingEnvironment: Bool
    let backupData: AccountBackupData?
}


private enum AddedAccountsResult {
    case upgrading(Float)
    case ready([(AccountRecordId, Account?, Int32)])
}
private enum AddedAccountResult {
    case upgrading(Float)
    case ready(AccountRecordId, Account?, Int32)
}




public final class AccountWithInfo: Equatable {
    public let account: Account
    public let peer: Peer
    
    init(account: Account, peer: Peer) {
        self.account = account
        self.peer = peer
    }
    
    public static func ==(lhs: AccountWithInfo, rhs: AccountWithInfo) -> Bool {
        if lhs.account !== rhs.account {
            return false
        }
        if !arePeersEqual(lhs.peer, rhs.peer) {
            return false
        }
        return true
    }
}



class SharedAccountContext {
    let accountManager: AccountManager
    var bindings: AccountContextBindings = AccountContextBindings()

    #if !SHARE
    let inputSource: InputSources = InputSources()
    
    private let _baseSettings: Atomic<BaseApplicationSettings> = Atomic(value: BaseApplicationSettings.defaultSettings)
    
    var baseSettings: BaseApplicationSettings {
        return _baseSettings.with { $0 }
    }
    #endif
   
    private let managedAccountDisposables = DisposableDict<AccountRecordId>()
    
    
    private var activeAccountsValue: (primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?)?
    private let activeAccountsPromise = Promise<(primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?)>()
    var activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?), NoError> {
        return self.activeAccountsPromise.get()
    }
    private var activeAccountsInfoValue:(primary: AccountRecordId?, accounts: [AccountWithInfo])?
    private let activeAccountsWithInfoPromise = Promise<(primary: AccountRecordId?, accounts: [AccountWithInfo])>()
    var activeAccountsWithInfo: Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> {
        return self.activeAccountsWithInfoPromise.get()
    }

    private var accountPhotos: [PeerId : CGImage] = [:]
    private var cleaningUpAccounts = false
    
    private(set) var layout:SplitViewState = .none
    let layoutHandler:ValuePromise<SplitViewState> = ValuePromise(ignoreRepeated:true)

    private var statusItem: NSStatusItem?

    
    func updateStatusBarImage(_ image: NSImage?) -> Void {
        let icon = image ?? NSImage(named: "StatusIcon")
      //  icon?.isTemplate = true
        statusItem?.image = icon
    }
    
    private func updateStatusBarMenuItem() {
        let menu = NSMenu()
        
        if let activeAccountsInfoValue = activeAccountsInfoValue, activeAccountsInfoValue.accounts.count > 1 {
            var activeAccountsInfoValue = activeAccountsInfoValue
            for (i, value) in activeAccountsInfoValue.accounts.enumerated() {
                if value.account.id == activeAccountsInfoValue.primary {
                    activeAccountsInfoValue.accounts.swapAt(i, 0)
                    break
                }
            }
            for account in activeAccountsInfoValue.accounts {
                let state: NSControl.StateValue?
                if account.account.id == activeAccountsInfoValue.primary {
                    state = .on
                } else {
                    state = nil
                }
                let image: NSImage?
                if let cgImage = self.accountPhotos[account.account.peerId] {
                    image = NSImage(cgImage: cgImage, size: NSMakeSize(16, 16))
                } else {
                    image = nil
                }
                
                menu.addItem(ContextMenuItem(account.peer.displayTitle, handler: {
                    self.switchToAccount(id: account.account.id, action: nil)
                }, image: image, state: state))
                
                if account.account.id == activeAccountsInfoValue.primary {
                    menu.addItem(ContextSeparatorItem())
                }
            }
            
            
            menu.addItem(ContextSeparatorItem())
        }
        
        menu.addItem(ContextMenuItem(L10n.statusBarActivate, handler: {
            if !mainWindow.isKeyWindow  {
                NSApp.activate(ignoringOtherApps: true)
                mainWindow.deminiaturize(nil)
            } else {
                NSApp.hide(nil)
            }
            
        }, dynamicTitle: {
            return !mainWindow.isKeyWindow ? L10n.statusBarActivate : L10n.statusBarHide
        }))
                
        menu.addItem(ContextMenuItem(L10n.statusBarQuit, handler: {
            NSApp.terminate(nil)
        }))
        
        statusItem?.menu = menu
    }
    
    private func updateStatusBar(_ show: Bool) {
        if show {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            }
        } else {
            if let statusItem = statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }

    private let layoutDisposable = MetaDisposable()
    private let displayUpgradeProgress: (Float?) -> Void
    

    
    init(accountManager: AccountManager, networkArguments: NetworkInitializationArguments, rootPath: String, encryptionParameters: ValueBoxEncryptionParameters, displayUpgradeProgress: @escaping(Float?) -> Void) {
        self.accountManager = accountManager
        self.displayUpgradeProgress = displayUpgradeProgress
        #if !SHARE
        self.accountManager.mediaBox.fetchCachedResourceRepresentation = { (resource, representation) -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return fetchCachedSharedResourceRepresentation(accountManager: accountManager, resource: resource, representation: representation)
        }
        _ = (baseAppSettings(accountManager: accountManager) |> deliverOnMainQueue).start(next: { settings in
            _ = self._baseSettings.swap(settings)
            self.updateStatusBar(settings.statusBar)
            forceUpdateStatusBarIconByDockTile(sharedContext: self)
        })
        
        #endif
        
        
        layoutDisposable.set(layoutHandler.get().start(next: { state in
            self.layout = state
        }))
        
        var supplementary: Bool = false
        #if SHARE
        supplementary = true
        #endif
        
        
        
        
        
        
        let differenceDisposable = MetaDisposable()
        let _ = (accountManager.accountRecords()
            |> map { view -> (AccountRecordId?, [AccountRecordId: AccountAttributes], (AccountRecordId, Bool)?) in
                var result: [AccountRecordId: AccountAttributes] = [:]
                for record in view.records {
                    let isLoggedOut = record.attributes.contains(where: { attribute in
                        return attribute is LoggedOutAccountAttribute
                    })
                    if isLoggedOut {
                        continue
                    }
                    let isTestingEnvironment = record.attributes.contains(where: { attribute in
                        if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                            return true
                        } else {
                            return false
                        }
                    })
                    var backupData: AccountBackupData?
                    var sortIndex: Int32 = 0
                    for attribute in record.attributes {
                        if let attribute = attribute as? AccountSortOrderAttribute {
                            sortIndex = attribute.order
                        } else if let attribute = attribute as? AccountBackupDataAttribute {
                            backupData = attribute.data
                        }
                    }
                    result[record.id] = AccountAttributes(sortIndex: sortIndex, isTestingEnvironment: isTestingEnvironment, backupData: backupData)
                }
                let authRecord: (AccountRecordId, Bool)? = view.currentAuthAccount.flatMap({ authAccount in
                    let isTestingEnvironment = authAccount.attributes.contains(where: { attribute in
                        if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                            return true
                        } else {
                            return false
                        }
                    })
                    return (authAccount.id, isTestingEnvironment)
                })
                return (view.currentRecord?.id, result, authRecord)
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                if lhs.2?.0 != rhs.2?.0 {
                    return false
                }
                if lhs.2?.1 != rhs.2?.1 {
                    return false
                }
                return true
            })
            |> deliverOnMainQueue).start(next: { primaryId, records, authRecord in
                var addedSignals: [Signal<AddedAccountResult, NoError>] = []
                var addedAuthSignal: Signal<UnauthorizedAccount?, NoError> = .single(nil)
                for (id, attributes) in records {
                    if self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == id}) == nil {
                        addedSignals.append(accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: id, encryptionParameters: encryptionParameters, supplementary: supplementary, rootPath: rootPath, beginWithTestingEnvironment: attributes.isTestingEnvironment, backupData: attributes.backupData, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                            |> map { result -> AddedAccountResult in
                                switch result {
                                case let .authorized(account):
                                    #if SHARE
                                    setupAccount(account, fetchCachedResourceRepresentation: nil, transformOutgoingMessageMedia: nil, preFetchedResourcePath: { resource in
                                        return nil
                                    })
                                    #else
                                    setupAccount(account, fetchCachedResourceRepresentation: fetchCachedResourceRepresentation, transformOutgoingMessageMedia: transformOutgoingMessageMedia, preFetchedResourcePath: { resource in
                                        return nil
                                    })
                                    #endif

                                    return .ready(id, account, attributes.sortIndex)
                                case let .upgrading(progress):
                                    return .upgrading(progress)
                                default:
                                    return .ready(id, nil, attributes.sortIndex)
                                }
                            })

                    }
                }
                if let authRecord = authRecord, authRecord.0 != self.activeAccountsValue?.currentAuth?.id {
                    addedAuthSignal = accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: authRecord.0, encryptionParameters: encryptionParameters, supplementary: supplementary, rootPath: rootPath, beginWithTestingEnvironment: authRecord.1, backupData: nil, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                        |> map { result -> UnauthorizedAccount? in
                            switch result {
                            case let .unauthorized(account):
                                return account
                            default:
                                return nil
                            }
                    }
                }
                
                let mappedAddedAccounts = combineLatest(queue: .mainQueue(), addedSignals)
                    |> map { results -> AddedAccountsResult in
                        var readyAccounts: [(AccountRecordId, Account?, Int32)] = []
                        var totalProgress: Float = 0.0
                        var hasItemsWithProgress = false
                        for result in results {
                            switch result {
                            case let .ready(id, account, sortIndex):
                                readyAccounts.append((id, account, sortIndex))
                                totalProgress += 1.0
                            case let .upgrading(progress):
                                hasItemsWithProgress = true
                                totalProgress += progress
                            }
                        }
                        if hasItemsWithProgress, !results.isEmpty {
                            return .upgrading(totalProgress / Float(results.count))
                        } else {
                            return .ready(readyAccounts)
                        }
                }
                

                
                differenceDisposable.set(combineLatest(queue: .mainQueue(), mappedAddedAccounts, addedAuthSignal).start(next: { mappedAddedAccounts, authAccount in
                    var addedAccounts: [(AccountRecordId, Account?, Int32)] = []
                    switch mappedAddedAccounts {
                    case let .upgrading(progress):
                        self.displayUpgradeProgress(progress)
                        return
                    case let .ready(value):
                        addedAccounts = value
                    }
                    
                    
                    var hadUpdates = false
                    if self.activeAccountsValue == nil {
                        self.activeAccountsValue = (nil, [], nil)
                        hadUpdates = true
                    }
                    
                    struct AccountPeerKey: Hashable {
                        let peerId: PeerId
                        let isTestingEnvironment: Bool
                    }

                    
                    var existingAccountPeerKeys = Set<AccountPeerKey>()
                    for accountRecord in addedAccounts {
                        if let account = accountRecord.1 {
                            if existingAccountPeerKeys.contains(AccountPeerKey(peerId: account.peerId, isTestingEnvironment: account.testingEnvironment)) {
                                let _ = accountManager.transaction({ transaction in
                                    transaction.updateRecord(accountRecord.0, { _ in
                                        return nil
                                    })
                                }).start()
                            } else {
                                existingAccountPeerKeys.insert(AccountPeerKey(peerId: account.peerId, isTestingEnvironment: account.testingEnvironment))
                                if let index = self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == account.id }) {
                                    self.activeAccountsValue?.accounts.remove(at: index)
                                    assertionFailure()
                                }
                                self.activeAccountsValue!.accounts.append((account.id, account, accountRecord.2))
                                self.managedAccountDisposables.set(self.updateAccountBackupData(account: account).start(), forKey: account.id)
                                account.resetStateManagement()
                                hadUpdates = true
                            }
                        } else {
                            let _ = accountManager.transaction({ transaction in
                                transaction.updateRecord(accountRecord.0, { _ in
                                    return nil
                                })
                            }).start()
                        }
                    }
                    var removedIds: [AccountRecordId] = []
                    for id in self.activeAccountsValue!.accounts.map({ $0.0 }) {
                        if records[id] == nil {
                            removedIds.append(id)
                        }
                    }
                    for id in removedIds {
                        hadUpdates = true
                        if let index = self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == id }) {
                            self.activeAccountsValue?.accounts.remove(at: index)
                            self.managedAccountDisposables.set(nil, forKey: id)
                        }
                    }
                    var primary: Account?
                    if let primaryId = primaryId {
                        if let index = self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == primaryId }) {
                            primary = self.activeAccountsValue?.accounts[index].1
                        }
                    }
                    if primary == nil && !self.activeAccountsValue!.accounts.isEmpty {
                        primary = self.activeAccountsValue!.accounts.first?.1
                    }
                    if primary !== self.activeAccountsValue!.primary {
                        hadUpdates = true
                        self.activeAccountsValue!.primary?.postbox.clearCaches()
                        self.activeAccountsValue!.primary = primary
                    }
                    if self.activeAccountsValue!.currentAuth?.id != authRecord?.0 {
                        hadUpdates = true
                        self.activeAccountsValue!.currentAuth?.postbox.clearCaches()
                        self.activeAccountsValue!.currentAuth = nil
                    }
                    if let authAccount = authAccount {
                        hadUpdates = true
                        self.activeAccountsValue!.currentAuth = authAccount
                    }
                    if hadUpdates {
                        self.activeAccountsValue!.accounts.sort(by: { $0.2 < $1.2 })
                        self.activeAccountsPromise.set(.single(self.activeAccountsValue!))
                    }
                    
                    if self.activeAccountsValue!.primary == nil && self.activeAccountsValue!.currentAuth == nil {
                        self.beginNewAuth(testingEnvironment: false)
                    }
                    
                    if (authAccount != nil || self.activeAccountsValue!.primary != nil) && !self.cleaningUpAccounts {
                        self.cleaningUpAccounts = true
                        let _ = managedCleanupAccounts(networkArguments: networkArguments, accountManager: self.accountManager, rootPath: rootPath, auxiliaryMethods: telegramAccountAuxiliaryMethods, encryptionParameters: encryptionParameters).start()
                    }
                }))
            })
        

        
        
        self.activeAccountsWithInfoPromise.set(self.activeAccounts
            |> mapToSignal { primary, accounts, _ -> Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> in
                return combineLatest(accounts.map { _, account, _ -> Signal<AccountWithInfo?, NoError> in
                    let peerViewKey: PostboxViewKey = .peer(peerId: account.peerId, components: [])
                    return account.postbox.combinedView(keys: [peerViewKey])
                        |> map { view -> AccountWithInfo? in
                            guard let peerView = view.views[peerViewKey] as? PeerView, let peer = peerView.peers[peerView.peerId] else {
                                return nil
                            }
                            return AccountWithInfo(account: account, peer: peer)
                        }
                        |> distinctUntilChanged
                })
                    |> map { accountsWithInfo -> (primary: AccountRecordId?, accounts: [AccountWithInfo]) in
                        var accountsWithInfoResult: [AccountWithInfo] = []
                        for info in accountsWithInfo {
                            if let info = info {
                                accountsWithInfoResult.append(info)
                            }
                        }
                        return (primary?.id, accountsWithInfoResult)
                }
            })
        
        let signal = self.activeAccountsWithInfoPromise.get() |> mapToSignal { (primary, accounts) -> Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo], [PeerId : CGImage]), NoError> in
            let photos:[Signal<(PeerId, CGImage?), NoError>] = accounts.map { info in
                return peerAvatarImage(account: info.account, photo: .peer(info.peer, info.peer.smallProfileImage, info.peer.displayLetters, nil), displayDimensions: NSMakeSize(32, 32)) |> map {
                    (info.account.peerId, $0.0)
                }
            }
            return combineLatest(photos) |> map { photos in
                let photos = photos.compactMap {
                    return $0.1 == nil ? nil : ($0.0, $0.1!)
                }
                let dict:[PeerId: CGImage] = photos.reduce([:], { result, current in
                    var result = result
                    result[current.0] = current.1
                    return result
                })
                return (primary, accounts, dict)
            }
            
        } |> deliverOnMainQueue
        
        _ = signal.start(next: { (primary, accounts, photos) in
            self.activeAccountsInfoValue = (primary, accounts)
            self.accountPhotos = photos
            self.updateStatusBarMenuItem()
        })
    }
    
    public func beginNewAuth(testingEnvironment: Bool) {
        let _ = self.accountManager.transaction({ transaction -> Void in
            let _ = transaction.createAuth([AccountEnvironmentAttribute(environment: testingEnvironment ? .test : .production)])
        }).start()
    }
    
    private var launchActions:[AccountRecordId : LaunchNavigation] = [:]
    
    func setLaunchAction(_ action: LaunchNavigation, for accountId: AccountRecordId) -> Void {
        assert(Queue.mainQueue().isCurrent())
        launchActions[accountId] = action
    }
    
    func getLaunchActionOnce(for accountId: AccountRecordId) -> LaunchNavigation? {
        assert(Queue.mainQueue().isCurrent())
        let action = launchActions[accountId]
        launchActions.removeValue(forKey: accountId)
        return action
    }
    
    private func updateAccountBackupData(account: Account) -> Signal<Never, NoError> {
        return accountBackupData(postbox: account.postbox)
            |> mapToSignal { backupData -> Signal<Never, NoError> in
                guard let backupData = backupData else {
                    return .complete()
                }
                return self.accountManager.transaction { transaction -> Void in
                    transaction.updateRecord(account.id, { record in
                        guard let record = record else {
                            return nil
                        }
                        var attributes = record.attributes.filter({ !($0 is AccountBackupDataAttribute) })
                        attributes.append(AccountBackupDataAttribute(data: backupData))
                        return AccountRecord(id: record.id, attributes: attributes, temporarySessionId: record.temporarySessionId)
                    })
                    }
                    |> ignoreValues
        }
    }

    
    public func switchToAccount(id: AccountRecordId, action: LaunchNavigation?) {
        if self.activeAccountsValue?.primary?.id == id {
            return
        }
        if let action = action {
            setLaunchAction(action, for: id)
        }
        
        assert(Queue.mainQueue().isCurrent())
        
        #if SHARE
        if let activeAccountsValue = self.activeAccountsValue, let account = activeAccountsValue.accounts.first(where: {$0.0 == id}) {
            var activeAccountsValue = activeAccountsValue
            activeAccountsValue.primary = account.1
            self.activeAccountsPromise.set(.single(activeAccountsValue))
            self.activeAccountsValue = activeAccountsValue
        }
        return
        #else
         _ = self.accountManager.transaction({ transaction in
            if transaction.getCurrent()?.0 != id {
                transaction.setCurrentId(id)
            }
        }).start()
        #endif
        
    }
    #if !SHARE
    func showCallHeader(with session:PCallSession) {
        bindings.rootNavigation().callHeader?.show(true)
        if let view = bindings.rootNavigation().callHeader?.view as? CallNavigationHeaderView {
            view.update(with: session)
        }
    }
    #endif
    deinit {
        layoutDisposable.dispose()
    }
    
}
