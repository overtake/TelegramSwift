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

    private(set) var isSleeping: Bool = false {
        didSet {
            onSleepValueUpdated?(isSleeping)
        }
    }
    
    var onSleepValueUpdated:((Bool)->Void)?
    
    init(sharedContext: SharedAccountContext, inForeground: Signal<Bool, NoError>) {
        self.sharedContext = sharedContext
        
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveWakeNote(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveSleepNote(_:)), name: NSWorkspace.didWakeNotification, object: nil)

        
         NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveWakeNote(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(receiveSleepNote(_:)), name: NSWorkspace.screensDidSleepNotification, object: nil)

        
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
    
    @objc func receiveSleepNote(_ notification: Notification) {
        if !self.isSleeping {
            for (account, _, _) in self.accountsAndTasks {
               account.shouldBeServiceTaskMaster.set(.single(.never))
            }
        }
        self.isSleeping = true
        
    }
    
    @objc func receiveWakeNote(_ notificaiton:Notification) {
        if self.isSleeping {
            for (account, _, _) in self.accountsAndTasks {
               account.shouldBeServiceTaskMaster.set(.single(.never) |> then(.single(.always)))
            }
        }
        self.isSleeping = false
    }

    private func updateRindingsStatuses(_ accounts:[Account]) {
        
        self.ringingStatesActivated = ringingStatesActivated.intersection(accounts.map { $0.id })
        let accountManager = sharedContext.accountManager
        for account in accounts {
            if !ringingStatesActivated.contains(account.id) {
                
                let combine = combineLatest(account.stateManager.isUpdating, account.callSessionManager.ringingStates()) |> mapToSignal { loading, states -> Signal<(Bool, CallSessionRingingState, PCallSession.InitialData)?, NoError> in
                    if let state = states.first {
                        return getPrivateCallSessionData(account, accountManager: accountManager, peerId: state.peerId) |> map {
                            (loading, state, $0)
                        }
                    } else {
                        return .single(nil)
                    }
                }
                |> filter { $0 != nil && !$0!.0 }
                |> map { $0! }
                |> deliverOnMainQueue
                _ = combine.start(next: { data in
                    let state = data.1
                    let initialData = data.2
                    
                    if self.sharedContext.hasActiveCall {
                        if self.sharedContext.p2pCall?.internalId != state.id {
                            account.callSessionManager.drop(internalId: state.id, reason: .busy, debugLog: .single(nil))
                        }
                    } else {
                        
                        var otherParticipants: [EnginePeer] = state.otherParticipants
                        
                        #if DEBUG
                        let fake = TelegramUser(id: PeerId(1), accessHash: nil, firstName: strings().appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                        
                        otherParticipants = [.init(fake)]
                        
                        #endif
                        
                        
                        if let accountContext = appDelegate?.activeContext(for: account.id), state.peerId != account.peerId {
                            showCallWindow(PCallSession(accountContext: accountContext, account: account, isOutgoing: false, incomingConferenceSource: state.conferenceSource, incomingParticipants: otherParticipants, peerId: state.peerId, id: state.id, initialState: nil, startWithVideo: state.isVideo, isVideoPossible: state.isVideoPossible, data: initialData))
                            
                        }
                    }
                })
                ringingStatesActivated.insert(account.id)
            }
            
        }
        
    }
    
    private func updateAccounts() {
        for (account, primary, tasks) in self.accountsAndTasks {
            account.shouldBeServiceTaskMaster.set(.single(.always))
            account.shouldExplicitelyKeepWorkerConnections.set(.single(tasks.backgroundAudio))
            
            let based = appDelegate?.supportAccountContextValue?.find(account.id)
            
            account.shouldKeepOnlinePresence.set(.single((primary || based != nil) && self.inForeground))
            account.shouldKeepBackgroundDownloadConnections.set(.single(tasks.backgroundDownloads))
            
            if !stateManagmentReseted.contains(account.id) {
                account.resetStateManagement()
                stateManagmentReseted.insert(account.id)
            }
        }
    }

}
