//
//  SharedWakeupManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore


private struct AccountTasks {
    let stateSynchronization: Bool
    let importantTasks: AccountRunningImportantTasks
    let backgroundDownloads: Bool
    let backgroundAudio: Bool
    let activeCalls: Bool
    let userInterfaceInUse: Bool
    
    var isEmpty: Bool {
        if self.stateSynchronization {
            return false
        }
        if !self.importantTasks.isEmpty {
            return false
        }
        if self.backgroundDownloads {
            return false
        }
        if self.backgroundAudio {
            return false
        }
        if self.activeCalls {
            return false
        }
        if self.userInterfaceInUse {
            return false
        }
        return true
    }
}



class SharedWakeupManager {
    private var accountsAndTasks: [(Account, Bool, AccountTasks)] = []
    private let sharedContext: SharedAccountContext
    
    private var stateManagmentReseted: Set<AccountRecordId> = Set()
    private var ringingStatesActivated: Set<AccountRecordId> = Set()
    private var inForeground: Bool = false

    init(sharedContext: SharedAccountContext, inForeground: Signal<Bool, NoError>) {
        self.sharedContext = sharedContext
        
         NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveWakeNote(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)

        
        _ = (inForeground |> deliverOnMainQueue).start(next: { value in
                self.inForeground = value
                self.checkTasks()
            })

       
        let signal = (sharedContext.activeAccounts |> map { ($0.0, $0.1.map { ($0.0, $0.1) }) } |> mapToSignal { primary, accounts -> Signal<[(Account, Bool, AccountTasks)], NoError> in
            
            let result: [Signal<(Account, Bool, AccountTasks), NoError>] = accounts.map { (_, account) -> Signal<(Account, Bool, AccountTasks), NoError> in
                return account.importantTasksRunning |> map { importantTasks in
                    return (account, primary?.id == account.id, AccountTasks(stateSynchronization: false, importantTasks: importantTasks, backgroundDownloads: false, backgroundAudio: false, activeCalls: false, userInterfaceInUse: false))
                }
            }
            
            return combineLatest(result)
            
        } |> deliverOnMainQueue)

        
        _ = signal.start(next: { accountsAndTasks in
            self.accountsAndTasks = accountsAndTasks
            self.updateRindingsStatuses(self.accountsAndTasks.map( { $0.0 } ))
            self.checkTasks()
        })
    }
    
    private func checkTasks() {
        updateAccounts()
    }
    
    @objc func receiveWakeNote(_ notificaiton:Notification) {
         for (account, _, _) in self.accountsAndTasks {
            account.shouldBeServiceTaskMaster.set(.single(.never) |> then(.single(.always)))
        }
    }

    private func updateRindingsStatuses(_ accounts:[Account]) {
        
        self.ringingStatesActivated = ringingStatesActivated.intersection(accounts.map { $0.id })
        
        for account in accounts {
            if !ringingStatesActivated.contains(account.id) {
                _ = (account.callSessionManager.ringingStates() |> deliverOn(callQueue)).start(next: { states in
                    pullCurrentSession( { session in
                        DispatchQueue.main.async {
                            if let state = states.first {
                                if session != nil {
                                    account.callSessionManager.drop(internalId: state.id, reason: .busy, debugLog: .single(nil))
                                } else {
                                    showCallWindow(PCallSession(account: account, sharedContext: self.sharedContext, isOutgoing: false, peerId: state.peerId, id: state.id, initialState: nil, startWithVideo: state.isVideo, isVideoPossible: state.isVideoPossible))
                                }
                            }
                        }
                    } )
                })
                ringingStatesActivated.insert(account.id)
            }
            
        }
        
    }
    
    private func updateAccounts() {
        for (account, primary, tasks) in self.accountsAndTasks {
            account.shouldBeServiceTaskMaster.set(.single(.always))
            account.shouldExplicitelyKeepWorkerConnections.set(.single(tasks.backgroundAudio))
            account.shouldKeepOnlinePresence.set(.single(primary && self.inForeground))
            account.shouldKeepBackgroundDownloadConnections.set(.single(tasks.backgroundDownloads))
            
            if !stateManagmentReseted.contains(account.id) {
                account.resetStateManagement()
                stateManagmentReseted.insert(account.id)
            }
        }
    }

}
