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



final class LanguageControllerArguments {
    let context:AccountContext
    let change:(LocalizationInfo)->Void
    let delete:(LocalizationInfo)->Void
    let searchInteractions:SearchInteractions
    init(context: AccountContext, change:@escaping(LocalizationInfo)->Void, delete:@escaping(LocalizationInfo)->Void, searchInteractions: SearchInteractions) {
        self.context = context
        self.change = change
        self.delete = delete
        self.searchInteractions = searchInteractions
    }
}

enum LanguageTableEntryId : Hashable {
    case search
    case language(String)
    case loading
    case sectionId(Int32)
    case headerId(Int32)
    var hashValue: Int {
        switch self {
        case .search:
            return 0
        case .language(let id):
            return id.hashValue
        case .loading:
            return 1
        case .sectionId:
            return 2
        case .headerId:
            return 3
        }
    }
}

enum LanguageTableEntry : TableItemListNodeEntry {
    case search(sectionId: Int32)
    case language(sectionId: Int32, index:Int32, selected: Bool, deletable: Bool, value: LocalizationInfo)
    case section(Int32)
    case header(sectionId: Int32, index:Int32, descId: Int32, value: String)
    case loading
    var stableId: LanguageTableEntryId {
        switch self {
        case .search:
            return .search
        case .language(_, _, _, _, let value):
            return .language(value.languageCode)
        case let .section(sectionId):
            return .sectionId(sectionId)
        case let .header(_,_, id, _):
            return .headerId(id)
        case .loading:
            return .loading
        }
    }
    
    
    var index:Int32 {
        switch self {
        case let .search(sectionId):
            return (sectionId * 1000) + 0
        case let .language(sectionId, index, _, _, _):
            return (sectionId * 1000) + index
        case let .header(sectionId, index, _, _):
            return (sectionId * 1000) + index
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        case .loading:
            return -1
        }
    }
    
    func item(_ arguments: LanguageControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .search:
            return SearchRowItem(initialSize, stableId: stableId, searchInteractions: arguments.searchInteractions, inset: NSEdgeInsets(left: 25, right: 25, top: 10, bottom: 10))
        case let .language(_, _, selected, deletable, value):
            return LanguageRowItem(initialSize: initialSize, stableId: stableId, selected: selected, deletable: deletable, value: value, action: {
                arguments.change(value)
            }, deleteAction: {
                arguments.delete(value)
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .header(_, _, _, value):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: value, drawCustomSeparator: true, inset: NSEdgeInsets(left: 25, right: 25, top:2, bottom:6))
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        }
    }
}

func <(lhs:LanguageTableEntry, rhs:LanguageTableEntry) -> Bool {
    return lhs.index < rhs.index
}



private func languageControllerEntries(listState: LocalizationListState?, language: TelegramLocalization, state:SearchState) -> [LanguageTableEntry] {

    var sectionId: Int32 = 0
    
    var entries: [LanguageTableEntry] = []
    if let listState = listState, !listState.availableSavedLocalizations.isEmpty || !listState.availableOfficialLocalizations.isEmpty {
        
        entries.append(.search(sectionId: sectionId))
        var index:Int32 = 1
        
        
        
        let availableSavedLocalizations = listState.availableSavedLocalizations.filter({ info in !listState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) }).filter { value in
            if state.request.isEmpty {
                return true
            } else {
                return (value.title.lowercased().range(of: state.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.request.lowercased()) != nil)
            }
        }
        
        let availableOfficialLocalizations = listState.availableOfficialLocalizations.filter { value in
            if state.request.isEmpty {
                return true
            } else {
                return (value.title.lowercased().range(of: state.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.request.lowercased()) != nil)
            }
        }
    
        var existingIds:Set<String> = Set()
        
        
        for value in availableSavedLocalizations {
            
            if existingIds.contains(value.languageCode) {
                continue
            }
            
            var accept: Bool = true
            if !state.request.isEmpty {
                accept = (value.title.lowercased().range(of: state.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.request.lowercased()) != nil)
            }
            if accept {
                existingIds.insert(value.languageCode)
                entries.append(.language(sectionId: sectionId, index: index, selected: value.languageCode == language.primaryLanguage.languageCode, deletable: true, value: value))
                index += 1
            }
        }
        
        
        
        if !availableOfficialLocalizations.isEmpty {
            
            if !availableSavedLocalizations.isEmpty {
                entries.append(.section(sectionId))
                sectionId += 1
                entries.append(.section(sectionId))
                sectionId += 1
                
                
              //  entries.append(.header(sectionId: sectionId, index: index, descId: randomInt32(), value: L10n.languageOfficialTransationsHeader))
                //index += 1
            }
            
           
            for value in listState.availableOfficialLocalizations {
                if existingIds.contains(value.languageCode) {
                    continue
                }
                var accept: Bool = true
                if !state.request.isEmpty {
                    accept = (value.title.lowercased().range(of: state.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.request.lowercased()) != nil)
                }
                if accept {
                    existingIds.insert(value.languageCode)
                    entries.append(.language(sectionId: sectionId, index: index, selected: value.languageCode == language.primaryLanguage.languageCode, deletable: false, value: value))
                    index += 1
                }
            }
        }
        
        
    } else {
        entries.append(.loading)
    }
    

    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<LanguageTableEntry>], right: [AppearanceWrapperEntry<LanguageTableEntry>], initialSize:NSSize, animated: Bool, arguments:LanguageControllerArguments) -> Signal<TableUpdateTransition, NoError> {
    
    
    return Signal { subscriber in
        
        
        var cancelled = false
        
        
        if Thread.isMainThread {
            var initialIndex:Int = 0
            var height:CGFloat = 0
            var firstInsertion:[(Int, TableRowItem)] = []
            let entries = Array(right)
            
            let index:Int = 0
            
            for i in index ..< entries.count {
                let item = entries[i].entry.item(arguments, initialSize: initialSize)
                height += item.height
                firstInsertion.append((i, item))
                if initialSize.height < height {
                    break
                }
            }
            
            
            initialIndex = firstInsertion.count
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state: .none(nil)))
            
            prepareQueue.async {
                if !cancelled {
                    
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []
                    
                    for i in initialIndex ..< entries.count {
                        let item:TableRowItem
                        item = entries[i].entry.item(arguments, initialSize: initialSize)
                        insertions.append((i, item))
                    }
                    
                    
                    subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: .none(nil)))
                    subscriber.putCompletion()
                }
            }
        } else {
            let (deleted,inserted,updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
                return entry.entry.item(arguments, initialSize: initialSize)
            })
            
            subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: .none(nil)))
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            cancelled = true
        }
    }
    
}



class LanguageViewController: TableViewController {
    private let languageDisposable = MetaDisposable()
    private let applyDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    
    override var enableBack: Bool {
        return true
    }
    
    override init(_ context: AccountContext) {
        super.init(context)
    }
    
    deinit {
        applyDisposable.dispose()
        languageDisposable.dispose()
        disposable.dispose()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        let searchPromise = ValuePromise<SearchState>()
        let context = self.context
        
        let removeItem: (String) -> Void = { id in
            let _ = (context.account.postbox.transaction { transaction in
                removeSavedLocalization(transaction: transaction, languageCode: id)
            }).start()
        }
        
        var animated: Bool = false
        
        let searchInteractions = SearchInteractions({ state, _ in
            animated = false
            searchPromise.set(state)
        }, { state in
            animated = false
            searchPromise.set(state)
        })
        searchPromise.set(SearchState(state: .None, request: nil))
        
        
        let arguments = LanguageControllerArguments(context: context, change: { [weak self] value in
            if value.languageCode != appCurrentLanguage.primaryLanguage.languageCode {
                animated = true
                self?.applyDisposable.set(showModalProgress(signal: downloadAndApplyLocalization(accountManager:context.sharedContext.accountManager, postbox: context.account.postbox, network: context.account.network, languageCode: value.languageCode), for: mainWindow).start())
            }
        }, delete: { info in
            confirm(for: mainWindow, information: L10n.languageRemovePack, successHandler: { _ in
                animated = true
                removeItem(info.languageCode)
            })
        }, searchInteractions: searchInteractions)
        
        let previous:Atomic<[AppearanceWrapperEntry<LanguageTableEntry>]> = Atomic(value: [])
        
        let initialSize = atomicSize

        let signal = context.account.postbox.preferencesView(keys: [PreferencesKeys.localizationListState]) |> map { value -> LocalizationListState? in
            return value.values[PreferencesKeys.localizationListState] as? LocalizationListState
        } |> deliverOnPrepareQueue
        
        let first: Atomic<Bool> = Atomic(value: true)
        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(signal, appearanceSignal)
            |> mapToSignal { infos, appearance in
                return searchPromise.get() |> map { state in
                    return (infos, appearance, state)
                }
            } |> mapToSignal { listState, appearance, state in
                let entries = languageControllerEntries(listState: listState, language: appearance.language, state: state).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify({$0}), animated: animated, arguments: arguments) |> runOn(first.swap(false) ? .mainQueue() : prepareQueue)
            } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
    }
    
    
    
}
