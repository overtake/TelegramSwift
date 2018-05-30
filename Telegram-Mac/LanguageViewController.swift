//
//  LanguageViewController.swift
//  Telegram
//
//  Created by keepcoder on 25/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

extension LocalizationInfo : Equatable {
    
}
public func ==(lhs:LocalizationInfo, rhs:LocalizationInfo) -> Bool {
    return lhs.title == rhs.title && lhs.languageCode == rhs.languageCode && lhs.localizedTitle == rhs.localizedTitle
}

final class LanguageControllerArguments {
    let account:Account
    let change:(LocalizationInfo)->Void
    let searchInteractions:SearchInteractions
    init(account:Account, change:@escaping(LocalizationInfo)->Void, searchInteractions: SearchInteractions) {
        self.account = account
        self.change = change
        self.searchInteractions = searchInteractions
    }
}

enum LanguageTableEntryId : Hashable {
    case search
    case language(String)
    case loading
    var hashValue: Int {
        switch self {
        case .search:
            return 0
        case .language(let id):
            return id.hashValue
        case .loading:
            return 1
        }
    }
    static func ==(lhs:LanguageTableEntryId, rhs:LanguageTableEntryId) -> Bool {
        switch lhs {
        case .search:
            if case .search = rhs {
                return true
            } else {
                return false
            }
        case .loading:
            if case .loading = rhs {
                return true
            } else {
                return false
            }
        case .language(let id):
            if case .language(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
}

enum LanguageTableEntry : TableItemListNodeEntry {
    case search
    case language(index:Int32, selected: Bool, value: LocalizationInfo)
    case loading
    var stableId: LanguageTableEntryId {
        switch self {
        case .search:
            return .search
        case .language(_, _, let value):
            return .language(value.languageCode)
        case .loading:
            return .loading
        }
    }
    
    var index:Int32 {
        switch self {
        case .search:
            return 0
        case .language(let index, _, _):
            return 1 + index
        case .loading:
            return -1
        }
    }
    
    func item(_ arguments: LanguageControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .search:
            return SearchRowItem(initialSize, stableId: stableId, searchInteractions: arguments.searchInteractions, inset: NSEdgeInsets(left: 25, right: 25, top: 10, bottom: 10))
        case let .language(_, selected, value):
            return LanguageRowItem(initialSize: initialSize, stableId: stableId, selected: selected, value: value, action: {
                arguments.change(value)
            })
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        }
    }
}

func ==(lhs:LanguageTableEntry, rhs:LanguageTableEntry) -> Bool {
    switch lhs {
    case .search:
        if case .search = rhs {
            return true
        } else {
            return false
        }
    case .loading:
        if case .loading = rhs {
            return true
        } else {
            return false
        }
    case let .language(index, selected, value):
        if case .language(index, selected, value) = rhs {
            return true
        } else {
            return false
        }
    }
}

func <(lhs:LanguageTableEntry, rhs:LanguageTableEntry) -> Bool {
    return lhs.index < rhs.index
}



private func languageControllerEntries(infos: [LocalizationInfo]?, language: Language, state:SearchState) -> [LanguageTableEntry] {

    var entries: [LanguageTableEntry] = []
    if let infos = infos {
        entries.append(.search)
        var index:Int32 = 1
        
        for value in infos {
            var accept: Bool = true
            if !state.request.isEmpty {
                accept = (value.title.lowercased().range(of: state.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.request.lowercased()) != nil)
            }
            if accept {
                entries.append(.language(index: index, selected: value.languageCode == language.languageCode, value: value))
                index += 1
            }
            
        }
    } else {
        entries.append(.loading)
    }
    

    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<LanguageTableEntry>], right: [AppearanceWrapperEntry<LanguageTableEntry>], initialSize:NSSize, arguments:LanguageControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}



class LanguageViewController: TableViewController {
    private let languageDisposable = MetaDisposable()
    private let applyDisposable = MetaDisposable()

    
    override var enableBack: Bool {
        return true
    }
    private let defaultLanguages:[LocalizationInfo]?
    
    init(_ account: Account, languages: [LocalizationInfo]? = nil) {
        self.defaultLanguages = languages
        super.init(account)
    }
    
    deinit {
        applyDisposable.dispose()
        languageDisposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        let searchPromise = ValuePromise<SearchState>()
        
        let searchInteractions = SearchInteractions({ state in
            searchPromise.set(state)
        }, { state in
            searchPromise.set(state)
        })
        searchPromise.set(SearchState(state: .None, request: nil))
        
        let account = self.account
        
        let arguments = LanguageControllerArguments(account: account, change: { [weak self] value in
            if value.languageCode != appCurrentLanguage.languageCode {
                self?.applyDisposable.set(showModalProgress(signal: downoadAndApplyLocalization(postbox: account.postbox, network: account.network, languageCode: value.languageCode), for: mainWindow).start())
            }
        }, searchInteractions: searchInteractions)
        
        let previous:Atomic<[AppearanceWrapperEntry<LanguageTableEntry>]> = Atomic(value: [])
        
        let initialSize = atomicSize

        genericView.merge(with: combineLatest(Signal<[LocalizationInfo]?, Void>.single(defaultLanguages) |> then(availableLocalizations(postbox: account.postbox, network: account.network, allowCached: true) |> map {Optional($0)} |> deliverOnMainQueue), appearanceSignal)
        |> mapToSignal { infos, appearance in
            return searchPromise.get() |> map { state in
                return (infos, appearance, state)
            }
        } |> map { infos, appearance, state in
            let entries = languageControllerEntries(infos: infos, language: appearance.language
                , state: state).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
        })
        
        
        
        readyOnce()
        
        
    }
    
    
    
}
