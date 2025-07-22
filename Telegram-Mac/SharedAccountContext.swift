//
//  SharedAccountContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit
import TGUIKit
import BuildConfig
import ApiCredentials

#if !SHARE
import PrivateCallScreen
#endif


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
    let accountManager: AccountManager<TelegramAccountManagerTypes>

    #if !SHARE
    var peerCall: PeerCallScreen? {
        didSet {
            var bp = 0
            bp += 1
        }
    }
    
    let inputSource: InputSources = InputSources()
    let devicesContext: DevicesContext
    private let _baseSettings: Atomic<BaseApplicationSettings> = Atomic(value: BaseApplicationSettings.defaultSettings)
    
    var baseSettings: BaseApplicationSettings {
        return _baseSettings.with { $0 }
    }
    
    var baseApplicationSettings: Signal<BaseApplicationSettings, NoError> {
        return baseAppSettings(accountManager: self.accountManager)
    }
    
   
    func isLite(_ key: LiteModeKey = .any) -> Bool {
        let mode = baseSettings.liteMode
        if mode.enabled {
            return true
        }
        if mode.lowBatteryPercent != 100 {
            if batteryLevel <= Double(mode.lowBatteryPercent) {
                return true
            }
        }
        
        return !mode.isEnabled(key: key)
    }
    #endif

    private(set) var batteryLevel: Double = 100
    
    private var batteryLevelTimer: SwiftSignalKit.Timer?
    
    private let managedAccountDisposables = DisposableDict<AccountRecordId>()
    
    
    private let appEncryption: Atomic<AppEncryptionParameters>
    
    var appEncryptionValue: AppEncryptionParameters {
        return appEncryption.with { $0 }
    }
    
    func updateAppEncryption(_ f: (AppEncryptionParameters)->AppEncryptionParameters) {
        _ = self.appEncryption.modify(f)
    }
    
    
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
    
    
    public var callStatusBarMenuItems:(()->[ContextMenuItem])? = nil {
        didSet {
            updateStatusBarMenuItem()
        }
    }

    private var statusItem: NSStatusItem?

    
    func updateStatusBarImage(_ image: NSImage?) -> Void {
        let icon: NSImage
        if let image = image {
            icon = image
        } else {
            icon = NSImage(named: "StatusIcon")!
            icon.isTemplate = true
        }
        statusItem?.image = icon
    }
    
    private func updateStatusBarMenuItem() {
        
        let menu = NSMenu()
        
        if let items = self.callStatusBarMenuItems?()  {
            for item in items {
                item.menu = nil
                menu.addItem(item)
            }
        } else {
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
            
            menu.addItem(ContextMenuItem(strings().statusBarActivate, handler: {
                if !mainWindow.isKeyWindow  {
                    NSApp.activate(ignoringOtherApps: true)
                    mainWindow.deminiaturize(nil)
                } else {
                    NSApp.hide(nil)
                }
                
            }, dynamicTitle: {
                return !mainWindow.isKeyWindow ? strings().statusBarActivate : strings().statusBarHide
            }))
                    
            menu.addItem(ContextMenuItem(strings().statusBarQuit, handler: {
                NSApp.terminate(nil)
            }))
        }
        
       
        
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

    private let displayUpgradeProgress: (Float?) -> Void
    

    
    init(accountManager: AccountManager<TelegramAccountManagerTypes>, networkArguments: NetworkInitializationArguments, rootPath: String, encryptionParameters: ValueBoxEncryptionParameters, appEncryption: AppEncryptionParameters, displayUpgradeProgress: @escaping(Float?) -> Void) {
        self.accountManager = accountManager
        self.displayUpgradeProgress = displayUpgradeProgress
        self.appEncryption = Atomic(value: appEncryption)
        #if !SHARE
        self.devicesContext = DevicesContext(accountManager)
        self.accountManager.mediaBox.fetchCachedResourceRepresentation = { (resource, representation) -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return fetchCachedSharedResourceRepresentation(accountManager: accountManager, resource: resource, representation: representation)
        }
        _ = (baseAppSettings(accountManager: accountManager) |> deliverOnMainQueue).start(next: { settings in
            _ = self._baseSettings.swap(settings)
            self.updateStatusBar(settings.statusBar)
            forceUpdateStatusBarIconByDockTile(sharedContext: self)
        })
        #endif
        
        

        
        var supplementary: Bool = false
        #if SHARE
        supplementary = true
        #endif
        
        
        self.batteryLevelTimer = .init(timeout: 1 * 60, repeat: true, completion: {
            let internalFinder = InternalFinder()
            if let internalBattery = internalFinder.getInternalBattery() {
                let batteryLevel = internalBattery.charge ?? 100
                DispatchQueue.main.async {
                    self.batteryLevel = batteryLevel
                }
            }
        }, queue: .concurrentDefaultQueue())
        
        
        self.batteryLevelTimer?.start()
        

        let differenceDisposable = MetaDisposable()
        let _ = (accountManager.accountRecords()
            |> map { view -> (AccountRecordId?, [AccountRecordId: AccountAttributes], (AccountRecordId, Bool)?) in
                var result: [AccountRecordId: AccountAttributes] = [:]
                for record in view.records {
                    let isLoggedOut = record.attributes.contains(where: { attribute in
                        if case .loggedOut = attribute {
                            return true
                        } else {
                            return false
                        }
                    })
                    if isLoggedOut {
                        continue
                    }

                    let isTestingEnvironment = record.attributes.contains(where: { attribute in
                        if case let .environment(environment) = attribute, case .test = environment.environment {
                            return true
                        } else {
                            return false
                        }
                    })

                    var backupData: AccountBackupData?
                    var sortIndex: Int32 = 0
                    for attribute in record.attributes {
                        if case let .sortOrder(sortOrder) = attribute {
                            sortIndex = sortOrder.order
                        } else if case let .backupData(backupDataValue) = attribute {
                            backupData = backupDataValue.data
                        }
                    }

                    result[record.id] = AccountAttributes(sortIndex: sortIndex, isTestingEnvironment: isTestingEnvironment, backupData: backupData)
                }
                let authRecord: (AccountRecordId, Bool)? = view.currentAuthAccount.flatMap({ authAccount in
                    let isTestingEnvironment = authAccount.attributes.contains(where: { attribute in
                        if case let .environment(environment) = attribute, case .test = environment.environment {
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
                        addedSignals.append(accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: id, encryptionParameters: encryptionParameters, supplementary: supplementary, isSupportUser: false, rootPath: rootPath, beginWithTestingEnvironment: attributes.isTestingEnvironment, backupData: attributes.backupData, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                            |> map { result -> AddedAccountResult in
                                switch result {
                                case let .authorized(account):
                                    #if SHARE
                                    setupAccount(account)
                                    #else
                                    setupAccount(account, fetchCachedResourceRepresentation: fetchCachedResourceRepresentation, transformOutgoingMessageMedia: transformOutgoingMessageMedia)
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
                    addedAuthSignal = accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: authRecord.0, encryptionParameters: encryptionParameters, supplementary: supplementary, isSupportUser: false, rootPath: rootPath, beginWithTestingEnvironment: authRecord.1, backupData: nil, auxiliaryMethods: telegramAccountAuxiliaryMethods)
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
                return peerAvatarImage(account: info.account, photo: .peer(info.peer, info.peer.smallProfileImage, info.peer.nameColor, info.peer.displayLetters, nil, nil), displayDimensions: NSMakeSize(32, 32)) |> map {
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
        
        #if !SHARE
        var spotlights:[AccountRecordId : SpotlightContext] = [:]
        
        _ = signal.start(next: { (primary, accounts, photos) in
            self.activeAccountsInfoValue = (primary, accounts)
            self.accountPhotos = photos
            self.updateStatusBarMenuItem()
            BrowserStateContext.checkActive(accounts.map { $0.account.id })
            
            #if !SHARE
            spotlights.removeAll()
            for info in accounts {
                spotlights[info.account.id] = SpotlightContext(engine: TelegramEngine(account: info.account))
            }
            #endif
        })
        #endif
    }
    
    public func beginNewAuth(testingEnvironment: Bool) {
        let _ = self.accountManager.transaction({ transaction -> Void in
            let _ = transaction.createAuth([.environment(AccountEnvironmentAttribute(environment: testingEnvironment ? .test : .production))])
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
    
    #if !SHARE
    private let crossCallSession: Atomic<PCallSession?> = Atomic<PCallSession?>(value: nil)
    
    func getCrossAccountCallSession() -> PCallSession? {
        return crossCallSession.with { $0 }
    }
    
    private let crossGroupCall: Atomic<GroupCallContext?> = Atomic<GroupCallContext?>(value: nil)
    
    func getCrossAccountGroupCall() -> GroupCallContext? {
        return crossGroupCall.with { $0 }
    }
   
    #endif
    
    
    private func updateAccountBackupData(account: Account) -> Signal<Never, NoError> {
        return accountBackupData(postbox: account.postbox)
            |> mapToSignal { backupData -> Signal<Never, NoError> in
                return self.accountManager.transaction { transaction -> Void in
                    transaction.updateRecord(account.id, { record in
                        guard let record = record else {
                            return nil
                        }
                        let attributes = record.attributes.filter {
                            if case .backupData = $0 {
                                return false
                            } else {
                                return true
                            }
                        }
                       
                        return AccountRecord(id: record.id, attributes: attributes, temporarySessionId: record.temporarySessionId)
                    })
                    }
                    |> ignoreValues
        }
    }

    
    public func switchToAccount(id: AccountRecordId, action: LaunchNavigation?) {
        
        #if !SHARE
        if let value = appDelegate?.supportAccountContextValue?.find(id) {
            value.focus()
            return;
        }
        #endif
        
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
    
    public func openAccount(id: AccountRecordId) {
    #if !SHARE

        let signal = self.activeAccounts
        |> take(1)
        |> deliverOnMainQueue
        _ = signal.start(next: { values in
            for account in values.accounts {
                if account.0 == id {
                    appDelegate?.openAccountInNewWindow(account.1)
                }
            }
        })
        #endif
    }

    
    
    
    #if !SHARE
    
    var hasActiveCall:Bool {
        return crossCallSession.with( { $0 }) != nil || crossGroupCall.with( { $0 }) != nil
    }
    
    var p2pCall: PCallSession? {
        return crossCallSession.with( { $0 })
    }

    func dropCrossCall() {
        _ = crossGroupCall.swap(nil)
        _ = crossCallSession.swap(nil)
    }
    
    func endCurrentCall() -> Signal<Bool, NoError> {
        if let groupCall = crossGroupCall.with({ $0 }) {
            return groupCall.leaveSignal() |> filter { $0 }
        } else if let callSession = crossCallSession.swap(nil) {
            return callSession.hangUpCurrentCall() |> filter { $0 }
        }
        return .single(true)
    }
    
    func showCall(with session:PCallSession) {
        appDelegate?.enumerateAccountContexts { accountContext in
            let callHeader = accountContext.bindings.rootNavigation().callHeader
            callHeader?.show(true, contextObject: session)
        }
        _ = crossCallSession.swap(session)
    }
    private let groupCallContextValue:Promise<GroupCallContext?> = Promise(nil)
    var groupCallContext:Signal<GroupCallContext?, NoError> {
        return groupCallContextValue.get()
    }
    func showGroupCall(with context: GroupCallContext) {
        appDelegate?.enumerateAccountContexts { accountContext in
            let callHeader = accountContext.bindings.rootNavigation().callHeader
            callHeader?.show(true, contextObject: context)
        }
        _ = crossGroupCall.swap(context)
    }
    
    func updateCurrentGroupCallValue(_ value: GroupCallContext?) -> Void {
        groupCallContextValue.set(.single(crossGroupCall.modify( { _ in return value } )))
    }
    
    func endGroupCall(terminate: Bool) -> Signal<Bool, NoError> {
        if let groupCall = crossGroupCall.swap(nil) {
            return groupCall.call.leave(terminateIfPossible: terminate) |> filter { $0 } |> take(1)
        } else {
            return .single(true)
        }
    }
    
    #endif
    
    
    #if !SHARE
    private let crossInlinePlayer: Atomic<InlineAudioPlayerView.ContextObject?> = Atomic<InlineAudioPlayerView.ContextObject?>(value: nil)

    func getCrossInlinePlayer() -> InlineAudioPlayerView.ContextObject? {
        return crossInlinePlayer.with { $0 }
    }
    func endInlinePlayer(animated: Bool) -> Void {
        let value = crossInlinePlayer.swap(nil)
        value?.controller.stop()
        appDelegate?.enumerateAccountContexts { accountContext in
            let header = accountContext.bindings.rootNavigation().header
            header?.hide(animated)
        }
    }
    
    func showInlinePlayer(_ object: InlineAudioPlayerView.ContextObject) {
        appDelegate?.enumerateAccountContexts { accountContext in
            let header = accountContext.bindings.rootNavigation().header
            header?.show(true, contextObject: object)
        }
        let previous = crossInlinePlayer.swap(object)
        previous?.controller.stop()
    }
    
    func getAudioPlayer() -> APController? {
        return getCrossInlinePlayer()?.controller
    }
    
    #endif
    
    deinit {
        batteryLevelTimer?.invalidate()
    }
    
}
