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
    init(context: AccountContext, change:@escaping(LocalizationInfo)->Void, delete:@escaping(LocalizationInfo)->Void) {
        self.context = context
        self.change = change
        self.delete = delete
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
    case language(sectionId: Int32, index:Int32, selected: Bool, deletable: Bool, value: LocalizationInfo, viewType: GeneralViewType)
    case section(Int32, Bool)
    case header(sectionId: Int32, index:Int32, descId: Int32, value: String, viewType: GeneralViewType)
    case loading
    var stableId: LanguageTableEntryId {
        switch self {
        case .language(_, _, _, _, let value, _):
            return .language(value.languageCode)
        case let .section(sectionId, _):
            return .sectionId(sectionId)
        case let .header(_, _, id, _, _):
            return .headerId(id)
        case .loading:
            return .loading
        }
    }
    
    
    var index:Int32 {
        switch self {
        case let .language(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + index
        case let .header(sectionId, index, _, _, _):
            return (sectionId * 1000) + index
        case let .section(sectionId, _):
            return (sectionId + 1) * 1000 - sectionId
        case .loading:
            return -1
        }
    }
    
    func item(_ arguments: LanguageControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .language(_, _, selected, deletable, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: value.title, description: value.localizedTitle, descTextColor: theme.colors.grayText, type: .selectable(selected), viewType: viewType, action: {
                arguments.change(value)
            }, menuItems: {
                if deletable {
                    return [ContextMenuItem(L10n.messageContextDelete, handler: {
                        arguments.delete(value)
                    })]
                }
                return []
            })
        case let .section(_, hasSearch):
            return GeneralRowItem(initialSize, height: hasSearch ? 80 : 30, stableId: stableId, viewType: .separator)
        case let .header(_, _, _, value, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: value, viewType: viewType)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        }
    }
}

func <(lhs:LanguageTableEntry, rhs:LanguageTableEntry) -> Bool {
    return lhs.index < rhs.index
}



private func languageControllerEntries(listState: LocalizationListState?, language: TelegramLocalization, state:SearchState, searchViewState: TableSearchViewState) -> [LanguageTableEntry] {

    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    var entries: [LanguageTableEntry] = []
    if let listState = listState, !listState.availableSavedLocalizations.isEmpty || !listState.availableOfficialLocalizations.isEmpty {
        
        
        switch searchViewState {
        case .visible:
            entries.append(.section(sectionId, true))
            sectionId += 1
        default:
            entries.append(.section(sectionId, false))
            sectionId += 1
        }
        
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
        
        
        let saved = availableSavedLocalizations.filter { value in
            
            if existingIds.contains(value.languageCode) {
                return false
            }
            
            var accept: Bool = true
            if !state.request.isEmpty {
                accept = (value.title.lowercased().range(of: state.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.request.lowercased()) != nil)
            }
            return accept
        }
        
        for value in saved {
            let viewType: GeneralViewType = bestGeneralViewType(saved, for: value)
            
            existingIds.insert(value.languageCode)
            entries.append(.language(sectionId: sectionId, index: index, selected: value.languageCode == language.primaryLanguage.languageCode, deletable: true, value: value, viewType: viewType))
            index += 1
        }
        
        
        
        if !availableOfficialLocalizations.isEmpty {
            
            if !availableSavedLocalizations.isEmpty {
                entries.append(.section(sectionId, false))
                sectionId += 1
            }
            
            
            let list = listState.availableOfficialLocalizations.filter { value in
                if existingIds.contains(value.languageCode) {
                    return false
                }
                var accept: Bool = true
                if !state.request.isEmpty {
                    accept = (value.title.lowercased().range(of: state.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.request.lowercased()) != nil)
                }
                return accept
            }
           
            for value in list {
                let viewType: GeneralViewType = bestGeneralViewType(list, for: value)
                existingIds.insert(value.languageCode)
                entries.append(.language(sectionId: sectionId, index: index, selected: value.languageCode == language.primaryLanguage.languageCode, deletable: false, value: value, viewType: viewType))
                index += 1
            }
        }
        
        entries.append(.section(sectionId, false))
        sectionId += 1
        
    } else {
        entries.append(.loading)
    }
    

    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<LanguageTableEntry>], right: [AppearanceWrapperEntry<LanguageTableEntry>], initialSize:NSSize, animated: Bool, arguments:LanguageControllerArguments, searchViewState: TableSearchViewState) -> Signal<TableUpdateTransition, NoError> {
    
    
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
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state: .none(nil), searchState: searchViewState))
            
            prepareQueue.async {
                if !cancelled {
                    
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []
                    
                    for i in initialIndex ..< entries.count {
                        let item:TableRowItem
                        item = entries[i].entry.item(arguments, initialSize: initialSize)
                        insertions.append((i, item))
                    }
                    
                    
                    subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: .none(nil), searchState: searchViewState))
                    subscriber.putCompletion()
                }
            }
        } else {
            let (deleted,inserted,updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
                return entry.entry.item(arguments, initialSize: initialSize)
            })
            
            subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated: animated, state: .none(nil), searchState: searchViewState))
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
    
    private var toggleSearch:(()->Void)? = nil
    
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
    
    override func getRightBarViewOnce() -> BarView {
        let view = ImageBarView(controller: self, theme.icons.chatSearch)
        
        view.button.set(handler: { [weak self] _ in
            self?.toggleSearch?()
        }, for: .Click)
        view.set(image: theme.icons.chatSearch, highlightImage: nil)
        return view
    }
    
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        (self.rightBarView as? ImageBarView)?.set(image: theme.icons.chatSearch, highlightImage: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.toggleSearch?()
            return .invoked
        }, with: self, for: .F, modifierFlags: [.command])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        let context = self.context
        
        
        let stateValue: Atomic<SearchState> = Atomic(value: SearchState(state: .None, request: nil))
        let statePromise:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)
        
        let updateState:((SearchState)->SearchState)->Void = { f in
            statePromise.set(stateValue.modify(f))
        }

        
        let searchValue:Atomic<TableSearchViewState> = Atomic(value: .none)
        let searchState: ValuePromise<TableSearchViewState> = ValuePromise(.none, ignoreRepeated: true)
        let updateSearchValue:((TableSearchViewState)->TableSearchViewState)->Void = { f in
            searchState.set(searchValue.modify(f))
        }
        
        let searchData = TableSearchVisibleData(cancelImage: theme.icons.chatSearchCancel, cancel: {
            updateSearchValue { _ in
                return .none
            }
        }, updateState: { searchState in
            updateState { _ in
                return searchState
            }
        })
        
        
        self.toggleSearch = {
            updateSearchValue { current in
                switch current {
                case .none:
                    return .visible(searchData)
                case .visible:
                    return .none
                }
            }
        }
        
        let arguments = LanguageControllerArguments(context: context, change: { [weak self] value in
            if value.languageCode != appCurrentLanguage.primaryLanguage.languageCode {
                self?.applyDisposable.set(showModalProgress(signal: downloadAndApplyLocalization(accountManager:context.sharedContext.accountManager, postbox: context.account.postbox, network: context.account.network, languageCode: value.languageCode), for: mainWindow).start())
            }
        }, delete: { info in
            confirm(for: context.window, information: L10n.languageRemovePack, successHandler: { _ in
                let _ = (context.account.postbox.transaction { transaction in
                    removeSavedLocalization(transaction: transaction, languageCode: info.languageCode)
                }).start()
            })
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<LanguageTableEntry>]> = Atomic(value: [])
        
        let initialSize = atomicSize

        let signal = context.account.postbox.preferencesView(keys: [PreferencesKeys.localizationListState]) |> map { value -> LocalizationListState? in
            return value.values[PreferencesKeys.localizationListState] as? LocalizationListState
        } |> deliverOnPrepareQueue
        
        let first: Atomic<Bool> = Atomic(value: true)
        let prevSearch: Atomic<String?> = Atomic(value: nil)

        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(signal, appearanceSignal, statePromise.get(), searchState.get()) |> mapToSignal { listState, appearance, state, searchViewState in
            let entries = languageControllerEntries(listState: listState, language: appearance.language, state: state, searchViewState: searchViewState)
                .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.with { $0 }, animated: prevSearch.swap(state.request) == state.request, arguments: arguments, searchViewState: searchViewState)
                    |> runOn(first.swap(false) ? .mainQueue() : prepareQueue)
            } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
    }
    

}
