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
    #endif
    
    private var activeAccountsValue: (primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?)?
    private let activeAccountsPromise = Promise<(primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?)>()
    var activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?), NoError> {
        return self.activeAccountsPromise.get()
    }
    private let activeAccountsWithInfoPromise = Promise<(primary: AccountRecordId?, accounts: [AccountWithInfo])>()
    var activeAccountsWithInfo: Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> {
        return self.activeAccountsWithInfoPromise.get()
    }

    
    
    private(set) var layout:SplitViewState = .none
    let layoutHandler:ValuePromise<SplitViewState> = ValuePromise(ignoreRepeated:true)

    

    private let layoutDisposable = MetaDisposable()
    
    init(accountManager: AccountManager, networkArguments: NetworkInitializationArguments, rootPath: String) {
        self.accountManager = accountManager
        #if !SHARE
        self.accountManager.mediaBox.fetchCachedResourceRepresentation = { (resource, representation) -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return fetchCachedSharedResourceRepresentation(accountManager: accountManager, resource: resource, representation: representation)
        }
        #endif
        
        layoutDisposable.set(layoutHandler.get().start(next: { [weak self] state in
            self?.layout = state
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
                    var sortIndex: Int32 = 0
                    for attribute in record.attributes {
                        if let attribute = attribute as? AccountSortOrderAttribute {
                            sortIndex = attribute.order
                        }
                    }
                    result[record.id] = AccountAttributes(sortIndex: sortIndex, isTestingEnvironment: isTestingEnvironment)
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
                var addedSignals: [Signal<(AccountRecordId, Account?, Int32), NoError>] = []
                var addedAuthSignal: Signal<UnauthorizedAccount?, NoError> = .single(nil)
                for (id, attributes) in records {
                    if self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == id}) == nil {
                        addedSignals.append(accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: id, supplementary: supplementary, rootPath: rootPath, beginWithTestingEnvironment: attributes.isTestingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                            |> map { result -> (AccountRecordId, Account?, Int32) in
                                switch result {
                                case let .authorized(account):
                                    #if !SHARE
                                        setupAccount(account, fetchCachedResourceRepresentation: fetchCachedResourceRepresentation, transformOutgoingMessageMedia: transformOutgoingMessageMedia, preFetchedResourcePath: { resource in
                                            return nil
                                        })
                                    #else
                                        setupAccount(account)
                                    #endif
                                    return (id, account, attributes.sortIndex)
                                default:
                                    return (id, nil, attributes.sortIndex)
                                }
                            })
                    }
                }
                if let authRecord = authRecord, authRecord.0 != self.activeAccountsValue?.currentAuth?.id {
                    addedAuthSignal = accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: authRecord.0, supplementary: supplementary, rootPath: rootPath, beginWithTestingEnvironment: authRecord.1, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                        |> map { result -> UnauthorizedAccount? in
                            switch result {
                            case let .unauthorized(account):
                                return account
                            default:
                                return nil
                            }
                    }
                }
                differenceDisposable.set((combineLatest(combineLatest(addedSignals), addedAuthSignal)
                    |> deliverOnMainQueue).start(next: { accounts, authAccount in
                        var hadUpdates = false
                        if self.activeAccountsValue == nil {
                            self.activeAccountsValue = (nil, [], nil)
                            hadUpdates = true
                        }
                        for accountRecord in accounts {
                            if let account = accountRecord.1 {
                                if let index = self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == account.id }) {
                                    self.activeAccountsValue?.accounts.remove(at: index)
                                    assertionFailure()
                                }
                                self.activeAccountsValue!.accounts.append((account.id, account, accountRecord.2))
                                hadUpdates = true
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
        
        let _ = managedCleanupAccounts(networkArguments: networkArguments, accountManager: self.accountManager, rootPath: rootPath, auxiliaryMethods: telegramAccountAuxiliaryMethods).start()

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
        #endif
        
        
        
        _ = self.accountManager.transaction({ transaction -> Bool in
            if transaction.getCurrent()?.0 != id {
                transaction.setCurrentId(id)
                return true
            } else {
                return false
            }
        }).start(next: { value in
            if value {
                
            }
        })
        
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
