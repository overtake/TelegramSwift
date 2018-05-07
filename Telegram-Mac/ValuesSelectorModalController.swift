//
//  ValuesSelectorModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

private final class ValuesSelectorArguments <T> where T : Equatable {
    let selectItem:(ValuesSelectorValue<T>)->Void
    init(selectItem:@escaping(ValuesSelectorValue<T>)->Void) {
        self.selectItem = selectItem
    }
}

private enum ValuesSelectorEntry<T> : TableItemListNodeEntry where T : Equatable {
    
    case value(index: Int32, value: ValuesSelectorValue<T>, selected: Bool)
    var stableId: Int32 {
        switch self {
        case let .value(index, _, _):
            return index
        }
    }
    
    func item(_ arguments: ValuesSelectorArguments<T>, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .value(_, value, selected):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: value.localized, type: .none, action: {
                arguments.selectItem(value)
            })
        }
    }
}

private func ==<T>(lhs: ValuesSelectorEntry<T>, rhs: ValuesSelectorEntry<T>) -> Bool {
    switch lhs {
    case let .value(index, value, selected):
        if case .value(index, value, selected) = rhs {
            return true
        } else {
            return false
        }
    }
}

private func <<T>(lhs: ValuesSelectorEntry<T>, rhs: ValuesSelectorEntry<T>) -> Bool {
    return lhs.stableId < rhs.stableId
}

private final class ValuesSelectorModalView : View {
    let tableView: TableView = TableView(frame: NSZeroRect)
    private let title: TextView = TextView()
    fileprivate let searchView: SearchView = SearchView(frame: NSZeroRect)
    private let separator : View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(tableView)
        addSubview(separator)
        addSubview(searchView)
        separator.backgroundColor = theme.colors.border
    }
    
    func hasSearch(_ hasSearch: Bool) {
        searchView.isHidden = !hasSearch
        title.isHidden = hasSearch
    }
    
    func updateTitle(_ title: String) {
        self.title.update(TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1))
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 50)
        title.layout?.measure(width: frame.width - 60)
        title.update(title.layout)
        title.centerX(y: floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - title.frame.height) / 2))
        searchView.setFrameSize(NSMakeSize(frame.width - 20, 30))
        searchView.centerX(y: floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - searchView.frame.height) / 2))
        separator.frame = NSMakeRect(0, 49, frame.width, .borderSize)
    }
}

private final class ValuesSelectorState<T> : Equatable where T : Equatable {
    let selected: ValuesSelectorValue<T>?
    let values: [ValuesSelectorValue<T>]
    init(selected: ValuesSelectorValue<T>? = nil, values: [ValuesSelectorValue<T>] = []) {
        self.selected = selected
        self.values = values
    }
    
    func withUpdatedSelected(_ selected: ValuesSelectorValue<T>?) -> ValuesSelectorState {
        return ValuesSelectorState(selected: selected, values: self.values)
    }
    func withUpdatedValues(_ values: [ValuesSelectorValue<T>]) -> ValuesSelectorState {
        return ValuesSelectorState(selected: self.selected, values: values)
    }
}

private func ==<T>(lhs: ValuesSelectorState<T>, rhs: ValuesSelectorState<T>) -> Bool {
    return lhs.selected == rhs.selected && lhs.values == rhs.values
}

fileprivate func prepareTransition<T>(left:[ValuesSelectorEntry<T>], right: [ValuesSelectorEntry<T>], initialSize:NSSize, arguments: ValuesSelectorArguments<T>) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

struct ValuesSelectorValue <T> : Equatable where T : Equatable {
    let localized: String
    let value: T
    init(localized: String, value: T) {
        self.localized = localized
        self.value = value
    }
}

func ==<T>(lhs: ValuesSelectorValue<T>, rhs: ValuesSelectorValue<T>) -> Bool {
    return lhs.value == rhs.value 
}

class ValuesSelectorModalController<T>: ModalViewController where T : Equatable {

    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.modalCancel, accept: { [weak self] in
            self?.close()
        }, drawBorder: false, height: 50)
    }
    
    private func complete() {
        if let selected = stateValue.modify({$0}).selected {
            self.onComplete(selected)
        }
        close()
    }
    
    
    override func viewClass() -> AnyClass {
        return ValuesSelectorModalView.self
    }
    
    private let onComplete:(ValuesSelectorValue<T>)->Void
    private let disposable = MetaDisposable()
    private let title: String
    private let stateValue: Atomic<ValuesSelectorState<T>>
    init(values: [ValuesSelectorValue<T>], selected: ValuesSelectorValue<T>?, title: String, onComplete:@escaping(ValuesSelectorValue<T>)->Void) {
        self.stateValue = Atomic(value: ValuesSelectorState(selected: nil, values: values))
        self.onComplete = onComplete
        self.title = title
        super.init(frame: NSMakeRect(0, 0, 250, 100))
        self.bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.updateTitle(self.title)
        genericView.hasSearch(self.stateValue.modify({$0}).values.count > 10)
        
        let search:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)

        let searchInteractions = SearchInteractions({ s in
            search.set(s)
        }, { s in
            search.set(s)
        })
        
        
        genericView.searchView.searchInteractions = searchInteractions
        
        let statePromise: ValuePromise<ValuesSelectorState<T>> = ValuePromise(ignoreRepeated: true)
        let stateValue = self.stateValue
        let updateState:((ValuesSelectorState<T>)->ValuesSelectorState<T>) -> Void = { f in
            statePromise.set(stateValue.modify(f))
        }
        
        updateState { current in
            return current
        }
        
        
        let arguments = ValuesSelectorArguments<T>(selectItem: { [weak self] selected in
            updateState { current in
                return current.withUpdatedSelected(selected)
            }
            self?.complete()
        })
        
        let initialSize = self.atomicSize
        
        let previous: Atomic<[ValuesSelectorEntry<T>]> = Atomic(value: [])
        
        let signal: Signal<TableUpdateTransition, Void> = combineLatest(statePromise.get() |> deliverOnPrepareQueue, search.get() |> deliverOnPrepareQueue) |> map { state, search in
            
            var entries:[ValuesSelectorEntry<T>] = []
            var index: Int32 = 0
            for value in state.values {
                let result = value.localized.split(separator: " ").filter({$0.lowercased().hasPrefix(search.request.lowercased())})
                if search.request.isEmpty || !result.isEmpty {
                    entries.append(ValuesSelectorEntry.value(index: index, value: value, selected: state.selected == value))
                    index += 1
                }
            }
            
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            self.genericView.tableView.merge(with: transition)
            self.readyOnce()
        }))
        
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.searchView.input
    }
    
    private func updateSize(_ width: CGFloat, animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(width, min(contentSize.height - 70, genericView.tableView.listHeight + 50)), animated: animated)
        }
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + 50)), animated: false)
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        complete()
        return .invoked
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    private var genericView:ValuesSelectorModalView {
        return self.view as! ValuesSelectorModalView
    }
    
    deinit {
        disposable.dispose()
    }
    
}
