//
//  AccountsListViewController.swift
//  Telegram
//
//  Created by keepcoder on 20/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

enum AccountRecordEntryStableId : Hashable {
    case record(AccountRecordId)
    case newAccount
    
    static func ==(lhs:AccountRecordEntryStableId, rhs:AccountRecordEntryStableId) -> Bool {
        switch lhs {
        case let .record(id):
            if case .record(id) = rhs {
                return true
            } else {
                return false
            }
        case .newAccount:
            if case .newAccount = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var hashValue: Int {
        switch self {
        case let .record(id):
            return id.hashValue
        case .newAccount:
            return 1000
        }
    }
}

enum AccountRecordEntry : Identifiable, Comparable {
    case record(AccountRecord, Bool, Int)
    case newAccount
    
    var stableId: AccountRecordEntryStableId {
        switch self {
        case let .record(record, _, _):
            return .record(record.id)
        case .newAccount:
            return .newAccount
        }
    }
    
    var index:Int {
        switch self {
        case let .record(_, _, idx):
            return idx
        case .newAccount:
            return 10000
        }
    }
}

func ==(lhs:AccountRecordEntry, rhs: AccountRecordEntry) -> Bool {
    switch lhs {
    case let .record(id, isCurrent, idx):
        if case .record(id, isCurrent, idx) = rhs {
            return true
        } else {
            return false
        }
    case .newAccount:
        if case .newAccount = rhs {
            return true
        } else {
            return false
        }
    }
}

func <(lhs:AccountRecordEntry, rhs: AccountRecordEntry) -> Bool {
    return lhs.index < rhs.index
}


class AccountsListViewController : GenericViewController<TableView> {
    private let account:Account
    private let accountManager:AccountManager
    private let statePromise:ValuePromise<ViewControllerState> = ValuePromise(.Normal, ignoreRepeated: true)
    init(_ account:Account, accountManager:AccountManager) {
        self.account = account
        self.accountManager = accountManager
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let entries:Atomic<[AccountRecordEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        self.genericView.merge(with: accountManager.accountRecords() |> mapToSignal { [weak self] records -> Signal<TableUpdateTransition, Void> in
            if let strongSelf = self {
                strongSelf.readyOnce()
                let converted = strongSelf.entries(from: records)
                return strongSelf.prepareEntries(left: entries.swap(converted), right: converted, initialSize: initialSize.modify {$0})
            } else {
                return .complete()
            }
        } |> deliverOnMainQueue)
        
        
    }
    
    override var defaultBarTitle: String {
        return "Accounts"
    }
    
    private func entries(from: AccountRecordsView) -> [AccountRecordEntry] {
        var entries:[AccountRecordEntry] = []
        entries.append(.newAccount)

        var i:Int = 0
        for record in from.records {
            entries.append(.record(record, record == from.currentRecord, i))
            i += 1
        }
        return entries
    }
    
    func prepareEntries(left: [AccountRecordEntry], right:[AccountRecordEntry], initialSize:NSSize) -> Signal<TableUpdateTransition, Void> {
        return Signal { subscriber in
            
            let (removed, inserted, updated) = proccessEntries(left, right: right, { (entry) -> TableRowItem in
                
                switch entry {
                case .newAccount:
                    return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(L10n.accountsControllerNewAccount), nameStyle: blueActionButton, type: .none, action: { [weak self] in
                        let _ = self?.accountManager.transaction({ transaction -> Void in
                            let id = transaction.createRecord([])
                            transaction.setCurrentId(id)
                        }).start()
                    })
                case let .record(record, isCurrent, _):
                    return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: "\(record.id.hashValue)", nameStyle: ControlStyle(font: .normal(.title), foregroundColor: isCurrent ? theme.colors.grayText : theme.colors.text), type: .none, action: { [weak self] in
                        let _ = self?.accountManager.transaction({ transaction -> Void in
                            transaction.setCurrentId(record.id)
                        }).start()
                    })
                }
                
            })
            
            subscriber.putNext(TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated))
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    
}
